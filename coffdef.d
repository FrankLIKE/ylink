
immutable ubyte[] DosHeader = cast(immutable ubyte[])
    x"4D 5A 60 00 01 00 00 00 04 00 10 00 FF FF 00 00
      FE 00 00 00 12 00 00 00 40 00 00 00 00 00 00 00
      00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
      00 00 00 00 00 00 00 00 00 00 00 00 60 00 00 00
      52 65 71 75 69 72 65 73 20 57 69 6E 33 32 20 20
      20 24 16 1F 33 D2 B4 09 CD 21 B8 01 4C CD 21 00";
static assert(DosHeader.length == 0x60);

immutable ubyte[] PE_Signature = ['P', 'E', 0, 0];

struct CoffHeader
{
align(1):
    ushort Machine;
    ushort NumberOfSections;
    uint TimeDateStamp;
    uint PointerToSymbolTable;
    uint NumberOfSymbols;
    ushort SizeOfOptionalHeader;
    ushort Characteristics;
}
static assert(CoffHeader.sizeof == 20);

enum ushort IMAGE_FILE_MACHINE_UNKNOWN = 0x0000;
enum ushort IMAGE_FILE_MACHINE_I386 = 0x14C;

enum ushort IMAGE_FILE_RELOCS_STRIPPED         = 0x0001;
enum ushort IMAGE_FILE_EXECUTABLE_IMAGE        = 0x0002;
enum ushort IMAGE_FILE_LINE_NUMS_STRIPPED      = 0x0004;
enum ushort IMAGE_FILE_LOCAL_SYMS_STRIPPED     = 0x0008;
enum ushort IMAGE_FILE_AGGRESSIVE_WS_TRIM      = 0x0010;
enum ushort IMAGE_FILE_LARGE_ADDRESS_AWARE     = 0x0020;
enum ushort IMAGE_FILE_BYTES_REVERSED_LO       = 0x0080;
enum ushort IMAGE_FILE_32BIT_MACHINE           = 0x0100;
enum ushort IMAGE_FILE_DEBUG_STRIPPED          = 0x0200;
enum ushort IMAGE_FILE_REMOVABLE_RUN_FROM_SWAP = 0x0400;
enum ushort IMAGE_FILE_NET_RUN_FROM_SWAP       = 0x0800;
enum ushort IMAGE_FILE_SYSTEM                  = 0x1000;
enum ushort IMAGE_FILE_DLL                     = 0x2000;
enum ushort IMAGE_FILE_UP_SYSTEM_ONLY          = 0x4000;
enum ushort IMAGE_FILE_BYTES_REVERSED_HI       = 0x8000;

struct OptionalHeader
{
align(1):
    // Common
    ushort Magic;
    ubyte MajorLinkerVersion;
    ubyte MinorLinkerVersion;
    uint SizeOfCode;
    uint SizeOfInitializedData;
    uint SizeOfUninitializedData;
    uint AddressOfEntryPoint;
    uint BaseOfCode;
    uint BaseOfData; // PE only
    // Windows Only
    uint ImageBase;
    uint SectionAlignment;
    uint FileAlignment;
    ushort MajorOperatingSystemVersion;
    ushort MinorOperatingSystemVersion;
    ushort MajorImageVersion;
    ushort MinorImageVersion;
    ushort MajorSubsystemVersion;
    ushort MinorSubsystemVersion;
    uint Win32VersionValue;
    uint SizeOfImage;
    uint SizeOfHeaders;
    uint CheckSum;
    ushort Subsystem;
    ushort DllCharacteristics;
    uint SizeOfStackReserve;
    uint SizeOfStackCommit;
    uint SizeOfHeapReserve;
    uint SizeOfHeapCommit;
    uint LoaderFlags;
    uint NumberOfRvaAndSizes;
}
static assert(OptionalHeader.sizeof == 96);

enum ushort PE_MAGIC = 0x010B;

enum ushort IMAGE_SUBSYSTEM_UNKNOWN     = 0x0000;
enum ushort IMAGE_SUBSYSTEM_WINDOWS_GUI = 0x0002;
enum ushort IMAGE_SUBSYSTEM_WINDOWS_CUI = 0x0003;

