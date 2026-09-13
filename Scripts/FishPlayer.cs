using Godot;

public partial class FishPlayer : CharacterBody3D
{
    [Export] public float SwimSpeed { get; set; } = 8f;
    [Export] public float BoostMultiplier { get; set; } = 1.85f;
    [Export] public float Acceleration { get; set; } = 12f;
    [Export] public float WaterDrag { get; set; } = 4f;
    [Export] public float TurnSpeed { get; set; } = 5f;
    [Export] public float MouseSensitivity { get; set; } = 0.0025f;
    [Export] public float FullChargeTime { get; set; } = 1.4f;
    [Export] public float MinimumLungeDistance { get; set; } = 3f;
    [Export] public float MaximumLungeDistance { get; set; } = 15f;
    [Export] public float LungeSpeed { get; set; } = 26f;
    [Export] public float BiteCooldown { get; set; } = 0.45f;
    public bool ExternalInput { get; set; }
    public FishInput Command { get; set; }
    public bool Boosting { get; private set; }
    public Node3D Pivot { get; private set; } = null!;
    public FishVisual Visual { get; private set; } = null!;
    private Camera3D _camera = null!;
    private float _yaw;
    private float _pitch = -0.08f;
    private Vector3 _spawn;

    public override void _Ready()
    {
        _spawn = Position;
        Pivot = GetNode<Node3D>("CameraPivot");
        Visual = GetNode<FishVisual>("Visual");
        _camera = GetNode<Camera3D>("CameraPivot/SpringArm3D/Camera3D");
        GetNode<SpringArm3D>("CameraPivot/SpringArm3D").AddExcludedObject(GetRid());
        Map("forward", Key.W); Map("back", Key.S);
        Map("left", Key.A); Map("right", Key.D);
        Map("rise", Key.Space); Map("dive", Key.Ctrl);
        Map("boost", Key.Shift); Map("reset", Key.R);
        if (!InputMap.HasAction("bite"))
        {
            InputMap.AddAction("bite");
            InputMap.ActionAddEvent("bite", new InputEventMouseButton { ButtonIndex = MouseButton.Left });
        }
        GetNode<CollisionShape3D>("CollisionShape3D").Shape = GetNode<CollisionShape3D>("CollisionShape3D").Shape.Duplicate() as Shape3D;
        Input.MouseMode = Input.MouseModeEnum.Captured;
        Pivot.Rotation = new Vector3(_pitch, _yaw, 0);
    }

    private static void Map(string action, Key key)
    {
        if (InputMap.HasAction(action)) return;
        InputMap.AddAction(action);
        InputMap.ActionAddEvent(action, new InputEventKey { PhysicalKeycode = key });
    }

    public override void _UnhandledInput(InputEvent ev)
    {
        if (ev is InputEventKey { Pressed: true, Echo: false, Keycode: Key.Escape })
        {
            CancelAttack();
            Input.MouseMode = Input.MouseMode == Input.MouseModeEnum.Captured
                ? Input.MouseModeEnum.Visible : Input.MouseModeEnum.Captured;
        }
        if (ev is InputEventMouseButton { Pressed: true, ButtonIndex: MouseButton.Left }
            && Input.MouseMode != Input.MouseModeEnum.Captured)
        {
            _suppressBiteUntilRelease = true;
            Input.MouseMode = Input.MouseModeEnum.Captured;
        }
        if (ev is InputEventMouseMotion motion && Input.MouseMode == Input.MouseModeEnum.Captured)
        {
            _yaw -= motion.Relative.X * MouseSensitivity;
            _pitch = Mathf.Clamp(_pitch - motion.Relative.Y * MouseSensitivity, -1.35f, 1.35f);
            Pivot.Rotation = new Vector3(_pitch, _yaw, 0);
        }
        if (ev.IsActionPressed("reset")) ResetFish();
    }

