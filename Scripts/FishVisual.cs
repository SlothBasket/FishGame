using Godot;

// Original procedural placeholder. Model faces local -Z; tail points +Z.
public partial class FishVisual : Node3D
{
    public float SwimIntensity { get; set; }
    public float Gape { get; set; }
    private MeshInstance3D _mouth = null!;
    private MeshInstance3D _jaw = null!;
    private Node3D _tail = null!;
    private Node3D _leftFin = null!;
    private Node3D _rightFin = null!;
    private float _phase;

    public override void _Ready()
    {
        var silver = Geometry.Material("86c9ce", 0.35f);
        var blue = Geometry.Material("23758c", 0.3f);
        var gold = Geometry.Material("edc97e", 0.4f);
        _mouth = Geometry.Sphere(this, "Mouth", new Vector3(0, -0.07f, -1.31f), new Vector3(0.24f, 0.02f, 0.04f), Geometry.Material("08252e"));
        _jaw = Geometry.Sphere(this, "LowerJaw", new Vector3(0, -0.17f, -1.16f), new Vector3(0.26f, 0.1f, 0.24f), silver);
        Geometry.Sphere(this, "Body", Vector3.Zero, new Vector3(0.49f, 0.67f, 1.35f), silver);
        Geometry.Sphere(this, "Back", new Vector3(0, 0.29f, 0.08f), new Vector3(0.42f, 0.4f, 1.08f), blue);
        Geometry.Sphere(this, "Belly", new Vector3(0, -0.25f, -0.1f), new Vector3(0.4f, 0.38f, 1.03f), Geometry.Material("d6e7d2"));
        for (int side = -1; side <= 1; side += 2)
        {
            Geometry.Sphere(this, "Eye", new Vector3(side * 0.35f, 0.16f, -0.91f), new Vector3(0.11f, 0.14f, 0.14f), gold);
            Geometry.Sphere(this, "Pupil", new Vector3(side * 0.435f, 0.17f, -0.94f), new Vector3(0.035f, 0.085f, 0.08f), Geometry.Material("092731"));
            var fin = new Node3D { Position = new Vector3(side * 0.36f, -0.14f, -0.14f) };
            AddChild(fin);
            Geometry.Triangle(fin, new Vector3(0, 0, -0.15f), new Vector3(side * 0.65f, -0.26f, 0.64f), new Vector3(0, 0, 0.53f), gold);
            if (side == -1) _leftFin = fin; else _rightFin = fin;
        }
        Geometry.Triangle(this, new Vector3(0, 0.44f, -0.45f), new Vector3(0, 1.03f, 0.35f), new Vector3(0, 0.43f, 0.9f), blue);
        _tail = new Node3D { Name = "Tail", Position = new Vector3(0, 0, 1.02f) };
        AddChild(_tail);
        Geometry.Triangle(_tail, Vector3.Zero, new Vector3(0, 0.79f, 1.13f), new Vector3(0, 0, 0.81f), gold);
        Geometry.Triangle(_tail, Vector3.Zero, new Vector3(0, 0, 0.81f), new Vector3(0, -0.79f, 1.13f), gold);
    }

    public override void _Process(double delta)
    {
        _mouth.Scale = new Vector3(0.24f + Gape * 0.06f, 0.025f + Gape * 0.22f, 0.045f);
        _jaw.Position = new Vector3(0, -0.17f - Gape * 0.31f, -1.16f);
        _phase += (float)delta * (3 + SwimIntensity * 8);
        _tail.Rotation = new Vector3(0, Mathf.Sin(_phase) * (0.14f + SwimIntensity * 0.18f), 0);
        _leftFin.Rotation = new Vector3(0, 0, Mathf.Sin(_phase * 0.6f) * 0.18f);
        _rightFin.Rotation = -_leftFin.Rotation;
    }
}
