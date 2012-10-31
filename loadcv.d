
import std.stdio;

import codeview;
import datafile;
import debuginfo;

private:

debug=LOADCV;

void debugfln(T...)(T args)
{
    debug(LOADCV)
    {
        static if (T.length)
            writefln(args);
        else
            writeln();
    }
}

public:

void loadCodeView(DataFile f, uint lfaBase, DebugInfo di)
{
    f.seek(lfaBase);
    auto cvh = f.read!uint();
    assert(cvh == CV41_SIG, "Only CV41 is supported");
    debugfln("Found CV41 debug information");
    auto lfoDir = f.read!uint();

    f.seek(lfaBase + lfoDir);
    auto dirheader = f.read!CV_DIRHEADER();
    assert(dirheader.cbDirHeader == CV_DIRHEADER.sizeof);
    assert(dirheader.cbDirEntry == CV_DIRENTRY.sizeof);
    assert(dirheader.lfoNextDir == 0);
    assert(dirheader.flags == 0);
    debugfln("Found %d subsections", dirheader.cDir);

    foreach(i; 0..dirheader.cDir)
    {
        f.seek(lfaBase + lfoDir + CV_DIRHEADER.sizeof + CV_DIRENTRY.sizeof * i);
        auto entry = f.read!CV_DIRENTRY();
        debugfln("Entry: 0x%.4X 0x%.4X 0x%.8X 0x%.8X", entry.subsection, entry.iMod, lfaBase + entry.lfo, entry.cb);
        f.seek(lfaBase + entry.lfo);
        switch(entry.subsection)
        {
        case sstModule:
            auto ovlNumber = f.read!ushort();
            assert(ovlNumber == 0, "Overlays are not supported");
            auto iLib = f.read!ushort();
            auto cSeg = f.read!ushort();
            auto Style = f.read!ushort();
            assert(Style == ('V' << 8 | 'C'), "Only CV is supported");
            foreach(j; 0..cSeg)
            {
                auto Seg = f.read!ushort();
                auto pad = f.read!ushort();
                auto offset = f.read!uint();
                auto cbSeg = f.read!uint();
            }
            auto name = f.readPreString();
            debugfln("CV sstModule: %s", cast(string)name);
            if (iLib)
                debugfln("\tFrom lib #%d", iLib);
            di.addModule(new DebugModule(name, iLib));
            break;
        case sstSrcModule:
            debugfln("CV sstSrcModule");

            // Module header
            auto cFile = f.read!ushort();
            auto cSeg = f.read!ushort();
            debugfln("\t%d files", cFile);
            debugfln("\t%d segments", cSeg);
            auto filebase = new uint[](cFile);
            foreach(j; 0..cFile)
                filebase[j] = f.read!uint();
            auto segstart = new uint[](cSeg);
            auto segend = new uint[](cSeg);
            auto segindex = new ushort[](cSeg);
            foreach(j; 0..cSeg)
            {
                segstart[j] = f.read!uint();
                segend[j] = f.read!uint();
            }
            foreach(j; 0..cSeg)
                segindex[j] = f.read!ushort();
            f.alignto(4);

            foreach(j; 0..cSeg)
            {
                debugfln("Seg %d (%d) at 0x%.8X..0x%.8X", j, segindex[j], segstart[j], segend[j]);
            }

            // File Info
            foreach(j, fileoff; filebase)
            {
                debugfln("File %d at 0x%.8X", j, fileoff);
                f.seek(lfaBase + entry.lfo + fileoff);
                auto xcSeg = f.read!ushort();
                assert(f.read!ushort() == 0);
                auto baseSrcLn = cast(immutable uint[])f.readBytes(uint.sizeof * xcSeg);
                auto startend = cast(immutable uint[2][])f.readBytes((uint[2]).sizeof * xcSeg);
                auto name = f.readPreString();
                debugfln("\tName: %s", cast(string)name);
                debugfln("\tLine maps: %(0x%.8X, %)", baseSrcLn);
                debugfln("\tSegs: %(%(0x%.8X..%), %)", startend);

                auto s = new DebugSourceFile(name);

                foreach(k, off; baseSrcLn)
                {
                    f.seek(lfaBase + entry.lfo + off);
                    debugfln("\tLine numbers in block %d:", k);
                    auto Segi = f.read!ushort();
                    auto cPair = f.read!ushort();
                    auto offset = cast(uint[])f.readBytes(uint.sizeof*cPair);
                    auto linenum = cast(ushort[])f.readBytes(ushort.sizeof*cPair);

                    BlockInfo bi;
                    bi.segid = Segi;
                    bi.start = startend[k][0];
                    bi.end = startend[k][1];

                    foreach(l; 0..cPair)
                    {
                        debugfln("\t\t0x%.8X: %d Seg #%d", offset[l], linenum[l], Segi);
                        bi.linnums ~= LineInfo(offset[l], linenum[l]);
                    }
                    s.addBlock(bi);
                }
                di.addSourceFile(s);
            }
            break;
        case sstLibraries:
            debugfln("CV Library list:");
            auto len = f.read!ubyte();
            assert(len == 0);
            auto count = 1;
            while ((len = f.read!ubyte()) != 0)
            {
                auto name = f.readBytes(len);
                debugfln("\tLib #%d: %s", count, cast(string)name);
                count++;
                di.addLibrary(new DebugLibrary(name));
            }
            break;
        case sstGlobalPub: // List of all public symbols
            auto symhash = f.read!ushort();
            auto addrhash = f.read!ushort();
            debugfln("CV Global Public Symbols:");
            //debugfln("\tSymbol hash: 0x%.4X", symhash);
            //debugfln("\tAddress hash: 0x%.4X", addrhash);
            auto cbSymbol = f.read!uint();
            auto cbSymHash = f.read!uint();
            auto cbAddrHash = f.read!uint();
            //debugfln("\tSymbols: 0x%X bytes", cbSymbol);
            //debugfln("\tcbSymHash: 0x%X bytes", cbSymHash);
            //debugfln("\tcbAddrHash: 0x%X bytes", cbAddrHash);
            auto symstart = f.tell();
            while(f.tell() < symstart + cbSymbol)
            {
                f.alignto(4);
                loadSymbol(f, di);
            }
            assert(f.tell() == symstart + cbSymbol);
            break;
        case sstGlobalSym: // List of all non-public symbols
            debugfln("CV Global Symbols:");
            auto symhash = f.read!ushort();
            auto addrhash = f.read!ushort();
            auto cbSymbol = f.read!uint();
            auto cbSymHash = f.read!uint();
            auto cbAddrHash = f.read!uint();
            auto symstart = f.tell();
            while(f.tell() < symstart + cbSymbol)
            {
                f.alignto(4);
                loadSymbol(f, di);
            }
            assert(f.tell() == symstart + cbSymbol);
            break;
        case sstGlobalTypes:
            debugfln("CV Global Types:");
            auto flags = f.read!uint();
            assert(flags == 0x00000001);
            auto cType = f.read!uint();
            auto offType = new uint[](cType);
            foreach(j, ref off; offType)
                off = f.read!uint();
            auto typestart = f.tell();
            foreach(j, ref off; offType)
            {
                f.seek(typestart + off);
                loadType(f, di);
            }
            break;
        case sstFileIndex:
            debugfln("CV File Index:");
            debugfln("%.8X", f.tell());
            auto cMod = f.read!ushort();
            auto cRef = f.read!ushort();
            auto ModStart = cast(ushort[])f.readBytes(ushort.sizeof * cMod);
            auto cRefCnt = cast(ushort[])f.readBytes(ushort.sizeof * cMod);
            auto NameRef = cast(uint[])f.readBytes(uint.sizeof * cRef);
            auto nametable = f.tell();
            foreach(j; 0..cMod)
            {
                debugfln("\tModule %d:", j+1);
                auto p = ModStart[j];
                foreach(k; 0..cRefCnt[j])
                {
                    f.seek(nametable + NameRef[p + k]);
                    auto name = f.readPreString();
                    debugfln("\t\tSourcefile: %s", cast(string)name);
                }
            }
            break;
        case sstSegMap:
            debugfln("CV Segment Map:");
            auto cSeg = f.read!ushort();
            auto cSegLog = f.read!ushort();
            auto SegDesc = new CV_SEGDESC[](cSegLog);
            debugfln("\tcSeg: %d", cSeg);
            debugfln("\tcSegLog: %d", cSegLog);
            foreach(j, ref v; SegDesc)
                v = f.read!CV_SEGDESC();
            foreach(j, ref v; SegDesc)
            {
                debugfln("\tSegment %d:", j+1);
                debugfln("\t\tFlags: 0x%.4X", v.flags);
                debugfln("\t\tOverlay: %d", v.ovl);
                debugfln("\t\tGroup: %d", v.group);
                debugfln("\t\tFrame: %d", v.frame);
                debugfln("\t\tSeg name: 0x%.4X", v.iSegName);
                debugfln("\t\tClass name: 0x%.4X", v.iClassName);
                debugfln("\t\tOffset: 0x%.8X", v.offset);
                debugfln("\t\tLength: 0x%.8X", v.cbseg);
                assert(v.ovl == 0);
                assert(v.iClassName == 0xFFFF);
                assert(v.offset == 0);
                auto fRead = (v.flags & 0x1) != 0;
                auto fWrite = (v.flags & 0x2) != 0;
                auto fExecute = (v.flags & 0x4) != 0;
                auto f32Bit = (v.flags & 0x8) != 0;
                auto fSel = (v.flags & 0x100) != 0;
                auto fAbs = (v.flags & 0x200) != 0;
                auto fGroup = (v.flags & 0x1000) != 0;
                assert(f32Bit && fSel && !fAbs && !fGroup);
                di.addSegment(new DebugSegment(v.cbseg));
            }
            break;
        case sstSegName:
            debugfln("CV Segment Names:");
            auto count = 0;
            while (f.tell() < lfaBase + entry.lfo + entry.cb)
            {
                count++;
                auto name = f.readZString();
                debugfln("\tSegment %d: %s", count, cast(string)name);
                di.setSegmentName(count, name);
            }
            break;
        case sstAlignSym:
            debugfln("CV Aligned Symbols:");
            auto sig = f.read!uint();
            assert(sig == 0x00000001);
            while(f.tell() < lfaBase + entry.lfo + entry.cb)
            {
                f.alignto(4);
                loadSymbol(f, di);
            }
            break;
        case sstStaticSym:
            debugfln("CV Static Symbol:");
            break;
        default:
            debugfln("Unhandled CV subsection type 0x%.3X", entry.subsection);
            assert(0);
        }
    }
}

