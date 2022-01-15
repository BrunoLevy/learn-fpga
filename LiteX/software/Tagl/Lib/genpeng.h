/*
 * This software is copyrighted as noted below.  It may be freely copied,
 * modified, and redistributed, provided that the copyright notice is
 * preserved on all copies.
 *
 * There is no warranty or other guarantee of fitness for this software,
 * it is provided solely "as is".  Bug reports or fixes may be sent
 * to the author, who may or may not act on them as he desires.
 *
 * You may not include this software in a program or other software product
 * without supplying the source, or without informing the end-user that the
 * source is available for no extra charge.
 *
 * If you modify this software, you should include a notice giving the
 * name of the person performing the modification, the date of modification,
 * and the reason for such modification.
 *
 * Author:      Bruno Levy
 *
 * Copyright (c) 1996, Bruno Levy.
 *
 */

/*
 *
 * generic polygon engine
 *
 * types to be defined:
 * 
 * o unsigned long
 *
 * macros to be defined:
 *
 * o GENPE_CLASS              (class name)
 * o GENPE_BYTES_PER_PIXEL
 * o GENPE_R_MASK            (will be auto-     )
 * o GENPE_G_MASK            (matically defined )
 * o GENPE_B_MASK            (if not given      )
 * o GENPE_R_SHIFT
 * o GENPE_G_SHIFT
 * o GENPE_B_SHIFT
 * o GENPE_RGB_SHIFT
 * o GENPE_RGB_MASK
 *
 * o GENPE_RGB_DITHER         (perform rgb dithering)
 * o GENPE_RGB_DSHIFT         (shift color comps before dithering)
 * o GENPE_RGB_DFORCE         (force dithering in rgb)
 * o GENPE_PRECISION_OVERRIDE (if needed)
 * o GENPE_BGR_CUMUL          (optionnal)  
 *
 * o GENPE_RGB_INDIRECT       (rgb ColorCode is a colormap index)
 * 
 */

#include <stdio.h>
#include "polyeng.h"

// compute canonical values

#ifndef GENPE_R_MASK
#define GENPE_R_MASK (((UColorCode)(GENPE_RGB_MASK)) << GENPE_R_SHIFT)
#endif

#ifndef GENPE_G_MASK
#define GENPE_G_MASK (((UColorCode)(GENPE_RGB_MASK)) << GENPE_G_SHIFT)
#endif

#ifndef GENPE_B_MASK
#define GENPE_B_MASK (((UColorCode)(GENPE_RGB_MASK)) << GENPE_B_SHIFT)
#endif

// convert separate components to colorcode.

#ifdef GENPE_BGR_CUMUL

#define GENPE_B_SHIFT_CUMUL  GENPE_B_SHIFT
#define GENPE_G_SHIFT_CUMUL (GENPE_G_SHIFT - GENPE_B_SHIFT_CUMUL)
#define GENPE_R_SHIFT_CUMUL (GENPE_R_SHIFT - GENPE_G_SHIFT_CUMUL)

#define RGB2W_1(r,g,b)     (((b) | (((g) | ((r) << GENPE_R_SHIFT_CUMUL))\
                           << GENPE_G_SHIFT_CUMUL)) << GENPE_B_SHIFT_CUMUL)

#else

#define RGB2W_1(r,g,b)  (((b) << GENPE_B_SHIFT)|\
                         ((g) << GENPE_G_SHIFT)|\
                         ((r) << GENPE_R_SHIFT)) 
#endif

#ifdef GENPE_RGB_INDIRECT
#define RGB2W(r,g,b) ((UColorCode)_colormap[RGB2W_1((UColorCode)r,(UColorCode)g,(UColorCode)b)])
#else
#define RGB2W(r,g,b) RGB2W_1((UColorCode)r,(UColorCode)g,(UColorCode)b)
#endif

#define STD_RGB2W(r,g,b) RGB2W((r >> GENPE_RGB_SHIFT),(g >> GENPE_RGB_SHIFT),(b >> GENPE_RGB_SHIFT))

// get dithering treshold from x,y. 

#define TRESHOLD(x,y) (D4[((x) & D_PMASK) + (((y) & D_PMASK) << D_PSHIFT)])

// get graph_ptr and z_ptr from x,y.

#define GPTR(x,y) (PixelValue *)((_graph_mem+(y)*_bytes_per_line+(x)*sizeof(PixelValue)))
#define ZPTR(x,y) (_z_mem + (y) * _width + (x))

// Brute force cast to PixelValue

#ifndef GCAST
#define GCAST(v) ((PixelValue)(v))
#endif

// Class definition

// Upper case : attribute is interpolated
// Lower case : attribute is constant
// c          : colormap index
// rgb        : rgb color components
// z          : zbuffer depth
// D          : dithering
// XY         : texture coordinates
// NOP        : No Operation (feature not implemented yet).

class GENPE_CLASS : public PolygonEngine
{

 public:
  GENPE_CLASS(GraphicPort *gp, int verbose_level = MSG_NONE);
  virtual ~GENPE_CLASS(void);
  virtual void CommitAttributes(void);

  static void FillPoly_NOP(GVertexAttributes *); 
   
  static void FillPoly_c(GVertexAttributes *);
  static void FillPoly_C(GVertexAttributes *);

  static void FillPoly_c_D(GVertexAttributes *);
  static void FillPoly_C_D(GVertexAttributes *);

#ifndef GENPE_RGB_DFORCE
  static void FillPoly_rgb(GVertexAttributes *);
  static void FillPoly_RGB(GVertexAttributes *);
#endif

  static void FillPoly_c_Z(GVertexAttributes *);
  static void FillPoly_C_Z(GVertexAttributes *);

  static void FillPoly_c_Z_D(GVertexAttributes *);
  static void FillPoly_C_Z_D(GVertexAttributes *);

#ifndef GENPE_RGB_DFORCE
  static void FillPoly_rgb_Z(GVertexAttributes *);
  static void FillPoly_RGB_Z(GVertexAttributes *);
#endif

#ifdef GENPE_RGB_DITHER
  static void FillPoly_rgb_Z_D(GVertexAttributes *);
  static void FillPoly_rgb_D(GVertexAttributes *);
  static void FillPoly_RGB_Z_D(GVertexAttributes *);
  static void FillPoly_RGB_D(GVertexAttributes *);
#endif

#ifndef GENPE_RGB_DFORCE   
  static void FillPoly_rgb_XY(GVertexAttributes *);
  static void FillPoly_rgb_XY_Z(GVertexAttributes *);
  static void FillPoly_RGB_XY(GVertexAttributes *);
  static void FillPoly_RGB_XY_Z(GVertexAttributes *);   
#endif   
   
#ifdef GENPE_RGB_DITHER
  static void FillPoly_rgb_XY_D(GVertexAttributes *);
  static void FillPoly_rgb_XY_Z_D(GVertexAttributes *);
  static void FillPoly_RGB_XY_D(GVertexAttributes *);
  static void FillPoly_RGB_XY_Z_D(GVertexAttributes *);   
#endif   
   
  static void DrawLine_c(GVertexAttributes *, GVertex *, GVertex *);
  static void DrawLine_C(GVertexAttributes *, GVertex *, GVertex *);

  static void DrawLine_c_D(GVertexAttributes *, GVertex *, GVertex *);
  static void DrawLine_C_D(GVertexAttributes *, GVertex *, GVertex *);

#ifndef GENPE_RGB_DFORCE
  static void DrawLine_rgb(GVertexAttributes *, GVertex *, GVertex *);
  static void DrawLine_RGB(GVertexAttributes *, GVertex *, GVertex *);
#endif

  static void DrawLine_c_Z(GVertexAttributes *, GVertex *, GVertex *);
  static void DrawLine_C_Z(GVertexAttributes *, GVertex *, GVertex *);

  static void DrawLine_c_Z_D(GVertexAttributes *, GVertex *, GVertex *);
  static void DrawLine_C_Z_D(GVertexAttributes *, GVertex *, GVertex *);

#ifndef GENPE_RGB_DFORCE
  static void DrawLine_rgb_Z(GVertexAttributes *, GVertex *, GVertex *);
  static void DrawLine_RGB_Z(GVertexAttributes *, GVertex *, GVertex *);
#endif

#ifdef GENPE_RGB_DITHER
  static void DrawLine_rgb_Z_D(GVertexAttributes *, GVertex *, GVertex *);
  static void DrawLine_rgb_D(GVertexAttributes *, GVertex *, GVertex *);
  static void DrawLine_RGB_Z_D(GVertexAttributes *, GVertex *, GVertex *);
  static void DrawLine_RGB_D(GVertexAttributes *, GVertex *, GVertex *);
#endif

