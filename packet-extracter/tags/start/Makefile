CC=gcc
CFLAGS=-Wall -O2 -march=i686 -mcpu=i586 -fexpensive-optimizations -funroll-loops -finline-functions
SRC=decoder.c ieee.c main.c pedump.c print.c debug.c
OBJ=decoder.o ieee.o main.o pedump.o print.o debug.o

.PHONY: clean

disasm: $(SRC) $(OBJ)
	$(CC) $(OBJ) -o disasm

clean:
	rm -f $(OBJ) disasm
