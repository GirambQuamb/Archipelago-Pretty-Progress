shader_type canvas_item;

uniform vec4 color_gap: source_color = vec4(0.25);
uniform vec4 color_stripe: source_color = vec4(1.0, 0.75, 0.0, 1.0);
uniform float divisions = 8.0; // increase for more stripe density
uniform float stripe_bias = 2.5; // 1.0 means no stripes; 2.0 means stripes and gaps are equal size
uniform float speed = 0.1;
uniform float angle = 0.7854; // in radians

void fragment() {
	float w = cos(angle) * UV.x + sin(angle) * UV.y - speed * TIME;
	if (floor(mod(w * divisions, stripe_bias)) < 0.0001) {
		COLOR = vec4(color_gap.r, color_gap.g, color_gap.b, COLOR.a);
	} else {
		COLOR = vec4(color_stripe.r, color_stripe.g, color_stripe.b, COLOR.a);
	}
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
