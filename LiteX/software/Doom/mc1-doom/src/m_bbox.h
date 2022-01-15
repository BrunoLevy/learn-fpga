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
//    Nil.
//
//-----------------------------------------------------------------------------

#ifndef __M_BBOX__
#define __M_BBOX__

#include "m_fixed.h"

// Bounding box coordinate storage.
enum
{
    BOXTOP,
    BOXBOTTOM,
    BOXLEFT,
    BOXRIGHT
};      // bbox coordinates

// Bounding box functions.
void M_ClearBox (fixed_t*       box);

void
M_AddToBox
( fixed_t*      box,
  fixed_t       x,
  fixed_t       y );

#endif  // __M_BBOX__
