
#VERBOSE=1  #uncomment this line and comment the next one to debug library compilation
VERBOSE="/dev/null"

echo "============> Compiling libs"
(cd LIBFEMTORV32; make clean libfemtorv32.a > $VERBOSE) # Compile hardware support lib
(cd LIBFEMTOC;    make clean libfemtoc.a    > $VERBOSE) # Compile lib with printf() replacement function
# Note: I 'make clean' each time, because there is no much to recompile (and dependencies
# are not specified)...

echo "============>" Making $EXE_BASENAME
EXE_BASENAME=`basename $1 | sed -e 's|\.c$||' -e 's|\.S$||'`
SOURCE_DIR=`dirname $1`
(cd $SOURCE_DIR; make clean $EXE_BASENAME".hex" $EXE_BASENAME".exe")

rm -f firmware.hex
if [[ -f  $SOURCE_DIR"/"$EXE_BASENAME".hex" ]]; then
   cp $SOURCE_DIR"/"$EXE_BASENAME".hex" firmware.hex
   # Display message with ARCH,ABI,OPTIMIZE (useful to know at that point)
   ARCH=`grep < makefile.inc '^ARCH='`
   ABI=`grep < makefile.inc '^ABI='`
   OPTIMIZE=`grep < makefile.inc '^OPTIMIZE='`
   echo "Generated firmware.hex (arch=$ARCH, abi=$ABI, optimize=$OPTIMIZE)"
else
   echo "Something went wrong, change VERBOSE in make_firmware.sh and retry"
fi


## Display assembly
#$RVOBJCOPY -O binary BUILD/firmware.elf BUILD/firmware.bin
#$RVOBJDUMP -D -b binary -m riscv BUILD/firmware.bin 
