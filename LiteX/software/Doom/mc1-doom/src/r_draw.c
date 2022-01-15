// Emacs style mode select   -*- C++ -*-
//-----------------------------------------------------------------------------
//
// Copyright (C) 1993-1996 by id Software, Inc.
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// DESCRIPTION:
//      The actual span/column drawing functions.
//      Here find the main potential for optimization,
//       e.g. inline assembly, different algorithms.
//
//-----------------------------------------------------------------------------

#include "doomdef.h"

#include "i_system.h"
#include "z_zone.h"
#include "w_wad.h"

#include "r_local.h"

// Needs access to LFB (guess what).
#include "v_video.h"

// State.
#include "doomstat.h"

// status bar height at bottom of screen
#define SBARHEIGHT              32

//
// All drawing to the view buffer is accomplished in this file.
// The other refresh files only know about ccordinates,
//  not the architecture of the frame buffer.
// Conveniently, the frame buffer is a linear one,
//  and we need only the base address,
//  and the total size == width*height*depth/8.,
//

byte*           viewimage;
int             viewwidth;
int             scaledviewwidth;
int             viewheight;
int             viewwindowx;
int             viewwindowy;
byte*           ylookup[SCREENHEIGHT];
int             columnofs[SCREENWIDTH];

// Color tables for different players,
//  translate a limited part to another
//  (color ramps used for  suit colors).
//
byte            translations[3][256];

#define FUZZTABLE 50
#define FUZZOFF (SCREENWIDTH)

const int fuzzoffset[FUZZTABLE] =
    {
        FUZZOFF,-FUZZOFF,FUZZOFF,-FUZZOFF,FUZZOFF,FUZZOFF,-FUZZOFF,
        FUZZOFF,FUZZOFF,-FUZZOFF,FUZZOFF,FUZZOFF,FUZZOFF,-FUZZOFF,
        FUZZOFF,FUZZOFF,FUZZOFF,-FUZZOFF,-FUZZOFF,-FUZZOFF,-FUZZOFF,
        FUZZOFF,-FUZZOFF,-FUZZOFF,FUZZOFF,FUZZOFF,FUZZOFF,FUZZOFF,-FUZZOFF,
        FUZZOFF,-FUZZOFF,FUZZOFF,FUZZOFF,-FUZZOFF,-FUZZOFF,FUZZOFF,
        FUZZOFF,-FUZZOFF,-FUZZOFF,-FUZZOFF,-FUZZOFF,FUZZOFF,FUZZOFF,
        FUZZOFF,FUZZOFF,-FUZZOFF,FUZZOFF,FUZZOFF,-FUZZOFF,FUZZOFF
};

//
// R_DrawColumnKernel - Implementation of the core column drawing loop.
// Inner loop that does the actual texture mapping, e.g. a DDA-line scaling.
// This is as fast as it gets.
//
// Note: R_DrawColumnKernel is the top CPU consumer, and about twice as much
// time is spent in R_DrawColumnKernel as in R_DrawSpanKernel (the second
// CPU consumer). If you want to optimize Doom performance - here is where to
// put your effort.
//

