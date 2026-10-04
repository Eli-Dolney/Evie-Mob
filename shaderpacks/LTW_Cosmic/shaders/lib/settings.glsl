// LTW_Cosmic settings. Values in [brackets] are shown as choices in the Iris menu.

// ---------- Shadows ----------
const int shadowMapResolution = 2048; // [1024 1536 2048 3072 4096]
const float shadowDistance = 112.0; // [64.0 80.0 96.0 112.0 128.0 160.0 192.0]
const float sunPathRotation = -25.0; // [-40.0 -35.0 -30.0 -25.0 -20.0 -15.0 -10.0 0.0 10.0 20.0]
const bool shadowHardwareFiltering = false;
const float shadowDistanceRenderMul = 1.0;
const float eyeBrightnessHalflife = 3.0;
const float ambientOcclusionLevel = 1.0; // [0.0 0.25 0.5 0.75 1.0]

#define SHADOW_SAMPLES 8 // [4 8 12 16]
#define SHADOW_SOFTNESS 1.4 // [0.5 0.8 1.0 1.2 1.4 1.8 2.2 3.0]
#define SHADOW_DISTORT 0.88

// ---------- Lighting ----------
#define SUN_BRIGHTNESS 1.0 // [0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.4 1.6]
#define AMBIENT_BRIGHTNESS 1.0 // [0.5 0.6 0.7 0.8 0.9 1.0 1.2 1.4 1.6]
#define TORCH_BRIGHTNESS 1.0 // [0.5 0.7 0.8 1.0 1.2 1.4 1.7 2.0]
#define TORCH_WARMTH 1.0 // [0.0 0.25 0.5 0.75 1.0 1.25 1.5]
#define TORCH_FLICKER
#define MIN_LIGHT 1.0 // [0.0 0.5 1.0 1.5 2.0 3.0]
#define EMISSIVE_STRENGTH 1.0 // [0.0 0.5 1.0 1.5 2.0 3.0]
#define FOLIAGE_SSS

// ---------- Dream palette ----------
#define DREAM_TINT 1.0 // [0.0 0.25 0.5 0.75 1.0 1.25 1.5 2.0]
#define FOLIAGE_VIBRANCE 1.0 // [0.0 0.25 0.5 0.75 1.0 1.25 1.5 2.0]
#define NIGHT_AURORA
#define AURORA_STRENGTH 1.0 // [0.25 0.5 0.75 1.0 1.5 2.0]

// ---------- Cosmos ----------
#define PORTAL
#define PORTAL_STRENGTH 1.0 // [0.25 0.5 0.75 1.0 1.25 1.5]
#define PORTAL_SIZE 1.0 // [0.5 0.75 1.0 1.25 1.5]
#define PORTAL_SPIN 1.0 // [0.0 0.5 1.0 2.0 4.0]
#define PLANETS
#define PLANET_SIZE 1.0 // [0.5 0.75 1.0 1.25 1.5 2.0]
#define FLOATING_ROCKS
#define ROCK_AMOUNT 0.22 // [0.08 0.15 0.22 0.3 0.4]
#define ROCK_SIZE 1.0 // [0.5 0.75 1.0 1.5 2.0]
#define SKY_HEADS
#define SKY_HEAD_DAYS 3 // [1 2 3 4 5 7]
#define GIANT_HEAD

// ---------- Comic ink ----------
#define INK_OUTLINES
#define INK_STRENGTH 0.8 // [0.0 0.25 0.5 0.65 0.8 1.0]
#define INK_WIDTH 1.5 // [1.0 1.5 2.0 2.5 3.0]
#define BLOCK_EDGES 0.35 // [0.0 0.15 0.25 0.35 0.5 0.7]
#define NEON_CAVES

// ---------- Waving ----------
#define WAVING_PLANTS
#define WAVING_LEAVES
#define WAVE_SPEED 1.0 // [0.25 0.5 0.75 1.0 1.25 1.5 2.0]
#define WAVE_AMOUNT 1.0 // [0.25 0.5 0.75 1.0 1.25 1.5 2.0]

// ---------- Water ----------
#define WATER_WAVES
#define WATER_WAVE_HEIGHT 1.0 // [0.25 0.5 0.75 1.0 1.25 1.5 2.0]
#define WATER_OPACITY 0.55 // [0.25 0.35 0.45 0.55 0.65 0.75 0.85]
#define SSR
#define SSR_STEPS 20 // [12 16 20 28 36]

// ---------- Atmosphere ----------
#define FOG_DENSITY 1.0 // [0.0 0.25 0.5 0.75 1.0 1.25 1.5 2.0]
#define BORDER_FOG
#define GODRAYS
#define GODRAY_SAMPLES 12 // [6 8 12 16 24]
#define GODRAY_STRENGTH 1.0 // [0.25 0.5 0.75 1.0 1.25 1.5 2.0]
#define CLOUD_TINT 1.0 // [0.0 0.5 1.0 1.5]
#define CARTOON_CLOUDS
#define CARTOON_CLOUD_AMOUNT 0.45 // [0.2 0.3 0.45 0.6 0.75]
#define CARTOON_CLOUD_HEIGHT 192.0 // [128.0 160.0 192.0 224.0 256.0 320.0]
#define CARTOON_OUTLINE 2.5 // [1.0 1.5 2.0 2.5 3.0 4.0 5.0]
#define CARTOON_CLOUD_SIZE 1.0 // [0.6 0.8 1.0 1.25 1.5 2.0]
#define CARTOON_CLOUD_VARIATION 40.0 // [0.0 16.0 24.0 32.0 40.0 48.0 64.0 96.0]
#define CARTOON_CLOUD_STYLE 0 // [0 1 2 3]
#define CARTOON_CLOUD_WIND 1.0 // [0.0 0.5 1.0 2.0 4.0]

// ---------- Post ----------
#define BLOOM
#define BLOOM_STRENGTH 1.0 // [0.25 0.5 0.75 1.0 1.25 1.5 2.0]
#define EXPOSURE 1.0 // [0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.4 1.6 2.0]
#define SATURATION 1.2 // [0.6 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.6]
#define VIBRANCE 1.3 // [0.8 1.0 1.1 1.2 1.3 1.5 1.8]
#define CONTRAST 1.08 // [0.9 0.95 1.0 1.04 1.08 1.12 1.2]
#define VIGNETTE 0.25 // [0.0 0.15 0.25 0.35 0.5 0.7]

// ---------- Performance HUD ----------
//#define PERF_HUD
#define HUD_SIZE 1.0 // [0.5 0.75 1.0 1.25 1.5 2.0]
