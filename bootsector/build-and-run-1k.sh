#!/bin/bash

# Check if an argument is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <filename_without_extension> [burn]"
    exit 1
fi

# Assign the argument to a variable
filename=$1

# Assemble the .asm file to .bin using NASM
nasm -f bin "${filename}/${filename}a.asm" -o "${filename}/${filename}a.bin"

# Check if NASM succeeded
if [ $? -ne 0 ]; then
    echo "> Side A -> Assembly failed."
    exit 1
else 
    echo "> Side A -> Assembly succeeded."
fi

nasm -f bin "${filename}/${filename}b.asm" -o "${filename}/${filename}b.bin"
# Check if NASM succeeded
if [ $? -ne 0 ]; then
    echo "> Side B -> Assembly failed."
    exit 1
else 
    echo "> Side B -> Assembly succeeded."
fi

# Write the first sector to the floppy image
dd if=${filename}/${filename}a.bin of=${filename}/floppy.img bs=512 count=1 conv=notrunc

# Write the second sector to the floppy image at the second sector (offset 512 bytes)
dd if=${filename}/${filename}b.bin of=${filename}/floppy.img bs=512 seek=1 conv=notrunc

# Check if QEMU exited successfully
if [ $? -ne 0 ]; then
    echo "> Creating floppy failed."
    exit 1
else
    echo "> Creating floppy succeeded."
fi


qemu-system-i386 -fda ${filename}/floppy.img
# qemu-system-i386 -drive format=raw,file="${filename}/${filename}.bin"
