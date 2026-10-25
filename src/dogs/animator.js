// ANIMAÇÃO PROCEDURAL DOS CACHORROS — tradução do client/Animator.lua do projeto Roblox (mesmos números e poses).
// Lê a velocidade, o chão, a água, a vida e a "ação" do cachorro e mexe as juntas: Body, Neck1..3, Jaw1..3,
// LegFL/FR/BL/BR, KneeFL/FR/BL/BR, Tail, WingL/WingR (+2 = cotovelo) e as orelhas.
//
// Convenções (iguais ao Roblox, o cachorro olha para -Z):
//   Perna/joelho: A(+x) leva a pata para a FRENTE. Joelho da frente dobra com x NEGATIVO, jarrete de trás com x POSITIVO.
//   Pescoço: A(+x) levanta o nariz · Mandíbula: A(-x) abre a boca · Rabo: A(+x) abaixa o rabo.
//   Asas: "para baixo" = A(0, 0, -lado) e "para trás" = A(0, -lado, 0) (lado: esquerda -1, direita +1).
import { A, T, HEAD, IDENT, axisAngle } from './cf.js';

const TUNE = {
	MoveAt: 0.35,
	TrotAt: 1.7,
	GallopAt: 4.2,
	Stride: { Walk: 1.25, Trot: 2.1, Gallop: 3.3 },
	Duty: { Walk: 0.64, Trot: 0.5, Gallop: 0.4 },
	Swing: { Walk: 0.36, Trot: 0.48, Gallop: 0.66 },
	Cycle: { Min: 0.55, Max: 3.4, Turn: 1.8 },
	IdleEvery: [5, 11],
	SitAfter: 18,
	LieAfter: 38,
	SleepAfter: 70,
	LowHealth: 0.3,
	BigStep: 2.5,
	Smooth: { Body: 14, Neck: 16, Jaw: 22, Leg: 24, Knee: 26, Tail: 30, Wing: 20, Fast: 40 },
	Look: { Yaw: 2.2, Neck: 1.2, Twist: 0.42, Up: 0.85, Down: 0.7, Stiff: 150, Damp: 18 },
	FlyMult: 4,
};

const LEGS = ['LegFL', 'LegFR', 'LegBL', 'LegBR'];
const KNEE_OF = { LegFL: 'KneeFL', LegFR: 'KneeFR', LegBL: 'KneeBL', LegBR: 'KneeBR' };
const FRONT = { LegFL: true, LegFR: true };
const SIDE = { LegFL: -1, LegBL: -1, LegFR: 1, LegBR: 1 };
const FLEX = { LegFL: -1, LegFR: -1, LegBL: 1, LegBR: 1 };
const PHASE = {
	Walk: { LegBL: 0, LegFL: 0.25, LegBR: 0.5, LegFR: 0.75 },
	Trot: { LegFL: 0, LegBR: 0, LegFR: 0.5, LegBL: 0.5 },
	Gallop: { LegBL: 0, LegBR: 0.1, LegFR: 0.42, LegFL: 0.54 },
};
const GALLOP_ACTIONS = { Dash: true, Charge: true, Zoom: true };
const NO_AIR_ACTIONS = {
	Fly: true, Float: true, Dive: true, Rear: true, Spin: true, KO: true, Vanish: true, Leap: true, Flip: true, Roll: true,
	Curl: true, Drill: true, Bounce: true, Belly: true, Slide: true, Focus: true, Summon: true, Victory: true,
};
const STILL_ACTIONS = {
	KO: true, Sit: true, Eat: true, Howl: true, Aim: true, Open: true, Bark: true, Sniff: true, Bow: true, Throw: true, Flex: true,
	Focus: true, Guard: true, Inhale: true, Snore: true, Victory: true, Wiggle: true, Shake: true, Dig: true, Stomp: true,
	Summon: true, Spit: true, Kick: true, Uppercut: true, Curl: true,
};

const RATE = { Body: TUNE.Smooth.Body, Tail: TUNE.Smooth.Tail };
for (const leg of LEGS) {
	RATE[leg] = TUNE.Smooth.Leg;
	RATE[KNEE_OF[leg]] = TUNE.Smooth.Knee;
}
for (let i = 1; i <= 3; i++) {
	RATE['Neck' + i] = TUNE.Smooth.Neck;
	RATE['Jaw' + i] = TUNE.Smooth.Jaw;
}
for (const w of ['WingL', 'WingR', 'WingL2', 'WingR2']) RATE[w] = TUNE.Smooth.Wing;

const TAU = Math.PI * 2;
const sin = Math.sin, cos = Math.cos, abs = Math.abs, max = Math.max, min = Math.min, sqrt = Math.sqrt;

function clamp(x, a, b) {
	return x < a ? a : x > b ? b : x;
}
function damp(dt, k) {
	return 1 - Math.exp(-k * dt);
}
function smooth01(x) {
	x = clamp(x, 0, 1);
	return x * x * (3 - 2 * x);
}
function envelope(t, dur, inT, outT) {
	return smooth01(t / inT) * smooth01((dur - t) / outT);
}
function pulse(t, dur) {
	if (t < 0 || t > dur) return 0;
	return sin((t / dur) * Math.PI);
}
function mul(P, name, cf) {
	P[name] = (P[name] || IDENT).mul(cf);
}
function pre(P, name, cf) {
	P[name] = cf.mul(P[name] || IDENT);
}
function body(P, cf) {
	P.Body = (P.Body || IDENT).mul(cf);
}
function spring(x, v, goal, k, d, dt) {
	const n = max(1, Math.ceil(dt / 0.016));
	const h = dt / n;
	for (let i = 0; i < n; i++) {
		v += ((goal - x) * k - v * d) * h;
		x += v * h;
	}
	return [x, v];
}
function blend(P, Q, w) {
	if (w <= 0.001) return;
	w = min(w, 1);
	for (const name in Q) {
		const v = Q[name];
		if (typeof v === 'number') {
			const cur = P[name] || 0;
			P[name] = cur + (v - cur) * w;
		} else {
			P[name] = (P[name] || IDENT).lerp(v, w);
		}
	}
}
function heads3(fn) {
	for (let i = 1; i <= 3; i++) fn(i);
}

// ---------------------------------------------------------------- 5. POSES
function legCycle(u, duty, amp) {
	u = ((u % 1) + 1) % 1;
	if (u < duty) return [amp * (1 - (2 * u) / duty), 0];
	const k = (u - duty) / (1 - duty);
	return [-amp + 2 * amp * smooth01(k), sin(k * Math.PI)];
}

function setLeg(s, P, leg, ang, flex, S) {
	const knee = KNEE_OF[leg];
	if (s.has[knee]) {
		const front = FRONT[leg];
		P[leg] = A(ang + 0.18 * flex);
		P[knee] = A(FLEX[leg] * flex * (front ? 1.15 : 0.85) + (front ? 0 : 0.06));
	} else {
		P[leg] = T(0, flex * 0.14 * S, 0).mul(A(ang));
	}
}

function foldWings(P, open) {
	for (const side of [-1, 1]) {
		const name = side < 0 ? 'WingL' : 'WingR';
		const closed = 1 - open;
		P[name] = A(0, -side * 0.95 * closed, 0).mul(A(0, 0, -side * 0.3 * closed));
		P[name + '2'] = A(0, -side * 1.25 * closed, 0).mul(A(0, 0, -side * 0.25 * closed));
	}
}

function flapWings(P, stroke, outer, fold, sweep) {
	for (const side of [-1, 1]) {
		const name = side < 0 ? 'WingL' : 'WingR';
		P[name] = A(0, -side * sweep, 0).mul(A(0, 0, -side * stroke));
		P[name + '2'] = A(0, -side * fold, 0).mul(A(0, 0, -side * outer));
	}
}

function bodyTurn(s, P, pitch, yaw, roll, plant) {
	if (abs(pitch) + abs(yaw) + abs(roll) < 1e-4) return;
	P.Body = (P.Body || IDENT).mul(A(pitch, yaw, roll));
	if (plant <= 0.001) return;
	const L = max(0.5, s.LegLen);
	for (const leg of LEGS) {
		const z = s.LegZ[leg] !== undefined ? s.LegZ[leg] : (FRONT[leg] ? -0.6 : 0.6) * s.S;
		const slide = clamp((-z * yaw) / L, -0.6, 0.6);
		pre(P, leg, A(-pitch * plant, -yaw * 0.5 * plant, (slide - roll) * plant));
	}
}

function sitPose(s, c) {
	const L = s.LegLen;
	const Q = {
		Body: T(0, -0.3 * L, 0.2 * L).mul(A(0.55)),
		LegBL: A(-1.2),
		LegBR: A(-1.2),
		KneeBL: A(1.5),
		KneeBR: A(1.5),
		LegFL: A(-0.55),
		LegFR: A(-0.55),
		TailX: 0.9,
		TailY: sin(c.t * (5 + 5 * s.Excite)) * (0.4 + 0.25 * s.Excite),
	};
	heads3((i) => (Q['Neck' + i] = HEAD(-0.45 + s.LookPitch, s.LookYaw, s.LookTilt)));
	bodyTurn(s, Q, 0, s.Twist * 0.7, -s.Twist * 0.1, 0.5);
	return Q;
}

function liePose(s, c) {
	const L = s.LegLen, sleep = s.SleepW;
	const br = sin(c.t * (2 - sleep));
	const awake = 1 - sleep;
	const Q = {
		Body: T(0, -0.8 * L + br * 0.015 * c.S, 0).mul(A(br * 0.01)),
		LegFL: A(1.45),
		LegFR: A(1.45),
		KneeFL: IDENT,
		KneeFR: IDENT,
		LegBL: A(1.25, 0, -0.35),
		LegBR: A(1.25, 0, 0.35),
		KneeBL: A(1.5),
		KneeBR: A(1.5),
		TailX: 0.6,
		TailY: 0.9 + br * 0.03,
	};
	heads3((i) => {
		Q['Neck' + i] = HEAD(0.05 - 0.5 * sleep + s.LookPitch * awake, s.LookYaw * awake, s.LookTilt * awake);
		Q['Jaw' + i] = IDENT;
	});
	return Q;
}

const BEHAVIORS = { sniff: 2.8, scratch: 2.4, shake: 1.1, yawn: 2.1, bow: 2.3, lookback: 1.8, paw: 1.6, hop: 1.1, chase: 2.4 };
const BEHAVIOR_LIST = ['sniff', 'scratch', 'shake', 'yawn', 'bow', 'lookback', 'paw', 'chase'];
const SHOWCASE_LIST = ['hop', 'bow', 'paw', 'lookback', 'shake', 'yawn', 'chase'];

function behaviorPose(s, P, c) {
	const b = s.Behavior;
	if (!b) return;
	const bt = c.now - s.BehaviorAt;
	const dur = BEHAVIORS[b];
	const t = c.t, S = c.S, side = s.BehaviorSide || 1;
	const Q = {};
	if (b === 'sniff') {
		const nose = sin(t * 15) * 0.035;
		Q.Body = T(0, -0.06 * S, -0.05 * S).mul(A(-0.1));
		heads3((i) => {
			Q['Neck' + i] = A(-0.7 + nose, sin(bt * 1.7 + i) * 0.35, 0);
			Q['Jaw' + i] = IDENT;
		});
		Q.LegFL = A(0.05);
		Q.LegFR = A(0.05);
		Q.KneeFL = A(-0.15);
		Q.KneeFR = A(-0.15);
		Q.TailX = -0.1;
		Q.TailY = sin(t * 4) * 0.25;
	} else if (b === 'scratch') {
		const leg = side < 0 ? 'LegBL' : 'LegBR';
		const other = side < 0 ? 'LegBR' : 'LegBL';
		const fast = sin(t * 22);
		Q.Body = T(0, -0.22 * s.LegLen, 0.12 * s.LegLen).mul(A(0.35, 0, side * 0.12));
		Q[leg] = A(1.0 + fast * 0.28, 0, side * 0.15);
		Q[KNEE_OF[leg]] = A(0.9 + fast * 0.2);
		Q[other] = A(-0.85);
		Q[KNEE_OF[other]] = A(1.1);
		Q.LegFL = A(-0.35);
		Q.LegFR = A(-0.35);
		heads3((i) => {
			Q['Neck' + i] = A(-0.1, side * 0.35, side * 0.45 + fast * 0.03);
			Q['Jaw' + i] = A(-0.08);
		});
		Q.TailX = 0.3;
		Q.TailY = 0;
		c.ear = 'droop';
	} else if (b === 'shake') {
		const decay = max(0, 1 - bt / dur);
		const w = sin(t * 30) * decay;
		Q.Body = T(0, -0.03 * S, 0).mul(A(0, w * 0.12, w * 0.32));
		heads3((i) => {
			Q['Neck' + i] = A(0.05, -w * 0.5, -w * 0.4);
			Q['Jaw' + i] = A(-0.15 * decay);
		});
		Q.TailX = 0;
		Q.TailY = -w * 0.8;
		s.EarKick += abs(w) * 0.6;
	} else if (b === 'yawn') {
		const open = smooth01(bt / 0.8) * smooth01((dur - bt) / 0.6);
		Q.Body = A(0.06 * open);
		heads3((i) => {
			Q['Neck' + i] = A(0.45 * open, 0, 0.12 * open * (i % 2 === 0 ? -1 : 1));
			Q['Jaw' + i] = A(-1.0 * open);
		});
		Q.LegFL = A(0.1 * open);
		Q.LegFR = A(0.1 * open);
		c.ear = 'back';
	} else if (b === 'bow') {
		Q.Body = T(0, -0.12 * S, -0.05 * S).mul(A(-0.38));
		Q.LegFL = A(1.1);
		Q.LegFR = A(1.1);
		Q.KneeFL = A(-0.1);
		Q.KneeFR = A(-0.1);
		Q.LegBL = A(0.38);
		Q.LegBR = A(0.38);
		heads3((i) => {
			Q['Neck' + i] = A(0.55, 0, sin(t * 2) * 0.1);
			Q['Jaw' + i] = A(-0.25);
		});
		Q.TailX = -0.5;
		Q.TailY = sin(t * 9) * 0.5;
	} else if (b === 'lookback') {
		const k = smooth01(bt / 0.4);
		Q.Body = A(0, side * 0.12 * k, side * 0.05 * k);
		heads3((i) => (Q['Neck' + i] = A(0.05, side * 1.25 * k, side * 0.15 * k)));
		Q.TailX = 0.05;
		Q.TailY = side * 0.4 + sin(t * 6) * 0.2;
	} else if (b === 'paw') {
		const leg = side < 0 ? 'LegFL' : 'LegFR';
		Q[leg] = A(0.55);
		Q[KNEE_OF[leg]] = A(-1.1);
		Q.Body = A(0.03, 0, -SIDE[leg] * 0.04);
		heads3((i) => (Q['Neck' + i] = A(0.08, 0, -SIDE[leg] * 0.35)));
	} else if (b === 'hop') {
		const h = abs(sin(bt * 6));
		Q.Body = T(0, h * 0.35 * S, 0).mul(A(0.1 * h));
		Q.LegFL = A(0.4 * h);
		Q.LegFR = A(0.4 * h);
		Q.KneeFL = A(-0.7 * h);
		Q.KneeFR = A(-0.7 * h);
		Q.LegBL = A(-0.3 * h);
		Q.LegBR = A(-0.3 * h);
		Q.KneeBL = A(0.6 * h);
		Q.KneeBR = A(0.6 * h);
		Q.TailY = sin(t * 14) * 0.6;
	} else if (b === 'chase') {
		for (const leg of LEGS) {
			const [a, f] = legCycle(bt * 2.8 + PHASE.Trot[leg], 0.5, 0.3);
			setLeg(s, Q, leg, a, f, S);
		}
		Q.Body = T(0, -0.04 * S, 0).mul(A(-0.05, 0, side * 0.12));
		heads3((i) => {
			Q['Neck' + i] = A(-0.12, side * 1.15, side * 0.2);
			Q['Jaw' + i] = A(-0.4);
		});
		Q.TailX = 0.05;
		Q.TailY = side * 0.9;
		c.ear = 'up';
	}
	blend(P, Q, envelope(bt, dur, 0.3, 0.35));
	if (b === 'chase') {
		body(P, A(0, side * TAU * smooth01((bt - 0.25) / (dur - 0.55)), 0));
		c.fast.Body = true;
	}
}

