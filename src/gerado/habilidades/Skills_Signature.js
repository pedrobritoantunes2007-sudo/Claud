// Gerado automaticamente de server/Services/SpecialsPacks/Skills_Signature.lua (código do jogo Roblox) por tools/lua2js — não edite à mão.
import { $t, $a, $n, $1, $M, $mv, $lst, $get, $set, $tm, $tc, $len, $cat, $eq, $add, $sub, $mul, $div, $mod, $pow, $idiv, $unm, $mc, $cy, $sp, $sp1, $W, $WS, $ins, $ins3, $arr, $pairs, $iter, $pcallG, $warnWait } from '../../rbx/lua.js';

export default function ($G, $script) {
	let require = $G["require"], Color3 = $G["Color3"], Vector3 = $G["Vector3"], math = $G["math"], os = $G["os"], task = $G["task"], ipairs = $G["ipairs"], table = $G["table"];
	let SkillKit = $sp1(require($script.Parent.Parent.SkillKit));
	let C = Color3.fromRGB;
	let UP = Vector3.new(0, 1, 0);
	let G = SkillKit.Ground;
	let side = function (d) {
		return Vector3.new((-d.Z), 0, d.X);
	};
	let flatDist = function (a, b) {
		return Vector3.new((a.X - b.X), 0, (a.Z - b.Z)).Magnitude;
	};
	return function (Specials, Fighters) {
		let def = function (id, fn) {
			$sp(SkillKit.def(Specials, id, 2, fn));
		};
		let HELL = C(255, 50, 90);
		def("SK_shadow_cerberus_2", function* (k) {
			$mc(k, "face");
			$mc(k, "pose", "Roar", 0.6);
			$mc(k, "fx", "Roar", { Model: k.f.Model, Color: C(255, 40, 80) });
			let c = $mc(k, "tground");
			$mc(k, "fx", "Circle", { Position: c, Radius: $mc(k, "R", 9), Color: C(200, 20, 60), Duration: 1.8, Kind: "hell" });
			if (!$t($1((yield* $cy($mc(k, "wait", 0.3)))))) {
				return;
			}
			for (let h = 1, $v1 = 3; h <= $v1; h++) {
				let a = $add($mul($mul((h / 3), math.pi), 2), $mc(k, "rand", 0, 1));
				let from = $add($add(c, $mul(Vector3.new(math.cos(a), 0, math.sin(a)), $mc(k, "R", 8))), UP);
				$mc(k, "fx", "SpectralBite", { From: from, To: $add(c, $mul(UP, 2)), Color: HELL, Big: (h === 3) });
				$mc(k, "later", 0.2, function () {
					$mc(k, "area", c, 5, ($n(((h === 3) && 0.25)) ?? 0.12), { Color: HELL });
				});
				if (!$t($1((yield* $cy($mc(k, "wait", 0.16)))))) {
					return;
				}
			}
			$mc(k, "fx", "Spikes", { Positions: $mc(k, "around", c, $mc(k, "R", 6), 10, 0), Color: C(40, 10, 30), Height: 9, Interval: 0.03, Kind: "shadow" });
			if (!$t($1((yield* $cy($mc(k, "wait", 0.25)))))) {
				return;
			}
			$mc(k, "fx", "Explosion", { Position: $add(c, UP), Radius: $mc(k, "R", 8), Color: C(200, 20, 60), Kind: "void" });
			$mc(k, "shake", c, 0.5, 50, 0.3);
			$mc(k, "area", c, 9, 0.5, { KnockbackPower: 10, Lift: 40, Color: HELL });
		});
		let GOLD = C(255, 210, 120);
		let RAGE_TIME = 7;
		let RAGE_DAMAGE = 1.3;
		let TITAN_HEIGHT = 14;
		let titanSize = function (f) {
			let s = ($n(f.ScaleNow) ?? 1);
			let base = $add((($n(f.HipHeight) ?? $div(f.Humanoid.HipHeight, s))), $mul($div(f.Root.Size.Y, s), 1.5));
			return math.clamp($div(TITAN_HEIGHT, math.max(base, 1)), 1.5, 3);
		};
		let titanScale = function (f, factor) {
			let old = ($n(f.ScaleNow) ?? 1);
			if ((factor > old)) {
				let rootY = $div(f.Root.Size.Y, old);
				let lift = $mul(($add((($n(f.HipHeight) ?? 2)), $div(rootY, 2))), ($sub(factor, old)));
				$mc(f.Model, "PivotTo", $add($mc(f.Model, "GetPivot"), $mul(UP, lift)));
			}
			$sp(Fighters.Scale(f, factor));
		};
		let titanEnd = function* (f, token) {
			while ((($eq(f.RageToken, token) && $t($1((yield* $cy(Fighters.Alive(f)))))) && (os.clock() < (($n(f.Raging) ?? 0))))) {
				(yield $W(0.25));
			}
			if (!$eq(f.RageToken, token)) {
				return;
			}
			f.RageToken = undefined;
			f.Raging = undefined;
			f.DamageDealt = $div((($n(f.DamageDealt) ?? RAGE_DAMAGE)), RAGE_DAMAGE);
			if (!$t($1((yield* $cy(Fighters.Alive(f)))))) {
				return;
			}
			$mc(f.Model, "SetAttribute", "Raging", undefined);
			let from = ($n(f.ScaleNow) ?? 1);
			for (let i = 1, $v2 = 4; i <= $v2; i++) {
				if ((!$t($1((yield* $cy(Fighters.Alive(f))))) || $t(f.RageToken))) {
					return;
				}
				(yield* $cy(Fighters.Scale(f, $add(from, $div($mul(($sub(1, from)), i), 4)))));
				(yield $W(0.08));
			}
			(yield* $cy(Fighters.Fx("Smoke", { Position: $1((yield* $cy(SkillKit.Ground(f.Root.Position)))), Color: C(200, 180, 140), Size: 6 })));
		};
		def("SK_titan_mastiff_2", function* (k) {
			let f = k.f;
			$mc(k, "face");
			$mc(k, "pose", "Roar", 0.7);
			$mc(k, "fx", "Roar", { Model: f.Model, Color: GOLD });
			$mc(k, "shake", $mc(k, "me"), 0.8, 90, 0.5);
			$mc(k, "shock", $mc(k, "feet"), 10, GOLD, true);
			if (!$t(f.RageToken)) {
				let token = [];
				f.RageToken = token;
				let from = ($n(f.ScaleNow) ?? 1), target = titanSize(f);
				$mc(k, "grab");
				for (let i = 1, $v3 = 4; i <= $v3; i++) {
					if (!$t($mc(k, "alive"))) {
						break;
					}
					titanScale(f, $add(from, $div($mul(($sub(target, from)), i), 4)));
					if (($mod(i, 2) === 0)) {
						$mc(k, "fx", "TitanGrow", { Model: f.Model });
					}
					(yield $W($mul(0.06, k.speed)));
				}
				$mc(k, "release");
				let seconds = $mc(k, "secs", RAGE_TIME);
				f.Raging = $add(os.clock(), seconds);
				f.DamageDealt = $mul((($n(f.DamageDealt) ?? 1)), RAGE_DAMAGE);
				$mc(f.Model, "SetAttribute", "Raging", true);
				(yield* $cy(Fighters.Fx("TitanAura", { Model: f.Model, Duration: seconds })));
				task.spawn(titanEnd, f, token);
			}
			if (!$t($mc(k, "alive"))) {
				return;
			}
			$mc(k, "pose", "Stomp", 0.4);
			let g = $mc(k, "feet"), c = $mc(k, "tground");
			let d = $mc(k, "dir", c);
			let len = math.max(8, $mc(k, "dist", c));
			$mc(k, "path", "Crack", g, c, { Duration: 1.4, Width: 3, Color: GOLD });
			let travel = $mc(k, "wave", "Spikes", { from: g, dir: d, length: len, width: 7, speed: 75, frac: 0.4, color: GOLD, on: function (e) {
				$mc(k, "launch", e, 25);
			} });
			if (!$t($1((yield* $cy($mc(k, "wait", $div(travel, k.speed))))))) {
				return;
			}
			$mc(k, "impact", c, 8, GOLD, true);
			$mc(k, "pillar", "Rock", c, 3, { Height: 12, Color: GOLD });
			$mc(k, "area", c, 8, 0.6, { KnockbackPower: 35, Lift: 30, Color: GOLD });
		});
		let STAR = C(255, 240, 160);
		def("SK_cosmic_dog_2", function* (k) {
			$mc(k, "face");
			$mc(k, "pose", "Float", 1.2);
			$mc(k, "fx", "EyeGlow", { Model: k.f.Model, Color: STAR, Duration: 1.2, Body: true });
			$mc(k, "orbit", "Star", { Count: 4, Radius: 3, Duration: 1, Color: STAR });
			if (!$t($1((yield* $cy($mc(k, "wait", 0.2)))))) {
				return;
			}
			let c = $mc(k, "tground");
			let around = $mc(k, "scatter", c, $mc(k, "R", 7), 4);
			let pts = [c, $get(around, 1), $get(around, 2), c, $get(around, 3), $get(around, 4), c];
			$mc(k, "rain", "Comet", pts, { fall: 0.45, gap: 0.1, radius: 5, frac: 0.2, size: 1.2, color: STAR });
			(yield* $cy($mc(k, "wait", 0.35)));
		});
		let FIRE = C(255, 130, 30);
		def("SK_phoenix_hound_2", function* (k) {
			$mc(k, "face");
			$mc(k, "pose", "Fly", 0.9);
			$mc(k, "fx", "PhoenixRise", { Model: k.f.Model, Duration: 0.9 });
			let land = $mc(k, "tground");
			$mc(k, "tele", land, 9, 0.4, FIRE);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.15)))))) {
				return;
			}
			$mc(k, "fx", "Streak", { Model: k.f.Model, Color: C(255, 110, 20), Duration: 0.7, Width: 3, Neon: true, Lifetime: 0.5, Sparks: true });
			if (!$t($1((yield* $cy($mc(k, "leap", land, 12, 0.45, { frac: 0.2, radius: 4, opts: { Color: FIRE } })))))) {
				return;
			}
			let spot = $mc(k, "feet");
			$mc(k, "pose", "Slam", 0.4);
			$mc(k, "fx", "Explosion", { Position: $add(spot, UP), Radius: $mc(k, "R", 10), Color: FIRE });
			$mc(k, "fx", "Lava", { Position: spot, Radius: $mc(k, "R", 6), Duration: 2.5 });
			$mc(k, "fx", "FireRing", { Position: spot, Radius: $mc(k, "R", 8), Duration: 1.2 });
			$mc(k, "shake", spot, 0.6, 60, 0.35);
			for (let $v4 = 0, $v5 = $arr($mc(k, "area", spot, 10, 0.65, { KnockbackPower: 45, Lift: 25, Color: FIRE })); $v4 < $v5.length; $v4++) {
				let e = $v5[$v4];
				if (e == null) break;
				$mc(k, "dot", e, 2, 0.15, "Burn");
			}
		});
		let VOID = C(170, 90, 255);
		def("SK_void_beast_2", function* (k) {
			$mc(k, "face");
			$mc(k, "pose", "Roar", 0.6);
			$mc(k, "fx", "Roar", { Model: k.f.Model, Color: VOID });
			let c = $mc(k, "tground");
			$mc(k, "fx", "Vortex", { Position: c, Radius: $mc(k, "R", 14), Duration: 1.6 });
			for (let i = 1, $v6 = 6; i <= $v6; i++) {
				if (!$t($1((yield* $cy($mc(k, "wait", 0.17)))))) {
					return;
				}
				for (let $v7 = 0, $v8 = $arr($mc(k, "enemies", c, $mc(k, "R", 18))); $v7 < $v8.length; $v7++) {
					let e = $v8[$v7];
					if (e == null) break;
					$mc(k, "pull", e, c, 30, 0.18);
				}
				if (($mod(i, 2) === 0)) {
					$mc(k, "area", c, 6, 0.06, { Color: VOID });
				}
			}
			$mc(k, "fx", "Explosion", { Position: $add(c, $mul(UP, 1.5)), Radius: $mc(k, "R", 11), Color: C(150, 70, 255), Kind: "void" });
			$mc(k, "shake", c, 0.8, 70, 0.4);
			$mc(k, "area", c, 11, 0.8, { KnockbackPower: 60, Lift: 30, Color: C(190, 130, 255) });
		});
		let VENOM = C(150, 255, 120);
		def("SK_hydra_hound_2", function* (k) {
			(yield* $cy($mc(k, "lunge", $mc(k, "R", 14))));
			if (!$t($mc(k, "alive"))) {
				return;
			}
			$mc(k, "face");
			$mc(k, "pose", "Rear", 0.8);
			$mc(k, "fx", "Roar", { Model: k.f.Model, Color: VENOM });
			let c = $mc(k, "tpos");
			let heads = math.max(1, ($n($mc(k.f.Model, "GetAttribute", "Heads")) ?? 5));
			let hits = 0;
			for (let $v9 = 0, $v10 = $arr([4, 1, 2, 3, 5]); $v9 < $v10.length; $v9++) {
				let h = $v10[$v9];
				if (h == null) break;
				let p = $add(c, Vector3.new($mc(k, "rand", (-1.5), 1.5), 0, $mc(k, "rand", (-1.5), 1.5)));
				$mc(k, "fx", "C_HydraNeck", { Model: k.f.Model, Head: $add($mod(($sub(h, 1)), heads), 1), To: p, Color: VENOM, Duration: 0.45 });
				$mc(k, "later", 0.13, function () {
					$mc(k, "fx", "BiteMark", { Position: p, Direction: $mc(k, "dir", p), Color: VENOM });
					hits = $add(hits, $len($mc(k, "area", $sp1(G(p)), 5, 0.1, { Color: VENOM })));
				});
				if (!$t($1((yield* $cy($mc(k, "wait", 0.1)))))) {
					return;
				}
			}
			if (!$t($1((yield* $cy($mc(k, "wait", 0.12)))))) {
				return;
			}
			$mc(k, "pose", "Charge", 0.4);
			for (let h = 1, $v11 = heads; h <= $v11; h++) {
				$mc(k, "fx", "C_HydraNeck", { Model: k.f.Model, Head: h, To: c, Color: VENOM, Duration: 0.5 });
			}
			if (!$t($1((yield* $cy($mc(k, "wait", 0.15)))))) {
				return;
			}
			$mc(k, "impact", $1((yield* $cy(G(c)))), 7, VENOM, true);
			hits = $add(hits, $len($mc(k, "area", $1((yield* $cy(G(c)))), 6, 0.5, { KnockbackPower: 35, Lift: 20, Color: VENOM })));
			if ((hits > 0)) {
				$mc(k, "fx", "C_Heal", { Model: k.f.Model, Color: VENOM });
				$mc(k, "heal", math.min(0.12, $mul(0.02, hits)));
			}
		});
		let GHOST = C(90, 255, 200);
		def("SK_bone_dragon_2", function* (k) {
			$mc(k, "face");
			$mc(k, "pose", "Vanish", 0.5);
			$mc(k, "fx", "C_BonePile", { Position: $mc(k, "feet"), Mode: "fall", Color: GHOST });
			let c = $mc(k, "tground");
			$mc(k, "tele", c, 7, 0.35, GHOST);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.3)))))) {
				return;
			}
			$mc(k, "fx", "C_BonePile", { Position: c, Mode: "rise", Color: GHOST });
			$mc(k, "fx", "C_BonePile", { Position: $mc(k, "feet"), Mode: "rise", Color: GHOST });
			$mc(k, "pose", "Rear", 0.7);
			$mc(k, "fx", "C_RibCage", { Position: c, Radius: $mc(k, "R", 6), Duration: 1.4 });
			for (let $v12 = 0, $v13 = $arr($mc(k, "enemies", c, $mc(k, "R", 6))); $v12 < $v13.length; $v12++) {
				let e = $v13[$v12];
				if (e == null) break;
				$mc(k, "stun", e, 1.1, "Cage", GHOST);
			}
			for (let _ = 1, $v14 = 2; _ <= $v14; _++) {
				if (!$t($1((yield* $cy($mc(k, "wait", 0.25)))))) {
					return;
				}
				$mc(k, "area", c, 6, 0.15, { Color: GHOST });
			}
			if (!$t($1((yield* $cy($mc(k, "wait", 0.25)))))) {
				return;
			}
			$mc(k, "shock", c, 10, GHOST, true);
			$mc(k, "impact", c, 7, GHOST, true);
			$mc(k, "area", c, 7, 0.7, { KnockbackPower: 25, Lift: 40, Color: GHOST });
		});
		let INK = C(255, 120, 200);
		def("SK_kraken_hound_2", function* (k) {
			$mc(k, "face");
			$mc(k, "pose", "Roar", 0.6);
			$mc(k, "fx", "Roar", { Model: k.f.Model, Color: INK });
			let c = $mc(k, "tground");
			$mc(k, "tele", c, 7, 0.3, C(120, 200, 230));
			if (!$t($1((yield* $cy($mc(k, "wait", 0.25)))))) {
				return;
			}
			$mc(k, "fx", "C_Tentacles", { Position: c, Radius: $mc(k, "R", 6), Count: 6, Duration: 1.6 });
			$mc(k, "shake", c, 0.4, 60, 0.35);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.3)))))) {
				return;
			}
			let grabbed = $mc(k, "area", c, 7, 0.3, { Color: INK });
			for (let $v15 = 0, $v16 = $arr(grabbed); $v15 < $v16.length; $v15++) {
				let e = $v16[$v15];
				if (e == null) break;
				$mc(k, "stun", e, 0.9, "Grab", INK);
				$mc(k, "launch", e, 38);
			}
			if (!$t($1((yield* $cy($mc(k, "wait", 0.45)))))) {
				return;
			}
			for (let $v17 = 0, $v18 = $arr(grabbed); $v17 < $v18.length; $v17++) {
				let e = $v18[$v17];
				if (e == null) break;
				$mc(k, "launch", e, (-90));
			}
			if (!$t($1((yield* $cy($mc(k, "wait", 0.1)))))) {
				return;
			}
			$mc(k, "impact", c, 9, INK, true);
			$mc(k, "fx", "C_Ink", { Position: c, Radius: $mc(k, "R", 8) });
			$mc(k, "area", c, 9, 0.7, { KnockbackPower: 30, Lift: 15, Color: INK });
		});
		let TIME = C(150, 210, 255);
		def("SK_chrono_hound_2", function* (k) {
			$mc(k, "face");
			$mc(k, "pose", "Howl", 0.6);
			$mc(k, "fx", "Roar", { Model: k.f.Model, Color: TIME, Howl: true });
			let c = $mc(k, "tground");
			let r = $mc(k, "R", 14);
			$mc(k, "fx", "C_TimeStop", { Position: c, Radius: r, Duration: 1.9 });
			for (let $v19 = 0, $v20 = $arr($mc(k, "enemies", c, r)); $v19 < $v20.length; $v19++) {
				let e = $v20[$v19];
				if (e == null) break;
				$mc(k, "stun", e, 1.2, "Time", TIME);
			}
			$mc(k, "fx", "C_AfterImage", { Model: k.f.Model, Duration: 1.2 });
			let stored = [];
			for (let i = 1, $v21 = 5; i <= $v21; i++) {
				if (!$t($1((yield* $cy($mc(k, "wait", 0.12)))))) {
					return;
				}
				let a = $add($mul($mul((i / 5), math.pi), 2), $mc(k, "rand", 0, 0.6));
				let d = Vector3.new(math.cos(a), 0, math.sin(a));
				$mc(k, "fx", "Slash", { Position: $add(c, $mul(UP, 2)), Direction: d, Color: TIME, Size: 6 });
				$ins(stored, d);
			}
			if (!$t($1((yield* $cy($mc(k, "wait", 0.35)))))) {
				return;
			}
			for (let $v22 = 0, $v23 = $arr(stored); $v22 < $v23.length; $v22++) {
				let d = $v23[$v22];
				if (d == null) break;
				$mc(k, "fx", "Slash", { Position: $add(c, $mul(UP, 2)), Direction: d, Color: C(235, 245, 255), Size: 9 });
			}
			$mc(k, "fx", "Explosion", { Position: $add(c, UP), Radius: $mc(k, "R", 8), Color: TIME, Kind: "void" });
			$mc(k, "shake", c, 0.6, 60, 0.3);
			$mc(k, "area", c, 8, 0.5, { KnockbackPower: 45, Lift: 25, Color: TIME, Crit: true });
		});
		let HORIZON = C(255, 160, 70);
		def("SK_singularity_pup_2", function* (k) {
			$mc(k, "face");
			$mc(k, "pose", "Float", 1.4);
			let holeModel = ($n(($a(k.aim) && k.t.Model)) ?? k.f.Model);
			$mc(k, "fx", "C_Singularity", { Model: holeModel, Duration: 1.5, Radius: $mc(k, "R", 11) });
			for (let i = 1, $v24 = 6; i <= $v24; i++) {
				if (!$t($1((yield* $cy($mc(k, "wait", 0.18)))))) {
					return;
				}
				let center = ($n(($a(k.aim) && $mc(k, "tground"))) ?? $mc(k, "feet"));
				for (let $v25 = 0, $v26 = $arr($mc(k, "enemies", center, $mc(k, "R", 20))); $v25 < $v26.length; $v25++) {
					let e = $v26[$v25];
					if (e == null) break;
					$mc(k, "pull", e, center, 34, 0.18);
				}
				if (($mod(i, 2) === 0)) {
					$mc(k, "area", center, 5, 0.06, { Color: HORIZON });
				}
			}
			let center = ($n(($a(k.aim) && $mc(k, "tground"))) ?? $mc(k, "feet"));
			$mc(k, "fx", "C_WhiteHole", { Position: center, Radius: $mc(k, "R", 9) });
			$mc(k, "shake", center, 0.7, 60, 0.35);
			$mc(k, "area", center, 9, 0.8, { KnockbackPower: 90, Lift: 40, Color: C(255, 245, 230) });
		});
		let HOLY = C(255, 225, 120);
		def("SK_seraph_hound_2", function* (k) {
			$mc(k, "face");
			$mc(k, "pose", "Float", 1.2);
			$mc(k, "fx", "EyeGlow", { Model: k.f.Model, Color: HOLY, Duration: 1.2, Body: true });
			let c = $mc(k, "tground");
			let dur = 1.2;
			$mc(k, "fx", "C_Judgement", { Position: c, Radius: $mc(k, "R", 10), Duration: dur });
			for (let i = 1, $v27 = 3; i <= $v27; i++) {
				if (!$t($1((yield* $cy($mc(k, "wait", $div(dur, 4))))))) {
					return;
				}
				$mc(k, "area", c, ((10 * ((1 - (i / 4)))) + 2), 0.12, { Color: HOLY });
			}
			if (!$t($1((yield* $cy($mc(k, "wait", $div(dur, 4))))))) {
				return;
			}
			$mc(k, "pillar", "Holy", c, 4, { Height: 30, Color: C(255, 240, 180) });
			$mc(k, "area", c, 6, 0.6, { KnockbackPower: 20, Lift: 35, Color: HOLY });
			$mc(k, "heal", 0.06);
		});
		let CRY = C(80, 245, 225);
		def("SK_crystal_golem_2", function* (k) {
			$mc(k, "face");
			$mc(k, "pose", "Slam", 0.45);
			$mc(k, "shock", $mc(k, "feet"), 10, CRY, true);
			$mc(k, "shake", $mc(k, "me"), 0.6, 70, 0.35);
			let origin = $mc(k, "feet"), c = $mc(k, "tground");
			let d = $mc(k, "dir", c);
			let pts = [];
			for (let i = 1, $v28 = math.clamp(math.floor($div($mc(k, "dist", c), 4)), 1, 14); i <= $v28; i++) {
				$ins(pts, $1((yield* $cy(G($add(origin, $mul(d, ((i * 4)))))))));
			}
			$mc(k, "fx", "Spikes", { Positions: pts, Color: CRY, Height: 4, Interval: 0.03 });
			if (!$t($1((yield* $cy($mc(k, "wait", $div(math.min(0.4, ($len(pts) * 0.03)), k.speed))))))) {
				return;
			}
			let jailed = $mc(k, "enemies", c, $mc(k, "R", 6));
			$mc(k, "area", c, 6, 0.3, { Color: CRY });
			for (let $v29 = 0, $v30 = $arr(jailed); $v29 < $v30.length; $v29++) {
				let e = $v30[$v29];
				if (e == null) break;
				$mc(k, "fx", "C_CrystalPrison", { Model: e.Model, Duration: 1.2 });
				$mc(k, "stun", e, 1, "Stone", CRY);
			}
			if (($len(jailed) === 0)) {
				$mc(k, "fx", "C_CrystalPrison", { Model: k.t.Model, Duration: 0.8 });
			}
			if (!$t($1((yield* $cy($mc(k, "wait", 0.45)))))) {
				return;
			}
			$mc(k, "pose", "Stomp", 0.4);
			$mc(k, "rain", "Crystal", [c], { fall: 0.3, radius: 8, frac: 0.7, size: 2.5, color: CRY });
			$mc(k, "later", 0.3, function () {
				$mc(k, "fx", "C_CrystalShatter", { Position: c });
			});
			(yield* $cy($mc(k, "wait", 0.3)));
		});
		let ICE = C(170, 225, 255);
		def("SK_frost_phoenix_2", function* (k) {
			$mc(k, "face");
			$mc(k, "pose", "Crouch", 0.6);
			$mc(k, "fx", "C_IceEgg", { Model: k.f.Model, Duration: 0.7 });
			$mc(k, "shield", 0.8, 0.85, "Ice", ICE);
			$mc(k, "heal", 0.1);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.45)))))) {
				return;
			}
			$mc(k, "pose", "Fly", 0.6);
			$mc(k, "fx", "C_FeatherStorm", { Position: $mc(k, "me"), Count: 10, Radius: $mc(k, "R", 10) });
			for (let $v31 = 0, $v32 = $arr($mc(k, "area", $mc(k, "feet"), 10, 0.3, { KnockbackPower: 25, Lift: 15, Color: ICE })); $v31 < $v32.length; $v31++) {
				let e = $v32[$v31];
				if (e == null) break;
				$mc(k, "freeze", e, 1);
			}
			let c = $mc(k, "tground");
			$mc(k, "shoot", "Feather", { points: $mc(k, "scatter", c, 3, 6, true), speed: 85, gap: 0.04, frac: 0.15, radius: 3, color: ICE, trail: true, on: function (e) {
				$mc(k, "slow", e, 1.5, 0.6);
			} });
			$mc(k, "later", 0.4, function () {
				$mc(k, "fx", "C_FeatherStorm", { Position: $add(c, $mul(UP, 2)), Count: 5, Radius: 4 });
			});
			(yield* $cy($mc(k, "wait", 0.3)));
		});
		let VOLT = C(255, 230, 80);
		def("SK_thunder_colossus_2", function* (k) {
			$mc(k, "face");
			$mc(k, "pose", "Rear", 0.45);
			$mc(k, "fx", "C_RodStrike", { Model: k.f.Model });
			if (!$t($1((yield* $cy($mc(k, "wait", 0.3)))))) {
				return;
			}
			let fracs = [0.25, 0.25, 0.5];
			for (let i = 1, $v33 = 3; i <= $v33; i++) {
				$mc(k, "pose", "Stomp", 0.3);
				let origin = $mc(k, "feet"), c = $mc(k, "tground");
				let d = $mc(k, "dir", c);
				let len = math.min($add($mc(k, "dist", c), 8), 60);
				let width = (8 + (i * 2));
				$mc(k, "shock", origin, 7, VOLT);
				$mc(k, "fx", "C_ThunderWall", { From: $add(origin, $mul(d, k.f.Radius)), Direction: d, Length: len, Width: $mc(k, "R", width), Duration: 0.45 });
				$mc(k, "shake", origin, 0.5, 80, 0.3);
				$mc(k, "wave", "Shock", { from: origin, dir: d, length: len, width: width, speed: 90, frac: $get(fracs, i), silent: true, color: VOLT, on: function (e) {
					if ((i === 3)) {
						$mc(k, "stun", e, 0.5, "Shock", VOLT);
					}
				} });
				if (!$t($1((yield* $cy($mc(k, "wait", 0.28)))))) {
					return;
				}
			}
		});
		let PINK = C(255, 160, 230);
		def("SK_rainbow_unicorn_2", function* (k) {
			$mc(k, "face");
			$mc(k, "pose", "Crouch", 0.3);
			let from = $mc(k, "feet");
			let to = $1((yield* $cy(G($mc(k, "clamp", $mc(k, "cap", $mc(k, "tground")))))));
			let height = math.clamp((($sub(to, from)).Magnitude * 0.45), 6, 14);
			$mc(k, "fx", "C_Rainbow", { From: from, To: to, Height: height, Duration: 1.4 });
			$mc(k, "tele", to, 8, 0.5, PINK);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.2)))))) {
				return;
			}
			$mc(k, "pose", "Dash", 0.6);
			if (!$t($1((yield* $cy($mc(k, "leap", to, height, 0.45, { frac: 0.15, radius: 4, opts: { Color: PINK } })))))) {
				return;
			}
			let spot = $mc(k, "feet");
			$mc(k, "fx", "C_Prism", { Position: spot, Radius: $mc(k, "R", 9) });
			$mc(k, "shake", spot, 0.5, 50, 0.3);
			for (let $v34 = 0, $v35 = $arr($mc(k, "area", spot, 9, 0.85, { KnockbackPower: 40, Lift: 30, Color: PINK })); $v34 < $v35.length; $v34++) {
				let e = $v35[$v34];
				if (e == null) break;
				$mc(k, "stun", e, 0.4, "Dizzy", PINK);
			}
		});
		let ONI = C(255, 60, 60);
		def("SK_demon_samurai_2", function* (k) {
			$mc(k, "face");
			$mc(k, "pose", "Roar", 0.4);
			$mc(k, "fx", "Roar", { Model: k.f.Model, Color: ONI });
			$mc(k, "fx", "C_Blades", { Model: k.f.Model, Target: k.t.Model, Duration: 1.5, Count: 4 });
			if (!$t($1((yield* $cy($mc(k, "wait", 0.25)))))) {
				return;
			}
			for (let _ = 1, $v36 = 5; _ <= $v36; _++) {
				$mc(k, "area", $mc(k, "tground"), 6, 0.09, { Color: ONI });
				if (!$t($1((yield* $cy($mc(k, "wait", 0.18)))))) {
					return;
				}
			}
			$mc(k, "pose", "Slash", 0.35);
			let c = $mc(k, "tground");
			let d = $mc(k, "dir", c);
			let right = side(d);
			$mc(k, "fx", "Slash", { Position: $add(c, $mul(UP, 2)), Direction: ($add(d, right)).Unit, Color: ONI, Size: 11 });
			$mc(k, "fx", "Slash", { Position: $add(c, $mul(UP, 2)), Direction: ($sub(d, right)).Unit, Color: ONI, Size: 11 });
			$mc(k, "impact", c, 6, ONI);
			$mc(k, "area", c, 7, 0.55, { KnockbackPower: 40, Lift: 20, Color: ONI });
		});
		let MECH = C(255, 160, 60);
		let PLASMA = C(80, 230, 255);
		def("SK_mecha_hound_2", function* (k) {
			$mc(k, "face");
			$mc(k, "pose", "Aim", 1.4);
			$mc(k, "fx", "EyeGlow", { Model: k.f.Model, Color: PLASMA, Duration: 0.4 });
			let c = $mc(k, "tground");
			let count = 8, flight = 0.75, gap = 0.06;
			$mc(k, "mark", k.t, "Reticle", $mul(1.2, k.speed), C(255, 80, 60));
			$mc(k, "fx", "C_Missiles", { Model: k.f.Model, Target: k.t.Model, Position: $mc(k, "tpos"), Count: count, Flight: $mul(flight, k.speed), Interval: $mul(gap, k.speed) });
			for (let i = 1, $v37 = count; i <= $v37; i++) {
				$mc(k, "later", $add($mul(((i - 1)), gap), flight), function () {
					$mc(k, "area", ($n(($a($mc(k, "real")) && $mc(k, "tground"))) ?? c), 4, 0.08, { Color: MECH });
				});
			}
			if (!$t($1((yield* $cy($mc(k, "wait", $add(flight, $mul(count, gap)))))))) {
				return;
			}
			$mc(k, "face");
			let to = ($n(($a($mc(k, "real")) && $mc(k, "tpos"))) ?? $add(c, UP));
			$mc(k, "fx", "C_Cannon", { Model: k.f.Model, To: to });
			$mc(k, "inLine", $mc(k, "me"), $mc(k, "dir", to), $add($mc(k, "dist", to), 4), 5, 0.36, { Color: PLASMA }, function (e) {
				$mc(k, "knock", e, $mc(k, "me"), 45, 20);
			});
		});
		let MOON = C(230, 220, 200);
		def("SK_planet_hound_2", function* (k) {
			$mc(k, "face");
			$mc(k, "pose", "Howl", 0.8);
			$mc(k, "fx", "Roar", { Model: k.f.Model, Color: C(150, 200, 255), Howl: true });
			let c = $mc(k, "tground");
			let r = $mc(k, "R", 8);
			let delay = 0.9;
			$mc(k, "fx", "C_MoonFall", { Model: k.f.Model, Position: c, Delay: $mul(delay, k.speed), Radius: r });
			$mc(k, "tele", c, 8, delay, C(255, 200, 150));
			if (!$t($1((yield* $cy($mc(k, "wait", delay)))))) {
				return;
			}
			$mc(k, "shake", c, 1, 80, 0.5);
			$mc(k, "area", c, 8, 0.75, { KnockbackPower: 55, Lift: 35, Color: MOON });
			if (!$t($1((yield* $cy($mc(k, "wait", 0.2)))))) {
				return;
			}
			$mc(k, "shock", c, 16, C(200, 220, 255), true);
			for (let $v38 = 0, $v39 = $arr($mc(k, "enemies", c, $mul(r, 2))); $v38 < $v39.length; $v38++) {
				let e = $v39[$v38];
				if (e == null) break;
				if ((flatDist(e.Root.Position, c) > r)) {
					$mc(k, "dmg", e, 0.3, { Color: MOON });
					$mc(k, "knock", e, c, 35, 15);
				}
			}
		});
		let SUN = C(255, 200, 70);
		def("SK_sun_dragon_2", function* (k) {
			$mc(k, "face");
			$mc(k, "pose", "Open", 1);
			$mc(k, "charge", 0.3, SUN);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.2)))))) {
				return;
			}
			let c = $mc(k, "tground");
			let burned = [];
			(yield* $cy($mc(k, "beam", "Sun", { length: math.clamp($add($mc(k, "dist", c), 6), 16, 44), width: 5, time: 0.8, ticks: 4, frac: 0.45, sweep: 28, color: SUN, color2: C(255, 120, 40), on: function (e) {
				if (!$t($get(burned, e))) {
					$set(burned, e, true);
					$mc(k, "dot", e, 2, 0.1, "Burn");
				}
			} })));
			if (!$t($mc(k, "alive"))) {
				return;
			}
			$mc(k, "rain", "Sun", [c], { fall: 0.35, radius: 8, frac: 0.45, size: 1.6, color: SUN });
			$mc(k, "later", 0.35, function () {
				$mc(k, "fx", "Explosion", { Position: $add(c, UP), Radius: $mc(k, "R", 9), Color: SUN });
				$mc(k, "shock", c, 11, C(255, 90, 60), true);
				$mc(k, "shake", c, 0.7, 60, 0.35);
			});
			$mc(k, "heal", 0.08);
			(yield* $cy($mc(k, "wait", 0.35)));
		});
	};
}