static void R_DrawColumnKernel (byte* dst,
                                const byte* const src,
                                const lighttable_t* const colormap,
                                fixed_t frac,
                                const fixed_t fracstep,
                                const int count)
{
#if defined(__MRISC32_VECTOR_OPS__)
    // This vectorized routine takes <7 clock-cycles per pixel.
    const unsigned stride = SCREENWIDTH;
    unsigned count_left, fracstepN, dst_incr;
    byte* dst_ptr;
    __asm__ volatile(
        "    blt     %[count], 2f\n"
        "    add     %[count_left], %[count], #1\n"
        "    getsr   vl, #0x10\n"
        "    mov     %[dst_ptr], %[dst]\n"
        "    mul     %[fracstepN], vl, %[fracstep]\n"
        "    mul     %[dst_incr], vl, %[stride]\n"
        "    ldea    v1, [%[frac], %[fracstep]]\n"
        "1:\n"
        "    min     vl, vl, %[count_left]\n"
        "    sub     %[count_left], %[count_left], vl\n"
        "    ebfu    v2, v1, #<16:7>\n"
        "    ldub    v2, [%[src], v2]\n"
        "    ldub    v2, [%[colormap], v2]\n"
        "    stb     v2, [%[dst_ptr], %[stride]]\n"
        "    ldea    %[dst_ptr], [%[dst_ptr], %[dst_incr]]\n"
        "    add     v1, v1, %[fracstepN]\n"
        "    bnz     %[count_left], 1b\n"
        "2:"
        : [count_left] "=&r"(count_left),
          [fracstepN] "=&r"(fracstepN),
          [dst_incr] "=&r"(dst_incr),
          [dst_ptr] "=&r"(dst_ptr)
        : [dst] "r"(dst),
          [src] "r"(src),
          [colormap] "r"(colormap),
          [frac] "r"(frac),
          [fracstep] "r"(fracstep),
          [count] "r"(count),
          [stride] "r"(stride)
        : "vl", "v1", "v2"
    );
#else
    for (int i = count; i >= 0; --i)
    {
        // Current texture index. All wall textures are 128 high.
        int idx = (frac >> FRACBITS) & 127;

        // Re-map color indices from wall texture column using a
        // lighting/special effects LUT.
        *dst = colormap[src[idx]];
        dst += SCREENWIDTH;

        // Next fractional step.
        frac += fracstep;
    }
#endif
}

//
// R_DrawFuzzColumnKernel - Implementation of the core column fuzzing loop.
//

static int R_DrawFuzzColumnKernel (byte* dst, int fuzz, const int count)
{
    // TODO(m): Can we vectorize this?
    const lighttable_t* colormap = &colormaps[6*256];
    for (int i = count; i >= 0; --i)
    {
        // Lookup framebuffer, and retrieve a pixel that is either one column
        // left or right of the current one. Add index from colormap to index.
        *dst = colormap[dst[fuzzoffset[fuzz]]];
        dst += SCREENWIDTH;

        // Clamp table lookup index.
        if (++fuzz == FUZZTABLE)
            fuzz = 0;
    }
    return fuzz;
}

//
// R_DrawFuzzColumnKernel - Implementation of the core translated column loop.
//

static void R_DrawTranslatedColumnKernel (byte* dst,
                                          const byte* const src,
                                          const byte* const translation,
                                          const lighttable_t* const colormap,
                                          fixed_t frac,
                                          const fixed_t fracstep,
                                          const int count)
{
#if defined(__MRISC32_VECTOR_OPS__)
    // This vectorized routine takes <7 clock-cycles per pixel.
    const unsigned stride = SCREENWIDTH;
    unsigned count_left, fracstepN, dst_incr;
    byte* dst_ptr;
    __asm__ volatile(
        "    blt     %[count], 2f\n"
        "    add     %[count_left], %[count], #1\n"
        "    getsr   vl, #0x10\n"
        "    mov     %[dst_ptr], %[dst]\n"
        "    mul     %[fracstepN], vl, %[fracstep]\n"
        "    mul     %[dst_incr], vl, %[stride]\n"
        "    ldea    v1, [%[frac], %[fracstep]]\n"
        "1:\n"
        "    min     vl, vl, %[count_left]\n"
        "    sub     %[count_left], %[count_left], vl\n"
        "    asr     v2, v1, #16\n"
        "    ldub    v2, [%[src], v2]\n"
        "    ldub    v2, [%[translation], v2]\n"
        "    ldub    v2, [%[colormap], v2]\n"
        "    stb     v2, [%[dst_ptr], %[stride]]\n"
        "    ldea    %[dst_ptr], [%[dst_ptr], %[dst_incr]]\n"
        "    add     v1, v1, %[fracstepN]\n"
        "    bnz     %[count_left], 1b\n"
        "2:"
        : [count_left] "=&r"(count_left),
          [fracstepN] "=&r"(fracstepN),
          [dst_incr] "=&r"(dst_incr),
          [dst_ptr] "=&r"(dst_ptr)
        : [dst] "r"(dst),
          [src] "r"(src),
          [colormap] "r"(colormap),
          [translation] "r"(translation),
          [frac] "r"(frac),
          [fracstep] "r"(fracstep),
          [count] "r"(count),
          [stride] "r"(stride)
        : "vl", "v1", "v2"
        );
#else
    for (int i = count; i >= 0; --i)
    {
        // Current texture index. No clamping to 128 height?
        int idx = frac >> FRACBITS;

        // Here we do an additional index re-mapping.
        // Translation tables are used to map certain colorramps to other ones,
        // used with PLAY sprites. Thus the "green" ramp of the player 0 sprite
        // is mapped to gray, red, black/indigo.
        *dst = colormap[translation[src[idx]]];
        dst += SCREENWIDTH;

        // Next fractional step.
        frac += fracstep;
    }
#endif
}

