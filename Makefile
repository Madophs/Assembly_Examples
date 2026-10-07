.PHONY: clean examples all lib

AS:=as
AS_FLAGS:=-g
ASM_SRC:=$(wildcard src/core/*.s src/gc/*.s)
ASM_OBJ:=$(ASM_SRC:%.s=%.o)
C_SRC:=$(wildcard examples/*.c)
C_BIN:=$(C_SRC:%.c=%.out)
PROJ_ROOT:=$(shell git rev-parse --show-toplevel)
_MKDIRS:=$(shell mkdir -p build/lib)
_EXPORT:=$(shell export LD_LIBRARY_PATH=$(PROJ_ROOT)/build/lib)

all: $(ASM_OBJ)

%.o: %.s
	gcc -fPIC -c -o $@ $<

lib: $(ASM_OBJ)
	gcc -shared $(ASM_OBJ) -o build/lib/libgnumds.so

examples:$(C_BIN)

$(C_BIN):$(C_SRC)

%.out: %.c
	gcc -L build/lib -lgnumds -Wl,--library-path build/lib -o $@ $<

clean:
	@rm -f src/core/*.o src/gc/*.o
	@rm -f build/lib/*
	@rm -f examples/*.out
