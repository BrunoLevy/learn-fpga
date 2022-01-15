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
 * Xgport.C
 *
 */


#include "Xgport.h"
#include <stdlib.h>

/*
OpCode XGraphicPort::ISXGPORT     = GraphicComponent::UniqueOpCode();
OpCode XGraphicPort::RESIZE       = GraphicComponent::UniqueOpCode();
OpCode XGraphicPort::XSTDPROP     = GraphicComponent::UniqueOpCode();
OpCode XGraphicPort::GETXDISPLAY  = GraphicComponent::UniqueOpCode();
OpCode XGraphicPort::GETXWINDOW   = GraphicComponent::UniqueOpCode();
OpCode XGraphicPort::GETXDRAWABLE = GraphicComponent::UniqueOpCode();
OpCode XGraphicPort::GETXGC       = GraphicComponent::UniqueOpCode();
OpCode XGraphicPort::LEAVEXEVENTS = GraphicComponent::UniqueOpCode();
*/

OpCode XGraphicPort::ISXGPORT     = 100;
OpCode XGraphicPort::RESIZE       = 101;
OpCode XGraphicPort::XSTDPROP     = 102;
OpCode XGraphicPort::GETXDISPLAY  = 103;
OpCode XGraphicPort::GETXWINDOW   = 104;
OpCode XGraphicPort::GETXDRAWABLE = 105;
OpCode XGraphicPort::GETXGC       = 106;
OpCode XGraphicPort::LEAVEXEVENTS = 107;

long
XGraphicPort::Cntl(OpCode op, int arg)
{
  if(op == ISXGPORT)
    {
      return 1;
    }
  else
  if(op == RESIZE)
    {
      XSizeHints  hint;
      hint.flags = PMinSize | PMaxSize;
      if(arg)
	{
	  hint.min_width  = MIN_WIDTH;
	  hint.min_height = MIN_HEIGHT;
	  hint.max_width  = MAX_WIDTH;
	  hint.max_height = MAX_HEIGHT;
	}
      else
	{
	  hint.min_width  = _width;
	  hint.min_height = _height;
	  hint.max_width  = _width;
	  hint.max_height = _height;
	  hint.flags = PMinSize | PMaxSize;
	}
      XSetStandardProperties (_display, 
			      _window, 
			      _name, 
			      _name, None, NULL, 0, &hint);
      return 1;
    }
  else
  if(op == XSTDPROP)
    {
      XSizeHints *hint = (XSizeHints *)arg;
      XSetStandardProperties(_display, 
			      _window, 
			      _name, 
			      _name, None, NULL, 0, hint);
      return 1;
    }
  else
  if(op == GETXDISPLAY)
    {
      return (long)_display;
    }
  else
  if(op == GETXWINDOW)
    {
      return (long)_window;
    }
  else
  if(op == GETXDRAWABLE)
    {
      return _resources.Get(XGPR_PIXMAP) ? _pixmap : _window;
    }
  else
  if(op == GETXGC)
    {
      return (long)_gc;
    }
  else
  if(op == LEAVEXEVENTS)
    {
      _leave_xevents = (int)arg;
      return 1; 
    }
  return 0;
}

XGraphicPort::XGraphicPort(char *name, ScrCoord width, ScrCoord height, int verbose_level, 
			   int no_framebuffer)
            :GraphicPort(name, width, height, verbose_level)
{
  char *env_str;

  _leave_xevents = 0; 
  _no_framebuffer = no_framebuffer;

  if((env_str = getenv("GPUREX")) && 
     (!strcmp(env_str,"YES") || !strcmp(env_str,"yes")))
    _no_framebuffer = 1;


  if(_no_framebuffer)
    (*this)[MSG_INFO] << "Using pure X functions (no framebuffer)\n";

  _error_code  = GPE_OK; 
  _xerror_flag = 0;
  _buffered    = 0;
  _resources.SetAll(XGPR_NONE);
  _proc_name = "XGraphicPort";

  if(!XInit())
    {
      (*this)[MSG_ERROR] << "could not init X stuff\n";
      return;
    }

#ifdef X_SHM  
  _shm_flag = XShmQueryExtension(_display);
  if(_shm_flag)
    {
      (*this)[MSG_INFO] << "X server has MIT XShm. Good.\n";
      _completion_type = XShmGetEventBase(_display) + ShmCompletion;
    }
#else
  _shm_flag = 0;
#endif

  _local_cmap_flag = 0;

  if(!AllocateXImage())
    return;

  Attributes().Set(GPA_DBUFF);

  if(!AllocateColormaps())
    return;

  ColormapMode();

  if(_resources.Get(XGPR_STD_XIMAGE) || _resources.Get(XGPR_SHM_XIMAGE))
    _bytes_per_line = _ximage->bytes_per_line;

  _clip.Set(0,0,_width-1,_height-1);

  if(_verbose_level >= MSG_INFO)
    {

      fprintf(stderr,"[TAGL] %s:: bits per pixel = %d\n", 
	      _proc_name, _bits_per_pixel);
      fprintf(stderr,"[TAGL] %s:: bytes per pixel = %d\n", 
	      _proc_name, _bytes_per_pixel);
      fprintf(stderr,"[TAGL] %s:: R mask = ",
	      _proc_name); printb(_R_mask); fprintf(stderr,"\n");
      fprintf(stderr,"[TAGL] %s:: G mask = ",
	      _proc_name); printb(_G_mask); fprintf(stderr,"\n");
      fprintf(stderr,"[TAGL] %s:: B mask = ",
	      _proc_name); printb(_B_mask); fprintf(stderr,"\n");
    }

  if(_no_framebuffer)
    _bytes_per_pixel = 0; // info for PolygonEngine virtual constructor

  SaveContext();
  _tgc.Activate();
}