  static void SetPixel_c(GVertexAttributes *, ScrCoord, ScrCoord);
  static void SetPixel_c_D(GVertexAttributes *, ScrCoord, ScrCoord);

#ifndef GENPE_RGB_DFORCE
  static void SetPixel_rgb(GVertexAttributes *, ScrCoord, ScrCoord);
#endif

#ifdef GENPE_RGB_DITHER
  static void SetPixel_rgb_D(GVertexAttributes *, ScrCoord, ScrCoord);
#endif

  static void SetPixel_c_z(GVertexAttributes *, ScrCoord, ScrCoord);
  static void SetPixel_c_z_D(GVertexAttributes *, ScrCoord, ScrCoord);

#ifndef GENPE_RGB_DFORCE
  static void SetPixel_rgb_z(GVertexAttributes *, ScrCoord, ScrCoord);
#endif

#ifdef GENPE_RGB_DITHER
  static void SetPixel_rgb_z_D(GVertexAttributes *, ScrCoord, ScrCoord);
#endif

  static PolyFun  _fillpoly_array[32];
  static LineFun  _drawline_array[16];
  static PixelFun _setpixel_array[16];

  static PolygonEngine* Make(GraphicPort *gp, int verbose_level = MSG_NONE);

};

// Operation arrays


PolyFun GENPE_CLASS::_fillpoly_array[32] =
{
//  ALPHA TEXTURE ZBUFFER DITHER GOURAUD RGB
//
//     0      0      0      0      0      0
  GENPE_CLASS::FillPoly_c,
//     0      0      0      0      0      1
#ifndef GENPE_RGB_DFORCE
  GENPE_CLASS::FillPoly_rgb,
#else
  GENPE_CLASS::FillPoly_rgb_D,
#endif
//     0      0      0      0      1      0
  GENPE_CLASS::FillPoly_C,
//     0      0      0      0      1      1
#ifdef GENPE_RGB_DFORCE
  GENPE_CLASS::FillPoly_RGB_D,
#else
  GENPE_CLASS::FillPoly_RGB,
#endif
//     0      0      0      1      0      0
  GENPE_CLASS::FillPoly_c_D,
//     0      0      0      1      0      1
#ifdef GENPE_RGB_DITHER
  GENPE_CLASS::FillPoly_rgb_D,
#else
  GENPE_CLASS::FillPoly_rgb,
#endif
//     0      0      0      1      1      0
  GENPE_CLASS::FillPoly_C_D,
//     0      0      0      1      1      1
#ifdef GENPE_RGB_DITHER
  GENPE_CLASS::FillPoly_RGB_D,
#else
  GENPE_CLASS::FillPoly_RGB,
#endif

//  ALPHA TEXTURE ZBUFFER DITHER GOURAUD RGB
//
//     0      0      1      0      0      0
  GENPE_CLASS::FillPoly_c_Z,
//     0      0      1      0      0      1
#ifndef GENPE_RGB_DFORCE
  GENPE_CLASS::FillPoly_rgb_Z,
#else
  GENPE_CLASS::FillPoly_rgb_Z_D,
#endif
//     0      0      1      0      1      0
  GENPE_CLASS::FillPoly_C_Z,
//     0      0      1      0      1      1
#ifdef GENPE_RGB_DFORCE
  GENPE_CLASS::FillPoly_RGB_Z_D,
#else
  GENPE_CLASS::FillPoly_RGB_Z,
#endif
//     0      0      1      1      0      0
  GENPE_CLASS::FillPoly_c_Z_D,
//     0      0      1      1      0      1
#ifdef GENPE_RGB_DITHER
  GENPE_CLASS::FillPoly_rgb_Z_D,
#else
  GENPE_CLASS::FillPoly_rgb_Z,
#endif
//     0      0      1      1      1      0
  GENPE_CLASS::FillPoly_C_Z_D,
//     0      0      1      1      1      1
#ifdef GENPE_RGB_DITHER
  GENPE_CLASS::FillPoly_RGB_Z_D,
#else
  GENPE_CLASS::FillPoly_RGB_Z,
#endif
   
//  ALPHA TEXTURE ZBUFFER DITHER GOURAUD RGB
//
//     0      1      0      0      0      0
  GENPE_CLASS::FillPoly_NOP,
//     0      1      0      0      0      1
#ifdef GENPE_RGB_DFORCE   
  GENPE_CLASS::FillPoly_rgb_XY_D,
#else
  GENPE_CLASS::FillPoly_rgb_XY,   
#endif   
//     0      1      0      0      1      0
  GENPE_CLASS::FillPoly_NOP,   
//     0      1      0      0      1      1
#ifdef GENPE_RGB_DFORCE   
  GENPE_CLASS::FillPoly_RGB_XY_D,
#else
  GENPE_CLASS::FillPoly_RGB_XY,   
#endif   
//     0      1      0      1      0      0
  GENPE_CLASS::FillPoly_NOP,
//     0      1      0      1      0      1
#ifdef GENPE_RGB_DITHER
  GENPE_CLASS::FillPoly_rgb_XY_D,
#else
  GENPE_CLASS::FillPoly_rgb_XY,   
#endif   
//     0      1      0      1      1      0
  GENPE_CLASS::FillPoly_NOP,   
//     0      1      0      1      1      1
#ifdef GENPE_RGB_DITHER   
  GENPE_CLASS::FillPoly_RGB_XY_D,
#else
  GENPE_CLASS::FillPoly_RGB_XY,   
#endif   

   
//  ALPHA TEXTURE ZBUFFER DITHER GOURAUD RGB
//
//     0      1      1      0      0      0
  GENPE_CLASS::FillPoly_NOP,   
//     0      1      1      0      0      1
#ifdef GENPE_RGB_DFORCE   
  GENPE_CLASS::FillPoly_rgb_XY_Z_D,
#else
  GENPE_CLASS::FillPoly_rgb_XY_Z,   
#endif   
//     0      1      1      0      1      0
  GENPE_CLASS::FillPoly_NOP,
//     0      1      1      0      1      1
#ifdef GENPE_RGB_DFORCE   
  GENPE_CLASS::FillPoly_RGB_XY_Z_D,
#else
  GENPE_CLASS::FillPoly_RGB_XY_Z,   
#endif   
//     0      1      1      1      0      0
  GENPE_CLASS::FillPoly_NOP,   
//     0      1      1      1      0      1
#ifdef GENPE_RGB_DITHER
  GENPE_CLASS::FillPoly_rgb_XY_Z_D,
#else
  GENPE_CLASS::FillPoly_rgb_XY_Z,   
#endif   
//     0      1      1      1      1      0
  GENPE_CLASS::FillPoly_NOP,   
//     0      1      1      1      1      1
#ifdef GENPE_RGB_DITHER   
  GENPE_CLASS::FillPoly_RGB_XY_Z_D
#else
  GENPE_CLASS::FillPoly_RGB_XY_Z   
#endif   
};


LineFun GENPE_CLASS::_drawline_array[16] =
{
//  ALPHA TEXTURE ZBUFFER DITHER GOURAUD RGB
//
//     0      0      0      0      0      0
  GENPE_CLASS::DrawLine_c,
//     0      0      0      0      0      1
#ifndef GENPE_RGB_DFORCE
  GENPE_CLASS::DrawLine_rgb,
#else
  GENPE_CLASS::DrawLine_rgb_D,
#endif
//     0      0      0      0      1      0
  GENPE_CLASS::DrawLine_C,
//     0      0      0      0      1      1
#ifndef GENPE_RGB_DFORCE
  GENPE_CLASS::DrawLine_RGB,
#else
  GENPE_CLASS::DrawLine_RGB_D,
#endif
//     0      0      0      1      0      0
  GENPE_CLASS::DrawLine_c_D,
//     0      0      0      1      0      1
#ifdef GENPE_RGB_DITHER
  GENPE_CLASS::DrawLine_rgb_D,
#else
  GENPE_CLASS::DrawLine_rgb,
#endif
//     0      0      0      1      1      0
  GENPE_CLASS::DrawLine_C_D,
//     0      0      0      1      1      1
#ifdef GENPE_RGB_DITHER
  GENPE_CLASS::DrawLine_RGB_D,
#else
  GENPE_CLASS::DrawLine_RGB,
#endif
//  ALPHA TEXTURE ZBUFFER DITHER GOURAUD RGB
//
//     0      0      1      0      0      0
  GENPE_CLASS::DrawLine_c_Z,
//     0      0      1      0      0      1
#ifndef GENPE_RGB_DFORCE
  GENPE_CLASS::DrawLine_rgb_Z,
#else
  GENPE_CLASS::DrawLine_rgb_Z_D,
#endif
//     0      0      1      0      1      0
  GENPE_CLASS::DrawLine_C_Z,
//     0      0      1      0      1      1
#ifdef GENPE_RGB_DFORCE
  GENPE_CLASS::DrawLine_RGB_Z_D,
#else
  GENPE_CLASS::DrawLine_RGB_Z,
#endif
//     0      0      1      1      0      0
  GENPE_CLASS::DrawLine_c_Z_D,
//     0      0      1      1      0      1
#ifdef GENPE_RGB_DITHER
  GENPE_CLASS::DrawLine_rgb_Z_D,
#else
  GENPE_CLASS::DrawLine_rgb_Z,
#endif
//     0      0      1      1      1      0
  GENPE_CLASS::DrawLine_C_Z_D,
//     0      0      1      1      1      1
#ifdef GENPE_RGB_DITHER
  GENPE_CLASS::DrawLine_RGB_Z_D
#else
  GENPE_CLASS::DrawLine_RGB_Z
#endif
};


