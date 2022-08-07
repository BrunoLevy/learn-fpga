/**
 * Converts ascii hex firmware files with byte values 
 * into files with word values. 
 * It is required by femtosoc's RAM initialization, that
 * is organized by words, and initialized using verilog's 
 * $readmemh().
 * Can also directly load an ELF statically-linked binary.
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

/**
 * \brief Converts a character into a nibble (half-byte)
 * \param[in] c one of 0..9,A..F,a..f
 * \return the numeric value as an unsigned char
 */
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

/**
 * \brief Converts a two-characters string into a byte
 * \param[in] str a pointer to a two-characters array 
 * \details \p str needs to have exactly two characters and
 *          does not need to be null-terminated
 * \return the numeric value as an unsigned char
 */
unsigned char string_to_byte(char* str) {
    return (char_to_nibble(str[0]) << 4) | char_to_nibble(str[1]);
}

/**
 * \brief Splits a string into parts
 * \details Splits the string \p in into a list of substrings \p out
 *  wherever \p separator occurs.
 * \param[in] in the input string to split
 * \param[in] separator the separator character
 * \param[in] out the resulting list of substrings
 * \param[in] skip_empty_fields specifies whether empty parts should
 *  be ignored and not stored in list \p out (this is true by default).
 *  \see join_strings()
 */
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
 * \brief Parses femtosoc.v and extracts RAM size
 * \param filename the VERILOG file to be parsed
 * \return RAM size or 0 if RAM size (NRV_RAM) is 
 *  not specified in \p filename
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


/**
 * \brief Loads an ASCII hexadecimal file into a vector of bytes
 * \param[in] filename the name of the file to be loaded
 * \param[out] RAM a vector of unsigned char where the content of the
 *  file will be loaded
 * \return the highest set address or -1 if there was an error
 * \details this function understands the '@' statement in VERILOG 
 *  files that redefine the origin. It performs several sanity checks, 
 *  including verifying that the same address was not written twice.
 */
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

/* 
 * \brief Loads a statically linked ELF binary into a vector of bytes
 * \param[out] RAM a vector of unsigned char where the content of the
 *  file will be loaded
 * \return the highest set address or -1 if there was an error
 */
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

/* 
 * \brief Loads a file into a vector of bytes
 * \param[in] filename the name of the file to be loaded, can be an ASCII
 *  hexadecimal file (.hex extension) or a statically linked ELF executable
 *  (.elf extension).
 * \return the highest set address or -1 if there was an error. 
 */
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

/**
 * \brief Saves a vector of bytes into an ASCII hexadecimal file that
 *  can be understood by VERILOG's readmemh() function
 * \param[in] filename the name of the file
 * \param[in] RAM the vector of bytes to be saved
 * \param[in] from_addr , to_addr the optional interval to be saved
 * \details from_addr and to_addr + 1 need to be on a word boundary
 */
void save_RAM_hex(
    const char* filename, std::vector<unsigned char>& RAM,
    int from_addr=0, int to_addr=-1
) {
    if(to_addr == -1) {
	to_addr = RAM.size()-1;
    }
    if((from_addr & 3) != 0) {
	std::cerr << "save RAM hex:"
		  << "from_addr needs to be on a word boundary"
		  << std::endl;
	exit(-1);
    }

    if(((to_addr+1) & 3) != 0) {
	std::cerr << "save RAM hex:"
		  << "(to_addr+1) needs to be on a word boundary"
		  << std::endl;
	exit(-1);
    }
    
    std::cerr << "   SAVE HEX: " << filename << std::endl;    
    std::ofstream out(filename);
    for(int i=from_addr; i<to_addr; i+=4) {
	char buff[10];
	sprintf(buff,"%.2x%.2x%.2x%.2x ",RAM[i+3],RAM[i+2],RAM[i+1],RAM[i]);
	out << buff; 
	if(((i/4+1) % 4) == 0) {
	    out << std::endl;
	}
    }
}

/**
 * \brief Saves a vector of bytes into a raw binary file
 * \param[in] filename the name of the file
 * \param[in] RAM the vector of bytes to be saved
 * \param[in] from_addr , to_addr the optional interval to be saved
 */
void save_RAM_bin(
    const char* filename, std::vector<unsigned char>& RAM,
    int from_addr=0, int to_addr=-1
) {
    if(to_addr==-1) {
	to_addr = RAM.size()-1;
    }
    std::cerr << "   SAVE BIN: " << filename << std::endl;
    printf("        from addr:0x%lx\n",(unsigned long)from_addr);
    printf("          to addr:0x%lx\n",(unsigned long)to_addr);    
    FILE* f = fopen(filename,"wb");
    fwrite(RAM.data()+from_addr, 1, to_addr+1-from_addr,f);
    fclose(f);
}

