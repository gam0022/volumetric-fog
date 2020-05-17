const float INF = 1e+10;
const float OFFSET = 0.001;

vec3 directionalLight;

#define SCENE_MANDEL 0.0
#define SCENE_UNIVERSE 1.0

uniform float gCameraEyeX;     // -0.08828528243935951 -100 100 camera
uniform float gCameraEyeY;     // 3.5309297601209235 -100 100
uniform float gCameraEyeZ;     // -2.705631420983895 -100 100
uniform float gCameraTargetX;  // 0.7576763789243015 -100 100
uniform float gCameraTargetY;  // 3.4515422110479044 -100 100
uniform float gCameraTargetZ;  // -0.21633410393024527 -100 100
uniform float gCameraFov;      // 37.88049605411499 0 180

uniform float gSceneEps;         // 0.002 0.00001 0.01 scene
uniform float gMandelboxScale;   // 2.7 1 5
uniform float gMandelboxRepeat;  // 10 1 100
uniform float gEdgeEps;          // 0.0005 0.0001 0.01
uniform float gEdgePower;        // 1 0.1 10
uniform float gBaseColor;        // 0.5
uniform float gRoughness;        // 0.14
uniform float gMetallic;         // 0.49

struct Ray {
    vec3 origin;
    vec3 direction;
};

struct Camera {
    vec3 eye, target;
    vec3 forward, right, up;
};
Camera camera;

Ray cameraShootRay(Camera c, vec2 uv) {
    c.forward = normalize(c.target - c.eye);
    c.right = normalize(cross(c.forward, c.up));
    c.up = normalize(cross(c.right, c.forward));

    Ray r;
    r.origin = c.eye;
    r.direction = normalize(uv.x * c.right + uv.y * c.up + c.forward / tan(gCameraFov / 360.0 * PI));

    return r;
}

struct Intersection {
    bool hit;
    vec3 position;
    float distance;
    vec3 normal;
    vec2 uv;
    int count;

    vec3 baseColor;
    float roughness;
    float reflectance;
    float metallic;
    vec3 emission;

    vec3 color;
};

#define calcNormal(p, dFunc, eps)                                                                                                                                                 \
    normalize(vec2(eps, -eps).xyy *dFunc(p + vec2(eps, -eps).xyy) + vec2(eps, -eps).yyx * dFunc(p + vec2(eps, -eps).yyx) + vec2(eps, -eps).yxy * dFunc(p + vec2(eps, -eps).yxy) + \
              vec2(eps, -eps).xxx * dFunc(p + vec2(eps, -eps).xxx))

float sdSphere(vec3 p, float r) { return length(p) - r; }

float sdCapsule(vec3 p, vec3 a, vec3 b, float r) {
    vec3 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - r;
}

mat2 rotate(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, s, -s, c);
}

float dMandelFast(vec3 p, float scale, int n) {
    vec4 q0 = vec4(p, 1.0);
    vec4 q = q0;

    for (int i = 0; i < n; i++) {
        q.xyz = clamp(q.xyz, -1.0, 1.0) * 2.0 - q.xyz;
        q = q * scale / clamp(dot(q.xyz, q.xyz), 0.3, 1.0) + q0;
    }

    return length(q.xyz) / abs(q.w);
}

float map(vec3 p) {
    float d = dMandelFast(p, gMandelboxScale, int(gMandelboxRepeat));
    return d;
}

float mapLod(vec3 p) {
    float d = dMandelFast(p, gMandelboxScale, 5);
    return d;
}

uniform float gF0;                 // 0.95 0 1 lighting
uniform float gDirectionalLightX;  // -0.48666426339228763 -1 1
uniform float gDirectionalLightY;  // 0.8111071056538127 -1 1
uniform float gDirectionalLightZ;  // 0.3244428422615251 -1 1
uniform float gAmbientIntensity;   // 0.077 0 1
uniform vec3 gSunColor;            // 255 128 128

float fresnelSchlick(float f0, float cosTheta) { return f0 + (1.0 - f0) * pow((1.0 - cosTheta), 5.0); }

