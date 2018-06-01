# Related directories, over-written in Run.sh
OUTDIR     := .
CDIR       := .
CPPDIR     := .
SACDIR     := /opt/sac

# Compile parameters & dirs, some could be overwritten in Run.sh
# Notice: the order of library names in LIBS could matter.
CPPCOMP    := c++ -std=c++14 -Wall -fPIC
INCDIR     := -I. -I$(CDIR) -I$(CPPDIR) -I$(SACDIR)/include -I/usr/include -I/opt/local/include
LIBDIR     := -L. -L$(CDIR) -L$(SACDIR)/lib -L/usr/local/lib64 -L/opt/local/lib
LIBS       := -lASU_tools -lsac -lsacio -lm

# all source files
CPPFILES   := $(wildcard *.cpp)
CPPDEPS    := $(patsubst %.cpp, $(OUTDIR)/%.d, $(CPPFILES))
CPPOBJS    := $(patsubst %.d, %.o, $(CPPDEPS))

# main files
CPPMAINS   := $(filter-out %.fun.cpp, $(CPPFILES))
CPPEXES    := $(patsubst %.cpp, $(OUTDIR)/%.out, $(CPPMAINS))

all: $(CPPEXES) $(CPPOBJS)
	@echo > /dev/null

# Resolve dependencies automatically.
-include $(CDEPS) $(CPPDEPS)

%.out: %.o $(CDIR)/libASU_tools.a
	@echo "Updating: $@ ..."
	@$(CPPCOMP) -o $@ $^ $(INCDIR) $(LIBDIR) $(LIBS)

$(OUTDIR)/%.o: %.cpp
	@$(CPPCOMP) -MD -MP -c $< -o $@ $(INCDIR)

clean:
	@rm -f $(OUTDIR)/*out $(OUTDIR)/*o $(OUTDIR)/*.d
