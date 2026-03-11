package;

import ceramic.Color;
import ceramic.Easing;
import ceramic.PixelArt;
import ceramic.Quad;
import ceramic.Scene;
import ceramic.Text;
import ceramic.Timer;
import ceramic.TouchInfo;
import ceramic.Tween;

class MainScene extends Scene {
    static inline var COLS = 8;
    static inline var ROWS = 8;
    static inline var TILE_SIZE = 40;
    static inline var NUM_COLORS = 6;
    static inline var BOARD_X = 8;
    static inline var BOARD_Y = 72;
    static inline var SWAP_DUR = 0.15;
    static inline var REMOVE_DUR = 0.2;
    static inline var DROP_DUR = 0.1;

    // Tool costs (total matches needed to earn one)
    static inline var BOMB_COST = 5;
    static inline var ROW_BOMB_COST = 15;
    static inline var COLOR_BOMB_COST = 25;

    var pixelArt:PixelArt;

    var grid:Array<Int> = [];
    var quads:Array<Quad> = [];

    var selected:Int = -1;
    var selectionQuad:Quad;
    var busy:Bool = false;
    var combo:Int = 0;

    // score & level
    var score:Int = 0;
    var levelScore:Int = 0;
    var level:Int = 1;
    var totalMatches:Int = 0;
    var levelTarget:Int = 300;
    var inClearPhase:Bool = false;

    // tools inventory
    var bombs:Int = 0;
    var rowBombs:Int = 0;
    var colorBombs:Int = 0;
    var lastBombAt:Int = 0;
    var lastRowBombAt:Int = 0;
    var lastColorBombAt:Int = 0;

    // active tool mode
    var activeTool:Int = 0;
    static inline var TOOL_NONE = 0;
    static inline var TOOL_BOMB = 1;
    static inline var TOOL_ROW = 2;
    static inline var TOOL_COLOR = 3;

    // UI elements
    var scoreText:Text;
    var levelText:Text;
    var phaseText:Text;
    var comboText:Text;

    var bombBtn:Quad;
    var bombCountText:Text;
    var rowBombBtn:Quad;
    var rowBombCountText:Text;
    var colorBombBtn:Quad;
    var colorBombCountText:Text;
    var toolHighlight:Quad;

    // overlay
    var overlayBg:Quad;
    var overlayText:Text;
    var overlaySubText:Text;
    var overlayVisible:Bool = false;

    override function preload() {
        assets.add(Images.JOOLS);
        assets.add(Images.ICON_BOMB);
        assets.add(Images.ICON_ROW);
        assets.add(Images.ICON_COLOR);
        assets.add(Sounds.SWAP);
        assets.add(Sounds.MATCH);
        assets.add(Sounds.DROP);
        assets.add(Sounds.INVALID);
        assets.add(Sounds.BOMB);
        assets.add(Sounds.LEVELUP);
        assets.add(Sounds.REWARD);
    }

    override function create() {
        pixelArt = cast app.scenes.filter;
        buildUI();
        initGrid();
    }

