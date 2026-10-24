import { createRequire } from 'node:module';
import { fileURLToPath, pathToFileURL } from 'node:url';
import path from 'node:path';
import fs from 'node:fs/promises';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const root = path.dirname(fileURLToPath(import.meta.url));
const manifest = JSON.parse(await fs.readFile(path.join(root, 'manifest.json'), 'utf8'));
const browser = await chromium.launch({ headless: true });
try {
  const page = await browser.newPage({ viewport: { width: 1024, height: 1024 }, deviceScaleFactor: 1 });
  for (const variant of manifest.variants) {
    const source = await fs.readFile(path.join(root, variant.id, 'icon.svg'), 'utf8');
    await page.setContent(`<html style="margin:0"><body style="margin:0;width:1024px;height:1024px">${source}</body></html>`);
    const png = await page.screenshot({ type: 'png' });
    await fs.writeFile(path.join(root, variant.id, 'icon-1024.png'), png);
    for (const size of [120, 60]) {
      // Render from the vector at each target size rather than stretching a bitmap.
      await page.setViewportSize({ width: size, height: size });
      await page.locator('svg').evaluate((svg, n) => { svg.setAttribute('width', n); svg.setAttribute('height', n); }, size);
      await page.screenshot({ path: path.join(root, variant.id, `icon-${size}.png`), type: 'png' });
    }
    await page.setViewportSize({ width: 1024, height: 1024 });
  }
  await fs.mkdir(path.join(root, 'previews'), { recursive: true });
  await page.setViewportSize({ width: 1600, height: 1000 });
  await page.goto(pathToFileURL(path.join(root, 'index.html')).href);
  await page.evaluate(async () => { await document.fonts.ready; await Promise.all([...document.images].map(img => img.decode())); });
  const names = { 'overview-board': 'overview', 'background-board': 'backgrounds-120-60', 'details-board': 'source-and-recommended' };
  const dimensions = {};
  for (const [selector, name] of Object.entries(names)) {
    const locator = page.locator(`.${selector}`);
    dimensions[name] = await locator.boundingBox();
    await locator.screenshot({ path: path.join(root, 'previews', `${name}.png`) });
  }
  const output = { renderer: 'Playwright Chromium, headless, deviceScaleFactor=1', browserVersion: browser.version(), nodeVersion: process.version, previewDimensions: dimensions };
  await fs.writeFile(path.join(root, 'previews', 'render-environment.json'), JSON.stringify(output, null, 2) + '\n');
  console.log(JSON.stringify(output));
} finally {
  await browser.close();
}
