#version 330

// Input vertex attributes
layout(location = 0) in vec3 vertexPosition;
layout(location = 1) in vec2 vertexTexCoord;
layout(location = 2) in vec3 vertexNormal;

// Input uniform values
uniform mat4 matProjection;
uniform mat4 matModel;
uniform mat4 matView;

// Output vertex attributes (to fragment shader)
out vec3 fragPosition;
out vec3 fragNormal;
out vec2 texCoord;
out vec3 view;

void main() {
    fragPosition = vertexPosition;
    fragNormal = vertexNormal;
    texCoord = vertexTexCoord;

    vec4 viewPosition = matView*matModel*vec4(vertexPosition, 1.0);
    view = normalize(viewPosition.xyz);
    gl_Position = matProjection*viewPosition;
}
