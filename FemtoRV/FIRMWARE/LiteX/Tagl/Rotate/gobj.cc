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
 * gobj.C
 *
 */

#include "gobj.h"
#include <math.h>

// Global shading attributes

int GraphicObject::_gamma_ramp[GAMMA_VALUES];

MVector GraphicObject::_L(0,0,-M_BIG); 

GraphicObject::GraphicObject() {
   _L = MVector(0,0,-M_BIG);
}

int GraphicObject::_Lr = 0;
int GraphicObject::_Lg = 0;
int GraphicObject::_Lb = 0;

int GraphicObject::_Lc = 0;

int GraphicObject::_zoom      = 16;
int GraphicObject::_zoom_step = 4;

int GraphicObject::_width  = 0;
int GraphicObject::_height = 0;

// Destructor

GraphicObject::~GraphicObject(void)
{
}

// Pre-computations for Lighting models

void
GraphicObject::GammaRamp(gfloat gamma)
{
  int i;
  
  for(i=0; i<GAMMA_VALUES; i++)
    _gamma_ramp[i] = (int)((gfloat)M_BIG * 
			   (1.0 - exp(-(gfloat)(i << GAMMA_SHIFT) / ((gfloat)M_BIG * gamma))));
}

void 
GraphicObject::Shiny(gfloat factor, gfloat lambertian, gfloat specular)
{
  int i;

  _KD = (int)(lambertian * (gfloat)M_BIG);
  _KS = (int)(specular   * (gfloat)M_BIG);

  for(i=0; i<SPEC_VALUES; i++)
      _specular[i] = (int)((gfloat)M_BIG * 
			   pow((gfloat)i/(gfloat)SPEC_VALUES, factor));

  _flags.Set(GF_SPECULAR);
}

void
GraphicObject::Dull(void)
{
  _flags.Reset(GF_SPECULAR);
}