PixelFun GENPE_CLASS::_setpixel_array[16] =
{
//  ALPHA TEXTURE ZBUFFER DITHER GOURAUD RGB
//
//     0      0      0      0      0      0
  GENPE_CLASS::SetPixel_c,
//     0      0      0      0      0      1
#ifdef GENPE_RGB_DFORCE
  GENPE_CLASS::SetPixel_rgb_D,
#else
  GENPE_CLASS::SetPixel_rgb,
#endif
//     0      0      0      0      1      0
  GENPE_CLASS::SetPixel_c,
//     0      0      0      0      1      
#ifdef GENPE_RGB_DFORCE
  GENPE_CLASS::SetPixel_rgb_D,
#else
  GENPE_CLASS::SetPixel_rgb,
#endif
//     0      0      0      1      0      0
  GENPE_CLASS::SetPixel_c_D,
//     0      0      0      1      0      1
#ifdef GENPE_RGB_DITHER
  GENPE_CLASS::SetPixel_rgb_D,
#else
  GENPE_CLASS::SetPixel_rgb,
#endif
//     0      0      0      1      1      0
  GENPE_CLASS::SetPixel_c_D,
//     0      0      0      1      1      1
#ifdef GENPE_RGB_DITHER
  GENPE_CLASS::SetPixel_rgb_D,
#else
  GENPE_CLASS::SetPixel_rgb,
#endif

//  ALPHA TEXTURE ZBUFFER DITHER GOURAUD RGB
//
//     0      0      1      0      0      0
  GENPE_CLASS::SetPixel_c_z,
//     0      0      1      0      0      1
#ifdef GENPE_RGB_DFORCE
  GENPE_CLASS::SetPixel_rgb_z_D,
#else
  GENPE_CLASS::SetPixel_rgb_z,
#endif
//     0      0      1      0      1      0
  GENPE_CLASS::SetPixel_c_z,
//     0      0      1      0      1      1
#ifdef GENPE_RGB_DFORCE
  GENPE_CLASS::SetPixel_rgb_z_D,
#else
  GENPE_CLASS::SetPixel_rgb_z,
#endif
//     0      0      1      1      0      0
  GENPE_CLASS::SetPixel_c_z_D,
//     0      0      1      1      0      1
#ifdef GENPE_RGB_DFORCE
  GENPE_CLASS::SetPixel_rgb_z_D,
#else
  GENPE_CLASS::SetPixel_rgb_z,
#endif
//     0      0      1      1      1      0
  GENPE_CLASS::SetPixel_c_z_D,
//     0      0      1      1      1      1
#ifdef GENPE_RGB_DITHER
  GENPE_CLASS::SetPixel_rgb_z_D
#else
  GENPE_CLASS::SetPixel_rgb_z
#endif
};

GENPE_CLASS::GENPE_CLASS(GraphicPort *gp, int verb) : PolygonEngine(gp, verb)
{
  static char proc_name[300];
  
  sprintf(proc_name,"PolygonEngine_%d_%d%d%d",GENPE_BYTES_PER_PIXEL,
	  nbrbits(GENPE_R_MASK), 
	  nbrbits(GENPE_G_MASK), 
	  nbrbits(GENPE_B_MASK));

  _proc_name = proc_name;
  Verbose(verb);
  (*this)[MSG_INFO] << "hello, world!\n";
  CommitAttributes();
}

GENPE_CLASS::~GENPE_CLASS(void)
{
}

void GENPE_CLASS::CommitAttributes(void)
{
  FlagSet idx = Attributes().GetAll() & ((1 << GA_MAX) - 1);

  _fillpoly = _fillpoly_array[idx & 31];
  _drawline = _drawline_array[idx & 15];
  _setpixel = _setpixel_array[idx & 15];

}  

//
//
// Polygon filling routines
//
//

void
GENPE_CLASS::FillPoly_NOP(GVertexAttributes* attr)
{
   printf("FillPoly: unrecognized combination of attributes\n");
}

#ifndef GENPE_RGB_DFORCE

#define GENFILL_RGB_MAX    255
#define GENFILL_RGB_SHIFT  GENPE_RGB_SHIFT
#define GENFILL_NAME       GENPE_CLASS::FillPoly_rgb
#define GENFILL_PIXEL      PixelValue
#define GENFILL_HEAD       ColorComponent r = MIN(VA->r,GENFILL_RGB_MAX) >> GENFILL_RGB_SHIFT; \
                           ColorComponent g = MIN(VA->g,GENFILL_RGB_MAX) >> GENFILL_RGB_SHIFT; \
                           ColorComponent b = MIN(VA->b,GENFILL_RGB_MAX) >> GENFILL_RGB_SHIFT; \
                           UColorCode cw = RGB2W(r,g,b);
#define GENFILL_SCAN       for(x=x1; x<=x2; x++,*(graph_ptr++) = GCAST(cw));

#include "genfill.h"

#endif

#ifndef GENPE_RGB_DFORCE

#define GENFILL_Z
#define GENFILL_RGB_MAX    255
#define GENFILL_RGB_SHIFT  GENPE_RGB_SHIFT
#define GENFILL_NAME       GENPE_CLASS::FillPoly_rgb_Z
#define GENFILL_PIXEL      PixelValue
#define GENFILL_HEAD       ColorComponent r = MIN(VA->r,GENFILL_RGB_MAX) >> GENFILL_RGB_SHIFT; \
                           ColorComponent g = MIN(VA->g,GENFILL_RGB_MAX) >> GENFILL_RGB_SHIFT; \
                           ColorComponent b = MIN(VA->b,GENFILL_RGB_MAX) >> GENFILL_RGB_SHIFT; \
                           UColorCode cw = RGB2W(r,g,b);
#define GENFILL_DO_PIXEL   if(z < *z_ptr)                                  \
                               {                                           \
                                 *z_ptr = z;                               \
                                 *graph_ptr = GCAST(cw);                   \
			       }

#include "genfill.h"

#endif


#ifndef GENPE_RGB_DFORCE

#define GENFILL_RGB
#define GENFILL_RGB_MAX    255
#define GENFILL_RGB_SHIFT  GENPE_RGB_SHIFT
#define GENFILL_NAME       GENPE_CLASS::FillPoly_RGB
#define GENFILL_PIXEL      PixelValue
#define GENFILL_DO_PIXEL   UColorCode cw = RGB2W(r,g,b); \
                           *graph_ptr = GCAST(cw);
#include "genfill.h"

#endif

#ifndef GENPE_RGB_DFORCE

#define GENFILL_Z
#define GENFILL_RGB
#define GENFILL_RGB_MAX    255
#define GENFILL_RGB_SHIFT  GENPE_RGB_SHIFT
#define GENFILL_NAME       GENPE_CLASS::FillPoly_RGB_Z
#define GENFILL_PIXEL      PixelValue
#define GENFILL_DO_PIXEL   if(z < *z_ptr)                      \
                               {                               \
                                 UColorCode cw = RGB2W(r,g,b); \
                                 *z_ptr = z;                   \
                                 *graph_ptr = GCAST(cw);       \
			       }
#include "genfill.h"

#endif

#define GENFILL_C
#define GENFILL_C_MAX      (255 << D_SHIFT)
#define GENFILL_C_SHIFT    D_SHIFT
#define GENFILL_NAME       GENPE_CLASS::FillPoly_C
#define GENFILL_PIXEL      PixelValue
#define GENFILL_DO_PIXEL   *graph_ptr = GCAST(_truecolormap[c]);

#include "genfill.h"



#define GENFILL_Z
#define GENFILL_C
#define GENFILL_C_MAX      (255 << D_SHIFT)
#define GENFILL_C_SHIFT    D_SHIFT
#define GENFILL_NAME       GENPE_CLASS::FillPoly_C_Z
#define GENFILL_PIXEL      PixelValue
#define GENFILL_DO_PIXEL   if(z < *z_ptr)                                        \
                               {                                                 \
                                 *z_ptr = z;                                     \
                                 *graph_ptr = GCAST(_truecolormap[c]);           \
			       }

#include "genfill.h"


#define GENFILL_NAME   GENPE_CLASS::FillPoly_c
#define GENFILL_PIXEL  PixelValue
#define GENFILL_HEAD   UColorCode cw = _truecolormap[VA->c >> D_SHIFT];
#define GENFILL_SCAN   for(x=x1; x<=x2; x++,*(graph_ptr++) = GCAST(cw));

