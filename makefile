CC		= g++

#CC		= g++-mp-4.6

INCDIR		= /usr/local/include
#INCDIR		= /opt/local/include

#CFLAGS		= -std=c++0x -Wall \

CFLAGS		= -Wall \
		-I/$(INCDIR) \
		-I.

OBJS		= $(SRCS:.c=.o)


PROGRAM		= usage.exe list-test.exe equal-test.exe

all:	$(PROGRAM)


%.exe: %.cpp
	$(CC) $(CFLAGS) $(LDFLAGS) $(LIBS) -o $@ $<


####freebsd ver
#.SUFFIXES: .exe .cpp
#.cpp.exe:
#	$(CC) $(CFLAGS) $(LDFLAGS) $(LIBS) -o $@ $<




usage.exe : usage.cpp


