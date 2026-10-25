// Som: músicas do projeto (tema principal, arena, boss) com troca suave, jingles (nível, ovo, vitória) e os
// efeitos do sfx_pack (um áudio só com todos os sons, tocando pedaços — igual ao jogo do Roblox).
import SFX_PACK from '../../assets/sfx/sfx_pack.mp3';
import { SFX_REGIONS } from '../data/jogo.js';

const MUSIC = { Main: 'assets/music/tema_principal.mp3', Arena: 'assets/music/arena.mp3', Boss: 'assets/music/boss.mp3' };
const JINGLES = { Hatch: 'assets/music/jingle_ovo.mp3', LevelUp: 'assets/music/jingle_level_up.mp3', Victory: 'assets/music/jingle_vitoria.mp3' };
const MUSIC_VOLUME = 0.45;
const JINGLE_VOLUME = 0.6;
const CROSSFADE = 1.6;

export class Audio {
	constructor() {
		this.musicVol = 0.5;
		this.sfxVol = 0.8;
		this.ctx = null;
		this.buffer = null;
		this.tracks = {};
		this.current = null;
		this.want = null;
		this.duck = 1;
		this.listener = { x: 0, y: 0, z: 0 };
		this.unlocked = false;
		this.lastPlay = {};
	}

	// precisa de um clique/toque antes (regra dos navegadores)
	unlock() {
		if (this.unlocked) return;
		this.unlocked = true;
		try {
			const AC = window.AudioContext || window.webkitAudioContext;
			this.ctx = new AC();
			this.master = this.ctx.createGain();
			this.master.connect(this.ctx.destination);
			const bin = atob(SFX_PACK);
			const bytes = new Uint8Array(bin.length);
			for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
			this.ctx.decodeAudioData(bytes.buffer).then((buf) => (this.buffer = buf)).catch(() => {});
		} catch (e) {
			this.ctx = null;
		}
		if (this.want) this.playMusic(this.want, true);
	}

	setVolumes(music, sfx) {
		this.musicVol = music;
		this.sfxVol = sfx;
		for (const t of Object.values(this.tracks)) t.target = t === this.current ? 1 : 0;
	}

	track(name) {
		let t = this.tracks[name];
		if (!t) {
			const a = new window.Audio(MUSIC[name]);
			a.loop = true;
			a.preload = 'auto';
			a.volume = 0;
			t = this.tracks[name] = { a, level: 0, target: 0 };
		}
		return t;
	}

	playMusic(name, force = false) {
		this.want = name;
		if (!this.unlocked) return;
		const t = this.track(name);
		if (this.current === t && !force) return;
		for (const o of Object.values(this.tracks)) o.target = 0;
		t.target = 1;
		this.current = t;
		if (t.a.paused) {
			t.a.play().catch(() => {});
		}
	}

	jingle(name) {
		if (!this.unlocked || !JINGLES[name]) return;
		const a = new window.Audio(JINGLES[name]);
		a.volume = Math.min(1, JINGLE_VOLUME * this.musicVol * 1.6);
		a.play().catch(() => {});
		this.duck = 0.35;
		const dur = name === 'Victory' ? 3500 : 2600;
		clearTimeout(this.duckTimer);
		this.duckTimer = setTimeout(() => (this.duck = 1), dur);
	}

	// efeito do pacote (nome da região do SfxConfig); at = lutador ou {x,y,z} (som 3D: mais baixo de longe)
	sfx(name, at, vol = 1) {
		let gain = vol;
		if (at && at.x !== undefined) {
			const d = Math.hypot(at.x - this.listener.x, (at.y || 0) - this.listener.y, at.z - this.listener.z);
			gain *= Math.max(0, 1 - d / 120);
			if (gain < 0.03) return;
		}
		this.sfx2(name, gain);
	}

	sfxAt(name, x, y, z, vol = 1) {
		this.sfx(name, { x, y, z }, vol);
	}

	sfx2(name, vol = 1) {
		if (!this.ctx || !this.buffer) return;
		const r = SFX_REGIONS[name];
		if (!r) return;
		// o mesmo som muitas vezes no mesmo instante vira barulho: limita
		const now = this.ctx.currentTime;
		if (this.lastPlay[name] && now - this.lastPlay[name] < 0.05) return;
		this.lastPlay[name] = now;
		const src = this.ctx.createBufferSource();
		src.buffer = this.buffer;
		src.playbackRate.value = 0.94 + Math.random() * 0.12;
		const g = this.ctx.createGain();
		g.gain.value = Math.min(1, vol * this.sfxVol * 0.9);
		src.connect(g);
		g.connect(this.master);
		// o mp3 começa ~25 ms depois (atraso do codificador)
		src.start(0, Math.max(0, r[0] + 0.025), r[1]);
	}

	update(dt, listener) {
		if (listener) this.listener = listener;
		if (this.ctx && this.ctx.state === 'suspended' && this.unlocked) this.ctx.resume().catch(() => {});
		for (const t of Object.values(this.tracks)) {
			const k = Math.min(1, dt / CROSSFADE);
			t.level += (t.target - t.level) * Math.max(k, t.target > t.level ? k : k * 1.5);
			if (Math.abs(t.target - t.level) < 0.01) t.level = t.target;
			const v = t.level * MUSIC_VOLUME * this.musicVol * this.duck;
			t.a.volume = Math.max(0, Math.min(1, v));
			if (t.level <= 0 && !t.a.paused && t !== this.current) t.a.pause();
		}
	}
}
