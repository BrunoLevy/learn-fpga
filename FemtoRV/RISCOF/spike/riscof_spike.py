import os
import re
import shutil
import subprocess
import shlex
import logging
import random
import string

import riscof.utils as utils
import riscof.constants as constants
from riscof.pluginTemplate import pluginTemplate

logger = logging.getLogger()

class spike(pluginTemplate):
    __model__ = "spike"
    __version__ = "0.1.0"

    def __init__(self, *args, **kwargs):
        """
        Process config.ini file and setup logging.
        """
        sclass = super().__init__(*args, **kwargs)

        config = kwargs.get('config')
        if config is None:
            logger.error(self.name + " config node is missing.")
            raise SystemExit(1)
        self.num_jobs = str(config['jobs'] if 'jobs' in config else 1)
        self.pluginpath = os.path.abspath(config['pluginpath'])
        self.isa_spec = os.path.abspath(config['ispec']) if 'ispec' in config else ''
        self.platform_spec = os.path.abspath(config['pspec']) if 'ispec' in config else ''
        self.make = config['make'] if 'make' in config else 'make'
        logger.debug(self.name + " plugin initialized using the following configuration:")
        self.config = config
        for entry in config:
            logger.debug(entry+' : '+config[entry])
        return sclass

    def initialise(self, suite, work_dir, archtest_env):
        """
        Prepare toolchain, and model executables.
        Checking whether the executables are available is done in the build step,
        since this step lacks XLEN information from YAML files.
        """
        self.suite = suite
        self.work_dir = work_dir
        self.archtest_env = archtest_env

        # NOTE: The following assumes you are using the riscv-gcc toolchain.
        #       If not please change appropriately.
        # prepare toolchain executables ({} to be replaced with XLEN)
        self.toolchain = 'riscv32-unknown-elf-'

        # prepare model executable
        self.ref_exe = os.path.join(self.config['PATH'] if 'PATH' in self.config else "","spike")

    def build(self, isa_yaml, platform_yaml):
        """
        Build is run only once before running for each test list.
        """
        # load ISA YAML file
        self.ispec = utils.load_yaml(isa_yaml)['hart0']
        self.xlen = ('64' if 64 in self.ispec['supported_xlen'] else '32')
        self.flen = ('64' if "D" in self.ispec["ISA"] else '32')
        # construct ISA string
        self.isa = 'rv' + self.xlen
        for ext in ['I', 'M', 'A', 'F', 'D', 'C']:
            if ext in self.ispec["ISA"]:
                self.isa += ext.lower()

        # check if toolchain executables are available
        for tool in [self.toolchain+'gcc', self.toolchain+'objdump']:
            if shutil.which(tool) is None:
                logger.error(tool + ": executable not found. Please check environment setup.")
                raise SystemExit(1)
            
        # check if the reference executable is available
        if shutil.which(self.ref_exe) is None:
            logger.error(self.ref_exe + ": executable not found. Please check environment setup.")
            raise SystemExit(1)
        
        # check if 'make' is available
        if shutil.which(self.make) is None:
            logger.error(self.make + ": executable not found. Please check environment setup.")
            raise SystemExit(1)

    def runTests(self, testList, cgf_file=None):
        # remove ':' from the end of the name
        name = self.name[:-1]
        if os.path.exists(self.work_dir+ "/Makefile." + name):
            os.remove(self.work_dir+ "/Makefile." + name)
        make = utils.makeUtil(makefilePath=os.path.join(self.work_dir, "Makefile." + name))
        make.makeCommand = self.make + ' -j' + self.num_jobs

        for file in testList:
            testentry = testList[file]
            test = testentry['test_path']
            test_dir = testentry['work_dir']

            elf = os.path.join(test_dir, 'ref.elf')
            dis = os.path.join(test_dir, 'ref.disass')
            sig = os.path.join(test_dir, name + ".signature")
            log = os.path.join(test_dir, 'ref.log')

            execute = []

            # NOTE: The following assumes you are using the riscv-gcc toolchain.
            #       If not please change appropriately.
            # compile testcase assembly into an elf file
            cmd = self.toolchain+'gcc' + (
                f' -mabi={'lp64' if 64 in self.ispec['supported_xlen'] else 'ilp32'} '
                f' -march={testentry['isa'].lower()}'
                 ' -static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles'
                f' -T {self.pluginpath}/env/link.ld'
                f' -I {self.pluginpath}/env/'
                f' -I {self.archtest_env}'
                f' {test}'
                f' -o {elf}'
                f' -D{" -D".join(testentry['macros'])}'
            )
            execute.append(cmd)

            # dump disassembled elf file
            cmd = self.toolchain+'objdump' + f' -M no-aliases -M numeric -D {elf} > {dis}'
            execute.append(cmd)

            # run reference model
            # signature-granularity specifies how many bytes in HEX are in a line of the signature file
            cmd = self.ref_exe + f' --isa={self.isa} --log-commits +signature={sig} +signature-granularity=4 {elf} > {log} 2>&1'
            execute.append(cmd)

            make.add_target('\n'.join(execute))

        make.execute_all(self.work_dir)
