#if defined(VERTEX)
#if __VERSION__ >= 130
#define COMPAT_VARYING out
#define COMPAT_ATTRIBUTE in
#define COMPAT_TEXTURE texture
#else
#define COMPAT_VARYING varying
#define COMPAT_ATTRIBUTE attribute
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif
uniform mat4 MVPMatrix;
uniform COMPAT_PRECISION int FrameDirection;
uniform COMPAT_PRECISION int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;

COMPAT_ATTRIBUTE vec4 VertexCoord;
COMPAT_ATTRIBUTE vec4 TexCoord;

COMPAT_VARYING vec2 v_texCoord;

void main()
{
    gl_Position = MVPMatrix * VertexCoord;
    v_texCoord = TexCoord.xy;
}
#elif defined(FRAGMENT)
#if __VERSION__ >= 130
#define COMPAT_VARYING in
#define COMPAT_TEXTURE texture
out vec4 FragColor;
#else
#define COMPAT_VARYING varying
#define FragColor gl_FragColor
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

#define saturate(x) clamp(x,0,1)
#define rsqrt inversesqrt

uniform COMPAT_PRECISION int FrameDirection;
uniform COMPAT_PRECISION int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;


COMPAT_VARYING vec2 v_texCoord;

uniform sampler2D tex0;

#define min3(a, b, c) min(a, min(b, c))
#define max3(a, b, c) max(a, max(b, c))

// Filtering for a given tap for the scalar.
void FsrEasuTap(
	inout vec3 aC, // Accumulated color, with negative lobe.
	inout float aW, // Accumulated weight.
	vec2 off, // Pixel offset from resolve position to tap.
	vec2 dir, // Gradient direction.
	vec2 len, // Length.
	float lob, // Negative lobe strength.
	float clp, // Clipping point.
	vec3 c  // Tap color.
) {
	// Rotate offset by direction.
	vec2 v;
	v.x = (off.x * (dir.x)) + (off.y * dir.y);
	v.y = (off.x * (-dir.y)) + (off.y * dir.x);
	// Anisotropy.
	v *= len;
	// Compute distance^2.
	float d2 = v.x * v.x + v.y * v.y;
	// Limit to the window as at corner, 2 taps can easily be outside.
	d2 = min(d2, clp);
	// Approximation of lanczos2 without sin() or rcp(), or sqrt() to get x.
	//  (25/16 * (2/5 * x^2 - 1)^2 - (25/16 - 1)) * (1/4 * x^2 - 1)^2
	//  |_______________________________________|   |_______________|
	//                   base                             window
	// The general form of the 'base' is,
	//  (a*(b*x^2-1)^2-(a-1))
	// Where 'a=1/(2*b-b^2)' and 'b' moves around the negative lobe.
	float wB = 2.0f / 5.0f * d2 - 1;
	float wA = lob * d2 - 1;
	wB *= wB;
	wA *= wA;
	wB = 25.0f / 16.0f * wB - (25.0f / 16.0f - 1.0f);
	float w = wB * wA;
	// Do weighted average.
	aC += c * w; aW += w;
}

// Accumulate direction and length.
void FsrEasuSet(
	inout vec2 dir,
	inout float len,
	vec2 pp,
	bool biS, bool biT, bool biU, bool biV,
	float lA, float lB, float lC, float lD, float lE) {
	// Compute bilinear weight, branches factor out as predicates are compiler time immediates.
	//  s t
	//  u v
	float w = 0;
	if (biS)w = (1 - pp.x) * (1 - pp.y);
	if (biT)w = pp.x * (1 - pp.y);
	if (biU)w = (1.0 - pp.x) * pp.y;
	if (biV)w = pp.x * pp.y;
	// Direction is the '+' diff.
	//    a
	//  b c d
	//    e
	// Then takes magnitude from abs average of both sides of 'c'.
	// Length converts gradient reversal to 0, smoothly to non-reversal at 1, shaped, then adding horz and vert terms.
	float dc = lD - lC;
	float cb = lC - lB;
	float lenX = max(abs(dc), abs(cb));
	lenX = rcp(lenX);
	float dirX = lD - lB;
	dir.x += dirX * w;
	lenX = saturate(abs(dirX) * lenX);
	lenX *= lenX;
	len += lenX * w;
	// Repeat for the y axis.
	float ec = lE - lC;
	float ca = lC - lA;
	float lenY = max(abs(ec), abs(ca));
	lenY = rcp(lenY);
	float dirY = lE - lA;
	dir.y += dirY * w;
	lenY = saturate(abs(dirY) * lenY);
	lenY *= lenY;
	len += lenY * w;
}

