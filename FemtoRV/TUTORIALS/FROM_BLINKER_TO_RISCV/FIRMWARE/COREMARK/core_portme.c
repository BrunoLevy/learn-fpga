/*
Copyright 2018 Embedded Microprocessor Benchmark Consortium (EEMBC)

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

Original Author: Shay Gal-on
*/
#include <io.h>
#include <stdio.h>
#include "coremark.h"
#include "core_portme.h"
#include <perf.h>

#if VALIDATION_RUN
volatile ee_s32 seed1_volatile = 0x3415;
volatile ee_s32 seed2_volatile = 0x3415;
volatile ee_s32 seed3_volatile = 0x66;
#endif
#if PERFORMANCE_RUN
volatile ee_s32 seed1_volatile = 0x0;
volatile ee_s32 seed2_volatile = 0x0;
volatile ee_s32 seed3_volatile = 0x66;
#endif
#if PROFILE_RUN
volatile ee_s32 seed1_volatile = 0x8;
volatile ee_s32 seed2_volatile = 0x8;
volatile ee_s32 seed3_volatile = 0x8;
#endif
volatile ee_s32 seed4_volatile = ITERATIONS;
volatile ee_s32 seed5_volatile = 0;

/* Porting : Timing functions
        How to capture time and convert to seconds must be ported to whatever is
   supported by the platform. e.g. Read value from on board RTC, read value from
   cpu clock cycles performance counter etc. Sample implementation for standard
   time.h and windows.h definitions included.
*/
CORETIMETYPE  barebones_clock()
{
   return (CORETIMETYPE)(rdcycle());
}

/* Define : TIMER_RES_DIVIDER
        Divider to trade off timer resolution and total time that can be
   measured.

        Use lower values to increase resolution, but make sure that overflow
   does not occur. If there are issues with the return value overflowing,
   increase this value.
        */
#define CLOCKS_PER_SEC             10000000
#define GETMYTIME(_t)              (*_t = barebones_clock())
#define MYTIMEDIFF(fin, ini)       ((fin) - (ini))
#define TIMER_RES_DIVIDER          1
#define SAMPLE_TIME_IMPLEMENTATION 1
#define EE_TICKS_PER_SEC           (CLOCKS_PER_SEC / TIMER_RES_DIVIDER)

/** Define Host specific (POSIX), or target specific global time variables. */
static CORETIMETYPE start_time_val, stop_time_val;

/* Function : start_time
        This function will be called right before starting the timed portion of
   the benchmark.

        Implementation may be capturing a system timer (as implemented in the
   example code) or zeroing some system parameters - e.g. setting the cpu clocks
   cycles to 0.
*/
void
start_time(void)
{
    GETMYTIME(&start_time_val);
}
/* Function : stop_time
        This function will be called right after ending the timed portion of the
   benchmark.

        Implementation may be capturing a system timer (as implemented in the
   example code) or other system parameters - e.g. reading the current value of
   cpu cycles counter.
*/
void
stop_time(void)
{
    GETMYTIME(&stop_time_val);
}
/* Function : get_time
        Return an abstract "ticks" number that signifies time on the system.

        Actual value returned may be cpu cycles, milliseconds or any other
   value, as long as it can be converted to seconds by <time_in_secs>. This
   methodology is taken to accommodate any hardware or simulated platform. The
   sample implementation returns millisecs by default, and the resolution is
   controlled by <TIMER_RES_DIVIDER>
*/
CORE_TICKS
get_time(void)
{
    CORE_TICKS elapsed
        = (CORE_TICKS)(MYTIMEDIFF(stop_time_val, start_time_val));
    return elapsed;
}
/* Function : time_in_secs
        Convert the value returned by get_time to seconds.

        The <secs_ret> type is used to accommodate systems with no support for
   floating point. Default implementation implemented by the EE_TICKS_PER_SEC
   macro above.
*/
secs_ret
time_in_secs(CORE_TICKS ticks)
{
    secs_ret retval = ((secs_ret)ticks) / (secs_ret)EE_TICKS_PER_SEC;
    return retval;
}

ee_u32 default_num_contexts = 1;

/* Function : portable_init
        Target specific initialization code
        Test for some common mistakes.
*/
void
portable_init(core_portable *p, int *argc, char *argv[])
{
    //usleep(100);
    //io.led = 0xF;

//  ee_printf("board: %s (id=%d)\n",board_name(io.board_id),io.board_id);
    ee_printf("build: %s for %s\n",BUILD,ARCH);

//    ee_printf("core%d: ",              io.core_id);                 // core id
//    ee_printf("darkriscv@%dMHz with: ",io.board_cm*2);              // board clock MHz
//    ee_printf("rv32%s ",               check4rv32i()?"i":"e");      // architecture
    ee_printf("\n");
//    ee_printf("uart0: 115200 bps (div=%d)\n",io.uart.baud);
//    ee_printf("timr0: frequency=%dHz (io.timer=%d)\n",(io.board_cm*2000000u)/(io.timer+1),io.timer);
    
    ee_printf("\n\n");
    
//    ee_printf("CoreMark start in %d us.\n",io.timeus);
      
// #error "Call board initialization routines in portable init (if needed), in particular initialize UART!\n"
    if (sizeof(ee_ptr_int) != sizeof(ee_u8 *))
    {
        ee_printf(
            "ERROR! Please define ee_ptr_int to a type that holds a "
            "pointer!\n");
    }
    if (sizeof(ee_u32) != 4)
    {
        ee_printf("ERROR! Please define ee_u32 to a 32b unsigned type!\n");
    }
    p->portable_id = 1;
}


// Print "fixed point" number (integer/1000)
void printk(uint64_t kx) {
    int intpart  = (int)(kx / 1000);
    int fracpart = (int)(kx % 1000);
    printf("%d.",intpart);
    if(fracpart<100) {
	printf("0");
    }
    if(fracpart<10) {
	printf("0");
    }
    printf("%d",fracpart);
}


void print_coremarks(uint64_t ticks) {
   const uint64_t MHz = CLOCKS_PER_SEC/1000000;
// printf("*** MHz        : %d\n",(int)MHz);    
   printf("*** Ticks        : %d\n",(int)ticks);
   uint64_t ksecs=ticks/(CLOCKS_PER_SEC/1000);
// printf("*** Time       : "); printk(ksecs); printf("\n");
   uint64_t kiter_per_sec= (uint64_t)(ITERATIONS*1000*1000)/ksecs;
// printf("*** Iter/s     : "); printk(kiter_per_sec); printf("\n");
   printf("*** Coremark/MHz : "); printk(kiter_per_sec/MHz); printf("\n");

   uint64_t kticks2 = rdcycle() * (uint64_t)1000;
   uint64_t instret2 = rdinstret();
   printf("*** CPI (2)      : "); printk(kticks2/instret2); printf("\n");
}

/* Function : portable_fini
        Target specific final code
*/
void
portable_fini(core_portable *p)
{
 //io.led = 0;
 //ee_printf("CoreMark finish in %d us.\n\n",io.timeus);
    p->portable_id = 0;
    
    // makes no sense return here!

    //while(1)
    //{
    //    usleep(500000);
    //    io.led++;    
    //}
}
