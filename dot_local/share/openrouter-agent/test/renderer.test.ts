import assert from 'node:assert/strict';
import test from 'node:test';

import { TuiRenderer } from '../src/renderer.js';

test('approval renders the complete shell command with control characters escaped', () => {
  const command = `printf safe-${'x'.repeat(100)}\rfinal-visible-marker`;
  const originalLog = console.log;
  const output: string[] = [];
  console.log = (...values: unknown[]) => {
    output.push(values.map(String).join(' '));
  };
  try {
    new TuiRenderer().approval({
      id: 'approval-test',
      name: 'shell',
      arguments: { command },
    });
  } finally {
    console.log = originalLog;
  }

  const rendered = output.join('\n');
  assert.match(rendered, /final-visible-marker/);
  assert.match(rendered, /\\rfinal-visible-marker/);
  assert.doesNotMatch(rendered, /\r/);
});
