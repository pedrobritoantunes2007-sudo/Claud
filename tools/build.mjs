// Monta o jogo pronto na pasta jogo/ (abre com dois cliques no jogo/index.html, sem servidor).
//   node tools/build.mjs            -> monta uma vez
//   node tools/build.mjs --watch    -> monta de novo a cada mudança
//   node tools/build.mjs --serve    -> também abre um servidor em http://localhost:8080
// Tudo o que o jogo lê (cachorros, dados, sons curtos, fontes) vai dentro do game.js/index.html, porque o
// navegador não deixa uma página aberta do disco (file://) carregar arquivos com fetch. As músicas ficam em
// jogo/assets/music (o <audio> do navegador consegue abrir do disco).
import * as esbuild from 'esbuild';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const OUT = path.join(ROOT, 'jogo');
const args = new Set(process.argv.slice(2));

function copyDir(from, to) {
	fs.mkdirSync(to, { recursive: true });
	for (const entry of fs.readdirSync(from, { withFileTypes: true })) {
		const a = path.join(from, entry.name);
		const b = path.join(to, entry.name);
		if (entry.isDirectory()) copyDir(a, b);
		else if (!fs.existsSync(b) || fs.statSync(a).mtimeMs > fs.statSync(b).mtimeMs || fs.statSync(a).size !== fs.statSync(b).size) fs.copyFileSync(a, b);
	}
}

function fontFace(name, file) {
	const data = fs.readFileSync(path.join(ROOT, 'assets', 'fonts', file)).toString('base64');
	return `@font-face{font-family:'${name}';src:url(data:font/woff2;base64,${data}) format('woff2');font-display:block}`;
}

function writeHtml() {
	let html = fs.readFileSync(path.join(ROOT, 'src', 'index.html'), 'utf8');
	const css = fs
		.readdirSync(path.join(ROOT, 'src', 'ui'))
		.filter((f) => f.endsWith('.css'))
		.sort((a, b) => (a === 'estilo.css' ? -1 : b === 'estilo.css' ? 1 : a.localeCompare(b)))
		.map((f) => fs.readFileSync(path.join(ROOT, 'src', 'ui', f), 'utf8'))
		.join('\n');
	const fonts = fontFace('Luckiest Guy', 'LuckiestGuy.woff2') + fontFace('Fredoka One', 'FredokaOne.woff2');
	const icon = fs.readFileSync(path.join(ROOT, 'assets', 'icones', 'icone_192.png')).toString('base64');
	html = html
		.replace('/*FONTES*/', fonts)
		.replace('/*ESTILO*/', css)
		.replace('ICONE_PNG', `data:image/png;base64,${icon}`)
		.replace('VERSAO', Date.now().toString(36));
	fs.mkdirSync(OUT, { recursive: true });
	fs.writeFileSync(path.join(OUT, 'index.html'), html);
}

function copyAssets() {
	copyDir(path.join(ROOT, 'assets', 'music'), path.join(OUT, 'assets', 'music'));
	copyDir(path.join(ROOT, 'assets', 'ilhas'), path.join(OUT, 'ilhas'));
}

const htmlPlugin = {
	name: 'html',
	setup(build) {
		build.onEnd((result) => {
			if (result.errors.length) return;
			writeHtml();
			copyAssets();
			const size = fs.statSync(path.join(OUT, 'game.js')).size;
			console.log(`[build] ok ${new Date().toLocaleTimeString()}  game.js ${(size / 1024 / 1024).toFixed(2)} MB`);
		});
	},
};

const options = {
	entryPoints: [path.join(ROOT, 'src', 'main.js')],
	bundle: true,
	format: 'iife',
	outfile: path.join(OUT, 'game.js'),
	minify: !args.has('--dev'),
	sourcemap: args.has('--dev') ? 'inline' : false,
	target: ['es2020'],
	loader: { '.json': 'json', '.mp3': 'base64' },
	legalComments: 'none',
	logLevel: 'warning',
	plugins: [htmlPlugin],
};

if (args.has('--watch') || args.has('--serve')) {
	const ctx = await esbuild.context(options);
	await ctx.watch();
	if (args.has('--serve')) {
		const { port } = await ctx.serve({ servedir: OUT, port: 8080 });
		console.log(`[build] jogo em http://localhost:${port}`);
	}
} else {
	await esbuild.build(options);
}
