echo "type: <ctrl-a> <ctrl-x> in order to exit terminal"
picocom -b 115200 /tmp/iceserial --imap lfcrlf,crcrlf --omap delbs,crlf --send-cmd "ascii-xfr -s -l 30 -n"
