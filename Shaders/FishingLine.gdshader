shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float travel = 0.0;
void fragment() {
 // Constant solid base; sparse highlights carry flow, not the whole ribbon.
 float phase = fract((UV.x-travel)/4.0);
 float marker = smoothstep(0.02,0.04,phase)*(1.0-smoothstep(0.12,0.14,phase));
 ALBEDO = mix(vec3(0.62,0.70,0.62),vec3(0.90,0.88,0.70),marker*0.55);
 ALPHA = 0.9;
}
