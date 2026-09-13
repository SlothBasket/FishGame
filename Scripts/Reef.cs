using Godot;
using System;
using System.Linq;

public partial class Reef : Node3D
{
    private FishPlayer _fish = null!;
    private Label _telemetry = null!;
    private Label _status = null!;
    private Label _score = null!;
    private float _time;
    private bool _capture;
    private bool _captured;
    private bool _feedingPreview;
    private bool _chargePreview;
    private bool _test;
    private int _testFrame;
    private int _failures;

    public override void _Ready()
    {
        _fish = GetNode<FishPlayer>("FishPlayer");
        _capture = OS.GetCmdlineUserArgs().Contains("--capture");
        _feedingPreview = OS.GetCmdlineUserArgs().Contains("--feeding-preview");
        _chargePreview = OS.GetCmdlineUserArgs().Contains("--charge-preview");
        _capture |= _feedingPreview || _chargePreview;
        _test = OS.GetCmdlineUserArgs().Contains("--self-test");
        BuildWater();
        BuildReef();
        BuildHud();
        if (!_test) AddChild(new BaitSchool());
        if (_test) { _fish.ExternalInput = true; RunMathTests(); }
        if (_capture) _fish.Pivot.Rotation = new Vector3(-0.13f, -0.45f, 0);
        if (_feedingPreview || _chargePreview)
        {
            _fish.ExternalInput = true;
            _fish.Pivot.Rotation = new Vector3(0, 0, 0);
            for (int i = 0; i < 3; i++) AddChild(new BaitActor { Kind = (BaitKind)i,
                Position = new Vector3(0, 6, 7 - i * 2), Driver = new ControlledBaitDriver() });
        }
    }

    private void BuildWater()
    {
        AddChild(new WorldEnvironment { Environment = new Godot.Environment
        {
            BackgroundMode = Godot.Environment.BGMode.Color,
            BackgroundColor = new Color("124555"),
            AmbientLightSource = Godot.Environment.AmbientSource.Color,
            AmbientLightColor = new Color("95b7bf"), AmbientLightEnergy = 0.35f,
            TonemapMode = Godot.Environment.ToneMapper.Filmic,
            FogEnabled = true, FogLightColor = new Color("154655"),
            FogLightEnergy = 0.5f, FogDensity = 0.025f,
        }});
        AddChild(new DirectionalLight3D { RotationDegrees = new Vector3(-58, -30, 0),
            LightColor = new Color("d0e4dc"), LightEnergy = 0.85f, ShadowEnabled = true });
        var water = Geometry.Material("428c97");
        water.Transparency = BaseMaterial3D.TransparencyEnum.Alpha;
        water.AlbedoColor = new Color(0.26f, 0.56f, 0.6f, 0.25f);
        AddChild(new MeshInstance3D { Position = new Vector3(0, 25, 0), Mesh = new PlaneMesh { Size = new Vector2(120, 120) }, MaterialOverride = water });
    }