    function buildUI() {
        // Score (top-left)
        scoreText = new Text();
        scoreText.content = "Score: 0";
        scoreText.color = Color.WHITE;
        scoreText.pos(BOARD_X, 2);
        add(scoreText);

        // Level (top-right area)
        levelText = new Text();
        levelText.content = "Lv 1";
        levelText.color = Color.WHITE;
        levelText.pos(270, 2);
        add(levelText);

        // Phase indicator
        phaseText = new Text();
        phaseText.content = "";
        phaseText.color = Color.GREEN;
        phaseText.pos(BOARD_X + 200, 20);
        add(phaseText);

        // Combo text
        comboText = new Text();
        comboText.content = "";
        comboText.color = Color.YELLOW;
        comboText.pos(180, 56);
        comboText.alpha = 0;
        comboText.depth = 10;
        add(comboText);

        // Tool buttons row (y=26)
        var toolY = 26;
        var toolSize = 26;
        var toolGap = 6;
        var toolStartX = BOARD_X;

        bombBtn = makeToolButton(toolStartX, toolY, toolSize, Color.RED);
        bombCountText = makeToolCount(toolStartX + toolSize - 8, toolY - 4);

        rowBombBtn = makeToolButton(toolStartX + toolSize + toolGap, toolY, toolSize, Color.ORANGE);
        rowBombCountText = makeToolCount(toolStartX + toolSize + toolGap + toolSize - 8, toolY - 4);

        colorBombBtn = makeToolButton(toolStartX + (toolSize + toolGap) * 2, toolY, toolSize, Color.CYAN);
        colorBombCountText = makeToolCount(toolStartX + (toolSize + toolGap) * 2 + toolSize - 8, toolY - 4);

        // Tool icons
        addToolIcon(Images.ICON_BOMB, toolStartX, toolY, toolSize);
        addToolIcon(Images.ICON_ROW, toolStartX + toolSize + toolGap, toolY, toolSize);
        addToolIcon(Images.ICON_COLOR, toolStartX + (toolSize + toolGap) * 2, toolY, toolSize);

        // Tool highlight
        toolHighlight = new Quad();
        toolHighlight.size(toolSize + 4, toolSize + 4);
        toolHighlight.color = Color.WHITE;
        toolHighlight.visible = false;
        toolHighlight.depth = 4;
        add(toolHighlight);

        // Click handlers
        bombBtn.onPointerDown(this, function(_:TouchInfo) { toggleTool(TOOL_BOMB); });
        rowBombBtn.onPointerDown(this, function(_:TouchInfo) { toggleTool(TOOL_ROW); });
        colorBombBtn.onPointerDown(this, function(_:TouchInfo) { toggleTool(TOOL_COLOR); });

        // Overlay
        overlayBg = new Quad();
        overlayBg.size(336, 416);
        overlayBg.pos(0, 0);
        overlayBg.color = Color.BLACK;
        overlayBg.alpha = 0;
        overlayBg.depth = 50;
        overlayBg.touchable = false;
        add(overlayBg);

        overlayText = new Text();
        overlayText.content = "";
        overlayText.color = Color.YELLOW;
        overlayText.pos(40, 170);
        overlayText.depth = 51;
        overlayText.alpha = 0;
        add(overlayText);

        overlaySubText = new Text();
        overlaySubText.content = "";
        overlaySubText.color = Color.WHITE;
        overlaySubText.pos(40, 210);
        overlaySubText.depth = 51;
        overlaySubText.alpha = 0;
        add(overlaySubText);

        // Selection highlight
        selectionQuad = new Quad();
        selectionQuad.size(TILE_SIZE + 4, TILE_SIZE + 4);
        selectionQuad.color = Color.YELLOW;
        selectionQuad.visible = false;
        selectionQuad.depth = 0;
        add(selectionQuad);

        updateToolUI();
    }

    function addToolIcon(image:Dynamic, x:Float, y:Float, size:Int) {
        var icon = new Quad();
        icon.texture = assets.texture(image);
        icon.size(size, size);
        icon.pos(x, y);
        icon.depth = 6;
        icon.touchable = false;
        add(icon);
    }

    function makeToolButton(x:Float, y:Float, size:Int, color:Color):Quad {
        var q = new Quad();
        q.size(size, size);
        q.pos(x, y);
        q.color = color;
        q.alpha = 0.3;
        q.depth = 5;
        q.touchable = true;
        add(q);
        return q;
    }

    function makeToolCount(x:Float, y:Float):Text {
        var t = new Text();
        t.content = "0";
        t.color = Color.WHITE;
        t.pos(x, y);
        t.depth = 8;
        add(t);
        return t;
    }

    function initGrid() {
        grid = [];
        quads = [];
        for (i in 0...ROWS * COLS) {
            grid.push(0);
            quads.push(null);
        }
        fillEmptyCells();
        removeInitialMatches();
        rebuildAllQuads();
        updatePhaseText();
    }

    // -- Grid helpers --

    inline function idx(col:Int, row:Int):Int return row * COLS + col;
    inline function colOf(i:Int):Int return i % COLS;
    inline function rowOf(i:Int):Int return Std.int(i / COLS);
    inline function tileX(col:Int):Float return BOARD_X + col * TILE_SIZE;
    inline function tileY(row:Int):Float return BOARD_Y + row * TILE_SIZE;

