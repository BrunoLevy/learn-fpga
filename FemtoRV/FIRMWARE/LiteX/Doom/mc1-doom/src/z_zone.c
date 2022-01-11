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
//      Zone Memory Allocation. Neat.
//
//-----------------------------------------------------------------------------

#include "z_zone.h"
#include "i_system.h"
#include "doomdef.h"

#include <inttypes.h>

//
// ZONE MEMORY ALLOCATION
//
// There is never any space between memblocks,
//  and there will never be two contiguous free memblocks.
// The rover can be left pointing at a non-empty block.
//
// It is of no value to free a cachable block,
//  because it will get overwritten automatically if needed.
//

#define ZONEID    0x1d4a11
#define ZONEGUARD 0xc001beef

typedef struct
{
    // total bytes malloced, including header
    int         size;

    // start / end cap for linked list
    memblock_t  blocklist;

    memblock_t* rover;

} memzone_t;

memzone_t*      mainzone;

#ifdef ZONE_DEBUG
static void
Z_CheckBlockIntegrity (const memblock_t* block)
{
    if (block->guard1 != ZONEGUARD || block->guard2 != ZONEGUARD)
        I_Error ("Z_CheckBlockIntegrity: guards have been clobbered");
    if (block->id != 0 && block->id != ZONEID)
        I_Error ("Z_CheckBlockIntegrity: invalid ID %d", block->id);
}
#else
#define Z_CheckBlockIntegrity(block)
#endif

//
// Z_ClearZone
//
void Z_ClearZone (memzone_t* zone)
{
    memblock_t*         block;

    // set the entire zone to one free block
    zone->blocklist.next =
        zone->blocklist.prev =
        block = (memblock_t *)( (byte *)zone + sizeof(memzone_t) );

    zone->blocklist.user = (void *)zone;
    zone->blocklist.tag = PU_STATIC;
    zone->rover = block;

    block->prev = block->next = &zone->blocklist;

    // NULL indicates a free block.
    block->user = NULL;

    block->size = zone->size - sizeof(memzone_t);
}

//
// Z_Init
//
void Z_Init (void)
{
    memblock_t* block;
    int         size;

    mainzone = (memzone_t *)I_ZoneBase (&size);
    if (mainzone == NULL)
        I_Error ("Z_Init: Out of memory (tried to allocate %d bytes", size);
    mainzone->size = size;

#ifdef ZONE_DEBUG
    memset (mainzone, 0x55, size);
#endif

    // set the entire zone to one free block
    mainzone->blocklist.next =
        mainzone->blocklist.prev =
        block = (memblock_t *)( (byte *)mainzone + sizeof(memzone_t) );

    mainzone->blocklist.user = (void *)mainzone;
    mainzone->blocklist.tag = PU_STATIC;
    mainzone->rover = block;

    block->prev = block->next = &mainzone->blocklist;

    // NULL indicates a free block.
    block->user = NULL;
    block->size = mainzone->size - sizeof(memzone_t);

#ifdef ZONE_DEBUG
    block->guard1 = block->guard2 = ZONEGUARD;
#endif
}

//
// Z_Free
//
void Z_Free (void* ptr)
{
    memblock_t*         block;
    memblock_t*         other;

    block = (memblock_t *) ( (byte *)ptr - sizeof(memblock_t));
    Z_CheckBlockIntegrity (block);

    if (block->id != ZONEID)
        I_Error ("Z_Free: freed a pointer without ZONEID");

    if (block->user > (void **)0x100)
    {
        // smaller values are not pointers
        // Note: OS-dependend?

        // clear the user's mark
        *block->user = 0;
    }

    // mark as free
    block->user = NULL;
    block->tag = 0;
    block->id = 0;

    other = block->prev;

    if (!other->user)
    {
        // merge with previous free block
        other->size += block->size;
        other->next = block->next;
        other->next->prev = other;

        if (block == mainzone->rover)
            mainzone->rover = other;

        block = other;
    }

    other = block->next;
    if (!other->user)
    {
        // merge the next free block onto the end
        block->size += other->size;
        block->next = other->next;
        block->next->prev = block;

        if (other == mainzone->rover)
            mainzone->rover = block;
    }
}

//
// Z_Malloc
// You can pass a NULL user if the tag is < PU_PURGELEVEL.
//
#define MINFRAGMENT             64

void*
Z_Malloc
( int           size,
  int           tag,
  void*         user )
{
    int         extra;
    memblock_t* start;
    memblock_t* rover;
    memblock_t* newblock;
    memblock_t* base;

    size = (size + (int)sizeof(size_t) - 1) & ~((int)sizeof(size_t) - 1);

    // scan through the block list,
    // looking for the first free block
    // of sufficient size,
    // throwing out any purgable blocks along the way.

    // account for size of block header
    size += sizeof(memblock_t);

    // if there is a free block behind the rover,
    //  back up over them
    base = mainzone->rover;

    if (!base->prev->user)
        base = base->prev;

    rover = base;
    start = base->prev;

    do
    {
        if (rover == start)
        {
            // scanned all the way around the list
            I_Error ("Z_Malloc: failed on allocation of %i bytes", size);
        }

        if (rover->user)
        {
            if (rover->tag < PU_PURGELEVEL)
            {
                // hit a block that can't be purged,
                //  so move base past it
                base = rover = rover->next;
            }
            else
            {
                // free the rover block (adding the size to base)

                // the rover can be the base block
                base = base->prev;
                Z_Free ((byte *)rover+sizeof(memblock_t));
                base = base->next;
                rover = base->next;
            }
        }
        else
            rover = rover->next;
    } while (base->user || base->size < size);

    // found a block big enough
    extra = base->size - size;

    if (extra >  MINFRAGMENT)
    {
        // there will be a free fragment after the allocated block
        newblock = (memblock_t *) ((byte *)base + size );
        newblock->size = extra;
#ifdef ZONE_DEBUG
        newblock->guard1 = newblock->guard2 = ZONEGUARD;
#endif

        // NULL indicates free block.
        newblock->user = NULL;
        newblock->tag = 0;
        newblock->id = 0;
        newblock->prev = base;
        newblock->next = base->next;
        newblock->next->prev = newblock;

        base->next = newblock;
        base->size = size;
    }

    if (user)
    {
        // mark as an in use block
        base->user = user;
        *(void **)user = (void *) ((byte *)base + sizeof(memblock_t));
    }
    else
    {
        if (tag >= PU_PURGELEVEL)
            I_Error ("Z_Malloc: an owner is required for purgable blocks");

        // mark as in use, but unowned
        base->user = (void *)2;
    }
    base->tag = tag;

    // next allocation will start looking here
    mainzone->rover = base->next;

    base->id = ZONEID;

#ifdef ZONE_DEBUG
    base->guard1 = base->guard2 = ZONEGUARD;
#endif

    return (void *) ((byte *)base + sizeof(memblock_t));
}

