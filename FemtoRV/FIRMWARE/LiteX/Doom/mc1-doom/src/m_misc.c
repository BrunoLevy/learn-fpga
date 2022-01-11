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
//      Main loop menu stuff.
//      Default Config File.
//      PCX Screenshots.
//
//-----------------------------------------------------------------------------

//#include <sys/stat.h>
//#include <sys/types.h>
//#include <fcntl.h>

#define LX_STDIO_OVERRIDE
#include <lite_stdio.h>

#include <stdlib.h>
#include <unistd.h>

#include <ctype.h>

#include "doomdef.h"

#include "z_zone.h"

#include "m_swap.h"
#include "m_argv.h"

#include "w_wad.h"

#include "i_system.h"
#include "i_video.h"
#include "v_video.h"

#include "hu_stuff.h"

// State.
#include "doomstat.h"

// Data.
#include "dstrings.h"

#include "m_misc.h"

//
// M_DrawText
// Returns the final X coordinate
// HU_Init must have been called to init the font
//
extern patch_t*         hu_font[HU_FONTSIZE];

int
M_DrawText
( int           x,
  int           y,
  boolean       direct,
  char*         string )
{
    int         c;
    int         w;

    while (*string)
    {
        c = toupper(*string) - HU_FONTSTART;
        string++;
        if (c < 0 || c> HU_FONTSIZE)
        {
            x += 4;
            continue;
        }

        w = SHORT (hu_font[c]->width);
        if (x+w > SCREENWIDTH)
            break;
        if (direct)
            V_DrawPatchDirect(x, y, 0, hu_font[c]);
        else
            V_DrawPatch(x, y, 0, hu_font[c]);
        x+=w;
    }

    return x;
}

//
// M_WriteFile
//
#ifndef O_BINARY
#define O_BINARY 0
#endif

boolean
M_WriteFile
( char const*   name,
  void*         source,
  int           length )
{
    int         handle;
    int         count;

    handle = open ( name, O_WRONLY | O_CREAT | O_TRUNC | O_BINARY, 0666);

    if (handle == -1)
        return false;

    count = write (handle, source, length);
    close (handle);

    if (count < length)
        return false;

    return true;
}

//
// M_ReadFile
//
int
M_ReadFile
( char const*   name,
  byte**        buffer )
{
    int handle, count, length;
    struct stat fileinfo;
    byte                *buf;

    handle = open (name, O_RDONLY | O_BINARY, 0666);
    if (handle == -1)
        I_Error ("Couldn't read file %s", name);
    if (fstat (handle,&fileinfo) == -1)
        I_Error ("Couldn't read file %s", name);
    length = fileinfo.st_size;
    buf = Z_Malloc (length, PU_STATIC, NULL);
    count = read (handle, buf, length);
    close (handle);

    if (count < length)
        I_Error ("Couldn't read file %s", name);

    *buffer = buf;
    return length;
}

int M_strcmpi (const char* s1, const char* s2)
{
    while (tolower (*s1) == tolower (*s2))
    {
        if (*s1 == 0)
            return 0;
        ++s1;
        ++s2;
    }
    return tolower (*s2) - tolower (*s1);
}

int M_strncmpi (const char* s1, const char* s2, size_t n)
{
    if (n == 0)
        return 0;

    size_t i = 0;
    while (i < (n - 1) && tolower (*s1) == tolower (*s2))
    {
        if (*s1 == 0)
            return 0;
        ++s1;
        ++s2;
        ++i;
    }
    return tolower (*s2) - tolower (*s1);
}

const char* M_GetHomeDir ()
{
#if defined(MC1)
    return ".";
#else
    const char* home = getenv ("HOME");
    return home ? home : ".";  // TODO(m): Try harder.
#endif
}

const char* M_GetDoomWadDir ()
{
#if defined(MC1)
    return ".";
#else
    const char* waddir = getenv ("DOOMWADDIR");
    return waddir ? waddir : ".";
#endif
}

int M_FileExists (const char* name)
{
    struct stat buf;
    if (stat (name, &buf) != 0)
        return 0;
    return 1;
}

//
// DEFAULTS
//
int             usemouse;
int             usejoystick;

extern int      key_right;
extern int      key_left;
extern int      key_up;
extern int      key_down;

extern int      key_strafeleft;
extern int      key_straferight;

extern int      key_fire;
extern int      key_use;
extern int      key_strafe;
extern int      key_speed;

extern int      enable_mouseymove;
extern int      mousebfire;
extern int      mousebstrafe;
extern int      mousebuse;
extern int      mousebforward;

extern int      joybfire;
extern int      joybstrafe;
extern int      joybuse;
extern int      joybspeed;

extern int      viewwidth;
extern int      viewheight;

extern int      mouseSensitivity;
extern int      showMessages;

extern int      screenblocks;

extern int      showMessages;

// machine-independent sound params
extern  int     numChannels;

extern char*    chat_macros[];

