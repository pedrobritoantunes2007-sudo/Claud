// Núcleo do Lua em JavaScript: as regras que o código traduzido (src/gerado, feito pelo tools/lua2js) usa.
// Verdade do Lua (só nil/false são falsos), tabelas (array JS = lista Lua começando em 1), vários retornos,
// operadores com Vector3/CFrame, chamadas de método (obj:m()), a biblioteca padrão (math, string, table, task...)
// e o AGENDADOR: funções que esperam (task.wait, k:wait) são function* e voltam a rodar quando o tempo passa.

// ------------------------------------------------------------------ vários valores
export class Multi {
	constructor(v) {
		this.v = v;
	}
}
export function $M(...v) {
	if (v.length === 1) return v[0];
	if (v.length === 0) return undefined;
	return new Multi(v);
}
export const $1 = (x) => (x instanceof Multi ? x.v[0] : x);
export const $mv = (x) => (x instanceof Multi ? x.v : [x]);
export function $lst(pre, last, n) {
	const out = last instanceof Multi ? pre.concat(last.v) : (pre.push(last), pre);
	while (out.length < n) out.push(undefined);
	return out;
}

// ------------------------------------------------------------------ verdade
export const $t = (x) => x !== undefined && x !== null && x !== false;
// a and b  →  ($a(a) && b)
export const $a = (x) => (x === undefined || x === null || x === false ? x : true);
// a or b   →  ($n(a) ?? b)
export const $n = (x) => (x === false ? undefined : x);

// ------------------------------------------------------------------ tabelas
const isPlain = (t) => {
	const p = Object.getPrototypeOf(t);
	return p === Object.prototype || p === Array.prototype || p === null || t.$lua === true;
};
function mapOf(t, create) {
	let m = t.$m;
	if (!m && create) {
		m = new Map();
		Object.defineProperty(t, '$m', { value: m, enumerable: false, writable: true });
	}
	return m;
}

export function $get(t, k) {
	if (t === undefined || t === null) throw new LuaError(`attempt to index nil with '${tostring(k)}'`);
	if (typeof k === 'number') return Array.isArray(t) ? t[k - 1] : t[k];
	if (typeof k === 'string') return t[k];
	if (k === undefined || k === null) return undefined;
	const m = t.$m;
	return m ? m.get(k) : undefined;
}

export function $set(t, k, v) {
	if (t === undefined || t === null) throw new LuaError(`attempt to index nil with '${tostring(k)}'`);
	const none = v === undefined || v === null;
	if (typeof k === 'number') {
		if (Array.isArray(t)) {
			const i = k - 1;
			if (none) {
				if (i < t.length) {
					t[i] = undefined;
					let n = t.length;
					while (n > 0 && (t[n - 1] === undefined || t[n - 1] === null)) n--;
					t.length = n;
				}
			} else t[i] = v;
			return;
		}
		if (none) delete t[k];
		else t[k] = v;
		return;
	}
	if (typeof k === 'string') {
		if (none && isPlain(t)) delete t[k];
		else t[k] = none ? undefined : v;
		return;
	}
	if (k === undefined || k === null) throw new LuaError('table index is nil');
	const m = mapOf(t, !none);
	if (!m) return;
	if (none) m.delete(k);
	else m.set(k, v);
}

// { 1, 2, x = 3 }
export function $tm(arr, obj) {
	return Object.assign(arr, obj);
}
// { [chave] = valor }
export function $tc(base, pairs) {
	let t = base;
	// só chaves numéricas e nenhuma outra: vira lista
	if (!Array.isArray(t) && Object.keys(t).length === 0 && pairs.every((p) => typeof p[0] === 'number')) t = [];
	for (const [k, v] of pairs) $set(t, k, v);
	return t;
}

export function $len(x) {
	if (typeof x === 'string') return x.length;
	if (Array.isArray(x)) {
		let n = x.length;
		while (n > 0 && (x[n - 1] === undefined || x[n - 1] === null)) n--;
		return n;
	}
	if (x === undefined || x === null) throw new LuaError('attempt to get length of a nil value');
	if (typeof x === 'object') {
		let n = 0;
		while (x[n + 1] !== undefined && x[n + 1] !== null) n++;
		return n;
	}
	return 0;
}

export function $ins(t, v) {
	if (Array.isArray(t)) t[$len(t)] = v;
	else t[$len(t) + 1] = v;
}
export function $ins3(t, pos, v) {
	t.splice(pos - 1, 0, v);
}

export function $arr(t) {
	if (Array.isArray(t)) return t;
	if (t === undefined || t === null) throw new LuaError("bad argument #1 to 'ipairs' (table expected, got nil)");
	const out = [];
	for (let i = 1; t[i] !== undefined && t[i] !== null; i++) out.push(t[i]);
	return out;
}