void loadSymbol(DataFile f, DebugInfo di)
{
    auto len = f.read!ushort();
    auto symtype = f.read!ushort();
    f.seek(f.tell() + len - 2);
}

void loadType(DataFile f, DebugInfo di)
{
}

version(none):

void dumpSymbol(ref File of, DataFile f)
{
    auto len = f.read!ushort();
    auto symtype = f.read!ushort();
    switch (symtype)
    {
    case S_PUB32:
        of.writeln("Symbol: S_PUB32");
        auto offset = f.read!uint();
        auto segment = f.read!ushort();
        auto type = f.read!ushort();
        auto name = f.readPreString();
        of.writefln("Seg %.4X + 0x%.8X: %s (%d)", segment, offset, cast(string)name, type);
        break;
    case S_ALIGN:
        of.writeln("Symbol: S_ALIGN");
        f.seek(f.tell() + len - 2);
        break;
    case S_PROCREF:
        of.writeln("Symbol: S_PROCREF");
        auto checksum = f.read!uint();
        auto offset = f.read!uint();
        auto mod = f.read!ushort();
        of.writefln("\tChecksum: 0x%.8X", checksum);
        of.writefln("\tOffset: 0x%.8X", offset);
        of.writefln("\tModule: 0x%.4X", mod);
        break;
    case S_UDT:
        of.writeln("Symbol: S_UDT");
        auto type = f.read!ushort();
        auto name = f.readPreString();
        of.writefln("\tName: %s", cast(string)name);
        of.writefln("\tType: %s", decodeCVType(type));
        break;
    case S_SSEARCH:
        of.writeln("Symbol: S_SSEARCH");
        auto offset = f.read!uint();
        auto seg = f.read!ushort();
        of.writefln("\tOffset: 0x%.8X", offset);
        of.writefln("\tSegment: 0x%.4X", seg);
        break;
    case S_COMPILE:
        of.writeln("Symbol: S_COMPILE");
        auto flags = f.read!uint();
        auto machine = flags & 0xFF;
        flags >>= 8;
        auto verstr = f.readPreString();
        of.writefln("\tMachine: 0x%.2X", machine);
        of.writefln("\tFlags: 0x%.6X", flags);
        of.writefln("\tVersion: %s", cast(string)verstr);
        break;
    case S_GPROC32:
        of.writeln("Symbol: S_GPROC32");
        auto pParent = f.read!uint();
        auto pEnd = f.read!uint();
        auto pNext = f.read!uint();
        auto proclen = f.read!uint();
        auto debugstart = f.read!uint();
        auto debugend = f.read!uint();
        auto offset = f.read!uint();
        auto segment = f.read!ushort();
        auto proctype = f.read!ushort();
        auto flags = f.read!ubyte();
        auto name = f.readPreString();
        of.writefln("\tParent scope: 0x%.8X", pParent);
        of.writefln("\tEnd of scope: 0x%.8X", pEnd);
        of.writefln("\tNext scope: 0x%.8X", pNext);
        of.writefln("\tLength: 0x%.8X", proclen);
        of.writefln("\tDebug Star: 0x%.8X", debugstart);
        of.writefln("\tDebug End: 0x%.8X", debugend);
        of.writefln("\tOffset: 0x%.8X", offset);
        of.writefln("\tSegment: 0x%.4X", segment);
        of.writefln("\tType: %s", decodeCVType(proctype));
        of.writefln("\tFlags: 0x%.2X", flags);
        of.writefln("\tName: %s", cast(string)name);
        break;
    case S_BPREL32:
        of.writeln("Symbol: S_BPREL32");
        auto offset = f.read!uint();
        auto type = f.read!ushort();
        auto name = f.readPreString();
        of.writefln("\tName: %s", cast(string)name);
        of.writefln("\tType: %s", decodeCVType(type));
        of.writefln("\tOffset: 0x%.8X", offset);
        break;
    case S_RETURN:
        of.writeln("Symbol: S_RETURN");
        auto flags = f.read!ushort();
        auto style = f.read!ubyte();
        switch(style)
        {
        case 0x00:
            of.writefln("\tvoid return");
            break;
        case 0x01:
            of.writefln("\treg return");
            auto cReg = f.read!ubyte();
            foreach(i; 0..cReg)
                of.writefln("\tReg: 0x%.2X", f.read!ubyte());
            break;
        default:
            break;
        }
        break;
    case S_END:
        of.writeln("Symbol: S_END");
        break;
    case S_LDATA32:
        of.writeln("Symbol: S_LDATA32");
        auto offset = f.read!uint();
        auto segment = f.read!ushort();
        auto type = f.read!ushort();
        auto name = f.readPreString();
        of.writefln("\tName: %s", cast(string)name);
        of.writefln("\tType: %s", decodeCVType(type));
        of.writefln("\tSegment: 0x%.4X", segment);
        of.writefln("\tOffset: 0x%.8X", offset);
        break;
    case S_ENDARG:
        of.writeln("Symbol: S_ENDARG");
        break;
    case S_GDATA32:
        of.writeln("Symbol: S_GDATA32");
        auto offset = f.read!uint();
        auto segment = f.read!ushort();
        auto type = f.read!ushort();
        auto name = f.readPreString();
        of.writefln("\tName: %s", cast(string)name);
        of.writefln("\tType: %s", decodeCVType(type));
        of.writefln("\tSegment: 0x%.4X", segment);
        of.writefln("\tOffset: 0x%.8X", offset);
        break;

    case S_REGISTER:
        of.writeln("Symbol: S_REGISTER");
        assert(0);
    case S_CONSTANT:
        of.writeln("Symbol: S_CONSTANT");
        assert(0);
    case S_SKIP:
        of.writeln("Symbol: S_SKIP");
        assert(0);
    case S_CVRESERVE:
        of.writeln("Symbol: S_CVRESERVE");
        assert(0);
    case S_OBJNAME:
        of.writeln("Symbol: S_OBJNAME");
        assert(0);
    case S_COBOLUDT:
        of.writeln("Symbol: S_COBOLUDT");
        assert(0);
    case S_MANYREG:
        of.writeln("Symbol: S_MANYREG");
        assert(0);
    case S_ENTRYTHIS:
        of.writeln("Symbol: S_ENTRYTHIS");
        assert(0);

    case S_LPROC32:
        of.writeln("Symbol: S_LPROC32");
        assert(0);
    case S_THUNK32:
        of.writeln("Symbol: S_THUNK32");
        assert(0);
    case S_BLOCK32:
        of.writeln("Symbol: S_BLOCK32");
        assert(0);
    case S_VFTPATH32:
        of.writeln("Symbol: S_VFTPATH32");
        assert(0);
    case S_REGREL32:
        of.writeln("Symbol: S_REGREL32");
        assert(0);
    case S_LTHREAD32:
        of.writeln("Symbol: S_LTHREAD32");
        assert(0);
    case S_GTHREAD32:
        of.writeln("Symbol: S_GTHREAD32");
        assert(0);

    case S_DATAREF:
        of.writeln("Symbol: S_DATAREF");
        assert(0);

    case S_BPREL16:
    case S_LDATA16:
    case S_GDATA16:
    case S_PUB16:
    case S_LPROC16:
    case S_GPROC16:
    case S_THUNK16:
    case S_BLOCK16:
    case S_WITH16:
    case S_LABEL16:
    case S_CEXMODEL16:
    case S_VFTPATH16:
    case S_REGREL16:
    case S_LPROCMIPS:
    case S_GPROCMIPS:
        assert(0, "Unsupported Symbol type: 0x" ~ to!string(symtype, 16));
        break;
    default:
        assert(0, "Unknown Symbol type: 0x" ~ to!string(symtype, 16));
        break;
    }
}

