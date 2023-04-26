unit WinNative;
(*
  Windows system libraries API (ntdll, etc).
*)

// D2006      --> XE11.1
// String     --> myAStr
// WideString --> myWStr
// Char       --> myChar
// WideChar   --> myWChar
// PChar      --> myPChar
// PWideChar  --> myPWChar
// PPChar     --> myPPChar;
// PAnsiString--> myPAStr;
// PWideString--> myPWStr;

(***)  interface  (***)

uses
  Legacy, Windows, SysUtils, UtilsB2, StrLib;


////////////////////////////////////////////////////////////////////////
//                                                                    //
//                      COMMON TYPES AND CONSTS                       //
//                                                                    //
////////////////////////////////////////////////////////////////////////

const
  (* Used in wrappers. Specifies to calculate zero-terminated string length automatically *)
  AUTO_LENGTH = -1;

  WIDE_NULL_CHAR_SIZE = sizeof(myWChar);

  STATUS_SUCCESS              = 0;
  STATUS_INFO_LENGTH_MISMATCH = $C0000004;
  STATUS_ACCESS_VIOLATION     = $C0000005;
  STATUS_NO_SUCH_FILE         = $C000000F;
  STATUS_NOT_A_DIRECTORY      = $C0000103;
  STATUS_INVALID_BUFFER_SIZE  = $C0000206;
  STATUS_INVALID_INFO_CLASS   = $C0000003;
  STATUS_BUFFER_TOO_SMALL     = $C0000023;
  STATUS_NO_MORE_FILES        = $80000006;
  STATUS_BUFFER_OVERFLOW      = $80000005;

  (* For GetFileAttributesXXX *)
  INVALID_FILE_ATTRIBUTES = -1;

  (* For GetModuleHandleXXX *)
  GET_MODULE_HANDLE_EX_FLAG_PIN                = 1;
  GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT = 2;
  GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS       = 4;

  MAX_FILENAME_LEN = 256;

type
  NTSTATUS  = Longword;
  USHORT    = word;
  PCSZ      = PAnsiChar;
  PWSTR     = myPWChar;
  HANDLE    = Windows.THandle;
  PVOID     = pointer;
  LONG      = integer;
  ULONG_PTR = pointer;
  SIZE_T    = cardinal;

  _STRING = packed record
    Length:        USHORT;
    MaximumLength: USHORT;
    Buffer:        PAnsiChar;
  end;

  ANSI_STRING  = _STRING;
  PANSI_STRING = ^ANSI_STRING;
  OEM_STRING   = _STRING;
  POEM_STRING  = ^OEM_STRING;
  PCOEM_STRING = POEM_STRING;

  _UNICODE_STRING = packed record
    Length:        USHORT; // in bytes
    MaximumLength: USHORT; // in bytes
    Buffer:        PWSTR;

    function  GetLength (): integer; inline; // in characters

    (* Inits string as static empty value *)
    procedure Reset;
    
    (* Allocates new buffer, copies data and sets up record fields *)
    procedure AssignNewStr (const Str: myWStr); overload;
    
    (* Allocates new buffer, copies data and sets up record fields *)
    procedure AssignNewStr (const {n} Str: myPWChar; NumChars: integer = AUTO_LENGTH); overload;

    (* Changes fields to point to existing buffer, updates buffer size info *)
    procedure AssignExistingStr (const {n} Str: myPWChar; NumChars: integer = AUTO_LENGTH); overload;

    (* Changes fields to point to existing buffer, updates buffer size info *)
    procedure AssignExistingStr (const Str: myWStr); overload;
    
    (* Frees buffer, if any and sets Length to 0 *)
    procedure Release;
    
    function  ToWideStr: myWStr;
  end; // .record _UNICODE_STRING
  
  UNICODE_STRING   = _UNICODE_STRING;
  PUNICODE_STRING  = ^UNICODE_STRING;
  PCUNICODE_STRING = PUNICODE_STRING;

const
  OBJ_INHERIT          = $00000002;
  OBJ_PERMANENT        = $00000010;
  OBJ_EXCLUSIVE        = $00000020;
  OBJ_CASE_INSENSITIVE = $00000040;
  OBJ_OPENIF           = $00000080;
  OBJ_OPENLINK         = $00000100;
  OBJ_KERNEL_HANDLE    = $00000200;
  OBJ_VALID_ATTRIBUTES = $000003F2;

type
  _OBJECT_ATTRIBUTES = packed record
    Length:                   ULONG;
    RootDirectory:            HANDLE;
    ObjectName:               PUNICODE_STRING;
    Attributes:               ULONG;
    SecurityDescriptor:       PVOID;
    SecurityQualityOfService: PVOID;

    procedure Init ({n} Path: PUNICODE_STRING = nil);
  end;
  
  OBJECT_ATTRIBUTES  = _OBJECT_ATTRIBUTES;
  POBJECT_ATTRIBUTES = ^OBJECT_ATTRIBUTES;
  TObjectAttributes  = OBJECT_ATTRIBUTES;
  PObjectAttributes  = ^TObjectAttributes;


  _IO_STATUS_BLOCK = packed record
    Status: packed record
      case byte of
        0: (Status:  NTSTATUS);
        1: (Pointer: ULONG_PTR);
    end;
    
    Information: ULONG_PTR;
  end;
  
  IO_STATUS_BLOCK  = _IO_STATUS_BLOCK;
  PIO_STATUS_BLOCK = ^IO_STATUS_BLOCK;
  TIoStatusBlock   = IO_STATUS_BLOCK;
  PIoStatusBlock   = ^TIoStatusBlock;

type
  _FILE_INFORMATION_CLASS = (
    FileDirectoryInformation = 1              ,
    FileFullDirectoryInformation              ,
    FileBothDirectoryInformation              ,
    FileBasicInformation                      ,
    FileStandardInformation                   ,
    FileInternalInformation                   ,
    FileEaInformation                         ,
    FileAccessInformation                     ,
    FileNameInformation                       ,
    FileRenameInformation                     ,
    FileLinkInformation                       ,
    FileNamesInformation                      ,
    FileDispositionInformation                ,
    FilePositionInformation                   ,
    FileFullEaInformation                     ,
    FileModeInformation                       ,
    FileAlignmentInformation                  ,
    FileAllInformation                        ,
    FileAllocationInformation                 ,
    FileEndOfFileInformation                  ,
    FileAlternateNameInformation              ,
    FileStreamInformation                     ,
    FilePipeInformation                       ,
    FilePipeLocalInformation                  ,
    FilePipeRemoteInformation                 ,
    FileMailslotQueryInformation              ,
    FileMailslotSetInformation                ,
    FileCompressionInformation                ,
    FileObjectIdInformation                   ,
    FileCompletionInformation                 ,
    FileMoveClusterInformation                ,
    FileQuotaInformation                      ,
    FileReparsePointInformation               ,
    FileNetworkOpenInformation                ,
    FileAttributeTagInformation               ,
    FileTrackingInformation                   ,
    FileIdBothDirectoryInformation            ,
    FileIdFullDirectoryInformation            ,
    FileValidDataLengthInformation            ,
    FileShortNameInformation                  ,
    FileIoCompletionNotificationInformation   ,
    FileIoStatusBlockRangeInformation         ,
    FileIoPriorityHintInformation             ,
    FileSfioReserveInformation                ,
    FileSfioVolumeInformation                 ,
    FileHardLinkInformation                   ,
    FileProcessIdsUsingFileInformation        ,
    FileNormalizedNameInformation             ,
    FileNetworkPhysicalNameInformation        ,
    FileIdGlobalTxDirectoryInformation        ,
    FileIsRemoteDeviceInformation             ,
    FileUnusedInformation                     ,
    FileNumaNodeInformation                   ,
    FileStandardLinkInformation               ,
    FileRemoteProtocolInformation             ,
    FileRenameInformationBypassAccessCheck    ,
    FileLinkInformationBypassAccessCheck      ,
    FileVolumeNameInformation                 ,
    FileIdInformation                         ,
    FileIdExtdDirectoryInformation            ,
    FileReplaceCompletionInformation          ,
    FileHardLinkFullIdInformation             ,
    FileIdExtdBothDirectoryInformation        ,
    FileDispositionInformationEx              ,
    FileRenameInformationEx                   ,
    FileRenameInformationExBypassAccessCheck  ,
    FileDesiredStorageClassInformation        ,
    FileStatInformation                       ,
    FileMemoryPartitionInformation            ,
    FileStatLxInformation                     ,
    FileCaseSensitiveInformation              ,
    FileMaximumInformation
  ); // _FILE_INFORMATION_CLASS
  
  FILE_INFORMATION_CLASS = _FILE_INFORMATION_CLASS;
  TFileInformationClass  = FILE_INFORMATION_CLASS;

