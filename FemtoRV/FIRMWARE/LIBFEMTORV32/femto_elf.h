/*
 * A minimalistic ELF loader. Probably many things are missing.
 * Disclaimer: I do not understand everything here !
 * Bruno Levy, 12/2020
 */

#ifdef STANDALONE_FEMTOELF
#include <stdint.h>
#else
#include <femtorv32.h>
#endif

typedef uint32_t elf32_addr; 

typedef struct {
  void*      base_address; /* Base memory address (NULL on normal operation). */
  elf32_addr text_address; /* The address of the text segment.                */
  elf32_addr max_address;  /* The maximum address of a segment.               */
} Elf32Info;

#define ELF32_OK                   0
#define ELF32_FILE_NOT_FOUND       1
#define ELF32_HEADER_SIZE_MISMATCH 2
#define ELF32_READ_ERROR           3

/**
 * \brief Loads an ELF executable to RAM.
 * \param[in] filename the name of the file that contains the ELF executable.
 * \param[out] info a pointer to an Elf32Info. On exit, base_adress is NULL,
 *  text_address contains the starting address of the text segment, and
 *  max_address the maximum address used by the segments.
 * \return ELF32_OK or an error code.
 */
int elf32_load(const char* filename, Elf32Info* info);

/**
 * \brief Loads an ELF executable to RAM at a specified address.
 * \details Used by programs that convert ELF executables to other formats.
 * \param[in] filename the name of the file that contains the ELF executable.
 * \param[out] info a pointer to an Elf32Info. On exit, base_adress is NULL,
 *  text_address contains the starting address of the text segment, and
 *  max_address the maximum address used by the segments.
 * \param[in] addr the address where to load the ELF segments.
 * \return ELF32_OK or an error code.
 */
int elf32_load_at(const char* filename, Elf32Info* info, void* addr);

/**
 * \brief Analyzes an ELF executable.
 * \param[in] filename the name of the file that contains the ELF executable.
 * \param[out] info a pointer to an Elf32Info. On exit, base_adress is NULL,
 *  text_address contains the starting address of the text segment, and
 *  max_address the maximum address used by the segments.
 * \return ELF32_OK or an error code.
 */
int elf32_stat(const char* filename, Elf32Info* info);

