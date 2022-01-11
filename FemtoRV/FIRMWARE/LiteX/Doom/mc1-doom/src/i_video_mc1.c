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
#include <string.h>
#include <sys/time.h>
#include <mr32intrin.h>

#include "doomdef.h"
#include "d_event.h"
#include "d_main.h"
#include "i_system.h"
#include "i_video.h"
#include "v_video.h"
#include "mc1.h"

// Video buffers.
static byte* s_vcp;
static byte* s_palette;
static byte* s_framebuffer;

// Pointers for the custom VRAM allocator.
static byte* s_vram_alloc_ptr;
static byte* s_vram_alloc_end;

static void MC1_AllocInit (void)
{
    // We assume that the Doom binary is loaded into XRAM (0x80000000...), or
    // into the "ROM" (0x00000000...) for the simulator, and that it has
    // complete ownership of VRAM (0x40000000...).
    s_vram_alloc_ptr = (byte*)0x40000100;
    s_vram_alloc_end = (byte*)(0x40000000 + GET_MMIO (VRAMSIZE));
}

static byte* MC1_VRAM_Alloc (const size_t bytes)
{
    // Check if there is enough room.
    byte* ptr = s_vram_alloc_ptr;
    byte* new_ptr = ptr + bytes;
    if (new_ptr > s_vram_alloc_end)
        return NULL;

    // Align the next allocation slot to a 32 byte boundary.
    if ((((size_t)new_ptr) & 31) != 0)
        new_ptr += 32U - (((size_t)new_ptr) & 31);
    s_vram_alloc_ptr = new_ptr;

    return ptr;
}

static byte* MC1_Alloc (const size_t bytes)
{
    // Prefer VRAM (for speed).
    byte* ptr = MC1_VRAM_Alloc (bytes);
    if (ptr == NULL)
        ptr = (byte*)malloc (bytes);
    return ptr;
}

static int MC1_IsVRAMPtr (const byte* ptr)
{
    return ptr >= (byte*)0x40000000 && ptr < (byte*)0x80000000;
}

static void MC1_Free (byte* ptr)
{
    // We can't free VRAM pointers.
    if (!MC1_IsVRAMPtr (ptr))
        free (ptr);
}

static void I_MC1_CreateVCP (void)
{
    // Get the native video signal resolution and calculate the scaling factors.
    unsigned native_width = GET_MMIO (VIDWIDTH);
    unsigned native_height = GET_MMIO (VIDHEIGHT);
    unsigned xincr = ((native_width - 1) << 16) / (SCREENWIDTH - 1);
    unsigned yincr = ((native_height - 1) << 16) / (SCREENHEIGHT - 1);

    // Frame configuraiton.
    unsigned* vcp = (unsigned*)s_vcp;
    *vcp++ = VCP_SETREG (VCR_XINCR, xincr);
    *vcp++ = VCP_SETREG (VCR_CMODE, CMODE_PAL8);
    *vcp++ = VCP_JSR (s_palette);

    // Generate lines.
    unsigned y = 0;
    unsigned addr = (unsigned)s_framebuffer;
    for (int i = 0; i < SCREENHEIGHT; ++i)
    {
        if (i == 0)
            *vcp++ = VCP_SETREG (VCR_HSTOP, native_width);
        *vcp++ = VCP_WAITY (y >> 16);
        *vcp++ = VCP_SETREG (VCR_ADDR, VCP_TOVCPADDR (addr));
        addr += SCREENWIDTH;
        y += yincr;
    }

    // End of frame (wait forever).
    *vcp = VCP_WAITY (32767);

    // Palette.
    unsigned* palette = (unsigned*)s_palette;
    *palette++ = VCP_SETPAL (0, 256);
    palette += 256;
    *palette = VCP_RTS;

    // Configure the main layer 1 VCP to call our VCP.
    *((unsigned*)0x40000008) = VCP_JMP (s_vcp);

    // The layer 2 VCP should do nothing.
    *((unsigned*)0x40000010) = VCP_WAITY (32767);
}