XGraphicPort::XGraphicPort(char *name, Display* display, XVisualInfo *vis_info, 
			   int verbose_level, int no_framebuffer)
            :GraphicPort(name, 0, 0, verbose_level)
{

  (*this)[MSG_INFO] << "Creating bare framebuffer\n";

  char *env_str;

  _leave_xevents = 0; 
  _no_framebuffer = no_framebuffer;

  if((env_str = getenv("GPUREX")) && 
     (!strcmp(env_str,"YES") || !strcmp(env_str,"yes")))
    _no_framebuffer = 1;


  if(_no_framebuffer)
    (*this)[MSG_INFO] << "Using pure X functions (no framebuffer)\n";

  _error_code  = GPE_OK; 
  _xerror_flag = 0;
  _buffered    = 0;
  _resources.SetAll(XGPR_NONE);
  _proc_name = "XGraphicPort";

  _display = display;
  _screen = DefaultScreen(_display);
  _resources.Set(XGPR_SCREEN);

  GetGraphicEndianess(vis_info);

#ifdef X_SHM  
  _shm_flag = XShmQueryExtension(_display);
  if(_shm_flag)
    {
      (*this)[MSG_INFO] << "X server has MIT XShm. Good.\n";
      _completion_type = XShmGetEventBase(_display) + ShmCompletion;
    }
#else
  _shm_flag = 0;
#endif

  _local_cmap_flag = 0;

  Attributes().Set(GPA_DBUFF);

  if(_verbose_level >= MSG_INFO)
    {

      fprintf(stderr,"[TAGL] %s:: bits per pixel = %d\n", 
	      _proc_name, _bits_per_pixel);
      fprintf(stderr,"[TAGL] %s:: bytes per pixel = %d\n", 
	      _proc_name, _bytes_per_pixel);
      fprintf(stderr,"[TAGL] %s:: R mask = ",
	      _proc_name); printb(_R_mask); fprintf(stderr,"\n");
      fprintf(stderr,"[TAGL] %s:: G mask = ",
	      _proc_name); printb(_G_mask); fprintf(stderr,"\n");
      fprintf(stderr,"[TAGL] %s:: B mask = ",
	      _proc_name); printb(_B_mask); fprintf(stderr,"\n");
    }

  if(_no_framebuffer)
    _bytes_per_pixel = 0; // info for PolygonEngine virtual constructor
}

////
////
//
//   an X error handler: detect problems during XImage initialisation
//
////
////


int XGraphicPort::_xerror_flag;

int XGraphicPort::HandleXError(Display *display, XErrorEvent *event)
{
  _xerror_flag = 1;
  return 0;
}

void XGraphicPort::InstallXErrorHandler()
{
  (*this)[MSG_INFO] << "Installing X error handler\n";
  XSetErrorHandler(HandleXError);
  XFlush(_display);
}

void XGraphicPort::UninstallXErrorHandler()
{
  typedef int (*XErrFunPtr)(Display *, XErrorEvent *);

  (*this)[MSG_INFO] << "Uninstalling X error handler\n";
  XSetErrorHandler((XErrFunPtr)NULL);
  XFlush(_display);
}


////
////
//
//   Attributes handling & destructor
//
////
////

XGraphicPort::~XGraphicPort(void)
{

  // Deletion (colorcell deallocation) requires
  // a SetContext(). Before setting context, get
  // a copy of current context.

  RenderContext* current             = RenderContext::_current;   
  RenderContext  this_graphic_bus    = _tgc;          
  SaveContext();                                      
  RenderContext  current_graphic_bus = _tgc;          
  _tgc = this_graphic_bus;                            
  SetContext();


  if(_resources.Get(XGPR_ZBUFFER))
    FreeZBuffer();

  if(_resources.Get(XGPR_STD_XIMAGE) || 
     _resources.Get(XGPR_SHM_XIMAGE) ||
     _resources.Get(XGPR_PIXMAP))
    FreeXImage();

  ResetColormaps();

  if(_resources.Get(XGPR_GC))
    XFreeGC(_display, _gc);

  if(_resources.Get(XGPR_X_ERROR_HANDLER))
    UninstallXErrorHandler();

  if(_resources.Get(XGPR_WINDOW))
    XDestroyWindow(_display, _window);

  if(_resources.Get(XGPR_DISPLAY))
    XCloseDisplay(_display);


// Restore current rendering context.
  _tgc = current_graphic_bus;
  RenderContext::_current = current;
  SetContext();
}

