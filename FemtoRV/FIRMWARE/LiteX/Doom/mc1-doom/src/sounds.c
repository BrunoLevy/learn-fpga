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
//      Created by a sound utility.
//      Kept as a sample, DOOM2 sounds.
//
//-----------------------------------------------------------------------------

#include "doomtype.h"
#include "sounds.h"

#include <stddef.h>

//
// Information about all the music
//

musicinfo_t S_music[] =
{
    { NULL, 0, NULL, 0 },
    { "e1m1", 0, NULL, 0 },
    { "e1m2", 0, NULL, 0 },
    { "e1m3", 0, NULL, 0 },
    { "e1m4", 0, NULL, 0 },
    { "e1m5", 0, NULL, 0 },
    { "e1m6", 0, NULL, 0 },
    { "e1m7", 0, NULL, 0 },
    { "e1m8", 0, NULL, 0 },
    { "e1m9", 0, NULL, 0 },
    { "e2m1", 0, NULL, 0 },
    { "e2m2", 0, NULL, 0 },
    { "e2m3", 0, NULL, 0 },
    { "e2m4", 0, NULL, 0 },
    { "e2m5", 0, NULL, 0 },
    { "e2m6", 0, NULL, 0 },
    { "e2m7", 0, NULL, 0 },
    { "e2m8", 0, NULL, 0 },
    { "e2m9", 0, NULL, 0 },
    { "e3m1", 0, NULL, 0 },
    { "e3m2", 0, NULL, 0 },
    { "e3m3", 0, NULL, 0 },
    { "e3m4", 0, NULL, 0 },
    { "e3m5", 0, NULL, 0 },
    { "e3m6", 0, NULL, 0 },
    { "e3m7", 0, NULL, 0 },
    { "e3m8", 0, NULL, 0 },
    { "e3m9", 0, NULL, 0 },
    { "inter", 0, NULL, 0 },
    { "intro", 0, NULL, 0 },
    { "bunny", 0, NULL, 0 },
    { "victor", 0, NULL, 0 },
    { "introa", 0, NULL, 0 },
    { "runnin", 0, NULL, 0 },
    { "stalks", 0, NULL, 0 },
    { "countd", 0, NULL, 0 },
    { "betwee", 0, NULL, 0 },
    { "doom", 0, NULL, 0 },
    { "the_da", 0, NULL, 0 },
    { "shawn", 0, NULL, 0 },
    { "ddtblu", 0, NULL, 0 },
    { "in_cit", 0, NULL, 0 },
    { "dead", 0, NULL, 0 },
    { "stlks2", 0, NULL, 0 },
    { "theda2", 0, NULL, 0 },
    { "doom2", 0, NULL, 0 },
    { "ddtbl2", 0, NULL, 0 },
    { "runni2", 0, NULL, 0 },
    { "dead2", 0, NULL, 0 },
    { "stlks3", 0, NULL, 0 },
    { "romero", 0, NULL, 0 },
    { "shawn2", 0, NULL, 0 },
    { "messag", 0, NULL, 0 },
    { "count2", 0, NULL, 0 },
    { "ddtbl3", 0, NULL, 0 },
    { "ampie", 0, NULL, 0 },
    { "theda3", 0, NULL, 0 },
    { "adrian", 0, NULL, 0 },
    { "messg2", 0, NULL, 0 },
    { "romer2", 0, NULL, 0 },
    { "tense", 0, NULL, 0 },
    { "shawn3", 0, NULL, 0 },
    { "openin", 0, NULL, 0 },
    { "evil", 0, NULL, 0 },
    { "ultima", 0, NULL, 0 },
    { "read_m", 0, NULL, 0 },
    { "dm2ttl", 0, NULL, 0 },
    { "dm2int", 0, NULL, 0 }
};

//
// Information about all the sfx
//

