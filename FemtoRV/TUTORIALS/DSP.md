DSPs
====
_WIP_

Introduction
------------
On xilinx, yosys does not support yet generating a wide multiplier
from DSPs, let's see how to do that, it is a good opportunity to 
see how DSPs work. Xilinx documentation on the DSP available in 
xc7 [2](https://www.xilinx.com/support/documentation/user_guides/ug479_7Series_DSP48E1.pdf) 
is rather hairy, so I aked on twitter and Jan Gray indicated some
resources [here](https://twitter.com/jangray/status/1117464465690095616). 
In particular, the user guide for Xilinx previous generation of DSPs
[1](https://www.xilinx.com/support/documentation/user_guides/ug073.pdf)
has some explations, page 33.

Principles
----------
A good approach to understand something is trying to reinvent it. So
let's imagine you want to invent a building bloc that one can assemble
to create nxn multipliers, where n is an arbitrary bitwidth. 
Let us take a look at how one computes a product:



References
==========
 - [Twitter thread (Jan Gray)](https://twitter.com/jangray/status/1117464465690095616)
 - [Twitter search (Jan Gray)](https://twitter.com/search?q=(dsp%20OR%20dsp48%20OR%20dsp48e1%20OR%20dsp48e2)%20(from%3Ajangray)&src=typed_query)
 - [1] [Xilinx Vitex-4 user guide](https://www.xilinx.com/support/documentation/user_guides/ug073.pdf) (OLD but has some information on cascading / how to assemble a wide multiplier)
 - [2] [Xilinx 48E1 DSP user guide](https://www.xilinx.com/support/documentation/user_guides/ug479_7Series_DSP48E1.pdf)
 - [2] [Xilinx 48E2 DSP user guide](https://www.xilinx.com/support/documentation/user_guides/ug579-ultrascale-dsp.pdf)
 - [3] [Compute-Efficient Neural Network Acceleration (slides)](https://www.isfpga.org/past/fpga2019/slides/Compute-Efficient_Neural-Network_Acceleration.pdf)
 - [4] [FloPoCo](http://flopoco.gforge.inria.fr/)
 - [5] [Karatsuba with rectanble mutlipliers for FPGAs](https://hal.inria.fr/hal-01773447/document)
 - /usr/local/share/yosys/xilinx/xc7_dsp_map.v