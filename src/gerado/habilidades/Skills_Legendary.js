// Gerado automaticamente de server/Services/SpecialsPacks/Skills_Legendary.lua (código do jogo Roblox) por tools/lua2js — não edite à mão.
import { $t, $a, $n, $1, $M, $mv, $lst, $get, $set, $tm, $tc, $len, $cat, $eq, $add, $sub, $mul, $div, $mod, $pow, $idiv, $unm, $mc, $cy, $sp, $sp1, $W, $WS, $ins, $ins3, $arr, $pairs, $iter, $pcallG, $warnWait } from '../../rbx/lua.js';

export default function ($G, $script) {
	let require = $G["require"], Color3 = $G["Color3"], Vector3 = $G["Vector3"], math = $G["math"], table = $G["table"], ipairs = $G["ipairs"];
	let SkillKit = $sp1(require($script.Parent.Parent.SkillKit));
	let C = Color3.fromRGB;
	let UP = Vector3.new(0, 1, 0);
	let G = SkillKit.Ground;
	let turn = SkillKit.Turn;
	let YELLOW = C(255, 235, 90);
	let FIRE = C(255, 130, 40);
	let side = function (d) {
		return Vector3.new((-d.Z), 0, d.X);
	};
	return function (Specials, _Fighters) {
		let def = function (id, slot, fn) {
			$sp(SkillKit.def(Specials, id, slot, fn));
		};
		def("SK_dragon_hound_2", 2, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "reach", $mul($mc(k, "R", 18), 0.7), 1)))))) {
				return;
			}
			$mc(k, "face");
			$mc(k, "pose", "Inhale", 0.45);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.45)))))) {
				return;
			}
			$mc(k, "pose", "Open", 1.2);
			(yield* $cy($mc(k, "breath", "Fire", { length: 18, angle: 30, time: 1.2, ticks: 4, frac: 0.75, color: FIRE })));
			$mc(k, "dot", k.t, 2.5, 0.25, "Burn");
		});
		def("SK_dragon_hound_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Fly", 1.6);
			$mc(k, "fx", "PhoenixRise", { Model: k.f.Model, Duration: 0.6 });
			if (!$t($1((yield* $cy($mc(k, "rise", 14, 0.5)))))) {
				return;
			}
			let c = $mc(k, "tpos");
			let d = $mc(k, "dir", c);
			let land = $1((yield* $cy(G($add(c, $mul(d, 8))))));
			$mc(k, "tele", $1((yield* $cy(G(c)))), 6, 0.35, FIRE);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.3)))))) {
				return;
			}
			$mc(k, "fx", "Streak", { Model: k.f.Model, Color: FIRE, Duration: 0.5, Width: 2.5, Neon: true, Sparks: true });
			let start = $mc(k, "feet");
			if (!$t($1((yield* $cy($mc(k, "land", land, 0.4, { frac: 0.6, radius: 5, opts: { Knockback: $add($mul(d, 25), $mul(UP, 25)), Color: FIRE } })))))) {
				return;
			}
			$mc(k, "path", "Fire", start, land, { Duration: 2.2, Width: 3, Color: FIRE });
			$mc(k, "fx", "Explosion", { Position: $add(land, UP), Radius: $mc(k, "R", 6), Color: FIRE });
			$mc(k, "area", land, 6, 0.25, { KnockbackPower: 16, Lift: 18, Color: FIRE });
			$mc(k, "zone", "Fire", $1((yield* $cy(G(c)))), 5, 2, 0.15);
		});
		def("SK_dragon_hound_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Fire", 3.4);
			$mc(k, "pose", "Fly", 3.2);
			$mc(k, "fx", "PhoenixRise", { Model: k.f.Model, Duration: 1 });
			if (!$t($1((yield* $cy($mc(k, "rise", 18, 0.5)))))) {
				return;
			}
			let c = $mc(k, "tground");
			let pts = [];
			for (let i = 1, $v1 = 8; i <= $v1; i++) {
				let a = math.rad((i * 70));
				let r = (2 + (i * 0.9));
				$ins(pts, $1((yield* $cy(G($add(c, Vector3.new($mul(math.cos(a), r), 0, $mul(math.sin(a), r))))))));
			}
			$ins3(pts, 1, c);
			$mc(k, "rain", "Meteor", pts, { fall: 0.7, gap: 0.13, size: 2, frac: 0.07, radius: 5, impact: "Explode", height: 45 });
			if (!$t($1((yield* $cy($mc(k, "wait", 0.9)))))) {
				return;
			}
			$mc(k, "face", c);
			$mc(k, "fx", "S_Beam", { Kind: "Fire", Model: k.f.Model, From: $mc(k, "mouth"), To: c, Width: $mc(k, "R", 5), Duration: 0.8 });
			$mc(k, "later", 0.4, function () {
				$mc(k, "fx", "Explosion", { Position: $add(c, UP), Radius: $mc(k, "R", 10), Color: FIRE });
				for (let $v2 = 0, $v3 = $arr($mc(k, "area", c, 10, 0.4, { KnockbackPower: 30, Lift: 26, Color: FIRE })); $v2 < $v3.length; $v2++) {
					let e = $v3[$v2];
					if (e == null) break;
					$mc(k, "dot", e, 3, 0.1, "Burn");
				}
				$mc(k, "zone", "Lava", c, 8, 2, 0);
			});
			if (!$t($1((yield* $cy($mc(k, "wait", 0.55)))))) {
				return;
			}
			(yield* $cy($mc(k, "land", undefined, 0.35)));
		});
		def("SK_twin_fang_2", 2, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "approach", 3, 1)))))) {
				return;
			}
			let cols = [C(150, 80, 220), C(255, 245, 200)];
			for (let i = 1, $v4 = 4; i <= $v4; i++) {
				$mc(k, "face");
				$mc(k, "fx", "Bite", { Model: k.f.Model, Head: (($mod(i, 2)) + 1) });
				$mc(k, "fx", "BiteMark", { Position: $mc(k, "tpos"), Direction: $1((yield* $cy(turn($mc(k, "dir"), ($n((($mod(i, 2) === 0) && 30)) ?? (-30)))))), Color: $get(cols, (($mod(i, 2)) + 1)) });
				if ((i === 4)) {
					$mc(k, "hit", 0.25, { Crit: true, Knockback: $add($mul($mc(k, "dir"), 30), $mul(UP, 12)), Color: $get(cols, 1) });
				} else {
					$mc(k, "hit", 0.17, { Color: $get(cols, (($mod(i, 2)) + 1)) });
				}
				if (!$t($1((yield* $cy($mc(k, "wait", 0.2)))))) {
					return;
				}
			}
		});
		def("SK_twin_fang_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Summon", 1.2);
			$mc(k, "fx", "S_Orbit", { Model: k.f.Model, Motif: "Orb", Count: 2, Radius: 2, Speed: 6, Height: 2, Duration: 0.8, Size: 1.3, Colors: [C(255, 245, 200), C(80, 30, 140)], End: "Fire", Target: ($n(($a($mc(k, "real")) && k.t.Model)) ?? undefined), To: $mc(k, "tground") });
			if (!$t($1((yield* $cy($mc(k, "wait", 1.1)))))) {
				return;
			}
			let c = $mc(k, "tground");
			$mc(k, "fx", "Explosion", { Position: $add(c, $mul(UP, 2)), Radius: $mc(k, "R", 7), Color: C(150, 80, 220), Kind: "void" });
			$mc(k, "pillar", "Holy", c, 3, { Height: 18, Time: 0.15, Hold: 0.4, Color: C(255, 245, 200) });
			$mc(k, "area", c, 7, 1, { KnockbackPower: 22, Lift: 22, Color: C(200, 150, 255) });
		});
		def("SK_twin_fang_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Dark", 3.2);
			$mc(k, "pose", "Summon", 2.2);
			let c = $mc(k, "tground");
			let pts = $mc(k, "around", c, 5, 6, $mc(k, "rand", 0, 60));
			for (let $v5 = 0, $v6 = $arr(pts); $v5 < $v6.length; $v5++) {
				let p = $v6[$v5];
				if (p == null) break;
				let i = $v5 + 1;
				$mc(k, "later", (0.2 + (i * 0.25)), function () {
					let light = ($mod(i, 2) === 0);
					$mc(k, "pillar", ($n(($a(light) && "Holy")) ?? "Shadow"), p, 2.5, { Height: 22, Time: 0.15, Hold: 0.4, Color: ($n(($a(light) && C(255, 245, 200))) ?? C(90, 40, 150)) });
					$mc(k, "area", p, 4.5, 0.1, { Color: ($n(($a(light) && C(255, 245, 200))) ?? C(150, 80, 220)) });
				});
			}
			if (!$t($1((yield* $cy($mc(k, "wait", 2)))))) {
				return;
			}
			$mc(k, "prop", "Moon", { Position: $add(c, $mul(UP, 12)), Path: "Hover", Time: 0.3, Hold: 0.4, Size: 3, Color: C(40, 20, 70) });
			$mc(k, "fx", "Explosion", { Position: $add(c, UP), Radius: $mc(k, "R", 11), Color: C(200, 150, 255), Kind: "void" });
			$mc(k, "area", c, 11, 0.45, { KnockbackPower: 30, Lift: 30, Color: C(220, 180, 255) });
			$mc(k, "heal", 0.2);
		});
		def("SK_velocity_hound_2", 2, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Crouch", 0.25);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.25)))))) {
				return;
			}
			let d = $mc(k, "dir");
			$mc(k, "pose", "Dash", 0.5);
			$mc(k, "fx", "SonicBoom", { Position: $mc(k, "me"), Direction: d, Radius: $mc(k, "R", 5), Color: C(150, 230, 255) });
			$mc(k, "aura", "Haste", 0.6, C(150, 230, 255));
			(yield* $cy($mc(k, "dash", $add($mc(k, "tpos"), $mul(d, 10)), 0.28, { frac: 1, radius: 4, opts: { Knockback: $add($mul(d, 45), $mul(UP, 18)), Color: C(150, 230, 255) } })));
			$mc(k, "fx", "SonicBoom", { Position: $mc(k, "me"), Direction: d, Radius: $mc(k, "R", 7), Color: C(220, 245, 255) });
		});
		def("SK_velocity_hound_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "pose", "Dash", 1.3);
			$mc(k, "aura", "Storm", 1.4, YELLOW);
			let c = $mc(k, "tpos");
			let prev = $mc(k, "feet");
			let lines = [];
			for (let i = 1, $v7 = 5; i <= $v7; i++) {
				let a = math.rad($add((i * 144), $mc(k, "rand", (-15), 15)));
				let p = $1((yield* $cy(G($add(c, $mul(Vector3.new(math.cos(a), 0, math.sin(a)), 7))))));
				if (!$t($1((yield* $cy($mc(k, "dash", p, 0.14, { frac: 0.08, radius: 3.5, opts: { Color: YELLOW } })))))) {
					return;
				}
				$mc(k, "path", "Bolt", prev, $mc(k, "feet"), { Color: YELLOW, Width: 2 });
				$ins(lines, [prev, $mc(k, "feet")]);
				prev = $mc(k, "feet");
			}
			$mc(k, "later", 0.3, function () {
				for (let $v8 = 0, $v9 = $arr(lines); $v8 < $v9.length; $v8++) {
					let l = $v9[$v8];
					if (l == null) break;
					let seg = $sub($get(l, 2), $get(l, 1));
					$mc(k, "pillar", "Lightning", $mc($get(l, 1), "Lerp", $get(l, 2), 0.5), 1.5, { Color: YELLOW });
					$mc(k, "inLine", $get(l, 1), seg, seg.Magnitude, 5, 0.12, { Color: YELLOW });
				}
			});
		});
		def("SK_velocity_hound_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "sky", "Storm", 3.2);
			$mc(k, "pose", "Dash", 2.6);
			$mc(k, "aura", "Storm", 2.6, YELLOW);
			let c = $mc(k, "tground");
			$mc(k, "fx", "Streak", { Model: k.f.Model, Color: YELLOW, Duration: 2, Width: 1.8, Neon: true, Sparks: true });
			$mc(k, "prop", "Tornado", { Position: c, Path: "Spin", Time: 1.6, Hold: 0.4, Size: $mul(4, k.A), Spin: 12, Color: C(255, 240, 150) });
			if (!$t($1((yield* $cy($mc(k, "circle", c, 6, 3, 1.6, { frac: 0.12, radius: 5, every: 1, opts: { Knockback: $mul(UP, 12), Color: YELLOW } })))))) {
				return;
			}
			for (let _ = 1, $v10 = 3; _ <= $v10; _++) {
				$mc(k, "pillar", "Lightning", $1((yield* $cy(G($add(c, Vector3.new($mc(k, "rand", (-4), 4), 0, $mc(k, "rand", (-4), 4))))))), 2.5, { Color: YELLOW });
			}
			$mc(k, "area", c, 7, 0.2, { Color: YELLOW });
			let d = $mc(k, "dir");
			$mc(k, "fx", "SonicBoom", { Position: $mc(k, "me"), Direction: d, Radius: $mc(k, "R", 8), Color: YELLOW });
			(yield* $cy($mc(k, "dash", $add($mc(k, "tpos"), $mul(d, 14)), 0.25, { frac: 0.44, radius: 5, opts: { Knockback: $add($mul(d, 60), $mul(UP, 30)), Color: YELLOW } })));
		});
		def("SK_storm_wolf_2", 2, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "approach", 3, 1)))))) {
				return;
			}
			$mc(k, "face");
			$mc(k, "pose", "Leap", 0.3);
			$mc(k, "fx", "Bite", { Model: k.f.Model, Head: 1 });
			$mc(k, "pillar", "Lightning", $mc(k, "tground"), 1.8, { Color: YELLOW });
			$mc(k, "hit", 0.6, { Color: YELLOW });
			$mc(k, "stun", k.t, 0.6, "Shock");
			let from = $mc(k, "tpos");
			let n = 0;
			for (let $v11 = 0, $v12 = $arr($mc(k, "enemies", from, 14)); $v11 < $v12.length; $v11++) {
				let e = $v12[$v11];
				if (e == null) break;
				if ((!$eq(e, k.t) && (n < 2))) {
					n = $add(n, 1);
					$mc(k, "fx", "S_Line", { Kind: "Bolt", From: from, To: e.Root.Position, Color: YELLOW, Width: 1.5 });
					$mc(k, "dmg", e, 0.4, { Color: YELLOW });
					$mc(k, "stun", e, 0.5, "Shock");
				}
			}
			if ((n === 0)) {
				$mc(k, "hit", 0.4, { Color: YELLOW });
			}
		});
		def("SK_storm_wolf_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Howl", 1.2);
			$mc(k, "fx", "Roar", { Model: k.f.Model, Color: C(200, 230, 255), Howl: true });
			let c = $mc(k, "tground");
			$mc(k, "prop", "Tornado", { Position: c, Path: "Spin", Time: 1.5, Hold: 0.3, Size: $mul(3.4, k.A), Spin: 10, Color: C(210, 235, 255) });
			for (let i = 1, $v13 = 4; i <= $v13; i++) {
				$mc(k, "later", (0.3 * i), function () {
					$mc(k, "pillar", "Lightning", $sp1(G($add(c, Vector3.new($mc(k, "rand", (-4), 4), 0, $mc(k, "rand", (-4), 4))))), 2, { Color: YELLOW });
					for (let $v14 = 0, $v15 = $arr($mc(k, "area", c, 7, 0.22, { Color: C(210, 235, 255) })); $v14 < $v15.length; $v14++) {
						let e = $v15[$v14];
						if (e == null) break;
						$mc(k, "pull", e, c, 14, 0.25);
					}
				});
			}
			$mc(k, "later", 1.5, function () {
				$mc(k, "area", c, 8, 0.12, { KnockbackPower: 30, Lift: 30, Color: YELLOW });
			});
			(yield* $cy($mc(k, "wait", 0.6)));
		});
		def("SK_storm_wolf_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Storm", 3.2);
			$mc(k, "pose", "Howl", 1.4);
			$mc(k, "fx", "Roar", { Model: k.f.Model, Color: YELLOW, Howl: true });
			let c = $mc(k, "tground");
			$mc(k, "zone", "Storm", c, 12, 3, 0);
			let pts = [];
			for (let $v16 = 0, $v17 = $arr($mc(k, "enemies", c, 18)); $v16 < $v17.length; $v16++) {
				let e = $v17[$v16];
				if (e == null) break;
				if (($len(pts) < 4)) {
					$ins(pts, $1((yield* $cy(G(e.Root.Position)))));
				}
			}
			while (($len(pts) < 4)) {
				$ins(pts, $1((yield* $cy(G($add(c, Vector3.new($mc(k, "rand", (-3), 3), 0, $mc(k, "rand", (-3), 3))))))));
			}
			$mc(k, "summon", "Wolf", { from: $mc(k, "me"), points: pts, time: 0.8, gap: 0.2, frac: 0.18, radius: 5, color: YELLOW, path: "Run", on: function (e) {
				$mc(k, "stun", e, 0.6, "Shock");
			} });
			$mc(k, "later", 1.9, function () {
				for (let _ = 1, $v18 = 3; _ <= $v18; _++) {
					$mc(k, "pillar", "Lightning", $sp1(G($add(c, Vector3.new($mc(k, "rand", (-5), 5), 0, $mc(k, "rand", (-5), 5))))), 2.5, { Color: YELLOW });
				}
				$mc(k, "area", c, 10, 0.28, { KnockbackPower: 20, Lift: 20, Color: YELLOW });
			});
			(yield* $cy($mc(k, "wait", 1.6)));
		});
		def("SK_inferno_hound_2", 2, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "approach", 3, 1)))))) {
				return;
			}
			$mc(k, "pose", "Roar", 0.6);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.25)))))) {
				return;
			}
			let g = $mc(k, "feet");
			$mc(k, "ringOut", "Flame", g, 1, 11, { Count: 12, Time: 0.55, Height: 0.5, Size: 1.4, Color: FIRE });
			$mc(k, "fx", "FireRing", { Position: g, Radius: $mc(k, "R", 9), Duration: 1 });
			for (let $v19 = 0, $v20 = $arr($mc(k, "area", g, 10, 0.7, { KnockbackPower: 20, Lift: 12, Color: FIRE })); $v19 < $v20.length; $v19++) {
				let e = $v20[$v19];
				if (e == null) break;
				$mc(k, "dot", e, 3, 0.3, "Burn");
			}
		});
		def("SK_inferno_hound_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Stomp", 0.9);
			let from = $add($mc(k, "feet"), $mul($mc(k, "dir"), 3));
			let to = $1((yield* $cy(G($add($mc(k, "tpos"), $mul($mc(k, "dir"), 2))))));
			for (let $v21 = 0, $v22 = $arr($mc(k, "lineOf", from, to, 5)); $v21 < $v22.length; $v21++) {
				let p = $v22[$v21];
				if (p == null) break;
				let i = $v21 + 1;
				$mc(k, "later", (0.15 + (i * 0.15)), function () {
					$mc(k, "tele", p, 3, 0.15, FIRE);
				});
				$mc(k, "later", (0.3 + (i * 0.15)), function () {
					$mc(k, "pillar", "Fire", p, 2.6, { Height: 18, Time: 0.18, Hold: 0.6 });
					for (let $v23 = 0, $v24 = $arr($mc(k, "area", p, 4, 0.2, { Lift: 24, KnockbackPower: 6, Color: FIRE })); $v23 < $v24.length; $v23++) {
						let e = $v24[$v23];
						if (e == null) break;
						$mc(k, "dot", e, 1.5, 0.04, "Burn");
					}
				});
			}
			(yield* $cy($mc(k, "wait", 0.9)));
		});
		def("SK_inferno_hound_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Fire", 3.2);
			$mc(k, "pose", "Summon", 1.6);
			let c = $mc(k, "tground");
			$mc(k, "zone", "Lava", c, 12, 3, 0.3);
			$mc(k, "zone", "Crack", c, 12, 3, 0, { color: C(255, 110, 30) });
			$mc(k, "prop", "Tornado", { Position: c, Path: "Spin", Time: 2, Hold: 0.4, Size: $mul(4.5, k.A), Spin: 9, Color: C(255, 120, 40) });
			for (let i = 1, $v25 = 5; i <= $v25; i++) {
				$mc(k, "later", (0.3 * i), function () {
					for (let $v26 = 0, $v27 = $arr($mc(k, "area", c, 7, 0.08, { Color: FIRE })); $v26 < $v27.length; $v26++) {
						let e = $v27[$v26];
						if (e == null) break;
						$mc(k, "pull", e, c, 16, 0.25);
					}
				});
			}
			$mc(k, "later", 0.8, function () {
				$mc(k, "rain", "Meteor", $mc(k, "scatter", c, 9, 5, false), { fall: 0.7, gap: 0.2, size: 1.6, frac: 0.06, radius: 4.5, impact: "Explode", height: 45 });
			});
			$mc(k, "later", 2.2, function () {
				$mc(k, "fx", "Explosion", { Position: $add(c, UP), Radius: $mc(k, "R", 11), Color: FIRE });
				for (let $v28 = 0, $v29 = $arr($mc(k, "area", c, 11, 0.3, { KnockbackPower: 30, Lift: 30, Color: FIRE })); $v28 < $v29.length; $v28++) {
					let e = $v29[$v28];
					if (e == null) break;
					$mc(k, "dot", e, 3, 0.1, "Burn");
				}
			});
			(yield* $cy($mc(k, "wait", 1.6)));
		});
		def("SK_shadow_doberman_2", 2, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Shadow", 0.9);
			let from = $mc(k, "feet");
			let to = $mc(k, "tground");
			$mc(k, "path", "Trail", from, to, { Duration: 1, Width: 3, Color: C(40, 15, 60) });
			if (!$t($1((yield* $cy($mc(k, "blink", to, 6, 0.08)))))) {
				return;
			}
			$mc(k, "pose", "Leap", 0.4);
			$mc(k, "fx", "Bite", { Model: k.f.Model, Head: 1 });
			$mc(k, "pillar", "Shadow", to, 2.5, { Height: 10, Time: 0.15, Hold: 0.3 });
			$mc(k, "area", to, 4.5, 1, { Lift: 40, KnockbackPower: 6, Color: C(140, 80, 220) });
			(yield* $cy($mc(k, "leap", $add(to, $mul($mc(k, "dir"), 1)), 4, 0.35)));
		});
		def("SK_shadow_doberman_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "pose", "Roar", 0.6);
			let c = $mc(k, "tground");
			let a0 = $mc(k, "rand", 0, 360);
			for (let i = 1, $v30 = 4; i <= $v30; i++) {
				let a = math.rad($add(a0, (i * 90)));
				let from = $1((yield* $cy(G($add(c, $mul(Vector3.new(math.cos(a), 0, math.sin(a)), 12))))));
				$mc(k, "summon", "Shade", { from: from, points: [c], time: (0.55 + (i * 0.05)), frac: 0.25, radius: 4, color: C(130, 70, 200) });
			}
			$mc(k, "later", 0.85, function () {
				$mc(k, "fx", "Explosion", { Position: $add(c, UP), Radius: $mc(k, "R", 6), Color: C(130, 70, 200), Kind: "void" });
			});
			(yield* $cy($mc(k, "wait", 0.5)));
		});
		def("SK_shadow_doberman_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "sky", "Night", 3.2);
			$mc(k, "pose", "Shadow", 2.6);
			$mc(k, "zone", "Shadow", $mc(k, "tground"), 12, 3, 0);
			for (let i = 1, $v31 = 8; i <= $v31; i++) {
				if (!$t($1((yield* $cy($mc(k, "wait", 0.17)))))) {
					return;
				}
				let a = math.rad((i * 137));
				let p = $1((yield* $cy(G($add($mc(k, "tpos"), $mul(Vector3.new(math.cos(a), 0, math.sin(a)), 4))))));
				$mc(k, "tp", p);
				$mc(k, "fx", "Bite", { Model: k.f.Model, Head: 1 });
				$mc(k, "fx", "BiteMark", { Position: $mc(k, "tpos"), Direction: $mc(k, "dir"), Color: C(220, 60, 80) });
				$mc(k, "hit", 0.06, { Color: C(170, 90, 230) });
			}
			if (!$t($1((yield* $cy($mc(k, "wait", 0.25)))))) {
				return;
			}
			$mc(k, "behind", 2);
			$mc(k, "pose", "Leap", 0.5);
			$mc(k, "fx", "Explosion", { Position: $mc(k, "tpos"), Radius: $mc(k, "R", 7), Color: C(140, 80, 220), Kind: "void" });
			$mc(k, "hit", 0.26, { Crit: true, Knockback: $add($mul($mc(k, "dir"), 40), $mul(UP, 20)), Color: C(220, 60, 80) });
		});
		def("SK_celestial_dog_2", 2, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Summon", 0.9);
			let c = $mc(k, "tground");
			$mc(k, "rain", "Star", $mc(k, "scatter", c, 4, 6, true), { fall: 0.6, gap: 0.1, size: 1.4, frac: 0.18, radius: 4, impact: "Stars", height: 40, color: C(255, 240, 150) });
			(yield* $cy($mc(k, "wait", 0.5)));
		});
		def("SK_celestial_dog_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Summon", 1.4);
			$mc(k, "aura", "Holy", 1.6, C(255, 245, 200));
			let c = $mc(k, "tground");
			$mc(k, "rain", "Feather", $mc(k, "scatter", c, 7, 10, true), { fall: 0.5, gap: 0.08, size: 1.8, frac: 0.1, radius: 4, impact: "Feathers", height: 30, color: C(255, 245, 200), tele: false });
			$mc(k, "later", 1, function () {
				$mc(k, "area", c, 8, 0.4, { Color: C(255, 245, 200) });
				$mc(k, "heal", 0.1);
			});
			(yield* $cy($mc(k, "wait", 0.9)));
		});
		def("SK_celestial_dog_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Space", 3.4);
			$mc(k, "pose", "Summon", 2.6);
			let c = $mc(k, "tground");
			let stars = $mc(k, "around", c, 9, 6, 0);
			for (let $v32 = 0, $v33 = $arr(stars); $v32 < $v33.length; $v32++) {
				let p = $v33[$v32];
				if (p == null) break;
				let i = $v32 + 1;
				$mc(k, "later", (0.15 * i), function () {
					$mc(k, "prop", "Star", { Position: $add(p, $mul(UP, 12)), Path: "Hover", Time: 0.3, Hold: 1.4, Size: 1.8, Spin: 2, Color: C(220, 230, 255) });
				});
			}
			$mc(k, "later", 1.1, function () {
				for (let i = 1, $v34 = $len(stars); i <= $v34; i++) {
					let a = $add($get(stars, i), $mul(UP, 12)), b = $add($get(stars, (($mod(i, $len(stars))) + 1)), $mul(UP, 12));
					$mc(k, "fx", "S_Line", { Kind: "Slash", From: a, To: b, Color: C(200, 220, 255), Height: 0 });
				}
			});
			if (!$t($1((yield* $cy($mc(k, "wait", 1.8)))))) {
				return;
			}
			$mc(k, "summon", "Spirit", { from: $add(c, $mul(UP, 14)), points: [c], time: 0.6, frac: 0.6, radius: 7, color: C(200, 220, 255), path: "Dive" });
			$mc(k, "later", 0.6, function () {
				$mc(k, "fx", "S_Burst", { Kind: "Stars", Position: c, Count: 20, Radius: 14, Color: C(220, 230, 255) });
				$mc(k, "area", c, 10, 0.4, { KnockbackPower: 30, Lift: 25, Color: C(200, 220, 255) });
			});
		});
		def("SK_astronaut_dog_2", 2, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Aim", 0.5);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.3)))))) {
				return;
			}
			$mc(k, "pose", "Spit", 0.6);
			$mc(k, "shoot", "Rocket", { from: $add($mc(k, "me"), $mul(UP, 2)), count: 4, spread: 30, speed: 55, arc: 4, frac: 0.25, radius: 4, gap: 0.1, trail: "Smoke", impact: "Explode", size: 0.9 });
		});
		def("SK_astronaut_dog_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Summon", 1.6);
			let c = $mc(k, "tground");
			$mc(k, "zone", "Gravity", c, 9, 1.8, 0);
			let lifted = $mc(k, "enemies", c, $mc(k, "R", 9));
			for (let $v35 = 0, $v36 = $arr(lifted); $v35 < $v36.length; $v35++) {
				let e = $v36[$v35];
				if (e == null) break;
				$mc(k, "launch", e, 30);
				$mc(k, "stun", e, 1.2, "Lift");
			}
			$mc(k, "area", c, 9, 0.3, { Color: C(180, 160, 255) });
			$mc(k, "later", 1.3, function () {
				$mc(k, "shock", c, 9, C(180, 160, 255), true);
				$mc(k, "area", c, 9, 0.7, { KnockbackPower: 10, Lift: 4, Color: C(180, 160, 255) });
				$mc(k, "burst", "Rocks", c, { Count: 8 });
			});
			(yield* $cy($mc(k, "wait", 0.8)));
		});
		def("SK_astronaut_dog_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Space", 3.4);
			$mc(k, "pose", "Focus", 0.5);
			$mc(k, "prop", "Rocket", { Position: $add($mc(k, "feet"), $mul(UP, 2)), To: $add($mc(k, "feet"), $mul(UP, 40)), Path: "Fly", Time: 0.8, Size: $mul(3, k.A) });
			$mc(k, "pose", "Fly", 2);
			if (!$t($1((yield* $cy($mc(k, "rise", 30, 0.8)))))) {
				return;
			}
			let c = $mc(k, "tground");
			$mc(k, "tele", c, 11, 1, C(255, 200, 80));
			if (!$t($1((yield* $cy($mc(k, "wait", 0.6)))))) {
				return;
			}
			$mc(k, "fx", "Streak", { Model: k.f.Model, Color: C(255, 200, 80), Duration: 0.5, Width: 3, Neon: true, Sparks: true });
			if (!$t($1((yield* $cy($mc(k, "land", c, 0.4)))))) {
				return;
			}
			$mc(k, "pose", "Slam", 0.5);
			$mc(k, "fx", "Explosion", { Position: $add(c, UP), Radius: $mc(k, "R", 12), Color: C(255, 210, 120) });
			$mc(k, "fx", "S_Burst", { Kind: "Stars", Position: c, Count: 24, Radius: 16, Color: C(255, 230, 150) });
			$mc(k, "shake", c, 1.2, 80);
			$mc(k, "area", c, 12, 1, { KnockbackPower: 40, Lift: 35, Color: C(255, 210, 120) });
		});
		def("SK_yeti_dog_2", 2, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Rear", 0.6);
			$mc(k, "prop", "Snowball", { Position: $add($mc(k, "me"), $mul(UP, ((k.f.Root.Size.Y + 3)))), Path: "Hover", Time: 0.25, Hold: 0.2, Size: 3 });
			if (!$t($1((yield* $cy($mc(k, "wait", 0.45)))))) {
				return;
			}
			$mc(k, "pose", "Throw", 0.5);
			let t = $mc(k, "shoot", "Snowball", { speed: 40, arc: 8, frac: 0.8, radius: 6, size: 3, impact: "Snow" });
			$mc(k, "later", t, function () {
				for (let $v37 = 0, $v38 = $arr($mc(k, "area", ($n(($a($mc(k, "real")) && $mc(k, "tground"))) ?? $add($mc(k, "feet"), $mul($mc(k, "dir"), 20))), 6, 0.2, { Color: C(230, 245, 255) })); $v37 < $v38.length; $v37++) {
					let e = $v38[$v37];
					if (e == null) break;
					$mc(k, "slow", e, 2, 0.5);
				}
			});
		});
		def("SK_yeti_dog_3", 3, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "approach", 6, 1)))))) {
				return;
			}
			$mc(k, "pose", "Stomp", 0.8);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.3)))))) {
				return;
			}
			let g = $mc(k, "feet");
			let d = $mc(k, "dir");
			for (let i = 0, $v39 = 3; i <= $v39; i++) {
				$mc(k, "wave", "Ice", { from: g, dir: $1((yield* $cy(turn(d, (i * 90))))), length: 18, width: 6, speed: 40, frac: ($n(((i === 0) && 0.6)) ?? 0.15), color: C(180, 225, 255), on: function (e) {
					$mc(k, "launch", e, 24);
					$mc(k, "slow", e, 1.5, 0.6);
				} });
			}
			$mc(k, "shock", g, 8, C(180, 225, 255), true);
			$mc(k, "area", g, 8, 0.25, { Color: C(180, 225, 255) });
		});
		def("SK_yeti_dog_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Ice", 3.2);
			$mc(k, "pose", "Roar", 0.8);
			$mc(k, "fx", "Roar", { Model: k.f.Model, Color: C(220, 245, 255) });
			let c = $mc(k, "tground");
			$mc(k, "zone", "Snow", c, 13, 3, 0.2, { on: function (e) {
				$mc(k, "slow", e, 0.6, 0.6);
			} });
			let pts = [c];
			for (let $v40 = 0, $v41 = $arr($mc(k, "around", c, 6, 3, $mc(k, "rand", 0, 120))); $v40 < $v41.length; $v40++) {
				let p = $v41[$v40];
				if (p == null) break;
				$ins(pts, p);
			}
			$mc(k, "later", 0.5, function () {
				$mc(k, "summon", "Fist", { points: pts, time: 0.6, gap: 0.35, frac: 0.18, radius: 5, color: C(200, 235, 255), path: "Dive" });
			});
			$mc(k, "later", 2.1, function () {
				for (let $v42 = 0, $v43 = $arr($mc(k, "area", c, 9, 0.1, { Color: C(200, 235, 255) })); $v42 < $v43.length; $v42++) {
					let e = $v43[$v42];
					if (e == null) break;
					$mc(k, "freeze", e, 1.5);
				}
			});
			(yield* $cy($mc(k, "wait", 1.6)));
		});
		def("SK_werewolf_dog_2", 2, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "approach", 3, 1)))))) {
				return;
			}
			for (let i = 1, $v44 = 5; i <= $v44; i++) {
				$mc(k, "face");
				$mc(k, "pose", "Slash", 0.25);
				let d = $mc(k, "dir");
				$mc(k, "fx", "Slash", { Position: $mc(k, "tpos"), Direction: $1((yield* $cy(turn(d, ($n(((($mod(i, 2) === 0)) && 70)) ?? (-70)))))), Color: C(200, 90, 255), Size: 6, Tilt: ($n(((($mod(i, 2) === 0)) && 35)) ?? (-35)) });
				$mc(k, "hit", ($n(((i === 5) && 0.28)) ?? 0.18), { Knockback: $mul(d, (($n(((i === 5) && 30)) ?? 5))), Color: C(200, 90, 255) });
				if (!$t($1((yield* $cy($mc(k, "wait", 0.18)))))) {
					return;
				}
			}
		});
		def("SK_werewolf_dog_3", 3, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "approach", 6, 1)))))) {
				return;
			}
			$mc(k, "pose", "Howl", 1.2);
			$mc(k, "prop", "Moon", { Position: $add($mc(k, "me"), $mul(UP, 16)), Path: "Hover", Time: 0.4, Hold: 1.4, Size: 3, Color: C(235, 235, 255) });
			$mc(k, "fx", "Roar", { Model: k.f.Model, Color: C(230, 230, 255), Howl: true });
			$mc(k, "rage", 5, 1.3, "Shadow", C(140, 80, 220));
			if (!$t($1((yield* $cy($mc(k, "wait", 0.6)))))) {
				return;
			}
			let g = $mc(k, "feet");
			$mc(k, "shock", g, 12, C(200, 200, 255));
			for (let $v45 = 0, $v46 = $arr($mc(k, "area", g, 13, 0.8, { KnockbackPower: 18, Lift: 10, Color: C(200, 90, 255) })); $v45 < $v46.length; $v45++) {
				let e = $v46[$v45];
				if (e == null) break;
				$mc(k, "slow", e, 2.5, 0.5, "Fear");
			}
		});
		def("SK_werewolf_dog_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Red", 3.2);
			$mc(k, "pose", "Howl", 1);
			$mc(k, "prop", "Moon", { Position: $add($mc(k, "me"), $mul(UP, 20)), Path: "Hover", Time: 0.5, Hold: 2.2, Size: 5, Color: C(255, 70, 80) });
			$mc(k, "rage", 3, 1.2, "Rage", C(255, 70, 80));
			if (!$t($1((yield* $cy($mc(k, "wait", 0.9)))))) {
				return;
			}
			let d = $mc(k, "dir");
			for (let i = 1, $v47 = 3; i <= $v47; i++) {
				$mc(k, "pose", "Slash", 0.35);
				let c = $mc(k, "tground");
				let dir = $1((yield* $cy(turn(d, (((i - 2)) * 35)))));
				$mc(k, "fx", "Slash", { Position: $add(c, $mul(UP, 2)), Direction: dir, Color: C(255, 70, 80), Size: 16, Tilt: (((i - 2)) * 30) });
				$mc(k, "path", "Crack", $sub(c, $mul(dir, 9)), $add(c, $mul(dir, 9)), { Duration: 1.6, Color: C(255, 60, 70) });
				$mc(k, "inLine", $sub(c, $mul(dir, 9)), dir, 18, 5, 0.27, { Knockback: $add($mul(dir, 20), $mul(UP, 12)), Color: C(255, 70, 80) });
				if (!$t($1((yield* $cy($mc(k, "wait", 0.35)))))) {
					return;
				}
			}
		});
		def("SK_octopus_dog_2", 2, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "reach", $mul($mc(k, "R", 15), 0.7), 1)))))) {
				return;
			}
			$mc(k, "face");
			$mc(k, "pose", "Spit", 0.6);
			(yield* $cy($mc(k, "breath", "Ink", { length: 15, angle: 30, time: 0.6, ticks: 2, frac: 0.4 })));
			let c = $mc(k, "tground");
			$mc(k, "zone", "Ink", c, 7, 2.5, 0.6, { on: function (e) {
				$mc(k, "slow", e, 0.6, 0.5, "Ink");
			} });
		});
		def("SK_octopus_dog_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Summon", 1.2);
			let c = $mc(k, "tground");
			for (let i = 1, $v48 = 4; i <= $v48; i++) {
				$mc(k, "later", (((i - 1)) * 0.22), function () {
					let dd = $sp1(turn(Vector3.new(1, 0, 0), ((i * 90) + 45)));
					let base = $sub(c, $mul(dd, 5));
					$mc(k, "prop", "Tentacle", { Position: base, Look: dd, Path: "Swing", Time: 0.4, Hold: 0.1, Reach: 5, Size: $mul(1.1, k.A), Impact: "Splash", Color: C(170, 90, 200), Color2: C(230, 170, 240), End: "Sink" });
				});
				$mc(k, "later", ((((i - 1)) * 0.22) + 0.4), function () {
					$mc(k, "area", c, 5, 0.25, { Lift: 18, KnockbackPower: 8, Color: C(170, 90, 200) });
				});
			}
			(yield* $cy($mc(k, "wait", 0.8)));
		});
		def("SK_octopus_dog_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Abyss", 3.2);
			$mc(k, "pose", "Summon", 2);
			let c = $mc(k, "tground");
			$mc(k, "zone", "Water", c, 12, 3, 0.25, { on: function (e) {
				$mc(k, "pull", e, c, 18, 0.3);
			} });
			$mc(k, "summon", "Tentacle", { points: $mc(k, "around", c, 6, 6, $mc(k, "rand", 0, 60)), time: 0.5, gap: 0.2, frac: 0.08, radius: 5, color: C(90, 60, 180), path: "Rise" });
			$mc(k, "later", 2, function () {
				$mc(k, "wave", "Water", { from: $sp1(G($sub(c, $mul($mc(k, "dir"), 12)))), dir: $mc(k, "dir"), length: 24, width: 14, speed: 32, frac: 0.35, color: C(60, 50, 140) });
			});
			(yield* $cy($mc(k, "wait", 1.6)));
		});
		def("SK_tank_dog_2", 2, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Aim", 0.5);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.4)))))) {
				return;
			}
			$mc(k, "pose", "Spit", 0.4);
			$mc(k, "shake", $mc(k, "me"), 0.3, 30);
			$mc(k, "shoot", "Shell", { from: $mc(k, "mouth"), speed: 90, arc: 1, frac: 1, radius: 5, size: 1.5, trail: "Smoke", impact: "Explode" });
		});
		def("SK_tank_dog_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Aim", 1);
			let c = $mc(k, "tground");
			$mc(k, "mark", k.t, "Reticle", 1);
			$mc(k, "rain", "Shell", $mc(k, "scatter", c, 6, 6, true), { fall: 0.9, gap: 0.12, size: 1.2, frac: 0.2, radius: 4.5, impact: "Explode", height: 45 });
			(yield* $cy($mc(k, "wait", 0.7)));
		});
		def("SK_tank_dog_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Dark", 3.2);
			$mc(k, "pose", "Bark", 0.6);
			$mc(k, "pop", "AIR STRIKE!", undefined, C(255, 200, 80), 1.2);
			let c = $mc(k, "tground");
			let d = $mc(k, "dir");
			let s = side(d);
			for (let lane = (-1), $v49 = 1; lane <= $v49; lane++) {
				let pts = $mc(k, "lineOf", $add($sub(c, $mul(d, 8)), $mul($mul(s, lane), 5)), $add($add(c, $mul(d, 8)), $mul($mul(s, lane), 5)), 4);
				$mc(k, "later", (0.3 + (((lane + 1)) * 0.35)), function () {
					$mc(k, "summon", "Plane", { from: $sub(c, $mul(d, 60)), points: pts, time: 0.9, gap: 0.12, frac: 0.07, radius: 5, size: 1.2 });
				});
			}
			$mc(k, "later", 2.4, function () {
				$mc(k, "fx", "Explosion", { Position: $add(c, UP), Radius: $mc(k, "R", 10), Color: C(255, 140, 50) });
				$mc(k, "area", c, 10, 0.3, { KnockbackPower: 30, Lift: 26, Color: C(255, 140, 50) });
			});
			(yield* $cy($mc(k, "wait", 1.4)));
		});
		def("SK_wizard_dog_2", 2, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Summon", 1.1);
			let cols = [C(255, 120, 40), C(150, 220, 255), C(255, 235, 90)];
			$mc(k, "fx", "S_Orbit", { Model: k.f.Model, Motif: "ArcaneOrb", Count: 3, Radius: 2.2, Speed: 5, Height: 2.5, Duration: 0.8, Size: 1.2, Colors: cols, End: "Fire", Target: ($n(($a($mc(k, "real")) && k.t.Model)) ?? undefined), To: $mc(k, "tground") });
			$mc(k, "later", 1.05, function () {
				$mc(k, "hit", 0.3, { Color: $get(cols, 1) });
				$mc(k, "dot", k.t, 2, 0.1, "Burn");
			});
			$mc(k, "later", 1.13, function () {
				$mc(k, "hit", 0.25, { Color: $get(cols, 2) });
				$mc(k, "slow", k.t, 2, 0.6);
			});
			$mc(k, "later", 1.21, function () {
				$mc(k, "hit", 0.25, { Color: $get(cols, 3) });
				$mc(k, "stun", k.t, 0.6, "Shock");
			});
			(yield* $cy($mc(k, "wait", 0.9)));
		});
		def("SK_wizard_dog_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Summon", 1.6);
			let c = $mc(k, "tground");
			$mc(k, "zone", "Rune", c, 9, 1.8, 0, { color: C(200, 140, 255) });
			let kinds = ["Fire", "Ice", "Lightning"];
			for (let $v50 = 0, $v51 = $arr($mc(k, "around", c, 6, 3, $mc(k, "rand", 0, 120))); $v50 < $v51.length; $v50++) {
				let p = $v51[$v50];
				if (p == null) break;
				let i = $v50 + 1;
				$mc(k, "later", (0.3 + (i * 0.25)), function () {
					$mc(k, "pillar", $get(kinds, i), p, 2.6, { Height: 20, Time: 0.2, Hold: 0.8 });
					$mc(k, "area", p, 4.5, 0.12, { Color: C(220, 160, 255) });
				});
			}
			$mc(k, "later", 1.5, function () {
				$mc(k, "fx", "Explosion", { Position: $add(c, UP), Radius: $mc(k, "R", 8), Color: C(200, 140, 255) });
				for (let $v52 = 0, $v53 = $arr($mc(k, "area", c, 8, 0.64, { KnockbackPower: 25, Lift: 25, Color: C(220, 160, 255) })); $v52 < $v53.length; $v52++) {
					let e = $v53[$v52];
					if (e == null) break;
					$mc(k, "dot", e, 2, 0.05, "Burn");
					$mc(k, "slow", e, 2, 0.6);
				}
			});
			(yield* $cy($mc(k, "wait", 1)));
		});
		def("SK_wizard_dog_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Space", 3.4);
			$mc(k, "pose", "Summon", 2.8);
			let c = $mc(k, "tground");
			$mc(k, "zone", "Rune", c, 13, 3.2, 0, { color: C(190, 130, 255) });
			$mc(k, "later", 0.4, function () {
				$mc(k, "rain", "Meteor", [c, $sp1(G($add(c, Vector3.new(5, 0, 3)))), ...$mv($sp(G($add(c, Vector3.new((-4), 0, (-4))))))], { fall: 0.8, gap: 0.25, size: 2.4, frac: 0.12, radius: 6, impact: "Explode", height: 50 });
			});
			$mc(k, "later", 1.2, function () {
				$mc(k, "zone", "Snow", c, 10, 1.6, 0.15, { on: function (e) {
					$mc(k, "slow", e, 0.6, 0.5);
				} });
			});
			for (let i = 1, $v54 = 4; i <= $v54; i++) {
				$mc(k, "later", (1.4 + (i * 0.25)), function () {
					$mc(k, "pillar", "Lightning", $sp1(G($add(c, Vector3.new($mc(k, "rand", (-5), 5), 0, $mc(k, "rand", (-5), 5))))), 2.5, { Color: YELLOW });
					$mc(k, "area", c, 9, 0.05, { Color: YELLOW });
				});
			}
			$mc(k, "later", 2.7, function () {
				$mc(k, "fx", "Explosion", { Position: $add(c, UP), Radius: $mc(k, "R", 12), Color: C(200, 140, 255) });
				$mc(k, "area", c, 12, 0.3, { KnockbackPower: 35, Lift: 35, Color: C(220, 160, 255) });
			});
			(yield* $cy($mc(k, "wait", 1.6)));
		});
	};
}
