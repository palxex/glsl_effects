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
float rcp(float x) { return 1.0/x; }

uniform COMPAT_PRECISION int FrameDirection;
uniform COMPAT_PRECISION int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;

COMPAT_VARYING vec2 v_texCoord;

uniform sampler2D tex0;

#line 61
COMPAT_PRECISION float inputPtX, inputPtY;

mat4 vec3x4(float a, float b, float c, float d, float e, float f, float g, float h, float i, float j, float k, float l)
{
	return mat4( a,b,c,d,e,f,g,h,i,j,k,l, 0.0, 0.0, 0.0, 0.0 );
}

void main() {
    vec2 pos=v_texCoord;
	vec4 target1, target2;
	inputPtX = rcp(OutputSize.x);
	inputPtY = rcp(OutputSize.y);

	// [ a, d, g ]
	// [ b, e, h ]
	// [ c, f, i ]
	vec4 a = COMPAT_TEXTURE(tex0, pos + vec2(-inputPtX, -inputPtY));
	vec4 b = COMPAT_TEXTURE(tex0, pos + vec2(-inputPtX, 0));
	vec4 c = COMPAT_TEXTURE(tex0, pos + vec2(-inputPtX, inputPtY));
	vec4 d = COMPAT_TEXTURE(tex0, pos + vec2(0, -inputPtY));
	vec4 e = COMPAT_TEXTURE(tex0, pos);
	vec4 f = COMPAT_TEXTURE(tex0, pos + vec2(0, inputPtY));
	vec4 g = COMPAT_TEXTURE(tex0, pos + vec2(inputPtX, -inputPtY));
	vec4 h = COMPAT_TEXTURE(tex0, pos + vec2(inputPtX, 0));
	vec4 i = COMPAT_TEXTURE(tex0, pos + vec2(inputPtX, inputPtY));

	target1 = vec3x4(-0.050913796, -0.05115213, -0.0205767, -0.26266688, -0.12883802, 0.107968464, 0.03389763, -0.70179373, 0.0030511466, 0.07718592, -0.06562523, -0.060305536) * a;
	target1 += mul(b, vec3x4(0.009235469, -0.018979615, 0.10033019, -0.20307243, 0.040932532, -0.10095427, 0.038843542, -0.28774044, -0.07829864, -0.04317961, 0.032555006, -0.05584433));
	target1 += mul(c, vec3x4(0.23774138, 0.04701499, -0.16824278, 0.025335955, 0.30246395, -0.037289508, 0.070405066, 0.03094164, -0.0075012813, 0.06881163, -0.03157643, -0.032394916));
	target1 += mul(d, vec3x4(-0.12524955, 0.18535072, -0.05323482, 0.004486272, 0.15295836, 0.3050709, 0.081431866, 0.09352846, -0.059866652, -0.029570978, 0.019920588, 0.121749535));
	target1 += mul(e, vec3x4(-0.2111615, -0.1268416, 0.45642895, 0.47401953, -0.7580866, 0.5514855, 0.96250856, 0.7827129, 0.0003978912, 0.17167407, -0.04423575, -0.04569368));
	target1 += mul(f, vec3x4(0.17050457, -0.18697786, -0.11608587, -0.038065948, 0.26542, -0.7021022, -0.33751717, 0.053689335, 0.10030526, -0.19492362, 0.069387496, 0.07228368));
	target1 += mul(g, vec3x4(0.15900351, -0.017636139, 0.01917807, 0.05584281, 0.28530255, 0.04795445, -0.104170926, 0.1192509, 0.09859251, 0.057123564, 0.025724344, -0.07723904));
	target1 += mul(h, vec3x4(-0.06581913, 0.07548721, -0.054552317, -0.08317343, 0.32851526, -0.2362575, -0.39470714, -0.073999345, 0.07246812, -0.04103072, 0.06058696, 0.09532553));
	target1 += mul(i, vec3x4(-0.12524493, 0.095179625, -0.0918538, 0.016793616, -0.48433152, 0.03702525, -0.100864686, -0.0018861603, -0.14784335, -0.048320837, -0.057494648, -0.024096634));
	target1 += vec4(-0.012922576, -0.11982956, 0.021963459, 0.019259451);
	
	target2 = mul(a, vec3x4(0.04816902, 0.030087546, 0.019183155, -0.08234757, 0.09378316, -0.047217257, -0.04757087, -0.16541782, -0.043394983, 0.05779227, 0.018105166, 0.03222583));
	target2 += mul(b, vec3x4(0.13639967, -0.001877575, 0.049495522, 0.060094353, 0.015303669, 0.059043188, 0.090356335, -0.12654372, 0.06469071, -0.054733396, -0.013548386, -0.093697555));
	target2 += mul(c, vec3x4(-0.13214277, 0.00062924915, -0.640379, -0.052121993, -0.022532608, 0.01077454, -0.057074178, -0.103670195, -0.0017062012, 0.0035225085, -0.044859786, -0.020764757));
	target2 += mul(d, vec3x4(0.2553945, -0.08126201, 0.055215932, 0.10690791, 0.6771195, 0.09377514, -0.09488318, -0.43969935, 0.35444704, -0.10392259, 0.07595239, 0.021814484));
	target2 += mul(e, vec3x4(-0.37628967, 0.026895085, 0.035044484, -0.16414654, -0.5694931, -0.20123884, 0.14891861, 1.1822934, -0.25648627, 0.14110301, -0.057699542, 0.17731132));
	target2 += mul(f, vec3x4(0.023089241, 0.14888923, -0.2730167, 0.1330048, -0.039043408, 0.75768983, 0.07385114, 0.0138615575, -0.06565686, 0.10451973, 0.037489507, 0.021156311));
	target2 += mul(g, vec3x4(0.03965048, 0.040422294, -0.0662493, -0.043219455, 0.00834316, -0.08315282, 0.13010995, -0.11822414, -0.06811034, 0.029744523, -0.098641835, -0.063671604));
	target2 += mul(h, vec3x4(-0.077282995, -0.29400682, 0.116103284, 0.096747644, -0.47398612, -0.77101594, -0.20683232, 0.111703634, -0.08370965, -0.24218678, 0.13780457, -0.017660126));
	target2 += mul(i, vec3x4(0.08542605, 0.13080615, 0.081582755, -0.00024888176, 0.31160986, 0.17787197, -0.019935975, -0.09658498, 0.096656196, 0.064402744, -0.033331197, 0.027531069));
	target2 += vec4(-0.0018859988, 0.004285429, 0.5060845, -0.030093472);

	gl_FragData[0] = vec4(COMPAT_TEXTURE(tex0, pos).rgb, 1.0);
	gl_FragData[1] = target1;
	gl_FragData[2] = target2;
}

#endif
