// Tira a "foto-catálogo" dos cachorros: abre render.html no Chromium (Playwright) e salva um PNG.
// Uso: node tools/preview/render.js dogs.json saida.png [opções.json]
//   opções: { cols, card (largura do card px), size (px da foto), title, view: {yaw, pitch, zoom},
//             labels: { id: { label, rarityLabel, labelColor:[r,g,b], note, views:[{yaw,pitch,zoom,note}] } } }
const http = require('http');
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const [, , input, output, optsFile] = process.argv;
const opts = optsFile ? JSON.parse(fs.readFileSync(optsFile, 'utf8')) : {};
const dogs = JSON.parse(fs.readFileSync(input, 'utf8'));
for (const d of dogs) Object.assign(d, (opts.labels || {})[d.id] || {});
const order = opts.order;
const list = order ? order.map(id => dogs.find(d => d.id === id)).filter(Boolean) : dogs;

const dir = __dirname;
const server = http.createServer((req, res) => {
  const file = path.join(dir, decodeURIComponent(req.url.split('?')[0]));
  if (!file.startsWith(dir) || !fs.existsSync(file)) { res.writeHead(404); return res.end(); }
  const type = file.endsWith('.js') ? 'text/javascript' : 'text/html';
  res.writeHead(200, { 'Content-Type': type });
  fs.createReadStream(file).pipe(res);
});
server.listen(0, '127.0.0.1', async () => {
  const port = server.address().port;
  const browser = await chromium.launch({ executablePath: process.env.CHROME || '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  try {
    const page = await browser.newPage({ viewport: { width: 1400, height: 900 }, deviceScaleFactor: 1 });
    page.on('console', m => { if (m.type() === 'error') console.log('[page]', m.text()); });
    page.on('pageerror', e => console.log('[page error]', e.message));
    await page.goto(`http://127.0.0.1:${port}/render.html`);
    await page.waitForFunction(() => window.ready === true, null, { timeout: 30000 });
    await page.evaluate(([l, o]) => window.buildSheet(l, o), [list, opts]);
    await page.waitForTimeout(300);
    const sheet = await page.$('#sheet');
    await sheet.screenshot({ path: output });
    console.log('ok:', output);
  } finally {
    await browser.close();
    server.close();
  }
});
