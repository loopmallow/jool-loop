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
    static inline var OFFSET_X = 8;
    static inline var OFFSET_Y = 40;
    static inline var SWAP_DUR = 0.15;
    static inline var REMOVE_DUR = 0.2;
    static inline var DROP_DUR = 0.1;

    var pixelArt:PixelArt;

    var grid:Array<Int> = [];       // color 1-6, 0 = empty
    var quads:Array<Quad> = [];

    var selected:Int = -1;
    var selectionQuad:Quad;
    var scoreText:Text;
    var comboText:Text;
    var score:Int = 0;
    var combo:Int = 0;
    var busy:Bool = false;

    override function preload() {
        assets.add(Images.JOOLS);
        assets.add(Sounds.SWAP);
        assets.add(Sounds.MATCH);
        assets.add(Sounds.DROP);
        assets.add(Sounds.INVALID);
    }

    override function create() {
        pixelArt = cast app.scenes.filter;

        scoreText = new Text();
        scoreText.content = "Score: 0";
        scoreText.color = Color.WHITE;
        scoreText.pos(OFFSET_X, 4);
        add(scoreText);

        comboText = new Text();
        comboText.content = "";
        comboText.color = Color.YELLOW;
        comboText.pos(200, 4);
        comboText.alpha = 0;
        comboText.depth = 10;
        add(comboText);

        selectionQuad = new Quad();
        selectionQuad.size(TILE_SIZE + 4, TILE_SIZE + 4);
        selectionQuad.color = Color.YELLOW;
        selectionQuad.visible = false;
        selectionQuad.depth = 0;
        add(selectionQuad);

        for (i in 0...ROWS * COLS) {
            grid.push(0);
            quads.push(null);
        }
        fillEmptyCells();
        removeInitialMatches();
        rebuildAllQuads();
    }

    // -- Grid helpers --

    inline function idx(col:Int, row:Int):Int return row * COLS + col;
    inline function colOf(i:Int):Int return i % COLS;
    inline function rowOf(i:Int):Int return Std.int(i / COLS);
    inline function tileX(col:Int):Float return OFFSET_X + col * TILE_SIZE;
    inline function tileY(row:Int):Float return OFFSET_Y + row * TILE_SIZE;

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

    // Check if swapping (c1,r1) with (c2,r2) would create a match
    function swapCreatesMatch(c1:Int, r1:Int, c2:Int, r2:Int):Bool {
        // temporarily swap
        var i1 = idx(c1, r1);
        var i2 = idx(c2, r2);
        var tmp = grid[i1]; grid[i1] = grid[i2]; grid[i2] = tmp;
        var matches = findMatches();
        // swap back
        var tmp2 = grid[i1]; grid[i1] = grid[i2]; grid[i2] = tmp2;
        return matches.length > 0;
    }

    function hasValidMoves():Bool {
        for (r in 0...ROWS) for (c in 0...COLS) {
            if (grid[idx(c, r)] == 0) continue;
            // check right neighbor
            if (c + 1 < COLS && grid[idx(c + 1, r)] != 0) {
                if (swapCreatesMatch(c, r, c + 1, r)) return true;
            }
            // check down neighbor
            if (r + 1 < ROWS && grid[idx(c, r + 1)] != 0) {
                if (swapCreatesMatch(c, r, c, r + 1)) return true;
            }
        }
        return false;
    }

    function shuffleBoard() {
        // Fisher-Yates shuffle of grid colors
        var n = ROWS * COLS;
        for (i in 0...n - 1) {
            var j = i + Std.random(n - i);
            var tmp = grid[i]; grid[i] = grid[j]; grid[j] = tmp;
        }
    }

    // returns map of destination index -> number of rows dropped, plus fills empty top cells
    function applyGravityAndRefill():Map<Int, Int> {
        var drops = new Map<Int, Int>();

        for (c in 0...COLS) {
            // compact down
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
            // fill empty cells at top with new random tiles
            var emptyCount = writeRow + 1;
            var row = writeRow;
            while (row >= 0) {
                grid[idx(c, row)] = randomColor();
                // new tiles "drop from above": distance = emptyCount (from off-screen)
                drops.set(idx(c, row), emptyCount);
                row--;
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

    function showCombo(c:Int) {
        if (c > 1) {
            comboText.content = "x" + c + " Combo!";
            comboText.alpha = 1;
            Tween.start(this, LINEAR, 1.0, 1, 0, function(v:Float, _:Float) {
                comboText.alpha = v;
            });
        }
    }

    // -- Input --

    function onTileClicked(i:Int) {
        if (busy) return;
        if (grid[i] == 0) return;

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
        var qa = quads[a];
        var qb = quads[b];
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
        var done1 = false;
        var done2 = false;
        var checkDone = function() { if (done1 && done2 && onDone != null) onDone(); };

        if (q1 != null) {
            var tw = Tween.start(this, QUAD_EASE_IN_OUT, SWAP_DUR, 0, 1, function(t:Float, _:Float) {
                q1.pos(x1From + (x1To - x1From) * t, y1From + (y1To - y1From) * t);
            });
            tw.onceComplete(this, function() { done1 = true; checkDone(); });
        } else { done1 = true; checkDone(); }

        if (q2 != null) {
            var tw2 = Tween.start(this, QUAD_EASE_IN_OUT, SWAP_DUR, 0, 1, function(t:Float, _:Float) {
                q2.pos(x2From + (x2To - x2From) * t, y2From + (y2To - y2From) * t);
            });
            tw2.onceComplete(this, function() { done2 = true; checkDone(); });
        } else { done2 = true; checkDone(); }
    }

    // -- Match removal with animation --

    function processMatches(matches:Array<Int>) {
        combo++;
        var points = matches.length * 10 * combo;
        score += points;
        scoreText.content = "Score: " + score;
        showCombo(combo);
        assets.sound(Sounds.MATCH).play();

        for (i in matches) grid[i] = 0;

        var remaining = matches.length;
        for (i in matches) {
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

    function afterRemoval() {
        var drops = applyGravityAndRefill();

        // destroy all quads and recreate
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
                    var tw = Tween.start(this, BOUNCE_EASE_OUT, dur, 0, 1, function(t:Float, _:Float) {
                        capturedQ.y = startY + (capturedFinalY - startY) * t;
                    });
                    tw.onceComplete(this, function() {
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
        var newMatches = findMatches();
        if (newMatches.length > 0) {
            processMatches(newMatches);
        } else {
            // check for valid moves
            if (!hasValidMoves()) {
                doShuffle();
            } else {
                busy = false;
            }
        }
    }

    function doShuffle() {
        // shuffle until we have moves and no immediate matches
        var attempts = 0;
        do {
            shuffleBoard();
            attempts++;
            // if shuffle creates matches, remove them by re-rolling
            removeInitialMatches();
        } while (!hasValidMoves() && attempts < 100);

        rebuildAllQuads();

        // brief flash to indicate shuffle
        comboText.content = "Shuffle!";
        comboText.alpha = 1;
        Tween.start(this, LINEAR, 1.5, 1, 0, function(v:Float, _:Float) {
            comboText.alpha = v;
        });
        assets.sound(Sounds.SWAP).play();

        busy = false;
    }
}