void intersectObjects(inout Intersection intersection, inout Ray ray) {
    float d;
    float distance = 0.0;
    vec3 p = ray.origin;
    float eps;

    for (int i = 0; i < 300; i++) {
        d = map(p);
        distance += d;
        p = ray.origin + distance * ray.direction;
        intersection.count = i;
        eps = gSceneEps * distance;
        if (d < eps) break;
    }

    if (distance < intersection.distance) {
        intersection.distance = distance;
        intersection.hit = true;
        intersection.position = p;
        intersection.normal = calcNormal(p, map, gSceneEps);

        intersection.baseColor = vec3(gBaseColor);
        intersection.roughness = gRoughness;
        intersection.metallic = gMetallic;
        intersection.reflectance = 0.0;
    }
}

uniform float gLodEps;    // 0.00001 0 0.01
uniform float gLodLoop;   // 45 0 100
uniform float gLodScale;  // 3.1 1 10

void intersectObjectsLod(inout Intersection intersection, inout Ray ray) {
    float d;
    float distance = 0.0;
    vec3 p = ray.origin;
    float eps = gLodEps;

    for (int i = 0; i < int(gLodLoop); i++) {
        d = mapLod(p);
        distance += d * gLodScale;
        p = ray.origin + distance * ray.direction;
        if (d < eps) break;
    }

    if (distance < intersection.distance) {
        intersection.hit = true;
    }
}

#define FLT_EPS 5.960464478e-8

float roughnessToExponent(float roughness) { return clamp(2.0 * (1.0 / (roughness * roughness)) - 2.0, FLT_EPS, 1.0 / FLT_EPS); }

vec3 evalPointLight(inout Intersection i, vec3 v, vec3 lp, vec3 radiance) {
    vec3 n = i.normal;
    vec3 p = i.position;
    vec3 ref = mix(vec3(0.04), i.baseColor, i.metallic);

    vec3 l = lp - p;
    float len = length(l);
    l /= len;

    vec3 h = normalize(l + v);

    vec3 diffuse = mix(1.0 - ref, vec3(0.0), i.metallic) * i.baseColor / PI;
    float m = roughnessToExponent(i.roughness);
    vec3 specular = ref * pow(max(0.0, dot(n, h)), m) * (m + 2.0) / (8.0 * PI);
    return (diffuse + specular) * radiance * max(0.0, dot(l, n)) / (len * len);
}

vec3 evalDirectionalLight(inout Intersection i, vec3 v, vec3 lightDir, vec3 radiance) {
    vec3 n = i.normal;
    vec3 p = i.position;
    vec3 ref = mix(vec3(0.04), i.baseColor, i.metallic);

    vec3 l = lightDir;
    vec3 h = normalize(l + v);

    vec3 diffuse = mix(1.0 - ref, vec3(0.0), i.metallic) * i.baseColor / PI;
    float m = roughnessToExponent(i.roughness);
    vec3 specular = ref * pow(max(0.0, dot(n, h)), m) * (m + 2.0) / (8.0 * PI);
    return (diffuse + specular) * radiance * max(0.0, dot(l, n));
}

uniform float gAoLen;            // 0.0724 0 0.2
uniform float gAoMul;            // 1 0 1
uniform float gShadowIntensity;  // 0.17 0 1

float calcAo(in vec3 p, in vec3 n) {
    float k = 1.0, occ = 0.0;
    for (int i = 0; i < 5; i++) {
        float len = float(i + 1) * gAoLen;
        float distance = map(n * len + p);
        occ += (len - distance) * k;
        k *= gAoMul;
    }
    return saturate(1.0 - occ);
}

float calcShadow(in vec3 p, in vec3 rd) {
    float d;
    float distance = OFFSET;
    float bright = 1.0;
    float shadowSharpness = 10.0;

    for (int i = 0; i < 30; i++) {
        d = mapLod(p + rd * distance);
        if (d < gLodEps) return gShadowIntensity;
        bright = min(bright, shadowSharpness * d / distance);
        distance += d * gLodScale;
    }

    return gShadowIntensity + (1.0 - gShadowIntensity) * bright;
}

// https://www.shadertoy.com/view/WsfBDf

const int c_numRayMarchSteps = 16;
const vec3 c_fogColorLit = vec3(1.0f, 1.0f, 1.0f);
const vec3 c_fogColorUnlit = vec3(0.0f, 0.0f, 0.0f);

uniform float gFogDensity;  // 0.13 0 0.5