const INDEX = /^(0|[1-9]\d*)$/;
export function* $pairs(t) {
	if (t === undefined || t === null) throw new LuaError("bad argument #1 to 'pairs' (table expected, got nil)");
	if (Array.isArray(t)) {
		for (let i = 0; i < t.length; i++) {
			const v = t[i];
			if (v !== undefined && v !== null) yield [i + 1, v];
		}
		for (const k of Object.keys(t)) {
			if (INDEX.test(k)) continue;
			const v = t[k];
			if (v !== undefined && v !== null) yield [k, v];
		}
	} else {
		for (const k of Object.keys(t)) {
			const v = t[k];
			if (v === undefined || v === null) continue;
			yield [INDEX.test(k) ? +k : k, v];
		}
	}
	const m = t.$m;
	if (m) for (const [k, v] of [...m]) yield [k, v];
}
export function* $iter(f, s, c) {
	if (typeof f !== 'function') throw new LuaError('attempt to call a non-function in for-in');
	while (true) {
		const r = f(s, c);
		const vals = r instanceof Multi ? r.v : [r];
		if (vals[0] === undefined || vals[0] === null) return;
		c = vals[0];
		yield vals;
	}
}

export function next(t, k) {
	const keys = [];
	for (const [kk] of $pairs(t)) keys.push(kk);
	let i = 0;
	if (k !== undefined && k !== null) {
		i = keys.findIndex((x) => x === k) + 1;
		if (i === 0) return undefined;
	}
	if (i >= keys.length) return undefined;
	return $M(keys[i], $get(t, keys[i]));
}

// ------------------------------------------------------------------ texto
export function numStr(n) {
	if (Number.isInteger(n) && Math.abs(n) < 1e15) return String(n);
	if (n !== n) return 'nan';
	if (n === Infinity) return 'inf';
	if (n === -Infinity) return '-inf';
	let s = n.toPrecision(14);
	if (s.includes('e')) {
		let [m, e] = s.split('e');
		if (m.includes('.')) m = m.replace(/0+$/, '').replace(/\.$/, '');
		const ev = parseInt(e, 10);
		return `${m}e${ev < 0 ? '-' : '+'}${String(Math.abs(ev)).padStart(2, '0')}`;
	}
	if (s.includes('.')) s = s.replace(/0+$/, '').replace(/\.$/, '');
	return s;
}

let ids = 0;
const idOf = new WeakMap();
function addr(x) {
	let id = idOf.get(x);
	if (!id) {
		id = ++ids;
		idOf.set(x, id);
	}
	return '0x' + (0x10000000 + id * 16).toString(16).padStart(8, '0');
}

export function tostring(x) {
	if (x === undefined || x === null) return 'nil';
	if (typeof x === 'number') return numStr(x);
	if (typeof x === 'string') return x;
	if (typeof x === 'boolean') return x ? 'true' : 'false';
	if (typeof x === 'function') return 'function: ' + addr(x);
	if (x instanceof Multi) return tostring(x.v[0]);
	if (typeof x.toString === 'function' && !isPlain(x)) return x.toString();
	if (x.$mt && x.$mt.__tostring) return x.$mt.__tostring(x);
	return 'table: ' + addr(x);
}

export function $cat(a, b) {
	const sa = typeof a === 'string' ? a : typeof a === 'number' ? numStr(a) : null;
	const sb = typeof b === 'string' ? b : typeof b === 'number' ? numStr(b) : null;
	if (sa === null || sb === null) throw new LuaError(`attempt to concatenate ${typeName(sa === null ? a : b)} with ${typeName(sa === null ? b : a)}`);
	return sa + sb;
}

// ------------------------------------------------------------------ comparação e contas
export function $eq(a, b) {
	if (a === b) return true;
	if (a === undefined || a === null || b === undefined || b === null) return (a === undefined || a === null) && (b === undefined || b === null);
	if (typeof a === 'object' && typeof a.__eq === 'function' && typeof b === 'object') return a.__eq(b);
	return false;
}

