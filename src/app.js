// O APLICATIVO: junta o jogo (mundo + luta) com as telas, o save, as missões, os ovos, as viagens e o som.
import * as THREE from 'three';
import { R, setQuality, render } from './core/render.js';
import { Input, initInput, onKey } from './core/input.js';
import { Audio } from './core/audio.js';
import { Game } from './game/jogo.js';
import { Npcs } from './game/npcs.js';
import { loadSave, writeSave, resetSave, addDog, equippedDog } from './game/save.js';
import { Hud } from './ui/hud.js';
import { TouchControls } from './ui/toque.js';
import { openDogsMenu } from './ui/menuCaes.js';
import { openEggsMenu, eggIsland } from './ui/menuOvos.js';
import { openMapMenu, canUnlock } from './ui/menuMapa.js';
import { openSettings, openGuide } from './ui/menuConfig.js';
import { openDialog, closeDialog, dialogOpen } from './ui/dialogo.js';
import { windowOpen, closeWindow } from './ui/janela.js';
import { hatchScreen, rouletteScreen, titleScreen, curtain } from './ui/telasEspeciais.js';
import { CONFIG, ISLANDS, SPECIES, EGGS, RARITY, rollEgg, rollRoulette, eggOdds, skillsOf, hasSupreme, powerUnlockLevel, xpToNext } from './data/jogo.js';
import { formatCash } from './core/util.js';

const VERSION = '1.0';
const SPIN_PRICE = { Normal: 1000, Lucky: 15000 };

export class App {
	constructor() {
		this.version = VERSION;
		this.uiRoot = document.getElementById('ui');
		this.save = loadSave();
		this.audio = new Audio();
		this.game = new Game(this.uiRoot);
		this.game.audio = this.audio;
		this.npcs = new Npcs(this);
		this.hud = new Hud(this, this.uiRoot);
		this.hud.show(false);
		this.game.hud = this.hud;
		this.game.portalLocked = (p) => this.portalLocked(p);
		this.touch = new TouchControls(this, this.uiRoot);
		this.curtain = curtain(this);
		this.playing = false;
		this.saveClock = 0;
		this.wire();
	}

	// ---------------------------------------------------------------- começo
	async start() {
		initInput(R.renderer.domElement);
		this.applySettings(true);
		// fundo da tela de entrada: a Pawville vista de cima, girando devagar
		await this.game.world.load('village');
		this.game.islandId = 'village';
		this.game.local = this.game.world.data.info;
		this.showcase = true;
		this.loop();
		hideLoading();
		await titleScreen(this);
		this.audio.unlock();
		this.audio.playMusic('Main');
		this.showcase = false;
		if (!this.save.dogs.length) {
			// primeiro cachorro: roleta do Prof. Barkley (3 giros grátis)
			const sp = await rouletteScreen(this, {
				spins: Math.max(1, this.save.spins),
				roll: () => rollRoulette('Normal'),
			});
			this.save.spins = 0;
			const dog = addDog(this.save, sp, 1);
			this.save.equipped = dog.id;
			this.save.tutorial = 1;
			this.saveNow();
		}
		const dog = equippedDog(this.save);
		this.game.setPlayerDog(dog.sp, dog.lv, { uid: dog.id, xp: dog.xp, name: dog.name });
		this.hud.setDog(this.game.player, dog);
		const where = this.save.islands[this.save.lastIsland] || ['village', 'main'].includes(this.save.lastIsland) ? this.save.lastIsland : 'village';
		await this.travel(where, { first: true });
		this.playing = true;
		this.hud.show(true);
		this.touch.setVisible(Input.touch);
		if (this.save.tutorial === 1) {
			this.hud.toast('🐶 Welcome to <b>Pawville</b>!', 'ouro', 4);
			setTimeout(() => this.hud.toast('Go through the 🌻 <b>PUPPY MEADOWS</b> portal to start fighting!', '', 6), 1500);
		}
	}