//
// R_DrawSpanKernel - Implementation of the core span drawing loop.
//

static void R_DrawSpanKernel (byte* dst,
                              const byte* const src,
                              const lighttable_t* const colormap,
                              fixed_t xfrac,
                              const fixed_t xfracstep,
                              fixed_t yfrac,
                              const fixed_t yfracstep,
                              const int count)
{
#if defined(__MRISC32_VECTOR_OPS__)
    // This vectorized routine takes <11 clock-cycles per pixel.
    unsigned count_left, xfracstepN, yfracstepN;
    byte* dst_ptr;
    __asm__ volatile(
        "    blt     %[count], 2f\n"
        "    add     %[count_left], %[count], #1\n"
        "    getsr   vl, #0x10\n"
        "    mov     %[dst_ptr], %[dst]\n"
        "    mul     %[xfracstepN], vl, %[xfracstep]\n"
        "    mul     %[yfracstepN], vl, %[yfracstep]\n"
        "    ldea    v1, [%[xfrac], %[xfracstep]]\n"
        "    ldea    v2, [%[yfrac], %[yfracstep]]\n"
        "1:\n"
        "    min     vl, vl, %[count_left]\n"
        "    sub     %[count_left], %[count_left], vl\n"
        "    ebfu    v3, v1, #<16:6>\n"
        "    lsr     v4, v2, #16\n"
        "    ibf     v3, v4, #<6:6>\n"
        "    ldub    v3, [%[src], v3]\n"
        "    ldub    v3, [%[colormap], v3]\n"
        "    stb     v3, [%[dst_ptr], #1]\n"
        "    ldea    %[dst_ptr], [%[dst_ptr], vl]\n"
        "    add     v1, v1, %[xfracstepN]\n"
        "    add     v2, v2, %[yfracstepN]\n"
        "    bnz     %[count_left], 1b\n"
        "2:"
        : [count_left] "=&r"(count_left),
          [xfracstepN] "=&r"(xfracstepN),
          [yfracstepN] "=&r"(yfracstepN),
          [dst_ptr] "=&r"(dst_ptr)
        : [dst] "r"(dst),
          [src] "r"(src),
          [colormap] "r"(colormap),
          [xfrac] "r"(xfrac),
          [xfracstep] "r"(xfracstep),
          [yfrac] "r"(yfrac),
          [yfracstep] "r"(yfracstep),
          [count] "r"(count)
        : "vl", "v1", "v2", "v3", "v4"
        );
#else
    for (int i = count; i >= 0; --i)
    {
        // Current texture index in u,v. All floor textures are 64x64 in size.
        int idx = ((yfrac >> (16 - 6)) & (63 * 64)) + ((xfrac >> 16) & 63);

        // Lookup pixel from flat texture tile, re-index using light/colormap.
        *dst++ = colormap[src[idx]];

        // Next step in u,v.
        xfrac += xfracstep;
        yfrac += yfracstep;
    }
#endif
}