    public FishInput ReadLocalInput()
    {
        if (Input.MouseMode != Input.MouseModeEnum.Captured) return new FishInput(Vector3.Zero, false, CancelBite: true);
        if (!Input.IsActionPressed("bite")) _suppressBiteUntilRelease = false;
        Vector2 axes = Input.GetVector("left", "right", "forward", "back");
        return CameraRelativeInput(axes, Input.GetAxis("dive", "rise"), Input.IsActionPressed("boost")) with
        { BiteHeld = Input.IsActionPressed("bite") && !_suppressBiteUntilRelease, AimDirection = AimThroughCrosshair() };
    }

    public Vector3 AimThroughCrosshair()
    {
        Vector3 origin = _camera.GlobalPosition;
        Vector3 end = origin - _camera.GlobalBasis.Z * 100;
        var ray = PhysicsRayQueryParameters3D.Create(origin, end, 1 | 4);
        var hit = GetWorld3D().DirectSpaceState.IntersectRay(ray);
        Vector3 target = hit.Count > 0 ? (Vector3)hit["position"] : end;
        Vector3 direction = target - GlobalPosition;
        // Avoid lunging backward when the camera retracts into a nearby obstacle.
        return direction.Dot(-Pivot.GlobalBasis.Z) > 0.1f ? direction.Normalized() : -Pivot.GlobalBasis.Z.Normalized();
    }

    public FishInput CameraRelativeInput(Vector2 axes, float vertical, bool boost)
    {
        Vector3 direction = Pivot.GlobalBasis * new Vector3(axes.X, 0, axes.Y);
        direction += Vector3.Up * vertical;
        return new FishInput(direction.LimitLength(), boost);
    }

    public override void _PhysicsProcess(double delta)
    {
        float dt = (float)delta;
        FishInput input = ExternalInput ? Command : ReadLocalInput();
        UpdateAttack(input, dt);
        Boosting = input.Boost && input.Direction.LengthSquared() > 0.01f && !IsCharging && !IsDashing;
        if (IsDashing) AdvanceDash(dt);
        else
        {
            var swim = input with { Boost = Boosting };
            Velocity = FishMovement.NextVelocity(Velocity, swim, SwimSpeed * (IsCharging ? 0.4f : 1), BoostMultiplier, Acceleration, WaterDrag, dt);
            MoveAndSlide();
        }
        if (Velocity.LengthSquared() > 0.05f)
        {
            Vector3 direction = Velocity.Normalized();
            float yaw = Mathf.Atan2(-direction.X, -direction.Z);
            float pitch = Mathf.Asin(Mathf.Clamp(direction.Y, -1, 1));
            float blend = 1f - Mathf.Exp(-(IsDashing ? 24 : TurnSpeed) * dt);
            Visual.Rotation = new Vector3(Mathf.LerpAngle(Visual.Rotation.X, pitch, blend),
                Mathf.LerpAngle(Visual.Rotation.Y, yaw, blend), 0);
        }
        Visual.SwimIntensity = Velocity.Length() / SwimSpeed;
        Visual.Gape = IsDashing ? 1 : IsCharging ? 0.25f + ChargeFraction * 0.45f : Mathf.Clamp(_biteFlash * 4, 0, 1);
        Visual.Scale = Vector3.One * SizeMultiplier * new Vector3(1 + ChargeFraction * 0.04f, 1 + ChargeFraction * 0.06f, 1 - ChargeFraction * 0.08f);
        _camera.Fov = Mathf.Lerp(_camera.Fov, IsDashing ? 88 : IsCharging ? 67 : Boosting ? 80 : 72, 1 - Mathf.Exp(-6 * dt));
    }

    public void ResetFish()
    {
        CancelAttack();
        CooldownRemaining = 0;
        Position = _spawn;
        Velocity = Vector3.Zero;
        Visual.Rotation = Vector3.Zero;
        _yaw = 0; _pitch = -0.08f;
        Pivot.Rotation = new Vector3(_pitch, _yaw, 0);
    }

    public override void _Notification(int what)
    {
        if (what == NotificationApplicationFocusOut)
        {
            CancelAttack();
            Input.MouseMode = Input.MouseModeEnum.Visible;
        }
    }
}