    private void BuildReef()
    {
        var sand = Geometry.Material("617f78");
        Geometry.Box(this, "Seabed", new Vector3(0, -1, 0), new Vector3(120, 2, 120), sand);
        Geometry.Box(this, "SurfaceBoundary", new Vector3(0, 26, 0), new Vector3(120, 2, 120), sand, false);
        Geometry.Box(this, "North", new Vector3(0, 12, -60), new Vector3(120, 28, 2), sand, false);
        Geometry.Box(this, "South", new Vector3(0, 12, 60), new Vector3(120, 28, 2), sand, false);
        Geometry.Box(this, "East", new Vector3(60, 12, 0), new Vector3(2, 28, 120), sand, false);
        Geometry.Box(this, "West", new Vector3(-60, 12, 0), new Vector3(2, 28, 120), sand, false);
        var rng = new RandomNumberGenerator { Seed = 426 };
        var stone = Geometry.Material("42686b");
        var coral = Geometry.Material("c28f73");
        var weed = Geometry.Material("367e77");
        for (int i = 0; i < 65; i++)
        {
            float x = rng.RandfRange(-49, 49), z = rng.RandfRange(-49, 49);
            if (Mathf.Abs(x) < 5 && z > -32 && z < 20) continue;
            Vector3 size = new(rng.RandfRange(1, 3.5f), rng.RandfRange(0.8f, 3), rng.RandfRange(1, 3));
            var rock = new StaticBody3D { Position = new Vector3(x, size.Y * 0.35f, z) };
            AddChild(rock);
            Geometry.Sphere(rock, "Rock", Vector3.Zero, size, stone);
            rock.AddChild(new CollisionShape3D { Shape = new SphereShape3D { Radius = 1 }, Scale = size });
            // Exact matching convex shape avoids nonuniform scaling on physics shapes.
            var collision = rock.GetChild<CollisionShape3D>(1);
            collision.Scale = Vector3.One;
            var mesh = (SphereMesh)rock.GetChild<MeshInstance3D>(0).Mesh;
            var shape = mesh.CreateConvexShape();
            var points = shape.Points;
            for (int j = 0; j < points.Length; j++) points[j] *= size;
            shape.Points = points;
            collision.Shape = shape;
            for (int j = 0; j < 3; j++)
            {
                float height = rng.RandfRange(0.8f, 2.8f);
                Geometry.Sphere(this, "SeaGrass", new Vector3(x + size.X + j * 0.32f, height * 0.5f, z),
                    new Vector3(0.12f, height * 0.5f, 0.22f), weed);
            }
            if (i % 3 == 0) Geometry.Sphere(this, "Coral", new Vector3(x - 1, 0.5f, z + 2), new Vector3(1.1f, 0.7f, 0.85f), coral);
        }
        var ringMaterial = Geometry.Material("efc581", 0.45f);
        ringMaterial.EmissionEnabled = true;
        ringMaterial.Emission = new Color("896a35");
        Vector3[] centers = { new(0, 6, -3), new(0, 9, -18), new(9, 13, -29), new(22, 8, -30), new(29, 5, -15) };
        for (int i = 0; i < centers.Length; i++)
        {
            var ring = new Node3D { Name = "SwimHoop" + (i + 1), Position = centers[i] };
            AddChild(ring);
            ring.AddChild(new MeshInstance3D { Mesh = new TorusMesh { InnerRadius = 2.65f, OuterRadius = 2.85f, Rings = 48, RingSegments = 12 },
                RotationDegrees = new Vector3(90, 0, 0), MaterialOverride = ringMaterial });
            var body = new StaticBody3D(); ring.AddChild(body);
            for (int segment = 0; segment < 32; segment++)
            {
                float a = segment * Mathf.Tau / 32;
                body.AddChild(new CollisionShape3D { Position = new Vector3(Mathf.Cos(a), Mathf.Sin(a), 0) * 2.75f,
                    Shape = new SphereShape3D { Radius = 0.29f } });
            }
        }
        // Suspended specks provide a close-range reference for speed and depth.
        var particleMat = Geometry.Material("91c5bc");
        for (int i = 0; i < 160; i++) Geometry.Sphere(this, "SuspendedParticle",
            new Vector3(rng.RandfRange(-40, 40), rng.RandfRange(2, 24), rng.RandfRange(-45, 35)),
            Vector3.One * rng.RandfRange(0.015f, 0.045f), particleMat);
    }

