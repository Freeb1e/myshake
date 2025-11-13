.PHONY: all clean
ADDR=0
all: input_gen
input_gen:input_gen.cpp
	g++ -o input_gen input_gen.cpp

run: input_gen
	./input_gen
clean:
	rm -f input_gen