static int I_MC1_TranslateKey (unsigned keycode)
{
    // clang-format off
    switch (keycode)
    {
        case KB_SPACE:         return ' ';
        case KB_LEFT:          return KEY_LEFTARROW;
        case KB_RIGHT:         return KEY_RIGHTARROW;
        case KB_DOWN:          return KEY_DOWNARROW;
        case KB_UP:            return KEY_UPARROW;
        case KB_ESC:           return KEY_ESCAPE;
        case KB_ENTER:         return KEY_ENTER;
        case KB_TAB:           return KEY_TAB;
        case KB_F1:            return KEY_F1;
        case KB_F2:            return KEY_F2;
        case KB_F3:            return KEY_F3;
        case KB_F4:            return KEY_F4;
        case KB_F5:            return KEY_F5;
        case KB_F6:            return KEY_F6;
        case KB_F7:            return KEY_F7;
        case KB_F8:            return KEY_F8;
        case KB_F9:            return KEY_F9;
        case KB_F10:           return KEY_F10;
        case KB_F11:           return KEY_F11;
        case KB_F12:           return KEY_F12;
        case KB_DEL:
        case KB_BACKSPACE:     return KEY_BACKSPACE;
        case KB_MM_PLAY_PAUSE: return KEY_PAUSE;
        case KB_KP_PLUS:       return KEY_EQUALS;
        case KB_KP_MINUS:      return KEY_MINUS;
        case KB_LSHIFT:
        case KB_RSHIFT:        return KEY_RSHIFT;
        case KB_LCTRL:
        case KB_RCTRL:         return KEY_RCTRL;
        case KB_LALT:
        case KB_LMETA:
        case KB_RALT:
        case KB_RMETA:         return KEY_RALT;

        case KB_A:             return 'a';
        case KB_B:             return 'b';
        case KB_C:             return 'c';
        case KB_D:             return 'd';
        case KB_E:             return 'e';
        case KB_F:             return 'f';
        case KB_G:             return 'g';
        case KB_H:             return 'h';
        case KB_I:             return 'i';
        case KB_J:             return 'j';
        case KB_K:             return 'k';
        case KB_L:             return 'l';
        case KB_M:             return 'm';
        case KB_N:             return 'n';
        case KB_O:             return 'o';
        case KB_P:             return 'p';
        case KB_Q:             return 'q';
        case KB_R:             return 'r';
        case KB_S:             return 's';
        case KB_T:             return 't';
        case KB_U:             return 'u';
        case KB_V:             return 'v';
        case KB_W:             return 'w';
        case KB_X:             return 'x';
        case KB_Y:             return 'y';
        case KB_Z:             return 'z';
        case KB_0:             return '0';
        case KB_1:             return '1';
        case KB_2:             return '2';
        case KB_3:             return '3';
        case KB_4:             return '4';
        case KB_5:             return '5';
        case KB_6:             return '6';
        case KB_7:             return '7';
        case KB_8:             return '8';
        case KB_9:             return '9';

        default:
            return 0;
    }
    // clang-format on
}

static unsigned s_keyptr;

static boolean I_MC1_PollKeyEvent (event_t* event)
{
    unsigned keyptr, keycode;
    int doom_key;

    // Check if we have any new keycode from the keyboard.
    keyptr = GET_MMIO (KEYPTR);
    if (s_keyptr == keyptr)
        return false;

    // Get the next keycode.
    ++s_keyptr;
    keycode = GET_KEYBUF (s_keyptr % KEYBUF_SIZE);

    // Translate the MC1 keycode to a Doom keycode.
    doom_key = I_MC1_TranslateKey (keycode & 0x1ff);
    if (doom_key != 0)
    {
        // Create a Doom keyboard event.
        event->type = (keycode & 0x80000000) ? ev_keydown : ev_keyup;
        event->data1 = doom_key;
    }

    return true;
}

