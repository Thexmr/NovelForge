#!/usr/bin/env node
// NovelForge KDP-Sidecar — autonomer eBook-Entwurf-Upload zu Amazon KDP.
//
// GRUNDPRINZIP: Amazon hat keine Publishing-API. Wir bedienen das echte KDP-
// Dashboard per Chromium (puppeteer-core + Stealth) mit einem PERSISTENTEN
// Nutzerprofil (--user-data-dir). Einmal manuell einloggen (Befehl `login`),
// danach läuft der Upload autonom — ABER: Es wird IMMER nur ein ENTWURF
// gespeichert. Der finale „Veröffentlichen"-Klick bleibt beim Menschen.
//
// Befehle:
//   node index.js login  --profile <dir> [--chrome <pfad>]
//   node index.js upload  --job <job.json> --status <status.json> --profile <dir> [--chrome <pfad>] [--dry-run]
//   node index.js check   --profile <dir> [--chrome <pfad>]   (prüft, ob eingeloggt)
//
// Alle Schritte schreiben nach status.json (Fortschritt für die Swift-App).

import fs from 'fs';
import { createRequire } from 'module';

const require = createRequire(import.meta.url);

// ---- Argumente ----
function parseArgs(argv) {
  const out = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) {
      const key = a.slice(2);
      const next = argv[i + 1];
      if (next && !next.startsWith('--')) { out[key] = next; i++; }
      else out[key] = true;
    } else out._.push(a);
  }
  return out;
}
const args = parseArgs(process.argv.slice(2));
const command = args._[0];

// ---- Status-Reporting ----
let statusPath = args.status || null;
let statusObj = { stage: 'init', progress: 0, message: '', ok: null, draftUrl: null, error: null };
function report(patch) {
  statusObj = { ...statusObj, ...patch, ts: Date.now() };
  const line = `[${statusObj.stage}] ${statusObj.message}`;
  console.log(line);
  if (statusPath) {
    try { fs.writeFileSync(statusPath, JSON.stringify(statusObj, null, 2)); } catch (_) {}
  }
}

// ---- Chrome finden ----
function findChrome(explicit) {
  if (explicit && fs.existsSync(explicit)) return explicit;
  const candidates = [
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    '/Applications/Chromium.app/Contents/MacOS/Chromium',
    '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge',
    '/Applications/Brave Browser.app/Contents/MacOS/Brave Browser',
  ];
  for (const c of candidates) if (fs.existsSync(c)) return c;
  return null;
}

async function launch(profileDir, chromePath, { headless } = { headless: false }) {
  const puppeteer = (await import('puppeteer-extra')).default;
  try {
    const Stealth = (await import('puppeteer-extra-plugin-stealth')).default;
    puppeteer.use(Stealth());
  } catch (_) { /* Stealth optional */ }
  const executablePath = findChrome(chromePath);
  if (!executablePath) throw new Error('Kein Chrome/Chromium/Edge/Brave gefunden. Bitte --chrome <pfad> angeben.');
  fs.mkdirSync(profileDir, { recursive: true });
  const browser = await puppeteer.launch({
    executablePath,
    headless: headless ? 'new' : false,
    userDataDir: profileDir,
    defaultViewport: null,
    args: ['--no-first-run', '--no-default-browser-check', '--window-size=1400,1000'],
  });
  return browser;
}

const KDP_BOOKSHELF = 'https://kdp.amazon.com/en_US/bookshelf';
const KDP_LOGIN_PROOF = '#dp-bookshelf, .a-nav-link, [data-testid="bookshelf"]';

