
import std.conv;
import std.exception;
import std.process;
import std.stdio;
import std.string;

import x86dis;
import windebug;

void main()
{
    dump("p0.txt", "testd.sym", "log0.txt");
    dump("p1.txt", "teste.sym", "log1.txt");
}

string[uint] getSyms(string fn)
{
    string[uint] r;
    foreach(l; File(fn, "r").byLine())
    {
        auto x = split(l);
        r[to!uint(x[0], 16)] = x[1].idup;
    }
    return r;
}

void dump(string src, string symf, string dest)
{
    auto f0 = File(src, "rb");
    auto l0 = f0.byLine();

    uint lastbase;
    bool u;
    bool full;

    auto out0 = File(dest, "w");
    auto count = 0;

    auto syms = getSyms(symf);

    while (!l0.empty && count < 1_000_000)
    {
        auto con0 = unpack(l0.front);
        con0.expand(syms);

        if (full)
        {
            out0.writefln("%.8X: %s (%s+0x%X)", con0.addr, X86Disassemble(con0.inst.ptr), con0.sym, con0.off);
        }
        else if (con0.addr < 0x400_000 || con0.addr > 0x500_000 && u)
        {
        }
        else if (con0.sym == "__Dmain")
        {
            full = true;
            count++;
        }
        else if (lastbase != con0.addr - con0.off)
        {
            u = con0.sym == "__Unknown__";
            out0.writefln("%.8X: %s (%s+0x%X)", con0.addr, X86Disassemble(con0.inst.ptr), con0.sym, con0.off);
            lastbase = con0.addr - con0.off;
        }

        l0.popFront();
    }
}

struct context
{
    uint addr;
    ubyte[16] inst;
    uint off;
    string sym;
    void expand(string[uint] syms)
    {
        sym = "__Unknown__";
        auto p = addr;
        while (p >= 0x400000 && p <= 0x500000 && p !in syms)
            p--;
        if (p in syms)
            sym = syms[p];
        off = addr - p;
    }
}

context unpack(char[] l)
{
    auto v = split(l);
    context c;
    with (c)
    {
        scope(failure) writeln(v);
        addr = to!uint(v[0], 16);
        foreach(i, ref b; inst) b = to!ubyte(v[1][i*2..i*2+2], 16);
    }
    return c;
}
