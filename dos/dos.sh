#!/bin/bash

# Check if an argument is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <filename_without_extension> [burn]"
    exit 1
fi

# Assign the argument to a variable
filename=$1

# Assemble the .asm file to .com using FASM
fasm "${filename}/${filename}.asm" "game.com"
# Check if FASM succeeded
if [ $? -ne 0 ]; then
    echo "> Assembly failed."
    exit 1
else 
    echo "> Assembly succeeded."
fi

qemu-system-i386 \
-m 16 \
-k en-us \
-rtc base=localtime \
-device cirrus-vga \
-fda freedos.img \
-drive file=fat:rw:. \
-boot order=a
