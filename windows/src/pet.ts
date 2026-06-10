// Renders + animates a pet spritesheet on a canvas. Sheets are an 8x9 grid:
// 8 animation frames per row, 9 rows (one per state). We pick the row by the
// pet's current state and loop the 8 frames. drawImage of a sub-rectangle , no
// pixel reads , so cross-origin CDN images work without tainting.

const COLS = 8;
const ROWS = 9;

// Row index per state, matching the macOS app's spritesheet layout:
// 0 Idle, 1 RunRight, 2 RunLeft, 3 Waving, 4 Jumping, 5 Failed, 6 Waiting, 7 Running, 8 Review
const STATE_ROW: Record<string, number> = {
  idle: 0,
  registered: 0,
  working: 7,
  waiting: 6,
  done: 4,
};

export class Pet {
  private ctx: CanvasRenderingContext2D;
  private img = new Image();
  private loaded = false;
  private frame = 0;
  private row = 0;
  private lastTick = 0;
  private readonly fps = 8;

  constructor(private canvas: HTMLCanvasElement) {
    const c = canvas.getContext("2d");
    if (!c) throw new Error("no 2d context");
    this.ctx = c;
    this.ctx.imageSmoothingEnabled = false;
    this.img.onload = () => { this.loaded = true; };
    requestAnimationFrame((t) => this.loop(t));
  }

  load(spritesheetUrl: string) {
    this.loaded = false;
    this.img.src = spritesheetUrl;
  }

  setState(state: string) {
    const row = STATE_ROW[state] ?? 0;
    if (row !== this.row) { this.row = row; this.frame = 0; }
  }

  private loop(t: number) {
    if (this.loaded && t - this.lastTick > 1000 / this.fps) {
      this.lastTick = t;
      this.frame = (this.frame + 1) % COLS;
      this.draw();
    }
    requestAnimationFrame((n) => this.loop(n));
  }

  private draw() {
    const { width: W, height: H } = this.canvas;
    this.ctx.clearRect(0, 0, W, H);
    const fw = this.img.naturalWidth / COLS;
    const fh = this.img.naturalHeight / ROWS;
    if (!fw || !fh) return;
    // Fit the frame into the canvas, anchored to the bottom. Snap to an integer
    // scale so pixel-art stays crisp (no shimmering edges from fractional zoom).
    const fit = Math.min(W / fw, H / fh);
    const s = fit >= 1 ? Math.floor(fit) : fit;
    const dw = fw * s, dh = fh * s;
    this.ctx.drawImage(
      this.img,
      this.frame * fw, this.row * fh, fw, fh,
      (W - dw) / 2, H - dh, dw, dh
    );
  }
}