function idlePose(s, P, c) {
	const t = c.t, S = c.S;
	const sleep = s.SleepW, hurt = s.Health < TUNE.LowHealth;
	const ex = s.Excite;
	const rate = 2.1 + 3.5 * max(s.Pant, ex * 0.6) - 1.2 * sleep;
	const br = sin(t * rate);
	const hop = abs(sin(t * 8)) * max(0, ex - 0.3) * 0.12 * S;
	const wiggle = sin(t * (6.5 + 7 * ex)) * 0.05 * ex;
	P.Body = T(0, br * (0.02 + 0.015 * s.Pant) * S + hop, 0).mul(A(br * 0.012, wiggle, sin(t * 0.55) * 0.012));
	const shift = sin(t * 0.45) * 0.045;
	body(P, A(0, 0, shift));
	P.LegFL = A(shift * 0.5, 0, -shift);
	P.LegFR = A(-shift * 0.5, 0, -shift);
	P.LegBL = A(-shift * 0.4, 0, -shift);
	P.LegBR = A(shift * 0.4, 0, -shift);
	P.KneeBL = A(0.06);
	P.KneeBR = A(0.06);
	heads3((i) => {
		const own = c.heads > 1 ? sin(t * 0.37 + i * 2.1) * 0.25 + (i - 2) * 0.18 : 0;
		P['Neck' + i] = HEAD(s.LookPitch + br * 0.02 - (hurt ? 0.12 : 0), s.LookYaw + own, s.LookTilt);
		P['Jaw' + i] = A(-(0.08 + 0.14 * abs(sin(t * 9 + i))) * max(s.Pant, ex * 0.8));
	});
	P.TailX = 0.05 + (hurt ? 0.45 : 0) - 0.3 * ex;
	P.TailY = sin(t * (hurt ? 2.5 : 6.5 + 7 * ex)) * (hurt ? 0.15 : 0.38 + 0.3 * ex) * (1 - sleep);
	foldWings(P, 0);
	const awake = 1 - sleep;
	bodyTurn(s, P, clamp(s.LookPitch * 0.12, -0.08, 0.1) * awake, s.Twist * awake, -s.Twist * 0.12 * awake, 1);
	if (ex > 0.4) c.ear = 'up';
	if (s.TurnW > 0.01) {
		const Q = {};
		for (const leg of LEGS) {
			const [a, f] = legCycle(s.Phase + PHASE.Trot[leg], 0.5, 0.12);
			setLeg(s, Q, leg, a, f * 0.7, S);
		}
		blend(P, Q, s.TurnW);
	}
	behaviorPose(s, P, c);
	if (s.SitW > 0.01) blend(P, sitPose(s, c), s.SitW);
	if (s.LieW > 0.01) blend(P, liePose(s, c), s.LieW);
}

function footsteps(s, c) {
	if (c.snap) return;
	const g = s.Gait;
	const gait = g.Gallop > g.Trot && g.Gallop > g.Walk ? 'Gallop' : g.Trot > g.Walk ? 'Trot' : 'Walk';
	for (const leg of LEGS) {
		const u = (s.Phase + PHASE[gait][leg]) % 1;
		const last = s.LastStep[leg];
		if (last !== undefined && u < last && !s.Back && s.MoveW > 0.6 && s.onDust) {
			s.onDust(s.footPoint(leg), 0.18 * sqrt(c.S));
		}
		s.LastStep[leg] = u;
	}
}

function movePose(s, P, c) {
	const g = s.Gait, S = c.S, t = c.t;
	const u = s.Phase;
	const scale = clamp(0.55 + s.Rel * 0.2, 0.55, 1.15);
	const hurt = s.Health < TUNE.LowHealth;
	for (const leg of LEGS) {
		let ang = 0, flex = 0;
		for (const gait of ['Walk', 'Trot', 'Gallop']) {
			const w = g[gait];
			if (w > 0.001) {
				const amp = TUNE.Swing[gait] * (gait === 'Gallop' ? 1 : scale);
				let [a, f] = legCycle(u + PHASE[gait][leg], TUNE.Duty[gait], amp);
				if (gait === 'Gallop') a += FRONT[leg] ? 0.1 : -0.08;
				ang += a * w;
				flex += f * w;
			}
		}
		if (hurt && leg === s.LimpLeg) {
			ang *= 0.55;
			flex = min(1, flex * 1.3 + 0.15);
		}
		setLeg(s, P, leg, ang, flex, S);
	}
	const W = g.Walk, Tr = g.Trot, G = g.Gallop;
	const a1 = u * TAU;
	let bob = (cos(a1 * 2) * (0.03 * W + 0.06 * Tr) + sin(a1) * 0.17 * G) * S;
	const pitch = -0.03 - 0.02 * G + sin(a1 + 0.8) * 0.14 * G + cos(a1 * 2) * 0.02 * Tr;
	let roll = sin(a1) * (0.05 * W + 0.025 * Tr);
	const sway = sin(a1) * 0.05 * W + sin(a1 * 2) * 0.012 * Tr;
	if (hurt) {
		const lu = (u + PHASE.Trot[s.LimpLeg]) % 1;
		bob -= (lu < 0.5 ? sin((lu / 0.5) * Math.PI) : 0) * 0.06 * S;
	}
	if (c.big) {
		bob *= 1.35;
		roll *= 1.3;
	}
	const turn = clamp(-s.Yaw * 0.085 * min(1, s.Rel / 2), -0.32, 0.32);
	P.Body = T(0, bob, 0).mul(A(pitch, sway, roll + turn + s.Side * 0.1));
	const nod = cos(a1 * 2 + 0.5) * 0.06 * W + cos(a1 * 2) * 0.025 * Tr - (pitch + 0.04) * 0.8 * G;
	const lead = clamp(s.Yaw * 0.14, -0.5, 0.5);
	heads3((i) => {
		P['Neck' + i] = HEAD(-0.08 + nod + s.LookPitch * 0.6 - (hurt ? 0.12 : 0), lead + s.LookYaw * 0.8 - sway * 0.6, -(roll + turn) * 0.6);
		P['Jaw' + i] = A(-(0.05 + 0.12 * G) - 0.1 * s.Pant);
	});
	P.TailX = 0.05 - 0.4 * G + sin(a1) * 0.12 * G + (hurt ? 0.4 : 0);
	P.TailY = sin(a1) * 0.3 * W + sin(t * 9) * 0.18 * Tr - s.Yaw * 0.08 - sway * 1.5;
	foldWings(P, 0.15 * G);
	bodyTurn(s, P, 0, s.Twist * 0.5, 0, 0.6);
	if (c.big) footsteps(s, c);
}

function brakePose(s, P, c) {
	if (s.Speed < 0.3 * s.LegLen) return;
	const acc = s.Accel / max(1, s.LegLen);
	if (acc < -2) {
		const k = clamp((-acc - 2) / 8, 0, 1);
		body(P, T(0, -0.08 * c.S * k, 0).mul(A(0.12 * k)));
		mul(P, 'LegFL', A(0.35 * k));
		mul(P, 'LegFR', A(0.35 * k));
		mul(P, 'LegBL', A(0.25 * k));
		mul(P, 'LegBR', A(0.25 * k));
	} else if (acc > 2) {
		const k = clamp((acc - 2) / 8, 0, 1);
		body(P, A(-0.1 * k));
		heads3((i) => mul(P, 'Neck' + i, A(-0.1 * k)));
	}
}

function swimPose(s, P, c) {
	const t = c.t, S = c.S;
	const w = t * 7;
	P.Body = T(0, -0.25 * S, 0).mul(A(0.12, 0, sin(w * 0.5) * 0.04));
	for (const leg of LEGS) {
		const off = (SIDE[leg] > 0 ? Math.PI : 0) + (FRONT[leg] ? 0 : Math.PI * 0.5);
		if (FRONT[leg]) setLeg(s, P, leg, 0.25 + sin(w + off) * 0.55, max(0, cos(w + off)) * 0.9, S);
		else setLeg(s, P, leg, -0.2 + sin(w + off) * 0.3, max(0, cos(w + off)) * 0.6, S);
	}
	heads3((i) => {
		P['Neck' + i] = HEAD(0.35 + sin(w) * 0.04 + s.LookPitch * 0.3, s.LookYaw * 0.6, 0);
		P['Jaw' + i] = A(-0.06);
	});
	P.TailX = 0;
	P.TailY = sin(t * 3) * 0.35 - s.Yaw * 0.15;
	c.ear = 'back';
}

function airPose(s, P, c) {
	const t = c.t, S = c.S;
	const rise = clamp(s.VelY / (14 * sqrt(S)), -1, 1);
	const k = (rise + 1) / 2;
	P.Body = A(clamp((s.VelY * 0.015) / sqrt(S), -0.3, 0.3));
	const flail = c.now - s.AirSince > 0.9 ? sin(t * 14) * 0.15 : 0;
	for (const leg of LEGS) {
		const f = SIDE[leg] * flail;
		if (FRONT[leg]) setLeg(s, P, leg, 0.35 + 0.55 * k + f, 0.2 + 0.7 * k, S);
		else setLeg(s, P, leg, 0.3 - 1.05 * k - f, 0.55 - 0.35 * k, S);
	}
	heads3((i) => {
		P['Neck' + i] = A(0.18 * k - 0.08);
		P['Jaw' + i] = A(-0.15);
	});
	P.TailX = 0.1 - 0.4 * k;
	P.TailY = sin(t * 10) * 0.2;
	foldWings(P, 0.35);
}

function takeoffPose(s, P, c) {
	const k = pulse(c.now - s.TakeoffAt, 0.22);
	if (k <= 0) return;
	body(P, A(0.2 * k));
	mul(P, 'LegBL', A(-0.6 * k));
	mul(P, 'LegBR', A(-0.6 * k));
	mul(P, 'LegFL', A(0.4 * k));
	mul(P, 'LegFR', A(0.4 * k));
}

function landPose(s, P, c) {
	const lt = c.now - s.LandAt;
	if (lt > 0.7) return;
	const comp = s.LandPower * Math.exp(-lt * 7) * cos(lt * 11);
	const down = max(comp, -0.3);
	P.Body = T(0, -0.42 * c.S * down, 0).mul(A(-0.12 * down)).mul(P.Body || IDENT);
	mul(P, 'LegFL', A(-0.15 * down));
	mul(P, 'LegFR', A(-0.15 * down));
	mul(P, 'LegBL', A(0.3 * down));
	mul(P, 'LegBR', A(0.3 * down));
	mul(P, 'KneeFL', A(-0.5 * down));
	mul(P, 'KneeFR', A(-0.5 * down));
	mul(P, 'KneeBL', A(0.6 * down));
	mul(P, 'KneeBR', A(0.6 * down));
	heads3((i) => mul(P, 'Neck' + i, A(-0.25 * down)));
}

function floaterPose(s, P, c) {
	const t = c.t, S = c.S;
	P.Body = (P.Body || IDENT).mul(T(0, (0.15 + sin(t * 1.6) * 0.25) * S, 0));
	const Q = {};
	LEGS.forEach((leg, i) => setLeg(s, Q, leg, (FRONT[leg] ? -0.25 : 0.25) + sin(t * 1.6 + i + 1) * 0.08, 0.3, S));
	blend(P, Q, 1 - s.MoveW * 0.6);
	flapWings(P, sin(t * 2.8) * 0.3, sin(t * 2.8 - 0.7) * 0.25, 0.2, 0.2);
}

