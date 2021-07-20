Installing open-source tools for ARTIX-7 FPGAs
==============================================

Step 1: Install symbiflow
=========================

To do that, a (custom) version of [symbiflow-magic](https://github.com/merledu/symbiflow-magic) is bundled with FemtoRV.
Symbiflow-magic is a makefile that downloads and configures a pre-compiled version of symbiflow for ARTIX-7.
The version bundled with FemtoRV fixes a couple of [issues](https://github.com/merledu/symbiflow-magic/issues/1).
```
$ cd learn-fpga/FemtoRV
$ make -f TOOLS/get_symbifow.mk
```

It will download and install several packages (takes a while...)

Step 2: post-install step
=========================

Add anaconda initialization to your shell startup file as follows:
```
$ $HOME/opt/symbiflow/xc7/conda/bin/conda init $SHELL
```

Add the following line to your shell startup file (`.bashrc` if you use bash).
```
export PATH=/home/blevy/opt/symbiflow/xc7/install/bin/:$PATH
conda activate xc7
```

Start a new terminal window. If everything went well, the prompt should start with `(xc7)`.

Notes
=====

I'm currently working on another procedure that compiles
Yosys/NextPNR/ProjectXRay directly from the up-to-date sources, because:
- This version of symbiflow does not seem to support DSPs
- Symbiflow includes a place-and-route tool that is not as efficient as nextPNR
