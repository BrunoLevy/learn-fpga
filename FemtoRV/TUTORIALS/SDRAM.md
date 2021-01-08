SDRAM
=====

_WIP_
Let us try to talk to the SDRAM chip of the ULX3S and OrangeCrab ! For now, this page contains
some unstructured notes, I'm currently gathering information and trying some designs. Progress
will be reported here.

Misc notes
----------
- Address: Bank, Row, Column
- Commands: open row (activate), read/write, close row (precharge)
- Refresh: either auto-refresh, or access rows
- FPGA4Fun example: ideal for graphic board (dual ported, read agent
refreshes)
- DDR RAMS
- ULX3S data sheet: 32MB SDRAM, 166MHz, 16-bit [Micron MT48LC32M16](https://www.digchip.com/datasheets/parts/datasheet/297/MT48LC32M16.php)
- But on my own ULX3S: ALLIANCE AS4C32M16SB-7TCN

Pins
----
- clk      : 166MHz clock
- cke      : clock enable (wire to 1)
- csn      : chip select (high: everything inhibited)
- wen      : write enable (read/write bit)             \
- rasn     : row address strobe (but not a strobe)      > select one of eight commands
- casn     : column address strobe (but not a strobe)  /
- a[12:0]  : address (+ 1 line to select operations burst/auto close and close in bank, close in all bans)
- ba[1:0]  : bank
- dqm[1:0] : data mask (high: suppress data I/O). One line per 8 bits.
- d[15:0]  : bidirectional data bus

Commands
--------
- nop
- load mode
- open row (activate)
- read
- write
- close row (precharge)
- refresh

State machine
-------------
- Idle
    |
    +-- open row (activate) on transition
    |
    v
- Read/Write
- Close row (precharge)
- Nop

We may need also:
 - a timer and 'refresh state' if reader is not active enough
 - additional 'nop' states after opening and closing a row

There are 'small caps' in the FPGA4fun design, read comments carefully:
 - Need to initialize CAS (Column Address Strobe) latency=2 and any valid burt mode
 - Read agent is active enough to refresh the RAM
  
First project - Goal
--------------------
A graphic board with a 640x480 RGB framebuffer
Writer: a simple animated pattern (or FemtoRV32)
Questions:
   - Q1: How to initialize MODE register properly ?
   - Q2: What are the different modes ?
   - Q3: How to synchronize data read and video signal generation ?
   - Q4: Which one is the 'special' address line that selects burst mode ?

Read chip datasheet
-------------------
- Fast clock rate: 166/143 MHz
- 512 Mbits (64 MBytes): 8M words x 16 bits x 4 banks
- Modes
   - CAS Latency: 2 or 3
   - Burst length: 1,2,4,8 or full page
   - Burst type: sequential or interleaved
   - Burst stop function
- Auto refresh / self refresh
- 8192 refresh cycles / 64 ms
- Bank Activate: row address = A[12:0]
- Read/write: column address = A[9:0], auto-precharge = A[10]
- Mode register set: op code = A[..:..]
- Page 7: list of commands (19 commands !)






References
----------
[FPGA4fun](https://www.fpga4fun.com/SDRAM.html)
[Lawrie](https://github.com/lawrie/ulx3s_68k/blob/master/src/sdram.v)
[stffrdhrn](https://github.com/stffrdhrn/sdram-controller)
[Hackaday](https://hackaday.com/2013/10/11/sdram-controller-for-low-end-fpgas/)
[Wikipedia](https://en.wikipedia.org/wiki/Synchronous_dynamic_random-access_memory)
[Hackster](https://www.hackster.io/salvador-canas/a-practical-introduction-to-sdr-sdram-memories-using-an-fpga-8f5949)
[Chip datasheet](https://www.alliancememory.com/wp-content/uploads/pdf/dram/512M%20SDRAM_%20B%20die_AS4C32M16SB-7TCN-7TIN-6TIN_Rev%201.0%20June%202016.pdf)