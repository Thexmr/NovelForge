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
import path from 'path';
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

// ---- Das ECHTE Chrome des Nutzers verwenden ----------------------------------
// Ziel: KDP soll mit der bestehenden Anmeldung des Nutzers arbeiten – kein zweiter Login.
// Strategien in dieser Reihenfolge:
//   1) --cdp <url>            an ein laufendes Chrome mit --remote-debugging-port andocken
//   2) --use-my-chrome        Chrome mit dem ECHTEN Profil starten (nur wenn Chrome zu ist)
//   3) --use-my-chrome-copy   Sitzungsdaten (Cookies) aus dem echten Profil übernehmen und
//                             in einem eigenen Profil arbeiten → dein Chrome bleibt nutzbar
//   4) Standard               eigenes Profil (einmaliger Login per `login`)

function realChromeProfileDir() {
  const home = process.env.HOME || '';
  if (process.platform === 'darwin') return path.join(home, 'Library', 'Application Support', 'Google', 'Chrome');
  if (process.platform === 'win32') return path.join(process.env.LOCALAPPDATA || '', 'Google', 'Chrome', 'User Data');
  return path.join(home, '.config', 'google-chrome');
}

/** Prüft, ob das echte Chrome-Profil gerade von einer laufenden Chrome-Instanz gesperrt ist. */
function realChromeRunning() {
  try {
    const out = require('child_process').execSync('ps -A -o command=', { encoding: 'utf8' });
    return out.split('\n').some((l) =>
      /Google Chrome\.app\/Contents\/MacOS\/Google Chrome/.test(l) && !/--user-data-dir=/.test(l));
  } catch (_) { return false; }
}

/**
 * Übernimmt die ANMELDE-SITZUNG aus dem echten Chrome-Profil in ein eigenes Arbeitsprofil:
 * kopiert nur die Sitzungsdateien (Cookies + „Local State" für den Entschlüsselungsschlüssel
 * + Preferences). Es werden KEINE Passwörter kopiert und keine Werte gelesen/ausgegeben.
 * So bleibt dein normales Chrome geöffnet und nutzbar.
 */
function hydrateSessionFromRealChrome(targetDir, profileName) {
  const src = realChromeProfileDir();
  const prof = profileName || 'Default';
  const pairs = [
    [path.join(src, 'Local State'), path.join(targetDir, 'Local State')],
    [path.join(src, prof, 'Cookies'), path.join(targetDir, prof, 'Cookies')],
    [path.join(src, prof, 'Network', 'Cookies'), path.join(targetDir, prof, 'Network', 'Cookies')],
    [path.join(src, prof, 'Preferences'), path.join(targetDir, prof, 'Preferences')],
  ];
  let copied = 0;
  for (const [from, to] of pairs) {
    try {
      if (!fs.existsSync(from)) continue;
      fs.mkdirSync(path.dirname(to), { recursive: true });
      fs.copyFileSync(from, to);
      copied++;
    } catch (_) { /* einzelne Datei gesperrt → weiter */ }
  }
  return copied;
}

async function launch(profileDir, chromePath, { headless } = { headless: false }) {
  const puppeteer = (await import('puppeteer-extra')).default;
  try {
    const Stealth = (await import('puppeteer-extra-plugin-stealth')).default;
    puppeteer.use(Stealth());
  } catch (_) { /* Stealth optional */ }

  // (1) An ein bereits laufendes Chrome andocken (nutzt DEINE offene Sitzung 1:1).
  const cdp = args.cdp || process.env.NF_CHROME_CDP;
  if (cdp) {
    const browserURL = String(cdp).startsWith('http') ? String(cdp) : 'http://127.0.0.1:' + String(cdp);
    try {
      const browser = await puppeteer.connect({ browserURL, defaultViewport: null });
      console.log('  (an laufendes Chrome angedockt: ' + browserURL + ')');
      browser.__nfAttached = true; // nicht schließen – es ist DEIN Browser
      return browser;
    } catch (e) {
      throw new Error('Konnte nicht an Chrome andocken (' + browserURL + '): ' + e.message
        + '\nStarte Chrome einmal mit: open -a "Google Chrome" --args --remote-debugging-port=9222');
    }
  }

  const executablePath = findChrome(chromePath);
  if (!executablePath) throw new Error('Kein Chrome/Chromium/Edge/Brave gefunden. Bitte --chrome <pfad> angeben.');

  const wantMine = !!(args['use-my-chrome'] || process.env.NF_USE_MY_CHROME);
  const wantCopy = !!(args['use-my-chrome-copy'] || process.env.NF_USE_MY_CHROME_COPY);
  const profileName = args['chrome-profile'] || 'Default';
  let userDataDir = profileDir;
  const extraArgs = [];
  // Puppeteer setzt standardmäßig --use-mock-keychain und --password-store=basic.
  // Damit kann Chrome die im macOS-Schlüsselbund verschlüsselten Cookies NICHT
  // entschlüsseln → übernommene Sitzungen wären wertlos. Für „mein Chrome" abschalten.
  const ignoreDefaultArgs = (wantMine || wantCopy)
    ? ['--use-mock-keychain', '--password-store=basic']
    : undefined;

  if (wantMine && !realChromeRunning()) {
    // (2) Direkt im echten Profil arbeiten – alle Logins vorhanden.
    userDataDir = realChromeProfileDir();
    extraArgs.push('--profile-directory=' + profileName);
    console.log('  (nutzt DEIN echtes Chrome-Profil: ' + userDataDir + ' / ' + profileName + ')');
  } else if (wantMine || wantCopy) {
    // (3) Chrome läuft → Sitzung ins Arbeitsprofil übernehmen, dein Chrome bleibt offen.
    fs.mkdirSync(profileDir, { recursive: true });
    const n = hydrateSessionFromRealChrome(profileDir, profileName);
    extraArgs.push('--profile-directory=' + profileName);
    console.log('  (Sitzung aus deinem Chrome übernommen: ' + n + ' Sitzungsdateien; dein Chrome bleibt offen)');
  }

  fs.mkdirSync(userDataDir, { recursive: true });
  const launchOpts = {
    executablePath,
    headless: headless ? 'new' : false,
    userDataDir,
    defaultViewport: null,
    args: ['--no-first-run', '--no-default-browser-check', '--window-size=1400,1000',
           '--lang=de-DE', '--accept-lang=de-DE,de', ...extraArgs],
  };
  if (ignoreDefaultArgs) launchOpts.ignoreDefaultArgs = ignoreDefaultArgs;
  const browser = await puppeteer.launch(launchOpts);
  return browser;
}

/**
 * Meldet sich bei Amazon an, WENN hinterlegte Zugangsdaten vorliegen und gerade das
 * Anmeldeformular sichtbar ist.
 *
 * Die Daten kommen ausschließlich über UMGEBUNGSVARIABLEN (NF_KDP_EMAIL / NF_KDP_PASSWORD),
 * die die App aus dem System-Schlüsselbund liest. Bewusst NICHT über die Kommandozeile
 * (dort stünden sie in der Prozessliste) und NICHT über die Job-Datei (die liegt auf der
 * Platte). Es wird nichts protokolliert – auch keine Länge, kein Ausschnitt.
 *
 * Bleibt eine Zwei-Faktor-Abfrage (SMS/App-Code) stehen, wird das gemeldet: diesen Schritt
 * macht der Mensch, bzw. auf Android liest die App den SMS-Code selbst aus.
 */
