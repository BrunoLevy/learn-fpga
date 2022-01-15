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
//
//-----------------------------------------------------------------------------

#include <string.h>

#include "m_misc.h"

int myargc;
char** myargv;

//
// M_CheckParm
// Checks for the given parameter in the program's command line arguments.
// Returns the argument number (1 to argc-1) or 0 if not present
int M_CheckParm (const char* check)
{
    int i;

    for (i = 1; i < myargc; i++)
    {
        if (!M_strcmpi (check, myargv[i]))
            return i;
    }

    return 0;
}
