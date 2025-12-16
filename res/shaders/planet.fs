#version 330

in vec3 fragPosition;
in vec4 fragVertColor;
in vec3 fragNormal;
in float height;

out vec4 finalColor;

void main() {
    finalColor = vec4(height, height, height, height);
    // finalColor = fragVertColor;
    // finalColor = vec4(fragNormal, 1.0);//vec4(1.0, 0.0, 0.0, 1.0);
}
