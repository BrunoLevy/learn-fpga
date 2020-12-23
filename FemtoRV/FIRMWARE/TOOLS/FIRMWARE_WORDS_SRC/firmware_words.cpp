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
#include <map>
#include <string>
#include <vector>
#include <cstring>
#include <cstdint>

#include <femto_elf.h>


/*********************************************************************/

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
	exit(-1);
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

void split_string(
    const std::string& in,
    char separator,
    std::vector<std::string>& out,
    bool skip_empty_fields = true
) {
    size_t length = in.length();
    size_t start = 0;
    while(start < length) {
	size_t end = in.find(separator, start);
	if(end == std::string::npos) {
	    end = length;
	}
	if(!skip_empty_fields || (end - start > 0)) {
	    out.push_back(in.substr(start, end - start));
	}
	start = end + 1;
    }
}

/**************************************************************/

/*
 * \brief Parses femtosoc.v and extracts configured devices,
 *        frequency, RAM size.
 * \return RAM size.
 */
int get_RAM_size_from_verilog(const char* filename) {
    int result = 0;
    std::ifstream in(filename);
    if(!in) {
	std::cerr << "Could not open " << filename << std::endl;
	return 0;
    }
    std::string line;
    while(std::getline(in, line)) {
	std::vector<std::string> words;
	split_string(line, ' ', words);
	if(
	   words.size() >= 3 &&
	   words[0] == "`define" &&
	   words[1] == "NRV_RAM"
	) {
	  sscanf(words[2].c_str(), "%d", &result);
	}
    }
    return result;
}

/**************************************************************************/

/* returns the highest set address or -1 if there was an error. */
int load_RAM_rawhex(const char* filename, std::vector<unsigned char>& RAM) {
  std::cerr << "   LOAD RAWHEX: " << filename << std::endl;
  
  int RAM_SIZE = RAM.size();

  /* Occupancy array, to make sure we do not set the same byte twice. */
  std::vector<unsigned char> OCC(RAM_SIZE,0);

  int address = 0;
  int lineno = 0;
  int max_address = 0;
  std::ifstream in(filename);
  if(!in) {
    std::cerr << "Could not open " << filename << std::endl;
    return -1;
  }
  
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
	return -1;
      }

      int i = 0;
      while(i < charbytes.size()) {
	if(address >= RAM_SIZE) {
	  std::cerr << "Line : " << lineno << std::endl;
	  std::cerr << " RAM size exceeded"
		    << std::endl;
	  return -1;
	}
	if(OCC[address] != 0) {
	  std::cerr << "Line : " << lineno << std::endl;
	  std::cerr << " same RAM address written twice"
		    << std::endl;
	  return -1;
	}
	max_address = std::max(max_address, address);
	RAM[address] = string_to_byte(&charbytes[i]);
	OCC[address] = 255;
	i += 2;
	address++;
      }
    }
  }
  return max_address;
}

/* returns the highest set address or -1 if there was an error. */
int load_RAM_elf(const char* filename, std::vector<unsigned char>& RAM) {
  std::cerr << "   LOAD ELF: " << filename << std::endl;
  int RAM_SIZE = RAM.size();
  Elf32Info info;
  if(elf32_stat(filename, &info) != ELF32_OK) {
    std::cerr << "Error while reading ELF file " << filename << std::endl;
    return -1;
  }
   std::cerr << "       max address=" << info.max_address << std::endl; 
  if(info.max_address >= RAM_SIZE) {
    std::cerr << "Memory exceeded !" << std::endl;
    return -1;
  }
  if(elf32_load_at(filename, &info, RAM.data()) != ELF32_OK) {
    std::cerr << "Error while reading ELF file " << filename << std::endl;
    return -1;
  }
  return info.max_address;
}