enum ushort IMAGE_DLL_CHARACTERISTICS_DYNAMIC_BASE          = 0x0040;
enum ushort IMAGE_DLL_CHARACTERISTICS_FORCE_INTEGRITY       = 0x0080;
enum ushort IMAGE_DLL_CHARACTERISTICS_NX_COMPAT             = 0x0100;
enum ushort IMAGE_DLL_CHARACTERISTICS_NO_ISOLATION          = 0x0200;
enum ushort IMAGE_DLL_CHARACTERISTICS_NO_SEH                = 0x0400;
enum ushort IMAGE_DLL_CHARACTERISTICS_NO_BIND               = 0x0800;
enum ushort IMAGE_DLL_CHARACTERISTICS_WDM_DRIVER            = 0x2000;
enum ushort IMAGE_DLL_CHARACTERISTICS_TERMINAL_SERVER_AWARE = 0x8000;

struct IMAGE_DATA_DIRECTORY
{
align(1):
    uint VirtualAddress;
    uint Size;
}
static assert(IMAGE_DATA_DIRECTORY.sizeof == 8);

struct DataDirectories
{
    IMAGE_DATA_DIRECTORY ExportTable;
    IMAGE_DATA_DIRECTORY ImportTable;
    IMAGE_DATA_DIRECTORY ResourceTable;
    IMAGE_DATA_DIRECTORY ExceptionTable;
    IMAGE_DATA_DIRECTORY CertificateTable;
    IMAGE_DATA_DIRECTORY BaseRelocationTable;
    IMAGE_DATA_DIRECTORY Debug;
    IMAGE_DATA_DIRECTORY Architecture;
    IMAGE_DATA_DIRECTORY GlobalPtr;
    IMAGE_DATA_DIRECTORY TLSTable;
    IMAGE_DATA_DIRECTORY LoadConfigTable;
    IMAGE_DATA_DIRECTORY BoundImportTable;
    IMAGE_DATA_DIRECTORY ImportAddressTable;
    IMAGE_DATA_DIRECTORY DelayImportDescriptor;
    IMAGE_DATA_DIRECTORY CLRRuntimeHeader;
    IMAGE_DATA_DIRECTORY Reserved;
}

immutable ubyte[8][] SectionNames =
[
    cast(ubyte[8])".idata\0\0",
    cast(ubyte[8])".edata\0\0",
    cast(ubyte[8])".text\0\0\0",
    cast(ubyte[8])".tls\0\0\0\0",
    cast(ubyte[8])".data\0\0\0",
    cast(ubyte[8])".rdata\0\0",
    cast(ubyte[8])".bss\0\0\0\0",
    cast(ubyte[8])".reloc\0\0",
    cast(ubyte[8])".debug\0\0",
];

struct SectionHeader
{
align(1):
    ubyte[8] Name;
    uint VirtualSize;
    uint VirtualAddress;
    uint SizeOfRawData;
    uint PointerToRawData;
    uint PointerToRelocations;
    uint PointerToLinenumbers;
    ushort NumberOfRelocations;
    ushort NumberOfLinenumbers;
    uint Characteristics;
}

