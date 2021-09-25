# Extracts compilation flags from selected board, and
# write them to FIRMWARE/config.mk
cd RTL
iverilog -I PROCESSOR $1 get_config.v -o tmp.vvp 
vvp tmp.vvp > ../FIRMWARE/config.mk
rm -f tmp.vvp
echo BOARD=$BOARD >> ../FIRMWARE/config.mk
cat ../FIRMWARE/config.mk
