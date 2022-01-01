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
 * gcomp.h
 *
 */

#ifndef GCOMP_H
#define GCOMP_H

#include "flags.h"
#include "rect.h"
#include "gdefs.h"

const int ATTRIB_STACK_SZ = 100;

const int MSG_NONE      = 0;
const int MSG_QUIET     = 0;
const int MSG_ERROR     = 1;
const int MSG_WARNING   = 2;
const int MSG_INFO      = 3;
const int MSG_RESOURCE  = 4;
const int MSG_FUNCTION  = 4;
const int MSG_ALL       = 100;
const int MSG_ENV       = 101;


// OpCodes are used in Cntl() calls
typedef int OpCode;

const int G_TEXTURE_SHADES  = 32;
const int G_TEX_SHADE_SHIFT = 3; 

// This class represents a rendering context.
// It is used by SaveContext() and SetContext() functions.

class RenderContext
{
 public:
  RenderContext(void); 
  ~RenderContext(void); 
  void Activate(void);
  void Deactivate(void);
  int  Active(void);

 protected:
  ScrCoord    _width, _height;
  ColorIndex *_graph_mem;
  ZCoord     *_z_mem;
  ColorIndex  _colormap[GP_COLORMAP_SZ];
  UColorCode  _truecolormap[GP_COLORMAP_SZ];
  int         _bytes_per_line;
  int         _bits_per_pixel;
  int         _bytes_per_pixel;
  UColorCode  _R_mask;
  UColorCode  _G_mask;
  UColorCode  _B_mask;
  Rect        _clip;
  int         _active;
  ColorIndex *_tex_mem;
  ColorIndex *_tex_cmap;
  ScrCoord    _tex_size;
  UScrCoord   _tex_mask;
  UScrCoord   _tex_shift; 

  static RenderContext* _current;

  friend class GraphicPort;
  friend class XGraphicPort;
  friend class LiteXGraphicPort;     
};


// A component of the rendering pipeline

class GraphicComponent
{

 protected:
  
  int _verbose_level;
  int _verbose_request;
  
  Flags _attrib_stack[100];
  int   _attrib_stack_idx;

  Flags _last_attributes;
  const char *_proc_name;

  static ScrCoord      _width, _height;
  static ColorIndex   *_graph_mem;
  static ZCoord       *_z_mem;
  static ColorIndex    _colormap[GP_COLORMAP_SZ];
  static UColorCode    _truecolormap[GP_COLORMAP_SZ];
  static int           _bytes_per_line;
  static int           _bits_per_pixel;
  static int           _bytes_per_pixel;
  static UColorCode    _R_mask;
  static UColorCode    _G_mask;
  static UColorCode    _B_mask;
  static Rect          _clip;
  static ColorIndex*   _tex_mem;
  static ColorIndex*   _tex_cmap;
         ColorIndex    _local_tex_cmap[GP_COLORMAP_SZ * G_TEXTURE_SHADES];
  static ScrCoord      _tex_size;
  static UScrCoord     _tex_mask;
  static UScrCoord     _tex_shift; 

   
  static int           _argc;
  static char        **_argv;

 public:

  GraphicComponent(void);

  void Verbose(const int verbose_level);

  GraphicComponent& operator [] (const int verbose_request);
  GraphicComponent& operator << (const char *str);
  GraphicComponent& operator << (const char c);
  GraphicComponent& operator << (const int  i);
  GraphicComponent& operator << (const long i);
  GraphicComponent& operator << (const float  f);
  GraphicComponent& operator << (const double f);

  void PushAttributes(void);
  void PopAttributes(void);
  Flags&  Attributes(void);
  
  virtual void CommitAttributes(void);
  virtual ~GraphicComponent(void);

  static  int  UniqueOpCode(void);         // generate operation codes
  virtual long Cntl(OpCode op, int arg=0); // special operations

  void   SetCommandLine(int argc, char **argv);
  int    ArgC(void);
  char **ArgV(void);

  int IsSet(char *env_var_name); 
   
 private:
  static OpCode _max_op_code;

};


#include "gcomp.ih"

#endif




