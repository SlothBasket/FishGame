using Godot;

// World-space intent: a future input provider can supply this without owning a camera.
public readonly record struct FishInput(Vector3 Direction, bool Boost, bool BiteHeld = false,
    Vector3 AimDirection = default, bool CancelBite = false);

public static class FishMovement
{
    public static Vector3 NextVelocity(Vector3 current, FishInput input, float speed,
        float boostMultiplier, float acceleration, float drag, float delta)
    {
        Vector3 direction = input.Direction.LimitLength();
        Vector3 target = direction * speed * (input.Boost ? boostMultiplier : 1f);
        return current.MoveToward(target, (direction.LengthSquared() > 0.001f ? acceleration : drag) * delta);
    }
}