typedef struct
{
    char*       name;
    int*        location;
    int         defaultvalue;
    char**      str_location;
    char*       str_defaultvalue;
    int         scantranslate;          // PC scan code hack
    int         untranslated;           // lousy hack
} default_t;

default_t defaults[] =
{
    {"sfx_volume", &snd_SfxVolume, 8, NULL, NULL, 0, 0},
    {"music_volume", &snd_MusicVolume, 8, NULL, NULL, 0, 0},
    {"show_messages", &showMessages, 1, NULL, NULL, 0, 0},

    {"key_right", &key_right, KEY_RIGHTARROW, NULL, NULL, 0, 0},
    {"key_left", &key_left, KEY_LEFTARROW, NULL, NULL, 0, 0},
    {"key_up", &key_up, 'w', NULL, NULL, 0, 0},
    {"key_down", &key_down, 's', NULL, NULL, 0, 0},
    {"key_strafeleft", &key_strafeleft, 'a', NULL, NULL, 0, 0},
    {"key_straferight", &key_straferight, 'd', NULL, NULL, 0, 0},

    {"key_fire", &key_fire, KEY_RCTRL, NULL, NULL, 0, 0},
    {"key_use", &key_use, ' ', NULL, NULL, 0, 0},
    {"key_strafe", &key_strafe, KEY_RALT, NULL, NULL, 0, 0},
    {"key_speed", &key_speed, KEY_RSHIFT, NULL, NULL, 0, 0},

    {"use_mouse", &usemouse, 1, NULL, NULL, 0, 0},
    {"mouse_sensitivity", &mouseSensitivity, 5, NULL, NULL, 0, 0},
    {"enable_mouseymove", &enable_mouseymove, 0, NULL, NULL, 0, 0},
    {"mouseb_fire", &mousebfire, 0, NULL, NULL, 0, 0},
    {"mouseb_strafe", &mousebstrafe, 1, NULL, NULL, 0, 0},
    {"mouseb_use", &mousebuse, 2, NULL, NULL, 0, 0},
    {"mouseb_forward", &mousebforward, -1, NULL, NULL, 0, 0},

    {"use_joystick", &usejoystick, 0, NULL, NULL, 0, 0},
    {"joyb_fire", &joybfire, 0, NULL, NULL, 0, 0},
    {"joyb_strafe", &joybstrafe, 1, NULL, NULL, 0, 0},
    {"joyb_use", &joybuse, 3, NULL, NULL, 0, 0},
    {"joyb_speed", &joybspeed, 2, NULL, NULL, 0, 0},

    {"screenblocks", &screenblocks, 10, NULL, NULL, 0, 0},

    {"snd_channels", &numChannels, 8, NULL, NULL, 0, 0},

    {"usegamma", &usegamma, 0, NULL, NULL, 0, 0},

    {"chatmacro0", NULL, 0, &chat_macros[0], HUSTR_CHATMACRO0, 0, 0 },
    {"chatmacro1", NULL, 0, &chat_macros[1], HUSTR_CHATMACRO1, 0, 0 },
    {"chatmacro2", NULL, 0, &chat_macros[2], HUSTR_CHATMACRO2, 0, 0 },
    {"chatmacro3", NULL, 0, &chat_macros[3], HUSTR_CHATMACRO3, 0, 0 },
    {"chatmacro4", NULL, 0, &chat_macros[4], HUSTR_CHATMACRO4, 0, 0 },
    {"chatmacro5", NULL, 0, &chat_macros[5], HUSTR_CHATMACRO5, 0, 0 },
    {"chatmacro6", NULL, 0, &chat_macros[6], HUSTR_CHATMACRO6, 0, 0 },
    {"chatmacro7", NULL, 0, &chat_macros[7], HUSTR_CHATMACRO7, 0, 0 },
    {"chatmacro8", NULL, 0, &chat_macros[8], HUSTR_CHATMACRO8, 0, 0 },
    {"chatmacro9", NULL, 0, &chat_macros[9], HUSTR_CHATMACRO9, 0, 0 }

};

int     numdefaults;
char*   defaultfile;

//
// M_SaveDefaults
//
void M_SaveDefaults (void)
{
    int         i;
    FILE*       f;

    f = fopen (defaultfile, "w");
    if (!f)
        return; // can't write the file, but don't complain

    for (i=0 ; i<numdefaults ; i++)
    {
        if (defaults[i].location != NULL)
        {
            fprintf (f, "%s\t\t%i\n", defaults[i].name,
                     *defaults[i].location);
        } else if (defaults[i].str_location != NULL) {
            fprintf (f, "%s\t\t\"%s\"\n", defaults[i].name,
                     *defaults[i].str_location);
        }
    }

    fclose (f);
}

//
// M_LoadDefaults
//
extern byte     scantokey[128];

