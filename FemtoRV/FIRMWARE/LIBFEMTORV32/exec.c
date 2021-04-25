#include <femtorv32.h>
#include <femto_elf.h>

static int exec_bin(const char* filename);
static int exec_elf(const char* filename);

/************************************************************************/

int exec(const char* filename) {
  int l = strlen(filename);
  if(l > 4 && !strcmp(filename + l - 4, ".elf")) {
    return exec_elf(filename);
  }
  return 0;
}

/**********************************************************************************/

typedef void (*funptr)();

int exec_elf(const char* filename) {
  Elf32Info info;
  int errcode = filesystem_init();
   
  if(errcode) {
    return errcode;
  }

  // Clear memory (normally it should not be necessary, but if I don't do that,
  // sometimes it gets stuck). Maybe it is because I do not setup the stack
  // properly (we need to push argc, argv, envp etc...), but maybe it is something
  // else because the stack is not there...
  if(0) {
    void* start = (void*)0x10000;
    int memsize = IO_IN(IO_HW_CONFIG_RAM);
    memset(start, 0, memsize - 0x10000 - 1024); // -1024 to avoid touching the stack
  }

  errcode = elf32_load(filename, &info);

  if(errcode != ELF32_OK) {
    switch(errcode) {
    case ELF32_FILE_NOT_FOUND:
      printf("File not found\n");
      break;
    case ELF32_HEADER_SIZE_MISMATCH:
      printf("ELF header size mismatch\n");
      break;
    case ELF32_READ_ERROR:
      printf("Read error\n");
      break;
    default:
      printf("Unknown error\n");
      break;
    }
    return errcode;
  }

  LEDS(0);
  
  // Now we can transfer execution to beginning of text segment.
  ((funptr)(info.text_address))();

  // Note: there is also elf_header.e_entry = 0x101cc,
  //             whereas text segment start = 0x10074
  // Calling elf_header.e_entry does not work. I don't understand what it is....

  return 0;
}

