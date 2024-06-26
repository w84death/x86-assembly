# x86 Assembly Programs

## Bootsector (512b) / No Operating System Games
![512 bytes image](bootsector/resources/512bytes.gif)
This image size is exactly 512 bytes. Same as the limit of bootsector programs.

## Game 1 - Land Me
[Land Me Homepage](bootsector/game1/)

![Game 1 Level 1](bootsector/game1/game1-level1.png)

## Game 2 - Ganja Farmer 512b
[Ganja Farmer 512b Home Page](bootsector/game2/)

![Game 2 Level 1](bootsector/game2/game2-screen1.png)

## Download floppy image and run
- Game 1 [floppy.img](bootsector/game1/floppy.img)
- Game 2 [floppy.img](bootsector/game2/floppy.img)
- Run in emulator (online) https://copy.sh/v86/ or boot on real hardware (x86)
- Examine image in https://hexed.it/

## Game 3 - Fly Escape
[Fly Escape Home Page](bootsector/game3/)

![Game 3 Level 1](bootsector/game3/screen1.gif)

## Download floppy image and run
- Game 1 [floppy.img](bootsector/game1/floppy.img)
- Game 2 [floppy.img](bootsector/game2/floppy.img)
- Game 3 [floppy.img](bootsector/game3/floppy.img)
- Run in emulator (online) https://copy.sh/v86/ or boot on real hardware (x86)
- Examine image in https://hexed.it/

### Prequisite for building
- QEMU (x86_64)
- NASM

### Build & Run
```
$ cd bootsector/
$ ./build-and-run.sh game1
```