void dumpType(ref File of, DataFile f)
{
    auto len = f.read!ushort();
    of.writeln("Type:");
    auto start = f.tell();
    while (f.tell() < start + len)
    {
        dumpTypeLeaf(of, f);
    }
}

void dumpTypeLeaf(ref File of, DataFile f)
{
    auto type = f.read!ushort();
    switch (type)
    {
    case LF_ARGLIST:
        of.writeln("\tLF_ARGLIST");
        auto count = f.read!ushort();
        of.writefln("\t\t%d args", count);
        foreach(i; 0..count)
        {
            auto typind = f.read!ushort();
            of.writefln("\t\t%s", decodeCVType(typind));
        }
        break;

    case LF_PROCEDURE:
        of.writeln("\tLF_PROCEDURE");
        auto rettype = f.read!ushort();
        auto cc = f.read!ubyte();
        auto reserved = f.read!ubyte();
        auto argcount = f.read!ushort();
        auto arglist = f.read!ushort();
        of.writefln("\t\tReturn type: %s", decodeCVType(rettype));
        of.writefln("\t\tCalling convention: %d", cc);
        of.writefln("\t\tArg count: %d", argcount);
        of.writefln("\t\tArg list: %s", decodeCVType(arglist));
        break;

    case LF_FIELDLIST:
        of.writeln("\tLF_FIELDLIST");
        while ((f.peek!ushort() & 0xFF00) == 0x0400) dumpFieldLeaf(of, f);
        break;

    case LF_STRUCTURE:
    case LF_CLASS:
        if (type == LF_STRUCTURE)
            of.writeln("\tLF_STRUCTURE");
        else
            of.writeln("\tLF_CLASS");
        auto count = f.read!ushort();
        auto ftype = f.read!ushort();
        auto prop = f.read!ushort();
        auto dlist = f.read!ushort();
        auto vtbl = f.read!ushort();
        auto length = f.read!ushort();
        auto name = f.readPreString();
        of.writefln("\t\tName: %s", cast(string)name);
        of.writefln("\t\tMembers: %d", count);
        of.writefln("\t\tFields: %s", decodeCVType(ftype));
        of.writefln("\t\tProperties: %.4X", prop);
        of.writefln("\t\tDerived: %s", decodeCVType(dlist));
        of.writefln("\t\tVtbl: %s", decodeCVType(vtbl));
        of.writefln("\t\tsizeof: %d", length);
        break;

    case LF_POINTER:
        of.writeln("\tLF_POINTER");
        auto attr = f.read!ushort();
        auto ptype = f.read!ushort();
        of.writefln("\t\ttype: %s", decodeCVType(ptype));
        of.writefln("\t\tattr: %.4X", attr);
        auto size = attr & 0x1F;
        assert(size == 0xA);
        auto ptrmode = (attr >> 5) & 0x3;
        switch(ptrmode)
        {
        case 0:
            of.writefln("\t\tmode: pointer");
            break;
        case 1:
            of.writefln("\t\tmode: reference");
            break;
        default:
            assert(0);
        }
      break;

    case LF_MODIFIER:
        of.writeln("\tLF_MODIFIER");
        auto attr = f.read!ushort();
        auto ptype = f.read!ushort();
        of.writefln("\t\ttype: %s", decodeCVType(ptype));
        of.writefln("\t\tattr:%s%s%s", (attr & 0x1) ? " const" : "", (attr & 0x2) ? " volatile" : "", (attr & 0x4) ? " unaligned" : "");
        break;

    case LF_OEM:
        of.writeln("\tLF_OEM");
        auto OEMid = f.read!ushort();
        auto recOEM = f.read!ushort();
        auto count = f.read!ushort();
        auto indices = cast(ushort[])f.readBytes(ushort.sizeof * count);
        of.writefln("\t\tOEM id: 0x%.4X", OEMid);
        of.writefln("\t\ttype id: 0x%.4X", recOEM);
        foreach(ind; indices)
            of.writefln("\t\tsubtype: %s", decodeCVType(ind));
        break;

    case LF_ARRAY:
        of.writeln("\tLF_ARRAY");
        auto etype = f.read!ushort();
        auto itype = f.read!ushort();
        auto length = f.read!ushort();
        auto name = f.readPreString();
        of.writefln("\t\tName: %s", name);
        of.writefln("\t\tElement type: %s", decodeCVType(etype));
        of.writefln("\t\tIndex type: %s", decodeCVType(itype));
        of.writefln("\t\tLength: %d", length);
        break;

    case LF_MFUNCTION:
        of.writeln("\tLF_MFUNCTION");
        auto rvtype = f.read!ushort();
        auto classt = f.read!ushort();
        auto thist = f.read!ushort();
        auto cc = f.read!ubyte();
        f.read!ubyte();
        auto parms = f.read!ushort();
        auto arglist = f.read!ushort();
        auto thisadjust = f.read!uint();
        of.writefln("\t\tReturn type: %s", decodeCVType(rvtype));
        of.writefln("\t\tClass type: %s", decodeCVType(classt));
        of.writefln("\t\tThis type: %s", decodeCVType(thist));
        of.writefln("\t\tCalling convention: %d", cc);
        of.writefln("\t\tParams: %d", parms);
        of.writefln("\t\tArgs: %s", decodeCVType(arglist));
        of.writefln("\t\tThis adjust: 0x%.8X", thisadjust);
        break;

    case LF_UNION:
    case LF_ENUM:
    case LF_VTSHAPE:
    case LF_COBOL0:
    case LF_COBOL1:
    case LF_BARRAY:
    case LF_LABEL:
    case LF_NULL:
    case LF_NOTTRAN:
    case LF_DIMARRAY:
    case LF_VFTPATH:
    case LF_PRECOMP:
    case LF_ENDPRECOMP:

    case LF_SKIP:
    case LF_DEFARG:
    case LF_LIST:
    case LF_DERIVED:
    case LF_BITFIELD:
    case LF_MLIST:
    case LF_DIMCONU:
    case LF_DIMCONLU:
    case LF_DIMVARU:
    case LF_DIMVARLU:
    case LF_REFSYM:

    case LF_BCLASS:
    case LF_VBCLASS:
    case LF_IVBCLASS:
    case LF_ENUMERATE:
    case LF_FRIENDFCN:
    case LF_INDEX:
    case LF_MEMBER:
    case LF_STMEMBER:
    case LF_METHOD:
    case LF_NESTTYPE:
    case LF_VFUNCTAB:
    case LF_FRIENDCLS:
    case LF_ONEMETHOD:
    case LF_VFUNCOFF:

    case LF_CHAR:
    case LF_SHORT:
    case LF_USHORT:
    case LF_LONG:
    case LF_ULONG:
    case LF_REAL32:
    case LF_REAL64:
    case LF_REAL80:
    case LF_REAL128:
    case LF_QUADWORD:
    case LF_UQUADWORD:
    case LF_REAL48:
    case LF_COMPLEX32:
    case LF_COMPLEX64:
    case LF_COMPLEX80:
    case LF_COMPLEX128:
    case LF_VARSTRING:

    case LF_PAD0:
    case LF_PAD1:
    case LF_PAD2:
    case LF_PAD3:
    case LF_PAD4:
    case LF_PAD5:
    case LF_PAD6:
    case LF_PAD7:
    case LF_PAD8:
    case LF_PAD9:
    case LF_PAD10:
    case LF_PAD11:
    case LF_PAD12:
    case LF_PAD13:
    case LF_PAD14:
    case LF_PAD15:
        assert(0, "Unsupported CV4 Type: 0x" ~ to!string(type, 16));
    default:
        assert(0, "Unknown CV4 Type: 0x" ~ to!string(type, 16));
    }
}

