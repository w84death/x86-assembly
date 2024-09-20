#!/bin/bash

# Check if an argument is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <filename_without_extension> [boot]"
    exit 1
fi

filename=$1

fasm "${filename}/${filename}.asm" "game.com"

if [ $# -eq 2 ]; then
    dd if=/dev/zero of=floppy.img bs=1474560 count=1
    fasm boot.asm boot.bin
    fasm "${filename}/${filename}.asm" "game.bin"
    dd if=boot.bin of=floppy.img bs=512 count=1 conv=notrunc
    dd if=game.bin of=floppy.img bs=512 seek=1 conv=notrunc
    qemu-system-i386 \
    -m 16 \
    -k en-us \
    -rtc base=localtime \
    -device cirrus-vga \
    -fda floppy.img
else
    qemu-system-i386 \
    -m 16 \
    -k en-us \
    -rtc base=localtime \
    -device cirrus-vga \
    -fda freedos.img \
    -drive file=fat:rw:. \
    -boot order=a
fi
