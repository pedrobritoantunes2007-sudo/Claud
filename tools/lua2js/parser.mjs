// Leitor de código Lua 5.1 + Luau (o Lua do Roblox): tipos (ignorados), +=, continue, ::.
// Gera uma árvore (AST) simples que o gerador.mjs transforma em JavaScript.

const KEYWORDS = new Set([
	'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', 'if', 'in', 'local', 'nil', 'not', 'or',
	'repeat', 'return', 'then', 'true', 'until', 'while',
]);

const SYMBOLS = [
	'...', '..=', '//=', '..', '::', '==', '~=', '<=', '>=', '//', '+=', '-=', '*=', '/=', '%=', '^=', '->',
	'+', '-', '*', '/', '%', '^', '#', '&', '~', '|', '<', '>', '=', '(', ')', '{', '}', '[', ']', ';', ':', ',', '.', '?',
];

export class LuaSyntaxError extends Error {}

export function tokenize(src, file = '?') {
	const toks = [];
	let i = 0;
	let line = 1;
	const n = src.length;
	const err = (msg) => {
		throw new LuaSyntaxError(`${file}:${line}: ${msg}`);
	};
	const longBracket = (start) => {
		// src[start] === '[' ; devolve [nível, posição depois do 2º colchete] ou null
		let j = start + 1;
		let level = 0;
		while (src[j] === '=') {
			level++;
			j++;
		}
		if (src[j] !== '[') return null;
		return [level, j + 1];
	};
	const readLong = (level, from) => {
		const close = ']' + '='.repeat(level) + ']';
		const end = src.indexOf(close, from);
		if (end < 0) err('long string/comment not closed');
		let text = src.slice(from, end);
		for (const ch of text) if (ch === '\n') line++;
		if (text.startsWith('\r\n')) text = text.slice(2);
		else if (text.startsWith('\n')) text = text.slice(1);
		i = end + close.length;
		return text;
	};
	while (i < n) {
		const c = src[i];
		if (c === '\n') {
			line++;
			i++;
			continue;
		}
		if (c === ' ' || c === '\t' || c === '\r' || c === '\f' || c === '\v') {
			i++;
			continue;
		}
		if (c === '-' && src[i + 1] === '-') {
			i += 2;
			if (src[i] === '[') {
				const lb = longBracket(i);
				if (lb) {
					readLong(lb[0], lb[1]);
					continue;
				}
			}
			while (i < n && src[i] !== '\n') i++;
			continue;
		}
		const tokLine = line;
		if (/[A-Za-z_]/.test(c)) {
			let j = i + 1;
			while (j < n && /[A-Za-z0-9_]/.test(src[j])) j++;
			const word = src.slice(i, j);
			toks.push({ t: KEYWORDS.has(word) ? 'kw' : 'name', v: word, line: tokLine });
			i = j;
			continue;
		}
		if (/[0-9]/.test(c) || (c === '.' && /[0-9]/.test(src[i + 1]))) {
			let j = i;
			let value;
			if (c === '0' && (src[i + 1] === 'x' || src[i + 1] === 'X')) {
				j = i + 2;
				while (j < n && /[0-9a-fA-F_]/.test(src[j])) j++;
				value = parseInt(src.slice(i + 2, j).replace(/_/g, ''), 16);
			} else if (c === '0' && (src[i + 1] === 'b' || src[i + 1] === 'B')) {
				j = i + 2;
				while (j < n && /[01_]/.test(src[j])) j++;
				value = parseInt(src.slice(i + 2, j).replace(/_/g, ''), 2);
			} else {
				while (j < n && /[0-9_]/.test(src[j])) j++;
				if (src[j] === '.') {
					j++;
					while (j < n && /[0-9_]/.test(src[j])) j++;
				}
				if (src[j] === 'e' || src[j] === 'E') {
					j++;
					if (src[j] === '+' || src[j] === '-') j++;
					while (j < n && /[0-9]/.test(src[j])) j++;
				}
				value = parseFloat(src.slice(i, j).replace(/_/g, ''));
			}
			toks.push({ t: 'num', v: value, line: tokLine });
			i = j;
			continue;
		}
		if (c === '"' || c === "'") {
			let j = i + 1;
			let out = '';
			while (true) {
				if (j >= n) err('string not closed');
				const ch = src[j];
				if (ch === c) break;
				if (ch === '\n') err('unfinished string');
				if (ch === '\\') {
					const e = src[j + 1];
					j += 2;
					if (e === 'n') out += '\n';
					else if (e === 't') out += '\t';
					else if (e === 'r') out += '\r';
					else if (e === 'a') out += '\x07';
					else if (e === 'b') out += '\b';
					else if (e === 'f') out += '\f';
					else if (e === 'v') out += '\v';
					else if (e === '\\') out += '\\';
					else if (e === '"') out += '"';
					else if (e === "'") out += "'";
					else if (e === '\n') {
						out += '\n';
						line++;
					} else if (e === 'x') {
						out += String.fromCharCode(parseInt(src.slice(j, j + 2), 16));
						j += 2;
					} else if (e === 'z') {
						while (j < n && /\s/.test(src[j])) {
							if (src[j] === '\n') line++;
							j++;
						}
					} else if (e === 'u' && src[j] === '{') {
						const close = src.indexOf('}', j);
						out += String.fromCodePoint(parseInt(src.slice(j + 1, close), 16));
						j = close + 1;
					} else if (/[0-9]/.test(e)) {
						let k = j - 1;
						let digits = '';
						while (digits.length < 3 && /[0-9]/.test(src[k])) digits += src[k++];
						out += String.fromCharCode(parseInt(digits, 10));
						j = k;
					} else err(`bad escape \\${e}`);
					continue;
				}
				out += ch;
				j++;
			}
			toks.push({ t: 'str', v: out, line: tokLine });
			i = j + 1;
			continue;
		}
		if (c === '[') {
			const lb = longBracket(i);
			if (lb) {
				const text = readLong(lb[0], lb[1]);
				toks.push({ t: 'str', v: text, line: tokLine });
				continue;
			}
		}
		if (c === '`') err('interpolated strings are not supported');
		let sym = null;
		for (const s of SYMBOLS) {
			if (src.startsWith(s, i)) {
				sym = s;
				break;
			}
		}
		if (!sym) err(`unexpected character '${c}'`);
		toks.push({ t: 'sym', v: sym, line: tokLine });
		i += sym.length;
	}
	toks.push({ t: 'eof', v: '<eof>', line });
	return toks;
}

