#include <stdio.h>
// #include <iostream>
// /home/blevy/Programming/LiteX/litex/litex/soc/software/include/basec++ is missing...

extern "C" void hellocpp(void);
void hellocpp(void)
{
     printf("C++: Hello, world!\n"); 
//   std::cout << "C++: Hello, world" << std::endl;
}