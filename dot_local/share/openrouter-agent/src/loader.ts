const DIM = '\x1b[2m';
const RESET = '\x1b[0m';
const FRAMES = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];

export class Loader {
  private frame = 0;
  private timer: ReturnType<typeof setInterval> | undefined;

  start(text = 'Using paid OpenRouter credits'): void {
    if (!process.stdout.isTTY) return;
    this.timer = setInterval(() => {
      process.stdout.write(`\r${DIM}${FRAMES[this.frame++ % FRAMES.length]} ${text}${RESET}`);
    }, 80);
  }

  stop(): void {
    if (this.timer) clearInterval(this.timer);
    this.timer = undefined;
    if (process.stdout.isTTY) process.stdout.write('\r\x1b[K');
  }
}
