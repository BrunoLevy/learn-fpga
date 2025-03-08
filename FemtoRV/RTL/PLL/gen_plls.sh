
echo Generating PLL for FOMU
./gen_pll.sh ICE40 48 > pll_fomu.v

echo Generating PLL for IceFeather
./gen_pll.sh ICE40 12 > pll_icefeather.v

echo Generating PLL for IceStick
./gen_pll.sh ICE40 12 > pll_icestick.v

echo Generating PLL for IceSugar
./gen_pll.sh ICE40 12 > pll_icesugar.v

echo Generating PLL for ULX3S
./gen_pll.sh ECP5 25 > pll_ulx3s.v

echo Generating PLL for ECP5 evaluation board
./gen_pll.sh ECP5 12 > pll_ecp5_evn.v

echo Generating PLL for SIPEED Tangnano9k board
./gen_pll.sh TANGNANO9K 27 > pll_tangnano9k.v

echo Generating PLL for SIPEED Tangnano20k board
./gen_pll.sh TANGNANO20K 27 > pll_tangnano20k.v