    function colorAt(col:Int, row:Int):Int {
        if (col < 0 || col >= COLS || row < 0 || row >= ROWS) return -1;
        return grid[idx(col, row)];
    }

    function randomColor():Int return Std.random(NUM_COLORS) + 1;

    function isAdjacent(a:Int, b:Int):Bool {
        var ac = colOf(a); var ar = rowOf(a);
        var bc = colOf(b); var br = rowOf(b);
        return (ac == bc && (ar - br == 1 || ar - br == -1))
            || (ar == br && (ac - bc == 1 || ac - bc == -1));
    }

    // -- Fill & Match --

    function fillEmptyCells() {
        for (i in 0...ROWS * COLS)
            if (grid[i] == 0) grid[i] = randomColor();
    }

    function removeInitialMatches() {
        var changed = true;
        while (changed) {
            changed = false;
            for (r in 0...ROWS) for (c in 0...COLS) {
                var color = grid[idx(c, r)];
                if (c >= 2 && colorAt(c - 1, r) == color && colorAt(c - 2, r) == color) {
                    grid[idx(c, r)] = randomColor(); changed = true;
                }
                if (r >= 2 && colorAt(c, r - 1) == color && colorAt(c, r - 2) == color) {
                    grid[idx(c, r)] = randomColor(); changed = true;
                }
            }
        }
    }

    function findMatches():Array<Int> {
        var matched = new Map<Int, Bool>();
        for (r in 0...ROWS) {
            var c = 0;
            while (c < COLS) {
                var color = colorAt(c, r);
                if (color == 0) { c++; continue; }
                var end = c + 1;
                while (end < COLS && colorAt(end, r) == color) end++;
                if (end - c >= 3) for (x in c...end) matched.set(idx(x, r), true);
                c = end;
            }
        }
        for (c in 0...COLS) {
            var r = 0;
            while (r < ROWS) {
                var color = colorAt(c, r);
                if (color == 0) { r++; continue; }
                var end = r + 1;
                while (end < ROWS && colorAt(c, end) == color) end++;
                if (end - r >= 3) for (y in r...end) matched.set(idx(c, y), true);
                r = end;
            }
        }
        var result:Array<Int> = [];
        for (k in matched.keys()) result.push(k);
        return result;
    }

    function swapCreatesMatch(c1:Int, r1:Int, c2:Int, r2:Int):Bool {
        var i1 = idx(c1, r1); var i2 = idx(c2, r2);
        var tmp = grid[i1]; grid[i1] = grid[i2]; grid[i2] = tmp;
        var matches = findMatches();
        var tmp2 = grid[i1]; grid[i1] = grid[i2]; grid[i2] = tmp2;
        return matches.length > 0;
    }

    function hasValidMoves():Bool {
        for (r in 0...ROWS) for (c in 0...COLS) {
            if (grid[idx(c, r)] == 0) continue;
            if (c + 1 < COLS && grid[idx(c + 1, r)] != 0)
                if (swapCreatesMatch(c, r, c + 1, r)) return true;
            if (r + 1 < ROWS && grid[idx(c, r + 1)] != 0)
                if (swapCreatesMatch(c, r, c, r + 1)) return true;
        }
        return false;
    }

    function shuffleBoard() {
        var n = ROWS * COLS;
        for (i in 0...n - 1) {
            var j = i + Std.random(n - i);
            var tmp = grid[i]; grid[i] = grid[j]; grid[j] = tmp;
        }
    }

    function isBoardEmpty():Bool {
        for (i in 0...ROWS * COLS) if (grid[i] != 0) return false;
        return true;
    }

    function countTiles():Int {
        var n = 0;
        for (i in 0...ROWS * COLS) if (grid[i] != 0) n++;
        return n;
    }

    function applyGravityAndRefill(refill:Bool):Map<Int, Int> {
        var drops = new Map<Int, Int>();
        for (c in 0...COLS) {
            var writeRow = ROWS - 1;
            var r = ROWS - 1;
            while (r >= 0) {
                if (grid[idx(c, r)] != 0) {
                    if (r != writeRow) {
                        grid[idx(c, writeRow)] = grid[idx(c, r)];
                        grid[idx(c, r)] = 0;
                        drops.set(idx(c, writeRow), writeRow - r);
                    }
                    writeRow--;
                }
                r--;
            }
            if (refill) {
                var emptyCount = writeRow + 1;
                var row = writeRow;
                while (row >= 0) {
                    grid[idx(c, row)] = randomColor();
                    drops.set(idx(c, row), emptyCount);
                    row--;
                }
            }
        }
        return drops;
    }