function arithError(op, a, b) {
	return new LuaError(`attempt to perform arithmetic (${op}) on ${typeName(a)} and ${typeName(b)}`);
}
function num(x) {
	if (typeof x === 'string') {
		const n = Number(x);
		if (!isNaN(n)) return n;
	}
	return null;
}
export function $add(a, b) {
	if (typeof a === 'number' && typeof b === 'number') return a + b;
	if (a !== null && typeof a === 'object' && a.__add) return a.__add(b);
	const na = typeof a === 'number' ? a : num(a), nb = typeof b === 'number' ? b : num(b);
	if (na !== null && nb !== null) return na + nb;
	throw arithError('add', a, b);
}
export function $sub(a, b) {
	if (typeof a === 'number' && typeof b === 'number') return a - b;
	if (a !== null && typeof a === 'object' && a.__sub) return a.__sub(b);
	const na = typeof a === 'number' ? a : num(a), nb = typeof b === 'number' ? b : num(b);
	if (na !== null && nb !== null) return na - nb;
	throw arithError('sub', a, b);
}
export function $mul(a, b) {
	if (typeof a === 'number') {
		if (typeof b === 'number') return a * b;
		if (b !== null && typeof b === 'object' && b.__mulNum) return b.__mulNum(a);
	} else if (a !== null && typeof a === 'object' && a.__mul) return a.__mul(b);
	const na = typeof a === 'number' ? a : num(a), nb = typeof b === 'number' ? b : num(b);
	if (na !== null && nb !== null) return na * nb;
	throw arithError('mul', a, b);
}
export function $div(a, b) {
	if (typeof a === 'number') {
		if (typeof b === 'number') return a / b;
		if (b !== null && typeof b === 'object' && b.__divNum) return b.__divNum(a);
	} else if (a !== null && typeof a === 'object' && a.__div) return a.__div(b);
	const na = typeof a === 'number' ? a : num(a), nb = typeof b === 'number' ? b : num(b);
	if (na !== null && nb !== null) return na / nb;
	throw arithError('div', a, b);
}
export function $mod(a, b) {
	if (typeof a !== 'number' || typeof b !== 'number') {
		const na = typeof a === 'number' ? a : num(a), nb = typeof b === 'number' ? b : num(b);
		if (na === null || nb === null) throw arithError('mod', a, b);
		a = na;
		b = nb;
	}
	return a - Math.floor(a / b) * b;
}
export function $pow(a, b) {
	if (typeof a === 'number' && typeof b === 'number') return a ** b;
	const na = typeof a === 'number' ? a : num(a), nb = typeof b === 'number' ? b : num(b);
	if (na !== null && nb !== null) return na ** nb;
	throw arithError('pow', a, b);
}
export function $idiv(a, b) {
	if (typeof a === 'number' && typeof b === 'number') return Math.floor(a / b);
	if (a !== null && typeof a === 'object' && a.__idiv) return a.__idiv(b);
	throw arithError('idiv', a, b);
}
export function $unm(a) {
	if (typeof a === 'number') return -a;
	if (a !== null && typeof a === 'object' && a.__unm) return a.__unm();
	const na = num(a);
	if (na !== null) return -na;
	throw new LuaError(`attempt to perform arithmetic (unm) on ${typeName(a)}`);
}

// ------------------------------------------------------------------ chamada de método  obj:m(...)
// tabela do Lua: m(obj, ...) — objeto do JS (Vector3, Instance, kit): obj.m(...) com this = obj
export function $mc(o, k, ...a) {
	if (typeof o === 'string') {
		const f = STRING[k];
		if (!f) throw new LuaError(`attempt to call missing method '${k}' of string`);
		return f(o, ...a);
	}
	if (o === undefined || o === null) throw new LuaError(`attempt to index nil with '${k}'`);
	const f = o[k];
	if (typeof f !== 'function') throw new LuaError(`attempt to call a ${typeName(f)} value (method '${k}' of ${tostring(o)})`);
	if (isPlain(o)) return f(o, ...a);
	return f.apply(o, a);
}

// ------------------------------------------------------------------ erros
export class LuaError extends Error {
	constructor(message, value) {
		super(typeof message === 'string' ? message : tostring(message));
		this.value = value === undefined ? message : value;
	}
}

export function typeName(x) {
	if (x === undefined || x === null) return 'nil';
	if (typeof x === 'boolean') return 'boolean';
	if (typeof x === 'number') return 'number';
	if (typeof x === 'string') return 'string';
	if (typeof x === 'function') return 'function';
	if (isGen(x)) return 'thread';
	if (typeof x === 'object' && !isPlain(x)) return 'userdata';
	return 'table';
}

export const errors = [];
export function reportError(e, where) {
	const msg = e instanceof Error ? e.message : tostring(e);
	errors.push({ msg, where, stack: e && e.stack });
	if (errors.length > 60) errors.shift();
	console.warn(`[Lua]${where ? ' ' + where : ''}: ${msg}`, e && e.stack ? '\n' + e.stack.split('\n').slice(1, 6).join('\n') : '');
}

// ------------------------------------------------------------------ agendador (task.wait, task.delay...)
const GEN_PROTO = Object.getPrototypeOf(Object.getPrototypeOf((function* () {})()));
export function isGen(x) {
	return x !== null && typeof x === 'object' && Object.getPrototypeOf(Object.getPrototypeOf(x)) === GEN_PROTO;
}

