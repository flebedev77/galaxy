#version 330

// Input vertex attributes
layout(location = 0) in vec3 vertexPosition;
layout(location = 1) in vec2 vertexTexCoord;
layout(location = 2) in vec3 vertexNormal;
layout(location = 3) in vec4 vertexColor;
layout(location = 5) in vec2 heightmap;

// Input uniform values
uniform mat4 matProjection;
uniform mat4 matView;

// Output vertex attributes (to fragment shader)
out vec3 fragPosition;
out vec4 fragVertColor;
out vec3 fragNormal;
out float height;

out vec2 texCoord;

void main() {
    fragPosition = vertexPosition;
    fragVertColor = vertexColor;
    fragNormal = vertexNormal;
    height = heightmap.x;
    texCoord = vertexTexCoord;

    gl_Position = matProjection*matView*vec4(vertexPosition, 1.0);
}
