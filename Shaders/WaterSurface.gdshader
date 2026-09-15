shader_type spatial;
render_mode cull_disabled, depth_draw_never;
uniform vec3 water_color : source_color = vec3(0.16, 0.47, 0.52);
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 vec2 p = world_position.xz;
 float a = sin(p.x*2.0 + sin(p.y*0.7 + TIME*0.4) + TIME*0.8);
 float b = sin(p.y*1.5 - p.x*0.5 - TIME*0.65);
 float crests = smoothstep(0.88, 0.99, a) * smoothstep(-0.55, 0.45, b);
 float distance_fade = 1.0 - smoothstep(35.0, 100.0, length(VERTEX));
 crests *= distance_fade;
 float edge = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
 ALBEDO = mix(water_color, vec3(0.72,0.88,0.81), crests*0.7);
 EMISSION = vec3(0.18,0.32,0.29)*crests;
 ROUGHNESS = 0.3;
 ALPHA = 0.22 + edge*0.28 + crests*0.28;
}
