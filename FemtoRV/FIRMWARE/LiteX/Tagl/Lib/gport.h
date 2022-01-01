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
 * gport.h
 * Base class for GraphicPorts.
 *
 */


#ifndef GPORT_H
#define GPORT_H

#include <stdlib.h>
#include "gdefs.h"
#include "flags.h"
#include "ccell.h" 
#include "gcomp.h"

const char GK_Return = 1;
const char GK_Escape = 2;
const char GK_Left   = 3;
const char GK_Right  = 4;
const char GK_Up     = 5;
const char GK_Down   = 6;

const Flag GPE_OK    = 0;

const Flag GPA_NONE  = 0;
const Flag GPA_DBUFF = 1;
const Flag GPA_ZBUFF = 2;
const Flag GPA_CMAP  = 3;
const Flag GPA_RGB   = 4;

const ColorIndex BLACK   = 0;
const ColorIndex RED     = 1;
const ColorIndex GREEN   = 2;
const ColorIndex YELLOW  = 3;
const ColorIndex BLUE    = 4;
const ColorIndex MAGENTA = 5;
const ColorIndex CYAN    = 6;
const ColorIndex WHITE   = 7;

// Virtual constructor stuff.

const int GP_VC_NORMAL = 0; // X does not hang if cannot initialize.
const int GP_VC_HANGS  = 1; // SVGAlib does ...


class GraphicPort;

typedef GraphicPort *(*GraphicPort_MakeFun)(const char*, ScrCoord, ScrCoord, int);

typedef struct
{
  GraphicPort_MakeFun make;
  int flags;
} GraphicPort_VC_Entry;


class GraphicPort: public GraphicComponent
{

 public:

  GraphicPort(const char *name, ScrCoord width, ScrCoord height, int verbose_level = MSG_ENV);

  virtual ~GraphicPort(void);


  virtual void RGBMode(void)      = 0;
  virtual void ColormapMode(void) = 0;

  virtual int  SingleBuffer(void)     = 0;
  virtual int  DoubleBuffer(void)     = 0;
  virtual int  SwapBuffers(void)      = 0;
  virtual void CopyBuffer256(ColorIndex *buffer);
  virtual void ScaleBuffer256(ColorIndex *buffer, 
			      ScrCoord width, ScrCoord height);
  virtual int ZBuffer(const int yes) = 0;

  ColorIndex* GraphMem(void)     const;
  ColorIndex* Colormap(void)     const;
  UColorCode* TrueColormap(void) const;
  ColorCell*  Colortable(void)   ;
  ZCoord*     ZMem(void)         const;    
  ScrCoord    Width(void)        const;
  ScrCoord    Height(void)       const;
  int         BytesPerLine(void) const;
  Rect&       Clip(void);
  int         BitsPerPixel(void)  const;
  int         BytesPerPixel(void) const;
  int         RMask(void)         const;
  int         GMask(void)         const;
  int         BMask(void)         const;

  Flag        ErrorCode(void)    const;

  void GetGeometry(ScrCoord *_width, ScrCoord *_height) const;

  virtual void MapColor(const ColorIndex i, 
			const ColorComponent r, 
			const ColorComponent g, 
			const ColorComponent b ) = 0;

  virtual int  SetGeometry(const ScrCoord _width, const ScrCoord _height) = 0;

  virtual int  WaitEvent(void) = 0;
  virtual char GetKey(void) = 0;
  virtual int  GetMouse(ScrCoord *x, ScrCoord *y) = 0;

  void         Clear(ColorComponent R,
		     ColorComponent G,
		     ColorComponent B);

  void         Clear(ColorIndex idx);

  virtual void ZClear(void);
  virtual void ZClear(ZCoord z);

  //  These two functions convert a color from its RGB form
  // to a value that represent how it is coded in graph mem.
  //  The second form performs dithering. 
  //  These two functions are not used within the rasterisation 
  // code. They are used by the Clear() function and by texture
  // conversion utilities. 
   

  UColorCode   RGB2ColorCode(ColorComponent R, 
			     ColorComponent G,
			     ColorComponent B);

  UColorCode   RGB2ColorCode(ColorComponent R,
			     ColorComponent G,
			     ColorComponent B,
			     ScrCoord x,
			     ScrCoord y);
   

  void         TextureBind(UColorCode* texture, ScrCoord size);
   
 protected:

  
  void         StoreColor(ColorIndex idx,
			  ColorComponent R, 
			  ColorComponent G,
			  ColorComponent B);


  virtual void Clear(UColorCode x);

  const char       *_name;
  ColorCell   _colortable[GP_COLORMAP_SZ];
  int         _error_code;


   
// virtual constructor stuff.

 public:
  static GraphicPort* Make(const char* name, ScrCoord width, ScrCoord height, 
			   int verbose_level = MSG_ENV);

  static void Register(const GraphicPort_MakeFun make, const int flags);
 private:   
  static int _entries;                       
  static GraphicPort_VC_Entry _entry[VC_ENTRIES];  

  friend class Stub;

// Context handling

 public:
  void SetContext();
  void SaveContext();
  int  ContextIsActive();

 protected:
  RenderContext _tgc;
};

#include "gport.ih"

#endif
