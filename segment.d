
import std.exception;
import std.stdio;

import section;

enum SegmentType
{
    Import,
    Export,
    Text,
    TLS,
    Data,
    Const,
    BSS,
    Reloc,
    Debug,
}

final class Segment
{
    SegmentType type;
    uint base;
    uint length;
    uint fileOffset;
    CombinedSection[] members;
    ubyte[] data;

    this(SegmentType type, uint base, uint fileOffset)
    {
        this.type = type;
        this.base = base;
        this.fileOffset = fileOffset;
    }
    void append(CombinedSection sec)
    {
        members ~= sec;
        sec.seg = this;
        sec.setBase(base + length);
        length += sec.length;
    }
    void allocate(uint segAlign)
    {
        data.length = (length + segAlign - 1) & ~(segAlign - 1);
        foreach(sec; members)
        {
            auto rbase = sec.base-base;
            sec.allocate(data[rbase..rbase+sec.length]);
        }
    }
    void dump()
    {
        writefln("Segment: (%s) 0x%.8X -> 0x%.8X (0x%.8X)", type, base, base + length, length);
    }
}