function ragePose(s, P, c) {
	const t = c.t;
	const tremble = sin(t * 37) * 0.012;
	body(P, A(tremble - 0.05, 0, tremble));
	heads3((i) => {
		mul(P, 'Neck' + i, A(-0.22 + sin(t * 3) * 0.04, sin(t * 23 + i) * 0.03, 0));
		P['Jaw' + i] = A(-0.38 + sin(t * 7 + i) * 0.1);
	});
	P.TailX = -0.55;
	P.TailY = sin(t * 4) * 0.1;
	c.ear = 'back';
}

// ---------------------------------------------------------------- 6. AÇÕES
const ACTIONS = {};

ACTIONS.Crouch = (s, P, c) => {
	const t = c.t, S = c.S;
	const tr = sin(t * 30) * 0.008;
	const wiggle = sin(t * 9) * 0.06;
	const Q = {
		Body: T(0, -0.42 * s.LegLen, 0.05 * S).mul(A(-0.12 + tr, wiggle * 0.3, 0)),
		LegFL: A(0.35), LegFR: A(0.35), KneeFL: A(-0.55), KneeFR: A(-0.55),
		LegBL: A(-0.15 + wiggle), LegBR: A(-0.15 - wiggle), KneeBL: A(1.0), KneeBR: A(1.0),
		TailX: -0.05, TailY: sin(t * 14) * 0.18,
	};
	heads3((i) => {
		Q['Neck' + i] = HEAD(-0.15 + s.LookPitch * 0.3, s.LookYaw * 0.4, 0);
		Q['Jaw' + i] = A(-0.12);
	});
	blend(P, Q, smooth01(c.at / 0.25));
	c.ear = 'back';
};

ACTIONS.Howl = (s, P, c) => {
	const t = c.t, L = s.LegLen;
	const phrase = c.at % 2.4;
	const open = smooth01(phrase / 0.35) * smooth01((2.1 - phrase) / 0.3);
	const Q = {
		Body: T(0, -0.22 * L, 0.15 * L).mul(A(0.38)),
		LegBL: A(-0.95), LegBR: A(-0.95), KneeBL: A(1.25), KneeBR: A(1.25), LegFL: A(-0.38), LegFR: A(-0.38),
		TailX: 0.5, TailY: sin(t * 2) * 0.1,
	};
	heads3((i) => {
		Q['Neck' + i] = A(0.85 + 0.15 * open + sin(t * 1.3 + i) * 0.04, (i - 2) * 0.25 * (c.heads > 1 ? 1 : 0), 0);
		Q['Jaw' + i] = A(-(0.12 + 0.5 * open) - sin(t * 18 + i) * 0.04 * open);
	});
	blend(P, Q, smooth01(c.at / 0.45));
	c.ear = 'back';
};

ACTIONS.Roar = (s, P, c) => {
	const at = c.at, t = c.t, S = c.S;
	const wind = smooth01(at / 0.18);
	const blast = smooth01((at - 0.18) / 0.12);
	const shake = sin(t * 42) * 0.03 * blast;
	const Q = {
		Body: T(0, -0.12 * S, (0.12 * wind - 0.32 * blast) * S).mul(A(0.06 * wind - 0.12 * blast + shake, 0, shake)),
		LegFL: A(0.35 * blast), LegFR: A(0.35 * blast), KneeFL: A(-0.1), KneeFR: A(-0.1),
		LegBL: A(-0.3 * blast), LegBR: A(-0.3 * blast), KneeBL: A(0.3), KneeBR: A(0.3),
		TailX: -0.55 * blast, TailY: shake * 3,
	};
	heads3((i) => {
		Q['Neck' + i] = A(0.3 * wind - 0.45 * blast + shake, sin(t * 31 + i) * 0.07 * blast, 0);
		Q['Jaw' + i] = A(-0.25 * wind - 0.65 * blast - sin(t * 20) * 0.08 * blast);
	});
	blend(P, Q, 1);
	c.ear = 'back';
};

ACTIONS.Rear = (s, P, c) => {
	const t = c.t, L = s.LegLen;
	const k = smooth01(c.at / 0.4);
	const theta = 1.0 * k;
	const box = sin(t * 12);
	const Q = {
		Body: T(0, L * 0.9 * sin(theta), 0.5 * L * k).mul(A(theta)),
		LegBL: A(-theta + 0.1), LegBR: A(-theta + 0.1), KneeBL: A(0.35), KneeBR: A(0.35),
		LegFL: A(-0.2 + box * 0.45), LegFR: A(-0.2 - box * 0.45),
		KneeFL: A(-0.9 - max(0, box) * 0.4), KneeFR: A(-0.9 - max(0, -box) * 0.4),
		TailX: 0.25, TailY: sin(t * 7) * 0.3,
	};
	heads3((i) => {
		Q['Neck' + i] = HEAD(-0.55 * k, s.LookYaw * 0.3, 0);
		Q['Jaw' + i] = A(-0.35 - max(0, box) * 0.2);
	});
	blend(P, Q, 1);
	c.ear = 'up';
};

ACTIONS.Slam = (s, P, c) => {
	const at = c.at, t = c.t, S = c.S;
	const up = smooth01(at / 0.16) * (1 - smooth01((at - 0.16) / 0.08));
	const hit = smooth01((at - 0.18) / 0.06);
	const ring = Math.exp(-max(0, at - 0.24) * 9) * hit;
	const shake = sin(t * 50) * 0.05 * ring;
	const Q = {
		Body: T(0, (0.35 * up - 0.3 * hit) * S, -0.15 * S * hit).mul(A(0.45 * up - 0.3 * hit + shake, 0, shake)),
		LegFL: A(-0.4 * up + 0.75 * hit), LegFR: A(-0.4 * up + 0.75 * hit), KneeFL: A(-1.0 * up), KneeFR: A(-1.0 * up),
		LegBL: A(-0.4 * up + 0.2 * hit), LegBR: A(-0.4 * up + 0.2 * hit), KneeBL: A(0.5 * up + 0.4 * hit), KneeBR: A(0.5 * up + 0.4 * hit),
		TailX: -0.4, TailY: shake * 4,
	};
	heads3((i) => {
		Q['Neck' + i] = A(0.25 * up - 0.3 * hit);
		Q['Jaw' + i] = A(-0.3 * up - 0.55 * hit);
	});
	blend(P, Q, 1);
	if (at > 0.2 && !s.ActionFx && !c.snap) {
		s.ActionFx = true;
		if (s.onDust) s.onDust(s.frontGround(1), 0.8 * sqrt(S));
	}
};

ACTIONS.Open = (s, P, c) => {
	const t = c.t, S = c.S;
	const Q = {
		Body: T(0, -0.05 * S, 0).mul(A(-0.06)),
		LegFL: A(0.2), LegFR: A(0.2), LegBL: A(-0.15), LegBR: A(-0.15), TailX: -0.2,
	};
	heads3((i) => {
		Q['Neck' + i] = A(0.1 + sin(t * 2 + i) * 0.04, sin(t * 1.5 + i) * 0.1, 0);
		Q['Jaw' + i] = A(-0.9 + sin(t * 14) * 0.05);
	});
	blend(P, Q, smooth01(c.at / 0.2));
};

ACTIONS.Eat = (s, P, c) => {
	const t = c.t, L = s.LegLen;
	const cycle = c.at % 3.2;
	const lift = smooth01((cycle - 2.3) / 0.25) * smooth01((3.2 - cycle) / 0.25);
	const chew = abs(sin(t * 10));
	const Q = {
		Body: T(0, -0.1 * L, 0).mul(A(-0.14)),
		LegFL: A(0.12, 0, 0.06), LegFR: A(0.12, 0, -0.06), KneeFL: A(-0.12), KneeFR: A(-0.12), LegBL: A(-0.05), LegBR: A(-0.05),
		TailX: 0, TailY: sin(t * 12) * 0.5,
	};
	heads3((i) => {
		Q['Neck' + i] = A(-0.85 + lift * 0.75 + chew * 0.04, sin(t * 1.1 + i) * 0.08, 0);
		Q['Jaw' + i] = A(-0.3 * chew);
	});
	blend(P, Q, smooth01(c.at / 0.3));
};

ACTIONS.Fly = (s, P, c) => {
	const t = c.t, S = c.S;
	const cruise = max(8, s.BaseSpeed * TUNE.FlyMult);
	const v = sqrt(s.Speed * s.Speed + s.VelY * s.VelY) / cruise;
	const glide = smooth01((v - 0.4) / 0.45);
	const hover = 1 - smooth01(v / 0.4);
	const climb = clamp(s.VelY / (cruise * 0.5), -1, 1);
	const dive = smooth01((-climb - 0.35) / 0.5) * glide;
	const boost = 1 - smooth01(c.at / 0.8);
	const push = clamp((s.Accel / cruise) * 1.5, 0, 1);
	if (!c.snap && c.now > (s.NextFlap || 0)) {
		s.NextFlap = c.now + 1.8 + Math.random() * 1.8;
		s.FlapAt = c.now;
	}
	const burst = c.snap ? 0 : pulse(c.now - (s.FlapAt ?? -10), 1.1);
	const beat = clamp(max(hover, boost, climb * 0.85, push * 0.8, burst * 0.7) * (1 - dive), 0, 1);
	const rate = (7 + 8 * beat) / max(1, S ** 0.35);
	s.FlapPhase = c.snap ? c.at * rate : (s.FlapPhase || 0) + c.dt * rate;
	const w = s.FlapPhase;
	const amp = 0.12 + 0.78 * beat;
	const stroke = (sin(w) + 0.25 * sin(2 * w)) * amp;
	const flat = s.WingFlat ?? 0.9;
	const bank = s.Bank;
	const turn = clamp(s.Yaw, -3, 3);
	const Q = {
		Body: T(0, stroke * 0.08 * S, 0).mul(A(0.55 * hover + 0.12 * boost - 0.05 * glide - 0.04 * stroke, turn * 0.05, 0)),
		TailX: 0.45 * glide + 0.1 * hover,
		TailY: -turn * 0.22 + sin(t * 3.1) * 0.08 * (1 - glide * 0.6),
	};
	const paddle = sin(t * 4) * 0.12 * hover;
	for (const leg of LEGS) {
		const side = SIDE[leg];
		if (FRONT[leg]) setLeg(s, Q, leg, (-0.85 - 0.2 * dive) * glide + (0.15 + paddle * side) * (1 - glide), 0.95 * glide + 0.45 * (1 - glide), S);
		else setLeg(s, Q, leg, (-1.25 - 0.15 * dive) * glide + (-0.25 - paddle * side) * (1 - glide), 0.12 * glide + 0.5 * (1 - glide), S);
	}
	const sweep = 0.06 + 0.22 * glide * min(v, 1.4) + 0.85 * dive;
	const fold = max(0, -cos(w)) * 0.55 * beat + 0.6 * dive;
	for (const side of [-1, 1]) {
		const name = side < 0 ? 'WingL' : 'WingR';
		const down = flat - 0.08 + stroke + side * turn * 0.05;
		Q[name] = A(0, -side * sweep, 0).mul(A(0, 0, -side * down));
		Q[name + '2'] = A(0, -side * fold, 0).mul(A(0, 0, -side * (0.04 - 0.12 * glide + sin(w - 0.8) * 0.4 * beat)));
	}
	heads3((i) => {
		Q['Neck' + i] = HEAD(0.08 * glide - 0.5 * hover + s.LookPitch * 0.6 - 0.03 * stroke, s.LookYaw * 0.8 + turn * 0.08, -bank * 0.55);
		Q['Jaw' + i] = A(-0.08 - 0.22 * glide * min(v, 1.3));
	});
	blend(P, Q, smooth01(c.at / 0.25));
	c.ear = 'back';
	c.wind = glide * min(v, 1.5);
};

ACTIONS.Float = (s, P, c) => {
	const t = c.t, S = c.S;
	const Q = {
		Body: T(0, (0.6 + sin(t * 2.4) * 0.18) * S, 0).mul(A(0.08 + sin(t * 1.2) * 0.04, sin(t * 0.7) * 0.08, sin(t * 1.3) * 0.05)),
		TailX: 0.25,
		TailY: sin(t * 1.6) * 0.4,
	};
	LEGS.forEach((leg, i) => setLeg(s, Q, leg, (FRONT[leg] ? -0.25 : 0.25) + sin(t * 1.8 + i + 1) * 0.12, 0.35 + sin(t * 1.8 + i + 1) * 0.1, S));
	flapWings(Q, sin(t * 5) * 0.4, sin(t * 5 - 0.7) * 0.35, 0.15, 0.1);
	heads3((i) => {
		Q['Neck' + i] = A(0.3 + sin(t * 2.4) * 0.05);
		Q['Jaw' + i] = A(-0.15);
	});
	blend(P, Q, smooth01(c.at / 0.4));
	c.ear = 'up';
};

function pounce(P, k, S) {
	if (k <= 0) return;
	P.Body = (P.Body || IDENT).mul(T(0, -0.12 * S * k, -0.12 * S * k)).mul(A(-0.1 * k));
	mul(P, 'LegFL', A(1.05 * k));
	mul(P, 'LegFR', A(0.85 * k));
	mul(P, 'KneeFL', A(-0.12 * k));
	mul(P, 'KneeFR', A(-0.2 * k));
	mul(P, 'LegBL', A(-0.95 * k));
	mul(P, 'LegBR', A(-0.8 * k));
	mul(P, 'KneeBL', A(0.12 * k));
	mul(P, 'KneeBR', A(0.2 * k));
	heads3((i) => mul(P, 'Neck' + i, A(0.06 * k)));
	P.TailX = (P.TailX || 0) + 0.45 * k;
}

ACTIONS.Dash = (s, P, c) => {
	body(P, T(0, -0.06 * c.S, 0).mul(A(-0.1)));
	heads3((i) => mul(P, 'Neck' + i, A(-0.18)));
	P.TailX = -0.35;
	P.TailY = sin(c.t * 8) * 0.12;
	if (!(s.DodgeForward && c.now - s.DodgeAt < 0.6)) pounce(P, pulse(c.at, 0.4), c.S);
	c.ear = 'back';
};

