import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import puppeteer from 'puppeteer-core';
import { ensureKDPLogin, inspectKDPLogin } from '../auth-core.js';

const executablePath = [
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/Applications/Chromium.app/Contents/MacOS/Chromium',
].find(path => fs.existsSync(path));

test('Browserfixture: Code eingeben, bestaetigen, ohne zweite Navigation fortsetzen',
  { skip: !executablePath, timeout: 20000 }, async () => {
    const browser = await puppeteer.launch({ executablePath, headless: true });
    try {
      const page = await browser.newPage();
      await page.setRequestInterception(true);
      let navigations = 0;
      page.on('request', request => {
        if (request.isNavigationRequest()) navigations++;
        void request.respond({ status: 200, contentType: 'text/html', body:
          '<form><input id="auth-mfa-otpcode"><button>Bestätigen</button></form>'
          + '<script>document.querySelector("form").onsubmit=e=>{e.preventDefault();'
          + 'document.body.innerHTML="<main id=dp-bookshelf>Bücherregal</main>"}</script>' });
      });
      let attempts = 0;
      let inputTask;
      const statuses = [];
      await ensureKDPLogin(page, browser, {
        attemptLogin: async () => { attempts++; },
        timeoutMs: 10000, pollMs: 50,
        report: status => {
          statuses.push(status);
          if (status.stage === 'auth-wait' && !inputTask) {
            inputTask = (async () => {
              assert.equal((await inspectKDPLogin(page)).authenticated, false);
              await page.type('#auth-mfa-otpcode', '123456');
              await page.click('button');
            })();
          }
        },
      });
      await inputTask;
      assert.equal(navigations, 1);
      assert.equal(attempts, 1);
      assert.equal(statuses.at(-1).stage, 'auth');
      assert.equal((await inspectKDPLogin(page)).authenticated, true);
      await page.setContent('<nav><a class="a-nav-link">Startseite</a></nav>');
      assert.equal((await inspectKDPLogin(page)).authenticated, false);
    } finally {
      await browser.close();
    }
  });
