RSRC                    ShaderMaterial            ��������                                            "      resource_local_to_scene    resource_name    code    script    shader    shader_parameter/direction    shader_parameter/spread )   shader_parameter/initial_linear_velocity    shader_parameter/initial_angle "   shader_parameter/angular_velocity     shader_parameter/orbit_velocity    shader_parameter/linear_accel    shader_parameter/radial_accel    shader_parameter/tangent_accel    shader_parameter/damping    shader_parameter/scale    shader_parameter/anim_speed    shader_parameter/anim_offset 0   shader_parameter/initial_linear_velocity_random &   shader_parameter/initial_angle_random )   shader_parameter/angular_velocity_random '   shader_parameter/orbit_velocity_random %   shader_parameter/linear_accel_random %   shader_parameter/radial_accel_random &   shader_parameter/tangent_accel_random     shader_parameter/damping_random    shader_parameter/scale_random #   shader_parameter/anim_speed_random $   shader_parameter/anim_offset_random %   shader_parameter/lifetime_randomness &   shader_parameter/emission_box_extents    shader_parameter/trail_divisor    shader_parameter/gravity    shader_parameter/colorscheme    
   Texture2D +   res://BackgroundGenerator/Colorscheme.tres �Y�^wb�	   
   local://1 �      -   res://BackgroundGenerator/StarParticles.tres �!         Shader          )  shader_type particles;

uniform vec3 direction;
uniform float spread;
//uniform float flatness;
uniform float initial_linear_velocity;
uniform float initial_angle;
uniform float angular_velocity;
uniform float orbit_velocity;
uniform float linear_accel;
uniform float radial_accel;
uniform float tangent_accel;
uniform float damping;
uniform float scale;
//uniform float hue_variation;
uniform float anim_speed;
uniform float anim_offset;
uniform float initial_linear_velocity_random;
uniform float initial_angle_random;
uniform float angular_velocity_random;
uniform float orbit_velocity_random;
uniform float linear_accel_random;
uniform float radial_accel_random;
uniform float tangent_accel_random;
uniform float damping_random;
uniform float scale_random;
//uniform float hue_variation_random;
uniform float anim_speed_random;
uniform float anim_offset_random;
uniform float lifetime_randomness;
uniform vec3 emission_box_extents;
//uniform vec4 color_value : source_color;
uniform int trail_divisor;
uniform vec3 gravity;
//uniform sampler2D color_ramp;
uniform sampler2D colorscheme;
//in uint var num = NUMBER ;

float rand_from_seed(inout uint seed) {
	int k;
	int s = int(seed);
	if (s == 0)
	s = 305420679;
	k = s / 127773;
	s = 16807 * (s - k * 127773) - 2836 * k;
	if (s < 0)
		s += 2147483647;
	seed = uint(s);
	return float(seed % uint(65536)) / 65535.0;
}

float rand_from_seed_m1_p1(inout uint seed) {
	return rand_from_seed(seed) * 2.0 - 1.0;
}

uint hash(uint x) {
	x = ((x >> uint(16)) ^ x) * uint(73244475);
	x = ((x >> uint(16)) ^ x) * uint(73244475);
	x = (x >> uint(16)) ^ x;
	return x;
}

