// Pack system.
//
// Packs live in packs/<name>/ alongside the game binary (or served alongside game.js on web).
// Each pack contains:
//   pack.hscript   - script describing the pack's candies and rules
//   shapes/*.png   - (or any image path referenced by the script)
//
// PackManager.load(onDone) is async - call it from loadAssets() before init().
//
// pack.hscript API:
//   pack.name = "My Pack";
//   pack.matchScore = 15;
//   pack.addCandy("shapes/my_red.png");   // path relative to the pack folder

typedef CandyDef = {
    var imagePath: String;   // full path as served: e.g. "packs/default/shapes/blue_body_circle.png"
    var tile: h2d.Tile;      // loaded at runtime
}

class PackApi {
    public var name: String = "Unnamed Pack";
    public var matchScore: Int = 10;

    var _packDir: String;
    var _candies: Array<{ imagePath: String }> = [];

    public function new(packDir: String) {
        _packDir = packDir;
    }

    // imagePath is relative to the pack folder
    public function addCandy(imagePath: String) {
        _candies.push({ imagePath: '$_packDir/$imagePath' });
    }

    public function getRawCandies() return _candies;
}

class PackManager {
    public static var candies(default, null): Array<CandyDef> = [];
    public static var matchScore(default, null): Int = 10;

    static var parser = new hscript.Parser();

    // Async entry point - call from hxd.App.loadAssets()
    public static function load(onDone: Void -> Void) {
        candies = [];
        var interp = makeInterp();

        #if sys
        loadDesktop(interp, onDone);
        #else
        loadWeb(interp, onDone);
        #end
    }

    static function makeInterp(): hscript.Interp {
        var interp = new hscript.Interp();
        interp.variables.set("Math", Math);
        interp.variables.set("Std", Std);
        interp.variables.set("trace", Reflect.makeVarArgs(function(args) trace(args.join(" "))));
        return interp;
    }

    // -------------------------------------------------------------------------
    // Desktop: use LocalFileSystem to scan packs/ directory
    // -------------------------------------------------------------------------

    #if sys
    static function loadDesktop(interp: hscript.Interp, onDone: Void -> Void) {
        var packsFs = new hxd.fs.LocalFileSystem("packs", "");
        var packNames = getPackNames(packsFs);

        for (name in packNames) {
            // Each pack gets its own LocalFileSystem rooted at packs/<name>/
            var packFs = new hxd.fs.LocalFileSystem('packs/$name', "");
            if (!packFs.exists("pack.hscript")) continue;
            var source = packFs.get("pack.hscript").getText();
            var api = runScript(interp, source, 'packs/$name', 'packs/$name/pack.hscript');
            if (api == null) continue;
            var loader = new hxd.res.Loader(packFs);
            for (raw in api.getRawCandies()) {
                // raw.imagePath is like "packs/default/shapes/foo.png" — strip "packs/<name>/"
                var rel = raw.imagePath.substr('packs/$name/'.length);
                if (!packFs.exists(rel)) { trace('Missing asset: ${raw.imagePath}'); continue; }
                var bmp = loader.load(rel).toImage().toBitmap();
                var tile = h2d.Tile.fromBitmap(bmp);
                candies.push({ imagePath: raw.imagePath, tile: tile });
            }
            matchScore = api.matchScore;
            trace('Loaded pack "${api.name}" with ${api.getRawCandies().length} candies');
        }
        onDone();
    }

    static function getPackNames(fs: hxd.fs.LocalFileSystem): Array<String> {
        var names: Array<String> = [];
        for (e in fs.getRoot().iterator()) {
            if (e.isDirectory) names.push(e.name);
        }
        names.sort(function(a, b) {
            if (a == "default") return -1;
            if (b == "default") return 1;
            return Reflect.compare(a, b);
        });
        return names;
    }
    #end

    // -------------------------------------------------------------------------
    // Web: fetch packs/manifest.txt via XHR, then fetch each pack script,
    //      then load images via js.html.Image
    // -------------------------------------------------------------------------

    #if !sys
    static function loadWeb(interp: hscript.Interp, onDone: Void -> Void) {
        fetchText("packs/manifest.txt", function(content) {
            if (content == null) {
                trace("No packs/manifest.txt found - no packs loaded");
                onDone();
                return;
            }
            var names = content.split("\n").map(s -> StringTools.trim(s)).filter(s -> s.length > 0);
            // default first
            names.sort(function(a, b) {
                if (a == "default") return -1;
                if (b == "default") return 1;
                return Reflect.compare(a, b);
            });
            loadWebPacks(interp, names, onDone);
        });
    }

    static function loadWebPacks(interp: hscript.Interp, names: Array<String>, onDone: Void -> Void) {
        if (names.length == 0) { onDone(); return; }
        var name = names.shift();
        fetchText('packs/$name/pack.hscript', function(source) {
            if (source == null) {
                loadWebPacks(interp, names, onDone);
                return;
            }
            var api = runScript(interp, source, 'packs/$name', 'packs/$name/pack.hscript');
            if (api == null) { loadWebPacks(interp, names, onDone); return; }
            var rawCandies = api.getRawCandies().copy();
            loadWebImages(rawCandies, function(defs) {
                for (d in defs) candies.push(d);
                matchScore = api.matchScore;
                trace('Loaded pack "${api.name}" with ${defs.length} candies');
                loadWebPacks(interp, names, onDone);
            });
        });
    }

    static function loadWebImages(raws: Array<{ imagePath: String }>, onDone: Array<CandyDef> -> Void) {
        var defs: Array<CandyDef> = [];
        var remaining = raws.length;
        if (remaining == 0) { onDone(defs); return; }
        for (raw in raws) {
            var path = raw.imagePath;
            var img = new js.html.Image();
            img.onload = function() {
                var bmp = new hxd.BitmapData(img.width, img.height);
                @:privateAccess bmp.ctx.drawImage(img, 0, 0);
                var tile = h2d.Tile.fromBitmap(bmp);
                defs.push({ imagePath: path, tile: tile });
                remaining--;
                if (remaining == 0) onDone(defs);
            };
            img.onerror = function(_) {
                trace('Failed to load image: $path');
                remaining--;
                if (remaining == 0) onDone(defs);
            };
            img.src = path;
        }
    }

    static function fetchText(url: String, onDone: Null<String> -> Void) {
        var loader = new hxd.net.BinaryLoader(url);
        loader.onLoaded = function(bytes) onDone(bytes.toString());
        loader.onError = function(_) onDone(null);
        loader.load();
    }
    #end

    // -------------------------------------------------------------------------
    // Shared
    // -------------------------------------------------------------------------

    static function runScript(interp: hscript.Interp, source: String, packDir: String, path: String): Null<PackApi> {
        var api = new PackApi(packDir);
        interp.variables.set("pack", api);
        try {
            interp.execute(parser.parseString(source));
        } catch (e: Dynamic) {
            trace('Pack script error in $path: $e');
            return null;
        }
        return api;
    }
}