//
// Z_FreeTags
//
void
Z_FreeTags
( int           lowtag,
  int           hightag )
{
    memblock_t* block;
    memblock_t* next;

    for (block = mainzone->blocklist.next ;
         block != &mainzone->blocklist ;
         block = next)
    {
        Z_CheckBlockIntegrity (block);

        // get link before freeing
        next = block->next;

        // free block?
        if (!block->user)
            continue;

        if (block->tag >= lowtag && block->tag <= hightag)
            Z_Free ( (byte *)block+sizeof(memblock_t));
    }
}

//
// Z_DumpHeap
// Note: TFileDumpHeap( stdout ) ?
//
void
Z_DumpHeap
( int           lowtag,
  int           hightag )
{
    memblock_t* block;

    printf ("zone size: %i  location: %p\n", mainzone->size, (void*)mainzone);

    printf ("tag range: %i to %i\n",
            lowtag, hightag);

    for (block = mainzone->blocklist.next ; ; block = block->next)
    {
        Z_CheckBlockIntegrity (block);

        if (block->tag >= lowtag && block->tag <= hightag)
            printf ("block:%p    size:%7i    user:%p    tag:%3i\n",
                    (void*)block,
                    block->size,
                    (void*)block->user,
                    block->tag);

        if (block->next == &mainzone->blocklist)
        {
            // all blocks have been hit
            break;
        }

        if ( (byte *)block + block->size != (byte *)block->next)
            printf ("ERROR: block size does not touch the next block\n");

        if ( block->next->prev != block)
            printf ("ERROR: next block doesn't have proper back link\n");

        if (!block->user && !block->next->user)
            printf ("ERROR: two consecutive free blocks\n");
    }
}

//
// Z_FileDumpHeap
//
void Z_FileDumpHeap (FILE* f)
{
    memblock_t* block;

    fprintf (
        f, "zone size: %i  location: %p\n", mainzone->size, (void*)mainzone);

    for (block = mainzone->blocklist.next ; ; block = block->next)
    {
        Z_CheckBlockIntegrity (block);

        fprintf (f,
                 "block:%p    size:%7i    user:%p    tag:%3i\n",
                 (void*)block,
                 block->size,
                 (void*)block->user,
                 block->tag);

        if (block->next == &mainzone->blocklist)
        {
            // all blocks have been hit
            break;
        }

        if ( (byte *)block + block->size != (byte *)block->next)
            fprintf (f,"ERROR: block size does not touch the next block\n");

        if ( block->next->prev != block)
            fprintf (f,"ERROR: next block doesn't have proper back link\n");

        if (!block->user && !block->next->user)
            fprintf (f,"ERROR: two consecutive free blocks\n");
    }
}

//
// Z_CheckHeap
//
void Z_CheckHeap (void)
{
    memblock_t* block;

    for (block = mainzone->blocklist.next ; ; block = block->next)
    {
        Z_CheckBlockIntegrity (block);

        if (block->next == &mainzone->blocklist)
        {
            // all blocks have been hit
            break;
        }

        if ( (byte *)block + block->size != (byte *)block->next)
            I_Error ("Z_CheckHeap: block size does not touch the next block\n");

        if ( block->next->prev != block)
            I_Error ("Z_CheckHeap: next block doesn't have proper back link\n");

        if (!block->user && !block->next->user)
            I_Error ("Z_CheckHeap: two consecutive free blocks\n");
    }
}

//
// Z_ChangeTag
//
void
Z_ChangeTag2
( void*         ptr,
  int           tag )
{
    memblock_t* block;

    block = (memblock_t *) ( (byte *)ptr - sizeof(memblock_t));
    Z_CheckBlockIntegrity (block);

    if (block->id != ZONEID)
        I_Error ("Z_ChangeTag: freed a pointer without ZONEID");

    if (tag >= PU_PURGELEVEL && (uintptr_t)block->user < 0x100)
        I_Error ("Z_ChangeTag: an owner is required for purgable blocks");

    block->tag = tag;
}

//
// Z_FreeMemory
//
int Z_FreeMemory (void)
{
    memblock_t*         block;
    int                 free;

    free = 0;

    for (block = mainzone->blocklist.next ;
         block != &mainzone->blocklist;
         block = block->next)
    {
        Z_CheckBlockIntegrity (block);

        if (!block->user || block->tag >= PU_PURGELEVEL)
            free += block->size;
    }
    return free;
}