/* returns the highest set address or -1 if there was an error. */
int load_RAM(const char* filename, std::vector<unsigned char>& RAM) {
  int l = strlen(filename);
  if(l >= 3 && !strcmp(filename+l-3,"hex")) {
    return load_RAM_rawhex(filename, RAM);
  } 
  if(l >= 3 && !strcmp(filename+l-3,"elf")) {
    return load_RAM_elf(filename, RAM);
  }
  std::cerr << filename << ": invalid extension" << std::endl;
  return -1;
}

void save_RAM_hex(const char* filename, std::vector<unsigned char>& RAM) {
  int RAM_SIZE = RAM.size();
  std::cerr << "   SAVE HEX: " << filename << std::endl;    
  std::ofstream out(filename);
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
}

void save_RAM_bin(const char* filename, std::vector<unsigned char>& RAM, int start_addr, int max_addr) {
  std::cerr << "   SAVE BIN: " << filename << std::endl;
  printf("        start addr:0x%lx\n",(unsigned long)start_addr);
  FILE* f = fopen(filename,"wb");
  fwrite(RAM.data()+start_addr, 1, max_addr+1-start_addr,f);
  fclose(f);
}

/****************************************************************/

int main(int argc, char** argv) {

  bool cmdline_error = false;

  std::string in_filename;
  std::string in_verilog_filename;
  std::string out_hex_filename;
  std::string out_occ_filename;
  std::string out_bin_filename;
  int bin_start_addr = 0;
  int RAM_SIZE = 0;
  
  if(argc < 2) {
    cmdline_error = true;
  } else {
    in_filename = argv[1];
  }
  
  for(int i=2; i<argc; i+=2) {
    if(i+1 >= argc) {
      cmdline_error = true;
      break;
    }
    if(!strcmp(argv[i],"-verilog")) {
      in_verilog_filename = argv[i+1]; 
    } else if(!strcmp(argv[i],"-hex")) {
      out_hex_filename = argv[i+1];       
    } else if(!strcmp(argv[i],"-occ")) {
      out_occ_filename = argv[i+1];             
    } else if(!strcmp(argv[i],"-bin")) {
      out_bin_filename = argv[i+1];
    } else if(!strcmp(argv[i],"-bin_start_addr")) {
      sscanf(argv[i+1],"%x",&bin_start_addr);
    } else if (!strcmp(argv[i],"-ram")) {
      sscanf(argv[i+1],"%d",&RAM_SIZE);
    } else {
      cmdline_error = true;
      break;
    }
  }

  if(cmdline_error) {
    std::cerr << "usage: " << argv[0]
	      << " input.rawhex <-verilog femtosoc.v> <-hex out.hex> <-occ out.occ> <-exe out.exe>"
	      << std::endl;
    return 1;
  }
  
  if(in_verilog_filename != "") {
    std::cerr << "   CONFIG: parsing " << in_verilog_filename << std::endl;
    RAM_SIZE = get_RAM_size_from_verilog(in_verilog_filename.c_str());
    if(RAM_SIZE == 0) {
      std::cerr << "Did not find RAM size in femtosoc.v"
		<< std::endl;
      return 1;
    }
  }

  if(RAM_SIZE == 0) {
    std::cerr << "RAM size not specified"
	      << std::endl;
    return 1;
  }

  std::cerr << "   RAM SIZE=" << RAM_SIZE << std::endl;
  
  std::vector<unsigned char> RAM(RAM_SIZE,0);

  int max_addr = load_RAM(in_filename.c_str(), RAM);
  if(max_addr == -1) {
    return 1;
  }
  
  if(out_hex_filename != "") {
    save_RAM_hex(out_hex_filename.c_str(), RAM);
  }

  if(out_bin_filename != "") {
    save_RAM_bin(out_bin_filename.c_str(), RAM, bin_start_addr, max_addr);
  }
    
  std::cout << "Code size: "
	    << (max_addr-bin_start_addr)/4 << " words"
	    << " ( total RAM size: "
	    << (RAM_SIZE/4)
	    << " words )"
	    << std::endl;
  std::cout << "Occupancy: " << ((max_addr-bin_start_addr)*100) / RAM_SIZE
	    << "%" << std::endl;
  return 0;
}