	wire() {
		const g = this.game;
		g.on('toast', (msg, kind) => this.hud.toast(msg, kind));
		g.on('portal', (p) => this.onPortal(p));
		g.on('kill', (t) => this.onKill(t));
		g.on('xp', () => this.syncDog());
		g.on('levelup', (p, ups) => this.onLevelUp(p, ups));
		g.on('ko', () => {
			this.hud.toast('💫 Your dog was knocked out!', 'erro');
		});
		g.on('respawn', () => this.hud.showKO(false));
		g.on('island', (id) => this.onIsland(id));
		onKey((k) => this.onKeyDown(k));
		window.addEventListener('beforeunload', () => this.saveNow());
		document.addEventListener('visibilitychange', () => {
			if (document.hidden) this.saveNow();
		});
	}

	onKeyDown(k) {
		if (!this.playing) return;
		if (k === 'e' && !windowOpen()) this.interact();
		else if (k === 'h') this.openMenu('help');
		else if (k === 'tab' || k === 'm') this.openMenu('map');
		else if (k === 'ctrl' && !Input.touch) {
			// trava da câmera: mira no meio da tela, mouse gira a câmera
			if (document.pointerLockElement) document.exitPointerLock();
			else R.renderer.domElement.requestPointerLock && R.renderer.domElement.requestPointerLock();
		}
	}

	// ---------------------------------------------------------------- laço
	loop() {
		let last = performance.now();
		const frame = () => {
			const now = performance.now();
			const dt = Math.min(0.1, (now - last) / 1000);
			last = now;
			this.tick(dt);
			requestAnimationFrame(frame);
		};
		requestAnimationFrame(frame);
	}

	tick(dt) {
		const g = this.game;
		if (this.showcase) {
			// tela de entrada: câmera voando em volta da vila
			const t = performance.now() / 1000;
			const r = 260;
			R.camera.position.set(Math.cos(t * 0.05) * r, 150, Math.sin(t * 0.05) * r + 40);
			R.camera.lookAt(0, 10, 40);
			g.world.update(dt, t, 0, 40, R.camera.position.x, R.camera.position.z);
			render();
			return;
		}
		const paused = (windowOpen() || this.modal) && !this.travelling;
		g.paused = paused || this.travelling;
		g.frame(dt);
		if (!this.playing) return;
		const p = g.player;
		this.audio.update(dt, p ? { x: p.x, y: p.y, z: p.z } : null);
		if (paused) return;
		this.hud.update(dt);
		this.touch.sync(this.hud);
		const near = this.npcs.update(dt, g);
		this.hud.showHint(dialogOpen() ? null : this.npcs.hintFor(near, this.save));
		if (!near && dialogOpen() && this.dialogNpc) closeDialog();
		if (p && p.dead) this.hud.showKO(true, g.koUntil - g.time);
		// música: Boss quando o campeão está brigando com você
		if (!this.travelling) {
			const champ = g.champion && !g.champion.dead && g.champion.target === p;
			this.audio.playMusic(champ ? 'Boss' : ['village', 'main'].includes(g.islandId) ? 'Main' : 'Arena');
		}
		this.save.stats.playTime += dt;
		this.saveClock += dt;
		if (this.saveClock > 10) {
			this.saveClock = 0;
			this.syncDog();
			writeSave(this.save);
		}
		this.updateNext();
	}

	// ---------------------------------------------------------------- save
	saveNow() {
		this.syncDog();
		writeSave(this.save, true);
	}

	syncDog() {
		const p = this.game.player;
		if (!p || !p.dogUid) return;
		const d = this.save.dogs.find((x) => x.id === p.dogUid);
		if (d) {
			d.lv = p.level;
			d.xp = Math.floor(p.xp || 0);
		}
	}

	refreshDog() {
		const d = equippedDog(this.save);
		if (d && this.game.player) this.hud.setDog(this.game.player, d);
	}

