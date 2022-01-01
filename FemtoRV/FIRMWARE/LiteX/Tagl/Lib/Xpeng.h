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
 * Xpeng.h
 * 
 * A polygon engine that works with X.
 * Must be initialized from an XGraphicPort.
 * Usefull for remote displays when ZBuffer and Gouraud are
 * not needed.
 *
 */


#ifndef XPENG_H
#define XPENG_H

#include "Xgport.h"
#include "polyeng.h"


class XPolygonEngine: public PolygonEngine
{
public:
  XPolygonEngine(GraphicPort *gp, int verbose_level = MSG_NONE);
  virtual ~XPolygonEngine(void);
  virtual void CommitAttributes(void);

protected:
  static int          _bw;
  static unsigned char         _stipple_data[8][8];
  static Pixmap       _stipple[8];
  static GC           _stipple_gc[8];

  static GraphicPort *_static_gport;
  static Flags       *_static_attributes;
  static Display     *_display;
  static Window       _window;
  static GC           _gc;


  static int       RGB2Gray(ColorComponent r, 
			    ColorComponent g, 
			    ColorComponent b);

  static Drawable  GetDrawable();

  static void      SetColor(ColorIndex idx);
  static void      SetColor(ColorComponent r, ColorComponent g, ColorComponent b);
  static void      SetColor(GVertexAttributes *attr);

  static void _FillPoly(GVertexAttributes *attr);
  static void _DrawLine(GVertexAttributes *attr, GVertex *V1, GVertex *V2);
  static void _SetPixel(GVertexAttributes *attr, ScrCoord x, ScrCoord y);

private:
  static PolygonEngine* Make(GraphicPort *gp, int verbose_level = MSG_NONE);
  
  friend class Stub;

};

#include "Xpeng.ih"

#endif
