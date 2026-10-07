shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 tension_tint : source_color = vec4(1.0);
uniform float travel = 0.0;
void fragment() {
 // Constant solid base; sparse highlights carry flow, not the whole ribbon.
 float phase = fract((UV.x-travel)/4.0);
 float marker = smoothstep(0.02,0.04,phase)*(1.0-smoothstep(0.12,0.14,phase));
 ALBEDO = tension_tint.rgb*(0.86+marker*0.14);
 ALPHA = 0.9;
}
