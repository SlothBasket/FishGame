using Godot;
using System;

public partial class FishPlayer
{
    public bool IsCharging { get; private set; }
    public bool IsDashing => _dashRemaining > 0;
    public float ChargeFraction => Mathf.Clamp(_chargeTime / Mathf.Max(0.01f, FullChargeTime), 0, 1);
    public float CooldownRemaining { get; private set; }
    public int Food { get; private set; }
    public int BaitEaten { get; private set; }
    public float SizeMultiplier => 1 + Mathf.Min(Food, 60) * 0.01f;
    public Vector3 MouthPosition => GlobalPosition - Visual.GlobalBasis.Z.Normalized() * (1.25f * SizeMultiplier);
    public string LastMeal { get; private set; } = "";
    public float MealNoticeTime { get; private set; }
    public float LastLungeDistance { get; private set; }
    public event Action<BaitActor>? AteBait;
    private bool _wasBiteHeld;
    private bool _suppressBiteUntilRelease;
    private float _chargeTime;
    private float _dashRemaining;
    private Vector3 _dashDirection;
    private float _biteFlash;
    private float _trailTime;

    private void UpdateAttack(FishInput input, float dt)
    {
        CooldownRemaining = Mathf.Max(0, CooldownRemaining - dt);
        MealNoticeTime = Mathf.Max(0, MealNoticeTime - dt);
        _biteFlash = Mathf.Max(0, _biteFlash - dt);
        if (input.CancelBite) { CancelAttack(); return; }
        if (!IsDashing && CooldownRemaining <= 0 && input.BiteHeld && !_wasBiteHeld)
        { IsCharging = true; _chargeTime = 0; }
        if (IsCharging)
        {
            if (input.BiteHeld) _chargeTime = Mathf.Min(Mathf.Max(0.01f, FullChargeTime), _chargeTime + dt);
            else
            {
                LastLungeDistance = Mathf.Lerp(MinimumLungeDistance, MaximumLungeDistance, ChargeFraction);
                _dashRemaining = Mathf.Max(0.1f, LastLungeDistance);
                Vector3 aim = input.AimDirection;
                _dashDirection = aim.LengthSquared() > 0.001f ? aim.Normalized() : -Pivot.GlobalBasis.Z.Normalized();
                IsCharging = false; _chargeTime = 0; _trailTime = 0;
            }
        }
        _wasBiteHeld = input.BiteHeld;
    }

    private void AdvanceDash(float dt)
    {
        Vector3 start = GlobalPosition;
        float step = Mathf.Min(_dashRemaining, Mathf.Max(1, LungeSpeed) * dt);
        Velocity = _dashDirection * Mathf.Max(1, LungeSpeed);
        var collision = MoveAndCollide(_dashDirection * step);
        SweepBite(start, GlobalPosition);
        _dashRemaining -= step;
        _trailTime -= dt;
        if (_trailTime <= 0)
        {
            SpawnBurst(GlobalPosition + _dashDirection * -0.8f, new Color("b7e8e2"), 3);
            _trailTime = 0.045f;
        }
        if (collision != null || _dashRemaining <= 0.001f)
        {
            _dashRemaining = 0;
            CooldownRemaining = BiteCooldown;
            Velocity = collision != null ? Vector3.Zero : _dashDirection * SwimSpeed;
            _biteFlash = 0.16f;
        }
    }

    // Sweep the actual travelled segment, not the requested endpoint. This catches
    // small bait between physics ticks; occlusion prevents bites through terrain.
    public int SweepBite(Vector3 from, Vector3 to)
    {
        if (!IsDashing) return 0;
        int count = 0;
        foreach (Node node in GetTree().GetNodesInGroup("bait"))
        {
            if (node is not BaitActor bait || bait.Claimed) continue;
            Vector3 nearest = ClosestPoint(from, to, bait.GlobalPosition);
            float radius = 0.9f * SizeMultiplier + bait.HitRadius;
            if (nearest.DistanceSquaredTo(bait.GlobalPosition) > radius * radius) continue;
            var ray = PhysicsRayQueryParameters3D.Create(nearest, bait.GlobalPosition, 1);
            if (GetWorld3D().DirectSpaceState.IntersectRay(ray).Count != 0) continue;
            if (bait.TryBite(this)) count++;
        }
        return count;
    }

    public static Vector3 ClosestPoint(Vector3 from, Vector3 to, Vector3 point)
    {
        Vector3 segment = to - from;
        float lengthSquared = segment.LengthSquared();
        if (lengthSquared < 0.000001f) return from;
        return from + segment * Mathf.Clamp((point - from).Dot(segment) / lengthSquared, 0, 1);
    }

    public void AwardFood(BaitActor bait)
    {
        Food += bait.Nutrition; BaitEaten++;
        LastMeal = $"{bait.DisplayName.ToUpperInvariant()}  +{bait.Nutrition}";
        MealNoticeTime = 1.8f; _biteFlash = 0.25f;
        if (GetNode<CollisionShape3D>("CollisionShape3D").Shape is SphereShape3D shape)
            shape.Radius = 0.65f * SizeMultiplier;
        SpawnBurst(bait.GlobalPosition, new Color("f4d79d"), 10);
        AteBait?.Invoke(bait);
    }

    private void SpawnBurst(Vector3 position, Color color, int count)
    {
        GetParent().AddChild(new FeedingBurst { Position = position, Tint = color, Count = count });
    }

    public void CancelAttack()
    {
        IsCharging = false; _chargeTime = 0;
        if (IsDashing) Velocity = Vector3.Zero;
        _dashRemaining = 0; _wasBiteHeld = false;
        _suppressBiteUntilRelease = true;
    }
}
