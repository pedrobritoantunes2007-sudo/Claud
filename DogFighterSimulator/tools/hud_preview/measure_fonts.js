// Mede a largura de cada letra das fontes do HUD (Luckiest Guy e Fredoka One) no Chromium e salva
// fonts_metrics.json: o mini-Roblox usa isso no TextService:GetTextSize (igual ao Roblox, que usa as mesmas fontes).
// Uso: node measure_fonts.js
const http = require('http');
const fs = require('fs');
const path = require('path');
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const dir = __dirname;
const server = http.createServer((req, res) => {
  const file = path.join(dir, decodeURIComponent(req.url.split('?')[0]));
  if (!file.startsWith(dir) || !fs.existsSync(file) || !fs.statSync(file).isFile()) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'Content-Type': file.endsWith('.woff2') ? 'font/woff2' : 'text/html' });
  fs.createReadStream(file).pipe(res);
});
const CHARS = [];
for (let c = 32; c < 127; c++) CHARS.push(String.fromCharCode(c));
CHARS.push('★', '☆', '▲', '·', '→', '✦', '●', '•', '…', 'é', 'ã', 'ç', '×');
server.listen(0, '127.0.0.1', async () => {
  const port = server.address().port;
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
  try {
    const page = await browser.newPage();
    await page.goto(`http://127.0.0.1:${port}/fonts.html`);
    const out = await page.evaluate(async (chars) => {
      await document.fonts.load('100px "Fredoka One"');
      await document.fonts.load('100px "Luckiest Guy"');
      const c = document.createElement('canvas').getContext('2d');
      const res = {};
      for (const [key, fam] of [['FredokaOne', 'Fredoka One'], ['LuckiestGuy', 'Luckiest Guy']]) {
        c.font = `100px "${fam}"`;
        const adv = {};
        for (const ch of chars) adv[ch] = c.measureText(ch).width;
        res[key] = adv;
      }
      return res;
    }, CHARS);
    fs.writeFileSync(path.join(dir, 'fonts_metrics.json'), JSON.stringify(out));
    console.log('ok', Object.keys(out.FredokaOne).length, 'letras; A =', out.FredokaOne['A'].toFixed(1), '/', out.LuckiestGuy['A'].toFixed(1));
  } finally { await browser.close(); server.close(); }
});
