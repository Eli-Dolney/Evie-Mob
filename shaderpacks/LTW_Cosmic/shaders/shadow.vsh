#version 330 compatibility

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/common.glsl"
#include "/lib/distort.glsl"
#include "/lib/waving.glsl"

uniform mat4 shadowModelViewInverse;

in vec4 mc_Entity;
in vec4 mc_midTexCoord;

out vec2 texcoord;
out vec4 glcolor;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor = gl_Color;

    int id = int(mc_Entity.x + 0.5);
    if (id == ID_WATER) {
        gl_Position = vec4(10.0, 10.0, 10.0, 1.0);
        return;
    }

    vec4 vpos = gl_ModelViewMatrix * gl_Vertex;
    vec3 ppos = (shadowModelViewInverse * vpos).xyz;
    ppos = applyWaving(ppos, id, gl_MultiTexCoord0.t < mc_midTexCoord.t);

    vec4 clip = shadowProjection * (shadowModelView * vec4(ppos, 1.0));
    clip.xyz = distortShadow(clip.xyz);
    gl_Position = clip;
}
