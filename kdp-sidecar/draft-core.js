import fs from 'node:fs';

export function draftIdentity(raw) {
  try {
    const url = new URL(raw);
    const match = url.pathname.match(/^\/([a-z]{2}_[A-Z]{2})\/title-setup\/(kindle|paperback)\/([A-Za-z0-9_-]+)\/(details|content|pricing)\/?$/);
    if (url.protocol !== 'https:' || url.hostname !== 'kdp.amazon.com' || !match || match[3].toLowerCase() === 'new') return null;
    return { id: match[3], format: match[2], url: `${url.origin}/${match[1]}/title-setup/${match[2]}/${match[3]}/${match[4]}` };
  } catch { return null; }
}

export function writeJSONAtomic(file, data) {
  const temp = `${file}.${process.pid}.tmp`;
  try {
    fs.writeFileSync(temp, JSON.stringify(data, null, 2), { mode: 0o600 });
    fs.renameSync(temp, file);
  } finally {
    if (fs.existsSync(temp)) fs.unlinkSync(temp);
  }
}

export class DraftCheckpoint {
  constructor(file, format) {
    this.file = file;
    this.format = format;
    this.state = { version: 1, creationPending: false, draftURL: null };
    if (fs.existsSync(file)) {
      try {
        const saved = JSON.parse(fs.readFileSync(file, 'utf8'));
        if (saved.version !== 1 || typeof saved.creationPending !== 'boolean'
          || (saved.draftURL !== null && draftIdentity(saved.draftURL)?.format !== format)) throw Error();
        this.state = saved;
      } catch { throw new Error('KDP-Wiederaufnahmedatei unlesbar. Kein neuer Entwurf wird angelegt; bitte bestehenden Entwurf prüfen.'); }
    }
  }

  resumeURL() {
    if (this.state.creationPending && !this.state.draftURL) {
      throw new Error('Vorherige KDP-Titelanlage ungewiss. Bitte das Bücherregal prüfen und den bestehenden Entwurf zuordnen; kein doppelter Entwurf wird angelegt.');
    }
    return this.state.draftURL;
  }

  beginCreation() {
    this.state.creationPending = true;
    writeJSONAtomic(this.file, this.state);
  }

  remember(url) {
    const draft = draftIdentity(url);
    if (!draft || draft.format !== this.format) return;
    const previous = draftIdentity(this.state.draftURL);
    if (previous && previous.id !== draft.id) throw new Error('Ein anderer KDP-Entwurf wurde geöffnet. Vorgang aus Sicherheitsgründen angehalten.');
    this.state = { version: 1, creationPending: false, draftURL: draft.url };
    writeJSONAtomic(this.file, this.state);
  }
}

function visibleSaveMessages() {
  return [...document.querySelectorAll('[role="status"], [role="alert"], .a-alert-success')]
    .filter(el => el.getClientRects().length && getComputedStyle(el).visibility !== 'hidden')
    .map(el => (el.innerText || '').trim())
    .filter(text => text.length < 400
      && !/nicht|\bnot\b|error|fehler|unable|konnte/i.test(text)
      && /saved successfully|successfully saved|saved as (?:a )?draft|draft saved|changes saved|(?:entwurf|änderungen|angaben|daten).{0,40}gespeichert|erfolgreich gespeichert/i.test(text));
}

export async function saveDraftAndVerify(page, { timeoutMs = 30000 } = {}) {
  const draft = draftIdentity(page.url());
  if (!draft) throw new Error('Keine bestätigte KDP-Buch-ID vor dem Speichern.');
  const before = await page.evaluate(visibleSaveMessages);
  // Never fall back to Save and continue or a publish control.
  const button = await page.$('#save-announce, #save, button[data-action="save-draft"]');
  if (!button) throw new Error('Entwurf-Speichern-Knopf nicht gefunden. Speicherung nicht bestätigt.');
  const safe = await button.evaluate(el => {
    const control = el.closest('button, input, a') || el;
    const label = (control.innerText || control.value || control.getAttribute('aria-label') || '').trim();
    return !control.disabled && control.getAttribute('aria-disabled') !== 'true'
      && /^(?:save(?: as (?:a )?draft)?|speichern(?: als entwurf)?|als entwurf speichern)$/i.test(label);
  });
  if (!safe) throw new Error('Kein eindeutig sicherer Entwurf-Speichern-Knopf. Kein Veröffentlichen-Klick ausgeführt.');
  await button.click();
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (page.isClosed()) throw new Error('Fenster geschlossen; Speicherung nicht bestätigt.');
    const current = draftIdentity(page.url());
    if (current && (current.id !== draft.id || current.format !== draft.format)) {
      throw new Error('Buch-ID nach Speichern abweichend. Speicherung nicht bestätigt.');
    }
    const messages = await page.evaluate(visibleSaveMessages).catch(() => []);
    if (messages.some(text => !before.includes(text))) return draft.url;
    await new Promise(resolve => setTimeout(resolve, 200));
  }
  throw new Error('Amazon hat die Entwurf-Speicherung nicht bestätigt. Bestehender Entwurf bleibt zur Wiederaufnahme vorgemerkt.');
}