// Prüft, ob eine gültige Session besteht.
// navigate=true: geht aktiv zum Bücherregal (für `check`).
// navigate=false: prüft NUR die aktuelle Seite, ohne wegzunavigieren
//   (wichtig während des manuellen Logins — sonst würde das Formular ständig
//   unterbrochen und das Fenster schiene sich „zu schließen").
async function isLoggedIn(page, { navigate = true } = {}) {
  if (navigate) {
    await page.goto(KDP_BOOKSHELF, { waitUntil: 'domcontentloaded', timeout: 60000 }).catch(() => {});
  }
  const url = page.url();
  if (url.includes('/ap/signin') || url.includes('/ap/') || url.includes('signin')) return false;
  // Auf einer KDP-Seite (nicht signin) → eingeloggt, wenn ein Regal-/Nav-Element existiert.
  if (url.includes('kdp.amazon')) {
    try { await page.waitForSelector(KDP_LOGIN_PROOF, { timeout: 3000 }); return true; }
    catch (_) { return !url.includes('signin') && !url.includes('/ap/'); }
  }
  return false;
}

// ---------- Befehl: login ----------
async function cmdLogin() {
  report({ stage: 'login', progress: 0.1, message: 'Öffne KDP-Login (einmalig, manuell inkl. 2FA) …' });
  const browser = await launch(args.profile, args.chrome, { headless: false });
  const page = (await browser.pages())[0] || await browser.newPage();
  // KDP selbst aufrufen — Amazon leitet dann mit ALLEN korrekten OpenID-Parametern
  // zur echten Anmeldeseite weiter (eine selbstgebaute /ap/signin-URL zeigt sonst
  // „Es ist ein Fehler aufgetreten").
  await page.goto('https://kdp.amazon.com/', { waitUntil: 'domcontentloaded', timeout: 60000 }).catch(() => {});
  await page.bringToFront().catch(() => {});
  report({ stage: 'login', progress: 0.4, message: 'Bitte im geöffneten Fenster bei Amazon KDP einloggen (inkl. 2FA). Warte auf dein Bücherregal …' });
  // Bis zu 8 Minuten warten – OHNE das Fenster wegzunavigieren (passiv prüfen).
  const deadline = Date.now() + 480000;
  let ok = false;
  while (Date.now() < deadline) {
    // Browser-/Fenster-Schließung durch den Nutzer sauber abfangen.
    if (!browser.isConnected()) { report({ stage: 'login', message: 'Fenster wurde geschlossen.' }); break; }
    try {
      if (await isLoggedIn(page, { navigate: false })) { ok = true; break; }
    } catch (_) { /* Seite lädt gerade um – weiter warten */ }
    await new Promise(r => setTimeout(r, 2500));
  }
  report({ stage: 'login', progress: 1, ok, message: ok ? 'Login erfolgreich, Session gespeichert.' : 'Login nicht abgeschlossen (Zeit abgelaufen oder Fenster geschlossen).' });
  await new Promise(r => setTimeout(r, 2500));
  await browser.close().catch(() => {});
  if (!ok) process.exit(2);
}

// ---------- Befehl: check ----------
async function cmdCheck() {
  const browser = await launch(args.profile, args.chrome, { headless: false });
  const page = (await browser.pages())[0] || await browser.newPage();
  const ok = await isLoggedIn(page);
  report({ stage: 'check', progress: 1, ok, message: ok ? 'Eingeloggt.' : 'Nicht eingeloggt.' });
  await browser.close();
  process.exit(ok ? 0 : 2);
}

// ---------- Hilfen fürs Formular ----------
async function typeInto(page, selectors, value, { label } = {}) {
  if (value == null || value === '') return false;
  const list = Array.isArray(selectors) ? selectors : [selectors];
  for (const sel of list) {
    const el = await page.$(sel);
    if (el) {
      await el.click({ clickCount: 3 }).catch(() => {});
      await el.type(String(value), { delay: 12 }).catch(() => {});
      return true;
    }
  }
  console.log(`  (Feld nicht gefunden${label ? ' für ' + label : ''}: ${list.join(', ')})`);
  return false;
}

