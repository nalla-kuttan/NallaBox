import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const root = new URL('../../', import.meta.url);
const pairs = ['tokens.css', 'base.css', 'components.css', 'fonts/nunito-wght.woff2', 'img/nallabox-symbol-color.svg'];

test('controller shared files are byte copies of the mockup shared files', () => {
  for (const f of pairs) {
    const a = readFileSync(new URL(`app/Resources/Controller/shared/${f}`, root));
    const b = readFileSync(new URL(`design/mockups/shared/${f}`, root));
    assert.ok(a.equals(b), `${f} differs from design/mockups/shared/${f}`);
  }
});
