DEVICE=/dev/ttyUSB1
BAUDS=115200



# MINITERM  exit: <ctrl> ]     package: sudo apt-get install python3-serial
#miniterm --dtr=0 $DEVICE $BAUDS

# SCREEN    exit: <ctrl> a \   package: sudo apt-get install screen
screen $DEVICE $BAUDS

# PICOCOM exit: <ctrl> a \   package: sudo apt-get install picocom
#picocom -b $BAUDS $DEVICE --imap lfcrlf,crcrlf --omap delbs,crlf --send-cmd "ascii-xfr -s -l 30 -n"
