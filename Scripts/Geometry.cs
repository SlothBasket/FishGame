using Godot;

public static class Geometry
{
    public static StandardMaterial3D Material(string hex, float metallic = 0) => new()
    {
        AlbedoColor = new Color(hex), Metallic = metallic, Roughness = 0.55f,
        CullMode = BaseMaterial3D.CullModeEnum.Disabled
    };

    public static MeshInstance3D Sphere(Node3D parent, string name, Vector3 position, Vector3 scale, Material material)
    {
        var mesh = new MeshInstance3D { Name = name, Position = position, Scale = scale,
            Mesh = new SphereMesh { Radius = 1, Height = 2, RadialSegments = 24, Rings = 12 }, MaterialOverride = material };
        parent.AddChild(mesh);
        return mesh;
    }

    public static void Triangle(Node3D parent, Vector3 a, Vector3 b, Vector3 c, Material material)
    {
        var mesh = new ImmediateMesh();
        mesh.SurfaceBegin(Mesh.PrimitiveType.Triangles);
        mesh.SurfaceSetNormal((b - a).Cross(c - a).Normalized());
        mesh.SurfaceAddVertex(a); mesh.SurfaceAddVertex(b); mesh.SurfaceAddVertex(c);
        mesh.SurfaceEnd();
        parent.AddChild(new MeshInstance3D { Mesh = mesh, MaterialOverride = material });
    }

    public static void Box(Node3D parent, string name, Vector3 position, Vector3 size, Material material, bool visible = true)
    {
        var body = new StaticBody3D { Name = name, Position = position };
        parent.AddChild(body);
        body.AddChild(new CollisionShape3D { Shape = new BoxShape3D { Size = size } });
        if (visible) body.AddChild(new MeshInstance3D { Mesh = new BoxMesh { Size = size }, MaterialOverride = material });
    }
}
