// Emacs style mode select   -*- C++ -*-
//-----------------------------------------------------------------------------
//
// Copyright (C) 1993-1996 by id Software, Inc.
// Copyright (C) 2020 by Marcus Geelnard.
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
//      System interface for sound.
//
//-----------------------------------------------------------------------------

#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#define _POSIX_SOURCE  // Because ALSA redefines struct timespec otherwise.
#include <alsa/asoundlib.h>

#include "z_zone.h"

#include "i_system.h"
#include "i_sound.h"
#include "m_argv.h"
#include "m_misc.h"
#include "w_wad.h"

#include "doomdef.h"

// The number of internal mixing channels,
//  the samples calculated for each mixing step,
//  the size of the 16bit, 2 hardware channel (stereo)
//  mixing buffer, and the samplerate of the raw data.

#define SAMPLECOUNT 4096      // Number of samples
#define SAMPLECHANS 2         // Stereo
#define SAMPLESIZE 4          // 16-bit stereo (4 bytes)
#define SAMPLERATE 44100      // Hz
#define LATENCY_MICROS 40000  // 40 ms

#define MIXBUFFERSIZE (SAMPLECOUNT * SAMPLECHANS)
#define NUM_CHANNELS 8

// Externally, the volume range is 0..15, but we use a wider range internally to
// support stereo separation with greater precision.
#define VOL_MAX 255
#define VOL_SHIFT 8

// The actual lengths of all sound effects.
static int s_sfx_lengths[NUMSFX];

// The global mixing buffer.
// Basically, samples from all active internal channels
//  are modifed and added, and stored in the buffer
//  that is submitted to the audio device.
static signed short s_mixbuffer[MIXBUFFERSIZE];

// The state for one internal mix channel.
typedef struct
{
    unsigned char* data;      // Current sample pointer
    unsigned char* data_end;  // Sample end
    int leftvol;              // Left volume
    int rightvol;             // Right volume
    unsigned int step;        // 16.16 bit step size
    unsigned int step_rem;    // 0.16 bit remainder of last step
    int start_t;              // Start time for the sound
    int handle;               // External handle
    int id;                   // SFX id (used to catch duplicates)
} mixchannel_t;

static mixchannel_t s_channel[NUM_CHANNELS];

// We keep track of where in the mixbuffer we shall start mixing, based on how
// much was left from the previous mixing pass in case not all samples were sent
// to the sound device.
static int s_mix_start;

// A counter that keeps track of unique channel handles.
static int s_next_handle;

// Pitch to stepping lookup, unused.
static int s_steptable[256];

// ALSA PCM handle.
static snd_pcm_t* s_alsa_handle;

//
// This function loads the sound data from the WAD lump, for single sound.
//
static void* getsfx (const char* sfxname, int* len)
{
    // Get the sound data from the WAD, allocate lump in zone memory.
    char name[20];
    sprintf (name, "ds%s", sfxname);

    // Now, there is a severe problem with the sound handling, in it is not
    // (yet/anymore) gamemode aware. That means, sounds from DOOM II will be
    // requested even with DOOM shareware.
    //
    // The sound list is wired into sounds.c, which sets the external variable.
    // I do not do runtime patches to that variable. Instead, we will use a
    // default sound for replacement.
    int sfxlump;
    if (W_CheckNumForName (name) == -1)
        sfxlump = W_GetNumForName ("dspistol");
    else
        sfxlump = W_GetNumForName (name);

    int size = W_LumpLength (sfxlump);

    // Debug.
#if 0
    fprintf (
        stderr, " -loading %s (lump %d, %d bytes)\n", sfxname, sfxlump, size);
    fflush (stderr);
#endif

    unsigned char* sfx = (unsigned char*)W_CacheLumpNum (sfxlump, PU_STATIC);

    // Not sure what the 8 here is, but I suppose it's a header of sorts.
    unsigned char* samples = sfx + 8;
    int samples_size = size - 8;

    // Pads the sound effect out to the mixing buffer size (this enables faster
    // sampling since we don't have to check for the end of the data in the
    // sampling routine - not currently used though).
    int paddedsize =
        ((samples_size + (SAMPLECOUNT - 1)) / SAMPLECOUNT) * SAMPLECOUNT;

    // Allocate from zone memory.
    unsigned char* paddedsfx =
        (unsigned char*)Z_Malloc (paddedsize, PU_STATIC, 0);

    // Now copy and pad.
    memcpy (paddedsfx, samples, (size_t)samples_size);
    for (int i = samples_size; i < paddedsize; i++)
        paddedsfx[i] = 128;

    // Remove the cached lump.
    Z_Free (sfx);

    // We return the original sound length (without padding).
    *len = samples_size;

    // Return allocated padded data.
    return (void*)paddedsfx;
}

