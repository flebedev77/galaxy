#version 330

in vec3 fragPosition;
in vec4 fragVertColor;
in vec3 fragNormal;
in float height;
in vec2 texCoord; 

out vec4 finalColor;

uniform vec4 color;
uniform float color_weight;

uniform vec4 water_color;

uniform sampler2D albedo;
uniform sampler2D texture1;

void main() {
    vec4 ao = vec4(height, height, height, 1.0);
    ao *= color_weight;
    vec4 colornew = color * (1-color_weight);
    // finalColor = vec4(mix(color, ao, color_weight).rgb, 1.0);
    finalColor = ao + colornew + texture(albedo, texCoord);
    if (height <= 0) {
      // finalColor = water_color * (height * -1.1) + texture(texture1, texCoord);
      finalColor = texture(texture1, texCoord);
    }
    // finalColor = color;
    // finalColor = fragVertColor;
    // finalColor = vec4(fragNormal, 1.0);//vec4(1.0, 0.0, 0.0, 1.0);
}