#include "genfill.h"


#define GENFILL_Z
#define GENFILL_NAME   GENPE_CLASS::FillPoly_c_Z
#define GENFILL_PIXEL  PixelValue
#define GENFILL_HEAD   UColorCode cw = _truecolormap[VA->c >> D_SHIFT];
#define GENFILL_DO_PIXEL   if(z < *z_ptr)                                  \
                               {                                           \
                                 *z_ptr = z;                               \
                                 *graph_ptr = GCAST(cw);                   \
			       }
#include "genfill.h"


#define GENFILL_C
#define GENFILL_C_MAX    (255 << D_SHIFT)
#define GENFILL_C_SHIFT  0
#define GENFILL_NAME     GENPE_CLASS::FillPoly_C_D
#define GENFILL_PIXEL    PixelValue
#define GENFILL_HEAD     ColorCode cw;
#define GENFILL_DO_PIXEL cw = c >> D_SHIFT;                   \
                         if((c & D_MASK) > TRESHOLD(x,y))     \
                            cw++;                             \
			 *graph_ptr = GCAST(_truecolormap[cw]);
#include "genfill.h"			 


#define GENFILL_NAME     GENPE_CLASS::FillPoly_c_D
#define GENFILL_PIXEL    PixelValue
#define GENFILL_HEAD     ColorCode c = VA->c;                                                \
                         c = (c > (255 << D_SHIFT)) ? (255 << D_SHIFT) : c;                  \
			 ColorCode cw = c >> D_SHIFT;                                        \
                         ColorCode cm = c & D_MASK;

#define GENFILL_DO_PIXEL if(cm > TRESHOLD(x,y) )                     \
			    *graph_ptr = GCAST(_truecolormap[cw+1]); \
                         else                                        \
			    *graph_ptr = GCAST(_truecolormap[cw]);
#include "genfill.h"



#define GENFILL_Z
#define GENFILL_C
#define GENFILL_C_MAX    (255 << D_SHIFT)
#define GENFILL_C_SHIFT  0
#define GENFILL_NAME     GENPE_CLASS::FillPoly_C_Z_D
#define GENFILL_PIXEL    PixelValue
#define GENFILL_HEAD     ColorCode cw;
#define GENFILL_DO_PIXEL if(z < *z_ptr)                              \
                            {                                        \
			      *z_ptr = z;                            \
			      cw = c >> D_SHIFT;                     \
                           if((c & D_MASK) > TRESHOLD(x,y) )         \
                              cw++;                                  \
			      *graph_ptr = GCAST(_truecolormap[cw]); \
			    }
#include "genfill.h"



#define GENFILL_Z
#define GENFILL_NAME     GENPE_CLASS::FillPoly_c_Z_D
#define GENFILL_PIXEL    PixelValue
#define GENFILL_HEAD     ColorCode c = VA->c;                                \
                         c = (c > (255 << D_SHIFT)) ? (255 << D_SHIFT) : c;  \
			 ColorCode cw = c >> D_SHIFT;                        \
                         ColorCode cm = c & D_MASK;

#define GENFILL_DO_PIXEL if(z < *z_ptr)                               \
                         {                                            \
			   *z_ptr = z;                                \
                         if(cm > TRESHOLD(x,y))                       \
			    *graph_ptr = GCAST(_truecolormap[cw+1]);  \
                         else                                         \
			    *graph_ptr = GCAST(_truecolormap[cw]);    \
		         }
#include "genfill.h"


#ifdef GENPE_RGB_DITHER

#ifdef  GENPE_PRECISION_OVERRIDE
#define GENFILL_PRECISION_OVERRIDE
#define GENPE_RGB_DECL     UColorCode r = MIN(VA->r,GENFILL_RGB_MAX) << GENPE_RGB_DSHIFT; \
                           UColorCode g = MIN(VA->g,GENFILL_RGB_MAX) << GENPE_RGB_DSHIFT; \
                           UColorCode b = MIN(VA->b,GENFILL_RGB_MAX) << GENPE_RGB_DSHIFT;
#else
#define GENPE_RGB_DECL     UColorCode r = MIN(VA->r,GENFILL_RGB_MAX) >> GENPE_RGB_DSHIFT; \
                           UColorCode g = MIN(VA->g,GENFILL_RGB_MAX) >> GENPE_RGB_DSHIFT; \
                           UColorCode b = MIN(VA->b,GENFILL_RGB_MAX) >> GENPE_RGB_DSHIFT;
#endif

#define GENFILL_RGB_MAX    (GENPE_RGB_MASK << GENPE_RGB_SHIFT)
#define GENFILL_NAME       GENPE_CLASS::FillPoly_rgb_D
#define GENFILL_PIXEL      PixelValue
#define GENFILL_HEAD       UColorCode cw; \
                           int treshold;  \
                           GENPE_RGB_DECL                    \
                           UColorCode mr = r  & D_MASK;      \
                           UColorCode mg = g  & D_MASK;      \
                           UColorCode mb = b  & D_MASK;      \
                           UColorCode rr = r >> D_SHIFT;     \
                           UColorCode gg = g >> D_SHIFT;     \
                           UColorCode bb = b >> D_SHIFT;


#define GENFILL_DO_PIXEL   UColorCode rd,gd,bd;                \
                                                               \
                           treshold = TRESHOLD(x,y);           \
                                                               \
                           rd = (mr > treshold) ? rr + 1 : rr; \
                           gd = (mg > treshold) ? gg + 1 : gg; \
                           bd = (mb > treshold) ? bb + 1 : bb; \
                                                               \
                           cw = RGB2W(rd,gd,bd);               \
	                   *graph_ptr = GCAST(cw);


#include "genfill.h"

#undef GENPE_RGB_DECL

#endif

#ifdef GENPE_RGB_DITHER

#ifdef  GENPE_PRECISION_OVERRIDE
#define GENFILL_PRECISION_OVERRIDE
#endif

#define GENFILL_RGB
#define GENFILL_RGB_MAX    (GENPE_RGB_MASK << GENPE_RGB_SHIFT)
#define GENFILL_RGB_SHIFT  GENPE_RGB_DSHIFT
#define GENFILL_NAME       GENPE_CLASS::FillPoly_RGB_D
#define GENFILL_PIXEL      PixelValue
#define GENFILL_HEAD       UColorCode cw; \
                           int treshold;
#define GENFILL_DO_PIXEL   UColorCode rr = r >> D_SHIFT;    \
                           UColorCode gg = g >> D_SHIFT;    \
                           UColorCode bb = b >> D_SHIFT;    \
                                                            \
                           treshold = TRESHOLD(x,y);        \
                                                            \
                           if((r & D_MASK) > treshold)      \
                                 rr++;                      \
                                                            \
                           if((g & D_MASK) > treshold)      \
                                 gg++;                      \
                                                            \
                           if((b & D_MASK) > treshold)      \
                                 bb++;                      \
                                                            \
                           cw = RGB2W(rr,gg,bb);            \
	                   *graph_ptr = GCAST(cw);


#include "genfill.h"

#endif



#ifdef GENPE_RGB_DITHER

#ifdef  GENPE_PRECISION_OVERRIDE
#define GENFILL_PRECISION_OVERRIDE
#define GENPE_RGB_DECL     UColorCode r = MIN(VA->r,GENFILL_RGB_MAX) << GENPE_RGB_DSHIFT; \
                           UColorCode g = MIN(VA->g,GENFILL_RGB_MAX) << GENPE_RGB_DSHIFT; \
                           UColorCode b = MIN(VA->b,GENFILL_RGB_MAX) << GENPE_RGB_DSHIFT;
#else
#define GENPE_RGB_DECL     UColorCode r = MIN(VA->r,GENFILL_RGB_MAX) >> GENPE_RGB_DSHIFT; \
                           UColorCode g = MIN(VA->g,GENFILL_RGB_MAX) >> GENPE_RGB_DSHIFT; \
                           UColorCode b = MIN(VA->b,GENFILL_RGB_MAX) >> GENPE_RGB_DSHIFT;
#endif

#define GENFILL_Z
#define GENFILL_RGB_MAX    (GENPE_RGB_MASK << GENPE_RGB_SHIFT)
#define GENFILL_NAME       GENPE_CLASS::FillPoly_rgb_Z_D
#define GENFILL_PIXEL      PixelValue
#define GENFILL_HEAD       UColorCode cw; \
                           int treshold;  \
                           GENPE_RGB_DECL                    \
                           UColorCode mr = r  & D_MASK;      \
                           UColorCode mg = g  & D_MASK;      \
                           UColorCode mb = b  & D_MASK;      \
                           UColorCode rr = r >> D_SHIFT;     \
                           UColorCode gg = g >> D_SHIFT;     \
                           UColorCode bb = b >> D_SHIFT;


