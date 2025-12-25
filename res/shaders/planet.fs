#version 330

in vec3 fragPosition;
in vec4 fragVertColor;
in vec3 fragNormal;
in float height;
in float noise;
in vec2 texCoord; 

out vec4 finalColor;

uniform vec4 color;
uniform float color_weight;

uniform vec4 water_color;

uniform float sea_level;
uniform float shore_margin;
uniform float snow_factor;

uniform float ao_intensity;
uniform float ao_darkness;

uniform float noise_intensity;

uniform float ambient;

uniform sampler2D texture0;
uniform sampler2D normalMap;

void main() {
    vec4 ao = vec4(height, height, height, 1.0);
    ao = (ao-sea_level)*ao_intensity;
    ao = ao-ao_darkness;
    ao.a = 1;
    // ao *= color_weight;
    // vec4 colornew = color * (1-color_weight);
    // finalColor = vec4(mix(color, ao, color_weight).rgb, 1.0);
    // finalColor = mix(texture(texture0, texCoord*4), ao, color_weight);
    finalColor = texture(texture0, texCoord*4);
    if (height <= sea_level+0.0001) {
      // finalColor = water_color * (height * -1.1) + texture(normalMap, texCoord);
      finalColor = mix(texture(normalMap, texCoord*4), finalColor, clamp(sea_level-height, 0, 1));
      finalColor += (vec4(0, 0, 0, 1.0)*ao_intensity-ao_darkness)*color_weight;
    } else {
      finalColor += ao*color_weight;
    }
    if (height <= sea_level - shore_margin) {
      // finalColor = mix(finalColor, vec4(0.42, 0.267, 0.165, 1), 0.5);
      finalColor = mix(finalColor, water_color, 1);
    }
    if (height > snow_factor) {
      finalColor = mix(finalColor, vec4(1, 1, 1, 1), 5*(height-snow_factor));
    }
    finalColor += noise*noise_intensity;
    finalColor += ambient;
    finalColor.a = 1;
    // finalColor = color;
    // finalColor = fragVertColor;
    // finalColor = vec4(fragNormal, 1.0);//vec4(1.0, 0.0, 0.0, 1.0);
}