	equipDog(uid) {
		this.syncDog();
		const d = this.save.dogs.find((x) => x.id === uid);
		if (!d) return;
		this.save.equipped = uid;
		const old = this.game.player;
		const hpFrac = old ? old.hp / old.maxHp : 1;
		const f = this.game.setPlayerDog(d.sp, d.lv, { uid: d.id, xp: d.xp, name: d.name });
		f.hp = Math.max(1, Math.round(f.maxHp * Math.max(0.3, hpFrac)));
		this.game.fx.burst(f.x, f.y + 1, f.z, { count: 20, color: [0xffffff, 0xffe066], speed: 8, up: 8, size: 0.4, life: 0.6 });
		this.hud.setDog(f, d);
		this.hud.toast(`🐶 ${d.name || SPECIES[d.sp].Name} is ready to fight!`, 'bom');
		writeSave(this.save);
	}

	releaseDog(uid, value) {
		const i = this.save.dogs.findIndex((x) => x.id === uid);
		if (i < 0 || uid === this.save.equipped) return;
		this.save.dogs.splice(i, 1);
		this.save.cash += value;
		this.hud.toast(`👋 Released! +${formatCash(value)}`, 'bom');
		writeSave(this.save);
	}

	applySettings(qualityChanged = false) {
		const s = this.save.settings;
		this.audio.setVolumes(s.music, s.sfx);
		this.game.cam.shakeOff = !s.shake;
		this.game.plates.root.style.display = s.names ? '' : 'none';
		if (qualityChanged) {
			let q = s.quality;
			if (q === 'auto') q = Input.touch || (navigator.hardwareConcurrency || 8) <= 4 ? 'medium' : 'high';
			setQuality(q);
			this.game.quality = q;
			this.game.fx.quality = q;
			this.game.world.setQuality(q);
		}
		writeSave(this.save);
	}

	resetAll() {
		resetSave();
		this.save = null;
		location.reload();
	}

	// ---------------------------------------------------------------- menus
	openMenu(name) {
		if (!this.playing) return;
		closeDialog();
		if (name === 'dogs') openDogsMenu(this);
		else if (name === 'eggs') openEggsMenu(this);
		else if (name === 'map') openMapMenu(this);
		else if (name === 'settings') openSettings(this);
		else if (name === 'help') openGuide(this);
	}

	pressSlot(key, down) {
		const c = this.game.ctrl;
		if (!c || !this.playing) return;
		if (key === 'attack') c.touchAttack = down;
		else if (down && key === 'dash') c.dashPressed = true;
		else if (down && key[0] === 's') c.skillPressed = Number(key.slice(1));
	}

	skillCooldown(k) {
		const s = this.game.skills;
		return s ? s.cooldownOf(this.game.player, k) : null;
	}

	// ---------------------------------------------------------------- viagens
	async travel(id, opts = {}) {
		if (this.travelling) return;
		const def = ISLANDS.List[id];
		if (def && !this.save.islands[id]) {
			this.hud.toast(`🔒 ${def.Name} is locked. Unlock it in the MAP!`, 'erro');
			return;
		}
		this.travelling = true;
		closeDialog();
		closeWindow();
		const name = id === 'village' ? 'Pawville' : id === 'main' ? 'Dog Arena Island' : def.Name;
		if (!opts.first) await this.curtain.show(`${(ISLANDS.EMOJI && ISLANDS.EMOJI[id]) || (id === 'village' ? '🏡' : '⚔️')} ${name}`);
		else await this.curtain.show(`🏡 ${name}`);
		const unsub = (iid, p) => this.curtain.progress(p);
		this.game.listeners.loading = [unsub];
		await this.game.enterIsland(id, { spawn: opts.spawn });
		this.save.lastIsland = id;
		writeSave(this.save);
		this.curtain.hide();
		this.travelling = false;
	}

	onIsland(id) {
		if (id === 'main') this.mainPortals = this.game.local.plazaPortals;
		this.hud.setIsland(id);
		this.npcs.build(this.game);
		this.hud.setQuest(this.save.quest);
		const def = ISLANDS.List[id];
		if (def) setTimeout(() => this.hud.toast(`${ISLANDS.EMOJI[id] || ''} <b>${def.Name}</b> · wild dogs Lv.${def.Levels[0]}-${def.Levels[1]}`, '', 4), 400);
		if (def && def.Flyers && !this.game.player.canFly) setTimeout(() => this.hud.toast('🕊️ Only dogs that FLY can fight in the clouds — but you can explore!', 'ouro', 5), 2200);
	}

