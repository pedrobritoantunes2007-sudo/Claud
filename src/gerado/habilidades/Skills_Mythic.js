// Gerado automaticamente de server/Services/SpecialsPacks/Skills_Mythic.lua (código do jogo Roblox) por tools/lua2js — não edite à mão.
import { $t, $a, $n, $1, $M, $mv, $lst, $get, $set, $tm, $tc, $len, $cat, $eq, $add, $sub, $mul, $div, $mod, $pow, $idiv, $unm, $mc, $cy, $sp, $sp1, $W, $WS, $ins, $ins3, $arr, $pairs, $iter, $pcallG, $warnWait } from '../../rbx/lua.js';

export default function ($G, $script) {
	let require = $G["require"], Color3 = $G["Color3"], Vector3 = $G["Vector3"], ipairs = $G["ipairs"], table = $G["table"], math = $G["math"];
	let SkillKit = $sp1(require($script.Parent.Parent.SkillKit));
	let C = Color3.fromRGB;
	let UP = Vector3.new(0, 1, 0);
	let G = SkillKit.Ground;
	let turn = SkillKit.Turn;
	let YELLOW = C(255, 235, 90);
	let GOLD = C(255, 210, 90);
	let side = function (d) {
		return Vector3.new((-d.Z), 0, d.X);
	};
	return function (Specials, _Fighters) {
		let def = function (id, slot, fn) {
			$sp(SkillKit.def(Specials, id, slot, fn));
		};
		let huntPoints = function (k, center, n, radius) {
			let pts = [];
			for (let $v1 = 0, $v2 = $arr($mc(k, "enemies", center, ($n(radius) ?? 16))); $v1 < $v2.length; $v1++) {
				let e = $v2[$v1];
				if (e == null) break;
				if (($len(pts) < n)) {
					$ins(pts, $sp1(G(e.Root.Position)));
				}
			}
			while (($len(pts) < n)) {
				$ins(pts, $sp1(G($add(center, Vector3.new($mc(k, "rand", (-3), 3), 0, $mc(k, "rand", (-3), 3))))));
			}
			return pts;
		};
		def("SK_shadow_cerberus_3", 3, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "approach", 4, 1)))))) {
				return;
			}
			$mc(k, "face");
			$mc(k, "pose", "Roar", 0.4);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.35)))))) {
				return;
			}
			$mc(k, "pose", "Open", 1.3);
			let d = $mc(k, "dir");
			for (let h = 1, $v3 = 3; h <= $v3; h++) {
				$mc(k, "fx", "S_Cone", { Kind: "Fire", Model: k.f.Model, Head: h, Length: $mc(k, "R", 15), Angle: 24, Duration: 1.2, Color: C(255, 80, 60) });
			}
			let burned = [];
			for (let i = 1, $v4 = 4; i <= $v4; i++) {
				if (!$t($1((yield* $cy($mc(k, "wait", 0.3)))))) {
					return;
				}
				for (let $v5 = 0, $v6 = $arr([(-40), 0, 40]); $v5 < $v6.length; $v5++) {
					let ang = $v6[$v5];
					if (ang == null) break;
					$mc(k, "inCone", $mc(k, "me"), $1((yield* $cy(turn(d, $add(ang, (((i - 2.5)) * 8)))))), 15, 22, ($n(((ang === 0) && 0.15)) ?? 0.06), { Color: C(255, 80, 60) }, function (e) {
						if (!$t($get(burned, e))) {
							$set(burned, e, true);
							$mc(k, "dot", e, 3, 0.25, "Burn");
						}
					});
				}
			}
		});
		def("SK_shadow_cerberus_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Red", 3.4);
			$mc(k, "pose", "Howl", 1.4);
			$mc(k, "fx", "Roar", { Model: k.f.Model, Color: C(255, 70, 50), Howl: true });
			let c = $mc(k, "tground");
			$mc(k, "zone", "Shadow", c, 12, 3.2, 0);
			$mc(k, "zone", "Lava", c, 6, 3.2, 0.1);
			$mc(k, "later", 0.5, function () {
				$mc(k, "summon", "Hound", { from: $mc(k, "me"), points: huntPoints(k, c, 3, 18), time: 0.9, gap: 0.25, frac: 0.2, radius: 5, color: C(255, 70, 50), path: "Run", on: function (e) {
					$mc(k, "dot", e, 2, 0.04, "Burn");
				} });
			});
			$mc(k, "later", 2.2, function () {
				$mc(k, "fx", "Explosion", { Position: $add(c, UP), Radius: $mc(k, "R", 11), Color: C(255, 70, 50) });
				$mc(k, "fx", "Explosion", { Position: $add(c, $mul(UP, 2)), Radius: $mc(k, "R", 7), Color: C(90, 30, 120), Kind: "void" });
				$mc(k, "area", c, 11, 0.3, { KnockbackPower: 35, Lift: 30, Color: C(255, 70, 50) });
			});
			(yield* $cy($mc(k, "wait", 1.4)));
		});
		def("SK_titan_mastiff_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Crouch", 0.35);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.35)))))) {
				return;
			}
			$mc(k, "pose", "Leap", 0.7);
			let d = $mc(k, "dir");
			let land = $add($mc(k, "me"), $mul(d, math.min(12, $mul($mc(k, "dist"), 0.5))));
			if (!$t($1((yield* $cy($mc(k, "leap", land, 12, 0.6)))))) {
				return;
			}
			$mc(k, "pose", "Slam", 0.5);
			let g = $mc(k, "feet");
			$mc(k, "shock", g, 9, GOLD, true);
			$mc(k, "area", g, 7, 0.3, { KnockbackPower: 20, Lift: 20, Color: GOLD });
			$mc(k, "wave", "Spikes", { from: g, dir: d, length: 26, width: 8, speed: 45, frac: 0.7, color: GOLD, on: function (e) {
				$mc(k, "launch", e, 32);
			} });
			$mc(k, "path", "Crack", g, $1((yield* $cy(G($add(g, $mul(d, 26)))))), { Duration: 1.6, Color: GOLD });
		});
		def("SK_titan_mastiff_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Gold", 3.4);
			$mc(k, "pose", "Summon", 1.8);
			let c = $mc(k, "tground");
			for (let $v7 = 0, $v8 = $arr($mc(k, "around", c, 8, 6, 0)); $v7 < $v8.length; $v7++) {
				let p = $v8[$v7];
				if (p == null) break;
				let i = $v7 + 1;
				$mc(k, "later", (0.15 * i), function () {
					$mc(k, "pillar", "Holy", p, 2.5, { Height: 26, Time: 0.2, Hold: 1.6 });
					$mc(k, "area", p, 4, 0.02, { Color: GOLD });
				});
			}
			$mc(k, "tele", c, 8, 1.6, GOLD);
			$mc(k, "later", 1, function () {
				$mc(k, "summon", "Fist", { points: [c], time: 0.6, frac: 0.6, radius: 8, color: GOLD, size: 2.5, path: "Dive", on: function (e) {
					$mc(k, "stun", e, 1.2, "Dizzy");
				} });
			});
			$mc(k, "later", 1.65, function () {
				$mc(k, "shock", c, 12, GOLD, true);
				$mc(k, "fx", "Explosion", { Position: $add(c, UP), Radius: $mc(k, "R", 10), Color: GOLD });
				$mc(k, "area", c, 12, 0.3, { KnockbackPower: 30, Lift: 20, Color: GOLD });
			});
			(yield* $cy($mc(k, "wait", 1.6)));
		});
		def("SK_cosmic_dog_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Summon", 1.4);
			let c = $mc(k, "tground");
			let stars = $mc(k, "around", c, 6, 5, $mc(k, "rand", 0, 72));
			for (let $v9 = 0, $v10 = $arr(stars); $v9 < $v10.length; $v9++) {
				let p = $v10[$v9];
				if (p == null) break;
				let i = $v9 + 1;
				$mc(k, "later", (0.1 * i), function () {
					$mc(k, "prop", "Star", { Position: $add(p, $mul(UP, 3)), Path: "Hover", Time: 0.25, Hold: 0.9, Size: 1.6, Spin: 3, Color: C(220, 200, 255) });
				});
			}
			$mc(k, "later", 0.75, function () {
				for (let i = 1, $v11 = $len(stars); i <= $v11; i++) {
					$mc(k, "fx", "S_Line", { Kind: "Slash", From: $add($get(stars, i), $mul(UP, 3)), To: $add($get(stars, (($mod(i, $len(stars))) + 1)), $mul(UP, 3)), Color: C(220, 200, 255), Height: 0 });
				}
				for (let $v12 = 0, $v13 = $arr($mc(k, "enemies", c, $mc(k, "R", 7))); $v12 < $v13.length; $v12++) {
					let e = $v13[$v12];
					if (e == null) break;
					$mc(k, "pull", e, c, 14, 0.2);
				}
			});
			$mc(k, "later", 1.3, function () {
				$mc(k, "fx", "S_Burst", { Kind: "Stars", Position: c, Count: 16, Radius: 12, Color: C(220, 200, 255) });
				$mc(k, "fx", "Explosion", { Position: $add(c, UP), Radius: $mc(k, "R", 7), Color: C(200, 170, 255), Kind: "void" });
				$mc(k, "area", c, 7, 1, { KnockbackPower: 25, Lift: 25, Color: C(200, 170, 255) });
			});
			(yield* $cy($mc(k, "wait", 1)));
		});
		def("SK_cosmic_dog_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Space", 3.6);
			$mc(k, "pose", "Float", 2.8);
			if (!$t($1((yield* $cy($mc(k, "rise", 14, 0.5)))))) {
				return;
			}
			$mc(k, "charge", 1, C(255, 255, 255));
			$mc(k, "pop", "...", undefined, C(255, 255, 255), 1);
			let c = $mc(k, "tground");
			$mc(k, "fx", "Vortex", { Position: c, Radius: $mc(k, "R", 12), Duration: 1.2 });
			for (let _ = 1, $v14 = 4; _ <= $v14; _++) {
				if (!$t($1((yield* $cy($mc(k, "wait", 0.2)))))) {
					return;
				}
				for (let $v15 = 0, $v16 = $arr($mc(k, "enemies", c, $mc(k, "R", 14))); $v15 < $v16.length; $v15++) {
					let e = $v16[$v15];
					if (e == null) break;
					$mc(k, "pull", e, c, 20, 0.25);
				}
			}
			$mc(k, "sky", "Holy", 0.6);
			$mc(k, "fx", "Explosion", { Position: $add(c, $mul(UP, 2)), Radius: $mc(k, "R", 14), Color: C(200, 160, 255), Kind: "void" });
			$mc(k, "fx", "S_Ring", { Motif: "Star", Position: c, R0: 1, R1: $mc(k, "R", 16), Count: 16, Time: 0.8, Height: 2, Swirl: 3, Size: 1.4, Color: C(255, 240, 200) });
			$mc(k, "shake", c, 1.3, 90);
			$mc(k, "area", c, 14, 1, { KnockbackPower: 45, Lift: 35, Color: C(220, 190, 255) });
			if (!$t($1((yield* $cy($mc(k, "wait", 0.5)))))) {
				return;
			}
			(yield* $cy($mc(k, "land", undefined, 0.4)));
		});
		def("SK_phoenix_hound_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Fly", 1.6);
			$mc(k, "fx", "PhoenixRise", { Model: k.f.Model, Duration: 0.8 });
			if (!$t($1((yield* $cy($mc(k, "rise", 16, 0.5)))))) {
				return;
			}
			let c = $mc(k, "tground");
			$mc(k, "zone", "Rune", c, 7, 0.9, 0, { color: C(255, 140, 40) });
			if (!$t($1((yield* $cy($mc(k, "glide", $add(c, $mul(UP, 18)), 0.4)))))) {
				return;
			}
			$mc(k, "fx", "Streak", { Model: k.f.Model, Color: C(255, 130, 30), Duration: 0.5, Width: 3, Neon: true, Sparks: true });
			if (!$t($1((yield* $cy($mc(k, "land", c, 0.3)))))) {
				return;
			}
			$mc(k, "fx", "Explosion", { Position: $add(c, UP), Radius: $mc(k, "R", 9), Color: C(255, 130, 30) });
			for (let $v17 = 0, $v18 = $arr($mc(k, "area", c, 9, 0.75, { KnockbackPower: 30, Lift: 30, Color: C(255, 130, 30) })); $v17 < $v18.length; $v17++) {
				let e = $v18[$v17];
				if (e == null) break;
				$mc(k, "dot", e, 3, 0.1, "Burn");
			}
			$mc(k, "zone", "Fire", c, 7, 2.5, 0.15);
		});
		def("SK_phoenix_hound_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Fire", 3.4);
			$mc(k, "pose", "Summon", 2);
			let c = $mc(k, "tground");
			$mc(k, "summon", "Bird", { from: $mc(k, "me"), points: [c], time: 1, frac: 0.35, radius: 10, color: C(255, 140, 40), size: 9, path: "Over" });
			$mc(k, "later", 0.6, function () {
				$mc(k, "rain", "Feather", $mc(k, "scatter", c, 9, 10, true), { fall: 0.6, gap: 0.1, size: 2, frac: 0.04, radius: 4, impact: "Fire", height: 30, color: C(255, 150, 40), tele: false });
			});
			$mc(k, "later", 2, function () {
				$mc(k, "fx", "Explosion", { Position: $add(c, UP), Radius: $mc(k, "R", 11), Color: C(255, 140, 40) });
				for (let $v19 = 0, $v20 = $arr($mc(k, "area", c, 11, 0.3, { KnockbackPower: 30, Lift: 30, Color: C(255, 140, 40) })); $v19 < $v20.length; $v19++) {
					let e = $v20[$v19];
					if (e == null) break;
					$mc(k, "dot", e, 3, 0.05, "Burn");
				}
				$mc(k, "heal", 0.25);
				$mc(k, "aura", "Fire", 3, C(255, 150, 40));
			});
			(yield* $cy($mc(k, "wait", 1.5)));
		});
		def("SK_void_beast_3", 3, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "reach", 26, 1)))))) {
				return;
			}
			$mc(k, "face");
			$mc(k, "pose", "Focus", 0.6);
			$mc(k, "charge", 0.6, C(170, 90, 255));
			if (!$t($1((yield* $cy($mc(k, "wait", 0.6)))))) {
				return;
			}
			$mc(k, "pose", "Open", 0.9);
			(yield* $cy($mc(k, "beam", "Void", { length: 34, width: 4, time: 0.8, ticks: 3, frac: 1, color: C(170, 90, 255), on: function (e) {
				$mc(k, "slow", e, 2.5, 0.5);
			} })));
		});
		def("SK_void_beast_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Abyss", 3.2);
			$mc(k, "pose", "Summon", 1.8);
			let c = $mc(k, "tground");
			$mc(k, "zone", "Shadow", c, 11, 2.8, 0);
			$mc(k, "fx", "S_Ring", { Motif: "Fang", Position: c, R0: $mc(k, "R", 10), R1: $mc(k, "R", 2), Count: 12, Time: 1, Height: 2, Rise: 1, Size: 3, Color: C(255, 255, 255) });
			for (let _ = 1, $v21 = 4; _ <= $v21; _++) {
				if (!$t($1((yield* $cy($mc(k, "wait", 0.25)))))) {
					return;
				}
				for (let $v22 = 0, $v23 = $arr($mc(k, "enemies", c, $mc(k, "R", 12))); $v22 < $v23.length; $v22++) {
					let e = $v23[$v22];
					if (e == null) break;
					$mc(k, "pull", e, c, 18, 0.25);
				}
			}
			$mc(k, "pop", "CHOMP!", $add(c, $mul(UP, 6)), C(200, 140, 255), 1.6);
			$mc(k, "fx", "Explosion", { Position: $add(c, UP), Radius: $mc(k, "R", 9), Color: C(150, 60, 240), Kind: "void" });
			$mc(k, "area", c, 9, 0.7, { KnockbackPower: 20, Lift: 35, Color: C(170, 90, 255) });
			$mc(k, "summon", "Tentacle", { points: $mc(k, "around", c, 4, 3, $mc(k, "rand", 0, 120)), time: 0.45, gap: 0.15, frac: 0.1, radius: 4.5, color: C(120, 50, 200), path: "Rise" });
		});
		def("SK_hydra_hound_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Rear", 0.6);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.5)))))) {
				return;
			}
			$mc(k, "pose", "Roar", 0.5);
			let poisoned = [];
			$mc(k, "wave", "Water", { from: $mc(k, "feet"), dir: $mc(k, "dir"), length: math.min(34, $add($mc(k, "dist"), 10)), width: 12, speed: 38, frac: 0.6, color: C(110, 220, 120), on: function (e) {
				$mc(k, "knock", e, $mc(k, "me"), 20, 14);
				if (!$t($get(poisoned, e))) {
					$set(poisoned, e, true);
					$mc(k, "dot", e, 4, 0.4, "Poison");
				}
			} });
		});
		def("SK_hydra_hound_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Toxic", 3.4);
			$mc(k, "pose", "Summon", 2);
			let c = $mc(k, "tground");
			$mc(k, "zone", "Poison", c, 9, 3, 0);
			$mc(k, "summon", "Snake", { points: $mc(k, "around", c, 3.5, 5, $mc(k, "rand", 0, 72)), time: 0.6, gap: 0.25, frac: 0.16, radius: 4.5, color: C(100, 230, 110), size: 1.8, path: "Rise", on: function (e) {
				$mc(k, "dot", e, 2, 0.02, "Poison");
			} });
			$mc(k, "later", 2, function () {
				$mc(k, "area", c, 9, 0.12, { KnockbackPower: 25, Lift: 20, Color: C(100, 230, 110) });
				$mc(k, "heal", 0.3);
			});
			(yield* $cy($mc(k, "wait", 1.6)));
		});
		def("SK_bone_dragon_3", 3, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "reach", $mul($mc(k, "R", 18), 0.7), 1)))))) {
				return;
			}
			$mc(k, "face");
			$mc(k, "pose", "Inhale", 0.4);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.4)))))) {
				return;
			}
			$mc(k, "pose", "Open", 1.1);
			let cursed = [];
			(yield* $cy($mc(k, "breath", "Ghost", { length: 18, angle: 30, time: 1, ticks: 4, frac: 0.85, color: C(90, 255, 220), on: function (e) {
				if (!$t($get(cursed, e))) {
					$set(cursed, e, true);
					$mc(k, "curse", e, 4, 1.2);
				}
			} })));
			$mc(k, "dot", k.t, 2, 0.15, "Curse");
		});
		def("SK_bone_dragon_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Night", 3.4);
			$mc(k, "pose", "Summon", 2.2);
			let c = $mc(k, "tground");
			$mc(k, "zone", "Grave", c, 12, 3.2, 0);
			$mc(k, "summon", "Skeleton", { points: huntPoints(k, c, 5, 16), time: 0.7, gap: 0.2, frac: 0.12, radius: 4.5, path: "Rise" });
			$mc(k, "later", 1.4, function () {
				$mc(k, "summon", "Hand", { points: [c], time: 0.5, frac: 0.2, radius: 5, path: "Rise", on: function (e) {
					$mc(k, "stun", e, 1.5, "Cage", C(240, 230, 200));
				} });
			});
			$mc(k, "later", 2.3, function () {
				$mc(k, "shock", c, 11, C(110, 255, 210));
				$mc(k, "area", c, 11, 0.2, { KnockbackPower: 25, Lift: 20, Color: C(110, 255, 210) });
			});
			(yield* $cy($mc(k, "wait", 1.6)));
		});
		def("SK_kraken_hound_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Summon", 1.4);
			let c = $mc(k, "tground");
			$mc(k, "zone", "Water", c, 9, 2.6, 0.5, { on: function (e) {
				$mc(k, "pull", e, c, 18, 0.3);
			} });
			for (let i = 1, $v24 = 2; i <= $v24; i++) {
				$mc(k, "later", (0.5 + (i * 0.6)), function () {
					let dd = $sp1(turn(Vector3.new(1, 0, 0), $mc(k, "rand", 0, 360)));
					$mc(k, "prop", "Tentacle", { Position: $sub(c, $mul(dd, 5)), Look: dd, Path: "Swing", Time: 0.4, Hold: 0.1, Reach: 5, Size: $mul(1.3, k.A), Impact: "Splash", Color: C(70, 140, 230), Color2: C(180, 220, 255), End: "Sink" });
				});
				$mc(k, "later", (0.9 + (i * 0.6)), function () {
					$mc(k, "area", c, 6, 0.25, { Lift: 20, KnockbackPower: 6, Color: C(70, 140, 230) });
				});
			}
			(yield* $cy($mc(k, "wait", 0.8)));
		});
		def("SK_kraken_hound_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Abyss", 3.4);
			$mc(k, "pose", "Summon", 2.4);
			let c = $mc(k, "tground");
			$mc(k, "zone", "Water", c, 13, 3.2, 0.1, { on: function (e) {
				$mc(k, "pull", e, c, 14, 0.3);
			} });
			$mc(k, "summon", "Tentacle", { points: $mc(k, "around", c, 5, 8, $mc(k, "rand", 0, 45)), time: 0.5, gap: 0.15, frac: 0.07, radius: 5, color: C(80, 130, 230), size: 1.6, path: "Rise" });
			$mc(k, "later", 2.1, function () {
				$mc(k, "wave", "Water", { from: $sp1(G($sub(c, $mul($mc(k, "dir"), 14)))), dir: $mc(k, "dir"), length: 30, width: 16, speed: 34, frac: 0.35, color: C(70, 120, 220) });
			});
			(yield* $cy($mc(k, "wait", 1.6)));
		});
		def("SK_chrono_hound_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			let home = $mc(k, "feet");
			$mc(k, "pose", "Dash", 1.6);
			$mc(k, "pop", "REWIND!", undefined, C(255, 235, 150), 0.9);
			let slowed = [];
			for (let _ = 1, $v25 = 3; _ <= $v25; _++) {
				let d = $mc(k, "dir");
				if (!$t($1((yield* $cy($mc(k, "dash", $add($mc(k, "tpos"), $mul(d, 5)), 0.2, { frac: 0.33, radius: 3.5, opts: { Color: C(255, 235, 150) }, on: function (e) {
					if (!$t($get(slowed, e))) {
						$set(slowed, e, true);
						$mc(k, "slow", e, 3, 0.5, "Time");
					}
				} })))))) {
					return;
				}
				$mc(k, "path", "Trail", $mc(k, "feet"), home, { Duration: 0.4, Width: 1.5, Color: C(255, 235, 150) });
				$mc(k, "fx", "Smoke", { Position: $mc(k, "feet"), Color: C(220, 220, 240), Size: 3 });
				if (!$t($mc(k, "tp", home))) {
					return;
				}
				if (!$t($1((yield* $cy($mc(k, "wait", 0.12)))))) {
					return;
				}
			}
		});
		def("SK_chrono_hound_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Time", 3.6);
			$mc(k, "pose", "Summon", 2.6);
			let c = $mc(k, "tground");
			$mc(k, "prop", "Clock", { Position: $add(c, $mul(UP, 15)), Look: $unm($mc(k, "dir")), Path: "Hover", Time: 0.4, Hold: 2.6, Size: $mul(4, k.A) });
			$mc(k, "zone", "Time", c, 9, 3, 0);
			for (let i = 1, $v26 = 6; i <= $v26; i++) {
				$mc(k, "later", (0.4 + (i * 0.32)), function () {
					let p = ($n((($mod(i, 2) === 0) && c)) ?? $sp1(G($add(c, Vector3.new($mc(k, "rand", (-5), 5), 0, $mc(k, "rand", (-5), 5))))));
					$mc(k, "pillar", "Lightning", p, 2.5, { Color: C(255, 230, 120) });
					$mc(k, "pop", "DONG", $add(c, $mul(UP, 8)), C(255, 235, 150), (0.6 + (i * 0.1)));
					$mc(k, "area", p, 5, 0.1, { Color: C(255, 230, 120) });
				});
			}
			$mc(k, "later", 2.5, function () {
				$mc(k, "fx", "Explosion", { Position: $add(c, UP), Radius: $mc(k, "R", 11), Color: C(255, 230, 120) });
				for (let $v27 = 0, $v28 = $arr($mc(k, "area", c, 11, 0.4, { KnockbackPower: 30, Lift: 25, Color: C(255, 230, 120) })); $v27 < $v28.length; $v27++) {
					let e = $v28[$v27];
					if (e == null) break;
					$mc(k, "stun", e, 1.5, "Time");
				}
			});
			(yield* $cy($mc(k, "wait", 1.6)));
		});
		def("SK_singularity_pup_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Summon", 1.3);
			let c = $mc(k, "tground");
			$mc(k, "zone", "Gravity", c, 8, 1.4, 0);
			for (let $v29 = 0, $v30 = $arr($mc(k, "enemies", c, $mc(k, "R", 8))); $v29 < $v30.length; $v29++) {
				let e = $v30[$v29];
				if (e == null) break;
				$mc(k, "launch", e, 36);
				$mc(k, "stun", e, 1, "Lift");
			}
			$mc(k, "area", c, 8, 0.3, { Color: C(150, 90, 230) });
			$mc(k, "later", 1.05, function () {
				$mc(k, "shock", c, 9, C(150, 90, 230), true);
				$mc(k, "fx", "Explosion", { Position: $add(c, UP), Radius: $mc(k, "R", 7), Color: C(150, 90, 230), Kind: "void" });
				$mc(k, "burst", "Rocks", c, { Count: 10 });
				$mc(k, "area", c, 9, 0.7, { KnockbackPower: 10, Lift: 4, Color: C(150, 90, 230) });
			});
			(yield* $cy($mc(k, "wait", 0.9)));
		});
		def("SK_singularity_pup_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Space", 3.4);
			$mc(k, "pose", "Focus", 2.6);
			let c = $mc(k, "tground");
			$mc(k, "prop", "Orb", { Position: $add(c, $mul(UP, 7)), Path: "Spin", Time: 2.2, Hold: 0.2, Size: $mul(4, k.A), Spin: 4, Color: C(40, 10, 70) });
			$mc(k, "fx", "Vortex", { Position: c, Radius: $mc(k, "R", 14), Duration: 2.2 });
			for (let _ = 1, $v31 = 10; _ <= $v31; _++) {
				if (!$t($1((yield* $cy($mc(k, "wait", 0.2)))))) {
					return;
				}
				for (let $v32 = 0, $v33 = $arr($mc(k, "enemies", c, $mc(k, "R", 16))); $v32 < $v33.length; $v32++) {
					let e = $v33[$v32];
					if (e == null) break;
					$mc(k, "pull", e, c, 22, 0.22);
				}
				$mc(k, "area", c, 7, 0.035, { Color: C(170, 110, 255) });
			}
			$mc(k, "sky", "Holy", 0.6);
			$mc(k, "fx", "Explosion", { Position: $add(c, $mul(UP, 2)), Radius: $mc(k, "R", 14), Color: C(255, 255, 255) });
			$mc(k, "pop", "WHITE HOLE!", $add(c, $mul(UP, 8)), C(255, 255, 255), 1.4);
			$mc(k, "area", c, 14, 0.65, { KnockbackPower: 50, Lift: 35, Color: C(230, 220, 255) });
		});
		def("SK_seraph_hound_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Summon", 1.4);
			$mc(k, "aura", "Holy", 1.6, C(255, 230, 150));
			let c = $mc(k, "tground");
			$mc(k, "rain", "Feather", $mc(k, "scatter", c, 6, 14, true), { fall: 0.45, gap: 0.06, size: 2, frac: 0.09, radius: 3.5, impact: "Holy", height: 26, color: C(255, 225, 130), tele: false });
			(yield* $cy($mc(k, "wait", 1)));
		});
		def("SK_seraph_hound_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Holy", 3.4);
			$mc(k, "pose", "Summon", 2.4);
			let c = $mc(k, "tground");
			let d = $mc(k, "dir");
			$mc(k, "prop", "Gate", { Position: $add(c, $mul(d, 9)), Look: $unm(d), Path: "Rise", Depth: 12, Time: 0.6, Hold: 2.2, Size: $mul(1.4, k.A), Impact: "Holy", End: "Sink" });
			$mc(k, "later", 0.7, function () {
				$mc(k, "summon", "Spear", { points: $mc(k, "scatter", c, 5, 6, true), time: 0.6, gap: 0.2, frac: 0.12, radius: 4.5, color: C(255, 230, 150), path: "Dive" });
			});
			$mc(k, "later", 2.3, function () {
				$mc(k, "pillar", "Holy", c, 5, { Height: 34, Time: 0.2, Hold: 0.8 });
				$mc(k, "area", c, 10, 0.28, { KnockbackPower: 30, Lift: 25, Color: C(255, 230, 150) });
				$mc(k, "heal", 0.3);
			});
			(yield* $cy($mc(k, "wait", 1.6)));
		});
		def("SK_crystal_golem_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Slam", 0.5);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.2)))))) {
				return;
			}
			let len = math.min(36, $add($mc(k, "dist"), 6));
			$mc(k, "wave", "Crystal", { length: len, width: 7, speed: 40, frac: 0.8, color: C(170, 220, 255), on: function (e) {
				$mc(k, "launch", e, 30);
			} });
			$mc(k, "later", $div(len, 40), function () {
				let p = ($n(($a($mc(k, "real")) && $mc(k, "tground"))) ?? undefined);
				if ($t(p)) {
					$mc(k, "fx", "S_Burst", { Kind: "Crystals", Position: p, Count: 12, Radius: 10, Color: C(190, 230, 255) });
					$mc(k, "area", p, 6, 0.2, { Color: C(170, 220, 255) });
				}
			});
		});
		def("SK_crystal_golem_4", 4, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "approach", 6, 1)))))) {
				return;
			}
			$mc(k, "sky", "Ice", 3.2);
			$mc(k, "pose", "Guard", 2.4);
			$mc(k, "shield", 4, 0.5, "Crystal", C(200, 235, 255));
			let g = $mc(k, "feet");
			for (let $v34 = 0, $v35 = $arr($mc(k, "around", g, 7, 8, 0)); $v34 < $v35.length; $v34++) {
				let p = $v35[$v34];
				if (p == null) break;
				let i = $v34 + 1;
				$mc(k, "later", (0.08 * i), function () {
					$mc(k, "pillar", "Ice", p, 2.2, { Height: 14, Time: 0.25, Hold: 1.6 });
				});
			}
			if (!$t($1((yield* $cy($mc(k, "wait", 2)))))) {
				return;
			}
			$mc(k, "pose", "Slam", 0.5);
			g = $mc(k, "feet");
			$mc(k, "shoot", "Crystal", { from: $add(g, $mul(UP, 3)), points: $mc(k, "around", g, 15, 12, 15), speed: 50, arc: 2, frac: 0.05, radius: 3.5, size: 1.6, impact: "Crystal", color: C(200, 235, 255) });
			$mc(k, "shock", g, 13, C(200, 235, 255), true);
			for (let $v36 = 0, $v37 = $arr($mc(k, "area", g, 13, 0.75, { KnockbackPower: 35, Lift: 20, Color: C(200, 235, 255) })); $v36 < $v37.length; $v36++) {
				let e = $v37[$v36];
				if (e == null) break;
				$mc(k, "freeze", e, 1);
			}
		});
		def("SK_frost_phoenix_3", 3, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "reach", $mul($mc(k, "R", 18), 0.7), 1)))))) {
				return;
			}
			$mc(k, "face");
			$mc(k, "pose", "Summon", 1.3);
			(yield* $cy($mc(k, "breath", "Frost", { length: 18, angle: 40, time: 1, ticks: 4, frac: 0.6, color: C(170, 225, 255) })));
			$mc(k, "inCone", $mc(k, "me"), $mc(k, "dir"), 18, 40, 0.4, { Color: C(170, 225, 255) }, function (e) {
				$mc(k, "freeze", e, 1.3);
			});
		});
		def("SK_frost_phoenix_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Ice", 3.4);
			$mc(k, "pose", "Fly", 2.4);
			let c = $mc(k, "tground");
			$mc(k, "summon", "Bird", { from: $mc(k, "me"), points: [c], time: 1, frac: 0.3, radius: 10, color: C(190, 235, 255), size: 9, path: "Over" });
			$mc(k, "later", 0.8, function () {
				$mc(k, "rain", "Icicle", $mc(k, "scatter", c, 8, 8, true), { fall: 0.6, gap: 0.1, size: 2.5, frac: 0.06, radius: 4.5, impact: "Shatter", color: C(190, 235, 255) });
			});
			$mc(k, "later", 2.2, function () {
				$mc(k, "fx", "S_Burst", { Kind: "Shards", Position: c, Count: 20, Radius: 14, Color: C(210, 240, 255) });
				for (let $v38 = 0, $v39 = $arr($mc(k, "area", c, 11, 0.25, { Color: C(190, 235, 255) })); $v38 < $v39.length; $v38++) {
					let e = $v39[$v38];
					if (e == null) break;
					$mc(k, "freeze", e, 2);
				}
			});
			(yield* $cy($mc(k, "wait", 1.6)));
		});
		def("SK_thunder_colossus_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Summon", 1);
			let c = $mc(k, "tground");
			$mc(k, "tele", c, 7, 0.9, YELLOW);
			$mc(k, "later", 0.3, function () {
				$mc(k, "summon", "Fist", { points: [c], time: 0.6, frac: 0.8, radius: 7, color: YELLOW, size: 2, path: "Dive", on: function (e) {
					$mc(k, "stun", e, 1.2, "Shock");
				} });
			});
			$mc(k, "later", 0.9, function () {
				$mc(k, "pillar", "Lightning", c, 3, { Color: YELLOW });
				$mc(k, "shock", c, 9, YELLOW);
				$mc(k, "area", c, 9, 0.2, { KnockbackPower: 20, Lift: 15, Color: YELLOW });
			});
			(yield* $cy($mc(k, "wait", 0.8)));
		});
		def("SK_thunder_colossus_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Storm", 3.4);
			$mc(k, "pose", "Stomp", 2.8);
			let c = $mc(k, "tground");
			$mc(k, "zone", "Storm", c, 12, 3, 0);
			for (let i = 1, $v40 = 10; i <= $v40; i++) {
				$mc(k, "later", (0.25 * i), function () {
					let p = ($n((($mod(i, 3) === 0) && (($n(($a($mc(k, "real")) && $mc(k, "tground"))) ?? c)))) ?? $sp1(G($add(c, Vector3.new($mc(k, "rand", (-8), 8), 0, $mc(k, "rand", (-8), 8))))));
					$mc(k, "pillar", "Lightning", p, 2.4, { Color: YELLOW });
					$mc(k, "area", p, 4.5, 0.07, { Color: YELLOW });
				});
			}
			for (let i = 1, $v41 = 4; i <= $v41; i++) {
				$mc(k, "later", (0.6 * i), function () {
					$mc(k, "shock", c, 12, C(255, 240, 150), true);
					$mc(k, "shake", c, 0.6, 60);
					$mc(k, "area", c, 12, 0.03, { Color: YELLOW });
				});
			}
			$mc(k, "later", 2.8, function () {
				for (let $v42 = 0, $v43 = $arr($mc(k, "area", c, 11, 0.2, { KnockbackPower: 25, Lift: 25, Color: YELLOW })); $v42 < $v43.length; $v42++) {
					let e = $v43[$v42];
					if (e == null) break;
					$mc(k, "stun", e, 1.2, "Shock");
				}
			});
			(yield* $cy($mc(k, "wait", 1.8)));
		});
		def("SK_rainbow_unicorn_3", 3, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "reach", 22, 1)))))) {
				return;
			}
			$mc(k, "face");
			$mc(k, "pose", "Summon", 0.6);
			$mc(k, "charge", 0.5, C(255, 200, 255));
			if (!$t($1((yield* $cy($mc(k, "wait", 0.5)))))) {
				return;
			}
			$mc(k, "pose", "Open", 0.9);
			let d = $mc(k, "dir");
			for (let $v44 = 0, $v45 = $arr([(-22), 22]); $v44 < $v45.length; $v44++) {
				let ang = $v45[$v44];
				if (ang == null) break;
				$mc(k, "fx", "S_Beam", { Kind: "Rainbow", Model: k.f.Model, From: $mc(k, "mouth"), To: $add($mc(k, "mouth"), $mul($1((yield* $cy(turn(d, ang)))), 26)), Width: $mc(k, "R", 3), Duration: 0.8 });
				$mc(k, "inLine", $mc(k, "me"), $1((yield* $cy(turn(d, ang)))), 26, 4, 0.15, { Color: C(255, 200, 255) });
			}
			(yield* $cy($mc(k, "beam", "Rainbow", { length: 30, width: 4, time: 0.8, ticks: 3, frac: 0.85 })));
		});
		def("SK_rainbow_unicorn_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Rainbow", 3.4);
			$mc(k, "pose", "Victory", 2.4);
			let c = $mc(k, "tground");
			let cols = [C(255, 90, 100), C(255, 220, 80), C(90, 220, 130), C(110, 170, 255), C(190, 120, 255)];
			for (let $v46 = 0, $v47 = $arr(cols); $v46 < $v47.length; $v46++) {
				let col = $v47[$v46];
				if (col == null) break;
				let i = $v46 + 1;
				$mc(k, "later", (0.2 + (i * 0.25)), function () {
					$mc(k, "rain", "Star", $mc(k, "scatter", c, 7, 3, (i === 3)), { fall: 0.55, gap: 0.08, size: 1.5, frac: 0.06, radius: 4, impact: "Stars", height: 35, color: col, tele: false });
				});
			}
			for (let i = 1, $v48 = 3; i <= $v48; i++) {
				$mc(k, "later", (0.6 * i), function () {
					$mc(k, "heal", 0.08);
				});
			}
			$mc(k, "later", 2.1, function () {
				$mc(k, "fx", "S_Burst", { Kind: "Confetti", Position: c, Count: 30, Radius: 14 });
				$mc(k, "area", c, 11, 0.3, { KnockbackPower: 30, Lift: 25, Color: C(255, 180, 240) });
			});
			(yield* $cy($mc(k, "wait", 1.6)));
		});
		def("SK_demon_samurai_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Slash", 1.4);
			let lines = [];
			for (let i = 1, $v49 = 3; i <= $v49; i++) {
				let d = $mc(k, "dir");
				let s = $mul(side(d), (($n(((($mod(i, 2) === 0)) && 3)) ?? (-3))));
				let from = $mc(k, "feet");
				let to = $add($add($mc(k, "tpos"), $mul(d, 6)), s);
				if (!$t($1((yield* $cy($mc(k, "dash", to, 0.16, { frac: 0.18, radius: 3.5, opts: { Color: C(255, 90, 50) } })))))) {
					return;
				}
				$mc(k, "path", "Fire", from, $mc(k, "feet"), { Duration: 1.2, Width: 2.5, Color: C(255, 90, 50) });
				$ins(lines, [from, $mc(k, "feet")]);
				$mc(k, "face");
				if (!$t($1((yield* $cy($mc(k, "wait", 0.1)))))) {
					return;
				}
			}
			$mc(k, "later", 0.5, function () {
				for (let $v50 = 0, $v51 = $arr(lines); $v50 < $v51.length; $v50++) {
					let l = $v51[$v50];
					if (l == null) break;
					let seg = $sub($get(l, 2), $get(l, 1));
					$mc(k, "fx", "Explosion", { Position: $add($mc($get(l, 1), "Lerp", $get(l, 2), 0.5), UP), Radius: $mc(k, "R", 4), Color: C(255, 90, 50) });
					$mc(k, "inLine", $get(l, 1), seg, seg.Magnitude, 5, 0.15, { Color: C(255, 90, 50) });
				}
			});
		});
		def("SK_demon_samurai_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Red", 3.4);
			$mc(k, "pose", "Summon", 2.4);
			let c = $mc(k, "tground");
			$mc(k, "prop", "Mask", { Position: $add(c, $mul(UP, 24)), Look: $unm($mc(k, "dir")), Path: "Hover", Time: 0.5, Hold: 2.4, Size: $mul(4, k.A) });
			$mc(k, "prop", "Tornado", { Position: c, Path: "Spin", Time: 2.2, Hold: 0.3, Size: $mul(4, k.A), Spin: 10, Color: C(255, 80, 40) });
			let center = ($n(($a(k.t) && k.t.Model)) ?? undefined);
			if ($t(center)) {
				$mc(k, "fx", "S_Orbit", { Model: center, Motif: "Blade", Count: 4, Radius: 3.5, Speed: 8, Height: 2, Duration: 1.9, Size: 1.6, Color: C(255, 80, 40), End: "Burst" });
			}
			for (let i = 1, $v52 = 8; i <= $v52; i++) {
				$mc(k, "later", (0.25 * i), function () {
					for (let $v53 = 0, $v54 = $arr($mc(k, "area", c, 6, 0.08, { Color: C(255, 90, 50) })); $v53 < $v54.length; $v53++) {
						let e = $v54[$v53];
						if (e == null) break;
						$mc(k, "pull", e, c, 10, 0.2);
					}
				});
			}
			$mc(k, "later", 2.3, function () {
				$mc(k, "fx", "Explosion", { Position: $add(c, UP), Radius: $mc(k, "R", 10), Color: C(255, 80, 40) });
				for (let $v55 = 0, $v56 = $arr($mc(k, "area", c, 10, 0.36, { KnockbackPower: 35, Lift: 30, Color: C(255, 80, 40) })); $v55 < $v56.length; $v55++) {
					let e = $v56[$v55];
					if (e == null) break;
					$mc(k, "dot", e, 2, 0.04, "Burn");
				}
			});
			(yield* $cy($mc(k, "wait", 1.6)));
		});
		def("SK_mecha_hound_3", 3, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "reach", 28, 1)))))) {
				return;
			}
			$mc(k, "face");
			$mc(k, "pose", "Aim", 0.8);
			$mc(k, "charge", 0.8, C(120, 230, 255));
			if (!$t($1((yield* $cy($mc(k, "wait", 0.8)))))) {
				return;
			}
			$mc(k, "pose", "Open", 1);
			$mc(k, "shake", $mc(k, "me"), 0.6, 50);
			(yield* $cy($mc(k, "beam", "Photon", { length: 40, width: 6, time: 1, ticks: 4, frac: 1, color: C(120, 230, 255) })));
		});
		def("SK_mecha_hound_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Dark", 3.4);
			$mc(k, "pose", "Aim", 2.6);
			let c = $mc(k, "tground");
			let spots = huntPoints(k, c, 4, 18);
			for (let $v57 = 0, $v58 = $arr(spots); $v57 < $v58.length; $v57++) {
				let p = $v58[$v57];
				if (p == null) break;
				let i = $v57 + 1;
				$mc(k, "later", (0.1 * i), function () {
					for (let $v59 = 0, $v60 = $arr($mc(k, "enemies", p, 3)); $v59 < $v60.length; $v59++) {
						let e = $v60[$v59];
						if (e == null) break;
						$mc(k, "mark", e, "Reticle", 1.2);
					}
					$mc(k, "tele", p, 4, 0.9, C(120, 230, 255));
				});
				$mc(k, "later", (1 + (i * 0.3)), function () {
					$mc(k, "pillar", "Plasma", p, 3.5, { Height: 45, Time: 0.12, Hold: 0.5, Color: C(120, 230, 255) });
					$mc(k, "area", p, 5, 0.18, { Lift: 20, KnockbackPower: 10, Color: C(120, 230, 255) });
				});
			}
			$mc(k, "later", 0.6, function () {
				$mc(k, "shoot", "Missile", { from: $add($mc(k, "me"), $mul(UP, 3)), points: $mc(k, "scatter", c, 6, 6, true), speed: 45, arc: 12, frac: 0.04, radius: 4, gap: 0.06, size: 0.9, trail: "Smoke", impact: "Explode" });
			});
			$mc(k, "later", 2.4, function () {
				$mc(k, "pillar", "Plasma", c, 6, { Height: 50, Time: 0.15, Hold: 0.7, Color: C(150, 240, 255) });
				$mc(k, "fx", "Explosion", { Position: $add(c, UP), Radius: $mc(k, "R", 10), Color: C(120, 230, 255) });
				$mc(k, "area", c, 10, 0.22, { KnockbackPower: 30, Lift: 26, Color: C(120, 230, 255) });
			});
			(yield* $cy($mc(k, "wait", 1.6)));
		});
		def("SK_planet_hound_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Summon", 1.4);
			let c = $mc(k, "tground");
			$mc(k, "zone", "Flowers", c, 9, 2.6, 0.3, { on: function (e) {
				$mc(k, "slow", e, 0.6, 0.6);
			} });
			for (let $v61 = 0, $v62 = $arr($mc(k, "around", c, 4, 3, $mc(k, "rand", 0, 120))); $v61 < $v62.length; $v61++) {
				let p = $v62[$v61];
				if (p == null) break;
				let i = $v61 + 1;
				$mc(k, "later", (0.3 * i), function () {
					$mc(k, "pillar", "Water", p, 2.4, { Height: 16, Time: 0.2, Hold: 0.5 });
					$mc(k, "area", p, 4.5, 0.15, { Lift: 30, KnockbackPower: 4, Color: C(90, 170, 255) });
				});
			}
			$mc(k, "later", 1.3, function () {
				for (let $v63 = 0, $v64 = $arr($mc(k, "area", c, 9, 0.25, { Color: C(110, 220, 120) })); $v63 < $v64.length; $v63++) {
					let e = $v64[$v63];
					if (e == null) break;
					$mc(k, "stun", e, 1, "Vines");
				}
			});
			(yield* $cy($mc(k, "wait", 1)));
		});
		def("SK_planet_hound_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Space", 3.6);
			$mc(k, "pose", "Summon", 2.4);
			let c = $mc(k, "tground");
			$mc(k, "tele", c, 12, 1, C(90, 200, 255));
			$mc(k, "prop", "Planet", { Position: $add(c, $mul($mul(UP, 4), k.A)), Path: "Fall", Height: 60, Time: 1, Hold: 0.6, Size: $mul(3, k.A), Color: C(90, 170, 110), Color2: C(200, 230, 255), Impact: "Explode", Shake: 1.2 });
			$mc(k, "later", 1, function () {
				$mc(k, "area", c, 12, 0.5, { KnockbackPower: 40, Lift: 35, Color: C(90, 200, 255) });
				$mc(k, "rain", "Rock", $mc(k, "scatter", c, 10, 8, false), { fall: 0.5, gap: 0.08, size: 2, frac: 0.03, radius: 4, impact: "Rock", height: 25, tele: false });
			});
			$mc(k, "later", 1.6, function () {
				for (let i = 0, $v65 = 3; i <= $v65; i++) {
					$mc(k, "wave", "Water", { from: c, dir: $sp1(turn($mc(k, "dir"), ((i * 90) + 45))), length: 16, width: 10, speed: 32, frac: 0.06, color: C(70, 150, 240) });
				}
			});
			$mc(k, "later", 2.1, function () {
				$mc(k, "zone", "Flowers", c, 10, 2, 0.15, { on: function (e) {
					$mc(k, "slow", e, 0.6, 0.6);
				} });
			});
			(yield* $cy($mc(k, "wait", 1.6)));
		});
	};
}
