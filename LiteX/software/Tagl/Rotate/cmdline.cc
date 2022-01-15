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
 * cmdline.cc
 * 
 */

#include "cmdline.h"
#include <stdio.h>
#include <string.h>
// #include <iostream>
using namespace std;

void CmdLineUsage(char* cmdname, CmdLineArg* args)
{
   int arg = 0;
   
   printf("Usage: %s ",cmdname);
   
   while(args[arg].type)
     {
	if(!args[arg].compulsory)
	  printf("[ ");
	
	printf("%s ",args[arg].flag);

	switch(args[arg].type)
	  {
	   case CMD_LINE_INT:
	     printf("<integer>");
	     break;
	   case CMD_LINE_FLT:
	     printf("<float>");
	     break;
	   case CMD_LINE_STR:
	     printf("<name>");
	     break;
	  }
	
	if(!args[arg].compulsory)
	  printf(" ]");
	
	printf(" ");
	
	arg++;
     }
   
   printf("\n");
   CmdLineShowDefaults(cmdname, args);
}

void  CmdLineShowDefaults(char* cmdname, CmdLineArg* args)
{
   int arg = 0;
   
   printf("Current values: %s",cmdname);
   
   while(args[arg].type)
     {
	if(args[arg].set)
	  {
	     printf("%s ",args[arg].flag);
	     switch(args[arg].type)
	       {
		case CMD_LINE_INT:
		  printf("%d",*(int *)args[arg].value);
		  break;
		case CMD_LINE_FLT:
		  printf("%f",*(float *)args[arg].value);
		  break;
		case CMD_LINE_STR:
		  printf("\"%s\"",*(char **)args[arg].value);
		  break;
	       }
	  }
	
	printf(" ");
	
	arg++;
     }
   
   printf("\n");
}

static CmdLineArg* Find(CmdLineArg* args, char* flag)
{
   int arg;
   for(arg=0; args[arg].type; arg++)
      if(!strcmp(args[arg].flag, flag))
         return &args[arg];
   
   return NULL;
}

int CmdLineParse(int argc, char** argv, CmdLineArg* args)
{
   int arg = 1;
   
   while(arg < argc)
     {
	CmdLineArg* current; 
	if(!(current = Find(args, argv[arg])))
	  {
	     printf("%s: Does not understand %s", argv[0],argv[arg]);
	     return 0;
	  }

	if(current->type == CMD_LINE_FLG)
	  *(int*)(current->value) = 1;
	
	else
	  {
	     arg++;
	     if(arg >= argc)
	       {
		  printf("%s: Missing value for %s",argv[0],argv[arg-1]);
		  return 0;
	       }
	     
	     switch(current->type)
	       {
		  float val_f;
		  int   val_i;
		  
		case CMD_LINE_INT:
		  if(!sscanf(argv[arg],"%d",&val_i))
		    {
		       printf("%s: Invalid integer value: \':%s\'",argv[0],argv[arg]);
		       return 0;
		    }
		  *(int*)(current->value) = val_i;
		  break;
		case CMD_LINE_FLT:
		  if(!sscanf(argv[arg],"%f",&val_f))
		    {
		       printf("%s: Invalid float value: \':%s\'",argv[0],argv[arg]);
		       return 0;
		    }
		  *(float*)(current->value) = val_f;	     
		  break;
		case CMD_LINE_STR:
		  *(char**)(current->value) = argv[arg];
		  break;
	       }
	  }
	
	current->set = 1;
	arg++;
     }
   
   for(arg=0; args[arg].type; arg++)
      if(args[arg].compulsory && !args[arg].set)
         {
	    printf("%s: Missing value for %s",argv[0],args[arg].flag);
	    return 0;
	 }
   
   return 1;
}