ACTIONS.Charge = (s, P, c) => {
	body(P, T(0, -0.1 * c.S, 0).mul(A(-0.16)));
	heads3((i) => {
		mul(P, 'Neck' + i, A(-0.5));
		P['Jaw' + i] = A(-0.05);
	});
	P.TailX = -0.5;
	c.ear = 'back';
};

ACTIONS.Zoom = (s, P, c) => {
	const t = c.t;
	body(P, A(-0.08, 0, sin(t * 7) * 0.08));
	heads3((i) => {
		mul(P, 'Neck' + i, A(sin(t * 11) * 0.12, sin(t * 6 + i) * 0.25, sin(t * 8) * 0.2));
		P['Jaw' + i] = A(-0.45 + sin(t * 20) * 0.08);
	});
	P.TailX = -0.2 + sin(t * 15) * 0.3;
	P.TailY = cos(t * 15) * 0.6;
};

ACTIONS.Spin = (s, P, c) => {
	const turns = c.at / 0.45;
	const S = c.S;
	const Q = {
		Body: T(0, 0.25 * S * sin(min(1, turns) * Math.PI), 0).mul(A(-0.05, -turns * TAU, 0)),
		TailX: -0.4,
		TailY: 0.6,
	};
	for (const leg of LEGS) setLeg(s, Q, leg, FRONT[leg] ? 0.5 : -0.4, 0.9, S);
	heads3((i) => (Q['Neck' + i] = A(-0.1)));
	blend(P, Q, 1);
	c.fast.Body = true;
};

ACTIONS.Shadow = (s, P, c) => {
	body(P, T(0, -0.18 * s.LegLen, 0).mul(A(-0.06)));
	mul(P, 'KneeFL', A(-0.35));
	mul(P, 'KneeFR', A(-0.35));
	mul(P, 'KneeBL', A(0.45));
	mul(P, 'KneeBR', A(0.45));
	heads3((i) => mul(P, 'Neck' + i, A(-0.2)));
	P.TailX = 0.3;
	P.TailY = sin(c.t * 2) * 0.2;
	c.ear = 'back';
	return 0.65;
};

ACTIONS.Vanish = (s, P, c) => {
	body(P, T(0, -0.2 * s.LegLen * smooth01(c.at / 0.15), 0));
	return 1;
};

ACTIONS.Dive = (s, P, c) => {
	const at = c.at, t = c.t, S = c.S;
	const dig = 1 - smooth01((at - 0.45) / 0.15);
	const sink = smooth01((at - 0.35) / 0.4);
	const d1 = sin(t * 24), d2 = sin(t * 24 + Math.PI);
	const Q = {
		Body: T(0, -(s.LegLen * 1.8 + 1.5 * S) * sink, -0.3 * S * sink).mul(A(-0.25 - 0.5 * sink)),
		LegBL: A(-0.3 - 0.4 * sink), LegBR: A(-0.3 - 0.4 * sink), KneeBL: A(0.5), KneeBR: A(0.5),
		TailX: -0.4, TailY: sin(t * 12) * 0.4 * dig,
	};
	setLeg(s, Q, 'LegFL', 0.4 + d1 * 0.6 * dig, 0.7 + max(0, d1) * 0.5 * dig, S);
	setLeg(s, Q, 'LegFR', 0.4 + d2 * 0.6 * dig, 0.7 + max(0, d2) * 0.5 * dig, S);
	heads3((i) => {
		Q['Neck' + i] = A(-0.5);
		Q['Jaw' + i] = A(-0.1);
	});
	blend(P, Q, smooth01(at / 0.1));
	c.ear = 'back';
};

ACTIONS.Aim = (s, P, c) => {
	const tr = sin(c.t * 25) * 0.005;
	const Q = {
		Body: T(0, -0.06 * c.S, 0).mul(A(-0.04 + tr)),
		LegFL: A(0.4), KneeFL: A(-1.25), LegFR: A(0.05), LegBL: A(-0.15), LegBR: A(-0.1), KneeBL: A(0.2),
		TailX: -0.25, TailY: 0,
	};
	heads3((i) => {
		Q['Neck' + i] = HEAD(0.02 + tr, s.LookYaw * 0.2, 0);
		Q['Jaw' + i] = IDENT;
	});
	blend(P, Q, smooth01(c.at / 0.25));
	c.ear = 'up';
};

ACTIONS.Sit = (s, P, c) => blend(P, sitPose(s, c), smooth01(c.at / 0.4));

ACTIONS.KO = (s, P, c) => {
	const at = c.at, t = c.t, L = s.LegLen;
	const wob = smooth01(at / 0.25) * (1 - smooth01((at - 0.25) / 0.2));
	const fall = smooth01((at - 0.3) / 0.35);
	const slow = sin(t * 1.1) * 0.012;
	const Q = {
		Body: T(0, -L * 0.8 * fall + slow * c.S, 0).mul(A(-0.1 * wob + slow, 0, sin(at * 18) * 0.12 * wob + 1.45 * fall)),
		TailX: 0.7,
		TailY: 0,
	};
	LEGS.forEach((leg, i) => setLeg(s, Q, leg, (FRONT[leg] ? 0.25 : 0.05) * fall + 0.2 * wob + sin(t * 0.6 + i + 1) * 0.02, 0.35 * fall, c.S));
	heads3((i) => {
		Q['Neck' + i] = A(-0.3 * wob - 0.15 * fall + slow);
		Q['Jaw' + i] = A(-0.28 * fall);
	});
	flapWings(Q, -0.25, 0.3, 0.2, 0.3);
	blend(P, Q, 1);
	c.ear = 'droop';
};

// ---- 6b. poses das habilidades
ACTIONS.Leap = (s, P, c) => {
	const at = c.at, t = c.t, S = c.S;
	const up = clamp(s.VelY / (12 * sqrt(S)), -1, 1);
	const down = max(0, -up);
	const Q = { Body: T(0, 0.1 * S, 0).mul(A(0.32 * up - 0.04, 0, 0)), TailX: -0.3 - 0.25 * max(0, up), TailY: sin(t * 9) * 0.15 };
	setLeg(s, Q, 'LegFL', 0.95 - 0.35 * down, 0.15 + 0.2 * down, S);
	setLeg(s, Q, 'LegFR', 0.8 - 0.35 * down, 0.25 + 0.2 * down, S);
	setLeg(s, Q, 'LegBL', -1.0 + 0.3 * down, 0.15, S);
	setLeg(s, Q, 'LegBR', -0.9 + 0.3 * down, 0.25, S);
	heads3((i) => {
		Q['Neck' + i] = HEAD(0.05 - 0.2 * up, s.LookYaw * 0.3, 0);
		Q['Jaw' + i] = A(-0.25 - 0.35 * down);
	});
	flapWings(Q, 0.35, 0.2, 0.1, 0.25);
	blend(P, Q, smooth01(at / 0.1));
	c.ear = 'back';
};

ACTIONS.Flip = (s, P, c) => {
	const u = clamp(c.at / 0.55, 0, 1);
	const S = c.S;
	const Q = { Body: T(0, 0.9 * S * sin(u * Math.PI), 0).mul(A(smooth01(u) * TAU, 0, 0)), TailX: -0.4, TailY: 0 };
	for (const leg of LEGS) setLeg(s, Q, leg, FRONT[leg] ? 0.6 : -0.5, 1.0, S);
	heads3((i) => {
		Q['Neck' + i] = A(-0.2);
		Q['Jaw' + i] = A(-0.1);
	});
	foldWings(Q, 0.2);
	blend(P, Q, 1);
	c.fast.Body = true;
	c.ear = 'back';
};

function curlPose(s, c, spin) {
	const S = c.S, L = s.LegLen;
	const k = smooth01(c.at / 0.15);
	const Q = { Body: T(0, (-0.35 * L + 0.35 * S) * k, 0).mul(A(-spin, 0, 0)).mul(A(-0.3 * k, 0, 0)), TailX: 0.6 * k, TailY: 0 };
	for (const leg of LEGS) setLeg(s, Q, leg, (FRONT[leg] ? -0.6 : 0.7) * k, 1.4 * k, S);
	heads3((i) => {
		Q['Neck' + i] = A(-0.9 * k);
		Q['Jaw' + i] = IDENT;
	});
	foldWings(Q, 0);
	return Q;
}
ACTIONS.Curl = (s, P, c) => {
	blend(P, curlPose(s, c, 0), 1);
	c.ear = 'droop';
};
ACTIONS.Roll = (s, P, c) => {
	blend(P, curlPose(s, c, c.at * 12), 1);
	c.fast.Body = true;
	c.ear = 'droop';
};

ACTIONS.Drill = (s, P, c) => {
	const S = c.S;
	const Q = { Body: T(0, 0.1 * S, 0).mul(A(-0.1, 0, c.at * 18)), TailX: -0.5, TailY: 0 };
	for (const leg of LEGS) setLeg(s, Q, leg, FRONT[leg] ? 1.0 : -1.0, 0.2, S);
	heads3((i) => {
		Q['Neck' + i] = A(-0.2);
		Q['Jaw' + i] = A(-0.2);
	});
	foldWings(Q, 0);
	blend(P, Q, 1);
	c.fast.Body = true;
	c.ear = 'back';
};

ACTIONS.Kick = (s, P, c) => {
	const at = c.at, S = c.S;
	const load = smooth01(at / 0.15) * (1 - smooth01((at - 0.15) / 0.06));
	const kick = smooth01((at - 0.17) / 0.07) * (1 - smooth01((at - 0.45) / 0.2));
	const Q = {
		Body: T(0, (0.15 * kick - 0.08 * load) * S, -0.1 * kick * S).mul(A(-0.35 * kick + 0.1 * load, 0, 0)),
		LegFL: A(0.25 * kick), LegFR: A(0.25 * kick), KneeFL: A(-0.2), KneeFR: A(-0.2), TailX: -0.6 * kick, TailY: 0,
	};
	setLeg(s, Q, 'LegBL', 0.4 * load - 1.5 * kick, 0.9 * load + 0.1, S);
	setLeg(s, Q, 'LegBR', 0.4 * load - 1.4 * kick, 0.9 * load + 0.1, S);
	heads3((i) => {
		Q['Neck' + i] = A(-0.3 * kick + 0.1 * load);
		Q['Jaw' + i] = A(-0.25 * kick);
	});
	blend(P, Q, 1);
	c.ear = 'back';
};

ACTIONS.Dig = (s, P, c) => {
	const t = c.t, S = c.S;
	const d1 = sin(t * 22), d2 = sin(t * 22 + Math.PI);
	const Q = {
		Body: T(0, -0.05 * S, 0).mul(A(-0.28, 0, sin(t * 11) * 0.03)),
		LegBL: A(-0.2), LegBR: A(-0.2), KneeBL: A(0.4), KneeBR: A(0.4), TailX: -0.5, TailY: sin(t * 14) * 0.4,
	};
	setLeg(s, Q, 'LegFL', 0.35 + d1 * 0.55, 0.6 + max(0, d1) * 0.6, S);
	setLeg(s, Q, 'LegFR', 0.35 + d2 * 0.55, 0.6 + max(0, d2) * 0.6, S);
	heads3((i) => {
		Q['Neck' + i] = A(-0.6 + sin(t * 5) * 0.05);
		Q['Jaw' + i] = A(-0.1);
	});
	blend(P, Q, smooth01(c.at / 0.12));
	c.ear = 'droop';
	if (!c.snap && c.now > (s.NextDig || 0)) {
		s.NextDig = c.now + 0.16;
		if (s.onDust) s.onDust(s.frontGround(0.8), 0.4 * sqrt(S));
	}
};

ACTIONS.Bark = (s, P, c) => {
	const at = c.at, t = c.t, S = c.S;
	const ph = (at % 0.32) / 0.32;
	const snap = sin(min(1, ph / 0.35) * Math.PI);
	const Q = {
		Body: T(0, 0.04 * S * snap, -0.12 * S * snap).mul(A(0.06 * snap, 0, 0)),
		LegFL: A(0.25 * snap), LegFR: A(0.25 * snap), KneeFL: A(-0.15 * snap), KneeFR: A(-0.15 * snap), LegBL: A(-0.1), LegBR: A(-0.1),
		TailX: -0.4, TailY: sin(t * 16) * 0.3,
	};
	heads3((i) => {
		Q['Neck' + i] = HEAD(0.15 + 0.25 * snap, s.LookYaw * 0.4, 0).mul(T(0, 0, -0.15 * S * snap));
		Q['Jaw' + i] = A(-0.75 * snap);
	});
	blend(P, Q, smooth01(at / 0.08));
	c.ear = snap > 0.3 ? 'back' : 'up';
};

ACTIONS.Spit = (s, P, c) => {
	const at = c.at, S = c.S;
	const ph = at % 0.35;
	const back = smooth01(ph / 0.1) * (1 - smooth01((ph - 0.1) / 0.05));
	const out = smooth01((ph - 0.11) / 0.06) * (1 - smooth01((ph - 0.24) / 0.1));
	const Q = { Body: T(0, 0, (0.1 * back - 0.12 * out) * S).mul(A(0.06 * back - 0.04 * out)), TailX: -0.3, TailY: 0 };
	heads3((i) => {
		Q['Neck' + i] = HEAD(0.25 * back - 0.1 * out, s.LookYaw * 0.4, 0).mul(T(0, 0, (0.1 * back - 0.2 * out) * S));
		Q['Jaw' + i] = A(-0.15 * back - 0.75 * out);
	});
	blend(P, Q, smooth01(at / 0.06));
	c.ear = 'back';
};

