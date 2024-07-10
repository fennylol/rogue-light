shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, unshaded;

uniform sampler2D albedo_texture;
uniform vec3 player_position;
uniform vec3 camera_position;

void fragment() {
    // Get the world position of the current pixel
    vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    
    // Calculate vectors
    vec2 to_player = player_position.xz - world_pos.xz;
    vec2 to_camera = camera_position.xz - world_pos.xz;
    
    // Normalize vectors
    to_player = normalize(to_player);
    to_camera = normalize(to_camera);
    
    // Calculate dot product
    float dot_product = -dot(to_player, to_camera);
    
    // If dot product is positive, the object is between player and camera
    float fade = smoothstep(-0.2, 0.2, dot_product);
    
    // Get the color from the texture
    vec4 base_color = texture(albedo_texture, UV);
    
    // Apply color and transparency
    ALBEDO = base_color.rgb;
    ALPHA = mix(1.0, 0.5, fade);
}