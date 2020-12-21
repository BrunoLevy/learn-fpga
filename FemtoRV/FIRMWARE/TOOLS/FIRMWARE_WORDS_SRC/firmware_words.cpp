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

int RAM_SIZE = 0;
std::vector<unsigned char> RAM;
std::vector<unsigned char> OCC;

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

struct Sym {
    std::string name;
    int value;
    int address;
    int bit;      // or -1 if full word
};
typedef std::vector<Sym> SymTable;

/*
 * \brief Parses femtosoc.v and extracts configured devices,
 *        frequency, RAM size.
 * \return RAM size.
 */
int parse_verilog(const char* filename, SymTable& table) {
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
	std::string symname;
	std::string symvalue;
	std::string symaddress;
	if(words.size() >= 5 && words[0] == "`define") {
	    if(words[2] == "//" && words[3] == "CONFIGWORD") {
		symname = words[1];
		symvalue = "1";
		symaddress = words[4];
	    } else if(
		words.size() >= 6 && words[3] == "//" &&
		words[4] == "CONFIGWORD") {
		symname = words[1];
		symvalue = words[2];
		symaddress = words[5];
	    } else if(
		words.size() >= 3 &&
		words[0] == "`define" &&
		words[1] == "NRV_RAM"
	    ) {
	        symname = words[1];
	        symvalue = words[2];
		symaddress = "0x0000";
	    }
	    if(symname != "" && symvalue != "" && symaddress != "") {
		int value;
		int addr;
		int bit = -1;

		sscanf(symvalue.c_str(), "%d", &value);
		
		sscanf(symaddress.c_str()+2, "%x", &addr);
		const char* strbit = strchr(symaddress.c_str(), '[');
		if(strbit != nullptr) {
		    sscanf(strbit+1, "%d", &bit);
		}
		
		if(bit != -1) {
		    fprintf(stderr, "   CONFIG  %22s=%5d  @0x%lx[%d]\n",
			    symname.c_str(), value, (unsigned long int)addr, bit
		    );
		} else {
		    fprintf(stderr, "   CONFIG  %22s=%5d  @0x%lx\n",
			    symname.c_str(), value, (unsigned long int)addr
		    );		    
		}

		Sym sym;
		sym.name = symname;
		sym.value = value;
		sym.address = addr;
		sym.bit = bit;
		if(sym.name == "NRV_RAM") {
		    result = sym.value;
		}
		if(sym.address != 0) {
		  table.push_back(sym);
		}
	    }
	}
    }
    return result;
}

int main(int argc, char** argv) {

  bool cmdline_error = false;

  std::string in_rawhex_filename;
  std::string in_verilog_filename;
  std::string out_hex_filename;
  std::string out_occ_filename;
  std::string out_bin_filename;
  int bin_start_addr = 0;
  
  if(argc < 2) {
    cmdline_error = true;
  } else {
    in_rawhex_filename = argv[1];
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
  
  std::string firmware;
  std::ifstream in(in_rawhex_filename);
   
  if(!in) {
    std::cerr << "Could not open " << in_rawhex_filename << std::endl;
    return 1;
  }

   
  SymTable defines;
  if(in_verilog_filename != "") {
    std::cerr << "   CONFIG: parsing " << in_verilog_filename << std::endl;
    RAM_SIZE = parse_verilog(in_verilog_filename.c_str(), defines);
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
  
  RAM.assign(RAM_SIZE,0);
  OCC.assign(RAM_SIZE,0);

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
	exit(-1);
      }

      int i = 0;
      while(i < charbytes.size()) {
	if(address >= RAM_SIZE) {
	  std::cerr << "Line : " << lineno << std::endl;
	  std::cerr << " RAM size exceeded"
		    << std::endl;
	  exit(-1);
	}
	if(OCC[address] != 0) {
	  std::cerr << "Line : " << lineno << std::endl;
	  std::cerr << " same RAM address written twice"
		    << std::endl;
	  exit(-1);
	}
	max_address = std::max(max_address, address);
	RAM[address] = string_to_byte(&charbytes[i]);
	OCC[address] = 255;
	i += 2;
	address++;
      }
    }
  }
   
  for(int i=0; i<defines.size(); ++i) {
    int addr  = defines[i].address;
    int value = defines[i].value;
    int bit   = defines[i].bit;
    if(addr + 4 >= RAM_SIZE) {
      std::cerr << defines[i].name << ": "
		<< defines[i].address
		<< " larger than RAM_SIZE(" << RAM_SIZE << ")"
		<< std::endl;
      exit(-1);
    }
    uint32_t* target = (uint32_t*)(&RAM[addr]);
    if(bit == -1) {
      *target = value;
    } else {
      *target |= (1 << bit);
    }
  }

  if(out_hex_filename != "") {
    std::cerr << "   SAVE HEX: " << out_hex_filename << std::endl;    
    std::ofstream out(out_hex_filename.c_str());
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

  if(out_occ_filename != "") {
    std::cerr << "   SAVE OCC: " << out_occ_filename << std::endl;        
    std::ofstream out_occ(out_occ_filename.c_str());  
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
  }

  int MAX_ADDR = 0;
  for(int i=0; i<RAM_SIZE; i++) {
    if(OCC[i] != 0) {
      MAX_ADDR=i;
    }
  }
	
  if(out_bin_filename != "") {
    std::cerr << "   SAVE BIN: " << out_bin_filename << std::endl;
    printf("        start addr:0x%lx\n",(unsigned long)bin_start_addr);
    FILE* f = fopen(out_bin_filename.c_str(),"wb");
    fwrite(RAM.data()+bin_start_addr, 1, MAX_ADDR+1-bin_start_addr, f);
    fclose(f);
  }
    
  std::cout << "Code size: "
	    << (max_address-bin_start_addr)/4 << " words"
	    << " ( total RAM size: "
	    << (RAM_SIZE/4)
	    << " words )"
	    << std::endl;
  std::cout << "Occupancy: " << ((max_address-bin_start_addr)*100) / RAM_SIZE
	    << "%" << std::endl;
  return 0;
}
