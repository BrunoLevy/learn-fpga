#include "../femtostdlib.h"

size_t strlen(const char *str) {
   for (size_t len = 0;;++len) if (str[len]==0) return len;
}


