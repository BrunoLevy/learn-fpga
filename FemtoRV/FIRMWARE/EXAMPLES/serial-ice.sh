echo "If using HX1KEVB ensure TX and RX solder jumpers are bridged."
echo "With HX8KEVB this is not an issue."
PRE_SERIAL_SOCAT_PID=$(lsof -t -i :4343)
if [ $? -eq 0 ]; then
   kill -9 $PRE_SERIAL_SOCAT_PID
fi

lsof -i :4343
#socat -d -d PTY,link=/tmp/iceserial,raw TCP:PicoW-ice40fpga-bridge:4343 &
socat -d -d PTY,link=/tmp/iceserial,raw TCP:10.42.0.225:4343 &
sleep 1

#minicom -D /tmp/iceserial

#POST_SERIAL_SOCAT_PID=$(lsof -t -i :4343)
#if [ $? -eq 0 ]; then
#   kill -9 $POST_SERIAL_SOCAT_PID
#fi