	portalLocked(p) {
		const def = ISLANDS.List[p.to];
		return !!def && !this.save.islands[p.to];
	}

	onPortal(p) {
		const g = this.game;
		if (this.portalLocked(p)) {
			const def = ISLANDS.List[p.to];
			if (canUnlock(this.save, p.to)) this.hud.toast(`🔒 ${def.Name}: unlock for <b>${formatCash(def.Price)}</b> in the MAP`, 'erro', 4);
			else this.hud.toast(`🔒 ${def.Name}: unlock ${ISLANDS.List[def.Requires].Name} first`, 'erro', 4);
			// empurra para fora do portal
			const pl = g.player;
			const dx = pl.x - p.x, dz = pl.z - p.z, n = Math.hypot(dx, dz) || 1;
			pl.body.vx = (dx / n) * 30;
			pl.body.vz = (dz / n) * 30;
			return;
		}
		let spawn;
		if (p.to === 'main') {
			// chega na frente do portal da ilha de onde veio (ou do portal da Pawville)
			const L = null;
			void L;
			spawn = 'from:' + (p.spawn || g.islandId);
		}
		if (this.save.tutorial === 1 && p.to === 'common') this.save.tutorial = 2;
		this.travel(p.to, { spawn: spawn ? this.spawnNearPortal(spawn.slice(5)) : undefined });
	}

	// ponto na ilha principal na frente do portal de uma ilha (ou da Pawville)
	spawnNearPortal(from) {
		if (from === 'village' || from === 'pawville') return [0, 586, Math.PI];
		const cf = this.mainPortals && this.mainPortals[from];
		if (cf) return [cf[0] - cf[5] * 14, cf[2] - cf[11] * 14, Math.atan2(cf[5], cf[11])];
		// a ilha principal ainda não carregou: calcula pelo ângulo do Islands.lua
		const PLAZA = { common: 74, epic: 238, cloud: 256 };
		const c = ISLANDS.List[from] && ISLANDS.List[from].Center;
		if (!c) return undefined;
		const a = PLAZA[from] !== undefined ? (PLAZA[from] * Math.PI) / 180 : Math.atan2(c[2], c[0]);
		const R = ISLANDS.PLAZA_PORTAL_RADIUS - 14;
		return [Math.cos(a) * R, Math.sin(a) * R, Math.atan2(Math.cos(a), Math.sin(a))];
	}

	unlockIsland(id) {
		const def = ISLANDS.List[id];
		if (!canUnlock(this.save, id)) return false;
		if (this.save.cash < def.Price) {
			this.hud.toast(`Not enough cash! You need ${formatCash(def.Price)}`, 'erro');
			return false;
		}
		this.save.cash -= def.Price;
		this.save.islands[id] = true;
		this.audio.jingle('Victory');
		this.hud.toast(`🎉 <b>${def.Name}</b> unlocked!`, 'ouro', 4);
		this.saveNow();
		return true;
	}

	updateNext() {
		const s = this.save;
		let nextId = null;
		for (const id of ISLANDS.ORDER) {
			if (canUnlock(s, id)) {
				nextId = id;
				break;
			}
		}
		const key = (nextId || '') + '|' + s.cash;
		if (key === this.nextKey) return;
		this.nextKey = key;
		if (nextId) {
			const def = ISLANDS.List[nextId];
			const ready = s.cash >= def.Price;
			this.hud.setNext(`${ready ? '<b>READY:</b>' : '<b>NEXT:</b>'} Unlock ${ISLANDS.EMOJI[nextId] || ''} ${def.Name}`, s.cash, def.Price, ready);
		} else {
			const n = Object.keys(s.seen).length;
			this.hud.setNext(`<b>GOAL:</b> Find all the dogs! ${n}/80`, n, 80, false);
		}
	}

