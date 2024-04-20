# x86 Assembly Programs

## Bootsector (512B) / No Operating System Games

### Prequisite for building
- QEMU (x86_64)
- NASM

### Online Tools
- https://copy.sh/v86/ - to run the game in browser (floppy.img)
- https://hexed.it/ - to examine code

### Build & Run
```
$ cd bootsector/
$ ./build-and-run.sh game
```
![Screenshot](bootsector/game/screenshot.png)

#### Game 1 Versions
I saved few revisions on branches:
- master (current bleeding edge)
- game-1-simple (simple platformer)
- girl-animated-512b (with animated sprites)
- coins (coins detection and collection)