static inline int clamp (int x, int minval, int maxval)
{
    if (x < minval)
        return minval;
    if (x > maxval)
        return maxval;
    return x;
}

static inline short clamp_to_short (int x)
{
    return (short)clamp (x, -32768, 32767);
}

static void setchannelvolume (int chan, int vol, int sep)
{
    // Convert volume range from 0..15 to 0..255.
    vol *= 17;

    // Calculate the left/right channel volume.
    // x^2 seperation, adjust volume properly.
    // sep is in the range 0..255 (128 represents center).
    int lsep = sep + 1;    // 1..256
    int rsep = sep - 257;  // -1..255
    int leftvol = vol - ((vol * lsep * lsep) >> 16);
    int rightvol = vol - ((vol * rsep * rsep) >> 16);

    // Clamp the volume (just in case - should not be necessary).
    s_channel[chan].leftvol = clamp (leftvol, 0, VOL_MAX);
    s_channel[chan].rightvol = clamp (rightvol, 0, VOL_MAX);
}

//
// SFX API
//

void I_InitSound ()
{
    int i;
    int err;

    // Secure and configure sound device first.
    fprintf (stderr, "I_InitSound: ");
    if ((err = snd_pcm_open (&s_alsa_handle,
                             "default",
                             SND_PCM_STREAM_PLAYBACK,
                             SND_PCM_NONBLOCK)) < 0)
    {
        fprintf (stderr, "snd_pcm_open error: %s\n", snd_strerror (err));
        return;
    }
    if ((err = snd_pcm_set_params (s_alsa_handle,
                                   SND_PCM_FORMAT_S16_LE,
                                   SND_PCM_ACCESS_RW_INTERLEAVED,
                                   2,
                                   SAMPLERATE,
                                   1,
                                   LATENCY_MICROS)) < 0)
    {
        fprintf (stderr, "snd_pcm_set_params error: %s\n", snd_strerror (err));
        return;
    }
    fprintf (stderr, "Configured audio device.\n");

    // Initialize external data (all sounds) at start, keep static.
    fprintf (stderr, "I_InitSound: ");

    // Pre-cache all sounds effects.
    for (i = 1; i < NUMSFX; i++)
    {
        // Alias? Example is the chaingun sound linked to pistol.
        if (!S_sfx[i].link)
        {
            // Load data from WAD file.
            S_sfx[i].data = getsfx (S_sfx[i].name, &s_sfx_lengths[i]);
        }
        else
        {
            // Previously loaded already?
            S_sfx[i].data = S_sfx[i].link->data;
            s_sfx_lengths[i] =
                s_sfx_lengths[(S_sfx[i].link - S_sfx) /
                              sizeof (sfxinfo_t)];  // Is this correct?
        }
    }
    fprintf (stderr, "Pre-cached all sound data.\n");

    // This table provides step widths for pitch parameters.
    for (int i = -128; i < 128; i++)
        s_steptable[i + 128] =
            (int)(pow (2.0, (i / 64.0)) * (11025.0 / SAMPLERATE) * 65536.0);

    // Reset internal mixing channel state.
    for (int i = 0; i < NUM_CHANNELS; i++)
        memset (&s_channel[i], 0, sizeof (mixchannel_t));

    // Now initialize mixbuffer with zero.
    memset (&s_mixbuffer[0], 0, sizeof(s_mixbuffer));

    // We start mixing at the beginning of the mixbuffer.
    s_mix_start = 0;

    // Start with a non-zero handle.
    s_next_handle = 123;

    // Finished initialization.
    fprintf (stderr, "I_InitSound: Sound module ready.\n");
}

