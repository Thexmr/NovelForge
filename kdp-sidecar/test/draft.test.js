import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { draftIdentity, DraftCheckpoint } from '../draft-core.js';

test('Entwurfsadressen brauchen eine echte Buch-ID und exakt den KDP-Host', () => {
  assert.equal(draftIdentity('https://kdp.amazon.com/de_DE/title-setup/kindle/A123/details').id, 'A123');
  for (const url of ['https://kdp.amazon.com/de_DE/bookshelf',
    'https://kdp.amazon.com/de_DE/title-setup/kindle/new/details',
    'https://kdp.amazon.com.evil.test/de_DE/title-setup/kindle/A123/details',
    'https://kdp.amazon.com/de_DE/title-setup/kindle/A123/details/extra']) {
    assert.equal(draftIdentity(url), null);
  }
});

test('bekannte Buch-ID ueberlebt Neustart und darf nicht durch eine andere ersetzt werden', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'nf-draft-test-'));
  try {
    const file = path.join(dir, 'checkpoint.json');
    const checkpoint = new DraftCheckpoint(file, 'kindle');
    assert.equal(checkpoint.resumeURL(), null);
    checkpoint.beginCreation();
    checkpoint.remember('https://kdp.amazon.com/de_DE/title-setup/kindle/A123/content');
    assert.match(new DraftCheckpoint(file, 'kindle').resumeURL(), /A123/);
    assert.throws(() => checkpoint.remember('https://kdp.amazon.com/de_DE/title-setup/kindle/B999/content'), /anderer/);
    assert.equal(fs.readdirSync(dir).length, 1);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test('ungewisser Abbruch waehrend Titelanlage erlaubt keinen zweiten neuen Entwurf', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'nf-draft-test-'));
  try {
    const file = path.join(dir, 'checkpoint.json');
    new DraftCheckpoint(file, 'kindle').beginCreation();
    assert.throws(() => new DraftCheckpoint(file, 'kindle').resumeURL(), /ungewiss/);
    fs.writeFileSync(file, '{broken');
    assert.throws(() => new DraftCheckpoint(file, 'kindle'), /unlesbar/);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});
