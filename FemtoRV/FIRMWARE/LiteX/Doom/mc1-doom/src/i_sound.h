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
//      System interface, sound.
//
//-----------------------------------------------------------------------------

#ifndef __I_SOUND__
#define __I_SOUND__

#include "doomdef.h"
#include "doomstat.h"
#include "sounds.h"

// Init at program start...
void I_InitSound ();

// ... update sound buffer and audio device at runtime...
void I_UpdateSound (void);
void I_SubmitSound (void);

// ... shut down and relase at program termination.
void I_ShutdownSound (void);

//
//  SFX I/O
//

// Get raw data lump index for sound descriptor.
int I_GetSfxLumpNum (sfxinfo_t* sfxinfo);

// Starts a sound in a particular sound channel.
int I_StartSound (int id, int vol, int sep, int pitch, int priority);

// Stops a sound channel.
void I_StopSound (int handle);

// Stop all playing sounds.
void I_StopAllSounds ();

// Called by S_*() functions
//  to see if a channel is still playing.
// Returns 0 if no longer playing, 1 if playing.
int I_SoundIsPlaying (int handle);

// Updates the volume, separation,
//  and pitch of a sound channel.
void I_UpdateSoundParams (int handle, int vol, int sep, int pitch);

//
//  MUSIC I/O
//
void I_InitMusic (void);
void I_ShutdownMusic (void);

// Volume.
void I_SetMusicVolume (int volume);

// PAUSE game handling.
void I_PauseSong (int handle);
void I_ResumeSong (int handle);

// Registers a song handle to song data.
int I_RegisterSong (void* data);

// Check if the song is actually playing right now.
int I_QrySongPlaying (int handle);

// Called by anything that wishes to start music.
//  plays a song, and when the song is done,
//  starts playing it again in an endless loop.
// Horrible thing to do, considering.
void I_PlaySong (int handle, int looping);

// Stops a song over 3 seconds.
void I_StopSong (int handle);

// See above (register), then think backwards
void I_UnRegisterSong (int handle);

#endif  // __I_SOUND__