ACTIONS.Sniff = (s, P, c) => {
	const t = c.t, S = c.S;
	const sweep = sin(t * 2.2) * 0.35;
	const sniff = sin(t * 28) * 0.03;
	const Q = {
		Body: T(0, -0.08 * S, 0).mul(A(-0.12, sweep * 0.3, 0)),
		LegFL: A(0.12), LegFR: A(0.12), KneeFL: A(-0.25), KneeFR: A(-0.25), TailX: -0.3, TailY: sin(t * 13) * 0.5,
	};
	heads3((i) => {
		Q['Neck' + i] = HEAD(-0.75 + sniff, sweep, 0);
		Q['Jaw' + i] = A(-0.05);
	});
	blend(P, Q, smooth01(c.at / 0.2));
	c.ear = 'droop';
};

ACTIONS.Bow = (s, P, c) => {
	const t = c.t, L = s.LegLen;
	const Q = {
		Body: T(0, -0.25 * L, 0).mul(A(-0.35, 0, 0)),
		LegFL: A(0.9), LegFR: A(0.9), KneeFL: A(-0.1), KneeFR: A(-0.1), LegBL: A(-0.1), LegBR: A(-0.1),
		TailX: -0.7, TailY: sin(t * 18) * 0.6,
	};
	heads3((i) => {
		Q['Neck' + i] = HEAD(0.45, sin(t * 3) * 0.1, sin(t * 2) * 0.15);
		Q['Jaw' + i] = A(-0.3);
	});
	blend(P, Q, smooth01(c.at / 0.2));
	c.ear = 'up';
};

ACTIONS.Throw = (s, P, c) => {
	const at = c.at, S = c.S;
	const wind = smooth01(at / 0.18) * (1 - smooth01((at - 0.2) / 0.08));
	const fling = smooth01((at - 0.2) / 0.1) * (1 - smooth01((at - 0.55) / 0.25));
	const Q = {
		Body: T(0, 0, (0.1 * wind - 0.15 * fling) * S).mul(A(-0.1 * wind + 0.18 * fling, 0.25 * wind - 0.15 * fling, 0)),
		LegFL: A(-0.15 * wind + 0.3 * fling), LegFR: A(0.1 * fling), TailX: -0.3, TailY: 0.3 * wind,
	};
	heads3((i) => {
		Q['Neck' + i] = HEAD(-0.55 * wind + 0.7 * fling, 0.6 * wind - 0.2 * fling, 0);
		Q['Jaw' + i] = A(-0.15 * wind - 0.5 * fling);
	});
	blend(P, Q, 1);
	c.ear = 'back';
};

ACTIONS.Uppercut = (s, P, c) => {
	const at = c.at, t = c.t, S = c.S, L = s.LegLen;
	const crouch = smooth01(at / 0.12) * (1 - smooth01((at - 0.12) / 0.06));
	const rise = smooth01((at - 0.14) / 0.12) * (1 - smooth01((at - 0.6) / 0.2));
	const theta = 0.9 * rise;
	const Q = {
		Body: T(0, L * 0.85 * sin(theta) - 0.15 * L * crouch, 0.4 * L * rise).mul(A(theta - 0.1 * crouch)),
		LegBL: A(-theta + 0.1), LegBR: A(-theta + 0.1), KneeBL: A(0.35 + 0.4 * crouch), KneeBR: A(0.35 + 0.4 * crouch),
		TailX: 0.2, TailY: sin(t * 7) * 0.2,
	};
	setLeg(s, Q, 'LegFR', -0.4 * crouch + 1.6 * rise, 0.9 * crouch + 0.1, S);
	setLeg(s, Q, 'LegFL', -0.2, 0.9, S);
	heads3((i) => {
		Q['Neck' + i] = HEAD(-0.4 * rise + 0.2, s.LookYaw * 0.3, 0);
		Q['Jaw' + i] = A(-0.3 * rise);
	});
	blend(P, Q, 1);
	c.ear = 'up';
};

ACTIONS.Headbutt = (s, P, c) => {
	const at = c.at, S = c.S;
	const load = smooth01(at / 0.2) * (1 - smooth01((at - 0.22) / 0.06));
	const ram = smooth01((at - 0.22) / 0.08) * (1 - smooth01((at - 0.5) / 0.2));
	const Q = {
		Body: T(0, -0.12 * S * load, (0.18 * load - 0.45 * ram) * S).mul(A(-0.12 * load - 0.08 * ram)),
		LegFL: A(-0.2 * load + 0.4 * ram), LegFR: A(-0.2 * load + 0.4 * ram), KneeFL: A(-0.4 * load), KneeFR: A(-0.4 * load),
		LegBL: A(0.25 * load - 0.5 * ram), LegBR: A(0.25 * load - 0.5 * ram), KneeBL: A(0.6 * load), KneeBR: A(0.6 * load),
		TailX: -0.5, TailY: 0,
	};
	heads3((i) => {
		Q['Neck' + i] = A(-0.55 * load - 0.35 * ram).mul(T(0, 0, -0.2 * S * ram));
		Q['Jaw' + i] = A(-0.05);
	});
	blend(P, Q, 1);
	c.ear = 'back';
};

ACTIONS.Stomp = (s, P, c) => {
	const at = c.at, S = c.S;
	const n = Math.floor(at / 0.36);
	const cyc = (at % 0.36) / 0.36;
	const side = n % 2 === 0 ? 1 : -1;
	const lift = sin(min(1, cyc / 0.6) * Math.PI);
	const Q = { Body: T(0, 0.08 * S * lift, 0).mul(A(0.12 * lift, 0, 0.06 * side * lift)), TailX: -0.3, TailY: 0 };
	setLeg(s, Q, side > 0 ? 'LegFR' : 'LegFL', 0.2 - 0.3 * lift, 1.2 * lift, S);
	setLeg(s, Q, side > 0 ? 'LegFL' : 'LegFR', 0.1, 0.1, S);
	heads3((i) => {
		Q['Neck' + i] = A(0.1 * lift - 0.15);
		Q['Jaw' + i] = A(-0.3);
	});
	blend(P, Q, smooth01(at / 0.1));
	if (cyc > 0.6 && !c.snap && s.LastStomp !== n) {
		s.LastStomp = n;
		if (s.onDust) s.onDust(s.frontGround(0.6), 0.5 * sqrt(S));
	}
	c.ear = 'back';
};

ACTIONS.Summon = (s, P, c) => {
	const at = c.at, t = c.t, S = c.S, L = s.LegLen;
	const k = smooth01(at / 0.35);
	const theta = 0.75 * k;
	const Q = {
		Body: T(0, L * 0.75 * sin(theta), 0.35 * L * k).mul(A(theta + sin(t * 3) * 0.02)),
		LegBL: A(-theta + 0.1), LegBR: A(-theta + 0.1), KneeBL: A(0.3), KneeBR: A(0.3), TailX: 0.1, TailY: sin(t * 3) * 0.3,
	};
	setLeg(s, Q, 'LegFL', 0.9 * k + sin(t * 4) * 0.08, 0.3, S);
	setLeg(s, Q, 'LegFR', 0.9 * k + sin(t * 4 + 1) * 0.08, 0.3, S);
	heads3((i) => {
		Q['Neck' + i] = HEAD(0.25 * k, (i - 2) * 0.25 * (c.heads > 1 ? 1 : 0), 0);
		Q['Jaw' + i] = A(-0.35 * k);
	});
	flapWings(Q, -0.35 * k + sin(t * 4) * 0.1, 0.1, 0, 0.1);
	blend(P, Q, 1);
	c.ear = 'up';
};

ACTIONS.Focus = (s, P, c) => {
	const t = c.t, S = c.S, L = s.LegLen;
	const k = smooth01(c.at / 0.3);
	const tr = sin(t * 38) * 0.012 * k;
	const Q = { Body: T(0, (-0.25 * L + 0.08 * S * sin(t * 2.5)) * k, 0).mul(A(-0.08 * k + tr, 0, tr)), TailX: 0.4, TailY: sin(t * 2) * 0.1 };
	for (const leg of LEGS) setLeg(s, Q, leg, FRONT[leg] ? 0.25 : -0.25, 0.8 * k, S);
	heads3((i) => {
		Q['Neck' + i] = A(-0.45 * k);
		Q['Jaw' + i] = IDENT;
	});
	flapWings(Q, -0.3 * k, -0.2 * k, 0, 0);
	blend(P, Q, 1);
	c.ear = 'back';
};

ACTIONS.Flex = (s, P, c) => {
	const at = c.at, t = c.t, S = c.S, L = s.LegLen;
	const k = smooth01(at / 0.25);
	const pump = sin(t * 6) * 0.5 + 0.5;
	const theta = 0.55 * k;
	const Q = {
		Body: T(0, L * 0.45 * sin(theta), 0.2 * L * k).mul(A(theta)),
		LegBL: A(-theta - 0.2), LegBR: A(-theta - 0.2), KneeBL: A(0.5), KneeBR: A(0.5), TailX: 0, TailY: sin(t * 10) * 0.4,
	};
	setLeg(s, Q, 'LegFL', 0.6 * k + 0.2 * pump, 1.3 * k, S);
	setLeg(s, Q, 'LegFR', 0.6 * k + 0.2 * (1 - pump), 1.3 * k, S);
	Q.LegFL = Q.LegFL.mul(A(0, 0, -0.35 * k));
	Q.LegFR = Q.LegFR.mul(A(0, 0, 0.35 * k));
	heads3((i) => {
		Q['Neck' + i] = HEAD(0.2 * k - 0.35 * k, sin(t * 2) * 0.2, 0);
		Q['Jaw' + i] = A(-0.2 * k);
	});
	blend(P, Q, 1);
	c.ear = 'up';
};

ACTIONS.Slide = (s, P, c) => {
	const t = c.t, S = c.S, L = s.LegLen;
	const k = smooth01(c.at / 0.15);
	const Q = { Body: T(0, -0.75 * L * k, 0).mul(A(0.05 * k, 0, sin(t * 6) * 0.03)), TailX: -0.2, TailY: sin(t * 8) * 0.3 };
	setLeg(s, Q, 'LegFL', 1.2 * k, 0.1, S);
	setLeg(s, Q, 'LegFR', 1.2 * k, 0.1, S);
	setLeg(s, Q, 'LegBL', -1.3 * k, 0.1, S);
	setLeg(s, Q, 'LegBR', -1.3 * k, 0.1, S);
	heads3((i) => {
		Q['Neck' + i] = HEAD(0.35 * k, 0, 0);
		Q['Jaw' + i] = A(-0.4 * k);
	});
	foldWings(Q, 0.3);
	blend(P, Q, 1);
	c.ear = 'back';
};

ACTIONS.Bounce = (s, P, c) => {
	const at = c.at, t = c.t, S = c.S, L = s.LegLen;
	const ph = (at % 0.42) / 0.42;
	const h = sin(ph * Math.PI);
	const squash = 1 - smooth01(ph / 0.15) + smooth01((ph - 0.85) / 0.15);
	const Q = {
		Body: T(0, L * (0.9 * h - 0.15 * squash), 0).mul(A(0.1 * h - 0.05 * squash, 0, sin(t * 5) * 0.06)),
		TailX: -0.3 * h,
		TailY: sin(t * 15) * 0.5,
	};
	for (const leg of LEGS) setLeg(s, Q, leg, (FRONT[leg] ? 0.3 : -0.3) * h, 0.6 * squash + 0.3 * h, S);
	heads3((i) => {
		Q['Neck' + i] = HEAD(0.2 * h, 0, sin(t * 5) * 0.1);
		Q['Jaw' + i] = A(-0.35 * h);
	});
	flapWings(Q, sin(t * 20) * 0.4 * h, 0.2, 0.1, 0.1);
	blend(P, Q, 1);
	c.ear = h > 0.5 ? 'up' : 'droop';
};

ACTIONS.Twirl = (s, P, c) => {
	const at = c.at, L = s.LegLen;
	const k = smooth01(at / 0.2);
	const theta = 0.6 * k;
	const Q = {
		Body: T(0, L * 0.5 * sin(theta), 0.2 * L * k).mul(A(0, -at * 13, 0)).mul(A(theta, 0, 0)),
		LegBL: A(-theta), LegBR: A(-theta), TailX: -0.3, TailY: 0.6,
	};
	setLeg(s, Q, 'LegFL', 0.5 * k, 0.8, c.S);
	setLeg(s, Q, 'LegFR', 0.5 * k, 0.8, c.S);
	heads3((i) => {
		Q['Neck' + i] = HEAD(0.3 - 0.4 * k, 0, 0.2);
		Q['Jaw' + i] = A(-0.2);
	});
	blend(P, Q, 1);
	c.fast.Body = true;
	c.ear = 'back';
};

ACTIONS.Guard = (s, P, c) => {
	const t = c.t, S = c.S, L = s.LegLen;
	const k = smooth01(c.at / 0.2);
	const br = sin(t * 3) * 0.02;
	const Q = {
		Body: T(0, -0.2 * L * k, 0.08 * S * k).mul(A(-0.08 * k + br, 0, 0)),
		LegFL: A(0.3 * k, 0, -0.25 * k), LegFR: A(0.3 * k, 0, 0.25 * k), KneeFL: A(-0.35 * k), KneeFR: A(-0.35 * k),
		LegBL: A(-0.25 * k, 0, -0.2 * k), LegBR: A(-0.25 * k, 0, 0.2 * k), KneeBL: A(0.5 * k), KneeBR: A(0.5 * k),
		TailX: 0.1, TailY: 0,
	};
	heads3((i) => {
		Q['Neck' + i] = HEAD(-0.3 * k, s.LookYaw * 0.5, 0);
		Q['Jaw' + i] = A(-0.12 * k);
	});
	foldWings(Q, 0.6);
	blend(P, Q, 1);
	c.ear = 'back';
};

