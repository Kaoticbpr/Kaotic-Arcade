/*
   cabinet-crt.glsl  -  single-pass CRT look for the Arcade1Up cabinet
   ------------------------------------------------------------------
   Built for the cabinet's 1280x960 4:3 panel and the two cores the mod
   ships: FinalBurn Neo (CPS1/2/3, Neo Geo, Midway - 224..254 source
   lines) and Flycast (NAOMI - 480 source lines).

   The scanline phase is taken from the SOURCE line, not from the output
   pixel row, so the gaps land in the same place whether the game is
   scaled 2x (NAOMI 480 -> 960) or 4.28x (CPS2 224 -> 960).  A beam that
   is centred on the source line cannot do this: at an exact 2x scale the
   two output rows sit symmetrically either side of the line centre and
   get identical weight, which washes the effect out to a flat dim.
   Splitting each source line into a lit part and a gap part avoids that.

   One pass, five texture fetches.  Comfortable on the Mali-T860.
*/

#pragma parameter SCANLINE_WEIGHT "Scanline depth"     0.45 0.00 1.00 0.05
#pragma parameter BEAM_WIDTH      "Beam width"         0.55 0.20 1.00 0.05
#pragma parameter MASK_STRENGTH   "Aperture mask"      0.20 0.00 1.00 0.05
#pragma parameter SHARPNESS       "Pixel sharpness"    0.90 0.00 1.00 0.05
#pragma parameter GLOW            "Phosphor glow"      0.15 0.00 0.60 0.05
#pragma parameter BRIGHT_BOOST    "Brightness"         1.20 0.50 2.00 0.05

#if defined(VERTEX)

#if __VERSION__ >= 130
#define COMPAT_VARYING   out
#define COMPAT_ATTRIBUTE in
#else
#define COMPAT_VARYING   varying
#define COMPAT_ATTRIBUTE attribute
#endif

#ifdef GL_ES
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

COMPAT_ATTRIBUTE vec4 VertexCoord;
COMPAT_ATTRIBUTE vec4 COLOR;
COMPAT_ATTRIBUTE vec4 TexCoord;
COMPAT_VARYING   vec4 COL0;
COMPAT_VARYING   vec4 TEX0;

uniform mat4 MVPMatrix;
uniform COMPAT_PRECISION int  FrameDirection;
uniform COMPAT_PRECISION int  FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;

void main()
{
   gl_Position = MVPMatrix * VertexCoord;
   COL0    = COLOR;
   TEX0.xy = TexCoord.xy;
}

#elif defined(FRAGMENT)

#if __VERSION__ >= 130
#define COMPAT_VARYING in
#define COMPAT_TEXTURE texture
out vec4 FragColor;
#else
#define COMPAT_VARYING varying
#define COMPAT_TEXTURE texture2D
#define FragColor gl_FragColor
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

uniform sampler2D Texture;
COMPAT_VARYING vec4 TEX0;

uniform COMPAT_PRECISION int  FrameDirection;
uniform COMPAT_PRECISION int  FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;

#ifdef PARAMETER_UNIFORM
uniform COMPAT_PRECISION float SCANLINE_WEIGHT;
uniform COMPAT_PRECISION float BEAM_WIDTH;
uniform COMPAT_PRECISION float MASK_STRENGTH;
uniform COMPAT_PRECISION float SHARPNESS;
uniform COMPAT_PRECISION float GLOW;
uniform COMPAT_PRECISION float BRIGHT_BOOST;
#else
#define SCANLINE_WEIGHT 0.40
#define BEAM_WIDTH      0.55
#define MASK_STRENGTH   0.20
#define SHARPNESS       0.90
#define GLOW            0.15
#define BRIGHT_BOOST    1.20
#endif

void main()
{
   /* ---- sharp-bilinear sampling -------------------------------------
      Squeeze the bilinear ramp down to roughly one output pixel so the
      art stays crisp at the cabinet's non-integer 4.28x scale without
      the uneven pixel widths that plain nearest sampling would give.
      Needs filter_linear0 = "true" in the preset - the hardware does
      the actual blend, this only bends the coordinate.               */
   vec2 texel  = TEX0.xy * TextureSize;
   vec2 scale  = mix(vec2(1.0), max(floor(OutputSize / InputSize), vec2(1.0)), SHARPNESS);
   vec2 dist   = fract(texel) - 0.5;
   vec2 range  = 0.5 - 0.5 / scale;
   vec2 coord  = (floor(texel) + (dist - clamp(dist, -range, range)) * scale + 0.5) / TextureSize;

   vec3 col = COMPAT_TEXTURE(Texture, coord).rgb;

   /* ---- phosphor glow: a cheap horizontal smear, like a real tube --- */
   if (GLOW > 0.0)
   {
      float dx = 0.8 / TextureSize.x;
      vec3  l  = COMPAT_TEXTURE(Texture, coord - vec2(dx, 0.0)).rgb;
      vec3  r  = COMPAT_TEXTURE(Texture, coord + vec2(dx, 0.0)).rgb;
      col = mix(col, col * 0.5 + (l + r) * 0.25, GLOW);
   }

   col = pow(clamp(col, 0.0, 1.0), vec3(2.4));   /* to linear light */

   /* ---- scanlines ---------------------------------------------------
      Each source line is BEAM_WIDTH lit and the rest gap.  The soft
      edge is one output pixel wide so it antialiases itself at any
      scale factor instead of shimmering.                             */
   float vscale = max(OutputSize.y / InputSize.y, 1.0);
   float aa     = 0.5 / vscale;
   float gap    = smoothstep(BEAM_WIDTH - aa, BEAM_WIDTH + aa, fract(texel.y));
   col *= 1.0 - SCANLINE_WEIGHT * gap;

   /* ---- aperture grille: dim two of every three output columns ------ */
   if (MASK_STRENGTH > 0.0)
   {
      float i = floor(mod(gl_FragCoord.x, 3.0));
      vec3  m = vec3(step(abs(i - 0.0), 0.5),
                     step(abs(i - 1.0), 0.5),
                     step(abs(i - 2.0), 0.5));
      col *= mix(vec3(1.0), m, MASK_STRENGTH);
   }

   col *= BRIGHT_BOOST;
   col  = pow(clamp(col, 0.0, 1.0), vec3(1.0 / 2.2));   /* back to sRGB */

   FragColor = vec4(col, 1.0);
}

#endif
