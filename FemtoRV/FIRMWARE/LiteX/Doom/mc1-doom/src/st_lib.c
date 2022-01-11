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
//      The status bar widget code.
//
//-----------------------------------------------------------------------------

#include <ctype.h>

#include "doomdef.h"

#include "z_zone.h"
#include "v_video.h"

#include "m_swap.h"

#include "i_system.h"

#include "w_wad.h"

#include "st_stuff.h"
#include "st_lib.h"
#include "r_local.h"

// in AM_map.c
extern boolean          automapactive;

//
// Hack display negative frags.
//  Loads and store the stminus lump.
//
patch_t*                sttminus;

void STlib_init(void)
{
    sttminus = (patch_t *) W_CacheLumpName("STTMINUS", PU_STATIC);
}

// ?
void
STlib_initNum
( st_number_t*          n,
  int                   x,
  int                   y,
  patch_t**             pl,
  int*                  num,
  boolean*              on,
  int                   width )
{
    n->x        = x;
    n->y        = y;
    n->oldnum   = 0;
    n->width    = width;
    n->num      = num;
    n->on       = on;
    n->p        = pl;
}

//
// A fairly efficient way to draw a number
//  based on differences from the old number.
// Note: worth the trouble?
//
void
STlib_drawNum
( st_number_t*  n,
  boolean       refresh )
{

    int         numdigits = n->width;
    int         num = *n->num;

    int         w = SHORT(n->p[0]->width);
    int         h = SHORT(n->p[0]->height);
    int         x;

    int         neg;

    // UNUSED.
    (void)refresh;

    n->oldnum = *n->num;

    // Handle sign and overflow (if the number does not fit with a minus sign).
    neg = num < 0;
    if (neg)
    {
        if (numdigits == 2 && num < -9)
            num = -9;
        else if (numdigits == 3 && num < -99)
            num = -99;
        num = -num;
    }

    // Clear the area.
    int srcx = n->x - numdigits*w;
    int srcy = n->y - ST_Y;
    if (srcy < 0)
        I_Error("drawNum: srcy < 0");
    int dstx = ST_XTOSCREEN (srcx);
    int dsty = ST_YTOSCREEN (n->y);
    V_CopyRect (srcx, srcy, BG, w * numdigits, h, dstx, dsty, FG);

    // if non-number, do not draw it
    if (num == 1994)
        return;

    // in the special case of 0, you draw 0
    if (!num)
    {
        dstx = ST_XTOSCREEN (n->x - w);
        dsty = ST_YTOSCREEN (n->y);
        V_DrawPatch (dstx, dsty, FG, n->p[0]);
    }

    // Draw the new number.
    x = n->x;
    while (num && numdigits--)
    {
        x -= w;
        dstx = ST_XTOSCREEN (x);
        dsty = ST_YTOSCREEN (n->y);
        V_DrawPatch (dstx, dsty, FG, n->p[num % 10]);
        num /= 10;
    }

    // Draw a minus sign if necessary.
    if (neg)
    {
        dstx = ST_XTOSCREEN (x - 8);
        dsty = ST_YTOSCREEN (n->y);
        V_DrawPatch (dstx, dsty, FG, sttminus);
    }
}

//
void
STlib_updateNum
( st_number_t*          n,
  boolean               refresh )
{
    if (*n->on) STlib_drawNum(n, refresh);
}

//
void
STlib_initPercent
( st_percent_t*         p,
  int                   x,
  int                   y,
  patch_t**             pl,
  int*                  num,
  boolean*              on,
  patch_t*              percent )
{
    STlib_initNum(&p->n, x, y, pl, num, on, 3);
    p->p = percent;
}

void
STlib_updatePercent
( st_percent_t*         per,
  int                   refresh )
{
    if (refresh && *per->n.on)
    {
        int dstx = ST_XTOSCREEN (per->n.x);
        int dsty = ST_YTOSCREEN (per->n.y);
        V_DrawPatch (dstx, dsty, FG, per->p);
    }

    STlib_updateNum (&per->n, refresh);
}

void
STlib_initMultIcon
( st_multicon_t*        i,
  int                   x,
  int                   y,
  patch_t**             il,
  int*                  inum,
  boolean*              on )
{
    i->x        = x;
    i->y        = y;
    i->oldinum  = -1;
    i->inum     = inum;
    i->on       = on;
    i->p        = il;
}

void
STlib_updateMultIcon
( st_multicon_t*        mi,
  boolean               refresh )
{
    if (*mi->on && (mi->oldinum != *mi->inum || refresh) && (*mi->inum != -1))
    {
        if (mi->oldinum != -1)
        {
            // Clear the area.
            int x = mi->x - SHORT (mi->p[mi->oldinum]->leftoffset);
            int y = mi->y - SHORT (mi->p[mi->oldinum]->topoffset);
            int w = SHORT (mi->p[mi->oldinum]->width);
            int h = SHORT (mi->p[mi->oldinum]->height);

            int srcx = x;
            int srcy = y - ST_Y;
            if (srcy < 0)
                I_Error ("updateMultIcon: srcy < 0");
            int dstx = ST_XTOSCREEN (x);
            int dsty = ST_YTOSCREEN (y);
            V_CopyRect (srcx, srcy, BG, w, h, dstx, dsty, FG);
        }

        // Draw the icon.
        V_DrawPatch (ST_XTOSCREEN (mi->x),
                     ST_YTOSCREEN (mi->y),
                     FG,
                     mi->p[*mi->inum]);

        mi->oldinum = *mi->inum;
    }
}

void
STlib_initBinIcon
( st_binicon_t*         b,
  int                   x,
  int                   y,
  patch_t*              i,
  boolean*              val,
  boolean*              on )
{
    b->x        = x;
    b->y        = y;
    b->oldval   = false;
    b->val      = val;
    b->on       = on;
    b->p        = i;
}

void
STlib_updateBinIcon
( st_binicon_t*         bi,
  boolean               refresh )
{
    int                 x;
    int                 y;
    int                 w;
    int                 h;

    if (*bi->on
        && (bi->oldval != *bi->val || refresh))
    {
        if (*bi->val)
        {
            int dstx = ST_XTOSCREEN (bi->x);
            int dsty = ST_YTOSCREEN (bi->y);
            V_DrawPatch (dstx, dsty, FG, bi->p);
        }
        else
        {
            // Clear the area.
            x = bi->x - SHORT (bi->p->leftoffset);
            y = bi->y - SHORT (bi->p->topoffset);
            w = SHORT (bi->p->width);
            h = SHORT (bi->p->height);

            int srcx = x;
            int srcy = y - ST_Y;
            if (srcy < 0)
                I_Error ("updateBinIcon: srcy < 0");
            int dstx = ST_XTOSCREEN (x);
            int dsty = ST_YTOSCREEN (y);
            V_CopyRect (srcx, srcy, BG, w, h, dstx, dsty, FG);
        }

        bi->oldval = *bi->val;
    }

}