void XGraphicPort::CommitAttributes(void)
{
  Flags changed;

  changed.SetAll(_last_attributes.GetAll() ^ Attributes().GetAll());

  if(changed.Get(GPA_CMAP) && Attributes().Get(GPA_CMAP))
    ColormapMode();

  if(changed.Get(GPA_RGB)  && Attributes().Get(GPA_RGB))
    RGBMode();

  if(changed.Get(GPA_ZBUFF))
    ZBuffer(Attributes().Get(GPA_ZBUFF));
}

////
////
//
//   Display, Window and VisualInfo
//
////
////

int
XGraphicPort::OpenDisplay(char* display_name)
{
  _display = XOpenDisplay(display_name);
  if (!_display) 
    {
    _error_code = XGPE_DISPLAY;  
    (*this)[MSG_ERROR] << "Cannot open display\n";
    return 0;
    }

  _resources.Set(XGPR_DISPLAY);

  _screen = DefaultScreen(_display);
 
  _resources.Set(XGPR_SCREEN);
  return 1;
}

XVisualInfo*
XGraphicPort::GetVisualInfo(void)
{
  static XVisualInfo vinfo;

  _bytes_per_pixel = 0;

  if(getenv("GX8BIT"))
    goto gx8bit;

  if(XMatchVisualInfo(_display, _screen, 24, TrueColor, &vinfo))
     {
        (*this)[MSG_INFO]    << "24bpp TrueColor display, you've got the high-score !!\n";
	return &vinfo;
     }
  else if(XMatchVisualInfo(_display, _screen, 16, TrueColor, &vinfo))
     {
        (*this)[MSG_INFO] << "16bpp TrueColor display, waooow !!\n";
	return &vinfo;
     }
  else if(XMatchVisualInfo(_display, _screen, 15, TrueColor, &vinfo))
     {
        (*this)[MSG_INFO] << "15bpp TrueColor display, waooow !!\n";
	return &vinfo;
     }
  else
  gx8bit:
       if(XMatchVisualInfo(_display, _screen, 8, PseudoColor, &vinfo))
     {
        (*this)[MSG_INFO] << "8bpp PseudoColor display\n";
	return &vinfo;
     }
  else if(XMatchVisualInfo(_display, _screen, 8, GrayScale, &vinfo))
     {
        (*this)[MSG_INFO] << "8bpp GrayScale display\n";
	return &vinfo;
     }
     
  XVisualInfo vis_template, *vis_list;
  int vis_num;

  (*this)[MSG_WARNING] << "Visual class should be either 8,15,16,or 24 bpp\n";
  (*this)[MSG_WARNING] << " for use with a PolygonEngine\n";

  vis_template.screen = _screen;
  vis_list = XGetVisualInfo(_display, VisualScreenMask, &vis_template, &vis_num);

  if(vis_num)
    {
    vinfo = *vis_list;
    return &vinfo;
    }


  if(!_no_framebuffer)
    _error_code = XGPE_VISUAL;

  return NULL;
}

void
XGraphicPort::GetGraphicEndianess(XVisualInfo* vinfo)
{
  _bits_per_pixel = vinfo->depth;

  if(_bits_per_pixel >= 24)
     _bytes_per_pixel = 4;
  else if(_bits_per_pixel > 8)
     _bytes_per_pixel = 2;
  else
     _bytes_per_pixel = 1;

  if(_bits_per_pixel ==  8)
    {
      _R_mask = ((UColorCode)3) << 4;
      _G_mask = ((UColorCode)3) << 2;
      _B_mask = ((UColorCode)3);
    }
  else
    {
      _R_mask = vinfo->red_mask;
      _G_mask = vinfo->green_mask;
      _B_mask = vinfo->blue_mask;
    }
}

