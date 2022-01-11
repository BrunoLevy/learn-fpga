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
//      SDL2-based DOOM graphics renderer
//
//-----------------------------------------------------------------------------

#include <stdlib.h>

#include <SDL2/SDL.h>

#include "doomdef.h"
#include "doomstat.h"
#include "d_main.h"
#include "i_system.h"
#include "m_argv.h"
#include "v_video.h"

static SDL_Window* s_window;
static SDL_Renderer* s_renderer;
static SDL_Texture* s_texture;

static unsigned int s_palette[256];

static unsigned int color_to_argb8888 (unsigned int r,
                                       unsigned int g,
                                       unsigned int b)
{
    return 0xff000000u | (r << 16) | (g << 8) | b;
}

static int translatekey (SDL_Keysym* key)
{
    int rc;

    switch (key->scancode)
    {
        case SDL_SCANCODE_LEFT:
            rc = KEY_LEFTARROW;
            break;
        case SDL_SCANCODE_RIGHT:
            rc = KEY_RIGHTARROW;
            break;
        case SDL_SCANCODE_DOWN:
            rc = KEY_DOWNARROW;
            break;
        case SDL_SCANCODE_UP:
            rc = KEY_UPARROW;
            break;
        case SDL_SCANCODE_ESCAPE:
            rc = KEY_ESCAPE;
            break;
        case SDL_SCANCODE_RETURN:
            rc = KEY_ENTER;
            break;
        case SDL_SCANCODE_TAB:
            rc = KEY_TAB;
            break;
        case SDL_SCANCODE_F1:
            rc = KEY_F1;
            break;
        case SDL_SCANCODE_F2:
            rc = KEY_F2;
            break;
        case SDL_SCANCODE_F3:
            rc = KEY_F3;
            break;
        case SDL_SCANCODE_F4:
            rc = KEY_F4;
            break;
        case SDL_SCANCODE_F5:
            rc = KEY_F5;
            break;
        case SDL_SCANCODE_F6:
            rc = KEY_F6;
            break;
        case SDL_SCANCODE_F7:
            rc = KEY_F7;
            break;
        case SDL_SCANCODE_F8:
            rc = KEY_F8;
            break;
        case SDL_SCANCODE_F9:
            rc = KEY_F9;
            break;
        case SDL_SCANCODE_F10:
            rc = KEY_F10;
            break;
        case SDL_SCANCODE_F11:
            rc = KEY_F11;
            break;
        case SDL_SCANCODE_F12:
            rc = KEY_F12;
            break;

        case SDL_SCANCODE_BACKSPACE:
        case SDL_SCANCODE_DELETE:
            rc = KEY_BACKSPACE;
            break;

        case SDL_SCANCODE_PAUSE:
            rc = KEY_PAUSE;
            break;

        case SDL_SCANCODE_EQUALS:
            rc = KEY_EQUALS;
            break;

        case SDL_SCANCODE_KP_MINUS:
        case SDL_SCANCODE_MINUS:
            rc = KEY_MINUS;
            break;

        case SDL_SCANCODE_LSHIFT:
        case SDL_SCANCODE_RSHIFT:
            rc = KEY_RSHIFT;
            break;

        case SDL_SCANCODE_LCTRL:
        case SDL_SCANCODE_RCTRL:
            rc = KEY_RCTRL;
            break;

        case SDL_SCANCODE_LALT:
        case SDL_SCANCODE_LGUI:
        case SDL_SCANCODE_RALT:
        case SDL_SCANCODE_RGUI:
            rc = KEY_RALT;
            break;

        default:
            // TODO(m): We should probably use SDL_SCANCODE_* for all the
            // printable keys too, to bypass keyboard mapping, and add key->sym
            // as a special Doom event_t field for regular keyboard input (e.g.
            // for typing in the name of a savegame).
            rc = key->sym;
            break;
    }

    return rc;
}

static void handleevent (SDL_Event* sdlevent)
{
    Uint8 buttonstate;
    event_t event;

    switch (sdlevent->type)
    {
        case SDL_KEYDOWN:
            event.type = ev_keydown;
            event.data1 = translatekey (&sdlevent->key.keysym);
            D_PostEvent (&event);
            break;

        case SDL_KEYUP:
            event.type = ev_keyup;
            event.data1 = translatekey (&sdlevent->key.keysym);
            D_PostEvent (&event);
            break;

        case SDL_MOUSEBUTTONDOWN:
        case SDL_MOUSEBUTTONUP:
            buttonstate = SDL_GetMouseState (NULL, NULL);
            event.type = ev_mouse;
            event.data1 = 0 | (buttonstate & SDL_BUTTON (1) ? 1 : 0) |
                          (buttonstate & SDL_BUTTON (2) ? 2 : 0) |
                          (buttonstate & SDL_BUTTON (3) ? 4 : 0);
            event.data2 = event.data3 = 0;
            D_PostEvent (&event);
            break;

        case SDL_MOUSEMOTION:
            event.type = ev_mouse;
            event.data1 = 0 |
                          (sdlevent->motion.state & SDL_BUTTON (1) ? 1 : 0) |
                          (sdlevent->motion.state & SDL_BUTTON (2) ? 2 : 0) |
                          (sdlevent->motion.state & SDL_BUTTON (3) ? 4 : 0);
            event.data2 = sdlevent->motion.xrel << 4;
            event.data3 = -(sdlevent->motion.yrel << 4);
            D_PostEvent (&event);
            break;

        case SDL_QUIT:
            I_Quit ();
    }
}

