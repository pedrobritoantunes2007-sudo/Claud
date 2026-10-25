// Gerador: árvore do parser.mjs → módulo JavaScript que roda em cima de src/rbx/lua.js.
//
// Regras principais (iguais ao Lua):
//   • verdadeiro/falso: só nil e false são "falsos" ($t, $a, $n); 0 e "" são verdadeiros;
//   • tabelas: {a, b} vira array JS (índice Lua 1 = posição 0), {x = 1} vira objeto; t[k] passa por $get/$set;
//   • operadores com Vector3/CFrame: $add, $sub, $mul... (números conhecidos usam + - * / direto);
//   • vários retornos: $M(a, b) e $1(...) pega o primeiro;
//   • esperas (task.wait, k:wait, sinal:Wait): a função vira function* e as chamadas viram yield* — o agendador de
//     src/rbx/lua.js continua a função depois do tempo, sem travar o jogo.
import { parse } from './parser.mjs';

const JS_RESERVED = new Set([
	'arguments', 'await', 'case', 'catch', 'class', 'const', 'continue', 'debugger', 'default', 'delete', 'enum', 'eval',
	'export', 'extends', 'finally', 'implements', 'import', 'instanceof', 'interface', 'let', 'new', 'null', 'package',
	'private', 'protected', 'public', 'static', 'super', 'switch', 'this', 'throw', 'try', 'typeof', 'var', 'void',
	'with', 'yield', 'undefined', 'NaN', 'Infinity', 'Object', 'Array', 'Math', 'String', 'Number', 'Symbol', 'Map',
	'Set', 'JSON', 'Error', 'globalThis', 'window', 'document', 'console',
]);

// funções da biblioteca que nunca devolvem vários valores nem esperam (chamada direta, sem embrulho)
const LIB_SINGLE = new Set([
	'math.abs', 'math.acos', 'math.asin', 'math.atan', 'math.atan2', 'math.ceil', 'math.clamp', 'math.cos', 'math.cosh',
	'math.deg', 'math.exp', 'math.floor', 'math.fmod', 'math.log', 'math.log10', 'math.max', 'math.min', 'math.noise',
	'math.pow', 'math.rad', 'math.random', 'math.round', 'math.sign', 'math.sin', 'math.sinh', 'math.sqrt', 'math.tan',
	'math.tanh', 'math.lerp', 'table.insert', 'table.remove', 'table.concat', 'table.sort', 'table.clone', 'table.clear',
	'table.find', 'table.create', 'table.freeze', 'table.isfrozen', 'string.rep', 'string.format', 'string.sub',
	'string.upper', 'string.lower', 'string.len', 'string.reverse', 'string.char', 'string.split', 'os.clock', 'os.time',
	'tick', 'time', 'type', 'typeof', 'tostring', 'tonumber', 'print', 'warn', 'error', 'assert', 'ipairs', 'pairs',
	'rawget', 'rawset', 'rawequal', 'setmetatable', 'getmetatable', 'task.spawn', 'task.delay', 'task.defer',
	'task.cancel', 'spawn', 'delay', 'Vector3.new', 'Vector2.new', 'CFrame.new', 'CFrame.Angles', 'CFrame.lookAt',
	'CFrame.fromEulerAnglesXYZ', 'CFrame.fromEulerAnglesYXZ', 'CFrame.fromAxisAngle', 'CFrame.fromOrientation',
	'CFrame.fromMatrix', 'Color3.new', 'Color3.fromRGB', 'Color3.fromHSV', 'Color3.fromHex', 'NumberSequence.new',
	'NumberSequenceKeypoint.new', 'ColorSequence.new', 'ColorSequenceKeypoint.new', 'NumberRange.new', 'UDim2.new',
	'UDim2.fromOffset', 'UDim2.fromScale', 'UDim.new', 'TweenInfo.new', 'Random.new', 'Instance.new', 'BrickColor.new',
	'Ray.new', 'RaycastParams.new', 'OverlapParams.new', 'Rect.new', 'Font.new', 'utf8.char', 'utf8.len',
]);
// métodos que podem devolver vários valores
const MULTI_METHODS = new Set([
	'ToEulerAnglesXYZ', 'ToEulerAnglesYXZ', 'ToOrientation', 'ToAxisAngle', 'GetComponents', 'components', 'ToHSV',
	'FindPartOnRay', 'FindPartOnRayWithIgnoreList', 'find', 'match', 'gsub', 'GetBoundingBox',
]);
const NUMERIC_MEMBERS = new Set(['X', 'Y', 'Z', 'Magnitude']);
const ARITH = { '+': '$add', '-': '$sub', '*': '$mul', '/': '$div', '%': '$mod', '^': '$pow', '//': '$idiv' };

