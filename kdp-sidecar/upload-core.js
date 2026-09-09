import fs from 'node:fs';
import path from 'node:path';

const supportedDisclosures = new Set(['ai-generated', 'ai-assisted', 'none']);
// KDP's current eBook marketing-cover upload accepts JPEG or TIFF.
const imageExtensions = new Set(['.jpg', '.jpeg', '.tif', '.tiff']);

function present(value) {
  return typeof value === 'string' && value.trim().length > 0;
}

function header(pathname, length = 4) {
  let descriptor;
  try {
    descriptor = fs.openSync(pathname, 'r');
    const bytes = Buffer.alloc(length);
    const count = fs.readSync(descriptor, bytes, 0, length, 0);
    return bytes.subarray(0, count);
  } catch (_) {
    return Buffer.alloc(0);
  } finally {
    if (descriptor !== undefined) fs.closeSync(descriptor);
  }
}

function isEPUB(pathname) {
  const bytes = header(pathname);
  return bytes.length >= 4 && bytes[0] === 0x50 && bytes[1] === 0x4b
    && bytes[2] === 0x03 && bytes[3] === 0x04;
}

function isCoverImage(pathname) {
  const bytes = header(pathname);
  const jpeg = bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
  const littleTIFF = bytes.length >= 4 && bytes[0] === 0x49 && bytes[1] === 0x49
    && bytes[2] === 0x2a && bytes[3] === 0x00;
  const bigTIFF = bytes.length >= 4 && bytes[0] === 0x4d && bytes[1] === 0x4d
    && bytes[2] === 0x00 && bytes[3] === 0x2a;
  return jpeg || littleTIFF || bigTIFF;
}

export function validateUploadJob(job, { fileExists = fs.existsSync } = {}) {
  const issues = [];
  if (!present(job?.title)) issues.push('Titel fehlt.');
  if (!present(job?.author)) issues.push('Autor fehlt.');
  if (!present(job?.description)) issues.push('Beschreibung fehlt.');

  const epubPath = present(job?.epubPath) ? job.epubPath : '';
  if (path.extname(epubPath).toLowerCase() !== '.epub' || !fileExists(epubPath)
      || !isEPUB(epubPath)) {
    issues.push('EPUB fehlt, ist nicht lesbar oder hat die falsche Dateiendung.');
  }
  const coverPath = present(job?.coverPath) ? job.coverPath : '';
  if (!imageExtensions.has(path.extname(coverPath).toLowerCase()) || !fileExists(coverPath)
      || !isCoverImage(coverPath)) {
    issues.push('Cover fehlt, ist nicht lesbar oder hat kein unterstütztes Bildformat.');
  }

  const price = Number(job?.priceEUR);
  if (!Number.isFinite(price) || price <= 0) issues.push('Preis muss größer als 0 sein.');
  if (!Array.isArray(job?.keywords) || job.keywords.length < 1 || job.keywords.length > 7
      || job.keywords.some((value) => !present(value))) {
    issues.push('Keywords müssen 1 bis 7 ausgefüllte Einträge enthalten.');
  }
  if (!Array.isArray(job?.categories) || job.categories.length < 1 || job.categories.length > 3
      || job.categories.some((value) => !present(value))) {
    issues.push('Kategorien müssen 1 bis 3 ausgefüllte Einträge enthalten.');
  }
  if (!supportedDisclosures.has(job?.aiDisclosure)) {
    issues.push('KI-Offenlegung muss ai-generated, ai-assisted oder none sein.');
  }
  return issues;
}

export function offlinePreflight(job, options) {
  const probleme = validateUploadJob(job, options);
  return {
    stage: probleme.length ? 'error' : 'done',
    progress: 1,
    ok: probleme.length === 0,
    offline: true,
    draftUrl: null,
    probleme,
    error: probleme.length ? probleme.join(' ') : null,
    message: probleme.length
      ? 'Offline-Prüfung fehlgeschlagen: ' + probleme.join(' · ')
      : 'Offline-Prüfung bestanden – kein Browser geöffnet, nichts zu KDP übertragen.',
  };
}