#define GENFILL_DO_PIXEL   if(z < *z_ptr)                      \
                           {                                   \
                           UColorCode rd,gd,bd;                \
                                                               \
                           *z_ptr = z;                         \
                                                               \
                           treshold = TRESHOLD(x,y);           \
                                                               \
                           rd = (mr > treshold) ? rr + 1 : rr; \
                           gd = (mg > treshold) ? gg + 1 : gg; \
                           bd = (mb > treshold) ? bb + 1 : bb; \
                                                               \
                           cw = RGB2W(rd,gd,bd);               \
	                   *graph_ptr = GCAST(cw);             \
			   }


#include "genfill.h"

#undef GENPE_RGB_DECL

#endif

#ifdef GENPE_RGB_DITHER

#ifdef  GENPE_PRECISION_OVERRIDE
#define GENFILL_PRECISION_OVERRIDE
#endif

#define GENFILL_Z
#define GENFILL_RGB
#define GENFILL_RGB_MAX    (GENPE_RGB_MASK << GENPE_RGB_SHIFT)
#define GENFILL_RGB_SHIFT  GENPE_RGB_DSHIFT
#define GENFILL_NAME       GENPE_CLASS::FillPoly_RGB_Z_D
#define GENFILL_PIXEL      PixelValue
#define GENFILL_HEAD       UColorCode cw; \
                           int treshold;

#define GENFILL_DO_PIXEL   if(z < *z_ptr)                   \
                           {                                \
                           UColorCode rr = r >> D_SHIFT;    \
                           UColorCode gg = g >> D_SHIFT;    \
                           UColorCode bb = b >> D_SHIFT;    \
                           *z_ptr = z;                      \
                           treshold = TRESHOLD(x,y);        \
                                                            \
                           if((r & D_MASK) > treshold)      \
                                 rr++;                      \
                                                            \
                           if((g & D_MASK) > treshold)      \
                                 gg++;                      \
                                                            \
                           if((b & D_MASK) > treshold)      \
                                 bb++;                      \
                                                            \
                           cw = RGB2W(rr,gg,bb);            \
	                   *graph_ptr = GCAST(cw);          \
                           }


#include "genfill.h"

#endif


#ifndef GENPE_RGB_DFORCE

#define GENFILL_XY
#define GENFILL_NAME      GENPE_CLASS::FillPoly_rgb_XY
#define GENFILL_PIXEL     PixelValue
#define GENFILL_TEXEL     GTexel
#define GENFILL_DO_PIXEL  *graph_ptr = STD_RGB2W(tex_ptr->r, tex_ptr->g, tex_ptr->b);

#include "genfill.h"

#endif

#ifndef GENPE_RGB_DFORCE

#define GENFILL_XY
#define GENFILL_Z
#define GENFILL_NAME      GENPE_CLASS::FillPoly_rgb_XY_Z
#define GENFILL_PIXEL     PixelValue
#define GENFILL_TEXEL     GTexel
#define GENFILL_DO_PIXEL  if(z < *z_ptr)                                                 \
                             {                                                           \
			     *z_ptr = z;                                                 \
                             *graph_ptr = STD_RGB2W(tex_ptr->r, tex_ptr->g, tex_ptr->b); \
			     }
#include "genfill.h"

#endif


#ifndef GENPE_RGB_DFORCE

#define GENFILL_XY
#define GENFILL_RGB
#define GENFILL_RGB_MAX    255
#define GENFILL_RGB_SHIFT  GENPE_RGB_SHIFT
#define GENFILL_NAME       GENPE_CLASS::FillPoly_RGB_XY
#define GENFILL_PIXEL      PixelValue
#define GENFILL_TEXEL      GTexel
#define GENFILL_DO_PIXEL   {                                                                \
                           UColorCode tex_r = tex_ptr->r;                                   \
                           UColorCode tex_g = tex_ptr->g;                                   \
                           UColorCode tex_b = tex_ptr->b;                                   \
                           tex_r *= r;                                                      \
                           tex_r >>= 8;                                                     \
                           tex_g *= g;                                                      \
                           tex_g >>= 8;                                                     \
                           tex_b *= b;                                                      \
                           tex_b >>= 8;                                                     \
                           *graph_ptr = RGB2W(tex_r, tex_g, tex_b);                         \
                           }
#include "genfill.h"

#endif

#ifndef GENPE_RGB_DFORCE

#define GENFILL_Z
#define GENFILL_XY
#define GENFILL_RGB
#define GENFILL_RGB_MAX    255
#define GENFILL_RGB_SHIFT  GENPE_RGB_SHIFT
#define GENFILL_NAME       GENPE_CLASS::FillPoly_RGB_XY_Z
#define GENFILL_PIXEL      PixelValue
#define GENFILL_TEXEL      GTexel
#define GENFILL_DO_PIXEL   if(z < *z_ptr)                                                   \
                           {                                                                \
			   *z_ptr = z;                                                      \
                           UColorCode tex_r = tex_ptr->r;                                   \
                           UColorCode tex_g = tex_ptr->g;                                   \
                           UColorCode tex_b = tex_ptr->b;                                   \
                           tex_r *= r;                                                      \
                           tex_r >>= 8;                                                     \
                           tex_g *= g;                                                      \
                           tex_g >>= 8;                                                     \
                           tex_b *= b;                                                      \
                           tex_b >>= 8;                                                     \
                           *graph_ptr = RGB2W(tex_r, tex_g, tex_b);                         \
                           }
#include "genfill.h"

#endif

/* toto */

#ifdef GENPE_RGB_DITHER

#ifdef  GENPE_PRECISION_OVERRIDE
#define GENFILL_PRECISION_OVERRIDE
#endif

#define GENFILL_XY
#define GENFILL_NAME       GENPE_CLASS::FillPoly_rgb_XY_D
#define GENFILL_PIXEL      PixelValue
#define GENFILL_TEXEL      GTexel
#define GENFILL_DO_PIXEL   {                                                                \
                           UColorCode tex_r = tex_ptr->r;                                   \
                           UColorCode tex_g = tex_ptr->g;                                   \
                           UColorCode tex_b = tex_ptr->b;                                   \
                           tex_r >>= GENPE_RGB_DSHIFT;                                      \
                           tex_g >>= GENPE_RGB_DSHIFT;                                      \
                           tex_b >>= GENPE_RGB_DSHIFT;                                      \
                           int treshold = TRESHOLD(x,y);                                    \
                           UColorCode rr = tex_r >> D_SHIFT;                                \
                           UColorCode gg = tex_g >> D_SHIFT;                                \
                           UColorCode bb = tex_b >> D_SHIFT;                                \
                           if((tex_r & D_MASK) > treshold)                                  \
                               rr++;                                                        \
                           if((tex_g & D_MASK) > treshold)                                  \
                               gg++;                                                        \
                           if((tex_b & D_MASK) > treshold)                                  \
                               bb++;                                                        \
                           if(rr > GENPE_RGB_MASK)                                          \
                              rr = GENPE_RGB_MASK;                                          \
                           if(gg > GENPE_RGB_MASK)                                          \
                              gg = GENPE_RGB_MASK;                                          \
                           if(bb > GENPE_RGB_MASK)                                          \
                              bb = GENPE_RGB_MASK;                                          \
                           *graph_ptr = RGB2W(rr, gg, bb);                                  \
                           }
#include "genfill.h"
#endif


#ifdef GENPE_RGB_DITHER

#ifdef  GENPE_PRECISION_OVERRIDE
#define GENFILL_PRECISION_OVERRIDE
#endif

#define GENFILL_XY
#define GENFILL_Z
#define GENFILL_NAME       GENPE_CLASS::FillPoly_rgb_XY_Z_D
#define GENFILL_PIXEL      PixelValue
#define GENFILL_TEXEL      GTexel
#define GENFILL_DO_PIXEL   if(z < *z_ptr)                                                   \
                           {                                                                \
			   *z_ptr = z;                                                      \
                           UColorCode tex_r = tex_ptr->r;                                   \
                           UColorCode tex_g = tex_ptr->g;                                   \
                           UColorCode tex_b = tex_ptr->b;                                   \
                           tex_r >>= GENPE_RGB_DSHIFT;                                      \
                           tex_g >>= GENPE_RGB_DSHIFT;                                      \
                           tex_b >>= GENPE_RGB_DSHIFT;                                      \
                           int treshold = TRESHOLD(x,y);                                    \
                           UColorCode rr = tex_r >> D_SHIFT;                                \
                           UColorCode gg = tex_g >> D_SHIFT;                                \
                           UColorCode bb = tex_b >> D_SHIFT;                                \
                           if((tex_r & D_MASK) > treshold)                                  \
                               rr++;                                                        \
                           if((tex_g & D_MASK) > treshold)                                  \
                               gg++;                                                        \
                           if((tex_b & D_MASK) > treshold)                                  \
                               bb++;                                                        \
                           if(rr > GENPE_RGB_MASK)                                          \
                              rr = GENPE_RGB_MASK;                                          \
                           if(gg > GENPE_RGB_MASK)                                          \
                              gg = GENPE_RGB_MASK;                                          \
                           if(bb > GENPE_RGB_MASK)                                          \
                              bb = GENPE_RGB_MASK;                                          \
                           *graph_ptr = RGB2W(rr, gg, bb);                                  \
                           }
