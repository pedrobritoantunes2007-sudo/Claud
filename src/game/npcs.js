// Pessoas e pontos de conversa de cada ilha: ❗ Mission Master (missões), estande do ovo, Prof. Barkley
// (roleta) e placas dos portais. Perto de um deles aparece a dica "E" no HUD.
import * as THREE from 'three';
import { makePerson, animatePerson, makeBang } from '../world/pessoa.js';
import { ISLANDS, EGGS } from '../data/jogo.js';
import { formatCash } from '../core/util.js';
import { CONFIG } from '../data/jogo.js';

const TALK = 14;

export class Npcs {
	constructor(app) {
		this.app = app;
		this.group = new THREE.Group();
		this.list = [];
		this.labels = [];
	}

	clear() {
		this.group.removeFromParent();
		this.group = new THREE.Group();
		this.list = [];
	}

	build(game) {
		this.clear();
		game.scene.add(this.group);
		const id = game.islandId;
		const L = game.local;
		const ground = (x, z) => game.groundAt(x, z, 200);
		if (L.def && L.def.QuestGiver) {
			const cf = L.def.QuestGiver;
			const x = cf[0], z = cf[2];
			const person = makePerson({ shirt: '#2f8f6a', vest: '#3a2a1a', pants: '#5a4630', hat: 'explorer', hatColor: '#c9a46a', hair: '#5a3a22', beard: '#5a3a22' });
			person.position.set(x, ground(x, z), z);
			// olha na direção do CFrame (LookVector = -Z da matriz)
			person.rotation.y = Math.atan2(cf[5], cf[11]);
			const bang = makeBang('#ffd34d', '!');
			bang.position.set(0, 7.3, 0);
			person.add(bang);
			this.group.add(person);
			this.list.push({ kind: 'quest', person, bang, x, z, y: person.position.y, name: 'Mission Master', color: '#ffd34d' });
		}
		// estande do ovo (modelo "Ovo" da ilha)
		const egg = game.world.model('Ovo');
		const def = ISLANDS.List[id];
		if (egg && def && def.Egg) {
			this.list.push({ kind: 'egg', x: egg[2][0], z: egg[2][2], y: ground(egg[2][0], egg[2][2]), egg: def.Egg, name: EGGS[def.Egg].Name, color: '#ffb81c', r: 18 });
		}
		if (id === 'village') {
			const x = 0, z = -4;
			const prof = makePerson({ shirt: '#f4f4f4', sleeve: '#f4f4f4', pants: '#4a4a6a', hat: 'grad', hair: '#d0d0d8', beard: '#e8e8ee', glasses: true, skin: '#f0c8a0' });
			prof.position.set(x, ground(x, z), z);
			prof.rotation.y = Math.PI;
			const bang = makeBang('#7fd6ff', '?');
			bang.position.set(0, 7.3, 0);
			prof.add(bang);
			this.group.add(prof);
			this.list.push({ kind: 'prof', person: prof, bang, x, z, y: prof.position.y, name: 'Prof. Barkley', color: '#7fd6ff' });
		}
		// placas dos portais (nome em cima)
		for (const p of game.portals) {
			const s = makeSign(p.label, game.portalLocked && game.portalLocked(p));
			s.position.set(p.x, ground(p.x, p.z) + 17, p.z);
			this.group.add(s);
		}
	}

	update(dt, game) {
		const p = game.player;
		let near = null, best = Infinity;
		for (const n of this.list) {
			if (n.person) animatePerson(n.person, dt, p ? new THREE.Vector3(p.x, p.y, p.z) : null);
			if (n.bang) n.bang.position.y = 7.3 + Math.sin(performance.now() / 300) * 0.25;
			if (!p || p.dead) continue;
			const d = Math.hypot(p.x - n.x, p.z - n.z);
			if (d < (n.r || TALK) && d < best && Math.abs(p.y - n.y) < 12) {
				near = n;
				best = d;
			}
		}
		this.near = near;
		return near;
	}

	hintFor(n, save) {
		if (!n) return null;
		if (n.kind === 'quest') return save.quest && save.quest.island === this.app.game.islandId ? '📜 Mission Master <small>(your mission)</small>' : '📜 Talk to the <b>Mission Master</b>';
		if (n.kind === 'egg') return `🥚 Buy <b>${n.name}</b> · ${formatCash(CONFIG.EGG_PRICE[n.egg])}`;
		if (n.kind === 'prof') return '🎓 Talk to <b>Prof. Barkley</b>';
		return null;
	}
}

function makeSign(text, locked) {
	const c = document.createElement('canvas');
	c.width = 512;
	c.height = 128;
	const g = c.getContext('2d');
	g.fillStyle = locked ? 'rgba(60,40,60,0.85)' : 'rgba(36,28,64,0.9)';
	roundRect(g, 6, 14, 500, 100, 26);
	g.fill();
	g.lineWidth = 8;
	g.strokeStyle = '#1b1430';
	g.stroke();
	g.font = '54px "Luckiest Guy", sans-serif';
	g.textAlign = 'center';
	g.textBaseline = 'middle';
	g.fillStyle = locked ? '#b8b0d0' : '#ffe066';
	g.fillText((locked ? '🔒 ' : '') + text, 256, 68, 470);
	const tex = new THREE.CanvasTexture(c);
	tex.colorSpace = THREE.SRGBColorSpace;
	const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex, transparent: true }));
	s.scale.set(16, 4, 1);
	return s;
}

function roundRect(g, x, y, w, h, r) {
	g.beginPath();
	g.moveTo(x + r, y);
	g.arcTo(x + w, y, x + w, y + h, r);
	g.arcTo(x + w, y + h, x, y + h, r);
	g.arcTo(x, y + h, x, y, r);
	g.arcTo(x, y, x + w, y, r);
	g.closePath();
}
