// O mundo: carrega uma ilha (vila Pawville, ilha principal ou ilha de raridade), põe água e o céu de cada lugar,
// e mantém os pedaços perto do jogador montados.
import { loadIsland } from './ilhaDados.js';
import { IslandView } from './ilhaMalha.js';
import { Physics } from './fisica.js';
import { createWater, updateWater } from './agua.js';
import { R, setAtmosphere } from '../core/render.js';

// céu e neblina de cada lugar (cores do "ar" de cada ilha do projeto Roblox)
const ATMOSPHERE = {
	default: { top: '#3f9cf0', mid: '#9ed8ff', bottom: '#dff3ff', fog: '#a9ddff', fogNear: 220, fogFar: 760, hemiSky: '#dff1ff', hemiGround: '#6a7a52', sun: '#fff4de', sunIntensity: 2.1, hemiIntensity: 1.7 },
	uncommon: { top: '#7fb6e8', mid: '#cfe6f7', bottom: '#f2f8ff', fog: '#dcebf7', fogNear: 160, fogFar: 640, hemiSky: '#eef6ff', hemiGround: '#8a96a8', sun: '#ffffff', sunIntensity: 2.0, hemiIntensity: 1.8 },
	rare: { top: '#5aa6e0', mid: '#f3d9a8', bottom: '#ffe9c4', fog: '#f1d7aa', fogNear: 180, fogFar: 700, hemiSky: '#fff1d6', hemiGround: '#a07850', sun: '#fff0d0', sunIntensity: 2.2, hemiIntensity: 1.6 },
	epic: { top: '#2f8fe6', mid: '#93d6f5', bottom: '#d8f6ff', fog: '#a7e0f2', fogNear: 200, fogFar: 720, hemiSky: '#e4f6ff', hemiGround: '#6b7a4a', sun: '#fff2d2', sunIntensity: 2.1, hemiIntensity: 1.7 },
	legendary: { top: '#3b1c22', mid: '#a5492b', bottom: '#f08b3c', fog: '#8e4a35', fogNear: 120, fogFar: 520, hemiSky: '#ffb08a', hemiGround: '#3a2a2a', sun: '#ffc08a', sunIntensity: 1.9, hemiIntensity: 1.5 },
	mythic: { top: '#0d0628', mid: '#3b2477', bottom: '#7a55c8', fog: '#2e1f5c', fogNear: 160, fogFar: 640, hemiSky: '#c8b8ff', hemiGround: '#2a2244', sun: '#e8dcff', sunIntensity: 1.9, hemiIntensity: 1.6 },
	divine: { top: '#f0a33a', mid: '#ffd98a', bottom: '#fff1cf', fog: '#ffe2a6', fogNear: 180, fogFar: 680, hemiSky: '#fff2d0', hemiGround: '#a88a50', sun: '#ffe7b0', sunIntensity: 2.2, hemiIntensity: 1.7 },
	cloud: { top: '#4fa6f5', mid: '#bfe4ff', bottom: '#ffffff', fog: '#d9efff', fogNear: 240, fogFar: 900, hemiSky: '#ffffff', hemiGround: '#b8d2ea', sun: '#ffffff', sunIntensity: 2.0, hemiIntensity: 1.9 },
};

export class World {
	constructor() {
		this.id = null;
		this.data = null;
		this.view = null;
		this.physics = null;
		this.water = null;
		this.quality = 'high';
	}

	async load(id, onProgress) {
		this.unload();
		onProgress && onProgress(0.1);
		const data = await loadIsland(id);
		onProgress && onProgress(0.5);
		this.id = id;
		this.data = data;
		this.view = new IslandView(data, R.scene);
		this.view.setQuality(this.quality);
		onProgress && onProgress(0.8);
		this.physics = new Physics(data);
		if (id !== 'cloud') {
			this.water = createWater();
			R.scene.add(this.water);
		}
		setAtmosphere(ATMOSPHERE[id] || ATMOSPHERE.default);
		onProgress && onProgress(1);
		return data;
	}

	unload() {
		if (this.view) this.view.dispose();
		if (this.water) {
			R.scene.remove(this.water);
			this.water.geometry.dispose();
			this.water.material.dispose();
		}
		this.view = null;
		this.physics = null;
		this.water = null;
		this.data = null;
		this.id = null;
	}

	setQuality(q) {
		this.quality = q;
		if (this.view) this.view.setQuality(q);
	}

	// x, z = onde está o jogador (monta os pedaços em volta)
	update(dt, t, x, z, camX, camZ) {
		if (!this.view) return;
		this.view.update(x, z, 5);
		if (this.water) updateWater(this.water, t, camX, camZ);
	}

	// modelo da ilha pelo nome (centro da caixa, no espaço da ilha)
	model(name) {
		const list = this.data?.info.models || [];
		return list.find((m) => m[0] === name) || null;
	}
}
