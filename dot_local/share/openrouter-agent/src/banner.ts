const RESET = '\x1b[0m';
const BOLD = '\x1b[1m';
const DIM = '\x1b[2m';
const CYAN = '\x1b[36m';
const YELLOW = '\x1b[33m';

export function printBanner(name: string, model: string, workspace: string): void {
  const width = Math.min(process.stdout.columns || 72, 72);
  const border = '─'.repeat(width);
  console.log(`\n${CYAN}${border}${RESET}`);
  console.log(`  ${BOLD}${name}${RESET}`);
  console.log(`  ${DIM}model${RESET}      ${model}`);
  console.log(`  ${DIM}workspace${RESET}  ${workspace}`);
  console.log(`  ${YELLOW}${BOLD}Paid OpenRouter mode — each model request may consume credits.${RESET}`);
  console.log(`${CYAN}${border}${RESET}`);
  console.log(`  ${DIM}/help for commands; risky local tools always pause for approval.${RESET}\n`);
}