void I_ShutdownSound (void)
{
    // Wait till all pending sounds are finished.
    int done = 0;
    int i;
    int err;

    // FIXME (below).
    fprintf (stderr, "I_ShutdownSound: NOT finishing pending sounds\n");
    fflush (stderr);

    while (!done)
    {
        for (i = 0; i < 8 && s_channel[i].data == NULL; i++)
            ;

        // FIXME. No proper channel output.
        // if (i==8)
        done = 1;
    }

    // Cleaning up.
    err = snd_pcm_drain (s_alsa_handle);
    if (err < 0)
        printf ("snd_pcm_drain failed: %s\n", snd_strerror (err));
    snd_pcm_close (s_alsa_handle);

    // Done.
    return;
}

//
// Retrieve the raw data lump index for a given SFX name.
//
int I_GetSfxLumpNum (sfxinfo_t* sfx)
{
    char namebuf[9];
    sprintf (namebuf, "ds%s", sfx->name);
    return W_GetNumForName (namebuf);
}

//
// Starting a sound means adding it to the current list of active sounds in the
// internal channels.
//
int I_StartSound (int id, int vol, int sep, int pitch, int priority)
{
    // UNUSED
    (void)priority;

    // Chainsaw troubles.
    // Play these sound effects only one at a time.
    if (id == sfx_sawup || id == sfx_sawidl || id == sfx_sawful ||
        id == sfx_sawhit || id == sfx_stnmov || id == sfx_pistol)
    {
        // Loop all channels, check.
        for (int i = 0; i < NUM_CHANNELS; i++)
        {
            // Active, and using the same SFX?
            if (s_channel[i].data != NULL && s_channel[i].id == id)
            {
                // Reset.
                s_channel[i].data = NULL;
                // We are sure that iff, there will only be one.
                break;
            }
        }
    }

    // Find a free channel, or replace the oldest SFX.
    // TODO(m): We should use priority and/or volume here too.
    int chan = 0;
    int oldest = gametic;
    for (int i = 0; i < NUM_CHANNELS; i++)
    {
        if (s_channel[i].data == NULL)
        {
            chan = i;
            break;
        }
        if (s_channel[i].start_t < oldest)
        {
            chan = i;
            oldest = s_channel[i].start_t;
        }
    }

    // Set start/stop pointers to the raw data.
    s_channel[chan].data = (unsigned char*)S_sfx[id].data;
    s_channel[chan].data_end = s_channel[chan].data + s_sfx_lengths[id];

    // Set the sample step size (pitch).
    s_channel[chan].step = (unsigned int)s_steptable[pitch];
    s_channel[chan].step_rem = 0u;

    // Set the channel volume.
    setchannelvolume (chan, vol, sep);

    // Set the start gametic.
    s_channel[chan].start_t = gametic;

    // Preserve sound SFX id, e.g. for avoiding duplicates of chainsaw.
    s_channel[chan].id = id;

    // Assign and return a handle to this SFX.
    s_channel[chan].handle = s_next_handle++;
    return s_channel[chan].handle;
}

void I_UpdateSoundParams (int handle, int vol, int sep, int pitch)
{
    for (int i = 0; i < NUM_CHANNELS; i++)
    {
        if (s_channel[i].data != NULL && s_channel[i].handle == handle)
        {
            s_channel[i].step = (unsigned int)s_steptable[pitch];
            setchannelvolume (i, vol, sep);
            break;
        }
    }
}

void I_StopSound (int handle)
{
    for (int i = 0; i < NUM_CHANNELS; i++)
    {
        if (s_channel[i].data != NULL && s_channel[i].handle == handle)
        {
            s_channel[i].data = NULL;
            break;
        }
    }
}

//
// Stop all playing sounds.
//
void I_StopAllSounds ()
{
    for (int i = 0; i < NUM_CHANNELS; i++)
        s_channel[i].data = NULL;
}

int I_SoundIsPlaying (int handle)
{
    for (int i = 0; i < NUM_CHANNELS; i++)
    {
        if (s_channel[i].data != NULL && s_channel[i].handle == handle)
        {
            return 1;
        }
    }

    return 0;
}

