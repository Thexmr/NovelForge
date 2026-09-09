export const KDP_BOOKSHELF = 'https://kdp.amazon.com/de_DE/bookshelf';

export function isAuthenticatedKDPPage(url, { hasProof = false, challenge = null } = {}) {
  try {
    const parsed = new URL(url);
    return parsed.protocol === 'https:' && parsed.hostname === 'kdp.amazon.com'
      && /^\/(?:[a-z]{2}_[A-Z]{2}\/)?(?:bookshelf(?:\/|$)|title-setup\/)/.test(parsed.pathname)
      && hasProof && !challenge;
  } catch { return false; }
}

export async function inspectKDPLogin(page) {
  const evidence = await page.evaluate(() => {
    const visible = selector => [...document.querySelectorAll(selector)].some(el =>
      el.getClientRects().length && getComputedStyle(el).visibility !== 'hidden');
    const challenge = visible('#auth-mfa-otpcode, input[name="otpCode"], #cvf-input-code, input[autocomplete="one-time-code"]')
      ? 'code'
      : visible('#captchacharacters, input[name="cvf_captcha_input"], iframe[src*="captcha"]')
        ? 'captcha'
        : visible('#ap_email, #ap_email_login, #ap_password, input[name="email"], input[name="password"]')
          ? 'signin' : null;
    const hasProof = visible('#dp-bookshelf, [data-testid="bookshelf"], a[href*="/title-setup/"], a[href*="/signout"], a[href*="/logout"]');
    return { challenge, hasProof };
  });
  return { ...evidence, authenticated: isAuthenticatedKDPPage(page.url(), evidence) };
}

// Observe only: never navigate away from a code field, read a code, or resubmit credentials.
export async function waitForKDPLogin(page, browser, {
  report = () => {}, inspect = inspectKDPLogin, timeoutMs = 30 * 60 * 1000,
  pollMs = 1500, now = Date.now, sleep = ms => new Promise(resolve => setTimeout(resolve, ms)),
} = {}) {
  const deadline = now() + timeoutMs;
  let previousChallenge;
  let lastReportAt = -Infinity;
  await page.bringToFront().catch(() => {});
  while (now() < deadline) {
    if (!browser.isConnected() || page.isClosed()) {
      throw new Error('Amazon-Anmeldefenster wurde geschlossen. Anmeldung nicht abgeschlossen; kein neuer Entwurf angelegt.');
    }
    let state;
    try { state = await inspect(page); } catch {
      // Amazon replaces the execution context while redirecting after sign-in.
      await sleep(pollMs);
      continue;
    }
    if (state.authenticated) {
      report({ stage: 'auth', progress: 0.1, message: 'Amazon-Anmeldung bestätigt. Vorgang wird automatisch fortgesetzt.' });
      return;
    }
    if (state.challenge !== previousChallenge || now() - lastReportAt >= 30000) {
      const instruction = state.challenge === 'code'
        ? 'Bestätigungscode im Amazon-Fenster eingeben und bestätigen.'
        : state.challenge === 'captcha'
          ? 'Amazon verlangt eine Sicherheitsprüfung. Bitte selbst im Amazon-Fenster abschließen.'
          : 'Bitte die Anmeldung im Amazon-Fenster abschließen.';
      report({ stage: 'auth-wait', progress: 0.08,
        message: `${instruction} Danach geht es automatisch weiter. Wartezeit verbleibend: ${Math.ceil((deadline - now()) / 60000)} Min.` });
      previousChallenge = state.challenge;
      lastReportAt = now();
    }
    await sleep(pollMs);
  }
  throw new Error(`Amazon-Anmeldung nicht abgeschlossen: Zeitlimit von ${Math.ceil(timeoutMs / 60000)} Min. erreicht. Kein neuer Entwurf angelegt.`);
}

export async function ensureKDPLogin(page, browser, { attemptLogin, report, ...waitOptions }) {
  await page.goto(KDP_BOOKSHELF, { waitUntil: 'domcontentloaded', timeout: 60000 });
  const inspect = waitOptions.inspect || inspectKDPLogin;
  if ((await inspect(page)).authenticated) return;
  try { await attemptLogin(page); } catch {
    report({ stage: 'auth-wait', progress: 0.08,
      message: 'Automatische Anmeldung nicht abgeschlossen. Bitte im Amazon-Fenster prüfen.' });
  }
  await waitForKDPLogin(page, browser, { report, ...waitOptions });
}
