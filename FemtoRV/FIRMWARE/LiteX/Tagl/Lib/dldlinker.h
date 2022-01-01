/*
 * This software is copyrighted as noted below.  It may be freely copied,
 * modified, and redistributed, provided that the copyright notice is
 * preserved on all copies.
 *
 * There is no warranty or other guarantee of fitness for this software,
 * it is provided solely "as is".  Bug reports or fixes may be sent
 * to the author, who may or may not act on them as he desires.
 *
 * You may not include this software in a program or other software product
 * without supplying the source, or without informing the end-user that the
 * source is available for no extra charge.
 *
 * If you modify this software, you should include a notice giving the
 * name of the person performing the modification, the date of modification,
 * and the reason for such modification.
 *
 * Author:      Bruno Levy
 *
 * Copyright (c) 1996, Bruno Levy.
 *
 */
/*
 *
 * dldlinker.h
 *
 */

#ifndef DLD_LINKER_H
#define DLD_LINKER_H

#include "gcomp.h"

const Flag GLR_LIBPATH  = 1;
const Flag GLR_DRIVERS  = 2;
const Flag GLR_DLD      = 3;

#define DEFAULT_GLIB "/usr/local/lib/tagl"

extern "C" {
#include "dld.h"
}

class DLDLinker : public GraphicComponent
{
 public:
  DLDLinker(int verbose_level = MSG_ENV);
  ~DLDLinker(void);

 protected:
  int Link(char* module);
  int Call(char* name);
  int Init(void);
  
  Flags _resources;
  char* _library;
  char* _drivers;
};

#endif
