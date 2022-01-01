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
 * dldlinker.cc
 *
 */

#include "dldlinker.h"

DLDLinker::~DLDLinker(void)
{
  if(_resources.Get(GLR_DRIVERS))
    free(_drivers);
  if(_resources.Get(GLR_LIBPATH))
    free(_library);
}


DLDLinker::DLDLinker(int verbose_level) 
{
  char *current;
  _proc_name = "DLDLinker";
  
  Verbose(verbose_level);

  if(!(_library = getenv("GLIBRARY")))
    {
      (*this)[MSG_WARNING] << "GLIBRARY not set\n";
      (*this)[MSG_WARNING] << "using default " << DEFAULT_GLIB << "\n";
      _library = strdup(DEFAULT_GLIB);
    }
  else
    {
      _library = strdup(_library);
      (*this)[MSG_INFO] << "library path: " << _library << "\n";
    }

  _resources.Set(GLR_LIBPATH);

  if(_drivers = getenv("GDRIVERS"))
    {
      _resources.Set(GLR_DRIVERS);
      _drivers = strdup(_drivers);
      (*this)[MSG_INFO] << "using drivers: " << _drivers << "\n";
    }
  else
    {
      (*this)[MSG_WARNING] << "GDRIVERS not set\n";
      (*this)[MSG_WARNING] << "Nothing will be linked !!!\n";
      return;
    }

  if(!Init())
    return;

  (*this)[MSG_INFO] << "Dynamic linker initialized\n";
  
  for(current = strtok(_drivers,":"); current; current = strtok(NULL,":"))
    {
      char full_name[300];
      char init_func[300];
      sprintf(full_name, "%s/%s.o",_library,current);
      sprintf(init_func, "init_%s",current);
      if(Link(full_name))
	Call(init_func);
    }
}

int
DLDLinker::Init(void)
{
  char *argv0;

  if((argv0 = getenv("_")))
    (*this)[MSG_INFO] << "getting argv[0] from bash environment\n";
  else
    argv0 = _argv[0];

  if(!argv0)
    {
      (*this)[MSG_ERROR] << "Could not get executable name \n";
      (*this)[MSG_ERROR] << "Use bash or GraphicComponent::SetCommandLine()\n";
      (*this)[MSG_ERROR] << "Or set \'_\' to the executable path\n";
      (*this)[MSG_ERROR] << " ... Dynamic linking won\'t be performed\n";
      return 0;
    }
  else
    (*this)[MSG_INFO] << "argv[0] = " << argv0 << "\n";

/*
  if(dld_init(dld_find_executable(argv0)) && (_verbose_level >= MSG_ERROR))
    {
      dld_perror("[TAGL_DL] GLinker:");
      return 0;
    }
*/
  printf(""); // Don't ask !!!

  _resources.Set(GLR_DLD);
  return 1;
}

int 
DLDLinker::Link(char* module)
{
/*
  if(dld_link(module))
    {
      if(_verbose_level >= MSG_ERROR)
	dld_perror("[TAGL_DL] GLinker:");
      return 0;
    }

  char **syms = dld_list_undefined_sym();
  int i;
  if(_verbose_level >= MSG_ERROR)
    for(i=0; i<dld_undefined_sym_count; i++)
      fprintf(stderr, "[TAGL_DL] GLinker:: undefined symbol %d>> %s\n",i,syms[i]);

  if(dld_undefined_sym_count)
    return 0;

  (*this)[MSG_INFO] << module << " sucessfully linked\n";
*/
  return 1;
}

int 
DLDLinker::Call(char* name)
{
  (*this)[MSG_INFO] << "Calling " << name << "()\n";

  void (*entry)()  = 0 ; //  (void (*)())dld_get_func(name);
  if(!entry)
    {
      if(_verbose_level >= MSG_ERROR)
//	dld_perror("[TAGL_DL] GLinker:");
      return 0;
    }

  (*entry)();
  
  (*this)[MSG_INFO] << name << "()" << " called\n";
  
  return 1;
}
