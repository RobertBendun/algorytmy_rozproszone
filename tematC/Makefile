CXX=clang++
Flags=-Wall -Wextra -O3 -std=c++20
Sfml=-lsfml-graphics -lsfml-window -lsfml-network -lsfml-system

audio-chat: audio-chat.cc
	$(CXX) $(Flags) $(Sfml) -o $@ $<

build:
	mkdir build

build/*.o: *.cc build
	$(CXX) $(Flags) -o $@ $<


.PHONY: clean
clean:
	[ -e build ] && rmdir build
