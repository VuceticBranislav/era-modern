unit VfsUtils;
(*
  
*)


(***)  interface  (***)

uses
  SysUtils, Math, Windows,
  UtilsB2, WinNative, Alg, TypeWrappers,
  Lists, DataLib, StrLib,
  VfsMatching, Legacy;

type
  (* Import *)
  TDict    = DataLib.TDict;
  TObjDict = DataLib.TObjDict;
  TString  = TypeWrappers.TString;
  TList    = Lists.TList;

const
  MAX_FILENAME_SIZE               = WinNative.MAX_FILENAME_LEN * sizeof(myWChar);
  DRIVE_CHAR_INDEX_IN_NT_ABS_PATH = 5; // \??\D:

type
  TSysOpenFileMode = (OPEN_AS_ANY = 0, OPEN_AS_FILE = WinNative.FILE_NON_DIRECTORY_FILE, OPEN_AS_DIR = WinNative.FILE_DIRECTORY_FILE);

  (* WINNT widest file structre wrapper *)
  PNativeFileInfo = ^TNativeFileInfo;
  TNativeFileInfo = record
    Base:     WinNative.FILE_ID_BOTH_DIR_INFORMATION;
    FileName: myWStr;

    procedure SetFileName (const NewFileName: myWStr);
    function  CopyFileNameToBuf ({ni} Buf: pbyte; BufSize: integer): boolean;
    function  GetFileSize: Int64;
  end;

  (* TNativeFileInfo wrapper for dynamical data structures with memory manamement *)
  TFileInfo = class
   public
    Data: TNativeFileInfo;

    constructor Create ({n} Data: PNativeFileInfo = nil);
  end;

  (* Universal directory listing holder *)
  TDirListing = class
   private
    {O} fFileList: {O} DataLib.TList {OF TFileInfo};
        fFileInd:  integer;

    function GetCount: integer;

   public
    constructor Create;
    destructor  Destroy; override;

    function  IsEnd: boolean;
    procedure AddItem ({U} FileInfo: PNativeFileInfo; const FileName: myWStr = ''; const InsertBefore: integer = High(integer));
    function  GetNextItem ({OUT} var {U} Res: TFileInfo): boolean;
    procedure Rewind;
    procedure Clear;

    (* Always seeks as close as possible *)
    function Seek (SeekInd: integer): boolean;
    function SeekRel (RelInd: integer): boolean;

    function GetDebugDump: myAStr;

    property FileInd: integer read fFileInd;
    property Count:   integer read GetCount;
  end; // .class TDirListing

  ISysDirScanner = interface
    function IterNext ({OUT} var FileName: myWStr; {n} FileInfo: WinNative.PFILE_ID_BOTH_DIR_INFORMATION = nil): boolean;
  end;

  TSysDirScanner = class (UtilsB2.TManagedObject, ISysDirScanner)
   protected const
     BUF_SIZE = 65000;

   protected
    fOwnsDirHandle: boolean;
    fDirHandle:     Windows.THandle;
    fMask:          myWStr;
    fMaskU:         WinNative.UNICODE_STRING;
    fIsStart:       boolean;
    fIsEnd:         boolean;
    fBufPos:        integer;
    fBuf:           array [0..BUF_SIZE - 1] of byte;

   public
    constructor Create (const hDir: Windows.THandle; const Mask: myWStr); overload;
    constructor Create (const DirPath, Mask: myWStr); overload;
    destructor Destroy; override;
    
    function IterNext ({OUT} var FileName: myWStr; {n} FileInfo: WinNative.PFILE_ID_BOTH_DIR_INFORMATION = nil): boolean;
  end; // .class TSysDirScanner


(* Packs lower cased WideString bytes into AnsiString buffer *)
function WideStrToCaselessKey (const Str: myWStr): myAStr;

(* The opposite of WideStrToKey *)
function CaselessKeyToWideStr (const CaselessKey: myAStr): myWStr;

(* Returns expanded unicode path, preserving trailing delimiter, or original path on error *)
function ExpandPath (const Path: myWStr): myWStr;

