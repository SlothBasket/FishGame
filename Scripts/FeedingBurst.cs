using Godot;
using System.Collections.Generic;

public partial class FeedingBurst : Node3D
{
    public Color Tint { get; set; }
    public int Count { get; set; } = 8;
    private readonly List<(MeshInstance3D Mesh, Vector3 Drift)> _specks = new();
    private float _age;
    public override void _Ready()
    {
        var material = new StandardMaterial3D { AlbedoColor = Tint,
            ShadingMode = BaseMaterial3D.ShadingModeEnum.Unshaded };
        for (int i = 0; i < Count; i++)
        {
            float angle = i * 2.39996f;
            Vector3 drift = new Vector3(Mathf.Cos(angle), 0.4f + (i % 3) * 0.35f, Mathf.Sin(angle)) * (0.5f + i * 0.05f);
            var mesh = Geometry.Sphere(this, "Bubble", Vector3.Zero, Vector3.One * (0.035f + i % 3 * 0.012f), material);
            _specks.Add((mesh, drift));
        }
    }
    public override void _Process(double delta)
    {
        _age += (float)delta;
        foreach (var speck in _specks)
        {
            speck.Mesh.Position += speck.Drift * (float)delta;
            speck.Mesh.Scale *= Mathf.Exp(-3 * (float)delta);
        }
        if (_age > 0.6f) QueueFree();
    }
}
