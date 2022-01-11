// Emacs style mode select   -*- C++ -*-
//-----------------------------------------------------------------------------
//
// Copyright (C) 1993-1996 by id Software, Inc.
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// DESCRIPTION:
//      Gamma correction LUT.
//      Functions to draw patches (by post) directly to screen.
//      Functions to blit a block to the screen.
//
//-----------------------------------------------------------------------------

#ifndef __V_VIDEO__
#define __V_VIDEO__

#include "doomtype.h"

#include "doomdef.h"

// Needed because we are refering to patches.
#include "r_data.h"

//
// VIDEO
//

#define CENTERY                 (SCREENHEIGHT/2)

// Screen 0 is the screen updated by I_Update screen.
// Screen 1 is an extra buffer.

extern  byte*           screens[5];

extern  int     dirtybox[4];

extern  byte    gammatable[5][256];
extern  int     usegamma;

// Allocates buffer screens, call before R_Init.
void V_Init (void);

void
V_CopyRect
( int           srcx,
  int           srcy,
  int           srcscrn,
  int           width,
  int           height,
  int           destx,
  int           desty,
  int           destscrn );

void
V_DrawPatch
( int           x,
  int           y,
  int           scrn,
  patch_t*      patch);

void
V_DrawPatchDirect
( int           x,
  int           y,
  int           scrn,
  patch_t*      patch );

void
V_DrawPatchScaled
( int           x,
  int           y,
  int           scrn,
  patch_t*      patch);

// Draw a linear block of pixels into the view buffer.
void
V_DrawBlock
( int           x,
  int           y,
  int           scrn,
  int           width,
  int           height,
  byte*         src );

// Reads a linear block of pixels into the view buffer.
void
V_GetBlock
( int           x,
  int           y,
  int           scrn,
  int           width,
  int           height,
  byte*         dest );

void
V_MarkRect
( int           x,
  int           y,
  int           width,
  int           height );

void
V_FillRect
( int           x,
  int           y,
  int           scrn,
  int           width,
  int           height,
  int           color );

#endif  // __V_VIDEO__
