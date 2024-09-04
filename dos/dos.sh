!#/bin/bash
qemu-system-i386 \
-m 16 \
-k en-us \
-rtc base=localtime \
-device cirrus-vga \
-hda ~/OS/freedos.img \
-drive file=fat:rw:~/Code/ \
-boot order=c
