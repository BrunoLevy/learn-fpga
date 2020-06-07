#include <iostream>
#include <fstream>

// NanoRV RAM is organized in pages of 256 words.
// Each page is stored in two SB_RAM40_4K (4 KBits)

const int NB_PAGES = 6;
const int PAGE_SIZE_IN_WORDS = 256;
const int PAGE_SIZE_IN_BYTES = PAGE_SIZE_IN_WORDS * 2;
const int RAM_SIZE_IN_WORDS = NB_PAGES * 256;
const int RAM_SIZE_IN_BYTES = RAM_SIZE_IN_WORDS * 4;


int main() {
    std::string firmware;
    std::ifstream in("firmware.hex");
    
    if(!in) {
	std::cerr << "Could not open firmware.hex" << std::endl;
	return 1;
    }
    
    std::string line;
    while(std::getline(in, line)) {
	firmware.append(line);
    }
    firmware.resize(RAM_SIZE_IN_BYTES*2,'0');

    for(int page=0; page<NB_PAGES; ++page) {
	int base = page * PAGE_SIZE_IN_WORDS * 8;
	std::ofstream page_lo(("page_" + std::to_string(page+1) + "_lo.hex").c_str());
	std::ofstream page_hi(("page_" + std::to_string(page+1) + "_hi.hex").c_str());
	for(int i=0; i<16; ++i) {
	    for(int j=0; j<16; ++j) {
		int offset = (i*16+j)*8;
		char* word = &firmware[base+offset];
		page_lo << word[4] << word[5] << word[6] << word[7] << ' ';
		page_hi << word[0] << word[1] << word[2] << word[3] << ' ';
	    }
	    page_lo << std::endl;
	    page_hi << std::endl;
	}
    }
    
    return 0;
}