//
// R_DrawColumn
// Source is the top of the column to scale.
//
lighttable_t*           dc_colormap;
int                     dc_x;
int                     dc_yl;
int                     dc_yh;
fixed_t                 dc_iscale;
fixed_t                 dc_texturemid;

// first pixel in a column (possibly virtual)
byte*                   dc_source;

// just for profiling
int                     dccount;

//
// A column is a vertical slice/span from a wall texture that,
//  given the DOOM style restrictions on the view orientation,
//  will always have constant z depth.
// Thus a special case loop for very fast rendering can
//  be used. It has also been used with Wolfenstein 3D.
//
void R_DrawColumn (void)
{
    int                 count;
    byte*               dest;
    fixed_t             frac;
    fixed_t             fracstep;

    count = dc_yh - dc_yl;
    if (count < 0)
        return;

#ifdef RANGECHECK
    if ((unsigned)dc_x >= SCREENWIDTH
        || dc_yl < 0
        || dc_yh >= SCREENHEIGHT)
        I_Error ("R_DrawColumn: %i to %i at %i", dc_yl, dc_yh, dc_x);
#endif

    // Framebuffer destination address.
    // Use ylookup LUT to avoid multiply with ScreenWidth.
    // Use columnofs LUT for subwindows?
    dest = ylookup[dc_yl] + columnofs[dc_x];

    // Determine scaling,
    //  which is the only mapping to be done.
    fracstep = dc_iscale;
    frac = dc_texturemid + (dc_yl-centery)*fracstep;

    R_DrawColumnKernel (dest, dc_source, dc_colormap, frac, fracstep, count);
}

//
// Spectre/Invisibility.
//

//
// Framebuffer postprocessing.
// Creates a fuzzy image by copying pixels
//  from adjacent ones to left and right.
// Used with an all black colormap, this
//  could create the SHADOW effect,
//  i.e. spectres and invisible players.
//
void R_DrawFuzzColumn (void)
{
    static int          fuzzpos;
    int                 count;
    byte*               dest;

    // Adjust borders. Low...
    if (!dc_yl)
        dc_yl = 1;

    // .. and high.
    if (dc_yh == viewheight-1)
        dc_yh = viewheight - 2;

    count = dc_yh - dc_yl;
    if (count < 0)
        return;

#ifdef RANGECHECK
    if ((unsigned)dc_x >= SCREENWIDTH
        || dc_yl < 0 || dc_yh >= SCREENHEIGHT)
    {
        I_Error ("R_DrawFuzzColumn: %i to %i at %i",
                 dc_yl, dc_yh, dc_x);
    }
#endif

    // Does not work with blocky mode.
    dest = ylookup[dc_yl] + columnofs[dc_x];

    fuzzpos = R_DrawFuzzColumnKernel(dest, fuzzpos, count);
}

//
// R_DrawTranslatedColumn
// Used to draw player sprites
//  with the green colorramp mapped to others.
// Could be used with different translation
//  tables, e.g. the lighter colored version
//  of the BaronOfHell, the HellKnight, uses
//  identical sprites, kinda brightened up.
//
byte*   dc_translation;
byte*   translationtables;

void R_DrawTranslatedColumn (void)
{
    int                 count;
    byte*               dest;
    fixed_t             frac;
    fixed_t             fracstep;

    count = dc_yh - dc_yl;
    if (count < 0)
        return;

#ifdef RANGECHECK
    if ((unsigned)dc_x >= SCREENWIDTH
        || dc_yl < 0
        || dc_yh >= SCREENHEIGHT)
    {
        I_Error ( "R_DrawColumn: %i to %i at %i",
                  dc_yl, dc_yh, dc_x);
    }
#endif

    // FIXME. As above.
    dest = ylookup[dc_yl] + columnofs[dc_x];

    // Looks familiar.
    fracstep = dc_iscale;
    frac = dc_texturemid + (dc_yl-centery)*fracstep;

    R_DrawTranslatedColumnKernel (
        dest, dc_source, dc_translation, dc_colormap, frac, fracstep, count);
}

