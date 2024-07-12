shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back, diffuse_toon;

uniform sampler2D albedo_texture;
uniform vec3 player_position;
uniform vec3 camera_position;
uniform vec3 fade_settings = vec3(10.0, 20.0, 0.25);

void fragment() {
	float fade_begin = fade_settings.x;
	float fade_end = fade_settings.y;
	float fade_strength = fade_settings.z;
	// Get the world position of the current pixel
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// Calculate vectors
	vec2 to_player = player_position.xz - world_pos.xz;
	vec2 to_camera = camera_position.xz - world_pos.xz;
	
	float dist_to_player = sqrt((to_player.x*to_player.x)+(to_player.y*to_player.y));
	// Normalize vectors
	to_player = normalize(to_player);
	to_camera = normalize(to_camera);

	// Calculate dot product
	float dot_product = -dot(to_player, to_camera);

	// If dot product is positive, the object is between player and camera
	float past_distance = dist_to_player * dot_product;
	
	float fade = smoothstep(fade_begin, fade_end, past_distance);

	// Get the color from the texture
	vec4 base_color = texture(albedo_texture, UV);

	// Apply color and transparency
	ALBEDO = base_color.rgb;
	ALPHA = mix(1.0, fade_strength, fade);
	ROUGHNESS = 1.0;
	SPECULAR = 0.25;
	//ALPHA_SCISSOR_THRESHOLD = fade/2.0;
}

void light() {
	// Diffuse light
    float NdotL = dot(NORMAL, LIGHT);
    DIFFUSE_LIGHT += max(NdotL, 0.0) * ATTENUATION * ALBEDO * LIGHT_COLOR;
}