ACTIONS.Slash = (s, P, c) => {
	const at = c.at, S = c.S;
	const wind = smooth01(at / 0.15) * (1 - smooth01((at - 0.16) / 0.05));
	const cut = smooth01((at - 0.16) / 0.09);
	const back = 1 - smooth01((at - 0.45) / 0.25);
	const yaw = 0.7 * wind - 0.9 * cut * back;
	const Q = {
		Body: T(0, -0.06 * S, -0.15 * S * cut * back).mul(A(-0.05, yaw * 0.6, -0.08 * cut * back)),
		LegFL: A(0.35 * cut * back), LegBR: A(-0.35 * cut * back), TailX: -0.3, TailY: -yaw * 0.8,
	};
	heads3((i) => {
		Q['Neck' + i] = HEAD(0.05, yaw, -yaw * 0.3);
		Q['Jaw' + i] = A(-0.06);
	});
	blend(P, Q, 1);
	c.ear = 'back';
};

ACTIONS.Inhale = (s, P, c) => {
	const t = c.t, S = c.S;
	const k = smooth01(c.at / 0.4);
	const Q = {
		Body: T(0, 0.05 * S * k, 0.12 * S * k).mul(A(0.15 * k, 0, 0)),
		LegFL: A(-0.1 * k), LegFR: A(-0.1 * k), TailX: -0.2, TailY: sin(t * 5) * 0.1,
	};
	heads3((i) => {
		Q['Neck' + i] = HEAD(0.55 * k, 0, 0);
		Q['Jaw' + i] = A(-0.15 * k);
	});
	flapWings(Q, -0.4 * k, -0.2 * k, 0, 0.1);
	blend(P, Q, 1);
	c.ear = 'back';
};

ACTIONS.Belly = (s, P, c) => {
	const S = c.S, L = s.LegLen;
	const k = smooth01(c.at / 0.15);
	const fall = s.VelY < -2 ? 1 : 0;
	const Q = { Body: T(0, -0.5 * L * k * fall, 0).mul(A(-0.05 * k, 0, 0)), TailX: -0.4, TailY: 0 };
	setLeg(s, Q, 'LegFL', 1.0 * k, 0.1, S);
	setLeg(s, Q, 'LegFR', 1.0 * k, 0.1, S);
	setLeg(s, Q, 'LegBL', -1.0 * k, 0.1, S);
	setLeg(s, Q, 'LegBR', -1.0 * k, 0.1, S);
	Q.LegFL = Q.LegFL.mul(A(0, 0, -0.6 * k));
	Q.LegFR = Q.LegFR.mul(A(0, 0, 0.6 * k));
	Q.LegBL = Q.LegBL.mul(A(0, 0, -0.6 * k));
	Q.LegBR = Q.LegBR.mul(A(0, 0, 0.6 * k));
	heads3((i) => {
		Q['Neck' + i] = HEAD(0.3 * k, 0, 0);
		Q['Jaw' + i] = A(-0.5 * k);
	});
	flapWings(Q, 0, 0, 0, 0);
	blend(P, Q, 1);
	c.ear = 'back';
};

ACTIONS.Snore = (s, P, c) => {
	blend(P, liePose(s, c), smooth01(c.at / 0.3));
	const breath = sin(c.t * 3);
	body(P, T(0, 0.05 * c.S * breath, 0));
	heads3((i) => {
		mul(P, 'Neck' + i, A(-0.15 + 0.06 * breath));
		P['Jaw' + i] = A(-0.08 - 0.12 * max(0, breath));
	});
	c.ear = 'droop';
};

ACTIONS.Victory = (s, P, c) => {
	const at = c.at, t = c.t, S = c.S, L = s.LegLen;
	const k = smooth01(at / 0.3);
	const theta = 1.05 * k;
	const Q = {
		Body: T(0, L * 0.95 * sin(theta), 0.5 * L * k).mul(A(theta, 0, sin(t * 5) * 0.08)),
		LegBL: A(-theta + 0.1), LegBR: A(-theta + 0.1), KneeBL: A(0.3), KneeBR: A(0.3), TailX: 0, TailY: sin(t * 16) * 0.7,
	};
	setLeg(s, Q, 'LegFL', 0.4 + sin(t * 10) * 0.5, 0.4, S);
	setLeg(s, Q, 'LegFR', 0.4 + sin(t * 10 + Math.PI) * 0.5, 0.4, S);
	heads3((i) => {
		Q['Neck' + i] = HEAD(-0.3 * k + sin(t * 5) * 0.1, sin(t * 2.5) * 0.3, 0);
		Q['Jaw' + i] = A(-0.45 * k);
	});
	flapWings(Q, sin(t * 9) * 0.5, sin(t * 9 - 0.6) * 0.4, 0.1, 0.1);
	blend(P, Q, 1);
	c.ear = 'up';
};

ACTIONS.Wiggle = (s, P, c) => {
	const t = c.t, S = c.S;
	const beat = sin(t * 9);
	const Q = {
		Body: T(0, abs(beat) * 0.08 * S, 0).mul(A(0, beat * 0.25, beat * 0.12)),
		LegBL: A(-0.1 + beat * 0.15), LegBR: A(-0.1 - beat * 0.15), TailX: -0.5, TailY: beat * 0.9,
	};
	heads3((i) => {
		Q['Neck' + i] = HEAD(0.15 + abs(beat) * 0.15, -beat * 0.2, beat * 0.25);
		Q['Jaw' + i] = A(-0.25 - abs(beat) * 0.2);
	});
	flapWings(Q, beat * 0.3, 0.1, 0, 0.1);
	blend(P, Q, smooth01(c.at / 0.15));
	c.ear = 'up';
};

ACTIONS.Shake = (s, P, c) => {
	const at = c.at, t = c.t;
	const env = smooth01(at / 0.1) * (1 - smooth01((at - 0.6) / 0.25));
	const w = sin(t * 34);
	const Q = {
		Body: A(0, w * 0.15 * env, w * 0.4 * env),
		LegFL: A(0.1, 0, -0.15), LegFR: A(0.1, 0, 0.15), LegBL: A(-0.1, 0, -0.15), LegBR: A(-0.1, 0, 0.15),
		TailX: -0.2, TailY: -w * 0.8 * env,
	};
	heads3((i) => {
		Q['Neck' + i] = HEAD(0.05, -w * 0.5 * env, -w * 0.4 * env);
		Q['Jaw' + i] = A(-0.1);
	});
	blend(P, Q, 1);
	c.fast.Body = true;
	c.ear = 'up';
	s.EarKick += 0.6 * env;
};

const GENERIC = ['push', 'stomp', 'channel', 'lunge'];
function genericAction(s, P, c) {
	const name = c.action;
	let h = 0;
	for (let i = 0; i < name.length; i++) h = (h * 31 + name.charCodeAt(i)) % 997;
	const kind = GENERIC[h % GENERIC.length];
	const at = c.at, t = c.t, S = c.S;
	const wind = smooth01(at / 0.2);
	const go = smooth01((at - 0.2) / 0.12);
	const Q = {};
	if (kind === 'push') {
		Q.Body = T(0, -0.08 * S, (0.08 * wind - 0.2 * go) * S).mul(A(0.08 * wind - 0.08 * go));
		setLeg(s, Q, 'LegFL', -0.3 * wind + 0.8 * go, 0.8 * wind * (1 - go), S);
		setLeg(s, Q, 'LegFR', -0.3 * wind + 0.8 * go, 0.8 * wind * (1 - go), S);
		Q.LegBL = A(-0.35 * go);
		Q.LegBR = A(-0.35 * go);
		heads3((i) => {
			Q['Neck' + i] = A(0.15 * wind + 0.2 * go);
			Q['Jaw' + i] = A(-0.6 * go);
		});
		Q.TailX = -0.4 * go;
	} else if (kind === 'stomp') {
		const lift = sin(((at % 0.7) / 0.7) * Math.PI);
		Q.Body = T(0, 0.15 * S * lift, 0).mul(A(0.25 * lift));
		setLeg(s, Q, 'LegFL', -0.3 * lift, 0.9 * lift, S);
		setLeg(s, Q, 'LegFR', -0.3 * lift, 0.9 * lift, S);
		heads3((i) => {
			Q['Neck' + i] = A(0.2 * lift - 0.1);
			Q['Jaw' + i] = A(-0.4);
		});
		Q.TailX = -0.3;
	} else if (kind === 'channel') {
		const tr = sin(t * 40) * 0.02 * (1 - go);
		Q.Body = T(0, (-0.15 * (1 - go) + 0.05 * go) * S, 0).mul(A(-0.1 * (1 - go) + 0.15 * go + tr, 0, tr));
		for (const leg of LEGS) setLeg(s, Q, leg, 0, 0.45 * (1 - go), S);
		heads3((i) => {
			Q['Neck' + i] = A(-0.45 * (1 - go) + 0.65 * go);
			Q['Jaw' + i] = A(-0.75 * go);
		});
		Q.TailX = -0.5 * go;
		flapWings(Q, -0.3 * go, 0, 0, 0);
	} else {
		Q.Body = T(0, -0.1 * S * wind, (0.1 * wind - 0.45 * go) * S).mul(A(-0.15 * go));
		Q.LegFL = A(0.6 * go);
		Q.LegFR = A(0.6 * go);
		Q.LegBL = A(-0.5 * go);
		Q.LegBR = A(-0.5 * go);
		heads3((i) => {
			Q['Neck' + i] = A(-0.1);
			Q['Jaw' + i] = A(-0.8 * go * (1 - smooth01((at - 0.45) / 0.1)));
		});
		Q.TailX = -0.35;
	}
	blend(P, Q, smooth01(at / 0.1));
	c.ear = 'back';
}

// ---------------------------------------------------------------- 7. CAMADAS POR CIMA
const BITE_TIME = 0.38;
function bitePose(s, P, c) {
	let bodyDone = false;
	for (const head in s.Bites) {
		const b = s.Bites[head];
		const bt = c.now - b.At;
		if (bt > BITE_TIME) {
			delete s.Bites[head];
			continue;
		}
		const S = c.S;
		const wind = smooth01(bt / 0.07) * (1 - smooth01((bt - 0.07) / 0.05));
		const strike = smooth01((bt - 0.07) / 0.08) * (1 - smooth01((bt - 0.2) / 0.14));
		const open = bt < 0.15 ? smooth01(bt / 0.1) : 1 - smooth01((bt - 0.15) / 0.04);
		const shakeK = smooth01((bt - 0.18) / 0.04) * (1 - smooth01((bt - 0.3) / 0.08));
		let yaw = 0, pitch = 0;
		if (b.Variant === 2) yaw = (0.4 - 0.8 * smooth01((bt - 0.07) / 0.1)) * b.Side;
		else if (b.Variant === 3) pitch = -0.35 + 0.6 * smooth01((bt - 0.07) / 0.1);
		const neck = 'Neck' + head, jaw = 'Jaw' + head;
		const big = b.Big ? 1.5 : 1;
		mul(P, neck, T(0, 0, (0.18 * wind - 0.6 * strike * big) * S).mul(A(0.15 * wind - 0.1 * strike + pitch * strike, yaw * strike + sin(c.t * 45) * 0.12 * shakeK, 0)));
		P[jaw] = A(-0.95 * open);
		c.fast[neck] = true;
		c.fast[jaw] = true;
		if (!bodyDone) {
			bodyDone = true;
			body(P, T(0, (0.03 * wind - 0.06 * strike) * S, (0.1 * wind - 0.3 * strike * big) * S).mul(A(0.07 * wind - 0.1 * strike * big)));
			mul(P, 'LegFL', A(0.3 * strike - 0.1 * wind));
			mul(P, 'LegFR', A(0.3 * strike - 0.1 * wind));
			mul(P, 'LegBL', A(-0.25 * strike));
			mul(P, 'LegBR', A(-0.25 * strike));
			P.TailX = (P.TailX || 0) - 0.3 * strike;
		}
		c.ear = 'back';
	}
}

const SWIPE_TIME = 0.42;
function swipePose(s, P, c) {
	for (const key in s.Swipes) {
		const side = Number(key);
		const sw = s.Swipes[key];
		const t = c.now - sw.At;
		if (t > SWIPE_TIME) {
			delete s.Swipes[key];
			continue;
		}
		const S = c.S;
		const leg = side > 0 ? 'LegFR' : 'LegFL';
		const knee = KNEE_OF[leg];
		const up = smooth01(t / 0.09);
		const strike = smooth01((t - 0.09) / 0.08);
		const back = smooth01((t - 0.22) / 0.2);
		const k = up * (1 - back);
		const hit = strike * (1 - back);
		P[leg] = (P[leg] || IDENT).lerp(A(1.55 - 1.1 * strike, 0, side * (0.3 - 0.7 * strike)), k);
		P[knee] = (P[knee] || IDENT).lerp(A(FLEX[leg] * (0.95 - 0.8 * strike) * 1.15), k);
		mul(P, side > 0 ? 'LegFL' : 'LegFR', A(0.1 * k, 0, -side * 0.08 * k));
		body(P, T(0, 0.05 * S * k, -0.12 * S * hit).mul(A(0.1 * up * (1 - strike) - 0.06 * hit, side * 0.12 * hit, side * 0.1 * k)));
		heads3((i) => {
			mul(P, 'Neck' + i, HEAD(-0.08 * k, side * 0.15 * hit, -side * 0.1 * k));
			mul(P, 'Jaw' + i, A(-0.25 * k));
		});
		c.fast[leg] = true;
		c.fast[knee] = true;
		c.ear = 'back';
	}
}

function hitPose(s, P, c) {
	const k = pulse(c.now - s.HitAt, 0.4) * s.HitPower;
	if (k <= 0) return;
	const side = s.HitSide;
	body(P, T(0, -0.05 * c.S * k, 0.22 * c.S * k).mul(A(0.12 * k, side * 0.15 * k, side * 0.18 * k)));
	heads3((i) => {
		mul(P, 'Neck' + i, A(0.3 * k, -side * 0.35 * k, side * 0.2 * k));
		mul(P, 'Jaw' + i, A(-0.3 * k));
	});
	mul(P, 'LegFL', A(0.3 * k));
	mul(P, 'LegFR', A(0.2 * k));
	mul(P, 'KneeBL', A(0.4 * k));
	mul(P, 'KneeBR', A(0.4 * k));
	P.TailX = (P.TailX || 0) + 0.5 * k;
	c.ear = 'back';
}