static boolean I_MC1_PollMouseEvent (event_t* event)
{
    static unsigned s_old_mousepos;
    static unsigned s_old_mousebtns;

    // Do we have a new mouse movement event?
    unsigned mousepos = GET_MMIO (MOUSEPOS);
    unsigned mousebtns = GET_MMIO (MOUSEBTNS);
    if (mousepos == s_old_mousepos && mousebtns == s_old_mousebtns)
        return false;

    // Get the x & y mouse delta.
    int mousex = ((int)(short)mousepos) - ((int)(short)s_old_mousepos);
    int mousey = (((int)mousepos) >> 16) - (((int)s_old_mousepos) >> 16);

    // Create a Doom mouse event.
    event->type = ev_mouse;
    event->data1 = mousebtns;
    event->data2 = mousex;
    event->data3 = mousey;

    s_old_mousepos = mousepos;
    s_old_mousebtns = mousebtns;

    return true;
}

void I_InitGraphics (void)
{
    MC1_AllocInit ();

    // Video buffers that need to be in VRAM.
    const size_t vcp_size = (5 + SCREENHEIGHT * 2) * sizeof (unsigned);
    const size_t palette_size = (2 + 256) * sizeof (unsigned);
    const size_t framebuffer_size = SCREENWIDTH * SCREENHEIGHT * sizeof (byte);
    s_vcp = MC1_VRAM_Alloc (vcp_size);
    s_palette = MC1_VRAM_Alloc (palette_size);
    s_framebuffer = MC1_VRAM_Alloc (framebuffer_size);
    if (s_framebuffer == NULL)
        I_Error ("Error: Not enough VRAM!");

    // Allocate regular memory for the Doom screen.
    const size_t screen_size = SCREENWIDTH * SCREENHEIGHT * sizeof (byte);
    screens[0] = MC1_Alloc (screen_size);
    if (MC1_IsVRAMPtr (screens[0]))
        printf ("I_InitGraphics: Using VRAM for the pixel buffer\n");

    I_MC1_CreateVCP ();

    s_keyptr = GET_MMIO (KEYPTR);

    printf (
        "I_InitGraphics: Resolution = %d x %d\n"
        "                Framebuffer @ 0x%08x (%d)\n"
        "                Palette     @ 0x%08x (%d)\n",
        SCREENWIDTH,
        SCREENHEIGHT,
        (unsigned)s_framebuffer,
        (unsigned)s_framebuffer,
        (unsigned)(s_palette + 4),
        (unsigned)(s_palette + 4));
}

void I_ShutdownGraphics (void)
{
    MC1_Free (screens[0]);
}

void I_StartFrame (void)
{
    // Er? This is declared in i_system.h.
}

void I_StartTic (void)
{
    event_t event;

    // Read mouse and keyboard events.
    if (I_MC1_PollKeyEvent (&event))
        D_PostEvent (&event);
    if (I_MC1_PollMouseEvent (&event))
        D_PostEvent (&event);
}

void I_SetPalette (byte* palette)
{
    unsigned* dst = &((unsigned*)s_palette)[1];
    const unsigned a = 255;
    for (int i = 0; i < 256; ++i)
    {
        unsigned r = (unsigned)palette[i * 3];
        unsigned g = (unsigned)palette[i * 3 + 1];
        unsigned b = (unsigned)palette[i * 3 + 2];
#ifdef __MRISC32_PACKED_OPS__
        dst[i] = _mr32_pack_h (_mr32_pack (a, g), _mr32_pack (b, r));
#else
        dst[i] = (a << 24) | (b << 16) | (g << 8) | r;
#endif
    }
}

void I_UpdateNoBlit (void)
{
}

void I_FinishUpdate (void)
{
    memcpy (s_framebuffer, screens[0], SCREENWIDTH * SCREENHEIGHT);
}

void I_WaitVBL (int count)
{
#if 0
    // TODO(m): Replace this with MC1 MMIO-based timing.
    struct timeval t0, t;
    long dt, waitt;

    // Busy-wait for COUNT*1/60 s.
    gettimeofday (&t0, NULL);
    waitt = count * (1000000L / 60L);
    do
    {
        gettimeofday (&t, NULL);
        dt = (t.tv_sec - t0.tv_sec) * 1000000L + (t.tv_usec - t0.tv_usec);
    } while (dt < waitt);
#else
    // Run at max FPS - no wait.
    (void)count;
#endif
}

void I_ReadScreen (byte* scr)
{
    memcpy (scr, screens[0], SCREENWIDTH * SCREENHEIGHT);
}
