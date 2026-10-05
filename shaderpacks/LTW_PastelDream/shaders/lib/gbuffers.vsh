out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 normalV;
out vec3 worldPos;

uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;

void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    lmcoord  = clamp((lmcoord - 0.03125) * 1.06667, 0.0, 1.0);
    glcolor  = gl_Color;
    normalV  = normalize(gl_NormalMatrix * gl_Normal);
    vec4 vp  = gl_ModelViewMatrix * gl_Vertex;
    worldPos = (gbufferModelViewInverse * vp).xyz + cameraPosition;
}
