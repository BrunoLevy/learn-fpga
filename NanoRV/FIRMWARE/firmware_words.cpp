/**
 * Converts ascii hex firmware files with byte values 
 * into files with word values. 
 * It is required by NanoRV's RAM initialization, that
 * is organized by words, and initialized using verilog's 
 * $readmemh().
 */ 

#include <iostream>
#include <fstream>
#include <cctype>

int main() {
    std::string firmware;
    std::ifstream in("firmware.objcopy.hex");
    std::ofstream out("firmware.hex");
   
    if(!in) {
	std::cerr << "Could not open firmware.objcopy.hex" << std::endl;
	return 1;
    }
    
    std::string line;
    while(std::getline(in, line)) {
        if(line[0] == '@') {
//         not sure readmemh() understands this kind of directive
//	   out << line << std::endl;
	} else {
	   std::string bytes;
	   for(int i=0; i<line.length(); ++i) {
	      if(line[i] != ' ' && std::isprint(line[i])) {
		 bytes.push_back(line[i]);
	      }
	   }
	   while((bytes.size() % 8) != 0) {
	      bytes.push_back('0');
	   }
	   for(int i=0; i<bytes.size(); i+=8) {
	      out 
		<< bytes[i+6]
		<< bytes[i+7]
		<< bytes[i+4]
		<< bytes[i+5]
		<< bytes[i+2]
		<< bytes[i+3]
		<< bytes[i+0]
		<< bytes[i+1]
		<< ' ';
	   }
	   out << std::endl;
	}
    }
   return 0;
}