void I_InitGraphics (void)
{
    // Only initialize once.
    static int initialized = 0;
    if (initialized)
        return;
    initialized = 1;

    // Gather video configuration.
    boolean fullscreen = M_CheckParm ("-fullscreen") != 0;
    boolean novsync =
        (M_CheckParm ("-novsync") != 0) || (M_CheckParm ("-timedemo") != 0);
    boolean grabmouse = M_CheckParm ("-grabmouse") != 0;
    int video_w = SCREENWIDTH;
    int video_h = SCREENHEIGHT;

    // Should we open the window in fullscreen mode?
    Uint32 window_flags = 0;
    if (fullscreen)
        window_flags |= SDL_WINDOW_FULLSCREEN_DESKTOP;
    else
        window_flags |= SDL_WINDOW_RESIZABLE;

    // Avoid silly small window sizes.
    int window_w = 1024;
    int window_h = (window_w * SCREENHEIGHT) / SCREENWIDTH;

    // Create the window.
    s_window = SDL_CreateWindow ("MC1-DOOM v1.10",
                                 SDL_WINDOWPOS_UNDEFINED,
                                 SDL_WINDOWPOS_UNDEFINED,
                                 window_w,
                                 window_h,
                                 window_flags);
    if (s_window == NULL)
        I_Error ("Couldn't create SDL window");

    // Create the renderer.
    s_renderer = SDL_CreateRenderer (
        s_window, -1, novsync ? 0 : SDL_RENDERER_PRESENTVSYNC);
    if (s_renderer == NULL)
        I_Error ("Couldn't create SDL renderer");
    SDL_RenderSetLogicalSize (s_renderer, video_w, video_h);

    // Create the texture.
    s_texture = SDL_CreateTexture (s_renderer,
                                   SDL_PIXELFORMAT_ARGB8888,
                                   SDL_TEXTUREACCESS_STREAMING,
                                   video_w,
                                   video_h);
    if (s_texture == NULL)
        I_Error ("Couldn't create SDL texture");

    // Configure the mouse.
    if (grabmouse || fullscreen)
    {
        SDL_CaptureMouse (SDL_TRUE);
        SDL_SetRelativeMouseMode (SDL_TRUE);
    }
    SDL_ShowCursor (SDL_DISABLE);

    // Allocate regular memory for the Doom screen.
    screens[0] = (unsigned char*)malloc (SCREENWIDTH * SCREENHEIGHT);
    if (screens[0] == NULL)
        I_Error ("Couldn't allocate screen memory");
}

void I_ShutdownGraphics (void)
{
    free (screens[0]);
    SDL_DestroyTexture (s_texture);
    SDL_DestroyRenderer (s_renderer);
    SDL_DestroyWindow (s_window);
    SDL_Quit ();
}

void I_WaitVBL (int count)
{
    SDL_Delay (count * (1000 / 70));
}

void I_StartFrame (void)
{
    // er?
}

void I_StartTic (void)
{
    SDL_Event e;
    while (SDL_PollEvent (&e))
        handleevent (&e);
}

void I_UpdateNoBlit (void)
{
    // what is this?
}

void I_FinishUpdate (void)
{
    // Copy the internal screen to the SDL texture, converting the
    // 8-bit indexed pixels to 32-bit ARGB.
    void* pixels;
    int pitch;
    if (SDL_LockTexture (s_texture, NULL, &pixels, &pitch) != 0)
    {
        fprintf (stderr, "I_FinishUpdate: Unable to lock texture\n");
        return;
    }
    const unsigned char* src = (const unsigned char*)screens[0];
    unsigned int* dst = (unsigned int*)pixels;
    for (int y = 0; y < SCREENHEIGHT; ++y)
    {
        for (int x = 0; x < SCREENWIDTH; ++x)
            dst[x] = s_palette[src[x]];
        src += SCREENWIDTH;
        dst += pitch / 4;
    }
    SDL_UnlockTexture (s_texture);

    // Render the texture.
    SDL_RenderClear (s_renderer);
    SDL_RenderCopy (s_renderer, s_texture, NULL, NULL);
    SDL_RenderPresent (s_renderer);
}

void I_ReadScreen (byte* scr)
{
    memcpy (scr, screens[0], SCREENWIDTH * SCREENHEIGHT);
}

void I_SetPalette (byte* palette)
{
    for (int i = 0; i < 256; ++i)
    {
        unsigned int r = (unsigned int)gammatable[usegamma][*palette++];
        unsigned int g = (unsigned int)gammatable[usegamma][*palette++];
        unsigned int b = (unsigned int)gammatable[usegamma][*palette++];
        s_palette[i] = color_to_argb8888 (r, g, b);
    }
}
