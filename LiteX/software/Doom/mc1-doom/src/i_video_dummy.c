// Emacs style mode select   -*- C++ -*-
//-----------------------------------------------------------------------------
//
// Copyright (C) 1993-1996 by id Software, Inc.
// Copyright (C) 2020 by Marcus Geelnard
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
//      Dummy system interface for video.
//
//-----------------------------------------------------------------------------

#include <stdlib.h>

#include "doomdef.h"
#include "i_system.h"
#include "i_video.h"
#include "v_video.h"

void I_InitGraphics (void)
{
    // Allocate regular memory for the Doom screen.
    screens[0] = (unsigned char*)malloc (SCREENWIDTH * SCREENHEIGHT);
    if (screens[0] == NULL)
        I_Error ("Couldn't allocate screen memory");
}

void I_ShutdownGraphics (void)
{
    free (screens[0]);
}

void I_StartFrame (void)
{
    // Er? This is declared in i_system.h.
}

void I_StartTic (void)
{
    // Er? This is declared in i_system.h.
}

void I_SetPalette (byte* palette)
{
    (void)palette;
}

void I_UpdateNoBlit (void)
{
}

void I_FinishUpdate (void)
{
}

void I_WaitVBL (int count)
{
    (void)count;
}

void I_ReadScreen (byte* scr)
{
    memcpy (scr, screens[0], SCREENWIDTH * SCREENHEIGHT);
}
