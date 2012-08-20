CC = gcc
CFLAGS = -mmacosx-version-min=10.4  -Wall -g -framework IOKit

all: smc 

smc: smc.o
	$(CC) $(CFLAGS) -o smc smc.o

smc.o: smc.h smc.c
	$(CC) -c smc.c

clean:
	-rm -f smc smc.o
