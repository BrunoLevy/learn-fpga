// Emacs style mode select   -*- C++ -*-
//-----------------------------------------------------------------------------
//
// Copyright (C) 1993-1996 by id Software, Inc.
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
//-----------------------------------------------------------------------------

// mc1.h -- System defines for MC1

#ifndef MC1_H
#define MC1_H

// MC1 MMIO.
// clang-format off
#define CLKCNTLO    0
#define CLKCNTHI    4
#define CPUCLK      8
#define VRAMSIZE    12
#define XRAMSIZE    16
#define VIDWIDTH    20
#define VIDHEIGHT   24
#define VIDFPS      28
#define VIDFRAMENO  32
#define VIDY        36
#define SWITCHES    40
#define BUTTONS     44
#define KEYPTR      48
#define MOUSEPOS    52
#define MOUSEBTNS   56
// clang-format on

#define GET_MMIO(reg) \
	(*(volatile unsigned *)(&((volatile byte *)0xc0000000)[reg]))
#define GET_KEYBUF(ptr) \
	((volatile unsigned *)(((volatile byte *)0xc0000080)))[ptr]
#define KEYBUF_SIZE 16

// MC1 keyboard scancodes.
// clang-format off
#define KB_A                0x01c
#define KB_B                0x032
#define KB_C                0x021
#define KB_D                0x023
#define KB_E                0x024
#define KB_F                0x02b
#define KB_G                0x034
#define KB_H                0x033
#define KB_I                0x043
#define KB_J                0x03b
#define KB_K                0x042
#define KB_L                0x04b
#define KB_M                0x03a
#define KB_N                0x031
#define KB_O                0x044
#define KB_P                0x04d
#define KB_Q                0x015
#define KB_R                0x02d
#define KB_S                0x01b
#define KB_T                0x02c
#define KB_U                0x03c
#define KB_V                0x02a
#define KB_W                0x01d
#define KB_X                0x022
#define KB_Y                0x035
#define KB_Z                0x01a
#define KB_0                0x045
#define KB_1                0x016
#define KB_2                0x01e
#define KB_3                0x026
#define KB_4                0x025
#define KB_5                0x02e
#define KB_6                0x036
#define KB_7                0x03d
#define KB_8                0x03e
#define KB_9                0x046

#define KB_SPACE            0x029
#define KB_BACKSPACE        0x066
#define KB_TAB              0x00d
#define KB_LSHIFT           0x012
#define KB_LCTRL            0x014
#define KB_LALT             0x011
#define KB_LMETA            0x11f
#define KB_RSHIFT           0x059
#define KB_RCTRL            0x114
#define KB_RALT             0x111
#define KB_RMETA            0x127
#define KB_ENTER            0x05a
#define KB_ESC              0x076
#define KB_F1               0x005
#define KB_F2               0x006
#define KB_F3               0x004
#define KB_F4               0x00c
#define KB_F5               0x003
#define KB_F6               0x00b
#define KB_F7               0x083
#define KB_F8               0x00a
#define KB_F9               0x001
#define KB_F10              0x009
#define KB_F11              0x078
#define KB_F12              0x007

#define KB_INSERT           0x170
#define KB_HOME             0x16c
#define KB_DEL              0x171
#define KB_END              0x169
#define KB_PGUP             0x17d
#define KB_PGDN             0x17a
#define KB_UP               0x175
#define KB_LEFT             0x16b
#define KB_DOWN             0x172
#define KB_RIGHT            0x174

#define KB_KP_0             0x070
#define KB_KP_1             0x069
#define KB_KP_2             0x072
#define KB_KP_3             0x07a
#define KB_KP_4             0x06b
#define KB_KP_5             0x073
#define KB_KP_6             0x074
#define KB_KP_7             0x06c
#define KB_KP_8             0x075
#define KB_KP_9             0x07d
#define KB_KP_PERIOD        0x071
#define KB_KP_PLUS          0x079
#define KB_KP_MINUS         0x07b
#define KB_KP_MUL           0x07c
#define KB_KP_DIV           0x06d
#define KB_KP_ENTER         0x06e

#define KB_ACPI_POWER       0x137
#define KB_ACPI_SLEEP       0x13f
#define KB_ACPI_WAKE        0x15e

#define KB_MM_NEXT_TRACK    0x14d
#define KB_MM_PREV_TRACK    0x115
#define KB_MM_STOP          0x13b
#define KB_MM_PLAY_PAUSE    0x134
#define KB_MM_MUTE          0x123
#define KB_MM_VOL_UP        0x132
#define KB_MM_VOL_DOWN      0x121
#define KB_MM_MEDIA_SEL     0x150
#define KB_MM_EMAIL         0x148
#define KB_MM_CALCULATOR    0x12b
#define KB_MM_MY_COMPUTER   0x140

#define KB_WWW_SEARCH       0x110
#define KB_WWW_HOME         0x13a
#define KB_WWW_BACK         0x138
#define KB_WWW_FOWRARD      0x130
#define KB_WWW_STOP         0x128
#define KB_WWW_REFRESH      0x120
#define KB_WWW_FAVORITES    0x118
// clang-format on

// Macros for creating VCP commands.
// clang-format off
#define VCP_TOVCPADDR(addr)      ((((unsigned)(addr)) - 0x40000000) >> 2)
#define VCP_JMP(addr)            (0x00000000 | VCP_TOVCPADDR (addr))
#define VCP_JSR(addr)            (0x10000000 | VCP_TOVCPADDR (addr))
#define VCP_RTS                   0x20000000
#define VCP_NOP                   0x30000000
#define VCP_WAITX(x)             (0x40000000 | ((x) & 0xffff))
#define VCP_WAITY(y)             (0x50000000 | ((y) & 0xffff))
#define VCP_SETPAL(first, count) (0x60000000 | ((first) << 8) | ((count) - 1))
#define VCP_SETREG(reg, value)   (0x80000000 | ((reg) << 24) | (value))
// clang-format on

// Video registers.
#define VCR_ADDR  0
#define VCR_XOFFS 1
#define VCR_XINCR 2
#define VCR_HSTRT 3
#define VCR_HSTOP 4
#define VCR_CMODE 5
#define VCR_RMODE 6

// Color modes for the CMODE register.
#define CMODE_RGBA8888 0
#define CMODE_RGBA5551 1
#define CMODE_PAL8 2
#define CMODE_PAL4 3
#define CMODE_PAL2 4
#define CMODE_PAL1 5

#endif // MC1_H