//
// Large (64-bit) integer types and operations
//

type
  LPLARGE_INTEGER = ^LARGE_INTEGER;
  _LARGE_INTEGER  = Windows._LARGE_INTEGER;
  LARGE_INTEGER   = Windows.LARGE_INTEGER;
  TLargeInteger   = Windows.TLargeInteger;

  PLARGE_INTEGER = ^LARGE_INTEGER;
  PLargeInteger  = LPLARGE_INTEGER;

  LPULARGE_INTEGER = ^ULARGE_INTEGER;

  ULARGE_INTEGER = Windows.ULARGE_INTEGER;
  TULargeInteger = Windows.TULargeInteger;
  PULargeInteger = Windows.PULargeInteger;

  PULARGE_INTEGER = ^ULARGE_INTEGER;

  TIME  = LARGE_INTEGER;
  _TIME = _LARGE_INTEGER;
  PTIME = PLARGE_INTEGER;


  PLIST_ENTRY = ^_LIST_ENTRY;
  _LIST_ENTRY = packed record
    Flink: PLIST_ENTRY;
    Blink: PLIST_ENTRY;
  end;
  
  LIST_ENTRY   = _LIST_ENTRY;
  PRLIST_ENTRY = PLIST_ENTRY;

  PRTL_BITMAP = ^RTL_BITMAP;
  RTL_BITMAP  = packed record
    SizeOfBitMap: ULONG;  (* Number of bits in the bitmap *)
    Buffer:       PULONG; (* Bitmap data, assumed sized to a DWORD boundary *)
  end;
  
  RTL_CRITICAL_SECTION  = record (* implementation dependent *) end;
  PRTL_CRITICAL_SECTION = ^RTL_CRITICAL_SECTION;

  _CLIENT_ID = packed record
    UniqueProcess: HANDLE;
    UniqueThread:  HANDLE;
  end;
  
  CLIENT_ID  = _CLIENT_ID;
  PCLIENT_ID = ^CLIENT_ID;

  _FILE_BASIC_INFORMATION = packed record
    CreationTime:   LARGE_INTEGER;
    LastAccessTime: LARGE_INTEGER;
    LastWriteTime:  LARGE_INTEGER;
    ChangeTime:     LARGE_INTEGER;
    FileAttributes: ULONG;
    Dummy:          ULONG;
  end;

  FILE_BASIC_INFORMATION  = _FILE_BASIC_INFORMATION;
  PFILE_BASIC_INFORMATION = ^FILE_BASIC_INFORMATION;

  PFILE_STANDARD_INFORMATION = ^FILE_STANDARD_INFORMATION;
  FILE_STANDARD_INFORMATION  = packed record
    AllocationSize: LARGE_INTEGER;
    EndOfFile:      LARGE_INTEGER;
    NumberOfLinks:  ULONG;
    DeletePending:  BOOLEAN;
    Directory:      BOOLEAN;
    Dummy:          word;
  end;

  PFILE_INTERNAL_INFORMATION = ^FILE_INTERNAL_INFORMATION;
  FILE_INTERNAL_INFORMATION  = packed record
    IndexNumber: LARGE_INTEGER;
  end;

  PFILE_EA_INFORMATION = ^FILE_EA_INFORMATION;
  FILE_EA_INFORMATION  = packed record
    EaSize: ULONG;
  end;

  PFILE_ACCESS_INFORMATION = ^FILE_ACCESS_INFORMATION;
  FILE_ACCESS_INFORMATION  = packed record
    AccessFlags: ACCESS_MASK;
  end;

  PFILE_POSITION_INFORMATION = ^FILE_POSITION_INFORMATION;
  FILE_POSITION_INFORMATION  = packed record
    CurrentByteOffset: LARGE_INTEGER;
  end;

  PFILE_MODE_INFORMATION = ^FILE_MODE_INFORMATION;
  FILE_MODE_INFORMATION  = packed record
    Mode: ULONG;
  end;

  PFILE_ALIGNMENT_INFORMATION = ^FILE_ALIGNMENT_INFORMATION;
  FILE_ALIGNMENT_INFORMATION  = packed record
    AlignmentRequirement: ULONG;
  end;

  PFILE_NAME_INFORMATION = ^FILE_NAME_INFORMATION;
  FILE_NAME_INFORMATION  = packed record
    FileNameLength: ULONG;
    FileName:       UtilsB2.TEmptyRec;
  end;

  _FILE_BOTH_DIR_INFORMATION = packed record
    NextEntryOffset: ULONG;
    FileIndex:       ULONG;
    CreationTime:    LARGE_INTEGER;
    LastAccessTime:  LARGE_INTEGER;
    LastWriteTime:   LARGE_INTEGER;
    ChangeTime:      LARGE_INTEGER;
    EndOfFile:       LARGE_INTEGER;
    AllocationSize:  LARGE_INTEGER;
    FileAttributes:  ULONG;
    FileNameLength:  ULONG;
    EaSize:          ULONG;
    ShortNameLength: BYTE;
    Dummy:           BYTE;
    ShortName:       array [0..11] of WCHAR;
    FileName:        TEmptyRec;
  end;

  FILE_BOTH_DIR_INFORMATION  = _FILE_BOTH_DIR_INFORMATION;
  PFILE_BOTH_DIR_INFORMATION = ^FILE_BOTH_DIR_INFORMATION;

  PFILE_DIRECTORY_INFORMATION = ^FILE_DIRECTORY_INFORMATION;
  FILE_DIRECTORY_INFORMATION  = packed record
    NextEntryOffset: ULONG;
    FileIndex:       ULONG;
    CreationTime:    LARGE_INTEGER;
    LastAccessTime:  LARGE_INTEGER;
    LastWriteTime:   LARGE_INTEGER;
    ChangeTime:      LARGE_INTEGER;
    EndOfFile:       LARGE_INTEGER;
    AllocationSize:  LARGE_INTEGER;
    FileAttributes:  ULONG;
    FileNameLength:  ULONG;
    FileName:        TEmptyRec;
  end;

  PFILE_FULL_DIR_INFORMATION = ^FILE_FULL_DIR_INFORMATION;
  FILE_FULL_DIR_INFORMATION  = packed record
    NextEntryOffset: ULONG;
    FileIndex:       ULONG;
    CreationTime:    LARGE_INTEGER;
    LastAccessTime:  LARGE_INTEGER;
    LastWriteTime:   LARGE_INTEGER;
    ChangeTime:      LARGE_INTEGER;
    EndOfFile:       LARGE_INTEGER;
    AllocationSize:  LARGE_INTEGER;
    FileAttributes:  ULONG;
    FileNameLength:  ULONG;
    EaSize:          ULONG;
    FileName:        TEmptyRec;
  end;

  PFILE_ID_BOTH_DIR_INFORMATION = ^FILE_ID_BOTH_DIR_INFORMATION;
  FILE_ID_BOTH_DIR_INFORMATION  = packed record
    NextEntryOffset: ULONG;
    FileIndex:       ULONG;
    CreationTime:    LARGE_INTEGER;
    LastAccessTime:  LARGE_INTEGER;
    LastWriteTime:   LARGE_INTEGER;
    ChangeTime:      LARGE_INTEGER;
    EndOfFile:       LARGE_INTEGER;
    AllocationSize:  LARGE_INTEGER;
    FileAttributes:  ULONG;
    FileNameLength:  ULONG;
    EaSize:          ULONG;
    ShortNameLength: BYTE;
    Dummy_1:         BYTE;
    ShortName:       array [0..11] of WCHAR;
    Dummy_2:         WORD;
    FileId:          LARGE_INTEGER;
    FileName:        TEmptyRec;
  end;

  PFILE_ID_FULL_DIR_INFORMATION = ^FILE_ID_FULL_DIR_INFORMATION;
  FILE_ID_FULL_DIR_INFORMATION  = packed record
    NextEntryOffset: ULONG;
    FileIndex:       ULONG;
    CreationTime:    LARGE_INTEGER;
    LastAccessTime:  LARGE_INTEGER;
    LastWriteTime:   LARGE_INTEGER;
    ChangeTime:      LARGE_INTEGER;
    EndOfFile:       LARGE_INTEGER;
    AllocationSize:  LARGE_INTEGER;
    FileAttributes:  ULONG;
    FileNameLength:  ULONG;
    EaSize:          ULONG;
    Dummy:           ULONG;
    FileId:          LARGE_INTEGER;
    FileName:        TEmptyRec;
  end;

  PFILE_NAMES_INFORMATION = ^FILE_NAMES_INFORMATION;
  FILE_NAMES_INFORMATION  = packed record
    NextEntryOffset: ULONG;
    FileIndex:       ULONG;
    FileNameLength:  ULONG;
    FileName:        TEmptyRec;
  end;

  PFILE_ALL_INFORMATION = ^FILE_ALL_INFORMATION;
  FILE_ALL_INFORMATION  = packed record
    BasicInformation:     FILE_BASIC_INFORMATION;
    StandardInformation:  FILE_STANDARD_INFORMATION;
    InternalInformation:  FILE_INTERNAL_INFORMATION;
    EaInformation:        FILE_EA_INFORMATION;
    AccessInformation:    FILE_ACCESS_INFORMATION;
    PositionInformation:  FILE_POSITION_INFORMATION;
    ModeInformation:      FILE_MODE_INFORMATION;
    AlignmentInformation: FILE_ALIGNMENT_INFORMATION;
    NameInformation:      FILE_NAME_INFORMATION;
  end;

  _FILE_NETWORK_OPEN_INFORMATION = packed record
    CreationTime:   LARGE_INTEGER;
    LastAccessTime: LARGE_INTEGER;
    LastWriteTime:  LARGE_INTEGER;
    ChangeTime:     LARGE_INTEGER;
    AllocationSize: LARGE_INTEGER;
    EndOfFile:      LARGE_INTEGER;
    FileAttributes: ULONG;
    Reserved:       ULONG;
  end;

  FILE_NETWORK_OPEN_INFORMATION  = _FILE_NETWORK_OPEN_INFORMATION;
  PFILE_NETWORK_OPEN_INFORMATION = ^FILE_NETWORK_OPEN_INFORMATION;

  PFILE_NOTIFY_INFORMATION = ^FILE_NOTIFY_INFORMATION;
  FILE_NOTIFY_INFORMATION  = packed record
    NextEntryOffset: DWORD;
    Action:          DWORD;
    FileNameLength:  DWORD;
    FileName:        UtilsB2.TEmptyRec;

    function GetFileName: myWStr;
  end;

