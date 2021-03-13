// http://www.pixelbeat.org/programming/gcc/supc++/
// This one works on the IceStick (but IceStick does
// not support much more !! 6kB is really too small to
// do C++ it seems...)

#include <vector>
#include <algorithm>

extern "C" {
#include <femtorv32.h>
void femtosoc_tty_init();
}

int main() {
   femtosoc_tty_init();
   std::vector<int> V;
   V.push_back(8);
   V.push_back(11);
   V.push_back(3);
   V.push_back(100);
   V.push_back(53);
   V.push_back(5);
   std::sort(V.begin(), V.end());
   for(int i=0; i<V.size(); ++i) {
      printf("%d\n",V[i]);
   }
   return 0;
}