/**
 * \brief Saves a vector of bytes into a file.
 * \param[in] filename the name of the file. Extension can be .hex 
 *  (ASCII hexadecimal that can be understood by VERILOG's readmemh
 *   command) or .bin (raw binary file).
 * \param[in] RAM the vector of bytes to be saved
 * \param[in] from_addr , to_addr the optional interval to be saved
 * \details from_addr and to_addr + 1 need to be on a word boundary
 */
void save_RAM(
    const char* filename, std::vector<unsigned char>& RAM,
    int from_addr=0, int to_addr=-1
) {
    int l = strlen(filename);
    if(l >= 3 && !strcmp(filename+l-3,"hex")) {
	return save_RAM_hex(filename, RAM, from_addr, to_addr);
    } 
    if(l >= 3 && !strcmp(filename+l-3,"elf")) {
	return save_RAM_bin(filename, RAM, from_addr, to_addr);
    }
    std::cerr << "save_RAM:" << filename
	      << ": invalid extension" << std::endl;
    exit(-1);
}

/****************************************************************/

/**
 * \brief Parses an integer given as a command line argument
 * \param[in] str the string to be parsed
 * \return the parsed integer
 * \details if the string starts with "0x", then the integer is
 *  considered to be hexadecimal, else it is considered to be 
 *  decimal.
 */
int parse_int(const char* str) {
    int result;
    if(strlen(str) > 2 && str[0] == '0' && str[1] == 'x') {
	sscanf(str+2, "%x", &result);
	return result;
    }
    sscanf(str,"%d",&result);
    return result;
}

/****************************************************************/

int main(int argc, char** argv) {

    bool cmdline_error = false;

    std::string in_filename;
    std::string in_verilog_filename;
    std::string out_filename;
    int from_addr = 0;
    int to_addr   = -1;
    int RAM_SIZE  = 0;
    int MAX_ADDR  = 0;
   
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
	} else if(!strcmp(argv[i],"-out")) {
	    out_filename = argv[i+1];       
	} else if(!strcmp(argv[i],"-from_addr")) {
	    from_addr = parse_int(argv[i+1]);
	} else if(!strcmp(argv[i],"-to_addr")) {
	    to_addr = parse_int(argv[i+1]);
	} else if (!strcmp(argv[i],"-ram")) {
	    RAM_SIZE = parse_int(argv[i+1]);
	} else if (!strcmp(argv[i],"-max_addr")) {
	    MAX_ADDR = parse_int(argv[i+1]);
	} else {
	    cmdline_error = true;
	    break;
	}
    }

    if(cmdline_error) {
	std::cerr << "usage: " << argv[0]
		  << " input.rawhex|input.elf <-out out.hex|out.bin>"
		  << " <-from_addr addr> <-to_addr addr>"
		  << " <-ram ram_amount> <-max_addr max_address>"
	          << " <-verilog femtosoc.v> "
		  << std::endl;
	std::cerr << "  -out out.hex|out.bin         :"
		  << " VERILOG .hex for readmemh()"
		  << " or plain binary file" << std::endl;
	std::cerr << "  -from_addr addr -to_addr addr:"
		  << " optional address sequence to be saved"
		  << " (default: save whole RAM)"
		  << std::endl;
	std::cerr << "  -ram ram_size                :"
		  << " specify RAM size explicity"
		  << std::endl;
	std::cerr << "  -verilog source.v            :"
		  << " get RAM size from verilog source (NRV_RAM=xxxx)"
		  << std::endl;
	std::cerr << "  -max_addr addr               :"
		  << " specify optional maximum address. For instance, "
		  << "can be used to make sure some space remains for the stack."
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
  
    std::cout << "Code size: "
	      << max_addr/4 << " words"
	      << " ( total RAM size: "
	      << (RAM_SIZE/4)
	      << " words )"
	      << std::endl;
    std::cout << "Occupancy: " << (max_addr*100) / RAM_SIZE
	      << "%" << std::endl;

   
    if(MAX_ADDR != 0) {
	std::cout << "testing MAX_ADDR limit: " << MAX_ADDR << std::endl;
	if(max_addr > MAX_ADDR) {
	    std::cerr << "   max_addr overflow, MAX_ADDR exceeded" << std::endl;
	    return 1;
	} else {
	    std::cout << "   max_addr OK" << std::endl;
	}
    }
   
    if(out_filename != "") {
	save_RAM(out_filename.c_str(), RAM, from_addr, to_addr);
    }
    
    return 0;
}