    private void BuildHud()
    {
        var layer = new CanvasLayer(); AddChild(layer);
        var root = new Control { MouseFilter = Control.MouseFilterEnum.Ignore };
        layer.AddChild(root); root.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
        Label Text(string value, int size, Color color, Vector2 position)
        {
            var label = new Label { Text = value, Position = position, MouseFilter = Control.MouseFilterEnum.Ignore };
            label.AddThemeFontSizeOverride("font_size", size);
            label.AddThemeColorOverride("font_color", color); root.AddChild(label); return label;
        }
        Color cream = new("e6efe3"), muted = new("a4c8c8");
        Text("P E L A G I C", 30, cream, new Vector2(38, 30));
        Text("02  /  THE FEEDING GROUNDS", 13, new Color("e7c184"), new Vector2(40, 75));
        Text("MINNOW   +1     /     SHRIMP   +2     /     SQUID   +3", 13, muted, new Vector2(40, 102));
        _score = Text("", 20, cream, Vector2.Zero);
        _score.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.TopRight);
        _score.OffsetLeft = -300; _score.OffsetTop = 92; _score.OffsetRight = -38; _score.OffsetBottom = 155;
        _score.HorizontalAlignment = HorizontalAlignment.Right;
        var topRight = Text("FEED  /  GROW  /  REPEAT\nSHALLOW WATER  /  DAY", 13, muted, Vector2.Zero);
        topRight.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.TopRight);
        topRight.OffsetLeft = -282; topRight.OffsetTop = 36; topRight.OffsetRight = -38; topRight.OffsetBottom = 86;
        topRight.HorizontalAlignment = HorizontalAlignment.Right;
        var hint = Text("Hold LMB. Line it up. Release.", 24, cream, Vector2.Zero);
        hint.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.BottomLeft);
        hint.OffsetLeft = 40; hint.OffsetTop = -125; hint.OffsetBottom = -85; hint.OffsetRight = 440;
        var controls = Text("WASD  swim     MOUSE  look     SHIFT  boost\nSPACE / CTRL  rise / dive     R  reset     ESC  release cursor", 15, muted, Vector2.Zero);
        controls.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.BottomLeft);
        controls.OffsetLeft = 40; controls.OffsetTop = -83; controls.OffsetBottom = -25; controls.OffsetRight = 640;
        _telemetry = Text("", 20, cream, Vector2.Zero);
        _telemetry.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.BottomRight);
        _telemetry.OffsetLeft = -260; _telemetry.OffsetTop = -103; _telemetry.OffsetRight = -40; _telemetry.OffsetBottom = -43;
        _telemetry.HorizontalAlignment = HorizontalAlignment.Right;
        _status = Text("", 14, new Color("e7c184"), Vector2.Zero);
        _status.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.CenterTop);
        _status.OffsetLeft = -200; _status.OffsetTop = 35; _status.OffsetRight = 200; _status.OffsetBottom = 65;
        _status.HorizontalAlignment = HorizontalAlignment.Center;
        var crosshair = Text("·", 32, new Color(0.9f, 0.97f, 0.91f, 0.65f), Vector2.Zero);
        crosshair.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.Center);
        crosshair.OffsetLeft = -5; crosshair.OffsetTop = -23; crosshair.OffsetRight = 10; crosshair.OffsetBottom = 23;
        crosshair.Visible = false;
        var feedingHud = new FeedingHud { Fish = _fish }; root.AddChild(feedingHud);
        feedingHud.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
    }

    public override async void _Process(double delta)
    {
        _time += (float)delta;
        if (_feedingPreview || _chargePreview)
            _fish.Command = new FishInput(Vector3.Zero, false, _time < 1.5f || _chargePreview, Vector3.Forward);
        _telemetry.Text = $"{_fish.Velocity.Length():0.0} m/s\n{25 - _fish.Position.Y:0.0} m depth";
        _score.Text = $"{_fish.Food} FOOD   /   {_fish.BaitEaten} EATEN\n{_fish.SizeMultiplier:0.00}× SIZE";
        _status.Text = Input.MouseMode != Input.MouseModeEnum.Captured ? "CLICK TO SWIM" : _fish.IsDashing ? "F E E D I N G   L U N G E" : _fish.Boosting ? "B O O S T" : "";
        if (_capture && !_captured && _time > (_feedingPreview ? 1.85f : 2))
        {
            _captured = true;
            await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
            string filename = _feedingPreview ? "FishGame-feeding.png" : _chargePreview ? "FishGame-charge.png" : "FishGame-preview.png";
            GetViewport().GetTexture().GetImage().SavePng(ProjectSettings.GlobalizePath("res://../" + filename));
            GetTree().Quit();
        }
    }

    private void Check(bool condition, string label)
    {
        if (!condition) _failures++;
        GD.Print((condition ? "PASS " : "FAIL ") + label);
    }

    private void RunMathTests()
    {
        Vector3 Simulate(int hz, FishInput input)
        {
            Vector3 v = Vector3.Zero;
            for (int i = 0; i < hz * 3; i++) v = FishMovement.NextVelocity(v, input, 8, 1.85f, 12, 4, 1f / hz);
            return v;
        }
        Check(Mathf.Abs(Simulate(60, new FishInput(Vector3.Forward, false)).Length() - 8) < 0.01f, "Cruise speed");
        Check(Mathf.Abs(Simulate(60, new FishInput(Vector3.Forward, true)).Length() - 14.8f) < 0.01f, "Boost speed");
        Check(Simulate(60, new FishInput(new Vector3(1, 1, 1), false)).Length() <= 8.001f, "Diagonal speed capped");
        Check(Simulate(30, new FishInput(Vector3.Forward, false)).DistanceTo(Simulate(120, new FishInput(Vector3.Forward, false))) < 0.001f, "Frame-rate independent speed");
        Check(FishMovement.NextVelocity(Vector3.Forward * 8, new FishInput(Vector3.Zero, false), 8, 1.85f, 12, 4, 0.1f).Length() < 8, "Water drag");
        _fish.Pivot.Rotation = new Vector3(0.5f, 0.6f, 0);
        var local = _fish.CameraRelativeInput(new Vector2(0, -1), 0, false);
        Check(local.Direction.Y > 0.4f && local.Direction.X < -0.4f, "Forward follows camera pitch and yaw");
        _fish.ResetFish();
        _fish.Command = new FishInput(Vector3.Down, false);
    }

    public override void _PhysicsProcess(double delta)
    {
        if (!_test) return;
        _testFrame++;
        if (_testFrame == 180)
        {
            Check(_fish.Position.Y >= 0.64f && _fish.Position.Y < 0.8f, "Fish collides with seabed");
            Check(Mathf.Abs(_fish.Visual.Rotation.Z) < 0.001f, "No fish roll");
            _fish.Command = new FishInput(Vector3.Up, true);
        }
        if (_testFrame == 420)
        {
            Check(_fish.Position.Y <= 24.36f && _fish.Position.Y > 24, "Fish remains under water surface");
            _fish.ResetFish();
            Check(_fish.Position.DistanceTo(new Vector3(0, 6, 12)) < 0.001f && _fish.Velocity == Vector3.Zero, "Reset restores spawn and clears momentum");
            _fish.Command = new FishInput(Vector3.Zero, false);
            _fish.Position = new Vector3(57.5f, 12, 12);
            _fish.Pivot.Rotation = new Vector3(0, Mathf.Pi / 2, 0);
        }
        if (_testFrame == 440)
        {
            Check(_fish.GetNode<SpringArm3D>("CameraPivot/SpringArm3D").GetHitLength() < 2,
                "Camera retracts at wall");
            _test = false;
            AddChild(new FeedingChecks { Fish = _fish, Failures = _failures });
        }
    }
}