	// ---------------------------------------------------------------- missões
	questIdleText() {
		const id = this.game.islandId;
		if (id === 'village') return 'Go to the 🌻 PUPPY MEADOWS portal!';
		if (id === 'main') return 'Pick an island portal to fight!';
		return 'Talk to the ❗ Mission Master near the portal';
	}

	questHint() {
		const q = this.save.quest;
		if (q && q.island !== this.game.islandId) this.hud.toast(`Your mission is on <b>${ISLANDS.List[q.island].Name}</b>`, '', 3);
		else if (!q) this.hud.toast(this.questIdleText(), '', 3);
	}

	questDialog() {
		const id = this.game.islandId;
		const def = ISLANDS.List[id];
		const Q = def.Quest;
		const s = this.save;
		const face = { who: '📜 Mission Master', face: '🧭', faceBg: 'linear-gradient(#bfe8a8, #5fb04a)' };
		const offer = (dlg, text) => {
			dlg.set(text, [
				{
					html: `🐶 <b>WILD DOGS</b> — defeat ${Q.Count} wild dogs on this island<small>+${formatCash(Q.Cash)} · +${Q.XP} XP</small>`,
					label: 'ACCEPT',
					fn: (d) => this.acceptQuest('wild', d),
				},
				{
					html: `👑 <b>BOSS</b> — defeat ${def.Champion.Name} (Lv.${def.Champion.Level})<small>+${formatCash(Q.BossCash)} · +${Q.BossXP} XP</small>`,
					label: 'ACCEPT',
					cls: 'ouro',
					fn: (d) => this.acceptQuest('boss', d),
				},
			]);
		};
		const dlg = openDialog(this.uiRoot, { ...face, column: true, text: '' });
		this.dialogNpc = true;
		if (s.quest && s.quest.island === id) {
			const what = s.quest.kind === 'boss' ? `defeat ${def.Champion.Name}` : `defeat ${s.quest.need} wild dogs`;
			dlg.set(`Your mission: ${what}. You have ${s.quest.have}/${s.quest.need}. Keep going!`, [
				{ label: 'OK!', fn: (d) => d.close() },
				{
					label: 'ABANDON',
					cls: 'vermelho',
					fn: () => {
						s.quest = null;
						this.hud.setQuest(null);
						offer(dlg, 'No problem. Want a different mission?');
					},
				},
			]);
		} else if (s.quest) {
			const other = ISLANDS.List[s.quest.island];
			dlg.set(`You already have a mission on ${other.Name}. Want to switch to one from here?`, [
				{
					label: 'SWITCH',
					cls: 'azul',
					fn: () => {
						s.quest = null;
						this.hud.setQuest(null);
						offer(dlg, 'Pick your mission!');
					},
				},
				{ label: 'KEEP MINE', cls: 'cinza', fn: (d) => d.close() },
			]);
		} else {
			offer(dlg, `Welcome to ${def.Name}! The wild dogs here are Lv.${def.Levels[0]}-${def.Levels[1]}. Missions are how you earn Cash. Pick one:`);
		}
	}

	acceptQuest(kind, dlg) {
		const id = this.game.islandId;
		const Q = ISLANDS.List[id].Quest;
		this.save.quest = { island: id, kind, need: kind === 'boss' ? 1 : Q.Count, have: 0 };
		this.hud.setQuest(this.save.quest);
		this.audio.sfx2('Quest');
		dlg.close();
		this.hud.toast(kind === 'boss' ? `👑 Go find <b>${ISLANDS.List[id].Champion.Name}</b>!` : `🐶 Defeat <b>${Q.Count}</b> wild dogs!`, 'bom');
		writeSave(this.save);
	}