const
  (* flags for NtCreateFile and NtOpenFile *)
  FILE_DIRECTORY_FILE            = $00000001;
  FILE_WRITE_THROUGH             = $00000002;
  FILE_SEQUENTIAL_ONLY           = $00000004;
  FILE_NO_INTERMEDIATE_BUFFERING = $00000008;
  FILE_SYNCHRONOUS_IO_ALERT      = $00000010;
  FILE_SYNCHRONOUS_IO_NONALERT   = $00000020;
  FILE_NON_DIRECTORY_FILE        = $00000040;
  FILE_CREATE_TREE_CONNECTION    = $00000080;
  FILE_COMPLETE_IF_OPLOCKED      = $00000100;
  FILE_NO_EA_KNOWLEDGE           = $00000200;
  FILE_OPEN_FOR_RECOVERY         = $00000400;
  FILE_RANDOM_ACCESS             = $00000800;
  FILE_DELETE_ON_CLOSE           = $00001000;
  FILE_OPEN_BY_FILE_ID           = $00002000;
  FILE_OPEN_FOR_BACKUP_INTENT    = $00004000;
  FILE_NO_COMPRESSION            = $00008000;
  FILE_RESERVE_OPFILTER          = $00100000;
  FILE_TRANSACTED_MODE           = $00200000;
  FILE_OPEN_OFFLINE_FILE         = $00400000;
  FILE_OPEN_FOR_FREE_SPACE_QUERY = $00800000;
  FILE_ATTRIBUTE_VALID_FLAGS     = $00007fb7;
  FILE_ATTRIBUTE_VALID_SET_FLAGS = $000031a7;

  (* status for NtCreateFile or NtOpenFile *)
  FILE_SUPERSEDED     = 0;
  FILE_OPENED         = 1;
  FILE_CREATED        = 2;
  FILE_OVERWRITTEN    = 3;
  FILE_EXISTS         = 4;
  FILE_DOES_NOT_EXIST = 5;

  (* disposition for NtCreateFile *)
  FILE_SUPERSEDE           = 0;
  FILE_OPEN                = 1;
  FILE_CREATE              = 2;
  FILE_OPEN_IF             = 3;
  FILE_OVERWRITE           = 4;
  FILE_OVERWRITE_IF        = 5;
  FILE_MAXIMUM_DISPOSITION = 5;

  (* Characteristics of a File System *)
  FILE_REMOVABLE_MEDIA                     = $00000001;
  FILE_READ_ONLY_DEVICE                    = $00000002;
  FILE_FLOPPY_DISKETTE                     = $00000004;
  FILE_WRITE_ONE_MEDIA                     = $00000008;
  FILE_REMOTE_DEVICE                       = $00000010;
  FILE_DEVICE_IS_MOUNTED                   = $00000020;
  FILE_VIRTUAL_VOLUME                      = $00000040;
  FILE_AUTOGENERATED_DEVICE_NAME           = $00000080;
  FILE_DEVICE_SECURE_OPEN                  = $00000100;
  FILE_CHARACTERISTIC_PNP_DEVICE           = $00000800;
  FILE_CHARACTERISTIC_TS_DEVICE            = $00001000;
  FILE_CHARACTERISTIC_WEBDAV_DEVICE        = $00002000;
  FILE_CHARACTERISTIC_CSV                  = $00010000;
  FILE_DEVICE_ALLOW_APPCONTAINER_TRAVERSAL = $00020000;
  FILE_PORTABLE_DEVICE                     = $00040000;

  (* options for NtCreateNamedPipeFile *)
  FILE_PIPE_INBOUND     = $00000000;
  FILE_PIPE_OUTBOUND    = $00000001;
  FILE_PIPE_FULL_DUPLEX = $00000002;

  (* options for pipe's type *)
  FILE_PIPE_TYPE_MESSAGE = $00000001;
  FILE_PIPE_TYPE_BYTE    = $00000000;
  
  (* options for pipe's message mode *)
  FILE_PIPE_MESSAGE_MODE     = $00000001;
  FILE_PIPE_BYTE_STREAM_MODE = $00000000;
  
  (* options for pipe's blocking mode *)
  FILE_PIPE_COMPLETE_OPERATION = $00000001;
  FILE_PIPE_QUEUE_OPERATION    = $00000000;
  
  (* and client / server end *)
  FILE_PIPE_SERVER_END = $00000001;
  FILE_PIPE_CLIENT_END = $00000000;


////////////////////////////////////////////////////////////////////////
//                                                                    //
//                             ACCESS TYPES                           //
//                                                                    //
////////////////////////////////////////////////////////////////////////

type
  ACCESS_MASK  = DWORD;
  PACCESS_MASK = ^ACCESS_MASK;
  TAccessMask  = ACCESS_MASK;
  PAccessMask  = PACCESS_MASK; 

//
//  The following are masks for the predefined standard access types
//

const
  FILE_READ_DATA            = $0001;        (* file & pipe *)
  FILE_LIST_DIRECTORY       = $0001;        (* directory *)
  FILE_WRITE_DATA           = $0002;        (* file & pipe *)
  FILE_ADD_FILE             = $0002;        (* directory *)
  FILE_APPEND_DATA          = $0004;        (* file *)
  FILE_ADD_SUBDIRECTORY     = $0004;        (* directory *)
  FILE_CREATE_PIPE_INSTANCE = $0004;        (* named pipe *)
  FILE_READ_EA              = $0008;        (* file & directory *)
  FILE_READ_PROPERTIES      = FILE_READ_EA;
  FILE_WRITE_EA             = $0010;        (* file & directory *)
  FILE_WRITE_PROPERTIES     = FILE_READ_EA;
  FILE_EXECUTE              = $0020;        (* file *)
  FILE_TRAVERSE             = $0020;        (* directory *)
  FILE_DELETE_CHILD         = $0040;        (* directory *)
  FILE_READ_ATTRIBUTES      = $0080;        (* all *)
  FILE_WRITE_ATTRIBUTES     = $0100;        (* all *)

  DELETE                   = $00010000;
  READ_CONTROL             = $00020000;
  WRITE_DAC                = $00040000;
  WRITE_OWNER              = $00080000;
  SYNCHRONIZE              = $00100000;

  STANDARD_RIGHTS_REQUIRED = $000F0000;
  STANDARD_RIGHTS_READ     = READ_CONTROL;
  STANDARD_RIGHTS_WRITE    = READ_CONTROL;
  STANDARD_RIGHTS_EXECUTE  = READ_CONTROL;
  STANDARD_RIGHTS_ALL      = $001F0000;
  SPECIFIC_RIGHTS_ALL      = $0000FFFF;

  //
  // AccessSystemAcl access type
  //
  ACCESS_SYSTEM_SECURITY = $01000000;

  //
  // MaximumAllowed access type
  //
  MAXIMUM_ALLOWED = $02000000;

  //
  // Generic rights
  //
  FILE_GENERIC_READ    = STANDARD_RIGHTS_READ or FILE_READ_DATA or FILE_READ_ATTRIBUTES or FILE_READ_EA or SYNCHRONIZE;
  FILE_GENERIC_WRITE   = STANDARD_RIGHTS_WRITE or FILE_WRITE_DATA or FILE_WRITE_ATTRIBUTES or FILE_WRITE_EA or FILE_APPEND_DATA or SYNCHRONIZE;
  FILE_GENERIC_EXECUTE = STANDARD_RIGHTS_EXECUTE or FILE_READ_ATTRIBUTES or FILE_EXECUTE or SYNCHRONIZE;

  //
  // New Win10+ NtQueryDirectoryFileEx query flags
  //
  SL_RESTART_SCAN                = $01;
  SL_RETURN_SINGLE_ENTRY         = $02;
  SL_INDEX_SPECIFIED             = $04;
  SL_RETURN_ON_DISK_ENTRIES_ONLY = $08;
  SL_QUERY_DIRECTORY_MASK        = $0B;
  SL_NO_CURSOR_UPDATE_QUERY      = $10;

//
//  Define the generic mapping array.  This is used to denote the
//  mapping of each generic access right to a specific access mask.
//

type
  PGENERIC_MAPPING = ^GENERIC_MAPPING;
  _GENERIC_MAPPING = packed record
    GenericRead: ACCESS_MASK;
    GenericWrite: ACCESS_MASK;
    GenericExecute: ACCESS_MASK;
    GenericAll: ACCESS_MASK;
  end;
  
  GENERIC_MAPPING = _GENERIC_MAPPING;
  TGenericMapping = GENERIC_MAPPING;
  PGenericMapping = PGENERIC_MAPPING;


////////////////////////////////////////////////////////////////////////
//                                                                    //
//                              PEB, TEB                              //
//                                                                    //
////////////////////////////////////////////////////////////////////////

type
  _CURDIR = packed record
    DosPath: UNICODE_STRING;
    Handle:  Windows.THandle;
  end;
  
  CURDIR  = _CURDIR;
  PCURDIR = ^CURDIR;

  PRTL_DRIVE_LETTER_CURDIR = ^RTL_DRIVE_LETTER_CURDIR;
  RTL_DRIVE_LETTER_CURDIR  = packed record
    Flags:     USHORT;
    Length:    USHORT;
    TimeStamp: ULONG;
    DosPath:   UNICODE_STRING;
  end;

  _RTL_USER_PROCESS_PARAMETERS = packed record
    AllocationSize:     ULONG;
    Size:               ULONG;
    Flags:              ULONG;
    DebugFlags:         ULONG;
    ConsoleHandle:      HANDLE;
    ConsoleFlags:       ULONG;
    hStdInput:          HANDLE;
    hStdOutput:         HANDLE;
    hStdError:          HANDLE;
    CurrentDirectory:   CURDIR;
    DllPath:            UNICODE_STRING;
    ImagePathName:      UNICODE_STRING;
    CommandLine:        UNICODE_STRING;
    Environment:        PWSTR;
    dwX:                ULONG;
    dwY:                ULONG;
    dwXSize:            ULONG;
    dwYSize:            ULONG;
    dwXCountChars:      ULONG;
    dwYCountChars:      ULONG;
    dwFillAttribute:    ULONG;
    dwFlags:            ULONG;
    wShowWindow:        ULONG;
    WindowTitle:        UNICODE_STRING;
    Desktop:            UNICODE_STRING;
    ShellInfo:          UNICODE_STRING;
    RuntimeInfo:        UNICODE_STRING;
    DLCurrentDirectory: array [0..31] of RTL_DRIVE_LETTER_CURDIR;
  end; // .record _RTL_USER_PROCESS_PARAMETERS

  RTL_USER_PROCESS_PARAMETERS  = _RTL_USER_PROCESS_PARAMETERS;
  PRTL_USER_PROCESS_PARAMETERS = ^RTL_USER_PROCESS_PARAMETERS;

  _PEB_LDR_DATA = packed record
    Length:                          ULONG;
    Initialized:                     BOOLEAN;
    SsHandle:                        PVOID;
    InLoadOrderModuleList:           LIST_ENTRY;
    InMemoryOrderModuleList:         LIST_ENTRY;
    InInitializationOrderModuleList: LIST_ENTRY;
    EntryInProgress:                 PVOID;
  end;
  
  PEB_LDR_DATA  = _PEB_LDR_DATA;
  PPEB_LDR_DATA = ^PEB_LDR_DATA;

  _PEB = packed record
                                                                  (* win32/win64 *)
    InheritedAddressSpace:          BOOLEAN;                      (* 000/000 *)
    ReadImageFileExecOptions:       BOOLEAN;                      (* 001/001 *)
    BeingDebugged:                  BOOLEAN;                      (* 002/002 *)
    SpareBool:                      BOOLEAN;                      (* 003/003 *)
    Mutant:                         HANDLE;                       (* 004/008 *)
    ImageBaseAddress:               HMODULE;                      (* 008/010 *)
    LdrData:                        PPEB_LDR_DATA;                (* 00c/018 *)
    ProcessParameters:              ^RTL_USER_PROCESS_PARAMETERS; (* 010/020 *)
    SubSystemData:                  PVOID;                        (* 014/028 *)
    ProcessHeap:                    HANDLE;                       (* 018/030 *)
    FastPebLock:                    PRTL_CRITICAL_SECTION;        (* 01c/038 *)
    FastPebLockRoutine:             PVOID (*PPEBLOCKROUTINE*);    (* 020/040 *)
    FastPebUnlockRoutine:           PVOID (*PPEBLOCKROUTINE*);    (* 024/048 *)
    EnvironmentUpdateCount:         ULONG;                        (* 028/050 *)
    KernelCallbackTable:            PVOID;                        (* 02c/058 *)
    Reserved:                       array [0..1] of ULONG;        (* 030/060 *)
    FreeList:                       PVOID (*PPEB_FREE_BLOCK*);    (* 038/068 *)
    TlsExpansionCounter:            ULONG;                        (* 03c/070 *)
    TlsBitmap:                      PRTL_BITMAP;                  (* 040/078 *)
    TlsBitmapBits:                  array [0..1] of ULONG;        (* 044/080 *)
    ReadOnlySharedMemoryBase:       PVOID;                        (* 04c/088 *)
    ReadOnlySharedMemoryHeap:       PVOID;                        (* 050/090 *)
    ReadOnlyStaticServerData:       ^PVOID;                       (* 054/098 *)
    AnsiCodePageData:               PVOID;                        (* 058/0a0 *)
    OemCodePageData:                PVOID;                        (* 05c/0a8 *)
    UnicodeCaseTableData:           PVOID;                        (* 060/0b0 *)
    NumberOfProcessors:             ULONG;                        (* 064/0b8 *)
    NtGlobalFlag:                   ULONG;                        (* 068/0bc *)
    CriticalSectionTimeout:         LARGE_INTEGER;                (* 070/0c0 *)
    HeapSegmentReserve:             SIZE_T;                       (* 078/0c8 *)
    HeapSegmentCommit:              SIZE_T;                       (* 07c/0d0 *)
    HeapDeCommitTotalFreeThreshold: SIZE_T;                       (* 080/0d8 *)
    HeapDeCommitFreeBlockThreshold: SIZE_T;                       (* 084/0e0 *)
    NumberOfHeaps:                  ULONG;                        (* 088/0e8 *)
    MaximumNumberOfHeaps:           ULONG;                        (* 08c/0ec *)
    ProcessHeaps:                   ^PVOID;                       (* 090/0f0 *)
    GdiSharedHandleTable:           PVOID;                        (* 094/0f8 *)
    ProcessStarterHelper:           PVOID;                        (* 098/100 *)
    GdiDCAttributeList:             PVOID;                        (* 09c/108 *)
    LoaderLock:                     PVOID;                        (* 0a0/110 *)
    OSMajorVersion:                 ULONG;                        (* 0a4/118 *)
    OSMinorVersion:                 ULONG;                        (* 0a8/11c *)
    OSBuildNumber:                  ULONG;                        (* 0ac/120 *)
    OSPlatformId:                   ULONG;                        (* 0b0/124 *)
    ImageSubSystem:                 ULONG;                        (* 0b4/128 *)
    ImageSubSystemMajorVersion:     ULONG;                        (* 0b8/12c *)
    ImageSubSystemMinorVersion:     ULONG;                        (* 0bc/130 *)
    ImageProcessAffinityMask:       ULONG;                        (* 0c0/134 *)
    GdiHandleBuffer:                array [0..27] of HANDLE;      (* 0c4/138 *)
    unknown:                        array [0..5] of ULONG;        (* 134/218 *)
    PostProcessInitRoutine:         PVOID;                        (* 14c/230 *)
    TlsExpansionBitmap:             PRTL_BITMAP;                  (* 150/238 *)
    TlsExpansionBitmapBits:         array [0..31] of ULONG;       (* 154/240 *)
    SessionId:                      ULONG;                        (* 1d4/2c0 *)
    AppCompatFlags:                 ULARGE_INTEGER;               (* 1d8/2c8 *)
    AppCompatFlagsUser:             ULARGE_INTEGER;               (* 1e0/2d0 *)
    ShimData:                       PVOID;                        (* 1e8/2d8 *)
    AppCompatInfo:                  PVOID;                        (* 1ec/2e0 *)
    CSDVersion:                     UNICODE_STRING;               (* 1f0/2e8 *)
    ActivationContextData:          PVOID;                        (* 1f8/2f8 *)
    ProcessAssemblyStorageMap:      PVOID;                        (* 1fc/300 *)
    SystemDefaultActivationData:    PVOID;                        (* 200/308 *)
    SystemAssemblyStorageMap:       PVOID;                        (* 204/310 *)
    MinimumStackCommit:             SIZE_T;                       (* 208/318 *)
    FlsCallback:                    ^PVOID;                       (* 20c/320 *)
    FlsListHead:                    LIST_ENTRY;                   (* 210/328 *)
    FlsBitmap:                      PRTL_BITMAP;                  (* 218/338 *)
    FlsBitmapBits:                  array [0..3] of ULONG;        (* 21c/340 *)
  end; // .record _PEB
  
  PEB  = _PEB;
  PPEB = ^PEB;

  _TEB = packed record
                                                               (* win32/win64 *)
    Tib:                          array [1..$1c] of byte; (* NT_TIB; *) (* 000/0000 *)
    EnvironmentPointer:           PVOID;                       (* 01c/0038 *)
    ClientId:                     CLIENT_ID;                   (* 020/0040 *)
    ActiveRpcHandle:              PVOID;                       (* 028/0050 *)
    ThreadLocalStoragePointer:    PVOID;                       (* 02c/0058 *)
    Peb:                          PPEB;                        (* 030/0060 *)
    LastErrorValue:               ULONG;                       (* 034/0068 *)
    CountOfOwnedCriticalSections: ULONG;                       (* 038/006c *)
    CsrClientThread:              PVOID;                       (* 03c/0070 *)
    Win32ThreadInfo:              PVOID;                       (* 040/0078 *)
    Win32ClientInfo:              array [0..31 - 1] of ULONG;  (* 044/0080 used for user32 private data in Wine *)
    WOW32Reserved:                PVOID;                       (* 0c0/0100 *)
    CurrentLocale:                ULONG;                       (* 0c4/0108 *)
    FpSoftwareStatusRegister:     ULONG;                       (* 0c8/010c *)
    SystemReserved1:              array [0..54 - 1] of PVOID;  (* 0cc/0110 used for kernel32 private data in Wine *)
    ExceptionCode:                LONG;                        (* 1a4/02c0 *)
    ActivationContextStack:       array [1..20] of byte; (* ACTIVATION_CONTEXT_STACK; *) (* 1a8/02c8 *)
    SpareBytes1:                  array [0..24 - 1] of BYTE;   (* 1bc/02e8 *)
    SystemReserved2:              array [0..10 - 1] of PVOID;  (* 1d4/0300 used for ntdll platform-specific private data in Wine *)
    GdiTebBatch:                  array [1..1248] of byte; (* GDI_TEB_BATCH; *) (* 1fc/0350 used for ntdll private data in Wine *)
    gdiRgn:                       HANDLE;                      (* 6dc/0838 *)
    gdiPen:                       HANDLE;                      (* 6e0/0840 *)
    gdiBrush:                     HANDLE;                      (* 6e4/0848 *)
    RealClientId:                 CLIENT_ID;                   (* 6e8/0850 *)
    GdiCachedProcessHandle:       HANDLE;                      (* 6f0/0860 *)
    GdiClientPID:                 ULONG;                       (* 6f4/0868 *)
    GdiClientTID:                 ULONG;                       (* 6f8/086c *)
    GdiThreadLocaleInfo:          PVOID;                       (* 6fc/0870 *)
    UserReserved:                 array [0..5 - 1] of ULONG;   (* 700/0878 *)
    glDispatchTable:              array [0..280 - 1] of PVOID; (* 714/0890 *)
    glReserved1:                  array [0..26 - 1] of PVOID;  (* b74/1150 *)
    glReserved2:                  PVOID;                       (* bdc/1220 *)
    glSectionInfo:                PVOID;                       (* be0/1228 *)
    glSection:                    PVOID;                       (* be4/1230 *)
    glTable:                      PVOID;                       (* be8/1238 *)
    glCurrentRC:                  PVOID;                       (* bec/1240 *)
    glContext:                    PVOID;                       (* bf0/1248 *)
    LastStatusValue:              ULONG;                       (* bf4/1250 *)
    StaticUnicodeString:          UNICODE_STRING;              (* bf8/1258 used by advapi32 *)
    StaticUnicodeBuffer:          array [0..261 - 1] of WCHAR; (* c00/1268 used by advapi32 *)
    DeallocationStack:            PVOID;                       (* e0c/1478 *)
    TlsSlots:                     array [0..64 - 1] of PVOID;  (* e10/1480 *)
    TlsLinks:                     LIST_ENTRY;                  (* f10/1680 *)
    Vdm:                          PVOID;                       (* f18/1690 *)
    ReservedForNtRpc:             PVOID;                       (* f1c/1698 *)
    DbgSsReserved:                array [0..2 - 1] of PVOID;   (* f20/16a0 *)
    HardErrorDisabled:            ULONG;                       (* f28/16b0 *)
    Instrumentation:              array [0..16 - 1] of PVOID;  (* f2c/16b8 *)
    WinSockData:                  PVOID;                       (* f6c/1738 *)
    GdiBatchCount:                ULONG;                       (* f70/1740 *)
    Spare2:                       ULONG;                       (* f74/1744 *)
    Spare3:                       PVOID;                       (* f78/1748 *)
    Spare4:                       PVOID;                       (* f7c/1750 *)
    ReservedForOle:               PVOID;                       (* f80/1758 *)
    WaitingOnLoaderLock:          ULONG;                       (* f84/1760 *)
    Reserved5:                    array [0..3 - 1] of PVOID;   (* f88/1768 *)
    TlsExpansionSlots:            ^PVOID;                      (* f94/1780 *)
    {$IFDEF WIN64}
    DeallocationBStore:           PVOID;                       (*    /1788 *)
    BStoreLimit:                  PVOID;                       (*    /1790 *)
    {$ENDIF}
    ImpersonationLocale:          ULONG;                       (* f98/1798 *)
    IsImpersonating:              ULONG;                       (* f9c/179c *)
    NlsCache:                     PVOID;                       (* fa0/17a0 *)
    ShimData:                     PVOID;                       (* fa4/17a8 *)
    HeapVirtualAffinity:          ULONG;                       (* fa8/17b0 *)
    CurrentTransactionHandle:     PVOID;                       (* fac/17b8 *)
    ActiveFrame:                  PVOID; (* ^TEB_ACTIVE_FRAME; *) (* fb0/17c0 *)
    FlsSlots:                     ^PVOID;                      (* fb4/17c8 *)
  end; // .record _TEB
  
  TEB  = _TEB;
  PTEB = ^TEB;


////////////////////////////////////////////////////////////////////////
//                                                                    //
//                         EXPORTED FUNCTIONS                         //
//                                                                    //
////////////////////////////////////////////////////////////////////////

type
  TNtOpenFile = function (FileHandle: PHANDLE; DesiredAccess: ACCESS_MASK; ObjectAttributes: POBJECT_ATTRIBUTES; IoStatusBlock: PIO_STATUS_BLOCK; ShareAccess: ULONG; OpenOptions: ULONG): NTSTATUS; stdcall;
  
  TNtCreateFile = function(FileHandle: PHANDLE; DesiredAccess: ACCESS_MASK; ObjectAttributes: POBJECT_ATTRIBUTES; IoStatusBlock: PIO_STATUS_BLOCK; AllocationSize: PLARGE_INTEGER;
                           FileAttributes: ULONG; ShareAccess: ULONG; CreateDisposition: ULONG; CreateOptions: ULONG; EaBuffer: PVOID; EaLength: ULONG): NTSTATUS; stdcall;
  TNtClose = function (hData: HANDLE): NTSTATUS; stdcall;

  TNtQueryInformationFile    = function (FileHandle: HANDLE; PIO_STATUS_BLOCK: PIoStatusBlock; FileInformation: PVOID; Length: ULONG; FileInformationClass: integer (* FILE_INFORMATION_CLASS *)): NTSTATUS; stdcall;
  TNtQueryDirectoryFile      = function (FileHandle: HANDLE; Event: HANDLE; ApcRoutine: POINTER; ApcContext: PVOID; Io: PIO_STATUS_BLOCK; Buffer: PVOID; BufLength: ULONG;
                                         InfoClass: integer (* FILE_INFORMATION_CLASS *); SingleEntry: BOOLEAN; Mask: PUNICODE_STRING; RestartScan: BOOLEAN): NTSTATUS; stdcall;
  TNtQueryDirectoryFileEx    = function (FileHandle: HANDLE; Event: HANDLE; ApcRoutine: pointer; ApcContext: PVOID; Io: PIO_STATUS_BLOCK; Buffer: PVOID; BufLength: ULONG;
                                         InfoClass: integer (* FILE_INFORMATION_CLASS *); QueryFlags: integer; Mask: PUNICODE_STRING): NTSTATUS; stdcall;
  TNtQueryAttributesFile     = function (ObjectAttributes: POBJECT_ATTRIBUTES; FileInformation: PFILE_BASIC_INFORMATION): NTSTATUS; stdcall;
  TNtQueryFullAttributesFile = function (ObjectAttributes: POBJECT_ATTRIBUTES; FileInformation: PFILE_NETWORK_OPEN_INFORMATION): NTSTATUS; stdcall;
  TNtDeleteFile              = function (ObjectAttributes: POBJECT_ATTRIBUTES): NTSTATUS; stdcall;
  TRtlExitUserProcess        = procedure (Status: integer); stdcall;
  
  function  wcslen (Str: myPWChar): integer; stdcall; external 'ntdll.dll';
  function  RtlAllocateHeap (HeapHandle: HANDLE; Flags: ULONG; Size: SIZE_T): PVOID; stdcall; external 'ntdll.dll';
  procedure RtlFreeHeap     (HeapHandle: HANDLE; Flags: ULONG; BaseAddress: PVOID); stdcall; external 'ntdll.dll';
  procedure RtlAcquirePebLock; stdcall; external 'ntdll.dll';
  procedure RtlReleasePebLock; stdcall; external 'ntdll.dll';

  function  NtQueryAttributesFile (ObjectAttributes: POBJECT_ATTRIBUTES; FileInformation: PFILE_BASIC_INFORMATION): NTSTATUS; stdcall; external 'ntdll.dll';
  function  NtQueryInformationFile (FileHandle: HANDLE; PIO_STATUS_BLOCK: PIoStatusBlock; FileInformation: PVOID; Length: ULONG; FileInformationClass: integer (* FILE_INFORMATION_CLASS *)): NTSTATUS; stdcall; external 'ntdll.dll';
  function  NtQueryDirectoryFile (FileHandle: HANDLE; Event: HANDLE; ApcRoutine: pointer; ApcContext: PVOID; Io: PIO_STATUS_BLOCK; Buffer: PVOID; BufLength: ULONG; InfoClass: integer (* FILE_INFORMATION_CLASS *);
                                  SingleEntry: BOOLEAN; Mask: PUNICODE_STRING; RestartScan: BOOLEAN): NTSTATUS; stdcall; external 'ntdll.dll';
  function  NtQueryDirectoryFileEx (FileHandle: HANDLE; Event: HANDLE; ApcRoutine: pointer; ApcContext: PVOID; Io: PIO_STATUS_BLOCK; Buffer: PVOID; BufLength: ULONG; InfoClass: integer (* FILE_INFORMATION_CLASS *);
                                    QueryFlags: integer; Mask: PUNICODE_STRING): NTSTATUS; stdcall; external 'ntdll.dll';
  function  NtCreateFile (FileHandle: PHANDLE; DesiredAccess: ACCESS_MASK; ObjectAttributes: POBJECT_ATTRIBUTES; IoStatusBlock: PIO_STATUS_BLOCK; AllocationSize: PLARGE_INTEGER;
                          FileAttributes: ULONG; ShareAccess: ULONG; CreateDisposition: ULONG; CreateOptions: ULONG; EaBuffer: PVOID; EaLength: ULONG): NTSTATUS; stdcall; external 'ntdll.dll';
  function  NtOpenFile (FileHandle: PHANDLE; DesiredAccess: ACCESS_MASK; ObjectAttributes: POBJECT_ATTRIBUTES; IoStatusBlock: PIO_STATUS_BLOCK; ShareAccess: ULONG; OpenOptions: ULONG): NTSTATUS; stdcall; external 'ntdll.dll';
  function  NtClose (hData: HANDLE): NTSTATUS; stdcall; external 'ntdll.dll';
  function  NtQueryTimerResolution (var MinimumResolution, MaximumResolution, CurrentResolution: cardinal): NTSTATUS; stdcall; external 'ntdll.dll';
  function  NtSetTimerResolution (Resolution: cardinal; SetResolution: LONGBOOL; var CurrentResolution: cardinal): NTSTATUS; stdcall; external 'ntdll.dll';
  procedure RtlExitUserProcess (Status: integer); stdcall; external 'ntdll.dll';
  function  PathIsRelativeW (lpFileName: myPWChar): boolean; stdcall; external 'Shlwapi.dll';
  function  GetModuleHandleExW (dwFlags: integer; lpModuleName: myPWChar; var hModule: Windows.THandle): LONGBOOL; stdcall; external 'kernel32.dll';

  function  MemAlloc (Size: cardinal): pointer;
  procedure MemFree ({n} Ptr: pointer);
  procedure MemFreeAndNil (var Ptr);
  function  GetTeb: PTEB;

  function NT_SUCCESS     (Status: NTSTATUS): boolean; inline;
  function NT_INFORMATION (Status: NTSTATUS): boolean; inline;
  function NT_WARNING     (Status: NTSTATUS): boolean; inline;
  function NT_ERROR       (Status: NTSTATUS): boolean; inline;

  function FileInformationClassToStr (FileInformationClass: integer): AnsiString; overload;
  function FileInformationClassToStr (FileInformationClass: FILE_INFORMATION_CLASS): AnsiString; overload;
  function GetFileInformationClassSize (FileInformationClass: integer): integer; overload;
  function GetFileInformationClassSize (FileInformationClass: FILE_INFORMATION_CLASS): integer; overload;


(***)  implementation  (***)


function _UNICODE_STRING.GetLength: integer;
begin
  result := Self.Length shr 1;
end;

procedure _UNICODE_STRING.Reset;
begin
  Self.Length        := 0;
  Self.MaximumLength := 0;
  Self.Buffer        := nil;
end;

procedure _UNICODE_STRING.AssignNewStr (const Str: myWStr);
begin
  Self.AssignNewStr(myPWChar(Str), System.Length(Str));
end;

procedure _UNICODE_STRING.AssignNewStr (const {n} Str: myPWChar; NumChars: integer = AUTO_LENGTH);
var
  BufSize: integer;

begin
  {!} Assert((NumChars < 0) or UtilsB2.IsValidBuf(Str, NumChars));
  
  if (NumChars = 0) or (Str = nil) or ((NumChars = AUTO_LENGTH) and (Str^ = #0)) then begin
    Self.Length        := 0;
    Self.MaximumLength := 0;
    Self.Buffer        := nil;
  end else begin
    if NumChars < 0 then begin
      BufSize := wcslen(Str) * sizeof(Str[1]) + WIDE_NULL_CHAR_SIZE;
    end else begin
      BufSize := NumChars * sizeof(Str[1]) + WIDE_NULL_CHAR_SIZE;
    end;
    
    Self.Buffer        := MemAlloc(BufSize);
    Self.Length        := BufSize - WIDE_NULL_CHAR_SIZE;
    Self.MaximumLength := BufSize;
    pword(UtilsB2.PtrOfs(Self.Buffer, Self.Length))^ := 0;
    UtilsB2.CopyMem(Self.Length, Str, Self.Buffer);
  end; // .else
end; // .procedure _UNICODE_STRING.AssignNewStr

procedure _UNICODE_STRING.AssignExistingStr (const Str: myWStr);
begin
  Self.AssignExistingStr(myPWChar(Str), System.Length(Str));
end;

procedure _UNICODE_STRING.AssignExistingStr (const {n} Str: myPWChar; NumChars: integer = AUTO_LENGTH);
var
  BufSize: integer;

begin
  {!} Assert((NumChars < 0) or UtilsB2.IsValidBuf(Str, NumChars));
  
  if (NumChars = 0) or (Str = nil) or (Str^ = #0) then begin
    Self.Length        := 0;
    Self.MaximumLength := 0;
    Self.Buffer        := nil;
  end else begin
    if NumChars < 0 then begin
      BufSize := wcslen(Str) * sizeof(Str[1]);
    end else begin
      BufSize := NumChars * sizeof(Str[1]);
    end;
    
    Self.Buffer        := Str;
    Self.Length        := BufSize;
    Self.MaximumLength := BufSize + WIDE_NULL_CHAR_SIZE;
  end; // .else
end; // .procedure _UNICODE_STRING.AssignExistingStr

procedure _UNICODE_STRING.Release;
begin
  if (Self.Length > 0) then begin
    if Self.Buffer <> nil then begin
      MemFree(Self.Buffer);
    end;
    
    Self.Buffer        := nil;
    Self.Length        := 0;
    Self.MaximumLength := 0;
  end;
end;

function _UNICODE_STRING.ToWideStr: myWStr;
begin
  if (@Self = nil) or (Self.Length = 0) then begin
    result := '';
  end else begin
    result := StrLib.WideStringFromBuf(Self.Buffer, Self.GetLength());
  end;
end;

procedure _OBJECT_ATTRIBUTES.Init ({n} Path: PUNICODE_STRING = nil);
begin
  Self.Length                   := sizeof(Self);
  Self.RootDirectory            := 0;
  Self.Attributes               := OBJ_CASE_INSENSITIVE;
  Self.ObjectName               := Path;
  Self.SecurityDescriptor       := nil;
  Self.SecurityQualityOfService := nil;
end;

function FILE_NOTIFY_INFORMATION.GetFileName: myWStr;
begin
  result := StrLib.WideStringFromBuf(@Self.FileName, Self.FileNameLength div sizeof(myWChar));
end;

function NT_SUCCESS (Status: NTSTATUS): boolean; inline;
begin
  result := integer(Status) >= 0;
end;

function NT_INFORMATION (Status: NTSTATUS): boolean; inline;
begin
  result := (Status shr 30) = 1;
end;

function NT_WARNING (Status: NTSTATUS): boolean; inline;
begin
  result := (Status shr 30) = 2;
end;

function NT_ERROR (Status: NTSTATUS): boolean; inline;
begin
  result := (Status shr 30) = 3;
end;

function MemAlloc (Size: cardinal): pointer;
begin
  {!} Assert(Size <> 0);
  result := RtlAllocateHeap(Windows.GetProcessHeap(), Windows.HEAP_GENERATE_EXCEPTIONS, Size);
end;

procedure MemFree ({n} Ptr: pointer);
begin
  if Ptr <> nil then begin
    RtlFreeHeap(Windows.GetProcessHeap(), 0, Ptr);
  end;
end;

procedure MemFreeAndNil (var Ptr);
begin
  MemFree(pointer(Ptr));
  pointer(Ptr) := nil;
end;

function GetTeb: PTEB; assembler; 
asm
  db $64, $A1, $18, $00, $00, $00; // mov [eax], dword [FS:$18]
  mov result, eax
end;

function FileInformationClassToStr (FileInformationClass: integer): AnsiString; overload;
begin
  case FileInformationClass of
    ord(FileDirectoryInformation):                 result := 'FileDirectoryInformation';
    ord(FileFullDirectoryInformation):             result := 'FileFullDirectoryInformation';
    ord(FileBothDirectoryInformation):             result := 'FileBothDirectoryInformation';
    ord(FileBasicInformation):                     result := 'FileBasicInformation';
    ord(FileStandardInformation):                  result := 'FileStandardInformation';
    ord(FileInternalInformation):                  result := 'FileInternalInformation';
    ord(FileEaInformation):                        result := 'FileEaInformation';
    ord(FileAccessInformation):                    result := 'FileAccessInformation';
    ord(FileNameInformation):                      result := 'FileNameInformation';
    ord(FileRenameInformation):                    result := 'FileRenameInformation';
    ord(FileLinkInformation):                      result := 'FileLinkInformation';
    ord(FileNamesInformation):                     result := 'FileNamesInformation';
    ord(FileDispositionInformation):               result := 'FileDispositionInformation';
    ord(FilePositionInformation):                  result := 'FilePositionInformation';
    ord(FileFullEaInformation):                    result := 'FileFullEaInformation';
    ord(FileModeInformation):                      result := 'FileModeInformation';
    ord(FileAlignmentInformation):                 result := 'FileAlignmentInformation';
    ord(FileAllInformation):                       result := 'FileAllInformation';
    ord(FileAllocationInformation):                result := 'FileAllocationInformation';
    ord(FileEndOfFileInformation):                 result := 'FileEndOfFileInformation';
    ord(FileAlternateNameInformation):             result := 'FileAlternateNameInformation';
    ord(FileStreamInformation):                    result := 'FileStreamInformation';
    ord(FilePipeInformation):                      result := 'FilePipeInformation';
    ord(FilePipeLocalInformation):                 result := 'FilePipeLocalInformation';
    ord(FilePipeRemoteInformation):                result := 'FilePipeRemoteInformation';
    ord(FileMailslotQueryInformation):             result := 'FileMailslotQueryInformation';
    ord(FileMailslotSetInformation):               result := 'FileMailslotSetInformation';
    ord(FileCompressionInformation):               result := 'FileCompressionInformation';
    ord(FileObjectIdInformation):                  result := 'FileObjectIdInformation';
    ord(FileCompletionInformation):                result := 'FileCompletionInformation';
    ord(FileMoveClusterInformation):               result := 'FileMoveClusterInformation';
    ord(FileQuotaInformation):                     result := 'FileQuotaInformation';
    ord(FileReparsePointInformation):              result := 'FileReparsePointInformation';
    ord(FileNetworkOpenInformation):               result := 'FileNetworkOpenInformation';
    ord(FileAttributeTagInformation):              result := 'FileAttributeTagInformation';
    ord(FileTrackingInformation):                  result := 'FileTrackingInformation';
    ord(FileIdBothDirectoryInformation):           result := 'FileIdBothDirectoryInformation';
    ord(FileIdFullDirectoryInformation):           result := 'FileIdFullDirectoryInformation';
    ord(FileValidDataLengthInformation):           result := 'FileValidDataLengthInformation';
    ord(FileShortNameInformation):                 result := 'FileShortNameInformation';
    ord(FileIoCompletionNotificationInformation):  result := 'FileIoCompletionNotificationInformation';
    ord(FileIoStatusBlockRangeInformation):        result := 'FileIoStatusBlockRangeInformation';
    ord(FileIoPriorityHintInformation):            result := 'FileIoPriorityHintInformation';
    ord(FileSfioReserveInformation):               result := 'FileSfioReserveInformation';
    ord(FileSfioVolumeInformation):                result := 'FileSfioVolumeInformation';
    ord(FileHardLinkInformation):                  result := 'FileHardLinkInformation';
    ord(FileProcessIdsUsingFileInformation):       result := 'FileProcessIdsUsingFileInformation';
    ord(FileNormalizedNameInformation):            result := 'FileNormalizedNameInformation';
    ord(FileNetworkPhysicalNameInformation):       result := 'FileNetworkPhysicalNameInformation';
    ord(FileIdGlobalTxDirectoryInformation):       result := 'FileIdGlobalTxDirectoryInformation';
    ord(FileIsRemoteDeviceInformation):            result := 'FileIsRemoteDeviceInformation';
    ord(FileUnusedInformation):                    result := 'FileUnusedInformation';
    ord(FileNumaNodeInformation):                  result := 'FileNumaNodeInformation';
    ord(FileStandardLinkInformation):              result := 'FileStandardLinkInformation';
    ord(FileRemoteProtocolInformation):            result := 'FileRemoteProtocolInformation';
    ord(FileRenameInformationBypassAccessCheck):   result := 'FileRenameInformationBypassAccessCheck';
    ord(FileLinkInformationBypassAccessCheck):     result := 'FileLinkInformationBypassAccessCheck';
    ord(FileVolumeNameInformation):                result := 'FileVolumeNameInformation';
    ord(FileIdInformation):                        result := 'FileIdInformation';
    ord(FileIdExtdDirectoryInformation):           result := 'FileIdExtdDirectoryInformation';
    ord(FileReplaceCompletionInformation):         result := 'FileReplaceCompletionInformation';
    ord(FileHardLinkFullIdInformation):            result := 'FileHardLinkFullIdInformation';
    ord(FileIdExtdBothDirectoryInformation):       result := 'FileIdExtdBothDirectoryInformation';
    ord(FileDispositionInformationEx):             result := 'FileDispositionInformationEx';
    ord(FileRenameInformationEx):                  result := 'FileRenameInformationEx';
    ord(FileRenameInformationExBypassAccessCheck): result := 'FileRenameInformationExBypassAccessCheck';
    ord(FileDesiredStorageClassInformation):       result := 'FileDesiredStorageClassInformation';
    ord(FileStatInformation):                      result := 'FileStatInformation';
    ord(FileMemoryPartitionInformation):           result := 'FileMemoryPartitionInformation';
    ord(FileStatLxInformation):                    result := 'FileStatLxInformation';
    ord(FileCaseSensitiveInformation):             result := 'FileCaseSensitiveInformation';
    ord(FileMaximumInformation):                   result := 'FileMaximumInformation';
  else
    result := Legacy.IntToStr(FileInformationClass);
  end; // .switch FileInformationClass
end; // .function FileInformationClassToStr

function FileInformationClassToStr (FileInformationClass: FILE_INFORMATION_CLASS): AnsiString; overload;
begin
  result := FileInformationClassToStr(ord(FileInformationClass));
end;

function GetFileInformationClassSize (FileInformationClass: integer): integer; overload;
begin
  case FileInformationClass of
    ord(FileBothDirectoryInformation):   result := sizeof(FILE_BOTH_DIR_INFORMATION);
    ord(FileDirectoryInformation):       result := sizeof(FILE_DIRECTORY_INFORMATION);
    ord(FileFullDirectoryInformation):   result := sizeof(FILE_FULL_DIR_INFORMATION);
    ord(FileIdBothDirectoryInformation): result := sizeof(FILE_ID_BOTH_DIR_INFORMATION);
    ord(FileIdFullDirectoryInformation): result := sizeof(FILE_ID_FULL_DIR_INFORMATION);
    ord(FileNamesInformation):           result := sizeof(FILE_NAMES_INFORMATION);
  else
    result := 0;
  end; // .switch FileInformationClass
end; // .function GetFileInformationClassSize

function GetFileInformationClassSize (FileInformationClass: FILE_INFORMATION_CLASS): integer; overload;
begin
  result := GetFileInformationClassSize(ord(FileInformationClass));
end;

end.