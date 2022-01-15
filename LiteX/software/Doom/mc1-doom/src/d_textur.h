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
//      Typedefs related to to textures etc.,
//       isolated here to make it easier separating modules.
//
//-----------------------------------------------------------------------------

#ifndef __D_TEXTUR__
#define __D_TEXTUR__

#include "doomtype.h"

//
// Flats?
//
// a pic is an unmasked block of pixels
typedef struct
{
    byte                width;
    byte                height;
    byte                data;
} pic_t;

#endif  // __D_TEXTUR__