function dodgePose(s, P, c) {
	if (c.action === 'Fly') {
		const kk = pulse(c.now - s.DodgeAt, 0.55);
		if (kk > 0) {
			for (const side of [-1, 1]) mul(P, side < 0 ? 'WingL' : 'WingR', A(0, -side * 0.6 * kk, 0));
			mul(P, 'KneeFL', A(-0.5 * kk));
			mul(P, 'KneeFR', A(-0.5 * kk));
			mul(P, 'LegBL', A(-0.3 * kk));
			mul(P, 'LegBR', A(-0.3 * kk));
			c.ear = 'back';
		}
		return;
	}
	if (s.DodgeForward) {
		pounce(P, pulse(c.now - s.DodgeAt, 0.4), c.S);
		if (c.now - s.DodgeAt < 0.4) c.ear = 'back';
		return;
	}
	const k = pulse(c.now - s.DodgeAt, 0.35);
	if (k <= 0) return;
	const d = s.DodgeDir;
	body(P, T(0, 0.35 * c.S * k, 0).mul(A(d[2] * 0.3 * k, -d[0] * 0.25 * k, -d[0] * 0.55 * k)));
	mul(P, 'LegFL', A(0.4 * k));
	mul(P, 'LegFR', A(0.4 * k));
	mul(P, 'LegBL', A(-0.4 * k));
	mul(P, 'LegBR', A(-0.4 * k));
	mul(P, 'KneeFL', A(-0.9 * k));
	mul(P, 'KneeFR', A(-0.9 * k));
	mul(P, 'KneeBL', A(0.8 * k));
	mul(P, 'KneeBR', A(0.8 * k));
	P.TailX = (P.TailX || 0) - 0.3 * k;
	c.ear = 'back';
}

function limpPose(s, P, c) {
	if (s.Health >= TUNE.LowHealth || s.MoveW > 0.5 || c.action) return;
	const k = 1 - s.MoveW * 2;
	const leg = s.LimpLeg;
	mul(P, leg, A(0.15 * k));
	mul(P, KNEE_OF[leg], A(FLEX[leg] * 0.5 * k));
	if (!c.ear) c.ear = 'droop';
}

function buildPose(s, c) {
	const P = {};
	idlePose(s, P, c);
	if (s.MoveW > 0.001) {
		const Q = {};
		movePose(s, Q, c);
		blend(P, Q, s.MoveW);
	}
	brakePose(s, P, c);
	if (s.SwimW > 0.001) {
		const Q = {};
		swimPose(s, Q, c);
		blend(P, Q, s.SwimW);
	}
	if (c.floater) floaterPose(s, P, c);
	if (s.AirW > 0.001) {
		const Q = {};
		airPose(s, Q, c);
		blend(P, Q, s.AirW);
	}
	takeoffPose(s, P, c);
	landPose(s, P, c);
	if (c.raging) ragePose(s, P, c);
	if (c.action) {
		const fn = ACTIONS[c.action] || genericAction;
		if (c.airAction) {
			const fc = Object.assign({}, c, { at: 10 });
			ACTIONS.Fly(s, P, fc);
			const F = Object.assign({}, P);
			c.fade = fn(s, P, c) || 0;
			for (const name of ['WingL', 'WingR', 'WingL2', 'WingR2']) if (F[name]) P[name] = F[name];
			for (const leg of LEGS) {
				for (const name of [leg, KNEE_OF[leg]]) if (F[name] && P[name]) P[name] = P[name].lerp(F[name], 0.55);
			}
			c.ear = c.ear || 'back';
		} else {
			c.fade = fn(s, P, c) || 0;
		}
	}
	limpPose(s, P, c);
	bitePose(s, P, c);
	swipePose(s, P, c);
	hitPose(s, P, c);
	dodgePose(s, P, c);
	return P;
}

// ---------------------------------------------------------------- o Animator de um cachorro
export class DogAnimator {
	// rig = createDogModel(...); opts: { showcase: true } para telas (sem sentar/dormir, comportamentos fofos)
	constructor(rig, opts = {}) {
		const asset = rig.asset;
		const d = asset.data;
		this.rig = rig;
		this.showcase = !!opts.showcase;
		this.gameScale = rig.scale;
		this.BaseSpeed = opts.baseSpeed || 16;
		this.motors = [];
		this.ears = [];
		this.has = {};
		d.bones.forEach((b, i) => {
			if (b.n === 'Ear') this.ears.push({ index: i, side: b.side, up: b.up });
			else if (b.n !== 'Root') {
				this.motors.push({ index: i, name: b.n });
				this.has[b.n] = true;
			}
		});
		const tail = d.bones.find((b) => b.n === 'Tail');
		this.wag = tail && tail.wag ? tail.wag : null;
		this.heads = d.heads || 1;
		this.floater = !!d.float;
		const now = performance.now() / 1000;
		Object.assign(this, {
			S: (d.scale || 1) * rig.scale,
			LegLen: max(0.5, d.legLen * rig.scale),
			Seed: Math.random() * 100,
			Phase: Math.random(),
			Current: {},
			EarCur: [],
			Speed: 0, Rel: 0, Accel: 0, VelY: 0, Yaw: 0, Side: 0, Back: false, Health: 1, Bank: 0,
			MoveW: 0, AirW: 0, SwimW: 0, TurnW: 0, Gait: { Walk: 1, Trot: 0, Gallop: 0 }, Pant: 0,
			Air: false, AirSince: 0, TakeoffAt: -10, LandAt: -10, LandPower: 0, LastStep: {},
			LookYaw: 0, LookPitch: 0, LookTilt: 0, LookYawV: 0, LookPitchV: 0, Twist: 0, LookGoal: [0, 0, 0],
			NextLook: 0, NextTarget: 0, Target: null, LastLookDir: null, LastPoint: null, StillFor: 0, TiltSide: 1, Excite: 0,
			IdleTime: 0, Behavior: null, BehaviorAt: 0, BehaviorSide: 1, NextBehavior: now + 3 + Math.random() * 4,
			SitW: 0, LieW: 0, SleepW: 0,
			Bites: {}, BiteVariant: 0, Swipes: {}, HitAt: -10, HitPower: 0, HitSide: 1, DodgeAt: -10, DodgeDir: [1, 0, 0],
			DodgeForward: false, LimpLeg: LEGS[Math.floor(Math.random() * 4)],
			TailX: 0, TailY: 0, TailVX: 0, TailVY: 0, EarX: { '-1': 0, 1: 0 }, EarV: { '-1': 0, 1: 0 }, EarKick: 0,
			NextTwitch: now + Math.random() * 4,
			ActionName: null, ActionStart: 0, ActionFx: false,
			LastYawAngle: null, LastSpeed: 0,
			fade: 0,
		});
		// medidas do esqueleto (unidades do mundo)
		const sc = rig.scale;
		this.LegZ = {};
		for (const leg of LEGS) {
			const i = asset.byName[leg];
			if (i !== undefined) this.LegZ[leg] = asset.joint[i].z * sc;
		}
		const neck = asset.byName.Neck1;
		this.NeckPos = neck !== undefined ? [asset.joint[neck].x * sc, asset.joint[neck].y * sc, asset.joint[neck].z * sc] : [0, 0, -d.rootY];
		this.WingFlat = null;
		const wr = asset.byName.WingR, wr2 = asset.byName.WingR2;
		if (wr !== undefined && wr2 !== undefined) {
			const e = asset.joint[wr2];
			const p = asset.joint[wr].rotate(e.x, e.y, e.z);
			this.WingFlat = clamp(Math.atan2(p[1], abs(p[0])), 0, 1.4);
		}
		// entrada do quadro (o jogo preenche): posição/rotação da raiz, velocidade, chão...
		this.pos = [0, 0, 0];
		this.quat = [0, 0, 0, 1];
		this.vel = [0, 0, 0];
		this.grounded = true;
		this.inWater = false;
		this.flying = false;
		this.raging = false;
		this.action = null;
		this.actionSpeed = 1;
		this.lookPoint = null;
		this.lookTargets = null; // função () => lista de [x, y, z] para NPC olhar
		this.onDust = null; // (pos [x,y,z], força) => poeira
	}

	// ---- API (igual ao Animator.lua)
	playBite(head = 1) {
		const now = performance.now() / 1000;
		const last = this.Bites[head];
		if (last && now - last.At < 0.2) return;
		this.BiteVariant = (this.BiteVariant % 3) + 1;
		this.Bites[head] = { At: now, Variant: this.BiteVariant, Side: Math.random() < 0.5 ? -1 : 1 };
	}

	// passo 1 = pata direita, 2 = pata esquerda, 3 = mordida forte
	playMelee(step) {
		const now = performance.now() / 1000;
		if (step === 3) this.Bites[1] = { At: now, Variant: 1, Side: Math.random() < 0.5 ? -1 : 1, Big: true };
		else this.Swipes[step === 1 ? 1 : -1] = { At: now };
	}

	// levou dano (power 0..1)
	playHit(power = 0.6) {
		this.HitAt = performance.now() / 1000;
		this.HitPower = clamp(power, 0.35, 1);
		this.HitSide = Math.random() < 0.5 ? -1 : 1;
		this.EarKick += 5 * this.HitPower;
	}

	// esquiva/dash: direção no mundo [x, z]
	playDodge(dx, dz, forward = false) {
		const local = this.toLocal(dx, 0, dz);
		const m = Math.hypot(local[0], local[2]);
		this.DodgeDir = m > 0.01 ? [local[0] / m, 0, local[2] / m] : [0, 0, 1];
		this.DodgeForward = forward;
		this.DodgeAt = performance.now() / 1000;
	}

	toLocal(x, y, z) {
		// gira pelo inverso da rotação da raiz
		const [qx, qy, qz, qw] = this.quat;
		const ix = -qx, iy = -qy, iz = -qz;
		const tx = 2 * (iy * z - iz * y);
		const ty = 2 * (iz * x - ix * z);
		const tz = 2 * (ix * y - iy * x);
		return [x + qw * tx + (iy * tz - iz * ty), y + qw * ty + (iz * tx - ix * tz), z + qw * tz + (ix * ty - iy * tx)];
	}

	toWorldDir(x, y, z) {
		const [qx, qy, qz, qw] = this.quat;
		const tx = 2 * (qy * z - qz * y);
		const ty = 2 * (qz * x - qx * z);
		const tz = 2 * (qx * y - qy * x);
		return [x + qw * tx + (qy * tz - qz * ty), y + qw * ty + (qz * tx - qx * tz), z + qw * tz + (qx * ty - qy * tx)];
	}

	// ponto do chão na frente do cachorro (poeira)
	frontGround(k) {
		const f = this.toWorldDir(0, 0, -1);
		return [this.pos[0] + f[0] * this.LegLen * k, this.pos[1] - this.LegLen, this.pos[2] + f[2] * this.LegLen * k];
	}

	footPoint(leg) {
		const z = this.LegZ[leg] || 0;
		const x = SIDE[leg] * this.S * 0.4;
		const w = this.toWorldDir(x, 0, z);
		return [this.pos[0] + w[0], this.pos[1] - this.LegLen, this.pos[2] + w[2]];
	}

	// ---- 3. sentidos
	sense(dt) {
		const vx = this.vel[0], vz = this.vel[2];
		const speed = Math.hypot(vx, vz);
		const vy = this.vel[1];
		// giro (rad/s) pela direção do nariz
		const f = this.toWorldDir(0, 0, -1);
		const ang = Math.atan2(f[0], f[2]);
		let yawRate = 0;
		if (this.LastYawAngle !== null && dt > 0) {
			let d = ang - this.LastYawAngle;
			d = ((d + Math.PI) % TAU + TAU) % TAU - Math.PI;
			yawRate = d / dt;
		}
		this.LastYawAngle = ang;
		let side = 0, back = false;
		if (speed > 0.5) {
			const l = this.toLocal(vx, 0, vz);
			side = l[0] / speed;
			back = l[2] > speed * 0.4;
		}
		const lastSpeed = this.Speed;
		this.Speed += (speed - this.Speed) * damp(dt, 10);
		this.Accel += ((this.Speed - lastSpeed) / max(dt, 1e-3) - this.Accel) * damp(dt, 6);
		this.VelY += (vy - this.VelY) * damp(dt, 12);
		this.Yaw += (clamp(yawRate, -8, 8) - this.Yaw) * damp(dt, 6);
		this.Side += (side - this.Side) * damp(dt, 6);
		this.Back = back;
		this.Rel = this.Speed / this.LegLen;
		// inclinação lateral do corpo (voo)
		const r = this.toWorldDir(1, 0, 0);
		this.Bank = Math.asin(clamp(r[1], -1, 1));
	}

	setHealth(frac) {
		this.Health = clamp(frac, 0, 1);
	}

	context(dt, now, snap) {
		let action = this.action;
		if ((!action || action === 'Dash') && this.flying) action = 'Fly';
		if (action !== this.ActionName) {
			this.ActionName = action;
			this.ActionStart = now;
			this.ActionFx = false;
		}
		return {
			now,
			dt,
			t: now + this.Seed,
			S: this.S,
			action,
			at: (now - this.ActionStart) * (this.actionSpeed || 1),
			raging: this.raging,
			airAction: this.flying && !!action && action !== 'Fly' && action !== 'Float',
			floater: this.floater,
			heads: this.heads,
			big: this.S >= TUNE.BigStep,
			boss: this.S >= 4,
			snap,
			fast: {},
			ear: null,
			wind: 0,
			fade: 0,
		};
	}

