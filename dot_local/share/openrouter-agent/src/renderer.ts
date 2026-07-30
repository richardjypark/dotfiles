import type { AgentEvent, ApprovalRequest } from './agent.js';

const RESET = '\x1b[0m';
const BOLD = '\x1b[1m';
const DIM = '\x1b[2m';
const CYAN = '\x1b[36m';
const GREEN = '\x1b[32m';
const YELLOW = '\x1b[33m';
const RED = '\x1b[31m';
const GRAY = '\x1b[90m';

function truncate(value: string, limit = 72): string {
  return value.length > limit ? `${value.slice(0, limit)}…` : value;
}

function visible(value: unknown): string {
  return JSON.stringify(String(value ?? ''));
}

function toolSummary(name: string, args: Record<string, unknown>): string {
  if (name === 'shell') return `command=${visible(args.command)}`;
  if (name === 'file_write') {
    return `path=${visible(args.path)} bytes=${Buffer.byteLength(String(args.content ?? ''))}`;
  }
  if (name === 'file_edit') {
    const edits = Array.isArray(args.edits) ? args.edits.length : 0;
    return `path=${visible(args.path)} edits=${edits}`;
  }
  const key = ['path', 'pattern', 'query'].find((candidate) => candidate in args);
  return key ? `${key}=${truncate(visible(args[key]))}` : '';
}

export class TuiRenderer {
  private lineBuffer = '';
  private streaming = false;
  private inCodeBlock = false;
  private readonly toolStarts = new Map<string, number>();

  handle(event: AgentEvent): void {
    if (event.type === 'text') this.text(event.delta);
    else if (event.type === 'reasoning') this.reasoning(event.delta);
    else if (event.type === 'tool_call') this.toolCall(event.name, event.callId, event.args);
    else this.toolResult(event.name, event.callId, event.output);
  }

  approval(request: ApprovalRequest): void {
    this.endTurn();
    console.log(`${YELLOW}${BOLD}Approval required${RESET}`);
    console.log(`  ${YELLOW}${request.name}${RESET} ${DIM}${toolSummary(request.name, request.arguments)}${RESET}`);
    console.log(`  ${DIM}The tool has not run. Approve this one call?${RESET}`);
  }

  private text(delta: string): void {
    this.streaming = true;
    this.lineBuffer += delta;
    const lines = this.lineBuffer.split('\n');
    this.lineBuffer = lines.pop() ?? '';
    for (const line of lines) process.stdout.write(`${this.markdown(line)}\n`);
  }

  private markdown(line: string): string {
    if (line.startsWith('```')) {
      this.inCodeBlock = !this.inCodeBlock;
      return `${DIM}${line}${RESET}`;
    }
    if (this.inCodeBlock) return `${DIM}${line}${RESET}`;
    if (/^#{1,3}\s/.test(line)) return `${BOLD}${line.replace(/^#+\s*/, '')}${RESET}`;
    return line
      .replace(/\*\*(.+?)\*\*/g, `${BOLD}$1${RESET}`)
      .replace(/`([^`]+)`/g, `${CYAN}$1${RESET}`);
  }

  private reasoning(delta: string): void {
    this.flushText();
    process.stdout.write(`${DIM}${delta}${RESET}`);
  }

  private toolCall(name: string, callId: string, args: Record<string, unknown>): void {
    this.endTurn();
    this.toolStarts.set(callId, Date.now());
    console.log(`  ${YELLOW}⚡${RESET} ${BOLD}${name}${RESET} ${DIM}${toolSummary(name, args)}${RESET}`);
  }

  private toolResult(name: string, callId: string, output: string): void {
    const elapsed = Date.now() - (this.toolStarts.get(callId) ?? Date.now());
    console.log(`  ${GREEN}✓${RESET} ${name} ${GRAY}(${(elapsed / 1000).toFixed(1)}s) ${truncate(output.replace(/\s+/g, ' '), 100)}${RESET}`);
  }

  private flushText(): void {
    if (this.lineBuffer) {
      process.stdout.write(this.markdown(this.lineBuffer));
      this.lineBuffer = '';
    }
  }

  endTurn(): void {
    if (!this.streaming && !this.lineBuffer) return;
    this.flushText();
    process.stdout.write(`${RESET}\n`);
    this.streaming = false;
    this.inCodeBlock = false;
  }

  error(error: unknown): void {
    this.endTurn();
    const message = error instanceof Error ? error.message : String(error);
    console.error(`${RED}Error:${RESET} ${message}`);
  }
}
