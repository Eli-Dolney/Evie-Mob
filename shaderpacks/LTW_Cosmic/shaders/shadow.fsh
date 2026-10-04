#version 330 compatibility

uniform sampler2D gtexture;

in vec2 texcoord;
in vec4 glcolor;

layout(location = 0) out vec4 outColor;

void main() {
    vec4 color = texture(gtexture, texcoord) * glcolor;
    if (color.a < 0.1) discard;
    outColor = color;
}
