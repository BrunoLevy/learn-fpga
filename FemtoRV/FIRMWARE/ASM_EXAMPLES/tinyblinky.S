# tinyblinky.S  by Matthias Koch
# Generate smooth breathing LED effect

.globl main
.type  main, @function

# On the IceStick, install the code in BRAM (much faster)
.ifdef ICE_STICK
.section .fastcode
.endif

main:   
  li x8, 0x400004                # LED register
  li   x10, 1                    # Set up initial x, y for Minsky circle algorithm
  slli x11, x10, 19

# -----------------------------------------------------------------------------
breathe_led: # Generate smooth breathing LED effect
# -----------------------------------------------------------------------------

    # Register usage:

    # x8  : Initialised with IO address for GPIO
    # x9  : Phase accumulator for sigma-delta modulator
    # x10 : Minsky circle alg x = sin(t)
    # x11 : Minsky circle alg y = cos(t)
    # x12 : Scratch
    # x13 : Scratch
                                 # Minsky circle algorithm x, y = sin(t), cos(t)
    srai x12, x10, 17            # -dx = y >> 17
    sub  x11, x11, x12           #  x += dx
    srai x12, x11, 17            #  dy = x >> 17
    add  x10, x10, x12           #  y += dy

    srai x12, x11, 13            # -49 <= r4 <= 64   --> scaled cos(t)
    addi x12, x12, 167           # 118 <= r4 <= 231  --> scaled cos(t) with offset

    andi x13, x12, 7             # Simplified bitexp function.
    addi x13, x13, 8             #   Valid for inputs up to 231
    srli x12, x12, 3             #   Gives too small values above 231
    sll  x13, x13, x12           # Input in x12, output in x13

    add  x9, x9, x13             # Sigma-Delta phase accumulator
    sltu x13, x9, x13            # Sigma-Delta output on overflow
    sub  x13, zero, x13          # (0, 1) --> (0, -1)

   sw  x13, 0(x8)                # Set all LEDs at once
   j breathe_led