export const sched = { clock: 0, queue: [], seq: 0, running: null };

class Thread {
	constructor(gen) {
		this.gen = gen;
		this.dead = false;
		this.at = 0;
		this.start = 0;
		this.seq = 0;
	}
	get $type() {
		return 'thread';
	}
}

function schedule(entry, at) {
	entry.at = at;
	entry.seq = ++sched.seq;
	sched.queue.push(entry);
}

function resume(th, value) {
	if (th.dead) return;
	const prev = sched.running;
	sched.running = th;
	let r;
	try {
		r = th.gen.next(value);
	} catch (e) {
		th.dead = true;
		sched.running = prev;
		reportError(e, 'thread');
		return;
	}
	sched.running = prev;
	if (r.done) {
		th.dead = true;
		return;
	}
	const req = r.value;
	if (req && req.w !== undefined) {
		th.start = sched.clock;
		schedule({ th }, sched.clock + Math.max(0, req.w));
	} else if (req && req.s) {
		req.s.$addWaiter(th);
	} else {
		th.start = sched.clock;
		schedule({ th }, sched.clock);
	}
}

export function spawnThread(gen) {
	const th = new Thread(gen);
	resume(th, undefined);
	return th;
}

// chama uma função do Lua vinda do JS (callback): se ela esperar, vira uma linha do agendador
export function callLua(fn, ...args) {
	try {
		const r = fn(...args);
		if (isGen(r)) {
			spawnThread(r);
			return undefined;
		}
		return r;
	} catch (e) {
		reportError(e, 'callback');
		return undefined;
	}
}

function startFn(f, args) {
	if (f instanceof Thread) {
		resume(f, $M(...args));
		return f;
	}
	if (typeof f !== 'function') throw new LuaError('attempt to spawn a non-function');
	const r = f(...args);
	if (isGen(r)) return spawnThread(r);
	const th = new Thread(null);
	th.dead = true;
	return th;
}

export function delayCall(seconds, f, ...args) {
	const entry = { f, args, cancelled: false };
	schedule(entry, sched.clock + Math.max(0, seconds || 0));
	return entry;
}

// roda o agendador: o relógio do jogo andou dt segundos
export function stepScheduler(dt) {
	sched.clock += dt;
	// só o que já venceu; o que for agendado agora espera a próxima rodada
	const due = [];
	const keep = [];
	for (const e of sched.queue) (e.at <= sched.clock ? due : keep).push(e);
	if (!due.length) return;
	sched.queue = keep;
	due.sort((a, b) => a.at - b.at || a.seq - b.seq);
	for (const e of due) {
		if (e.th) {
			resume(e.th, sched.clock - e.th.start);
		} else if (!e.cancelled) {
			try {
				startFn(e.f, e.args);
			} catch (err) {
				reportError(err, 'task.delay');
			}
		}
	}
}

export function resetScheduler() {
	sched.queue = [];
}

// pedidos de espera (yield $W(t) / yield $WS(sinal))
export const $W = (t) => ({ w: typeof t === 'number' && t === t ? t : 0 });
export const $WS = (sig) => ({ s: sig });
let warnedWait = false;
export function $warnWait() {
	if (!warnedWait) {
		warnedWait = true;
		console.warn('[Lua] wait() fora de uma função que pode esperar');
	}
	return 0;
}

// chamada desconhecida dentro de function*: se devolver um gerador, espera ele acabar
export function* $cy(v) {
	if (isGen(v)) return yield* v;
	return v;
}
// chamada desconhecida numa função comum: gerador vira linha separada
export function $sp(v) {
	if (isGen(v)) {
		spawnThread(v);
		return undefined;
	}
	return v;
}
export function $sp1(v) {
	if (isGen(v)) {
		spawnThread(v);
		return undefined;
	}
	return v instanceof Multi ? v.v[0] : v;
}

function errValue(e) {
	if (e instanceof LuaError) return e.value;
	return e instanceof Error ? e.message : e;
}
export function pcall(f, ...args) {
	try {
		const r = f(...args);
		if (isGen(r)) {
			spawnThread(r);
			return true;
		}
		return $M(true, ...$mv(r));
	} catch (e) {
		return $M(false, errValue(e));
	}
}
export function* $pcallG(f, ...args) {
	try {
		let r = f(...args);
		if (isGen(r)) r = yield* r;
		return $M(true, ...$mv(r));
	} catch (e) {
		return $M(false, errValue(e));
	}
}
function xpcall(f, handler, ...args) {
	try {
		const r = f(...args);
		if (isGen(r)) {
			spawnThread(r);
			return true;
		}
		return $M(true, ...$mv(r));
	} catch (e) {
		return $M(false, $1(handler(errValue(e))));
	}
}

