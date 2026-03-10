// A single candy piece on the board.
// type is an index into PackManager.candies.

class Candy extends h2d.Object {
    public static inline var CELL_SIZE = 80;

    // Total number of candy types — read from PackManager after init
    public static var numTypes(get, never): Int;
    static function get_numTypes() return PackManager.candies.length;

    public var type(default, null): Int;
    public var col: Int;
    public var row: Int;

    // tween targets
    var tweenX: Float;
    var tweenY: Float;
    var isTweenPos: Bool = false;

    var scaleTarget: Float = 1.0;
    var scaleCur: Float = 1.0;

    public function new(parent: h2d.Object, type: Int, col: Int, row: Int) {
        super(parent);
        this.type = type;
        this.col = col;
        this.row = row;

        var tile = PackManager.candies[type].tile;
        var bmp = new h2d.Bitmap(tile, this);
        bmp.x = (CELL_SIZE - tile.width) / 2;
        bmp.y = (CELL_SIZE - tile.height) / 2;

        snapToGrid();
    }

    public function snapToGrid() {
        x = col * CELL_SIZE;
        y = row * CELL_SIZE;
        tweenX = x;
        tweenY = y;
        isTweenPos = false;
    }

    public function tweenToGrid() {
        tweenX = col * CELL_SIZE;
        tweenY = row * CELL_SIZE;
        isTweenPos = true;
    }

    public function tweenToPos(tx: Float, ty: Float) {
        tweenX = tx;
        tweenY = ty;
        isTweenPos = true;
    }

    public function spawnAnim() {
        scaleCur = 0.0;
        scaleX = scaleY = 0.0;
        scaleTarget = 1.0;
    }

    public function popAnim() {
        scaleTarget = 0.0;
    }

    public function isPopped(): Bool {
        return scaleTarget == 0.0 && scaleCur < 0.05;
    }

    public function isTweening(): Bool {
        return isTweenPos || Math.abs(scaleTarget - scaleCur) > 0.02;
    }

    public function update(dt: Float) {
        if (isTweenPos) {
            var speed = 12.0;
            x += (tweenX - x) * dt * speed;
            y += (tweenY - y) * dt * speed;
            if (Math.abs(tweenX - x) < 0.5 && Math.abs(tweenY - y) < 0.5) {
                x = tweenX;
                y = tweenY;
                isTweenPos = false;
            }
        }

        scaleCur += (scaleTarget - scaleCur) * dt * 15.0;
        if (Math.abs(scaleTarget - scaleCur) < 0.01) scaleCur = scaleTarget;
        scaleX = scaleY = scaleCur;
    }
}
