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
 * cmdline.h
 * 
 */

#ifndef CMDLINE_H
#define CMDLINE_H


const int CMD_LINE_INT  = 1;
const int CMD_LINE_FLT  = 2;
const int CMD_LINE_STR  = 3;
const int CMD_LINE_FLG  = 4;

typedef struct
{
   const char*  flag;   
   int    type;
   int    compulsory;
   void*  value;
   int    set; 
} CmdLineArg;


int   CmdLineParse(int argc, char** argv, CmdLineArg* args);
void  CmdLineUsage(char* cmdname, CmdLineArg* args);
void  CmdLineShowDefaults(char* cmdname, CmdLineArg* args);

#endif
