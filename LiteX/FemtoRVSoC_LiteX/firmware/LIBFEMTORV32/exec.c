#include <femtorv32.h>
#include <femto_elf.h>

static int exec_elf(const char* filename, int argc, char** argv);

/************************************************************************/

int exec(const char* filename, int argc, char** argv) {
  int l = strlen(filename);
  if(l > 4 && !strcmp(filename + l - 4, ".elf")) {
    return exec_elf(filename, argc, argv);
  }
  return 0;
}

/************************************************************************/

typedef void (*funptr)(int argc, char** argv);

int exec_elf(const char* filename, int argc, char** argv) {
  Elf32Info info;
  int errcode;
   
  errcode = elf32_load(filename, &info);

  if(errcode != ELF32_OK) {
    return errcode;
  }

  LEDS(0);
  
  // Now we can transfer execution to beginning of text segment.
  // It where main() resides, so we can pass it argc and argv.
  ((funptr)(info.text_address))(argc, argv);

  // Note: there is also elf_header.e_entry = 0x101cc,
  //             whereas text segment start = 0x10074
  // Calling elf_header.e_entry does not work. 
  // It is probably where crt0.S is implanted. It would be better
  // to call it (but it did not work when I tried). There are
  // complicated things to setup for argc/argv/envp to work.
  
  return 0;
}

