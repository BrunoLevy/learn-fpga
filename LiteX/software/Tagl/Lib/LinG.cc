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
 * LinG.cc
 *
 */

#include "LinG.h"
#include "gport.h"

// #define X_GPORT 

#ifdef X_GPORT
#include "Xgport.h"
#endif

#ifdef SVGA_GPORT
#include <processors/gport/SVGAgport.h>
#endif

GraphicPort  *LinG_GP        = 0;
ling_pixel   *LinG_graph_mem = 0;
ling_pixel   *LinG_colormap  = 0;
ling_modemask LinG_mode      = 0;
ling_coord    LinG_width;
ling_coord    LinG_height;


extern "C" {
   void init_gport_X() ;
}

int LinG_OpenScreen  (ling_coord width, ling_coord height, ling_modemask mode)
{

  init_gport_X() ;

  if(!(LinG_GP = GraphicPort::Make("LinG", width, height)))
    return 0;

   
#ifdef X_GPORT

  cerr << "setting standard properties"<< endl ;
   
  // keep aspect constant (Venus requires that).

  XSizeHints hint;

  hint.min_aspect.x = 320;
  hint.min_aspect.y = 200;
  hint.max_aspect.x = 320;
  hint.max_aspect.y = 200;
  hint.flags = PAspect;
  LinG_GP->Cntl(XGraphicPort::XSTDPROP, (int)&hint);
   
#endif 
   
   
  LinG_width   = width;
  LinG_height  = height;
  LinG_mode    = mode;

  // Disallow window resizing if no scaling.

#ifdef X_GPORT
  if(!(LinG_mode & LGF_Scale))
    LinG_GP->Cntl(XGraphicPort::RESIZE, 0);
#endif

  // Try to do double buffering in VRAM.
/*
#ifdef SVGA_GPORT
  LinG_GP->Cntl(SVGAGraphicPort::HARDSWP);
#endif
*/

  // Allocate an off-screen 8bpp bitmap.

  if( (LinG_mode & LGF_Scale)       ||
     !(LinG_mode & LGF_DirectPixel) || 
      (LinG_GP->BytesPerPixel() != 1))
    {
      if(!(LinG_graph_mem = new ling_pixel[width * height]))
	{
	  LinG_CloseScreen();
	  return 0;
	}

      LinG_mode &= ~LGF_DirectPixel;
      LinG_colormap = new ling_pixel[256];
      for(int i=0; i<256; i++)
	LinG_colormap[i] = i;
    }

  else

  // Use TAGL bitmap.

    {
      LinG_graph_mem = LinG_GP->GraphMem();
      LinG_colormap  = (ling_pixel *)LinG_GP->Colormap();
    }

  LinG_GP->Clear(BLACK);
  LinG_GP->SwapBuffers();  

  return 1;
}

void LinG_CloseScreen (void)
{
  if(LinG_GP)
    {
      delete LinG_GP;
      LinG_GP = 0;
    }


  if(!(LinG_mode & LGF_DirectPixel))
    {
      if(LinG_graph_mem)
	{
	  delete[] LinG_graph_mem;
	  LinG_graph_mem = 0;
	}

      if(LinG_colormap)
	delete[] LinG_colormap;
    }
}

ling_modemask LinG_GetMode (void)
{
  return LinG_mode;
}

ling_pixel *LinG_GraphMem (void)
{
  return LinG_graph_mem;
}

ling_pixel   *LinG_Colormap (void)
{
  return LinG_colormap;
}

void LinG_SwapBuffers (void)
{
  if(!(LinG_mode & LGF_DirectPixel))
    {
      if(LinG_mode & LGF_Scale) {
	LinG_GP->ScaleBuffer256(LinG_graph_mem, LinG_width, LinG_height); 
      } else {
        LinG_GP->SwapBuffers();
	ling_coord old_width = LinG_width ;
	ling_coord old_height = LinG_height ;
        LinG_width   = LinG_GP->Width() ;
        LinG_height  = LinG_GP->Height() ;
	if(LinG_width == old_width && LinG_height == old_height) {
   	   LinG_GP->CopyBuffer256(LinG_graph_mem);
	}
      }
    }

  LinG_GP->SwapBuffers();

}



void        LinG_SetRGBColor (ling_pixel idx, 
			      ling_colorcomponent r, 
			      ling_colorcomponent g, 
			      ling_colorcomponent b)
{
  LinG_GP->MapColor(idx, r, g, b);
}



ling_key          LinG_GetKey (void)
{
  return LinG_GP->GetKey();
}

ling_mousebuttons LinG_GetMouse (ling_coord *x, ling_coord *y)
{
    int my_x, my_y ;
    ling_mousebuttons result = LinG_GP->GetMouse(&my_x,&my_y);
    *x = my_x * LinG_width / LinG_GP->Width() ;
    *y = my_y * LinG_height / LinG_GP->Height() ;
    return result ;
}
