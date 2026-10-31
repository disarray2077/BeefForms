const assert = require('node:assert/strict');
const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');
const { chromium } = require('playwright');

async function main() {
  const directory = path.resolve(process.argv[2] || path.join(__dirname, 'build/Debug_wasm32/BeefForms.WasmTests'));
  const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.data': 'application/octet-stream' };
  const server = http.createServer((request, response) => {
    const file = path.resolve(directory, '.' + new URL(request.url, 'http://localhost').pathname);
    if (!file.startsWith(directory + path.sep)) {
      response.writeHead(403).end();
      return;
    }
    fs.readFile(file, (error, data) => {
      if (error) {
        response.writeHead(404).end();
        return;
      }
      response.setHeader('Content-Type', types[path.extname(file)] || 'application/octet-stream');
      response.end(data);
    });
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  let browser;
  try {
    browser = await chromium.launch({ executablePath: process.env.CHROME_PATH || undefined, headless: true });
    const context = await browser.newContext({ viewport: { width: 420, height: 800 }, isMobile: true, hasTouch: true });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.goto(`http://127.0.0.1:${server.address().port}/WasmTests.html`);
    await page.waitForFunction(() => document.querySelector('#output')?.value.includes('READY'));
    const output = () => page.locator('#output').inputValue();
    assert.ok((await output()).includes('PASS: Emscripten main-loop scheduling, cancellation, and restart'));
    const canvas = page.locator('canvas');
    async function tap(x, y) {
      const box = await canvas.boundingBox();
      const size = await canvas.evaluate(element => ({ width: element.width, height: element.height }));
      await page.touchscreen.tap(box.x + box.width * x / size.width, box.y + box.height * y / size.height);
    }
    await tap(30, 23);
    const dialog = page.getByRole('dialog').first();
    await dialog.waitFor();
    const input = page.locator('dialog input');
    assert.equal(await input.inputValue(), '12');
    assert.ok(await input.evaluate(element => document.activeElement === element));
    await input.fill('abc345');
    assert.ok(!(await output()).includes('FILTERED:'));
    await page.getByRole('button', { name: 'Done', exact: true }).click();
    await page.waitForFunction(() => document.querySelector('#output').value.includes('FILTERED:345'));
    await tap(30, 23);
    assert.equal(await input.inputValue(), '345');
    await input.fill('999');
    await page.getByRole('button', { name: 'Cancel', exact: true }).click();
    await tap(30, 23);
    assert.equal(await input.inputValue(), '345');
    await input.fill('');
    await page.getByRole('button', { name: 'Done', exact: true }).click();
    await tap(30, 23);
    assert.equal(await input.inputValue(), '');
    await page.keyboard.press('Escape');
    await tap(30, 85);
    const area = page.locator('dialog textarea');
    assert.equal(await area.inputValue(), 'one\ntwo');
    await area.fill('é😀\nthree');
    await area.dispatchEvent('compositionstart');
    await page.getByRole('button', { name: 'Done', exact: true }).click();
    assert.equal(await page.locator('dialog').count(), 1);
    assert.ok(!(await output()).includes('MULTILINE:'));
    await area.dispatchEvent('compositionend');
    await page.getByRole('button', { name: 'Done', exact: true }).click();
    await page.waitForFunction(() => document.querySelector('#output').value.includes('MULTILINE:é😀|three'));
    await tap(30, 172);
    assert.equal(await page.locator('dialog').count(), 0);
    await tap(30, 222);
    await input.fill('close');
    await page.getByRole('button', { name: 'Done', exact: true }).click();
    await page.waitForFunction(() => document.querySelector('#output').value.includes('CLOSED'));
    assert.equal(await page.locator('dialog').count(), 0);
    assert.deepEqual(errors, []);
    console.log('PASS: touch editor, deferred filtering, Cancel, deletion, multiline Unicode, read-only, and close during filtering.');
  } finally {
    if (browser) await browser.close();
    await new Promise(resolve => server.close(resolve));
  }
}

main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