#include "genfill.h"
#endif




#ifdef GENPE_RGB_DITHER

#ifdef  GENPE_PRECISION_OVERRIDE
#define GENFILL_PRECISION_OVERRIDE
#endif

#define GENFILL_XY
#define GENFILL_RGB
#define GENFILL_RGB_SHIFT  GENPE_RGB_DSHIFT
#define GENFILL_RGB_MAX    (GENPE_RGB_MASK << GENPE_RGB_SHIFT)
#define GENFILL_NAME       GENPE_CLASS::FillPoly_RGB_XY_D
#define GENFILL_PIXEL      PixelValue
#define GENFILL_TEXEL      GTexel
#define GENFILL_DO_PIXEL   {                                                                \
                           UColorCode tex_r = tex_ptr->r;                                   \
                           UColorCode tex_g = tex_ptr->g;                                   \
                           UColorCode tex_b = tex_ptr->b;                                   \
                           tex_r *= (UColorCode)r;                                          \
                           tex_r >>= 8;                                                     \
                           tex_g *= (UColorCode)g;                                          \
                           tex_g >>= 8;                                                     \
                           tex_b *= (UColorCode)b;                                          \
                           tex_b >>= 8;                                                     \
                           int treshold = TRESHOLD(x,y);                                    \
                           UColorCode rr = tex_r >> D_SHIFT;                                \
                           UColorCode gg = tex_g >> D_SHIFT;                                \
                           UColorCode bb = tex_b >> D_SHIFT;                                \
                           if((tex_r & D_MASK) > treshold)                                  \
                               rr++;                                                        \
                           if((tex_g & D_MASK) > treshold)                                  \
                               gg++;                                                        \
                           if((tex_b & D_MASK) > treshold)                                  \
                               bb++;                                                        \
                           *graph_ptr = RGB2W(rr, gg, bb);                                  \
                           }
#include "genfill.h"
#endif

#ifdef GENPE_RGB_DITHER

#ifdef  GENPE_PRECISION_OVERRIDE
#define GENFILL_PRECISION_OVERRIDE
#endif

#define GENFILL_XY
#define GENFILL_Z
#define GENFILL_RGB
#define GENFILL_RGB_SHIFT  GENPE_RGB_DSHIFT
#define GENFILL_RGB_MAX    (GENPE_RGB_MASK << GENPE_RGB_SHIFT)
#define GENFILL_NAME       GENPE_CLASS::FillPoly_RGB_XY_Z_D
#define GENFILL_PIXEL      PixelValue
#define GENFILL_TEXEL      GTexel
#define GENFILL_DO_PIXEL   if(z < *z_ptr)                                                   \
                           {                                                                \
			   *z_ptr = z;                                                      \
                           UColorCode tex_r = tex_ptr->r;                                   \
                           UColorCode tex_g = tex_ptr->g;                                   \
                           UColorCode tex_b = tex_ptr->b;                                   \
                           tex_r *= (UColorCode)r;                                          \
                           tex_r >>= 8;                                                     \
                           tex_g *= (UColorCode)g;                                          \
                           tex_g >>= 8;                                                     \
                           tex_b *= (UColorCode)b;                                          \
                           tex_b >>= 8;                                                     \
                           int treshold = TRESHOLD(x,y);                                    \
                           UColorCode rr = tex_r >> D_SHIFT;                                \
                           UColorCode gg = tex_g >> D_SHIFT;                                \
                           UColorCode bb = tex_b >> D_SHIFT;                                \
                           if((tex_r & D_MASK) > treshold)                                  \
                               rr++;                                                        \
                           if((tex_g & D_MASK) > treshold)                                  \
                               gg++;                                                        \
                           if((tex_b & D_MASK) > treshold)                                  \
                               bb++;                                                        \
                           *graph_ptr = RGB2W(rr, gg, bb);                                  \
                           }
#include "genfill.h"
#endif

/* toto */

//
//
// Line drawing functions
//
//



#ifndef GENPE_RGB_DFORCE

#define GENDRAW_RGB_MAX    255
#define GENDRAW_RGB_SHIFT  GENPE_RGB_SHIFT
#define GENDRAW_NAME       GENPE_CLASS::DrawLine_rgb
#define GENDRAW_PIXEL      PixelValue
#define GENDRAW_HEAD       ColorComponent r = MIN(VA->r,GENDRAW_RGB_MAX) >> GENDRAW_RGB_SHIFT; \
                           ColorComponent g = MIN(VA->g,GENDRAW_RGB_MAX) >> GENDRAW_RGB_SHIFT; \
                           ColorComponent b = MIN(VA->b,GENDRAW_RGB_MAX) >> GENDRAW_RGB_SHIFT; \
                           UColorCode cw = RGB2W(r,g,b);
#define GENDRAW_DO_PIXEL   *graph_ptr = GCAST(cw);

#include "gendraw.h"

#endif


#ifndef GENPE_RGB_DFORCE

#define GENDRAW_Z
#define GENDRAW_RGB_MAX    255
#define GENDRAW_RGB_SHIFT  GENPE_RGB_SHIFT
#define GENDRAW_NAME       GENPE_CLASS::DrawLine_rgb_Z
#define GENDRAW_PIXEL      PixelValue
#define GENDRAW_HEAD       ColorComponent r = MIN(VA->r,GENDRAW_RGB_MAX) >> GENDRAW_RGB_SHIFT; \
                           ColorComponent g = MIN(VA->g,GENDRAW_RGB_MAX) >> GENDRAW_RGB_SHIFT; \
                           ColorComponent b = MIN(VA->b,GENDRAW_RGB_MAX) >> GENDRAW_RGB_SHIFT; \
                           UColorCode cw = RGB2W(r,g,b);
#define GENDRAW_DO_PIXEL   if(z < *z_ptr)                                  \
                               {                                           \
                                 *z_ptr = z;                               \
                                 *graph_ptr = GCAST(cw);                   \
			       }

#include "gendraw.h"

#endif


#ifndef GENPE_RGB_DFORCE

#define GENDRAW_RGB
#define GENDRAW_RGB_MAX    255
#define GENDRAW_RGB_SHIFT  GENPE_RGB_SHIFT
#define GENDRAW_NAME       GENPE_CLASS::DrawLine_RGB
#define GENDRAW_PIXEL      PixelValue
#define GENDRAW_DO_PIXEL   UColorCode cw = RGB2W(r,g,b); \
                           *graph_ptr = GCAST(cw);

#include "gendraw.h"

#endif

#ifndef GENPE_RGB_DFORCE

#define GENDRAW_Z
#define GENDRAW_RGB
#define GENDRAW_RGB_MAX    255
#define GENDRAW_RGB_SHIFT  GENPE_RGB_SHIFT
#define GENDRAW_NAME       GENPE_CLASS::DrawLine_RGB_Z
#define GENDRAW_PIXEL      PixelValue
#define GENDRAW_DO_PIXEL   if(z < *z_ptr)                                  \
                               {                                           \
				 UColorCode cw = RGB2W(r,g,b);             \
                                 *z_ptr = z;                               \
                                 *graph_ptr = GCAST(cw);                   \
			       }
#include "gendraw.h"

#endif

#define GENDRAW_C
#define GENDRAW_C_MAX      (255 << D_SHIFT)
#define GENDRAW_C_SHIFT    D_SHIFT
#define GENDRAW_NAME       GENPE_CLASS::DrawLine_C
#define GENDRAW_PIXEL      PixelValue
#define GENDRAW_DO_PIXEL   *graph_ptr = GCAST(_truecolormap[c]);

#include "gendraw.h"



#define GENDRAW_Z
#define GENDRAW_C
#define GENDRAW_C_MAX      (255 << D_SHIFT)
#define GENDRAW_C_SHIFT    D_SHIFT
#define GENDRAW_NAME       GENPE_CLASS::DrawLine_C_Z
#define GENDRAW_PIXEL      PixelValue
#define GENDRAW_DO_PIXEL   if(z < *z_ptr)                                  \
                               {                                           \
                                 *z_ptr = z;                               \
                                 *graph_ptr = GCAST(_truecolormap[c]);     \
			       }

#include "gendraw.h"


#define GENDRAW_NAME     GENPE_CLASS::DrawLine_c
#define GENDRAW_PIXEL    PixelValue
#define GENDRAW_HEAD     UColorCode cw = _truecolormap[VA->c >> D_SHIFT];
#define GENDRAW_DO_PIXEL *graph_ptr = GCAST(cw);

