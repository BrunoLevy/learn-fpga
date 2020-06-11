/**
 * Converts ascii hex firmware files with byte values 
 * into files with word values. 
 * It is required by femtosoc's RAM initialization, that
 * is organized by words, and initialized using verilog's 
 * $readmemh().
 */ 

#include <iostream>
#include <fstream>
#include <cctype>

const int RAM_SIZE = 4096;
unsigned char RAM[RAM_SIZE];
unsigned char OCC[RAM_SIZE];

unsigned char char_to_nibble(char c) {
    unsigned char result;
    if(c >= '0' && c <= '9') {
	result = c - '0';
    } else if(c >= 'A' && c <= 'F') {
	result = c - 'A' + 10;
    } else if(c >= 'a' && c <= 'f') {
	result = c - 'a' + 10;
    } else {
	std::cerr << "Invalid hexadecimal digit: " << c << std::endl;
	abort();
    }
    return result;
}

unsigned char string_to_byte(char* str) {
    return (char_to_nibble(str[0]) << 4) | char_to_nibble(str[1]);
}

char byte_to_nibble(unsigned char c) {
    return (c <= 9) ? (c + '0') : (c - 10 + 'a');
}

char* byte_to_string(unsigned char c) {
    static char result[3];
    result[0] = byte_to_nibble((c >> 4) & 15);
    result[1] = byte_to_nibble(c & 15);    
    result[2] = '\0';
    return result;
}

int main() {
    std::string firmware;
    std::ifstream in("firmware.objcopy.hex");
    std::ofstream out("firmware.hex");
    std::ofstream out_occ("firmware_occupancy.hex");
   
    if(!in) {
	std::cerr << "Could not open firmware.objcopy.hex" << std::endl;
	return 1;
    }

    for(unsigned int i=0; i<RAM_SIZE; ++i) {
	RAM[i] = 0;
        OCC[i] = 0;
    }

    int address = 0;
    int lineno = 0;
    int max_address = 0;
    std::string line;
    while(std::getline(in, line)) {
	++lineno;
        if(line[0] == '@') {
	    sscanf(line.c_str()+1,"%x",&address);
	} else {
	   std::string charbytes;
	   for(int i=0; i<line.length(); ++i) {
	      if(line[i] != ' ' && std::isprint(line[i])) {
		 charbytes.push_back(line[i]);
	      }
	   }

	   if(charbytes.size() % 2 != 0) {
	       std::cerr << "Line : " << lineno << std::endl;
	       std::cerr << " invalid number of characters"
			 << std::endl;
	       abort();
	   }

	   int i = 0;
	   while(i < charbytes.size()) {
	       if(address >= RAM_SIZE) {
		   std::cerr << "Line : " << lineno << std::endl;
		   std::cerr << " RAM size exceeded"
			     << std::endl;
		   abort();
	       }
	       if(OCC[address] != 0) {
		   std::cerr << "Line : " << lineno << std::endl;
		   std::cerr << " same RAM address written twice"
			     << std::endl;
		   abort();
	       }
	       max_address = std::max(max_address, address);
	       RAM[address] = string_to_byte(&charbytes[i]);
	       OCC[address] = 255;
	       i += 2;
	       address++;
	   }
	}
    }
    for(int i=0; i<RAM_SIZE; i+=4) {
	out << byte_to_string(RAM[i+3])
	    << byte_to_string(RAM[i+2])
	    << byte_to_string(RAM[i+1])
	    << byte_to_string(RAM[i])
	    << " ";
	if(((i/4+1) % 4) == 0) {
	    out << std::endl;
	}
    }

    for(int i=0; i<RAM_SIZE; i+=4) {
	out_occ << byte_to_string(OCC[i+3])
	        << byte_to_string(OCC[i+2])
	        << byte_to_string(OCC[i+1])
	        << byte_to_string(OCC[i])
	        << " ";
	if(((i/4+1) % 16) == 0) {
	    out_occ << std::endl;
	}
    }

    std::cout << "Code size: " << max_address/4 << " words" << std::endl;
    return 0;
}
