CXX=g++
CXXFLAGS=-Wall -O3 -funroll-loops -finline-functions -march=i586 -mcpu=i686

VERSION=1.0.0
DISTNAME=openkore-$(VERSION)
DISTFILES=DevelopersNotes.txt Inject.cpp Tools.cpp Makefile Makefile.win32\
	Inject.def Tools.def openkore.pl functions.pl

.PHONY: all clean dist distdir

all: Tools.so

Tools.so: Tools.cpp
	$(CXX) -shared -fPIC $(CXXFLAGS) Tools.cpp -o Tools.so

distdir:
	rm -rf $(DISTNAME)
	mkdir $(DISTNAME)
	cp $(DISTFILES) $(DISTNAME)/

dist: distdir
	tar -czf $(DISTNAME).tar.gz $(DISTNAME)
	rm -rf $(DISTNAME)

clean:
	rm -f Tools.so $(DISTNAME.zip)