void main() {
	vec2 pos = v_texCoord;
	vec2 inputSize = InputSize;
	vec2 outputSize = OutputSize;

	//------------------------------------------------------------------------------------------------------------------------------
	  // Get position of 'f'.
	vec2 pp = (floor(pos * outputSize) + 0.5f) / outputSize * inputSize - 0.5f;
	vec2 fp = floor(pp);
	pp -= fp;
	//------------------------------------------------------------------------------------------------------------------------------
	  // 12-tap kernel.
	  //    b c
	  //  e f g h
	  //  i j k l
	  //    n o
	  // Gather 4 ordering.
	  //  a b
	  //  r g
	  // For packed FP16, need either {rg} or {ab} so using the following setup for gather in all versions,
	  //    a b    <- unused (z)
	  //    r g
	  //  a b a b
	  //  r g r g
	  //    a b
	  //    r g    <- unused (z)
	  // Allowing dead-code removal to remove the 'z's.
	vec2 p0 = fp + vec2(1, -1);
	// These are from p0 to avoid pulling two constants on pre-Navi hardware.
	vec2 p1 = p0 + vec2(-1, 2);
	vec2 p2 = p0 + vec2(1, 2);
	vec2 p3 = p0 + vec2(0, 4);

	p0 /= inputSize;
	p1 /= inputSize;
	p2 /= inputSize;
	p3 /= inputSize;

	vec4 bczzR = textureGather(tex0, p0, 0);
	vec4 bczzG = textureGather(tex0, p0, 1);
	vec4 bczzB = textureGather(tex0, p0, 2);
	vec4 ijfeR = textureGather(tex0, p1, 0);
	vec4 ijfeG = textureGather(tex0, p1, 1);
	vec4 ijfeB = textureGather(tex0, p1, 2);
	vec4 klhgR = textureGather(tex0, p2, 0);
	vec4 klhgG = textureGather(tex0, p2, 1);
	vec4 klhgB = textureGather(tex0, p2, 2);
	vec4 zzonR = textureGather(tex0, p3, 0);
	vec4 zzonG = textureGather(tex0, p3, 1);
	vec4 zzonB = textureGather(tex0, p3, 2);
	//------------------------------------------------------------------------------------------------------------------------------
	  // Simplest multi-channel approximate luma possible (luma times 2, in 2 FMA/MAD).
	vec4 bczzL = bczzB * 0.5 + (bczzR * 0.5 + bczzG);
	vec4 ijfeL = ijfeB * 0.5 + (ijfeR * 0.5 + ijfeG);
	vec4 klhgL = klhgB * 0.5 + (klhgR * 0.5 + klhgG);
	vec4 zzonL = zzonB * 0.5 + (zzonR * 0.5 + zzonG);
	// Rename.
	float bL = bczzL.x;
	float cL = bczzL.y;
	float iL = ijfeL.x;
	float jL = ijfeL.y;
	float fL = ijfeL.z;
	float eL = ijfeL.w;
	float kL = klhgL.x;
	float lL = klhgL.y;
	float hL = klhgL.z;
	float gL = klhgL.w;
	float oL = zzonL.z;
	float nL = zzonL.w;
	// Accumulate for bilinear interpolation.
	vec2 dir = {0, 0};
	float len = 0;
	FsrEasuSet(dir, len, pp, true, false, false, false, bL, eL, fL, gL, jL);
	FsrEasuSet(dir, len, pp, false, true, false, false, cL, fL, gL, hL, kL);
	FsrEasuSet(dir, len, pp, false, false, true, false, fL, iL, jL, kL, nL);
	FsrEasuSet(dir, len, pp, false, false, false, true, gL, jL, kL, lL, oL);
	//------------------------------------------------------------------------------------------------------------------------------
	  // Normalize with approximation, and cleanup close to zero.
	vec2 dir2 = dir * dir;
	float dirR = dir2.x + dir2.y;
	bool zro = dirR < 1.0f / 32768.0f;
	dirR = rsqrt(dirR);
	dirR = zro ? 1 : dirR;
	dir.x = zro ? 1 : dir.x;
	dir *= dirR;
	// Transform from {0 to 2} to {0 to 1} range, and shape with square.
	len = len * 0.5;
	len *= len;
	// Stretch kernel {1.0 vert|horz, to sqrt(2.0) on diagonal}.
	float stretch = (dir.x * dir.x + dir.y * dir.y) * rcp(max(abs(dir.x), abs(dir.y)));
	// Anisotropic length after rotation,
	//  x := 1.0 lerp to 'stretch' on edges
	//  y := 1.0 lerp to 2x on edges
	vec2 len2 = { 1 + (stretch - 1) * len, 1 - 0.5 * len };
	// Based on the amount of 'edge',
	// the window shifts from +/-{sqrt(2.0) to slightly beyond 2.0}.
	float lob = 0.5 + ((1.0 / 4.0 - 0.04) - 0.5) * len;
	// Set distance^2 clipping point to the end of the adjustable window.
	float clp = rcp(lob);
	//------------------------------------------------------------------------------------------------------------------------------
	  // Accumulation mixed with min/max of 4 nearest.
	  //    b c
	  //  e f g h
	  //  i j k l
	  //    n o
	vec3 min4 = min(min3(vec3(ijfeR.z, ijfeG.z, ijfeB.z), vec3(klhgR.w, klhgG.w, klhgB.w), vec3(ijfeR.y, ijfeG.y, ijfeB.y)),
		vec3(klhgR.x, klhgG.x, klhgB.x));
	vec3 max4 = max(max3(vec3(ijfeR.z, ijfeG.z, ijfeB.z), vec3(klhgR.w, klhgG.w, klhgB.w), vec3(ijfeR.y, ijfeG.y, ijfeB.y)),
		vec3(klhgR.x, klhgG.x, klhgB.x));
	// Accumulation.
	vec3 aC = {0,0,0};
	float aW = 0;
	FsrEasuTap(aC, aW, vec2(0.0, -1.0) - pp, dir, len2, lob, clp, vec3(bczzR.x, bczzG.x, bczzB.x)); // b
	FsrEasuTap(aC, aW, vec2(1.0, -1.0) - pp, dir, len2, lob, clp, vec3(bczzR.y, bczzG.y, bczzB.y)); // c
	FsrEasuTap(aC, aW, vec2(-1.0, 1.0) - pp, dir, len2, lob, clp, vec3(ijfeR.x, ijfeG.x, ijfeB.x)); // i
	FsrEasuTap(aC, aW, vec2(0.0, 1.0) - pp, dir, len2, lob, clp, vec3(ijfeR.y, ijfeG.y, ijfeB.y)); // j
	FsrEasuTap(aC, aW, vec2(0.0, 0.0) - pp, dir, len2, lob, clp, vec3(ijfeR.z, ijfeG.z, ijfeB.z)); // f
	FsrEasuTap(aC, aW, vec2(-1.0, 0.0) - pp, dir, len2, lob, clp, vec3(ijfeR.w, ijfeG.w, ijfeB.w)); // e
	FsrEasuTap(aC, aW, vec2(1.0, 1.0) - pp, dir, len2, lob, clp, vec3(klhgR.x, klhgG.x, klhgB.x)); // k
	FsrEasuTap(aC, aW, vec2(2.0, 1.0) - pp, dir, len2, lob, clp, vec3(klhgR.y, klhgG.y, klhgB.y)); // l
	FsrEasuTap(aC, aW, vec2(2.0, 0.0) - pp, dir, len2, lob, clp, vec3(klhgR.z, klhgG.z, klhgB.z)); // h
	FsrEasuTap(aC, aW, vec2(1.0, 0.0) - pp, dir, len2, lob, clp, vec3(klhgR.w, klhgG.w, klhgB.w)); // g
	FsrEasuTap(aC, aW, vec2(1.0, 2.0) - pp, dir, len2, lob, clp, vec3(zzonR.z, zzonG.z, zzonB.z)); // o
	FsrEasuTap(aC, aW, vec2(0.0, 2.0) - pp, dir, len2, lob, clp, vec3(zzonR.w, zzonG.w, zzonB.w)); // n
  //------------------------------------------------------------------------------------------------------------------------------
	// Normalize and dering.
	vec3 c = min(max4, max(min4, aC * rcp(aW)));

	FragColor = vec4(c, 1.0f);
}
#endif