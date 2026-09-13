using Godot;
using System.Collections.Generic;

public partial class BaitSchool : Node3D
{
    public float RespawnDelay { get; set; } = 8f;
    private readonly List<(float Remaining, BaitKind Kind, Vector3 Home, float Phase)> _respawns = new();

    public override void _Ready()
    {
        var rng = new RandomNumberGenerator { Seed = 9317 };
        Vector3[] homes = { new(-1.5f, 6.3f, 3), new(2.5f, 5.3f, -4), new(0, 9, -12),
            new(11, 11, -23), new(19, 5, -20), new(26, 10, -12) };
        for (int group = 0; group < homes.Length; group++)
        {
            BaitKind kind = (BaitKind)(group % 3);
            int count = kind == BaitKind.Minnow ? 7 : 4;
            for (int i = 0; i < count; i++)
            {
                Vector3 home = homes[group] + new Vector3(rng.RandfRange(-1.5f, 1.5f), rng.RandfRange(-0.6f, 0.6f), rng.RandfRange(-1.5f, 1.5f));
                Spawn(kind, home, group * 1.7f + i * 0.24f);
            }
        }
    }

    private void Spawn(BaitKind kind, Vector3 home, float phase)
    {
        var bait = new BaitActor { Kind = kind, Position = home, Driver = new LiveBaitDriver(home, phase) };
        bait.Bitten += (_, _) => _respawns.Add((RespawnDelay, kind, home, phase));
        AddChild(bait);
    }

    public override void _Process(double delta)
    {
        for (int i = _respawns.Count - 1; i >= 0; i--)
        {
            var entry = _respawns[i];
            entry.Remaining -= (float)delta;
            if (entry.Remaining <= 0) { _respawns.RemoveAt(i); Spawn(entry.Kind, entry.Home, entry.Phase); }
            else _respawns[i] = entry;
        }
    }
}
