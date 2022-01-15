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

#include "gcomp.h"
#include <stdlib.h>
#include <ctype.h>
#include <strings.h>

RenderContext* RenderContext::_current = NULL;

OpCode GraphicComponent::_max_op_code = 0;



void GraphicComponent::CommitAttributes(void)
{
  // default CommitAttributes
  // (nop)
}

long GraphicComponent::Cntl(OpCode op, int arg)
{
  // default operation does nothing and returns 0.
  return 0;
}

// Define a virtual destructor for GraphicProcessors

GraphicComponent::~GraphicComponent(void)
{
  (*this)[MSG_INFO] << "morituri te salutant\n";
}

// Graphic Bus

ScrCoord     GraphicComponent::_width;
ScrCoord     GraphicComponent::_height;
ColorIndex * GraphicComponent::_graph_mem;
ZCoord *     GraphicComponent::_z_mem;
ColorIndex   GraphicComponent::_colormap[GP_COLORMAP_SZ];
UColorCode   GraphicComponent::_truecolormap[GP_COLORMAP_SZ];
int          GraphicComponent::_bytes_per_line;
int          GraphicComponent::_bits_per_pixel;
int          GraphicComponent::_bytes_per_pixel;
Rect         GraphicComponent::_clip;
UColorCode   GraphicComponent::_R_mask;
UColorCode   GraphicComponent::_G_mask;
UColorCode   GraphicComponent::_B_mask;
ColorIndex*  GraphicComponent::_tex_mem;
ColorIndex*  GraphicComponent::_tex_cmap;
ScrCoord     GraphicComponent::_tex_size;
UScrCoord    GraphicComponent::_tex_mask;
UScrCoord    GraphicComponent::_tex_shift;

// Command line

int          GraphicComponent::_argc = 0;
char**       GraphicComponent::_argv = NULL;

// Environment

int
GraphicComponent::IsSet(char* var_name)
{
char *var_env = getenv(var_name);

if(var_env)
   {
   if(!strcmp(var_env, "yes"))
      return 1;
   if(!strcmp(var_env, "on"))
      return 1;
   }

return 0;
}