void 
XGraphicPort::OpenWindow(XVisualInfo* vinfo)
{
  XSizeHints  hint;
  unsigned    long fg, bg;

  _error_code = GPE_OK;

  (*this)[MSG_RESOURCE] << "Opening window\n";

 
  hint.width      = _width;
  hint.height     = _height;
  hint.min_width  = MIN_WIDTH;
  hint.min_height = MIN_HEIGHT;
  hint.max_width  = MAX_WIDTH;
  hint.max_height = MAX_HEIGHT;

  hint.flags = PSize | PMinSize | PMaxSize;
  
  // foreground and background
  
  fg = WhitePixel (_display, _screen);
  bg = BlackPixel (_display, _screen);
  
  // build window

  if(_bits_per_pixel <= 8)
      _window = XCreateSimpleWindow (_display,
				     DefaultRootWindow (_display),
				     hint.x, hint.y,
				     hint.width, hint.height,
				     4, fg, bg);
  
  else
      {
	  XSetWindowAttributes wattr;
	  int                  cmap;

	  cmap = XCreateColormap(_display, DefaultRootWindow (_display),
				 vinfo->visual, AllocNone);

	  wattr.colormap = cmap;
	  wattr.border_pixel = 0;

	  _window = XCreateWindow       (_display,
					 DefaultRootWindow (_display),
					 hint.x, hint.y,
					 hint.width, hint.height,
					 0, 
					 vinfo->depth,
					 InputOutput,
					 vinfo->visual,
					 CWColormap | CWBorderPixel, &wattr);
      }

  _resources.Set(XGPR_WINDOW);

  XSelectInput(_display, _window, StructureNotifyMask);
  XSetStandardProperties (_display, 
			  _window, 
			  _name, 
			  _name, None, NULL, 0, &hint);
  

  XMapWindow(_display, _window);
  
  // Wait for window map.
  while(1) 
    {
      XEvent xev;

      XNextEvent(_display, &xev);
      if(xev.type == MapNotify && xev.xmap.event == _window)
	break;
    }

  XSelectInput(_display, _window, KeyPressMask | StructureNotifyMask | ExposureMask 
	       | PointerMotionMask);

  _gc = XCreateGC(_display, _window, 0, NULL);
  _resources.Set(XGPR_GC);
}

int
XGraphicPort::XInit(char* disp_name)
{
   if(!OpenDisplay(disp_name))
      return 0;
      
   XVisualInfo* vinfo = GetVisualInfo();
   if(!vinfo)
      return 0;
      
   GetGraphicEndianess(vinfo);
   OpenWindow(vinfo);
   
   return 1;
}

int
XGraphicPort::Bind(Window w)
{
   _window = w;
   Window       dummy_w;
   int          dummy_i;
   unsigned int dummy_ui;
   
   if(!XGetGeometry(_display, _window, 
                    &dummy_w, &dummy_i, &dummy_i,
                    (unsigned int*)&_width, (unsigned int*)&_height, 
		    &dummy_ui, &dummy_ui))
     {
        (*this)[MSG_ERROR] << "Could not get window geometry\n";
	return 0;
     }

  _gc = XCreateGC(_display, _window, 0, NULL);
  _resources.Set(XGPR_GC);
     
   Resize(_width, _height);
   AllocateColormaps();
   ColormapMode();
   SaveContext();
   _tgc.Activate();
   return 1;
}

////
////
//
//   Utilities for colormaps
//
////
////


int XGraphicPort::AllocateColormaps(void)
{

  if(_bits_per_pixel > 8)
    {
      (*this)[MSG_INFO] << "Colormap emulation\n";
      return 1;
    }

  (*this)[MSG_INFO] << "Allocating colormaps\n";

  _global_cmap = XDefaultColormap(_display, _screen);
  _resources.Set(XGPR_GLOBAL_CMAP);

  return 1;
}

void XGraphicPort::LocalColormap(void)
{
  XColor xcolor;
  XWindowAttributes xwa;
  int i,r,g,b;


  (*this)[MSG_INFO] << "Allocating local colormap\n";

  XGetWindowAttributes(_display, _window, &xwa);
  _local_cmap  = XCreateColormap(_display, _window, xwa.visual, AllocNone);
  _resources.Set(XGPR_LOCAL_CMAP);
  XSetWindowColormap(_display, _window, _local_cmap);
  _local_cmap_flag = 1;

  xcolor.flags = DoRed | DoGreen | DoBlue;

  for(i=0; i<GP_COLORMAP_SZ; i++)
    if(_colortable[i].Stat().Get(CC_USED))
      {
	_colortable[i].Get(&r,&g,&b);
	xcolor.red   = r << 8;
	xcolor.green = g << 8;
	xcolor.blue  = b << 8;
	if(!XAllocColor(_display, _local_cmap, &xcolor))
	  {
	    (*this)[MSG_ERROR] << "could not allocate color in local cmap (strange)\n";
	    exit(1);
	  }
	_colormap[i] = (ColorIndex)(xcolor.pixel);
      }
}

void XGraphicPort::ResetColortable(void)
{
  int c;

  for(c=0; c<GP_COLORMAP_SZ; c++)
    _colortable[c].Stat().Reset(CC_USED);
}

