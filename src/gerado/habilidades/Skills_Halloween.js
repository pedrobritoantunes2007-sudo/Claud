// Gerado automaticamente de server/Services/SpecialsPacks/Skills_Halloween.lua (código do jogo Roblox) por tools/lua2js — não edite à mão.
import { $t, $a, $n, $1, $M, $mv, $lst, $get, $set, $tm, $tc, $len, $cat, $eq, $add, $sub, $mul, $div, $mod, $pow, $idiv, $unm, $mc, $cy, $sp, $sp1, $W, $WS, $ins, $ins3, $arr, $pairs, $iter, $pcallG, $warnWait } from '../../rbx/lua.js';

export default function ($G, $script) {
	let require = $G["require"], Color3 = $G["Color3"], Vector3 = $G["Vector3"], ipairs = $G["ipairs"];
	let SkillKit = $sp1(require($script.Parent.Parent.SkillKit));
	let C = Color3.fromRGB;
	let UP = Vector3.new(0, 1, 0);
	let CREAM = C(255, 248, 235);
	let ORANGE = C(255, 135, 30);
	let PURPLE = C(150, 60, 220);
	let LIME = C(150, 235, 60);
	return function (Specials, _Fighters) {
		let def = function (id, slot, fn) {
			$sp(SkillKit.def(Specials, id, slot, fn));
		};
		def("SK_clown_dog_2", 2, function* (k) {
			$mc(k, "face");
			$mc(k, "pose", "Throw", 0.5);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.12)))))) {
				return;
			}
			$mc(k, "shoot", "Pie", { count: 3, spread: 22, speed: 85, arc: 3, spin: 6, frac: 0.3, radius: 4.5, impact: "Splash", size: 1.6, color: CREAM, on: function (e) {
				$mc(k, "slow", e, 1.6, 0.6, "Honey");
			} });
			$mc(k, "later", 0.35, function () {
				$mc(k, "pop", "SPLAT!", $add($mc(k, "tground"), $mul(UP, 5)), CREAM, 1.1);
			});
			(yield* $cy($mc(k, "wait", 0.3)));
		});
		def("SK_clown_dog_3", 3, function* (k) {
			$mc(k, "face");
			$mc(k, "pose", "Summon", 0.6);
			let c = $mc(k, "tground");
			let d = $mc(k, "dir", c);
			$mc(k, "tele", c, 7, 0.4, ORANGE);
			$mc(k, "prop", "JackBox", { Position: c, Path: "Grow", Time: 0.35, Hold: 1.3, Size: $mul(2.4, k.A), Look: $unm(d), Impact: "Confetti", Radius: 6, Shake: 0.3 });
			if (!$t($1((yield* $cy($mc(k, "wait", 0.4)))))) {
				return;
			}
			$mc(k, "pop", "BOING!", $add(c, $mul(UP, 7)), LIME, 1.4);
			$mc(k, "burst", "Confetti", $add(c, $mul(UP, 3)), { Count: 30, Radius: 8 });
			for (let $v1 = 0, $v2 = $arr($mc(k, "area", c, 7, 0.6, { KnockbackPower: 12, Lift: 40, Color: ORANGE })); $v1 < $v2.length; $v1++) {
				let e = $v2[$v1];
				if (e == null) break;
				$mc(k, "stun", e, 1.1, "Dizzy", PURPLE);
			}
			$mc(k, "shake", c, 0.5, 40);
			$mc(k, "later", 0.55, function () {
				$mc(k, "burst", "Confetti", $add(c, $mul(UP, 2)), { Count: 18, Radius: 6 });
				$mc(k, "area", c, 8, 0.35, { KnockbackPower: 25, Lift: 15, Color: LIME });
			});
		});
		def("SK_clown_dog_4", 4, function* (k) {
			$mc(k, "face");
			$mc(k, "sky", "Spooky", 3.2);
			$mc(k, "pose", "Summon", 2);
			let c = $mc(k, "tground");
			$mc(k, "tele", c, 13, 0.5, ORANGE);
			$mc(k, "prop", "BigTop", { Position: c, Path: "Fall", Time: 0.45, Hold: 2.3, Size: $mul(3, k.A), Impact: "Confetti", Radius: 10, Shake: 0.7, End: "Sink" });
			$mc(k, "zone", "Shadow", c, 13, 3, 0.2, { color: PURPLE });
			$mc(k, "later", 0.5, function () {
				$mc(k, "rain", "Pumpkin", $mc(k, "scatter", c, 12, 7), { fall: 0.5, gap: 0.12, radius: 4, frac: 0.04, impact: "Explode", color: ORANGE, size: 1.3 });
			});
			$mc(k, "later", 1.5, function () {
				$mc(k, "ringOut", "ClownHead", c, 2, 12, { Time: 0.7, Count: 8 });
				$mc(k, "pop", "HA HA HA!", $add(c, $mul(UP, 10)), ORANGE, 1.6);
			});
			$mc(k, "later", 2.3, function () {
				$mc(k, "fx", "Explosion", { Position: $add(c, $mul(UP, 2)), Radius: $mc(k, "R", 13), Color: ORANGE });
				$mc(k, "burst", "Confetti", $add(c, $mul(UP, 4)), { Count: 60, Radius: 14 });
				$mc(k, "shake", c, 1.2, 80);
				for (let $v3 = 0, $v4 = $arr($mc(k, "area", c, 13, 0.5, { KnockbackPower: 45, Lift: 35, Color: ORANGE })); $v3 < $v4.length; $v3++) {
					let e = $v4[$v3];
					if (e == null) break;
					$mc(k, "stun", e, 1.2, "Dizzy", ORANGE);
				}
			});
			(yield* $cy($mc(k, "wait", 1.2)));
		});
	};
}
