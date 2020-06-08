const char* hello = "hello, world\n";

int charsum() {
   int result = 0;
   const char* p = hello;
   while(*p) {
      result += *p;
      ++p;
   }
   return result;
}




