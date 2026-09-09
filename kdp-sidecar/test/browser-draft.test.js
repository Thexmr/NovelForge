import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import puppeteer from 'puppeteer-core';
import { saveDraftAndVerify } from '../draft-core.js';

const executablePath = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
test('Speichern im Browser: fehlend, unsicher, unbestaetigt und bestaetigt unterscheiden',
  { skip: !fs.existsSync(executablePath), timeout: 15000 }, async () => {
    const browser = await puppeteer.launch({ executablePath, headless: true });
    try {
      const page = await browser.newPage();
      await page.setRequestInterception(true);
      page.on('request', request => void request.respond({ status: 200, contentType: 'text/html', body: '<main></main>' }));
      await page.goto('https://kdp.amazon.com/de_DE/title-setup/kindle/A123/pricing');
      await assert.rejects(saveDraftAndVerify(page), /nicht gefunden/);
      await page.setContent('<button id="save-announce">Veröffentlichen</button>');
      await assert.rejects(saveDraftAndVerify(page), /sicherer/);
      await page.setContent('<button id="save-and-continue-announce">Save and continue</button>');
      await assert.rejects(saveDraftAndVerify(page), /nicht gefunden/);
      await page.setContent('<button id="save">Save as draft</button><p role="status">Draft saved</p>');
      await assert.rejects(saveDraftAndVerify(page, { timeoutMs: 250 }), /nicht bestätigt/);
      await page.setContent('<button id="save" onclick="document.querySelector(\'p\').textContent=\'Entwurf erfolgreich gespeichert\'">Als Entwurf speichern</button><p role="status"></p>');
      assert.match(await saveDraftAndVerify(page, { timeoutMs: 2000 }), /A123\/pricing$/);
    } finally { await browser.close(); }
  });
