!#/bin/bash
qemu-system-i386 \
-m 16 \
-k en-us \
-rtc base=localtime \
-device cirrus-vga \
-display gtk \
-hda ~/OS/dos.img \
-drive file=fat:rw:~/Code/ \
-boot order=c
