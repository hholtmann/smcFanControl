CC = gcc
CFLAGS = -mmacosx-version-min=10.4  -Wall -g -framework IOKit
CPPFLAGS = -DCMD_TOOL_BUILD

all: smc 

smc: smc.o
	$(CC) $(CFLAGS) -o smc smc.o

smc.o: smc.h smc.c
	$(CC) $(CPPFLAGS) -c smc.c

clean:
	-rm -f smc smc.o
