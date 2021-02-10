###############################################################################
# NanoRv OLED display support
# Supports two types of OLED displays: SSD1351(96x64) and SSD1331(128x128)
# They use the same hardware/RTL (a SPI interface)
#
# Besides size and resolution, there are subtle differences between them:
#  - initialization sequence is simpler for the SSD1331
#  - some commands are different / take different arguments
#  - SSD1351 sends commands as commands, and command arguments as data, whereas
#    SSD1331 sends commands AND arguments as commands !
#  - there is no "write data" command on the SSD1331, everything sent
#    to the data register is data.
#
#  Side-by-side comparizon
#
#         SSD1351:                           SSD1331:
# -----------------------------------------------------------------
#   +A large tiny screen !       |  -A bit too tiny
#   -Needs wires on the ULX3S    |  +Fits well on a ULX3S
#   -Cannot flip/rotate          |  +Flexible configuration
#   -Nearly no accel. primitives |  +HW accel fillrect,scroll,copy
# ------------------------------------------------------------------
#  +For both: luminous and crisp rendering, much better than LCD !
#  +For both: last but not least, supported by FemtoRV32/FemtoSOC !!
#
# My recommendation: for ULX3S:SSD1331  for others:SSD1351
#  
###############################################################################

# Macros to send commands to the OLED driver (wrappers around OLEDx functions)
	
.macro OLED0 cmd
	li a0,\cmd
	call oled0
.endm

.macro OLED1 cmd,arg1
	li a0,\cmd
	li a1,\arg1
	call oled1
.endm

.macro OLED2 cmd,arg1,arg2
	li a0,\cmd
	li a1,\arg1
	li a2,\arg2
	call oled2
.endm

.macro OLED3 cmd,arg1,arg2,arg3
	li a0,\cmd
	li a1,\arg1
	li a2,\arg2
	li a3,\arg3	
	call oled3
.endm

################################################################################
	