// ------------------------------------------------------------------ padrões do Lua (string.find/match/gsub)
function patternToRegex(pat) {
	let re = '';
	let i = 0;
	const cls = (c) => {
		switch (c) {
			case 'a': return 'A-Za-z';
			case 'd': return '0-9';
			case 'l': return 'a-z';
			case 's': return '\\s';
			case 'u': return 'A-Z';
			case 'w': return 'A-Za-z0-9';
			case 'x': return 'A-Fa-f0-9';
			case 'p': return '!-\\/:-@\\[-`{-~';
			case 'c': return '\\x00-\\x1f';
			default: return null;
		}
	};
	const esc = (c) => c.replace(/[\\^$.*+?()[\]{}|/-]/g, '\\$&');
	if (pat[0] === '^') {
		re += '^';
		i = 1;
	}
	while (i < pat.length) {
		const c = pat[i];
		let atom;
		if (c === '%') {
			const d = pat[i + 1];
			i += 2;
			if (d === 'b' || d === 'f') throw new LuaError(`pattern %${d} not supported`);
			const k = cls(d.toLowerCase());
			if (k) atom = d === d.toLowerCase() ? `[${k}]` : `[^${k}]`;
			else if (/[0-9]/.test(d)) atom = `\\${d}`;
			else atom = esc(d);
		} else if (c === '[') {
			let j = i + 1;
			let set = '[';
			if (pat[j] === '^') {
				set += '^';
				j++;
			}
			let first = true;
			while (j < pat.length && (pat[j] !== ']' || first)) {
				first = false;
				if (pat[j] === '%') {
					const k = cls(pat[j + 1].toLowerCase());
					set += k ? (pat[j + 1] === pat[j + 1].toLowerCase() ? k : '') : esc(pat[j + 1]);
					j += 2;
				} else if (pat[j + 1] === '-' && pat[j + 2] && pat[j + 2] !== ']') {
					set += `${esc(pat[j])}-${esc(pat[j + 2])}`;
					j += 3;
				} else {
					set += esc(pat[j]);
					j++;
				}
			}
			atom = set + ']';
			i = j + 1;
		} else if (c === '.') {
			atom = '[\\s\\S]';
			i++;
		} else if (c === '(') {
			re += '(';
			i++;
			continue;
		} else if (c === ')') {
			re += ')';
			i++;
			continue;
		} else if (c === '$' && i === pat.length - 1) {
			re += '$';
			i++;
			continue;
		} else {
			atom = esc(c);
			i++;
		}
		const q = pat[i];
		if (q === '*' || q === '+' || q === '?') {
			atom += q;
			i++;
		} else if (q === '-') {
			atom += '*?';
			i++;
		}
		re += atom;
	}
	return re;
}

function luaIndex(s, i, def) {
	if (i === undefined || i === null) return def;
	if (i < 0) return Math.max(0, s.length + i);
	return Math.max(0, i - 1);
}

