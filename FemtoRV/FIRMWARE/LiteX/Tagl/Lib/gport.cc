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
 * gport.C
 *
 */

#include "gproc.h"
#include <stdio.h>
#include <string.h>


#pragma GCC diagnostic ignored "-Wstrict-aliasing"

// A virtual destructor for GraphicPorts

GraphicPort::~GraphicPort(void)
{
}




// Virtual constructor

int GraphicPort::_entries = 0;
GraphicPort_VC_Entry GraphicPort::_entry[VC_ENTRIES];  

void GraphicPort::Register(const GraphicPort_MakeFun make, const int flags)
{
  assert(_entries < VC_ENTRIES);
  _entry[_entries].make    = make;
  _entry[_entries].flags   = flags;
  _entries++;
  char *tmp;

  if((tmp = getenv("GVERBOSE")) && (atoi(tmp) >=  MSG_INFO))
    printf("[TAGL_VC] GraphicPort::Register() called - %d entries\n",_entries);

}

GraphicPort* GraphicPort::Make(const char* name, ScrCoord width, ScrCoord height, 
				   int verb)
{
  int i;
  GraphicPort *GP = NULL;
  for(i=0; i<_entries; i++)
    if((!_entry[i].flags) && (GP = _entry[i].make(name, width, height, verb)))
      return GP;

  for(i=0; i<_entries; i++)
    if((_entry[i].flags) && (GP = _entry[i].make(name, width, height, verb)))
      return GP;
  
  char *tmp;

  if((tmp = getenv("GVERBOSE")) && (atoi(tmp) >=  MSG_ERROR))
     printf("[TAGL_VC] GraphicPort::Make() No constructor available for this technology\n");

  return NULL;
}


void GraphicPort::Clear(UColorCode x)
{
  typedef struct
    {
      unsigned char r,g,b;
    } Pixel24;

  switch(_bytes_per_pixel)
    {
    case 1:
      memset(_graph_mem, (unsigned char)x, _bytes_per_line * _height);
      break;
    case 2:
      {
	unsigned short *graph_ptr;
	int size = (_bytes_per_line * _height) >> 1;
	for(graph_ptr = (unsigned short *)_graph_mem; size > 0; size--)
	  *(graph_ptr++) = (unsigned short)x;
      }
      break;
    case 3:
      {
	Pixel24 *graph_ptr;
	int size = (_bytes_per_line * _height) / 3;
	for(graph_ptr = (Pixel24 *)_graph_mem; size > 0; size--)
	  *(graph_ptr++) = *(Pixel24 *)&x; // little endian only !! :-(
      }
      break;
    case 4:
      {
	uint32 *graph_ptr;
	int size = (_bytes_per_line * _height) >> 2;
	for(graph_ptr = (uint32 *)_graph_mem; size > 0; size--)
	  *(graph_ptr++) = (uint32)x;
      }
      break;
    default:
      (*this)[MSG_ERROR]   << "No code to clear this graphic port\n";
      (*this)[MSG_WARNING] << "Setting pixel values to 0\n";
      memset(_graph_mem, 0, _bytes_per_line * _height);
      break;
    }
}

void GraphicPort::ZClear(void)
{
  if(Attributes().Get(GPA_ZBUFF))
    memset(_z_mem, 255, _width * _height * sizeof(ZCoord));
}

void GraphicPort::ZClear(ZCoord z)
{
  ZCoord *z_ptr;
  int size = _width * _height;
  for(z_ptr = _z_mem; size > 0; size--)
    *(z_ptr++) = z;
}