(* Returns path without trailing delimiter (for non-drives). Optionally returns flag, whether path had trailing delim or not.
   The flag is false for drives *)
function NormalizeAbsPath (const Path: myWStr; {n} HadTrailingDelim: pboolean = nil): myWStr;

(* Returns expanded path without trailing delimiter (for non-drives). Optionally returns flag, whether path had trailing delim or not.
   The flag is false for drives *)
function NormalizePath (const Path: myWStr; {n} HadTrailingDelim: pboolean = nil): myWStr;

(* Returns absolute normalized path with nt path prefix '\??\' (unless path already begins with '\' character).
   Optionally returns flag, whether path had trailing delim or not. *)
function ToNtAbsPath (const Path: myWStr; {n} HadTrailingDelim: pboolean = nil): myWStr;

(* Return true if path is valid absolute path to root drive like 'X:' with any/zero number of trailing slashes *)
function IsRootDriveAbsPath (const Path: myWStr): boolean;

(* Return true if path is valid absolute NT path to root drive like '\??\X:' with any/zero number of trailing slashes *)
function IsNtRootDriveAbsPath (const Path: myWStr): boolean;

(* Adds backslash to path end, unless there is already existing one *)
function AddBackslash (const Path: myWStr): myWStr;

(* Joins multiple path parts into single path. Backslashes are trimmed from each part and finally empty parts are ignored.
   Each part must be valid path part like '\DirName\\\' or 'C:' *)
function MakePath (const Parts: array of myWStr): myWStr;

(* Removes optional leading \??\ prefix from path *)
function StripNtAbsPathPrefix (const Path: myWStr): myWStr;

(* Saves API result in external variable and returns result as is *)
function SaveAndRet (Res: integer; out ResCopy): integer;

(* Returns attributes for file at given path *)
function GetFileAttrs (const Path: myWStr; {out} var Attrs: integer): boolean;

(* Returns true if directory with given path exists *)
function IsDir (const Path: myWStr): boolean;

(* Opens file/directory using absolute NT path and returns success flag *)
function SysOpenFile (const NtAbsPath: myWStr; {OUT} var Res: Windows.THandle; const OpenMode: TSysOpenFileMode = OPEN_AS_ANY; const AccessMode: ACCESS_MASK = FILE_GENERIC_READ): boolean;

(* Returns TNativeFileInfo record for single file/directory. Short names and files indexes/ids in the result are always empty. *)
function GetFileInfo (const FilePath: myWStr; {OUT} var Res: TNativeFileInfo): boolean;

function SysScanDir (const hDir: Windows.THandle; const Mask: myWStr): ISysDirScanner; overload;
function SysScanDir (const DirPath, Mask: myWStr): ISysDirScanner; overload;

(* Scans specified directory and adds sorted entries to directory listing. Optionally exclude names from Exclude dictionary.
   Excluded items must be preprocessed via WideStringToCaselessKey routine.
   Applies filtering by mask to fix possible invalid native functions behavior, found at least on Win XP when
   tests were run on network drive *)
procedure GetDirectoryListing (const SearchPath, FileMask: myWStr; {Un} Exclude: TDict {OF CaselessKey => not NIL}; DirListing: TDirListing);


(***)  implementation  (***)


type
  TDirListingItem = class
    SearchName: myWStr;
    Info:       TNativeFileInfo;
  end;


function WideStrToCaselessKey (const Str: myWStr): myAStr;
var
  ProcessedPath: myWStr;

begin
  result := '';

  if Str <> '' then begin
    ProcessedPath := StrLib.WideLowerCase(Str);
    SetLength(result, Length(ProcessedPath) * sizeof(ProcessedPath[1]) div sizeof(result[1]));
    UtilsB2.CopyMem(Length(result) * sizeof(result[1]), myPWChar(ProcessedPath), myPChar(result));
  end;
end;

function CaselessKeyToWideStr (const CaselessKey: myAStr): myWStr;
begin
  result := '';

  if CaselessKey <> '' then begin
    SetLength(result, Length(CaselessKey) * sizeof(CaselessKey[1]) div sizeof(result[1]));
    UtilsB2.CopyMem(Length(result) * sizeof(result[1]), myPChar(CaselessKey), myPWChar(result));
  end;
end;

function ExpandPath (const Path: myWStr): myWStr;
var
  BufLen:         integer;
  NumCharsCopied: integer;
  FileNameAddr:   myPWChar;

begin
  result := '';

  if Path <> '' then begin
    BufLen         := 0;
    NumCharsCopied := Windows.GetFullPathNameW(myPWChar(Path), 0, nil, FileNameAddr);

    while NumCharsCopied > BufLen do begin
      BufLen         := NumCharsCopied;
      SetLength(result, BufLen - 1);
      NumCharsCopied := Windows.GetFullPathNameW(myPWChar(Path), BufLen, myPWChar(result), FileNameAddr);
    end;

    if NumCharsCopied <= 0 then begin
      result := Path;
    end else begin
      SetLength(result, NumCharsCopied);
    end;
  end; // .if
end; // .function ExpandPath

function NormalizeAbsPath (const Path: myWStr; {n} HadTrailingDelim: pboolean = nil): myWStr;
begin
  result := StrLib.ExcludeTrailingBackslashW(Path, HadTrailingDelim);

  if (Length(result) = 2) and (result[2] = ':') then begin
    result := result + '\';

    if HadTrailingDelim <> nil then begin
      HadTrailingDelim^ := false;
    end;
  end;
end;

function NormalizePath (const Path: myWStr; {n} HadTrailingDelim: pboolean = nil): myWStr;
begin
  result := NormalizeAbsPath(ExpandPath(Path), HadTrailingDelim);
end;

function ToNtAbsPath (const Path: myWStr; {n} HadTrailingDelim: pboolean = nil): myWStr;
begin
  result := NormalizePath(Path, HadTrailingDelim);

  if (result <> '') and (result[1] <> '\') then begin
    result := '\??\' + result;
  end;
end;

function IsRootDriveAbsPath (const Path: myWStr): boolean;
const
  MIN_VALID_LEN = Length(myAStr('X:'));

var
  i: integer;

begin
  result := (Length(Path) >= MIN_VALID_LEN) and (ord(Path[1]) < 256) and (mychar(Path[1]) in ['A'..'Z']) and (Path[2] = ':');

  if result then begin
    for i := MIN_VALID_LEN + 1 to Length(Path) do begin
      if Path[i] <> '\' then begin
        result := false;
        exit;
      end;
    end;
  end;
end; // .function IsRootDriveAbsPath

function IsNtRootDriveAbsPath (const Path: myWStr): boolean;
const
  MIN_VALID_LEN = Length(myAStr('\??\X:'));

var
  i: integer;

begin
  result := (Length(Path) >= MIN_VALID_LEN) and (Path[1] = '\') and (Path[2] = '?') and (Path[3] = '?') and (Path[4] = '\') and (ord(Path[5]) < 256) and (mychar(Path[5]) in ['A'..'Z']) and (Path[6] = ':');

  if result then begin
    for i := MIN_VALID_LEN + 1 to Length(Path) do begin
      if Path[i] <> '\' then begin
        result := false;
        exit;
      end;
    end;
  end;
end; // .function IsNtRootDriveAbsPath

function StripNtAbsPathPrefix (const Path: myWStr): myWStr;
begin
  result := Path;

  if (Length(Path) >= 4) and (Path[1] = '\') and (Path[2] = '?') and (Path[3] = '?') and (Path[4] = '\') then begin
    result := Copy(Path, 4 + 1);
  end;
end;

function AddBackslash (const Path: myWStr): myWStr;
begin
  if (Path = '') or (Path[Length(Path)] <> '\') then begin
    result := Path + '\';
  end else begin
    result := Path;
  end;
end;

function MakePath (const Parts: array of myWStr): myWStr;
var
{n} CurrChar: myPWChar;
    Part:     myWStr;
    PartLen:  integer;
    ResLen:   integer;
    i:        integer;

begin
  CurrChar := nil;
  // * * * * * //
  ResLen := 0;
  
  // Calculate estimated final string length, assume extra '\' for each non-empty part
  for i := 0 to High(Parts) do begin
    if Parts[i] <> '' then begin
      Inc(ResLen, Length(Parts[i]) + 1);
    end;
  end;

  SetLength(result, ResLen);
  CurrChar := myPWChar(result);

  for i := 0 to High(Parts) do begin
    PartLen := Length(Parts[i]);

    if PartLen > 0 then begin
      Part := StrLib.TrimBackslashesW(Parts[i]);
      
      if Part <> '' then begin
        // Add '\' glue for non-first part
        if i = 0 then begin
          Dec(ResLen);
        end else begin
          CurrChar^ := '\';
          Inc(CurrChar);
        end;
        
        Dec(ResLen, PartLen - Length(Part));
        PartLen := Length(Part);
        
        UtilsB2.CopyMem(PartLen * sizeof(myWChar), myPWChar(Part), CurrChar);
        Inc(CurrChar, PartLen);
      end else begin
        Dec(ResLen, PartLen + 1);
      end;
    end;
  end; // .for

  // Trim garbage at final string end
  SetLength(result, ResLen);
end; // .function MakePath

function SaveAndRet (Res: integer; out ResCopy): integer;
begin
  integer(ResCopy) := Res;
  result           := Res;
end;

procedure TNativeFileInfo.SetFileName (const NewFileName: myWStr);
begin
  Self.FileName            := NewFileName;
  Self.Base.FileNameLength := Length(NewFileName) * sizeof(myWChar);
end;

function TNativeFileInfo.CopyFileNameToBuf ({ni} Buf: pbyte; BufSize: integer): boolean;
begin
  {!} Assert(UtilsB2.IsValidBuf(Buf, BufSize));
  result := integer(Self.Base.FileNameLength) <= BufSize;

  if BufSize > 0 then begin
    UtilsB2.CopyMem(Self.Base.FileNameLength, myPWChar(Self.FileName), Buf);
  end;
end;

function TNativeFileInfo.GetFileSize: Int64;
begin
  result := Self.Base.EndOfFile.QuadPart;
end;

constructor TFileInfo.Create ({n} Data: PNativeFileInfo = nil);
begin
  if Data <> nil then begin
    Self.Data := Data^;
  end;
end;

constructor TDirListing.Create;
begin
  Self.fFileList := DataLib.NewList(UtilsB2.OWNS_ITEMS);
  Self.fFileInd  := 0;
end;

destructor TDirListing.Destroy;
begin
  Legacy.FreeAndNil(Self.fFileList);
end;

procedure TDirListing.AddItem (FileInfo: PNativeFileInfo; const FileName: myWStr = ''; const InsertBefore: integer = High(integer));
var
{O} Item: TFileInfo;

begin
  {!} Assert(FileInfo <> nil);
  // * * * * * //
  Item := TFileInfo.Create(FileInfo);

  if FileName <> '' then begin
    Item.Data.SetFileName(FileName);
  end;

  if InsertBefore >= Self.fFileList.Count then begin
    Self.fFileList.Add(Item); Item := nil;
  end else begin
    Self.fFileList.Insert(Item, InsertBefore); Item := nil;
  end;  
  // * * * * * //
  Legacy.FreeAndNil(Item);
end; // .procedure TDirListing.AddItem

function TDirListing.GetCount: integer;
begin
  result := Self.fFileList.Count;
end;

function TDirListing.IsEnd: boolean;
begin
  result := Self.fFileInd >= Self.fFileList.Count;
end;

function TDirListing.GetNextItem ({OUT} var Res: TFileInfo): boolean;
begin
  result := Self.fFileInd < Self.fFileList.Count;

  if result then begin
    Res := TFileInfo(Self.fFileList[Self.fFileInd]);
    Inc(Self.fFileInd);
  end;
end;

procedure TDirListing.Rewind;
begin
  Self.fFileInd := 0;
end;

procedure TDirListing.Clear;
begin
  Self.fFileList.Clear;
  Self.fFileInd := 0;
end;

function TDirListing.Seek (SeekInd: integer): boolean;
begin
  Self.fFileInd := Alg.ToRange(SeekInd, 0, Self.fFileList.Count - 1);
  result        := Self.fFileInd = SeekInd;
end;

function TDirListing.SeekRel (RelInd: integer): boolean;
begin
  result := Self.Seek(Self.fFileInd + RelInd);    
end;

function TDirListing.GetDebugDump: myAStr;
var
  FileNames: UtilsB2.TArrayOfStr;
  i:         integer;

begin
  SetLength(FileNames, Self.fFileList.Count);

  for i := 0 to Self.fFileList.Count - 1 do begin
    FileNames[i] := myAStr(TFileInfo(Self.fFileList[i]).Data.FileName);
  end;

  result := StrLib.Join(FileNames, #13#10);
end;

function GetFileAttrs (const Path: myWStr; {out} var Attrs: integer): boolean;
const
  INVALID_FILE_ATTRIBUTES = -1;

var
  Res: integer;

begin
  Res    := integer(Windows.GetFileAttributesW(myPWChar(Path)));
  result := Res <> INVALID_FILE_ATTRIBUTES;

  if result then begin
    Attrs := Res;
  end;
end;

function IsDir (const Path: myWStr): boolean;
var
  FileAttrs: integer;

begin
  result := GetFileAttrs(Path, FileAttrs) and UtilsB2.Flags(FileAttrs).Have(Windows.FILE_ATTRIBUTE_DIRECTORY);
end;

function SysOpenFile (const NtAbsPath: myWStr; {OUT} var Res: Windows.THandle; const OpenMode: TSysOpenFileMode = OPEN_AS_ANY; const AccessMode: ACCESS_MASK = FILE_GENERIC_READ): boolean;
var
  FilePathU:     WinNative.UNICODE_STRING;
  hFile:         Windows.THandle;
  ObjAttrs:      WinNative.OBJECT_ATTRIBUTES;
  IoStatusBlock: WinNative.IO_STATUS_BLOCK;

begin
  FilePathU.AssignExistingStr(NtAbsPath);
  ObjAttrs.Init(@FilePathU);


  result := WinNative.NtOpenFile(@hFile, AccessMode, @ObjAttrs, @IoStatusBlock, FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE,
                                 ord(OpenMode) or FILE_SYNCHRONOUS_IO_NONALERT or FILE_OPEN_FOR_BACKUP_INTENT) = WinNative.STATUS_SUCCESS;

  if result then begin
    Res := hFile;
  end;
end; // .function SysOpenFile

function GetFileInfo (const FilePath: myWStr; {OUT} var Res: TNativeFileInfo): boolean;
const
  BUF_SIZE = sizeof(WinNative.FILE_ALL_INFORMATION) + MAX_FILENAME_SIZE;

var
{U} FileAllInfo:   WinNative.PFILE_ALL_INFORMATION;
    NtAbsPath:     myWStr;
    hFile:         Windows.THandle;
    Buf:           array [0..BUF_SIZE - 1] of byte;
    IoStatusBlock: WinNative.IO_STATUS_BLOCK;

begin
  FileAllInfo := @Buf;
  // * * * * * //
  NtAbsPath := ToNtAbsPath(FilePath); 
  result    := SysOpenFile(NtAbsPath, hFile, OPEN_AS_ANY, STANDARD_RIGHTS_READ or FILE_READ_ATTRIBUTES or FILE_READ_EA or SYNCHRONIZE);

  if not result then begin
    exit;
  end;

  if IsNtRootDriveAbsPath(NtAbsPath) then begin
    // Return fake info for root drive
    result := GetFileAttrs(StripNtAbsPathPrefix(NtAbsPath), integer(FileAllInfo.BasicInformation.FileAttributes));

    if result then begin
      Legacy.FillChar(Res.Base, sizeof(Res.Base), 0);
      Res.Base.FileAttributes := FileAllInfo.BasicInformation.FileAttributes;
      Res.SetFileName(NtAbsPath[DRIVE_CHAR_INDEX_IN_NT_ABS_PATH] + myWStr(':\'#0));
    end;
  end else begin
    result := WinNative.NtQueryInformationFile(hFile, @IoStatusBlock, FileAllInfo, BUF_SIZE, ord(WinNative.FileAllInformation)) = WinNative.STATUS_SUCCESS;

    if result then begin
      Res.Base.FileIndex       := 0;
      Res.Base.CreationTime    := FileAllInfo.BasicInformation.CreationTime;
      Res.Base.LastAccessTime  := FileAllInfo.BasicInformation.LastAccessTime;
      Res.Base.LastWriteTime   := FileAllInfo.BasicInformation.LastWriteTime;
      Res.Base.ChangeTime      := FileAllInfo.BasicInformation.ChangeTime;
      Res.Base.FileAttributes  := FileAllInfo.BasicInformation.FileAttributes;
      Res.Base.EndOfFile       := FileAllInfo.StandardInformation.EndOfFile;
      Res.Base.AllocationSize  := FileAllInfo.StandardInformation.AllocationSize;
      Res.Base.EaSize          := FileAllInfo.EaInformation.EaSize;
      Res.Base.ShortNameLength := 0;
      Res.Base.ShortName[0]    := #0;
      Res.Base.FileNameLength  := FileAllInfo.NameInformation.FileNameLength;
      Res.Base.FileId.LowPart  := 0;
      Res.Base.FileId.HighPart := 0;

      Res.SetFileName(StrLib.ExtractFileNameW(StrLib.WideStringFromBuf(
        @FileAllInfo.NameInformation.FileName,
        Max(0, Min(integer(IoStatusBlock.Information) - sizeof(FileAllInfo^), FileAllInfo.NameInformation.FileNameLength)) div sizeof(myWChar)
      )));
    end; // .if
  end; // .else

  WinNative.NtClose(hFile);
end; // .function GetFileInfo

constructor TSysDirScanner.Create (const hDir: Windows.THandle; const Mask: myWStr);
begin
  Self.fOwnsDirHandle := false;
  Self.fDirHandle     := hDir;
  Self.fMask          := StrLib.WideLowerCase(Mask);
  Self.fMaskU.AssignExistingStr(Self.fMask);
  Self.fIsStart       := true;
  Self.fIsEnd         := false;
  Self.fBufPos        := 0;
end;

constructor TSysDirScanner.Create (const DirPath, Mask: myWStr);
var
  hDir: Windows.THandle;

begin
  hDir := Windows.INVALID_HANDLE_VALUE;
  SysOpenFile(ToNtAbsPath(DirPath), hDir, OPEN_AS_DIR, FILE_LIST_DIRECTORY or SYNCHRONIZE);

  Self.Create(hDir, Mask);

  if hDir <> Windows.INVALID_HANDLE_VALUE then begin
    Self.fOwnsDirHandle := true;
  end else begin
    Self.fIsEnd := true;
  end;
end; // .constructor TSysDirScanner.Create

destructor TSysDirScanner.Destroy;
begin
  if Self.fOwnsDirHandle then begin
    WinNative.NtClose(Self.fDirHandle);
  end;
end;

function TSysDirScanner.IterNext ({OUT} var FileName: myWStr; {n} FileInfo: WinNative.PFILE_ID_BOTH_DIR_INFORMATION = nil): boolean;
const
  MULTIPLE_ENTRIES = false;

var
{n} FileInfoInBuf: WinNative.PFILE_ID_BOTH_DIR_INFORMATION;
    IoStatusBlock: WinNative.IO_STATUS_BLOCK;
    FileNameLen:   integer;
    Status:        integer;

begin
  FileInfoInBuf := nil;
  // * * * * * //
  result := not Self.fIsEnd and (Self.fDirHandle <> Windows.INVALID_HANDLE_VALUE);

  if not result then begin
    exit;
  end;

  if not Self.fIsStart and (Self.fBufPos < Self.BUF_SIZE) then begin
    FileInfoInBuf := @Self.fBuf[Self.fBufPos];
    FileNameLen   := Min(FileInfoInBuf.FileNameLength, Self.BUF_SIZE - Self.fBufPos) div sizeof(myWChar);
    FileName      := StrLib.WideStringFromBuf(@FileInfoInBuf.FileName, FileNameLen);

    if FileInfo <> nil then begin
      FileInfo^               := FileInfoInBuf^;
      FileInfo.FileNameLength := FileNameLen * sizeof(myWChar);
    end;

    Self.fBufPos := UtilsB2.IfThen(FileInfoInBuf.NextEntryOffset <> 0, Self.fBufPos + integer(FileInfoInBuf.NextEntryOffset), Self.BUF_SIZE);
  end else begin
    Self.fBufPos  := 0;
    Status        := WinNative.NtQueryDirectoryFile(Self.fDirHandle, 0, nil, nil, @IoStatusBlock, @Self.fBuf, Self.BUF_SIZE, ord(WinNative.FileIdBothDirectoryInformation), MULTIPLE_ENTRIES, @Self.fMaskU, Self.fIsStart);
    result        := (Status = WinNative.STATUS_SUCCESS) and (integer(IoStatusBlock.Information) <> 0);
    Self.fIsStart := false;

    if result then begin
      result := Self.IterNext(FileName, FileInfo);
    end else begin
      Self.fIsEnd := true;
    end;
  end; // .else
end; // .function TSysDirScanner.IterNext

function SysScanDir (const hDir: Windows.THandle; const Mask: myWStr): ISysDirScanner; overload;
begin
  result := TSysDirScanner.Create(hDir, Mask);
end;

function SysScanDir (const DirPath, Mask: myWStr): ISysDirScanner; overload;
begin
  result := TSysDirScanner.Create(DirPath, Mask);
end;

function CompareFileItemsByNameAsc (Item1, Item2: integer): integer;
begin
  result := StrLib.CompareBinStringsW(TDirListingItem(Item1).SearchName, TDirListingItem(Item2).SearchName);

  if result = 0 then begin
    result := StrLib.CompareBinStringsW(TDirListingItem(Item1).Info.FileName, TDirListingItem(Item2).Info.FileName);
  end;
end;

procedure SortDirListing ({U} List: TList {OF TDirListingItem});
begin
  List.CustomSort(CompareFileItemsByNameAsc);
end;

procedure GetDirectoryListing (const SearchPath, FileMask: myWStr; {Un} Exclude: TDict {OF CaselessKey => not NIL}; DirListing: TDirListing);
var
{O} Items: {O} TList {OF TDirListingItem};
{O} Item:  {O} TDirListingItem;
    i:     integer;

begin
  {!} Assert(DirListing <> nil);
  Items := DataLib.NewList(UtilsB2.OWNS_ITEMS);
  Item  := TDirListingItem.Create;
  // * * * * * //
  with VfsUtils.SysScanDir(SearchPath, FileMask) do begin
    while IterNext(Item.Info.FileName, @Item.Info.Base) do begin     
      if (Exclude = nil) or (Exclude[WideStrToCaselessKey(Item.Info.FileName)] = nil) then begin
        Item.SearchName := StrLib.WideLowerCase(Item.Info.FileName);
        Items.Add(Item); Item := nil;
        Item := TDirListingItem.Create;
      end;
    end;
  end;

  SortDirListing(Items);

  for i := 0 to Items.Count - 1 do begin
    DirListing.AddItem(@TDirListingItem(Items[i]).Info);
  end;
  // * * * * * //
  Legacy.FreeAndNil(Items);
  Legacy.FreeAndNil(Item);
end; // .procedure GetDirectoryListing

end.