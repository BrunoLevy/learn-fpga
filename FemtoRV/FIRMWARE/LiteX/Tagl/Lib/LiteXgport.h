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


#ifndef LITE_XGPORT_H
#define LITE_XGPORT_H

#include "gport.h"

const Flag XGPR_NONE            = 0;
const Flag XGPR_ZBUFFER         = 10;

const Flag XGPE_MALLOC  = 5;

#include <stdlib.h>
#include <stdio.h>

class LiteXGraphicPort : public GraphicPort
{
 public:

  LiteXGraphicPort(const char *name, int verbose_level = MSG_ENV);

  virtual ~LiteXGraphicPort(void);
  virtual void CommitAttributes(void);

  virtual void ZClear(void);
  virtual void ZClear(ZCoord z);
    
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
  virtual long Cntl(OpCode op, int arg);

 protected: 

  // internal machinery
  virtual void Clear(UColorCode c);

    
  int  AllocateZBuffer(void);
  void FreeZBuffer(void);

  Flags    _resources;

  char _key;
  // virtual constructor stuff

 public:
  static GraphicPort* Make(const char *name, ScrCoord width, ScrCoord height, 
			   int verb = MSG_NONE);
};


#endif
