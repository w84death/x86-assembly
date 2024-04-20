# x86 Assembly Programs

## Bootsector (512b) / No Operating System Games
![512 bytes image](bootsector/resources/512bytes.gif)
This image size is exactly 512 bytes. Same as the limit of bootsector programs.


### Prequisite for building
- QEMU (x86_64)
- NASM

### Online Tools
- https://copy.sh/v86/ - to run the game in browser (use [main.img](bootsector/floppies/main.img), [simple.img](bootsector/floppies/simple.img) or [girl-animated.img](bootsector/floppies/girl-animated.img) floppy images)
- https://hexed.it/ - to examine binary

### Build & Run
```
$ cd bootsector/
$ ./build-and-run.sh game
```
![Screenshot](bootsector/resources/game-main.png)

#### Game 1 Versions
I saved few revisions on branches:
- master - current bleeding edge
- simple - a simple platformer with 4 levels
- girl-animated - 3 frame animated sprite and 1 level
- coins - coins detection and collection

![Screenshot](bootsector/resources/simple.png)
![Screenshot](bootsector/resources/girl-animated.png)