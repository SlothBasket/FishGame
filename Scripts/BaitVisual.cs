using Godot;
using System.Collections.Generic;

// Source-agnostic visuals: a lure of this kind has no special color, label, or animation.
public partial class BaitVisual : Node3D
{
    public BaitKind Kind { get; set; }
    public float Speed { get; set; }
    public float Twitch { get; set; }
    private readonly List<Node3D> _appendages = new();
    private Node3D _body = null!;
    private float _phase;

    public override void _Ready()
    {
        _body = new Node3D(); AddChild(_body);
        var dark = Geometry.Material("112e3b");
        if (Kind == BaitKind.Minnow)
        {
            var silver = Geometry.Material("ccdfd3", 0.45f);
            var blue = Geometry.Material("537f9a", 0.3f);
            Geometry.Sphere(_body, "SilverBody", Vector3.Zero, new Vector3(0.16f, 0.22f, 0.55f), silver);
            Geometry.Sphere(_body, "BlueBack", new Vector3(0, 0.1f, 0.03f), new Vector3(0.14f, 0.14f, 0.45f), blue);
            var tail = new Node3D { Position = new Vector3(0, 0, 0.42f) }; _body.AddChild(tail); _appendages.Add(tail);
            Geometry.Triangle(tail, Vector3.Zero, new Vector3(0, 0.29f, 0.43f), new Vector3(0, -0.29f, 0.43f), silver);
            Geometry.Triangle(_body, new Vector3(0, 0.13f, -0.1f), new Vector3(0, 0.4f, 0.18f), new Vector3(0, 0.13f, 0.32f), blue);
            Eyes(_body, dark, 0.13f, 0.06f, -0.36f, 0.055f);
        }
        else if (Kind == BaitKind.Shrimp)
        {
            var shell = Geometry.Material("e8a788", 0.15f);
            var light = Geometry.Material("f3d4ae");
            for (int i = 0; i < 5; i++)
                Geometry.Sphere(_body, "ShellSegment", new Vector3(0, Mathf.Sin(i * 0.65f) * 0.11f, (i - 2) * 0.15f),
                    new Vector3(0.16f - i * 0.014f, 0.15f - i * 0.012f, 0.14f), shell);
            for (int side = -1; side <= 1; side += 2)
            {
                for (int i = 0; i < 3; i++)
                {
                    var leg = new Node3D { Position = new Vector3(side * 0.1f, -0.07f, i * 0.12f - 0.2f) };
                    _body.AddChild(leg); _appendages.Add(leg);
                    Geometry.Triangle(leg, Vector3.Zero, new Vector3(side * 0.23f, -0.2f, 0.1f), new Vector3(side * 0.08f, -0.06f, 0.12f), light);
                }
                Geometry.Triangle(_body, new Vector3(side * 0.06f, 0.03f, -0.3f),
                    new Vector3(side * 0.34f, 0.1f, -1), new Vector3(side * 0.08f, 0.04f, -0.33f), light);
            }
            Geometry.Triangle(_body, new Vector3(0, 0.04f, 0.3f), new Vector3(-0.25f, 0, 0.58f), new Vector3(0.25f, 0, 0.58f), shell);
            Eyes(_body, dark, 0.12f, 0.1f, -0.35f, 0.055f);
        }
        else
        {
            var mantle = Geometry.Material("d3a8d7", 0.2f);
            var fins = Geometry.Material("ae81bd");
            Geometry.Sphere(_body, "Mantle", new Vector3(0, 0, -0.2f), new Vector3(0.29f, 0.3f, 0.6f), mantle);
            for (int side = -1; side <= 1; side += 2)
                Geometry.Triangle(_body, new Vector3(0, 0, -0.7f), new Vector3(side * 0.56f, 0, -0.15f), new Vector3(0, 0, 0.2f), fins);
            Eyes(_body, dark, 0.26f, 0.04f, 0.14f, 0.08f);
            for (int i = 0; i < 6; i++)
            {
                float a = i * Mathf.Tau / 6;
                var arm = new Node3D { Position = new Vector3(Mathf.Cos(a) * 0.17f, Mathf.Sin(a) * 0.17f, 0.25f) };
                _body.AddChild(arm); _appendages.Add(arm);
                Geometry.Sphere(arm, "Tentacle", new Vector3(0, 0, 0.33f), new Vector3(0.045f, 0.045f, i % 2 == 0 ? 0.5f : 0.36f), mantle);
            }
        }
    }

    private static void Eyes(Node3D parent, Material material, float x, float y, float z, float radius)
    {
        for (int side = -1; side <= 1; side += 2)
            Geometry.Sphere(parent, "Eye", new Vector3(side * x, y, z), Vector3.One * radius, material);
    }

    public override void _Process(double delta)
    {
        _phase += (float)delta * (4 + Speed * 6);
        for (int i = 0; i < _appendages.Count; i++)
        {
            float wave = Mathf.Sin(_phase + i * 0.8f);
            _appendages[i].Rotation = Kind == BaitKind.Minnow ? new Vector3(0, wave * 0.4f, 0)
                : Kind == BaitKind.Shrimp ? new Vector3(wave * 0.4f, 0, wave * 0.2f)
                : new Vector3(wave * 0.25f, Mathf.Cos(_phase + i) * 0.25f, 0);
        }
        _body.Scale = Kind == BaitKind.Squid ? new Vector3(1 - Twitch * 0.16f, 1 - Twitch * 0.16f, 1 + Twitch * 0.12f) : Vector3.One;
    }
}