void GraphicPort::CopyBuffer256(ColorIndex *buffer)
{

  typedef struct
    {
      unsigned char r,g,b;
    } Pixel24;

  ColorIndex *src = buffer;
  int x,y;

  switch(_bytes_per_pixel)
    {

    case 1:
      {
	unsigned char *line_ptr = _graph_mem;
	ColorIndex *dst;

	for(y = 0; y < _height; y++, line_ptr += _bytes_per_line)
	    for(x = 0, dst = line_ptr; x < _width; x++)
	      *(dst++) = _colormap[*(src++)];
      }
      break;

    case 2:
      {
	unsigned char  *line_ptr = _graph_mem;
	unsigned short *dst;

	for(y = 0; y < _height; y++, line_ptr += _bytes_per_line)
	    for(x = 0, dst = (unsigned short *)line_ptr; x < _width; x++)
	      *(dst++) = (unsigned short)_truecolormap[*(src++)];
      }
      break;

    case 3:
      {
	unsigned char  *line_ptr = _graph_mem;
	Pixel24  *dst;

	for(y = 0; y < _height; y++, line_ptr += _bytes_per_line)
	    for(x = 0, dst = (Pixel24 *)line_ptr; x < _width; x++)
	      *(dst++) = *(Pixel24 *)&(_truecolormap[*(src++)]); 

      // WARNING: little endian dependant code !!

      }
      break;

    case 4:
      {
	unsigned char  *line_ptr = _graph_mem;
        uint32 *dst;

	for(y = 0; y < _height; y++, line_ptr += _bytes_per_line)
	    for(x = 0, dst = (uint32 *)line_ptr; x < _width; x++)
	      *(dst++) = _truecolormap[*(src++)]; 

      }
      break;

    default:
      (*this)[MSG_ERROR] << "Invalid depth for CopyBuffer256()\n";
      break;

    }
}


void GraphicPort::ScaleBuffer256(ColorIndex *buffer, 
				 ScrCoord width, ScrCoord height)
{
  typedef struct
    {
      unsigned char r,g,b;
    } Pixel24;

  ColorIndex    *src;
  ColorIndex    *src_lineptr = buffer; 
  unsigned char *dst_lineptr = _graph_mem;
  int i,j;
  int Ex = (width  << 1) - _width;
  int ex;
  int ey = (height << 1) - _height;

  switch(_bytes_per_pixel)
    {

    case 1:
      {
	ColorIndex *dst;

	for(i=0; i<_height; i++, dst_lineptr += _bytes_per_line)
	  {
	    ex = Ex;
	    dst = dst_lineptr;
	    src = src_lineptr;

	    for(j=0; j<_width; j++, dst++)
	      {
		*dst = _colormap[*src];
		while(ex >= 0)
		  {
		    src++;
		    ex -= (_width << 1);
		  }
		ex += (width << 1);
	      }

	    while(ey >= 0)
	      {
		src_lineptr += width;
		ey -= (_height << 1);
	      }
	    ey += (height << 1);
	  }
      }
      break;

    case 2:
      {
	unsigned short *dst;

	for(i=0; i<_height; i++, dst_lineptr += _bytes_per_line)
	  {
	    ex = Ex;
	    dst = (unsigned short *)dst_lineptr;
	    src = src_lineptr;

	    for(j=0; j<_width; j++, dst++)
	      {
		*dst = (unsigned short)_truecolormap[*src];
		while(ex >= 0)
		  {
		    src++;
		    ex -= (_width << 1);
		  }
		ex += (width << 1);
	      }

	    while(ey >= 0)
	      {
		src_lineptr += width;
		ey -= (_height << 1);
	      }
	    ey += (height << 1);
	  }
      }
      break;

    case 3:
      {
	Pixel24 *dst;

	for(i=0; i<_height; i++, dst_lineptr += _bytes_per_line)
	  {
	    ex = Ex;
	    dst = (Pixel24 *)dst_lineptr;
	    src = src_lineptr;

	    for(j=0; j<_width; j++, dst++)
	      {
		*dst = *(Pixel24 *)&_truecolormap[*src]; // endian dependant !!
		while(ex >= 0)
		  {
		    src++;
		    ex -= (_width << 1);
		  }
		ex += (width << 1);
	      }

	    while(ey >= 0)
	      {
		src_lineptr += width;
		ey -= (_height << 1);
	      }
	    ey += (height << 1);
	  }
      }
      break;

    case 4:
      {
	uint32 *dst;

	for(i=0; i<_height; i++, dst_lineptr += _bytes_per_line)
	  {
	    ex = Ex;
	    dst = (uint32 *)dst_lineptr;
	    src = src_lineptr;

	    for(j=0; j<_width; j++, dst++)
	      {
		*dst = _truecolormap[*src]; 
		while(ex >= 0)
		  {
		    src++;
		    ex -= (_width << 1);
		  }
		ex += (width << 1);
	      }

	    while(ey >= 0)
	      {
		src_lineptr += width;
		ey -= (_height << 1);
	      }
	    ey += (height << 1);
	  }
      }
      break;

    default:
      (*this)[MSG_ERROR] << "Invalid depth for CopyBuffer256()\n";
      break;

    }
}


