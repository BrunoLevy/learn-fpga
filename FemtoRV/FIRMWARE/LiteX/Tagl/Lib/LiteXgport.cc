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

#include "LiteXgport.h"
extern "C" {
#include "lite_fb.h"
}
#include <libbase/uart.h>
#include <libbase/console.h>
#include <stdlib.h>

OpCode LiteXGraphicPort::ISXGPORT     = 100;

long LiteXGraphicPort::Cntl(OpCode op, int arg) {
  if(op == ISXGPORT)
    {
      return 1;
    }
  return 0;
}

LiteXGraphicPort::LiteXGraphicPort(const char *name, int verbose_level)
    :GraphicPort(name, 640, 480, verbose_level)
{
   fb_init();
   fb_set_dual_buffering(1);
   _graph_mem = (ColorIndex*)fb_base;
   _bits_per_pixel = 24;
   _bytes_per_pixel = 4;
   _bytes_per_line  = _bytes_per_pixel * 640;
   _R_mask = ((UColorCode)255) << 16;
   _G_mask = ((UColorCode)255) << 8;
   _B_mask = ((UColorCode)255);
   Attributes().Set(GPA_DBUFF);
   _clip.Set(0,0,_width-1,_height-1);
   SaveContext();
   _tgc.Activate();
   _bytes_per_pixel = 4;
}

////
////
//
//   Attributes handling & destructor
//
////
////

LiteXGraphicPort::~LiteXGraphicPort(void)
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

// Restore current rendering context.
  _tgc = current_graphic_bus;
  RenderContext::_current = current;
  SetContext();
}

void LiteXGraphicPort::CommitAttributes(void)
{
  Flags changed;

  changed.SetAll(_last_attributes.GetAll() ^ Attributes().GetAll());

  if(changed.Get(GPA_ZBUFF))
    ZBuffer(Attributes().Get(GPA_ZBUFF));
}


////
////
//
// ZBuffer 
//
////
////

int LiteXGraphicPort::AllocateZBuffer(void)
{

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

void LiteXGraphicPort::FreeZBuffer(void)
{
  (*this)[MSG_RESOURCE] << "Freeing ZBuffer\n";

  if(_resources.Get(XGPR_ZBUFFER))
    delete[] _z_mem;

  _resources.Reset(XGPR_ZBUFFER);
}

////
////
//
// High level functions
//
////
////

void LiteXGraphicPort::MapColor(const ColorIndex idx, 
			    const ColorComponent r, 
			    const ColorComponent g, 
			    const ColorComponent b )
{
  _colortable[idx].Set(r,g,b);
  _colortable[idx].Stat().Set(CC_USED);
  //_truecolormap[idx] = lastcolor;
}  

void LiteXGraphicPort::RGBMode(void)
{
  (*this)[MSG_INFO] << "Switching to RGB mode\n";

  Attributes().Set(GPA_RGB);
  Attributes().Reset(GPA_CMAP);
}

void LiteXGraphicPort::ColormapMode(void)
{

  (*this)[MSG_INFO] << "Switching to colormap mode\n";

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

int LiteXGraphicPort::SingleBuffer(void)
{
   fb_set_dual_buffering(0);
   return 1;
}

int LiteXGraphicPort::DoubleBuffer(void)
{
  fb_set_dual_buffering(1);
  return 1;
}

int LiteXGraphicPort::SwapBuffers(void)
{
   fb_swap_buffers();
   _graph_mem = (ColorIndex*)fb_base;   
   return 1;
}

int  LiteXGraphicPort::WaitEvent(void) {
   if (readchar_nonblock()) {
       _key=getchar();
   }
   return (_key != 0);
}

char LiteXGraphicPort::GetKey(void)
{
    char result = _key;
    if(_key != 0) {
	_key = 0;
	return result;
    }
   if (readchar_nonblock()) {
       result=getchar();
   }
   return result;
}

int  LiteXGraphicPort::GetMouse(ScrCoord *x, ScrCoord *y)
{
   *x = 0;
   *y = 0;
   return 0;
}

int LiteXGraphicPort::ZBuffer(const int yes)
{
  int result;
  if(yes)
    {
	if((result = AllocateZBuffer()))
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
  

int LiteXGraphicPort::SetGeometry(const ScrCoord width, const ScrCoord height)
{
  return 0;
}


void LiteXGraphicPort::ZClear(void) {
    ZClear(0xffff);
}

void LiteXGraphicPort::ZClear(ZCoord z) {
    union {
	ZCoord zz[2];
	uint32_t val;
    };
    zz[0] = z;
    zz[1] = z;
    blitter_value_write(val);
    blitter_dma_writer_base_write((uint32_t)(_z_mem));
    blitter_dma_writer_length_write(FB_WIDTH*FB_HEIGHT*sizeof(ZCoord));
    blitter_dma_writer_enable_write(1);
    while(!blitter_dma_writer_done_read());
    blitter_dma_writer_enable_write(0);    
}


void 
LiteXGraphicPort::Clear(UColorCode c)
{
    blitter_value_write(0xff0000);
    blitter_dma_writer_base_write((uint32_t)(fb_base));
    blitter_dma_writer_length_write(FB_WIDTH*FB_HEIGHT*4);
    blitter_dma_writer_enable_write(1);
    while(!blitter_dma_writer_done_read());
    blitter_dma_writer_enable_write(0);    
}


////
////
//
// Virtual constructor stuff
//
////
////


GraphicPort* LiteXGraphicPort::Make(const char *name, ScrCoord width, ScrCoord height, 
				int verb)
{
  LiteXGraphicPort *GP = new LiteXGraphicPort(name, verb);
  if(GP->ErrorCode())
    {
      delete GP;
      return NULL;
    }
  return GP;
}

// The only purpose of this dummy class is to have its constructor
// called before the beginning of main(), so that LiteXGraphicPort::Make
// is registered to the virtual constructor.

extern "C" {
    void init_gport_LiteX() ;
}

void init_gport_LiteX() {
    GraphicPort::Register(LiteXGraphicPort::Make,GP_VC_NORMAL) ; 
}


