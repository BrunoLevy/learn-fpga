echo "When the builtin led goes out on the pico2w we are ready to connect"
echo "sleep for 5 seconds"
sleep 5
kill -9 $(lsof -t -i :4242)
lsof -i :4242
#socat -d -d PTY,link=/tmp/iceflash,raw TCP:PicoW-ice40fpga-bridge:4242 &
socat -d -d PTY,link=/tmp/iceflash,raw TCP:10.42.0.225:4242 &
sleep 1

echo "Now issue "./iceprogduino -v -I /tmp/iceflash -t" etc."
echo "If you do a chip erase poll with above command after about 40 seconds."
#./iceprogduino -v -I/tmp/iceflash -r readback.bin
#kill -9 $(lsof -t -i :4242)
