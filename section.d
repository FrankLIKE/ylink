
import std.algorithm;
import std.stdio;

import segment;

enum SectionClass
{
    Code,
    Data,
    Const,
    BSS,
    ENDBSS,
    TLS,
    STACK,
    DEBSYM,
    DEBTYP,
    // generated
    IData,
}

enum SectionAlign
{
    align_1 = 1,
    align_2 = 2,
    align_4 = 4,
    align_16 = 16,
    align_page = 4096,
}

final class CombinedSection
{
    immutable(ubyte)[] name;
    immutable(ubyte)[] tag;
    SectionClass secclass;
    Section[] members;
    Segment seg;
    uint length;
    SectionAlign secalign = SectionAlign.align_1;

    this(immutable(ubyte)[] name, immutable(ubyte)[] tag, SectionClass secclass)
    {
        this.name = name;
        this.tag = tag;
        this.secclass = secclass;
    }
    void append(Section sec)
    {
        secalign = max(secalign, sec.secalign);
        length = (length + sec.secalign - 1) & ~cast(uint)(sec.secalign - 1);
        sec.offset = length;
        length += sec.length;
        members ~= sec;
        sec.container = this;
    }
    void dump()
    {
        writeln("Section: ", cleanString(name), cleanString(tag), " (", secclass, ") ", length, " bytes align:", secalign);
    }
    void setBase(uint base)
    {
        foreach(sec; members)
            sec.offset += base;
    }
}

final class Section
{
    immutable(ubyte)[] fullname;
    immutable(ubyte)[] name;
    immutable(ubyte)[] tag;
    SectionClass secclass;
    SectionAlign secalign;
    uint length;
    uint offset;
    CombinedSection container;

    this(immutable(ubyte)[] name, SectionClass secclass, SectionAlign secalign, uint length)
    {
        auto i = name.indexOf('$');
        this.fullname = name;
        this.name = i == -1 ? name : name[0..i];
        this.tag = i == -1 ? null : name[i..$];
        this.secclass = secclass;
        this.secalign = secalign;
        this.length = length;
    }
}

string cleanString(immutable(ubyte)[] s)
{
    string r;
    foreach(c; s)
    {
        if (c > 0x7F)
            r ~= '*';
        else
            r ~= c;
    }
    return r;
}