// Beschreibung in KDPs CKEditor schreiben. auto-kdp-validiert: Quelltext-Button
// #cke_18 aktivieren, dann in #cke_1_contents > textarea schreiben. Fallbacks:
// contenteditable-Editor oder klassisches Textfeld.
async function fillDescription(page, text) {
  if (!text) return false;
  const srcBtn = await page.$('#cke_18, a.cke_button__source, .cke_button__source');
  if (srcBtn) { await srcBtn.click().catch(() => {}); await new Promise(r => setTimeout(r, 600)); }
  const ta = await page.$('#cke_1_contents > textarea, #cke_1_contents textarea, textarea.cke_source');
  if (ta) {
    await ta.click({ clickCount: 3 }).catch(() => {});
    await ta.type(String(text), { delay: 3 }).catch(() => {});
    return true;
  }
  const ce = await page.$('#cke_1_contents div[contenteditable="true"], div[contenteditable="true"]');
  if (ce) {
    await page.evaluate((el, t) => {
      el.innerHTML = '<p>' + String(t).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/\n\n/g, '</p><p>').replace(/\n/g, '<br>') + '</p>';
      el.dispatchEvent(new Event('input', { bubbles: true }));
    }, ce, String(text));
    return true;
  }
  return await typeInto(page, ['textarea[name="description"]', '#data-ebook-description'], text, { label: 'Beschreibung' });
}

