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
 * polyeng.h
 *
 */


#ifndef POLYENG_H
#define POLYENG_H

#include "gdefs.h"
#include "vpool.h"
#include "polygon.h"
#include "gproc.h"

const int PE_MAX_HEIGHT = 1024;


const int PEA_ZCLIP = GA_MAX + 1;

class Mug
{
 public:
  GVertex _left;
  GVertex _right;
};


class PolygonEngine;

typedef void (* PolyFun)(GVertexAttributes *);
typedef void (* LineFun)(GVertexAttributes *, GVertex *, GVertex *);
typedef void (* PixelFun)(GVertexAttributes *, ScrCoord, ScrCoord);


typedef PolygonEngine *(*PolygonEngine_MakeFun)(GraphicPort*, int);

typedef struct
{
  PolygonEngine_MakeFun make;
  int bytes_per_pixel;
  UColorCode R_mask;
  UColorCode G_mask;
  UColorCode B_mask;
} PolygonEngine_VC_Entry;


class PolygonEngine : public GraphicProcessor
{

 protected:
  GVertexAttributes    _va;

  static GVertexPool _vpool;
  static GPolygon    _p1;
  static GPolygon    _p2;
  static Mug         _mug[PE_MAX_HEIGHT];


  GVertexAttributes _vattrib_stack[ATTRIB_STACK_SZ];

  PolyFun   _fillpoly;
  LineFun   _drawline;
  PixelFun  _setpixel;

 public:
  PolygonEngine(GraphicPort *gp, int verbose_level = MSG_ENV);
  virtual ~PolygonEngine(void);
  GVertexAttributes& VAttributes(void);

  void Push(GVertex *v);
  void Reset(void);

  void FillPoly();
  void DrawPoly();

  void SetPixel(GVertex* v);
  void SetPixel(ScrCoord x, ScrCoord y);
  void SetPixel(ScrCoord x, ScrCoord y, ColorCode c);
  void SetPixel(ScrCoord x, ScrCoord y, 
		ColorComponent r, ColorComponent g, ColorComponent b);

  void ClipPoly(void);

  // virtual constructor stuff

 public:
  static PolygonEngine* Make(GraphicPort *GP, int verb = MSG_ENV);

 private:
  static int _entries;
  static PolygonEngine_VC_Entry _entry[VC_ENTRIES];

  public:
  static void Register(const PolygonEngine_MakeFun make, int bytes_per_pixel,
		int R_mask, int G_mask, int B_mask);

  friend class Stub;
};

#include "polyeng.ih"

#endif
