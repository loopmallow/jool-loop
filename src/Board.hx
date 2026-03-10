enum State {
    Idle;
    Selected;
    Swapping;
    SwapBack;
    Removing;
    Falling;
}

class Board extends h2d.Object {
    public static inline var COLS = 8;
    public static inline var ROWS = 8;

    var grid: Array<Array<Null<Candy>>>;
    var state: State = Idle;

    var selCol: Int = -1;
    var selRow: Int = -1;
    var selHighlight: h2d.Graphics;

    var swapA: Candy;
    var swapB: Candy;
    var toRemove: Array<Candy> = [];

    public var score(default, null): Int = 0;
    var scoreTf: h2d.Text;

    var candyLayer: h2d.Object;

    public function new(parent: h2d.Object) {
        super(parent);

        // Checkerboard background
        var bg = new h2d.Graphics(this);
        for (r in 0...ROWS) {
            for (c in 0...COLS) {
                bg.beginFill((c + r) % 2 == 0 ? 0x3b2a55 : 0x2e2048);
                bg.drawRect(c * Candy.CELL_SIZE + 2, r * Candy.CELL_SIZE + 2,
                    Candy.CELL_SIZE - 4, Candy.CELL_SIZE - 4);
                bg.endFill();
            }
        }

        candyLayer = new h2d.Object(this);

        selHighlight = new h2d.Graphics(this);
        selHighlight.visible = false;

        var font = hxd.res.DefaultFont.get().clone();

        var lbl = new h2d.Text(font, this);
        lbl.scaleX = lbl.scaleY = 2;
        lbl.text = "SCORE";
        lbl.x = 4;
        lbl.y = ROWS * Candy.CELL_SIZE + 8;

        scoreTf = new h2d.Text(font, this);
        scoreTf.scaleX = scoreTf.scaleY = 3;
        scoreTf.text = "0";
        scoreTf.x = 4;
        scoreTf.y = ROWS * Candy.CELL_SIZE + 30;

        grid = [for (_ in 0...COLS) [for (_ in 0...ROWS) null]];
        fillBoard();

        var hit = new h2d.Interactive(COLS * Candy.CELL_SIZE, ROWS * Candy.CELL_SIZE, this);
        hit.onClick = onClick;
    }

    function fillBoard() {
        for (c in 0...COLS) {
            for (r in 0...ROWS) {
                var type = safeRandom(c, r);
                var candy = new Candy(candyLayer, type, c, r);
                candy.spawnAnim();
                grid[c][r] = candy;
            }
        }
    }

    function safeRandom(c: Int, r: Int): Int {
        for (_ in 0...30) {
            var t = Std.random(Candy.numTypes);
            if (!wouldMatch(c, r, t)) return t;
        }
        return Std.random(Candy.numTypes);
    }

    function wouldMatch(c: Int, r: Int, t: Int): Bool {
        if (c >= 2 && grid[c-1][r] != null && grid[c-1][r].type == t
                   && grid[c-2][r] != null && grid[c-2][r].type == t) return true;
        if (r >= 2 && grid[c][r-1] != null && grid[c][r-1].type == t
                   && grid[c][r-2] != null && grid[c][r-2].type == t) return true;
        return false;
    }

    function onClick(e: hxd.Event) {
        if (state != Idle && state != Selected) return;
        var c = Std.int(e.relX / Candy.CELL_SIZE);
        var r = Std.int(e.relY / Candy.CELL_SIZE);
        if (c < 0 || c >= COLS || r < 0 || r >= ROWS || grid[c][r] == null) return;

        if (state == Idle) {
            select(c, r);
        } else {
            if (c == selCol && r == selRow) {
                deselect();
            } else if (isAdj(selCol, selRow, c, r)) {
                doSwap(selCol, selRow, c, r);
            } else {
                select(c, r);
            }
        }
    }

    function select(c: Int, r: Int) {
        selCol = c; selRow = r;
        state = Selected;
        selHighlight.clear();
        selHighlight.lineStyle(4, 0xFFFFFF);
        selHighlight.drawRect(c * Candy.CELL_SIZE + 3, r * Candy.CELL_SIZE + 3,
            Candy.CELL_SIZE - 6, Candy.CELL_SIZE - 6);
        selHighlight.visible = true;
    }

    function deselect() {
        selCol = selRow = -1;
        state = Idle;
        selHighlight.visible = false;
    }

    function isAdj(ac: Int, ar: Int, bc: Int, br: Int): Bool {
        return Math.abs(ac - bc) + Math.abs(ar - br) == 1;
    }