enum : uint
{
    IMAGE_SCN_TYPE_NO_PAD = 0x00000008,
    IMAGE_SCN_CNT_CODE = 0x00000020,
    IMAGE_SCN_CNT_INITIALIZED_DATA = 0x00000040,
    IMAGE_SCN_CNT_UNINITIALIZED_DATA = 0x00000080,
    IMAGE_SCN_LNK_OTHER = 0x00000100,
    IMAGE_SCN_LNK_INFO = 0x00000200,
    IMAGE_SCN_LNK_REMOVE = 0x00000800,
    IMAGE_SCN_LNK_COMDAT = 0x00001000,
    IMAGE_SCN_GPREL = 0x00008000,
    IMAGE_SCN_MEM_PURGEABLE = 0x00020000,
    IMAGE_SCN_MEM_LOCKED = 0x00040000,
    IMAGE_SCN_MEM_PRELOAD = 0x00080000,
    IMAGE_SCN_ALIGN_1BYTES = 0x00100000,
    IMAGE_SCN_ALIGN_2BYTES = 0x00200000,
    IMAGE_SCN_ALIGN_4BYTES = 0x00300000,
    IMAGE_SCN_ALIGN_8BYTES = 0x00400000,
    IMAGE_SCN_ALIGN_16BYTES = 0x00500000,
    IMAGE_SCN_ALIGN_32BYTES = 0x00600000,
    IMAGE_SCN_ALIGN_64BYTES = 0x00700000,
    IMAGE_SCN_ALIGN_128BYTES = 0x00800000,
    IMAGE_SCN_ALIGN_256BYTES = 0x00900000,
    IMAGE_SCN_ALIGN_512BYTES = 0x00A00000,
    IMAGE_SCN_ALIGN_1024BYTES = 0x00B00000,
    IMAGE_SCN_ALIGN_2048BYTES = 0x00C00000,
    IMAGE_SCN_ALIGN_4096BYTES = 0x00D00000,
    IMAGE_SCN_ALIGN_8192BYTES = 0x00E00000,
    IMAGE_SCN_LNK_NRELOC_OVFL = 0x01000000,
    IMAGE_SCN_MEM_DISCARDABLE = 0x02000000,
    IMAGE_SCN_MEM_NOT_CACHED = 0x04000000,
    IMAGE_SCN_MEM_NOT_PAGED = 0x08000000,
    IMAGE_SCN_MEM_SHARED = 0x10000000,
    IMAGE_SCN_MEM_EXECUTE = 0x20000000,
    IMAGE_SCN_MEM_READ = 0x40000000,
    IMAGE_SCN_MEM_WRITE = 0x80000000,
}

align(1)
struct CoffRelocation
{
align(1):
    uint VirtualAddress;
    uint SymbolTableIndex;
    ushort Type;
}
static assert(CoffRelocation.sizeof == 10);

enum : ushort
{
    IMAGE_REL_I386_ABSOLUTE = 0x0000,
    IMAGE_REL_I386_DIR16 = 0x0001,
    IMAGE_REL_I386_REL16 = 0x0002,
    IMAGE_REL_I386_DIR32 = 0x0006,
    IMAGE_REL_I386_DIR32NB = 0x0007,
    IMAGE_REL_I386_SEG12 = 0x0009,
    IMAGE_REL_I386_SECTION = 0x000A,
    IMAGE_REL_I386_SECREL = 0x000B,
    IMAGE_REL_I386_TOKEN = 0x000C,
    IMAGE_REL_I386_SECREL7 = 0x000D,
    IMAGE_REL_I386_REL32 = 0x0014,
}

struct DebugDirectory
{
align(1):
    uint Characteristics;
    uint TimeDateStamp;
    ushort MajorVersion;
    ushort MinorVersion;
    uint Type;
    uint SizeOfData;
    uint AddressOfRawData;
    uint PointerToRawData;
}

enum : uint
{
    IMAGE_DEBUG_TYPE_UNKNOWN = 0,
    IMAGE_DEBUG_TYPE_COFF = 1,
    IMAGE_DEBUG_TYPE_CODEVIEW = 2,
    IMAGE_DEBUG_TYPE_FPO = 3,
    IMAGE_DEBUG_TYPE_MISC = 4,
    IMAGE_DEBUG_TYPE_EXCEPTION = 5,
    IMAGE_DEBUG_TYPE_FIXUP = 6,
    IMAGE_DEBUG_TYPE_OMAP_TO_SRC = 7,
    IMAGE_DEBUG_TYPE_OMAP_FROM_SRC = 8,
    IMAGE_DEBUG_TYPE_BORLAND = 9,
    IMAGE_DEBUG_TYPE_RESERVED10 = 10,
    IMAGE_DEBUG_TYPE_CLSID = 11,
}

struct ImportDirectory
{
align(1):
    uint ImportLookupTable;
    uint TimeDateStamp;
    uint ForwarderChain;
    uint Name;
    uint ImportAddressTable;
}

align(1)
struct StandardSymbolRecord
{
align(1):
    ubyte[8] Name;
    uint Value;
    short SectionNumber;
    ushort Type;
    ubyte StorageClass;
    ubyte NumberOfAuxSymbols;
}
static assert(StandardSymbolRecord.sizeof == 18);

