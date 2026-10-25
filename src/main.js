// Dog Fighter — ponto de partida do jogo.
import { initRender } from './core/render.js';
import { startGallery } from './teste/galeria.js';
import { startIslandTest } from './teste/ilhaTeste.js';
import { startGameTest } from './teste/jogoTeste.js';
import { App } from './app.js';

function setLoading(frac, text) {
	const bar = document.getElementById('carregando-barra');
	if (bar) bar.style.width = Math.round(frac * 100) + '%';
	const t = document.getElementById('carregando-texto');
	if (t && text) t.textContent = text;
}

function hideLoading() {
	const el = document.getElementById('carregando');
	if (!el) return;
	el.classList.add('sumindo');
	setTimeout(() => el.remove(), 700);
}

async function boot() {
	const params = new URLSearchParams(location.search);
	setLoading(0.2, 'Loading dogs...');
	await document.fonts.ready;
	initRender(document.getElementById('jogo'), params.get('qualidade') || 'high');
	if (params.get('teste') === 'jogo') {
		await startGameTest(params);
		setLoading(1, 'Ready!');
		hideLoading();
		return;
	}
	if (params.get('teste') === 'ilha') {
		await startIslandTest(params);
		setLoading(1, 'Ready!');
		hideLoading();
		return;
	}
	if (params.get('teste') === 'galeria') {
		startGallery(params);
		setLoading(1, 'Ready!');
		hideLoading();
		return;
	}
	setLoading(0.6, 'Building the island...');
	const app = new App();
	window.__app = app;
	await app.start();
}

boot().catch((err) => {
	console.error(err);
	const t = document.getElementById('carregando-texto');
	if (t) t.textContent = 'Error: ' + err.message;
});
