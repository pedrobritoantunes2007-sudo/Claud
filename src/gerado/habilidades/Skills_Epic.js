// Gerado automaticamente de server/Services/SpecialsPacks/Skills_Epic.lua (código do jogo Roblox) por tools/lua2js — não edite à mão.
import { $t, $a, $n, $1, $M, $mv, $lst, $get, $set, $tm, $tc, $len, $cat, $eq, $add, $sub, $mul, $div, $mod, $pow, $idiv, $unm, $mc, $cy, $sp, $sp1, $W, $WS, $ins, $ins3, $arr, $pairs, $iter, $pcallG, $warnWait } from '../../rbx/lua.js';

export default function ($G, $script) {
	let require = $G["require"], Color3 = $G["Color3"], Vector3 = $G["Vector3"], ipairs = $G["ipairs"], table = $G["table"], math = $G["math"];
	let SkillKit = $sp1(require($script.Parent.Parent.SkillKit));
	let C = Color3.fromRGB;
	let UP = Vector3.new(0, 1, 0);
	let G = SkillKit.Ground;
	let turn = SkillKit.Turn;
	let side = function (d) {
		return Vector3.new((-d.Z), 0, d.X);
	};
	return function (Specials, _Fighters) {
		let def = function (id, slot, fn) {
			$sp(SkillKit.def(Specials, id, slot, fn));
		};
		def("SK_brute_bulldog_2", 2, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "approach", 3, 1)))))) {
				return;
			}
			$mc(k, "pose", "Flex", 0.9);
			$mc(k, "rage", 4, 1.25, "Rage");
			$mc(k, "pop", "FLEX!", undefined, C(255, 170, 80));
			if (!$t($1((yield* $cy($mc(k, "wait", 0.35)))))) {
				return;
			}
			let g = $mc(k, "feet");
			$mc(k, "shock", g, 9, C(255, 160, 80), true);
			$mc(k, "area", g, 9, 1, { KnockbackPower: 30, Lift: 16 });
		});
		def("SK_brute_bulldog_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Crouch", 0.35);
			$mc(k, "tele", $mc(k, "tground"), 9, 1.25, C(255, 140, 60));
			if (!$t($1((yield* $cy($mc(k, "wait", 0.35)))))) {
				return;
			}
			$mc(k, "pose", "Belly", 1);
			$mc(k, "fx", "Streak", { Model: k.f.Model, Color: C(255, 140, 50), Duration: 0.9, Width: 2.2, Neon: true, Sparks: true });
			if (!$t($1((yield* $cy($mc(k, "leap", $mc(k, "tpos"), 22, 0.85)))))) {
				return;
			}
			let g = $mc(k, "feet");
			$mc(k, "impact", g, 9, C(255, 140, 60), true);
			$mc(k, "fx", "Explosion", { Position: $add(g, UP), Radius: $mc(k, "R", 8), Color: C(255, 130, 50) });
			$mc(k, "burst", "Rocks", g, { Count: 12, Radius: 12 });
			$mc(k, "area", g, 9, 1, { KnockbackPower: 26, Lift: 32 });
			$mc(k, "zone", "Crack", g, 7, 2, 0, { color: C(255, 120, 40) });
		});
		def("SK_brute_bulldog_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "sky", "Gold", 3.2);
			$mc(k, "pose", "Flex", 0.9);
			$mc(k, "prop", "Dumbbell", { Position: $add($mc(k, "me"), $mul(UP, 9)), Path: "Hover", Time: 0.4, Hold: 0.5, Size: $mul(2.4, k.A), Color: C(220, 50, 40) });
			if (!$t($1((yield* $cy($mc(k, "wait", 0.8)))))) {
				return;
			}
			let fracs = [0.25, 0.3, 0.45];
			for (let i = 1, $v1 = 3; i <= $v1; i++) {
				let c = $mc(k, "tground");
				$mc(k, "pose", "Slam", 0.45);
				$mc(k, "prop", "Dumbbell", { Position: $add(c, $mul(UP, 1.2)), Path: "Fall", Height: 26, Time: 0.32, Hold: 0.2, Size: $mul(((2 + (i * 0.4))), k.A), Color: C(220, 50, 40), Impact: "Rock", Shake: (0.4 + (i * 0.2)) });
				if (!$t($1((yield* $cy($mc(k, "wait", 0.32)))))) {
					return;
				}
				$mc(k, "shock", c, (6 + (i * 2.5)), C(255, 190, 60), true);
				$mc(k, "pop", ($n(((i === 3) && "MAX REP!")) ?? ($cat("REP ", i))), $add(c, $mul(UP, 6)), C(255, 200, 80));
				let hits = $mc(k, "area", c, (6 + (i * 2.5)), $get(fracs, i), { KnockbackPower: (10 + (i * 8)), Lift: 20 });
				if ((i === 3)) {
					for (let $v2 = 0, $v3 = $arr(hits); $v2 < $v3.length; $v2++) {
						let e = $v3[$v2];
						if (e == null) break;
						$mc(k, "stun", e, 1.5, "Dizzy");
					}
				}
				if (!$t($1((yield* $cy($mc(k, "wait", 0.3)))))) {
					return;
				}
			}
		});
		def("SK_samurai_shiba_2", 2, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Guard", 0.5);
			$mc(k, "charge", 0.4, C(235, 240, 255));
			if (!$t($1((yield* $cy($mc(k, "wait", 0.45)))))) {
				return;
			}
			let d = $mc(k, "dir");
			let start = $mc(k, "feet");
			let through = $add($mc(k, "tpos"), $mul(d, 6));
			$mc(k, "pose", "Slash", 0.6);
			let victims = $mc(k, "inLine", start, d, $mc(k, "dist", through), 4, 0);
			if (!$t($1((yield* $cy($mc(k, "blink", through, 2, 0.03)))))) {
				return;
			}
			$mc(k, "path", "Slash", start, $1((yield* $cy(G(through)))), { Color: C(235, 240, 255) });
			$mc(k, "pop", "ZAN!", undefined, C(235, 240, 255), 0.9);
			$mc(k, "later", 0.35, function () {
				for (let $v4 = 0, $v5 = $arr(victims); $v4 < $v5.length; $v4++) {
					let e = $v5[$v4];
					if (e == null) break;
					$mc(k, "dmg", e, 1, { Color: C(255, 200, 220) });
					$mc(k, "burst", "Petals", e.Root.Position, { Count: 8, Color: C(255, 175, 205) });
				}
			});
		});
		def("SK_samurai_shiba_3", 3, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "approach", 3, 1)))))) {
				return;
			}
			$mc(k, "pose", "Spin", 1.2);
			let g = $mc(k, "feet");
			$mc(k, "ringOut", "Petal", g, 2, 9, { Count: 12, Time: 1.1, Height: 2, Swirl: 6, Color: C(255, 175, 205) });
			for (let i = 1, $v6 = 4; i <= $v6; i++) {
				if (!$t($1((yield* $cy($mc(k, "wait", 0.27)))))) {
					return;
				}
				let a = $mc(k, "rand", 0, 360);
				let d = $1((yield* $cy(turn(Vector3.new(1, 0, 0), a))));
				$mc(k, "fx", "Slash", { Position: $mc(k, "me"), Direction: d, Color: C(255, 220, 235), Size: 8, Tilt: $mc(k, "rand", (-30), 30) });
				$mc(k, "area", $mc(k, "feet"), 8, 0.25, { KnockbackPower: 8, Lift: 8, Color: C(255, 200, 220) });
			}
		});
		def("SK_samurai_shiba_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Dark", 3);
			$mc(k, "pose", "Guard", 1.2);
			$mc(k, "pop", "...", undefined, C(255, 255, 255), 0.8);
			let c = $mc(k, "tground");
			$mc(k, "zone", "Rune", c, 9, 2.2, 0, { color: C(255, 200, 220) });
			for (let i = 1, $v7 = 9; i <= $v7; i++) {
				$mc(k, "later", (0.25 + (i * 0.09)), function () {
					let a = $mc(k, "rand", 0, 180);
					let d = $sp1(turn(Vector3.new(1, 0, 0), a));
					$mc(k, "path", "Slash", $sub(c, $mul(d, 8)), $add(c, $mul(d, 8)), { Color: C(255, 230, 240), Height: $mc(k, "rand", 0.8, 3) });
					$mc(k, "area", c, 6, 0.04, { Color: C(255, 200, 220) });
				});
			}
			if (!$t($1((yield* $cy($mc(k, "wait", 1.4)))))) {
				return;
			}
			$mc(k, "pose", "Slash", 0.6);
			$mc(k, "pop", "SLASH!", $add(c, $mul(UP, 6)), C(255, 120, 160), 1.6);
			$mc(k, "burst", "Petals", c, { Count: 30, Radius: 14, Color: C(255, 175, 205) });
			$mc(k, "shake", c, 1, 70);
			$mc(k, "area", c, 10, 0.64, { KnockbackPower: 30, Lift: 26, Color: C(255, 120, 160) });
		});
		def("SK_ghost_hound_2", 2, function* (k) {
			$mc(k, "stop");
			$mc(k, "fx", "Smoke", { Position: $mc(k, "feet"), Color: C(200, 230, 255), Size: 5 });
			$mc(k, "pose", "Vanish", 0.4);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.35)))))) {
				return;
			}
			if (!$t($mc(k, "behind", 2))) {
				return;
			}
			$mc(k, "fx", "Smoke", { Position: $mc(k, "feet"), Color: C(200, 230, 255), Size: 5 });
			$mc(k, "pose", "Leap", 0.3);
			$mc(k, "fx", "Bite", { Model: k.f.Model, Head: 1 });
			$mc(k, "fx", "BiteMark", { Position: $mc(k, "tpos"), Direction: $mc(k, "dir"), Color: C(200, 230, 255) });
			$mc(k, "hit", 0.5, { Crit: true, Knockback: $add($mul($mc(k, "dir"), 30), $mul(UP, 12)), Color: C(200, 230, 255) });
		});
		def("SK_ghost_hound_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Howl", 1);
			$mc(k, "fx", "Roar", { Model: k.f.Model, Color: C(190, 220, 255), Howl: true });
			if (!$t($1((yield* $cy($mc(k, "wait", 0.4)))))) {
				return;
			}
			let pts = [];
			for (let $v8 = 0, $v9 = $arr($mc(k, "enemies", $mc(k, "tpos"), 14)); $v8 < $v9.length; $v8++) {
				let e = $v9[$v8];
				if (e == null) break;
				if (($len(pts) < 3)) {
					$ins(pts, $1((yield* $cy(G(e.Root.Position)))));
				}
			}
			while (($len(pts) < 3)) {
				$ins(pts, $1((yield* $cy(G($add($mc(k, "tpos"), Vector3.new($mc(k, "rand", (-3), 3), 0, $mc(k, "rand", (-3), 3))))))));
			}
			$mc(k, "summon", "Ghost", { points: pts, time: 0.8, gap: 0.15, frac: 0.34, radius: 4, color: C(200, 230, 255), on: function (e) {
				$mc(k, "slow", e, 2, 0.5, "Fear");
			} });
		});
		def("SK_ghost_hound_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Night", 3.2);
			$mc(k, "pose", "Summon", 1.6);
			let c = $mc(k, "tground");
			$mc(k, "zone", "Grave", c, 10, 3, 0);
			$mc(k, "summon", "Ghost", { points: $mc(k, "around", c, 3, 6, $mc(k, "rand", 0, 60), 0.5), time: 0.7, gap: 0.15, frac: 0.14, radius: 4.5, color: C(180, 215, 255), path: "Rise" });
			if (!$t($1((yield* $cy($mc(k, "wait", 1.8)))))) {
				return;
			}
			$mc(k, "pose", "Howl", 0.6);
			$mc(k, "pop", "BOO!", $add(c, $mul(UP, 6)), C(200, 230, 255), 1.8);
			$mc(k, "shock", c, 11, C(200, 230, 255));
			for (let $v10 = 0, $v11 = $arr($mc(k, "area", c, 11, 0.4, { KnockbackPower: 30, Lift: 14, Color: C(200, 230, 255) })); $v10 < $v11.length; $v10++) {
				let e = $v11[$v10];
				if (e == null) break;
				$mc(k, "stun", e, 1.2, "Fear");
				$mc(k, "force", e, "Crouch", 1.2);
			}
		});
		def("SK_toxic_hound_2", 2, function (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Spit", 0.8);
			let c = $mc(k, "tpos");
			let pts = [$mc(k, "tground"), $sp1(G($add(c, Vector3.new($mc(k, "rand", (-3), 3), 0, $mc(k, "rand", (-3), 3))))), ...$mv($sp(G($add(c, Vector3.new($mc(k, "rand", (-3), 3), 0, $mc(k, "rand", (-3), 3))))))];
			let t = $mc(k, "shoot", "Acid", { points: pts, speed: 45, arc: 5, frac: 0.2, radius: 3.5, gap: 0.15, impact: "Poison", color: C(150, 240, 70) });
			for (let $v12 = 0, $v13 = $arr(pts); $v12 < $v13.length; $v12++) {
				let p = $v13[$v12];
				if (p == null) break;
				let i = $v12 + 1;
				$mc(k, "later", $add((((i - 1)) * 0.15), ($sub(t, 0.3))), function () {
					$mc(k, "zone", "Poison", p, 3.5, 1.8, 0.13, { color: C(150, 240, 70) });
				});
			}
		});
		def("SK_toxic_hound_3", 3, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "reach", $mul($mc(k, "R", 16), 0.7), 1)))))) {
				return;
			}
			$mc(k, "face");
			$mc(k, "pose", "Inhale", 0.4);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.4)))))) {
				return;
			}
			$mc(k, "pose", "Open", 1);
			(yield* $cy($mc(k, "breath", "Poison", { length: 16, angle: 32, time: 1, ticks: 3, frac: 0.4, color: C(140, 230, 60) })));
			let c = $mc(k, "tground");
			$mc(k, "zone", "Poison", c, 7, 3, 0.6, { color: C(140, 230, 60), on: function (e) {
				$mc(k, "slow", e, 0.6, 0.6);
			} });
		});
		def("SK_toxic_hound_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Toxic", 3);
			$mc(k, "pose", "Summon", 1.6);
			let c = $mc(k, "tground");
			let pts = $mc(k, "scatter", c, 8, 6, true);
			for (let $v14 = 0, $v15 = $arr(pts); $v14 < $v15.length; $v14++) {
				let p = $v15[$v14];
				if (p == null) break;
				let i = $v14 + 1;
				$mc(k, "later", (0.2 + (i * 0.2)), function () {
					$mc(k, "tele", p, 3.5, 0.25, C(140, 230, 60));
				});
				$mc(k, "later", (0.45 + (i * 0.2)), function () {
					$mc(k, "pillar", "Poison", p, 2.5, { Height: 16, Time: 0.2, Hold: 0.7 });
					for (let $v16 = 0, $v17 = $arr($mc(k, "area", p, 4, 0.1, { Lift: 30, KnockbackPower: 4, Color: C(140, 230, 60) })); $v16 < $v17.length; $v16++) {
						let e = $v17[$v16];
						if (e == null) break;
						$mc(k, "dot", e, 2, 0.06, "Poison");
					}
				});
			}
			$mc(k, "later", 1.8, function () {
				$mc(k, "zone", "Poison", c, 10, 2.5, 0.3, { color: C(130, 240, 60), on: function (e) {
					$mc(k, "slow", e, 0.6, 0.5);
				} });
			});
			(yield* $cy($mc(k, "wait", 1.8)));
		});
		def("SK_frost_beast_2", 2, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Rear", 0.5);
			$mc(k, "orbit", "Icicle", { Count: 5, Radius: 1.6, Speed: 4, Height: 2.5, Duration: 0.5, Size: 1.2, Color: C(180, 230, 255) });
			if (!$t($1((yield* $cy($mc(k, "wait", 0.5)))))) {
				return;
			}
			$mc(k, "pose", "Spit", 0.4);
			$mc(k, "shoot", "Icicle", { from: $add($mc(k, "me"), $mul(UP, 3)), count: 5, spread: 24, speed: 70, arc: 2, frac: 0.2, radius: 3, size: 1.3, gap: 0.05, impact: "Shatter", color: C(180, 230, 255) });
		});
		def("SK_frost_beast_3", 3, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "approach", 4, 1)))))) {
				return;
			}
			$mc(k, "pose", "Slam", 0.5);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.22)))))) {
				return;
			}
			let g = $mc(k, "feet");
			$mc(k, "zone", "Ice", g, 11, 2.5, 0.4, { on: function (e) {
				$mc(k, "slow", e, 0.6, 0.6);
			} });
			$mc(k, "ringOut", "Crystal", g, 2, 11, { Count: 10, Time: 0.45, Rise: 1.5, Size: 1.3, Color: C(180, 230, 255) });
			$mc(k, "shock", g, 11, C(170, 225, 255), true);
			for (let $v18 = 0, $v19 = $arr($mc(k, "area", g, 11, 0.6, { Color: C(170, 225, 255) })); $v18 < $v19.length; $v18++) {
				let e = $v19[$v18];
				if (e == null) break;
				$mc(k, "freeze", e, 1.2);
			}
		});
		def("SK_frost_beast_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Ice", 3.2);
			$mc(k, "pose", "Howl", 1.2);
			$mc(k, "fx", "Roar", { Model: k.f.Model, Color: C(200, 240, 255), Howl: true });
			let c = $mc(k, "tground");
			$mc(k, "zone", "Snow", c, 14, 3, 0.25, { on: function (e) {
				$mc(k, "slow", e, 0.6, 0.6);
			} });
			$mc(k, "later", 0.5, function () {
				$mc(k, "rain", "Icicle", $mc(k, "scatter", c, 9, 10, true), { fall: 0.7, gap: 0.12, size: 3, frac: 0.08, radius: 4, impact: "Shatter", color: C(190, 235, 255) });
			});
			if (!$t($1((yield* $cy($mc(k, "wait", 2.4)))))) {
				return;
			}
			$mc(k, "shock", c, 12, C(220, 245, 255), true);
			$mc(k, "fx", "S_Burst", { Kind: "Shards", Position: c, Count: 20, Radius: 14, Color: C(200, 240, 255) });
			for (let $v20 = 0, $v21 = $arr($mc(k, "area", c, 12, 0.35, { Color: C(190, 235, 255) })); $v20 < $v21.length; $v20++) {
				let e = $v21[$v20];
				if (e == null) break;
				$mc(k, "freeze", e, 2);
			}
		});
		def("SK_magma_hound_2", 2, function (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Spit", 0.8);
			let c = $mc(k, "tpos");
			let pts = [$mc(k, "tground"), $sp1(G($add(c, Vector3.new($mc(k, "rand", (-3), 3), 0, $mc(k, "rand", (-3), 3))))), ...$mv($sp(G($add(c, Vector3.new($mc(k, "rand", (-3), 3), 0, $mc(k, "rand", (-3), 3))))))];
			let t = $mc(k, "shoot", "Lava", { points: pts, speed: 45, arc: 5, frac: 0.2, radius: 3.5, gap: 0.15, impact: "Fire", color: C(255, 120, 30) });
			for (let $v22 = 0, $v23 = $arr(pts); $v22 < $v23.length; $v22++) {
				let p = $v23[$v22];
				if (p == null) break;
				let i = $v22 + 1;
				$mc(k, "later", $add((((i - 1)) * 0.15), ($sub(t, 0.3))), function () {
					$mc(k, "zone", "Lava", p, 3.5, 2, 0.13);
				});
			}
		});
		def("SK_magma_hound_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Stomp", 0.6);
			let from = $mc(k, "feet");
			let to = $1((yield* $cy(G($add($mc(k, "tpos"), $mul($mc(k, "dir"), 3))))));
			$mc(k, "path", "Crack", from, to, { Duration: 1.4, Color: C(255, 110, 30) });
			let pts = $mc(k, "lineOf", $add(from, $mul($mc(k, "dir"), 3)), to, 5);
			for (let $v24 = 0, $v25 = $arr(pts); $v24 < $v25.length; $v24++) {
				let p = $v25[$v24];
				if (p == null) break;
				let i = $v24 + 1;
				$mc(k, "later", (0.25 + (i * 0.12)), function () {
					$mc(k, "pillar", "Lava", p, 2.4, { Height: 14, Time: 0.18, Hold: 0.5 });
					for (let $v26 = 0, $v27 = $arr($mc(k, "area", p, 4, 0.2, { Lift: 26, KnockbackPower: 6, Color: C(255, 120, 30) })); $v26 < $v27.length; $v26++) {
						let e = $v27[$v26];
						if (e == null) break;
						$mc(k, "dot", e, 2, 0.04, "Burn");
					}
				});
			}
			(yield* $cy($mc(k, "wait", 0.6)));
		});
		def("SK_magma_hound_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Fire", 3.2);
			$mc(k, "pose", "Summon", 1.4);
			let c = $mc(k, "tground");
			$mc(k, "tele", c, 7, 0.6, C(255, 100, 20));
			$mc(k, "prop", "Volcano", { Position: c, Path: "Rise", Depth: 10, Time: 0.6, Hold: 2, Size: $mul(1.5, k.A), Impact: "Dirt", Shake: 0.8, End: "Sink" });
			$mc(k, "later", 0.6, function () {
				$mc(k, "area", c, 7, 0.35, { Lift: 45, KnockbackPower: 10, Color: C(255, 110, 25) });
				$mc(k, "pillar", "Lava", $add(c, $mul(UP, 6)), 2.5, { Height: 22, Time: 0.25, Hold: 1.4 });
			});
			$mc(k, "later", 0.9, function () {
				$mc(k, "rain", "Lava", $mc(k, "scatter", c, 10, 10, false), { fall: 0.6, gap: 0.1, size: 1.5, frac: 0.06, radius: 4, impact: "Fire", height: 30 });
			});
			$mc(k, "later", 2, function () {
				$mc(k, "zone", "Lava", c, 9, 2, 0.3);
			});
			(yield* $cy($mc(k, "wait", 1.6)));
		});
		def("SK_mummy_dog_2", 2, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Spit", 0.5);
			let t = $mc(k, "shoot", "Bandage", { speed: 60, arc: 0, frac: 0.5, size: 1.5, impact: "Dust", radius: 3 });
			$mc(k, "later", t, function () {
				if ($t($mc(k, "real"))) {
					$mc(k, "stun", k.t, 1.4, "Wrap");
					$mc(k, "pull", k.t, $mc(k, "me"), 35, 0.3);
				}
			});
			if (!$t($1((yield* $cy($mc(k, "wait", $add(t, 0.4))))))) {
				return;
			}
			$mc(k, "pose", "Bark", 0.3);
			$mc(k, "hit", 0.5, { Color: C(240, 230, 205) });
		});
		def("SK_mummy_dog_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Summon", 1);
			let c = $mc(k, "tground");
			let cursed = [];
			$mc(k, "zone", "Sand", c, 9, 3, 0.6, { color: C(225, 195, 130), on: function (e) {
				if (!$t($get(cursed, e))) {
					$set(cursed, e, true);
					$mc(k, "curse", e, 4, 1.2);
				}
			} });
			$mc(k, "summon", "Scarab", { from: $add(c, Vector3.new(8, 0, 0)), points: $mc(k, "scatter", c, 4, 4, true), time: 0.9, gap: 0.2, frac: 0.1, radius: 3.5, path: "Run" });
			(yield* $cy($mc(k, "wait", 0.6)));
		});
		def("SK_mummy_dog_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Sand", 3.2);
			$mc(k, "pose", "Summon", 1.6);
			let d = $mc(k, "dir");
			let c = $mc(k, "tground");
			$mc(k, "prop", "Pyramid", { Position: $add(c, $mul(d, 12)), Look: $unm(d), Path: "Rise", Depth: 9, Time: 0.6, Hold: 2.4, Size: $mul(2, k.A), Impact: "Sand", End: "Sink" });
			$mc(k, "later", 0.3, function () {
				$mc(k, "prop", "Sarcophagus", { Position: $add(c, $mul(UP, 1.5)), Look: d, Path: "Rise", Depth: 4, Time: 0.4, Hold: 1.3, Size: $mul(1.4, k.A), Impact: "Sand", End: "Shatter", Color: C(255, 210, 80) });
			});
			$mc(k, "later", 0.7, function () {
				$mc(k, "stun", k.t, 2, "Wrap");
				$mc(k, "zone", "Sand", c, 7, 1.9, 0.3, { color: C(225, 195, 130) });
			});
			if (!$t($1((yield* $cy($mc(k, "wait", 2)))))) {
				return;
			}
			$mc(k, "fx", "Explosion", { Position: $add(c, UP), Radius: $mc(k, "R", 9), Color: C(255, 210, 80) });
			$mc(k, "pillar", "Holy", c, 4, { Height: 24, Time: 0.2, Hold: 0.6, Color: C(255, 220, 120) });
			$mc(k, "area", c, 9, 0.7, { KnockbackPower: 35, Lift: 30, Color: C(255, 210, 80) });
		});
		def("SK_shark_dog_2", 2, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Dive", 0.6);
			$mc(k, "burst", "Drops", $mc(k, "feet"), { Count: 8 });
			if (!$t($1((yield* $cy($mc(k, "wait", 0.5)))))) {
				return;
			}
			$mc(k, "pose", "Vanish", 0.6);
			$mc(k, "fx", "Fin", { Model: k.f.Model, Duration: 0.7 });
			let target = $mc(k, "tpos");
			$mc(k, "path", "Water", $mc(k, "feet"), $1((yield* $cy(G(target)))), { Duration: 1.2, Width: 2.5, Color: C(90, 160, 230) });
			if (!$t($1((yield* $cy($mc(k, "blink", target, 6, 0.08)))))) {
				return;
			}
			$mc(k, "pose", "Leap", 0.5);
			$mc(k, "fx", "Bite", { Model: k.f.Model, Head: 1 });
			$mc(k, "burst", "Drops", $1((yield* $cy(G(target)))), { Count: 14, Radius: 9 });
			$mc(k, "impact", $1((yield* $cy(G(target)))), 5, C(90, 160, 230));
			$mc(k, "area", $1((yield* $cy(G(target)))), 5, 1, { Lift: 42, KnockbackPower: 8, Color: C(90, 160, 230) });
			(yield* $cy($mc(k, "leap", target, 4, 0.35)));
		});
		def("SK_shark_dog_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "pose", "Vanish", 1.6);
			$mc(k, "fx", "Fin", { Model: k.f.Model, Duration: 1.4 });
			let c = $mc(k, "tground");
			$mc(k, "zone", "Water", c, 8, 2.2, 0);
			if (!$t($1((yield* $cy($mc(k, "circle", c, 7, 1.5, 1.1)))))) {
				return;
			}
			let a0 = $mc(k, "rand", 0, 360);
			for (let i = 1, $v28 = 3; i <= $v28; i++) {
				let a = math.rad($add(a0, (i * 120)));
				let p = $1((yield* $cy(G($add($mc(k, "tpos"), $mul(Vector3.new(math.cos(a), 0, math.sin(a)), 3.5))))));
				$mc(k, "tp", p);
				$mc(k, "face");
				$mc(k, "pose", "Leap", 0.3);
				$mc(k, "fx", "Bite", { Model: k.f.Model, Head: 1 });
				$mc(k, "fx", "BiteMark", { Position: $mc(k, "tpos"), Direction: $mc(k, "dir"), Color: C(220, 240, 255) });
				$mc(k, "burst", "Drops", p, { Count: 6 });
				$mc(k, "hit", 0.33, { Knockback: $add($mul($mc(k, "dir"), 10), $mul(UP, 8)), Color: C(90, 160, 230) });
				if (!$t($1((yield* $cy($mc(k, "wait", 0.22)))))) {
					return;
				}
			}
		});
		def("SK_shark_dog_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Ocean", 3);
			$mc(k, "pose", "Dive", 0.8);
			let c = $mc(k, "tground");
			let d = $mc(k, "dir");
			$mc(k, "zone", "Water", c, 11, 2.8, 0);
			$mc(k, "tele", c, 8, 0.8, C(80, 150, 230));
			$mc(k, "later", 0.8, function () {
				$mc(k, "prop", "Megalodon", { Position: $add(c, $mul(UP, 5)), Look: $unm(d), Tilt: 60, Path: "Rise", Depth: 18, Time: 0.45, Hold: 0.9, Size: $mul(1.1, k.A), Impact: "Splash", Shake: 1, End: "Sink" });
			});
			$mc(k, "later", 1.2, function () {
				$mc(k, "pop", "CHOMP!", $add(c, $mul(UP, 9)), C(220, 240, 255), 1.6);
				$mc(k, "area", c, 8, 0.6, { Lift: 48, KnockbackPower: 12, Color: C(80, 150, 230) });
			});
			$mc(k, "later", 1.8, function () {
				for (let i = 0, $v29 = 3; i <= $v29; i++) {
					let dd = $sp1(turn(d, (i * 90)));
					$mc(k, "wave", "Water", { from: c, dir: dd, length: 14, width: 10, speed: 35, frac: 0.1, color: C(80, 150, 230) });
				}
			});
			(yield* $cy($mc(k, "wait", 1.2)));
		});
		def("SK_alien_dog_2", 2, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Aim", 0.5);
			let c = $mc(k, "tground");
			$mc(k, "prop", "UFO", { Position: $add(c, $mul(UP, 14)), Path: "Hover", Time: 0.4, Hold: 1.3, Size: 1.3, Spin: 2, Color: C(120, 255, 180) });
			$mc(k, "later", 0.4, function () {
				$mc(k, "fx", "Tractor", { From: $add(c, $mul(UP, 13)), To: c, Duration: 1, Color: C(120, 255, 180) });
				$mc(k, "stun", k.t, 1.1, "Lift");
				if ($t($mc(k, "real"))) {
					$mc(k, "launch", k.t, 28);
				}
				$mc(k, "hit", 0.4, { Color: C(120, 255, 180) });
			});
			$mc(k, "later", 1.45, function () {
				$mc(k, "impact", c, 5, C(120, 255, 180));
				$mc(k, "area", c, 5, 0.6, { KnockbackPower: 12, Lift: 6, Color: C(120, 255, 180) });
			});
			(yield* $cy($mc(k, "wait", 0.5)));
		});
		def("SK_alien_dog_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Summon", 1.3);
			let c = $mc(k, "tground");
			let pts = [c];
			for (let $v30 = 0, $v31 = $arr($mc(k, "around", c, 6, 3, $mc(k, "rand", 0, 120))); $v30 < $v31.length; $v30++) {
				let p = $v31[$v30];
				if (p == null) break;
				$ins(pts, p);
			}
			for (let $v32 = 0, $v33 = $arr(pts); $v32 < $v33.length; $v32++) {
				let p = $v33[$v32];
				if (p == null) break;
				let i = $v32 + 1;
				$mc(k, "later", (((i - 1)) * 0.3), function () {
					$mc(k, "zone", "Rune", p, 4, 0.7, 0, { color: C(150, 255, 200) });
				});
				$mc(k, "later", ((((i - 1)) * 0.3) + 0.45), function () {
					$mc(k, "pillar", "Light", p, 2.5, { Height: 20, Time: 0.15, Hold: 0.4, Color: C(170, 255, 210) });
					$mc(k, "area", p, 4.5, 0.25, { Lift: 30, KnockbackPower: 4, Color: C(150, 255, 200) });
				});
			}
			(yield* $cy($mc(k, "wait", 0.8)));
		});
		def("SK_alien_dog_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Space", 3.2);
			$mc(k, "pose", "Summon", 1.8);
			let c = $mc(k, "tground");
			let sky = $add(c, $mul(UP, 26));
			$mc(k, "prop", "UFO", { Position: sky, Path: "Hover", Time: 0.6, Hold: 2.2, Size: $mul(3.2, k.A), Spin: 1, Color: C(120, 255, 170) });
			for (let i = 1, $v34 = 3; i <= $v34; i++) {
				$mc(k, "later", (0.6 + (i * 0.35)), function () {
					let p = $sp1(G($add(c, Vector3.new($mc(k, "rand", (-6), 6), 0, $mc(k, "rand", (-6), 6)))));
					$mc(k, "fx", "Tractor", { From: $sub(sky, $mul(UP, 2)), To: p, Duration: 0.45, Color: C(120, 255, 170) });
					$mc(k, "area", p, 5, 0.1, { Color: C(120, 255, 170) });
				});
			}
			$mc(k, "later", 2.1, function () {
				$mc(k, "pillar", "Plasma", c, 6, { Height: 26, Time: 0.15, Hold: 0.7, Color: C(120, 255, 170) });
				$mc(k, "fx", "Explosion", { Position: $add(c, UP), Radius: $mc(k, "R", 9), Color: C(120, 255, 170) });
				$mc(k, "area", c, 9, 0.7, { KnockbackPower: 30, Lift: 26, Color: C(120, 255, 170) });
			});
			(yield* $cy($mc(k, "wait", 1.6)));
		});
		def("SK_ninja_dog_2", 2, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Throw", 0.45);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.2)))))) {
				return;
			}
			$mc(k, "shoot", "Shuriken", { count: 5, spread: 40, speed: 80, arc: 0.5, frac: 0.24, radius: 2.5, size: 1.1, gap: 0.03 });
		});
		def("SK_ninja_dog_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "fx", "Smoke", { Position: $mc(k, "feet"), Color: C(110, 70, 170), Size: 6 });
			$mc(k, "pose", "Vanish", 0.9);
			let c = $mc(k, "tground");
			let a0 = $mc(k, "rand", 0, 360);
			for (let i = 1, $v35 = 3; i <= $v35; i++) {
				let a = math.rad($add(a0, (i * 120)));
				let from = $1((yield* $cy(G($add(c, $mul(Vector3.new(math.cos(a), 0, math.sin(a)), 10))))));
				$mc(k, "summon", "Shade", { from: from, points: [c], time: 0.45, frac: 0.3, radius: 4, color: C(110, 70, 170) });
			}
			if (!$t($1((yield* $cy($mc(k, "wait", 0.6)))))) {
				return;
			}
			$mc(k, "fx", "Smoke", { Position: c, Color: C(110, 70, 170), Size: 8 });
			if (!$t($mc(k, "behind", 2))) {
				return;
			}
			$mc(k, "pose", "Slash", 0.4);
			$mc(k, "hit", 0.1, { Knockback: $add($mul($mc(k, "dir"), 20), $mul(UP, 10)), Color: C(150, 90, 220) });
		});
		def("SK_ninja_dog_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "sky", "Night", 3);
			$mc(k, "fx", "Smoke", { Position: $mc(k, "feet"), Color: C(110, 70, 170), Size: 7 });
			$mc(k, "pose", "Vanish", 2.4);
			let c = $mc(k, "tground");
			$mc(k, "rain", "Kunai", $mc(k, "scatter", c, 5, 8, true), { fall: 0.4, gap: 0.08, size: 1.4, frac: 0.03, radius: 3, impact: "Burst", height: 25, tele: false });
			for (let i = 1, $v36 = 8; i <= $v36; i++) {
				if (!$t($1((yield* $cy($mc(k, "wait", 0.15)))))) {
					return;
				}
				let a = math.rad($add((i * 135), $mc(k, "rand", (-20), 20)));
				let p = $1((yield* $cy(G($add($mc(k, "tpos"), $mul(Vector3.new(math.cos(a), 0, math.sin(a)), 5))))));
				$mc(k, "tp", p);
				$mc(k, "path", "Slash", p, $1((yield* $cy(G($sub($mc(k, "tpos"), ($sub(p, $mc(k, "tpos")))))))), { Color: C(170, 110, 255), Height: 1.6 });
				$mc(k, "hit", 0.06, { Color: C(170, 110, 255) });
			}
			if (!$t($1((yield* $cy($mc(k, "wait", 0.3)))))) {
				return;
			}
			$mc(k, "behind", 3);
			$mc(k, "pose", "Slash", 0.6);
			let tc = $mc(k, "tground");
			$mc(k, "path", "Slash", $add(tc, Vector3.new((-6), 0, (-6))), $add(tc, Vector3.new(6, 0, 6)), { Color: C(220, 180, 255), Height: 2 });
			$mc(k, "path", "Slash", $add(tc, Vector3.new((-6), 0, 6)), $add(tc, Vector3.new(6, 0, (-6))), { Color: C(220, 180, 255), Height: 2 });
			$mc(k, "pop", "X!", $add(tc, $mul(UP, 6)), C(220, 180, 255), 1.5);
			$mc(k, "hit", 0.26, { Crit: true, Knockback: $add($mul($mc(k, "dir"), 40), $mul(UP, 20)), Color: C(220, 180, 255) });
		});
		def("SK_pirate_dog_2", 2, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Throw", 0.5);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.22)))))) {
				return;
			}
			let t = $mc(k, "shoot", "Anchor", { speed: 55, arc: 2, frac: 0.5, size: 1.4, impact: "Rock", radius: 3 });
			$mc(k, "later", t, function () {
				if ($t($mc(k, "real"))) {
					$mc(k, "path", "Trail", $mc(k, "feet"), $mc(k, "tground"), { Duration: 0.5, Width: 0.4, Color: C(120, 120, 130) });
					$mc(k, "pull", k.t, $mc(k, "me"), 35, 0.35);
					$mc(k, "stun", k.t, 0.6, "Pin");
				}
			});
			if (!$t($1((yield* $cy($mc(k, "wait", $add(t, 0.4))))))) {
				return;
			}
			$mc(k, "pose", "Headbutt", 0.4);
			$mc(k, "impact", $mc(k, "tpos"), 4, C(160, 170, 185));
			$mc(k, "hit", 0.5, { Knockback: $add($mul($mc(k, "dir"), 25), $mul(UP, 10)), Color: C(160, 170, 185) });
		});
		def("SK_pirate_dog_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Bark", 0.6);
			$mc(k, "pop", "FIRE!", undefined, C(255, 200, 80), 1);
			let c = $mc(k, "tground");
			$mc(k, "rain", "Cannonball", $mc(k, "scatter", c, 6, 6, true), { fall: 0.8, gap: 0.15, size: 1.2, frac: 0.2, radius: 4, impact: "Explode", height: 30 });
			(yield* $cy($mc(k, "wait", 0.6)));
		});
		def("SK_pirate_dog_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Abyss", 3.2);
			$mc(k, "pose", "Victory", 1);
			let c = $mc(k, "tground");
			let d = $mc(k, "dir");
			let s = side(d);
			let shipA = $sub($sub(c, $mul(s, 32)), $mul(d, 10));
			let shipB = $sub($add(c, $mul(s, 32)), $mul(d, 10));
			$mc(k, "prop", "Ship", { Position: $add(shipA, $mul(UP, 1)), To: $add(shipB, $mul(UP, 1)), Path: "Fly", Time: 2.4, Size: $mul(1.6, k.A), Bob: 0.5, Roll: 0.08 });
			for (let v = 1, $v37 = 3; v <= $v37; v++) {
				$mc(k, "later", (0.5 + (v * 0.45)), function () {
					let from = $add($mc(shipA, "Lerp", shipB, (((0.5 + (v * 0.45))) / 2.4)), $mul(UP, 3));
					$mc(k, "shoot", "Cannonball", { from: from, points: $mc(k, "scatter", c, 6, 4, (v === 2)), speed: 50, arc: 6, frac: 0.06, radius: 4, size: 1, impact: "Explode" });
				});
			}
			$mc(k, "later", 2.3, function () {
				$mc(k, "wave", "Water", { from: $sp1(G($sub(c, $mul(d, 14)))), dir: d, length: 28, width: 14, speed: 35, frac: 0.3, color: C(90, 200, 220) });
			});
			(yield* $cy($mc(k, "wait", 1.6)));
		});
		def("SK_scorpion_dog_2", 2, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "approach", 4, 1)))))) {
				return;
			}
			$mc(k, "face");
			$mc(k, "pose", "Rear", 0.6);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.3)))))) {
				return;
			}
			$mc(k, "shoot", "Needle", { from: $add($mc(k, "me"), $mul(UP, 3.5)), speed: 90, arc: 0, frac: 0.5, size: 2, color: C(160, 240, 80), impact: "Poison", radius: 3 });
			$mc(k, "dot", k.t, 3, 0.5, "Poison");
		});
		def("SK_scorpion_dog_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Dig", 0.7);
			let c = $mc(k, "tground");
			let poisoned = [];
			$mc(k, "zone", "Sand", c, 7, 2.5, 0.5, { color: C(225, 195, 130), on: function (e) {
				$mc(k, "pull", e, c, 16, 0.3);
				if (!$t($get(poisoned, e))) {
					$set(poisoned, e, true);
					$mc(k, "dot", e, 3, 0.5, "Poison");
				}
			} });
			(yield* $cy($mc(k, "wait", 0.6)));
		});
		def("SK_scorpion_dog_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Sand", 3.2);
			$mc(k, "pose", "Summon", 1.6);
			let c = $mc(k, "tground");
			let d = $mc(k, "dir");
			$mc(k, "zone", "Sand", c, 10, 3, 0.2, { color: C(225, 195, 130) });
			for (let i = 1, $v38 = 3; i <= $v38; i++) {
				$mc(k, "later", (0.4 + (((i - 1)) * 0.6)), function () {
					let base = $sub($sp1(G(($n(($a($mc(k, "real")) && $mc(k, "tground"))) ?? c))), $mul(d, 4.5));
					$mc(k, "prop", "ScorpionTail", { Position: base, Look: d, Path: "Swing", Time: 0.45, Hold: 0.1, Reach: $mul(4.5, k.A), Size: $mul(1.4, k.A), Impact: "Poison", End: "Sink", Color: C(150, 230, 70) });
				});
				$mc(k, "later", (0.85 + (((i - 1)) * 0.6)), function () {
					let p = ($n(($a($mc(k, "real")) && $mc(k, "tground"))) ?? c);
					for (let $v39 = 0, $v40 = $arr($mc(k, "area", p, 5, ($n(((i === 3) && 0.3)) ?? 0.2), { Lift: 20, KnockbackPower: 6, Color: C(150, 230, 70) })); $v39 < $v40.length; $v39++) {
						let e = $v40[$v39];
						if (e == null) break;
						$mc(k, "dot", e, 2, 0.03, "Poison");
						if ((i === 3)) {
							$mc(k, "stun", e, 1, "Dizzy");
						}
					}
				});
			}
			(yield* $cy($mc(k, "wait", 2)));
		});
		def("SK_flytrap_dog_2", 2, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Dig", 0.5);
			let c = $mc(k, "tground");
			$mc(k, "prop", "Flytrap", { Position: c, Offset: $mul(UP, 3), Look: $mc(k, "dir"), Path: "Grow", Depth: 6, Time: 0.3, Hold: 1, Size: $mul(0.9, k.A), Impact: "Leaves", End: "Sink" });
			$mc(k, "later", 0.3, function () {
				$mc(k, "stun", k.t, 1.4, "Vines");
				$mc(k, "area", c, 4, 0.6, { Color: C(110, 210, 80) });
				$mc(k, "pop", "SNAP!", $add(c, $mul(UP, 5)), C(140, 230, 90));
			});
			$mc(k, "later", 1.1, function () {
				$mc(k, "area", c, 4, 0.4, { Lift: 25, KnockbackPower: 8, Color: C(110, 210, 80) });
			});
			(yield* $cy($mc(k, "wait", 0.4)));
		});
		def("SK_flytrap_dog_3", 3, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "approach", 3, 1)))))) {
				return;
			}
			$mc(k, "pose", "Stomp", 1.1);
			let g = $mc(k, "feet");
			let d = $mc(k, "dir");
			for (let i = 1, $v41 = 4; i <= $v41; i++) {
				$mc(k, "later", (((i - 1)) * 0.25), function () {
					let dd = $sp1(turn(d, (((i - 1)) * 90)));
					$mc(k, "prop", "Tentacle", { Position: $add(g, $mul(dd, 2)), Look: dd, Path: "Swing", Time: 0.35, Hold: 0.05, Reach: 6, Size: $mul(0.9, k.A), Impact: "Leaves", Color: C(80, 180, 60), Color2: C(160, 230, 110), End: "Sink" });
				});
				$mc(k, "later", ((((i - 1)) * 0.25) + 0.35), function () {
					$mc(k, "area", g, 9, 0.25, { KnockbackPower: 16, Lift: 10, Color: C(90, 190, 70) });
				});
			}
			(yield* $cy($mc(k, "wait", 1)));
		});
		def("SK_flytrap_dog_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Toxic", 3.2);
			$mc(k, "pose", "Summon", 1.6);
			let c = $mc(k, "tground");
			$mc(k, "zone", "Flowers", c, 12, 3, 0.2, { on: function (e) {
				$mc(k, "slow", e, 0.6, 0.6);
			} });
			$mc(k, "prop", "Flytrap", { Position: c, Offset: $mul(UP, 7), Look: $mc(k, "dir"), Path: "Grow", Depth: 12, Time: 0.5, Hold: 1.7, Size: $mul(2.4, k.A), Impact: "Leaves", Shake: 0.8, End: "Sink" });
			$mc(k, "later", 0.5, function () {
				$mc(k, "stun", k.t, 1.8, "Vines");
				$mc(k, "pop", "GULP!", $add(c, $mul(UP, 12)), C(140, 230, 90), 1.5);
				$mc(k, "area", c, 6, 0.4, { Color: C(110, 220, 80) });
			});
			if (!$t($1((yield* $cy($mc(k, "wait", 2.1)))))) {
				return;
			}
			$mc(k, "burst", "Leaves", $add(c, $mul(UP, 6)), { Count: 20, Radius: 14 });
			$mc(k, "pop", "PTUI!", $add(c, $mul(UP, 10)), C(140, 230, 90), 1.2);
			$mc(k, "area", c, 7, 0.4, { Lift: 50, KnockbackPower: 20, Color: C(110, 220, 80) });
		});
		def("SK_dj_dog_2", 2, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Wiggle", 1.4);
			let c = $mc(k, "tground");
			let s = side($mc(k, "dir"));
			for (let $v42 = 0, $v43 = $arr([(-1), 1]); $v42 < $v43.length; $v42++) {
				let sgn = $v43[$v42];
				if (sgn == null) break;
				$mc(k, "prop", "Speaker", { Position: $add($add(c, $mul($mul(s, sgn), 6)), $mul(UP, 0.8)), Look: $mul($unm(s), sgn), Path: "Rise", Depth: 4, Time: 0.25, Hold: 1.3, Size: $mul(1.4, k.A), Color: C(255, 120, 220), Impact: "Notes", End: "Sink" });
			}
			for (let i = 1, $v44 = 3; i <= $v44; i++) {
				if (!$t($1((yield* $cy($mc(k, "wait", 0.4)))))) {
					return;
				}
				$mc(k, "shock", c, (5 + (i * 2)), C(255, 120, 220));
				$mc(k, "ringOut", "Note", c, 1, (5 + (i * 2)), { Count: 6, Time: 0.4, Height: 2, Color: C(255, 120, 220) });
				$mc(k, "area", c, (5 + (i * 2)), 0.333, { KnockbackPower: 18, Lift: 8, Color: C(255, 120, 220) });
			}
		});
		def("SK_dj_dog_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Wiggle", 1.6);
			let c = $mc(k, "tground");
			$mc(k, "prop", "DiscoBall", { Position: $add(c, $mul(UP, 11)), Path: "Hover", Time: 0.4, Hold: 2, Size: 1.6, Spin: 2, Color: C(255, 120, 220) });
			$mc(k, "zone", "Dance", c, 9, 2.4, 0.6);
			$mc(k, "later", 0.4, function () {
				for (let $v45 = 0, $v46 = $arr($mc(k, "area", c, 9, 0.4, { Color: C(200, 120, 255) })); $v45 < $v46.length; $v45++) {
					let e = $v46[$v45];
					if (e == null) break;
					$mc(k, "stun", e, 1.6, "Dance");
					$mc(k, "force", e, "Wiggle", 1.6);
				}
				for (let i = 1, $v47 = 3; i <= $v47; i++) {
					let p = $sp1(G($add(c, Vector3.new($mc(k, "rand", (-6), 6), 0, $mc(k, "rand", (-6), 6)))));
					$mc(k, "fx", "S_Beam", { Kind: "Rainbow", From: $add(c, $mul(UP, 10)), To: p, Width: 1.2, Duration: 1.2, Sweep: (30 * i) });
				}
			});
			(yield* $cy($mc(k, "wait", 0.5)));
		});
		def("SK_dj_dog_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Rainbow", 3.2);
			$mc(k, "pose", "Wiggle", 2.4);
			let c = $mc(k, "tground");
			for (let i = 0, $v48 = 3; i <= $v48; i++) {
				let dd = $1((yield* $cy(turn(Vector3.new(1, 0, 0), ((i * 90) + 45)))));
				$mc(k, "prop", "Speaker", { Position: $add($add(c, $mul(dd, 10)), $mul(UP, 1)), Look: $unm(dd), Path: "Rise", Depth: 5, Time: 0.3, Hold: 2.4, Size: $mul(2, k.A), Color: C(255, 100, 230), Impact: "Notes", End: "Sink" });
			}
			$mc(k, "zone", "Dance", c, 11, 2.8, 0);
			for (let b = 1, $v49 = 4; b <= $v49; b++) {
				$mc(k, "later", (0.4 + (b * 0.45)), function () {
					$mc(k, "shock", c, 11, C(255, 100, 230));
					for (let _ = 1, $v50 = 2; _ <= $v50; _++) {
						$mc(k, "pillar", "Lightning", $sp1(G($add(c, Vector3.new($mc(k, "rand", (-6), 6), 0, $mc(k, "rand", (-6), 6))))), 2.2, { Color: C(255, 140, 240) });
					}
					$mc(k, "area", c, 9, 0.15, { Color: C(255, 140, 240) });
				});
			}
			if (!$t($1((yield* $cy($mc(k, "wait", 2.4)))))) {
				return;
			}
			$mc(k, "pop", "DROP!", $add(c, $mul(UP, 8)), C(255, 100, 230), 1.8);
			$mc(k, "burst", "Confetti", c, { Count: 30, Radius: 14 });
			$mc(k, "fx", "Explosion", { Position: $add(c, UP), Radius: $mc(k, "R", 10), Color: C(255, 100, 230) });
			$mc(k, "area", c, 11, 0.4, { KnockbackPower: 30, Lift: 45, Color: C(255, 100, 230) });
		});
		def("SK_knight_dog_2", 2, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "approach", 8, 1)))))) {
				return;
			}
			$mc(k, "face");
			$mc(k, "pose", "Guard", 0.4);
			$mc(k, "shield", 1.2, 0.4, "Metal", C(150, 180, 255));
			if (!$t($1((yield* $cy($mc(k, "wait", 0.35)))))) {
				return;
			}
			$mc(k, "pose", "Headbutt", 0.4);
			let d = $mc(k, "dir");
			(yield* $cy($mc(k, "dash", $sub($mc(k, "tpos"), $mul(d, 1.5)), 0.2, { frac: 1, radius: 3, opts: { Knockback: $add($mul(d, 40), $mul(UP, 14)), Color: C(150, 180, 255) }, on: function (e) {
				$mc(k, "stun", e, 1.1, "Dizzy");
				$mc(k, "pop", "BASH!", $add(e.Root.Position, $mul(UP, 4)), C(150, 180, 255));
				$mc(k, "impact", e.Root.Position, 4, C(150, 180, 255));
			} })));
		});
		def("SK_knight_dog_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Charge", 0.7);
			$mc(k, "charge", 0.35, C(255, 230, 140));
			if (!$t($1((yield* $cy($mc(k, "wait", 0.3)))))) {
				return;
			}
			let d = $mc(k, "dir");
			$mc(k, "fx", "Streak", { Model: k.f.Model, Color: C(255, 230, 140), Duration: 0.5, Width: 1.6, Neon: true });
			(yield* $cy($mc(k, "dash", $sub($mc(k, "tpos"), $mul(d, 1)), 0.35, { frac: 0.6, radius: 3.5, opts: { Knockback: $add($mul(d, 25), $mul(UP, 10)), Color: C(255, 230, 140) } })));
			let p = $mc(k, "tground");
			$mc(k, "pillar", "Holy", p, 3, { Height: 22, Time: 0.2, Hold: 0.8 });
			$mc(k, "prop", "Lance", { Position: $add(p, $mul(UP, 2)), Path: "Fall", Height: 3, Time: 0.1, Hold: 0.9, Size: 2, Color: C(255, 230, 140), Impact: "Holy", Shake: 0.3 });
			$mc(k, "area", p, 5, 0.4, { Lift: 24, Color: C(255, 230, 140) });
		});
		def("SK_knight_dog_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Holy", 3.2);
			$mc(k, "pose", "Summon", 1.5);
			let c = $mc(k, "tground");
			$mc(k, "tele", c, 10, 1.1, C(255, 215, 90));
			$mc(k, "prop", "Sword", { Position: $add(c, $mul($mul(UP, 4.5), k.A)), Path: "Fall", Height: 50, Time: 0.9, Hold: 1.3, Size: $mul(2, k.A), Color: C(255, 215, 90), Impact: "Holy", Shake: 1, End: "Up" });
			if (!$t($1((yield* $cy($mc(k, "wait", 0.9)))))) {
				return;
			}
			$mc(k, "pillar", "Holy", c, 4, { Height: 30, Time: 0.15, Hold: 0.8 });
			$mc(k, "area", c, 10, 0.7, { KnockbackPower: 40, Lift: 30, Color: C(255, 215, 90) });
			$mc(k, "heal", 0.2);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.7)))))) {
				return;
			}
			$mc(k, "shock", c, 9, C(255, 230, 140));
			$mc(k, "area", c, 9, 0.3, { KnockbackPower: 20, Lift: 10, Color: C(255, 230, 140) });
		});
		def("SK_armadillo_dog_2", 2, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Curl", 0.3);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.28)))))) {
				return;
			}
			$mc(k, "pose", "Roll", 0.7);
			let d = $mc(k, "dir");
			(yield* $cy($mc(k, "dash", $add($mc(k, "tpos"), $mul(d, 5)), 0.45, { frac: 1, radius: 3.5, opts: { Knockback: $add($mul(d, 35), $mul(UP, 22)), Color: C(200, 170, 140) }, on: function (e) {
				$mc(k, "impact", e.Root.Position, 4, C(200, 170, 140));
			} })));
		});
		def("SK_armadillo_dog_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "pose", "Curl", 0.25);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.25)))))) {
				return;
			}
			$mc(k, "pose", "Roll", 1.8);
			let c = $mc(k, "tpos");
			let a0 = $mc(k, "rand", 0, 360);
			for (let i = 1, $v51 = 4; i <= $v51; i++) {
				let a = math.rad($add(a0, (i * 100)));
				let p = $add(c, $mul(Vector3.new(math.cos(a), 0, math.sin(a)), 7));
				if (!$t($1((yield* $cy($mc(k, "dash", p, 0.28, { frac: 0.25, radius: 3.5, opts: { Knockback: $add($mul(Vector3.new(math.cos(a), 0, math.sin(a)), 14), $mul(UP, 12)), Color: C(200, 170, 140) }, on: function (e) {
					$mc(k, "pop", "PING!", $add(e.Root.Position, $mul(UP, 4)), C(255, 230, 120), 0.8);
				} })))))) {
					return;
				}
				c = ($n(($a($mc(k, "real")) && $mc(k, "tpos"))) ?? c);
			}
		});
		def("SK_armadillo_dog_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "sky", "Dark", 3);
			$mc(k, "aura", "Stone", 2.8, C(170, 150, 130));
			$mc(k, "shield", 2.8, 0.3);
			$mc(k, "orbit", "Boulder", { Count: 4, Radius: 1.4, Speed: 9, Height: 0.4, Duration: 2.6, Size: 1.4 });
			$mc(k, "pose", "Roll", 2.8);
			let c = $mc(k, "tground");
			if (!$t($1((yield* $cy($mc(k, "circle", c, 6, 1.5, 1.8, { frac: 0.2, radius: 6, every: 1, opts: { Knockback: $mul(UP, 18), Color: C(170, 150, 130) } })))))) {
				return;
			}
			let d = $mc(k, "dir");
			(yield* $cy($mc(k, "dash", $add($mc(k, "tpos"), $mul(d, 3)), 0.3, { frac: 0.4, radius: 5, opts: { Knockback: $add($mul(d, 40), $mul(UP, 30)), Color: C(170, 150, 130) } })));
			let g = $mc(k, "feet");
			$mc(k, "impact", g, 9, C(170, 150, 130), true);
			$mc(k, "burst", "Rocks", g, { Count: 14, Radius: 12 });
			$mc(k, "area", g, 9, 0.4, { KnockbackPower: 20, Lift: 25, Color: C(170, 150, 130) });
		});
		def("SK_saber_dog_2", 2, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "approach", 8, 1)))))) {
				return;
			}
			$mc(k, "face");
			$mc(k, "pose", "Crouch", 0.3);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.3)))))) {
				return;
			}
			$mc(k, "pose", "Leap", 0.4);
			if (!$t($1((yield* $cy($mc(k, "leap", $sub($mc(k, "tpos"), $mul($mc(k, "dir"), 2)), 5, 0.35)))))) {
				return;
			}
			for (let i = 1, $v52 = 2; i <= $v52; i++) {
				$mc(k, "pose", "Slash", 0.35);
				let d = $mc(k, "dir");
				$mc(k, "fx", "Slash", { Position: $mc(k, "tpos"), Direction: $1((yield* $cy(turn(d, ($n(((i === 1) && 70)) ?? (-70)))))), Color: C(240, 70, 80), Size: 6, Tilt: ($n(((i === 1) && 40)) ?? (-40)) });
				$mc(k, "hit", 0.35, { Color: C(240, 70, 80) });
				if (!$t($1((yield* $cy($mc(k, "wait", 0.25)))))) {
					return;
				}
			}
			$mc(k, "dot", k.t, 3, 0.3, "Bleed");
		});
		def("SK_saber_dog_3", 3, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "reach", $mul($mc(k, "R", 16), 0.7), 1)))))) {
				return;
			}
			$mc(k, "face");
			$mc(k, "pose", "Roar", 0.5);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.3)))))) {
				return;
			}
			$mc(k, "pose", "Open", 0.8);
			(yield* $cy($mc(k, "breath", "Frost", { length: 16, angle: 35, time: 0.8, ticks: 3, frac: 0.5, color: C(170, 225, 255) })));
			$mc(k, "inCone", $mc(k, "me"), $mc(k, "dir"), 16, 35, 0.5, { Color: C(170, 225, 255) }, function (e) {
				$mc(k, "freeze", e, 1.5);
			});
		});
		def("SK_saber_dog_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Ice", 3.2);
			$mc(k, "pose", "Howl", 1);
			$mc(k, "fx", "Roar", { Model: k.f.Model, Color: C(200, 240, 255), Howl: true });
			let c = $mc(k, "tground");
			for (let $v53 = 0, $v54 = $arr($mc(k, "around", c, 11, 8, 0)); $v53 < $v54.length; $v53++) {
				let p = $v54[$v53];
				if (p == null) break;
				let i = $v53 + 1;
				$mc(k, "later", (0.1 * i), function () {
					$mc(k, "pillar", "Ice", p, 2, { Height: 12, Time: 0.25, Hold: 2 });
				});
			}
			if (!$t($1((yield* $cy($mc(k, "wait", 0.9)))))) {
				return;
			}
			$mc(k, "summon", "Spirit", { from: $sub($mc(k, "me"), $mul($mc(k, "dir"), 6)), points: [c], time: 0.7, frac: 0.5, radius: 6, color: C(180, 230, 255), path: "Fly" });
			if (!$t($1((yield* $cy($mc(k, "wait", 0.75)))))) {
				return;
			}
			let d = $mc(k, "dir");
			$mc(k, "fx", "Slash", { Position: $add(c, $mul(UP, 2)), Direction: $1((yield* $cy(turn(d, 45)))), Color: C(220, 245, 255), Size: 14, Tilt: 45 });
			$mc(k, "fx", "Slash", { Position: $add(c, $mul(UP, 2)), Direction: $1((yield* $cy(turn(d, (-45))))), Color: C(220, 245, 255), Size: 14, Tilt: (-45) });
			for (let $v55 = 0, $v56 = $arr($mc(k, "area", c, 10, 0.5, { KnockbackPower: 20, Lift: 20, Color: C(190, 235, 255) })); $v55 < $v56.length; $v55++) {
				let e = $v56[$v55];
				if (e == null) break;
				$mc(k, "freeze", e, 2);
			}
		});
	};
}
