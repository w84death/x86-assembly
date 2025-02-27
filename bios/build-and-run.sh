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

dd if=/dev/zero of=floppy.img bs=1474560 count=1

if ! fasm ${filename}/boot.asm temp/boot.bin; then
    echo "Failed to assemble boot.asm"
    exit 1
fi

if ! fasm "${filename}/${filename}.asm" "temp/game.bin"; then
    echo "Failed to assemble ${filename}/${filename}.asm"
    exit 1
fi

if ! fasm "${filename}/${filename}.asm" "${filename}/com/game.com"; then
    echo "Failed to assemble ${filename}/${filename}.asm"
    exit 1
fi

echo ""
echo "=========================="
echo "GAME CODE SIZE: $(stat -c %s temp/game.bin) bytes"
echo "=========================="

echo ""
echo "Creating floppy image..."
dd if=temp/boot.bin of=floppy.img bs=512 count=1 conv=notrunc
dd if=temp/game.bin of=floppy.img bs=512 seek=1 conv=notrunc

cp floppy.img "${filename}/${filename}_floppy.img"

echo ""
echo "Running..."
# qemu-system-i386 \
# -m 1 \
# -k en-us \
# -rtc base=localtime \
# -vga std \
# -cpu 486 \
# -boot a \
# -fda floppy.img

# dosemu "${filename}/com/game.com"
dosbox-x "${filename}/com/game.com"