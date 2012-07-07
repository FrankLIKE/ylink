
import std.exception;
import std.file;
import std.path;
import std.stdio;

import objectfile;
import omfobjectfile;
import paths;
import relocation;
import sectiontable;
import symboltable;
import workqueue;

void main(string[] args)
{
    bool dump;
    string[] objectFilenames;
    Paths paths = new Paths();
    paths.add(".");
    paths.addLINK();

    foreach(s; args[1..$])
    {
        switch(s)
        {
        case "-d":
            dump = true;
            break;
        default:
            switch(extension(s))
            {
            case ".obj":
            case ".lib":
                objectFilenames ~= s;
                break;
            default:
                enforce(false, "Unknown file type: '" ~ s ~ "'");
                break;
            }
            break;
        }
    }

    auto queue = new WorkQueue!string();
    foreach(filename; objectFilenames)
        queue.append(defaultExtension(filename, "obj"));

    auto sectab = new SectionTable();
    auto symtab = new SymbolTable();
    auto objects = new WorkQueue!ObjectFile();
    while (!queue.empty())
    {
        auto filename = queue.pop();
        enforce(paths.search(filename), "File not found: " ~ filename);
        auto object = ObjectFile.detectFormat(filename);
        enforce(object, "Unknown object file format: " ~ filename);
        object.loadSymbols(symtab, sectab, queue, objects);
    }
    sectab.add(symtab.defineImports());
    symtab.defineSpecial();
    if (dump)
    {
        sectab.dump();
        symtab.dump();
    }
    symtab.checkUnresolved();
    auto segments = sectab.allocateSegments();
}