#include "gendraw.h"


#define GENDRAW_Z
#define GENDRAW_NAME       GENPE_CLASS::DrawLine_c_Z
#define GENDRAW_PIXEL      PixelValue
#define GENDRAW_HEAD       UColorCode cw = _truecolormap[VA->c >> D_SHIFT];
#define GENDRAW_DO_PIXEL   if(z < *z_ptr)                                  \
                               {                                           \
                                 *z_ptr = z;                               \
                                 *graph_ptr = GCAST(cw);                   \
			       }
#include "gendraw.h"


#define GENDRAW_C
#define GENDRAW_C_MAX    (255 << D_SHIFT)
#define GENDRAW_C_SHIFT  0
#define GENDRAW_NAME     GENPE_CLASS::DrawLine_C_D
#define GENDRAW_PIXEL    PixelValue
#define GENDRAW_HEAD     ColorCode cw;
#define GENDRAW_DO_PIXEL cw = c >> D_SHIFT;               \
                         if((c & D_MASK) > TRESHOLD(x,y)) \
                            cw++;                         \
			 *graph_ptr = GCAST(_truecolormap[cw]);
#include "gendraw.h"			 


#define GENDRAW_NAME     GENPE_CLASS::DrawLine_c_D
#define GENDRAW_PIXEL    PixelValue
#define GENDRAW_HEAD     ColorCode c = VA->c;                               \
                         c = (c > (255 << D_SHIFT)) ? (255 << D_SHIFT) : c; \
			 ColorCode cw = c >> D_SHIFT;                       \
                         ColorCode cm = c & D_MASK;

#define GENDRAW_DO_PIXEL if(cm > TRESHOLD(x,y) )                     \
			    *graph_ptr = GCAST(_truecolormap[cw+1]); \
                         else                                        \
			    *graph_ptr = GCAST(_truecolormap[cw]);
#include "gendraw.h"



#define GENDRAW_Z
#define GENDRAW_C
#define GENDRAW_C_MAX    (255 << D_SHIFT)
#define GENDRAW_C_SHIFT  0
#define GENDRAW_NAME     GENPE_CLASS::DrawLine_C_Z_D
#define GENDRAW_PIXEL    PixelValue
#define GENDRAW_HEAD     ColorCode cw;
#define GENDRAW_DO_PIXEL if(z < *z_ptr)                              \
                            {                                        \
			      *z_ptr = z;                            \
			      cw = c >> D_SHIFT;                     \
                           if((c & D_MASK) > TRESHOLD(x,y))          \
                              cw++;                                  \
			      *graph_ptr = GCAST(_truecolormap[cw]); \
			    }
#include "gendraw.h"



#define GENDRAW_Z
#define GENDRAW_NAME     GENPE_CLASS::DrawLine_c_Z_D
#define GENDRAW_PIXEL    PixelValue
#define GENDRAW_HEAD     ColorCode c = VA->c;                               \
                         c = (c > (255 << D_SHIFT)) ? (255 << D_SHIFT) : c; \
			 ColorCode cw = c >> D_SHIFT;                       \
                         ColorCode cm = c & D_MASK;

#define GENDRAW_DO_PIXEL if(z < *z_ptr)                              \
                         {                                           \
			   *z_ptr = z;                               \
                         if(cm > TRESHOLD(x,y))                      \
			    *graph_ptr = GCAST(_truecolormap[cw+1]); \
                         else                                        \
			    *graph_ptr = GCAST(_truecolormap[cw]);   \
		         }
#include "gendraw.h"




#ifdef GENPE_RGB_DITHER

#ifdef  GENPE_PRECISION_OVERRIDE
#define GENDRAW_PRECISION_OVERRIDE
#define GENPE_RGB_DECL     UColorCode r = MIN(VA->r,GENDRAW_RGB_MAX) << GENPE_RGB_DSHIFT; \
                           UColorCode g = MIN(VA->g,GENDRAW_RGB_MAX) << GENPE_RGB_DSHIFT; \
                           UColorCode b = MIN(VA->b,GENDRAW_RGB_MAX) << GENPE_RGB_DSHIFT;
#else
#define GENPE_RGB_DECL     UColorCode r = MIN(VA->r,GENDRAW_RGB_MAX) >> GENPE_RGB_DSHIFT; \
                           UColorCode g = MIN(VA->g,GENDRAW_RGB_MAX) >> GENPE_RGB_DSHIFT; \
                           UColorCode b = MIN(VA->b,GENDRAW_RGB_MAX) >> GENPE_RGB_DSHIFT;
#endif

#define GENDRAW_RGB_MAX    (GENPE_RGB_MASK << GENPE_RGB_SHIFT)
#define GENDRAW_NAME       GENPE_CLASS::DrawLine_rgb_D
#define GENDRAW_PIXEL      PixelValue
#define GENDRAW_HEAD       UColorCode cw; \
                           int treshold;  \
                           GENPE_RGB_DECL                    \
                           UColorCode mr = r  & D_MASK;      \
                           UColorCode mg = g  & D_MASK;      \
                           UColorCode mb = b  & D_MASK;      \
                           UColorCode rr = r >> D_SHIFT;     \
                           UColorCode gg = g >> D_SHIFT;     \
                           UColorCode bb = b >> D_SHIFT;


#define GENDRAW_DO_PIXEL   UColorCode rd,gd,bd;                \
                                                               \
                           treshold = TRESHOLD(x,y);           \
                                                               \
                           rd = (mr > treshold) ? rr + 1 : rr; \
                           gd = (mg > treshold) ? gg + 1 : gg; \
                           bd = (mb > treshold) ? bb + 1 : bb; \
                                                               \
                           cw = RGB2W(rd,gd,bd);               \
	                   *graph_ptr = GCAST(cw);


#include "gendraw.h"

#undef GENPE_RGB_DECL

#endif


#ifdef GENPE_RGB_DITHER

#ifdef GENPE_PRECISION_OVERRIDE
#define GENDRAW_PRECISION_OVERRIDE
#endif

#define GENDRAW_RGB
#define GENDRAW_RGB_MAX    (GENPE_RGB_MASK << GENPE_RGB_SHIFT)
#define GENDRAW_RGB_SHIFT  GENPE_RGB_DSHIFT;
#define GENDRAW_NAME       GENPE_CLASS::DrawLine_RGB_D
#define GENDRAW_PIXEL      PixelValue
#define GENDRAW_HEAD       UColorCode cw; \
                           int treshold;
#define GENDRAW_DO_PIXEL   UColorCode rr = r >> D_SHIFT;    \
                           UColorCode gg = g >> D_SHIFT;    \
                           UColorCode bb = b >> D_SHIFT;    \
                           treshold = TRESHOLD(x,y);        \
                                                            \
                           if((r & D_MASK) > treshold)      \
                                rr++;                       \
                                                            \
                           if((g & D_MASK) > treshold)      \
                                gg++;                       \
                                                            \
                           if((b & D_MASK) > treshold)      \
                                bb++;                       \
                                                            \
                           cw = RGB2W(rr,gg,bb);            \
	                   *graph_ptr = GCAST(cw);


#include "gendraw.h"

#endif



#ifdef GENPE_RGB_DITHER

#ifdef  GENPE_PRECISION_OVERRIDE
#define GENDRAW_PRECISION_OVERRIDE
#define GENPE_RGB_DECL     UColorCode r = MIN(VA->r,GENDRAW_RGB_MAX) << GENPE_RGB_DSHIFT; \
                           UColorCode g = MIN(VA->g,GENDRAW_RGB_MAX) << GENPE_RGB_DSHIFT; \
                           UColorCode b = MIN(VA->b,GENDRAW_RGB_MAX) << GENPE_RGB_DSHIFT;
#else
#define GENPE_RGB_DECL     UColorCode r = MIN(VA->r,GENDRAW_RGB_MAX) >> GENPE_RGB_DSHIFT; \
                           UColorCode g = MIN(VA->g,GENDRAW_RGB_MAX) >> GENPE_RGB_DSHIFT; \
                           UColorCode b = MIN(VA->b,GENDRAW_RGB_MAX) >> GENPE_RGB_DSHIFT;
#endif

#define GENDRAW_Z
#define GENDRAW_RGB_MAX    (GENPE_RGB_MASK << GENPE_RGB_SHIFT)
#define GENDRAW_NAME       GENPE_CLASS::DrawLine_rgb_Z_D
#define GENDRAW_PIXEL      PixelValue
#define GENDRAW_HEAD       UColorCode cw; \
                           int treshold;  \
                           GENPE_RGB_DECL                    \
                           UColorCode mr = r  & D_MASK;      \
                           UColorCode mg = g  & D_MASK;      \
                           UColorCode mb = b  & D_MASK;      \
                           UColorCode rr = r >> D_SHIFT;     \
                           UColorCode gg = g >> D_SHIFT;     \
                           UColorCode bb = b >> D_SHIFT;


