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
 * Xgport.h
 * A GraphicPort for Unix/X11
 *
 */


#ifndef XGPORT_H
#define XGPORT_H

#include "gport.h"

const int MIN_WIDTH  = 100;
const int MIN_HEIGHT = 100;
const int MAX_WIDTH  = 1024;
const int MAX_HEIGHT = 1024;

const Flag XGPR_NONE            = 0;
const Flag XGPR_DISPLAY         = 1;
const Flag XGPR_SCREEN          = 2;
const Flag XGPR_WINDOW          = 3;
const Flag XGPR_GC              = 4;
const Flag XGPR_GLOBAL_CMAP     = 5;
const Flag XGPR_LOCAL_CMAP      = 6;
const Flag XGPR_SHM_XIMAGE      = 7;
const Flag XGPR_X_ERROR_HANDLER = 8;
const Flag XGPR_STD_XIMAGE      = 9;
const Flag XGPR_ZBUFFER         = 10;
const Flag XGPR_PIXMAP          = 11;

const Flag XGPE_DISPLAY = 1;
const Flag XGPE_VISUAL  = 2;
const Flag XGPE_WINDOW  = 3;
const Flag XGPE_XIMAGE  = 4;
const Flag XGPE_MALLOC  = 5;

const ScrCoord MAX_X_WIDTH  = 640;
const ScrCoord MAX_X_HEIGHT = 480;

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/keysym.h> 

#ifdef X_SHM
#include <sys/ipc.h>
#include <sys/shm.h>
#include <X11/extensions/XShm.h>

// I could not find the following prototypes in system 
// includes (I work with Linux),
// These declarations avoid a compiler warning.

extern "C" {
  int XShmQueryExtension(Display *);
  int XShmGetEventBase(Display *);
  }
#endif


#include <stdlib.h>
#include <stdio.h>

class XGraphicPort : public GraphicPort
{
 public:

  XGraphicPort(char *name, ScrCoord width, ScrCoord height, int verbose_level = MSG_ENV,
	       int no_framebuffer = 0);

      // Set no_framebuffer to 1 if X is used for drawing (instead of a PolygonEngine).


  virtual ~XGraphicPort(void);
  virtual void CommitAttributes(void);


  virtual void RGBMode(void);
  virtual void ColormapMode(void);

  virtual int SingleBuffer(void);
  virtual int DoubleBuffer(void);
  virtual int SwapBuffers(void);
  virtual int ZBuffer(const int yes);

  virtual void MapColor(const ColorIndex i, 
			const ColorComponent r, 
			const ColorComponent g, 
			const ColorComponent b );  

  virtual int SetGeometry(const ScrCoord width, const ScrCoord height);

  virtual char GetKey(void);
  virtual int  GetMouse(ScrCoord *x, ScrCoord *y);
  virtual int  WaitEvent(void);

   // Cntl codes and function.
 public:
  static OpCode ISXGPORT;
  static OpCode RESIZE;
  static OpCode XSTDPROP;
  static OpCode GETXWINDOW;
  static OpCode GETXDISPLAY;
  static OpCode GETXDRAWABLE;
  static OpCode GETXGC;
  static OpCode LEAVEXEVENTS; 


  virtual long Cntl(OpCode op, int arg);

   // Specific XWindow interface
 public:
   XGraphicPort(char *name, Display* display, XVisualInfo *vis_info, 
		int verbose_level = MSG_ENV, int no_framebuffer = 0);
   int Bind(Window w);

   int  Resize(const ScrCoord width, const ScrCoord height);   
   
 protected: 

  // internal machinery

  virtual void Clear(UColorCode c);


                // Predicate procedure used by WaitEvent()
  static Bool predproc(Display *display, XEvent *event, char *arg);

                // X error handler
  static int HandleXError(Display *, XErrorEvent *);
  void InstallXErrorHandler(void);
  void UninstallXErrorHandler(void);

                // internal functions
  int          OpenDisplay(char* disp_name = "");
  XVisualInfo* GetVisualInfo(void);
  void         GetGraphicEndianess(XVisualInfo* vinfo); 
  void         OpenWindow(XVisualInfo* vinfo);
  int          XInit(char* disp_name = ""); 

  int  AllocateColormaps(void);
  void ResetColormaps(void);
  void ResetColortable(void);
  void LocalColormap(void);

  int  AllocateXImage(void);
  void FreeXImage(void);

  int  AllocateZBuffer(void);
  void FreeZBuffer(void);



#ifdef X_SHM
  XShmSegmentInfo _shminfo;
  int _completion_type;
#endif

  int      _leave_xevents; 
  int      _no_framebuffer;
  Pixmap   _pixmap;

  XImage  *_ximage;       
  Display *_display;
  int      _screen;
  Window   _window;
  GC       _gc;
  int      _global_cmap;
  int      _local_cmap;
  int      _local_cmap_flag;
  int      _shm_flag;
  Flags    _resources;
  static   int _xerror_flag;
  int      _buffered;
  char     _charbuff;

  // virtual constructor stuff

 public:
  static GraphicPort* Make(char *name, ScrCoord width, ScrCoord height, 
			   int verb = MSG_NONE);
};


#endif
