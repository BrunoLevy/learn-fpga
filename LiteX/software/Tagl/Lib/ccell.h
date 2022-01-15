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
 * colorcell.h
 *
 */

#ifndef COLORCELL_H
#define COLORCELL_H

typedef int ColorComponent;

const Flag CC_NONE      = 0;
const Flag CC_USED      = 1;

class ColorCell
{
  Flags _flags;
  ColorComponent _r,_v,_b;

 public:

  ColorCell( void );
  void Set(ColorComponent  r, 
	   ColorComponent  v, 
	   ColorComponent  b);
  void Get(ColorComponent *r, ColorComponent *g, ColorComponent *b) const;
  Flags& Stat( void );
  
};

#include "ccell.ih"

#endif
