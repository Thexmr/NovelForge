import test from 'node:test';
import assert from 'node:assert/strict';
import { isAuthenticatedKDPPage, waitForKDPLogin, ensureKDPLogin } from '../auth-core.js';

test('nur geschuetzte KDP-Seiten mit Formularnachweis gelten als angemeldet', () => {
  const proof = { hasProof: true, challenge: null };
  assert.equal(isAuthenticatedKDPPage('https://kdp.amazon.com/de_DE/bookshelf', proof), true);
  assert.equal(isAuthenticatedKDPPage('https://kdp.amazon.com/en_US/title-setup/kindle/123/details', proof), true);
  for (const url of ['https://kdp.amazon.com/', 'https://kdp.amazon.com/ap/signin',
    'https://kdp.amazon.com/help/topic/test', 'https://kdp.amazon.com.evil.test/de_DE/bookshelf',
    'http://kdp.amazon.com/de_DE/bookshelf', 'about:blank']) {
    assert.equal(isAuthenticatedKDPPage(url, proof), false, url);
  }
  assert.equal(isAuthenticatedKDPPage('https://kdp.amazon.com/de_DE/bookshelf', { hasProof: false }), false);
  assert.equal(isAuthenticatedKDPPage('https://kdp.amazon.com/de_DE/bookshelf', { ...proof, challenge: 'code' }), false);
});

function fixture(states, { closesAt = Infinity } = {}) {
  let time = 0;
  const messages = [];
  const page = { isClosed: () => time >= closesAt, bringToFront: async () => {} };
  const browser = { isConnected: () => true };
  return {
    page, browser, messages,
    options: {
      timeoutMs: 6000, pollMs: 1000, now: () => time,
      sleep: async ms => { time += ms; },
      inspect: async () => states[Math.min(time / 1000, states.length - 1)],
      report: status => messages.push(status),
    },
  };
}

test('2FA wartet im selben Browser und setzt erst nach bestaetigter Anmeldung fort', async () => {
  const f = fixture([{ challenge: 'code' }, { challenge: 'code' }, { authenticated: true }]);
  await waitForKDPLogin(f.page, f.browser, f.options);
  assert.equal(f.messages[0].stage, 'auth-wait');
  assert.match(f.messages[0].message, /Bestätigungscode/);
  assert.equal(f.messages.at(-1).stage, 'auth');
  assert.equal(f.messages.at(-1).ok, undefined, 'Login darf nicht den gesamten Upload als erfolgreich markieren');
});

test('falscher oder abgelaufener Code bleibt korrigierbar, ohne neuen Loginversuch', async () => {
  const f = fixture([{ challenge: 'code' }, { challenge: 'code' }, { challenge: 'code' }, { authenticated: true }]);
  await waitForKDPLogin(f.page, f.browser, f.options);
  assert.equal(f.messages.filter(x => x.stage === 'auth').length, 1);
});

test('Captcha wird nur dem Menschen angezeigt und niemals automatisch geloest', async () => {
  const f = fixture([{ challenge: 'captcha' }, { authenticated: true }]);
  await waitForKDPLogin(f.page, f.browser, f.options);
  assert.match(f.messages[0].message, /Sicherheitsprüfung/);
});

test('geschlossene Fenster beenden den Wartezustand mit eindeutiger Ursache', async () => {
  const f = fixture([{ challenge: 'code' }], { closesAt: 1000 });
  await assert.rejects(waitForKDPLogin(f.page, f.browser, f.options), /geschlossen/);
});

test('Zeitablauf meldet keinen Erfolg und nennt die verstrichene Wartezeit', async () => {
  const f = fixture([{ challenge: 'code' }]);
  await assert.rejects(waitForKDPLogin(f.page, f.browser, f.options), /Zeitlimit/);
  assert.equal(f.messages.some(x => x.stage === 'auth'), false);
});

test('Seitenwechsel waehrend Codeeingabe ist kein Abbruch', async () => {
  const f = fixture([{ challenge: 'code' }, { authenticated: true }]);
  const inspect = f.options.inspect;
  let calls = 0;
  f.options.inspect = async () => {
    if (calls++ === 0) throw Error('Execution context was destroyed');
    return inspect();
  };
  await waitForKDPLogin(f.page, f.browser, f.options);
  assert.equal(f.messages.at(-1).stage, 'auth');
});

test('ein Anmeldeversuch, eine Navigation, danach denselben Auftrag fortsetzen', async () => {
  const f = fixture([{ challenge: 'code' }, { authenticated: true }]);
  let navigations = 0;
  let attempts = 0;
  let continued = 0;
  f.page.goto = async () => { navigations++; };
  await ensureKDPLogin(f.page, f.browser, {
    ...f.options, attemptLogin: async () => { attempts++; },
  });
  continued++;
  assert.equal(navigations, 1);
  assert.equal(attempts, 1);
  assert.equal(continued, 1);
});

test('bestehende Anmeldung verwendet keine Zugangsdaten erneut', async () => {
  const f = fixture([{ authenticated: true }]);
  f.page.goto = async () => {};
  await ensureKDPLogin(f.page, f.browser, {
    ...f.options, attemptLogin: async () => assert.fail('unnoetige Neuanmeldung'),
  });
  assert.equal(f.messages.length, 0);
});
