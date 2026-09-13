using Godot;

public enum BaitKind { Minnow, Shrimp, Squid }
public enum BaitSource { Live, Fisherman }

// Identical presentation and motor for live prey and future fisherman-controlled lures.
// A command contains motion intent, never a visual flag exposing its source.
public readonly record struct BaitCommand(Vector3 Direction, float Effort, float Twitch = 0);

public interface IBaitDriver
{
    BaitCommand Sample(BaitActor bait, float time);
}

public sealed class LiveBaitDriver(Vector3 home, float phase) : IBaitDriver
{
    public BaitCommand Sample(BaitActor bait, float time)
    {
        float t = time + phase;
        Vector3 target;
        float effort, twitch = 0;
        switch (bait.Kind)
        {
            case BaitKind.Shrimp:
                target = home + new Vector3(Mathf.Sin(t * 0.6f) * 1.4f, Mathf.Sin(t * 1.2f) * 0.5f, Mathf.Cos(t * 0.7f));
                twitch = Mathf.Pow(Mathf.Max(0, Mathf.Sin(t * 3.8f)), 10);
                effort = 0.12f + twitch * 0.88f;
                break;
            case BaitKind.Squid:
                target = home + new Vector3(Mathf.Sin(t * 0.45f) * 2, Mathf.Sin(t * 0.9f) * 1.3f, Mathf.Cos(t * 0.45f) * 2);
                twitch = Mathf.Pow(Mathf.Max(0, Mathf.Sin(t * 2.6f)), 4);
                effort = 0.18f + twitch * 0.82f;
                break;
            default:
                target = home + new Vector3(Mathf.Sin(t * 0.65f) * 2.3f, Mathf.Sin(t * 0.8f) * 0.45f, Mathf.Cos(t * 0.65f) * 2.3f);
                effort = 0.65f;
                break;
        }
        Vector3 direction = target - bait.GlobalPosition;
        return new BaitCommand(direction.LimitLength(), effort, twitch);
    }
}

// Future rod input/network code feeds this driver. It uses exactly the same actor,
// speed limits, pose, tail/leg/tentacle animation, hit detection, and bite callback.
public sealed class ControlledBaitDriver : IBaitDriver
{
    public BaitCommand Command { get; set; }
    public BaitCommand Sample(BaitActor bait, float time) => Command;
}
