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
 * Xpeng.cc
 * 
 * A polygon engine that works with X.
 * Must be initialized from an XGraphicPort.
 * Usefull for remote displays when ZBuffer and Gouraud are
 * not needed.
 *
 */

#include "Xpeng.h"

GraphicPort *XPolygonEngine::_static_gport;
Flags       *XPolygonEngine::_static_attributes;
Display     *XPolygonEngine::_display;
Window       XPolygonEngine::_window;
GC           XPolygonEngine::_gc;

int  XPolygonEngine::_bw;

unsigned char XPolygonEngine::_stipple_data[8][8] =
{
  {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00},
  {0x11, 0x00, 0x00, 0x00, 0x11, 0x00, 0x00, 0x00},
  {0x11, 0x00, 0x44, 0x00, 0x11, 0x00, 0x44, 0x00},
  {0x55, 0x00, 0x55, 0x00, 0x55, 0x00, 0x55, 0x00},
  {0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa},
  {0x55, 0xff, 0x55, 0xff, 0x55, 0xff, 0x55, 0xff},
  {0xdd, 0xff, 0x77, 0xff, 0xdd, 0xff, 0x77, 0xff},
  {0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff}
};


Pixmap XPolygonEngine::_stipple[8];

GC     XPolygonEngine::_stipple_gc[8];


XPolygonEngine::XPolygonEngine(GraphicPort *gp, int verbose_level)
              : PolygonEngine(gp, verbose_level)
{

  _static_gport = _gport;

  _fillpoly      = _FillPoly;
  _drawline      = _DrawLine;
  _setpixel      = _SetPixel;
  _proc_name     = "XPolygonEngine";

  if(!gp->Cntl(XGraphicPort::ISXGPORT))
    {
      (*this)[MSG_ERROR] << "GraphicPort is not an XGraphicPort !!\n";
      return;
    }

  _display = (Display *)gp->Cntl(XGraphicPort::GETXDISPLAY);
  _window  = (Window   )gp->Cntl(XGraphicPort::GETXWINDOW );

  if(!_bw)
    _gc      = XCreateGC(_display, _window, 0, NULL);

  _static_attributes = &Attributes();

  _bw = (gp->BitsPerPixel() == 1);

  if(_bw)
    {
      int i;

      (*this)[MSG_INFO] << "Black and white X display, using stipples\n";


      for(i=0; i<8; i++)
	{
	  if((_stipple[i] = XCreateBitmapFromData(_display, _window, _stipple_data[i], 8, 8)) == None)
	    {
	      (*this)[MSG_ERROR] << "Error creating stipple\n";
	      return;
	    }

	  _stipple_gc[i] = XCreateGC(_display, _window, 0, NULL);

	  XSetForeground(_display, _stipple_gc[i], WhitePixel(_display, DefaultScreen(_display)));
	  XSetBackground(_display, _stipple_gc[i], BlackPixel(_display, DefaultScreen(_display)));
	  XSetFillStyle(_display,  _stipple_gc[i], FillStippled);
	  XSetStipple(_display, _stipple_gc[i], _stipple[i]);
	}

    }

}


XPolygonEngine::~XPolygonEngine(void)
{


  if(_bw)
    {
      int i;
      for(i=0; i<8; i++)
	{
	  XFreeGC(_display, _stipple_gc[i]);
	  XFreePixmap(_display, _stipple[i]);
	}
    }
  else
    XFreeGC(_display, _gc);
}

void
XPolygonEngine::CommitAttributes(void)
{
  // It would be possible to check here is no attempt
  // is made to set Gouraud or ZBuffer mode ..
}

void 
XPolygonEngine::_FillPoly(GVertexAttributes *attr)
{
  XPoint xpt[POLYGON_SZ];
  int i;

  SetColor(attr);

  for(i=0; i<_p1.Size(); i++)
    {
      xpt[i].x = (short)_p1[i]->x;
      xpt[i].y = (short)_p1[i]->y;
    }

  XFillPolygon(_display, GetDrawable(), _gc, xpt, _p1.Size(), Convex, CoordModeOrigin);
}

void 
XPolygonEngine::_DrawLine(GVertexAttributes *attr, GVertex *V1, GVertex *V2)
{
  
  SetColor(attr);

  XDrawLine(_display, GetDrawable(), _gc, 
	    (int)V1->x, (int)V1->y, (int)V2->x, (int)V2->y);
}

void 
XPolygonEngine::_SetPixel(GVertexAttributes *attr, ScrCoord x, ScrCoord y)
{

  SetColor(attr);

  XDrawPoint(_display, GetDrawable(), _gc, (int)x, (int)y);

}


////
////
//
// Virtual constructor stuff
//
////
////


PolygonEngine* XPolygonEngine::Make(GraphicPort *GP, int verb)
{
  return new XPolygonEngine(GP, verb);
}

static class Stub
{
public:
  Stub(void) 
    { 
      PolygonEngine::Register(XPolygonEngine::Make,
			      0,
			      0, 0, 0); 
    } 
} Dummy;


////
////
//
// Dynamic linker entry
//
////
////



extern "C" {
void init_Xpeng(void);
}


void init_Xpeng(void)
{
  Stub dummy;
}
