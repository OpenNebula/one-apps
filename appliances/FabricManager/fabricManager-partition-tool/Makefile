IDIR := /usr/include
CXXFLAGS = -I$(IDIR)

LDIR := /usr/lib
LDFLAGS = -L$(LDIR) -lnvfm

partitioner: partitioner.o
	$(CXX) -o $@ $< $(LDFLAGS)

partitioner.o: partitioner.cpp
	$(CXX) -c $< $(CXXFLAGS)

clean:
	rm -f partitioner.o partitioner