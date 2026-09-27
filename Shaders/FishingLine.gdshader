shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float travel = 0.0;
void fragment() {
 float stripe = smoothstep(0.35,0.45,fract((UV.x-travel)/1.4));
 ALBEDO = mix(vec3(0.22,0.34,0.32),vec3(1.0,0.95,0.7),stripe);
 ALPHA = 0.9;
}