void M_LoadDefaults (void)
{
    int         i;
    int         len;
    FILE*       f;
    char        def[80];
    char        strparm[100];
    char*       newstring;
    int         parm;

    // set everything to base values
    numdefaults = sizeof(defaults)/sizeof(defaults[0]);
    for (i=0 ; i<numdefaults ; i++)
    {
        if (defaults[i].location != NULL)
            *defaults[i].location = defaults[i].defaultvalue;
        if (defaults[i].str_location != NULL)
            *defaults[i].str_location = defaults[i].str_defaultvalue;
    }

    // check for a custom default file
    i = M_CheckParm ("-config");
    if (i && i<myargc-1)
    {
        defaultfile = myargv[i+1];
        printf ("       default file: %s\n",defaultfile);
    }
    else
        defaultfile = basedefault;

    // read the file in, overriding any set defaults
    f = fopen (defaultfile, "r");
    if (f)
    {
        while (!feof(f))
        {
            if (fscanf (f, "%79s %[^\n]\n", def, strparm) == 2)
            {
                newstring = NULL;
                if (strparm[0] == '"')
                {
                    // get a string default
                    len = strlen (strparm);
                    newstring = (char*)malloc (len);
                    strparm[len - 1] = 0;
                    strcpy (newstring, strparm + 1);
                }
                else if (strparm[0] == '0' && strparm[1] == 'x')
                    sscanf (strparm + 2, "%x", (unsigned*)&parm);
                else
                    sscanf (strparm, "%i", &parm);
                for (i = 0; i < numdefaults; i++)
                    if (!strcmp (def, defaults[i].name))
                    {
                        if (defaults[i].location != NULL && newstring == NULL)
                            *defaults[i].location = parm;
                        else if (defaults[i].str_location != NULL &&
                                 newstring != NULL)
                            *defaults[i].str_location = newstring;
                        break;
                    }
            }
        }

        fclose (f);
    }
}

//
// SCREEN SHOTS
//

typedef struct
{
    char                manufacturer;
    char                version;
    char                encoding;
    char                bits_per_pixel;

    unsigned short      xmin;
    unsigned short      ymin;
    unsigned short      xmax;
    unsigned short      ymax;

    unsigned short      hres;
    unsigned short      vres;

    unsigned char       palette[48];

    char                reserved;
    char                color_planes;
    unsigned short      bytes_per_line;
    unsigned short      palette_type;

    char                filler[58];
    unsigned char       data;           // unbounded
} pcx_t;

//
// WritePCXfile
//
void
WritePCXfile
( char*         filename,
  byte*         data,
  int           width,
  int           height,
  byte*         palette )
{
    int         i;
    int         length;
    pcx_t*      pcx;
    byte*       pack;

    pcx = (pcx_t*)Z_Malloc (width * height * 2 + 1000, PU_STATIC, NULL);

    pcx->manufacturer = 0x0a;           // PCX id
    pcx->version = 5;                   // 256 color
    pcx->encoding = 1;                  // uncompressed
    pcx->bits_per_pixel = 8;            // 256 color
    pcx->xmin = 0;
    pcx->ymin = 0;
    pcx->xmax = SHORT(width-1);
    pcx->ymax = SHORT(height-1);
    pcx->hres = SHORT(width);
    pcx->vres = SHORT(height);
    memset (pcx->palette,0,sizeof(pcx->palette));
    pcx->color_planes = 1;              // chunky image
    pcx->bytes_per_line = SHORT(width);
    pcx->palette_type = SHORT(2);       // not a grey scale
    memset (pcx->filler,0,sizeof(pcx->filler));

    // pack the image
    pack = &pcx->data;

    for (i=0 ; i<width*height ; i++)
    {
        if ( (*data & 0xc0) != 0xc0)
            *pack++ = *data++;
        else
        {
            *pack++ = 0xc1;
            *pack++ = *data++;
        }
    }

    // write the palette
    *pack++ = 0x0c;     // palette ID byte
    for (i=0 ; i<768 ; i++)
        *pack++ = *palette++;

    // write output file
    length = pack - (byte *)pcx;
    M_WriteFile (filename, pcx, length);

    Z_Free (pcx);
}

//
// M_ScreenShot
//
void M_ScreenShot (void)
{
    int         i;
    byte*       linear;
    char        lbmname[12];

    // munge planar buffer to linear
    linear = screens[2];
    I_ReadScreen (linear);

    // find a file name to save it to
    strcpy(lbmname,"DOOM00.pcx");

    for (i=0 ; i<=99 ; i++)
    {
        lbmname[4] = i/10 + '0';
        lbmname[5] = i%10 + '0';
        if (!M_FileExists (lbmname))
            break;      // file doesn't exist
    }
    if (i==100)
        I_Error ("M_ScreenShot: Couldn't create a PCX");

    // save the pcx file
    WritePCXfile (lbmname, linear,
                  SCREENWIDTH, SCREENHEIGHT,
                  W_CacheLumpName ("PLAYPAL",PU_CACHE));

    players[consoleplayer].message = "screen shot";
}

