!#/bin/bash
qemu-system-i386 \
-m 2048M \
-k en-us \
-rtc base=localtime \
-device cirrus-vga \
-display gtk \
-hda ~/OS/xp-dev.img \
-drive file=fat:rw:~/Code/ \
-boot order=c \
-netdev user,id=lan \
-device rtl8139,netdev=lan \
-usb \
-device usb-tablet