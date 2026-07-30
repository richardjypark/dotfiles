import { createInterface } from 'node:readline/promises';

const RESET = '\x1b[0m';
const WHITE = '\x1b[97m';
const GRAY = '\x1b[90m';
const BG = '\x1b[48;5;235m';

export const SLASH_COMMANDS = [
  '/help',
  '/new',
  '/save',
  '/resume',
  '/sessions',
  '/model',
  '/cost',
  '/clear',
  '/exit',
] as const;

async function plainQuestion(prompt: string): Promise<string> {
  const reader = createInterface({ input: process.stdin, output: process.stdout });
  try {
    return await reader.question(prompt);
  } finally {
    reader.close();
  }
}

export async function readYesNo(prompt = '  Approve? [y/N] '): Promise<boolean> {
  if (!process.stdin.isTTY || typeof process.stdin.setRawMode !== 'function') {
    return /^(?:y|yes)$/i.test((await plainQuestion(prompt)).trim());
  }
  process.stdout.write(prompt);
  process.stdin.setRawMode(true);
  process.stdin.resume();
  try {
    return await new Promise<boolean>((resolve) => {
      const onData = (data: Buffer) => {
        const value = data.toString('utf8').toLowerCase();
        process.stdin.off('data', onData);
        process.stdout.write(`${value.startsWith('y') ? 'yes' : 'no'}\n`);
        resolve(value.startsWith('y'));
      };
      process.stdin.on('data', onData);
    });
  } finally {
    process.stdin.setRawMode(false);
    process.stdin.pause();
  }
}

export async function readBlockInput(history: string[]): Promise<string> {
  if (!process.stdin.isTTY || typeof process.stdin.setRawMode !== 'function') {
    return plainQuestion('> ');
  }

  return new Promise<string>((resolve) => {
    let line = '';
    let historyIndex = history.length;
    let completionIndex = 0;
    const width = Math.max(20, process.stdout.columns || 80);
    const border = `${GRAY}${'─'.repeat(width)}${RESET}`;

    const draw = (first = false) => {
      if (first) {
        process.stdout.write(`\n${border}\n${BG}\x1b[K ${WHITE}› ${line}${RESET}\n${border}\x1b[1A\r`);
      } else {
        process.stdout.write(`\r\x1b[2K${BG}\x1b[K ${WHITE}› ${line}${RESET}`);
      }
    };

    const finish = () => {
      process.stdin.off('data', onData);
      process.stdin.setRawMode(false);
      process.stdin.pause();
      process.stdout.write(`\n${border}\n`);
      resolve(line);
    };

    const onData = (data: Buffer) => {
      const value = data.toString('utf8');
      if (value === '\r' || value === '\n') return finish();
      if (value === '\u0003') {
        line = '/exit';
        return finish();
      }
      if (value === '\u007f' || value === '\b') {
        line = line.slice(0, -1);
        return draw();
      }
      if (value === '\x1b[A') {
        if (historyIndex > 0) historyIndex -= 1;
        line = history[historyIndex] ?? '';
        return draw();
      }
      if (value === '\x1b[B') {
        if (historyIndex < history.length) historyIndex += 1;
        line = history[historyIndex] ?? '';
        return draw();
      }
      if (value === '\t' && line.startsWith('/')) {
        const matches = SLASH_COMMANDS.filter((command) => command.startsWith(line.split(/\s/)[0]));
        if (matches.length > 0) {
          line = matches[completionIndex % matches.length] ?? line;
          completionIndex += 1;
          draw();
        }
        return;
      }
      if (!value.startsWith('\x1b')) {
        for (const character of value) {
          if (character.charCodeAt(0) >= 32) line += character;
        }
        historyIndex = history.length;
        completionIndex = 0;
        draw();
      }
    };

    draw(true);
    process.stdin.setRawMode(true);
    process.stdin.resume();
    process.stdin.on('data', onData);
  });
}