void         
GraphicPort::TextureBind(UColorCode* texture, ScrCoord size)
{
   if(nbrbits(size) != 1)
     {
	(*this)[MSG_ERROR] << "TextureBind: invalid texture size (must be a power of 2)\n";
	return;
     }
   
   _tex_mem   = (ColorIndex*)texture;
   _tex_size  = size;
   _tex_shift = firstbit(size);
   _tex_mask  = size - 1;
}

inline 
UColorCode GraphicPort::RGB2ColorCode(ColorComponent R, 
				      ColorComponent G,
				      ColorComponent B,
				      ScrCoord x,
				      ScrCoord y)
{

UColorCode treshold = 
     (UColorCode)GraphicProcessor::D4[(x & D_PMASK ) + ((y & D_PMASK) << D_PSHIFT)];

UColorCode r_max  = (1L << nbrbits(_R_mask)) - 1;
UColorCode g_max  = (1L << nbrbits(_G_mask)) - 1;
UColorCode b_max  = (1L << nbrbits(_B_mask)) - 1;   
   
int r_bits = D_SHIFT + nbrbits(_R_mask);
int g_bits = D_SHIFT + nbrbits(_G_mask);
int b_bits = D_SHIFT + nbrbits(_B_mask);   

int r_shift = firstbit(_R_mask);
int g_shift = firstbit(_G_mask);
int b_shift = firstbit(_B_mask);
   
UColorCode r2, g2, b2;   
UColorCode r3, g3, b3;   
   
if(r_bits > 8)
    r2 = R << (r_bits - 8);
else   
    r2 = R >> (8 - r_bits);
   
if(g_bits > 8)
    g2 = G << (g_bits - 8);
else   
    g2 = G >> (8 - g_bits);   
   
if(b_bits > 8)
    b2 = B << (b_bits - 8);
else   
    b2 = B >> (8 - b_bits);   
   

r3 = r2 >> D_SHIFT;
g3 = g2 >> D_SHIFT;   
b3 = b2 >> D_SHIFT;
   
if((r2 & D_MASK) > treshold)
     r3++;
   
if((g2 & D_MASK) > treshold)
     g3++;
   
if((b2 & D_MASK) > treshold)
     b3++;
   
if(r3 > r_max)
     r3 = r_max;
   
if(g3 > g_max)
     g3 = g_max;
   
if(b3 > b_max)
     b3 = b_max;   
   
return (r3 << r_shift) | (g3 << g_shift) | (b3 << b_shift);

}
   
   
void 
GraphicPort::SetContext()
{
  if(!ContextIsActive())
    {
      _width            = _tgc._width;
      _height           = _tgc._height; 
      _graph_mem        = _tgc._graph_mem;
      _z_mem            = _tgc._z_mem;
      memcpy(_colormap,     _tgc._colormap,     sizeof(_colormap));
      memcpy(_truecolormap, _tgc._truecolormap, sizeof(_truecolormap));
      _bytes_per_line   = _tgc._bytes_per_line;
      _bytes_per_pixel  = _tgc._bytes_per_pixel;
      _R_mask           = _tgc._R_mask;
      _G_mask           = _tgc._G_mask;
      _B_mask           = _tgc._B_mask;
      _clip             = _tgc._clip;
      _tex_mem          = _tgc._tex_mem;
      _tex_cmap         = _tgc._tex_cmap; 
      _tex_size         = _tgc._tex_size;
      _tex_mask         = _tgc._tex_mask;
      _tex_shift        = _tgc._tex_shift; 
      _tgc.Activate();
    }
}

void 
GraphicPort::SaveContext()
{
  _tgc._width            = _width;
  _tgc._height           = _height; 
  _tgc._graph_mem        = _graph_mem;
  _tgc._z_mem            = _z_mem;
  memcpy(_tgc._colormap,     _colormap,     sizeof(_colormap));
  memcpy(_tgc._truecolormap, _truecolormap, sizeof(_truecolormap));
  _tgc._bytes_per_line   = _bytes_per_line;
  _tgc._bytes_per_pixel  = _bytes_per_pixel;
  _tgc._R_mask           = _R_mask;
  _tgc._G_mask           = _G_mask;
  _tgc._B_mask           = _B_mask;
  _tgc._clip             = _clip;
  _tgc._tex_mem          = _tex_mem;
  _tgc._tex_cmap         = _tex_cmap;
  _tgc._tex_size         = _tex_size;
  _tgc._tex_mask         = _tex_mask;
  _tgc._tex_shift        = _tex_shift;
}