    // -- Visuals --

    function createTileQuad(i:Int):Quad {
        var color = grid[i];
        if (color == 0) return null;
        var col = colOf(i);
        var row = rowOf(i);
        var tileIdx = (color - 1) * 4 + Std.random(4);
        var srcCol = tileIdx % 4;
        var srcRow = Std.int(tileIdx / 4);

        var q = new Quad();
        q.texture = assets.texture(Images.JOOLS);
        q.frame(srcCol * TILE_SIZE, srcRow * TILE_SIZE, TILE_SIZE, TILE_SIZE);
        q.size(TILE_SIZE, TILE_SIZE);
        q.pos(tileX(col), tileY(row));
        q.depth = 1;
        q.touchable = true;
        q.onPointerDown(this, function(info:TouchInfo) { onTileClicked(i); });
        add(q);
        return q;
    }

    function rebuildAllQuads() {
        for (i in 0...quads.length) {
            if (quads[i] != null) { quads[i].destroy(); quads[i] = null; }
        }
        for (i in 0...ROWS * COLS) quads[i] = createTileQuad(i);
    }

    // -- UI updates --

    function updateScoreUI() { scoreText.content = "Score: " + score; }
    function updateLevelUI() { levelText.content = "Lv " + level; }

    function updatePhaseText() {
        if (inClearPhase) {
            phaseText.content = "CLEAR! " + countTiles() + " left";
            phaseText.color = Color.RED;
        } else {
            var remaining = levelTarget - levelScore;
            if (remaining < 0) remaining = 0;
            phaseText.content = remaining + " to clear";
            phaseText.color = Color.GREEN;
        }
    }

    function updateToolUI() {
        bombCountText.content = "" + bombs;
        rowBombCountText.content = "" + rowBombs;
        colorBombCountText.content = "" + colorBombs;
        bombBtn.alpha = bombs > 0 ? 0.9 : 0.3;
        rowBombBtn.alpha = rowBombs > 0 ? 0.9 : 0.3;
        colorBombBtn.alpha = colorBombs > 0 ? 0.9 : 0.3;
    }

    function showCombo(c:Int) {
        if (c > 1) {
            comboText.content = "x" + c + "!";
            comboText.alpha = 1;
            Tween.start(this, LINEAR, 1.0, 1, 0, function(v:Float, _:Float) { comboText.alpha = v; });
        }
    }

    function showBanner(msg:String) {
        comboText.content = msg;
        comboText.alpha = 1;
        Tween.start(this, LINEAR, 2.0, 1, 0, function(v:Float, _:Float) { comboText.alpha = v; });
    }

    // -- Overlay --

    function showOverlay(title:String, sub:String, ?autoClose:Bool = false) {
        overlayVisible = true;
        overlayBg.touchable = true;
        Tween.start(this, QUAD_EASE_OUT, 0.3, 0, 0.75, function(v:Float, _:Float) { overlayBg.alpha = v; });
        overlayText.content = title;
        overlaySubText.content = sub;
        Tween.start(this, QUAD_EASE_OUT, 0.3, 0, 1, function(v:Float, _:Float) {
            overlayText.alpha = v; overlaySubText.alpha = v;
        });
        if (autoClose) Timer.delay(this, 1.5, dismissOverlay);
    }

    function dismissOverlay() {
        if (!overlayVisible) return;
        overlayVisible = false;
        overlayBg.touchable = false;
        Tween.start(this, QUAD_EASE_IN, 0.2, 1, 0, function(v:Float, _:Float) {
            overlayBg.alpha = v * 0.75; overlayText.alpha = v; overlaySubText.alpha = v;
        });
    }

    // -- Tool logic --

