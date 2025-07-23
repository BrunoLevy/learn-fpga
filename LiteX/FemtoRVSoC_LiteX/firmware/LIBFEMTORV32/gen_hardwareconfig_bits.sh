VERILOG=../../RTL/DEVICES/HardwareConfig_bits.v

# C/C++ header #####################################################

cat > HardwareConfig_bits.h << EOF
/* Constants for memory-mapped IO registers.                      */
/* Automatically extracted from RTL/DEVICES/HardwareConfig_bits.v */

EOF

cat $VERILOG | grep localparam \
             | sed -e 's|;||g' \
             | awk '{printf "#define %s %s\n", $2, $4}' \
	     >> HardwareConfig_bits.h
	     
# ASM header #####################################################

cat > HardwareConfig_bits.inc << EOF

# Constants for memory-mapped IO registers.                      
# Automatically extracted from RTL/DEVICES/HardwareConfig_bits.v 

EOF

cat $VERILOG | grep localparam \
             | sed -e 's|;||g' \
             | awk '{printf ".equ %s, %s\n", $2, $4}' \
	     >> HardwareConfig_bits.inc

cat >> HardwareConfig_bits.inc << EOF

#################################################################
# IO_XXX = 1 << (IO_XXX_bit + 2)

EOF

cat $VERILOG | grep localparam \
             | sed -e 's|;||g' \
	     | sed -e 's|_bit||g'\
             | awk '{printf ".equ %s, %d\n", $2, lshift(1,$4+2)}' \
	     >> HardwareConfig_bits.inc
