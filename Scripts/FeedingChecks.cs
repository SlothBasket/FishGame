using Godot;
using System;
using System.Threading.Tasks;

// End-to-end physics checks; run by --self-test after the original controller checks.
public partial class FeedingChecks : Node
{
    public FishPlayer Fish { get; set; } = null!;
    public int Failures { get; set; }
    private readonly Vector3 _origin = new(-25, 15, 25);

    private void Check(bool condition, string label)
    {
        if (!condition) Failures++;
        GD.Print((condition ? "PASS " : "FAIL ") + label);
    }
    private async Task Frames(int count)
    {
        for (int i = 0; i < count; i++) await ToSignal(GetTree(), SceneTree.SignalName.PhysicsFrame);
    }
    private void Reset()
    {
        Fish.ResetFish(); Fish.Position = _origin;
        Fish.Pivot.Rotation = Vector3.Zero;
        Fish.Command = new FishInput(Vector3.Zero, false, AimDirection: Vector3.Forward);
    }
    private BaitActor Bait(BaitKind kind, Vector3 position, BaitSource source = BaitSource.Live)
    {
        var actor = new BaitActor { Kind = kind, Position = position, Source = source, Driver = new ControlledBaitDriver() };
        GetParent().AddChild(actor); return actor;
    }
    private async Task<float> Dash(int chargeFrames)
    {
        Fish.Command = new FishInput(Vector3.Zero, false, true, Vector3.Forward);
        await Frames(chargeFrames + 1);
        Vector3 start = Fish.Position;
        Fish.Command = new FishInput(Vector3.Zero, false, false, Vector3.Forward);
        await Frames(2);
        int timeout = 180;
        while (Fish.IsDashing && timeout-- > 0) await Frames(1);
        Check(timeout > 0, "Dash terminates");
        return start.DistanceTo(Fish.Position);
    }

    public override async void _Ready()
    {
        try
        {
            Reset();
            var touching = Bait(BaitKind.Minnow, _origin);
            await Frames(3);
            Check(!touching.Claimed && Fish.BaitEaten == 0, "Ordinary swimming does not eat bait");
            touching.QueueFree(); await Frames(2);

            Reset(); float shortDistance = await Dash(1);
            Check(shortDistance >= 3 && shortDistance < 3.6f, "Tap produces a short bite lunge");
            Reset(); float longDistance = await Dash(100);
            Check(longDistance > 14.8f && longDistance < 15.2f && longDistance > shortDistance * 3,
                "Long hold caps at a 15 m lunge");

            Reset();
            Fish.Command = new FishInput(Vector3.Zero, false, true, Vector3.Forward);
            await Frames(20);
            Fish.Command = new FishInput(Vector3.Zero, false, CancelBite: true);
            await Frames(3);
            Check(!Fish.IsCharging && !Fish.IsDashing && Fish.Position.DistanceTo(_origin) < 0.01f,
                "Cancel charging does not fire a dash");

            Reset();
            for (int i = 0; i < 3; i++) Bait((BaitKind)i, _origin + Vector3.Forward * (3 + i * 3));
            int foodBefore = Fish.Food;
            await Dash(90);
            Check(Fish.BaitEaten == 3 && Fish.Food - foodBefore == 6, "One dash eats multiple bait types and awards their nutrition");
            Check(Fish.SizeMultiplier > 1, "Food grows the fish");
            await Frames(20);
            Check(GetTree().GetNodesInGroup("bait").Count == 0, "Consumed bait leaves the edible set");

            Reset();
            var single = Bait(BaitKind.Shrimp, _origin + Vector3.Right * 4);
            foodBefore = Fish.Food;
            Check(single.TryBite(Fish) && !single.TryBite(Fish) && Fish.Food - foodBefore == 2,
                "A bait can only award food once");

            Reset();
            var fake = Bait(BaitKind.Minnow, _origin + Vector3.Forward * 3, BaitSource.Fisherman);
            bool fishermanNotified = false;
            fake.Bitten += (_, _) => fishermanNotified = true;
            foodBefore = Fish.Food;
            await Dash(20);
            Check(fishermanNotified && Fish.Food == foodBefore, "Fisherman bait shares bite detection but signals the fisherman without nutrition");

            Reset();
            var live = Bait(BaitKind.Squid, new Vector3(-38, 15, 20));
            var controlled = Bait(BaitKind.Squid, new Vector3(-34, 15, 20), BaitSource.Fisherman);
            var sameCommand = new BaitCommand(Vector3.Forward, 0.7f, 0.6f);
            ((ControlledBaitDriver)live.Driver!).Command = sameCommand;
            ((ControlledBaitDriver)controlled.Driver!).Command = sameCommand;
            Vector3 liveStart = live.Position, controlledStart = controlled.Position;
            await Frames(35);
            Check((live.Position - liveStart).DistanceTo(controlled.Position - controlledStart) < 0.001f
                && live.Visual.GetChildCount() == controlled.Visual.GetChildCount()
                && live.Visual.Twitch == controlled.Visual.Twitch,
                "Live and fisherman bait use identical motion and presentation for identical commands");
            live.QueueFree(); controlled.QueueFree();

            Reset();
            var barrier = new Node3D(); GetParent().AddChild(barrier);
            Geometry.Box(barrier, "BiteOcclusionTestWall", _origin + Vector3.Forward * 4,
                new Vector3(12, 12, 0.25f), Geometry.Material("334455"));
            var hidden = Bait(BaitKind.Squid, _origin + Vector3.Forward * 4.6f);
            await Frames(2); foodBefore = Fish.Food;
            float blockedDistance = await Dash(90);
            Check(blockedDistance < 3.5f && Fish.Food == foodBefore && !hidden.Claimed,
                "Walls stop lunges and block eating through cover");
            hidden.QueueFree(); barrier.QueueFree(); await Frames(3);

            Reset();
            var tiny = Bait(BaitKind.Minnow, _origin + Vector3.Forward * 2.2f);
            Fish.LungeSpeed = 300;
            foodBefore = Fish.Food;
            await Dash(1);
            Check(Fish.Food == foodBefore + 1, "Swept bite catches bait between high-speed physics steps");
            Fish.LungeSpeed = 26;
            Check(FishPlayer.ClosestPoint(Vector3.Zero, Vector3.Zero, Vector3.One) == Vector3.Zero,
                "Stationary bite sweep remains finite");
            await Frames(20);
            Reset();
            var school = new BaitSchool { RespawnDelay = 0.12f }; GetParent().AddChild(school);
            int population = GetTree().GetNodesInGroup("bait").Count;
            var meal = (BaitActor)GetTree().GetNodesInGroup("bait")[0];
            meal.TryBite(Fish);
            await Frames(30);
            Check(GetTree().GetNodesInGroup("bait").Count == population, "Eaten bait respawns to replenish the feeding grounds");
            GD.Print($"SELF-TEST COMPLETE: {Failures} failures");
            GetTree().Quit(Failures == 0 ? 0 : 1);
        }
        catch (Exception error)
        {
            GD.PrintErr(error); GetTree().Quit(1);
        }
    }
}