async function autoAnmelden(page) {
  const email = process.env.NF_KDP_EMAIL;
  const passwort = process.env.NF_KDP_PASSWORD;
  if (!email || !passwort) return { versucht: false, hinweis: 'keine Zugangsdaten hinterlegt' };

  const emailFeld = await page.$('#ap_email, input[name="email"], #ap_email_login');
  const passFeld = await page.$('#ap_password, input[name="password"]');
  if (!emailFeld && !passFeld) return { versucht: false, hinweis: 'kein Anmeldeformular sichtbar' };

  report({ stage: 'login', progress: 0.08, message: 'Melde mit hinterlegten Zugangsdaten an …' });
  if (emailFeld) {
    await emailFeld.click({ clickCount: 3 }).catch(() => {});
    await emailFeld.type(email, { delay: 25 }).catch(() => {});
    // Zweistufige Maske: erst „Weiter", dann Passwort.
    const weiter = await page.$('#continue, input#continue');
    if (weiter && !passFeld) {
      await weiter.click().catch(() => {});
      await page.waitForNavigation({ waitUntil: 'domcontentloaded', timeout: 30000 }).catch(() => {});
      await new Promise(r => setTimeout(r, 1500));
    }
  }
  const passFeld2 = await page.$('#ap_password, input[name="password"]');
  if (passFeld2) {
    await passFeld2.click({ clickCount: 3 }).catch(() => {});
    await passFeld2.type(passwort, { delay: 25 }).catch(() => {});
    // „Angemeldet bleiben" ankreuzen: verlängert die Sitzung, spart künftige Anmeldungen.
    await page.$eval('input[name="rememberMe"], #auth-remember-me', (e) => { if (!e.checked) e.click(); }).catch(() => {});
    const senden = await page.$('#signInSubmit, input#signInSubmit');
    if (senden) {
      await senden.click().catch(() => {});
      await page.waitForNavigation({ waitUntil: 'domcontentloaded', timeout: 45000 }).catch(() => {});
      await new Promise(r => setTimeout(r, 3000));
    }
  }
  // Steht jetzt eine Zwei-Faktor-Abfrage? Dann ehrlich melden statt „erfolgreich".
  const zweiFaktor = await page.$('#auth-mfa-otpcode, input[name="otpCode"], #cvf-input-code');
  if (zweiFaktor) {
    return { versucht: true, zweiFaktor: true, hinweis: 'Bestätigungscode erforderlich (SMS/App) – bitte im Fenster eingeben.' };
  }
  return { versucht: true, zweiFaktor: false, hinweis: 'Anmeldung mit hinterlegten Daten versucht.' };
}

/**
 * SELBSTPRÜFUNG UND SELBSTHEILUNG der Detailseite.
 *
 * Statt Blocker einzeln zu entdecken (was mehrere Anläufe kostet), liest diese Funktion
 * den Zustand der Seite aus, behebt selbstständig, was sie beheben kann, prüft erneut
 * und meldet am Ende ehrlich, was wirklich offen ist.
 *
 * Bewusst gedeckelt (max. 3 Runden) – sie kann nicht endlos laufen.
 * Rückgabe: { sauber, behoben:[], offen:[] }
 */
async function pruefeUndRepariere(page, job, maxRunden = 3) {
  const behoben = [];
  let offen = [];

  for (let runde = 1; runde <= maxRunden; runde++) {
    // 1) Zustand erheben: Was ist gesetzt, welche Hinweise stehen auf der Seite?
    const zustand = await page.evaluate(() => {
      const sicht = (e) => e && e.offsetParent !== null;
      const hinweise = [...document.querySelectorAll('[class*="error" i],[class*="alert" i],[role="alert"]')]
        .filter(sicht)
        .map((e) => (e.innerText || '').replace(/\s+/g, ' ').trim())
        .filter((t) => t.length > 6 && t.length < 220);
      let beschreibungLeer = null;
      try {
        const k = Object.keys((window.CKEDITOR && window.CKEDITOR.instances) || {});
        if (k.length) beschreibungLeer = !window.CKEDITOR.instances[k[0]].getData().trim();
      } catch (_) { /* egal */ }
      return {
        titelLeer: !((document.querySelector('#data-title') || {}).value || '').trim(),
        autorLeer: !((document.querySelector('#data-primary-author-last-name') || {}).value || '').trim(),
        beschreibungLeer,
        rechteOffen: !(document.querySelector('#non-public-domain') || {}).checked,
        alterOffen: ![...document.querySelectorAll('input[name="data[is_adult_content]-radio"]')].some((r) => r.checked),
        kategorieOffen: /kategorie/i.test(document.body.innerText)
          && /hinzufügen|fehlt|auswählen|mindestens/i.test(document.body.innerText),
        hinweise: [...new Set(hinweise)].slice(0, 6),
      };
    }).catch(() => null);
    if (!zustand) return { sauber: false, behoben, offen: ['Seitenzustand nicht lesbar'] };

    offen = [];

    // 2) Selbst beheben, was bekannt ist.
    if (zustand.rechteOffen) {
      const ok = await page.evaluate(() => {
        const r = document.querySelector('#non-public-domain');
        if (!r) return false; if (!r.checked) { r.click(); r.dispatchEvent(new Event('change', { bubbles: true })); }
        return true;
      }).catch(() => false);
      ok ? behoben.push('Verlagsrechte') : offen.push('Verlagsrechte');
    }
    if (zustand.alterOffen) {
      const ok = await page.evaluate(() => {
        const r = document.querySelector('input[name="data[is_adult_content]-radio"][value="false"]');
        if (!r) return false; if (!r.checked) { r.click(); r.dispatchEvent(new Event('change', { bubbles: true })); }
        return true;
      }).catch(() => false);
      ok ? behoben.push('Alterseinstufung') : offen.push('Alterseinstufung');
    }
    if (zustand.titelLeer) {
      const r = await typeVerified(page, ['#data-title', 'input[name="data[title]"]'], job.title, { label: 'Titel' });
      r.ok ? behoben.push('Titel') : offen.push('Titel');
    }
    if (zustand.autorLeer && job.author) {
      const teile = String(job.author).trim().split(/\s+/).filter(Boolean);
      const r = await typeVerified(page, ['#data-primary-author-last-name'],
        teile.length > 1 ? teile[teile.length - 1] : teile[0], { label: 'Autor' });
      r.ok ? behoben.push('Autor') : offen.push('Autor');
    }
    if (zustand.beschreibungLeer === true && job.description) {
      (await fillDescription(page, job.description)) ? behoben.push('Beschreibung') : offen.push('Beschreibung');
    }
    if (zustand.kategorieOffen) {
      (await setzeKategorie(page, job)) ? behoben.push('Kategorie') : offen.push('Kategorie');
    }

    // 3) Nichts mehr zu tun? Dann ist die Seite sauber.
    const nochOffen = zustand.rechteOffen || zustand.alterOffen || zustand.titelLeer
      || zustand.autorLeer || zustand.kategorieOffen;
    if (!nochOffen) {
      return { sauber: true, behoben: [...new Set(behoben)], offen: [], hinweise: zustand.hinweise };
    }
    await new Promise(r => setTimeout(r, 2000));
  }
  // Über mehrere Runden kann derselbe Punkt mehrfach angefasst werden – im Bericht
  // soll er trotzdem nur einmal stehen.
  return { sauber: offen.length === 0, behoben: [...new Set(behoben)], offen: [...new Set(offen)] };
}

/**
 * Wartet, bis KDP eine hochgeladene Datei WIRKLICH angenommen hat – und beweist das
 * am Seiteninhalt, nicht an einer Wartezeit. KDP zeigt nach der Verarbeitung den
 * Dateinamen samt „Hochgeladen am …" an; scheitert die Prüfung, erscheint stattdessen
 * eine Fehlermeldung. Beides wird hier unterschieden.
 */
