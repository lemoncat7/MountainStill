shader_type canvas_item;
uniform float dissolve : hint_range(0.0,1.0) = 0.0;
float grain(vec2 p) {
    return fract(sin(dot(floor(p*vec2(96.0,158.0)),vec2(127.1,311.7)))*43758.5453);
}
void fragment() {
    // In Godot 4, fragment COLOR already includes TEXTURE and draw modulation.
    // Sampling it again squares RGB/alpha, causing a dark flash at portal entry.
    vec4 tex = COLOR;
    float n = grain(UV);
    float visible = step(dissolve, n);
    float edge = (1.0-smoothstep(dissolve,dissolve+0.13,n))*step(0.01,dissolve);
    tex.rgb = mix(tex.rgb,vec3(0.91,0.83,0.49),edge*0.85);
    COLOR = vec4(tex.rgb,tex.a*visible);
}
