YLINK=ylink.exe
SRC=ylink.d coffdef.d datafile.d linker.d modules.d objectfile.d omfdef.d omflibraryfile.d omfobjectfile.d paths.d pe.d relocation.d section.d sectiontable.d segment.d symbol.d symboltable.d workqueue.d

DEBLINK=deblink.exe
DEBLINKSRC=deblink.d windebug.d x86dis.d

DEBDUMP=debdump.exe
DEBDUMPSRC=debdump.d x86dis.d

TESTOBJ=testc.obj

MAP2SYM=map2sym.exe
MAP2SYMSRC=map2sym.d

#DEBUGFLAGS=-debug=fixup -debug=OMFDATA
DEBUGFLAGS=-debug=OMFDEBUG -debug=OMFDATA
#DEBUGFLAGS=

default: test

$(YLINK): $(SRC)
	dmd -of$(YLINK) $(SRC) $(DEBUGFLAGS)

$(DEBLINK): $(DEBLINKSRC)
	dmd -of$(DEBLINK) $(DEBLINKSRC) psapi.lib

$(DEBDUMP): $(DEBDUMPSRC)
	dmd -of$(DEBDUMP) $(DEBDUMPSRC)

$(MAP2SYM): $(MAP2SYMSRC)
	dmd -of$(MAP2SYM) $(MAP2SYMSRC)

testc.obj: testc.c
	dmc -c testc.c -g

testd.obj: testd.d
	dmd -c testd.d -g

testd.exe testd.map: $(TESTOBJ)
	link /MAP $(TESTOBJ),testd.exe

teste.exe teste.map: $(TESTOBJ) $(YLINK)
	$(YLINK) $(TESTOBJ) -o teste.exe -m

testd.sym: testd.map $(MAP2SYM)
	$(MAP2SYM) testd.map testd.sym

teste.sym: teste.map
	copy teste.map teste.sym

p0.txt p1.txt: $(YLINK) $(DEBLINK) testd.exe teste.exe testd.sym teste.sym
	$(DEBLINK)

test: $(DEBDUMP) p0.txt p1.txt
	debdump

clean:
	-del *.exe
	-del *.obj
	-del *.txt