//
// R_InitTranslationTables
// Creates the translation tables to map
//  the green color ramp to gray, brown, red.
// Assumes a given structure of the PLAYPAL.
// Could be read from a lump instead.
//
void R_InitTranslationTables (void)
{
    int         i;

    translationtables = Z_Malloc (256*3+255, PU_STATIC, 0);
    translationtables = (byte *)(( (size_t)translationtables + 255 ) & ~(size_t)255);

    // translate just the 16 green colors
    for (i=0 ; i<256 ; i++)
    {
        if (i >= 0x70 && i<= 0x7f)
        {
            // map green ramp to gray, brown, red
            translationtables[i] = 0x60 + (i&0xf);
            translationtables [i+256] = 0x40 + (i&0xf);
            translationtables [i+512] = 0x20 + (i&0xf);
        }
        else
        {
            // Keep all other colors as is.
            translationtables[i] = translationtables[i+256]
                = translationtables[i+512] = i;
        }
    }
}

//
// R_DrawSpan
// With DOOM style restrictions on view orientation,
//  the floors and ceilings consist of horizontal slices
//  or spans with constant z depth.
// However, rotation around the world z axis is possible,
//  thus this mapping, while simpler and faster than
//  perspective correct texture mapping, has to traverse
//  the texture at an angle in all but a few cases.
// In consequence, flats are not stored by column (like walls),
//  and the inner loop has to step in texture space u and v.
//
int                     ds_y;
int                     ds_x1;
int                     ds_x2;

lighttable_t*           ds_colormap;

fixed_t                 ds_xfrac;
fixed_t                 ds_yfrac;
fixed_t                 ds_xstep;
fixed_t                 ds_ystep;

// start of a 64*64 tile image
byte*                   ds_source;

// just for profiling
int                     dscount;

//
// Draws the actual span.
void R_DrawSpan (void)
{
    fixed_t             xfrac;
    fixed_t             yfrac;
    byte*               dest;
    int                 count;

#ifdef RANGECHECK
    if (ds_x2 < ds_x1
        || ds_x1<0
        || ds_x2>=SCREENWIDTH
        || (unsigned)ds_y>SCREENHEIGHT)
    {
        I_Error( "R_DrawSpan: %i to %i at %i",
                 ds_x1,ds_x2,ds_y);
    }
//      dscount++;
#endif

    count = ds_x2 - ds_x1;

    // Zero length.
    if (count < 0)
        return;

    xfrac = ds_xfrac;
    yfrac = ds_yfrac;

    dest = ylookup[ds_y] + columnofs[ds_x1];

    R_DrawSpanKernel (
        dest, ds_source, ds_colormap, xfrac, ds_xstep, yfrac, ds_ystep, count);
}

//
// R_InitBuffer
// Creats lookup tables that avoid
//  multiplies and other hazzles
//  for getting the framebuffer address
//  of a pixel to draw.
//
void
R_InitBuffer
( int           width,
  int           height )
{
    int         i;

    // Handle resize,
    //  e.g. smaller view windows
    //  with border and/or status bar.
    viewwindowx = (SCREENWIDTH-width) >> 1;

    // Column offset. For windows.
    for (i=0 ; i<width ; i++)
        columnofs[i] = viewwindowx + i;

    // Samw with base row offset.
    if (width == SCREENWIDTH)
        viewwindowy = 0;
    else
        viewwindowy = (SCREENHEIGHT-SBARHEIGHT-height) >> 1;

    // Preclaculate all row offsets.
    for (i=0 ; i<height ; i++)
        ylookup[i] = screens[0] + (i+viewwindowy)*SCREENWIDTH;
}