//
// This function loops all active (internal) sound channels, retrieves a given
// number of samples from the raw sound data, modifies it according to the
// current (internal) channel parameters, mixes the per channel samples into the
// global mixbuffer, clamping it to the allowed range, and sets up everything
// for transferring the contents of the mixbuffer to the (two) hardware channels
// (left and right, that is).
//
void I_UpdateSound (void)
{
    // Mix sounds into the mixing buffer.
    for (int i = s_mix_start; i < SAMPLECOUNT; ++i)
    {
        int dl = 0;
        int dr = 0;
        for (int chan = 0; chan < NUM_CHANNELS; chan++)
        {
            mixchannel_t* channel = &s_channel[chan];

            // Check channel, if active.
            unsigned char* sample_ptr = channel->data;
            if (sample_ptr)
            {
                int frac_pos = (int)channel->step_rem;

                // Perform linear interpolation between two consecutive samples,
                // and convert from 8-bit unsigned to 16-bit signed.
                // Note: It is safe to sample beyond the end of the sample since
                // we have added padding.
                int s1 = (int)sample_ptr[0];
                int s2 = (int)sample_ptr[1];
                int sample = (s1 << 8) + ((frac_pos * (s2 - s1)) >> 8) - 32768;

                // Add left and right part for this channel (sound) to the
                // current data. Adjust volume accordingly.
                dl += (channel->leftvol * sample) >> VOL_SHIFT;
                dr += (channel->rightvol * sample) >> VOL_SHIFT;

                // Update the sample position using fixed point (16.16 bit)
                // arithmetic.
                unsigned int increment = channel->step + (unsigned int)frac_pos;
                sample_ptr += increment >> 16;
                channel->step_rem = increment & 65535u;

                // Check whether we have reached the end of this sample.
                if (sample_ptr >= channel->data_end)
                    sample_ptr = NULL;

                channel->data = sample_ptr;
            }
        }

        s_mixbuffer[SAMPLECHANS * i] = clamp_to_short (dl);
        s_mixbuffer[SAMPLECHANS * i + 1] = clamp_to_short (dr);
    }
}

//
// This would be used to write out the mixbuffer during each game loop update.
// Updates sound buffer and audio device at runtime.
//
void I_SubmitSound (void)
{
    snd_pcm_uframes_t frames_left = SAMPLECOUNT;
    while (frames_left > 0)
    {
        snd_pcm_sframes_t res =
            snd_pcm_writei (s_alsa_handle, s_mixbuffer, frames_left);
        if (res < 0)
            res = snd_pcm_recover (s_alsa_handle, (int)res, 1);
        if (res < 0)
        {
            // We get EAGAIN when the resource is busy (because we're using
            // non-blocking mode and the device can't accept any more data right
            // now). We'll try again the next time I_SubmitSound is called.
            // If the error was something else, print it.
            if (res != -EAGAIN)
            {
                printf ("snd_pcm_writei failed: %s\n", snd_strerror ((int)res));
            }
            break;
        }
        frames_left -= (snd_pcm_uframes_t)res;
    }

    // Keep mix samples that were not submitted.
    if (frames_left > 0 && frames_left < SAMPLECOUNT)
    {
        // TODO(m): We may be able to avoid the memmove if we treat the
        // mixbuffer as a circular FIFO.
        size_t offs = (SAMPLECOUNT - frames_left) * SAMPLECHANS;
        size_t size = frames_left * SAMPLESIZE;
        memmove (&s_mixbuffer[0], &s_mixbuffer[offs], size);
        s_mix_start = (int)frames_left;
    }
    else
    {
        s_mix_start = 0;
    }
}

//
// MUSIC API.
// Still no music done.
//
static int s_music_looping;
static int s_music_dies;

void I_InitMusic (void)
{
    s_music_looping = 0;
    s_music_dies = 0;
}

void I_ShutdownMusic (void)
{
}

void I_SetMusicVolume (int volume)
{
    // UNUSED.
    (void)volume;
}

void I_PlaySong (int handle, int looping)
{
    // UNUSED.
    (void)handle;

    s_music_looping = looping;

    // Dummy: Say that the music ends after 30 seconds.
    s_music_dies = gametic + TICRATE * 30;
}

void I_PauseSong (int handle)
{
    // UNUSED.
    (void)handle;
}

void I_ResumeSong (int handle)
{
    // UNUSED.
    (void)handle;
}

void I_StopSong (int handle)
{
    // UNUSED.
    (void)handle;

    s_music_looping = 0;
    s_music_dies = 0;
}

void I_UnRegisterSong (int handle)
{
    // UNUSED.
    (void)handle;
}

int I_RegisterSong (void* data)
{
    // UNUSED.
    (void)data;

    return 1;
}

// Is the song playing?
int I_QrySongPlaying (int handle)
{
    // UNUSED.
    (void)handle;

    return s_music_looping || (s_music_dies > gametic);
}