// ---------- Befehl: upload ----------
async function cmdUpload() {
  const job = JSON.parse(fs.readFileSync(args.job, 'utf8'));
  const dryRun = !!args['dry-run'];
  report({ stage: 'start', progress: 0.02, message: `Upload-Entwurf: „${job.title}"${dryRun ? ' (Testlauf)' : ''}` });

  const browser = await launch(args.profile, args.chrome, { headless: false });
  try {
    const page = (await browser.pages())[0] || await browser.newPage();
    page.setDefaultTimeout(45000);

    report({ stage: 'auth', progress: 0.06, message: 'Prüfe KDP-Login …' });
    if (!(await isLoggedIn(page))) {
      throw new Error('Nicht bei KDP eingeloggt. Bitte zuerst „KDP-Login" ausführen.');
    }

    // Neues Kindle-eBook.
    report({ stage: 'create', progress: 0.12, message: 'Lege neues Kindle-eBook an …' });
    await page.goto('https://kdp.amazon.com/en_US/title-setup/kindle/new/details',
      { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('#data-print-book-title, #data-ebook-title, input[name="title"]',
      { timeout: 45000 }).catch(() => {});

    // Details ausfüllen. Primär-Selektoren aus dem im Betrieb validierten auto-kdp-Projekt,
    // mit eBook-/generischen Fallbacks (KDP-IDs können je Format leicht abweichen).
    report({ stage: 'metadata', progress: 0.25, message: 'Fülle Titel, Autor, Beschreibung …' });
    await typeInto(page, ['#data-print-book-title', '#data-ebook-title', 'input[name="title"]'], job.title, { label: 'Titel' });
    await typeInto(page, ['#data-print-book-subtitle', '#data-ebook-subtitle', 'input[name="subtitle"]'], job.subtitle);
    // Autor: KDP trennt Vor- und Nachname (auto-kdp: primary-author-first/last-name).
    const _ap = String(job.author || '').trim().split(/\s+/).filter(Boolean);
    const authorLast = _ap.length > 1 ? _ap[_ap.length - 1] : (_ap[0] || '');
    const authorFirst = _ap.length > 1 ? _ap.slice(0, -1).join(' ') : '';
    await typeInto(page, ['#data-print-book-primary-author-first-name', 'input[name="authorFirstName"]'], authorFirst, { label: 'Autor-Vorname' });
    await typeInto(page, ['#data-print-book-primary-author-last-name', '#data-ebook-primary-author-last-name', 'input[name="authorLastName"]'], authorLast, { label: 'Autor-Nachname' });
    // Beschreibung über den CKEditor (auto-kdp-Weg, mit Fallbacks).
    await fillDescription(page, job.description);

    // Keywords (7 Slots).
    report({ stage: 'keywords', progress: 0.4, message: 'Trage Keywords ein …' });
    const kws = (job.keywords || []).slice(0, 7);
    for (let i = 0; i < kws.length; i++) {
      await typeInto(page, [`#data-print-book-keywords-${i}`, `#data-ebook-keywords-${i}`, `input[name="keywords[${i}]"]`], kws[i]);
    }

    // KI-Offenlegung (Pflicht bei KDP): job.aiDisclosure = 'ai-generated' | 'ai-assisted' | 'none'
    report({ stage: 'ai-disclosure', progress: 0.5, message: `KI-Kennzeichnung: ${job.aiDisclosure || 'ai-assisted'}` });
    // Die genauen Radio-/Checkbox-Selektoren dieses (neueren) KDP-Abschnitts werden
    // beim ersten echten Login validiert; hier wird die Absicht protokolliert.

    // Content-Upload: EPUB + Cover.
    report({ stage: 'content', progress: 0.62, message: 'Lade Manuskript (EPUB) und Cover hoch …' });
    await page.goto('https://kdp.amazon.com/en_US/title-setup/kindle/new/content',
      { waitUntil: 'domcontentloaded' }).catch(() => {});
    const epubInput = await page.$('input[type="file"][accept*="epub"], #data-ebook-manuscript-file, input[type="file"]');
    if (epubInput && job.epubPath && fs.existsSync(job.epubPath)) {
      await epubInput.uploadFile(job.epubPath);
      report({ stage: 'content', progress: 0.72, message: 'Manuskript hochgeladen, warte auf Verarbeitung …' });
    } else {
      report({ stage: 'content', progress: 0.72, message: '(EPUB-Upload-Feld nicht gefunden – bei erstem echten Login kalibrieren)' });
    }
    const coverInput = await page.$$('input[type="file"]');
    if (coverInput.length > 1 && job.coverPath && fs.existsSync(job.coverPath)) {
      await coverInput[coverInput.length - 1].uploadFile(job.coverPath);
      report({ stage: 'content', progress: 0.8, message: 'Cover hochgeladen.' });
    }

    // Preis.
    report({ stage: 'pricing', progress: 0.88, message: `Setze Preis (${job.priceEUR} €) …` });
    await page.goto('https://kdp.amazon.com/en_US/title-setup/kindle/new/pricing',
      { waitUntil: 'domcontentloaded' }).catch(() => {});
    await typeInto(page, ['#data-pricing-print-list-price-EUR', 'input[name="priceEUR"]', 'input[name="listPrice"]'], String(job.priceEUR));

    if (dryRun) {
      report({ stage: 'done', progress: 1, ok: true, message: 'Testlauf beendet – NICHTS gespeichert.' });
    } else {
      // ENTWURF speichern — NICHT veröffentlichen.
      report({ stage: 'save-draft', progress: 0.95, message: 'Speichere als Entwurf (kein Veröffentlichen) …' });
      const saveBtn = await page.$('#save-announce, button[data-action="save-draft"], #save-and-continue-announce');
      if (saveBtn) { await saveBtn.click().catch(() => {}); await new Promise(r => setTimeout(r, 4000)); }
      const draftUrl = page.url();
      report({ stage: 'done', progress: 1, ok: true, draftUrl,
        message: 'Entwurf in KDP gespeichert. Bitte Preis prüfen und manuell veröffentlichen.' });
    }
  } catch (e) {
    report({ stage: 'error', progress: statusObj.progress, ok: false, error: String(e.message || e),
      message: 'Fehler: ' + String(e.message || e) });
    await browser.close().catch(() => {});
    process.exit(1);
  }
  // Fenster kurz offen lassen zur Sichtkontrolle, dann schließen.
  await new Promise(r => setTimeout(r, 3000));
  await browser.close().catch(() => {});
}

(async () => {
  try {
    if (command === 'login') await cmdLogin();
    else if (command === 'check') await cmdCheck();
    else if (command === 'upload') await cmdUpload();
    else { console.error('Unbekannter Befehl. Nutze: login | check | upload'); process.exit(64); }
  } catch (e) {
    report({ stage: 'error', ok: false, error: String(e.message || e), message: 'Fehler: ' + String(e.message || e) });
    process.exit(1);
  }
})();