sfxinfo_t S_sfx[] =
{
  // S_sfx[0] needs to be a dummy for odd reasons.
  { "none", false,  0, NULL, -1, -1, NULL, 0, 0 },

  { "pistol", false, 64, NULL, -1, -1, NULL, 0, 0 },
  { "shotgn", false, 64, NULL, -1, -1, NULL, 0, 0 },
  { "sgcock", false, 64, NULL, -1, -1, NULL, 0, 0 },
  { "dshtgn", false, 64, NULL, -1, -1, NULL, 0, 0 },
  { "dbopn", false, 64, NULL, -1, -1, NULL, 0, 0 },
  { "dbcls", false, 64, NULL, -1, -1, NULL, 0, 0 },
  { "dbload", false, 64, NULL, -1, -1, NULL, 0, 0 },
  { "plasma", false, 64, NULL, -1, -1, NULL, 0, 0 },
  { "bfg", false, 64, NULL, -1, -1, NULL, 0, 0 },
  { "sawup", false, 64, NULL, -1, -1, NULL, 0, 0 },
  { "sawidl", false, 118, NULL, -1, -1, NULL, 0, 0 },
  { "sawful", false, 64, NULL, -1, -1, NULL, 0, 0 },
  { "sawhit", false, 64, NULL, -1, -1, NULL, 0, 0 },
  { "rlaunc", false, 64, NULL, -1, -1, NULL, 0, 0 },
  { "rxplod", false, 70, NULL, -1, -1, NULL, 0, 0 },
  { "firsht", false, 70, NULL, -1, -1, NULL, 0, 0 },
  { "firxpl", false, 70, NULL, -1, -1, NULL, 0, 0 },
  { "pstart", false, 100, NULL, -1, -1, NULL, 0, 0 },
  { "pstop", false, 100, NULL, -1, -1, NULL, 0, 0 },
  { "doropn", false, 100, NULL, -1, -1, NULL, 0, 0 },
  { "dorcls", false, 100, NULL, -1, -1, NULL, 0, 0 },
  { "stnmov", false, 119, NULL, -1, -1, NULL, 0, 0 },
  { "swtchn", false, 78, NULL, -1, -1, NULL, 0, 0 },
  { "swtchx", false, 78, NULL, -1, -1, NULL, 0, 0 },
  { "plpain", false, 96, NULL, -1, -1, NULL, 0, 0 },
  { "dmpain", false, 96, NULL, -1, -1, NULL, 0, 0 },
  { "popain", false, 96, NULL, -1, -1, NULL, 0, 0 },
  { "vipain", false, 96, NULL, -1, -1, NULL, 0, 0 },
  { "mnpain", false, 96, NULL, -1, -1, NULL, 0, 0 },
  { "pepain", false, 96, NULL, -1, -1, NULL, 0, 0 },
  { "slop", false, 78, NULL, -1, -1, NULL, 0, 0 },
  { "itemup", true, 78, NULL, -1, -1, NULL, 0, 0 },
  { "wpnup", true, 78, NULL, -1, -1, NULL, 0, 0 },
  { "oof", false, 96, NULL, -1, -1, NULL, 0, 0 },
  { "telept", false, 32, NULL, -1, -1, NULL, 0, 0 },
  { "posit1", true, 98, NULL, -1, -1, NULL, 0, 0 },
  { "posit2", true, 98, NULL, -1, -1, NULL, 0, 0 },
  { "posit3", true, 98, NULL, -1, -1, NULL, 0, 0 },
  { "bgsit1", true, 98, NULL, -1, -1, NULL, 0, 0 },
  { "bgsit2", true, 98, NULL, -1, -1, NULL, 0, 0 },
  { "sgtsit", true, 98, NULL, -1, -1, NULL, 0, 0 },
  { "cacsit", true, 98, NULL, -1, -1, NULL, 0, 0 },
  { "brssit", true, 94, NULL, -1, -1, NULL, 0, 0 },
  { "cybsit", true, 92, NULL, -1, -1, NULL, 0, 0 },
  { "spisit", true, 90, NULL, -1, -1, NULL, 0, 0 },
  { "bspsit", true, 90, NULL, -1, -1, NULL, 0, 0 },
  { "kntsit", true, 90, NULL, -1, -1, NULL, 0, 0 },
  { "vilsit", true, 90, NULL, -1, -1, NULL, 0, 0 },
  { "mansit", true, 90, NULL, -1, -1, NULL, 0, 0 },
  { "pesit", true, 90, NULL, -1, -1, NULL, 0, 0 },
  { "sklatk", false, 70, NULL, -1, -1, NULL, 0, 0 },
  { "sgtatk", false, 70, NULL, -1, -1, NULL, 0, 0 },
  { "skepch", false, 70, NULL, -1, -1, NULL, 0, 0 },
  { "vilatk", false, 70, NULL, -1, -1, NULL, 0, 0 },
  { "claw", false, 70, NULL, -1, -1, NULL, 0, 0 },
  { "skeswg", false, 70, NULL, -1, -1, NULL, 0, 0 },
  { "pldeth", false, 32, NULL, -1, -1, NULL, 0, 0 },
  { "pdiehi", false, 32, NULL, -1, -1, NULL, 0, 0 },
  { "podth1", false, 70, NULL, -1, -1, NULL, 0, 0 },
  { "podth2", false, 70, NULL, -1, -1, NULL, 0, 0 },
  { "podth3", false, 70, NULL, -1, -1, NULL, 0, 0 },
  { "bgdth1", false, 70, NULL, -1, -1, NULL, 0, 0 },
  { "bgdth2", false, 70, NULL, -1, -1, NULL, 0, 0 },
  { "sgtdth", false, 70, NULL, -1, -1, NULL, 0, 0 },
  { "cacdth", false, 70, NULL, -1, -1, NULL, 0, 0 },
  { "skldth", false, 70, NULL, -1, -1, NULL, 0, 0 },
  { "brsdth", false, 32, NULL, -1, -1, NULL, 0, 0 },
  { "cybdth", false, 32, NULL, -1, -1, NULL, 0, 0 },
  { "spidth", false, 32, NULL, -1, -1, NULL, 0, 0 },
  { "bspdth", false, 32, NULL, -1, -1, NULL, 0, 0 },
  { "vildth", false, 32, NULL, -1, -1, NULL, 0, 0 },
  { "kntdth", false, 32, NULL, -1, -1, NULL, 0, 0 },
  { "pedth", false, 32, NULL, -1, -1, NULL, 0, 0 },
  { "skedth", false, 32, NULL, -1, -1, NULL, 0, 0 },
  { "posact", true, 120, NULL, -1, -1, NULL, 0, 0 },
  { "bgact", true, 120, NULL, -1, -1, NULL, 0, 0 },
  { "dmact", true, 120, NULL, -1, -1, NULL, 0, 0 },
  { "bspact", true, 100, NULL, -1, -1, NULL, 0, 0 },
  { "bspwlk", true, 100, NULL, -1, -1, NULL, 0, 0 },
  { "vilact", true, 100, NULL, -1, -1, NULL, 0, 0 },
  { "noway", false, 78, NULL, -1, -1, NULL, 0, 0 },
  { "barexp", false, 60, NULL, -1, -1, NULL, 0, 0 },
  { "punch", false, 64, NULL, -1, -1, NULL, 0, 0 },
  { "hoof", false, 70, NULL, -1, -1, NULL, 0, 0 },
  { "metal", false, 70, NULL, -1, -1, NULL, 0, 0 },
  { "chgun", false, 64, &S_sfx[sfx_pistol], 150, 0, NULL, 0, 0 },
  { "tink", false, 60, NULL, -1, -1, NULL, 0, 0 },
  { "bdopn", false, 100, NULL, -1, -1, NULL, 0, 0 },
  { "bdcls", false, 100, NULL, -1, -1, NULL, 0, 0 },
  { "itmbk", false, 100, NULL, -1, -1, NULL, 0, 0 },
  { "flame", false, 32, NULL, -1, -1, NULL, 0, 0 },
  { "flamst", false, 32, NULL, -1, -1, NULL, 0, 0 },
  { "getpow", false, 60, NULL, -1, -1, NULL, 0, 0 },
  { "bospit", false, 70, NULL, -1, -1, NULL, 0, 0 },
  { "boscub", false, 70, NULL, -1, -1, NULL, 0, 0 },
  { "bossit", false, 70, NULL, -1, -1, NULL, 0, 0 },
  { "bospn", false, 70, NULL, -1, -1, NULL, 0, 0 },
  { "bosdth", false, 70, NULL, -1, -1, NULL, 0, 0 },
  { "manatk", false, 70, NULL, -1, -1, NULL, 0, 0 },
  { "mandth", false, 70, NULL, -1, -1, NULL, 0, 0 },
  { "sssit", false, 70, NULL, -1, -1, NULL, 0, 0 },
  { "ssdth", false, 70, NULL, -1, -1, NULL, 0, 0 },
  { "keenpn", false, 70, NULL, -1, -1, NULL, 0, 0 },
  { "keendt", false, 70, NULL, -1, -1, NULL, 0, 0 },
  { "skeact", false, 70, NULL, -1, -1, NULL, 0, 0 },
  { "skesit", false, 70, NULL, -1, -1, NULL, 0, 0 },
  { "skeatk", false, 70, NULL, -1, -1, NULL, 0, 0 },
  { "radio", false, 60, NULL, -1, -1, NULL, 0, 0 }
};