void XGraphicPort::ResetColormaps(void)
{
  int c;

  if((_error_code != GPE_OK) || _bits_per_pixel > 8)
      return;

  (*this)[MSG_INFO] << "Reseting colormaps\n";

  if(_local_cmap_flag)
    {
      XSetWindowColormap(_display, _window, _global_cmap);
      XFreeColormap(_display, _local_cmap);
      _resources.Reset(XGPR_LOCAL_CMAP);
    }
  else
    for(c=0; c<GP_COLORMAP_SZ; c++)
      {
	unsigned long tmp_pixel;
	if(_colortable[c].Stat().Get(CC_USED))
	  {
	    tmp_pixel = _colormap[c];
	    XFreeColors(_display, _global_cmap, &tmp_pixel, 1, 0);
	  }
      }
  _local_cmap_flag = 0;
}

////
////
//
// XImage utilities
//
////
////

int XGraphicPort::AllocateXImage(void)
{

  if(!_resources.Get(XGPR_X_ERROR_HANDLER))
    {
      InstallXErrorHandler();
      _resources.Set(XGPR_X_ERROR_HANDLER);
    }

  if(_no_framebuffer)
    {
      _pixmap = XCreatePixmap(_display, 
			      _window,
			      _width, _height, _bits_per_pixel);
      _resources.Set(XGPR_PIXMAP);
      (*this)[MSG_RESOURCE] << "Pixmap allocated\n";
      return 1;
    }


#ifdef X_SHM
  if(_shm_flag)
    {
      if(!(_ximage = XShmCreateImage(_display, None, _bits_per_pixel, ZPixmap, 
				     NULL, &_shminfo, _width, _height)))
	{
	  (*this)[MSG_WARNING] << "could not create XShmImage\n";
	  _shm_flag = 0;
	  return AllocateXImage();
	}

      _shminfo.shmid = shmget(IPC_PRIVATE, (_ximage->bytes_per_line *
					    _ximage->height),
			      IPC_CREAT | 0777);

      if(_shminfo.shmid < 0)
	{
	  (*this)[MSG_WARNING] << "shmget() failed\n";
	  _shm_flag = 0;
	  XDestroyImage(_ximage);
	  return AllocateXImage();
	}

      _shminfo.shmaddr = (char *)shmat(_shminfo.shmid, 0, 0);

      if (_shminfo.shmaddr == ((char *) -1)) 
	{
	  (*this)[MSG_WARNING] << "shmat() failed\n";
	  _shm_flag = 0;
	  XDestroyImage(_ximage);
	  return AllocateXImage();
	}

      _ximage->data = _shminfo.shmaddr;
      _graph_mem    = (ColorIndex *) _ximage->data;
      _shminfo.readOnly = False;

      XShmAttach(_display, &_shminfo);
      XSync(_display, False);

      if (_xerror_flag) 
	{
	  (*this)[MSG_WARNING] << "XShm error occured\n";
	  XDestroyImage(_ximage);
	  _shm_flag    = 0;
	  _xerror_flag = 0;
	  return AllocateXImage();
	} 

      shmctl(_shminfo.shmid, IPC_RMID, 0);
      _resources.Set(XGPR_SHM_XIMAGE);

      (*this)[MSG_RESOURCE] << "Shm XImage created\n";
      return 1;
    }
  else
    {
      (*this)[MSG_INFO] << "Switching to native X calls\n";
#endif

      if(!(_ximage = XCreateImage(_display, None,  _bits_per_pixel, ZPixmap, 0, NULL,
				  _width, _height, _bytes_per_pixel*8, 0)))
	{
	  (*this)[MSG_ERROR] << "Could not create XImage\n";
	  _error_code = XGPE_XIMAGE;
	  return 0;
	}

      if(!(_ximage->data = (char *)malloc(_height*_width*_bytes_per_pixel)))
	{
	  (*this)[MSG_ERROR] << "Could not alloc img buffer\n";
	  _error_code = XGPE_MALLOC;
	  return 0;
	}
      
      _graph_mem = (unsigned char *)(_ximage->data);
      _resources.Set(XGPR_STD_XIMAGE);
      (*this)[MSG_RESOURCE] << "Std XImage created\n";      
      return 1;
      
#ifdef X_SHM
    }
#endif

if(_resources.Get(XGPR_X_ERROR_HANDLER))
  UninstallXErrorHandler();

}

void XGraphicPort::FreeXImage(void)
{

#ifdef X_SHM
  if(_resources.Get(XGPR_SHM_XIMAGE))
    {
      XShmDetach(_display,&_shminfo);
      XDestroyImage(_ximage);
      shmdt(_shminfo.shmaddr);
      _resources.Reset(XGPR_SHM_XIMAGE);
      (*this)[MSG_RESOURCE] << "Shm XImage destroyed\n";
    }
#endif

  if(_resources.Get(XGPR_STD_XIMAGE))
    {
      XDestroyImage(_ximage);
      _resources.Reset(XGPR_STD_XIMAGE);
      (*this)[MSG_RESOURCE] << "Std XImage destroyed\n";
    }

  if(_resources.Get(XGPR_PIXMAP))
    {
      XFreePixmap(_display,_pixmap);
      _resources.Reset(XGPR_PIXMAP);
      (*this)[MSG_RESOURCE] << "Pixmap destroyed\n";
    }
}