void dumpFieldLeaf(ref File of, DataFile f)
{
    auto type = f.read!ushort();
    switch (type)
    {
    case LF_MEMBER:
        auto ftype = f.read!ushort();
        auto attrib = decodeAttrib(f.read!ushort());
        auto offset = f.read!ushort();
        auto name = f.readPreString();
        of.writefln("\t\tMember: %s (+%s) (%s)", cast(string)name, offset, attrib);
        break;
    default:
        assert(0, "Unknown CV4 Field Type: 0x" ~ to!string(type, 16));
    }
    auto fix = f.peek!ubyte();
    if (fix > 0xF0)
        f.seek(f.tell() + (fix & 0xF));
}

string decodeAttrib(ushort attrib)
{
    return "<<attrib>>";
}

string decodeCVType(ushort typeind)
{
    if ((typeind & 0xF000) != 0)
        return format("0x%.4X", typeind);

    auto mode = (typeind >> 8) & 0x7;
    auto type = (typeind >> 4) & 0xF;
    auto size = typeind & 0x7;

    assert(mode == 0 || mode == 2 || mode == 4, "Unknown CV4 type mode: 0x" ~ to!string(mode, 16));
    auto pointer = (mode != 0) ? " *" : "";
    switch (type)
    {
    case 0x00:
        switch (size)
        {
        case 0x00: return "No type";
        case 0x03: return "void" ~ pointer;
        default: assert(0);
        }
    case 0x01:
        switch (size)
        {
        case 0x00: return "byte" ~ pointer;
        case 0x01: return "short" ~ pointer;
        case 0x02: return "c_long" ~ pointer;
        case 0x03: return "long" ~ pointer;
        default: assert(0);
        }
    case 0x02:
        switch (size)
        {
        case 0x00: return "ubyte" ~ pointer;
        case 0x01: return "ushort" ~ pointer;
        case 0x02: return "c_ulong" ~ pointer;
        case 0x03: return "ulong" ~ pointer;
        default: assert(0);
        }
    case 0x03:
        switch (size)
        {
        case 0x00: return "bool" ~ pointer;
        default: assert(0);
        }
    case 0x04:
        switch (size)
        {
        case 0x00: return "float" ~ pointer;
        case 0x01: return "double" ~ pointer;
        case 0x02: return "real" ~ pointer;
        default: assert(0);
        }
    case 0x05:
        switch (size)
        {
        case 0x00: return "cfloat" ~ pointer;
        case 0x01: return "cdouble" ~ pointer;
        case 0x02: return "creal" ~ pointer;
        default: assert(0);
        }
    case 0x06:
        assert(0);
    case 0x07:
        switch (size)
        {
        case 0x00: return "char" ~ pointer;
        case 0x01: return "wchar" ~ pointer;
        case 0x04: return "int" ~ pointer;
        case 0x05: return "uint" ~ pointer;
        default: assert(0);
        }
    default:
        assert(0, "Unknown CV4 type: 0x" ~ to!string(type, 16));
    }
}
