using Godot;

public partial class FeedingHud : Control
{
    public FishPlayer Fish { get; set; } = null!;
    public override void _Ready() { MouseFilter = MouseFilterEnum.Ignore; }
    public override void _Process(double delta) => QueueRedraw();
    public override void _Draw()
    {
        Vector2 center = GetViewportRect().Size * 0.5f;
        Color gold = new("f2ce8a"), muted = new("9dc6c8");
        var font = ThemeDB.FallbackFont;
        // Keep the meter near the aim point so charging never pulls attention away from prey.
        DrawArc(center, 16, 0, Mathf.Tau, 48, new Color(0.7f, 0.88f, 0.85f, 0.4f), 1.5f, true);
        DrawCircle(center, 2, gold);
        if (Fish.IsCharging)
        {
            DrawArc(center, 22, -Mathf.Pi / 2, -Mathf.Pi / 2 + Mathf.Tau * Fish.ChargeFraction, 64, gold, 4, true);
            string text = Fish.ChargeFraction >= 0.999f ? "FULL CHARGE  /  RELEASE" : $"RELEASE TO LUNGE  {Mathf.Lerp(Fish.MinimumLungeDistance, Fish.MaximumLungeDistance, Fish.ChargeFraction):0.0} m";
            DrawString(font, center + new Vector2(-110, 58), text, fontSize: 14, modulate: gold);
        }
        else if (Fish.CooldownRemaining > 0)
            DrawArc(center, 22, -Mathf.Pi / 2, -Mathf.Pi / 2 + Mathf.Tau * (1 - Fish.CooldownRemaining / Mathf.Max(0.01f, Fish.BiteCooldown)), 48, muted, 2, true);
        if (Fish.MealNoticeTime > 0)
            DrawString(font, new Vector2(center.X - 75, 115), Fish.LastMeal, fontSize: 21,
                modulate: new Color(gold.R, gold.G, gold.B, Mathf.Min(1, Fish.MealNoticeTime * 2)));
    }
}