#define GENDRAW_DO_PIXEL   if(z < *z_ptr)                      \
                           {                                   \
                           UColorCode rd,gd,bd;                \
                                                               \
                           *z_ptr = z;                         \
                                                               \
                           treshold = TRESHOLD(x,y);           \
                                                               \
                           rd = (mr > treshold) ? rr + 1 : rr; \
                           gd = (mg > treshold) ? gg + 1 : gg; \
                           bd = (mb > treshold) ? bb + 1 : bb; \
                                                               \
                           cw = RGB2W(rd,gd,bd);               \
	                   *graph_ptr = GCAST(cw);             \
			   }


#include "gendraw.h"

#undef GENPE_RGB_DECL

#endif


#ifdef GENPE_RGB_DITHER

#ifdef GENPE_PRECISION_OVERRIDE
#define GENDRAW_PRECISION_OVERRIDE
#endif

#define GENDRAW_Z
#define GENDRAW_RGB
#define GENDRAW_RGB_MAX    (GENPE_RGB_MASK << GENPE_RGB_SHIFT)
#define GENDRAW_RGB_SHIFT  GENPE_RGB_DSHIFT
#define GENDRAW_NAME       GENPE_CLASS::DrawLine_RGB_Z_D
#define GENDRAW_PIXEL      PixelValue
#define GENDRAW_HEAD       UColorCode cw; \
                           int treshold;
#define GENDRAW_DO_PIXEL   if(z < *z_ptr)                   \
                           {                                \
                           UColorCode rr = r >> D_SHIFT;    \
                           UColorCode gg = g >> D_SHIFT;    \
                           UColorCode bb = b >> D_SHIFT;    \
                                                            \
                           *z_ptr = z;                      \
                           treshold = TRESHOLD(x,y);        \
                                                            \
                           if((r & D_MASK) > treshold)      \
                                 rr++;                      \
                                                            \
                           if((g & D_MASK) > treshold)      \
                                 gg++;                      \
                                                            \
                           if((b & D_MASK) > treshold)      \
                                 bb++;                      \
                                                            \
                           cw = RGB2W(rr,gg,bb);            \
	                   *graph_ptr = GCAST(cw);          \
                           }

#include "gendraw.h"

#endif

//
//
// Pixel routines
//
//

#ifndef GENPE_RGB_DFORCE

void GENPE_CLASS::SetPixel_rgb(GVertexAttributes *VA, ScrCoord x, ScrCoord y)
{
  ColorComponent r = MIN(VA->r,255) >> GENPE_RGB_SHIFT; 
  ColorComponent g = MIN(VA->g,255) >> GENPE_RGB_SHIFT; 
  ColorComponent b = MIN(VA->b,255) >> GENPE_RGB_SHIFT; 

  UColorCode cw = RGB2W(r,g,b);
  *GPTR(x,y) = GCAST(cw);
}

#endif

#ifndef GENPE_RGB_DFORCE

void GENPE_CLASS::SetPixel_rgb_z(GVertexAttributes *VA, ScrCoord x, ScrCoord y)
{
  ZCoord  *z_ptr = ZPTR(x,y);

  if(VA->z < *z_ptr)
    {
      *z_ptr = VA->z;

      ColorComponent r = MIN(VA->r,255) >> GENPE_RGB_SHIFT; 
      ColorComponent g = MIN(VA->g,255) >> GENPE_RGB_SHIFT; 
      ColorComponent b = MIN(VA->b,255) >> GENPE_RGB_SHIFT; 

      UColorCode cw =  RGB2W(r,g,b);
      *GPTR(x,y) = GCAST(cw);
    }
}

#endif

#ifdef GENPE_RGB_DITHER

void GENPE_CLASS::SetPixel_rgb_D(GVertexAttributes *VA, ScrCoord x, ScrCoord y)
{
  ColorComponent r = MIN(VA->r, GENPE_RGB_MASK << GENPE_RGB_SHIFT);
  ColorComponent g = MIN(VA->g, GENPE_RGB_MASK << GENPE_RGB_SHIFT);
  ColorComponent b = MIN(VA->b, GENPE_RGB_MASK << GENPE_RGB_SHIFT);

#ifdef GENPE_PRECISION_OVERRIDE
  
  r <<= GENPE_RGB_DSHIFT;
  g <<= GENPE_RGB_DSHIFT;
  b <<= GENPE_RGB_DSHIFT;

#else

  r >>= GENPE_RGB_DSHIFT;
  g >>= GENPE_RGB_DSHIFT;
  b >>= GENPE_RGB_DSHIFT;

#endif

  UColorCode rr = r >> D_SHIFT;
  UColorCode gg = g >> D_SHIFT;
  UColorCode bb = b >> D_SHIFT;

  int treshold = TRESHOLD(x,y);  

  if((r & D_MASK) > treshold)                                  
    rr++;
      
  if((g & D_MASK) > treshold)                                  
    gg++;
  
  if((b & D_MASK) > treshold)                                  
    bb++;

  UColorCode cw = RGB2W(rr,gg,bb);
  *GPTR(x,y) = GCAST(cw);

}

#endif

#ifdef GENPE_RGB_DITHER

void GENPE_CLASS::SetPixel_rgb_z_D(GVertexAttributes *VA, ScrCoord x, ScrCoord y)
{

  ZCoord   *z_ptr  = ZPTR(x,y);

  if(VA->z < *z_ptr)
    {
      *z_ptr = VA->z;

      ColorComponent r = MIN(VA->r, GENPE_RGB_MASK << GENPE_RGB_SHIFT);
      ColorComponent g = MIN(VA->g, GENPE_RGB_MASK << GENPE_RGB_SHIFT);
      ColorComponent b = MIN(VA->b, GENPE_RGB_MASK << GENPE_RGB_SHIFT);

#ifdef GENPE_PRECISION_OVERRIDE
  
      r <<= GENPE_RGB_DSHIFT;
      g <<= GENPE_RGB_DSHIFT;
      b <<= GENPE_RGB_DSHIFT;

#else

      r >>= GENPE_RGB_DSHIFT;
      g >>= GENPE_RGB_DSHIFT;
      b >>= GENPE_RGB_DSHIFT;

#endif

      UColorCode rr = r >> D_SHIFT;
      UColorCode gg = g >> D_SHIFT;
      UColorCode bb = b >> D_SHIFT;

      int treshold = TRESHOLD(x,y);  

      if((r & D_MASK) > treshold)                                  
	rr++;
      
      if((g & D_MASK) > treshold)                                  
	gg++;
  
      if((b & D_MASK) > treshold)                                  
	bb++;

      UColorCode cw = RGB2W(rr,gg,bb);
      *GPTR(x,y) = GCAST(cw);

    }
}

#endif

void GENPE_CLASS::SetPixel_c(GVertexAttributes *VA, ScrCoord x, ScrCoord y)
{
  *GPTR(x,y) = GCAST(_truecolormap[VA->c >> D_SHIFT]);
}

void GENPE_CLASS::SetPixel_c_z(GVertexAttributes *VA, ScrCoord x, ScrCoord y)
{
  ZCoord   *z_ptr  = ZPTR(x,y);

  if(VA->z < *z_ptr)
    {
      *z_ptr = VA->z;
      *GPTR(x,y) = GCAST(_truecolormap[VA->c >> D_SHIFT]);
    }
}

void GENPE_CLASS::SetPixel_c_D(GVertexAttributes *VA, ScrCoord x, ScrCoord y)
{
  ColorCode  c = MIN(VA->c, 255 << D_SHIFT);
  ColorCode cc = c >> D_SHIFT;

  if((c & D_MASK) > TRESHOLD(x,y))
    cc++;

  *GPTR(x,y) = GCAST(_truecolormap[cc]);
}



void GENPE_CLASS::SetPixel_c_z_D(GVertexAttributes *VA, ScrCoord x, ScrCoord y)
{

  ZCoord   *z_ptr  = ZPTR(x,y);

  if(VA->z < *z_ptr)
    {
      *z_ptr = VA->z;

      ColorCode  c = MIN(VA->c, 255 << D_SHIFT);
      ColorCode cc = c >> D_SHIFT;
      
      if((c & D_MASK) > TRESHOLD(x,y))
	cc++;

      *GPTR(x,y) = GCAST(_truecolormap[cc]);
    }
}


////
////
//
// Virtual constructor stuff
//
////
////


PolygonEngine* GENPE_CLASS::Make(GraphicPort *GP, int verb)
{
  return new GENPE_CLASS(GP, verb);
}

////
////
//
// Dynamic loader entry point
//
////
////

extern "C" {
void GENPE_DLD(void);
}

void GENPE_DLD(void)
{
PolygonEngine::Register(
               GENPE_CLASS::Make,
               GENPE_BYTES_PER_PIXEL,
               GENPE_R_MASK, GENPE_G_MASK, GENPE_B_MASK
) ; 
}
