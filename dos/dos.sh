#!/bin/bash
echo ""
echo "============================"
echo ">>> P1X ASM BUILD SCRIPT <<<"
echo "============================"
echo ""

if [ $# -eq 0 ]; then
    echo "Usage: $0 <filename_without_extension>"
    exit 1
fi

filename=$1

echo "Assembling..."

    if ! fasm "${filename}/${filename}.asm" "game.com"; then
        echo "Failed to assemble ${filename}/${filename}.asm"
        exit 1
    fi
    
    qemu-system-i386 \
    -m 16 \
    -k en-us \
    -rtc base=localtime \
    -device cirrus-vga \
    -fda freedos.img \
    -drive file=fat:rw:. \
    -cpu 486 \
    -boot order=a

