//#define USE_FILELIB_STDIO_COMPAT_NAMES
#define FAT_INLINE inline
#include "fat_io_lib/fat_filelib.h"

/**
 * \brief Initializes filesystem access on SDCard.
 * \retval 0 if everything went well
 * \retval -1 otherwise
 */ 
int filesystem_init(void);