    function toggleTool(tool:Int) {
        if (busy || overlayVisible) return;
        var count = switch (tool) { case 1: bombs; case 2: rowBombs; case 3: colorBombs; default: 0; };
        if (count <= 0) return;
        if (activeTool == tool) {
            activeTool = TOOL_NONE;
            toolHighlight.visible = false;
            selectionQuad.color = Color.YELLOW;
        } else {
            activeTool = tool;
            var btn = switch (tool) { case 1: bombBtn; case 2: rowBombBtn; case 3: colorBombBtn; default: bombBtn; };
            toolHighlight.pos(btn.x - 2, btn.y - 2);
            toolHighlight.visible = true;
            selectionQuad.color = Color.RED;
            selected = -1;
            selectionQuad.visible = false;
        }
    }

    function useTool(i:Int) {
        if (grid[i] == 0) return;
        busy = true;
        var tilesToRemove:Array<Int> = [];

        switch (activeTool) {
            case 1:
                bombs--;
                tilesToRemove.push(i);
            case 2:
                rowBombs--;
                var r = rowOf(i);
                for (c in 0...COLS) { var ii = idx(c, r); if (grid[ii] != 0) tilesToRemove.push(ii); }
            case 3:
                colorBombs--;
                var targetColor = grid[i];
                for (j in 0...ROWS * COLS) if (grid[j] == targetColor) tilesToRemove.push(j);
            default: {}
        }

        activeTool = TOOL_NONE;
        toolHighlight.visible = false;
        selectionQuad.color = Color.YELLOW;
        updateToolUI();
        assets.sound(Sounds.BOMB).play();
        combo = 0;
        animateToolRemoval(tilesToRemove);
    }

    function animateToolRemoval(indices:Array<Int>) {
        var points = indices.length * 5;
        score += points;
        levelScore += points;
        updateScoreUI();

        for (i in indices) grid[i] = 0;

        var remaining = indices.length;
        if (remaining == 0) { afterRemoval(); return; }
        for (i in indices) {
            var q = quads[i];
            if (q == null) { remaining--; if (remaining == 0) afterRemoval(); continue; }
            var cx = q.x + TILE_SIZE * 0.5;
            var cy = q.y + TILE_SIZE * 0.5;
            quads[i] = null;
            var capturedQ = q;
            var tw = Tween.start(this, QUAD_EASE_IN, REMOVE_DUR, 0, 1, function(t:Float, _:Float) {
                var s = 1.0 - t;
                capturedQ.size(TILE_SIZE * s, TILE_SIZE * s);
                capturedQ.pos(cx - TILE_SIZE * s * 0.5, cy - TILE_SIZE * s * 0.5);
                capturedQ.alpha = s;
            });
            tw.onceComplete(this, function() {
                capturedQ.destroy();
                remaining--;
                if (remaining == 0) afterRemoval();
            });
        }
    }

    // -- Reward checking --

    function checkRewards(matchCount:Int) {
        totalMatches += matchCount;
        var earned = Std.int(totalMatches / BOMB_COST);
        var newBombs = earned - lastBombAt;
        if (newBombs > 0) { bombs += newBombs; lastBombAt = earned; }

        earned = Std.int(totalMatches / ROW_BOMB_COST);
        var newRowBombs = earned - lastRowBombAt;
        if (newRowBombs > 0) { rowBombs += newRowBombs; lastRowBombAt = earned; }

        earned = Std.int(totalMatches / COLOR_BOMB_COST);
        var newColorBombs = earned - lastColorBombAt;
        if (newColorBombs > 0) { colorBombs += newColorBombs; lastColorBombAt = earned; }

        updateToolUI();

        if (newColorBombs > 0) {
            assets.sound(Sounds.REWARD).play();
            showBanner("Got Color Bomb!");
        } else if (newRowBombs > 0) {
            assets.sound(Sounds.REWARD).play();
            showBanner("Got Row Bomb!");
        } else if (newBombs > 0) {
            assets.sound(Sounds.REWARD).play();
            showBanner("Got Bomb!");
        }
    }

    // -- Input --

