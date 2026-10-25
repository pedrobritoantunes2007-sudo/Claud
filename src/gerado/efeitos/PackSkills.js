// Gerado automaticamente de client/EffectsPacks/PackSkills.lua (código do jogo Roblox) por tools/lua2js — não edite à mão.
import { $t, $a, $n, $1, $M, $mv, $lst, $get, $set, $tm, $tc, $len, $cat, $eq, $add, $sub, $mul, $div, $mod, $pow, $idiv, $unm, $mc, $cy, $sp, $sp1, $W, $WS, $ins, $ins3, $arr, $pairs, $iter, $pcallG, $warnWait } from '../../rbx/lua.js';

export default function ($G, $script) {
	let game = $G["game"], require = $G["require"], Color3 = $G["Color3"], math = $G["math"], Enum = $G["Enum"], Vector3 = $G["Vector3"], workspace = $G["workspace"], Instance = $G["Instance"], pairs = $G["pairs"], ipairs = $G["ipairs"], table = $G["table"], NumberSequenceKeypoint = $G["NumberSequenceKeypoint"], NumberSequence = $G["NumberSequence"], ColorSequenceKeypoint = $G["ColorSequenceKeypoint"], ColorSequence = $G["ColorSequence"], os = $G["os"], pcall = $G["pcall"], warn = $G["warn"], typeof$1 = $G["typeof"], NumberRange = $G["NumberRange"], Vector2 = $G["Vector2"], TweenInfo = $G["TweenInfo"], task = $G["task"], CFrame = $G["CFrame"], UDim2 = $G["UDim2"], tostring = $G["tostring"];
	const $va = [];
	let Debris = $mc(game, "GetService", "Debris");
	let Lighting = $mc(game, "GetService", "Lighting");
	let Players = $mc(game, "GetService", "Players");
	let RunService = $mc(game, "GetService", "RunService");
	let TweenService = $mc(game, "GetService", "TweenService");
	let SkillArt = $sp1(require($mc($script.Parent.Parent, "WaitForChild", "SkillArt")));
	let C = Color3.fromRGB;
	let WHITE = Color3.new(1, 1, 1);
	let BLACK = C(25, 20, 30);
	let TAU = $mul(math.pi, 2);
	let NEON = Enum.Material.Neon;
	let GLASS = Enum.Material.Glass;
	let UP = Vector3.new(0, 1, 0);
	let TEX = { Sparkle: "rbxasset://textures/particles/sparkles_main.dds", Smoke: "rbxasset://textures/particles/smoke_main.dds", Fire: "rbxasset://textures/particles/fire_main.dds", Spark: "rbxasset://textures/particles/fire_sparks_main.dds", Glow: "rbxasset://textures/particles/forcefield_glow_main.dds", Swirl: "rbxasset://textures/particles/forcefield_vortex_main.dds" };
	let RAINBOW = [C(255, 70, 80), C(255, 160, 50), C(255, 230, 70), C(90, 220, 110), C(80, 170, 255), C(170, 100, 255)];
	let CONFETTI = [C(255, 80, 90), C(255, 200, 60), C(90, 220, 120), C(80, 170, 255), C(200, 110, 255), C(255, 140, 200)];
	return function (H, Effects) {
		let player = Players.LocalPlayer;
		let QUALITY = { Alto: 1, "Médio": 0.6, Baixo: 0.3 };
		let quality = function () {
			return ($n($get(QUALITY, ($n(($a(player) && $mc(player, "GetAttribute", "GraphicsQuality"))) ?? "Alto"))) ?? 1);
		};
		let q = function (n) {
			return math.max(1, math.floor($add($mul(n, quality()), 0.5)));
		};
		let folder = $mc(workspace, "FindFirstChild", "FX");
		if (!$t(folder)) {
			folder = Instance.new("Folder");
			folder.Name = "FX";
			folder.Parent = workspace;
		}
		let MAX_PARTS = 380;
		let myParts = 0;
		let full = function (extra) {
			return ($add(myParts, (($n(extra) ?? 0))) > $mul(MAX_PARTS, ($add(0.4, $mul(0.6, quality())))));
		};
		let track = function (p) {
			myParts = $add(myParts, 1);
			$mc(p.Destroying, "Connect", function () {
				myParts = $sub(myParts, 1);
			});
			$mc(Debris, "AddItem", p, 16);
		};
		let fxPart = function (props) {
			let p = Instance.new("Part");
			p.Anchored = true;
			p.CanCollide = false;
			p.CanQuery = false;
			p.CanTouch = false;
			p.CastShadow = false;
			p.Material = NEON;
			p.TopSurface = Enum.SurfaceType.Smooth;
			p.BottomSurface = Enum.SurfaceType.Smooth;
			for (let [k, v] of $pairs(props)) {
				$set(p, k, v);
			}
			track(p);
			p.Parent = folder;
			return p;
		};
		let build = function (motif, size, c1, c2, force) {
			if ((!$t(motif) || !$t($sp1(SkillArt.Has(motif))))) {
				return undefined;
			}
			if ((!$t(force) && $t(full(6)))) {
				return undefined;
			}
			let rig = $sp1(SkillArt.Build(motif, ($n(size) ?? 1), c1, c2, folder));
			if ($t(rig)) {
				for (let $v1 = 0, $v2 = $arr(rig.Parts); $v1 < $v2.length; $v1++) {
					let p = $v2[$v1];
					if (p == null) break;
					track(p);
				}
			}
			return rig;
		};
		let NS = function (...$va) {
			let a = [...$va];
			let kps = [];
			for (let i = 1, $v3 = $len(a); i <= $v3; i += 2) {
				$ins(kps, NumberSequenceKeypoint.new($get(a, i), $get(a, (i + 1))));
			}
			return NumberSequence.new(kps);
		};
		let CS = function (...$va) {
			let a = [...$va];
			let kps = [];
			for (let i = 1, $v4 = $len(a); i <= $v4; i += 2) {
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
		let smooth = function (k) {
			k = math.clamp(k, 0, 1);
			return $mul($mul(k, k), ($sub(3, $mul(2, k))));
		};
		let pick = function (list) {
			return $get(list, math.random(1, $len(list)));
		};
		let unitRandom = function (up) {
			let v = Vector3.new(rnd((-1), 1), $add(rnd((-1), 1), (($n(up) ?? 0))), rnd((-1), 1));
			return ($n(((v.Magnitude > 0.01) && v.Unit)) ?? UP);
		};
		let anims = [];
		let animate = function (duration, fn, done) {
			$ins(anims, { Start: os.clock(), Last: os.clock(), Dur: math.max(duration, 0.001), Fn: fn, Done: done });
		};
		$mc(RunService.RenderStepped, "Connect", function () {
			let now = os.clock();
			for (let i = $len(anims), $v5 = 1; i >= $v5; i += (-1)) {
				let a = $get(anims, i);
				let k = math.clamp($div(($sub(now, a.Start)), a.Dur), 0, 1);
				let dt = $sub(now, a.Last);
				a.Last = now;
				let [ok, stop] = $lst([], pcall(a.Fn, k, $sub(now, a.Start), dt), 2);
				if (!$t(ok)) {
					warn("[Skills] anim", stop);
				}
				if ((((k >= 1) || (stop === true)) || !$t(ok))) {
					$set(anims, i, $get(anims, $len(anims)));
					$set(anims, $len(anims), undefined);
					if ($t(a.Done)) {
						let [okDone, err] = $lst([], pcall(a.Done), 2);
						if (!$t(okDone)) {
							warn("[Skills] fim", err);
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
		let puff = function (position, color, count, size, speed, texture, extra) {
			let a = anchor(position, 3);
			let seq = color;
			if ((typeof$1(color) === "Color3")) {
				seq = ColorSequence.new(color);
			}
			let props = { Texture: ($n(texture) ?? TEX.Sparkle), Color: seq, Size: NS(0, size, 1, 0), Transparency: NS(0, 0, 0.7, 0.3, 1, 1), Lifetime: NumberRange.new(0.35, 0.8), Speed: NumberRange.new($mul(speed, 0.4), speed), SpreadAngle: Vector2.new(180, 180), Drag: 4, Rotation: NumberRange.new(0, 360), RotSpeed: NumberRange.new((-120), 120) };
			if ($t(extra)) {
				for (let [k, v] of $pairs(extra)) {
					$set(props, k, v);
				}
			}
			let e = emitter(a, props);
			$mc(e, "Emit", q(count));
			return e;
		};
		let smoke = function (position, color, count, size, speed) {
			puff(position, color, count, size, speed, TEX.Smoke, { Size: NS(0, $mul(size, 0.5), 1, $mul(size, 1.6)), Transparency: NS(0, 0.35, 1, 1), Lifetime: NumberRange.new(0.6, 1.2), LightEmission: 0, Drag: 3, Acceleration: Vector3.new(0, 3, 0) });
		};
		let lights = 0;
		let light = function (position, color, range, duration, brightness) {
			if ((lights >= math.floor($add(3, $mul(6, quality()))))) {
				return;
			}
			lights = $add(lights, 1);
			let a = anchor(position, $add(duration, 0.1));
			let l = Instance.new("PointLight");
			l.Color = color;
			l.Range = math.min(range, 60);
			l.Brightness = ($n(brightness) ?? 4);
			l.Shadows = false;
			l.Parent = a;
			$mc($mc(TweenService, "Create", l, TweenInfo.new(duration), { Brightness: 0 }), "Play");
			task.delay(duration, function () {
				lights = $sub(lights, 1);
			});
		};
		let disc = function (position, radius, color, transparency, material) {
			return fxPart({ Shape: Enum.PartType.Cylinder, Size: Vector3.new(0.12, $mul(radius, 2), $mul(radius, 2)), CFrame: $mul(CFrame.new($add(position, Vector3.new(0, 0.08, 0))), CFrame.Angles(0, 0, math.rad(90))), Color: color, Transparency: ($n(transparency) ?? 0.3), Material: ($n(material) ?? NEON) });
		};
		let setDisc = function (part, radius) {
			part.Size = Vector3.new(part.Size.X, math.max(0.1, $mul(radius, 2)), math.max(0.1, $mul(radius, 2)));
		};
		let flash = function (position, radius, color, duration) {
			let d = ($n(duration) ?? 0.25);
			let ball = fxPart({ Shape: Enum.PartType.Ball, Size: $mul($mul(Vector3.one, radius), 0.4), CFrame: CFrame.new(position), Color: color });
			animate(d, function (k) {
				ball.Size = $mul($mul(Vector3.one, radius), ($add(0.4, $mul(1.6, outCubic(k)))));
				ball.Transparency = $pow(k, 0.6);
			}, function () {
				$mc(ball, "Destroy");
			});
		};
		let groundRing = function (position, r0, r1, color, duration, thick) {
			let n = math.max(10, math.floor($mul(18, ($add(0.5, $mul(0.5, quality()))))));
			let list = [];
			for (let _ = 1, $v6 = n; _ <= $v6; _++) {
				$ins(list, fxPart({ Size: Vector3.new(0.3, 0.3, 1), Color: color }));
			}
			let th = ($n(thick) ?? math.max(0.4, $mul(r1, 0.07)));
			let cf = CFrame.new($add(position, Vector3.new(0, 0.12, 0)));
			animate(duration, function (k) {
				let e = outCubic(k);
				let r = $add(r0, $mul(($sub(r1, r0)), e));
				let arc = $mul($div($mul(TAU, r), n), 1.12);
				for (let $v7 = 0, $v8 = $arr(list); $v7 < $v8.length; $v7++) {
					let p = $v8[$v7];
					if (p == null) break;
					let i = $v7 + 1;
					let a = $mul($div(i, n), TAU);
					p.Size = Vector3.new($mul(th, ($sub(1, $mul(0.7, k)))), $mul(0.3, ($sub(1, $mul(0.5, k)))), math.max(0.05, arc));
					p.CFrame = $mul($mul(cf, CFrame.Angles(0, a, 0)), CFrame.new(r, 0.15, 0));
					p.Transparency = $pow(k, 1.3);
				}
			}, function () {
				for (let $v9 = 0, $v10 = $arr(list); $v9 < $v10.length; $v9++) {
					let p = $v10[$v9];
					if (p == null) break;
					$mc(p, "Destroy");
				}
			});
		};
		let rootOf = function (model) {
			return ($a(($a(model) && model.Parent)) && model.PrimaryPart);
		};
		let headOf = function (model, index) {
			return ($a(model) && (($n($mc(model, "FindFirstChild", $cat("Head", (($n(index) ?? 1))))) ?? $mc(model, "FindFirstChild", "Head1"))));
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
		let mouthCF = function (model) {
			let head = headOf(model);
			if ($t(head)) {
				return $mul(head.CFrame, CFrame.new(0, ((-head.Size.Y) * 0.15), ((-head.Size.Z) * 0.75)));
			}
			let root = rootOf(model);
			return ($n(($a(root) && $mul(root.CFrame, CFrame.new(0, (root.Size.Y * 0.3), ((-root.Size.Z) * 0.6))))) ?? undefined);
		};
		let sizeOf = function (model) {
			let root = rootOf(model);
			return ($n(($a(root) && math.clamp((root.Size.Z / 4), 0.6, 5))) ?? 1);
		};
		let shakeAt = function (position, intensity, radius) {
			if ($t(H.Shake)) {
				$sp(H.Shake({ Position: position, Intensity: intensity, Radius: radius }));
			}
		};
		let floatText = function (position, text, color, size, life, rise, rot) {
			let a = anchor(position, $add(life, 0.1));
			let gui = Instance.new("BillboardGui");
			gui.Size = UDim2.fromOffset($mul(size, 4), $mul(size, 1.3));
			gui.AlwaysOnTop = true;
			gui.LightInfluence = 0;
			gui.MaxDistance = 170;
			gui.Parent = a;
			let label = Instance.new("TextLabel");
			label.Size = UDim2.fromScale(1, 1);
			label.BackgroundTransparency = 1;
			label.Text = text;
			label.TextColor3 = color;
			label.TextScaled = true;
			label.Font = Enum.Font.LuckiestGuy;
			label.Rotation = ($n(rot) ?? 0);
			label.Parent = gui;
			let stroke = Instance.new("UIStroke");
			stroke.Color = BLACK;
			stroke.Thickness = 3;
			stroke.Parent = label;
			let scale = Instance.new("UIScale");
			scale.Scale = 0.2;
			scale.Parent = label;
			animate(life, function (k) {
				a.Position = $add(position, Vector3.new(0, $mul(rise, outCubic(k)), 0));
				let s;
				if ((k < 0.12)) {
					s = $add(0.2, $mul(($div(k, 0.12)), 1.3));
				} else if ((k < 0.25)) {
					s = $sub(1.5, $mul(($div(($sub(k, 0.12)), 0.13)), 0.5));
				} else {
					s = 1;
				}
				scale.Scale = s;
				let fade = math.clamp($div(($sub(k, 0.7)), 0.3), 0, 1);
				label.TextTransparency = fade;
				stroke.Transparency = fade;
			});
			return label;
		};
		let toss = function (motif, pos, n, speed, size, colorFn, opts) {
			opts = ($n(opts) ?? []);
			n = q(n);
			let pieces = [];
			for (let i = 1, $v11 = n; i <= $v11; i++) {
				let col = ($n(($a(colorFn) && $sp1(colorFn(i)))) ?? undefined);
				let rig = build(motif, $mul(size, rnd(0.7, 1.25)), col, undefined);
				if (!$t(rig)) {
					break;
				}
				let dir = unitRandom(($n(opts.up) ?? 0.9));
				if ($t(opts.dir)) {
					dir = ($add(opts.dir, $mul(unitRandom(0.6), (($n(opts.cone) ?? 0.6))))).Unit;
				}
				$ins(pieces, { rig: rig, p: $add(pos, Vector3.new(rnd((-0.3), 0.3), rnd(0, 0.4), rnd((-0.3), 0.3))), v: $mul($mul(dir, speed), rnd(0.5, 1)), r: CFrame.Angles(rnd(0, TAU), rnd(0, TAU), rnd(0, TAU)), w: Vector3.new(rnd((-8), 8), rnd((-8), 8), rnd((-8), 8)) });
			}
			if (($len(pieces) === 0)) {
				return;
			}
			let floor = $sub(pos.Y, (($n(opts.below) ?? 0.4)));
			let g = ($n(opts.gravity) ?? 70);
			let life = ($n(opts.life) ?? 1.2);
			animate(life, function (k, _t, dt) {
				dt = math.min(dt, (1 / 20));
				for (let $v12 = 0, $v13 = $arr(pieces); $v12 < $v13.length; $v12++) {
					let pc = $v13[$v12];
					if (pc == null) break;
					pc.v = $sub(pc.v, Vector3.new(0, $mul(g, dt), 0));
					if ($t(opts.drag)) {
						pc.v = $mul(pc.v, ($sub(1, $mul(opts.drag, dt))));
					}
					pc.p = $add(pc.p, $mul(pc.v, dt));
					if ((pc.p.Y < floor)) {
						pc.p = Vector3.new(pc.p.X, floor, pc.p.Z);
						pc.v = Vector3.new((pc.v.X * 0.5), (math.abs(pc.v.Y) * 0.3), (pc.v.Z * 0.5));
						pc.w = $mul(pc.w, 0.5);
					}
					pc.r = $mul(pc.r, CFrame.Angles($mul(pc.w.X, dt), $mul(pc.w.Y, dt), $mul(pc.w.Z, dt)));
					$sp(SkillArt.Place(pc.rig, $mul(CFrame.new(pc.p), pc.r)));
					if ((k > 0.65)) {
						$sp(SkillArt.Fade(pc.rig, $div(($sub(k, 0.65)), 0.35)));
					}
				}
			}, function () {
				for (let $v14 = 0, $v15 = $arr(pieces); $v14 < $v15.length; $v14++) {
					let pc = $v15[$v14];
					if (pc == null) break;
					$sp(SkillArt.Destroy(pc.rig));
				}
			});
		};
		let floatUp = function (motif, pos, n, size, color, life, spread) {
			let list = [];
			for (let _ = 1, $v16 = q(n); _ <= $v16; _++) {
				let rig = build(motif, $mul(size, rnd(0.7, 1.2)), color, undefined);
				if (!$t(rig)) {
					break;
				}
				$ins(list, { rig: rig, o: Vector3.new(rnd($unm(spread), spread), rnd(0, 1), rnd($unm(spread), spread)), s: rnd(2, 5), ph: rnd(0, TAU), d: rnd(0, 0.4) });
			}
			animate(life, function (k, t) {
				for (let $v17 = 0, $v18 = $arr(list); $v17 < $v18.length; $v17++) {
					let it = $v18[$v17];
					if (it == null) break;
					let kk = math.clamp($div(($sub(t, it.d)), ($sub(life, it.d))), 0, 1);
					let p = $add($add(pos, it.o), Vector3.new((math.sin($add($mul(t, 3), it.ph)) * 0.5), $mul(it.s, kk), 0));
					let cam = workspace.CurrentCamera;
					let look = ($n(($a(cam) && flat($sub(cam.CFrame.Position, p)))) ?? Vector3.new(0, 0, 1));
					if ((look.Magnitude < 0.01)) {
						look = Vector3.new(0, 0, 1);
					}
					$sp(SkillArt.Place(it.rig, $mul(CFrame.lookAt(p, $sub(p, look)), CFrame.Angles(0, 0, (math.sin($add($mul(t, 4), it.ph)) * 0.3)))));
					$sp(SkillArt.Fade(it.rig, ($n(((kk < 0.15) && $sub(1, $div(kk, 0.15)))) ?? math.clamp($div(($sub(kk, 0.6)), 0.4), 0, 1))));
				}
			}, function () {
				for (let $v19 = 0, $v20 = $arr(list); $v19 < $v20.length; $v19++) {
					let it = $v20[$v19];
					if (it == null) break;
					$sp(SkillArt.Destroy(it.rig));
				}
			});
		};
		let IMPACT_OF = { Bone: "Bones", Stick: "Pop", Ball: "Pop", Frisbee: "Burst", HotDog: "Pop", Bubble: "Splash", Drop: "Splash", Note: "Notes", Star: "Stars", Leaf: "Leaves", Fireball: "Fire", Lava: "Fire", Acid: "Poison", Ink: "Ink", Honey: "Honey", Shard: "Shatter", Icicle: "Shatter", Snowball: "Snow", Crystal: "Crystal", Rock: "Rock", Boulder: "Rock", Missile: "Explode", Rocket: "Explode", Shell: "Explode", Cannonball: "Explode", Bomb: "Explode", Skull: "Bones", GhostSkull: "Void", Ghost: "Void", Orb: "Burst", Plasma: "Shock", Bolt: "Shock", Shuriken: "Burst", Kunai: "Burst", Feather: "Feathers", Spore: "Poison", Mushroom: "Poison", Bee: "Poison", Balloon: "Splash", Heart: "Hearts", Pom: "Pop", Coin: "Coins", Comet: "Stars", Meteor: "Explode", ArcaneOrb: "Burst", Petal: "Petals", Flower: "Petals", Sand: "Sand", Needle: "Burst", Moon: "Holy", Planet: "Explode", Barrel: "Snow", Anchor: "Rock", Blade: "Burst", Lance: "Holy", Sword: "Holy", Fist: "Shock", Confetti: "Confetti", Egg: "Fire", Tornado: "Dust", Cloud: "Dust" };
		let impact = function (kind, pos, radius, color, color2) {
			let r = ($n(radius) ?? 3);
			let col = ($n(color) ?? WHITE);
			kind = ($n(kind) ?? "Burst");
			let up = $add(pos, Vector3.new(0, 0.8, 0));
			if ((kind === "Pop")) {
				smoke(up, C(245, 245, 240), 8, 1.6, 8);
				flash(up, $mul(r, 0.6), WHITE, 0.15);
				groundRing(pos, 0.5, r, col, 0.3, 0.35);
			} else if ((kind === "Splash")) {
				puff(up, C(200, 235, 255), 26, 0.6, 26, TEX.Sparkle, { Acceleration: Vector3.new(0, (-60), 0), Drag: 1, SpreadAngle: Vector2.new(60, 60), EmissionDirection: Enum.NormalId.Top });
				groundRing(pos, 0.5, $mul(r, 1.2), $mc(col, "Lerp", C(120, 190, 255), 0.5), 0.35);
				toss("Drop", up, 6, 18, 0.5, function () {
					return $mc(col, "Lerp", C(120, 200, 255), 0.6);
				}, { life: 0.8 });
			} else if ((kind === "Explode")) {
				if ($t(H.Explosion)) {
					$sp(H.Explosion({ Position: up, Radius: r, Color: ($n(color) ?? C(255, 130, 40)) }));
				}
			} else if ((kind === "Shatter")) {
				flash(up, $mul(r, 0.5), C(220, 245, 255), 0.18);
				toss("Shard", up, 7, 26, 0.45, function () {
					return col;
				}, { life: 0.9 });
				puff(up, C(230, 250, 255), 14, 0.7, 20);
			} else if (((kind === "Dirt") || (kind === "Rock"))) {
				smoke(pos, C(150, 125, 95), 12, 2.4, 12);
				toss("Rock", up, ($n(((kind === "Rock") && 7)) ?? 5), 26, ($n(((kind === "Rock") && 0.6)) ?? 0.4), undefined, { life: 1 });
				groundRing(pos, 0.5, $mul(r, 1.1), C(170, 140, 100), 0.35);
			} else if ((kind === "Confetti")) {
				toss("Confetti", up, 22, 30, 1, function (i) {
					return $get(CONFETTI, $add(($mod(i, $len(CONFETTI))), 1));
				}, { gravity: 25, drag: 1.5, life: 1.6 });
				flash(up, $mul(r, 0.6), WHITE, 0.15);
			} else if (((kind === "Smoke") || (kind === "Dust"))) {
				smoke(up, ($n(color) ?? C(200, 200, 200)), 14, 2.5, 10);
			} else if ((kind === "Bones")) {
				toss("Bone", up, 5, 22, 0.45, undefined, { life: 1 });
				smoke(up, C(235, 225, 200), 6, 1.4, 8);
			} else if (((kind === "Leaves") || (kind === "Petals"))) {
				toss(($n(((kind === "Leaves") && "Leaf")) ?? "Petal"), up, 10, 18, 0.7, function () {
					return ($n(((kind === "Leaves") && $mc(C(90, 190, 70), "Lerp", C(160, 220, 80), math.random()))) ?? (($n(color) ?? C(255, 170, 200))));
				}, { gravity: 12, drag: 2, life: 1.5 });
			} else if ((kind === "Notes")) {
				floatUp("Note", up, 5, 0.9, ($n(color) ?? C(255, 120, 220)), 1.1, 1.5);
				groundRing(pos, 0.5, r, col, 0.35);
			} else if ((kind === "Hearts")) {
				floatUp("Heart", up, 5, 0.8, ($n(color) ?? C(255, 90, 150)), 1.1, 1.5);
			} else if ((kind === "Stars")) {
				toss("Star", up, 6, 20, 0.6, function () {
					return ($n(color) ?? C(255, 230, 90));
				}, { gravity: 30, life: 0.9 });
				flash(up, $mul(r, 0.6), ($n(color) ?? C(255, 240, 160)), 0.2);
			} else if ((kind === "Coins")) {
				toss("Coin", up, 8, 24, 0.7, undefined, { life: 1.1 });
			} else if ((kind === "Honey")) {
				let d = disc(pos, $mul(r, 0.8), C(255, 175, 30), 0.25, GLASS);
				animate(1.5, function (k) {
					d.Transparency = (0.25 + (0.75 * math.clamp($div(($sub(k, 0.6)), 0.4), 0, 1)));
				}, function () {
					$mc(d, "Destroy");
				});
				toss("Honey", up, 4, 14, 0.35, undefined, { life: 0.8 });
			} else if ((kind === "Ink")) {
				let d = disc(pos, $mul(r, 0.9), C(25, 20, 35), 0.1, GLASS);
				animate(1.8, function (k) {
					d.Transparency = (0.1 + (0.9 * math.clamp($div(($sub(k, 0.6)), 0.4), 0, 1)));
				}, function () {
					$mc(d, "Destroy");
				});
				toss("Ink", up, 5, 18, 0.4, undefined, { life: 0.8 });
			} else if ((kind === "Fire")) {
				puff(up, CS(0, C(255, 240, 180), 0.5, col, 1, C(120, 30, 10)), 20, 2.2, 18, TEX.Fire, { LightEmission: 1, Lifetime: NumberRange.new(0.3, 0.6) });
				puff(up, C(255, 190, 80), 14, 0.4, 30, TEX.Spark, { Acceleration: Vector3.new(0, (-30), 0), Drag: 1 });
				groundRing(pos, 0.5, $mul(r, 1.1), col, 0.35);
			} else if ((kind === "Holy")) {
				flash(up, $mul(r, 0.8), C(255, 245, 200), 0.25);
				for (let i = 1, $v21 = q(5); i <= $v21; i++) {
					let a = $mul((i / 5), TAU);
					let ray = fxPart({ Size: Vector3.new(0.3, $mul(r, 2), 0.3), CFrame: CFrame.new($add(pos, Vector3.new($mul($mul(math.cos(a), r), 0.4), r, $mul($mul(math.sin(a), r), 0.4)))), Color: ($n(color) ?? C(255, 230, 140)), Transparency: 0.2 });
					animate(0.5, function (k) {
						ray.Transparency = $add(0.2, $mul(0.8, k));
					}, function () {
						$mc(ray, "Destroy");
					});
				}
				groundRing(pos, 0.5, $mul(r, 1.2), ($n(color) ?? C(255, 220, 120)), 0.4);
			} else if ((kind === "Void")) {
				let ball = fxPart({ Shape: Enum.PartType.Ball, Size: $mul($mul(Vector3.one, r), 2), CFrame: CFrame.new(up), Color: C(20, 0, 35), Material: Enum.Material.SmoothPlastic, Transparency: 0.2 });
				animate(0.35, function (k) {
					ball.Size = $mul(Vector3.one, math.max(0.2, $mul($mul(r, 2), ($sub(1, k)))));
				}, function () {
					$mc(ball, "Destroy");
					flash(up, $mul(r, 0.7), ($n(color) ?? C(190, 120, 255)), 0.2);
				});
				puff(up, ($n(color) ?? C(170, 90, 255)), 18, 0.8, 22);
			} else if ((kind === "Crystal")) {
				toss("Crystal", up, 6, 22, 0.45, function () {
					return col;
				}, { life: 1 });
				puff(up, col, 16, 0.7, 20);
			} else if ((kind === "Bubbles")) {
				floatUp("Bubble", up, 6, 0.8, ($n(color) ?? C(170, 220, 255)), 1.2, 1.6);
			} else if ((kind === "Feathers")) {
				toss("Feather", up, 8, 14, 0.7, function () {
					return ($n(color) ?? WHITE);
				}, { gravity: 6, drag: 2.5, life: 1.6 });
			} else if ((kind === "Shock")) {
				flash(up, $mul(r, 0.5), C(255, 250, 200), 0.15);
				if ($t(Effects.Bolt)) {
					for (let _ = 1, $v22 = q(4); _ <= $v22; _++) {
						$sp(Effects.Bolt(up, $add(up, $mul($mul(unitRandom(0.2), r), 1.4)), ($n(color) ?? C(255, 230, 90)), 0.2, 0.25));
					}
				}
				puff(up, ($n(color) ?? C(255, 235, 120)), 16, 0.5, 30, TEX.Spark);
			} else if ((kind === "Snow")) {
				smoke(up, C(240, 248, 255), 12, 2, 12);
				toss("Snowflake", up, 6, 12, 0.5, function () {
					return C(220, 240, 255);
				}, { gravity: 6, drag: 2, life: 1.2 });
			} else if ((kind === "Poison")) {
				puff(up, C(150, 240, 80), 18, 0.9, 16, TEX.Smoke, { LightEmission: 0.4, Lifetime: NumberRange.new(0.6, 1.1) });
				floatUp("Bubble", up, 3, 0.5, C(150, 240, 80), 0.8, 1);
				groundRing(pos, 0.5, r, C(140, 230, 70), 0.35);
			} else if ((kind === "Sand")) {
				smoke(pos, C(225, 195, 130), 14, 2.5, 14);
				toss("Sand", up, 8, 20, 0.6, undefined, { life: 0.9 });
			} else {
				flash(up, $mul(r, 0.5), $mc(WHITE, "Lerp", col, 0.4), 0.18);
				puff(up, col, 18, 0.7, 26, TEX.Spark, { Lifetime: NumberRange.new(0.2, 0.45), Drag: 5 });
				groundRing(pos, 0.5, $mul(r, 1.1), col, 0.3);
			}
			light(up, ($n(color) ?? col), $mul(r, 3), 0.3);
		};
		Effects.SkillImpact = impact;
		let trailOn = function (part, kind, color, size) {
			if ((!$t(kind) || !$t(part))) {
				return;
			}
			let a0 = Instance.new("Attachment");
			a0.Position = Vector3.new(0, $mul(0.25, size), 0);
			a0.Parent = part;
			let a1 = Instance.new("Attachment");
			a1.Position = Vector3.new(0, $mul((-0.25), size), 0);
			a1.Parent = part;
			let tr = Instance.new("Trail");
			tr.Attachment0 = a0;
			tr.Attachment1 = a1;
			tr.Lifetime = 0.25;
			tr.MinLength = 0.05;
			tr.FaceCamera = true;
			tr.LightEmission = 0.7;
			tr.Color = ColorSequence.new(color);
			tr.Transparency = NS(0, 0.3, 1, 1);
			tr.WidthScale = NS(0, 1, 1, 0);
			tr.Parent = part;
			let tex = $get(({ Smoke: TEX.Smoke, Fire: TEX.Fire, Sparkle: TEX.Sparkle, Swirl: TEX.Swirl, Spark: TEX.Spark }), kind);
			if ($t(tex)) {
				emitter(a0, { Texture: tex, Enabled: true, Rate: $mul(40, quality()), Color: ($n(((kind === "Smoke") && ColorSequence.new(C(220, 220, 220)))) ?? ColorSequence.new(color)), Size: NS(0, $mul(0.5, size), 1, $mul((($n(((kind === "Smoke") && 1.4)) ?? 0.1)), size)), Transparency: NS(0, 0.3, 1, 1), Lifetime: NumberRange.new(0.25, 0.45), Speed: NumberRange.new(0.5, 1.5), LightEmission: ($n(((kind === "Smoke") && 0)) ?? 0.9), SpreadAngle: Vector2.new(180, 180) });
			}
		};
		let SPIN_OF = { Bone: Vector3.new(14, 0, 0), Stick: Vector3.new(12, 0, 0), HotDog: Vector3.new(9, 0, 0), Frisbee: Vector3.new(0, 22, 0), Shuriken: Vector3.new(0, 30, 0), Coin: Vector3.new(0, 14, 0), Star: Vector3.new(0, 0, 8), Rock: Vector3.new(6, 4, 0), Boulder: Vector3.new(5, 0, 0), Snowball: Vector3.new(8, 0, 0), Skull: Vector3.new(0, 0, 3), Barrel: Vector3.new(9, 0, 0), Anchor: Vector3.new(0, 0, 10), Gear: Vector3.new(14, 0, 0), Crystal: Vector3.new(0, 0, 9), Leaf: Vector3.new(0, 6, 4), Feather: Vector3.new(0, 4, 0), Kunai: Vector3.new(0, 0, 0), Pom: Vector3.new(6, 6, 0), Planet: Vector3.new(0, 3, 0) };
		H.S_Pop = function (p) {
			let size = $mul(36, (($n(p.Size) ?? 1)));
			floatText(p.Position, ($n(p.Text) ?? "POW!"), ($n(p.Color) ?? C(255, 220, 60)), size, 1.1, 3, rnd((-12), 12));
		};
		H.S_Shot = function (p) {
			let points = ($n(p.Points) ?? []);
			let times = ($n(p.Times) ?? []);
			let delays = ($n(p.Delays) ?? []);
			let color = ($n(p.Color) ?? WHITE);
			let size = ($n(p.Size) ?? 1);
			let spin = ($n(($n(($a(p.Spin) && Vector3.new(0, 0, p.Spin))) ?? $get(SPIN_OF, ($n(p.Motif) ?? "")))) ?? Vector3.zero);
			for (let $v23 = 0, $v24 = $arr(points); $v23 < $v24.length; $v23++) {
				let to = $v24[$v23];
				if (to == null) break;
				let i = $v23 + 1;
				task.delay(($n($get(delays, i)) ?? 0), function () {
					let m = ($a(p.Model) && mouthCF(p.Model));
					let from = ($n(($n(($a(m) && m.Position)) ?? p.From)) ?? to);
					let rig = build(p.Motif, size, color, p.Color2);
					let time = ($n($get(times, i)) ?? 0.5);
					let arc = ($n(p.Arc) ?? 0);
					let targetRoot = ($a(p.Target) && rootOf(p.Target));
					if (($t(rig) && $t(p.Trail))) {
						trailOn($get(rig.Parts, 1), p.Trail, color, size);
					}
					let last = from;
					let dest = to;
					animate(time, function (k, t) {
						if (($t(targetRoot) && $t(targetRoot.Parent))) {
							dest = targetRoot.Position;
						}
						let pos = $add($mc(from, "Lerp", dest, k), Vector3.new(0, $mul($mul($mul(arc, 4), k), ($sub(1, k))), 0));
						let dir = $sub(pos, last);
						if ((dir.Magnitude < 0.001)) {
							dir = $sub(dest, from);
						}
						if ((dir.Magnitude < 0.001)) {
							dir = Vector3.new(0, 0, (-1));
						}
						if ($t(rig)) {
							$sp(SkillArt.Place(rig, $mul(CFrame.lookAt(pos, $add(pos, dir)), CFrame.Angles($mul(spin.X, t), $mul(spin.Y, t), $mul(spin.Z, t)))));
						}
						last = pos;
					}, function () {
						impact(($n(($n(p.Impact) ?? $get(IMPACT_OF, ($n(p.Motif) ?? "")))) ?? "Burst"), dest, ($n(p.Radius) ?? $mul(2.5, size)), color, p.Color2);
						if ((($t(rig) && $t(p.Back)) && $t(p.Model))) {
							let start = dest;
							animate($mul(time, 0.9), function (k, t) {
								let r = rootOf(p.Model);
								let home = ($n(($a(r) && r.Position)) ?? from);
								let pos = $add($mc(start, "Lerp", home, k), Vector3.new(0, $mul($mul($mul(arc, 2), k), ($sub(1, k))), 0));
								$sp(SkillArt.Place(rig, $mul(CFrame.new(pos), CFrame.Angles($add($mul(spin.X, t), 3), $mul(spin.Y, t), $mul(spin.Z, t)))));
							}, function () {
								$sp(SkillArt.Destroy(rig));
							});
						} else if ($t(rig)) {
							$sp(SkillArt.Destroy(rig));
						}
					});
				});
			}
		};
		H.S_Rain = function (p) {
			let color = ($n(p.Color) ?? WHITE);
			let fall = ($n(p.Fall) ?? 0.6);
			let height = ($n(p.Height) ?? 40);
			let spin = ($n(($n(($a(p.Spin) && Vector3.new(p.Spin, 0, 0))) ?? $get(SPIN_OF, ($n(p.Motif) ?? "")))) ?? Vector3.new(0, 2, 0));
			for (let $v25 = 0, $v26 = $arr(($n(p.Points) ?? [])); $v25 < $v26.length; $v25++) {
				let pt = $v26[$v25];
				if (pt == null) break;
				let i = $v25 + 1;
				task.delay($mul(((i - 1)), (($n(p.Gap) ?? 0.1))), function () {
					if (((p.Tele !== false) && $t(H.Telegraph))) {
						$sp(H.Telegraph({ Position: pt, Radius: ($n(p.Radius) ?? 4), Duration: fall, Color: color }));
					}
					let rig = build(p.Motif, ($n(p.Size) ?? 1), color, p.Color2);
					let start = $add(pt, Vector3.new(rnd((-5), 5), height, rnd((-5), 5)));
					let dir = ($sub(pt, start)).Unit;
					animate(fall, function (k, t) {
						if ($t(rig)) {
							let pos = $mc(start, "Lerp", pt, $mul(k, k));
							$sp(SkillArt.Place(rig, $mul(CFrame.lookAt(pos, $add(pos, dir)), CFrame.Angles($mul(spin.X, t), $mul(spin.Y, t), $mul(spin.Z, t)))));
						}
					}, function () {
						impact(($n(($n(p.Impact) ?? $get(IMPACT_OF, ($n(p.Motif) ?? "")))) ?? "Burst"), pt, ($n(p.Radius) ?? 4), color, p.Color2);
						if ($t(rig)) {
							if ($t(p.Stay)) {
								$sp(SkillArt.Place(rig, CFrame.lookAt($add(pt, Vector3.new(0, 0.6, 0)), $add($add(pt, Vector3.new(0, 0.6, 0)), dir))));
								animate(p.Stay, function (k) {
									if ((k > 0.7)) {
										$sp(SkillArt.Fade(rig, $div(($sub(k, 0.7)), 0.3)));
									}
								}, function () {
									$sp(SkillArt.Destroy(rig));
								});
							} else {
								$sp(SkillArt.Destroy(rig));
							}
						}
					});
				});
			}
		};
		H.S_Ring = function (p) {
			let n = q(($n(p.Count) ?? 8));
			let pos = p.Position;
			let r0 = ($n(p.R0) ?? 1), r1 = ($n(p.R1) ?? 8);
			let time = ($n(p.Time) ?? 0.6);
			let h = ($n(p.Height) ?? 1);
			let list = [];
			for (let i = 1, $v27 = n; i <= $v27; i++) {
				let rig = build(p.Motif, ($n(p.Size) ?? 1), p.Color, p.Color2);
				if ($t(rig)) {
					$ins(list, { rig: rig, a: $add($mul($div(((i - 1)), n), TAU), (($n(p.Turn) ?? 0))) });
				}
			}
			let spin = ($n($get(SPIN_OF, ($n(p.Motif) ?? ""))) ?? Vector3.new(0, 4, 0));
			animate(time, function (k, t) {
				let e = outCubic(k);
				let r = $add(r0, $mul(($sub(r1, r0)), e));
				for (let $v28 = 0, $v29 = $arr(list); $v28 < $v29.length; $v28++) {
					let it = $v29[$v28];
					if (it == null) break;
					let a = $add(it.a, $mul((($n(p.Swirl) ?? 0)), k));
					let at = $add(pos, Vector3.new($mul(math.cos(a), r), $add(h, $mul((($n(p.Rise) ?? 0)), e)), $mul(math.sin(a), r)));
					let out = Vector3.new(math.cos(a), 0, math.sin(a));
					$sp(SkillArt.Place(it.rig, $mul(CFrame.lookAt(at, $add(at, out)), CFrame.Angles($mul(spin.X, t), $mul(spin.Y, t), $mul(spin.Z, t)))));
					if ((k > 0.6)) {
						$sp(SkillArt.Fade(it.rig, $div(($sub(k, 0.6)), 0.4)));
					}
				}
			}, function () {
				for (let $v30 = 0, $v31 = $arr(list); $v30 < $v31.length; $v30++) {
					let it = $v31[$v30];
					if (it == null) break;
					$sp(SkillArt.Destroy(it.rig));
				}
			});
		};
		H.S_Orbit = function (p) {
			let root = rootOf(p.Model);
			if (!$t(root)) {
				return;
			}
			let n = ($n(p.Count) ?? 3);
			let radius = $mul((($n(p.Radius) ?? 3)), sizeOf(p.Model));
			let speed = ($n(p.Speed) ?? 3);
			let dur = ($n(p.Duration) ?? 1.5);
			let h = ($n(p.Height) ?? 0.5);
			let list = [];
			for (let i = 1, $v32 = n; i <= $v32; i++) {
				let rig = build(p.Motif, ($n(p.Size) ?? 1), ($n(($a(p.Colors) && $get(p.Colors, i))) ?? p.Color), p.Color2);
				if ($t(rig)) {
					$ins(list, { rig: rig, a: $mul($div(((i - 1)), n), TAU) });
				}
			}
			let spin = ($n($get(SPIN_OF, ($n(p.Motif) ?? ""))) ?? Vector3.zero);
			let lastPos = [];
			animate(dur, function (k, t) {
				if (!$t(root.Parent)) {
					return true;
				}
				let grow = smooth(math.min(1, $div(t, 0.3)));
				for (let $v33 = 0, $v34 = $arr(list); $v33 < $v34.length; $v33++) {
					let it = $v34[$v33];
					if (it == null) break;
					let i = $v33 + 1;
					let a = $add(it.a, $mul(t, speed));
					let at = $add(root.Position, Vector3.new($mul($mul(math.cos(a), radius), grow), $add(h, (math.sin($add($mul(t, 3), i)) * 0.3)), $mul($mul(math.sin(a), radius), grow)));
					$set(lastPos, i, at);
					$sp(SkillArt.Place(it.rig, $mul(CFrame.lookAt(at, $add(at, Vector3.new((-math.sin(a)), 0, math.cos(a)))), CFrame.Angles($mul(spin.X, t), $mul(spin.Y, t), $mul(spin.Z, t)))));
				}
				return false;
			}, function () {
				let targetRoot = ($a(p.Target) && rootOf(p.Target));
				for (let $v35 = 0, $v36 = $arr(list); $v35 < $v36.length; $v35++) {
					let it = $v36[$v35];
					if (it == null) break;
					let i = $v35 + 1;
					let from = $get(lastPos, i);
					if (!$t(from)) {
						$sp(SkillArt.Destroy(it.rig));
						continue;
					}
					if (((p.End === "Fire") && ($t(targetRoot) || $t(p.To)))) {
						let dest = ($n(($a(targetRoot) && targetRoot.Position)) ?? p.To);
						let d = (((i - 1)) * 0.08);
						task.delay(d, function () {
							animate(0.3, function (k) {
								let pos = $mc(from, "Lerp", dest, k);
								$sp(SkillArt.Place(it.rig, CFrame.lookAt(pos, dest)));
							}, function () {
								impact(($n($get(IMPACT_OF, ($n(p.Motif) ?? ""))) ?? "Burst"), dest, 3, ($n(($a(p.Colors) && $get(p.Colors, i))) ?? p.Color));
								$sp(SkillArt.Destroy(it.rig));
							});
						});
					} else if ((p.End === "Burst")) {
						let out = flat($sub(from, root.Position));
						out = ($n(((out.Magnitude > 0.01) && out.Unit)) ?? UP);
						animate(0.35, function (k) {
							let pos = $add(from, $mul($mul(out, 10), outCubic(k)));
							$sp(SkillArt.Place(it.rig, CFrame.new(pos)));
							$sp(SkillArt.Fade(it.rig, k));
						}, function () {
							$sp(SkillArt.Destroy(it.rig));
						});
					} else {
						animate(0.25, function (k) {
							$sp(SkillArt.Fade(it.rig, k));
						}, function () {
							$sp(SkillArt.Destroy(it.rig));
						});
					}
				}
			});
		};
		H.S_Prop = function (p) {
			let rig = build(p.Motif, ($n(p.Size) ?? 1), p.Color, p.Color2, true);
			if (!$t(rig)) {
				return;
			}
			let pos = p.Position;
			let path = ($n(p.Path) ?? "Fall");
			let time = ($n(p.Time) ?? 0.6);
			let hold = ($n(p.Hold) ?? 0.8);
			let look = ($n(($a(p.Look) && flat(p.Look))) ?? Vector3.new(0, 0, (-1)));
			if ((look.Magnitude < 0.01)) {
				look = Vector3.new(0, 0, (-1));
			}
			let rot = CFrame.lookAt(Vector3.zero, look.Unit);
			if ($t(p.Tilt)) {
				rot = $mul(rot, CFrame.Angles(math.rad(p.Tilt), 0, 0));
			}
			let offset = ($n(p.Offset) ?? Vector3.zero);
			let place = function (at, extra) {
				$sp(SkillArt.Place(rig, $mul($mul(CFrame.new($add(at, offset)), rot), (($n(extra) ?? CFrame.identity)))));
			};
			let finish = function (after) {
				task.delay(after, function () {
					if ((p.End === "Shatter")) {
						impact("Shatter", pos, 6, p.Color);
						$sp(SkillArt.Destroy(rig));
					} else if ((p.End === "Sink")) {
						animate(0.5, function (k) {
							place($sub(pos, $mul($mul(UP, 6), k)));
							$sp(SkillArt.Fade(rig, k));
						}, function () {
							$sp(SkillArt.Destroy(rig));
						});
					} else if ((p.End === "Up")) {
						animate(0.6, function (k) {
							place($add(pos, $mul($mul($mul(UP, 40), k), k)));
							$sp(SkillArt.Fade(rig, (math.max(0, $sub(k, 0.5)) * 2)));
						}, function () {
							$sp(SkillArt.Destroy(rig));
						});
					} else {
						animate(0.4, function (k) {
							$sp(SkillArt.Fade(rig, k));
						}, function () {
							$sp(SkillArt.Destroy(rig));
						});
					}
				});
			};
			let spinRate = ($n(p.Spin) ?? 0);
			if ((path === "Fall")) {
				let start = $add(pos, $mul(UP, (($n(p.Height) ?? 45))));
				animate(time, function (k, t) {
					place($mc(start, "Lerp", pos, $mul(k, k)), CFrame.Angles(0, $mul(spinRate, t), 0));
				}, function () {
					place(pos);
					impact(($n(p.Impact) ?? "Holy"), pos, ($n(p.Radius) ?? 8), p.Color);
					shakeAt(pos, ($n(p.Shake) ?? 0.6), 60);
					finish(hold);
				});
			} else if (((path === "Rise") || (path === "Grow"))) {
				let depth = ($n(p.Depth) ?? 8);
				animate(time, function (k, t) {
					place($sub(pos, $mul($mul(UP, depth), ($sub(1, outCubic(k))))), CFrame.Angles(0, $mul(spinRate, t), 0));
				}, function () {
					impact(($n(p.Impact) ?? "Dirt"), pos, ($n(p.Radius) ?? 5), p.Color);
					if ($t(p.Shake)) {
						shakeAt(pos, p.Shake, 50);
					}
					animate(hold, function (_k, t) {
						place($add(pos, $mul($mul(UP, math.sin($mul(t, 2))), (($n(p.Bob) ?? 0)))), CFrame.Angles(0, $mul(spinRate, ($add(t, time))), 0));
					});
					finish(hold);
				});
			} else if ((path === "Fly")) {
				let to = ($n(p.To) ?? pos);
				let dir = $sub(to, pos);
				if ((flat(dir).Magnitude > 0.1)) {
					rot = CFrame.lookAt(Vector3.zero, flat(dir).Unit);
				}
				animate(time, function (k, t) {
					place($add($mc(pos, "Lerp", to, k), $mul($mul(UP, math.sin($mul(t, 2))), (($n(p.Bob) ?? 0)))), CFrame.Angles(0, 0, $mul(math.sin($mul(t, 1.5)), (($n(p.Roll) ?? 0)))));
				}, function () {
					pos = to;
					finish(0);
				});
			} else if ((path === "Hover")) {
				let start = $add(pos, $mul(UP, 20));
				$sp(SkillArt.Fade(rig, 1));
				animate(time, function (k, t) {
					place($mc(start, "Lerp", pos, outCubic(k)), CFrame.Angles(0, $mul(spinRate, t), 0));
					$sp(SkillArt.Fade(rig, $sub(1, k)));
				}, function () {
					animate(hold, function (_k, t) {
						place($add(pos, $mul($mul(UP, math.sin($mul(t, 2.2))), 0.6)), CFrame.Angles(0, $mul(spinRate, ($add(t, time))), 0));
					}, function () {
						if ((p.End == null)) {
							p.End = "Up";
						}
						finish(0);
					});
				});
			} else if ((path === "Spin")) {
				animate($add(time, hold), function (k, t) {
					place($add(pos, $mul($mul(UP, math.sin($mul(t, 3))), (($n(p.Bob) ?? 0)))), CFrame.Angles(0, $mul((($n(((spinRate !== 0) && spinRate)) ?? 6)), t), 0));
					if ((k < 0.15)) {
						$sp(SkillArt.Fade(rig, $sub(1, $div(k, 0.15))));
					}
				}, function () {
					finish(0);
				});
			} else if ((path === "Swing")) {
				animate($mul(time, 0.6), function (k) {
					place(pos, CFrame.Angles($mul(math.rad(25), smooth(k)), 0, 0));
				}, function () {
					animate($mul(time, 0.4), function (k) {
						place(pos, CFrame.Angles($sub(math.rad(25), $mul($mul(math.rad(115), k), k)), 0, 0));
					}, function () {
						let tip = $add(pos, $mul(look.Unit, (($n(p.Reach) ?? 8))));
						impact(($n(p.Impact) ?? "Rock"), tip, ($n(p.Radius) ?? 6), p.Color);
						shakeAt(tip, ($n(p.Shake) ?? 0.5), 50);
						finish(hold);
					});
				});
			} else if ((path === "Countdown")) {
				let lamps = [C(255, 60, 50), C(255, 210, 50), C(80, 255, 110)];
				place(pos);
				for (let $v37 = 0, $v38 = $arr(lamps); $v37 < $v38.length; $v37++) {
					let col = $v38[$v37];
					if (col == null) break;
					let i = $v37 + 1;
					task.delay($div($mul(((i - 1)), time), 3), function () {
						floatText($add(pos, $mul(UP, 2)), ($n(((i < 3) && tostring((4 - i)))) ?? "GO!"), col, 40, 0.6, 1.5);
						light($add(pos, $mul(UP, 2)), col, 18, 0.4, 6);
					});
				}
				finish($add(time, 0.2));
			} else {
				place(pos);
				finish($add(time, hold));
			}
		};
		H.S_Line = function (p) {
			let from = p.From, to = p.To;
			if (!($t(from) && $t(to))) {
				return;
			}
			let kind = ($n(p.Kind) ?? "Trail");
			let color = ($n(p.Color) ?? WHITE);
			let dur = ($n(p.Duration) ?? 1.2);
			let d = $sub(to, from);
			let len = flat(d).Magnitude;
			if ((len < 0.5)) {
				return;
			}
			let dir = flat(d).Unit;
			let side = Vector3.new((-dir.Z), 0, dir.X);
			let width = ($n(p.Width) ?? 2);
			if ((kind === "Bolt")) {
				if ($t(Effects.Bolt)) {
					$sp(Effects.Bolt($add(from, UP), $add(to, UP), color, 0.35, $mul(width, 0.3)));
				}
				puff($add(to, UP), color, 12, 0.5, 20, TEX.Spark);
				return;
			}
			if ((kind === "Slash")) {
				let mid = $add($mc(from, "Lerp", to, 0.5), $mul(UP, (($n(p.Height) ?? 1.5))));
				let line = fxPart({ Size: Vector3.new(0.12, 0.12, len), CFrame: CFrame.lookAt(mid, $add(mid, dir)), Color: color });
				let glow = fxPart({ Size: Vector3.new(0.5, 0.5, len), CFrame: CFrame.lookAt(mid, $add(mid, dir)), Color: color, Transparency: 0.6 });
				animate(0.45, function (k) {
					line.Size = Vector3.new($add($mul(0.12, ($sub(1, k))), 0.02), $add($mul(0.12, ($sub(1, k))), 0.02), len);
					line.Transparency = k;
					glow.Transparency = $add(0.6, $mul(0.4, k));
				}, function () {
					$mc(line, "Destroy");
					$mc(glow, "Destroy");
				});
				puff($add(to, UP), color, 10, 0.4, 18, TEX.Spark);
				return;
			}
			let steps = math.clamp(math.floor($div(len, (($n(((kind === "Paw") && 2.2)) ?? 1.6)))), 2, 40);
			let parts = [], rigs = [];
			for (let i = 1, $v39 = steps; i <= $v39; i++) {
				let u = $div(((i - 0.5)), steps);
				let at = $mc(from, "Lerp", to, u);
				if ((kind === "Scent")) {
					at = $add(at, $add($mul($mul(side, math.sin($mul(u, 14))), 1.2), $mul(UP, 1.2)));
					$ins(parts, fxPart({ Shape: Enum.PartType.Ball, Size: $mul(Vector3.one, 0.5), CFrame: CFrame.new(at), Color: color, Transparency: 1 }));
				} else if ((kind === "Paw")) {
					let rig = build("Paw", 0.8, color, undefined);
					if ($t(rig)) {
						$sp(SkillArt.Place(rig, CFrame.lookAt($add($add(at, $mul(UP, 0.12)), $mul(side, (($n(((($mod(i, 2) === 0)) && 0.45)) ?? (-0.45))))), $add($add(at, $mul(UP, 0.12)), dir))));
						$sp(SkillArt.Fade(rig, 1));
						$ins(rigs, rig);
					}
				} else if ((kind === "Fire")) {
					let rig = build("Flame", $mul($mul(rnd(0.8, 1.3), width), 0.5), color, undefined);
					if ($t(rig)) {
						$sp(SkillArt.Place(rig, CFrame.new($add(at, $mul(UP, 0.5)))));
						$sp(SkillArt.Fade(rig, 1));
						$ins(rigs, rig);
					}
				} else if (((kind === "Ice") || (kind === "Crystal"))) {
					let rig = build("Crystal", $mul($mul(rnd(0.6, 1.1), width), 0.6), color, undefined);
					if ($t(rig)) {
						$sp(SkillArt.Place(rig, $mul(CFrame.new($add(at, $mul(side, rnd((-1), 1)))), CFrame.Angles(math.rad($add((-90), rnd((-20), 20))), rnd(0, TAU), 0))));
						$sp(SkillArt.Fade(rig, 1));
						$ins(rigs, rig);
					}
				} else if ((kind === "Crack")) {
					let seg = fxPart({ Size: Vector3.new(0.35, 0.1, $mul($div(len, steps), 1.3)), CFrame: CFrame.lookAt($add($add(at, $mul(UP, 0.06)), $mul(side, rnd((-0.6), 0.6))), $add($add($add(at, $mul(UP, 0.06)), dir), $mul(side, rnd((-0.6), 0.6)))), Color: color, Transparency: 1 });
					$ins(parts, seg);
				} else if ((kind === "Race")) {
					let seg = fxPart({ Size: Vector3.new(width, 0.06, $mul($div(len, steps), 0.6)), CFrame: CFrame.lookAt($add(at, $mul(UP, 0.05)), $add($add(at, $mul(UP, 0.05)), dir)), Color: ($n(((($mod(i, 2) === 0)) && WHITE)) ?? color), Material: Enum.Material.SmoothPlastic, Transparency: 1 });
					$ins(parts, seg);
				} else if ((kind === "Wind")) {
					let seg = fxPart({ Size: Vector3.new(0.15, 0.15, 2.2), CFrame: CFrame.lookAt($add($add(at, $mul(UP, rnd(0.5, 2.5))), $mul(side, rnd($unm(width), width))), $add($add(at, UP), $mul(dir, 10))), Color: WHITE, Transparency: 1 });
					$ins(parts, seg);
				} else {
					let seg = fxPart({ Size: Vector3.new(width, 0.08, $mul($div(len, steps), 1.05)), CFrame: CFrame.lookAt($add(at, $mul(UP, 0.07)), $add($add(at, $mul(UP, 0.07)), dir)), Color: color, Material: ($n(((kind === "Water") && GLASS)) ?? NEON), Transparency: 1 });
					$ins(parts, seg);
				}
			}
			let appear = math.min(0.35, $mul(dur, 0.3));
			animate(dur, function (k, t) {
				let front = math.clamp($div(t, appear), 0, 1);
				let fade = math.clamp($div(($sub(k, 0.65)), 0.35), 0, 1);
				for (let $v40 = 0, $v41 = $arr(parts); $v40 < $v41.length; $v40++) {
					let part = $v41[$v40];
					if (part == null) break;
					let i = $v40 + 1;
					let on = (((i / $len(parts))) <= front);
					let base = ($n(($n(($n((((kind === "Scent") && 0.25))) ?? (((kind === "Crack") && 0.15)))) ?? (((kind === "Wind") && 0.5)))) ?? 0.35);
					part.Transparency = ($n(($a(on) && ($add(base, $mul(($sub(1, base)), fade))))) ?? 1);
					if ((kind === "Wind")) {
						part.CFrame = $add(part.CFrame, $mul(dir, 0.6));
					} else if ((kind === "Scent")) {
						part.CFrame = CFrame.new($add(part.Position, Vector3.new(0, (math.sin($add($mul(t, 4), i)) * 0.01), 0)));
					}
				}
				for (let $v42 = 0, $v43 = $arr(rigs); $v42 < $v43.length; $v42++) {
					let rig = $v43[$v42];
					if (rig == null) break;
					let i = $v42 + 1;
					let on = (((i / $len(rigs))) <= front);
					$sp(SkillArt.Fade(rig, ($n(($a(on) && fade)) ?? 1)));
				}
			}, function () {
				for (let $v44 = 0, $v45 = $arr(parts); $v44 < $v45.length; $v44++) {
					let part = $v45[$v44];
					if (part == null) break;
					$mc(part, "Destroy");
				}
				for (let $v46 = 0, $v47 = $arr(rigs); $v46 < $v47.length; $v46++) {
					let rig = $v47[$v46];
					if (rig == null) break;
					$sp(SkillArt.Destroy(rig));
				}
			});
			if ((kind === "Fire")) {
				light($add($mc(from, "Lerp", to, 0.5), UP), color, len, $mul(dur, 0.8), 3);
			}
		};
		let ZONE_LOOK = { Puddle: [C(90, 170, 255), GLASS, 0.35], Water: [C(70, 150, 240), GLASS, 0.3], Honey: [C(255, 175, 30), GLASS, 0.25], Lava: [C(255, 110, 30), NEON, 0.2], Fire: [C(60, 30, 20), Enum.Material.Slate, 0.2], Ice: [C(190, 235, 255), Enum.Material.Ice, 0.25], Snow: [C(245, 250, 255), Enum.Material.Snow, 0.1], Poison: [C(130, 220, 60), NEON, 0.55], Sand: [C(225, 195, 130), Enum.Material.Sand, 0.05], Mud: [C(110, 80, 50), Enum.Material.Mud, 0.05], Vines: [C(70, 150, 60), Enum.Material.Grass, 0.1], Flowers: [C(110, 200, 90), Enum.Material.Grass, 0.15], Spores: [C(150, 110, 200), NEON, 0.7], Stars: [C(40, 30, 90), NEON, 0.35], Holy: [C(255, 225, 130), NEON, 0.6], Shadow: [C(30, 10, 45), Enum.Material.SmoothPlastic, 0.25], Ink: [C(25, 20, 35), GLASS, 0.1], Web: [C(240, 240, 240), NEON, 0.92], Rune: [C(255, 255, 255), NEON, 0.85], Dance: [C(30, 25, 40), Enum.Material.SmoothPlastic, 0.2], Storm: [C(120, 130, 160), NEON, 0.85], Grave: [C(70, 90, 60), Enum.Material.Grass, 0.2], Gravity: [C(120, 60, 200), NEON, 0.7], Time: [C(200, 200, 210), NEON, 0.75], Confetti: [C(255, 255, 255), NEON, 0.9], Crack: [C(60, 45, 35), Enum.Material.Slate, 0.4] };
		H.S_Zone = function (p) {
			let pos = p.Position;
			let r = ($n(p.Radius) ?? 8);
			let dur = ($n(p.Duration) ?? 3);
			let kind = ($n(p.Kind) ?? "Puddle");
			let look = ($n($get(ZONE_LOOK, kind)) ?? ZONE_LOOK.Puddle);
			let color = ($n(p.Color) ?? $get(look, 1));
			let baseColor = ($n(((((((((kind === "Rune") || (kind === "Holy")) || (kind === "Stars")) || (kind === "Gravity")) || (kind === "Poison")) || (kind === "Spores"))) && color)) ?? $get(look, 1));
			let base = disc(pos, 0.1, baseColor, 1, $get(look, 2));
			let baseTr = $get(look, 3);
			let extras = [], rigs = [], emitters = [];
			let holder = anchor($add(pos, $mul(UP, 0.5)), $add(dur, 2));
			let emit = function (props) {
				let e = emitter(holder, props);
				e.Enabled = true;
				$ins(emitters, e);
				return e;
			};
			let deco = function (motif, n, size, col, ring) {
				for (let i = 1, $v48 = q(n); i <= $v48; i++) {
					let a = ($n(($a(ring) && ($mul($div(i, n), TAU)))) ?? rnd(0, TAU));
					let rr = ($n(($a(ring) && $mul(r, 0.85))) ?? $mul($mul(math.sqrt(math.random()), r), 0.85));
					let rig = build(motif, $mul(size, rnd(0.8, 1.2)), ($n(col) ?? color), undefined);
					if ($t(rig)) {
						$ins(rigs, { rig: rig, at: $add(pos, Vector3.new($mul(math.cos(a), rr), 0, $mul(math.sin(a), rr))), a: a, ph: rnd(0, TAU) });
					}
				}
			};
			if (((kind === "Lava") || (kind === "Fire"))) {
				emit({ Texture: TEX.Fire, Rate: $mul(30, quality()), Color: CS(0, C(255, 230, 150), 1, C(255, 80, 20)), Size: NS(0, 1.4, 1, 0), Lifetime: NumberRange.new(0.4, 0.8), Speed: NumberRange.new(3, 7), SpreadAngle: Vector2.new(20, 20), EmissionDirection: Enum.NormalId.Top, LightEmission: 1 });
				deco("Flame", ($n(((kind === "Fire") && 7)) ?? 3), 1.3, C(255, 140, 40));
			} else if (((kind === "Poison") || (kind === "Spores"))) {
				emit({ Texture: TEX.Smoke, Rate: $mul(14, quality()), Color: ColorSequence.new(color), Size: NS(0, 1.5, 1, 3.5), Transparency: NS(0, 0.5, 1, 1), Lifetime: NumberRange.new(1, 1.6), Speed: NumberRange.new(1, 3), SpreadAngle: Vector2.new(60, 60), EmissionDirection: Enum.NormalId.Top, LightEmission: 0.3 });
				if ((kind === "Spores")) {
					deco("Mushroom", 6, 1.2, C(200, 80, 200), true);
				}
			} else if (((kind === "Ice") || (kind === "Snow"))) {
				deco("Crystal", 6, 1.2, C(180, 230, 255), true);
				emit({ Texture: TEX.Sparkle, Rate: $mul(12, quality()), Color: ColorSequence.new(C(220, 245, 255)), Size: NS(0, 0.5, 1, 0), Lifetime: NumberRange.new(0.8, 1.4), Speed: NumberRange.new(1, 2), SpreadAngle: Vector2.new(80, 80), EmissionDirection: Enum.NormalId.Top });
			} else if ((kind === "Sand")) {
				emit({ Texture: TEX.Smoke, Rate: $mul(20, quality()), Color: ColorSequence.new(C(225, 195, 130)), Size: NS(0, 2, 1, 4), Transparency: NS(0, 0.4, 1, 1), Lifetime: NumberRange.new(0.8, 1.2), Speed: NumberRange.new(4, 8), SpreadAngle: Vector2.new(10, 180), EmissionDirection: Enum.NormalId.Right, LightEmission: 0 });
				deco("Scarab", 3, 0.8, undefined);
			} else if (((kind === "Vines") || (kind === "Flowers"))) {
				deco(($n(((kind === "Flowers") && "Flower")) ?? "Leaf"), 10, 1, ($n(((kind === "Flowers") && pick(CONFETTI))) ?? C(80, 180, 70)));
			} else if ((kind === "Stars")) {
				deco("Star", 8, 0.7, C(255, 240, 150));
			} else if (((kind === "Holy") || (kind === "Rune"))) {
				let rune = build("Rune", $div(r, 1.1), color, WHITE);
				if ($t(rune)) {
					$ins(rigs, { rig: rune, at: $add(pos, $mul(UP, 0.12)), a: 0, ph: 0, spinning: true });
				}
				emit({ Texture: TEX.Sparkle, Rate: $mul(18, quality()), Color: ColorSequence.new(color), Size: NS(0, 0.6, 1, 0), Lifetime: NumberRange.new(0.8, 1.2), Speed: NumberRange.new(4, 8), SpreadAngle: Vector2.new(30, 30), EmissionDirection: Enum.NormalId.Top });
			} else if (((kind === "Shadow") || (kind === "Ink"))) {
				emit({ Texture: TEX.Smoke, Rate: $mul(16, quality()), Color: ColorSequence.new(($n(((kind === "Ink") && C(20, 15, 30))) ?? C(60, 20, 90))), Size: NS(0, 1.5, 1, 3), Transparency: NS(0, 0.4, 1, 1), Lifetime: NumberRange.new(0.8, 1.3), Speed: NumberRange.new(1, 3), SpreadAngle: Vector2.new(50, 50), EmissionDirection: Enum.NormalId.Top, LightEmission: 0 });
			} else if ((kind === "Honey")) {
				deco("Honey", 5, 0.6, undefined);
				deco("Bee", 3, 0.7, undefined);
			} else if (((kind === "Puddle") || (kind === "Water"))) {
				deco("Bubble", 4, 0.6, C(190, 230, 255));
			} else if ((kind === "Dance")) {
				let n = math.clamp(math.floor($div(r, 2.2)), 2, 5);
				let cell = $div($mul(r, 2), ($add($mul(n, 2), 1)));
				for (let x = $unm(n), $v49 = n; x <= $v49; x++) {
					for (let z = $unm(n), $v50 = n; z <= $v50; z++) {
						if ((($add($mul(x, x), $mul(z, z)) <= $mul(n, n)) && !$t(full(4)))) {
							let tile = fxPart({ Size: Vector3.new($mul(cell, 0.92), 0.1, $mul(cell, 0.92)), CFrame: CFrame.new($add(pos, Vector3.new($mul(x, cell), 0.12, $mul(z, cell)))), Color: $get(CONFETTI, $add(($mod(($add(x, z)), $len(CONFETTI))), 1)), Transparency: 1 });
							$ins(extras, { part: tile, i: $add(x, $mul(z, 3)) });
						}
					}
				}
			} else if ((kind === "Storm")) {
				let cloud = build("Cloud", $div(r, 2.4), C(90, 95, 115), undefined);
				if ($t(cloud)) {
					$ins(rigs, { rig: cloud, at: $add(pos, $mul(UP, 16)), a: 0, ph: 0, sky: true });
				}
				emit({ Texture: TEX.Sparkle, Rate: $mul(40, quality()), Color: ColorSequence.new(C(170, 200, 255)), Size: NS(0, 0.25, 1, 0.25), Lifetime: NumberRange.new(0.5, 0.7), Speed: NumberRange.new(30, 40), SpreadAngle: Vector2.new(15, 15), EmissionDirection: Enum.NormalId.Bottom });
			} else if ((kind === "Grave")) {
				deco("Tombstone", 5, 1.3, undefined, true);
				emit({ Texture: TEX.Smoke, Rate: $mul(10, quality()), Color: ColorSequence.new(C(120, 255, 200)), Size: NS(0, 2, 1, 4), Transparency: NS(0, 0.6, 1, 1), Lifetime: NumberRange.new(1, 2), Speed: NumberRange.new(0.5, 1.5), SpreadAngle: Vector2.new(10, 180), EmissionDirection: Enum.NormalId.Right, LightEmission: 0.3 });
			} else if ((kind === "Gravity")) {
				emit({ Texture: TEX.Sparkle, Rate: $mul(30, quality()), Color: ColorSequence.new(color), Size: NS(0, 0.4, 1, 0), Lifetime: NumberRange.new(0.8, 1.2), Speed: NumberRange.new(6, 12), SpreadAngle: Vector2.new(10, 10), EmissionDirection: Enum.NormalId.Top });
			} else if ((kind === "Time")) {
				let clock = build("Clock", $div(r, 1.3), undefined, undefined);
				if ($t(clock)) {
					$ins(rigs, { rig: clock, at: $add(pos, $mul(UP, 0.2)), a: 0, ph: 0, flatDisc: true });
				}
			} else if ((kind === "Confetti")) {
				emit({ Texture: TEX.Sparkle, Rate: $mul(30, quality()), Color: ColorSequence.new(pick(CONFETTI)), Size: NS(0, 0.5, 1, 0.3), Lifetime: NumberRange.new(1, 1.5), Speed: NumberRange.new(2, 4), SpreadAngle: Vector2.new(50, 50), EmissionDirection: Enum.NormalId.Top });
			} else if ((kind === "Web")) {
				for (let i = 1, $v51 = 6; i <= $v51; i++) {
					let a = $mul((i / 6), math.pi);
					let strand = fxPart({ Size: Vector3.new(0.1, 0.06, $mul(r, 2)), CFrame: $mul(CFrame.new($add(pos, $mul(UP, 0.15))), CFrame.Angles(0, a, 0)), Color: WHITE, Transparency: 1 });
					$ins(extras, { part: strand, web: true });
				}
			} else if ((kind === "Crack")) {
				for (let _ = 1, $v52 = q(7); _ <= $v52; _++) {
					let a = rnd(0, TAU);
					let seg = fxPart({ Size: Vector3.new(0.4, 0.1, $mul(r, rnd(0.5, 1))), CFrame: $mul($mul(CFrame.new($add(pos, $mul(UP, 0.1))), CFrame.Angles(0, a, 0)), CFrame.new(0, 0, $mul($unm(r), 0.4))), Color: color, Transparency: 1 });
					$ins(extras, { part: seg, web: true });
				}
			}
			animate(dur, function (k, t) {
				let open = outCubic(math.min(1, $div(t, 0.35)));
				let fade = math.clamp($div(($sub(k, 0.8)), 0.2), 0, 1);
				setDisc(base, $mul(r, open));
				base.Transparency = $add(baseTr, $mul(($sub(1, baseTr)), fade));
				for (let $v53 = 0, $v54 = $arr(rigs); $v53 < $v54.length; $v53++) {
					let it = $v54[$v53];
					if (it == null) break;
					let cf;
					if ($t(it.sky)) {
						cf = CFrame.new($add(it.at, Vector3.new((math.sin(t) * 0.5), 0, 0)));
					} else if ($t(it.spinning)) {
						cf = $mul(CFrame.new(it.at), CFrame.Angles(0, $mul(t, 0.8), 0));
					} else if ($t(it.flatDisc)) {
						cf = $mul($mul(CFrame.new(it.at), CFrame.Angles(math.rad((-90)), 0, 0)), CFrame.Angles(0, 0, $mul($unm(t), 2)));
					} else {
						let bob = (math.sin($add($mul(t, 3), it.ph)) * 0.15);
						cf = $mul(CFrame.new($add(it.at, $mul(UP, ($add(0.3, bob))))), CFrame.Angles(0, $add(it.a, $mul(t, 0.3)), 0));
					}
					$sp(SkillArt.Place(it.rig, cf));
					$sp(SkillArt.Fade(it.rig, math.max($sub(1, open), fade)));
				}
				for (let $v55 = 0, $v56 = $arr(extras); $v55 < $v56.length; $v55++) {
					let ex = $v56[$v55];
					if (ex == null) break;
					if ($t(ex.web)) {
						ex.part.Transparency = (0.3 + (0.7 * math.max($sub(1, open), fade)));
					} else {
						let beat = math.floor($mul(t, 4));
						ex.part.Color = $get(CONFETTI, $add(($mod(($add(ex.i, beat)), $len(CONFETTI))), 1));
						ex.part.Transparency = (0.15 + (0.85 * math.max($sub(1, open), fade)));
					}
				}
				if ((((kind === "Storm") && (math.random() < $mul(0.03, quality()))) && $t(Effects.Bolt))) {
					let at = $add(pos, $mul(Vector3.new(rnd($unm(r), r), 0, rnd($unm(r), r)), 0.7));
					$sp(Effects.Bolt($add(at, $mul(UP, 16)), at, C(200, 220, 255), 0.2, 0.3));
				}
				if ((((kind === "Puddle") || (kind === "Water")) && (math.random() < 0.05))) {
					groundRing($add(pos, $mul(Vector3.new(rnd($unm(r), r), 0, rnd($unm(r), r)), 0.6)), 0.3, 1.8, C(200, 230, 255), 0.6, 0.15);
				}
			}, function () {
				$mc(base, "Destroy");
				for (let $v57 = 0, $v58 = $arr(rigs); $v57 < $v58.length; $v57++) {
					let it = $v58[$v57];
					if (it == null) break;
					$sp(SkillArt.Destroy(it.rig));
				}
				for (let $v59 = 0, $v60 = $arr(extras); $v59 < $v60.length; $v59++) {
					let ex = $v60[$v59];
					if (ex == null) break;
					$mc(ex.part, "Destroy");
				}
				for (let $v61 = 0, $v62 = $arr(emitters); $v61 < $v62.length; $v61++) {
					let e = $v62[$v61];
					if (e == null) break;
					e.Enabled = false;
				}
			});
		};
		H.S_Mark = function (p) {
			let model = p.Model;
			let root = rootOf(model);
			if (!$t(root)) {
				return;
			}
			let kind = ($n(p.Kind) ?? "Dizzy");
			let dur = math.max(0.3, ($n(p.Duration) ?? 1));
			let s = sizeOf(model);
			let color = p.Color;
			let rigs = [], parts = [], emitters = [];
			let att = Instance.new("Attachment");
			att.Parent = root;
			$mc(Debris, "AddItem", att, $add(dur, 1.5));
			let emit = function (props) {
				let e = emitter(att, props);
				e.Enabled = true;
				$ins(emitters, e);
				return e;
			};
			let top = $add((root.Size.Y * 0.5), $mul(1.6, s));
			let orbiters = function (motif, n, size, col) {
				for (let i = 1, $v63 = n; i <= $v63; i++) {
					let rig = build(motif, $mul(size, s), col, undefined, true);
					if ($t(rig)) {
						$ins(rigs, { rig: rig, a: $mul($div(((i - 1)), n), TAU) });
					}
				}
			};
			let mode = "orbit";
			if (((kind === "Dizzy") || (kind === "Shock"))) {
				orbiters(($n(((kind === "Shock") && "Bolt")) ?? "Star"), 3, 0.45, ($n(((kind === "Shock") && C(255, 235, 90))) ?? C(255, 225, 80)));
				if ((kind === "Shock")) {
					emit({ Texture: TEX.Spark, Rate: $mul(25, quality()), Color: ColorSequence.new(C(255, 240, 120)), Size: NS(0, 0.4, 1, 0), Lifetime: NumberRange.new(0.15, 0.3), Speed: NumberRange.new(6, 12) });
				}
			} else if ((kind === "Sleep")) {
				mode = "sleep";
			} else if (((kind === "Charm") || (kind === "Dance"))) {
				mode = "float";
			} else if ((kind === "Fear")) {
				emit({ Texture: TEX.Smoke, Rate: $mul(10, quality()), Color: ColorSequence.new(C(90, 40, 140)), Size: NS(0, 1.5, 1, 3), Transparency: NS(0, 0.5, 1, 1), Lifetime: NumberRange.new(0.6, 1), Speed: NumberRange.new(1, 2), LightEmission: 0 });
				orbiters("Ghost", 2, 0.4, C(200, 160, 255));
			} else if ((kind === "Burn")) {
				emit({ Texture: TEX.Fire, Rate: $mul(22, quality()), Color: CS(0, C(255, 230, 140), 1, C(255, 80, 20)), Size: NS(0, $mul(1.2, s), 1, 0), Lifetime: NumberRange.new(0.3, 0.6), Speed: NumberRange.new(2, 5), SpreadAngle: Vector2.new(25, 25), EmissionDirection: Enum.NormalId.Top, LightEmission: 1 });
				mode = "none";
			} else if (((((kind === "Poison") || (kind === "Bleed")) || (kind === "Wet")) || (kind === "Ink"))) {
				let col = $get(({ Poison: C(150, 240, 80), Bleed: C(220, 40, 50), Wet: C(140, 200, 255), Ink: C(30, 20, 40) }), kind);
				emit({ Texture: TEX.Sparkle, Rate: $mul(14, quality()), Color: ColorSequence.new(col), Size: NS(0, 0.5, 1, 0.2), Lifetime: NumberRange.new(0.5, 0.9), Speed: NumberRange.new(1, 3), Acceleration: ($n(((kind === "Poison") && Vector3.new(0, 4, 0))) ?? Vector3.new(0, (-14), 0)), LightEmission: ($n(((kind === "Ink") && 0)) ?? 0.5) });
				mode = "none";
			} else if ((kind === "Curse")) {
				orbiters("GhostSkull", 1, 0.55, C(180, 90, 255));
				emit({ Texture: TEX.Smoke, Rate: $mul(8, quality()), Color: ColorSequence.new(C(130, 60, 200)), Size: NS(0, 1, 1, 2.5), Transparency: NS(0, 0.5, 1, 1), Lifetime: NumberRange.new(0.6, 1), Speed: NumberRange.new(1, 2), LightEmission: 0.3 });
			} else if ((kind === "Slow")) {
				mode = "swirl";
			} else if ((kind === "Bubble")) {
				let rig = build("Bubble", (root.Size.Z * 0.9), C(170, 220, 255), undefined, true);
				if ($t(rig)) {
					$ins(rigs, { rig: rig, a: 0, center: true });
				}
				mode = "center";
			} else if ((((((((((kind === "Cage") || (kind === "Web")) || (kind === "Vines")) || (kind === "Wrap")) || (kind === "Pin")) || (kind === "Stone")) || (kind === "Honey")) || (kind === "Time")) || (kind === "Grab"))) {
				mode = "bars";
				let n = ($n(((kind === "Cage") && 8)) ?? 5);
				let col = ($n(color) ?? $get(({ Cage: C(255, 220, 120), Web: WHITE, Vines: C(80, 180, 70), Wrap: C(240, 230, 205), Pin: C(255, 255, 255), Stone: C(140, 130, 120), Honey: C(255, 175, 30), Time: C(220, 220, 240), Grab: C(150, 80, 200) }), kind));
				let h = $add(root.Size.Y, $mul(2.2, s));
				let rr = ((root.Size.Z * 0.65) + 0.4);
				for (let i = 1, $v64 = n; i <= $v64; i++) {
					let a = $mul($div(((i - 1)), n), TAU);
					let bar = fxPart({ Size: ($n(((kind === "Cage") && Vector3.new(0.25, h, 0.25))) ?? Vector3.new(0.35, 0.35, $mul(rr, 1.4))), Color: col, Material: ($n(($n(($n((((kind === "Stone") && Enum.Material.Slate))) ?? (((kind === "Honey") && GLASS)))) ?? (((kind === "Cage") && NEON)))) ?? Enum.Material.SmoothPlastic), Transparency: 1 });
					$ins(parts, { part: bar, a: a, rr: rr, h: h });
				}
				if ((kind === "Time")) {
					orbiters("Clock", 1, 0.9, undefined);
				}
			} else if ((kind === "Reticle")) {
				orbiters("Ring", 1, 1.6, C(255, 60, 50));
				mode = "reticle";
			} else if ((kind === "Lift")) {
				emit({ Texture: TEX.Sparkle, Rate: $mul(20, quality()), Color: ColorSequence.new(($n(color) ?? C(180, 140, 255))), Size: NS(0, 0.4, 1, 0), Lifetime: NumberRange.new(0.5, 0.8), Speed: NumberRange.new(3, 6), EmissionDirection: Enum.NormalId.Top, SpreadAngle: Vector2.new(20, 20) });
				mode = "none";
			} else {
				orbiters("Star", 2, 0.4, ($n(color) ?? C(255, 225, 80)));
			}
			let nextZ = 0;
			let nextFloat = 0;
			animate(dur, function (k, t) {
				if (!$t(root.Parent)) {
					return true;
				}
				let fade = math.clamp($div(($sub(k, 0.85)), 0.15), 0, 1);
				let appear = math.min(1, $div(t, 0.15));
				let headPos = $add(root.Position, $mul(UP, top));
				if (((mode === "orbit") || (mode === "reticle"))) {
					for (let $v65 = 0, $v66 = $arr(rigs); $v65 < $v66.length; $v65++) {
						let it = $v66[$v65];
						if (it == null) break;
						let i = $v65 + 1;
						let a = $add(it.a, $mul(t, (($n(((mode === "reticle") && 1)) ?? 5))));
						let at = ($n(((mode === "reticle") && $add(headPos, $mul(UP, 0.6)))) ?? $add(headPos, Vector3.new($mul((math.cos(a) * 1.1), s), (math.sin($add($mul(t, 7), i)) * 0.15), $mul((math.sin(a) * 1.1), s))));
						let cf = ($n(((mode === "reticle") && $mul(CFrame.new(at), CFrame.Angles(0, $mul(t, 2), 0)))) ?? $mul(CFrame.new(at), CFrame.Angles(0, $unm(a), $mul(t, 3))));
						$sp(SkillArt.Place(it.rig, cf));
						$sp(SkillArt.Fade(it.rig, math.max($sub(1, appear), fade)));
					}
				} else if ((mode === "center")) {
					for (let $v67 = 0, $v68 = $arr(rigs); $v67 < $v68.length; $v67++) {
						let it = $v68[$v67];
						if (it == null) break;
						$sp(SkillArt.Place(it.rig, CFrame.new($add(root.Position, $mul($mul(UP, math.sin($mul(t, 3))), 0.3)))));
						$sp(SkillArt.Fade(it.rig, math.max($sub(1, appear), fade)));
					}
				} else if ((mode === "bars")) {
					let feet = $sub(root.Position, $mul(UP, ($add((root.Size.Y * 0.5), $mul(0.5, s)))));
					for (let $v69 = 0, $v70 = $arr(parts); $v69 < $v70.length; $v69++) {
						let it = $v70[$v69];
						if (it == null) break;
						let i = $v69 + 1;
						let cf;
						if ((kind === "Cage")) {
							cf = CFrame.new($add(feet, Vector3.new($mul(math.cos(it.a), it.rr), $div(it.h, 2), $mul(math.sin(it.a), it.rr))));
						} else {
							let a = $add(it.a, $mul(t, (($n(((kind === "Wrap") && 1.5)) ?? 0.4))));
							let y = (root.Size.Y * ((0.2 + (0.6 * ((((i - 1)) / $len(parts)))))));
							cf = $mul(CFrame.new($add(feet, $mul(UP, ($add(y, $mul(0.4, s)))))), CFrame.Angles(0, a, math.rad(($n(((kind === "Vines") && 25)) ?? 12))));
						}
						it.part.CFrame = cf;
						it.part.Transparency = $add((($n(((kind === "Honey") && 0.35)) ?? 0.1)), (0.9 * math.max($sub(1, appear), fade)));
					}
					for (let $v71 = 0, $v72 = $arr(rigs); $v71 < $v72.length; $v71++) {
						let it = $v72[$v71];
						if (it == null) break;
						$sp(SkillArt.Place(it.rig, $mul(CFrame.new($add(headPos, $mul(UP, 0.8))), CFrame.Angles(0, t, 0))));
						$sp(SkillArt.Fade(it.rig, math.max($sub(1, appear), fade)));
					}
				} else if ((mode === "sleep")) {
					if ((t >= nextZ)) {
						nextZ = $add(t, 0.45);
						floatText($add(headPos, Vector3.new($mul(0.4, s), 0, 0)), "Z", C(200, 220, 255), 26, 1, 2.5, rnd((-15), 15));
					}
				} else if ((mode === "float")) {
					if ((t >= nextFloat)) {
						nextFloat = $add(t, 0.35);
						floatUp(($n(((kind === "Charm") && "Heart")) ?? "Note"), headPos, 1, 0.6, ($n(((kind === "Charm") && C(255, 100, 170))) ?? pick(CONFETTI)), 0.9, 0.8);
					}
				} else if ((mode === "swirl")) {
					if ((t >= nextFloat)) {
						nextFloat = $add(t, 0.3);
						groundRing($sub(root.Position, $mul(UP, ($add((root.Size.Y * 0.5), $mul(0.5, s))))), 0.3, $mul(2.2, s), ($n(color) ?? C(140, 190, 255)), 0.5, 0.2);
					}
				}
				return false;
			}, function () {
				for (let $v73 = 0, $v74 = $arr(rigs); $v73 < $v74.length; $v73++) {
					let it = $v74[$v73];
					if (it == null) break;
					$sp(SkillArt.Destroy(it.rig));
				}
				for (let $v75 = 0, $v76 = $arr(parts); $v75 < $v76.length; $v75++) {
					let it = $v76[$v75];
					if (it == null) break;
					$mc(it.part, "Destroy");
				}
				for (let $v77 = 0, $v78 = $arr(emitters); $v77 < $v78.length; $v77++) {
					let e = $v78[$v77];
					if (e == null) break;
					e.Enabled = false;
				}
			});
		};
		H.S_Aura = function (p) {
			let model = p.Model;
			let root = rootOf(model);
			if (!$t(root)) {
				return;
			}
			let kind = ($n(p.Kind) ?? "Shield");
			let dur = math.max(0.4, ($n(p.Duration) ?? 2));
			let color = ($n(p.Color) ?? C(140, 200, 255));
			let s = sizeOf(model);
			let att = Instance.new("Attachment");
			att.Parent = root;
			$mc(Debris, "AddItem", att, $add(dur, 1.5));
			let emitters = [], rigs = [], parts = [];
			let emit = function (props) {
				let e = emitter(att, props);
				e.Enabled = true;
				$ins(emitters, e);
				return e;
			};
			let bubble = undefined;
			let pl = Instance.new("PointLight");
			pl.Color = color;
			pl.Range = $mul(10, s);
			pl.Brightness = 0;
			pl.Shadows = false;
			pl.Parent = att;
			if ((((((kind === "Shield") || (kind === "Bubble")) || (kind === "Metal")) || (kind === "Holy")) || (kind === "Crystal"))) {
				bubble = fxPart({ Shape: Enum.PartType.Ball, Size: $mul(Vector3.one, ($add((root.Size.Z * 1.6), $mul(2, s)))), CFrame: root.CFrame, Color: color, Material: ($n(((kind === "Bubble") && GLASS)) ?? Enum.Material.ForceField), Transparency: 1 });
				if ((kind === "Holy")) {
					let halo = build("Ring", $mul(1.2, s), C(255, 230, 120), undefined, true);
					if ($t(halo)) {
						$ins(rigs, { rig: halo, halo: true });
					}
				} else if (((kind === "Crystal") || (kind === "Metal"))) {
					for (let i = 1, $v79 = 4; i <= $v79; i++) {
						let rig = build(($n(((kind === "Crystal") && "Crystal")) ?? "Shield"), $mul(0.8, s), color, undefined, true);
						if ($t(rig)) {
							$ins(rigs, { rig: rig, a: $mul((((i - 1)) / 4), TAU) });
						}
					}
				}
			} else if (((kind === "Rage") || (kind === "Fire"))) {
				emit({ Texture: TEX.Fire, Rate: $mul(40, quality()), Color: ($n(((kind === "Rage") && CS(0, C(255, 200, 120), 1, C(220, 30, 30)))) ?? CS(0, C(255, 230, 140), 1, C(255, 90, 20))), Size: NS(0, $mul(2, s), 1, 0), Lifetime: NumberRange.new(0.4, 0.7), Speed: NumberRange.new(2, 5), SpreadAngle: Vector2.new(180, 180), EmissionDirection: Enum.NormalId.Top, LightEmission: 1, Acceleration: Vector3.new(0, 6, 0) });
			} else if (((kind === "Haste") || (kind === "Wind"))) {
				emit({ Texture: TEX.Sparkle, Rate: $mul(30, quality()), Color: ColorSequence.new(WHITE), Size: NS(0, 0.3, 1, 0), Lifetime: NumberRange.new(0.2, 0.4), Speed: NumberRange.new(8, 14), SpreadAngle: Vector2.new(20, 20), EmissionDirection: Enum.NormalId.Back });
				if ($t(H.Streak)) {
					$sp(H.Streak({ Model: model, Color: color, Duration: dur, Width: 1, Lifetime: 0.3 }));
				}
			} else if ((kind === "Heal")) {
				emit({ Texture: TEX.Sparkle, Rate: $mul(25, quality()), Color: ColorSequence.new(C(120, 255, 140)), Size: NS(0, 0.6, 1, 0), Lifetime: NumberRange.new(0.6, 1), Speed: NumberRange.new(3, 6), SpreadAngle: Vector2.new(40, 40), EmissionDirection: Enum.NormalId.Top });
				for (let i = 1, $v80 = 3; i <= $v80; i++) {
					task.delay((((i - 1)) * 0.2), function () {
						floatText($add(root.Position, Vector3.new(rnd((-1), 1), root.Size.Y, rnd((-1), 1))), "+", C(120, 255, 140), 30, 0.8, 3);
					});
				}
			} else if ((kind === "Stone")) {
				for (let i = 1, $v81 = 5; i <= $v81; i++) {
					let rig = build("Rock", $mul(1.1, s), undefined, undefined, true);
					if ($t(rig)) {
						$ins(rigs, { rig: rig, a: $mul((((i - 1)) / 5), TAU) });
					}
				}
			} else if ((kind === "Shadow")) {
				emit({ Texture: TEX.Smoke, Rate: $mul(20, quality()), Color: ColorSequence.new(C(40, 15, 60)), Size: NS(0, $mul(2, s), 1, $mul(4, s)), Transparency: NS(0, 0.4, 1, 1), Lifetime: NumberRange.new(0.6, 1), Speed: NumberRange.new(1, 3), LightEmission: 0 });
			} else if ((kind === "Ice")) {
				emit({ Texture: TEX.Sparkle, Rate: $mul(25, quality()), Color: ColorSequence.new(C(200, 240, 255)), Size: NS(0, 0.5, 1, 0), Lifetime: NumberRange.new(0.5, 1), Speed: NumberRange.new(1, 4) });
				for (let i = 1, $v82 = 4; i <= $v82; i++) {
					let rig = build("Snowflake", $mul(0.7, s), C(200, 240, 255), undefined, true);
					if ($t(rig)) {
						$ins(rigs, { rig: rig, a: $mul((((i - 1)) / 4), TAU) });
					}
				}
			} else if ((kind === "Storm")) {
				emit({ Texture: TEX.Spark, Rate: $mul(30, quality()), Color: ColorSequence.new(C(255, 240, 120)), Size: NS(0, 0.5, 1, 0), Lifetime: NumberRange.new(0.15, 0.3), Speed: NumberRange.new(8, 14) });
			} else if ((kind === "Siren")) {
				for (let $v83 = 0, $v84 = $arr([C(255, 40, 40), C(40, 90, 255)]); $v83 < $v84.length; $v83++) {
					let col = $v84[$v83];
					if (col == null) break;
					let i = $v83 + 1;
					let ball = fxPart({ Shape: Enum.PartType.Ball, Size: $mul($mul(Vector3.one, 0.7), s), Color: col, Transparency: 0 });
					$ins(parts, { part: ball, side: ($n(((i === 1) && (-1))) ?? 1), col: col });
				}
			} else if (((kind === "Gold") || (kind === "Rainbow"))) {
				emit({ Texture: TEX.Sparkle, Rate: $mul(30, quality()), Color: ($n(((kind === "Rainbow") && CS(0, $get(RAINBOW, 1), 0.33, $get(RAINBOW, 3), 0.66, $get(RAINBOW, 5), 1, $get(RAINBOW, 6)))) ?? ColorSequence.new(C(255, 220, 100))), Size: NS(0, 0.6, 1, 0), Lifetime: NumberRange.new(0.5, 1), Speed: NumberRange.new(2, 5) });
			}
			animate(dur, function (k, t) {
				if (!$t(root.Parent)) {
					return true;
				}
				let appear = math.min(1, $div(t, 0.2));
				let fade = math.clamp($div(($sub(k, 0.85)), 0.15), 0, 1);
				let vis = math.max($sub(1, appear), fade);
				pl.Brightness = $mul(2.5, ($sub(1, vis)));
				if ($t(bubble)) {
					bubble.CFrame = $mul(CFrame.new(root.Position), CFrame.Angles(0, t, 0));
					let base = ($n(((kind === "Bubble") && 0.6)) ?? 0.15);
					bubble.Transparency = $add(base, $mul(($sub(1, base)), vis));
					bubble.Size = $mul($mul(Vector3.one, ($add((root.Size.Z * 1.6), $mul(2, s)))), ((1 + (math.sin($mul(t, 6)) * 0.03))));
				}
				for (let $v85 = 0, $v86 = $arr(rigs); $v85 < $v86.length; $v85++) {
					let it = $v86[$v85];
					if (it == null) break;
					let i = $v85 + 1;
					let cf;
					if ($t(it.halo)) {
						cf = $mul(CFrame.new($add(root.Position, $mul(UP, ($add((root.Size.Y * 0.5), $mul(1.8, s)))))), CFrame.Angles(math.rad(90), 0, t));
					} else {
						let a = $add(it.a, $mul(t, 2.2));
						let rr = $add((root.Size.Z * 0.8), $mul(1.4, s));
						cf = $mul(CFrame.new($add(root.Position, Vector3.new($mul(math.cos(a), rr), (math.sin($add($mul(t, 3), i)) * 0.4), $mul(math.sin(a), rr)))), CFrame.Angles(0, $unm(a), 0));
					}
					$sp(SkillArt.Place(it.rig, cf));
					$sp(SkillArt.Fade(it.rig, vis));
				}
				for (let $v87 = 0, $v88 = $arr(parts); $v87 < $v88.length; $v87++) {
					let it = $v88[$v87];
					if (it == null) break;
					let on = $eq((($mod(math.floor($mul(t, 6)), 2) === 0)), ((it.side < 0)));
					it.part.CFrame = $mul(root.CFrame, CFrame.new($mul($mul(it.side, 0.45), s), $add((root.Size.Y * 0.5), $mul(1.2, s)), 0));
					it.part.Transparency = ($n(($a(on) && vis)) ?? $add(0.7, $mul(0.3, vis)));
					if ($t(on)) {
						pl.Color = it.col;
					}
				}
				return false;
			}, function () {
				$mc(pl, "Destroy");
				if ($t(bubble)) {
					$mc(bubble, "Destroy");
				}
				for (let $v89 = 0, $v90 = $arr(rigs); $v89 < $v90.length; $v89++) {
					let it = $v90[$v89];
					if (it == null) break;
					$sp(SkillArt.Destroy(it.rig));
				}
				for (let $v91 = 0, $v92 = $arr(parts); $v91 < $v92.length; $v91++) {
					let it = $v92[$v91];
					if (it == null) break;
					$mc(it.part, "Destroy");
				}
				for (let $v93 = 0, $v94 = $arr(emitters); $v93 < $v94.length; $v93++) {
					let e = $v94[$v93];
					if (e == null) break;
					e.Enabled = false;
				}
			});
		};
		let BURST = { Confetti: ["Confetti", 0.9, 30, function (i) {
			return $get(CONFETTI, $add(($mod(i, $len(CONFETTI))), 1));
		}, { gravity: 25, drag: 1.5, life: 1.6 }], Dirt: ["Rock", 0.45, 22, undefined, { life: 1 }], Rocks: ["Rock", 0.7, 26, undefined, { life: 1.1 }], Leaves: ["Leaf", 0.7, 16, function () {
			return $mc(C(90, 190, 70), "Lerp", C(170, 220, 80), math.random());
		}, { gravity: 10, drag: 2, life: 1.6 }], Petals: ["Petal", 0.7, 16, undefined, { gravity: 8, drag: 2, life: 1.8 }], Bones: ["Bone", 0.5, 22, undefined, { life: 1.1 }], Hearts: ["Heart", 0.6, 14, undefined, { gravity: (-4), drag: 2, life: 1.3 }], Notes: ["Note", 0.7, 14, function () {
			return $get(CONFETTI, math.random(1, $len(CONFETTI)));
		}, { gravity: (-4), drag: 2, life: 1.3 }], Stars: ["Star", 0.6, 22, undefined, { gravity: 20, life: 1 }], Coins: ["Coin", 0.7, 24, undefined, { life: 1.2 }], Bubbles: ["Bubble", 0.7, 10, undefined, { gravity: (-6), drag: 2, life: 1.4 }], Snow: ["Snowflake", 0.6, 14, function () {
			return C(220, 240, 255);
		}, { gravity: 6, drag: 2, life: 1.4 }], Feathers: ["Feather", 0.8, 14, undefined, { gravity: 5, drag: 2.5, life: 1.8 }], Crystals: ["Crystal", 0.6, 24, undefined, { life: 1.1 }], Sand: ["Sand", 0.6, 22, undefined, { life: 1 }], Spores: ["Spore", 0.6, 10, undefined, { gravity: (-3), drag: 2, life: 1.6 }], Crumbs: ["Crumb", 0.8, 18, undefined, { life: 1 }], Poms: ["Pom", 0.6, 20, undefined, { life: 1.1 }], Drops: ["Drop", 0.6, 22, undefined, { life: 0.9 }], Embers: ["Ember", 0.6, 20, undefined, { gravity: (-2), drag: 1.5, life: 1.2 }], Feather: ["Feather", 0.8, 14, undefined, { gravity: 5, drag: 2.5, life: 1.8 }], Skulls: ["Skull", 0.5, 20, undefined, { life: 1 }], Shards: ["Shard", 0.5, 26, undefined, { life: 0.9 }], Ink: ["Ink", 0.5, 20, undefined, { life: 0.9 }] };
		H.S_Burst = function (p) {
			let def = ($n($get(BURST, ($n(p.Kind) ?? "Confetti"))) ?? BURST.Confetti);
			let color = p.Color;
			let colorFn = ($n($get(def, 4)) ?? function () {
				return color;
			});
			let speed = $mul($get(def, 3), $pow(($div((($n(p.Radius) ?? 6)), 6)), 0.5));
			let opts = table.clone($get(def, 5));
			if ($t(p.Dir)) {
				opts.dir = p.Dir;
				opts.cone = ($n(p.Cone) ?? 0.5);
			}
			toss($get(def, 1), $add(p.Position, $mul(UP, 0.6)), ($n(p.Count) ?? 12), speed, $mul((($n(p.Size) ?? 1)), $get(def, 2)), colorFn, opts);
			if ((((p.Kind === "Dirt") || (p.Kind === "Rocks")) || (p.Kind === "Sand"))) {
				smoke(p.Position, ($n(((p.Kind === "Sand") && C(225, 195, 130))) ?? C(150, 125, 95)), 10, 2.5, 10);
			}
		};
		let BEAM = { Laser: [C(255, 60, 60), WHITE, 0.35], Water: [C(90, 170, 255), C(230, 245, 255), 1], Fire: [C(255, 120, 30), C(255, 240, 170), 1], Holy: [C(255, 220, 120), WHITE, 1.2], Plasma: [C(120, 255, 140), WHITE, 0.9], Ice: [C(150, 220, 255), WHITE, 0.9], Sound: [C(255, 120, 220), WHITE, 0.8], Rainbow: [C(255, 255, 255), WHITE, 1], Void: [C(140, 60, 220), C(20, 0, 40), 1.1], Photon: [C(120, 230, 255), WHITE, 1.6], Tractor: [C(120, 255, 180), WHITE, 1], Sun: [C(255, 190, 60), C(255, 250, 220), 1.5] };
		H.S_Beam = function (p) {
			let kind = ($n(p.Kind) ?? "Laser");
			let def = ($n($get(BEAM, kind)) ?? BEAM.Laser);
			let color = ($n(p.Color) ?? $get(def, 1));
			let core = ($n(p.Color2) ?? $get(def, 2));
			let width = $mul($mul((($n(p.Width) ?? 3)), $get(def, 3)), 0.5);
			let dur = ($n(p.Duration) ?? 0.8);
			let from0 = p.From, to0 = p.To;
			if (!($t(from0) && $t(to0))) {
				return;
			}
			let baseDir = $sub(to0, from0);
			let length = baseDir.Magnitude;
			if ((length < 0.5)) {
				return;
			}
			baseDir = baseDir.Unit;
			let glow = fxPart({ Shape: Enum.PartType.Cylinder, Size: Vector3.new(length, $mul(width, 2), $mul(width, 2)), Color: color, Transparency: 0.45 });
			let mid = fxPart({ Shape: Enum.PartType.Cylinder, Size: Vector3.new(length, width, width), Color: color, Transparency: 0.15 });
			let inner = fxPart({ Shape: Enum.PartType.Cylinder, Size: Vector3.new(length, $mul(width, 0.4), $mul(width, 0.4)), Color: core, Transparency: 0 });
			let strands = [];
			if ((kind === "Rainbow")) {
				for (let i = 1, $v95 = 3; i <= $v95; i++) {
					$ins(strands, fxPart({ Shape: Enum.PartType.Cylinder, Size: Vector3.new(length, $mul(width, 0.5), $mul(width, 0.5)), Color: $get(RAINBOW, ((i * 2) - 1)), Transparency: 0.1 }));
				}
			}
			let endAtt = anchor(to0, $add(dur, 1));
			let endFx = emitter(endAtt, { Texture: ($n(((((kind === "Fire") || (kind === "Sun"))) && TEX.Fire)) ?? TEX.Sparkle), Enabled: true, Rate: $mul(50, quality()), Color: ColorSequence.new(color), Size: NS(0, $mul(width, 1.2), 1, 0), Lifetime: NumberRange.new(0.2, 0.4), Speed: NumberRange.new(6, 14), SpreadAngle: Vector2.new(180, 180), LightEmission: 1 });
			let startPos = from0;
			let rings = [];
			animate(dur, function (k, t) {
				let m = ($a(p.Model) && mouthCF(p.Model));
				if ($t(m)) {
					startPos = m.Position;
				}
				let d = baseDir;
				if ($t(p.Sweep)) {
					let a = math.rad($mul($mul(p.Sweep, ($sub(k, 0.5))), 2));
					let c = math.cos(a), sn = math.sin(a);
					d = Vector3.new($sub($mul(baseDir.X, c), $mul(baseDir.Z, sn)), baseDir.Y, $add($mul(baseDir.X, sn), $mul(baseDir.Z, c)));
				}
				let endPos = $add(startPos, $mul(d, length));
				let cf = $mul(CFrame.lookAt($mc(startPos, "Lerp", endPos, 0.5), endPos), CFrame.Angles(0, math.rad(90), 0));
				let open = math.min(1, $div(t, 0.12));
				let close = math.clamp($div(($sub(k, 0.8)), 0.2), 0, 1);
				let w = $mul($mul($mul(width, open), ($sub(1, close))), ((1 + (math.sin($mul(t, 40)) * 0.08))));
				glow.CFrame = cf;
				mid.CFrame = cf;
				inner.CFrame = cf;
				glow.Size = Vector3.new(length, $add($mul(w, 2), 0.05), $add($mul(w, 2), 0.05));
				mid.Size = Vector3.new(length, $add(w, 0.05), $add(w, 0.05));
				inner.Size = Vector3.new(length, $add($mul(w, 0.4), 0.05), $add($mul(w, 0.4), 0.05));
				for (let $v96 = 0, $v97 = $arr(strands); $v96 < $v97.length; $v96++) {
					let st = $v97[$v96];
					if (st == null) break;
					let i = $v96 + 1;
					let a = $add($mul(t, 8), $div($mul(i, TAU), 3));
					st.CFrame = $mul(cf, CFrame.new(0, $mul($mul(math.cos(a), w), 0.6), $mul($mul(math.sin(a), w), 0.6)));
					st.Size = Vector3.new(length, $add($mul(w, 0.5), 0.05), $add($mul(w, 0.5), 0.05));
				}
				endAtt.WorldPosition = endPos;
				if (((kind === "Sound") && (math.random() < 0.3))) {
					$ins(rings, { u: 0 });
				}
			}, function () {
				$mc(glow, "Destroy");
				$mc(mid, "Destroy");
				$mc(inner, "Destroy");
				for (let $v98 = 0, $v99 = $arr(strands); $v98 < $v99.length; $v98++) {
					let st = $v99[$v98];
					if (st == null) break;
					$mc(st, "Destroy");
				}
				endFx.Enabled = false;
			});
			light($mc(from0, "Lerp", to0, 0.5), color, $mul(length, 0.6), dur, 4);
			if ((kind === "Sound")) {
				for (let i = 1, $v100 = q(5); i <= $v100; i++) {
					task.delay($div($mul(((i - 1)), dur), 5), function () {
						let rig = build("Ring", $mul(width, 0.9), color, undefined);
						if (!$t(rig)) {
							return;
						}
						animate(0.4, function (k) {
							let m = ($a(p.Model) && mouthCF(p.Model));
							let s0 = ($n(($a(m) && m.Position)) ?? from0);
							let pos = $add(s0, $mul($mul(baseDir, length), k));
							$sp(SkillArt.Place(rig, CFrame.lookAt(pos, $add(pos, baseDir))));
							$sp(SkillArt.Fade(rig, k));
						}, function () {
							$sp(SkillArt.Destroy(rig));
						});
					});
				}
			}
		};
		let CONE = { Fire: [TEX.Fire, CS(0, C(255, 240, 170), 0.4, C(255, 130, 40), 1, C(120, 30, 10)), 1, undefined], Frost: [TEX.Sparkle, CS(0, WHITE, 1, C(140, 210, 255)), 0.8, "Snowflake"], Wind: [TEX.Swirl, ColorSequence.new(C(220, 255, 245)), 0.4, "Leaf"], Perfume: [TEX.Sparkle, CS(0, C(255, 200, 230), 1, C(255, 120, 200)), 0.8, "Heart"], Poison: [TEX.Smoke, ColorSequence.new(C(150, 230, 70)), 0.4, "Bubble"], Sand: [TEX.Smoke, ColorSequence.new(C(225, 195, 130)), 0, "Sand"], Sound: [TEX.Sparkle, ColorSequence.new(C(255, 150, 230)), 0.8, "Note"], Water: [TEX.Sparkle, CS(0, WHITE, 1, C(90, 170, 255)), 0.7, "Drop"], Spores: [TEX.Smoke, ColorSequence.new(C(190, 120, 230)), 0.5, "Spore"], Ink: [TEX.Smoke, ColorSequence.new(C(30, 20, 45)), 0, "Ink"], Ghost: [TEX.Fire, CS(0, C(220, 255, 250), 1, C(60, 220, 200)), 1, "GhostSkull"], Bubbles: [TEX.Sparkle, ColorSequence.new(C(190, 230, 255)), 0.6, "Bubble"], Shadow: [TEX.Smoke, ColorSequence.new(C(70, 30, 110)), 0.2, undefined], Holy: [TEX.Sparkle, CS(0, WHITE, 1, C(255, 220, 120)), 1, "Feather"] };
		H.S_Cone = function (p) {
			let head = headOf(p.Model, p.Head);
			let root = rootOf(p.Model);
			if (!($t(head) || $t(root))) {
				return;
			}
			let def = ($n($get(CONE, ($n(p.Kind) ?? "Fire"))) ?? CONE.Fire);
			let length = ($n(p.Length) ?? 16);
			let angle = ($n(p.Angle) ?? 30);
			let dur = ($n(p.Duration) ?? 1);
			let att = Instance.new("Attachment");
			let part = ($n(head) ?? root);
			let mouth = ($n(($a(head) && $mul(head.CFrame, CFrame.new(0, ((-head.Size.Y) * 0.15), ((-head.Size.Z) * 0.75))))) ?? mouthCF(p.Model));
			att.CFrame = $mc(part.CFrame, "ToObjectSpace", ($n(mouth) ?? part.CFrame));
			att.Parent = part;
			$mc(Debris, "AddItem", att, $add(dur, 2));
			let life = 0.5;
			let e = emitter(att, { Texture: $get(def, 1), Enabled: true, Rate: $mul(90, quality()), Color: ($n(($a(p.Color) && ColorSequence.new(p.Color))) ?? $get(def, 2)), Size: NS(0, 0.6, 1, $mul($mul(math.tan(math.rad(angle)), length), 0.9)), Transparency: NS(0, 0.15, 0.7, 0.5, 1, 1), Lifetime: NumberRange.new($mul(life, 0.8), life), Speed: NumberRange.new($mul($div(length, life), 0.8), $div(length, life)), SpreadAngle: Vector2.new($mul(angle, 0.7), $mul(angle, 0.7)), EmissionDirection: Enum.NormalId.Front, LightEmission: $get(def, 3), Drag: 1, RotSpeed: NumberRange.new((-90), 90), Rotation: NumberRange.new(0, 360) });
			let motifs = [];
			let nextMotif = 0;
			animate(dur, function (_k, t) {
				if ((($t($get(def, 4)) && (t >= nextMotif)) && !$t(full(8)))) {
					nextMotif = $add(t, $div(0.12, quality()));
					let m = mouthCF(p.Model);
					if ($t(m)) {
						let dir = ($add(m.LookVector, $mul(Vector3.new(rnd((-0.4), 0.4), rnd((-0.2), 0.3), rnd((-0.4), 0.4)), math.tan(math.rad(angle))))).Unit;
						let rig = build($get(def, 4), 0.6, p.Color, undefined);
						if ($t(rig)) {
							$ins(motifs, { rig: rig, p: m.Position, v: $div($mul(dir, length), 0.6), t0: t });
						}
					}
				}
				for (let i = $len(motifs), $v101 = 1; i >= $v101; i += (-1)) {
					let it = $get(motifs, i);
					let age = $sub(t, it.t0);
					let pos = $add(it.p, $mul(it.v, math.min(age, 0.6)));
					$sp(SkillArt.Place(it.rig, $mul(CFrame.lookAt(pos, $add(pos, it.v)), CFrame.Angles(0, 0, $mul(age, 6)))));
					$sp(SkillArt.Fade(it.rig, math.clamp($div(($sub(age, 0.35)), 0.3), 0, 1)));
					if ((age > 0.65)) {
						$sp(SkillArt.Destroy(it.rig));
						table.remove(motifs, i);
					}
				}
			}, function () {
				e.Enabled = false;
				for (let $v102 = 0, $v103 = $arr(motifs); $v102 < $v103.length; $v102++) {
					let it = $v103[$v102];
					if (it == null) break;
					$sp(SkillArt.Destroy(it.rig, 0.3));
				}
			});
			if ((((p.Kind === "Fire") || (p.Kind === "Ghost")) || (p.Kind === "Holy"))) {
				light((($n(mouthCF(p.Model)) ?? part.CFrame)).Position, ($n(p.Color) ?? C(255, 150, 60)), length, dur, 3);
			}
		};
		H.S_Wave = function (p) {
			let pos = p.Position;
			let dir = ($n(($a(p.Dir) && flat(p.Dir))) ?? Vector3.new(0, 0, (-1)));
			if ((dir.Magnitude < 0.01)) {
				return;
			}
			dir = dir.Unit;
			let side = Vector3.new((-dir.Z), 0, dir.X);
			let kind = ($n(p.Kind) ?? "Water");
			let length = ($n(p.Length) ?? 30);
			let width = ($n(p.Width) ?? 8);
			let speed = ($n(p.Speed) ?? 40);
			let color = ($n(p.Color) ?? C(90, 170, 255));
			let dur = $div(length, speed);
			let wall = [];
			let n = math.max(3, math.floor($div(width, 1.6)));
			let h = ($n(($n(($n(((kind === "Water") && 4)) ?? ((kind === "Sand") && 3))) ?? ((kind === "Sound") && 3))) ?? 2);
			if (((((((kind === "Water") || (kind === "Sand")) || (kind === "Fire")) || (kind === "Shadow")) || (kind === "Shock")) || (kind === "Sound"))) {
				for (let i = 1, $v104 = n; i <= $v104; i++) {
					let part = fxPart({ Size: Vector3.new($mul($div(width, n), 1.15), h, 1.2), Color: ($n(((kind === "Sand") && C(225, 195, 130))) ?? color), Material: ($n(($n((((kind === "Water") && GLASS))) ?? (((kind === "Sand") && Enum.Material.Sand)))) ?? NEON), Transparency: 1 });
					$ins(wall, { part: part, x: $sub($div(((i - 0.5)), n), 0.5) });
				}
			}
			let nextSpawn = 0;
			animate(dur, function (k, t) {
				let front = $add(pos, $mul($mul(dir, length), k));
				for (let $v105 = 0, $v106 = $arr(wall); $v105 < $v106.length; $v105++) {
					let w = $v106[$v105];
					if (w == null) break;
					let bulge = (math.cos($mul(w.x, math.pi)) * 1.2);
					let at = $add($add($add(front, $mul($mul(side, w.x), width)), $mul(dir, bulge)), $mul(UP, ($mul($div(h, 2), ((0.6 + (0.4 * math.sin($add($mul(t, 10), $mul(w.x, 6))))))))));
					w.part.CFrame = $mul(CFrame.lookAt(at, $add(at, dir)), CFrame.Angles(math.rad((-15)), 0, 0));
					w.part.Transparency = $add((($n(((kind === "Water") && 0.3)) ?? 0.25)), (0.75 * math.clamp($div(($sub(k, 0.8)), 0.2), 0, 1)));
				}
				if ((t >= nextSpawn)) {
					nextSpawn = $add(t, $div(0.06, quality()));
					let at = $add(front, $mul($mul(side, rnd((-0.5), 0.5)), width));
					if ((((kind === "Spikes") || (kind === "Ice")) || (kind === "Crystal"))) {
						let rig = build(($n(((kind === "Spikes") && "Rock")) ?? "Crystal"), rnd(1, 1.8), color, undefined);
						if ($t(rig)) {
							let cf = $mul(CFrame.new(at), CFrame.Angles(math.rad($add((-90), rnd((-25), 25))), rnd(0, TAU), 0));
							animate(1, function (kk) {
								$sp(SkillArt.Place(rig, $mul(cf, CFrame.new(0, 0, $mul(($sub(1, outCubic(math.min(1, $mul(kk, 5))))), 2)))));
								$sp(SkillArt.Fade(rig, math.clamp($div(($sub(kk, 0.6)), 0.4), 0, 1)));
							}, function () {
								$sp(SkillArt.Destroy(rig));
							});
						}
					} else if ((kind === "Water")) {
						puff($add(at, UP), C(220, 240, 255), 4, 0.7, 12, TEX.Sparkle, { Acceleration: Vector3.new(0, (-40), 0) });
					} else if ((kind === "Fire")) {
						puff($add(at, UP), CS(0, C(255, 230, 140), 1, color), 4, 1.5, 6, TEX.Fire, { EmissionDirection: Enum.NormalId.Top, SpreadAngle: Vector2.new(20, 20), LightEmission: 1 });
					} else if (((kind === "Sand") || (kind === "Shock"))) {
						smoke(at, ($n(((kind === "Sand") && C(225, 195, 130))) ?? C(160, 140, 110)), 3, 2, 6);
					} else if ((kind === "Sound")) {
						let rig = build("Note", 0.8, pick(CONFETTI), undefined);
						if ($t(rig)) {
							animate(0.6, function (kk) {
								$sp(SkillArt.Place(rig, CFrame.new($add(at, $mul(UP, ($add(1, $mul(2, kk))))))));
								$sp(SkillArt.Fade(rig, kk));
							}, function () {
								$sp(SkillArt.Destroy(rig));
							});
						}
					}
				}
			}, function () {
				for (let $v107 = 0, $v108 = $arr(wall); $v107 < $v108.length; $v107++) {
					let w = $v108[$v107];
					if (w == null) break;
					$mc(w.part, "Destroy");
				}
			});
		};
		let PILLAR = { Fire: [C(255, 120, 30), NEON, 0.15, TEX.Fire], Ice: [C(170, 225, 255), GLASS, 0.2, TEX.Sparkle], Holy: [C(255, 225, 130), NEON, 0.25, TEX.Sparkle], Light: [C(255, 255, 230), NEON, 0.2, TEX.Sparkle], Water: [C(80, 160, 255), GLASS, 0.25, TEX.Sparkle], Shadow: [C(90, 35, 140), GLASS, 0.35, TEX.Smoke], Poison: [C(140, 230, 70), NEON, 0.35, TEX.Smoke], Rock: [C(130, 115, 100), Enum.Material.Slate, 0, undefined], Wind: [C(220, 255, 245), Enum.Material.SmoothPlastic, 0.6, TEX.Swirl], Lava: [C(255, 100, 20), NEON, 0.1, TEX.Fire], Sand: [C(225, 195, 130), Enum.Material.Sand, 0.3, TEX.Smoke], Void: [C(40, 10, 70), GLASS, 0.3, TEX.Sparkle], Plasma: [C(120, 255, 160), NEON, 0.2, TEX.Spark], Lightning: [C(255, 240, 120), NEON, 0.3, TEX.Spark] };
		H.S_Pillar = function (p) {
			let kind = ($n(p.Kind) ?? "Fire");
			let def = ($n($get(PILLAR, kind)) ?? PILLAR.Fire);
			let pos = p.Position;
			let r = ($n(p.Radius) ?? 3);
			let height = ($n(p.Height) ?? 18);
			let time = ($n(p.Time) ?? 0.25);
			let hold = ($n(p.Hold) ?? 0.6);
			let color = ($n(p.Color) ?? $get(def, 1));
			if ((kind === "Lightning")) {
				if ($t(Effects.Bolt)) {
					$sp(Effects.Bolt($add(pos, $mul(UP, 50)), pos, color, 0.3, math.max(0.5, $mul(r, 0.35)), 0.1));
					$sp(Effects.Bolt($add($add(pos, $mul(UP, 50)), Vector3.new(rnd((-3), 3), 0, rnd((-3), 3))), pos, WHITE, 0.2, math.max(0.3, $mul(r, 0.2)), 0.12));
				}
				flash($add(pos, UP), $mul(r, 1.2), WHITE, 0.2);
				groundRing(pos, 0.5, $mul(r, 2), color, 0.4);
				light($add(pos, $mul(UP, 3)), color, $mul(r, 6), 0.4, 8);
				return;
			}
			let col = fxPart({ Shape: Enum.PartType.Cylinder, Size: Vector3.new(0.1, $mul(r, 2), $mul(r, 2)), Color: color, Material: $get(def, 2), Transparency: $get(def, 3) });
			let core;
			if (((kind !== "Rock") && (kind !== "Void"))) {
				core = fxPart({ Shape: Enum.PartType.Cylinder, Size: Vector3.new(0.1, $mul(r, 0.8), $mul(r, 0.8)), Color: $mc(WHITE, "Lerp", color, 0.3), Transparency: 0.1 });
			}
			let att = anchor($add(pos, $mul($mul(UP, height), 0.5)), $add($add(time, hold), 2));
			let e;
			if ($t($get(def, 4))) {
				e = emitter(att, { Texture: $get(def, 4), Enabled: true, Rate: $mul(40, quality()), Color: ColorSequence.new(color), Size: NS(0, $mul(r, 0.8), 1, 0), Lifetime: NumberRange.new(0.4, 0.8), Speed: NumberRange.new(4, 10), SpreadAngle: Vector2.new(180, 180), LightEmission: ($n(((kind === "Shadow") && 0)) ?? 1) });
			}
			let spin = ($n(((kind === "Wind") && 8)) ?? 1);
			animate($add(time, hold), function (_k, t) {
				let grow = outCubic(math.min(1, $div(t, time)));
				let fade = math.clamp($div(($sub($sub(t, time), $mul(hold, 0.6))), ($mul(hold, 0.4))), 0, 1);
				let hh = math.max(0.1, $mul(height, grow));
				let cf = $mul(CFrame.new($add(pos, $div($mul(UP, hh), 2))), CFrame.Angles(0, $mul(t, spin), math.rad(90)));
				col.CFrame = cf;
				col.Size = Vector3.new(hh, $mul($mul(r, 2), ($sub(1, $mul(0.6, fade)))), $mul($mul(r, 2), ($sub(1, $mul(0.6, fade)))));
				col.Transparency = $add($get(def, 3), $mul(($sub(1, $get(def, 3))), fade));
				if ($t(core)) {
					core.CFrame = cf;
					core.Size = Vector3.new(hh, $mul($mul(r, 0.8), ($sub(1, fade))), $mul($mul(r, 0.8), ($sub(1, fade))));
					core.Transparency = $add(0.1, $mul(0.9, fade));
				}
			}, function () {
				$mc(col, "Destroy");
				if ($t(core)) {
					$mc(core, "Destroy");
				}
				if ($t(e)) {
					e.Enabled = false;
				}
			});
			groundRing(pos, 0.5, $mul(r, 1.8), color, 0.45);
			light($add(pos, $mul(UP, 3)), color, $mul(r, 5), $add(time, hold), 5);
			if ((kind === "Rock")) {
				impact("Rock", pos, r, color);
			}
		};
		let CREATURE = { Bee: ["Bee", "Swarm", 0.8, "Poison"], Ghost: ["Ghost", "Fly", 1.2, "Void"], Wolf: ["Wolf", "Run", 1.1, "Shock"], Shade: ["Wolf", "Run", 1.1, "Void"], Bull: ["Bull", "Run", 1.4, "Dirt"], Skeleton: ["Skeleton", "Rise", 1, "Bones"], Bat: ["Bat", "Fly", 0.9, "Ink"], Bird: ["Bird", "Fly", 0.9, "Feathers"], Snake: ["Snake", "Rise", 1.2, "Poison"], Scarab: ["Scarab", "Run", 0.8, "Sand"], Fish: ["Fish", "Fly", 0.8, "Splash"], Plane: ["Plane", "Over", 1.6, "Explode"], Hound: ["Wolf", "Run", 1.3, "Fire"], Spirit: ["Wolf", "Fly", 2.2, "Holy"], Tentacle: ["Tentacle", "Rise", 1.2, "Splash"], Hand: ["BoneHand", "Rise", 1.2, "Bones"], Shark: ["Megalodon", "Rise", 0.35, "Splash"], Fist: ["Fist", "Dive", 1.4, "Shock"], Comet: ["Comet", "Dive", 1.2, "Stars"], Spear: ["Lance", "Dive", 1.3, "Holy"], Sword: ["Blade", "Dive", 1.3, "Burst"], Missile: ["Missile", "Over", 1.3, "Explode"] };
		H.S_Summon = function (p) {
			let def = ($n($get(CREATURE, ($n(p.Kind) ?? "Ghost"))) ?? CREATURE.Ghost);
			let from = ($n(($n(p.From) ?? (($a(rootOf(p.Model)) && rootOf(p.Model).Position)))) ?? Vector3.zero);
			let time = ($n(p.Time) ?? 0.8);
			let color = p.Color;
			let size = $mul((($n(p.Size) ?? 1)), $get(def, 3));
			let path = ($n(p.Path) ?? $get(def, 2));
			for (let $v109 = 0, $v110 = $arr(($n(p.Points) ?? [])); $v109 < $v110.length; $v109++) {
				let pt = $v110[$v109];
				if (pt == null) break;
				let i = $v109 + 1;
				task.delay($mul(((i - 1)), (($n(p.Gap) ?? 0.15))), function () {
					let swarm = (path === "Swarm");
					let count = ($n(($a(swarm) && q(4))) ?? 1);
					let list = [];
					for (let j = 1, $v111 = count; j <= $v111; j++) {
						let rig = build($get(def, 1), $mul(size, (($n(($a(swarm) && rnd(0.6, 1))) ?? 1))), color, undefined);
						if ($t(rig)) {
							$ins(list, { rig: rig, o: ($n(($a(swarm) && $mul(unitRandom(0.3), 1.5))) ?? Vector3.zero), ph: j });
						}
					}
					let start = $add(from, Vector3.new(rnd((-2), 2), 0, rnd((-2), 2)));
					if ((path === "Rise")) {
						start = $sub(pt, $mul(UP, 4));
					} else if ((path === "Dive")) {
						start = $add($add(pt, $mul(UP, 40)), Vector3.new(rnd((-8), 8), 0, rnd((-8), 8)));
					} else if ((path === "Over")) {
						let d = flat($sub(pt, from));
						d = ($n(((d.Magnitude > 0.1) && d.Unit)) ?? Vector3.new(0, 0, (-1)));
						start = $add($sub(pt, $mul(d, 60)), $mul(UP, 22));
					}
					let last = start;
					let riseHold = ($n(((path === "Rise") && 0.35)) ?? 0);
					let over = $add(pt, $mul(UP, 22));
					if ((path === "Over")) {
						task.delay(time, function () {
							impact($get(def, 4), pt, $mul(3, size), color);
						});
						task.delay($mul(time, 0.55), function () {
							let bomb = build(($n((($get(def, 1) === "Missile") && "Missile")) ?? "Bomb"), $mul(0.9, size), undefined, undefined);
							if ($t(bomb)) {
								let b0 = $mc(start, "Lerp", over, 0.55);
								animate($mul(time, 0.45), function (kk) {
									let bp = $mc(b0, "Lerp", pt, $mul(kk, kk));
									$sp(SkillArt.Place(bomb, CFrame.lookAt(bp, $add(pt, Vector3.new(0.01, 0, 0)))));
								}, function () {
									$sp(SkillArt.Destroy(bomb));
								});
							}
						});
					}
					animate($add($add(time, riseHold), (($n(((path === "Over") && $mul(time, 0.6))) ?? 0))), function (k, t) {
						let u = math.clamp($div(t, time), 0, 1);
						let pos;
						if ((path === "Rise")) {
							pos = $mc(start, "Lerp", $add(pt, $mul(UP, ($mul(2, size)))), outCubic(u));
							if ((t > time)) {
								pos = $add(pos, $mul($mul(UP, math.sin($mul(($sub(t, time)), 20))), 0.3));
							}
						} else if (((path === "Fly") || (path === "Swarm"))) {
							pos = $add($mc(start, "Lerp", pt, u), $mul(UP, ((3 + (4 * math.sin($mul(u, math.pi)))))));
						} else if ((path === "Dive")) {
							pos = $mc(start, "Lerp", pt, $mul(u, u));
						} else if ((path === "Over")) {
							pos = $mc(start, "Lerp", over, $div(t, time));
						} else {
							pos = $add($mc(start, "Lerp", pt, u), $mul(UP, ($add($mul(1, size), (math.abs(math.sin($mul(t, 14))) * 0.6)))));
						}
						let dir = $sub(pos, last);
						if ((dir.Magnitude < 0.001)) {
							dir = flat($sub(pt, start));
							if ((dir.Magnitude < 0.001)) {
								dir = Vector3.new(0, 0, (-1));
							}
						}
						if ((path === "Rise")) {
							dir = flat($sub(pt, from));
							if ((dir.Magnitude < 0.01)) {
								dir = Vector3.new(0, 0, (-1));
							}
						}
						last = pos;
						if ((path === "Dive")) {
							dir = $add($sub(pt, start), Vector3.new(0.01, 0, 0));
						}
						for (let $v112 = 0, $v113 = $arr(list); $v112 < $v113.length; $v112++) {
							let it = $v113[$v112];
							if (it == null) break;
							let wob = ($n(($a(swarm) && Vector3.new((math.sin($add($mul(t, 9), it.ph)) * 0.8), (math.cos($add($mul(t, 11), it.ph)) * 0.6), (math.cos($add($mul(t, 7), it.ph)) * 0.8)))) ?? Vector3.zero);
							let at = $add($add(pos, it.o), wob);
							$sp(SkillArt.Place(it.rig, CFrame.lookAt(at, $add(at, dir))));
							if ((k < 0.12)) {
								$sp(SkillArt.Fade(it.rig, $sub(1, $div(k, 0.12))));
							}
						}
					}, function () {
						if ((path !== "Over")) {
							impact($get(def, 4), pt, $mul(3, size), color);
						}
						for (let $v114 = 0, $v115 = $arr(list); $v114 < $v115.length; $v114++) {
							let it = $v115[$v114];
							if (it == null) break;
							let rig = it.rig;
							if (((path === "Rise") || (path === "Over"))) {
								animate(0.35, function (kk) {
									$sp(SkillArt.Fade(rig, kk));
								}, function () {
									$sp(SkillArt.Destroy(rig));
								});
							} else {
								$sp(SkillArt.Destroy(rig));
							}
						}
					});
				});
			}
		};
		let SKY = { Dark: [C(150, 135, 185), (-0.12), 0.15, (-0.2)], Red: [C(255, 150, 140), (-0.05), 0.2, 0.1], Gold: [C(255, 235, 180), 0.06, 0.1, 0.1], Ice: [C(200, 230, 255), 0.04, 0.05, (-0.25)], Night: [C(120, 120, 190), (-0.2), 0.2, (-0.3)], Storm: [C(170, 180, 205), (-0.12), 0.25, (-0.3)], Toxic: [C(190, 255, 170), (-0.04), 0.1, 0], Space: [C(160, 145, 230), (-0.15), 0.2, 0.1], Holy: [C(255, 250, 225), 0.12, 0.05, 0], Fire: [C(255, 195, 150), 0, 0.15, 0.15], Time: [C(225, 225, 235), 0, 0.05, (-0.95)], Rainbow: [C(255, 245, 250), 0.05, 0.1, 0.6], Abyss: [C(110, 150, 210), (-0.18), 0.2, (-0.2)], Sand: [C(255, 225, 170), 0, 0.1, (-0.1)], Ocean: [C(150, 200, 255), (-0.05), 0.1, 0.1], Spooky: [C(255, 185, 140), (-0.14), 0.22, 0.1] };
		H.S_Sky = function (p) {
			let cam = workspace.CurrentCamera;
			if ((!$t(cam) || ($t(p.Position) && (($sub(cam.CFrame.Position, p.Position)).Magnitude > 260)))) {
				return;
			}
			let def = ($n($get(SKY, ($n(p.Kind) ?? "Dark"))) ?? SKY.Dark);
			let dur = math.max(0.8, ($n(p.Duration) ?? 3));
			let cc = Instance.new("ColorCorrectionEffect");
			cc.Name = "SkillSky";
			cc.TintColor = WHITE;
			cc.Parent = Lighting;
			$mc(Debris, "AddItem", cc, $add(dur, 1));
			let goal = function (k) {
				return { TintColor: $mc(WHITE, "Lerp", $get(def, 1), k), Brightness: $mul($get(def, 2), k), Contrast: $mul($get(def, 3), k), Saturation: $mul($get(def, 4), k) };
			};
			$mc($mc(TweenService, "Create", cc, TweenInfo.new(0.35), goal(1)), "Play");
			task.delay($sub(dur, 0.45), function () {
				if ($t(cc.Parent)) {
					$mc($mc(TweenService, "Create", cc, TweenInfo.new(0.45), goal(0)), "Play");
				}
			});
			let fl = Instance.new("ColorCorrectionEffect");
			fl.Brightness = 0.35;
			fl.Parent = Lighting;
			$mc($mc(TweenService, "Create", fl, TweenInfo.new(0.35), { Brightness: 0 }), "Play");
			$mc(Debris, "AddItem", fl, 0.5);
			if ((p.Kind === "Storm")) {
				for (let i = 1, $v116 = q(4); i <= $v116; i++) {
					task.delay($div($mul(i, dur), 5), function () {
						let f2 = Instance.new("ColorCorrectionEffect");
						f2.Brightness = 0.25;
						f2.Parent = Lighting;
						$mc($mc(TweenService, "Create", f2, TweenInfo.new(0.15), { Brightness: 0 }), "Play");
						$mc(Debris, "AddItem", f2, 0.3);
					});
				}
			}
		};
		H.S_Charge = function (p) {
			let root = rootOf(p.Model);
			if (!$t(root)) {
				return;
			}
			let dur = math.max(0.2, ($n(p.Duration) ?? 0.6));
			let color = ($n(p.Color) ?? WHITE);
			let s = sizeOf(p.Model);
			let shell = fxPart({ Shape: Enum.PartType.Ball, Size: $mul(Vector3.one, ($add($mul(6, s), root.Size.Z))), CFrame: root.CFrame, Transparency: 1 });
			let e = emitter(shell, { Texture: TEX.Sparkle, Enabled: true, Rate: $mul(70, quality()), Color: ColorSequence.new(color), Size: NS(0, $mul(0.5, s), 1, 0.1), Lifetime: NumberRange.new(0.3, 0.45), Speed: NumberRange.new($mul(9, s), $mul(12, s)), Shape: Enum.ParticleEmitterShape.Sphere, ShapeStyle: Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut: Enum.ParticleEmitterShapeInOut.Inward, LightEmission: 1 });
			let glow = fxPart({ Shape: Enum.PartType.Ball, Size: Vector3.one, CFrame: root.CFrame, Color: color, Transparency: 1 });
			let pl = Instance.new("PointLight");
			pl.Color = color;
			pl.Range = $mul(12, s);
			pl.Brightness = 0;
			pl.Parent = glow;
			animate(dur, function (k) {
				if (!$t(root.Parent)) {
					return true;
				}
				shell.CFrame = root.CFrame;
				glow.CFrame = root.CFrame;
				glow.Size = $mul(Vector3.one, ($mul(root.Size.Z, ($add(0.6, $mul(0.9, k))))));
				glow.Transparency = $sub(0.9, $mul(0.45, k));
				pl.Brightness = $mul(4, k);
				return false;
			}, function () {
				e.Enabled = false;
				$mc(shell, "Destroy");
				flash(root.Position, (root.Size.Z * 1.2), color, 0.2);
				$mc(glow, "Destroy");
			});
			let feet = feetOf(p.Model);
			if ($t(feet)) {
				groundRing(feet, ((root.Size.Z * 1.6) + 3), 0.5, color, dur);
			}
		};
	};
}