align(1)
struct SectionSymbolRecord
{
align(1):
    uint Length;
    ushort NumberOfRelocations;
    ushort NumberOfLinenumbers;
    uint CheckSum;
    ushort Number;
    ubyte Selection;
    ubyte[3] Unused;
}
static assert(SectionSymbolRecord.sizeof == 18);

enum : short
{
    IMAGE_SYM_UNDEFINED = 0,
    IMAGE_SYM_ABSOLUTE = -1,
    IMAGE_SYM_DEBUG = -2,
}

enum : ubyte
{
    IMAGE_SYM_CLASS_END_OF_FUNCTION = 0xFF,
    IMAGE_SYM_CLASS_NULL = 0,
    IMAGE_SYM_CLASS_AUTOMATIC = 1,
    IMAGE_SYM_CLASS_EXTERNAL = 2,
    IMAGE_SYM_CLASS_STATIC = 3,
    IMAGE_SYM_CLASS_REGISTER = 4,
    IMAGE_SYM_CLASS_EXTERNAL_DEF = 5,
    IMAGE_SYM_CLASS_LABEL = 6,
    IMAGE_SYM_CLASS_UNDEFINED_LABEL = 7,
    IMAGE_SYM_CLASS_MEMBER_OF_STRUCT = 8,
    IMAGE_SYM_CLASS_ARGUMENT = 9,
    IMAGE_SYM_CLASS_STRUCT_TAG = 10,
    IMAGE_SYM_CLASS_MEMBER_OF_UNION = 11,
    IMAGE_SYM_CLASS_UNION_TAG = 12,
    IMAGE_SYM_CLASS_TYPE_DEFINITION = 13,
    IMAGE_SYM_CLASS_UNDEFINED_STATIC = 14,
    IMAGE_SYM_CLASS_ENUM_TAG = 15,
    IMAGE_SYM_CLASS_MEMBER_OF_ENUM = 16,
    IMAGE_SYM_CLASS_REGISTER_PARAM = 17,
    IMAGE_SYM_CLASS_BIT_FIELD = 18,
    IMAGE_SYM_CLASS_BLOCK = 100,
    IMAGE_SYM_CLASS_FUNCTION = 101,
    IMAGE_SYM_CLASS_END_OF_STRUCT = 102,
    IMAGE_SYM_CLASS_FILE = 103,
    IMAGE_SYM_CLASS_SECTION = 104,
    IMAGE_SYM_CLASS_WEAK_EXTERNAL = 105,
    IMAGE_SYM_CLASS_CLR_TOKEN = 107,
}

enum : ubyte
{
    IMAGE_COMDAT_SELECT_NODUPLICATES = 1,
    IMAGE_COMDAT_SELECT_ANY = 2,
    IMAGE_COMDAT_SELECT_SAME_SIZE = 3,
    IMAGE_COMDAT_SELECT_EXACT_MATCH = 4,
    IMAGE_COMDAT_SELECT_ASSOCIATIVE = 5,
    IMAGE_COMDAT_SELECT_LARGEST = 6
}

auto CoffLibSignature = cast(immutable(ubyte)[])"!<arch>\n";

struct CoffLibHeader
{
    char[16] Name;
    char[12] Date;
    char[6] UserID;
    char[6] GroupID;
    char[8] Mode;
    char[10] Size;
    char[2] End;
}
static assert(CoffLibHeader.sizeof == 60);

enum CoffLibLinkerMemberSig = "/               ";
enum CoffLibLongnamesMemberSig = "//              ";

struct CoffImportHeader
{
align(1):
    ushort Sig1;
    ushort Sig2;
    ushort Version;
    ushort Machine;
    uint TimeDateStamp;
    uint SizeOfData;
    ushort OrdinalHint;
    ushort Type;
}
static assert(CoffImportHeader.sizeof == 20);

enum : ubyte
{
    IMPORT_CODE = 0,
    IMPORT_DATA = 1,
    IMPORT_CONST = 2
}

enum : ubyte
{
    IMPORT_ORDINAL = 0,
    IMPORT_NAME = 1,
    IMPORT_NAME_NOPREFIX = 2,
    IMPORT_NAME_UNDECORATE = 3
}