	onKill(t) {
		const s = this.save;
		s.stats.kills++;
		if (t.kind === 'champion') s.stats.bosses++;
		const q = s.quest;
		if (!q || q.island !== this.game.islandId) return;
		if ((q.kind === 'wild' && t.kind === 'wild') || (q.kind === 'boss' && t.kind === 'champion')) {
			q.have++;
			this.hud.setQuest(q);
			if (q.have >= q.need) this.completeQuest();
			else this.audio.sfx2('Coin', 0.5);
		}
	}

	completeQuest() {
		const q = this.save.quest;
		const def = ISLANDS.List[q.island];
		const Q = def.Quest;
		const cash = q.kind === 'boss' ? Q.BossCash : Q.Cash;
		const xp = q.kind === 'boss' ? Q.BossXP : Q.XP;
		this.save.quest = null;
		this.save.questsDone++;
		this.save.cash += cash;
		this.hud.setQuest(null);
		const p = this.game.player;
		this.game.fx.text(p.x, p.y + p.body.height + 2, p.z, '+' + formatCash(cash), { cls: 'dinheiro', life: 1.6, rise: 5 });
		this.game.giveXP(xp);
		this.audio.jingle('Victory');
		this.audio.sfx2('Purchase');
		this.hud.toast(`🏆 MISSION COMPLETE! <b>+${formatCash(cash)}</b> · +${xp} XP`, 'ouro', 5);
		this.saveNow();
	}

	// ---------------------------------------------------------------- nível
	onLevelUp(p, ups) {
		this.syncDog();
		this.audio.jingle('LevelUp');
		this.hud.toast(`⭐ LEVEL UP! <b>Lv.${p.level}</b>`, 'ouro', 3);
		const skills = skillsOf(p.speciesId);
		for (let k = 0; k < 3; k++) {
			const need = powerUnlockLevel(k);
			if (p.level >= need && p.level - ups < need && skills[k] && (k < 2 || hasSupreme(p.species.Rarity))) {
				setTimeout(() => this.hud.toast(`🔓 NEW POWER: <b>${skills[k].Name}</b> (key ${k + 2})`, 'bom', 5), 900);
			}
		}
		writeSave(this.save);
	}

	// ---------------------------------------------------------------- conversa / interação
	interact() {
		const n = this.npcs.near;
		if (!n) return;
		if (n.kind === 'quest') this.questDialog();
		else if (n.kind === 'egg') this.eggDialog(n.egg);
		else if (n.kind === 'prof') this.profDialog();
	}

	npcSpots() {
		return this.npcs.list.map((n) => ({ x: n.x, z: n.z, color: n.color }));
	}

	eggDialog(eggId) {
		const egg = EGGS[eggId];
		const price = CONFIG.EGG_PRICE[eggId];
		const odds = eggOdds(eggId, this.game.player.level)
			.map((o) => `<span style="color:${RARITY[o.Rarity].Color}">${RARITY[o.Rarity].Label} ${Math.round(o.Chance * 10) / 10}%</span>`)
			.join(' · ');
		const dlg = openDialog(this.uiRoot, {
			who: '🥚 ' + egg.Name,
			face: '🥚',
			faceBg: `linear-gradient(${egg.Color}, ${egg.Spots})`,
			text: odds,
			options: [
				{ label: `BUY ${formatCash(price)}`, cls: 'ouro', fn: (d) => this.buyEggs(eggId, 1) && d.close() },
				{ label: `×3 ${formatCash(price * 3)}`, cls: 'roxo', fn: (d) => this.buyEggs(eggId, 3) && d.close() },
				{ label: 'ALL EGGS', cls: 'azul', fn: (d) => (d.close(), this.openMenu('eggs')) },
			],
		});
		this.dialogNpc = true;
		void dlg;
	}