//
// R_FillBackScreen
// Fills the back screen with a pattern
//  for variable screen sizes
// Also draws a beveled edge.
//
void R_FillBackScreen (void)
{
    byte*       src;
    byte*       dest;
    int         x;
    int         y;
    patch_t*    patch;

    // DOOM border patch.
    char        name1[] = "FLOOR7_2";

    // DOOM II border patch.
    char        name2[] = "GRNROCK";

    char*       name;

    if (scaledviewwidth == SCREENWIDTH)
        return;

    if ( gamemode == commercial)
        name = name2;
    else
        name = name1;

    src = W_CacheLumpName (name, PU_CACHE);
    dest = screens[1];

    for (y=0 ; y<SCREENHEIGHT-SBARHEIGHT ; y++)
    {
        for (x=0 ; x<SCREENWIDTH/64 ; x++)
        {
            memcpy (dest, src+((y&63)<<6), 64);
            dest += 64;
        }

        if (SCREENWIDTH&63)
        {
            memcpy (dest, src+((y&63)<<6), SCREENWIDTH&63);
            dest += (SCREENWIDTH&63);
        }
    }

    patch = W_CacheLumpName ("brdr_t",PU_CACHE);

    for (x=0 ; x<scaledviewwidth ; x+=8)
        V_DrawPatch (viewwindowx+x,viewwindowy-8,1,patch);
    patch = W_CacheLumpName ("brdr_b",PU_CACHE);

    for (x=0 ; x<scaledviewwidth ; x+=8)
        V_DrawPatch (viewwindowx+x,viewwindowy+viewheight,1,patch);
    patch = W_CacheLumpName ("brdr_l",PU_CACHE);

    for (y=0 ; y<viewheight ; y+=8)
        V_DrawPatch (viewwindowx-8,viewwindowy+y,1,patch);
    patch = W_CacheLumpName ("brdr_r",PU_CACHE);

    for (y=0 ; y<viewheight ; y+=8)
        V_DrawPatch (viewwindowx+scaledviewwidth,viewwindowy+y,1,patch);

    // Draw beveled edge.
    V_DrawPatch (viewwindowx-8,
                 viewwindowy-8,
                 1,
                 W_CacheLumpName ("brdr_tl",PU_CACHE));

    V_DrawPatch (viewwindowx+scaledviewwidth,
                 viewwindowy-8,
                 1,
                 W_CacheLumpName ("brdr_tr",PU_CACHE));

    V_DrawPatch (viewwindowx-8,
                 viewwindowy+viewheight,
                 1,
                 W_CacheLumpName ("brdr_bl",PU_CACHE));

    V_DrawPatch (viewwindowx+scaledviewwidth,
                 viewwindowy+viewheight,
                 1,
                 W_CacheLumpName ("brdr_br",PU_CACHE));
}

//
// Copy a screen buffer.
//
void
R_VideoErase
( unsigned      ofs,
  int           count )
{
  // LFB copy.
  // This might not be a good idea if memcpy
  //  is not optiomal, e.g. byte by byte on
  //  a 32bit CPU, as GNU GCC/Linux libc did
  //  at one point.
    memcpy (screens[0]+ofs, screens[1]+ofs, count);
}

//
// R_DrawViewBorder
// Draws the border around the view
//  for different size windows?
//
void
V_MarkRect
( int           x,
  int           y,
  int           width,
  int           height );

void R_DrawViewBorder (void)
{
    int         top;
    int         side;
    int         ofs;
    int         i;

    if (scaledviewwidth == SCREENWIDTH)
        return;

    top = ((SCREENHEIGHT-SBARHEIGHT)-viewheight)/2;
    side = (SCREENWIDTH-scaledviewwidth)/2;

    // copy top and one line of left side
    R_VideoErase (0, top*SCREENWIDTH+side);

    // copy one line of right side and bottom
    ofs = (viewheight+top)*SCREENWIDTH-side;
    R_VideoErase (ofs, top*SCREENWIDTH+side);

    // copy sides using wraparound
    ofs = top*SCREENWIDTH + SCREENWIDTH-side;
    side <<= 1;

    for (i=1 ; i<viewheight ; i++)
    {
        R_VideoErase (ofs, side);
        ofs += SCREENWIDTH;
    }

    // ?
    V_MarkRect (0,0,SCREENWIDTH, SCREENHEIGHT-SBARHEIGHT);
}