// prioridades dos operadores binários (iguais às do lparser.c): [esquerda, direita]
const BINARY = {
	or: [1, 1],
	and: [2, 2],
	'<': [3, 3], '>': [3, 3], '<=': [3, 3], '>=': [3, 3], '~=': [3, 3], '==': [3, 3],
	'..': [9, 8],
	'+': [10, 10], '-': [10, 10],
	'*': [11, 11], '/': [11, 11], '//': [11, 11], '%': [11, 11],
	'^': [14, 13],
};
const UNARY_PRIORITY = 12;

export function parse(src, file = '?') {
	const toks = tokenize(src, file);
	let p = 0;
	const tok = () => toks[p];
	const peek = (k = 1) => toks[p + k];
	const next = () => toks[p++];
	const err = (msg, t = tok()) => {
		throw new LuaSyntaxError(`${file}:${t.line}: ${msg} (near '${t.v}')`);
	};
	const is = (t, v) => tok().t === t && (v === undefined || tok().v === v);
	const isSym = (v) => is('sym', v);
	const isKw = (v) => is('kw', v);
	const accept = (t, v) => {
		if (is(t, v)) return next();
		return null;
	};
	const expect = (t, v) => {
		if (!is(t, v)) err(`'${v || t}' expected`);
		return next();
	};
	const expectName = () => {
		if (tok().t !== 'name') err('name expected');
		return next().v;
	};

	// ------------------------------------------------------------- tipos do Luau (lidos e jogados fora)
	function skipBalanced(open, close) {
		let depth = 0;
		do {
			if (tok().t === 'eof') err('unbalanced type');
			if (isSym(open)) depth++;
			else if (isSym(close)) depth--;
			next();
		} while (depth > 0);
	}
	function skipSimpleType() {
		if (isKw('nil') || isKw('true') || isKw('false') || is('str')) {
			next();
			return;
		}
		if (isSym('...')) {
			next();
			if (tok().t === 'name' || isSym('{') || isSym('(')) skipType();
			return;
		}
		if (is('name', 'typeof') && peek().t === 'sym' && peek().v === '(') {
			next();
			skipBalanced('(', ')');
			return;
		}
		if (tok().t === 'name') {
			next();
			while (isSym('.') && peek().t === 'name') {
				next();
				next();
			}
			if (isSym('<')) skipBalanced('<', '>');
			if (isSym('...')) next();
			return;
		}
		if (isSym('{')) {
			skipBalanced('{', '}');
			return;
		}
		if (isSym('<')) {
			skipBalanced('<', '>');
		}
		if (isSym('(')) {
			skipBalanced('(', ')');
			if (accept('sym', '->')) skipType();
			return;
		}
		err('type expected');
	}
	function skipType() {
		accept('sym', '|');
		accept('sym', '&');
		skipSimpleType();
		while (isSym('?')) next();
		while (isSym('|') || isSym('&')) {
			next();
			skipSimpleType();
			while (isSym('?')) next();
		}
		if (accept('sym', '->')) skipType();
	}
	function skipTypeAnnotation() {
		if (accept('sym', ':')) skipType();
	}

	// ------------------------------------------------------------- blocos
	function blockEnds() {
		const t = tok();
		if (t.t === 'eof') return true;
		if (t.t === 'kw' && (t.v === 'end' || t.v === 'else' || t.v === 'elseif' || t.v === 'until')) return true;
		return false;
	}

	function block() {
		const body = [];
		while (!blockEnds()) {
			if (isKw('return')) {
				body.push(retstat());
				break;
			}
			const s = statement();
			if (s) body.push(s);
		}
		return body;
	}

	function retstat() {
		const t = next();
		let exprs = [];
		if (!blockEnds() && !isSym(';')) exprs = exprList();
		accept('sym', ';');
		return { type: 'Return', exprs, line: t.line };
	}

	function statement() {
		const t = tok();
		const line = t.line;
		if (t.t === 'sym' && t.v === ';') {
			next();
			return null;
		}
		if (t.t === 'kw') {
			switch (t.v) {
				case 'if':
					return ifstat();
				case 'while': {
					next();
					const cond = expr();
					expect('kw', 'do');
					const body = block();
					expect('kw', 'end');
					return { type: 'While', cond, body, line };
				}
				case 'do': {
					next();
					const body = block();
					expect('kw', 'end');
					return { type: 'Do', body, line };
				}
				case 'for':
					return forstat();
				case 'repeat': {
					next();
					const body = block();
					expect('kw', 'until');
					const cond = expr();
					return { type: 'Repeat', body, cond, line };
				}
				case 'function': {
					next();
					// nome: a.b.c ou a.b:c
					let target = { type: 'Name', name: expectName(), line };
					let method = null;
					while (isSym('.')) {
						next();
						target = { type: 'Member', obj: target, name: expectName(), line };
					}
					if (accept('sym', ':')) method = expectName();
					const func = funcBody(line, method !== null, method || (target.type === 'Name' ? target.name : target.name));
					return { type: 'FunctionDecl', target, method, func, line };
				}
				case 'local': {
					next();
					if (accept('kw', 'function')) {
						const name = expectName();
						const func = funcBody(line, false, name);
						return { type: 'LocalFunction', name, func, line };
					}
					const names = [];
					do {
						const name = expectName();
						if (isSym('<')) skipBalanced('<', '>'); // <const> / <close>
						skipTypeAnnotation();
						names.push(name);
					} while (accept('sym', ','));
					let exprs = [];
					if (accept('sym', '=')) exprs = exprList();
					return { type: 'Local', names, exprs, line };
				}
				case 'return':
					return retstat();
				case 'break':
					next();
					return { type: 'Break', line };
				default:
					break;
			}
		}
		if (t.t === 'name') {
			// Luau: continue / type X = ... / export type X = ...
			if (t.v === 'continue' && !startsSuffix(peek())) {
				next();
				return { type: 'Continue', line };
			}
			if (t.v === 'type' && peek().t === 'name') {
				next();
				next();
				if (isSym('<')) skipBalanced('<', '>');
				expect('sym', '=');
				skipType();
				return null;
			}
			if (t.v === 'export' && peek().t === 'name' && peek().v === 'type') {
				next();
				next();
				next();
				if (isSym('<')) skipBalanced('<', '>');
				expect('sym', '=');
				skipType();
				return null;
			}
		}
		// atribuição ou chamada
		const first = suffixedExpr();
		if (isSym('=') || isSym(',')) {
			const targets = [first];
			while (accept('sym', ',')) targets.push(suffixedExpr());
			expect('sym', '=');
			const exprs = exprList();
			for (const tg of targets) if (tg.type !== 'Name' && tg.type !== 'Index' && tg.type !== 'Member') err('cannot assign');
			return { type: 'Assign', targets, exprs, line };
		}
		const compound = ['+=', '-=', '*=', '/=', '%=', '^=', '..=', '//='];
		if (tok().t === 'sym' && compound.includes(tok().v)) {
			const op = next().v.slice(0, -1);
			const value = expr();
			return { type: 'Compound', op, target: first, value, line };
		}
		if (first.type !== 'Call' && first.type !== 'MethodCall') err('syntax error');
		return { type: 'CallStat', call: first, line };
	}

	function startsSuffix(t) {
		if (t.t !== 'sym') return t.t === 'str';
		return ['(', '=', '.', '[', ':', ',', '{', '+=', '-=', '*=', '/=', '..='].includes(t.v);
	}

	function ifstat() {
		const line = tok().line;
		const clauses = [];
		next();
		let cond = expr();
		expect('kw', 'then');
		clauses.push({ cond, body: block() });
		let orelse = null;
		while (true) {
			if (accept('kw', 'elseif')) {
				cond = expr();
				expect('kw', 'then');
				clauses.push({ cond, body: block() });
			} else if (accept('kw', 'else')) {
				orelse = block();
				expect('kw', 'end');
				break;
			} else {
				expect('kw', 'end');
				break;
			}
		}
		return { type: 'If', clauses, orelse, line };
	}

	function forstat() {
		const line = next().line;
		const n1 = expectName();
		skipTypeAnnotation();
		if (accept('sym', '=')) {
			const start = expr();
			expect('sym', ',');
			const end = expr();
			let step = null;
			if (accept('sym', ',')) step = expr();
			expect('kw', 'do');
			const body = block();
			expect('kw', 'end');
			return { type: 'NumFor', var: n1, start, end, step, body, line };
		}
		const vars = [n1];
		while (accept('sym', ',')) {
			vars.push(expectName());
			skipTypeAnnotation();
		}
		expect('kw', 'in');
		const exprs = exprList();
		expect('kw', 'do');
		const body = block();
		expect('kw', 'end');
		return { type: 'GenFor', vars, exprs, body, line };
	}

	function funcBody(line, isMethod, name) {
		if (isSym('<')) skipBalanced('<', '>');
		expect('sym', '(');
		const params = [];
		let vararg = false;
		if (isMethod) params.push('self');
		if (!isSym(')')) {
			do {
				if (accept('sym', '...')) {
					vararg = true;
					skipTypeAnnotation();
					break;
				}
				params.push(expectName());
				skipTypeAnnotation();
			} while (accept('sym', ','));
		}
		expect('sym', ')');
		skipTypeAnnotation();
		const body = block();
		expect('kw', 'end');
		return { type: 'Function', params, vararg, body, name, line };
	}

	// ------------------------------------------------------------- expressões
	function exprList() {
		const list = [expr()];
		while (accept('sym', ',')) list.push(expr());
		return list;
	}

	function expr(limit = 0) {
		let left;
		const t = tok();
		if ((t.t === 'kw' && t.v === 'not') || (t.t === 'sym' && (t.v === '-' || t.v === '#'))) {
			next();
			const arg = expr(UNARY_PRIORITY);
			left = { type: 'Unary', op: t.v, arg, line: t.line };
		} else {
			left = simpleExpr();
		}
		while (true) {
			const o = tok();
			const op = o.t === 'kw' || o.t === 'sym' ? o.v : null;
			const pr = op && BINARY[op];
			if (!pr || pr[0] <= limit) break;
			next();
			const right = expr(pr[1]);
			left = { type: 'Binary', op, left, right, line: o.line };
		}
		return left;
	}

	function simpleExpr() {
		const t = tok();
		let e;
		if (t.t === 'num') {
			next();
			e = { type: 'Number', value: t.v, line: t.line };
		} else if (t.t === 'str') {
			next();
			e = { type: 'String', value: t.v, line: t.line };
		} else if (t.t === 'kw' && t.v === 'nil') {
			next();
			e = { type: 'Nil', line: t.line };
		} else if (t.t === 'kw' && t.v === 'true') {
			next();
			e = { type: 'True', line: t.line };
		} else if (t.t === 'kw' && t.v === 'false') {
			next();
			e = { type: 'False', line: t.line };
		} else if (t.t === 'sym' && t.v === '...') {
			next();
			e = { type: 'Vararg', line: t.line };
		} else if (t.t === 'sym' && t.v === '{') {
			e = table();
		} else if (t.t === 'kw' && t.v === 'function') {
			next();
			e = funcBody(t.line, false, null);
		} else if (t.t === 'kw' && t.v === 'if') {
			// Luau: if a then b elseif c then d else e
			next();
			const clauses = [];
			const cond = expr();
			expect('kw', 'then');
			clauses.push({ cond, value: expr() });
			while (accept('kw', 'elseif')) {
				const c2 = expr();
				expect('kw', 'then');
				clauses.push({ cond: c2, value: expr() });
			}
			expect('kw', 'else');
			e = { type: 'IfExpr', clauses, orelse: expr(), line: t.line };
		} else {
			e = suffixedExpr();
		}
		if (isSym('::')) {
			next();
			skipType();
		}
		return e;
	}

	function primaryExpr() {
		const t = tok();
		if (t.t === 'name') {
			next();
			return { type: 'Name', name: t.v, line: t.line };
		}
		if (t.t === 'sym' && t.v === '(') {
			next();
			const e = expr();
			expect('sym', ')');
			return { type: 'Paren', expr: e, line: t.line };
		}
		err('unexpected symbol');
	}

	function suffixedExpr() {
		let e = primaryExpr();
		while (true) {
			const t = tok();
			if (t.t === 'sym' && t.v === '.') {
				next();
				e = { type: 'Member', obj: e, name: expectName(), line: t.line };
			} else if (t.t === 'sym' && t.v === '[') {
				next();
				const key = expr();
				expect('sym', ']');
				e = { type: 'Index', obj: e, key, line: t.line };
			} else if (t.t === 'sym' && t.v === ':' && peek().t === 'name' && isCallStart(peek(2))) {
				next();
				const name = expectName();
				e = { type: 'MethodCall', obj: e, name, args: callArgs(), line: t.line };
			} else if (isCallStart(t)) {
				e = { type: 'Call', fn: e, args: callArgs(), line: t.line };
			} else if (t.t === 'sym' && t.v === '::') {
				next();
				skipType();
			} else {
				return e;
			}
		}
	}

	function isCallStart(t) {
		return (t.t === 'sym' && (t.v === '(' || t.v === '{')) || t.t === 'str';
	}

	function callArgs() {
		const t = tok();
		if (t.t === 'str') {
			next();
			return [{ type: 'String', value: t.v, line: t.line }];
		}
		if (t.t === 'sym' && t.v === '{') return [table()];
		expect('sym', '(');
		if (accept('sym', ')')) return [];
		const args = exprList();
		expect('sym', ')');
		return args;
	}

	function table() {
		const line = expect('sym', '{').line;
		const items = [];
		while (!isSym('}')) {
			if (isSym('[')) {
				next();
				const key = expr();
				expect('sym', ']');
				expect('sym', '=');
				items.push({ kind: 'computed', key, value: expr() });
			} else if (tok().t === 'name' && peek().t === 'sym' && peek().v === '=') {
				const key = next().v;
				next();
				items.push({ kind: 'named', key, value: expr() });
			} else {
				items.push({ kind: 'pos', value: expr() });
			}
			if (!accept('sym', ',') && !accept('sym', ';')) break;
		}
		expect('sym', '}');
		return { type: 'Table', items, line };
	}

	const body = block();
	if (tok().t !== 'eof') err("'<eof>' expected");
	return { type: 'Chunk', body };
}