////
////
//
// ZBuffer 
//
////
////

int XGraphicPort::AllocateZBuffer(void)
{
  if(_no_framebuffer)
    {
      (*this)[MSG_WARNING] << "No ZBuffer available in pure X mode\n";
      return 0;
    }

  if(_resources.Get(XGPR_ZBUFFER))
    {
      (*this)[MSG_WARNING] << "ZBuffer already allocated\n";
      return 1;
    }

  if(!(_z_mem = new ZCoord[_width * _height]))
    {
      (*this)[MSG_ERROR] << "could not alloc ZBuffer\n";
      _error_code = XGPE_MALLOC;
      return 0;
    }

  _resources.Set(XGPR_ZBUFFER);

  (*this)[MSG_RESOURCE] << "ZBuffer allocated\n";
  return 1;
}

void XGraphicPort::FreeZBuffer(void)
{
  (*this)[MSG_RESOURCE] << "Freeing ZBuffer\n";

  if(_resources.Get(XGPR_ZBUFFER))
    delete[] _z_mem;

  _resources.Reset(XGPR_ZBUFFER);
}


////
////
//
// Resize frame buffer & Z buffer
//
////
////


int XGraphicPort::Resize(const ScrCoord width, const ScrCoord height)
{
  int retval = 1;

  (*this)[MSG_INFO] << "Resizing to " << width << "x" << height << "\n";

  _width  = width;
  _height = height;

  int realloc_pixmap = _resources.Get(XGPR_PIXMAP); 
   
  if(_resources.Get(XGPR_STD_XIMAGE) || 
     _resources.Get(XGPR_SHM_XIMAGE) || 
     _resources.Get(XGPR_PIXMAP))
     FreeXImage();
     
  if(!_no_framebuffer || realloc_pixmap)   
     retval = AllocateXImage();

  if(_resources.Get(XGPR_STD_XIMAGE) || _resources.Get(XGPR_SHM_XIMAGE))
    _bytes_per_line = _ximage->bytes_per_line;

  if(_resources.Get(XGPR_ZBUFFER))
    {
      FreeZBuffer();
      retval &= AllocateZBuffer();
    }

  _clip.Set(0, 0, _width - 1, _height - 1);

  return retval;
}


////
////
//
// High level functions
//
////
////

void XGraphicPort::MapColor(const ColorIndex idx, 
			    const ColorComponent r, 
			    const ColorComponent g, 
			    const ColorComponent b )
{
  XColor     xcolor;
  UColorCode lastcolor = 0;

  StoreColor(idx,r,g,b);

  if(!_no_framebuffer && (_bits_per_pixel > 8))
    {
      _colortable[idx].Stat().Set(CC_USED);
      _colortable[idx].Set(r,g,b);
      return;
    }

  xcolor.flags = DoRed | DoGreen | DoBlue;
  xcolor.red   = r << 8;
  xcolor.green = g << 8;
  xcolor.blue  = b << 8;
  xcolor.pixel = idx;

  if(_local_cmap_flag)
    {
      if(_colortable[idx].Stat().Get(CC_USED))
	{
	  unsigned long tmp_pixel = _colormap[idx];
	  XFreeColors(_display, _local_cmap, &tmp_pixel, 1, 0);
	}

      if(!XAllocColor(_display, _local_cmap, &xcolor))
	{
	  (*this)[MSG_ERROR] << "could not allocate color in local cmap (panic!)\n";
	  exit(1);
	}

      _colormap[idx] = (ColorIndex)(xcolor.pixel);
      lastcolor      = (UColorCode)(xcolor.pixel);
    }
  else
    {
      if(_colortable[idx].Stat().Get(CC_USED))
	{
	  unsigned long tmp_pixel = _colormap[idx];
	  XFreeColors(_display, _global_cmap, &tmp_pixel, 1, 0);
	}

      if(XAllocColor(_display, _global_cmap, &xcolor))
	{
	  _colormap[idx] = (ColorIndex)(xcolor.pixel);
	  lastcolor      = (UColorCode)(xcolor.pixel);
	}
      else
	{
	  (*this)[MSG_INFO] << "switching to local colormap mode\n";
	  ResetColormaps();
	  LocalColormap();
	  MapColor(idx,r,g,b);
	}
    }

  _colortable[idx].Set(r,g,b);
  _colortable[idx].Stat().Set(CC_USED);
  _truecolormap[idx] = lastcolor;

}  

