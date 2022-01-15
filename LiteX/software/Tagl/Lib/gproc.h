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
 * gproc.h
 *
 */

#ifndef GPROC_H
#define GPROC_H

#include "gdefs.h"
#include "gcomp.h"
#include "gport.h"


const Flag GA_RGB     = 1;
const Flag GA_GOURAUD = 2;
const Flag GA_DITHER  = 3;
const Flag GA_ZBUFFER = 4;
const Flag GA_TEXTURE = 5;
const Flag GA_ALPHA   = 6;
const Flag GA_HCLIP   = 7;

const Flag GA_MAX     = GA_HCLIP;

// Dithering.

const int D_SHIFT  = 4;
const int D_MASK   = 15;
const int D_PMASK  = 3;
const int D_PSHIFT = 2;



class GraphicProcessor : public GraphicComponent
{
 protected:
  GraphicPort *_gport;
  static   int D4[16]; // Dithering matrix

// delegated features


 public:
  ScrCoord    Width(void)        const;
  ScrCoord    Height(void)       const;
  ColorIndex* GraphMem(void)     const;
  ColorIndex* Colormap(void)     const;
  ZCoord*     ZMem(void)         const;
  int         BytesPerLine(void) const;
  int         BitsPerPixel(void) const;
  int         RedMask(void)      const;
  int         GreenMask(void)    const;
  int         BlueMask(void)     const;
  Rect&       Clip(void);

  GraphicProcessor(void);
  GraphicProcessor(GraphicPort* gport);
  virtual ~GraphicProcessor(void);

  virtual void ColormapMode(void);
  virtual void RGBMode(void);
  virtual void Gouraud(int yes = 1);
  virtual void Flat(void);
  virtual void Dither(int yes = 1);
  virtual void ZBuffer(int yes = 1);
  virtual void Alpha(int yes = 1);
  virtual void Texture(int yes = 1);

  GraphicPort* Port(void);

  friend class GraphicPort;
};

#include "gproc.ih"

#endif
