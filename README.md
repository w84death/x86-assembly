# x86 Assembly Programs

## DOS (1Kb)
Programs up to 1Kb (1024b) for DOS. FreeDOS and MS-DOS, COM files.
Mouse driver required.

## Bootsector (512b) / No Operating System Games
![512 bytes image](bootsector/resources/512bytes.gif)
This image size is exactly 512 bytes. Same as the limit of bootsector programs.

### Prequisite for building
- QEMU (x86_64)
- NASM
- FASM (for newer productions)
### Build & Run
```
$ cd bootsector/
$ ./build-and-run.sh game1
```