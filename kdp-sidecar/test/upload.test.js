import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';

import { offlinePreflight, validateUploadJob } from '../upload-core.js';

function fixture() {
  const dir = mkdtempSync(path.join(tmpdir(), 'nf-kdp-'));
  const epubPath = path.join(dir, 'book.epub');
  const coverPath = path.join(dir, 'cover.jpg');
  writeFileSync(epubPath, Buffer.from([0x50, 0x4b, 0x03, 0x04, 0x00]));
  writeFileSync(coverPath, Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00]));
  return {
    dir,
    job: {
      title: 'Nacht ohne Ufer',
      author: 'Mara Winter',
      description: 'Ein vollständiger Verkaufstext.',
      keywords: ['Psychothriller', 'Nordsee'],
      categories: ['Thriller'],
      language: 'Deutsch',
      aiDisclosure: 'ai-generated',
      priceEUR: 3.99,
      epubPath,
      coverPath,
    },
  };
}

test('validiert einen vollständigen Uploadauftrag', () => {
  const { job } = fixture();
  assert.deepEqual(validateUploadJob(job), []);
  assert.equal(offlinePreflight(job).ok, true);
});

test('blockiert fehlende Dateien, falsche Endungen und ungültige Metadaten', () => {
  const { job } = fixture();
  job.title = ' ';
  job.priceEUR = 0;
  job.epubPath = '/nicht/vorhanden/book.pdf';
  job.coverPath = '/nicht/vorhanden/cover.txt';
  job.keywords = [];
  job.categories = [];
  job.aiDisclosure = 'vielleicht';
  const issues = validateUploadJob(job);
  for (const expected of ['Titel', 'EPUB', 'Cover', 'Preis', 'Keyword', 'Kategorie', 'KI-Offenlegung']) {
    assert.ok(issues.some((issue) => issue.includes(expected)), `${expected} muss beanstandet werden`);
  }
});

test('akzeptiert beim eBook-Cover nur die von KDP unterstützten Uploadformate', () => {
  const { dir, job } = fixture();
  const png = path.join(dir, 'cover.png');
  writeFileSync(png, 'png fixture');
  job.coverPath = png;
  assert.ok(validateUploadJob(job).some((issue) => issue.includes('Cover')));
});

test('blockiert nur umbenannte oder beschädigte EPUB- und Coverdateien', () => {
  const { job } = fixture();
  writeFileSync(job.epubPath, 'kein zip');
  writeFileSync(job.coverPath, 'kein jpeg');
  const issues = validateUploadJob(job);
  assert.ok(issues.some((issue) => issue.includes('EPUB')));
  assert.ok(issues.some((issue) => issue.includes('Cover')));
});

test('dry-run läuft vollständig offline und schreibt einen eindeutigen Status', () => {
  const { dir, job } = fixture();
  const jobPath = path.join(dir, 'job.json');
  const statusPath = path.join(dir, 'status.json');
  writeFileSync(jobPath, JSON.stringify(job));
  const run = spawnSync(process.execPath, [
    path.resolve('index.js'), 'upload', '--job', jobPath, '--status', statusPath,
    '--profile', '/absichtlich/nicht/vorhanden', '--chrome', '/absichtlich/nicht/vorhanden',
    '--dry-run',
  ], { cwd: path.resolve('.'), encoding: 'utf8' });
  assert.equal(run.status, 0, run.stdout + run.stderr);
  const status = JSON.parse(readFileSync(statusPath, 'utf8'));
  assert.equal(status.ok, true);
  assert.equal(status.offline, true);
  assert.equal(status.draftUrl, null);
  assert.deepEqual(status.probleme, []);
});
