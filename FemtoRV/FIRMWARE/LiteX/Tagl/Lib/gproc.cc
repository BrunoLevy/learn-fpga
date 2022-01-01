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
 * gproc.C
 *
 */

#include "gproc.h"
// #include "dldlinker.h"

// Dithering matrix

int 
GraphicProcessor::D4[16] =
   {
    0, 12,  3, 15,
    8,  4, 11,  7,
    2, 14,  1, 13,
   10,  6,  9,  5
   };


GraphicProcessor::~GraphicProcessor(void)
{
}

void GraphicProcessor::ColormapMode(void)
{
  _last_attributes = Attributes();
  Attributes().Reset(GA_RGB);
  CommitAttributes();
}

void GraphicProcessor::RGBMode(void)
{
  _last_attributes = Attributes();
  Attributes().Set(GA_RGB);
  CommitAttributes();
}

void GraphicProcessor::Gouraud(int yes)
{
  _last_attributes = Attributes();
  if(yes)
    Attributes().Set(GA_GOURAUD);
  else
    Attributes().Reset(GA_GOURAUD);
  CommitAttributes();
}

void GraphicProcessor::Flat(void)
{
  _last_attributes = Attributes();
  Attributes().Reset(GA_GOURAUD);
  CommitAttributes();
}

void GraphicProcessor::Dither(int yes)
{
  _last_attributes = Attributes();
  if(yes)
    Attributes().Set(GA_DITHER);
  else
    Attributes().Reset(GA_DITHER);
  CommitAttributes();
}

void GraphicProcessor::ZBuffer(int yes)
{
  _last_attributes = Attributes();
  if(yes)
    Attributes().Set(GA_ZBUFFER);
  else
    Attributes().Reset(GA_ZBUFFER);
  CommitAttributes();
}

void GraphicProcessor::Alpha(int yes)
{
  _last_attributes = Attributes();
  if(yes)
    Attributes().Set(GA_ALPHA);
  else
    Attributes().Reset(GA_ALPHA);
  CommitAttributes();
}

void GraphicProcessor::Texture(int yes)
{
  _last_attributes = Attributes();
  if(yes)
    Attributes().Set(GA_TEXTURE);
  else
    Attributes().Reset(GA_TEXTURE);
  CommitAttributes();
}


// DLDLinker glinker;