    function doSwap(ac: Int, ar: Int, bc: Int, br: Int) {
        selHighlight.visible = false;
        state = Swapping;
        swapA = grid[ac][ar];
        swapB = grid[bc][br];
        grid[ac][ar] = swapB; grid[bc][br] = swapA;
        swapA.col = bc; swapA.row = br;
        swapB.col = ac; swapB.row = ar;
        swapA.tweenToGrid();
        swapB.tweenToGrid();
    }

    function findMatches(): Array<Candy> {
        var found = new Map<Candy, Bool>();

        // horizontal
        for (r in 0...ROWS) {
            var run = 1;
            for (c in 1...COLS) {
                var a = grid[c-1][r]; var b = grid[c][r];
                if (a != null && b != null && a.type == b.type) {
                    run++;
                } else {
                    if (run >= 3) for (k in (c-run)...c) if (grid[k][r] != null) found[grid[k][r]] = true;
                    run = 1;
                }
            }
            if (run >= 3) for (k in (COLS-run)...COLS) if (grid[k][r] != null) found[grid[k][r]] = true;
        }

        // vertical
        for (c in 0...COLS) {
            var run = 1;
            for (r in 1...ROWS) {
                var a = grid[c][r-1]; var b = grid[c][r];
                if (a != null && b != null && a.type == b.type) {
                    run++;
                } else {
                    if (run >= 3) for (k in (r-run)...r) if (grid[c][k] != null) found[grid[c][k]] = true;
                    run = 1;
                }
            }
            if (run >= 3) for (k in (ROWS-run)...ROWS) if (grid[c][k] != null) found[grid[c][k]] = true;
        }

        return [for (c in found.keys()) c];
    }

    function gravity() {
        for (c in 0...COLS) {
            var write = ROWS - 1;
            var read  = ROWS - 1;
            while (read >= 0) {
                if (grid[c][read] != null) {
                    if (write != read) {
                        var candy = grid[c][read];
                        grid[c][write] = candy;
                        grid[c][read] = null;
                        candy.row = write;
                        candy.tweenToGrid();
                    }
                    write--;
                }
                read--;
            }
        }
    }

    function refill() {
        for (c in 0...COLS) {
            var offset = -1;
            for (r in 0...ROWS) {
                if (grid[c][r] == null) {
                    var candy = new Candy(candyLayer, Std.random(Candy.numTypes), c, r);
                    candy.x = c * Candy.CELL_SIZE;
                    candy.y = offset * Candy.CELL_SIZE;
                    candy.tweenToGrid();
                    grid[c][r] = candy;
                    offset--;
                }
            }
        }
    }

    public function update(dt: Float) {
        for (c in 0...COLS) for (r in 0...ROWS) if (grid[c][r] != null) grid[c][r].update(dt);

        switch (state) {
            case Swapping:
                if (!swapA.isTweening() && !swapB.isTweening()) {
                    var matches = findMatches();
                    if (matches.length > 0) {
                        startRemove(matches);
                    } else {
                        state = SwapBack;
                        var tc = swapA.col; var tr = swapA.row;
                        grid[swapA.col][swapA.row] = swapB;
                        grid[swapB.col][swapB.row] = swapA;
                        swapA.col = swapB.col; swapA.row = swapB.row;
                        swapB.col = tc;       swapB.row = tr;
                        swapA.tweenToGrid(); swapB.tweenToGrid();
                    }
                }

            case SwapBack:
                if (!swapA.isTweening() && !swapB.isTweening()) state = Idle;

            case Removing:
                if (toRemove.filter(c -> !c.isPopped()).length == 0) {
                    score += toRemove.length * PackManager.matchScore;
                    scoreTf.text = Std.string(score);
                    for (c in toRemove) { grid[c.col][c.row] = null; c.remove(); }
                    toRemove = [];
                    gravity();
                    refill();
                    state = Falling;
                }

            case Falling:
                var anyMoving = false;
                for (c in 0...COLS) for (r in 0...ROWS)
                    if (grid[c][r] != null && grid[c][r].isTweening()) { anyMoving = true; break; }
                if (!anyMoving) {
                    var matches = findMatches();
                    if (matches.length > 0) startRemove(matches) else state = Idle;
                }

            default:
        }
    }

    function startRemove(matches: Array<Candy>) {
        toRemove = matches;
        state = Removing;
        for (c in toRemove) c.popAnim();
    }
}
