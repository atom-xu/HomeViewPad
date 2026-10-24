import {createRequire} from 'node:module';
import {fileURLToPath,pathToFileURL} from 'node:url';
import path from 'node:path';
import fs from 'node:fs/promises';
const require=createRequire(import.meta.url);
const {chromium}=require('playwright');
const root=path.dirname(fileURLToPath(import.meta.url));
const manifest=JSON.parse(await fs.readFile(path.join(root,'manifest.json'),'utf8'));
const browser=await chromium.launch({headless:true});
try{
 const page=await browser.newPage({viewport:{width:1024,height:1024},deviceScaleFactor:1});
 for(const v of manifest.variants){
  const svg=await fs.readFile(path.join(root,v.id,'icon.svg'),'utf8');
  for(const size of [1024,120,60]){
   await page.setViewportSize({width:size,height:size});
   await page.setContent(`<html style="margin:0"><body style="margin:0">${svg}</body></html>`);
   await page.locator('svg').evaluate((el,n)=>{el.setAttribute('width',n);el.setAttribute('height',n);},size);
   await page.screenshot({path:path.join(root,v.id,`icon-${size}.png`)});
  }
 }
 await fs.mkdir(path.join(root,'previews'),{recursive:true});
 await page.setViewportSize({width:1600,height:1000});
 await page.goto(pathToFileURL(path.join(root,'index.html')).href);
 await page.evaluate(async()=>{await document.fonts.ready;await Promise.all([...document.images].map(im=>im.decode()));});
 for(const [selector,name] of [['overview-board','overview'],['background-board','backgrounds-120-60'],['evolution-board','evolution']]){
  await page.locator(`.${selector}`).screenshot({path:path.join(root,'previews',`${name}.png`)});
 }
 const environment={browserVersion:browser.version(),nodeVersion:process.version,deviceScaleFactor:1,renderer:'Playwright Chromium, headless'};
 await fs.writeFile(path.join(root,'previews/render-environment.json'),JSON.stringify(environment,null,2)+'\n');
 console.log(JSON.stringify(environment));
}finally{await browser.close();}
