import { createRequire } from 'node:module';
import { fileURLToPath, pathToFileURL } from 'node:url';
import path from 'node:path';
import fs from 'node:fs/promises';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const root = path.dirname(fileURLToPath(import.meta.url));
const browser = await chromium.launch({ headless: true });
try {
  const page = await browser.newPage({ deviceScaleFactor: 1 });
  for (const key of ['original', 'a', 'b', 'c']) {
    const svg = await fs.readFile(path.join(root, 'concepts', key + '.svg'), 'utf8');
    for (const size of [1024, 120, 60]) {
      await page.setViewportSize({ width: size, height: size });
      await page.setContent(`<html style="margin:0"><body style="margin:0">${svg}<style>svg{display:block;width:${size}px;height:${size}px}</style></body></html>`);
      await page.screenshot({ path: path.join(root, 'exports', `${key}-${size}.png`) });
    }
  }
  await page.setViewportSize({ width: 1680, height: 1400 });
  await page.goto(pathToFileURL(path.join(root, 'index.html')).href);
  await page.evaluate(async () => {
    await document.fonts.ready;
    await Promise.all([...document.images].map(image => image.decode()));
  });
  await page.locator('.board').screenshot({ path: path.join(root, 'comparison.png') });
  await page.locator('.desktop').screenshot({ path: path.join(root, 'desktop-comparison.png') });
  const report = { node: process.version, chromium: browser.version(), deviceScaleFactor: 1, platform: process.platform, architecture: process.arch };
  await fs.writeFile(path.join(root, 'render-environment.json'), JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report));
} finally { await browser.close(); }
