// Foto das ilhas montadas pelo código de verdade: node tools/preview/islands_render.js dump.json foto.png [opcoes.json]
// opções: { w, h, sky, view: { dist, pol, az, ty, dx, dz, shadow }, top: { cx, cz, span, ocean, transparent } }
const http = require('http');
const fs = require('fs');
const path = require('path');
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
// (o Chromium do ambiente muda de versão: usa o primeiro que existir; nenhum = o padrão do Playwright)
const CHROME = ['/opt/pw-browsers/chromium-1194/chrome-linux/chrome', '/opt/pw-browsers/chromium-1243/chrome-linux64/chrome'].find((p) => require('fs').existsSync(p));

const [, , input, output, optsFile] = process.argv;
const opts = optsFile ? JSON.parse(fs.readFileSync(optsFile, 'utf8')) : {};
const data = JSON.parse(fs.readFileSync(input, 'utf8'));
const dir = __dirname;
const server = http.createServer((req, res) => {
  const file = path.join(dir, decodeURIComponent(req.url.split('?')[0]));
  if (!file.startsWith(dir) || !fs.existsSync(file)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'Content-Type': file.endsWith('.js') ? 'text/javascript' : 'text/html' });
  fs.createReadStream(file).pipe(res);
});
server.listen(0, '127.0.0.1', async () => {
  const port = server.address().port;
  const browser = await chromium.launch({ executablePath: CHROME, args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  try {
    const page = await browser.newPage({ viewport: { width: opts.w || 1000, height: opts.h || 620 } });
    page.on('pageerror', (e) => console.log('[page error]', e.message));
    page.on('console', (m) => { if (m.type() === 'error') console.log('[page]', m.text()); });
    await page.goto(`http://127.0.0.1:${port}/islands_render.html`);
    await page.waitForFunction(() => window.ready === true, null, { timeout: 30000 });
    await page.evaluate(([d, o]) => window.renderIslands(d, o), [data, opts]);
    await page.waitForTimeout(200);
    // (foto de cima com o mar transparente: o PNG guarda a transparência)
    await page.screenshot({ path: output, omitBackground: !!(opts.top && opts.top.transparent) });
    console.log('ok:', output);
  } finally { await browser.close(); server.close(); }
});
