uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform vec3 cameraPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 shadowLightPosition;
uniform vec3 upPosition;
uniform vec3 fogColor;
uniform vec3 skyColor;

uniform float frameTimeCounter;
uniform float rainStrength;
uniform float wetness;
uniform float nightVision;
uniform float blindness;
uniform float viewWidth;
uniform float viewHeight;
uniform float near;
uniform float far;

uniform int isEyeInWater;
uniform int worldTime;
uniform int worldDay;
uniform ivec2 eyeBrightnessSmooth;

// Iris-only dimension info.
uniform bool hasCeiling;
uniform bool hasSkylight;
uniform float ambientLight;
