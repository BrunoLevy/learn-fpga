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

#include <ncurses.h>
#include <stdlib.h>

#include "i_video.h"
#include "v_video.h"
#include "doomdef.h"

static const char COL_TO_CHAR[] = " .-~=+cuoaqO0X8@#";
#define NUM_CHAR_LEVELS ((sizeof (COL_TO_CHAR) / sizeof (COL_TO_CHAR[0])) - 1)

static boolean do_color;
static int num_colors;
static byte palette_lut[256];
static byte short_palette[257 * 3];  // Actually (num_colors+1) * 3 entries.

static int sqr_diff (int a, int b)
{
    int diff = a - b;
    return diff * diff;
}

static int color_diff (int r1, int g1, int b1, int r2, int g2, int b2)
{
    return sqr_diff (r1, r2) + sqr_diff (g1, g2) + sqr_diff (b1, b2);
}

void I_InitGraphics (void)
{
    // Allocate memory for the framebuffer.
    screens[0] = (byte*)malloc (SCREENWIDTH * SCREENHEIGHT);

    initscr ();
    cbreak ();
    noecho ();
    intrflush (stdscr, FALSE);
    keypad (stdscr, TRUE);

    // Detect color capabilities.
    do_color = false;
    if (has_colors () == TRUE)
    {
// Note: init_color() appears to have no effect on macOS terminals.
#if !defined(__APPLE__)
        start_color ();
        num_colors = ((COLOR_PAIRS - 1) < 256) ? (COLOR_PAIRS - 1) : 256;
        num_colors = (COLORS < num_colors) ? COLORS : num_colors;

        if (num_colors > 100 && can_change_color () == TRUE)
        {
            for (int i = 0; i < num_colors; ++i)
            {
                // Generate a curses pair.
                init_pair (i + 1, i, i);
            }

            // Let the short palette wrap by appending the first element last.
            short_palette[num_colors * 3 + 0] = short_palette[0];
            short_palette[num_colors * 3 + 1] = short_palette[1];
            short_palette[num_colors * 3 + 2] = short_palette[2];

            do_color = true;
        }
#endif
    }

// Redirect stderr to /dev/null.
// TODO(m): Maybe redirect to a pipe and show it in I_ShutdownGraphics?
#ifdef _WIN32
    freopen ("nul:", "a", stderr);  // Unlikely to ever happen...
#else
    freopen ("/dev/null", "a", stderr);
#endif
}

void I_ShutdownGraphics (void)
{
    endwin ();
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
    int pal_idx;
    int next_pal_idx;
    int i;
    int j;
    int best_value;
    int best_err;
    int err;
    int r;
    int g;
    int b;
    int brightness;
    short rs;
    short gs;
    short bs;
    int col_div;

    if (do_color)
    {
        // Create a smaller palette consisting of num_colors.
        next_pal_idx = 0;
        for (i = 0; i < num_colors; ++i)
        {
            pal_idx = next_pal_idx;
            next_pal_idx = ((i + 1) * 256) / num_colors;

            // Calculate the average color for a number of palette entries.
            // Note: This assumes that the palette is reasonably smooth.
            r = 0;
            g = 0;
            b = 0;
            for (j = pal_idx; j < next_pal_idx; ++j)
            {
                r += (int)*palette++;
                g += (int)*palette++;
                b += (int)*palette++;
            }
            col_div = next_pal_idx - pal_idx;
            r = (r + (col_div >> 1)) / col_div;
            g = (g + (col_div >> 1)) / col_div;
            b =  (b + (col_div >> 1)) / col_div;

            // Store the average color in the short palette.
            short_palette[i * 3 + 0] = (byte)r;
            short_palette[i * 3 + 1] = (byte)g;
            short_palette[i * 3 + 2] = (byte)b;

            // Generate a curses color.
            rs = (short)((1000 * r) / 255);
            gs = (short)((1000 * g) / 255);
            bs = (short)((1000 * b) / 255);
            init_color ((short)i, rs, gs, bs);
        }

        // Define the optimal palette -> short_palette LUT.
        for (i = 0; i < 256; ++i)
        {
            // The color that we want.
            r = (int)palette[i * 3 + 0];
            g = (int)palette[i * 3 + 1];
            b = (int)palette[i * 3 + 2];

            // Find the closest match.
            best_err = 99999999;
            best_value = 0;
            for (j = 0; j < num_colors; ++j)
            {
                err = color_diff (r,
                                  g,
                                  b,
                                  (int)short_palette[j * 3 + 0],
                                  (int)short_palette[j * 3 + 1],
                                  (int)short_palette[j * 3 + 2]);
                if (err < best_err)
                {
                    best_value = j;
                    best_err = err;
                }
            }
            palette_lut[i] = (byte)best_value;
        }
    }
    else
    {
        for (i = 0; i < 256; ++i)
        {
            // The color that we want.
            r = (int)palette[i * 3 + 0];
            g = (int)palette[i * 3 + 1];
            b = (int)palette[i * 3 + 2];

            // Convert to grey scale.
            brightness = (76 * r + 150 * g + 30 * b) >> 8;

            // Convert to a character.
            best_value = ((NUM_CHAR_LEVELS - 1) * brightness + 128) / 255;
            palette_lut[i] = (byte)COL_TO_CHAR[best_value];
        }
    }
}

void I_UpdateNoBlit (void)
{
}

void I_FinishUpdate (void)
{
    int text_width;
    int text_height;
    int x;
    int y;

    // Get consol size.
    text_width = COLS;
    text_height = LINES;

    // We just do nearest neigbour sampling.
    for (y = 0; y < text_height; ++y)
    {
        int v = (y * SCREENHEIGHT) / text_height;
        byte* row = &screens[0][v * SCREENWIDTH];
        if (do_color)
        {
            int last_pair = 1;
            attron (COLOR_PAIR (last_pair));
            for (x = 0; x < text_width; ++x)
            {
                int u = (x * SCREENWIDTH) / text_width;
                int pair = 1 + (int)palette_lut[row[u]];
                if (pair != last_pair)
                {
                    attroff (COLOR_PAIR (last_pair));
                    attron (COLOR_PAIR (pair));
                    last_pair = pair;
                }
                mvaddch (y, x, ' ');
            }
            attroff (COLOR_PAIR (last_pair));
        }
        else
        {
            for (x = 0; x < text_width; ++x)
            {
                int u = (x * SCREENWIDTH) / text_width;
                mvaddch (y, x, (chtype)palette_lut[row[u]]);
            }
        }
    }

    refresh ();
}

void I_WaitVBL (int count)
{
    (void)count;
}

void I_ReadScreen (byte* scr)
{
    memcpy (scr, screens[0], SCREENWIDTH * SCREENHEIGHT);
}
