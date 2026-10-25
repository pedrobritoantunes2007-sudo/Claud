// SETTINGS (som, gráficos, câmera) e o GUIA de como jogar.
import { openWindow, h, button, confirmBox } from './janela.js';
import { Input } from '../core/input.js';

export function openSettings(app) {
	const w = openWindow({ title: '⚙️ SETTINGS', small: true });
	const s = app.save.settings;
	const slider = (label, key) => {
		const row = h('div', 'linha-config');
		const input = h('input');
		input.type = 'range';
		input.min = '0';
		input.max = '1';
		input.step = '0.05';
		input.value = String(s[key]);
		input.oninput = () => {
			s[key] = Number(input.value);
			app.applySettings();
		};
		row.append(h('span', null, label), input);
		return row;
	};
	const toggle = (label, key) => {
		const row = h('div', 'linha-config');
		const b = button(s[key] ? 'ON' : 'OFF', s[key] ? '' : 'cinza', () => {
			s[key] = !s[key];
			b.textContent = s[key] ? 'ON' : 'OFF';
			b.className = 'btn ' + (s[key] ? '' : 'cinza');
			app.applySettings();
		});
		row.append(h('span', null, label), b);
		return row;
	};
	w.body.append(slider('🎵 Music', 'music'), slider('🔊 Sound effects', 'sfx'));
	const q = h('div', 'linha-config');
	const opts = h('div');
	opts.style.display = 'flex';
	opts.style.gap = '6px';
	for (const [k, label] of [['auto', 'AUTO'], ['high', 'HIGH'], ['medium', 'MED'], ['low', 'LOW']]) {
		const b = button(label, s.quality === k ? 'ouro' : 'cinza', () => {
			s.quality = k;
			app.applySettings(true);
			for (const x of opts.children) x.className = 'btn cinza';
			b.className = 'btn ouro';
		});
		b.style.fontSize = '14px';
		b.style.padding = '6px 10px';
		opts.appendChild(b);
	}
	q.append(h('span', null, '🖥️ Graphics'), opts);
	w.body.append(q, toggle('📳 Camera shake', 'shake'), toggle('🏷️ Names above dogs', 'names'));
	w.body.appendChild(controlsHelp());
	const reset = h('div', 'linha-config');
	reset.append(
		h('span', null, '🗑️ Erase all progress'),
		button('RESET', 'vermelho', () => confirmBox('RESET EVERYTHING?', 'All your dogs, cash and islands will be erased forever.', 'ERASE', () => app.resetAll())),
	);
	w.body.appendChild(reset);
	return w;
}

function controlsHelp() {
	const box = h('div', 'teclas-ajuda');
	const rows = Input.touch
		? [['🕹️', 'Left stick: walk'], ['👆', 'Drag the screen: turn the camera'], ['🐾', 'Big button: attack'], ['2 3 4', 'Powers'], ['💨', 'Dash'], ['⬆️', 'Jump'], ['🏃', 'Run'], ['🕊️', 'Fly (dogs with wings)']]
		: [
				['W A S D', 'Walk'],
				['Shift', 'Run'],
				['Space', 'Jump (and fly up)'],
				['Mouse', 'Aim (your dog looks at the arrow)'],
				['Click / 1', 'Attack (paw combo or mouth shot)'],
				['2 3 4', 'Powers (unlock at Lv.10 / 25 / 50)'],
				['Q', 'Dash'],
				['F', 'Fly (dogs with wings)'],
				['C', 'Fly down'],
				['E', 'Talk / buy egg / interact'],
				['Right mouse', 'Turn the camera'],
				['Wheel', 'Zoom'],
				['Ctrl', 'Camera lock (aim at the center)'],
				['H', 'Guide'],
			];
	for (const [k, t] of rows) box.append(h('kbd', null, k), h('span', null, t));
	return box;
}

export function openGuide(app) {
	const w = openWindow({ title: '📖 HOW TO PLAY' });
	const cards = [
		['🐶', 'You ARE your dog', 'Walk, run, jump and fight as your dog. Bigger and rarer dogs are stronger.'],
		['📜', 'Missions pay the cash', 'Talk to the ❗ Mission Master next to the portal of each island. Defeat wild dogs (or the 👑 champion) to earn Cash and XP.'],
		['⚔️', 'Fight!', 'Click to attack where your arrow points: paw, paw, BITE! Some dogs shoot from far away. Q = dash.'],
		['🔓', 'Powers by level', 'Your dog learns power 2 at Lv.10, power 3 at Lv.25 and the SUPREME power 4 at Lv.50 (Epic and up).'],
		['🆚', 'Elements', 'Fire beats Ice and Nature, Water beats Fire... Strong hits say SUPER! (+30%), weak ones say WEAK (-20%).'],
		['🥚', 'Eggs', 'Buy eggs on each island (EGGS menu). Better islands sell better eggs with rarer dogs.'],
		['🗺️', 'Islands', 'Unlock the next island with Cash in the MAP menu. Each island has stronger wild dogs and a giant champion.'],
		['🏡', 'Pawville & the Arena', 'Pawville is the town where you start. The Arena portal takes you to the island with all the island portals.'],
	];
	const grid = h('div', 'lista-ilhas');
	for (const [e, t, d] of cards) {
		const c = h('div', 'carta-ilha');
		c.style.setProperty('--cor', '#ffe066');
		c.append(h('div', 'faixa'), h('div', 'emoji', e), h('h4', null, t), h('div', 'sub', d));
		grid.appendChild(c);
	}
	w.body.appendChild(grid);
	w.body.appendChild(controlsHelp());
	void app;
	return w;
}
