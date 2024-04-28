# x86 Assembly Programs

## Bootsector (512b) / No Operating System Games
![512 bytes image](bootsector/resources/512bytes.gif)
This image size is exactly 512 bytes. Same as the limit of bootsector programs.

## Game 1

![Game 1 Level 1](bootsector/game1/game1-level1.png)
![Game 1 Level 2](bootsector/game1/game1-level2.png)
![Game 1 Level 3](bootsector/game1/game1-level3.png)
![Game 1 Level 4](bootsector/game1/game1-level4.png)

### This is the whole game.
![Game 1 Hexdump](bootsector/game1/game1-hexdump.png)


## Game 2

![Game 2 Level 1](bootsector/game2/game2-screen1.png)
![Game 2 Level 2](bootsector/game2/game2-screen2.png)


## Download floppy image and run
- Game 1 [floppy.img](bootsector/game1/floppy.img)
- Game 2 [floppy.img](bootsector/game2/floppy.img)
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

#### Game 1 Versions
I saved few revisions on branches:
- master - current bleeding edge
- simple - a simple platformer with 4 levels
- girl-animated - 3 frame animated sprite and 1 level
- coins - coins detection and collection

![Screenshot](bootsector/resources/simple.png)
![Screenshot](bootsector/resources/girl-animated.png)