async function warteAufUploadFertig(page, dateiPfad, timeoutMs = 240000, melde = () => {}) {
  const name = path.basename(dateiPfad);
  const stamm = name.replace(/\.[^.]+$/, '').slice(0, 24);
  const bis = Date.now() + timeoutMs;
  let zuletzt = '';
  while (Date.now() < bis) {
    const s = await page.evaluate((stamm) => {
      const txt = (document.body.innerText || '');
      const fehler = [...document.querySelectorAll('[class*="error" i],[role="alert"]')]
        .filter((e) => e.offsetParent !== null)
        .map((e) => (e.innerText || '').replace(/\s+/g, ' ').trim())
        .find((t) => t.length > 6 && /fehl|error|ungültig|nicht|problem/i.test(t));
      return {
        nameDa: stamm.length > 3 && txt.includes(stamm),
        fertig: /hochgeladen am|erfolgreich hochgeladen|upload successful|hochgeladen \(/i.test(txt),
        laeuft: /wird hochgeladen|hochladen …|uploading|wird verarbeitet/i.test(txt),
        fehler: fehler || '',
      };
    }, stamm).catch(() => null);
    if (!s) return { ok: false, hinweis: 'Seite nicht lesbar' };
    if (s.fehler) return { ok: false, hinweis: 'KDP meldet: ' + s.fehler.slice(0, 140) };
    if (s.fertig || s.nameDa) return { ok: true, hinweis: 'von KDP angenommen (' + name + ')' };
    const stand = s.laeuft ? 'wird verarbeitet …' : 'warte auf Rückmeldung …';
    if (stand !== zuletzt) { zuletzt = stand; melde(stand); }
    await new Promise(r => setTimeout(r, 4000));
  }
  return { ok: false, hinweis: 'keine Bestätigung innerhalb der Wartezeit' };
}


/**
 * Klickt ein Formularelement, das über SEINEN SICHTBAREN TEXT gefunden wird.
 *
 * KDP vergibt für diese Abschnitte keine stabilen IDs. Über den Beschriftungstext zu
 * gehen ist dafür der verlässlichere Weg: Der Text steht im Formular und ändert sich
 * seltener als generierte Attribute.
 */
async function klickeNachBeschriftung(page, muster, nurTyp) {
  return page.evaluate((musterQuelle, typ) => {
    const re = new RegExp(musterQuelle, 'i');
    const eingaben = [...document.querySelectorAll('input[type="radio"], input[type="checkbox"]')]
      .filter((el) => !typ || el.type === typ);
    for (const el of eingaben) {
      // Beschriftung: verknüpftes <label>, umschließendes <label> oder Elternzeile.
      let text = '';
      if (el.id) {
        const lab = document.querySelector(`label[for="${CSS.escape(el.id)}"]`);
        if (lab) text = lab.innerText || '';
      }
      if (!text) text = (el.closest('label') || {}).innerText || '';
      if (!text) text = (el.parentElement || {}).innerText || '';
      if (!re.test(text)) continue;
      if (el.checked) return 'bereits';
      el.click();
      return el.checked ? 'geklickt' : 'klick-ohne-wirkung';
    }
    return 'nicht-gefunden';
  }, muster instanceof RegExp ? muster.source : String(muster), nurTyp || null);
}


/**
 * Setzt die Sprache des Buches auf der Detailseite.
 *
 * Wurde bisher gar nicht behandelt: Das job-Dict enthielt keine Sprache, und der
 * Sidecar rührte das Dropdown nie an. Für ein deutsches Buch im /de_DE/-Fluss
 * defaultet KDP zwar meist auf Deutsch, aber verlassen sollte man sich darauf nicht -
 * eine falsche Sprachangabe schiebt das Buch in die falschen Kategorien und
 * Empfehlungslisten.
 *
 * Gesucht wird die Option über ihren Text (Deutsch/German), nicht über einen
 * geratenen Wert - die Optionswerte sind bei KDP nicht stabil.
 */
async function setzeSprache(page, job) {
  const wunsch = String(job.language || 'Deutsch').trim();
  return page.evaluate((sprache) => {
    const nrm = (t) => (t || '').toLowerCase();
    const ziel = nrm(sprache);
    const aliasse = ziel.startsWith('de') || ziel.includes('deutsch') || ziel.includes('german')
      ? ['deutsch', 'german'] : [ziel];
    const felder = [...document.querySelectorAll('select')].filter((s) => s.offsetParent !== null);
    for (const sel of felder) {
      const opt = [...sel.options].find((o) => aliasse.some((a) => nrm(o.text).includes(a)));
      if (!opt) continue;
      // Nur ein Sprach-Dropdown anfassen: Es muss auch eine Englisch-Option haben.
      const sprachauswahl = [...sel.options].some((o) => /englisch|english/i.test(o.text));
      if (!sprachauswahl) continue;
      if (sel.value === opt.value) return 'bereits';
      const setter = Object.getOwnPropertyDescriptor(window.HTMLSelectElement.prototype, 'value').set;
      setter.call(sel, opt.value);
      sel.dispatchEvent(new Event('change', { bubbles: true }));
      return 'gesetzt';
    }
    return 'nicht-gefunden';
  }, wunsch);
}

/**
 * Klickt ein Formularelement, das ÜBER EINEN ABSCHNITT eingegrenzt wird.
 *
 * `klickeNachBeschriftung` sucht global auf der ganzen Seite. Das ist für die
 * KI-Kennzeichnung gefährlich: Das Muster `^\s*Ja\s*$` passt auf JEDE Ja/Nein-
 * Frage des Formulars (Altersfreigabe, öffentliche Domain, …), und `'text'`
 * passt auf jede Checkbox, deren Beschriftung das Wort enthält – der Treffer
 * war schlicht der erste im DOM, nicht notwendig der richtige.
 *
 * Hier wird zuerst der Abschnitt gesucht, dessen Text zum Abschnittsmuster
 * passt (z. B. die KI-Frage), und nur darin geklickt. Gibt es keinen solchen
 * Abschnitt, gilt das bisherige Verhalten als Rückfall.
 */
async function klickeInAbschnitt(page, abschnittMuster, beschriftungsMuster, nurTyp) {
  return page.evaluate((absQuelle, bQuelle, typ) => {
    const absRe = new RegExp(absQuelle, 'i');
    const bRe = new RegExp(bQuelle, 'i');
    const eingaben = [...document.querySelectorAll('input[type="radio"], input[type="checkbox"]')]
      .filter((el) => !typ || el.type === typ);
    const textVon = (el) => {
      let t = '';
      if (el.id) {
        const lab = document.querySelector(`label[for="${CSS.escape(el.id)}"]`);
        if (lab) t = lab.innerText || '';
      }
      if (!t) t = (el.closest('label') || {}).innerText || '';
      if (!t) t = (el.parentElement || {}).innerText || '';
      return t;
    };
    // Den SPEZIFISCHSTEN Abschnitts-Container finden: alle Elemente, deren
    // Text zum Abschnittsmuster passt UND die mindestens eine passende Eingabe
    // enthalten; davon gewinnt der KÜRZESTE Text (je spezifischer der Block,
    // desto kürzer). So scheitert kein Lockvogel: Ein übergeordnetes Element
    // (form/body), das Frage UND Fremdfragen umschließt, verliert immer gegen
    // den engen Block der eigentlichen Abschnittsfrage.
    let abschnitt = null;
    const kandidaten = document.querySelectorAll('fieldset, section, div, form, table, td, li');
    for (const el of kandidaten) {
      const t = (el.innerText || '');
      if (!absRe.test(t)) continue;
      const drin = [...el.querySelectorAll('input[type="radio"], input[type="checkbox"]')]
        .filter((e) => !typ || e.type === typ);
      if (!drin.length) continue;
      if (!abschnitt || t.length < (abschnitt.innerText || '').length) abschnitt = el;
    }
    const pool = abschnitt
      ? [...abschnitt.querySelectorAll('input[type="radio"], input[type="checkbox"]')]
          .filter((e) => !typ || e.type === typ)
      : eingaben;   // Rückfall: bisheriges globales Verhalten
    for (const el of pool) {
      if (!bRe.test(textVon(el))) continue;
      if (el.checked) return 'bereits';
      el.click();
      return el.checked ? 'geklickt' : 'klick-ohne-wirkung';
    }
    return 'nicht-gefunden';
  }, abschnittMuster instanceof RegExp ? abschnittMuster.source : String(abschnittMuster),
     beschriftungsMuster instanceof RegExp ? beschriftungsMuster.source : String(beschriftungsMuster),
     nurTyp || null);
}

// Textanker des KI-Offenlegungs-Abschnitts bei KDP (de/en).
const KI_ABSCHNITT = 'künstliche\\s+intelligenz|ki[-\\s]?tools|ki[-\\s]?generiert|artificial\\s+intelligence|ai[-\\s]?generated|ai\\s+tools';

/**
 * KI-Kennzeichnung ausfüllen – bei KDP ein PFLICHTFELD.
 *
 * Hier stand vorher nur ein Kommentar ("hier wird die Absicht protokolliert") und eine
 * Fortschrittsmeldung: Das Feld wurde nie ausgefüllt. Am echten Titel nachgesehen waren
 * unter "Haben Sie bei der Erstellung ... KI-Tools verwendet?" BEIDE Knöpfe leer, und
 * "Speichern und fortfahren" ging deshalb nicht weiter. Der Upload blieb genau davor
 * stehen ("Preise von Kindle eBooks: Nicht begonnen").
 *
 * Die Angabe muss der Wahrheit entsprechen: Diese Bücher entstehen mit KI, also "Ja".
 * Danach fragt KDP, WOFÜR – Text, Bilder, Übersetzung. Text und Bilder treffen zu.
 *
 * Alle Klicks laufen über klickeInAbschnitt: Die Ja/Nein-Frage darf nicht die
 * ERSTE beliebige Ja/Nein-Frage der Seite treffen, und die Text-/Bilder-Häkchen
 * keine fremde Checkbox mit „Text" in der Beschriftung.
 */
async function setzeKiKennzeichnung(page, job) {
  const art = String(job.aiDisclosure || 'ai-generated');
  const jaNein = art === 'none' ? 'Nein' : 'Ja';
  const schritte = [];

  schritte.push('Haupt:' + await klickeInAbschnitt(page, KI_ABSCHNITT, `^\\s*${jaNein}\\s*$`, 'radio'));
  await new Promise((r) => setTimeout(r, 1500));

  if (jaNein === 'Ja') {
    // Unterfragen erscheinen erst nach "Ja".
    schritte.push('Text:' + await klickeInAbschnitt(page, KI_ABSCHNITT, '^\\s*text\\b|\\btext(e|en)?\\b.*(erstellt|generiert|inhalt)', 'checkbox'));
    schritte.push('Bilder:' + await klickeInAbschnitt(page, KI_ABSCHNITT, 'bild', 'checkbox'));
    await new Promise((r) => setTimeout(r, 1000));
    // Umfang der KI-Beteiligung: "umfangreich bearbeitet" ist für diese Bücher korrekt.
    // WICHTIG: Das Muster darf nicht auf 'bearbeitet' allein lauten – das passt auch
    // auf "GERINGFÜGIG bearbeitet", und der erste DOM-Treffer wäre die falsche,
    // beschönigende Angabe (Sperrgrund, sobald Amazon sie entdeckt).
    schritte.push('Umfang:' + await klickeInAbschnitt(page, KI_ABSCHNITT, 'umfangreich', 'radio'));
  }
  return schritte;
}

/**
 * Auf "Bereits vorhandenes Cover hochladen" umschalten.
 *
 * KDP steht standardmäßig auf "Buchcover mit Cover Creator erstellen" – und solange
 * das gewählt ist, GIBT ES GAR KEIN DATEIFELD. Der Sidecar suchte trotzdem danach,
 * fand nichts und meldete den Schritt als erledigt. Am echten Titel nachgesehen stand
 * dort "Kein Cover hochgeladen", während die Fabrik "Cover: hochgeladen" anzeigte.
 */
async function waehleEigenesCover(page) {
  const r = await klickeNachBeschriftung(page, 'vorhandenes Cover hochladen|eigenes Cover', 'radio');
  await new Promise((res) => setTimeout(res, 2000));
  return r;
}

/**
 * Das Bestätigungsfeld unten auf der Inhaltsseite ankreuzen.
 * "Durch Anklicken dieses Feldes bestätige ich, dass meine Antworten korrekt sind."
 * Ohne dieses Häkchen speichert KDP die Seite nicht.
 */
async function bestaetigeAngaben(page) {
  return klickeNachBeschriftung(page, 'bestätige ich|Antworten korrekt', 'checkbox');
}

/** Öffnet den Kategorie-Dialog, wählt Ober-/Unterkategorie und speichert. */
async function setzeKategorie(page, job) {
  // Kategorien kommen je nach Aufrufer als Liste oder als „A > B | C > D"-Zeichenkette.
  // Beides annehmen: ein fest angenommenes Format hat hier schon einmal dazu geführt,
  // dass gar keine Kategorie gesetzt wurde.
  const katListe = Array.isArray(job.categories)
    ? job.categories
    : String(job.categories || '').split('|');
  // Die App liefert den vollen Pfad "Krimis & Thriller > Thriller > Psychologische
  // Thriller". Vorher wurde davon NUR das erste Glied benutzt; Unterkategorie und
  // Platzierung blieben leer, und angekreuzt wurde die erste beste freie Checkbox –
  // also irgendeine. Am echten Titel war die Kategorie deshalb komplett leer.
  const pfad = String(katListe[0] || '').split('>').map((x) => x.trim()).filter(Boolean);
  const wunsch = pfad[0] || '';
  // KEINE Kategorie erfinden. Vorher stand hier „Krimis & Thriller" als Notnagel –
  // damit bekam ein Ratgeber oder Liebesroman stillschweigend eine falsche Kategorie.
  // Eine falsche Kategorie schadet dem Ranking mehr als eine fehlende, und der Mensch
  // sieht am Entwurf sofort, dass hier noch etwas zu tun ist.
  if (!wunsch) return false;
  // Der Knopf hat die ID #categories-modal-button. Daneben steht der Hilfe-Link
  // „Was sind Kategorien?" – wird der getroffen, öffnet sich die Hilfe statt des Dialogs.
  const auf = await page.$('#categories-modal-button');
  if (!auf) return false;
  await auf.click().catch(() => {});
  await new Promise(r => setTimeout(r, 4000));
  const gesetzt = await page.evaluate((w) => {
    const s = [...document.querySelectorAll('select')].find((x) =>
      x.offsetParent !== null && [...x.options].some((o) => o.text.includes(w)));
    if (!s) return false;
    const opt = [...s.options].find((o) => o.text.includes(w));
    Object.getOwnPropertyDescriptor(window.HTMLSelectElement.prototype, 'value').set.call(s, opt.value);
    s.dispatchEvent(new Event('change', { bubbles: true }));
    return true;
  }, wunsch).catch(() => false);
  if (!gesetzt) return false;
  await new Promise(r => setTimeout(r, 3000));
  // Unterkategorie (zweites Glied) im nächsten Auswahlfeld setzen.
  if (pfad[1]) {
    await page.evaluate((u) => {
      const felder = [...document.querySelectorAll('select')].filter((x) => x.offsetParent !== null);
      for (const s of felder) {
        const opt = [...s.options].find((o) => o.text.trim().toLowerCase() === u.toLowerCase())
          || [...s.options].find((o) => o.text.toLowerCase().includes(u.toLowerCase()));
        if (!opt || s.value === opt.value) continue;
        Object.getOwnPropertyDescriptor(window.HTMLSelectElement.prototype, 'value').set.call(s, opt.value);
        s.dispatchEvent(new Event('change', { bubbles: true }));
        return true;
      }
      return false;
    }, pfad[1]).catch(() => {});
    await new Promise(r => setTimeout(r, 3000));
  }

  // Platzierung ankreuzen – die RICHTIGE, nicht die erste freie.
  //
  // Die Namen der App und die von KDP decken sich nicht immer wörtlich: Die App sagt
  // "Psychologische Thriller", im Formular steht "Psychothriller". Deshalb wird der
  // beste Treffer über gemeinsame Wortanfänge gesucht statt über Gleichheit.
  await page.evaluate((ziel) => {
    const stamm = (t) => (t.toLowerCase().match(/[a-zäöüß]{4,}/g) || []).map((w) => w.slice(0, 6));
    const zielStaemme = stamm(ziel || '');
    const kandidaten = [...document.querySelectorAll('input[type="checkbox"]')]
      .filter((c) => c.offsetParent !== null);
    let bester = null, bestePunkte = 0;
    for (const c of kandidaten) {
      let text = '';
      if (c.id) { const l = document.querySelector(`label[for="${CSS.escape(c.id)}"]`); if (l) text = l.innerText || ''; }
      if (!text) text = (c.closest('label') || c.parentElement || {}).innerText || '';
      const punkte = stamm(text).filter((w) => zielStaemme.includes(w)).length;
      if (punkte > bestePunkte) { bestePunkte = punkte; bester = c; }
    }
    // Ohne erkennbaren Bezug lieber NICHTS ankreuzen als das Falsche: Eine falsche
    // Kategorie schadet dem Ranking mehr als eine fehlende.
    if (!bester || bestePunkte === 0) return false;
    if (!bester.checked) { bester.click(); bester.dispatchEvent(new Event('change', { bubbles: true })); }
    return true;
  }, pfad[2] || pfad[1] || '').catch(() => {});
  await new Promise(r => setTimeout(r, 2000));
  const gespeichert = await page.evaluate(() => {
    const b = [...document.querySelectorAll('button')].find((e) =>
      /kategorien speichern/i.test((e.innerText || '').trim()) && e.offsetParent !== null);
    if (!b) return false; b.click(); return true;
  }).catch(() => false);
  await new Promise(r => setTimeout(r, 4000));
  return gespeichert;
}

// Angedockte Browser (dein echtes Chrome) NUR trennen, nie schließen. Eigene Instanzen schließen.
async function endSession(browser) {
  if (!browser) return;
  try {
    if (browser.__nfAttached) await browser.disconnect();
    else await browser.close();
  } catch (_) { /* egal */ }
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
  await endSession(browser);
  if (!ok) process.exit(2);
}

// ---------- Befehl: check ----------
async function cmdCheck() {
  // Headless: Die Login-Prüfung läuft im Hintergrund (Fabrik-Ansicht, Dispatcher).
  // Vorher öffnete jede Prüfung ein sichtbares Fenster. Das Auth-Cookie liest sich
  // auch headless (ignoreDefaultArgs schaltet den Schlüsselbund-Störer ab).
  const browser = await launch(args.profile, args.chrome, { headless: true });
  const page = (await browser.pages())[0] || await browser.newPage();
  await germanLocale(page);
  const ok = await isLoggedIn(page);
  report({ stage: 'check', progress: 1, ok, message: ok ? 'Eingeloggt.' : 'Nicht eingeloggt.' });
  await endSession(browser);
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

// ---------- Kontrolle: erst exakt lesen, dann hinsehen ----------
//
// Stufe 1 (immer): den tatsächlichen Feldwert aus dem DOM ZURÜCKLESEN. Das ist exakt,
//   sofort und kostenlos – es fängt abgeschnittene oder gar nicht angekommene Eingaben.
// Stufe 2 (wenn ein Bildmodell konfiguriert ist): einen Blick auf die gerenderte Seite
//   werfen. Nur so werden Dinge sichtbar, die im DOM nicht stehen: Fehlerbanner,
//   Validierungshinweise, „Pflichtfeld fehlt".

/** Liest den echten Wert eines Feldes zurück (erste passende Auswahl gewinnt). */
async function readBack(page, selectors) {
  const list = Array.isArray(selectors) ? selectors : [selectors];
  for (const sel of list) {
    const v = await page.$eval(sel, (el) => (el.value !== undefined ? el.value : el.innerText))
      .catch(() => null);
    if (v !== null) return String(v);
  }
  return null;
}

function normalizeForCompare(s) {
  return String(s || '').replace(/\s+/g, ' ').trim().toLowerCase();
}

/**
 * Füllt ein Feld und PRÜFT das Ergebnis durch Zurücklesen. Weicht der Wert ab, wird
 * genau einmal korrigiert (Feld leeren, neu setzen). Liefert { ok, hinweis }.
 */
async function typeVerified(page, selectors, value, { label } = {}) {
  if (value == null || value === '') return { ok: false, hinweis: 'leer' };
  const written = await typeInto(page, selectors, value, { label });
  if (!written) return { ok: false, hinweis: 'Feld nicht gefunden' };

  let ist = await readBack(page, selectors);
  if (ist !== null && normalizeForCompare(ist) === normalizeForCompare(value)) {
    return { ok: true, hinweis: 'geprüft' };
  }
  // Abweichung → einmal sauber neu setzen (Wert direkt setzen ist zuverlässiger als Tippen).
  const list = Array.isArray(selectors) ? selectors : [selectors];
  for (const sel of list) {
    const done = await page.$eval(sel, (el, v) => {
      const proto = el.tagName === 'TEXTAREA' ? window.HTMLTextAreaElement.prototype : window.HTMLInputElement.prototype;
      const setter = Object.getOwnPropertyDescriptor(proto, 'value').set;
      setter.call(el, v);
      el.dispatchEvent(new Event('input', { bubbles: true }));
      el.dispatchEvent(new Event('change', { bubbles: true }));
      return true;
    }, String(value)).catch(() => false);
    if (done) break;
  }
  ist = await readBack(page, selectors);
  const ok = ist !== null && normalizeForCompare(ist) === normalizeForCompare(value);
  return { ok, hinweis: ok ? 'nach Korrektur geprüft' : 'Wert weicht ab: ' + String(ist).slice(0, 60) };
}

/**
 * Zeigt der Bild-KI die gerenderte Seite und stellt eine Frage.
 * job.ai = { baseUrl, model, visionModel, apiKey }. Fehlt das, wird still übersprungen –
 * die Automatisierung läuft dann ohne Sicht-Kontrolle weiter, statt abzubrechen.
 */
async function visionAsk(page, job, frage) {
  const ai = job && job.ai;
  const model = ai && (ai.visionModel || ai.model);
  if (!ai || !ai.baseUrl || !model) return '';
  const shot = await page.screenshot({ type: 'png', encoding: 'base64', fullPage: false }).catch(() => null);
  if (!shot) return '';
  const base = String(ai.baseUrl).replace(/\/+$/, '').replace(/\/v1$/, '').replace(/\/+$/, '');
  const headers = { 'Content-Type': 'application/json' };
  if (ai.apiKey) headers['Authorization'] = 'Bearer ' + ai.apiKey;
  try {
    const res = await fetch(base + '/api/chat', {
      method: 'POST',
      headers,
      body: JSON.stringify({
        model,
        messages: [{ role: 'user', content: frage, images: [shot] }],
        stream: false,
        think: false,
      }),
    });
    if (!res.ok) return '';
    const data = await res.json();
    return ((data.message && data.message.content) || '').trim();
  } catch (_) {
    return '';
  }
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
      // Sind Zugangsdaten hinterlegt, wird jetzt angemeldet – sonst bleibt es beim Hinweis.
      const anmeldung = await autoAnmelden(page);
      if (anmeldung.versucht && !anmeldung.zweiFaktor && await isLoggedIn(page)) {
        report({ stage: 'auth', progress: 0.1, message: 'Angemeldet.' });
      } else if (anmeldung.zweiFaktor) {
        throw new Error(anmeldung.hinweis);
      } else {
        throw new Error('Nicht bei KDP eingeloggt. Entweder in den Einstellungen Zugangsdaten '
          + 'hinterlegen oder einmal „KDP-Login" ausführen.');
      }
    }

    // BESTEHENDEN ENTWURF FORTSETZEN statt jedes Mal einen neuen anzulegen.
    // Ohne das entsteht bei jedem Versuch ein weiterer Entwurf im echten Konto –
    // genau das ist beim Einrichten mehrfach passiert. Kennt der Auftrag die Buch-ID
    // (job.bookId oder --book), wird dieser Entwurf geöffnet und weitergeführt.
    const bestehend = args.book || job.bookId || null;
    let formularDa = false;
    if (bestehend) {
      report({ stage: 'create', progress: 0.12, message: `Öffne bestehenden Entwurf ${bestehend} …` });
      await page.goto(`https://kdp.amazon.com/de_DE/title-setup/kindle/${bestehend}/details`,
        { waitUntil: 'domcontentloaded' }).catch(() => {});
      formularDa = await page.waitForSelector('#data-title, input[name="data[title]"]', { timeout: 45000 })
        .then(() => true).catch(() => false);
      if (!formularDa) {
        report({ stage: 'create', progress: 0.13,
          message: 'Bestehender Entwurf nicht erreichbar – lege stattdessen einen neuen an.' });
      }
    }

    if (!formularDa) {
    // Neues Kindle-eBook.
    //
    // WICHTIG: Die Formular-URL NICHT direkt aufrufen. Amazon hängt an solche Deeplinks
    // `max_auth_age=0` (erzwungene Neu-Anmeldung) und leitet auf die Anmeldeseite um –
    // dort gibt es die Felder gar nicht. Innerhalb der angemeldeten Sitzung über das
    // Bücherregal zu navigieren umgeht diese Stufe zuverlässig.
    report({ stage: 'create', progress: 0.12, message: 'Öffne Bücherregal und lege neues eBook an …' });
    await page.goto(KDP_BOOKSHELF, { waitUntil: 'domcontentloaded' }).catch(() => {});
    await new Promise(r => setTimeout(r, 2000));

    // Der echte Weg besteht aus ZWEI Schritten (an der deutschen Oberfläche geprüft):
    //   1. „+ Einen neuen Titel oder eine neue Serie erstellen"  →  /de_DE/create
    //   2. dort „eBook erstellen"                                →  Detailformular
    // Wichtig: „+ Kindle eBook erstellen" im Regal gehört zu einem BESTEHENDEN Buch und
    // führt NICHT zu einem neuen Titel – das war der ursprüngliche Fehlgriff.
    // Klickt das Element, dessen Text zum Muster passt. WICHTIG: Hilfe-Links werden
    // ausgeschlossen – auf der Auswahlseite steht neben dem Knopf „eBook erstellen" auch
    // der Hilfe-Link „digital auf Kindle" (/help/topic/...). Wird der geklickt, landet man
    // in der Hilfe statt im Formular. Knöpfe haben Vorrang vor Links.
    const klickeText = (muster) => page.evaluate((m) => {
      const re = new RegExp(m, 'i');
      const passt = (e) => {
        const t = (e.innerText || e.textContent || '').replace(/\s+/g, ' ').trim();
        if (!re.test(t)) return false;
        const href = e.getAttribute('href') || '';
        return !/\/help\/|helplink|help\/topic/i.test(href); // Hilfe-Links nie klicken
      };
      const buttons = [...document.querySelectorAll('button')].filter(passt);
      const links = [...document.querySelectorAll('a')].filter(passt);
      const treffer = buttons[0] || links[0];
      if (!treffer) return false;
      (treffer.closest('a,button') || treffer).click();
      return true;
    }, muster).catch(() => false);

    const schritt1 = await klickeText('neuen titel|neue serie');
    if (schritt1) await new Promise(r => setTimeout(r, 5000));

    // Schritt 2: Format wählen. Für das eBook heißt der Knopf „eBook erstellen"
    // (live verifiziert: führt nach title-setup/kindle/new/details), für das
    // gedruckte Buch „Taschenbuch erstellen" → title-setup/paperback/new/details.
    // Der Ablauf danach ist derselbe; nur die Dateien unterscheiden sich:
    // Taschenbuch verlangt ein Cover-PDF, kein JPEG.
    const taschenbuch = job.format === 'paperback' || !!args.paperback;
    const schritt2 = await klickeText(taschenbuch ? 'taschenbuch erstellen' : 'ebook erstellen');
    if (schritt2) await new Promise(r => setTimeout(r, 6000));

    if (!schritt1 && !schritt2) {
      // Ersatzweg: Deeplink versuchen (klappt, wenn keine Neu-Anmeldung verlangt wird).
      await page.goto(taschenbuch
        ? 'https://kdp.amazon.com/de_DE/title-setup/paperback/new/details'
        : 'https://kdp.amazon.com/de_DE/title-setup/kindle/new/details',
        { waitUntil: 'domcontentloaded' }).catch(() => {});
    }

    formularDa = await page.waitForSelector(
      '#data-title, #data-print-book-title, input[name="data[title]"]',
      { timeout: 45000 },
    ).then(() => true).catch(() => false);
    } // Ende: nur wenn kein bestehender Entwurf geöffnet wurde

    // Nicht weitermachen, wenn das Formular nie erschien – sonst wird „erfolgreich"
    // gemeldet, obwohl nichts eingetragen werden konnte.
    if (!formularDa) {
      const wo = page.url();
      const anmeldung = /\/ap\/signin|signin/.test(wo);
      throw new Error(anmeldung
        ? 'Amazon verlangt eine neue Anmeldung (Sicherheitsstufe für die Titelanlage). '
          + 'Bitte einmal in diesem Fenster bei KDP anmelden und den Upload erneut starten.'
        : 'Das eBook-Formular ist nicht erschienen (Seite: ' + wo.slice(0, 120) + ').');
    }

    // Details ausfüllen. PRIMÄR: die an der echten deutschen KDP-eBook-Seite LIVE
    // validierten IDs (#data-title etc.). Fallbacks: auto-kdp-Print + name-Attribute.
    report({ stage: 'metadata', progress: 0.25, message: 'Fülle Titel, Autor, Beschreibung (mit Kontrolle) …' });
    const gefuellt = [];   // was nachweislich drinsteht
    const probleme = [];   // was nicht sicher gesetzt werden konnte
    const merke = (name, r) => { (r.ok ? gefuellt : probleme).push(`${name}: ${r.hinweis}`); };

    merke('Titel', await typeVerified(page, ['#data-title', '#data-print-book-title', 'input[name="data[title]"]', 'input[name="title"]'], job.title, { label: 'Titel' }));
    if (job.subtitle) merke('Untertitel', await typeVerified(page, ['#data-subtitle', '#data-print-book-subtitle', 'input[name="data[subtitle]"]'], job.subtitle, { label: 'Untertitel' }));
    // Autor: KDP trennt Vor- und Nachname (eBook: data-primary-author-first/last-name).
    const _ap = String(job.author || '').trim().split(/\s+/).filter(Boolean);
    const authorLast = _ap.length > 1 ? _ap[_ap.length - 1] : (_ap[0] || '');
    const authorFirst = _ap.length > 1 ? _ap.slice(0, -1).join(' ') : '';
    if (authorFirst) merke('Autor-Vorname', await typeVerified(page, ['#data-primary-author-first-name', '#data-print-book-primary-author-first-name', 'input[name="data[primary_author][first_name]"]'], authorFirst, { label: 'Autor-Vorname' }));
    if (authorLast) merke('Autor-Nachname', await typeVerified(page, ['#data-primary-author-last-name', '#data-print-book-primary-author-last-name', 'input[name="data[primary_author][last_name]"]'], authorLast, { label: 'Autor-Nachname' }));
    // Beschreibung über den CKEditor (Instanz 'editor1' → setData; mit Fallbacks).
    const descOk = await fillDescription(page, job.description);
    (descOk ? gefuellt : probleme).push('Beschreibung: ' + (descOk ? 'gesetzt' : 'nicht gesetzt'));

    // Sprache setzen (Pflichtangabe, vorher nie behandelt).
    {
      const spr = await setzeSprache(page, job);
      if (spr === 'nicht-gefunden') gefuellt.push('Sprache: Dropdown nicht gefunden (KDP-Default bleibt)');
      else gefuellt.push('Sprache: ' + spr + ' (' + (job.language || 'Deutsch') + ')');
    }

    // Keywords (7 Slots) — eBook: data-keywords-0..6.
    report({ stage: 'keywords', progress: 0.4, message: 'Trage Keywords ein …' });
    const kws = (job.keywords || []).slice(0, 7);
    let kwOk = 0;
    for (let i = 0; i < kws.length; i++) {
      const r = await typeVerified(page, [`#data-keywords-${i}`, `#data-print-book-keywords-${i}`, `input[name="data[keywords][${i}]"]`], kws[i], { label: 'Keyword ' + (i + 1) });
      if (r.ok) kwOk++;
    }
    if (kwOk) gefuellt.push(`Keywords: ${kwOk}/${kws.length} geprüft`);
    if (kwOk < kws.length) probleme.push(`Keywords: ${kws.length - kwOk} nicht gesetzt`);
    report({ stage: 'metadata', progress: 0.45, message: `Geprüft eingetragen: ${gefuellt.join(' · ') || 'nichts'}` });

    // SELBSTPRÜFUNG: Das Programm ermittelt selbst, was noch fehlt (Rechte, Alters-
    // einstufung, Kategorie, leere Pflichtfelder), behebt es selbst und prüft erneut.
    // Vorher wurden diese Blocker einzeln entdeckt – jeder Fehlversuch kostete einen
    // überflüssigen Entwurf. Jetzt erledigt das der Ablauf in einem Durchgang.
    report({ stage: 'selbstpruefung', progress: 0.48, message: 'Prüfe Pflichtangaben und behebe Fehlendes …' });
    const pruef = await pruefeUndRepariere(page, job);
    if (pruef.behoben.length) gefuellt.push('Selbst behoben: ' + pruef.behoben.join(', '));
    for (const o of pruef.offen) probleme.push(o + ' nicht gesetzt');
    report({
      stage: 'selbstpruefung', progress: 0.55,
      message: pruef.sauber
        ? 'Alle Pflichtangaben stehen' + (pruef.behoben.length ? ' (behoben: ' + pruef.behoben.join(', ') + ')' : '') + '.'
        : 'Noch offen: ' + pruef.offen.join(', '),
    });

    // KI-Offenlegung (Pflicht bei KDP): job.aiDisclosure = 'ai-generated' | 'ai-assisted' | 'none'
    report({ stage: 'ai-disclosure', progress: 0.56, message: `KI-Kennzeichnung: ${job.aiDisclosure || 'ai-generated'}` });
    {
      const schritte = await setzeKiKennzeichnung(page, job);
      const ok = schritte.some((x) => /geklickt|bereits/.test(x));
      (ok ? gefuellt : probleme).push('KI-Kennzeichnung: ' + schritte.join(', '));
      report({ stage: 'ai-disclosure', progress: 0.58, message: 'KI-Kennzeichnung: ' + schritte.join(', ') });
    }

    // Inhalt und Preis NUR im echten Lauf. Beide Seiten gehören zu einem BEREITS
    // angelegten Titel und sind erst über „Speichern und fortfahren" erreichbar –
    // die früher benutzten Deeplinks .../kindle/new/content bzw. /new/pricing
    // liefern eine 404-Seite (von der Sicht-Kontrolle entdeckt).
    if (!dryRun) {
      report({ stage: 'content', progress: 0.6, message: 'Speichere Details und gehe zum Inhalt …' });
      const weiter1 = await page.$('#save-and-continue-announce, #save-and-continue');
      if (weiter1) {
        await weiter1.click().catch(() => {});
        await page.waitForNavigation({ waitUntil: 'domcontentloaded', timeout: 60000 }).catch(() => {});
        await new Promise(r => setTimeout(r, 4000));
      }

      // BEWEIS statt Annahme: Sind wir wirklich weitergekommen? Bleibt die Detailseite
      // stehen, hat KDP die Eingabe abgelehnt (Pflichtfeld). Dann noch einmal selbst
      // prüfen, beheben und erneut fortfahren – höchstens zweimal.
      for (let versuch = 1; versuch <= 2 && /\/details/.test(page.url()); versuch++) {
        const p2 = await pruefeUndRepariere(page, job, 2);
        if (p2.behoben.length) gefuellt.push('Nach Weiter behoben: ' + p2.behoben.join(', '));
        report({ stage: 'content', progress: 0.62,
          message: `Detailseite blieb stehen (Versuch ${versuch}) – behoben: ${p2.behoben.join(', ') || 'nichts'}` });
        const nochmal = await page.$('#save-and-continue-announce, #save-and-continue');
        if (!nochmal) break;
        await nochmal.click().catch(() => {});
        await page.waitForNavigation({ waitUntil: 'domcontentloaded', timeout: 60000 }).catch(() => {});
        await new Promise(r => setTimeout(r, 4000));
      }
      if (/\/details/.test(page.url())) {
        probleme.push('Inhaltsseite nicht erreicht (Detailseite meldet noch Pflichtfelder)');
      }

      // Manuskript + Cover auf der Inhaltsseite hochladen (Feld-IDs live erhoben).
      report({ stage: 'content', progress: 0.68, message: 'Lade Manuskript (EPUB) und Cover hoch …' });
      const manuskriptFeld = await page.$('#data-assets-interior-file-upload-AjaxInput, input[type="file"][accept*="epub"]');
      if (manuskriptFeld && job.epubPath && fs.existsSync(job.epubPath)) {
        await manuskriptFeld.uploadFile(job.epubPath).catch(() => {});
        report({ stage: 'content', progress: 0.74, message: 'Manuskript übergeben, warte auf Verarbeitung …' });
        const b = await warteAufUploadFertig(page, job.epubPath, 240000, (t) =>
          report({ stage: 'content', progress: 0.76, message: 'Manuskript: ' + t }));
        (b.ok ? gefuellt : probleme).push('Manuskript: ' + b.hinweis);
      } else {
        probleme.push('Manuskript: Upload-Feld nicht gefunden');
      }
      // Beim Taschenbuch verlangt KDP das Cover als druckfertiges PDF (Vorderseite,
      // Buchrücken und Rückseite in einer Datei) – ein JPEG wird dort abgelehnt.
      const coverDatei = (job.format === 'paperback' && job.wrapPdfPath && fs.existsSync(job.wrapPdfPath))
        ? job.wrapPdfPath : job.coverPath;
      // ZUERST auf "Bereits vorhandenes Cover hochladen" umschalten: Solange der
      // Cover Creator gewählt ist, existiert überhaupt kein Dateifeld.
      const coverWahl = await waehleEigenesCover(page);
      report({ stage: 'content', progress: 0.78, message: 'Cover-Quelle: ' + coverWahl });
      if (coverWahl === 'nicht-gefunden') probleme.push('Cover: Umschalter auf eigenes Cover nicht gefunden');
      const coverFeld = await page.$('#data-assets-cover-file-upload-AjaxInput, input[type="file"][accept*="pdf"], input[type="file"][accept*="jpeg"], input[type="file"][accept*="jpg"]');
      if (coverFeld && coverDatei && fs.existsSync(coverDatei)) {
        await coverFeld.uploadFile(coverDatei).catch(() => {});
        report({ stage: 'content', progress: 0.80, message: 'Cover übergeben, warte auf Verarbeitung …' });
        const b = await warteAufUploadFertig(page, coverDatei, 180000, (t) =>
          report({ stage: 'content', progress: 0.82, message: 'Cover: ' + t }));
        (b.ok ? gefuellt : probleme).push('Cover: ' + b.hinweis);
      } else if (job.coverPath) {
        probleme.push('Cover: Upload-Feld nicht gefunden');
      }

      // Pflicht-Häkchen: Ohne die Bestätigung speichert KDP die Inhaltsseite nicht,
      // und "Speichern und fortfahren" bleibt wirkungslos.
      {
        const b = await bestaetigeAngaben(page);
        report({ stage: 'content', progress: 0.85, message: 'Bestätigung: ' + b });
        if (b === 'nicht-gefunden') {
          // Nicht immer vorhanden – KDP zeigt sie nur nach einem neuen Upload.
          gefuellt.push('Bestätigung: nicht verlangt');
        } else {
          (/geklickt|bereits/.test(b) ? gefuellt : probleme).push('Bestätigung: ' + b);
        }
      }

      // Weiter zur Preisseite (ebenfalls über den Ablauf, nicht per Deeplink).
      report({ stage: 'pricing', progress: 0.86, message: `Gehe zum Preis und setze ${job.priceEUR} € …` });
      const weiter2 = await page.$('#save-and-continue-announce, #save-and-continue');
      if (weiter2) {
        await weiter2.click().catch(() => {});
        await page.waitForNavigation({ waitUntil: 'domcontentloaded', timeout: 60000 }).catch(() => {});
        await new Promise(r => setTimeout(r, 4000));
      }
      await typeInto(page, ['#data-pricing-print-list-price-EUR', 'input[name="priceEUR"]', 'input[name="listPrice"]'], String(job.priceEUR));
    }

    // Sicht-Kontrolle VOR dem Speichern. WICHTIG: Sie ist nur ein ZUSATZ-Hinweis und darf
    // die exakte DOM-Rücklesung niemals überstimmen – ein Bildmodell antwortet erfahrungs-
    // gemäß gern optimistisch („alles ausgefüllt"), auch wenn nichts eingetragen wurde.
    // Maßgeblich ist immer `probleme`; Vision meldet nur, was der DOM nicht zeigt
    // (Fehlerbanner, Validierungshinweise).
    report({ stage: 'review', progress: 0.92, message: 'Sehe mir die Seite an …' });
    const befund = await visionAsk(page, job,
      'Sieh dir diese Amazon-KDP-Seite an. Nenne AUSSCHLIESSLICH sichtbare Fehlermeldungen, rote '
      + 'Hinweise oder als fehlend markierte Pflichtfelder – Wort für Wort, wie sie dastehen. '
      + 'Bewerte nichts und vermute nichts. Ist keine solche Meldung zu sehen, antworte exakt: KEINE MELDUNG.');
    const befundSauber = /keine meldung/i.test(befund) ? '' : befund;
    if (befundSauber) {
      report({ stage: 'review', progress: 0.93, message: 'Sicht-Prüfung meldet: ' + befundSauber.slice(0, 200) });
    }

    const bilanz = (probleme.length ? ' Offen: ' + probleme.join(' · ') + '.' : '')
      + (befundSauber ? ' Seite meldet: ' + befundSauber.slice(0, 200) : '');

    // Ehrliches Gesamturteil: „ok" nur, wenn die Pflichtangaben nachweislich im Formular
    // stehen. Fehlt etwas, wird das gemeldet – nicht als Erfolg verkauft.
    const pflichtOk = probleme.length === 0;

    if (dryRun) {
      report({ stage: 'done', progress: 1, ok: pflichtOk, probleme,
        message: 'Testlauf beendet – NICHTS gespeichert.' + bilanz });
    } else {
      // ENTWURF speichern — NICHT veröffentlichen.
      report({ stage: 'save-draft', progress: 0.95, message: 'Speichere als Entwurf (kein Veröffentlichen) …' });
      const saveBtn = await page.$('#save-announce, button[data-action="save-draft"], #save-and-continue-announce');
      if (saveBtn) { await saveBtn.click().catch(() => {}); await new Promise(r => setTimeout(r, 4000)); }
      const draftUrl = page.url();
      // EHRLICHES ERGEBNIS. Hier stand `ok: true` fest verdrahtet - egal, ob Cover,
      // Kategorie oder KI-Kennzeichnung gesetzt werden konnten. `pflichtOk` wurde
      // berechnet, aber nur im Testlauf benutzt. Ein Entwurf mit fehlendem Cover galt
      // damit als voller Erfolg, und die offenen Punkte standen nur im Meldungstext -
      // für die Swift-Seite unsichtbar.
      //
      // Der Entwurf IST gespeichert (deshalb kein Fehler-Exit), aber `ok` sagt jetzt
      // die Wahrheit, und `probleme` steht maschinenlesbar in der Statusdatei.
      report({ stage: 'done', progress: 1, ok: pflichtOk, draftUrl, probleme,
        message: (pflichtOk
          ? 'Entwurf vollständig in KDP gespeichert. Bitte Preis prüfen und manuell veröffentlichen.'
          : 'Entwurf gespeichert, aber nicht alle Pflichtfelder gesetzt - vor dem Veröffentlichen prüfen.')
          + bilanz });
    }
  } catch (e) {
    report({ stage: 'error', progress: statusObj.progress, ok: false, error: String(e.message || e),
      message: 'Fehler: ' + String(e.message || e) });
    await endSession(browser);
    process.exit(1);
  }
  // Fenster kurz offen lassen zur Sichtkontrolle, dann schließen.
  await new Promise(r => setTimeout(r, 3000));
  await endSession(browser);
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
