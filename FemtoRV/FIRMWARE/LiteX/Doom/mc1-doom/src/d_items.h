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
//      Items: key cards, artifacts, weapon, ammunition.
//
//-----------------------------------------------------------------------------

#ifndef __D_ITEMS__
#define __D_ITEMS__

#include "doomdef.h"

// Weapon info: sprite frames, ammunition use.
typedef struct
{
    ammotype_t  ammo;
    int         upstate;
    int         downstate;
    int         readystate;
    int         atkstate;
    int         flashstate;

} weaponinfo_t;

extern  weaponinfo_t    weaponinfo[NUMWEAPONS];

#endif  // __D_ITEMS__
