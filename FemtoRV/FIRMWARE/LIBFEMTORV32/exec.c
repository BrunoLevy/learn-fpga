#include <femtorv32.h>

static int exec_bin(const char* filename);
static int exec_elf(const char* filename);

/************************************************************************/

int exec(const char* filename) {
  int l = strlen(filename);
  if(l > 4 && !strcmp(filename + l - 4, ".bin")) {
    return exec_bin(filename);
  }
  if(l > 4 && !strcmp(filename + l - 4, ".elf")) {
    return exec_elf(filename);
  }
  return 0;
}

/************************************************************************/

/* 
 * Loads and starts a flat binary file. 
 * Data is to be implanted at address 0x10000.
 * crt is starting from address 0x10074 (readelf -a shows that).
 */
int exec_bin(const char* filename) {
    if(sd_init()) {
	printf("Could not initialize SDCard\n");
	return -1;
    }
    fl_init();
    if(fl_attach_media(
	   (fn_diskio_read)sd_readsector,
	   (fn_diskio_write)sd_writesector) != FAT_INIT_OK
    ) {
	printf("ERROR: Failed to init file system\n");
	return -1;
    }

    FILE* f = fopen(filename,"r");
    if(!f) {
	printf("Could not open %s\n", filename);
	return -1;
    }
    fseek(f, 0, SEEK_END);
    int file_size = ftell(f);
    printf("File size = %d\n", file_size);
    fseek(f, 0, SEEK_SET);

    void* start = (void*)0x10000;
    int memsize = IO_IN(IO_RAM);
    memset(start, 0, memsize - 0x10000 - 1024); // -1024 to avoid touching the stack
    
    if(fread(start, 1, file_size, f) != file_size) {
      	printf("Error while reading file\n");
    } else {
	printf("File ready in RAM\n");
    }

    asm("j 0x10074"); // TODO: understand why it starts 74 bites away from 0x10000
                      // NOTE: programs that simply return from main() are looping,
                      // I do not know why (to be fixed)
    return 0;
}

/**********************************************************************************/

/* Borrowed from /usr/include/elf.h of a Linux system */

/* Type for a 16-bit quantity.  */
typedef uint16_t Elf32_Half;

/* Types for signed and unsigned 32-bit quantities.  */
typedef uint32_t Elf32_Word;
typedef	int32_t  Elf32_Sword;

/* Types for signed and unsigned 64-bit quantities.  */
typedef uint64_t Elf32_Xword;
typedef	int64_t  Elf32_Sxword;

/* Type of addresses.  */
typedef uint32_t Elf32_Addr;

/* Type of file offsets.  */
typedef uint32_t Elf32_Off;

/* Type for section indices, which are 16-bit quantities.  */
typedef uint16_t Elf32_Section;

/* Type for version symbol information.  */
typedef Elf32_Half Elf32_Versym;

#define EI_NIDENT (16)
typedef struct
{
  unsigned char	e_ident[EI_NIDENT];	/* Magic number and other info */
  Elf32_Half	e_type;			/* Object file type */
  Elf32_Half	e_machine;		/* Architecture */
  Elf32_Word	e_version;		/* Object file version */
  Elf32_Addr	e_entry;		/* Entry point virtual address */
  Elf32_Off	e_phoff;		/* Program header table file offset */
  Elf32_Off	e_shoff;		/* Section header table file offset */
  Elf32_Word	e_flags;		/* Processor-specific flags */
  Elf32_Half	e_ehsize;		/* ELF header size in bytes */
  Elf32_Half	e_phentsize;		/* Program header table entry size */
  Elf32_Half	e_phnum;		/* Program header table entry count */
  Elf32_Half	e_shentsize;		/* Section header table entry size */
  Elf32_Half	e_shnum;		/* Section header table entry count */
  Elf32_Half	e_shstrndx;		/* Section header string table index */
} Elf32_Ehdr;