    function onTileClicked(i:Int) {
        if (overlayVisible) return;
        if (busy) return;
        if (grid[i] == 0) return;

        if (activeTool != TOOL_NONE) { useTool(i); return; }

        if (selected < 0) {
            selected = i;
            selectionQuad.pos(tileX(colOf(i)) - 2, tileY(rowOf(i)) - 2);
            selectionQuad.visible = true;
        } else if (selected == i) {
            selected = -1;
            selectionQuad.visible = false;
        } else if (isAdjacent(selected, i)) {
            selectionQuad.visible = false;
            var a = selected;
            selected = -1;
            trySwap(a, i);
        } else {
            selected = i;
            selectionQuad.pos(tileX(colOf(i)) - 2, tileY(rowOf(i)) - 2);
        }
    }

    // -- Animated swap --

    function trySwap(a:Int, b:Int) {
        busy = true;
        combo = 0;
        var qa = quads[a]; var qb = quads[b];
        var ax = tileX(colOf(a)); var ay = tileY(rowOf(a));
        var bx = tileX(colOf(b)); var by = tileY(rowOf(b));

        assets.sound(Sounds.SWAP).play();

        animateSwap(qa, ax, ay, bx, by, qb, bx, by, ax, ay, function() {
            var tmp = grid[a]; grid[a] = grid[b]; grid[b] = tmp;
            quads[a] = qb; quads[b] = qa;

            var matches = findMatches();
            if (matches.length == 0) {
                assets.sound(Sounds.INVALID).play();
                animateSwap(qb, ax, ay, bx, by, qa, bx, by, ax, ay, function() {
                    var tmp2 = grid[a]; grid[a] = grid[b]; grid[b] = tmp2;
                    quads[a] = qa; quads[b] = qb;
                    busy = false;
                });
            } else {
                processMatches(matches);
            }
        });
    }

    function animateSwap(q1:Quad, x1From:Float, y1From:Float, x1To:Float, y1To:Float,
                         q2:Quad, x2From:Float, y2From:Float, x2To:Float, y2To:Float,
                         onDone:Void->Void) {
        var done1 = false; var done2 = false;
        var checkDone = function() { if (done1 && done2 && onDone != null) onDone(); };

        if (q1 != null) {
            Tween.start(this, QUAD_EASE_IN_OUT, SWAP_DUR, 0, 1, function(t:Float, _:Float) {
                q1.pos(x1From + (x1To - x1From) * t, y1From + (y1To - y1From) * t);
            }).onceComplete(this, function() { done1 = true; checkDone(); });
        } else { done1 = true; checkDone(); }

        if (q2 != null) {
            Tween.start(this, QUAD_EASE_IN_OUT, SWAP_DUR, 0, 1, function(t:Float, _:Float) {
                q2.pos(x2From + (x2To - x2From) * t, y2From + (y2To - y2From) * t);
            }).onceComplete(this, function() { done2 = true; checkDone(); });
        } else { done2 = true; checkDone(); }
    }

    // -- Match removal --

    function processMatches(matches:Array<Int>) {
        combo++;
        var points = matches.length * 10 * combo;
        score += points;
        levelScore += points;
        updateScoreUI();
        showCombo(combo);
        assets.sound(Sounds.MATCH).play();
        checkRewards(matches.length);

        for (i in matches) grid[i] = 0;

        var remaining = matches.length;
        for (i in matches) {
            var q = quads[i];
            if (q == null) { remaining--; if (remaining == 0) afterRemoval(); continue; }
            var cx = q.x + TILE_SIZE * 0.5;
            var cy = q.y + TILE_SIZE * 0.5;
            quads[i] = null;
            var capturedQ = q;
            Tween.start(this, QUAD_EASE_IN, REMOVE_DUR, 0, 1, function(t:Float, _:Float) {
                var s = 1.0 - t;
                capturedQ.size(TILE_SIZE * s, TILE_SIZE * s);
                capturedQ.pos(cx - TILE_SIZE * s * 0.5, cy - TILE_SIZE * s * 0.5);
                capturedQ.alpha = s;
            }).onceComplete(this, function() {
                capturedQ.destroy();
                remaining--;
                if (remaining == 0) afterRemoval();
            });
        }
    }

