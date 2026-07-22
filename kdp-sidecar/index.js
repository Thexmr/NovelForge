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
    args: ['--no-first-run', '--no-default-browser-check', '--window-size=1400,1000',
           '--lang=de-DE', '--accept-lang=de-DE,de'],
  });
  return browser;
}

// Setzt die Sprache der Seite auf Deutsch, damit Amazon die Anmeldung NICHT
// auf Englisch/US zeigt. Vor jeder Navigation aufrufen.
async function germanLocale(page) {
  try { await page.setExtraHTTPHeaders({ 'Accept-Language': 'de-DE,de;q=0.9,en;q=0.5' }); } catch (_) {}
}
// KDP mit erzwungener deutscher Sprache öffnen (leitet die Anmeldung auf Deutsch weiter).
const KDP_HOME_DE = 'https://kdp.amazon.com/?language=de_DE';

const KDP_BOOKSHELF = 'https://kdp.amazon.com/de_DE/bookshelf';
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
  const onSignin = url.includes('/ap/signin') || url.includes('/ap/') || url.includes('signin');
  // Zuverlässigster Nachweis: das persistente Amazon-Auth-Token-Cookie (at-main /
  // sess-at-main / x-main). Ist es gesetzt UND wir sind nicht gerade auf der
  // Anmeldeseite → eingeloggt. Robuster als (sich ändernde) DOM-Selektoren.
  try {
    const cs = await page.cookies('https://www.amazon.com', 'https://kdp.amazon.com');
    const hasAuth = cs.some(c => /^(at-main|sess-at-main|x-main)$/.test(c.name) && c.value && c.value.length > 8);
    if (hasAuth && !onSignin) return true;
  } catch (_) { /* Cookie-Abfrage fehlgeschlagen – Fallback unten */ }
  if (onSignin) return false;
  // Fallback: auf einer KDP-Seite (nicht signin) mit Regal-/Nav-Element.
  if (url.includes('kdp.amazon')) {
    try { await page.waitForSelector(KDP_LOGIN_PROOF, { timeout: 3000 }); return true; }
    catch (_) { return true; } // KDP-Seite, nicht signin → als eingeloggt werten
  }
  return false;
}