// this noise, including the 5.58... scrolling constant are from Jorge Jimenez
float InterleavedGradientNoise(vec2 pixel, int frame) {
    pixel += (float(frame) * 5.588238f);
    return fract(52.9829189f * fract(0.06711056f * float(pixel.x) + 0.00583715f * float(pixel.y)));
}

// ray march from the camera to the depth of what the ray hit to do some simple scattering
vec3 applyFog(in vec3 rayPos, in vec3 rayDir, in vec3 pixelColor, in float rayHitTime, in vec2 pixelPos) {
    // Offset the start of the ray between 0 and 1 ray marching steps.
    // This turns banding into noise.
    int frame = 0;
    float startRayOffset = InterleavedGradientNoise(pixelPos, frame);

    // calculate how much of the ray is in direct light by taking a fixed number of steps down the ray
    // and calculating the percent.
    // Note: in a rasterizer, you'd replace the RayVsScene raytracing with a shadow map lookup!
    float fogLitPercent = 0.0f;
    for (int i = 0; i < c_numRayMarchSteps; ++i) {
        vec3 testPos = rayPos + rayDir * rayHitTime * ((float(i) + startRayOffset) / float(c_numRayMarchSteps));

        Intersection intersection;
        intersection.distance = INF;
        intersection.hit = false;

        Ray ray;
        ray.origin = testPos;
        ray.direction = directionalLight;

        intersectObjectsLod(intersection, ray);
        fogLitPercent = mix(fogLitPercent, intersection.hit ? 0.0 : 1.0, 1.0 / float(i + 1));
    }

    vec3 fogColor = mix(c_fogColorUnlit, c_fogColorLit, fogLitPercent);
    float absorb = exp(-rayHitTime * gFogDensity);
    return mix(fogColor, pixelColor, absorb);
}

void calcRadiance(inout Intersection intersection, inout Ray ray, vec2 fragCoord) {
    intersection.hit = false;
    intersection.distance = INF;
    intersectObjects(intersection, ray);

    if (intersection.hit) {
        intersection.color = intersection.emission;
        intersection.color += gAmbientIntensity * gSunColor * calcAo(intersection.position, intersection.normal);
        intersection.color += evalDirectionalLight(intersection, -ray.direction, directionalLight, gSunColor) * calcShadow(intersection.position, directionalLight);
        intersection.color = applyFog(ray.origin, ray.direction, intersection.color, intersection.distance, fragCoord);
    } else {
        intersection.color = c_fogColorLit;
    }
}

uniform float gShockDistortion;    // 0 0 1 distortion
uniform float gExplodeDistortion;  // 0 0 1

vec2 distortion(vec2 uv) {
    float l = length(uv);
    // uv += 1.5 * uv * sin(l + beat * PIH);

    uv += -gShockDistortion * uv * cos(l);

    float explode = 30.0 * gExplodeDistortion * exp(-2.0 * l);
    explode = mix(explode, 2.0 * sin(l + 10.0 * gExplodeDistortion), 10.0 * gExplodeDistortion);
    uv += explode * uv;
    return uv;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord * 2.0 - iResolution.xy) / min(iResolution.x, iResolution.y);
    uv = distortion(uv);

    directionalLight = normalize(vec3(gDirectionalLightX, gDirectionalLightY, gDirectionalLightZ));

    camera.eye = vec3(gCameraEyeX, gCameraEyeY, gCameraEyeZ);
    camera.target = vec3(gCameraTargetX, gCameraTargetY, gCameraTargetZ);
    camera.up = vec3(0.0, 1.0, 0.0);  // y-up
    Ray ray = cameraShootRay(camera, uv);

    vec3 color = vec3(0.0);
    vec3 reflection = vec3(1.0);
    Intersection intersection;

    for (int bounce = 0; bounce < 2; bounce++) {
        calcRadiance(intersection, ray, fragCoord);
        color += reflection * intersection.color;
        if (!intersection.hit || intersection.reflectance == 0.0) break;

        reflection *= intersection.reflectance;
        ray.origin = intersection.position + intersection.normal * OFFSET;
        vec3 l = reflect(ray.direction, intersection.normal);
        reflection *= fresnelSchlick(gF0, dot(l, intersection.normal));
        ray.direction = l;
    }

    fragColor = vec4(color, 1.0);
}