    function afterRemoval() {
        // Check phase transition
        if (!inClearPhase && levelScore >= levelTarget) {
            inClearPhase = true;
            updatePhaseText();
            assets.sound(Sounds.REWARD).play();
            showBanner("CLEAR PHASE!");
        }

        var refill = !inClearPhase;
        var drops = applyGravityAndRefill(refill);

        for (i in 0...ROWS * COLS) {
            if (quads[i] != null) { quads[i].destroy(); quads[i] = null; }
        }

        var animCount = 0;
        var hasDrops = false;
        for (i in 0...ROWS * COLS) {
            if (grid[i] != 0) {
                quads[i] = createTileQuad(i);
                if (drops.exists(i)) {
                    hasDrops = true;
                    var dropRows = drops.get(i);
                    var q = quads[i];
                    var finalY = q.y;
                    var startY = finalY - dropRows * TILE_SIZE;
                    q.y = startY;
                    animCount++;
                    var capturedQ = q;
                    var capturedFinalY = finalY;
                    var dur = DROP_DUR + DROP_DUR * dropRows * 0.5;
                    Tween.start(this, BOUNCE_EASE_OUT, dur, 0, 1, function(t:Float, _:Float) {
                        capturedQ.y = startY + (capturedFinalY - startY) * t;
                    }).onceComplete(this, function() {
                        animCount--;
                        if (animCount == 0) {
                            if (hasDrops) assets.sound(Sounds.DROP).play();
                            afterDrop();
                        }
                    });
                }
            }
        }
        if (animCount == 0) {
            if (hasDrops) assets.sound(Sounds.DROP).play();
            afterDrop();
        }
    }

    function afterDrop() {
        updatePhaseText();

        if (inClearPhase && isBoardEmpty()) { levelComplete(); return; }

        var newMatches = findMatches();
        if (newMatches.length > 0) {
            processMatches(newMatches);
        } else if (countTiles() > 0 && !hasValidMoves()) {
            if (inClearPhase) {
                if (bombs > 0 || rowBombs > 0 || colorBombs > 0) {
                    showBanner("No moves! Use tools!");
                    busy = false;
                } else {
                    levelComplete();
                }
            } else {
                doShuffle();
            }
        } else {
            busy = false;
        }
    }

    function doShuffle() {
        var attempts = 0;
        do { shuffleBoard(); attempts++; removeInitialMatches(); } while (!hasValidMoves() && attempts < 100);
        rebuildAllQuads();
        comboText.content = "Shuffle!";
        comboText.alpha = 1;
        Tween.start(this, LINEAR, 1.5, 1, 0, function(v:Float, _:Float) { comboText.alpha = v; });
        assets.sound(Sounds.SWAP).play();
        busy = false;
    }

    function levelComplete() {
        busy = true;
        var tilesLeft = countTiles();
        var clearBonus = (ROWS * COLS - tilesLeft) * 5;
        var fullClear = tilesLeft == 0;
        score += clearBonus;
        updateScoreUI();
        assets.sound(Sounds.LEVELUP).play();

        var title = fullClear ? "PERFECT CLEAR!" : "Level " + level + " Done!";
        var sub = "Bonus: +" + clearBonus + "\n" + (fullClear ? "Amazing!" : tilesLeft + " tiles left") + "\nTap to continue";

        overlayVisible = true;
        overlayBg.touchable = true;
        overlayBg.alpha = 0;
        overlayText.content = title;
        overlayText.alpha = 0;
        overlaySubText.content = sub;
        overlaySubText.alpha = 0;

        Tween.start(this, QUAD_EASE_OUT, 0.3, 0, 0.8, function(v:Float, _:Float) { overlayBg.alpha = v; });
        Tween.start(this, QUAD_EASE_OUT, 0.3, 0, 1, function(v:Float, _:Float) {
            overlayText.alpha = v; overlaySubText.alpha = v;
        });

        // wait for tap to advance
        overlayBg.onPointerDown(this, function(_:TouchInfo) {
            overlayBg.offPointerDown(null);
            dismissOverlay();
            advanceLevel();
        });
    }

    function advanceLevel() {
        level++;
        inClearPhase = false;
        levelScore = 0;
        levelTarget = 300 * level;
        updateLevelUI();

        for (i in 0...ROWS * COLS) {
            grid[i] = 0;
            if (quads[i] != null) { quads[i].destroy(); quads[i] = null; }
        }
        fillEmptyCells();
        removeInitialMatches();
        rebuildAllQuads();
        updatePhaseText();
        busy = false;
    }
}