function fmtNum(spec, v) {
	const m = /^%([-+ #0]*)(\d*)(?:\.(\d+))?([a-zA-Z])$/.exec(spec);
	if (!m) return spec;
	const [, flags, width, prec, conv] = m;
	let s;
	const n = typeof v === 'number' ? v : Number(v);
	switch (conv) {
		case 'd':
		case 'i':
			s = String(Math.trunc(n));
			break;
		case 'u':
			s = String(Math.abs(Math.trunc(n)));
			break;
		case 'f':
		case 'F':
			s = n.toFixed(prec === undefined ? 6 : +prec);
			break;
		case 'e':
		case 'E':
			s = n.toExponential(prec === undefined ? 6 : +prec).replace(/e([+-])(\d)$/, 'e$10$2');
			if (conv === 'E') s = s.toUpperCase();
			break;
		case 'g':
		case 'G':
			s = String(Number(n.toPrecision(prec === undefined ? 6 : Math.max(1, +prec))));
			break;
		case 'x':
			s = Math.trunc(n).toString(16);
			break;
		case 'X':
			s = Math.trunc(n).toString(16).toUpperCase();
			break;
		case 'o':
			s = Math.trunc(n).toString(8);
			break;
		case 'c':
			s = String.fromCharCode(n);
			break;
		case 's':
			s = tostring(v);
			if (prec !== undefined) s = s.slice(0, +prec);
			break;
		case 'q':
			s = JSON.stringify(String(v));
			break;
		default:
			s = String(v);
	}
	if (flags.includes('+') && 'dif'.includes(conv) && n >= 0) s = '+' + s;
	if (width && s.length < +width) {
		if (flags.includes('-')) s = s.padEnd(+width);
		else if (flags.includes('0') && conv !== 's') {
			const neg = s[0] === '-' || s[0] === '+';
			s = (neg ? s[0] : '') + s.slice(neg ? 1 : 0).padStart(+width - (neg ? 1 : 0), '0');
		} else s = s.padStart(+width);
	}
	return s;
}

const STRING = {
	len: (s) => s.length,
	sub(s, i = 1, j = -1) {
		const n = s.length;
		let a = i < 0 ? Math.max(n + i + 1, 1) : i === 0 ? 1 : i;
		let b = j < 0 ? n + j + 1 : Math.min(j, n);
		if (a > b) return '';
		return s.slice(a - 1, b);
	},
	upper: (s) => s.toUpperCase(),
	lower: (s) => s.toLowerCase(),
	rep(s, n, sep) {
		n = Math.floor(n);
		if (n <= 0) return '';
		if (sep === undefined) return s.repeat(n);
		return Array(n).fill(s).join(sep);
	},
	reverse: (s) => [...s].reverse().join(''),
	byte(s, i = 1, j) {
		j = j === undefined ? i : j;
		const out = [];
		for (let k = i; k <= j; k++) out.push(s.charCodeAt(k - 1));
		return $M(...out);
	},
	format(fmt, ...args) {
		let ai = 0;
		return String(fmt).replace(/%([-+ #0]*\d*(?:\.\d+)?[a-zA-Z%])/g, (all, spec) => {
			if (spec === '%') return '%';
			return fmtNum('%' + spec, args[ai++]);
		});
	},
	find(s, pat, init = 1, plain = false) {
		const start = luaIndex(s, init, 0);
		if (plain || !/[\^$*+?.()[\]%-]/.test(pat)) {
			const i = s.indexOf(pat, start);
			return i < 0 ? undefined : $M(i + 1, i + pat.length);
		}
		const re = new RegExp(patternToRegex(pat), 'g');
		re.lastIndex = start;
		const m = re.exec(s);
		if (!m || (pat[0] === '^' && m.index !== start)) return undefined;
		return $M(m.index + 1, m.index + m[0].length, ...m.slice(1));
	},
	match(s, pat, init = 1) {
		const start = luaIndex(s, init, 0);
		const re = new RegExp(patternToRegex(pat), 'g');
		re.lastIndex = start;
		const m = re.exec(s);
		if (!m) return undefined;
		return m.length > 1 ? $M(...m.slice(1)) : m[0];
	},
	gmatch(s, pat) {
		const re = new RegExp(patternToRegex(pat), 'g');
		return () => {
			const m = re.exec(s);
			if (!m) return undefined;
			if (m[0] === '') re.lastIndex++;
			return m.length > 1 ? $M(...m.slice(1)) : m[0];
		};
	},
	gsub(s, pat, repl, max = Infinity) {
		const re = new RegExp(patternToRegex(pat), 'g');
		let count = 0;
		const out = s.replace(re, (...m) => {
			if (count >= max) return m[0];
			count++;
			const caps = m.slice(1, -2);
			const whole = m[0];
			const first = caps.length ? caps[0] : whole;
			let r;
			if (typeof repl === 'string') r = repl.replace(/%([0-9%])/g, (a, d) => (d === '%' ? '%' : d === '0' ? whole : caps[+d - 1] ?? whole));
			else if (typeof repl === 'function') r = $1(repl(...(caps.length ? caps : [whole])));
			else r = $get(repl, first);
			return r === undefined || r === null || r === false ? whole : tostring(r);
		});
		return $M(out, count);
	},
	split(s, sep = ',') {
		return s.split(sep);
	},
	char: (...codes) => String.fromCharCode(...codes),
};

// ------------------------------------------------------------------ biblioteca padrão
// ruído de Perlin (math.noise)
const P = new Uint8Array(512);
{
	let seed = 1337;
	const perm = [...Array(256).keys()];
	for (let i = 255; i > 0; i--) {
		seed = (seed * 16807) % 2147483647;
		const j = seed % (i + 1);
		[perm[i], perm[j]] = [perm[j], perm[i]];
	}
	for (let i = 0; i < 512; i++) P[i] = perm[i & 255];
}
function grad(h, x, y, z) {
	const u = h < 8 ? x : y;
	const v = h < 4 ? y : h === 12 || h === 14 ? x : z;
	return ((h & 1) ? -u : u) + ((h & 2) ? -v : v);
}
const fade = (t) => t * t * t * (t * (t * 6 - 15) + 10);
function noise(x = 0, y = 0, z = 0) {
	const X = Math.floor(x) & 255, Y = Math.floor(y) & 255, Z = Math.floor(z) & 255;
	x -= Math.floor(x);
	y -= Math.floor(y);
	z -= Math.floor(z);
	const u = fade(x), v = fade(y), w = fade(z);
	const A = P[X] + Y, AA = P[A] + Z, AB = P[A + 1] + Z, B = P[X + 1] + Y, BA = P[B] + Z, BB = P[B + 1] + Z;
	const l = (a, b, t) => a + t * (b - a);
	const r = l(
		l(l(grad(P[AA] & 15, x, y, z), grad(P[BA] & 15, x - 1, y, z), u), l(grad(P[AB] & 15, x, y - 1, z), grad(P[BB] & 15, x - 1, y - 1, z), u), v),
		l(l(grad(P[AA + 1] & 15, x, y, z - 1), grad(P[BA + 1] & 15, x - 1, y, z - 1), u), l(grad(P[AB + 1] & 15, x, y - 1, z - 1), grad(P[BB + 1] & 15, x - 1, y - 1, z - 1), u), v),
		w,
	);
	return Math.max(-1, Math.min(1, r));
}

const math = {
	abs: Math.abs,
	acos: Math.acos,
	asin: Math.asin,
	atan: (y, x) => (x === undefined ? Math.atan(y) : Math.atan2(y, x)),
	atan2: Math.atan2,
	ceil: Math.ceil,
	clamp: (x, a, b) => (x < a ? a : x > b ? b : x),
	cos: Math.cos,
	cosh: Math.cosh,
	deg: (r) => (r * 180) / Math.PI,
	exp: Math.exp,
	floor: Math.floor,
	fmod: (a, b) => a % b,
	huge: Infinity,
	log: (x, base) => (base === undefined ? Math.log(x) : Math.log(x) / Math.log(base)),
	log10: Math.log10,
	max: (...a) => Math.max(...a),
	min: (...a) => Math.min(...a),
	modf: (x) => $M(Math.trunc(x), x - Math.trunc(x)),
	noise,
	pi: Math.PI,
	pow: Math.pow,
	rad: (d) => (d * Math.PI) / 180,
	random(m, n) {
		if (m === undefined) return Math.random();
		if (n === undefined) return 1 + Math.floor(Math.random() * Math.floor(m));
		return Math.floor(m) + Math.floor(Math.random() * (Math.floor(n) - Math.floor(m) + 1));
	},
	randomseed() {},
	round: (x) => Math.sign(x) * Math.round(Math.abs(x)),
	sign: (x) => (x > 0 ? 1 : x < 0 ? -1 : 0),
	sin: Math.sin,
	sinh: Math.sinh,
	sqrt: Math.sqrt,
	tan: Math.tan,
	tanh: Math.tanh,
	lerp: (a, b, t) => a + (b - a) * t,
};

function luaSort(t, cmp) {
	const n = $len(t);
	const part = t.slice(0, n);
	if (cmp) part.sort((a, b) => ($t($1(cmp(a, b))) ? -1 : $t($1(cmp(b, a))) ? 1 : 0));
	else part.sort((a, b) => (a < b ? -1 : a > b ? 1 : 0));
	for (let i = 0; i < n; i++) t[i] = part[i];
}

function unpack(t, i = 1, j) {
	if (j === undefined) j = $len(t);
	const out = [];
	for (let k = i; k <= j; k++) out.push($get(t, k));
	return $M(...out);
}

const table = {
	insert(t, a, b) {
		if (b === undefined) $ins(t, a);
		else $ins3(t, a, b);
	},
	remove(t, pos) {
		const n = $len(t);
		if (n === 0) return undefined;
		if (pos === undefined) pos = n;
		const v = t[pos - 1];
		t.splice(pos - 1, 1);
		return v;
	},
	concat(t, sep = '', i = 1, j) {
		if (j === undefined) j = $len(t);
		const out = [];
		for (let k = i; k <= j; k++) out.push(tostring($get(t, k)));
		return out.join(sep);
	},
	sort: luaSort,
	clone(t) {
		if (Array.isArray(t)) return Object.assign(t.slice(), Object.fromEntries(Object.keys(t).filter((k) => !INDEX.test(k)).map((k) => [k, t[k]])));
		const c = { ...t };
		if (t.$m) Object.defineProperty(c, '$m', { value: new Map(t.$m), enumerable: false, writable: true });
		return c;
	},
	clear(t) {
		if (Array.isArray(t)) t.length = 0;
		for (const k of Object.keys(t)) delete t[k];
		if (t.$m) t.$m.clear();
	},
	find(t, v, init = 1) {
		const n = $len(t);
		for (let i = init; i <= n; i++) if ($get(t, i) === v) return i;
		return undefined;
	},
	unpack,
	pack: (...a) => Object.assign(a, { n: a.length }),
	create: (n, v) => Array(n).fill(v),
	freeze: (t) => t,
	isfrozen: () => false,
	move(a1, f, e, t, a2 = a1) {
		for (let i = f; i <= e; i++) $set(a2, t + i - f, $get(a1, i));
		return a2;
	},
	getn: $len,
};

function tonumber(x, base) {
	if (typeof x === 'number') return x;
	if (typeof x !== 'string') return undefined;
	const s = x.trim();
	if (base !== undefined && base !== 10) {
		const n = parseInt(s, base);
		return isNaN(n) ? undefined : n;
	}
	if (/^-?0[xX][0-9a-fA-F]+$/.test(s)) return parseInt(s, 16);
	if (s === '' || !/^[-+]?(\d+\.?\d*|\.\d+)([eE][-+]?\d+)?$/.test(s)) return undefined;
	return Number(s);
}

function select(n, ...a) {
	if (n === '#') return a.length;
	if (n < 0) n = a.length + n + 1;
	return $M(...a.slice(n - 1));
}

function ipairsIter(t, i) {
	const v = $get(t, i + 1);
	if (v === undefined || v === null) return undefined;
	return $M(i + 1, v);
}

function luaTypeof(x) {
	if (x !== null && typeof x === 'object' && x.$type) return x.$type;
	return typeName(x);
}

function* waitGen(t) {
	return yield $W(t);
}

export function makeStdlib(extra = {}) {
	const shared = {};
	const G = {
		math,
		string: STRING,
		table,
		os: { clock: () => sched.clock, time: () => Math.floor(Date.now() / 1000), date: () => ({}) },
		task: {
			wait: waitGen,
			spawn: (f, ...a) => startFn(f, a),
			defer: (f, ...a) => delayCall(0, f, ...a),
			delay: (t, f, ...a) => delayCall(t, f, ...a),
			cancel(th) {
				if (th) {
					th.cancelled = true;
					th.dead = true;
				}
			},
		},
		coroutine: {
			running: () => sched.running,
			isyieldable: () => !!sched.running,
			yield: waitGen,
			wrap() {
				throw new LuaError('coroutine.wrap não suportado');
			},
			create() {
				throw new LuaError('coroutine.create não suportado');
			},
		},
		utf8: { char: (...c) => String.fromCodePoint(...c), len: (s) => [...s].length, charpattern: '[\0-\x7F\xC2-\xF4][\x80-\xBF]*' },
		bit32: {
			band: (...a) => a.reduce((x, y) => x & y, -1) >>> 0,
			bor: (...a) => a.reduce((x, y) => x | y, 0) >>> 0,
			bxor: (...a) => a.reduce((x, y) => x ^ y, 0) >>> 0,
			lshift: (x, n) => (x << n) >>> 0,
			rshift: (x, n) => x >>> n,
		},
		print: (...a) => console.log('[Lua]', ...a.map(tostring)),
		warn: (...a) => {
			const msg = a.map(tostring).join(' ');
			console.warn('[Lua]', msg);
			errors.push({ msg, where: 'warn' });
			if (errors.length > 60) errors.shift();
		},
		error(msg) {
			throw new LuaError(msg);
		},
		assert(v, msg, ...rest) {
			if (!$t(v)) throw new LuaError(msg === undefined ? 'assertion failed!' : msg);
			return $M(v, msg, ...rest);
		},
		type: typeName,
		typeof: luaTypeof,
		tostring,
		tonumber,
		select,
		unpack,
		ipairs: (t) => $M(ipairsIter, t, 0),
		pairs: (t) => $M(next, t, undefined),
		next,
		rawget: $get,
		rawset: (t, k, v) => ($set(t, k, v), t),
		rawequal: (a, b) => a === b,
		rawlen: $len,
		setmetatable(t, mt) {
			Object.defineProperty(t, '$mt', { value: mt, enumerable: false, writable: true, configurable: true });
			Object.defineProperty(t, '$lua', { value: true, enumerable: false, writable: true, configurable: true });
			if (mt && mt.__index && typeof mt.__index === 'object') Object.setPrototypeOf(t, mt.__index);
			return t;
		},
		getmetatable: (t) => (t && t.$mt) || undefined,
		pcall,
		xpcall,
		tick: () => sched.clock,
		time: () => sched.clock,
		elapsedTime: () => sched.clock,
		wait: waitGen,
		delay: (t, f) => delayCall(t, f),
		spawn: (f) => delayCall(0, f),
		shared,
		_G: shared,
		...extra,
	};
	return G;
}