void XGraphicPort::RGBMode(void)
{
  int r,g,b;

  (*this)[MSG_INFO] << "Switching to RGB mode\n";

  ResetColormaps();
  ResetColortable();

  if(_no_framebuffer || (_bits_per_pixel == 8))
    for(r=0; r<4; r++)
      for(g=0; g<4; g++)
        for(b=0; b<4; b++)
	  MapColor(b + (g << 2) + (r << 4), r << 6, g << 6, b << 6);

  Attributes().Set(GPA_RGB);
  Attributes().Reset(GPA_CMAP);
}

void XGraphicPort::ColormapMode(void)
{

  (*this)[MSG_INFO] << "Switching to colormap mode\n";

  ResetColormaps();
  ResetColortable();

// default colors

  MapColor(BLACK,   0,   0,   0   );
  MapColor(RED,     255, 0,   0   );
  MapColor(GREEN,   0,   255, 0   );
  MapColor(YELLOW,  255, 255, 0   );
  MapColor(BLUE,    0,   0,   255 );
  MapColor(MAGENTA, 255, 0,   255 );
  MapColor(CYAN,    0,   255, 255 );
  MapColor(WHITE,   255, 255, 255 );

  Attributes().Set(GPA_CMAP);
  Attributes().Reset(GPA_RGB);
}


int XGraphicPort::SingleBuffer(void)
{
  if(_no_framebuffer)
    {
      FreeXImage();
      return 1;
    }

  (*this)[MSG_WARNING] << "SingleBuffer mode not available for X/PolygonEngine\n";
  return 0;
}

int XGraphicPort::DoubleBuffer(void)
{
  if(_no_framebuffer && !_resources.Get(XGPR_PIXMAP))
    {
      AllocateXImage();
      return 1;
    }

  (*this)[MSG_WARNING] << "You are ALWAYS in DoubleBuffer mode under X/PolygonEngine\n";
  return 1;
}

int XGraphicPort::SwapBuffers(void)
{

  XEvent xev;


  if(_no_framebuffer)
    {
      if(_resources.Get(XGPR_PIXMAP))
	XCopyArea(_display, _pixmap, _window, _gc, 0, 0, _width, _height, 0, 0);

      if(!_leave_xevents)
	 {
	    if (!XCheckWindowEvent(_display, _window, StructureNotifyMask, &xev))
	       return 1;

	    if((xev.xconfigure.window == _window) && (xev.type == ConfigureNotify))
	      {
		 int w  = ((XConfigureEvent *)&xev)->width;
		 int h  = ((XConfigureEvent *)&xev)->height;
		 if((w != _width) || (h != _height))
		    Resize(w, h);
	      }
	 }
       else
	 {
	    unsigned int w,h;
	    Window       dummy_w;
	    int          dummy_i;
	    unsigned int dummy_ui;

	    XGetGeometry(_display, _window, &dummy_w,
			 &dummy_i, &dummy_i,
			 &w, &h,
			 &dummy_ui, &dummy_ui);
	    
	    if((w != _width) || (h != _height))
	       Resize(w, h);
	 }
      
      return 1;
    }

#ifdef X_SHM

  if (_shm_flag) 
    {

      XShmPutImage(_display, _window, _gc, 
		     _ximage, 
		     0, 0, 0, 0,
		     _width, _height, True);

      XFlush(_display);
      if(_leave_xevents)
       {
	  XEvent ev;
	  while(!XCheckTypedWindowEvent(_display, _window, _completion_type, &ev));
	  unsigned int w,h;
	  Window       dummy_w;
	  int          dummy_i;
	  unsigned int dummy_ui;

	  XGetGeometry(_display, _window, &dummy_w,
		       &dummy_i, &dummy_i,
		       &w, &h,
		       &dummy_ui, &dummy_ui);
	    
	  if((w != _width) || (h != _height))
	     Resize(w, h);	  
       }
      else
       while(1) 
	 {
	    XNextEvent(_display, &xev);
	    if(xev.type == _completion_type)
	       break;
	    
	    else
	       if (xev.type == KeyPress)
	      {
		 KeySym ks;
		 _buffered = 
		 (XLookupString((XKeyEvent *)&xev, 
				&_charbuff, 1, &ks, NULL) > 0);
		 switch(ks)
                {
		 case XK_Return:
		   _buffered = 1;
		   _charbuff = GK_Return;
		   break;
		 case XK_Escape:
		   _buffered = 1;
		   _charbuff = GK_Escape;
		   break;
		 case XK_Left:
		   _buffered = 1;
		   _charbuff = GK_Left;
		   break;
		 case XK_Right:
		   _buffered = 1;
		   _charbuff = GK_Right;
		   break;
		 case XK_Up:
		   _buffered = 1;
		   _charbuff = GK_Up;
		   break;
		 case XK_Down:
		   _buffered = 1;
		   _charbuff = GK_Down;
		   break;
      		}
	      }
	    else
	       if ((xev.xconfigure.window == _window) && (xev.type == ConfigureNotify))
	      {
		 int w  = ((XConfigureEvent *)&xev)->width;
		 int h  = ((XConfigureEvent *)&xev)->height;
		 if((w != _width) || (h != _height))
		    Resize(w, h);
	      }
	 }
    }
   else 
     {
#endif
	XPutImage(_display, _window, _gc, _ximage, 0, 0, 0, 0, _width, _height);
	
	if (!XCheckWindowEvent(_display, _window, StructureNotifyMask, &xev))
	   return 1;
	
	if((xev.xconfigure.window == _window) && (xev.type == ConfigureNotify))
	  {
	     int w  = ((XConfigureEvent *)&xev)->width;
	     int h  = ((XConfigureEvent *)&xev)->height;
	     if((w != _width) || (h != _height))
	     	Resize(w, h);
	  }
	
#ifdef X_SHM
     }
#endif
   return 1;
}


