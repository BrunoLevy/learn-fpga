/**
 * Displays data from IR remote using the built-in irda of the IceStick.
 * Decodes NEC protocol and SHARP protocol IR remotes
 * 
 * Tested with "Magic Lighting" remove controller for intelligent light bulb.
 *        and "Sharp LCDTV"
 * 
 * Select device in main() function at the end of this file.
 * 
 * References:
 * 
 * NEC infrared protocol:
 *   http://www.technoblogy.com/show?UVE
 *   https://techdocs.altium.com/display/FPGA/NEC+Infrared+Transmission+Protocol
 *
 * Magic Lighting remote controller codes:
 * https://docs.google.com/spreadsheets/d/1pGp-7BIC4l7Ogg4i09QTNGyKOmQkkMjxEph5mRSQdFA/edit#gid=0
 * 
 * Sharp protocol: https://www.sbprojects.net/knowledge/ir/sharp.php
 *
 */ 

#include <femtorv32.h>
#include <femtoGL.h>

// Uncomment one of the following lines depending
// on the type of IR remote you have:
  #define IR_PROTOCOL_NEC
//#define IR_PROTOCOL_SHARP

#if defined(IR_PROTOCOL_NEC)
#define ir_init nec_init
#define ir_read nec_read
#define ir_protocol_name "nec"
#elif defined(IR_PROTOCOL_SHARP)
#define ir_init sharp_init
#define ir_read sharp_read
#define ir_protocol_name "sharp"
#endif

// NEC protocol:
//                             ________   ________   ________   ________
//  |||||||||||||||           /        \ /        \ /        \ /        \
//  |||||||||||||||          .          X          X          X          . 
// _|||||||||||||||_________/ \________/ \________/ \________/ \________/
//   <--9 ms ----><-4.5 ms--> <--ADDRL-> <--ADDRH-> <--CMD---> <--~CMD-->
//
// ADDRL, ADDRH, CMD and ~CMD are 8 bits.
// Each bit is encoded as follows (a 562.5us pulse burst followed by a space,
// space length encodes the bit):
//
// Bit set to "0":
//  
//  |||||||         
//  |||||||         
// _|||||||______
//  <----> <---->
// 562.5us 562.5us 
// 
// Bit set to "1":
//           
//  |||||||         
//  |||||||         
// _|||||||____________________
//  <----> <------------------>
// 562.5us       1687.5us 
//
// Note: IR pulse bursts are not continuous (carrier is 38KHz),
// They are not like that:
//  ______         
//  |     |         
//  |     |         
// _|     |______
//
// They are like that:
//           
//  |||||||         
//  |||||||         
// _|||||||______
//
// for this reason, we cannot measure a pulse burst's length
// with "while(ir_status())", we instead pause for the
// supposed length of the pulse burst, and measure the length
// of spaces between the pulse bursts.

// 1 if IR light is detected, 0 otherwise
static inline int ir_status() {
   return !(IO_IN(IO_LEDS) & 64);
}

// Gets the number of cycles elapsed during
// a space (with IR light off).
uint32_t get_space_cycles() RV32_FASTCODE;
uint32_t get_space_cycles() {
  uint64_t cycles1 = cycles();
  while(!ir_status());  
  uint64_t cycles2 = cycles();
  return cycles2 - cycles1;
}

// Converts a time interval into a number of
// clock ticks.
static inline int microseconds_to_cycles(int ms) {
  return ms * FEMTORV32_FREQ;
}


// Tolerance for the initial space
//
uint32_t min_space_cycles  = 0;
uint32_t max_space_cycles  = 0;

// Tolerance and threshold for bits
//
//          min_space0_cycles     space01_cycles   max_space1_cycles
//                   |                 |                  |
// invalid --------->|<------- 0 ----->|<------- 1 ------>|<-------- invalid
uint32_t min_space0_cycles = 0;
uint32_t space01_cycles    = 0;
uint32_t max_space1_cycles = 0;

void nec_init() {
  min_space_cycles  = microseconds_to_cycles(3000);
  max_space_cycles  = microseconds_to_cycles(4000);
  min_space0_cycles = microseconds_to_cycles(300);
  space01_cycles    = microseconds_to_cycles(1000);
  max_space1_cycles = microseconds_to_cycles(2000);      
}

// Returns bit value, or -1 on error
int nec_read_bit() RV32_FASTCODE;
int nec_read_bit() {
  microwait(600); // skip the pulse burst
                  // (562.5 us plus security margin)
  uint32_t space_width = get_space_cycles();
  if(space_width < min_space0_cycles) return -1;
  if(space_width > max_space1_cycles) return -1;
  return (space_width > space01_cycles);
}

// Returns a single 32-bits value with
//  ADDRL ADDRH CMD ~CMD
// or 0 on error
uint32_t nec_read() RV32_FASTCODE;
uint32_t nec_read() {
  uint32_t result = 0;
  
  while(!ir_status()); // Wait for IR
  microwait(10000);    // First pulse is supposed to be 9ms long
                       // (wait a little bit more to make sure IR is off)
  
  // Now measure the length of the first space (supposed to be 4.5ms, minus
  // the 1ms security margin we added at the previous line).
  uint32_t space_width = get_space_cycles();

  // space outside of tolerance [3ms,4ms]  
  if(space_width < min_space_cycles || space_width > max_space_cycles) {
    return 0;
  }

  // read the 32 bits of address and command
  for(int i=0; i<32; ++i) {
    int bit = nec_read_bit();
    if(bit == -1) {
      return 0;
    }
    result = (result << 1) | bit;
  }
  return result;
}

/********************************************************************************/

// Sharp protocol
// https://www.sbprojects.net/knowledge/ir/sharp.php
// 5 bits of address, 8 bits of command
// logical "0": 320 us pulse burst, then 680 us space
// logical "1": 320 us pulse burst, then 1680 us space


void sharp_init() {
  min_space0_cycles = microseconds_to_cycles(300);
  space01_cycles    = microseconds_to_cycles(1000);
  max_space1_cycles = microseconds_to_cycles(2000);      
}

// Returns bit value, or -1 on error
int sharp_read_bit() RV32_FASTCODE;
int sharp_read_bit() {
  microwait(500); // skip the pulse burst
                  // (320 us plus security margin)
  uint32_t space_width = get_space_cycles();
  if(space_width < min_space0_cycles) return -1;
  if(space_width > max_space1_cycles) return -1;
  return (space_width > space01_cycles);
}

// Returns a single 13-bits value with
//  address (5 bits) command (8 bits)
// or 0 on error
uint32_t sharp_read() RV32_FASTCODE;
uint32_t sharp_read() {
  uint32_t result = 0;
  while(!ir_status()); // Wait for IR
  // read the 5 bits of address and 8 bits of command
  for(int i=0; i<13; ++i) {
    int bit = nec_read_bit();
    if(bit == -1) {
      return 0;
    }
     result = (result << 1) | bit;
  }
  if(nec_read_bit() == -1) { // exp bit
     return 0;
  }
  if(nec_read_bit() == -1) { // chk bit
     return 0;
  }
  // One could wait 40 ms and load the next command that contains the same
  // address and inverted bits, and check the inverted bits. We simply 
  // ignore the second message...
  milliwait(250);
  return result;
}


/********************************************************************************/

int main() {
   ir_init();
   femtosoc_tty_init();
   GL_set_font(&Font8x16);
   printf("%s IR remote\n",ir_protocol_name);
   for(;;) {
     uint32_t cmdaddr = ir_read();
     if(cmdaddr) {
       printf("%x\n",cmdaddr);
     }
   }
}
