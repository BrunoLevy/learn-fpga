# FOMU VGA
_Generate hypnotic graphics with the FOMU_

Step 1: graft wires to the FOMU
--------------------------------

![](Images/FrankenFOMU.png)

The FOMU has four pads `user_1`,...,`user_4` connected to FPGA pins
E4,D5,E5,F5. We can use them to generate the HSync and VSync VGA signals
plus two bits of color data. You will need to solder a wire to each pad, 
plus a wire to the mass, as shown on the image (five wires in total).
I observed that rigid wires with a single core are easier to solder.

Step 2: VGA connector
---------------------

![](Images/VGA.jpg)

Connect to the VGA connector as shown on the image. Pick the two colors
you prefer among R,G,B and connect them to `user_3` and `user_4`. 