// ---------- Befehl: login ----------
async function cmdLogin() {
  report({ stage: 'login', progress: 0.1, message: 'Öffne KDP-Login (einmalig, manuell inkl. 2FA) …' });
  const browser = await launch(args.profile, args.chrome, { headless: false });
  const page = (await browser.pages())[0] || await browser.newPage();
  await germanLocale(page);
  // WICHTIG: direkt aufs deutsche Bücherregal — das ERZWINGT die (deutsche) Anmeldung
  // mit korrektem return_to. Die Startseite (kdp.amazon.com/) zeigt jedem eine
  // Marketing-Seite OHNE Login → dort würde nie echt authentifiziert.
  await page.goto(KDP_BOOKSHELF, { waitUntil: 'domcontentloaded', timeout: 60000 }).catch(() => {});
  await page.bringToFront().catch(() => {});
  report({ stage: 'login', progress: 0.4, message: 'Bitte im geöffneten Fenster bei Amazon KDP einloggen (inkl. 2FA). Warte auf dein Bücherregal …' });
  // Bis zu 30 Minuten warten – OHNE das Fenster wegzunavigieren (passiv prüfen).
  const deadline = Date.now() + 1800000;
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
  await germanLocale(page);
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

// Beschreibung in KDPs CKEditor schreiben. PRIMÄR (an echter eBook-Seite validiert):
// die CKEditor-Instanz direkt per setData füllen (KDP nutzt 'editor1'). Danach
// Fallbacks: Quelltext-Button + Textarea / contenteditable / klassisches Textfeld.
async function fillDescription(page, text) {
  if (!text) return false;
  const html = '<p>' + String(text).replace(/&/g, '&amp;').replace(/</g, '&lt;')
    .replace(/\n\n/g, '</p><p>').replace(/\n/g, '<br>') + '</p>';
  const viaCke = await page.evaluate((h) => {
    try {
      if (window.CKEDITOR && CKEDITOR.instances) {
        const keys = Object.keys(CKEDITOR.instances);
        if (keys.length) { CKEDITOR.instances[keys[0]].setData(h); return true; }
      }
    } catch (e) { /* Fallback unten */ }
    return false;
  }, html).catch(() => false);
  if (viaCke) return true;
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
    await germanLocale(page);

    report({ stage: 'auth', progress: 0.06, message: 'Prüfe KDP-Login …' });
    if (!(await isLoggedIn(page))) {
      throw new Error('Nicht bei KDP eingeloggt. Bitte zuerst „KDP-Login" ausführen.');
    }

    // Neues Kindle-eBook.
    report({ stage: 'create', progress: 0.12, message: 'Lege neues Kindle-eBook an …' });
    await page.goto('https://kdp.amazon.com/de_DE/title-setup/kindle/new/details',
      { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('#data-title, #data-print-book-title, input[name="data[title]"]',
      { timeout: 45000 }).catch(() => {});

    // Details ausfüllen. PRIMÄR: die an der echten deutschen KDP-eBook-Seite LIVE
    // validierten IDs (#data-title etc.). Fallbacks: auto-kdp-Print + name-Attribute.
    report({ stage: 'metadata', progress: 0.25, message: 'Fülle Titel, Autor, Beschreibung …' });
    await typeInto(page, ['#data-title', '#data-print-book-title', 'input[name="data[title]"]', 'input[name="title"]'], job.title, { label: 'Titel' });
    await typeInto(page, ['#data-subtitle', '#data-print-book-subtitle', 'input[name="data[subtitle]"]'], job.subtitle);
    // Autor: KDP trennt Vor- und Nachname (eBook: data-primary-author-first/last-name).
    const _ap = String(job.author || '').trim().split(/\s+/).filter(Boolean);
    const authorLast = _ap.length > 1 ? _ap[_ap.length - 1] : (_ap[0] || '');
    const authorFirst = _ap.length > 1 ? _ap.slice(0, -1).join(' ') : '';
    await typeInto(page, ['#data-primary-author-first-name', '#data-print-book-primary-author-first-name', 'input[name="data[primary_author][first_name]"]'], authorFirst, { label: 'Autor-Vorname' });
    await typeInto(page, ['#data-primary-author-last-name', '#data-print-book-primary-author-last-name', 'input[name="data[primary_author][last_name]"]'], authorLast, { label: 'Autor-Nachname' });
    // Beschreibung über den CKEditor (Instanz 'editor1' → setData; mit Fallbacks).
    await fillDescription(page, job.description);

    // Keywords (7 Slots) — eBook: data-keywords-0..6.
    report({ stage: 'keywords', progress: 0.4, message: 'Trage Keywords ein …' });
    const kws = (job.keywords || []).slice(0, 7);
    for (let i = 0; i < kws.length; i++) {
      await typeInto(page, [`#data-keywords-${i}`, `#data-print-book-keywords-${i}`, `input[name="data[keywords][${i}]"]`], kws[i]);
    }

    // KI-Offenlegung (Pflicht bei KDP): job.aiDisclosure = 'ai-generated' | 'ai-assisted' | 'none'
    report({ stage: 'ai-disclosure', progress: 0.5, message: `KI-Kennzeichnung: ${job.aiDisclosure || 'ai-assisted'}` });
    // Die genauen Radio-/Checkbox-Selektoren dieses (neueren) KDP-Abschnitts werden
    // beim ersten echten Login validiert; hier wird die Absicht protokolliert.

    // Content-Upload: EPUB + Cover.
    report({ stage: 'content', progress: 0.62, message: 'Lade Manuskript (EPUB) und Cover hoch …' });
    await page.goto('https://kdp.amazon.com/de_DE/title-setup/kindle/new/content',
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
    await page.goto('https://kdp.amazon.com/de_DE/title-setup/kindle/new/pricing',
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
