@:expose
class Main extends hxd.App {
    static inline var WIN_WIDTH  = 720;
    static inline var WIN_HEIGHT = 1280;

    var board: Board;

    override function loadAssets(onDone: Void -> Void) {
        PackManager.load(onDone);
    }

    override function init() {
        s2d.scaleMode = h2d.ScaleMode.LetterBox(WIN_WIDTH, WIN_HEIGHT);

        var bg = new h2d.Graphics(s2d);
        bg.beginFill(0x1a0d2e);
        bg.drawRect(0, 0, WIN_WIDTH, WIN_HEIGHT);
        bg.endFill();

        var font = hxd.res.DefaultFont.get().clone();
        var title = new h2d.Text(font, s2d);
        title.scaleX = title.scaleY = 3;
        title.text = "JOOL LOOP";
        title.textAlign = h2d.Text.Align.Center;
        title.x = WIN_WIDTH / 2;
        title.y = 30;

        board = new Board(s2d);
        board.x = (WIN_WIDTH - Board.COLS * Candy.CELL_SIZE) / 2;
        board.y = 120;
    }

    override function update(dt: Float) {
        board.update(dt);
    }

    static function main() {
        new Main();
    }
}