Bool XGraphicPort::predproc(Display *display, XEvent *event, char *arg)
{
  if(event->xany.window == *(Window *)arg)
    return True;
  else
    return False;
}

int XGraphicPort::WaitEvent(void)
{
  XEvent event;
  XPeekIfEvent(_display, &event, predproc, (char *)&_window);
  return event.type;
}

char XGraphicPort::GetKey(void)
{
  char	q = 0;
  XEvent xev;
  KeySym ks;
  
  if(_buffered)
    {
      _buffered = 0;
      return _charbuff;
    }

  if (!XCheckWindowEvent(_display, _window, KeyPressMask, &xev))
    return 0;
  
  if ((xev.type == KeyPress))
    {

     if(XLookupString((XKeyEvent *)&xev, &q, 1, &ks, NULL) > 0)
       return q;

      switch(ks)
	{
	case XK_Return:
	  q = GK_Return;
	  break;
	case XK_Escape:
	  q = GK_Escape;
	  break;
	case XK_Left:
	  q = GK_Left;
	  break;
	case XK_Right:
	  q = GK_Right;
	  break;
	case XK_Up:
	  q = GK_Up;
	  break;
	case XK_Down:
	  q = GK_Down;
	  break;
	}
    }
	
  return q;
}

int  XGraphicPort::GetMouse(ScrCoord *x, ScrCoord *y)
{
  Window	rootw, childw;
  int		sx, sy;
  unsigned int	mask;

  static int last_x = 0;
  static int last_y = 0; 
   
  XQueryPointer(_display, _window, &rootw, &childw, &sx, &sy, x, y, 
		&mask);

  if( (*x >= 0) && (*y >= 0) && (*x < _width) && (*y < _height))
     {
	last_x = *x;
	last_y = *y;
	return(mask >> 8);
     }
   
   *x = last_x;
   *y = last_y;
   
   return 0;
}

int XGraphicPort::ZBuffer(const int yes)
{
  int result;
  if(yes)
    {
      if(result = AllocateZBuffer())
	Attributes().Set(GPA_ZBUFF);
    }
  else
    {
      result = 1;
      FreeZBuffer();
      Attributes().Reset(GPA_ZBUFF);
    }
  return result;
}
  

int XGraphicPort::SetGeometry(const ScrCoord width, const ScrCoord height)
{
  int retval;

  if((width == _width) && (height == _height))
    return 1;

  retval = Resize(width, height);
  
  if(_resources.Get(XGPR_WINDOW))
     {
     XResizeWindow(_display, _window, _width, _height);
  
     // Wait for window resize.
     if(!_leave_xevents)
     while(1) 
        {
          XEvent xev;

          XNextEvent(_display, &xev);
	  if(xev.type == Expose && xev.xmap.event == _window && !xev.xexpose.count)
	     break;
        }
     }
  return retval;
}


void 
XGraphicPort::Clear(UColorCode c)
{
  if(_no_framebuffer)
    {

      XSetForeground(_display, _gc, c);

      if(_resources.Get(XGPR_PIXMAP))
	XFillRectangle(_display, _pixmap, _gc, 0, 0, _width, _height);
      else
	XFillRectangle(_display, _window, _gc, 0, 0, _width, _height);
    }
  else
    GraphicPort::Clear(c);
}

////
////
//
// Virtual constructor stuff
//
////
////


GraphicPort* XGraphicPort::Make(char *name, ScrCoord width, ScrCoord height, 
				int verb)
{
  XGraphicPort *GP = new XGraphicPort(name, width, height, verb);
  if(GP->ErrorCode())
    {
      delete GP;
      return NULL;
    }
  return GP;
}

// The only purpose of this dummy class is to have its constructor
// called before the beginning of main(), so that XGraphicPort::Make
// is registered to the virtual constructor.

extern "C" {
    void init_gport_X() ;
}

void init_gport_X() {
      GraphicPort::Register(XGraphicPort::Make,GP_VC_NORMAL) ; 
}


