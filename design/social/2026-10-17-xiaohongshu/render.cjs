// Local editable HTML/CSS rendering. Screenshots remain untouched source files.
const fs=require('fs'),path=require('path'),{chromium}=require('playwright');
(async()=>{
 const dir=__dirname, evidence=path.resolve(dir,'../../../.validation/local/xiaohongshu-20261017');
 const browser=await chromium.launch({headless:true});const page=await browser.newPage({viewport:{width:1500,height:2000},deviceScaleFactor:1});
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto('file://'+path.join(dir,'cards.html'));
 await page.evaluate(()=>Promise.all([...document.images].map(i=>i.decode())));await page.evaluate(()=>document.fonts.ready);
 const cards=await page.locator('.card').all();const checks=[];
 for(const card of cards){const id=await card.getAttribute('id');await card.screenshot({path:path.join(dir,'exports',id+'.png')});
 checks.push(await card.evaluate(el=>{
 const r=el.getBoundingClientRect();const imgs=[...el.querySelectorAll('.device img')].map(i=>({src:i.getAttribute('src'),natural:[i.naturalWidth,i.naturalHeight],rendered:[i.width,i.height],loaded:i.complete&&i.naturalWidth>0,ratioError:Math.abs(i.width/i.height-2420/1668)}));
 const textNodes=[...el.querySelectorAll('h1,h2,p,.foot,.mast,.three-notes section')];
 const overflows=textNodes.filter(n=>{const q=n.getBoundingClientRect();return q.left<r.left-.5||q.right>r.right+.5||q.top<r.top-.5||q.bottom>r.bottom+.5||n.scrollWidth>n.clientWidth+1}).map(n=>({text:n.textContent.trim(),scroll:n.scrollWidth,client:n.clientWidth}));
 return {id:el.id,width:r.width,height:r.height,images:imgs,textOverflows:overflows}
 }));}
 fs.mkdirSync(evidence,{recursive:true});fs.writeFileSync(path.join(evidence,'render-checks.json'),JSON.stringify({renderer:'Playwright Chromium',timestamp:new Date().toISOString(),errors,cards:checks},null,2));
 await page.setViewportSize({width:1680,height:1730});await page.goto('file://'+path.join(dir,'overview.html'));await page.evaluate(()=>Promise.all([...document.images].map(i=>i.decode())));await page.locator('.sheet').screenshot({path:path.join(dir,'overview.png')});
 await browser.close();console.log(JSON.stringify({count:checks.length,errors,overflows:checks.flatMap(c=>c.textOverflows),imageRatios:checks.map(c=>[c.id,...c.images.map(i=>i.ratioError)])},null,2));
})().catch(e=>{console.error(e);process.exit(1)});