typedef struct
{
  Elf32_Word	sh_name;		/* Section name (string tbl index) */
  Elf32_Word	sh_type;		/* Section type */
  Elf32_Word	sh_flags;		/* Section flags */
  Elf32_Addr	sh_addr;		/* Section virtual addr at execution */
  Elf32_Off	sh_offset;		/* Section file offset */
  Elf32_Word	sh_size;		/* Section size in bytes */
  Elf32_Word	sh_link;		/* Link to another section */
  Elf32_Word	sh_info;		/* Additional section information */
  Elf32_Word	sh_addralign;		/* Section alignment */
  Elf32_Word	sh_entsize;		/* Entry size if section holds table */
} Elf32_Shdr;

/* Section header type */
#define SHT_NULL	  0		/* Section header table entry unused */
#define SHT_PROGBITS	  1		/* Program data */
#define SHT_NOBITS	  8		/* Program space with no data (bss) */
#define SHT_INIT_ARRAY	  14		/* Array of constructors */
#define SHT_FINI_ARRAY	  15		/* Array of destructors */

/* Section header flags */
#define SHF_ALLOC	     (1 << 1)	/* Occupies memory during execution */

typedef void (*funptr)();

/* 
 * Loads and starts an ELF file.
 */
int exec_elf(const char* filename) {
  LEDS(1);
  if(sd_init()) {
    printf("Could not initialize SDCard\n");
    return -1;
  }
  fl_init();
  LEDS(2);  
  if(fl_attach_media(
      (fn_diskio_read)sd_readsector,
      (fn_diskio_write)sd_writesector) != FAT_INIT_OK
  ) {
    printf("ERROR: Failed to init file system\n");
    return -1;
  }
  LEDS(4);  

  Elf32_Ehdr elf_header;
  Elf32_Shdr sec_header;
  FILE* f = fopen(filename,"r");
  
  if(f == NULL) {
    printf("ELF: Could not open %s\n",filename);
    return -1;
  }
  
  if(fread(&elf_header, 1, sizeof(elf_header), f) != sizeof(elf_header)) {
    printf("ELF: Could not read header\n",filename);
    return -1;
  }

  if(elf_header.e_ehsize != sizeof(elf_header)) {
    printf("ELF: invalid header size\n",filename);    
    return -1;
  }

  if(elf_header.e_shentsize != sizeof(Elf32_Shdr)) {
    printf("ELF: invalid section header size\n",filename);    
    return -1;
  }

  LEDS(8);
  
  Elf32_Addr text_address = 0;
  
  for(int i=0; i<elf_header.e_shnum; ++i) {
    fseek(f,elf_header.e_shoff + i*sizeof(sec_header), SEEK_SET);
    if(fread(&sec_header, 1, sizeof(sec_header), f) != sizeof(sec_header)) {
      printf("ELF: Could not read section header\n",filename);
      return -1;
    }
    LEDS(i);
    if(sec_header.sh_flags & SHF_ALLOC) {
      switch(sec_header.sh_type) {
      case SHT_PROGBITS: {
	if(text_address == 0) {
	  text_address = sec_header.sh_addr;
	}
      }
      case SHT_INIT_ARRAY:
      case SHT_FINI_ARRAY: {
	fseek(f,sec_header.sh_offset, SEEK_SET);
	if(fread((void*)sec_header.sh_addr, 1, sec_header.sh_size, f) != sec_header.sh_size) {
	  printf("ELF: Could not read section data\n",filename);
	  return -1;
	}
      } break;
      case SHT_NOBITS: {
	memset((void*)sec_header.sh_addr, 0, sec_header.sh_size);
      } break;
      default: {
      } break;
      };
    }
  }  
  fclose(f);

  LEDS(0);
  
  // Now we can transfer execution to beginning of text segment.
  ((funptr)(text_address))();

  // Note: there is also elf_header.e_entry = 0x101cc,
  //             whereas text segment start = 0x10074
  // Calling elf_header.e_entry does not work. I don't understand what it is....
  
  return 0;
}