class Scope {
	constructor(parent, fn) {
		this.parent = parent;
		this.fn = fn;
		this.vars = new Map();
	}
	lookup(name) {
		for (let s = this; s; s = s.parent) {
			const b = s.vars.get(name);
			if (b) return b;
		}
		return null;
	}
}

export function translate(src, opts = {}) {
	const file = opts.file || '?';
	const ast = parse(src, file);
	const yieldMethods = new Set(opts.yieldMethods || []);
	const freeNames = new Set();
	const bindings = [];
	const functions = [];
	let counter = 0;
	const fresh = (base) => `${base}$${++counter}`;

	// ------------------------------------------------------------- 1) escopos, nomes e chamadas
	const chunkFn = { type: 'Function', params: [], vararg: true, body: ast.body, isChunk: true, calls: [], returns: [] };
	functions.push(chunkFn);

	function declare(scope, name, kind) {
		const b = { name, kind, funcs: [], jsName: name };
		if (JS_RESERVED.has(name) || scope.lookup(name)) b.jsName = fresh(name);
		scope.vars.set(name, b);
		bindings.push(b);
		return b;
	}

	// "math.floor" se a expressão for um campo de um nome que ainda não é local (global da biblioteca)
	function libPathOf(e) {
		if (e.type === 'Member' && e.obj.type === 'Name' && !e.obj.binding) return `${e.obj.name}.${e.name}`;
		return null;
	}

	function resolveBlock(body, scope, fn) {
		for (const s of body) resolveStat(s, scope, fn);
	}

	function resolveFunction(f, scope) {
		f.calls = [];
		f.returns = [];
		functions.push(f);
		const s = new Scope(scope, f);
		f.paramBindings = f.params.map((p) => declare(s, p, 'param'));
		resolveBlock(f.body, s, f);
	}

	function resolveStat(s, scope, fn) {
		switch (s.type) {
			case 'Local': {
				for (const e of s.exprs) resolveExpr(e, scope, fn);
				s.bindings = s.names.map((n) => declare(scope, n, 'local'));
				s.exprs.forEach((e, i) => {
					const b = s.bindings[i];
					if (!b) return;
					if (e.type === 'Function') b.funcs.push(e);
					const path = libPathOf(e);
					if (path && LIB_SINGLE.has(path)) b.libAlias = path;
				});
				break;
			}
			case 'LocalFunction': {
				s.binding = declare(scope, s.name, 'local');
				s.binding.funcs.push(s.func);
				resolveFunction(s.func, scope);
				break;
			}
			case 'FunctionDecl': {
				resolveExpr(s.target, scope, fn);
				if (s.target.type === 'Name' && s.target.binding && !s.method) s.target.binding.funcs.push(s.func);
				if (s.method) s.func.methodName = s.method;
				resolveFunction(s.func, scope);
				break;
			}
			case 'Assign': {
				for (const e of s.exprs) resolveExpr(e, scope, fn);
				for (const t of s.targets) resolveExpr(t, scope, fn);
				s.targets.forEach((t, i) => {
					const e = s.exprs[i];
					if (t.type === 'Name' && t.binding) {
						t.binding.assigned = true;
						if (e && e.type === 'Function') t.binding.funcs.push(e);
					}
				});
				break;
			}
			case 'Compound':
				resolveExpr(s.target, scope, fn);
				resolveExpr(s.value, scope, fn);
				if (s.target.type === 'Name' && s.target.binding) s.target.binding.assigned = true;
				break;
			case 'CallStat':
				resolveExpr(s.call, scope, fn);
				break;
			case 'Do':
				resolveBlock(s.body, new Scope(scope, fn), fn);
				break;
			case 'While':
				resolveExpr(s.cond, scope, fn);
				resolveBlock(s.body, new Scope(scope, fn), fn);
				break;
			case 'Repeat': {
				const inner = new Scope(scope, fn);
				resolveBlock(s.body, inner, fn);
				resolveExpr(s.cond, inner, fn);
				break;
			}
			case 'If':
				for (const c of s.clauses) {
					resolveExpr(c.cond, scope, fn);
					resolveBlock(c.body, new Scope(scope, fn), fn);
				}
				if (s.orelse) resolveBlock(s.orelse, new Scope(scope, fn), fn);
				break;
			case 'NumFor': {
				resolveExpr(s.start, scope, fn);
				resolveExpr(s.end, scope, fn);
				if (s.step) resolveExpr(s.step, scope, fn);
				const inner = new Scope(scope, fn);
				s.binding = declare(inner, s.var, 'for');
				resolveBlock(s.body, inner, fn);
				break;
			}
			case 'GenFor': {
				for (const e of s.exprs) resolveExpr(e, scope, fn);
				const inner = new Scope(scope, fn);
				s.bindings = s.vars.map((v) => declare(inner, v, 'for'));
				resolveBlock(s.body, inner, fn);
				break;
			}
			case 'Return':
				fn.returns.push(s);
				for (const e of s.exprs) resolveExpr(e, scope, fn);
				break;
			case 'Break':
			case 'Continue':
				break;
			default:
				throw new Error(`${file}:${s.line}: unknown statement ${s.type}`);
		}
	}

	function resolveExpr(e, scope, fn) {
		switch (e.type) {
			case 'Name': {
				e.binding = scope.lookup(e.name);
				if (!e.binding) freeNames.add(e.name);
				break;
			}
			case 'Member':
				resolveExpr(e.obj, scope, fn);
				break;
			case 'Index':
				resolveExpr(e.obj, scope, fn);
				resolveExpr(e.key, scope, fn);
				break;
			case 'Call':
				fn.calls.push(e);
				resolveExpr(e.fn, scope, fn);
				for (const a of e.args) resolveExpr(a, scope, fn);
				break;
			case 'MethodCall':
				fn.calls.push(e);
				resolveExpr(e.obj, scope, fn);
				for (const a of e.args) resolveExpr(a, scope, fn);
				break;
			case 'Function':
				resolveFunction(e, scope);
				break;
			case 'Table':
				for (const it of e.items) {
					if (it.kind === 'computed') resolveExpr(it.key, scope, fn);
					resolveExpr(it.value, scope, fn);
				}
				break;
			case 'Binary':
				resolveExpr(e.left, scope, fn);
				resolveExpr(e.right, scope, fn);
				break;
			case 'Unary':
				resolveExpr(e.arg, scope, fn);
				break;
			case 'Paren':
				resolveExpr(e.expr, scope, fn);
				break;
			case 'IfExpr':
				for (const c of e.clauses) {
					resolveExpr(c.cond, scope, fn);
					resolveExpr(c.value, scope, fn);
				}
				resolveExpr(e.orelse, scope, fn);
				break;
			case 'Vararg':
				if (!fn.vararg) throw new Error(`${file}:${e.line}: '...' outside a vararg function`);
				break;
			default:
				break;
		}
	}

	const root = new Scope(null, chunkFn);
	resolveBlock(ast.body, root, chunkFn);
	// locais com o nome de um global usado no arquivo: renomeia (evita "let x = x")
	for (const b of bindings) if (b.jsName === b.name && freeNames.has(b.name)) b.jsName = fresh(b.name);
	// globais com nome proibido no JS (typeof...)
	const globalJs = new Map();
	for (const g of freeNames) globalJs.set(g, g === 'script' ? '$script' : JS_RESERVED.has(g) ? fresh(g) : g);

	// ------------------------------------------------------------- 2) quem espera (vira function*) e quem devolve vários
	const isGlobal = (e, name) => e.type === 'Name' && !e.binding && e.name === name;
	const libPath = (e) => {
		// "math.floor" se for um global da biblioteca (não um local com o mesmo nome) ou um apelido local dele
		if (e.type === 'Name' && !e.binding) return e.name;
		if (e.type === 'Name' && e.binding && e.binding.libAlias && !e.binding.assigned) return e.binding.libAlias;
		if (e.type === 'Member' && e.obj.type === 'Name' && !e.obj.binding) return `${e.obj.name}.${e.name}`;
		return null;
	};
	const knownYield = (c) => {
		if (c.type === 'Call') {
			const p = libPath(c.fn);
			return p === 'task.wait' || p === 'wait' || p === 'coroutine.yield';
		}
		return c.name === 'Wait' || yieldMethods.has(c.name);
	};
	for (const f of functions) {
		f.yields = f.calls.some(knownYield);
		f.multi = false;
	}
	const retMulti = (r) => {
		if (r.exprs.length > 1) return true;
		const last = r.exprs[r.exprs.length - 1];
		if (!last) return false;
		if (last.type === 'Vararg') return true;
		if (last.type === 'MethodCall') return MULTI_METHODS.has(last.name);
		if (last.type !== 'Call') return false;
		const p = libPath(last.fn);
		if (p && LIB_SINGLE.has(p)) return false;
		if (last.fn.type === 'Name' && last.fn.binding && last.fn.binding.funcs.length) return last.fn.binding.funcs.some((g) => g.multi);
		return true;
	};
	for (let again = true; again; ) {
		again = false;
		for (const f of functions) {
			if (!f.multi && f.returns.some(retMulti)) {
				f.multi = true;
				again = true;
			}
		}
	}
	const fileYieldMethods = new Set();
	let changed = true;
	while (changed) {
		changed = false;
		for (const f of functions) {
			if (f.yields) continue;
			const y = f.calls.some(
				(c) =>
					(c.type === 'Call' && c.fn.type === 'Name' && c.fn.binding && c.fn.binding.funcs.some((g) => g.yields)) ||
					(c.type === 'MethodCall' && fileYieldMethods.has(c.name)),
			);
			if (y) {
				f.yields = true;
				changed = true;
			}
		}
		// métodos declarados aqui (function T:m) que esperam: chamadas :m() também esperam
		for (const f of functions) {
			if (f.yields && f.methodName && !fileYieldMethods.has(f.methodName)) {
				fileYieldMethods.add(f.methodName);
				changed = true;
			}
		}
	}
	chunkFn.yields = false;

	// ------------------------------------------------------------- 3) emissão
	let tmp = 0;
	const T = () => `$v${++tmp}`;
	const out = [];
	let indent = 1;
	const line = (s) => out.push('\t'.repeat(indent) + s);
	let cur = chunkFn; // função atual (para saber se é function*)

	function nameOf(e) {
		if (!e.binding) return globalJs.get(e.name);
		return e.binding.jsName;
	}

	function isNum(e) {
		switch (e.type) {
			case 'Number':
				return true;
			case 'Unary':
				return e.op === '#' || (e.op === '-' && isNum(e.arg));
			case 'Binary':
				return ARITH[e.op] !== undefined && isNum(e.left) && isNum(e.right);
			case 'Paren':
				return isNum(e.expr);
			case 'Name':
				return !!e.binding && e.binding.kind === 'for' && e.binding.numeric;
			case 'Member':
				return NUMERIC_MEMBERS.has(e.name);
			case 'Call': {
				const p = libPath(e.fn);
				if (!p) return false;
				if (p.startsWith('math.')) return p !== 'math.modf' && p !== 'math.frexp';
				return p === 'os.clock' || p === 'tick' || p === 'time';
			}
			default:
				return false;
		}
	}
	function isBool(e) {
		if (e.type === 'True' || e.type === 'False') return true;
		if (e.type === 'Unary' && e.op === 'not') return true;
		if (e.type === 'Binary' && ['==', '~=', '<', '>', '<=', '>='].includes(e.op)) return true;
		if (e.type === 'Binary' && (e.op === 'and' || e.op === 'or')) return isBool(e.left) && isBool(e.right);
		if (e.type === 'Paren') return isBool(e.expr);
		return false;
	}
	const isMultiExpr = (e) => e.type === 'Call' || e.type === 'MethodCall' || e.type === 'Vararg';

	// condição (resultado booleano do JS)
	function cond(e) {
		if (e.type === 'Unary' && e.op === 'not') return `!${cond(e.arg)}`;
		if (e.type === 'Binary' && e.op === 'and') return `(${cond(e.left)} && ${cond(e.right)})`;
		if (e.type === 'Binary' && e.op === 'or') return `(${cond(e.left)} || ${cond(e.right)})`;
		if (e.type === 'Paren') return cond(e.expr);
		if (isBool(e)) return ex(e);
		if (e.type === 'Nil' || e.type === 'False') return 'false';
		if (e.type === 'Number' || e.type === 'String' || e.type === 'Table' || e.type === 'Function') return 'true';
		return `$t(${ex(e)})`;
	}

	function str(s) {
		return JSON.stringify(s).split(String.fromCharCode(0x2028)).join('\\u2028').split(String.fromCharCode(0x2029)).join('\\u2029');
	}

	const IDENT = /^[A-Za-z_$][A-Za-z0-9_$]*$/;

	// expressão com um valor só
	function ex(e) {
		return exM(e, false);
	}

	// multi = pode deixar vários valores (último argumento, último item, return)
	function exM(e, multi) {
		switch (e.type) {
			case 'Nil':
				return 'undefined';
			case 'True':
				return 'true';
			case 'False':
				return 'false';
			case 'Number':
				return Number.isFinite(e.value) ? (e.value < 0 ? `(${e.value})` : String(e.value)) : 'Infinity';
			case 'String':
				return str(e.value);
			case 'Vararg':
				return multi ? '$M(...$va)' : '$va[0]';
			case 'Name':
				return nameOf(e);
			case 'Paren':
				return `(${ex(e.expr)})`;
			case 'Member':
				return `${obj(e.obj)}.${e.name}`;
			case 'Index': {
				if (e.key.type === 'String' && IDENT.test(e.key.value)) return `${obj(e.obj)}.${e.key.value}`;
				return `$get(${ex(e.obj)}, ${ex(e.key)})`;
			}
			case 'Call':
			case 'MethodCall':
				return call(e, multi);
			case 'Function':
				return func(e);
			case 'Table':
				return tableCtor(e);
			case 'Unary': {
				if (e.op === 'not') return `!${cond(e.arg)}`;
				if (e.op === '#') return `$len(${ex(e.arg)})`;
				if (isNum(e.arg)) return `(-${ex(e.arg)})`;
				return `$unm(${ex(e.arg)})`;
			}
			case 'Binary':
				return binary(e);
			case 'IfExpr': {
				let s = '';
				for (const c of e.clauses) s += `${cond(c.cond)} ? ${ex(c.value)} : `;
				return `(${s}${ex(e.orelse)})`;
			}
			default:
				throw new Error(`${file}:${e.line}: unknown expression ${e.type}`);
		}
	}

	// objeto antes de .campo (números e literais precisam de parênteses)
	function obj(e) {
		const s = ex(e);
		if (e.type === 'Number' || e.type === 'String' || e.type === 'Table' || e.type === 'Function') return `(${s})`;
		return s;
	}

	function binary(e) {
		const op = e.op;
		if (op === 'and') {
			if (isBool(e.left)) return `(${ex(e.left)} && ${ex(e.right)})`;
			return `($a(${ex(e.left)}) && ${ex(e.right)})`;
		}
		if (op === 'or') {
			if (isBool(e.left)) return `(${ex(e.left)} || ${ex(e.right)})`;
			return `($n(${ex(e.left)}) ?? ${ex(e.right)})`;
		}
		if (op === '==' || op === '~=') {
			const neg = op === '~=';
			if (e.left.type === 'Nil' || e.right.type === 'Nil') {
				const other = e.left.type === 'Nil' ? e.right : e.left;
				return `(${ex(other)} ${neg ? '!=' : '=='} null)`;
			}
			const lit = (x) => ['Number', 'String', 'True', 'False'].includes(x.type);
			if (lit(e.left) || lit(e.right) || (isNum(e.left) && isNum(e.right))) return `(${ex(e.left)} ${neg ? '!==' : '==='} ${ex(e.right)})`;
			return `${neg ? '!' : ''}$eq(${ex(e.left)}, ${ex(e.right)})`;
		}
		if (op === '<' || op === '>' || op === '<=' || op === '>=') return `(${ex(e.left)} ${op} ${ex(e.right)})`;
		if (op === '..') return `$cat(${ex(e.left)}, ${ex(e.right)})`;
		const fn = ARITH[op];
		if (!fn) throw new Error(`${file}:${e.line}: operator ${op}`);
		if (isNum(e.left) && isNum(e.right)) {
			if (op === '^') return `(${ex(e.left)} ** ${ex(e.right)})`;
			if (op === '%') return `$mod(${ex(e.left)}, ${ex(e.right)})`;
			if (op === '//') return `Math.floor(${ex(e.left)} / ${ex(e.right)})`;
			return `(${ex(e.left)} ${op} ${ex(e.right)})`;
		}
		return `${fn}(${ex(e.left)}, ${ex(e.right)})`;
	}

	function args(list) {
		const parts = list.map((a, i) => {
			if (i === list.length - 1 && isMultiExpr(a)) {
				if (a.type === 'Vararg') return '...$va';
				if (singleValued(a)) return ex(a);
				return `...$mv(${exM(a, true)})`;
			}
			return ex(a);
		});
		return parts.join(', ');
	}

	// esta chamada com certeza devolve um valor só?
	function singleValued(c) {
		if (c.type === 'Call') {
			const p = libPath(c.fn);
			if (p && LIB_SINGLE.has(p)) return true;
			if (c.fn.type === 'Name' && c.fn.binding && c.fn.binding.funcs.length && !c.fn.binding.funcs.some((f) => f.multi)) return true;
			return false;
		}
		if (c.type === 'MethodCall') return !MULTI_METHODS.has(c.name);
		return false;
	}

	function call(c, multi) {
		const gen = cur.yields;
		const unwrap = (s) => (multi ? s : `$1(${s})`);
		if (c.type === 'MethodCall') {
			const o = ex(c.obj);
			const a = c.args.length ? `, ${args(c.args)}` : '';
			if (c.name === 'Wait' && c.args.length === 0) return gen ? unwrap(`(yield $WS(${o}))`) : `$WS(${o})`;
			if (yieldMethods.has(c.name) || fileYieldMethods.has(c.name)) {
				if (!gen) return `$sp($mc(${o}, ${str(c.name)}${a}))`;
				return unwrap(`(yield* $cy($mc(${o}, ${str(c.name)}${a})))`);
			}
			const s = `$mc(${o}, ${str(c.name)}${a})`;
			return MULTI_METHODS.has(c.name) ? unwrap(s) : s;
		}
		const p = libPath(c.fn);
		if (p === 'task.wait' || p === 'wait') {
			const t = c.args.length ? ex(c.args[0]) : '0';
			if (!gen) return `$warnWait()`;
			return `(yield $W(${t}))`;
		}
		if (p === 'coroutine.yield') return gen ? '(yield $W(0))' : '$warnWait()';
		if (p === 'select' && c.args[0] && c.args[0].type === 'String' && c.args[0].value === '#' && c.args[1] && c.args[1].type === 'Vararg') return '$va.length';
		if (p === 'table.insert') {
			if (c.args.length === 2) return `$ins(${ex(c.args[0])}, ${ex(c.args[1])})`;
			return `$ins3(${ex(c.args[0])}, ${ex(c.args[1])}, ${ex(c.args[2])})`;
		}
		if (p === 'pcall' || p === 'xpcall') {
			const s = `${gen ? '$pcallG' : 'pcall'}(${args(c.args)})`;
			return gen ? unwrap(`(yield* ${s})`) : unwrap(s);
		}
		const fnJs = c.fn.type === 'Function' || c.fn.type === 'Number' || c.fn.type === 'String' ? `(${ex(c.fn)})` : ex(c.fn);
		const s = `${fnJs}(${args(c.args)})`;
		if (p && LIB_SINGLE.has(p)) return s;
		if (c.fn.type === 'Name' && c.fn.binding && c.fn.binding.funcs.length) {
			// função local conhecida
			const fs = c.fn.binding.funcs;
			const yields = fs.some((f) => f.yields);
			const isMulti = fs.some((f) => f.multi);
			if (yields) {
				if (!gen) return `$sp(${s})`;
				return isMulti ? unwrap(`(yield* $cy(${s}))`) : `(yield* $cy(${s}))`;
			}
			return isMulti ? unwrap(s) : s;
		}
		// desconhecida (campo de tabela, parâmetro, global): pode ser function* ou ter vários retornos
		if (gen) return unwrap(`(yield* $cy(${s}))`);
		return multi ? `$sp(${s})` : `$sp1(${s})`;
	}

	function tableCtor(t) {
		const pos = [];
		const named = [];
		const computed = [];
		t.items.forEach((it, i) => {
			if (it.kind === 'pos') {
				const last = i === t.items.length - 1;
				if (last && isMultiExpr(it.value)) {
					if (it.value.type === 'Vararg') pos.push('...$va');
					else if (singleValued(it.value)) pos.push(ex(it.value));
					else pos.push(`...$mv(${exM(it.value, true)})`);
				} else pos.push(ex(it.value));
			} else if (it.kind === 'named') {
				named.push(`${IDENT.test(it.key) ? it.key : str(it.key)}: ${ex(it.value)}`);
			} else if (it.key.type === 'String') {
				named.push(`${str(it.key.value)}: ${ex(it.value)}`);
			} else {
				computed.push(`[${ex(it.key)}, ${ex(it.value)}]`);
			}
		});
		let base;
		if (named.length && !pos.length) base = `{ ${named.join(', ')} }`;
		else if (named.length) base = `$tm([${pos.join(', ')}], { ${named.join(', ')} })`;
		else base = `[${pos.join(', ')}]`;
		if (computed.length) return `$tc(${base}, [${computed.join(', ')}])`;
		return base;
	}

	function func(f) {
		const saved = cur;
		const savedIndent = indent;
		cur = f;
		const params = f.paramBindings.map((b) => b.jsName);
		if (f.vararg) params.push('...$va');
		const head = `function${f.yields ? '*' : ''} (${params.join(', ')}) {`;
		const bodyOut = [];
		const savedOut = out.length;
		indent = savedIndent + 1;
		emitBlock(f.body);
		const lines = out.splice(savedOut);
		bodyOut.push(...lines);
		indent = savedIndent;
		cur = saved;
		if (!bodyOut.length) return `${head}}`;
		return `${head}\n${bodyOut.join('\n')}\n${'\t'.repeat(indent)}}`;
	}

	function emitBlock(body) {
		for (const s of body) emitStat(s);
	}

	function assignTo(target, value) {
		if (target.type === 'Name') return `${nameOf(target)} = ${value};`;
		if (target.type === 'Member') return `${obj(target.obj)}.${target.name} = ${value};`;
		if (target.type === 'Index') {
			if (target.key.type === 'String' && IDENT.test(target.key.value)) return `${obj(target.obj)}.${target.key.value} = ${value};`;
			return `$set(${ex(target.obj)}, ${ex(target.key)}, ${value});`;
		}
		throw new Error(`${file}:${target.line}: bad assignment target`);
	}

	// lista de valores para n alvos: devolve [lista de expressões JS] ou null se precisa de $lst
	function valueList(exprs, n) {
		const last = exprs[exprs.length - 1];
		if (exprs.length >= n || !last || !isMultiExpr(last) || (last.type !== 'Vararg' && singleValued(last))) {
			const vals = [];
			for (let i = 0; i < n; i++) vals.push(exprs[i] ? ex(exprs[i]) : 'undefined');
			// expressões a mais também rodam (podem ter efeito)
			const extra = exprs.slice(n).map((e) => exM(e, true));
			return { vals, extra };
		}
		return null;
	}

	function emitStat(s) {
		switch (s.type) {
			case 'Local': {
				const names = s.bindings.map((b) => b.jsName);
				if (!s.exprs.length) {
					line(`let ${names.join(', ')};`);
					break;
				}
				const vl = valueList(s.exprs, names.length);
				if (vl) {
					line(`let ${names.map((n, i) => `${n} = ${vl.vals[i]}`).join(', ')};`);
					for (const x of vl.extra) line(`${x};`);
				} else {
					const pre = s.exprs.slice(0, -1).map(ex);
					const last = s.exprs[s.exprs.length - 1];
					const lastJs = last.type === 'Vararg' ? '$M(...$va)' : exM(last, true);
					line(`let [${names.join(', ')}] = $lst([${pre.join(', ')}], ${lastJs}, ${names.length});`);
				}
				break;
			}
			case 'LocalFunction':
				line(`let ${s.binding.jsName} = ${func(s.func)};`);
				break;
			case 'FunctionDecl': {
				if (s.method) s.func.methodName = s.method;
				const f = func(s.func);
				if (s.method) line(`${ex(s.target)}.${s.method} = ${f};`);
				else line(assignTo(s.target, f));
				break;
			}
			case 'Assign': {
				if (s.targets.length === 1 && s.exprs.length === 1) {
					line(assignTo(s.targets[0], ex(s.exprs[0])));
					break;
				}
				const n = s.targets.length;
				const vl = valueList(s.exprs, n);
				const v = T();
				if (vl) line(`const ${v} = [${vl.vals.join(', ')}];`);
				else {
					const pre = s.exprs.slice(0, -1).map(ex);
					const last = s.exprs[s.exprs.length - 1];
					line(`const ${v} = $lst([${pre.join(', ')}], ${last.type === 'Vararg' ? '$M(...$va)' : exM(last, true)}, ${n});`);
				}
				if (vl) for (const x of vl.extra) line(`${x};`);
				s.targets.forEach((t, i) => line(assignTo(t, `${v}[${i}]`)));
				break;
			}
			case 'Compound': {
				const fake = { type: 'Binary', op: s.op, left: s.target, right: s.value, line: s.line };
				line(assignTo(s.target, ex(fake)));
				break;
			}
			case 'CallStat':
				line(`${exM(s.call, true)};`);
				break;
			case 'Do':
				line('{');
				indent++;
				emitBlock(s.body);
				indent--;
				line('}');
				break;
			case 'While':
				line(`while (${cond(s.cond)}) {`);
				indent++;
				emitBlock(s.body);
				indent--;
				line('}');
				break;
			case 'Repeat':
				line('while (true) {');
				indent++;
				emitBlock(s.body);
				line(`if (${cond(s.cond)}) break;`);
				indent--;
				line('}');
				break;
			case 'If': {
				s.clauses.forEach((c, i) => {
					line(`${i === 0 ? 'if' : '} else if'} (${cond(c.cond)}) {`);
					indent++;
					emitBlock(c.body);
					indent--;
				});
				if (s.orelse && s.orelse.length) {
					line('} else {');
					indent++;
					emitBlock(s.orelse);
					indent--;
				}
				line('}');
				break;
			}
			case 'NumFor': {
				const v = s.binding.jsName;
				s.binding.numeric = isNum(s.start);
				const e = T();
				const start = ex(s.start);
				const end = ex(s.end);
				if (!s.step || (s.step.type === 'Number' && s.step.value > 0)) {
					const inc = !s.step || s.step.value === 1 ? `${v}++` : `${v} += ${s.step.value}`;
					line(`for (let ${v} = ${start}, ${e} = ${end}; ${v} <= ${e}; ${inc}) {`);
				} else if (s.step.type === 'Number' || (s.step.type === 'Unary' && s.step.op === '-' && s.step.arg.type === 'Number')) {
					const st = ex(s.step);
					line(`for (let ${v} = ${start}, ${e} = ${end}; ${v} >= ${e}; ${v} += ${st}) {`);
				} else {
					const st = T();
					line(`for (let ${v} = ${start}, ${e} = ${end}, ${st} = ${ex(s.step)}; ${st} > 0 ? ${v} <= ${e} : ${v} >= ${e}; ${v} += ${st}) {`);
				}
				indent++;
				emitBlock(s.body);
				indent--;
				line('}');
				break;
			}
			case 'GenFor': {
				const names = s.bindings.map((b) => b.jsName);
				const e0 = s.exprs[0];
				const direct = s.exprs.length === 1 && e0.type === 'Call' && e0.args.length === 1;
				if (direct && isGlobal(e0.fn, 'ipairs')) {
					const i = T();
					const a = T();
					line(`for (let ${i} = 0, ${a} = $arr(${ex(e0.args[0])}); ${i} < ${a}.length; ${i}++) {`);
					indent++;
					if (names[1]) line(`let ${names[1]} = ${a}[${i}];`);
					line(`if (${names[1] ? names[1] : `${a}[${i}]`} == null) break;`);
					if (names[0] && s.vars[0] !== '_') line(`let ${names[0]} = ${i} + 1;`);
					for (const b of s.bindings) if (b === s.bindings[0]) b.numeric = true;
					emitBlock(s.body);
					indent--;
					line('}');
					break;
				}
				let iter;
				if (direct && (isGlobal(e0.fn, 'pairs') || isGlobal(e0.fn, 'next'))) iter = `$pairs(${ex(e0.args[0])})`;
				else if (s.exprs.length === 2 && isGlobal(s.exprs[0], 'next')) iter = `$pairs(${ex(s.exprs[1])})`;
				else if (s.exprs.length === 1 && isMultiExpr(e0)) iter = `$iter(...$mv(${exM(e0, true)}))`;
				else iter = `$iter(${s.exprs.map(ex).join(', ')})`;
				line(`for (let [${names.join(', ')}] of ${iter}) {`);
				indent++;
				emitBlock(s.body);
				indent--;
				line('}');
				break;
			}
			case 'Return': {
				if (cur.isChunk) {
					line(`return ${s.exprs.length ? ex(s.exprs[0]) : 'undefined'};`);
					break;
				}
				if (!s.exprs.length) line('return;');
				else if (s.exprs.length === 1) line(`return ${exM(s.exprs[0], true)};`);
				else {
					const last = s.exprs[s.exprs.length - 1];
					const pre = s.exprs.slice(0, -1).map(ex);
					if (isMultiExpr(last) && !(last.type !== 'Vararg' && singleValued(last))) {
						const lastJs = last.type === 'Vararg' ? '...$va' : `...$mv(${exM(last, true)})`;
						line(`return $M(${pre.join(', ')}, ${lastJs});`);
					} else line(`return $M(${pre.join(', ')}, ${ex(last)});`);
				}
				break;
			}
			case 'Break':
				line('break;');
				break;
			case 'Continue':
				line('continue;');
				break;
			default:
				throw new Error(`${file}:${s.line}: unknown statement ${s.type}`);
		}
	}

	emitBlock(ast.body);

	const HELPERS = [
		'$t', '$a', '$n', '$1', '$M', '$mv', '$lst', '$get', '$set', '$tm', '$tc', '$len', '$cat', '$eq', '$add', '$sub',
		'$mul', '$div', '$mod', '$pow', '$idiv', '$unm', '$mc', '$cy', '$sp', '$sp1', '$W', '$WS', '$ins', '$ins3', '$arr',
		'$pairs', '$iter', '$pcallG', '$warnWait',
	];
	const globals = [...freeNames].filter((n) => n !== 'script');
	const header = [
		`// Gerado automaticamente de ${file} (código do jogo Roblox) por tools/lua2js — não edite à mão.`,
		`import { ${HELPERS.join(', ')} } from '${opts.runtime || '../rbx/lua.js'}';`,
		'',
		'export default function ($G, $script) {',
	];
	if (globals.length) header.push(`\tlet ${globals.map((g) => `${globalJs.get(g)} = $G[${str(g)}]`).join(', ')};`);
	if (out.some((l) => l.includes('$va'))) header.push('\tconst $va = [];');
	const js = [...header, ...out, '}', ''].join('\n');
	return { js, freeNames: globals, yieldMethods: [...fileYieldMethods] };
}