void process() {
	uint base_number = NUMBER / uint(trail_divisor);
	uint alt_seed = hash(base_number + uint(1) + RANDOM_SEED);
	float angle_rand = rand_from_seed(alt_seed);
	float scale_rand = rand_from_seed(alt_seed);
	//float hue_rot_rand = rand_from_seed(alt_seed);
	float anim_offset_rand = rand_from_seed(alt_seed);
	float pi = 3.14159;
	float degree_to_rad = pi / 180.0;

	bool restart = false;
	if (CUSTOM.y > CUSTOM.w) {
		restart = true;
	}

	if (RESTART || restart) {
		//float tex_linear_velocity = 0.0;
		float tex_angle = 0.0;
		float tex_anim_offset = 0.0;
		float spread_rad = spread * degree_to_rad;
		float angle1_rad = rand_from_seed_m1_p1(alt_seed) * spread_rad;
		angle1_rad += direction.x != 0.0 ? atan(direction.y, direction.x) : sign(direction.y) * (pi / 2.0);
		vec3 rot = vec3(cos(angle1_rad), sin(angle1_rad), 0.0);
		VELOCITY = rot * initial_linear_velocity * mix(1.0, rand_from_seed(alt_seed), initial_linear_velocity_random);
		float base_angle = (initial_angle + tex_angle) * mix(1.0, angle_rand, initial_angle_random);
		CUSTOM.x = base_angle * degree_to_rad;
		CUSTOM.y = 0.0;
		CUSTOM.w = (1.0 - lifetime_randomness * rand_from_seed(alt_seed));
		CUSTOM.z = (anim_offset + tex_anim_offset) * mix(1.0, anim_offset_rand, anim_offset_random);
		TRANSFORM[3].xyz = vec3(rand_from_seed(alt_seed) * 2.0 - 1.0, rand_from_seed(alt_seed) * 2.0 - 1.0, rand_from_seed(alt_seed) * 2.0 - 1.0) * emission_box_extents;
//		TRANSFORM[3].xy = floor(TRANSFORM[3].xy) - vec2(0.5,0.5);
		VELOCITY = (EMISSION_TRANSFORM * vec4(VELOCITY, 0.0)).xyz;
		TRANSFORM = EMISSION_TRANSFORM * TRANSFORM;
		VELOCITY.z = 0.0;
		TRANSFORM[3].z = 0.0;
	} else {
		CUSTOM.y += DELTA / LIFETIME;
		//float tex_linear_velocity = 0.0;
		float tex_orbit_velocity = 0.0;
		float tex_angular_velocity = 0.0;
		float tex_linear_accel = 0.0;
		float tex_radial_accel = 0.0;
		float tex_tangent_accel = 0.0;
		float tex_damping = 0.0;
		float tex_angle = 0.0;
		float tex_anim_speed = 0.0;
		float tex_anim_offset = 0.0;
		vec3 force = gravity;
		vec3 pos = TRANSFORM[3].xyz;
		pos.z = 0.0;
		// apply linear acceleration
		force += length(VELOCITY) > 0.0 ? normalize(VELOCITY) * (linear_accel + tex_linear_accel) * mix(1.0, rand_from_seed(alt_seed), linear_accel_random) : vec3(0.0);
		// apply radial acceleration
		vec3 org = EMISSION_TRANSFORM[3].xyz;
		vec3 diff = pos - org;
		force += length(diff) > 0.0 ? normalize(diff) * (radial_accel + tex_radial_accel) * mix(1.0, rand_from_seed(alt_seed), radial_accel_random) : vec3(0.0);
		// apply tangential acceleration;
		force += length(diff.yx) > 0.0 ? vec3(normalize(diff.yx * vec2(-1.0, 1.0)), 0.0) * ((tangent_accel + tex_tangent_accel) * mix(1.0, rand_from_seed(alt_seed), tangent_accel_random)) : vec3(0.0);
		// apply attractor forces
		VELOCITY += force * DELTA;
		// orbit velocity
		float orbit_amount = (orbit_velocity + tex_orbit_velocity) * mix(1.0, rand_from_seed(alt_seed), orbit_velocity_random);
		if (abs(orbit_amount) < 0.0001) {
		     float ang = orbit_amount * DELTA * pi * 2.0;
		     mat2 rot = mat2(vec2(cos(ang), -sin(ang)), vec2(sin(ang), cos(ang)));
		     TRANSFORM[3].xy -= diff.xy;
		     TRANSFORM[3].xy += rot * diff.xy;
		}
		if (damping + tex_damping > 0.0) {
			float v = length(VELOCITY);
			float damp = (damping + tex_damping) * mix(1.0, rand_from_seed(alt_seed), damping_random);
			v -= damp * DELTA;
			if (v < 0.0) {
				VELOCITY = vec3(0.0);
			} else {
				VELOCITY = normalize(VELOCITY) * v;
			}
		}
		float base_angle = (initial_angle + tex_angle) * mix(1.0, angle_rand, initial_angle_random);
		base_angle += CUSTOM.y * LIFETIME * (angular_velocity + tex_angular_velocity) * mix(1.0, rand_from_seed(alt_seed) * 2.0 - 1.0, angular_velocity_random);
		CUSTOM.x = base_angle * degree_to_rad;
		CUSTOM.x = 2.0*pi * floor(rand_from_seed(alt_seed) * 4.0);
		CUSTOM.z = (anim_offset + tex_anim_offset) * mix(1.0, anim_offset_rand, anim_offset_random) + CUSTOM.y * (anim_speed + tex_anim_speed) * mix(1.0, rand_from_seed(alt_seed), anim_speed_random);
	}
	float tex_scale = 1.0;
	//float tex_hue_variation = 0.0;
	//float hue_rot_angle = (hue_variation + tex_hue_variation) * pi * 2.0 * mix(1.0, hue_rot_rand * 2.0 - 1.0, hue_variation_random);
	//float hue_rot_c = cos(hue_rot_angle);
	//float hue_rot_s = sin(hue_rot_angle);
	//mat4 hue_rot_mat = mat4(vec4(0.299, 0.587, 0.114, 0.0),
			//vec4(0.299, 0.587, 0.114, 0.0),
			//vec4(0.299, 0.587, 0.114, 0.0),
			//vec4(0.000, 0.000, 0.000, 1.0)) +
		//mat4(vec4(0.701, -0.587, -0.114, 0.0),
			//vec4(-0.299, 0.413, -0.114, 0.0),
			//vec4(-0.300, -0.588, 0.886, 0.0),
			//vec4(0.000, 0.000, 0.000, 0.0)) * hue_rot_c +
		//mat4(vec4(0.168, 0.330, -0.497, 0.0),
			//vec4(-0.328, 0.035,  0.292, 0.0),
			//vec4(1.250, -1.050, -0.203, 0.0),
			//vec4(0.000, 0.000, 0.000, 0.0)) * hue_rot_s;
//	vec4 tex_col = textureLod(color_ramp, vec2(CUSTOM.y, 0.0), 0.0);
//	COLOR = hue_rot_mat * tex_col;
	float col_value = floor(rand_from_seed(alt_seed) * 7.0) / 7.0;
	COLOR = textureLod(colorscheme, vec2(col_value, 0.0), 0.0);
//	COLOR.a *= pow(rand_from_seed(alt_seed), 2.0);

	TRANSFORM[0] = vec4(cos(CUSTOM.x), -sin(CUSTOM.x), 0.0, 0.0);
	TRANSFORM[1] = vec4(sin(CUSTOM.x), cos(CUSTOM.x), 0.0, 0.0);
	TRANSFORM[2] = vec4(0.0, 0.0, 1.0, 0.0);
	float base_scale = tex_scale * mix(scale, 1.0, scale_random * scale_rand);
	if (base_scale < 0.000001) {
		base_scale = 0.000001;
	}
	TRANSFORM[0].xyz *= base_scale;
	TRANSFORM[1].xyz *= base_scale;
	TRANSFORM[2].xyz *= base_scale;
	VELOCITY.z = 0.0;
	TRANSFORM[3].z = 0.0;

	if (CUSTOM.y > CUSTOM.w) {		ACTIVE = false;
	}
}
          ShaderMaterial                                                                 	          
                                                      �?                                                                                                                                                   !                   RSRC