	profDialog() {
		const s = this.save;
		const options = [];
		if (s.spins > 0) options.push({ label: `🎟️ FREE SPIN (${s.spins})`, cls: 'ouro', fn: (d) => (d.close(), this.spin('Free')) });
		options.push({ label: `🎰 SPIN ${formatCash(SPIN_PRICE.Normal)}`, cls: 'roxo', fn: (d) => (d.close(), this.spin('Normal')) });
		options.push({ label: `🍀 LUCKY SPIN ${formatCash(SPIN_PRICE.Lucky)}`, cls: 'ouro', fn: (d) => (d.close(), this.spin('Lucky')) });
		openDialog(this.uiRoot, {
			who: '🎓 Prof. Barkley',
			face: '🎓',
			faceBg: 'linear-gradient(#e8f4ff, #7fb6e8)',
			text: 'Woof! My roulette can give you ANY dog — even Mythic! Lucky spins never give Common dogs.',
			options,
		});
		this.dialogNpc = true;
	}

	async spin(kind) {
		const s = this.save;
		if (s.dogs.length >= CONFIG.MAX_DOGS) return this.hud.toast(`Your kennel is full (${CONFIG.MAX_DOGS})! Release some dogs.`, 'erro');
		if (kind !== 'Free') {
			if (s.cash < SPIN_PRICE[kind]) return this.hud.toast(`Not enough cash! (${formatCash(SPIN_PRICE[kind])})`, 'erro');
			s.cash -= SPIN_PRICE[kind];
		} else s.spins--;
		this.modal = true;
		const sp = await rouletteScreen(this, {
			title: kind === 'Lucky' ? '🍀 LUCKY SPIN' : '🎰 ROULETTE',
			sub: kind === 'Lucky' ? 'No Common dogs! Better chances for Legendary and Mythic.' : 'Any dog can come out!',
			spins: 0,
			roll: () => rollRoulette(kind === 'Lucky' ? 'Lucky' : 'Normal'),
		});
		this.modal = false;
		const isNew = !s.seen[sp];
		addDog(s, sp, 1);
		this.hud.toast(`${isNew ? '✨ NEW! ' : ''}<b>${SPECIES[sp].Name}</b> joined your team! (DOGS menu)`, 'bom', 4);
		this.hud.badge('dogs', 'NEW');
		this.saveNow();
	}

	// ---------------------------------------------------------------- ovos
	buyEggs(eggId, n) {
		const s = this.save;
		const isl = eggIsland(eggId);
		if (isl && !s.islands[isl]) {
			this.hud.toast(`🔒 Unlock ${ISLANDS.List[isl].Name} first!`, 'erro');
			return false;
		}
		const price = CONFIG.EGG_PRICE[eggId] * n;
		if (s.cash < price) {
			this.hud.toast(`Not enough cash! You need ${formatCash(price)}`, 'erro');
			this.audio.sfx2('Error');
			return false;
		}
		if (s.dogs.length + n > CONFIG.MAX_DOGS) {
			this.hud.toast(`Your kennel is full (${CONFIG.MAX_DOGS})! Release some dogs in DOGS.`, 'erro');
			return false;
		}
		s.cash -= price;
		this.audio.sfx2('Purchase');
		this.hatch(eggId, n);
		return true;
	}

	openOwnedEgg(eggId) {
		const s = this.save;
		if (!s.eggs[eggId]) return;
		if (s.dogs.length >= CONFIG.MAX_DOGS) return this.hud.toast('Your kennel is full!', 'erro');
		s.eggs[eggId]--;
		this.hatch(eggId, 1);
	}

	async hatch(eggId, n) {
		const s = this.save;
		const level = this.game.player ? this.game.player.level : 1;
		const results = [];
		for (let i = 0; i < n; i++) {
			const [sp] = rollEgg(eggId, level);
			const isNew = !s.seen[sp];
			const dog = addDog(s, sp, 1);
			results.push({ sp, isNew, dogId: dog.id });
		}
		s.stats.hatched += n;
		this.saveNow();
		closeDialog();
		this.modal = true;
		await hatchScreen(this, eggId, results);
		this.modal = false;
		this.hud.badge('dogs', 'NEW');
		this.saveNow();
	}
}

export function hideLoading() {
	const el = document.getElementById('carregando');
	if (!el) return;
	el.classList.add('sumindo');
	setTimeout(() => el.remove(), 700);
}

void THREE;
void xpToNext;
