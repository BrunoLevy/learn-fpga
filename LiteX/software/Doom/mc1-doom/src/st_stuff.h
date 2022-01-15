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
//      Status bar code.
//      Does the face/direction indicator animatin.
//      Does palette indicators as well (red pain/berserk, bright pickup)
//
//-----------------------------------------------------------------------------

#ifndef __STSTUFF_H__
#define __STSTUFF_H__

#include "doomtype.h"
#include "d_event.h"

// Size of statusbar.
// Now sensitive for scaling.
#define ST_HEIGHT       32
#define ST_WIDTH        BASE_WIDTH
#define ST_Y            (BASE_HEIGHT - ST_HEIGHT)

// Convert ST coordinates (320x200) to screen coordinates.
#define ST_XTOSCREEN(x) ((x) + (SCREENWIDTH - BASE_WIDTH) / 2)
#define ST_YTOSCREEN(y) ((y) - BASE_HEIGHT + SCREENHEIGHT)

//
// STATUS BAR
//

// Called by main loop.
boolean ST_Responder (event_t* ev);

// Called by main loop.
void ST_Ticker (void);

// Called by main loop.
void ST_Drawer (boolean fullscreen, boolean refresh);

// Called when the console player is spawned on each level.
void ST_Start (void);

// Called by startup code.
void ST_Init (void);

// States for status bar code.
typedef enum
{
    AutomapState,
    FirstPersonState

} st_stateenum_t;

// States for the chat code.
typedef enum
{
    StartChatState,
    WaitDestState,
    GetChatState

} st_chatstateenum_t;

#endif  // __STSTUFF_H__