	updateAir(c) {
		let air = false;
		if (!c.floater && !NO_AIR_ACTIONS[c.action]) air = !this.grounded || this.VelY > 12 * sqrt(this.S);
		if (air !== this.Air) {
			if (air) {
				this.AirSince = c.now;
				if (this.VelY > 2) this.TakeoffAt = c.now;
			} else if (c.now - this.AirSince > 0.22) {
				this.LandAt = c.now;
				this.LandPower = clamp((c.now - this.AirSince) / 0.8, 0.35, 1);
				this.EarKick += 7 * this.LandPower;
				if (this.LandPower > 0.5 && this.onDust) this.onDust([this.pos[0], this.pos[1] - this.LegLen, this.pos[2]], this.LandPower * sqrt(this.S));
			}
			this.Air = air;
		}
		this.AirW += ((air && c.now - this.AirSince > 0.08 ? 1 : 0) - this.AirW) * damp(c.dt, 10);
		this.SwimW += ((this.inWater && !air ? 1 : 0) - this.SwimW) * damp(c.dt, 4);
	}

	gaitWeights(c, instant) {
		const rel = this.Rel;
		const gallop = GALLOP_ACTIONS[c.action] ? 1 : smooth01((rel - TUNE.GallopAt + 0.6) / 1.2);
		const trot = (1 - gallop) * smooth01((rel - TUNE.TrotAt + 0.4) / 0.8);
		const walk = 1 - gallop - trot;
		const g = this.Gait;
		const k = instant ? 1 : damp(c.dt, 5);
		g.Walk += (walk - g.Walk) * k;
		g.Trot += (trot - g.Trot) * k;
		g.Gallop += (gallop - g.Gallop) * k;
	}

	advancePhase(c) {
		const g = this.Gait;
		const stride = (TUNE.Stride.Walk * g.Walk + TUNE.Stride.Trot * g.Trot + TUNE.Stride.Gallop * g.Gallop) * this.LegLen;
		let freq = clamp(this.Speed / max(0.1, stride), TUNE.Cycle.Min, TUNE.Cycle.Max);
		if (this.TurnW > this.MoveW) freq = TUNE.Cycle.Turn;
		if (c.raging) freq *= 0.8;
		const w = max(this.MoveW, this.TurnW);
		this.Phase = (((this.Phase + c.dt * freq * w * (this.Back ? -1 : 1)) % 1) + 1) % 1;
	}

	updateLook(c) {
		const now = c.now, dt = c.dt, L = TUNE.Look;
		const point = this.lookPoint;
		let goal = [0, 0, 0];
		if (point) {
			const n = this.toWorldDir(this.NeckPos[0], this.NeckPos[1], this.NeckPos[2]);
			const nx = this.pos[0] + n[0], ny = this.pos[1] + n[1], nz = this.pos[2] + n[2];
			const dx = point[0] - nx, dy = point[1] - ny, dz = point[2] - nz;
			const dist = Math.hypot(dx, dy, dz);
			const rel = this.toLocal(dx, dy, dz);
			const yaw = Math.atan2(-rel[0], -rel[2]);
			const pitch = Math.atan2(rel[1], max(0.01, Math.hypot(rel[0], rel[2])));
			if (dist > 0.01) {
				const dir = [dx / dist, dy / dist, dz / dist];
				if (this.LastLookDir && dt > 0) {
					const dot = clamp(dir[0] * this.LastLookDir[0] + dir[1] * this.LastLookDir[1] + dir[2] * this.LastLookDir[2], -1, 1);
					const turnSpeed = Math.acos(dot) / dt;
					const near = 1 - smooth01((dist - 10 * this.S) / (30 * this.S));
					this.Excite = clamp(this.Excite + (max(0, turnSpeed - 1.2) * 0.4 * near - 0.2) * dt, 0, 1);
				}
				this.LastLookDir = dir;
			}
			if (this.LastPoint && Math.hypot(point[0] - this.LastPoint[0], point[1] - this.LastPoint[1], point[2] - this.LastPoint[2]) < 1.5 * this.S) {
				this.StillFor += dt;
			} else {
				this.StillFor = 0;
				this.LastPoint = [point[0], point[1], point[2]];
			}
			let tilt = 0;
			if (this.StillFor > 1.3 && dist < 22 * this.S && abs(yaw) < 1.3) {
				if (this.StillFor - dt <= 1.3) this.TiltSide = Math.random() < 0.5 ? -1 : 1;
				tilt = this.TiltSide * 0.32 * smooth01((this.StillFor - 1.3) / 0.4);
			}
			goal = [clamp(pitch, -L.Down, L.Up), clamp(yaw, -L.Yaw, L.Yaw), tilt];
		} else {
			this.Excite = max(0, this.Excite - dt * 0.3);
			this.LastLookDir = null;
			if (this.lookTargets && now > this.NextTarget) {
				this.NextTarget = now + 0.45;
				this.Target = null;
				let best = 26 * max(1, sqrt(this.S));
				const f = this.toWorldDir(0, 0, -1);
				for (const o of this.lookTargets()) {
					const dx = o[0] - this.pos[0], dy = o[1] - this.pos[1], dz = o[2] - this.pos[2];
					const dist = Math.hypot(dx, dy, dz);
					if (dist > 0.1 && dist < best && (f[0] * dx + f[1] * dy + f[2] * dz) / dist > -0.1) {
						best = dist;
						this.Target = o;
					}
				}
			}
			if (this.Target) {
				const t = this.Target;
				const rel = this.toLocal(t[0] - this.pos[0], t[1] - this.pos[1], t[2] - this.pos[2]);
				const yaw = Math.atan2(-rel[0], -rel[2]);
				const pitch = Math.atan2(rel[1], Math.hypot(rel[0], rel[2]));
				goal = [clamp(pitch, -0.45, 0.45), clamp(yaw, -1.4, 1.4), 0];
			} else {
				if (now > this.NextLook) {
					this.NextLook = now + 1.6 + Math.random() * 2.8;
					if (Math.random() < 0.3) this.LookGoal = [0, 0, 0];
					else this.LookGoal = [(Math.random() - 0.5) * 0.35, (Math.random() - 0.5) * 1.5, Math.random() < 0.25 ? (Math.random() - 0.5) * 0.6 : 0];
				}
				goal = this.LookGoal;
			}
		}
		const twistGoal = clamp(goal[1] * 0.32, -L.Twist, L.Twist);
		const neckGoal = clamp(goal[1] - twistGoal, -L.Neck, L.Neck);
		[this.LookYaw, this.LookYawV] = spring(this.LookYaw, this.LookYawV, neckGoal, L.Stiff, L.Damp, dt);
		[this.LookPitch, this.LookPitchV] = spring(this.LookPitch, this.LookPitchV, goal[0], L.Stiff, L.Damp, dt);
		this.LookTilt += (goal[2] - this.LookTilt) * damp(dt, 5);
		this.Twist += (twistGoal - this.Twist) * damp(dt, 4);
	}

	idleClock(c) {
		const calm = this.MoveW < 0.05 && this.AirW < 0.05 && this.SwimW < 0.05 && !c.action && !c.raging;
		if (calm) this.IdleTime += c.dt;
		else {
			this.IdleTime = 0;
			this.Behavior = null;
		}
		if (this.Excite > 0.3) this.IdleTime = min(this.IdleTime, TUNE.SitAfter * 0.5);
		let posture = 0;
		if (calm && !this.showcase && !c.boss) {
			if (this.IdleTime > TUNE.SleepAfter) posture = 3;
			else if (this.IdleTime > TUNE.LieAfter) posture = 2;
			else if (this.IdleTime > TUNE.SitAfter) posture = 1;
		}
		const k = damp(c.dt, 2.5);
		this.SitW += ((posture === 1 ? 1 : 0) - this.SitW) * k;
		this.LieW += ((posture >= 2 ? 1 : 0) - this.LieW) * k;
		this.SleepW += ((posture === 3 ? 1 : 0) - this.SleepW) * damp(c.dt, 1.2);
		if (this.Behavior && c.now - this.BehaviorAt > BEHAVIORS[this.Behavior]) this.Behavior = null;
		if (calm && posture === 0 && !this.Behavior && this.Excite > 0.7 && c.now > (this.NextPlay || 0)) {
			this.Behavior = 'bow';
			this.LastBehavior = 'bow';
			this.BehaviorAt = c.now;
			this.BehaviorSide = Math.random() < 0.5 ? -1 : 1;
			this.NextPlay = c.now + 6;
			this.NextBehavior = c.now + BEHAVIORS.bow + 3;
		}
		if (calm && posture === 0 && !this.Behavior && this.IdleTime > 1.5 && c.now > this.NextBehavior) {
			const list = this.showcase ? SHOWCASE_LIST : BEHAVIOR_LIST;
			let pick = list[Math.floor(Math.random() * list.length)];
			if (pick === this.LastBehavior) pick = list[(list.indexOf(pick) + 1) % list.length];
			this.Behavior = pick;
			this.LastBehavior = pick;
			this.BehaviorAt = c.now;
			this.BehaviorSide = Math.random() < 0.5 ? -1 : 1;
			const gap = TUNE.IdleEvery[0] + Math.random() * (TUNE.IdleEvery[1] - TUNE.IdleEvery[0]);
			this.NextBehavior = c.now + BEHAVIORS[pick] + gap;
		} else if (!calm) {
			this.NextBehavior = max(this.NextBehavior, c.now + 2);
		}
	}

	// ---- 8. molas
	tailFinish(P, c) {
		const gx = P.TailX || 0, gy = P.TailY || 0;
		if (c.snap) {
			this.TailX = gx;
			this.TailY = gy;
			this.TailVX = 0;
			this.TailVY = 0;
		} else {
			[this.TailX, this.TailVX] = spring(this.TailX, this.TailVX, gx, 90, 11, c.dt);
			[this.TailY, this.TailVY] = spring(this.TailY, this.TailVY, gy, 120, 9, c.dt);
		}
		const w = this.wag;
		P.Tail = w ? A(this.TailX, 0, 0).mul(axisAngle(w[0], w[1], w[2], this.TailY)) : A(this.TailX, this.TailY, 0);
		delete P.TailX;
		delete P.TailY;
	}

	earsFinish(c) {
		if (this.ears.length === 0) return;
		const now = c.now, dt = c.dt;
		const M = this.MoveW, G = this.Gait.Gallop;
		let goal = 0.22 * M + 0.18 * G + 0.25 * this.AirW + sin(this.Phase * TAU * 2) * 0.12 * M;
		let flare = sin(c.t * 1.7) * 0.03;
		if (c.ear === 'back') {
			goal = 0.65;
			flare = -0.1;
		} else if (c.ear === 'droop') {
			goal = 0.2;
			flare = 0.45;
		} else if (c.ear === 'up') {
			goal = -0.15;
			flare = 0;
		} else if (this.SleepW > 0.5) {
			goal = 0.3;
			flare = 0.3;
		}
		const wind = min(c.wind || 0, 1.5);
		if (wind > 0.05) goal += 0.25 * min(wind, 1);
		if (now > this.NextTwitch) {
			this.NextTwitch = now + 1.5 + Math.random() * 4;
			this.EarV[Math.random() < 0.5 ? -1 : 1] += 9;
		}
		for (const side of [-1, 1]) {
			this.EarV[side] += this.EarKick;
			if (wind > 0.05) this.EarV[side] += sin(c.t * 29 + side * 1.9) * 420 * wind * dt;
			if (c.snap) {
				this.EarX[side] = goal;
				this.EarV[side] = 0;
			} else {
				[this.EarX[side], this.EarV[side]] = spring(this.EarX[side], this.EarV[side], goal, 160, 13, dt);
			}
		}
		this.EarKick = 0;
		const ek = c.snap ? 1 : damp(dt, 30);
		const poses = this.rig.poses;
		this.ears.forEach((ear, n) => {
			const u = ear.up;
			const target = A(this.EarX[ear.side] * u, 0, -ear.side * u * flare);
			const cur = (this.EarCur[n] || IDENT).lerp(target, ek);
			this.EarCur[n] = cur;
			poses[ear.index] = cur;
		});
	}

	// ---- 9. aplicar (suaviza cada junta e escreve no esqueleto)
	apply(c, P) {
		const inv = 1 / this.gameScale;
		const poses = this.rig.poses;
		for (const m of this.motors) {
			const goal = P[m.name] || IDENT;
			let rate;
			if (c.snap) rate = 1;
			else if (c.fast[m.name]) rate = m.name === 'Body' ? 1 : damp(c.dt, TUNE.Smooth.Fast);
			else rate = damp(c.dt, RATE[m.name] || 14);
			const cur = (this.Current[m.name] || IDENT).lerp(goal, rate);
			this.Current[m.name] = cur;
			// deslocamentos das poses estão em studs do mundo; o esqueleto está em unidades do modelo
			if (cur.x !== 0 || cur.y !== 0 || cur.z !== 0) {
				const sc = cur.mul(IDENT);
				sc.x *= inv;
				sc.y *= inv;
				sc.z *= inv;
				poses[m.index] = sc;
			} else poses[m.index] = cur;
		}
		this.fade = c.fade || 0;
	}

	// um quadro de animação (dt em segundos)
	update(dt, snap = false) {
		const now = performance.now() / 1000;
		dt = min(dt, 0.1);
		this.sense(dt);
		const c = this.context(dt, now, snap);
		this.updateAir(c);
		const moving = this.Rel > TUNE.MoveAt && !STILL_ACTIONS[c.action];
		this.MoveW += ((moving ? 1 : 0) - this.MoveW) * damp(c.dt, 6);
		const turning = !moving && abs(this.Yaw) > 1.1 && this.AirW < 0.5;
		this.TurnW += ((turning ? 1 : 0) - this.TurnW) * damp(c.dt, 6);
		const running = this.MoveW > 0.5 && this.Gait.Walk < 0.5;
		this.Pant = clamp(this.Pant + (running ? c.dt * 0.2 : -c.dt * 0.07), 0, 1);
		this.gaitWeights(c, false);
		this.advancePhase(c);
		this.updateLook(c);
		this.idleClock(c);
		const P = buildPose(this, c);
		this.tailFinish(P, c);
		this.apply(c, P);
		this.earsFinish(c);
	}
}

export const ANIMATION_ACTIONS = Object.keys(ACTIONS);
