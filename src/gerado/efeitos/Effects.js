// Gerado automaticamente de client/Effects.lua (código do jogo Roblox) por tools/lua2js — não edite à mão.
import { $t, $a, $n, $1, $M, $mv, $lst, $get, $set, $tm, $tc, $len, $cat, $eq, $add, $sub, $mul, $div, $mod, $pow, $idiv, $unm, $mc, $cy, $sp, $sp1, $W, $WS, $ins, $ins3, $arr, $pairs, $iter, $pcallG, $warnWait } from '../../rbx/lua.js';

export default function ($G, $script) {
	let game = $G["game"], require = $G["require"], Color3 = $G["Color3"], Instance = $G["Instance"], workspace = $G["workspace"], math = $G["math"], table = $G["table"], NumberSequenceKeypoint = $G["NumberSequenceKeypoint"], NumberSequence = $G["NumberSequence"], ColorSequenceKeypoint = $G["ColorSequenceKeypoint"], ColorSequence = $G["ColorSequence"], Vector3 = $G["Vector3"], Enum = $G["Enum"], pairs = $G["pairs"], TweenInfo = $G["TweenInfo"], os = $G["os"], pcall = $G["pcall"], warn = $G["warn"], typeof$6 = $G["typeof"], NumberRange = $G["NumberRange"], Vector2 = $G["Vector2"], task = $G["task"], CFrame = $G["CFrame"], ipairs = $G["ipairs"], UDim2 = $G["UDim2"], type = $G["type"];
	const $va = [];
	let Debris = $mc(game, "GetService", "Debris");
	let Players = $mc(game, "GetService", "Players");
	let ReplicatedStorage = $mc(game, "GetService", "ReplicatedStorage");
	let RunService = $mc(game, "GetService", "RunService");
	let TweenService = $mc(game, "GetService", "TweenService");
	let Config = $sp1(require(ReplicatedStorage.Shared.Config));
	let DogData = $sp1(require(ReplicatedStorage.Shared.DogData));
	let Animator = $sp1(require($script.Parent.Animator));
	let Effects = [];
	let TEX = { Sparkle: "rbxasset://textures/particles/sparkles_main.dds", Smoke: "rbxasset://textures/particles/smoke_main.dds", Fire: "rbxasset://textures/particles/fire_main.dds", Spark: "rbxasset://textures/particles/fire_sparks_main.dds", Glow: "rbxasset://textures/particles/forcefield_glow_main.dds", Swirl: "rbxasset://textures/particles/forcefield_vortex_main.dds" };
	let C = Color3.fromRGB;
	let WHITE = Color3.new(1, 1, 1);
	let player = Players.LocalPlayer;
	let folder = Instance.new("Folder");
	folder.Name = "FX";
	folder.Parent = workspace;
	let QUALITY = { Alto: 1, "Médio": 0.6, Baixo: 0.3 };
	let quality = function () {
		return ($n($get(QUALITY, $mc(player, "GetAttribute", "GraphicsQuality"))) ?? 1);
	};
	let q = function (n) {
		return math.max(1, math.floor($add($mul(n, quality()), 0.5)));
	};
	let MAX_PARTS = 550;
	let partCount = 0;
	$mc(folder.ChildAdded, "Connect", function () {
		partCount = $add(partCount, 1);
	});
	$mc(folder.ChildRemoved, "Connect", function () {
		partCount = $sub(partCount, 1);
	});
	let crowded = function (extra) {
		return ($add(partCount, (($n(extra) ?? 0))) > $mul(MAX_PARTS, ($add(0.35, $mul(0.65, quality())))));
	};
	let lightCount = 0;
	let highlightCount = 0;
	let textCount = 0;
	let NS = function (...$va) {
		let a = [...$va];
		let kps = [];
		for (let i = 1, $v1 = $len(a); i <= $v1; i += 2) {
			$ins(kps, NumberSequenceKeypoint.new($get(a, i), $get(a, (i + 1))));
		}
		return NumberSequence.new(kps);
	};
	let CS = function (...$va) {
		let a = [...$va];
		let kps = [];
		for (let i = 1, $v2 = $len(a); i <= $v2; i += 2) {
			$ins(kps, ColorSequenceKeypoint.new($get(a, i), $get(a, (i + 1))));
		}
		return ColorSequence.new(kps);
	};
	let flat = function (v) {
		return Vector3.new(v.X, 0, v.Z);
	};
	let rnd = function (a, b) {
		return $add(a, $mul(math.random(), ($sub(b, a))));
	};
	let outCubic = function (k) {
		return $sub(1, $pow(($sub(1, k)), 3));
	};
	let fxPart = function (props) {
		let p = Instance.new("Part");
		p.Anchored = true;
		p.CanCollide = false;
		p.CanQuery = false;
		p.CanTouch = false;
		p.CastShadow = false;
		p.Material = Enum.Material.Neon;
		p.TopSurface = Enum.SurfaceType.Smooth;
		p.BottomSurface = Enum.SurfaceType.Smooth;
		for (let [k, v] of $pairs(props)) {
			$set(p, k, v);
		}
		p.Parent = folder;
		return p;
	};
	let tween = function (inst, time, goal, style, direction) {
		let tw = $mc(TweenService, "Create", inst, TweenInfo.new(time, ($n(style) ?? Enum.EasingStyle.Quad), ($n(direction) ?? Enum.EasingDirection.Out)), goal);
		$mc(tw, "Play");
		return tw;
	};
	let anims = [];
	let animate = function (duration, fn, done) {
		$ins(anims, { Start: os.clock(), Dur: math.max(duration, 0.001), Fn: fn, Done: done });
	};
	$mc(RunService.RenderStepped, "Connect", function () {
		let now = os.clock();
		for (let i = $len(anims), $v3 = 1; i >= $v3; i += (-1)) {
			let a = $get(anims, i);
			let k = math.clamp($div(($sub(now, a.Start)), a.Dur), 0, 1);
			let [ok, stop] = $lst([], pcall(a.Fn, k, $sub(now, a.Start)), 2);
			if (!$t(ok)) {
				warn("[Effects] anim", stop);
			}
			if ((((k >= 1) || (stop === true)) || !$t(ok))) {
				$set(anims, i, $get(anims, $len(anims)));
				$set(anims, $len(anims), undefined);
				if ($t(a.Done)) {
					let [okDone, err] = $lst([], pcall(a.Done), 2);
					if (!$t(okDone)) {
						warn("[Effects] anim fim", err);
					}
				}
			}
		}
	});
	let anchor = function (position, life) {
		let a = Instance.new("Attachment");
		a.Position = position;
		a.Parent = workspace.Terrain;
		$mc(Debris, "AddItem", a, life);
		return a;
	};
	let emitter = function (parent, props) {
		let e = Instance.new("ParticleEmitter");
		e.Texture = TEX.Sparkle;
		e.LightEmission = 0.8;
		e.Enabled = false;
		for (let [k, v] of $pairs(props)) {
			$set(e, k, v);
		}
		e.Parent = parent;
		return e;
	};
	let burst = function (position, color, count, size, speed, texture, extra) {
		let a = anchor(position, 3);
		let sequence = color;
		if ((typeof$6(color) === "Color3")) {
			sequence = ColorSequence.new(color);
		}
		let props = { Texture: ($n(texture) ?? TEX.Sparkle), Color: sequence, Size: NS(0, size, 1, 0), Transparency: NS(0, 0, 0.7, 0.3, 1, 1), Lifetime: NumberRange.new(0.35, 0.8), Speed: NumberRange.new($mul(speed, 0.4), speed), SpreadAngle: Vector2.new(180, 180), Drag: 4, Rotation: NumberRange.new(0, 360), RotSpeed: NumberRange.new((-120), 120) };
		if ($t(extra)) {
			for (let [k, v] of $pairs(extra)) {
				$set(props, k, v);
			}
		}
		let e = emitter(a, props);
		$mc(e, "Emit", q(count));
		return e;
	};
	let dust = function (position, color, count, size, speed) {
		burst($add(position, Vector3.new(0, 0.4, 0)), color, count, size, speed, TEX.Smoke, { Size: NS(0, $mul(size, 0.5), 1, $mul(size, 1.6)), Transparency: NS(0, 0.35, 1, 1), Lifetime: NumberRange.new(0.7, 1.3), SpreadAngle: Vector2.new(10, 180), EmissionDirection: Enum.NormalId.Right, Drag: 3, LightEmission: 0, Acceleration: Vector3.new(0, 2, 0) });
	};
	let light = function (position, color, range, duration, brightness) {
		if ((lightCount >= math.floor($add(4, $mul(8, quality()))))) {
			return;
		}
		lightCount = $add(lightCount, 1);
		let a = anchor(position, $add(duration, 0.1));
		let l = Instance.new("PointLight");
		l.Color = color;
		l.Range = math.min(range, 60);
		l.Brightness = ($n(brightness) ?? 4);
		l.Shadows = false;
		l.Parent = a;
		tween(l, duration, { Brightness: 0 });
		task.delay(duration, function () {
			lightCount = $sub(lightCount, 1);
		});
	};
	let disc = function (position, radius, color, transparency, material) {
		return fxPart({ Shape: Enum.PartType.Cylinder, Size: Vector3.new(0.12, $mul(radius, 2), $mul(radius, 2)), CFrame: $mul(CFrame.new($add(position, Vector3.new(0, 0.08, 0))), CFrame.Angles(0, 0, math.rad(90))), Color: color, Transparency: ($n(transparency) ?? 0.3), Material: ($n(material) ?? Enum.Material.Neon) });
	};
	let setDiscRadius = function (part, radius, thickness) {
		part.Size = Vector3.new(($n(thickness) ?? part.Size.X), $mul(radius, 2), $mul(radius, 2));
	};
	let flashBall = function (position, radius, color, duration) {
		let d = ($n(duration) ?? 0.25);
		let ball = fxPart({ Shape: Enum.PartType.Ball, Size: $mul($mul(Vector3.one, radius), 0.4), CFrame: CFrame.new(position), Color: color, Transparency: 0 });
		animate(d, function (k) {
			let e = outCubic(k);
			ball.Size = $mul($mul(Vector3.one, radius), ($add(0.4, $mul(1.6, e))));
			ball.Transparency = $pow(k, 0.6);
		}, function () {
			$mc(ball, "Destroy");
		});
		return ball;
	};
	let ringParts = function (n, color, material) {
		let list = [];
		for (let _ = 1, $v4 = n; _ <= $v4; _++) {
			$ins(list, fxPart({ Size: Vector3.new(0.3, 0.3, 1), Color: color, Material: ($n(material) ?? Enum.Material.Neon) }));
		}
		return list;
	};
	let placeRing = function (list, cf, radius, thick, height, spin, transparency) {
		let n = $len(list);
		let arc = $mul($div($mul($mul(2, math.pi), radius), n), 1.12);
		for (let $v5 = 0, $v6 = $arr(list); $v5 < $v6.length; $v5++) {
			let p = $v6[$v5];
			if (p == null) break;
			let i = $v5 + 1;
			let a = $add($mul($mul($div(i, n), math.pi), 2), spin);
			p.Size = Vector3.new(thick, height, math.max(0.05, arc));
			p.CFrame = $mul($mul(cf, CFrame.Angles(0, a, 0)), CFrame.new(radius, $div(height, 2), 0));
			p.Transparency = transparency;
		}
	};
	let ringWave = function (cf, r0, r1, color, duration, opts) {
		let o = ($n(opts) ?? []);
		let n = math.max(10, math.floor($mul((($n(o.Segs) ?? (($n(((r1 > 14) && 26)) ?? 18)))), ($add(0.5, $mul(0.5, quality()))))));
		let list = ringParts(n, color, o.Material);
		let thick = ($n(o.Thick) ?? math.max(0.5, $mul(r1, 0.08)));
		let height = ($n(o.Height) ?? 0.35);
		let base = ($n(o.Transparency) ?? 0.05);
		let rise = ($n(o.Rise) ?? 0);
		animate(duration, function (k) {
			let e = outCubic(k);
			placeRing(list, $mul(cf, CFrame.new(0, $mul(rise, e), 0)), $add(r0, $mul(($sub(r1, r0)), e)), $mul(thick, ($sub(1, $mul(0.75, k)))), $mul(height, ($sub(1, $mul(0.5, k)))), 0, $add(base, $mul(($sub(1, base)), $pow(k, 1.3))));
		}, function () {
			for (let $v7 = 0, $v8 = $arr(list); $v7 < $v8.length; $v7++) {
				let p = $v8[$v7];
				if (p == null) break;
				$mc(p, "Destroy");
			}
		});
	};
	let groundRing = function (position, r0, r1, color, duration, opts) {
		ringWave(CFrame.new($add(position, Vector3.new(0, 0.1, 0))), r0, r1, color, duration, opts);
	};
	let bolt = function (from, to, color, duration, width, jag) {
		let segments = math.max(3, math.floor($mul(7, ($add(0.5, $mul(0.5, quality()))))));
		let last = from;
		let length = ($sub(to, from)).Magnitude;
		for (let i = 1, $v9 = segments; i <= $v9; i++) {
			let k = $div(i, segments);
			let point = $mc(from, "Lerp", to, k);
			if ((i < segments)) {
				point = $add(point, $mul($mul(Vector3.new(rnd((-0.5), 0.5), rnd((-0.5), 0.5), rnd((-0.5), 0.5)), length), (($n(jag) ?? 0.13))));
			}
			let len = ($sub(point, last)).Magnitude;
			let cf = $mul(CFrame.lookAt(last, point), CFrame.new(0, 0, $div($unm(len), 2)));
			let glow = fxPart({ Size: Vector3.new(width, width, $add(len, $mul(width, 0.5))), CFrame: cf, Color: color, Transparency: 0.35 });
			let core = fxPart({ Size: Vector3.new($mul(width, 0.35), $mul(width, 0.35), $add(len, $mul(width, 0.2))), CFrame: cf, Color: WHITE, Transparency: 0 });
			animate(duration, function (kk) {
				glow.Transparency = $add(0.35, $mul(0.65, kk));
				core.Transparency = $pow(kk, 0.7);
			}, function () {
				$mc(glow, "Destroy");
				$mc(core, "Destroy");
			});
			last = point;
		}
	};
	Effects.Bolt = bolt;
	let spike = function (position, width, height, color, material, transparency, lean) {
		let cf = $mul($mul(CFrame.new(position), CFrame.Angles(0, $mul($mul(math.random(), math.pi), 2), 0)), CFrame.Angles($mul(rnd((-1), 1), (($n(lean) ?? 0.25))), 0, $mul(rnd((-1), 1), (($n(lean) ?? 0.25)))));
		let p = fxPart({ Shape: Enum.PartType.CornerWedge, Size: Vector3.new(width, 0.2, width), CFrame: cf, Color: color, Material: material, Transparency: transparency });
		animate(0.16, function (k) {
			let e = $sub(1, $mul($pow(($sub(1, k)), 2), ($sub(1, $mul(2.2, k)))));
			let h = math.max(0.2, $mul(height, math.min(e, 1.12)));
			p.Size = Vector3.new(width, h, width);
			p.CFrame = $mul(cf, CFrame.new(0, $sub($div(h, 2), 0.3), 0));
		});
		return p;
	};
	let shards = function (position, color, count, speed, size, material) {
		if ($t(crowded(count))) {
			return;
		}
		for (let _ = 1, $v10 = q(count); _ <= $v10; _++) {
			let s = $mul(size, rnd(0.6, 1.2));
			let p = fxPart({ Size: Vector3.new(s, $mul(s, rnd(0.6, 1.4)), s), Color: color, Material: ($n(material) ?? Enum.Material.Slate), CFrame: CFrame.new(position) });
			let v = $mul($mul(Vector3.new(rnd((-1), 1), rnd(0.8, 1.6), rnd((-1), 1)).Unit, speed), rnd(0.6, 1));
			let spin = Vector3.new(rnd((-8), 8), rnd((-8), 8), rnd((-8), 8));
			let floorY = (position.Y - 0.5);
			animate(rnd(0.7, 1), function (k, t) {
				let pos = $add($add(position, $mul(v, t)), Vector3.new(0, $mul($mul((-45), t), t), 0));
				if ((pos.Y < floorY)) {
					pos = Vector3.new(pos.X, floorY, pos.Z);
				}
				p.CFrame = $mul(CFrame.new(pos), CFrame.Angles($mul(spin.X, t), $mul(spin.Y, t), $mul(spin.Z, t)));
				if ((k > 0.6)) {
					p.Transparency = $div(($sub(k, 0.6)), 0.4);
				}
			}, function () {
				$mc(p, "Destroy");
			});
		}
	};
	let cracks = function (position, radius, color, count, duration, glow) {
		if ($t(crowded(count))) {
			return;
		}
		for (let _ = 1, $v11 = q(count); _ <= $v11; _++) {
			let a = $mul($mul(math.random(), math.pi), 2);
			let len = $mul(radius, rnd(0.5, 1));
			let dir = Vector3.new(math.cos(a), 0, math.sin(a));
			let start = $add($add(position, $mul($mul(dir, radius), 0.15)), Vector3.new(0, 0.06, 0));
			let p = fxPart({ Size: Vector3.new(rnd(0.25, 0.5), 0.08, 0.1), Color: color, Material: ($n(($a(glow) && Enum.Material.Neon)) ?? Enum.Material.Slate), Transparency: 0.1, CFrame: CFrame.lookAt(start, $add(start, dir)) });
			animate(0.18, function (k) {
				let l = $mul(len, outCubic(k));
				p.Size = Vector3.new(p.Size.X, 0.08, math.max(0.1, l));
				p.CFrame = $mul(CFrame.lookAt(start, $add(start, dir)), CFrame.new(0, 0, $div($unm(l), 2)));
			});
			task.delay(duration, function () {
				if ($t(p.Parent)) {
					tween(p, 0.8, { Transparency: 1 });
				}
			});
			$mc(Debris, "AddItem", p, $add(duration, 0.9));
		}
	};
	let scorch = function (position, radius, color, duration) {
		if ($t(crowded(1))) {
			return;
		}
		let d = disc($add(position, Vector3.new(0, 0.02, 0)), radius, ($n(color) ?? C(25, 20, 20)), 0.35, Enum.Material.SmoothPlastic);
		task.delay(($n(duration) ?? 2.5), function () {
			if ($t(d.Parent)) {
				tween(d, 1, { Transparency: 1 });
			}
		});
		$mc(Debris, "AddItem", d, $add((($n(duration) ?? 2.5)), 1.1));
		return d;
	};
	let fireEmitter = function (parent, rate, size, colorTop) {
		return emitter(parent, { Texture: TEX.Fire, Enabled: true, Rate: $mul(rate, quality()), LightEmission: 1, Color: CS(0, C(255, 245, 180), 0.35, ($n(colorTop) ?? C(255, 140, 40)), 1, C(120, 30, 10)), Size: NS(0, size, 0.5, $mul(size, 0.8), 1, $mul(size, 0.15)), Transparency: NS(0, 0.3, 0.2, 0.05, 1, 1), Lifetime: NumberRange.new(0.4, 0.8), Speed: NumberRange.new(3, 7), Acceleration: Vector3.new(0, 7, 0), SpreadAngle: Vector2.new(18, 18), EmissionDirection: Enum.NormalId.Top, Rotation: NumberRange.new(0, 360), RotSpeed: NumberRange.new((-90), 90) });
	};
	let embers = function (parent, rate, color) {
		return emitter(parent, { Texture: TEX.Spark, Enabled: true, Rate: $mul(rate, quality()), LightEmission: 1, Color: ColorSequence.new(($n(color) ?? C(255, 170, 60))), Size: NS(0, 0.35, 1, 0), Lifetime: NumberRange.new(0.6, 1.2), Speed: NumberRange.new(2, 6), Acceleration: Vector3.new(0, 4, 0), SpreadAngle: Vector2.new(40, 40), EmissionDirection: Enum.NormalId.Top });
	};
	let headOf = function (model, index) {
		return ($a(model) && (($n($mc(model, "FindFirstChild", $cat("Head", (($n(index) ?? 1))))) ?? $mc(model, "FindFirstChild", "Head1"))));
	};
	let rootOf = function (model) {
		return ($a(($a(model) && model.Parent)) && model.PrimaryPart);
	};
	let feetOf = function (model) {
		let root = rootOf(model);
		if (!$t(root)) {
			return undefined;
		}
		let hum = $mc(model, "FindFirstChildOfClass", "Humanoid");
		let hip = ($n(($a(hum) && hum.HipHeight)) ?? (($n($mc(model, "GetAttribute", "HipHeight")) ?? 2)));
		return $sub(root.Position, Vector3.new(0, $add((root.Size.Y / 2), hip), 0));
	};
	let mouthOf = function (head) {
		return $mul(head.CFrame, CFrame.new(0, ((-head.Size.Y) * 0.15), ((-head.Size.Z) * 0.75)));
	};
	let partsNamed = function (model, test) {
		let list = [];
		for (let $v12 = 0, $v13 = $arr($mc(model, "GetDescendants")); $v12 < $v13.length; $v12++) {
			let d = $v13[$v12];
			if (d == null) break;
			if (($t($mc(d, "IsA", "BasePart")) && $t($sp1(test(d.Name))))) {
				$ins(list, d);
			}
		}
		return list;
	};
	let trauma = 0;
	Effects.Shake = function (amount, _duration) {
		trauma = math.min(1.1, $add(trauma, amount));
	};
	let lastShake = os.clock();
	$mc(RunService, "BindToRenderStep", "DogShake", $add(Enum.RenderPriority.Camera.Value, 1), function () {
		let now = os.clock();
		let dt = $sub(now, lastShake);
		lastShake = now;
		if ((trauma > 0.002)) {
			let cam = workspace.CurrentCamera;
			let s = $mul(trauma, trauma);
			let t = $mul(now, 24);
			let rx = $mul($mul(math.noise(t, 1.7), s), 2.2);
			let ry = $mul($mul(math.noise(t, 9.3), s), 2.2);
			let rz = $mul($mul(math.noise(t, 17.1), s), 1.4);
			cam.CFrame = $mul(cam.CFrame, CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz)));
			trauma = math.max(0, $sub(trauma, $mul(dt, 1.5)));
		}
	});
	let shakeAt = function (position, intensity, radius, duration) {
		let cam = workspace.CurrentCamera;
		if (!$t(cam)) {
			return;
		}
		let dist = ($sub(cam.CFrame.Position, position)).Magnitude;
		let reach = $mul(radius, 1.5);
		if ((dist < reach)) {
			let falloff = math.clamp($sub(1, $div(dist, reach)), 0.15, 1);
			$sp(Effects.Shake($mul($mul(intensity, falloff), math.clamp($add(0.45, $mul((($n(duration) ?? 0.3)), 0.6)), 0.5, 1.15))));
		}
	};
	let H = [];
	let biteFlash = function (p) {
		let head = headOf(p.Model, p.Head);
		if ((!$t(head) || $t(crowded(2)))) {
			return;
		}
		task.delay(0.08, function () {
			if (!$t(head.Parent)) {
				return;
			}
			let m = $mul(mouthOf(head), CFrame.new(0, 0, ((-head.Size.Z) * 0.5)));
			let w = (head.Size.X * 1.1);
			let color = ($n(p.Color) ?? C(255, 255, 255));
			let top = fxPart({ Size: Vector3.new(w, 0.12, 0.25), Color: color, Transparency: 0.1 });
			let bottom = fxPart({ Size: Vector3.new(w, 0.12, 0.25), Color: color, Transparency: 0.1 });
			let gap = (head.Size.Y * 0.7);
			animate(0.16, function (k) {
				let g = $mul(gap, ($sub(1, outCubic(k))));
				top.CFrame = $mul($mul(m, CFrame.new(0, g, 0)), CFrame.Angles($mul(0.5, ($sub(1, k))), 0, 0));
				bottom.CFrame = $mul($mul(m, CFrame.new(0, $unm(g), 0)), CFrame.Angles($mul((-0.5), ($sub(1, k))), 0, 0));
				top.Transparency = $add(0.1, $mul(0.9, $pow(k, 2)));
				bottom.Transparency = top.Transparency;
			}, function () {
				$mc(top, "Destroy");
				$mc(bottom, "Destroy");
			});
		});
	};
	H.Bite = function (p) {
		$sp(Animator.PlayBite(p.Model, p.Head));
		biteFlash(p);
	};
	let clawSlash = function (model, side) {
		let root = rootOf(model);
		if ((!$t(root) || $t(crowded(3)))) {
			return;
		}
		task.delay(0.1, function () {
			if (!$t(root.Parent)) {
				return;
			}
			let size = root.Size;
			let cf = $mul(root.CFrame, CFrame.new($mul($mul(side, size.X), 0.15), (size.Y * 0.1), ((-size.Z) * 0.75)));
			let len = (math.max(size.X, size.Y) * 1.1);
			let parts = [];
			for (let i = (-1), $v14 = 1; i <= $v14; i++) {
				$ins(parts, [fxPart({ Size: Vector3.new(0.12, len, 0.12), Color: C(255, 255, 255), Transparency: 0.15 }), i]);
			}
			animate(0.22, function (k) {
				for (let $v15 = 0, $v16 = $arr(parts); $v15 < $v16.length; $v15++) {
					let e = $v16[$v15];
					if (e == null) break;
					let part = $get(e, 1), i = $get(e, 2);
					part.CFrame = $mul($mul(cf, CFrame.Angles(0, 0, $mul(side, 0.7))), CFrame.new($mul($mul(i, len), 0.18), $mul($mul(($sub(0.5, k)), len), 0.4), 0));
					part.Size = Vector3.new($mul(0.12, ($sub(1, $mul(k, 0.5)))), $mul(len, ($add(0.6, $mul(0.4, outCubic(k))))), 0.12);
					part.Transparency = $add(0.15, $mul(0.85, $pow(k, 2)));
				}
			}, function () {
				for (let $v17 = 0, $v18 = $arr(parts); $v17 < $v18.length; $v17++) {
					let e = $v18[$v17];
					if (e == null) break;
					$mc($get(e, 1), "Destroy");
				}
			});
		});
	};
	Effects.Melee = function (model, step, head, isLocal) {
		if (!($t(model) && $t($sp1(Animator.PlayMelee(model, step, isLocal))))) {
			return;
		}
		if ((step === 3)) {
			biteFlash({ Model: model, Head: head });
		} else {
			clawSlash(model, ($n(((step === 1) && 1)) ?? (-1)));
		}
	};
	H.Melee = function (p) {
		$sp(Effects.Melee(p.Model, p.Step, p.Head, false));
	};
	let RAINBOW_SHOT = [C(255, 70, 80), C(255, 160, 50), C(255, 230, 70), C(90, 220, 110), C(80, 170, 255), C(170, 100, 255)];
	let shotTrail = function (part, style, size) {
		let a0 = Instance.new("Attachment");
		a0.Position = Vector3.new(0, $mul(size, 0.3), 0);
		a0.Parent = part;
		let a1 = Instance.new("Attachment");
		a1.Position = Vector3.new(0, $mul($unm(size), 0.3), 0);
		a1.Parent = part;
		let trail = Instance.new("Trail");
		trail.Attachment0 = a0;
		trail.Attachment1 = a1;
		trail.Color = CS(0, ($n(style.Color2) ?? WHITE), 1, style.Color);
		trail.Transparency = NS(0, 0.15, 1, 1);
		trail.Lifetime = 0.18;
		trail.LightEmission = 1;
		trail.FaceCamera = true;
		trail.Parent = part;
		let kind = style.Trail;
		if ((kind === "Fire")) {
			fireEmitter(a0, 40, $mul(size, 1.2), style.Color);
		} else if ((kind === "Smoke")) {
			emitter(a0, { Texture: TEX.Smoke, Enabled: true, Rate: $mul(30, quality()), LightEmission: 0.2, Color: ColorSequence.new(style.Color), Size: NS(0, $mul(size, 0.6), 1, $mul(size, 1.4)), Transparency: NS(0, 0.4, 1, 1), Lifetime: NumberRange.new(0.3, 0.6), Speed: NumberRange.new(0.5, 2), SpreadAngle: Vector2.new(180, 180) });
		} else if ((kind === "Sparkle")) {
			emitter(a0, { Enabled: true, Rate: $mul(40, quality()), Color: ColorSequence.new(($n(style.Color2) ?? WHITE)), Size: NS(0, $mul(size, 0.5), 1, 0), Lifetime: NumberRange.new(0.25, 0.5), Speed: NumberRange.new(1, 4), SpreadAngle: Vector2.new(180, 180) });
		} else if ((kind === "Swirl")) {
			emitter(a0, { Texture: TEX.Swirl, Enabled: true, Rate: $mul(18, quality()), Color: ColorSequence.new(($n(style.Color2) ?? style.Color)), Size: NS(0, $mul(size, 1.2), 1, $mul(size, 0.2)), Transparency: NS(0, 0.3, 1, 1), Lifetime: NumberRange.new(0.3, 0.5), Speed: NumberRange.new(0, 1), Rotation: NumberRange.new(0, 360), RotSpeed: NumberRange.new((-300), 300) });
		}
	};
	let shotBody = function (style, size) {
		let parts = [];
		if ((style.Shape === "Shard")) {
			let p = fxPart({ Size: Vector3.new($mul(size, 0.45), $mul(size, 0.45), $mul(size, 1.6)), Color: style.Color, Transparency: 0.3 });
			$ins(parts, [p, CFrame.Angles(0, 0, math.rad(45))]);
			let core = fxPart({ Size: Vector3.new($mul(size, 0.2), $mul(size, 0.2), $mul(size, 1.2)), Color: ($n(style.Color2) ?? WHITE) });
			$ins(parts, [core, CFrame.Angles(0, 0, math.rad(45))]);
		} else if ((style.Shape === "Bone")) {
			let plastic = Enum.Material.SmoothPlastic;
			$ins(parts, [fxPart({ Size: Vector3.new($mul(size, 0.35), $mul(size, 0.35), $mul(size, 1.4)), Color: style.Color, Material: plastic }), CFrame.new()]);
			for (let $v19 = 0, $v20 = $arr([(-0.7), 0.7]); $v19 < $v20.length; $v19++) {
				let z = $v20[$v19];
				if (z == null) break;
				for (let $v21 = 0, $v22 = $arr([(-0.18), 0.18]); $v21 < $v22.length; $v21++) {
					let x = $v22[$v21];
					if (x == null) break;
					let knob = fxPart({ Shape: Enum.PartType.Ball, Size: $mul($mul(Vector3.one, size), 0.45), Color: style.Color, Material: plastic });
					$ins(parts, [knob, CFrame.new($mul(x, size), 0, $mul(z, size))]);
				}
			}
		} else {
			let bubble = (style.Bubble === true);
			let outer = fxPart({ Shape: Enum.PartType.Ball, Size: $mul(Vector3.one, size), Color: style.Color, Material: ($n(($a(bubble) && Enum.Material.Glass)) ?? Enum.Material.Neon), Transparency: ($n(($a(bubble) && 0.4)) ?? 0.3) });
			$ins(parts, [outer, CFrame.new()]);
			let core = fxPart({ Shape: Enum.PartType.Ball, Size: $mul($mul(Vector3.one, size), 0.55), Color: ($n(style.Color2) ?? WHITE), Transparency: ($n(($a(bubble) && 0.5)) ?? 0) });
			$ins(parts, [core, CFrame.new()]);
		}
		return parts;
	};
	let shotImpact = function (position, style, size, big, targetModel) {
		let color = style.Color;
		let color2 = ($n(style.Color2) ?? WHITE);
		flashBall(position, $mul(2, size), color, 0.2);
		light(position, color, ($n(($a(big) && 20)) ?? 12), 0.3);
		burst(position, color, ($n(($a(big) && 20)) ?? 10), $mul(0.9, size), 16);
		let kind = style.Impact;
		if ((kind === "Explode")) {
			burst(position, CS(0, C(255, 240, 180), 0.4, color2, 1, color), ($n(($a(big) && 18)) ?? 10), $mul(1.4, size), 14, TEX.Fire, { LightEmission: 1 });
			dust(position, C(90, 80, 70), ($n(($a(big) && 8)) ?? 4), 2, 10);
			ringWave(CFrame.new(position), 0.5, $mul((($n(($a(big) && 7)) ?? 4)), size), color2, 0.35);
			shakeAt(position, ($n(($a(big) && 0.35)) ?? 0.15), 25, 0.15);
		} else if ((kind === "Shatter")) {
			shards(position, color, ($n(($a(big) && 7)) ?? 4), 16, $mul(0.35, size), ($n(((style.Shape === "Bone") && Enum.Material.SmoothPlastic)) ?? Enum.Material.Ice));
		} else if ((kind === "Splash")) {
			burst(position, color, ($n(($a(big) && 14)) ?? 8), $mul(1.2, size), 10, TEX.Smoke, { LightEmission: 0.3 });
			let feet = feetOf(targetModel);
			if (($t(feet) && !$t(crowded(2)))) {
				let puddle = disc(feet, $mul((($n(($a(big) && 3.5)) ?? 2.2)), size), color, 0.25);
				animate(1.6, function (k) {
					puddle.Transparency = $add(0.25, $mul(0.75, $pow(k, 2)));
				}, function () {
					$mc(puddle, "Destroy");
				});
			}
		} else if ((kind === "Pop")) {
			let seq = [];
			for (let $v23 = 0, $v24 = $arr(RAINBOW_SHOT); $v23 < $v24.length; $v23++) {
				let c = $v24[$v23];
				if (c == null) break;
				let i = $v23 + 1;
				$ins(seq, ColorSequenceKeypoint.new((((i - 1)) / (($len(RAINBOW_SHOT) - 1))), c));
			}
			burst(position, ColorSequence.new(seq), ($n(($a(big) && 26)) ?? 16), 0.6, 22, undefined, { Shape: Enum.ParticleEmitterShape.Sphere });
			ringWave(CFrame.new(position), 0.3, $mul(3, size), WHITE, 0.25);
		}
	};
	H.MouthShot = function (p) {
		let style = $get(DogData.SHOT_STYLES, p.Style);
		if ((!$t(style) || !$t(p.Model))) {
			return;
		}
		$sp(Animator.PlayBite(p.Model, p.Head));
		let head = headOf(p.Model, p.Head);
		let root = rootOf(p.Model);
		let from = ($n((($a(($a(head) && head.Parent)) && mouthOf(head).Position))) ?? (($a(root) && root.Position)));
		if (!$t(from)) {
			return;
		}
		let targetRoot = rootOf(p.Target);
		let lastGoal = ($n(p.To) ?? from);
		let goal = function () {
			if (($t(targetRoot) && $t(targetRoot.Parent))) {
				lastGoal = targetRoot.Position;
			}
			return lastGoal;
		};
		let big = (p.Big === true);
		let size = $mul((($n(style.Size) ?? 1)), (($n(($a(big) && 1.7)) ?? 1)));
		let travel = math.max(0.05, ($n(p.Time) ?? 0.2));
		flashBall(from, $mul(1.1, size), style.Color, 0.15);
		if (((style.Shape === "Beam") || (style.Shape === "Bolt"))) {
			let to = goal();
			if ((style.Shape === "Bolt")) {
				bolt(from, to, style.Color, 0.25, $mul(0.45, size));
			} else {
				let len = ($sub(to, from)).Magnitude;
				let cf = $mul(CFrame.lookAt(from, to), CFrame.new(0, 0, $div($unm(len), 2)));
				let w = $mul(0.6, size);
				let glow = fxPart({ Size: Vector3.new(w, w, len), CFrame: cf, Color: style.Color, Transparency: 0.3 });
				let core = fxPart({ Size: Vector3.new($mul(w, 0.35), $mul(w, 0.35), len), CFrame: cf, Color: ($n(style.Color2) ?? WHITE), Transparency: 0 });
				animate(0.25, function (k, t) {
					if ($t(style.Rainbow)) {
						glow.Color = $get(RAINBOW_SHOT, ($mod(math.floor($mul(t, 30)), $len(RAINBOW_SHOT)) + 1));
					}
					let thin = $sub(1, $mul(0.7, k));
					glow.Size = Vector3.new($mul(w, thin), $mul(w, thin), len);
					glow.Transparency = $add(0.3, $mul(0.7, k));
					core.Transparency = $pow(k, 0.7);
				}, function () {
					$mc(glow, "Destroy");
					$mc(core, "Destroy");
				});
			}
			shotImpact(to, style, size, big, p.Target);
			return;
		}
		let count = ($n(style.Count) ?? 1);
		for (let i = 1, $v25 = count; i <= $v25; i++) {
			task.delay((((i - 1)) * 0.07), function () {
				let start = from;
				let spread = ($n(((count > 1) && rnd((-1.6), 1.6))) ?? 0);
				if ($t(crowded(6))) {
					task.delay(travel, function () {
						shotImpact(goal(), style, size, big, p.Target);
					});
					return;
				}
				let parts;
				if ((style.Shape === "Wave")) {
					parts = [];
					for (let $v26 = 0, $v27 = $arr(ringParts(12, style.Color)); $v26 < $v27.length; $v26++) {
						let part = $v27[$v26];
						if (part == null) break;
						$ins(parts, [part, CFrame.new()]);
					}
				} else {
					parts = shotBody(style, size);
					shotTrail($get($get(parts, 1), 1), style, size);
				}
				let dir = ($sub(goal(), start)).Unit;
				animate(travel, function (k, t) {
					let g = goal();
					let side = Vector3.new((-dir.Z), 0, dir.X);
					let pos = $add($add($mc(start, "Lerp", g, k), Vector3.new(0, $mul($mul($mul((($n(style.Arc) ?? 0)), 4), k), ($sub(1, k))), 0)), $mul($mul(side, spread), math.sin($mul(k, math.pi))));
					let delta = $sub(g, pos);
					if ((delta.Magnitude > 0.2)) {
						dir = delta.Unit;
					}
					let base = CFrame.lookAt(pos, $add(pos, dir));
					if ((style.Shape === "Wave")) {
						let list = [];
						for (let $v28 = 0, $v29 = $arr(parts); $v28 < $v29.length; $v28++) {
							let entry = $v29[$v28];
							if (entry == null) break;
							$ins(list, $get(entry, 1));
						}
						placeRing(list, $mul(base, CFrame.Angles(math.rad(90), 0, 0)), $mul(($add(0.6, $mul(1.6, k))), size), 0.25, 0.3, $mul(t, 4), $add(0.1, $mul(0.5, k)));
						return;
					}
					let spin = ($n(((style.Shape === "Bone") && CFrame.Angles($mul(t, 14), 0, 0))) ?? CFrame.Angles(0, 0, $mul(t, 10)));
					for (let $v30 = 0, $v31 = $arr(parts); $v30 < $v31.length; $v30++) {
						let entry = $v31[$v30];
						if (entry == null) break;
						$get(entry, 1).CFrame = $mul($mul(base, spin), $get(entry, 2));
					}
				}, function () {
					for (let $v32 = 0, $v33 = $arr(parts); $v32 < $v33.length; $v32++) {
						let entry = $v33[$v32];
						if (entry == null) break;
						$mc($get(entry, 1), "Destroy");
					}
					if ((i === 1)) {
						shotImpact(goal(), style, size, big, p.Target);
					} else {
						burst(goal(), style.Color, 6, $mul(0.7, size), 12);
					}
				});
			});
		}
	};
	H.Hit = function (p) {
		let model = p.Model;
		let root = rootOf(model);
		if (!$t(root)) {
			return;
		}
		if ((highlightCount < 6)) {
			highlightCount = $add(highlightCount, 1);
			let hl = Instance.new("Highlight");
			hl.Name = "HitFlash";
			hl.FillColor = WHITE;
			hl.FillTransparency = 0.15;
			hl.OutlineColor = WHITE;
			hl.OutlineTransparency = 0.4;
			hl.DepthMode = Enum.HighlightDepthMode.Occluded;
			hl.Parent = model;
			tween(hl, 0.2, { FillTransparency: 1, OutlineTransparency: 1 });
			task.delay(0.22, function () {
				highlightCount = $sub(highlightCount, 1);
				$mc(hl, "Destroy");
			});
		}
		burst($add(root.Position, Vector3.new(0, (root.Size.Y * 0.3), 0)), C(255, 250, 220), 6, 0.6, 22, TEX.Spark, { Lifetime: NumberRange.new(0.12, 0.3), Drag: 6 });
		if ($eq($mc(model, "GetAttribute", "Owner"), player.UserId)) {
			$sp(Effects.Shake(0.12));
		}
	};
	let floatingLabel = function (position, life, size) {
		let a = anchor(position, $add(life, 0.1));
		let gui = Instance.new("BillboardGui");
		gui.Size = UDim2.fromOffset(size.X, size.Y);
		gui.AlwaysOnTop = true;
		gui.LightInfluence = 0;
		gui.MaxDistance = 160;
		gui.Parent = a;
		return $M(a, gui);
	};
	let styledText = function (parent, text, color, strokeColor, font) {
		let label = Instance.new("TextLabel");
		label.Size = UDim2.fromScale(1, 1);
		label.BackgroundTransparency = 1;
		label.Text = text;
		label.TextColor3 = WHITE;
		label.TextScaled = true;
		label.Font = ($n(font) ?? Enum.Font.LuckiestGuy);
		label.Parent = parent;
		let gradient = Instance.new("UIGradient");
		gradient.Color = CS(0, $mc(WHITE, "Lerp", color, 0.25), 0.55, color, 1, $mc(color, "Lerp", Color3.new(0, 0, 0), 0.25));
		gradient.Rotation = 90;
		gradient.Parent = label;
		let stroke = Instance.new("UIStroke");
		stroke.Color = strokeColor;
		stroke.Thickness = 2.5;
		stroke.Parent = label;
		let scale = Instance.new("UIScale");
		scale.Scale = 0.2;
		scale.Parent = label;
		return $M(label, stroke, scale);
	};
	let floatingText = function (position, text, color, size, rise, font) {
		if ((textCount > 30)) {
			return;
		}
		textCount = $add(textCount, 1);
		let life = 1.1;
		let start = $add(position, Vector3.new(rnd((-1), 1), 0, rnd((-1), 1)));
		let [a, gui] = $lst([], floatingLabel(start, life, Vector2.new($mul(size, 5), size)), 2);
		let [label, stroke, scale] = $lst([], styledText(gui, text, color, Color3.fromRGB(30, 20, 30), font), 3);
		animate(life, function (k) {
			a.Position = $add(start, Vector3.new(0, $mul((($n(rise) ?? 4)), outCubic(k)), 0));
			scale.Scale = ($n(((k < 0.15) && $add(0.2, $mul(($div(k, 0.15)), 1)))) ?? (1.2 - (math.min(1, $div(($sub(k, 0.15)), 0.15)) * 0.2)));
			let fade = math.clamp($div(($sub(k, 0.6)), 0.4), 0, 1);
			label.TextTransparency = fade;
			stroke.Transparency = fade;
		}, function () {
			textCount = $sub(textCount, 1);
		});
	};
	H.Damage = function (p) {
		if ((textCount > 30)) {
			return;
		}
		textCount = $add(textCount, 1);
		let crit = (p.Crit === true);
		let text = ($n(((type(p.Amount) === "string") && p.Amount)) ?? undefined);
		let amount = ($n(((type(p.Amount) === "number") && p.Amount)) ?? 0);
		let color = ($n(p.Color) ?? (($n(($a(crit) && C(255, 190, 40))) ?? WHITE)));
		let size = ($n(($a(crit) && 64)) ?? math.clamp((28 + (math.log10($add(amount, 1)) * 5)), 28, 48));
		let life = ($n(($a(crit) && 1.3)) ?? 0.95);
		let side = $mul((($n(((math.random() < 0.5) && (-1))) ?? 1)), rnd(1.2, 2.6));
		let cam = workspace.CurrentCamera;
		let right = ($n(($a(cam) && cam.CFrame.RightVector)) ?? Vector3.new(1, 0, 0));
		let start = $add(p.Position, Vector3.new(0, 0.5, 0));
		let [a, gui] = $lst([], floatingLabel(start, life, Vector2.new($mul(size, 4), $mul(size, (($n(($a(crit) && 1.6)) ?? 1))))), 2);
		let holder = Instance.new("Frame");
		holder.BackgroundTransparency = 1;
		holder.Size = UDim2.fromScale(1, ($n(($a(crit) && 0.62)) ?? 1));
		holder.Position = UDim2.fromScale(0, ($n(($a(crit) && 0.38)) ?? 0));
		holder.Parent = gui;
		let [label, stroke, scale] = $lst([], styledText(holder, ($n(text) ?? $sp1(Config.Format(amount))), color, ($n(($a(crit) && C(90, 20, 10))) ?? Color3.fromRGB(25, 20, 30)), Enum.Font.LuckiestGuy), 3);
		label.Rotation = rnd((-8), 8);
		let tag, tagStroke, tagScale;
		if ($t(crit)) {
			let tagHolder = Instance.new("Frame");
			tagHolder.BackgroundTransparency = 1;
			tagHolder.Size = UDim2.fromScale(1, 0.4);
			tagHolder.Parent = gui;
			const $v34 = $lst([], styledText(tagHolder, "CRITICAL!", C(255, 90, 60), C(60, 10, 10), Enum.Font.LuckiestGuy), 3);
			tag = $v34[0];
			tagStroke = $v34[1];
			tagScale = $v34[2];
			burst(start, C(255, 210, 80), 14, 1.1, 26, TEX.Sparkle);
			flashBall(start, 1.5, C(255, 230, 120), 0.18);
		}
		animate(life, function (k) {
			let e = outCubic(k);
			a.Position = $add($add(start, $mul($mul(right, side), e)), Vector3.new(0, $sub((3.2 * math.sin($mul($mul(math.min(1, $mul(k, 1.6)), math.pi), 0.5))), $mul($mul(k, k), 1.2)), 0));
			let s;
			if ((k < 0.1)) {
				s = $add(0.2, $mul(($div(k, 0.1)), 1.15));
			} else if ((k < 0.22)) {
				s = $sub(1.35, $mul(($div(($sub(k, 0.1)), 0.12)), 0.35));
			} else {
				s = 1;
			}
			scale.Scale = s;
			if ($t(crit)) {
				label.Rotation = $mul((math.sin($mul(k, 60)) * 6), ($sub(1, k)));
			}
			let fade = math.clamp($div(($sub(k, 0.62)), 0.38), 0, 1);
			label.TextTransparency = fade;
			stroke.Transparency = fade;
			if ($t(tag)) {
				tag.TextTransparency = fade;
				tagStroke.Transparency = fade;
				tagScale.Scale = $mul(s, 0.9);
			}
		}, function () {
			textCount = $sub(textCount, 1);
		});
	};
	H.XP = function (p) {
		floatingText(p.Position, $cat("+", $cat(p.Amount, " XP")), Color3.fromRGB(120, 230, 255), 30, 5);
	};
	H.Cash = function (p) {
		if ($eq(p.Player, player.UserId)) {
			floatingText(p.Position, $cat("+$", $sp1(Config.Format(p.Amount))), Color3.fromRGB(120, 255, 120), 40, 6);
			burst(p.Position, Color3.fromRGB(120, 255, 120), 15, 0.8, 12);
		}
	};
	H.LevelUp = function (p) {
		let root = rootOf(p.Model);
		if (!$t(root)) {
			return;
		}
		floatingText($add(root.Position, Vector3.new(0, (root.Size.Y + 3), 0)), "LEVEL UP!", Color3.fromRGB(255, 220, 60), 46, 6);
		burst(root.Position, Color3.fromRGB(255, 230, 100), 40, 1.2, 20);
		let feet = ($n(feetOf(p.Model)) ?? root.Position);
		groundRing(feet, 1, 9, C(255, 220, 80), 0.6);
		light(root.Position, C(255, 220, 80), 16, 0.6);
	};
	H.SpecialName = function (p) {
		let root = rootOf(p.Model);
		let info = $get(DogData.Specials, p.Name);
		if (!($t(root) && $t(info))) {
			return;
		}
		floatingText($add(root.Position, Vector3.new(0, (root.Size.Y + 4), 0)), $cat("✦ ", $cat(info.Name, " ✦")), Color3.fromRGB(255, 200, 255), 34, 3, Enum.Font.FredokaOne);
		let feet = feetOf(p.Model);
		if ($t(feet)) {
			groundRing(feet, (root.Size.Z * 0.6), ((root.Size.Z * 1.6) + 3), C(255, 230, 255), 0.45, { Thick: 0.35, Height: 0.15 });
		}
	};
	H.Shake = function (p) {
		shakeAt(p.Position, ($n(p.Intensity) ?? 0.5), ($n(p.Radius) ?? 50), p.Duration);
	};
	H.Shockwave = function (p) {
		let pos = p.Position;
		let r = ($n(p.Radius) ?? 8);
		let color = ($n(p.Color) ?? C(235, 220, 190));
		groundRing(pos, 1, r, color, 0.45, { Thick: math.max(0.5, $mul(r, 0.09)), Height: ($n(($a(p.Thick) && 1.6)) ?? 0.5) });
		let flashDisc = disc(pos, $mul(r, 0.45), color, 0.3);
		animate(0.3, function (k) {
			setDiscRadius(flashDisc, $mul(r, ($add(0.45, $mul(0.4, k)))));
			flashDisc.Transparency = $add(0.3, $mul(0.7, k));
		}, function () {
			$mc(flashDisc, "Destroy");
		});
		dust(pos, $mc(color, "Lerp", C(150, 130, 110), 0.5), math.floor($add(10, r)), $add(2, $mul(r, 0.12)), $add(10, r));
		if ($t(p.Thick)) {
			shards($add(pos, Vector3.new(0, 0.5, 0)), C(120, 100, 80), 8, 30, 0.7);
			cracks(pos, $mul(r, 0.7), C(60, 45, 35), 7, 2);
		}
	};
	H.Roar = function (p) {
		let head = headOf(p.Model);
		if (!$t(head)) {
			return;
		}
		let color = ($n(p.Color) ?? WHITE);
		for (let i = 0, $v35 = 3; i <= $v35; i++) {
			task.delay((i * 0.13), function () {
				if (!$t(head.Parent)) {
					return;
				}
				let m = mouthOf(head);
				let cf;
				if ($t(p.Howl)) {
					cf = CFrame.new($add(m.Position, Vector3.new(0, 0.6, 0)));
				} else {
					cf = $mul(m, CFrame.Angles(math.rad((-90)), 0, 0));
				}
				ringWave(cf, 0.8, (6 + (i * 1.5)), color, 0.55, { Thick: 0.35, Height: 0.35, Rise: 6, Segs: 14 });
			});
		}
		let m = mouthOf(head);
		burst(m.Position, color, 12, 0.9, 16, TEX.Smoke, { EmissionDirection: Enum.NormalId.Front, SpreadAngle: Vector2.new(25, 25), Size: NS(0, 0.6, 1, 2.5), Transparency: NS(0, 0.5, 1, 1), LightEmission: 0.4 });
		shakeAt(head.Position, 0.18, 30, 0.4);
	};
	H.Telegraph = function (p) {
		let pos = p.Position;
		let r = ($n(p.Radius) ?? 8);
		let dur = ($n(p.Duration) ?? 0.8);
		let color = ($n(p.Color) ?? C(255, 80, 60));
		let base = disc(pos, r, color, 0.82);
		let fill = disc($add(pos, Vector3.new(0, 0.02, 0)), 0.1, color, 0.55);
		let n = math.max(12, math.floor($mul(r, 2)));
		let edge = ringParts(math.floor($mul(n, ($add(0.5, $mul(0.5, quality()))))), color);
		let edgeCF = CFrame.new($add(pos, Vector3.new(0, 0.1, 0)));
		animate(dur, function (k, t) {
			setDiscRadius(fill, math.max(0.1, $mul(r, k)));
			placeRing(edge, edgeCF, r, 0.3, (0.2 + (0.15 * math.sin($mul(t, 18)))), $mul(t, 0.6), 0.2);
		}, function () {
			$mc(base, "Destroy");
			$mc(fill, "Destroy");
			for (let $v36 = 0, $v37 = $arr(edge); $v36 < $v37.length; $v36++) {
				let e = $v37[$v36];
				if (e == null) break;
				$mc(e, "Destroy");
			}
		});
	};
	H.Impact = function (p) {
		let pos = p.Position;
		let r = ($n(p.Radius) ?? 6);
		let color = ($n(p.Color) ?? C(240, 225, 200));
		flashBall($add(pos, Vector3.new(0, 1, 0)), $mul(r, 0.6), $mc(WHITE, "Lerp", color, 0.4), 0.22);
		groundRing(pos, 1, $mul(r, 1.2), color, 0.4, { Thick: 0.6, Height: 0.6 });
		burst($add(pos, Vector3.new(0, 1, 0)), color, 16, 0.8, 30, TEX.Spark, { Lifetime: NumberRange.new(0.2, 0.45), Drag: 5 });
		dust(pos, C(170, 150, 120), $add(10, r), 2.5, 14);
		light($add(pos, Vector3.new(0, 2, 0)), color, $mul(r, 3), 0.35);
		if ($t(p.Heavy)) {
			shards(pos, C(120, 100, 80), 6, 26, 0.6);
			cracks(pos, r, C(60, 45, 35), 6, 1.8);
		}
		shakeAt(pos, math.clamp($div(r, 18), 0.15, 0.7), $add(40, $mul(r, 2)), 0.3);
	};
	H.Streak = function (p) {
		let root = rootOf(p.Model);
		if (!$t(root)) {
			return;
		}
		let w = $mul((($n(p.Width) ?? 1.5)), math.max(1, (root.Size.Y * 0.4)));
		let life = ($n(p.Lifetime) ?? 0.3);
		let a0 = Instance.new("Attachment");
		a0.Position = Vector3.new(0, $div(w, 2), 0);
		a0.Parent = root;
		let a1 = Instance.new("Attachment");
		a1.Position = Vector3.new(0, $div($unm(w), 2), 0);
		a1.Parent = root;
		let tr = Instance.new("Trail");
		tr.Attachment0 = a0;
		tr.Attachment1 = a1;
		tr.Color = CS(0, WHITE, 0.3, p.Color, 1, p.Color);
		tr.Transparency = NS(0, ($n(($a(p.Neon) && 0.05)) ?? 0.35), 1, 1);
		tr.WidthScale = NS(0, 1, 1, 0.2);
		tr.Lifetime = life;
		tr.LightEmission = ($n(($a(p.Neon) && 1)) ?? 0.3);
		tr.FaceCamera = true;
		tr.MinLength = 0.05;
		tr.Parent = root;
		let dur = ($n(p.Duration) ?? 0.5);
		task.delay(dur, function () {
			tr.Enabled = false;
		});
		$mc(Debris, "AddItem", tr, $add($add(dur, life), 0.1));
		$mc(Debris, "AddItem", a0, $add($add(dur, life), 0.1));
		$mc(Debris, "AddItem", a1, $add($add(dur, life), 0.1));
		if ($t(p.Sparks)) {
			let e = emitter(a1, { Texture: TEX.Spark, Enabled: true, Rate: $mul(40, quality()), Color: ColorSequence.new(p.Color), LightEmission: 1, Size: NS(0, 0.5, 1, 0), Lifetime: NumberRange.new(0.2, 0.4), Speed: NumberRange.new(2, 6), SpreadAngle: Vector2.new(180, 180) });
			task.delay(dur, function () {
				e.Enabled = false;
			});
		}
	};
	H.Trail = function (p) {
		let diff = $sub(p.To, p.From);
		let len = diff.Magnitude;
		if ((len < 0.5)) {
			return;
		}
		let w = ($n(p.Width) ?? 1);
		let cf = $mul(CFrame.lookAt(p.From, p.To), CFrame.new(0, 0, $div($unm(len), 2)));
		let streak = fxPart({ Size: Vector3.new(w, $mul(w, 0.5), len), CFrame: cf, Color: p.Color, Transparency: ($n(($a(p.Neon) && 0.15)) ?? 0.5) });
		let core = fxPart({ Size: Vector3.new($mul(w, 0.3), $mul(w, 0.15), len), CFrame: cf, Color: WHITE, Transparency: 0.1 });
		let dur = ($n(p.Duration) ?? 0.4);
		animate(dur, function (k) {
			streak.Size = Vector3.new($mul(w, ($sub(1, $mul(k, 0.9)))), $mul($mul(w, 0.5), ($sub(1, $mul(k, 0.9)))), len);
			streak.Transparency = $add((($n(($a(p.Neon) && 0.15)) ?? 0.5)), $mul(0.85, k));
			core.Transparency = $add(0.1, $mul(0.9, k));
		}, function () {
			$mc(streak, "Destroy");
			$mc(core, "Destroy");
		});
	};
	H.ThunderCharge = function (p) {
		let model = p.Model;
		let root = rootOf(model);
		if (!$t(root)) {
			return;
		}
		let color = ($n(p.Color) ?? C(130, 220, 255));
		let dur = ($n(p.Duration) ?? 1);
		let paws = partsNamed(model, function (n) {
			return (n === "Pata");
		});
		if (($len(paws) === 0)) {
			paws = partsNamed(model, function (n) {
				return ($1($mc(n, "match", "^Leg")) != null);
			});
		}
		let emitters = [];
		for (let $v38 = 0, $v39 = $arr(paws); $v38 < $v39.length; $v38++) {
			let part = $v39[$v38];
			if (part == null) break;
			$ins(emitters, emitter(part, { Texture: TEX.Spark, Color: CS(0, WHITE, 1, color), Rate: $mul(30, quality()), Enabled: true, LightEmission: 1, Size: NS(0, 0.5, 1, 0), Lifetime: NumberRange.new(0.12, 0.28), Speed: NumberRange.new(5, 12), SpreadAngle: Vector2.new(180, 180) }));
		}
		let feet = ($n(feetOf(model)) ?? root.Position);
		let glow = disc(feet, 0.5, color, 0.5);
		let l = Instance.new("PointLight");
		l.Color = color;
		l.Range = 10;
		l.Brightness = 0;
		l.Shadows = false;
		l.Parent = root;
		let nextArc = 0;
		animate(dur, function (k, t) {
			if (!$t(root.Parent)) {
				return true;
			}
			let f = ($n(feetOf(model)) ?? feet);
			glow.CFrame = $mul(CFrame.new($add(f, Vector3.new(0, 0.1, 0))), CFrame.Angles(0, 0, math.rad(90)));
			setDiscRadius(glow, $add(1, $mul((root.Size.Z * 0.9), k)));
			glow.Transparency = $add($sub(0.75, $mul(0.35, k)), (math.sin($mul(t, 40)) * 0.08));
			l.Brightness = $add(1, $mul(4, k));
			if (((t >= nextArc) && ($len(paws) > 0))) {
				nextArc = $add(t, $div(0.05, quality()));
				let part = $get(paws, math.random(1, $len(paws)));
				let a = part.Position;
				bolt(a, $add(a, $mul(Vector3.new(rnd((-1), 1), rnd(0.3, 1.4), rnd((-1), 1)), ($add(2, $mul(2, k))))), color, 0.08, $add(0.15, $mul(0.1, k)), 0.3);
			}
			return undefined;
		}, function () {
			for (let $v40 = 0, $v41 = $arr(emitters); $v40 < $v41.length; $v40++) {
				let e = $v41[$v40];
				if (e == null) break;
				$mc(e, "Destroy");
			}
			$mc(glow, "Destroy");
			$mc(l, "Destroy");
		});
	};
	H.Sparks = H.ThunderCharge;
	H.ThunderDash = function (p) {
		let from = p.From, to = p.To;
		let color = ($n(p.Color) ?? C(150, 230, 255));
		bolt($add(from, Vector3.new(0, 1.2, 0)), $add(to, Vector3.new(0, 1.2, 0)), color, 0.35, 0.9, 0.04);
		bolt($add(from, Vector3.new(0, 1.6, 0)), $add(to, Vector3.new(0, 1, 0)), WHITE, 0.2, 0.3, 0.07);
		$sp(H.Trail({ From: $add(from, Vector3.new(0, 1, 0)), To: $add(to, Vector3.new(0, 1, 0)), Color: color, Width: 2.2, Duration: 0.5, Neon: true }));
		let dir = flat($sub(to, from));
		let len = dir.Magnitude;
		if (((len > 1) && !$t(crowded(4)))) {
			let mark = fxPart({ Size: Vector3.new(1.4, 0.06, len), CFrame: $mul(CFrame.lookAt(from, $add(from, dir)), CFrame.new(0, (-0.9), $div($unm(len), 2))), Color: C(30, 40, 60), Material: Enum.Material.SmoothPlastic, Transparency: 0.4 });
			task.delay(1.2, function () {
				if ($t(mark.Parent)) {
					tween(mark, 0.8, { Transparency: 1 });
				}
			});
			$mc(Debris, "AddItem", mark, 2.1);
		}
		for (let k = 1, $v42 = q(5); k <= $v42; k++) {
			burst($add($mc(from, "Lerp", to, (k / 5)), Vector3.new(0, 1, 0)), color, 4, 0.6, 14, TEX.Spark);
		}
		light($add(to, Vector3.new(0, 2, 0)), color, 20, 0.3);
	};
	H.Lightning = function (p) {
		let ground = p.Position;
		let color = ($n(p.Color) ?? C(160, 230, 255));
		let big = (p.Big !== false);
		let sky = $add(ground, Vector3.new(rnd((-5), 5), 70, rnd((-5), 5)));
		bolt(sky, ground, color, 0.4, ($n(($a(big) && 1.6)) ?? 1), 0.12);
		bolt($add(sky, Vector3.new(rnd((-3), 3), 0, rnd((-3), 3))), $add(ground, Vector3.new(rnd((-2), 2), 0, rnd((-2), 2))), WHITE, 0.25, 0.45, 0.15);
		for (let _ = 1, $v43 = q(3); _ <= $v43; _++) {
			let mid = $mc(sky, "Lerp", ground, rnd(0.3, 0.7));
			bolt(mid, $add(mid, Vector3.new(rnd((-10), 10), rnd((-14), (-6)), rnd((-10), 10))), color, 0.25, 0.35, 0.2);
		}
		let col = fxPart({ Shape: Enum.PartType.Cylinder, Size: Vector3.new(60, 5, 5), CFrame: $mul(CFrame.new($add(ground, Vector3.new(0, 30, 0))), CFrame.Angles(0, 0, math.rad(90))), Color: color, Transparency: 0.5 });
		animate(0.3, function (k) {
			col.Size = Vector3.new(60, $add($mul(5, ($sub(1, k))), 0.2), $add($mul(5, ($sub(1, k))), 0.2));
			col.Transparency = $add(0.5, $mul(0.5, k));
		}, function () {
			$mc(col, "Destroy");
		});
		flashBall($add(ground, Vector3.new(0, 1, 0)), 4, WHITE, 0.2);
		light($add(ground, Vector3.new(0, 5, 0)), color, 50, 0.6, 8);
		burst($add(ground, Vector3.new(0, 1, 0)), color, 30, 1, 40, TEX.Spark, { Lifetime: NumberRange.new(0.25, 0.6), Acceleration: Vector3.new(0, (-30), 0) });
		groundRing(ground, 1, ($n(($a(big) && 16)) ?? 10), color, 0.45, { Thick: 0.8, Height: 0.4 });
		scorch(ground, ($n(($a(big) && 4)) ?? 2.5), C(20, 25, 35), 2);
		cracks(ground, ($n(($a(big) && 7)) ?? 4), color, ($n(($a(big) && 6)) ?? 4), 1.2, true);
		shakeAt(ground, ($n(($a(big) && 0.55)) ?? 0.35), 60, 0.3);
	};
	H.EyeGlow = function (p) {
		let model = p.Model;
		let root = rootOf(model);
		if (!$t(root)) {
			return;
		}
		let color = ($n(p.Color) ?? WHITE);
		let dur = ($n(p.Duration) ?? 0.5);
		let hosts = [];
		if ($t(p.Body)) {
			$ins(hosts, ($n($mc(model, "FindFirstChild", "Torso")) ?? root));
		} else {
			let heads = ($n(($a(p.All) && (($n($mc(model, "GetAttribute", "Heads")) ?? 1)))) ?? 1);
			for (let i = 1, $v44 = heads; i <= $v44; i++) {
				let h = headOf(model, i);
				if ($t(h)) {
					$ins(hosts, h);
				}
			}
		}
		let list = [];
		for (let $v45 = 0, $v46 = $arr(hosts); $v45 < $v46.length; $v45++) {
			let host = $v46[$v45];
			if (host == null) break;
			let att = Instance.new("Attachment");
			att.Position = ($n(($a(p.Body) && Vector3.zero)) ?? Vector3.new(0, (host.Size.Y * 0.12), ((-host.Size.Z) * 0.45)));
			att.Parent = host;
			let e = emitter(att, { Texture: TEX.Glow, Enabled: true, Rate: $mul(18, quality()), LightEmission: 1, Color: ColorSequence.new(color), Size: NS(0, ($n(($a(p.Body) && 3)) ?? 1.2), 1, 0), Transparency: NS(0, 0.3, 1, 1), Lifetime: NumberRange.new(0.15, 0.3), Speed: NumberRange.new(0, 0.5), LockedToPart: true });
			let l = Instance.new("PointLight");
			l.Color = color;
			l.Range = ($n(($a(p.Body) && 16)) ?? 8);
			l.Brightness = 0;
			l.Shadows = false;
			l.Parent = att;
			$ins(list, [att, e, l]);
		}
		burst(($n(($a($get(hosts, 1)) && $get(hosts, 1).Position)) ?? root.Position), color, 6, 0.7, 6, TEX.Sparkle);
		animate(dur, function (k, t) {
			for (let $v47 = 0, $v48 = $arr(list); $v47 < $v48.length; $v47++) {
				let entry = $v48[$v47];
				if (entry == null) break;
				$get(entry, 3).Brightness = $mul(($add(2, $mul(3, k))), ((0.85 + (0.15 * math.sin($mul(t, 30))))));
			}
		}, function () {
			for (let $v49 = 0, $v50 = $arr(list); $v49 < $v50.length; $v49++) {
				let entry = $v50[$v49];
				if (entry == null) break;
				$get(entry, 2).Enabled = false;
				$get(entry, 3).Enabled = false;
				$mc(Debris, "AddItem", $get(entry, 1), 0.4);
			}
		});
	};
	H.Laser = function (p) {
		let head = headOf(p.Model);
		let points = p.Points;
		if (((!$t(head) || !$t(points)) || ($len(points) === 0))) {
			return;
		}
		let color = ($n(p.Color) ?? C(255, 50, 50));
		let dur = ($n(p.Duration) ?? 1.2);
		let w = ($n(p.Width) ?? 0.8);
		let glow = fxPart({ Size: Vector3.new(w, w, 1), Color: color, Transparency: 0.35 });
		let core = fxPart({ Size: Vector3.new($mul(w, 0.35), $mul(w, 0.35), 1), Color: WHITE, Transparency: 0 });
		let tip = anchor($get(points, 1), $add(dur, 1));
		let sparks = emitter(tip, { Texture: TEX.Spark, Enabled: true, Rate: $mul(70, quality()), Color: CS(0, WHITE, 1, color), LightEmission: 1, Size: NS(0, 0.6, 1, 0), Lifetime: NumberRange.new(0.2, 0.45), Speed: NumberRange.new(8, 18), SpreadAngle: Vector2.new(60, 60), EmissionDirection: Enum.NormalId.Top, Acceleration: Vector3.new(0, (-25), 0) });
		let l = Instance.new("PointLight");
		l.Color = color;
		l.Range = 14;
		l.Brightness = 5;
		l.Parent = tip;
		let nextMark = 0;
		animate(dur, function (k, t) {
			if (!$t(head.Parent)) {
				return true;
			}
			let seg = $mul(k, (($len(points) - 1)));
			let i = math.clamp((math.floor(seg) + 1), 1, $len(points));
			let j = math.min($add(i, 1), $len(points));
			let target = $mc($get(points, i), "Lerp", $get(points, j), $sub(seg, ($sub(i, 1))));
			let from = $mul(head.CFrame, CFrame.new(0, (head.Size.Y * 0.12), ((-head.Size.Z) * 0.45)));
			let origin = from.Position;
			let len = ($sub(target, origin)).Magnitude;
			let cf = $mul(CFrame.lookAt(origin, target), CFrame.new(0, 0, $div($unm(len), 2)));
			let pulse = (1 + (math.sin($mul(t, 50)) * 0.15));
			glow.Size = Vector3.new($mul(w, pulse), $mul(w, pulse), len);
			glow.CFrame = cf;
			core.Size = Vector3.new($mul(w, 0.35), $mul(w, 0.35), len);
			core.CFrame = cf;
			tip.Position = target;
			if ((t >= nextMark)) {
				nextMark = $add(t, 0.06);
				scorch(target, 0.9, C(40, 15, 15), 1.2);
			}
			return undefined;
		}, function () {
			$mc(glow, "Destroy");
			$mc(core, "Destroy");
			sparks.Enabled = false;
			l.Enabled = false;
		});
		burst(head.Position, color, 10, 0.8, 4, TEX.Glow);
	};
	H.IceField = function (p) {
		let pos = p.Position;
		let r = ($n(p.Radius) ?? 14);
		let dur = ($n(p.Duration) ?? 3);
		let grow = ($n(p.Grow) ?? 0.6);
		let floor = disc(pos, 0.5, C(200, 240, 255), 0.25, Enum.Material.Ice);
		let rim = disc($add(pos, Vector3.new(0, 0.03, 0)), 0.5, C(230, 250, 255), 0.4);
		animate(grow, function (k) {
			let e = outCubic(k);
			setDiscRadius(floor, $mul(r, e));
			setDiscRadius(rim, $add($mul(r, e), 0.4));
			rim.Transparency = $add(0.4, $mul(0.5, k));
		});
		let crystals = [];
		let n = q(18);
		if (!$t(crowded(n))) {
			for (let i = 1, $v51 = n; i <= $v51; i++) {
				let a = $mul($mul(math.random(), math.pi), 2);
				let rr = $mul($mul(math.sqrt(math.random()), r), 0.95);
				task.delay($div($mul(grow, rr), r), function () {
					let c = spike($add(pos, Vector3.new($mul(math.cos(a), rr), 0, $mul(math.sin(a), rr))), rnd(0.6, 1.2), rnd(1.5, 4), C(185, 230, 255), Enum.Material.Glass, 0.15, 0.35);
					$ins(crystals, c);
				});
				if (($mod(i, 3) === 0)) {
					task.delay($div($mul(grow, rr), r), function () {
						burst($add(pos, Vector3.new($mul(math.cos(a), rr), 0.5, $mul(math.sin(a), rr))), C(220, 245, 255), 3, 0.5, 6);
					});
				}
			}
		}
		let mist = anchor($add(pos, Vector3.new(0, 0.5, 0)), $add(dur, 3));
		let fog = emitter(mist, { Texture: TEX.Smoke, Enabled: true, Rate: $mul(10, quality()), Color: ColorSequence.new(C(220, 245, 255)), LightEmission: 0.2, Size: NS(0, 2, 1, 5), Transparency: NS(0, 0.75, 1, 1), Lifetime: NumberRange.new(1.5, 2.5), Speed: NumberRange.new($mul(r, 0.3), $mul(r, 0.6)), SpreadAngle: Vector2.new(5, 180), EmissionDirection: Enum.NormalId.Right, Drag: 1 });
		task.delay(dur, function () {
			fog.Enabled = false;
			tween(floor, 0.6, { Transparency: 1 });
			tween(rim, 0.6, { Transparency: 1 });
			for (let $v52 = 0, $v53 = $arr(crystals); $v52 < $v53.length; $v52++) {
				let c = $v53[$v52];
				if (c == null) break;
				if ($t(c.Parent)) {
					burst(c.Position, C(210, 240, 255), 2, 0.5, 8);
					tween(c, 0.4, { Transparency: 1, Size: $mul(c.Size, Vector3.new(0.3, 0.2, 0.3)) });
				}
			}
		});
		$mc(Debris, "AddItem", floor, $add(dur, 0.7));
		$mc(Debris, "AddItem", rim, $add(dur, 0.7));
		task.delay($add(dur, 0.6), function () {
			for (let $v54 = 0, $v55 = $arr(crystals); $v54 < $v55.length; $v54++) {
				let c = $v55[$v54];
				if (c == null) break;
				$mc(c, "Destroy");
			}
		});
	};
	H.IceWave = function (p) {
		let from = p.From, dir = flat(p.Direction).Unit;
		let length = ($n(p.Length) ?? 50), width = ($n(p.Width) ?? 16), dur = ($n(p.Duration) ?? 0.8);
		let right = Vector3.new((-dir.Z), 0, dir.X);
		let color = ($n(p.Color) ?? C(180, 230, 255));
		let rows = math.max(6, math.floor($mul($div(length, 4), ($add(0.5, $mul(0.5, quality()))))));
		let placed = 0;
		let trail = [];
		let front = anchor($add(from, Vector3.new(0, 1, 0)), $add(dur, 2));
		let fog = emitter(front, { Texture: TEX.Smoke, Enabled: true, Rate: $mul(30, quality()), Color: ColorSequence.new(C(230, 250, 255)), LightEmission: 0.3, Size: NS(0, 2, 1, 6), Transparency: NS(0, 0.5, 1, 1), Lifetime: NumberRange.new(0.6, 1), Speed: NumberRange.new(4, 10), SpreadAngle: Vector2.new(70, 30), EmissionDirection: Enum.NormalId.Top });
		let wall = fxPart({ Size: Vector3.new(width, 0.4, 1.2), Color: WHITE, Transparency: 0.3 });
		animate(dur, function (k) {
			let along = $mul(length, k);
			let center = $add(from, $mul(dir, along));
			front.Position = $add(center, Vector3.new(0, 1, 0));
			let wallH = (2.5 + (math.sin($mul(k, math.pi)) * 2));
			wall.Size = Vector3.new($mul(width, ($add(0.7, $mul(0.3, k)))), wallH, 1.2);
			wall.CFrame = CFrame.lookAt($add(center, Vector3.new(0, $div(wallH, 2), 0)), $add($add(center, Vector3.new(0, $div(wallH, 2), 0)), dir));
			wall.Transparency = $add(0.35, $mul(0.4, k));
			let want = math.floor($mul(k, rows));
			while ((placed < want)) {
				placed = $add(placed, 1);
				let at = $add(from, $mul(dir, ($div($mul(length, placed), rows))));
				for (let s = (-1), $v56 = 1; s <= $v56; s++) {
					let pos = $add(at, $mul(right, ($add($mul($mul(s, width), 0.3), rnd((-1), 1)))));
					let c = spike(pos, rnd(1.2, 2), $mul(rnd(2.5, 4.5), (($n(((s === 0) && 1.3)) ?? 1))), color, Enum.Material.Glass, 0.1, 0.45);
					$ins(trail, c);
				}
				burst($add(at, Vector3.new(0, 1, 0)), C(225, 245, 255), 4, 0.8, 10);
			}
			return undefined;
		}, function () {
			$mc(wall, "Destroy");
			fog.Enabled = false;
		});
		task.delay($add(dur, 0.9), function () {
			for (let $v57 = 0, $v58 = $arr(trail); $v57 < $v58.length; $v57++) {
				let c = $v58[$v57];
				if (c == null) break;
				let i = $v57 + 1;
				if ($t(c.Parent)) {
					if (($mod(i, 3) === 0)) {
						burst(c.Position, C(215, 240, 255), 3, 0.6, 12);
					}
					tween(c, 0.35, { Transparency: 1, Size: $mul(c.Size, Vector3.new(0.4, 0.2, 0.4)) });
					$mc(Debris, "AddItem", c, 0.4);
				}
			}
		});
	};
	H.Wave = H.IceWave;
	H.Freeze = function (p) {
		let model = p.Model;
		let root = rootOf(model);
		if (!$t(root)) {
			return;
		}
		let dur = ($n(p.Duration) ?? 2);
		let size = $mc(model, "GetExtentsSize");
		if ((p.Kind === "vines")) {
			return;
		}
		if ((p.Kind === "bandage")) {
			let strips = [];
			let n = math.max(12, math.floor($mul(30, ($add(0.5, $mul(0.5, quality()))))));
			let turns = 4;
			for (let i = 1, $v59 = n; i <= $v59; i++) {
				$ins(strips, fxPart({ Size: Vector3.new(0.12, 0.55, 1), Color: ($n((($mod(i, 2) === 0) && C(235, 222, 185))) ?? C(215, 200, 160)), Material: Enum.Material.Fabric, Transparency: 1 }));
			}
			let rx = (size.X * 0.55), rz = (size.Z * 0.45);
			let helix = function (u, spread) {
				let a = $mul($mul($mul(u, turns), math.pi), 2);
				return Vector3.new($mul($mul(math.cos(a), rx), spread), $mul($mul(($sub(u, 0.5)), size.Y), 0.85), $mul($mul(math.sin(a), rz), spread));
			};
			animate(dur, function (k, t) {
				if (!$t(root.Parent)) {
					return true;
				}
				let pivot = $mc(model, "GetPivot");
				let wrap = math.min(1, $div(t, 0.4));
				let spread = $sub(1.5, $mul(0.5, outCubic(wrap)));
				for (let $v60 = 0, $v61 = $arr(strips); $v60 < $v61.length; $v60++) {
					let s = $v61[$v60];
					if (s == null) break;
					let i = $v60 + 1;
					let u0 = $div(((i - 1)), n), u1 = $div(i, n);
					let p0 = $mul(pivot, helix(u0, spread));
					let p1 = $mul(pivot, helix(u1, spread));
					let len = ($sub(p1, p0)).Magnitude;
					s.Size = Vector3.new(0.12, 0.55, $add(len, 0.15));
					s.CFrame = $mul(CFrame.lookAt(p0, p1), CFrame.new(0, 0, $div($unm(len), 2)));
					let shown = (u1 <= $add(wrap, 0.001));
					s.Transparency = ($n(($a(shown) && (($n(((k > 0.85) && $div(($sub(k, 0.85)), 0.15))) ?? 0)))) ?? 1);
				}
				return undefined;
			}, function () {
				for (let $v62 = 0, $v63 = $arr(strips); $v62 < $v63.length; $v62++) {
					let s = $v63[$v62];
					if (s == null) break;
					$mc(s, "Destroy");
				}
				burst(root.Position, C(235, 220, 180), 14, 0.7, 12, TEX.Smoke, { LightEmission: 0 });
			});
			return;
		}
		let block = fxPart({ Size: $mul(size, 1.12), CFrame: $mc(model, "GetPivot"), Color: C(170, 225, 255), Material: Enum.Material.Ice, Transparency: 0.45 });
		let crystals = [];
		let feet = ($n(feetOf(model)) ?? root.Position);
		if (!$t(crowded(6))) {
			for (let _ = 1, $v64 = q(6); _ <= $v64; _++) {
				let a = $mul($mul(math.random(), math.pi), 2);
				let c = spike($add(feet, $mul(Vector3.new(math.cos(a), 0, math.sin(a)), ((math.max(size.X, size.Z) * 0.55)))), rnd(0.6, 1.1), rnd(1.5, (size.Y * 0.9)), C(200, 240, 255), Enum.Material.Glass, 0.1, 0.5);
				$ins(crystals, c);
			}
		}
		burst(root.Position, C(220, 245, 255), 14, 0.9, 10);
		animate(dur, function () {
			if (!$t(root.Parent)) {
				return true;
			}
			block.CFrame = $mc(model, "GetPivot");
			return undefined;
		}, function () {
			shards(block.Position, C(190, 235, 255), 8, 22, 0.5, Enum.Material.Glass);
			burst(block.Position, C(220, 245, 255), 18, 1, 14);
			$mc(block, "Destroy");
			for (let $v65 = 0, $v66 = $arr(crystals); $v65 < $v66.length; $v65++) {
				let c = $v66[$v65];
				if (c == null) break;
				$mc(c, "Destroy");
			}
		});
	};
	H.Clones = function (p) {
		let source = p.Model;
		if (!($t(source) && $t(source.Parent))) {
			return;
		}
		let dur = ($n(p.Duration) ?? 1.2);
		let pivot = $mc(source, "GetPivot");
		let minSize = ($n(((quality() < 1) && 0.25)) ?? 0);
		let center = p.Center;
		for (let $v67 = 0, $v68 = $arr(p.CFrames); $v67 < $v68.length; $v67++) {
			let cf = $v68[$v67];
			if (cf == null) break;
			let i = $v67 + 1;
			task.delay((((i - 1)) * 0.1), function () {
				if (!$t(source.Parent)) {
					return;
				}
				let clone = Instance.new("Model");
				let list = [];
				for (let $v69 = 0, $v70 = $arr($mc(source, "GetDescendants")); $v69 < $v70.length; $v69++) {
					let d = $v70[$v69];
					if (d == null) break;
					if ((($t($mc(d, "IsA", "BasePart")) && (d.Name !== "HumanoidRootPart")) && (d.Size.Magnitude > minSize))) {
						let eye = (((d.Name === "Olho") || (d.Name === "Pupila")) || (d.Name === "Visor"));
						let c = fxPart({ Size: d.Size, Color: ($n(($a(eye) && C(220, 120, 255))) ?? C(25, 12, 40)), Material: Enum.Material.Neon, Transparency: 1, CFrame: $mul(cf, $mc(pivot, "ToObjectSpace", d.CFrame)) });
						let mesh = $mc(d, "FindFirstChildOfClass", "SpecialMesh");
						if ($t(mesh)) {
							$mc(mesh, "Clone").Parent = c;
						}
						c.Parent = clone;
						$ins(list, [c, eye]);
					}
				}
				clone.WorldPivot = cf;
				clone.Parent = folder;
				burst(cf.Position, C(90, 40, 160), 14, 2.2, 8, TEX.Smoke, { LightEmission: 0.2, Size: NS(0, 1.5, 1, 4) });
				let life = $sub(dur, (((i - 1)) * 0.1));
				let lungeFrom = cf;
				let lungeTo = cf;
				if ($t(center)) {
					let toward = flat($sub(center, cf.Position));
					if ((toward.Magnitude > 0.1)) {
						lungeTo = $add(cf, $mul(toward.Unit, math.min(3, (toward.Magnitude * 0.5))));
					}
				}
				animate(life, function (k, t) {
					let appear = math.min(1, $div(t, 0.18));
					let vanish = ($n(((k > 0.8) && $div(($sub(k, 0.8)), 0.2))) ?? 0);
					for (let $v71 = 0, $v72 = $arr(list); $v71 < $v72.length; $v71++) {
						let entry = $v72[$v71];
						if (entry == null) break;
						let base = ($n(($a($get(entry, 2)) && 0)) ?? 0.3);
						$get(entry, 1).Transparency = $sub(1, $mul($mul(($sub(1, base)), appear), ($sub(1, vanish))));
					}
					if ((k > 0.6)) {
						let e = outCubic(math.min(1, $div(($sub(k, 0.6)), 0.2)));
						$mc(clone, "PivotTo", $mul($mc(lungeFrom, "Lerp", lungeTo, e), CFrame.new(0, (math.sin($mul(t, 30)) * 0.05), 0)));
					}
					return undefined;
				}, function () {
					burst($mc(clone, "GetPivot").Position, C(60, 25, 100), 10, 2, 6, TEX.Smoke, { LightEmission: 0.1, Size: NS(0, 1.5, 1, 3.5) });
					$mc(clone, "Destroy");
				});
			});
		}
	};
	H.ShadowStrike = function (p) {
		let pos = p.Position;
		let color = ($n(p.Color) ?? C(190, 100, 255));
		flashBall(pos, 3, color, 0.2);
		light(pos, color, 22, 0.5, 6);
		burst(pos, C(40, 10, 70), 16, 2.5, 14, TEX.Smoke, { LightEmission: 0, Size: NS(0, 1, 1, 3.5) });
		burst(pos, color, 18, 0.9, 26, TEX.Sparkle);
		let d = ($n(p.Direction) ?? Vector3.new(0, 0, (-1)));
		$sp(H.Slash({ Position: pos, Direction: d, Color: color, Size: 8, Tilt: 0.8 }));
		$sp(H.Slash({ Position: pos, Direction: d, Color: WHITE, Size: 8, Tilt: (-0.8) }));
		shakeAt(pos, 0.35, 40);
	};
	H.Smoke = function (p) {
		burst(p.Position, p.Color, 22, ($n(p.Size) ?? 4), 8, TEX.Smoke, { LightEmission: 0.1, Size: NS(0, $mul((($n(p.Size) ?? 4)), 0.4), 1, ($n(p.Size) ?? 4)), Transparency: NS(0, 0.2, 1, 1), Lifetime: NumberRange.new(0.6, 1.1), Drag: 3 });
	};
	H.Slash = function (p) {
		let d = flat(($n(p.Direction) ?? Vector3.new(0, 0, (-1))));
		d = ($n(((d.Magnitude > 0.01) && d.Unit)) ?? Vector3.new(0, 0, (-1)));
		let color = ($n(p.Color) ?? WHITE);
		let size = ($n(p.Size) ?? 7);
		let tilt = ($n(p.Tilt) ?? rnd((-0.6), 0.6));
		let center = $add(p.Position, Vector3.new(0, 1, 0));
		let n = math.max(5, math.floor($mul(9, ($add(0.5, $mul(0.5, quality()))))));
		let base = $mul(CFrame.lookAt(center, $add(center, d)), CFrame.Angles(0, 0, tilt));
		let segs = [];
		let radius = $mul(size, 0.5);
		let arc = $mul(math.pi, 0.9);
		for (let i = 1, $v73 = n; i <= $v73; i++) {
			let mid = $div(math.abs($sub(i, $div(($add(n, 1)), 2))), ($div(($add(n, 1)), 2)));
			$ins(segs, [fxPart({ Size: Vector3.new(0.1, 0.1, 0.1), Color: ($n((($mod(i, 2) === 0) && WHITE)) ?? color), Transparency: 1 }), $sub(1, mid)]);
		}
		animate(0.28, function (k) {
			let reveal = math.min(1, $div(k, 0.45));
			for (let $v74 = 0, $v75 = $arr(segs); $v74 < $v75.length; $v74++) {
				let entry = $v75[$v74];
				if (entry == null) break;
				let i = $v74 + 1;
				let part = $get(entry, 1), thickK = $get(entry, 2);
				let a0 = $add($div($unm(arc), 2), $mul($div(((i - 1)), n), arc));
				let a1 = $add($div($unm(arc), 2), $mul($div(i, n), arc));
				let shown = (($div(i, n)) <= $add(reveal, 0.001));
				let p0 = $mul(base, Vector3.new($mul(math.sin(a0), radius), 0, $mul($mul((-math.cos(a0)), radius), 0.4)));
				let p1 = $mul(base, Vector3.new($mul(math.sin(a1), radius), 0, $mul($mul((-math.cos(a1)), radius), 0.4)));
				let len = ($sub(p1, p0)).Magnitude;
				let th = $mul(($add(0.15, $mul(0.55, thickK))), ($sub(1, $mul(k, 0.6))));
				part.Size = Vector3.new(th, $mul(th, 0.5), $add(len, th));
				part.CFrame = $mul(CFrame.lookAt(p0, p1), CFrame.new(0, 0, $div($unm(len), 2)));
				part.Transparency = ($n(($a(shown) && ((0.05 + (0.95 * math.max(0, $div(($sub(k, 0.4)), 0.6))))))) ?? 1);
			}
		}, function () {
			for (let $v76 = 0, $v77 = $arr(segs); $v76 < $v77.length; $v76++) {
				let entry = $v77[$v76];
				if (entry == null) break;
				$mc($get(entry, 1), "Destroy");
			}
		});
		burst(center, color, 5, 0.6, 14, TEX.Spark);
	};
	H.BiteMark = function (p) {
		let pos = p.Position;
		let d = flat(($n(p.Direction) ?? Vector3.new(0, 0, (-1))));
		d = ($n(((d.Magnitude > 0.01) && d.Unit)) ?? Vector3.new(0, 0, (-1)));
		let color = ($n(p.Color) ?? WHITE);
		let scale = ($n(($a(p.Big) && 1.8)) ?? 1);
		let base = $mul(CFrame.lookAt(pos, $add(pos, d)), CFrame.new(0, 0, 0.5));
		let teeth = [];
		let n = ($n(($a(p.Big) && 5)) ?? 4);
		for (let jaw = (-1), $v78 = 1; jaw <= $v78; jaw += 2) {
			for (let i = 1, $v79 = n; i <= $v79; i++) {
				let t = fxPart({ Shape: Enum.PartType.Wedge, Size: $mul(Vector3.new(0.35, 0.8, 0.5), scale), Color: ($n((($mod(i, 2) === 0) && WHITE)) ?? color), Transparency: 0 });
				$ins(teeth, [t, jaw, $mul($mul(($sub(i, $div(($add(n, 1)), 2))), 0.55), scale)]);
			}
		}
		let gap = $mul(2.2, scale);
		animate(0.3, function (k) {
			let close = ($n(((k < 0.4) && outCubic($div(k, 0.4)))) ?? 1);
			let g = $mul(gap, ($sub(1, close)));
			for (let $v80 = 0, $v81 = $arr(teeth); $v80 < $v81.length; $v80++) {
				let e = $v81[$v80];
				if (e == null) break;
				let part = $get(e, 1), jaw = $get(e, 2), x = $get(e, 3);
				let cf = $mul(base, CFrame.new(x, $mul(jaw, ($add(g, $mul(0.35, scale)))), 0));
				part.CFrame = ($n(((jaw > 0) && $mul(cf, CFrame.Angles(math.pi, 0, 0)))) ?? cf);
				part.Transparency = ($n(((k > 0.5) && $div(($sub(k, 0.5)), 0.5))) ?? 0);
			}
		}, function () {
			for (let $v82 = 0, $v83 = $arr(teeth); $v82 < $v83.length; $v82++) {
				let e = $v83[$v82];
				if (e == null) break;
				$mc($get(e, 1), "Destroy");
			}
		});
		task.delay(0.12, function () {
			burst(pos, color, ($n(($a(p.Big) && 18)) ?? 8), 0.8, 18, TEX.Spark);
			if ($t(p.Big)) {
				flashBall(pos, 2.5, color, 0.2);
				light(pos, color, 16, 0.3);
			}
		});
	};
	H.Spikes = function (p) {
		let interval = ($n(p.Interval) ?? 0.05);
		let shadow = (p.Kind === "shadow");
		let color = ($n(p.Color) ?? C(200, 150, 255));
		let h = ($n(p.Height) ?? 6);
		for (let $v84 = 0, $v85 = $arr(p.Positions); $v84 < $v85.length; $v84++) {
			let pos = $v85[$v84];
			if (pos == null) break;
			let i = $v84 + 1;
			task.delay($mul(i, interval), function () {
				let list = [];
				let main = spike(pos, ($n(($a(shadow) && 1.4)) ?? 1.6), h, color, ($n(($a(shadow) && Enum.Material.Neon)) ?? Enum.Material.Glass), ($n(($a(shadow) && 0.05)) ?? 0.1), 0.3);
				$ins(list, main);
				if ((!$t(shadow) && !$t(crowded(2)))) {
					for (let _ = 1, $v86 = 2; _ <= $v86; _++) {
						let off = Vector3.new(rnd((-1.2), 1.2), 0, rnd((-1.2), 1.2));
						$ins(list, spike($add(pos, off), rnd(0.6, 1), $mul(h, rnd(0.35, 0.6)), $mc(color, "Lerp", WHITE, 0.3), Enum.Material.Glass, 0.15, 0.6));
					}
				}
				if ($t(shadow)) {
					burst(pos, C(30, 0, 20), 6, 2, 6, TEX.Smoke, { LightEmission: 0, Size: NS(0, 1, 1, 3) });
				} else {
					burst($add(pos, Vector3.new(0, 1, 0)), color, 5, 0.7, 10);
					dust(pos, C(150, 130, 120), 3, 1.5, 6);
				}
				task.delay(0.9, function () {
					for (let $v87 = 0, $v88 = $arr(list); $v87 < $v88.length; $v87++) {
						let s = $v88[$v87];
						if (s == null) break;
						if ($t(s.Parent)) {
							if (!$t(shadow)) {
								burst(s.Position, color, 2, 0.5, 10);
							}
							tween(s, 0.3, { Transparency: 1, Size: $mul(s.Size, Vector3.new(0.3, 0.6, 0.3)) });
						}
					}
				});
				for (let $v89 = 0, $v90 = $arr(list); $v89 < $v90.length; $v89++) {
					let s = $v90[$v89];
					if (s == null) break;
					$mc(Debris, "AddItem", s, 1.3);
				}
			});
		}
	};
	H.GroundSlam = function (p) {
		let pos = p.Position;
		let r = ($n(p.Radius) ?? 20);
		let color = ($n(p.Color) ?? C(200, 170, 130));
		flashBall($add(pos, Vector3.new(0, 1, 0)), 3, C(255, 240, 210), 0.2);
		groundRing(pos, 1, r, color, 0.55, { Thick: 1.4, Height: 1.8, Material: Enum.Material.SmoothPlastic, Transparency: 0.2 });
		groundRing(pos, 1, $mul(r, 0.8), WHITE, 0.35, { Thick: 0.5, Height: 0.3 });
		let rings = 3;
		for (let ring = 1, $v91 = rings; ring <= $v91; ring++) {
			let rr = $div($mul(r, ring), ($add(rings, 0.5)));
			let count = q((6 + (ring * 3)));
			task.delay($div((0.55 * ring), ($add(rings, 0.5))), function () {
				if ($t(crowded(count))) {
					return;
				}
				for (let i = 1, $v92 = count; i <= $v92; i++) {
					let a = $add($mul($mul($div(i, count), math.pi), 2), rnd((-0.2), 0.2));
					let rp = $add(pos, $mul(Vector3.new(math.cos(a), 0, math.sin(a)), rr));
					let rock = spike(rp, rnd(1.2, 2.2), $mul(rnd(1.5, 3.2), ((1.2 - (ring * 0.15)))), C(130, 110, 90), Enum.Material.Slate, 0, 0.5);
					task.delay(0.7, function () {
						if ($t(rock.Parent)) {
							tween(rock, 0.35, { Transparency: 1, CFrame: $sub(rock.CFrame, Vector3.new(0, 1.5, 0)) });
						}
					});
					$mc(Debris, "AddItem", rock, 1.1);
				}
			});
		}
		dust(pos, C(170, 150, 120), 30, 4, 28);
		shards($add(pos, Vector3.new(0, 0.5, 0)), C(120, 100, 80), 10, 34, 0.8);
		cracks(pos, $mul(r, 0.6), C(50, 40, 30), 9, 2.5);
		light($add(pos, Vector3.new(0, 3, 0)), C(255, 220, 160), 30, 0.4);
		shakeAt(pos, 0.75, 70, 0.5);
	};
	H.Glob = function (p) {
		let from = p.From, to = p.To, dur = ($n(p.Duration) ?? 0.45);
		let color = ($n(p.Color) ?? C(130, 230, 60));
		let ball = fxPart({ Shape: Enum.PartType.Ball, Size: $mul(Vector3.one, 1.6), Color: color, Transparency: 0.1, CFrame: CFrame.new(from) });
		let a0 = Instance.new("Attachment");
		a0.Parent = ball;
		let drip = emitter(a0, { Texture: TEX.Smoke, Enabled: true, Rate: $mul(40, quality()), Color: ColorSequence.new(color), LightEmission: 0.4, Size: NS(0, 0.8, 1, 0.2), Transparency: NS(0, 0.3, 1, 1), Lifetime: NumberRange.new(0.3, 0.5), Speed: NumberRange.new(0, 1) });
		let height = math.max(4, (($sub(to, from)).Magnitude * 0.3));
		animate(dur, function (k) {
			ball.CFrame = CFrame.new($add($mc(from, "Lerp", to, k), Vector3.new(0, $mul(math.sin($mul(k, math.pi)), height), 0)));
		}, function () {
			drip.Enabled = false;
			$mc(Debris, "AddItem", ball, 0.6);
			ball.Transparency = 1;
			burst($add(to, Vector3.new(0, 0.5, 0)), color, 20, 1.2, 18, TEX.Sparkle);
			groundRing(to, 0.5, 5, color, 0.35, { Thick: 0.5 });
		});
	};
	H.Cloud = function (p) {
		let pos = p.Position, r = ($n(p.Radius) ?? 12), dur = ($n(p.Duration) ?? 5);
		let color = ($n(p.Color) ?? C(130, 230, 60));
		let anchorPart = fxPart({ Size: Vector3.new($mul(r, 2), 3, $mul(r, 2)), CFrame: CFrame.new($add(pos, Vector3.new(0, 2, 0))), Transparency: 1 });
		let fog = emitter(anchorPart, { Texture: TEX.Smoke, Enabled: true, Rate: $mul(25, quality()), LightEmission: 0.35, Color: CS(0, color, 1, $mc(color, "Lerp", C(60, 90, 20), 0.5)), Size: NS(0, 3, 1, 7), Transparency: NS(0, 0.55, 0.5, 0.6, 1, 1), Lifetime: NumberRange.new(1.5, 2.5), Speed: NumberRange.new(0.5, 2), Shape: Enum.ParticleEmitterShape.Box, RotSpeed: NumberRange.new((-20), 20), Rotation: NumberRange.new(0, 360) });
		let bubbles = emitter(anchorPart, { Texture: TEX.Glow, Enabled: true, Rate: $mul(14, quality()), LightEmission: 0.8, Color: ColorSequence.new($mc(color, "Lerp", WHITE, 0.3)), Size: NS(0, 0.2, 0.8, 0.7, 1, 0), Transparency: NS(0, 0.2, 1, 0.6), Lifetime: NumberRange.new(0.8, 1.4), Speed: NumberRange.new(2, 4), EmissionDirection: Enum.NormalId.Top, Shape: Enum.ParticleEmitterShape.Box });
		let floor = disc(pos, 0.5, $mc(color, "Lerp", C(40, 60, 10), 0.4), 0.55);
		animate(0.5, function (k) {
			setDiscRadius(floor, $mul(r, outCubic(k)));
		});
		task.delay(dur, function () {
			fog.Enabled = false;
			bubbles.Enabled = false;
			tween(floor, 0.8, { Transparency: 1 });
		});
		$mc(Debris, "AddItem", anchorPart, $add(dur, 3));
		$mc(Debris, "AddItem", floor, $add(dur, 0.9));
	};
	H.FireSpot = function (p) {
		let pos = p.Position, dur = ($n(p.Duration) ?? 2.5), size = ($n(p.Size) ?? 1.8);
		let a = anchor($add(pos, Vector3.new(0, 0.2, 0)), $add(dur, 1.2));
		let f = fireEmitter(a, 22, size);
		let glow = disc(pos, $mul(size, 0.9), C(255, 120, 30), 0.45);
		if ((math.random() < 0.4)) {
			light($add(pos, Vector3.new(0, 2, 0)), C(255, 140, 50), 12, dur, 2);
		}
		task.delay(dur, function () {
			f.Enabled = false;
			tween(glow, 0.5, { Transparency: 1, Color: C(40, 30, 25) });
		});
		$mc(Debris, "AddItem", glow, $add(dur, 0.6));
	};
	H.FireRing = function (p) {
		let pos = p.Position, r = ($n(p.Radius) ?? 8), dur = ($n(p.Duration) ?? 2);
		let n = math.max(8, math.floor($mul($mul(r, 2.2), ($add(0.45, $mul(0.55, quality()))))));
		let list = [];
		for (let i = 1, $v93 = n; i <= $v93; i++) {
			let a = $mul($mul($div(i, n), math.pi), 2);
			let at = anchor($add(pos, Vector3.new($mul(math.cos(a), r), 0.3, $mul(math.sin(a), r))), $add(dur, 1.2));
			let e = fireEmitter(at, 18, 2.6, C(255, 110, 30));
			e.Speed = NumberRange.new(6, 12);
			$ins(list, e);
		}
		groundRing(pos, r, r, C(255, 120, 30), dur, { Thick: 1.2, Height: 0.2, Transparency: 0.3 });
		let glow = disc(pos, $add(r, 1), C(255, 90, 20), 0.75);
		light($add(pos, Vector3.new(0, 3, 0)), C(255, 120, 40), $mul(r, 2.5), dur, 3);
		task.delay(dur, function () {
			for (let $v94 = 0, $v95 = $arr(list); $v94 < $v95.length; $v94++) {
				let e = $v95[$v94];
				if (e == null) break;
				e.Enabled = false;
			}
			tween(glow, 0.5, { Transparency: 1 });
		});
		$mc(Debris, "AddItem", glow, $add(dur, 0.6));
	};
	H.Ignite = function (p) {
		let pos = p.Position, r = ($n(p.Radius) ?? 4), dur = ($n(p.Duration) ?? 1.2);
		let glow = disc(pos, 0.3, C(255, 110, 30), 0.35);
		animate(0.35, function (k) {
			setDiscRadius(glow, $mul(r, outCubic(k)));
		});
		let n = q(6);
		for (let i = 1, $v96 = n; i <= $v96; i++) {
			let a = $mul($mul($div(i, n), math.pi), 2);
			let at = anchor($add(pos, Vector3.new($mul($mul(math.cos(a), r), 0.6), 0.2, $mul($mul(math.sin(a), r), 0.6))), $add(dur, 1));
			let e = fireEmitter(at, 14, 1.6);
			task.delay(dur, function () {
				e.Enabled = false;
			});
		}
		let sparks = embers(anchor(pos, $add(dur, 1.5)), 20);
		task.delay(dur, function () {
			sparks.Enabled = false;
		});
		light($add(pos, Vector3.new(0, 2, 0)), C(255, 120, 40), 14, dur, 3);
		task.delay(dur, function () {
			tween(glow, 0.4, { Transparency: 1 });
		});
		$mc(Debris, "AddItem", glow, $add(dur, 0.5));
		cracks(pos, r, C(255, 120, 40), 5, dur, true);
	};
	H.Burn = function (p) {
		let root = rootOf(p.Model);
		if (!$t(root)) {
			return;
		}
		let dur = ($n(p.Duration) ?? 1.5);
		let torso = ($n($mc(p.Model, "FindFirstChild", "Torso")) ?? root);
		let f = fireEmitter(torso, 25, math.max(1.2, (torso.Size.X * 0.7)));
		f.Shape = Enum.ParticleEmitterShape.Box;
		let e = embers(torso, 12);
		task.delay(dur, function () {
			f.Enabled = false;
			e.Enabled = false;
		});
		$mc(Debris, "AddItem", f, $add(dur, 1));
		$mc(Debris, "AddItem", e, $add(dur, 1.3));
	};
	H.Cone = function (p) {
		let head = headOf(p.Model, p.Head);
		if (!$t(head)) {
			return;
		}
		let fire = (p.Kind === "fire");
		let color = ($n(p.Color) ?? C(255, 120, 30));
		let att = Instance.new("Attachment");
		att.Parent = head;
		att.CFrame = CFrame.new(0, ((-head.Size.Y) * 0.15), ((-head.Size.Z) * 0.6));
		let len = ($n(p.Length) ?? 20);
		let main = emitter(att, { Texture: ($n(($a(fire) && TEX.Fire)) ?? TEX.Sparkle), Color: CS(0, C(255, 250, 200), 0.25, $mc(color, "Lerp", WHITE, 0.2), 0.7, color, 1, C(90, 20, 10)), LightEmission: 1, Size: NS(0, 0.8, 0.4, 3.5, 1, 6), Transparency: NS(0, 0.15, 0.7, 0.3, 1, 1), Lifetime: NumberRange.new($div(len, 48), $div(len, 36)), Speed: NumberRange.new(36, 48), SpreadAngle: Vector2.new($mul((($n(p.Angle) ?? 25)), 0.6), $mul((($n(p.Angle) ?? 25)), 0.6)), EmissionDirection: Enum.NormalId.Front, Rotation: NumberRange.new(0, 360), RotSpeed: NumberRange.new((-180), 180), Rate: $mul(110, quality()), Enabled: true, Drag: 1 });
		let sparks = emitter(att, { Texture: TEX.Spark, Color: ColorSequence.new(C(255, 220, 120)), LightEmission: 1, Size: NS(0, 0.4, 1, 0), Lifetime: NumberRange.new(0.4, 0.7), Speed: NumberRange.new(30, 45), SpreadAngle: Vector2.new(($n(p.Angle) ?? 25), ($n(p.Angle) ?? 25)), EmissionDirection: Enum.NormalId.Front, Acceleration: Vector3.new(0, (-10), 0), Rate: $mul(40, quality()), Enabled: true });
		let smoke = emitter(att, { Texture: TEX.Smoke, Color: ColorSequence.new(C(60, 50, 50)), LightEmission: 0, Size: NS(0, 2, 1, 7), Transparency: NS(0, 0.8, 0.4, 0.65, 1, 1), Lifetime: NumberRange.new(0.8, 1.2), Speed: NumberRange.new(20, 26), SpreadAngle: Vector2.new(20, 20), EmissionDirection: Enum.NormalId.Front, Acceleration: Vector3.new(0, 6, 0), Rate: $mul(14, quality()), Enabled: true });
		let l = Instance.new("PointLight");
		l.Color = color;
		l.Range = 22;
		l.Brightness = 4;
		l.Shadows = false;
		l.Parent = att;
		let dur = ($n(p.Duration) ?? 1);
		let nextMark = 0;
		animate(dur, function (_, t) {
			if (!$t(head.Parent)) {
				return true;
			}
			l.Brightness = (3.5 + (math.sin($mul(t, 30)) * 1));
			if (((t >= nextMark) && $t(fire))) {
				nextMark = $add(t, 0.18);
				let look = flat(head.CFrame.LookVector);
				if ((look.Magnitude > 0.1)) {
					let feet = feetOf(p.Model);
					if ($t(feet)) {
						let at = $add($add(feet, $mul(look.Unit, rnd($mul(len, 0.35), $mul(len, 0.8)))), Vector3.new(rnd((-2), 2), 0, rnd((-2), 2)));
						scorch(at, rnd(1.2, 2.2), C(35, 22, 18), 1.5);
						if ((math.random() < 0.5)) {
							$sp(H.FireSpot({ Position: at, Duration: 0.9, Size: 1.2 }));
						}
					}
				}
			}
			return undefined;
		}, function () {
			main.Enabled = false;
			sparks.Enabled = false;
			smoke.Enabled = false;
			l.Enabled = false;
		});
		$mc(Debris, "AddItem", att, $add(dur, 1.5));
	};
	H.TailSwipe = function (p) {
		let root = rootOf(p.Model);
		if (!$t(root)) {
			return;
		}
		let feet = ($n(feetOf(p.Model)) ?? root.Position);
		let r = ($n(p.Radius) ?? 10);
		let color = ($n(p.Color) ?? C(255, 140, 60));
		let n = math.max(8, math.floor($mul(16, ($add(0.5, $mul(0.5, quality()))))));
		let segs = ringParts(n, color);
		let cf0 = CFrame.new($add(feet, Vector3.new(0, ((root.Size.Y * 0.5) + 0.5), 0)));
		animate(0.4, function (k) {
			let sweep = $mul($mul(math.min(1, $div(k, 0.6)), math.pi), 2);
			let arc = $mul($div($mul($mul($mul(2, math.pi), r), 0.8), n), 1.15);
			for (let $v97 = 0, $v98 = $arr(segs); $v97 < $v98.length; $v97++) {
				let s = $v98[$v97];
				if (s == null) break;
				let i = $v97 + 1;
				let a = $mul($mul($div(i, n), math.pi), 2);
				let shown = (a <= sweep);
				s.Size = Vector3.new(0.6, $mul(1.2, ($sub(1, $mul(k, 0.5)))), arc);
				s.CFrame = $mul($mul(cf0, CFrame.Angles(0, $add($unm(a), math.pi), 0)), CFrame.new($mul(r, 0.8), 0, 0));
				let age = $div(($sub(sweep, a)), ($mul(math.pi, 2)));
				s.Transparency = ($n(($a(shown) && math.clamp($add($add(0.1, $mul(age, 1.6)), (math.max(0, $sub(k, 0.6)) * 2)), 0, 1))) ?? 1);
			}
		}, function () {
			for (let $v99 = 0, $v100 = $arr(segs); $v99 < $v100.length; $v99++) {
				let s = $v100[$v99];
				if (s == null) break;
				$mc(s, "Destroy");
			}
		});
		dust(feet, C(170, 150, 120), 14, 2.5, 18);
		groundRing(feet, 1, r, color, 0.4, { Thick: 0.6 });
	};
	H.Explosion = function (p) {
		let pos = p.Position;
		let color = ($n(p.Color) ?? C(255, 120, 30));
		let r = ($n(p.Radius) ?? 10);
		let water = (p.Kind === "water");
		let void$2 = (p.Kind === "void");
		flashBall(pos, $mul(r, 0.5), WHITE, 0.15);
		let ball = fxPart({ Shape: Enum.PartType.Ball, Size: $mul(Vector3.one, 2), CFrame: CFrame.new(pos), Color: color, Transparency: 0.1 });
		animate(0.4, function (k) {
			let e = outCubic(k);
			ball.Size = $mul(Vector3.one, ($add(2, $mul(($sub($mul(r, 2), 2)), e))));
			ball.Transparency = $add(0.1, $mul(0.9, $pow(k, 0.8)));
		}, function () {
			$mc(ball, "Destroy");
		});
		if ($t(water)) {
			burst(pos, C(200, 235, 255), 40, 1.2, 40, TEX.Sparkle, { Acceleration: Vector3.new(0, (-50), 0), Drag: 1 });
			burst(pos, C(230, 245, 255), 18, 3, 16, TEX.Smoke, { LightEmission: 0.3, Size: NS(0, 2, 1, 5) });
		} else if ($t(void$2)) {
			burst(pos, color, 40, 1.4, 45, TEX.Sparkle);
			burst(pos, C(30, 0, 60), 20, 5, 18, TEX.Smoke, { LightEmission: 0, Size: NS(0, 3, 1, 7) });
		} else {
			burst(pos, CS(0, C(255, 250, 200), 0.4, color, 1, C(120, 30, 10)), 30, 3.5, 30, TEX.Fire, { Size: NS(0, 2.5, 1, 5), Lifetime: NumberRange.new(0.4, 0.8), LightEmission: 1 });
			burst(pos, C(70, 60, 60), 18, 5, 14, TEX.Smoke, { LightEmission: 0, Size: NS(0, 3, 1, 8), Transparency: NS(0, 0.3, 1, 1), Lifetime: NumberRange.new(1, 1.8), Acceleration: Vector3.new(0, 4, 0) });
			burst(pos, C(255, 190, 80), 24, 0.5, 45, TEX.Spark, { Acceleration: Vector3.new(0, (-40), 0), Drag: 1, Lifetime: NumberRange.new(0.6, 1.2) });
		}
		light(pos, color, $mul(r, 3), 0.7, 7);
		groundRing($sub(pos, Vector3.new(0, 0.9, 0)), 1, $mul(r, 1.35), color, 0.5, { Thick: math.max(0.6, $mul(r, 0.08)), Height: 0.8 });
		if (!$t(water)) {
			scorch($sub(pos, Vector3.new(0, 0.9, 0)), $mul(r, 0.55), ($n(($a(void$2) && C(30, 10, 50))) ?? C(30, 22, 20)), 2.5);
			cracks($sub(pos, Vector3.new(0, 0.9, 0)), $mul(r, 0.8), ($n(($a(void$2) && color)) ?? C(255, 120, 40)), 6, 1.5, true);
		}
		shakeAt(pos, math.clamp($div(r, 16), 0.25, 0.9), $add(40, $mul(r, 3)), 0.4);
	};
	H.Lava = function (p) {
		let pos = p.Position, r = ($n(p.Radius) ?? 8), dur = ($n(p.Duration) ?? 4);
		let crust = disc(pos, 0.5, C(60, 25, 15), 0.05, Enum.Material.Basalt);
		let pool = disc($add(pos, Vector3.new(0, 0.03, 0)), 0.4, C(255, 110, 20), 0.05);
		animate(0.6, function (k) {
			let e = outCubic(k);
			setDiscRadius(crust, $add($mul(r, e), 0.6));
			setDiscRadius(pool, $mul(r, e));
		});
		let glowPart = fxPart({ Size: Vector3.new($mul(r, 1.6), 0.5, $mul(r, 1.6)), CFrame: CFrame.new($add(pos, Vector3.new(0, 0.5, 0))), Transparency: 1 });
		let f = emitter(glowPart, { Texture: TEX.Fire, Enabled: true, Rate: $mul($mul(r, 2.5), quality()), Color: CS(0, C(255, 220, 100), 1, C(255, 70, 20)), LightEmission: 1, Size: NS(0, 1.4, 1, 0), Lifetime: NumberRange.new(0.5, 1), Speed: NumberRange.new(2, 5), SpreadAngle: Vector2.new(15, 15), EmissionDirection: Enum.NormalId.Top, Shape: Enum.ParticleEmitterShape.Box });
		let pops = emitter(glowPart, { Texture: TEX.Spark, Enabled: true, Rate: $mul($mul(r, 1.2), quality()), Color: ColorSequence.new(C(255, 180, 60)), LightEmission: 1, Size: NS(0, 0.5, 1, 0), Lifetime: NumberRange.new(0.5, 0.9), Speed: NumberRange.new(6, 12), SpreadAngle: Vector2.new(30, 30), EmissionDirection: Enum.NormalId.Top, Acceleration: Vector3.new(0, (-30), 0), Shape: Enum.ParticleEmitterShape.Box });
		light($add(pos, Vector3.new(0, 3, 0)), C(255, 110, 30), $mul(r, 2.5), dur, 3);
		animate(dur, function (_, t) {
			pool.Color = $mc(C(255, 110, 20), "Lerp", C(255, 170, 50), (((math.sin($mul(t, 4)) + 1)) * 0.5));
		}, function () {
			f.Enabled = false;
			pops.Enabled = false;
			tween(pool, 0.8, { Transparency: 1, Color: C(80, 30, 20) });
			tween(crust, 1.6, { Transparency: 1 });
		});
		$mc(Debris, "AddItem", pool, $add(dur, 0.9));
		$mc(Debris, "AddItem", crust, $add(dur, 1.7));
		$mc(Debris, "AddItem", glowPart, $add(dur, 1.2));
	};
	H.LavaCracks = function (p) {
		let from = p.From;
		for (let $v101 = 0, $v102 = $arr(($n(p.Tos) ?? [])); $v101 < $v102.length; $v101++) {
			let to = $v102[$v101];
			if (to == null) break;
			let dir = flat($sub(to, from));
			let len = dir.Magnitude;
			if ((len > 1)) {
				let steps = math.clamp(math.floor($div(len, 5)), 2, 10);
				let last = from;
				for (let i = 1, $v103 = steps; i <= $v103; i++) {
					let k = $div(i, steps);
					let point = $add($add(from, $mul(dir, k)), (($n(((i < steps) && Vector3.new(rnd((-1.5), 1.5), 0, rnd((-1.5), 1.5)))) ?? Vector3.zero)));
					let a = last, b = point;
					task.delay($mul(k, 0.5), function () {
						let l = ($sub(b, a)).Magnitude;
						let seg = fxPart({ Size: Vector3.new(0.5, 0.1, l), CFrame: $mul(CFrame.lookAt(a, b), CFrame.new(0, 0.08, $div($unm(l), 2))), Color: C(255, 120, 30), Transparency: 0.05 });
						burst($add(b, Vector3.new(0, 0.3, 0)), C(255, 150, 50), 2, 0.5, 6, TEX.Spark);
						task.delay(($n(p.Duration) ?? 2), function () {
							if ($t(seg.Parent)) {
								tween(seg, 0.6, { Transparency: 1, Color: C(60, 30, 20) });
							}
						});
						$mc(Debris, "AddItem", seg, $add((($n(p.Duration) ?? 2)), 0.7));
					});
					last = point;
				}
			}
		}
	};
	H.Meteor = function (p) {
		let star = (p.Kind === "star");
		let delay = ($n(p.Delay) ?? 1);
		let color = ($n(($a(star) && C(255, 240, 150))) ?? C(255, 100, 30));
		$sp(H.Telegraph({ Position: p.Position, Radius: p.Radius, Duration: delay, Color: color }));
		let size = ($n(($a(star) && 2)) ?? 4.5);
		let start = $add(p.Position, Vector3.new(rnd(10, 20), 75, rnd(5, 15)));
		let rock = fxPart({ Shape: Enum.PartType.Ball, Size: $mul(Vector3.one, size), Color: ($n(($a(star) && C(255, 250, 200))) ?? C(90, 40, 25)), Material: ($n(($a(star) && Enum.Material.Neon)) ?? Enum.Material.Basalt), CFrame: CFrame.new(start) });
		let a0 = Instance.new("Attachment");
		a0.Position = Vector3.new(0, $mul(size, 0.4), 0);
		a0.Parent = rock;
		let a1 = Instance.new("Attachment");
		a1.Position = Vector3.new(0, $mul($unm(size), 0.4), 0);
		a1.Parent = rock;
		let tr = Instance.new("Trail");
		tr.Attachment0 = a0;
		tr.Attachment1 = a1;
		tr.Color = ($n(($a(star) && CS(0, WHITE, 1, color))) ?? CS(0, C(255, 230, 150), 0.4, C(255, 120, 30), 1, C(80, 30, 20)));
		tr.Transparency = NS(0, 0, 1, 1);
		tr.Lifetime = 0.35;
		tr.LightEmission = 1;
		tr.FaceCamera = true;
		tr.WidthScale = NS(0, 1.4, 1, 0);
		tr.Parent = rock;
		if ($t(star)) {
			emitter(rock, { Enabled: true, Rate: $mul(30, quality()), Color: ColorSequence.new(color), Size: NS(0, 0.8, 1, 0), Lifetime: NumberRange.new(0.3, 0.6), Speed: NumberRange.new(1, 3) });
		} else {
			fireEmitter(rock, 50, 3.5).SpreadAngle = Vector2.new(180, 180);
		}
		animate(delay, function (k) {
			let e = $mul(k, k);
			rock.CFrame = $mul(CFrame.new($mc(start, "Lerp", p.Position, e)), CFrame.Angles($mul(k, 8), $mul(k, 5), 0));
		}, function () {
			$mc(rock, "Destroy");
			$sp(H.Explosion({ Position: $add(p.Position, Vector3.new(0, 1, 0)), Radius: p.Radius, Color: color, Kind: ($n(($a(star) && "water")) ?? undefined) }));
			if ($t(star)) {
				burst($add(p.Position, Vector3.new(0, 1, 0)), color, 20, 1, 20, TEX.Sparkle);
			} else {
				shards($add(p.Position, Vector3.new(0, 0.5, 0)), C(70, 40, 30), 6, 28, 0.8, Enum.Material.Basalt);
				$sp(H.FireSpot({ Position: p.Position, Duration: 1.8, Size: 2 }));
			}
		});
	};
	H.Fin = function (p) {
		let root = rootOf(p.Model);
		if (!$t(root)) {
			return;
		}
		let feet = ($n(feetOf(p.Model)) ?? root.Position);
		let size = math.max(1, (root.Size.Y * 0.6));
		let fin = fxPart({ Shape: Enum.PartType.Wedge, Size: Vector3.new(0.35, $mul(2.6, size), $mul(2.4, size)), Color: C(80, 120, 160), Material: Enum.Material.SmoothPlastic });
		let dur = ($n(p.Duration) ?? 0.25);
		animate(dur, function (k) {
			if (!$t(root.Parent)) {
				return true;
			}
			let f = ($n(feetOf(p.Model)) ?? feet);
			fin.CFrame = $mul($mul(CFrame.new($add(f, Vector3.new(0, $mul(1.3, size), 0))), root.CFrame.Rotation), CFrame.Angles(0, math.pi, 0));
			fin.Transparency = ($n(((k > 0.8) && $div(($sub(k, 0.8)), 0.2))) ?? 0);
			return undefined;
		}, function () {
			$mc(fin, "Destroy");
		});
		burst($add(feet, Vector3.new(0, 0.5, 0)), C(200, 230, 255), 6, 0.8, 10, TEX.Sparkle, { Acceleration: Vector3.new(0, (-30), 0) });
		dust(feet, C(150, 125, 95), 3, 1.5, 5);
		if (!$t(crowded(4))) {
			groundRing(feet, 0.5, $mul(2.5, size), C(170, 210, 240), 0.5, { Thick: 0.25, Height: 0.1, Segs: 10 });
		}
	};
	H.Geyser = function (p) {
		let pos = p.Position, r = ($n(p.Radius) ?? 8);
		$sp(H.Explosion({ Position: $add(pos, Vector3.new(0, 1, 0)), Radius: r, Color: C(90, 180, 255), Kind: "water" }));
		let col = fxPart({ Shape: Enum.PartType.Cylinder, Size: Vector3.new(1, $mul(r, 0.9), $mul(r, 0.9)), CFrame: $mul(CFrame.new(pos), CFrame.Angles(0, 0, math.rad(90))), Color: C(150, 210, 255), Material: Enum.Material.Glass, Transparency: 0.25 });
		animate(0.7, function (k) {
			let h = ((18 * math.sin($mul($mul(math.min(1, $mul(k, 1.4)), math.pi), 0.5))) * ((1 - ((math.max(0, $sub(k, 0.7)) / 0.3) * 0.5))));
			col.Size = Vector3.new(math.max(0.5, h), $mul($mul(r, 0.9), ($sub(1, $mul(k, 0.5)))), $mul($mul(r, 0.9), ($sub(1, $mul(k, 0.5)))));
			col.CFrame = $mul(CFrame.new($add(pos, Vector3.new(0, $div(h, 2), 0))), CFrame.Angles(0, 0, math.rad(90)));
			col.Transparency = (0.25 + (0.75 * math.max(0, $div(($sub(k, 0.5)), 0.5))));
		}, function () {
			$mc(col, "Destroy");
		});
		burst($add(pos, Vector3.new(0, 14, 0)), C(210, 240, 255), 30, 1.2, 25, TEX.Sparkle, { Acceleration: Vector3.new(0, (-60), 0), Drag: 0.5, Lifetime: NumberRange.new(0.8, 1.3) });
		let puddle = disc(pos, $mul(r, 0.7), C(120, 180, 230), 0.5, Enum.Material.Glass);
		task.delay(1.5, function () {
			tween(puddle, 1, { Transparency: 1 });
		});
		$mc(Debris, "AddItem", puddle, 2.6);
	};
	H.Projectile = function (p) {
		let proj = Instance.new("Model");
		let parts = [];
		let color = C(245, 240, 225);
		if ((p.Kind === "bone")) {
			let mid = fxPart({ Size: Vector3.new(1.8, 0.4, 0.4), Color: color, Material: Enum.Material.SmoothPlastic, Shape: Enum.PartType.Cylinder });
			$ins(parts, [mid, CFrame.new()]);
			for (let $v104 = 0, $v105 = $arr([(-0.9), 0.9]); $v104 < $v105.length; $v104++) {
				let x = $v105[$v104];
				if (x == null) break;
				for (let $v106 = 0, $v107 = $arr([(-0.2), 0.2]); $v106 < $v107.length; $v106++) {
					let z = $v107[$v106];
					if (z == null) break;
					let knob = fxPart({ Size: $mul(Vector3.one, 0.55), Shape: Enum.PartType.Ball, Color: color, Material: Enum.Material.SmoothPlastic });
					$ins(parts, [knob, CFrame.new(x, 0, z)]);
				}
			}
		} else {
			color = C(235, 220, 180);
			let strip = fxPart({ Size: Vector3.new(0.7, 0.1, 3.2), Color: color, Material: Enum.Material.Fabric });
			$ins(parts, [strip, CFrame.new()]);
		}
		for (let $v108 = 0, $v109 = $arr(parts); $v108 < $v109.length; $v108++) {
			let entry = $v109[$v108];
			if (entry == null) break;
			$get(entry, 1).Parent = proj;
		}
		proj.Parent = folder;
		let main = $get($get(parts, 1), 1);
		let a0 = Instance.new("Attachment");
		a0.Position = Vector3.new(0.9, 0, 0);
		a0.Parent = main;
		let a1 = Instance.new("Attachment");
		a1.Position = Vector3.new((-0.9), 0, 0);
		a1.Parent = main;
		let tr = Instance.new("Trail");
		tr.Attachment0 = a0;
		tr.Attachment1 = a1;
		tr.Color = ColorSequence.new(color);
		tr.Transparency = NS(0, 0.4, 1, 1);
		tr.Lifetime = 0.2;
		tr.Parent = main;
		let dur = ($n(p.Duration) ?? 0.35);
		let from = p.From, to = p.To;
		let side = flat($sub(to, from));
		side = ($n(((side.Magnitude > 0.1) && Vector3.new((-side.Z), 0, side.X).Unit)) ?? Vector3.new(1, 0, 0));
		let curve = ($n(p.Curve) ?? 0);
		let total = ($n(($a(p.Return) && $mul(dur, 2))) ?? dur);
		animate(total, function (_, t) {
			let pos;
			if ((t <= dur)) {
				let k = $div(t, dur);
				pos = $add($add($mc(from, "Lerp", to, k), $mul($mul(side, math.sin($mul(k, math.pi))), curve)), Vector3.new(0, (math.sin($mul(k, math.pi)) * 2), 0));
			} else {
				let k = $div(($sub(t, dur)), dur);
				pos = $add($sub($mc(to, "Lerp", from, k), $mul($mul(side, math.sin($mul(k, math.pi))), curve)), Vector3.new(0, (math.sin($mul(k, math.pi)) * 1.5), 0));
			}
			let cf = $mul(CFrame.new(pos), CFrame.Angles(0, $mul(t, 25), ($n(((p.Kind === "bone") && 0)) ?? $mul(t, 6))));
			for (let $v110 = 0, $v111 = $arr(parts); $v110 < $v111.length; $v110++) {
				let entry = $v111[$v110];
				if (entry == null) break;
				$get(entry, 1).CFrame = $mul(cf, $get(entry, 2));
			}
		}, function () {
			$mc(proj, "Destroy");
		});
		if ((p.Kind === "bone")) {
			task.delay(dur, function () {
				burst(to, WHITE, 6, 0.7, 14, TEX.Spark);
			});
		}
	};
	H.Tractor = function (p) {
		let a = rootOf(p.From), b = rootOf(p.To);
		if (!($t(a) && $t(b))) {
			return;
		}
		let color = ($n(p.Color) ?? C(120, 255, 160));
		let dur = ($n(p.Duration) ?? 1.2);
		let beam = fxPart({ Shape: Enum.PartType.Cylinder, Size: Vector3.new(1, 3, 3), Color: color, Transparency: 0.55 });
		let core = fxPart({ Shape: Enum.PartType.Cylinder, Size: Vector3.new(1, 0.8, 0.8), Color: WHITE, Transparency: 0.2 });
		let ringsList = [];
		for (let i = 1, $v112 = 3; i <= $v112; i++) {
			$set(ringsList, i, ringParts(12, color));
		}
		let glow = Instance.new("PointLight");
		glow.Color = color;
		glow.Range = 14;
		glow.Brightness = 3;
		glow.Parent = b;
		let pull = emitter(b, { Enabled: true, Rate: $mul(30, quality()), Color: ColorSequence.new(color), Size: NS(0, 0.5, 1, 0), Lifetime: NumberRange.new(0.4, 0.7), Speed: NumberRange.new(4, 8), EmissionDirection: Enum.NormalId.Top, Acceleration: Vector3.new(0, 15, 0), SpreadAngle: Vector2.new(40, 40) });
		animate(dur, function (_, t) {
			if (!($t(a.Parent) && $t(b.Parent))) {
				return true;
			}
			let head = ($n(headOf(p.From)) ?? a);
			let from = head.Position;
			let len = ($sub(b.Position, from)).Magnitude;
			let w = (3 + (math.sin($mul(t, 20)) * 0.3));
			let cf = $mul($mul(CFrame.lookAt(from, b.Position), CFrame.new(0, 0, $div($unm(len), 2))), CFrame.Angles(0, math.rad(90), 0));
			beam.Size = Vector3.new(len, w, w);
			beam.CFrame = cf;
			core.Size = Vector3.new(len, 0.6, 0.6);
			core.CFrame = cf;
			let r = ((math.max(b.Size.X, b.Size.Z) * 0.9) + 1);
			for (let $v113 = 0, $v114 = $arr(ringsList); $v113 < $v114.length; $v113++) {
				let list = $v114[$v113];
				if (list == null) break;
				let i = $v113 + 1;
				let phase = $mod(($add($mul(t, 0.8), (i / 3))), 1);
				placeRing(list, $mul(CFrame.new($sub(b.Position, Vector3.new(0, b.Size.Y, 0))), CFrame.new(0, $mul($mul(phase, b.Size.Y), 3), 0)), $mul(r, ($sub(1, $mul(phase, 0.3)))), 0.25, 0.2, $mul(t, 3), phase);
			}
			return undefined;
		}, function () {
			$mc(beam, "Destroy");
			$mc(core, "Destroy");
			for (let $v115 = 0, $v116 = $arr(ringsList); $v115 < $v116.length; $v115++) {
				let list = $v116[$v115];
				if (list == null) break;
				for (let $v117 = 0, $v118 = $arr(list); $v117 < $v118.length; $v117++) {
					let s = $v118[$v117];
					if (s == null) break;
					$mc(s, "Destroy");
				}
			}
			$mc(glow, "Destroy");
			$mc(pull, "Destroy");
		});
	};
	H.SonicBoom = function (p) {
		let pos = p.Position;
		let color = ($n(p.Color) ?? C(255, 230, 100));
		let d = flat(($n(p.Direction) ?? Vector3.new(0, 0, (-1))));
		d = ($n(((d.Magnitude > 0.01) && d.Unit)) ?? Vector3.new(0, 0, (-1)));
		ringWave($mul(CFrame.lookAt(pos, $add(pos, d)), CFrame.Angles(math.rad((-90)), 0, 0)), 0.5, ($n(p.Radius) ?? 6), WHITE, 0.3, { Thick: 0.3, Height: 0.3, Segs: 14 });
		ringWave($mul(CFrame.lookAt(pos, $add(pos, d)), CFrame.Angles(math.rad((-90)), 0, 0)), 0.5, $mul((($n(p.Radius) ?? 6)), 0.7), color, 0.35, { Thick: 0.4, Height: 0.6, Segs: 14, Rise: 2 });
		flashBall(pos, 1.6, WHITE, 0.12);
		burst(pos, color, 8, 0.6, 26, TEX.Spark);
	};
	H.Circle = function (p) {
		let pos = p.Position, r = ($n(p.Radius) ?? 12), dur = ($n(p.Duration) ?? 2);
		let color = ($n(p.Color) ?? C(200, 20, 60));
		if ((p.Kind !== "hell")) {
			$sp(H.Telegraph({ Position: pos, Radius: r, Duration: dur, Color: color }));
			return;
		}
		let pit = disc(pos, 0.5, C(10, 0, 5), 0.1, Enum.Material.SmoothPlastic);
		let glow = disc($add(pos, Vector3.new(0, 0.02, 0)), 0.5, color, 0.6);
		let outer = ringParts(math.max(14, math.floor($mul(28, ($add(0.5, $mul(0.5, quality())))))), color);
		let inner = ringParts(math.max(10, math.floor($mul(20, ($add(0.5, $mul(0.5, quality())))))), C(255, 80, 60));
		let spokes = [];
		for (let i = 1, $v119 = 5; i <= $v119; i++) {
			$set(spokes, i, fxPart({ Size: Vector3.new(0.3, 0.1, 1), Color: color, Transparency: 0.1 }));
		}
		let smoke = anchor($add(pos, Vector3.new(0, 0.5, 0)), $add(dur, 3));
		let e = emitter(smoke, { Texture: TEX.Smoke, Enabled: true, Rate: $mul(25, quality()), LightEmission: 0.3, Color: CS(0, C(160, 0, 40), 1, C(30, 0, 10)), Size: NS(0, 2, 1, 6), Transparency: NS(0, 0.4, 1, 1), Lifetime: NumberRange.new(1, 1.6), Speed: NumberRange.new(4, 9), SpreadAngle: Vector2.new(25, 25), EmissionDirection: Enum.NormalId.Top });
		let l = Instance.new("PointLight");
		l.Color = color;
		l.Range = $mul(r, 2);
		l.Brightness = 0;
		l.Parent = smoke;
		animate(dur, function (k, t) {
			let open = outCubic(math.min(1, $div(t, 0.5)));
			let close = ($n(((k > 0.85) && $div(($sub(k, 0.85)), 0.15))) ?? 0);
			let cf = CFrame.new($add(pos, Vector3.new(0, 0.12, 0)));
			setDiscRadius(pit, $mul($mul(r, 0.8), open));
			setDiscRadius(glow, $mul(r, open));
			pit.Transparency = $add(0.1, $mul(0.9, close));
			glow.Transparency = $add($add(0.6, $mul(0.4, close)), (math.sin($mul(t, 8)) * 0.05));
			placeRing(outer, cf, $mul(r, open), 0.5, 0.25, $mul(t, 0.8), $add(0.05, $mul(0.95, close)));
			placeRing(inner, cf, $mul($mul(r, 0.62), open), 0.35, 0.25, $mul($unm(t), 1.4), $add(0.05, $mul(0.95, close)));
			for (let $v120 = 0, $v121 = $arr(spokes); $v120 < $v121.length; $v120++) {
				let s = $v121[$v120];
				if (s == null) break;
				let i = $v120 + 1;
				let a0 = $add($mul($mul(((i / 5)), math.pi), 2), $mul(t, 0.8));
				let a1 = $add($mul($mul(((((i + 2)) / 5)), math.pi), 2), $mul(t, 0.8));
				let p0 = $add($add(pos, $mul($mul($mul(Vector3.new(math.cos(a0), 0, math.sin(a0)), r), 0.95), open)), Vector3.new(0, 0.14, 0));
				let p1 = $add($add(pos, $mul($mul($mul(Vector3.new(math.cos(a1), 0, math.sin(a1)), r), 0.95), open)), Vector3.new(0, 0.14, 0));
				let len = ($sub(p1, p0)).Magnitude;
				s.Size = Vector3.new(0.3, 0.1, math.max(0.1, len));
				s.CFrame = $mul(CFrame.lookAt(p0, $add(p1, Vector3.new(0, 0.001, 0))), CFrame.new(0, 0, $div($unm(len), 2)));
				s.Transparency = $add(0.1, $mul(0.9, close));
			}
			l.Brightness = $mul($mul(3, open), ($sub(1, close)));
		}, function () {
			$mc(pit, "Destroy");
			$mc(glow, "Destroy");
			for (let $v122 = 0, $v123 = $arr(outer); $v122 < $v123.length; $v122++) {
				let s = $v123[$v122];
				if (s == null) break;
				$mc(s, "Destroy");
			}
			for (let $v124 = 0, $v125 = $arr(inner); $v124 < $v125.length; $v124++) {
				let s = $v125[$v124];
				if (s == null) break;
				$mc(s, "Destroy");
			}
			for (let $v126 = 0, $v127 = $arr(spokes); $v126 < $v127.length; $v126++) {
				let s = $v127[$v126];
				if (s == null) break;
				$mc(s, "Destroy");
			}
			e.Enabled = false;
		});
	};
	H.SpectralBite = function (p) {
		let from = p.From, to = p.To;
		let color = ($n(p.Color) ?? C(255, 50, 90));
		let skull = fxPart({ Shape: Enum.PartType.Ball, Size: Vector3.new(2.6, 2.2, 3), Color: C(40, 0, 15), Transparency: 0.2 });
		let eyeL = fxPart({ Shape: Enum.PartType.Ball, Size: $mul(Vector3.one, 0.5), Color: color });
		let eyeR = fxPart({ Shape: Enum.PartType.Ball, Size: $mul(Vector3.one, 0.5), Color: color });
		let att = Instance.new("Attachment");
		att.Parent = skull;
		let trail = emitter(att, { Texture: TEX.Smoke, Enabled: true, Rate: $mul(40, quality()), LightEmission: 0.4, Color: CS(0, color, 1, C(20, 0, 10)), Size: NS(0, 1.6, 1, 0.3), Transparency: NS(0, 0.3, 1, 1), Lifetime: NumberRange.new(0.3, 0.5), Speed: NumberRange.new(0, 1) });
		let dur = 0.35;
		animate(dur, function (k) {
			let pos = $add($mc(from, "Lerp", to, outCubic(k)), Vector3.new(0, (math.sin($mul(k, math.pi)) * 3), 0));
			let cf = CFrame.lookAt(pos, $add(to, Vector3.new(0, 0.001, 0)));
			skull.CFrame = cf;
			eyeL.CFrame = $mul(cf, CFrame.new((-0.6), 0.4, (-1.2)));
			eyeR.CFrame = $mul(cf, CFrame.new(0.6, 0.4, (-1.2)));
		}, function () {
			trail.Enabled = false;
			$mc(Debris, "AddItem", skull, 0.5);
			skull.Transparency = 1;
			$mc(eyeL, "Destroy");
			$mc(eyeR, "Destroy");
			$sp(H.BiteMark({ Position: to, Direction: $sub(to, from), Color: color, Big: p.Big }));
			burst(to, C(40, 0, 20), 10, 2, 8, TEX.Smoke, { LightEmission: 0 });
		});
	};
	H.TitanGrow = function (p) {
		let model = p.Model;
		let root = rootOf(model);
		if (!$t(root)) {
			return;
		}
		let feet = ($n(feetOf(model)) ?? root.Position);
		let size = $mc(model, "GetExtentsSize");
		dust(feet, C(180, 160, 130), 18, (2 + (size.X * 0.2)), (16 + size.X));
		groundRing(feet, (size.X * 0.4), ((size.X * 0.9) + 6), C(255, 210, 120), 0.45, { Thick: 0.8, Height: 0.8 });
		burst(root.Position, C(255, 220, 140), 14, 1.2, 14, TEX.Glow);
		if ((highlightCount < 6)) {
			highlightCount = $add(highlightCount, 1);
			let hl = Instance.new("Highlight");
			hl.FillColor = C(255, 200, 90);
			hl.FillTransparency = 0.45;
			hl.OutlineColor = C(255, 230, 160);
			hl.OutlineTransparency = 0.2;
			hl.DepthMode = Enum.HighlightDepthMode.Occluded;
			hl.Parent = model;
			tween(hl, 0.35, { FillTransparency: 1, OutlineTransparency: 1 });
			task.delay(0.36, function () {
				highlightCount = $sub(highlightCount, 1);
				$mc(hl, "Destroy");
			});
		}
	};
	H.TitanAura = function (p) {
		let model = p.Model;
		let root = rootOf(model);
		if (!$t(root)) {
			return;
		}
		let torso = ($n($mc(model, "FindFirstChild", "Torso")) ?? root);
		let dur = ($n(p.Duration) ?? 8);
		let heat = emitter(torso, { Texture: TEX.Smoke, Enabled: true, Rate: $mul(14, quality()), LightEmission: 0.5, Color: CS(0, C(255, 190, 90), 1, C(120, 60, 30)), Size: NS(0, 1.5, 1, 5), Transparency: NS(0, 0.65, 1, 1), Lifetime: NumberRange.new(0.8, 1.4), Speed: NumberRange.new(3, 6), EmissionDirection: Enum.NormalId.Top, Shape: Enum.ParticleEmitterShape.Box, Acceleration: Vector3.new(0, 4, 0) });
		let sparks = embers(torso, 18, C(255, 200, 90));
		sparks.Shape = Enum.ParticleEmitterShape.Box;
		let nextStep = 0;
		animate($add(dur, 1), function (_, t) {
			if (!($t(root.Parent) && $t(model.Parent))) {
				return true;
			}
			if (((t > 0.5) && ($mc(model, "GetAttribute", "Raging") !== true))) {
				return true;
			}
			let v = flat(root.AssemblyLinearVelocity).Magnitude;
			if (((v > 3) && (t >= nextStep))) {
				nextStep = $add(t, 0.42);
				let feet = feetOf(model);
				if ($t(feet)) {
					dust(feet, C(170, 150, 120), 6, 2.5, 10);
					if (!$t(crowded(3))) {
						groundRing(feet, 1, ((root.Size.X * 1.4) + 3), C(220, 190, 140), 0.3, { Thick: 0.4, Height: 0.2, Segs: 10 });
					}
					shakeAt(feet, 0.12, 40, 0.15);
				}
			}
			return undefined;
		}, function () {
			heat.Enabled = false;
			sparks.Enabled = false;
			$mc(Debris, "AddItem", heat, 1.5);
			$mc(Debris, "AddItem", sparks, 1.5);
		});
	};
	H.PhoenixRise = function (p) {
		let model = p.Model;
		let root = rootOf(model);
		if (!$t(root)) {
			return;
		}
		let dur = ($n(p.Duration) ?? 1.2);
		let list = [];
		let wings = partsNamed(model, function (n) {
			return (n === "AsaMembrana");
		});
		let hosts = ($n((($len(wings) > 0) && wings)) ?? [($n($mc(model, "FindFirstChild", "Torso")) ?? root)]);
		for (let $v128 = 0, $v129 = $arr(hosts); $v128 < $v129.length; $v128++) {
			let w = $v129[$v128];
			if (w == null) break;
			let f = fireEmitter(w, 40, 2.4);
			f.Shape = Enum.ParticleEmitterShape.Box;
			f.SpreadAngle = Vector2.new(60, 60);
			$ins(list, f);
		}
		$ins(list, embers(root, 30));
		$sp(H.Streak({ Model: model, Color: C(255, 140, 30), Duration: dur, Width: 2.5, Neon: true, Lifetime: 0.45 }));
		let feet = ($n(feetOf(model)) ?? root.Position);
		$sp(H.Ignite({ Position: feet, Radius: 5, Duration: 1 }));
		light(root.Position, C(255, 150, 50), 24, dur, 4);
		task.delay(dur, function () {
			for (let $v130 = 0, $v131 = $arr(list); $v130 < $v131.length; $v130++) {
				let e = $v131[$v130];
				if (e == null) break;
				e.Enabled = false;
				$mc(Debris, "AddItem", e, 1.2);
			}
		});
	};
	H.Vortex = function (p) {
		let pos = p.Position, r = ($n(p.Radius) ?? 18), dur = ($n(p.Duration) ?? 2);
		let color = C(170, 90, 255);
		let base = disc(pos, 0.5, C(15, 0, 30), 0.15, Enum.Material.SmoothPlastic);
		let core = fxPart({ Shape: Enum.PartType.Ball, Size: Vector3.one, CFrame: CFrame.new($add(pos, Vector3.new(0, 2, 0))), Color: C(10, 0, 20), Material: Enum.Material.SmoothPlastic });
		let halo = fxPart({ Shape: Enum.PartType.Ball, Size: Vector3.one, CFrame: CFrame.new($add(pos, Vector3.new(0, 2, 0))), Color: color, Transparency: 0.6 });
		let arms = [];
		let nArms = 4, perArm = math.max(4, math.floor($mul(9, ($add(0.5, $mul(0.5, quality()))))));
		for (let a = 1, $v132 = nArms; a <= $v132; a++) {
			for (let i = 1, $v133 = perArm; i <= $v133; i++) {
				$ins(arms, [fxPart({ Size: Vector3.new(0.4, 0.15, 1.5), Color: ($n((($mod(i, 2) === 0) && color)) ?? C(220, 170, 255)), Transparency: 0.2 }), a, i]);
			}
		}
		let sucker = fxPart({ Shape: Enum.PartType.Cylinder, Size: Vector3.new(2, $mul(r, 2), $mul(r, 2)), CFrame: $mul(CFrame.new($add(pos, Vector3.new(0, 1.5, 0))), CFrame.Angles(0, 0, math.rad(90))), Transparency: 1 });
		let e = emitter(sucker, { Enabled: true, Rate: $mul(70, quality()), Color: CS(0, C(230, 200, 255), 1, color), Size: NS(0, 0.9, 1, 0), Lifetime: NumberRange.new(0.5, 0.8), Speed: NumberRange.new((-26), (-18)), Shape: Enum.ParticleEmitterShape.Cylinder, ShapeStyle: Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut: Enum.ParticleEmitterShapeInOut.Outward });
		let swirl = anchor($add(pos, Vector3.new(0, 2, 0)), $add(dur, 2));
		let sw = emitter(swirl, { Texture: TEX.Swirl, Enabled: true, Rate: $mul(6, quality()), LightEmission: 1, Color: ColorSequence.new(color), Size: NS(0, $mul(r, 0.9), 1, 1), Transparency: NS(0, 0.6, 1, 1), Lifetime: NumberRange.new(0.8, 1), Speed: NumberRange.new(0, 0), RotSpeed: NumberRange.new(200, 300), Rotation: NumberRange.new(0, 360) });
		let l = Instance.new("PointLight");
		l.Color = color;
		l.Range = $mul(r, 1.5);
		l.Brightness = 3;
		l.Parent = swirl;
		animate(dur, function (k, t) {
			let open = outCubic(math.min(1, $div(t, 0.4)));
			setDiscRadius(base, $mul(r, open));
			let cs = $add($add(3, $mul(2.5, k)), (math.sin($mul(t, 12)) * 0.3));
			core.Size = $mul(Vector3.one, cs);
			halo.Size = $mul(Vector3.one, ($mul(cs, 1.5)));
			for (let $v134 = 0, $v135 = $arr(arms); $v134 < $v135.length; $v134++) {
				let entry = $v135[$v134];
				if (entry == null) break;
				let part = $get(entry, 1), a = $get(entry, 2), i = $get(entry, 3);
				let u = $div(i, perArm);
				let rr = $mul($mul(r, open), ($sub(1, $mul(u, 0.85))));
				let ang = $add($add($mul($mul($div(a, nArms), math.pi), 2), $mul(u, 2.6)), $mul(t, ($add(3, $mul(2, k)))));
				let at = $add(pos, Vector3.new($mul(math.cos(ang), rr), $add(0.2, $mul(u, 0.8)), $mul(math.sin(ang), rr)));
				let tangent = Vector3.new((-math.sin(ang)), 0, math.cos(ang));
				part.CFrame = CFrame.lookAt(at, $add(at, tangent));
				part.Size = Vector3.new($mul(0.5, ($sub(1, $mul(u, 0.5)))), 0.15, $add($mul($mul(2.2, ($sub(1, $mul(u, 0.5)))), open), 0.1));
			}
		}, function () {
			e.Enabled = false;
			sw.Enabled = false;
			l.Enabled = false;
			tween(base, 0.3, { Transparency: 1 });
			$mc(Debris, "AddItem", base, 0.35);
			$mc(core, "Destroy");
			$mc(halo, "Destroy");
			$mc(sucker, "Destroy");
			for (let $v136 = 0, $v137 = $arr(arms); $v136 < $v137.length; $v136++) {
				let entry = $v137[$v136];
				if (entry == null) break;
				$mc($get(entry, 1), "Destroy");
			}
		});
	};
	Effects.Start = function () {
		let packs = $mc($script.Parent, "FindFirstChild", "EffectsPacks");
		if ($t(packs)) {
			for (let $v138 = 0, $v139 = $arr($mc(packs, "GetChildren")); $v138 < $v139.length; $v138++) {
				let module = $v139[$v138];
				if (module == null) break;
				if ($t($mc(module, "IsA", "ModuleScript"))) {
					let [ok, err] = $lst([], pcall(function () {
						$sp($sp1(require(module))(H, Effects));
					}), 2);
					if (!$t(ok)) {
						warn("[Effects] pacote falhou", module.Name, err);
					}
				}
			}
		}
		let remotes = $mc(ReplicatedStorage, "WaitForChild", "Remotes");
		$mc(remotes.Effect.OnClientEvent, "Connect", function (name, params) {
			let handler = $get(H, name);
			if (($t(handler) && (type(params) === "table"))) {
				let [ok, err] = $lst([], pcall(handler, params), 2);
				if (!$t(ok)) {
					warn("[Effects]", name, err);
				}
			}
		});
	};
	return Effects;
}
