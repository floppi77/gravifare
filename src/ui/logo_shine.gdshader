shader_type canvas_item;
// Glanzstreifen über das GraviFare-Logo (wie im Trailer): ein heller, leicht schräger Streifen wandert von links nach rechts
// und hellt nur die hellen Flächen der Buchstaben auf; die dunklen Umrisse bleiben dunkel.
uniform float sweep = -1.0;         // Position des Streifens in UV (Bereich der Bildfläche); außerhalb von 0..1 unsichtbar
uniform float band_width = 0.045;   // Breite des Streifens in UV
uniform float strength = 0.85;

void fragment() {
	vec4 c = COLOR;
	float band = exp(-pow((UV.x + (0.5 - UV.y) * 0.04 - sweep) / band_width, 2.0));
	float bright = step(0.35, max(c.r, max(c.g, c.b)));
	c.rgb += vec3(1.0, 0.97, 0.88) * band * bright * c.a * strength;
	COLOR = c;
}
