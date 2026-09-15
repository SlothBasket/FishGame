shader_type spatial;
render_mode cull_disabled;
uniform vec3 sand_dark : source_color = vec3(0.23, 0.31, 0.27);
uniform vec3 sand_light : source_color = vec3(0.62, 0.65, 0.46);
uniform float ripple_spacing = 0.65;
varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
 vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
 return mix(mix(hash(i), hash(i+vec2(1,0)), f.x), mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), f.x), f.y);
}
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 vec2 p = world_position.xz;
 float phase = (p.x + sin(p.y*0.38)*0.8 + noise(p*0.12)*2.0) * 6.28318 / ripple_spacing;
 float visibility = 1.0 - smoothstep(0.7, 2.5, fwidth(phase));
 float ripples = sin(phase) * 0.5 * visibility + 0.5;
 float patches = noise(p*0.23);
 ALBEDO = mix(sand_dark, sand_light, clamp(0.32 + patches*0.35 + ripples*0.22, 0.0, 1.0));
 ROUGHNESS = 0.95;
}
