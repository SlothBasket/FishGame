using Godot;
using System;

public partial class BaitActor : CharacterBody3D
{
    public BaitKind Kind { get; set; }
    public BaitSource Source { get; set; } = BaitSource.Live;
    public IBaitDriver? Driver { get; set; }
    public bool Claimed { get; private set; }
    public float HitRadius => Kind == BaitKind.Squid ? 0.42f : 0.28f;
    public int Nutrition => Kind switch { BaitKind.Minnow => 1, BaitKind.Shrimp => 2, _ => 3 };
    public string DisplayName => Kind.ToString();
    public BaitVisual Visual { get; private set; } = null!;
    public event Action<BaitActor, FishPlayer>? Bitten;
    private FishPlayer? _eater;
    private float _time;
    private float _swallow;

    public override void _Ready()
    {
        CollisionLayer = 4; CollisionMask = 1;
        MotionMode = MotionModeEnum.Floating;
        AddChild(new CollisionShape3D { Shape = new SphereShape3D { Radius = HitRadius } });
        Visual = new BaitVisual { Kind = Kind }; AddChild(Visual);
        AddToGroup("bait");
        Driver ??= new LiveBaitDriver(GlobalPosition, GetIndex() * 0.71f);
    }

    public override void _PhysicsProcess(double delta)
    {
        if (Claimed) return;
        float dt = (float)delta;
        _time += dt;
        BaitCommand command = Driver!.Sample(this, _time);
        float speed = Kind switch { BaitKind.Minnow => 2.1f, BaitKind.Shrimp => 2.6f, _ => 2.3f };
        Vector3 target = command.Direction.LimitLength() * Mathf.Clamp(command.Effort, 0, 1) * speed;
        Velocity = Velocity.MoveToward(target, dt * (Kind == BaitKind.Shrimp ? 13 : 5));
        MoveAndSlide();
        if (Velocity.LengthSquared() > 0.005f)
        {
            Vector3 direction = Velocity.Normalized();
            Vector3 angles = Visual.Rotation;
            float blend = 1 - Mathf.Exp(-7 * dt);
            Visual.Rotation = new Vector3(Mathf.LerpAngle(angles.X, Mathf.Asin(Mathf.Clamp(direction.Y, -1, 1)), blend),
                Mathf.LerpAngle(angles.Y, Mathf.Atan2(-direction.X, -direction.Z), blend), 0);
        }
        Visual.Speed = Velocity.Length();
        Visual.Twitch = Mathf.Clamp(command.Twitch, 0, 1);
    }

    // Single-consumer gate. A future server should own this call and replicate the result.
    public bool TryBite(FishPlayer eater)
    {
        if (Claimed) return false;
        Claimed = true; _eater = eater; Velocity = Vector3.Zero;
        CollisionLayer = 0; CollisionMask = 0;
        RemoveFromGroup("bait");
        SetPhysicsProcess(false);
        if (Source == BaitSource.Live) eater.AwardFood(this);
        Bitten?.Invoke(this, eater); // Fisherman bait triggers this too, without awarding food.
        return true;
    }

    public override void _Process(double delta)
    {
        if (!Claimed) return;
        _swallow += (float)delta;
        if (GodotObject.IsInstanceValid(_eater))
            GlobalPosition = GlobalPosition.Lerp(_eater!.MouthPosition, 1 - Mathf.Exp(-22 * (float)delta));
        Visual.Scale = Vector3.One * Mathf.Max(0.01f, 1 - _swallow / 0.22f);
        if (_swallow >= 0.22f) QueueFree();
    }
}
