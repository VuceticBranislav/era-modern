unit Files;
{
DESCRIPTION:  Implementations of virtual device with sequential access
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

// D2006      --> XE11.0
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
  Legacy,
  Math,
  SysUtils,
  Windows,

  CFiles,
  Log,
  UtilsB2,
  WinWrappers; {$WARN SYMBOL_PLATFORM OFF}

const
  (* IMPORT *)
  MODE_OFF        = CFiles.MODE_OFF;
  MODE_READ       = CFiles.MODE_READ;
  MODE_WRITE      = CFiles.MODE_WRITE;
  MODE_READWRITE  = CFiles.MODE_READWRITE;

  (* Scan function settings *)
  faNotDirectory  = Legacy.faAnyFile and not Legacy.faDirectory;
  ANY_EXT         = '';

  PATH_SEPARATORS       = ['/', '\'];
  DISK_LETTER_SEPARATOR = ':';

type
  (* IMPORT *)
  TDeviceMode = CFiles.TDeviceMode;
  TItemInfo   = CFiles.TItemInfo;

  TFixedBuf = class (CFiles.TAbstractFile)
    (***) protected (***)
      {OUn} fBuf:     pointer;
            fOwnsMem: boolean;

    (***) public (***)
      destructor  Destroy; override;
      procedure Open ({n} Buf: pointer; BufSize: integer; DeviceMode: TDeviceMode);
      procedure Close;
      procedure CreateNew (BufSize: integer);
      function  ReadUpTo (Count: integer; {n} Buf: pointer; out BytesRead: integer): boolean; override;
      function  WriteUpTo (Count: integer; {n} Buf: pointer; out ByteWritten: integer): boolean; override;
      function  Seek (NewPos: integer): boolean; override;

      property  Buf:      pointer read fBuf;
      property  OwnsMem:  boolean read fOwnsMem;
  end; // .class TFixedBuf

  TFile = class (CFiles.TAbstractFile)
    (***) protected (***)
      fhFile:     integer;
      fFilePath:  myAStr;

    (***) public (***)
      destructor  Destroy; override;
      function  Open (const FilePath: myAStr; DeviceMode: TDeviceMode): boolean;
      function  AttachToHandle (FileHandle: integer): boolean;
      procedure DetachHandle;
      procedure Close;
      function  CreateNew (const FilePath: myAStr): boolean;
      function  ReadUpTo (Count: integer; {n} Buf: pointer; out BytesRead: integer): boolean; override;
      function  WriteUpTo (Count: integer; {n} Buf: pointer; out ByteWritten: integer): boolean; override;
      function  Seek (NewPos: integer): boolean; override;

      property  hFile:    integer read fhFile;
      property  FilePath: myAStr read fFilePath;
  end; // .class TFile

  TFileItemInfo = class (CFiles.TItemInfo)
    Data: Windows.TWin32FindDataA;
  end; // .class TFileItemInfo

  TFileLocator  = class (CFiles.TAbstractLocator)
    (***) protected (***)
      fOpened:        boolean;
      fSearchHandle:  integer;
      fFindData:      Windows.TWin32FindDataA;
      fDirPath:       myAStr;

    (***) public (***)
      destructor  Destroy; override;

      procedure FinitSearch; override;
      procedure InitSearch (const Mask: myAStr); override;
      function  GetNextItem (out ItemInfo: TItemInfo): myAStr; override;
      function  GetItemInfo (const ItemName: myAStr; out ItemInfo: TItemInfo): boolean; override;

      property  DirPath:  myAStr read fDirPath write fDirPath;
  end; // .class TFileLocator

  TScanCallback = function (var SearchRes: Legacy.TSearchRec): boolean;


  (*  High level directory scanning
      Files are strictly matched against template with wildcards  *)

  PSearchRec = ^TSearchRec;
  TSearchRec = record
    Rec: Legacy.TSearchRec;

    function IsFile: boolean;
    function IsDir: boolean;
  end;

  TSearchSubj = (ONLY_FILES, ONLY_DIRS, FILES_AND_DIRS);

  ILocator = interface
    procedure Locate (const MaskedPath: myAStr; SearchSubj: TSearchSubj);
    function  FindNext: boolean;
    procedure FindClose;
    function  GetFoundName: myAStr;
    function  GetFoundPath: myAStr;
    function  GetFoundRec:  {U} PSearchRec;

    property FoundName: myAStr read GetFoundName;
    property FoundPath: myAStr read GetFoundPath;
    property FoundRec:  PSearchRec read GetFoundRec;
  end; // .interface ILocator


function  HasPathSeparators (const FileName: myAStr): boolean;
function  IsBaseName (const FileName: myAStr): boolean;
function  IsAbsPath (const FilePath: myAStr): boolean;

(* Replaces '/' with '\' and after that replaces all repeating '\' with single '\', unless it's leading double backslash like '\\?\' *)
function NormalizePathSeparators (const Path: myAStr): myAStr;

(* Normalizes paths and converts  main path to relative path. Returns empty string on failure *)
function ToRelativePath (FilePath, BasePath: myAStr): myAStr;

(* Converts path to relative if possible. Returns original path unmodified on failure *)
function ToRelativePathIfPossible (FilePath, BasePath: myAStr): myAStr;

function  ReadFileContents (const FilePath: myAStr; out FileContents: myAStr): boolean; overload;
function  ReadFileContents (FileHandle: integer; out FileContents: myAStr): boolean; overload;
function  WriteFileContents (const FileContents, FilePath: myAStr): boolean;
function  AppendFileContents (const FileContents, FilePath: myAStr): boolean;
function  DeleteDir (const DirPath: myAStr): boolean;
function  GetFileSize (const FilePath: myAStr; out Res: integer): boolean;
function  Scan
(
  const FileMask:         myAStr;
        AdditionalAttrs:  integer;
  const FileLowCaseExt:   myAStr;
        Callback:         TScanCallback
): boolean;

function FileExists (const FilePath: myAStr): boolean;
function DirExists  (const FilePath: myAStr): boolean;

(* Safe replacement for SysUtils.ForceDirectories, not raising exceptions *)
function  ForcePath (const DirPath: myAStr): boolean;

(* Converts file name into name, used internally by file system in order to apply search mask afterwards *)
function FileNameToFsInternalFileName (const Name: myAStr): myAStr;

(* Converts file name mask into mask, suited for internal file system names *)
function MaskToFsInternalMask (const Mask: myAStr): myAStr;

function  Locate (const MaskedPath: myAStr; SearchSubj: TSearchSubj): ILocator;


(***) implementation (***)
uses StrLib;

const
  FILES_EXTRA_DEBUG = false;


type
  TLocator = class (TInterfacedObject, ILocator)
    protected
      fLastOperRes:   boolean;
      fSearchStarted: boolean;
      fDir:           myAStr;
      fFileMask:      myAStr;
      fSearchSubj:    TSearchSubj;
      fFoundRec:      Legacy.TSearchRec;

      function  MatchResult: boolean;

    public
      constructor Create;
      destructor  Destroy; override;

      procedure Locate (const MaskedPath: myAStr; SearchSubj: TSearchSubj);
      function  FindNext: boolean;
      procedure FindClose;
      function  GetFoundName: myAStr;
      function  GetFoundPath: myAStr;
      function  GetFoundRec:  {U} PSearchRec;
  end; // .class TLocator


function HasPathSeparators (const FileName: myAStr): boolean;
var
  i: integer;

begin
  result := false;

  for i := 1 to Length(FileName) do begin
    if FileName[i] in PATH_SEPARATORS then begin
      result := true;

      exit;
    end;
  end;
end;

function IsBaseName (const FileName: myAStr): boolean;
begin
  result := not HasPathSeparators(FileName);
end;

function IsAbsPath (const FilePath: myAStr): boolean;
begin
  result := (FilePath <> '') and ((FilePath[1] in PATH_SEPARATORS) or ((Length(FilePath) >= 2) and (FilePath[2] = DISK_LETTER_SEPARATOR)));
end;

function NormalizePathSeparators (const Path: myAStr): myAStr;
var
  PrevWasPathDelim: boolean;
  StartPos:         integer;
  i, j:             integer;

begin
  result           := Path;
  StartPos         := 1;
  PrevWasPathDelim := false;

  if (Length(result) >= 2) and (result[1] in PATH_SEPARATORS) and (result[2] in PATH_SEPARATORS) then begin
    result[1]        := '\';
    result[2]        := '\';
    PrevWasPathDelim := true;
    StartPos         := 3;
  end;

  j := StartPos;

  for i := StartPos to Length(result) do begin
    if not (result[i] in PATH_SEPARATORS) then begin
      result[j]        := result[i];
      PrevWasPathDelim := false;
      Inc(j);
    end else if not PrevWasPathDelim then begin
      result[j]        := '\';
      PrevWasPathDelim := true;
      Inc(j);
    end;
  end;

  if (j - 1) <> Length(result) then begin
    SetLength(result, j - 1);
  end;
end; // .function NormalizePathSeparators

function ToRelativePath (FilePath, BasePath: myAStr): myAStr;
var
  FilePathLen: integer;
  BasePathLen: integer;

begin
  FilePath    := Legacy.ExpandFileName(FilePath);
  BasePath    := Legacy.ExpandFileName(BasePath);
  FilePathLen := Length(FilePath);
  BasePathLen := Length(BasePath);
  result      := '';

  if (FilePath = '') or (BasePath = '') then begin
    exit;
  end;

  if FilePath[FilePathLen] in PATH_SEPARATORS then begin
    Dec(FilePathLen);
  end;

  if BasePath[BasePathLen] in PATH_SEPARATORS then begin
    Dec(BasePathLen);
  end;

  if FilePath < BasePath then begin
    exit;
  end;

  if
    Legacy.CompareMem(myPChar(Legacy.AnsiLowerCase(FilePath)), myPChar(Legacy.AnsiLowerCase(BasePath)), BasePathLen) and
    ((FilePathLen = BasePathLen) or (FilePath[BasePathLen + 1] in PATH_SEPARATORS))
  then begin
    result := System.Copy(FilePath, BasePathLen + 1 + ord(FilePath[BasePathLen + 1] in PATH_SEPARATORS));

    if result = '' then begin
      result := '.';
    end;
  end;
end; // .function ToRelativePath

function ToRelativePathIfPossible (FilePath, BasePath: myAStr): myAStr;
begin
  result := ToRelativePath(FilePath, BasePath);

  if result = '' then begin
    result := FilePath;
  end;
end;

destructor TFixedBuf.Destroy;
begin
  Self.Close;
  inherited;
end;

procedure TFixedBuf.Open ({n} Buf: pointer; BufSize: integer; DeviceMode: TDeviceMode);
begin
  {!} Assert(UtilsB2.IsValidBuf(Buf, BufSize));
  {!} Assert(DeviceMode <> MODE_OFF);
  Self.Close;
  Self.fMode         := DeviceMode;
  Self.fHasKnownSize := true;
  Self.fSizeIsConst  := true;
  Self.fSize         := BufSize;
  Self.fPos          := 0;
  Self.fEOF          := BufSize = 0;
  Self.fBuf          := Buf;
  Self.fOwnsMem      := false;
end; // .procedure TFixedBuf.Open

procedure TFixedBuf.Close;
begin
  if (Self.fMode <> MODE_OFF) and Self.OwnsMem then begin
    FreeMem(Self.fBuf); Self.fBuf :=  nil;
  end;
  Self.fMode := MODE_OFF;
end;

procedure TFixedBuf.CreateNew (BufSize: integer);
var
(* on *)  NewBuf: pointer;

begin
  {!} Assert(BufSize >= 0);
  NewBuf  :=  nil;
  // * * * * * //
  if BufSize > 0 then begin
    GetMem(NewBuf, BufSize);
  end;
  Self.Open(NewBuf, BufSize, MODE_READWRITE); NewBuf  :=  nil;
  Self.fOwnsMem := true;
end; // .procedure TFixedBuf.CreateNew

function TFixedBuf.ReadUpTo (Count: integer; {n} Buf: pointer; out BytesRead: integer): boolean;
begin
  {!} Assert(UtilsB2.IsValidBuf(Buf, Count));
  result  :=  ((Self.Mode = MODE_READ) or (Self.Mode = MODE_READWRITE)) and (not Self.EOF) and (Count > 0);
  if result then begin
    BytesRead :=  Math.Min(Count, Self.Size - Self.Pos);
    UtilsB2.CopyMem(BytesRead, UtilsB2.PtrOfs(Self.Buf, Self.Pos), Buf);
    Self.fPos :=  Self.Pos + BytesRead;
    Self.fEOF :=  Self.Pos = Self.Size;
  end;
end; // .function TFixedBuf.ReadUpTo

function TFixedBuf.WriteUpTo (Count: integer; {n} Buf: pointer; out ByteWritten: integer): boolean;
begin
  {!} Assert(UtilsB2.IsValidBuf(Buf, Count));
  result  :=  ((Self.Mode = MODE_WRITE) or (Self.Mode = MODE_READWRITE)) and (not Self.EOF);
  if result then begin
    ByteWritten :=  Math.Min(Count, Self.Size - Self.Pos);
    UtilsB2.CopyMem(ByteWritten, Buf, UtilsB2.PtrOfs(Self.Buf, Self.Pos));
    Self.fPos :=  Self.Pos + ByteWritten;
    Self.fEOF :=  Self.Pos = Self.Size;
  end;
end; // .function TFixedBuf.WriteUpTo

function TFixedBuf.Seek (NewPos: integer): boolean;
begin
  {!} Assert(NewPos >= 0);
  result  :=  (Self.Mode <> MODE_OFF) and (NewPos <= Self.Size);
  if result then begin
    Self.fPos :=  NewPos;
    Self.fEOF :=  Self.Pos = Self.Size;
  end;
end;

destructor TFile.Destroy;
begin
  Self.Close;
  inherited Destroy;
end;

function TFile.Open (const FilePath: myAStr; DeviceMode: TDeviceMode): boolean;
var
  OpeningMode: integer;
  FileSizeL:   integer;
  FileSizeH:   integer;

begin
  {!} Assert(DeviceMode <> MODE_OFF);
  Self.Close;
  Self.fhFile := WinWrappers.INVALID_HANDLE;

  case DeviceMode of
    MODE_READ:      OpeningMode :=  Legacy.fmOpenRead or Legacy.fmShareDenyWrite;
    MODE_WRITE:     OpeningMode :=  Legacy.fmOpenWrite or Legacy.fmShareExclusive;
    MODE_READWRITE: OpeningMode :=  Legacy.fmOpenReadWrite or Legacy.fmShareExclusive;
  else
    OpeningMode :=  0;
  end;

  result := WinWrappers.FileOpen(FilePath, OpeningMode, Self.fhFile) and WinWrappers.GetFileSize(Self.hFile, FileSizeL, FileSizeH) and (FileSizeH = 0);

  if result then begin
    Self.fMode         := DeviceMode;
    Self.fSize         := FileSizeL;
    Self.fPos          := 0;
    Self.fEOF          := Self.Pos = Self.Size;
    Self.fFilePath     := FilePath;
    Self.fHasKnownSize := true;
    Self.fSizeIsConst  := false;
  end;
  // * * * * * //
  if (not result) and (Self.hFile <> WinWrappers.INVALID_HANDLE) then begin
    Windows.CloseHandle(Self.hFile);
  end;
end; // .function TFile.Open

function TFile.AttachToHandle (FileHandle: integer): boolean;
begin
  Self.Close;
  Self.fhFile := FileHandle;
  result      := FileHandle <> WinWrappers.INVALID_HANDLE;

  if result then begin
    Self.fMode         := MODE_READWRITE;
    Self.fSize         := 0;
    Self.fPos          := 0;
    Self.fEOF          := false;
    Self.fFilePath     := '';
    Self.fHasKnownSize := false;
    Self.fSizeIsConst  := false;
  end;
end; // .function TFile.AttachToHandle

procedure TFile.DetachHandle;
begin
  Self.fhFile := WinWrappers.INVALID_HANDLE;
  Self.Close;
end;

procedure TFile.Close;
begin
  if (Self.fMode <> MODE_OFF) and (Self.fhFile <> WinWrappers.INVALID_HANDLE) then begin
    Windows.CloseHandle(Self.fhFile);
    Self.fhFile := WinWrappers.INVALID_HANDLE;
  end;

  Self.fMode     := MODE_OFF;
  Self.fFilePath := '';
end;

function TFile.CreateNew (const FilePath: myAStr): boolean;
begin
  Self.Close;
  result := WinWrappers.FileCreate(FilePath, Self.fhFile);

  if result then begin
    Self.fMode         := MODE_READWRITE;
    Self.fSize         := 0;
    Self.fPos          := 0;
    Self.fEOF          := true;
    Self.fFilePath     := FilePath;
    Self.fHasKnownSize := true;
    Self.fSizeIsConst  := false;
  end;
end; // .function TFile.CreateNew

function TFile.ReadUpTo (Count: integer; {n} Buf: pointer; out BytesRead: integer): boolean;
begin
  {!} Assert(UtilsB2.IsValidBuf(Buf, Count));
  result  :=  ((Self.Mode = MODE_READ) or (Self.Mode = MODE_READWRITE)) and (not Self.EOF);

  if result then begin
    BytesRead := Legacy.FileRead(Self.hFile, Buf^, Count);
    result    := BytesRead > 0;
    Self.fPos := Self.Pos + BytesRead;
    Self.fEOF := (Self.fHasKnownSize and (Self.Pos = Self.Size)) or (BytesRead <= 0);
  end;
end; // .function TFile.ReadUpTo

function TFile.WriteUpTo (Count: integer; {n} Buf: pointer; out ByteWritten: integer): boolean;
begin
  {!} Assert(UtilsB2.IsValidBuf(Buf, Count));
  result := (Self.Mode = MODE_WRITE) or (Self.Mode = MODE_READWRITE);

  if result then begin
    ByteWritten := Legacy.FileWrite(Self.hFile, Buf^, Count);
    result      := ByteWritten > 0;
    Self.fPos   := Self.Pos + ByteWritten;
    Self.fSize  := Self.Size + ByteWritten;
    Self.fEOF   := Self.Pos = Self.Size;
  end; // .if
end; // .function TFile.WriteUpTo

function TFile.Seek (NewPos: integer): boolean;
var
  SeekRes:  integer;

begin
  {!} Assert(NewPos >= 0);
  result  :=  Self.Mode <> MODE_OFF;

  if result then begin
    SeekRes := Legacy.FileSeek(Self.hFile, NewPos, 0);
    result  := SeekRes <> -1;

    if result then begin
      Self.fPos := SeekRes;
      result    := SeekRes = NewPos;
    end;

    Self.fEOF := Self.Pos = Self.Size;
  end; // .if
end; // .function TFile.Seek

procedure TFileLocator.FinitSearch;
begin
  if Self.fOpened then begin
    Windows.FindClose(Self.fSearchHandle);
    Self.fOpened := false;
  end;
end;

procedure TFileLocator.InitSearch (const Mask: myAStr);
begin
  Self.FinitSearch;
  Self.fSearchMask := Mask;
  Self.fOpened     := WinWrappers.FindFirstFile(Self.DirPath + '\' + Mask, Self.fSearchHandle, Self.fFindData);
  Self.fNotEnd     := Self.fOpened;
end;

function TFileLocator.GetNextItem (out ItemInfo: TItemInfo): myAStr;
var
(* O *) FileInfo: TFileItemInfo;

begin
  {!} Assert(Self.NotEnd);
  {!} Assert(ItemInfo = nil);
  FileInfo := TFileItemInfo.Create;
  // * * * * * //
  FileInfo.IsDir := (Self.fFindData.dwFileAttributes and Windows.FILE_ATTRIBUTE_DIRECTORY) <> 0;

  if not FileInfo.IsDir and (Self.fFindData.nFileSizeHigh = 0) and (Self.fFindData.nFileSizeLow < $7FFFFFFF) then begin
    FileInfo.HasKnownSize := true;
    FileInfo.FileSize     := Self.fFindData.nFileSizeLow;
  end;

  FileInfo.Data := Self.fFindData;
  ItemInfo      := FileInfo; FileInfo  :=  nil;
  result        := Self.fFindData.cFileName;
  Self.fNotEnd  := WinWrappers.FindNextFile(Self.fSearchHandle, Self.fFindData);
end; // .function TFileLocator.GetNextItem

destructor TFileLocator.Destroy;
begin
  Self.FinitSearch;
  inherited;
end;

function TFileLocator.GetItemInfo (const ItemName: myAStr; out ItemInfo: TItemInfo): boolean;
var
(* O *) Locator:  TFileLocator;
        ItemPath: myAStr;

begin
  {!} Assert(ItemInfo = nil);
  Locator :=  TFileLocator.Create;
  // * * * * * //
  ItemPath  :=  Self.DirPath + '\' + ItemName;
  result    :=  Legacy.FileExists(ItemPath);
  if result then begin
    Locator.InitSearch(ItemPath);
    if Locator.NotEnd then begin
      Locator.GetNextItem(ItemInfo);
    end;
  end;
  Legacy.FreeAndNil(Locator);
end; // .function TFileLocator.GetItemInfo

function ReadFileContents (const FilePath: myAStr; out FileContents: myAStr): boolean;
var
{O} TheFile: TFile;

begin
  TheFile := TFile.Create;
  // * * * * * //
  result := TheFile.Open(FilePath, MODE_READ) and TheFile.ReadAllToStr(FileContents);

  if not result then begin
    FileContents := '';
  end;
  // * * * * * //
  Legacy.FreeAndNil(TheFile);
end; // .function ReadFileContents

function ReadFileContents (FileHandle: integer; out FileContents: myAStr): boolean; overload;
var
{O} TheFile: TFile;

begin
  TheFile := TFile.Create;
  // * * * * * //
  result := TheFile.AttachToHandle(FileHandle) and TheFile.ReadAllToStr(FileContents);
  TheFile.DetachHandle;

  if not result then begin
    FileContents := '';
  end;
  // * * * * * //
  Legacy.FreeAndNil(TheFile);
end; // .function ReadFileContents

function WriteFileContents (const FileContents, FilePath: myAStr): boolean;
var
{O} MyFile: TFile;

begin
  MyFile  :=  TFile.Create;
  // * * * * * //
  result  :=
    MyFile.CreateNew(FilePath)  and
    MyFile.WriteStr(FileContents);
  // * * * * * //
  Legacy.FreeAndNil(MyFile);
end; // .function WriteFileContents

function AppendFileContents (const FileContents, FilePath: myAStr): boolean;
var
{O} MyFile: TFile;

begin
  MyFile := TFile.Create;
  // * * * * * //
  if Legacy.FileExists(FilePath) then begin
    result := MyFile.Open(FilePath, MODE_WRITE) and MyFile.Seek(MyFile.Size);
  end else begin
    result := MyFile.CreateNew(FilePath);
  end;

  result := result and MyFile.WriteStr(FileContents);
  // * * * * * //
  Legacy.FreeAndNil(MyFile);
end; // .function AppendFileContents

function DeleteDir (const DirPath: myAStr): boolean;
var
{O} Locator:  TFileLocator;
{O} FileInfo: TFileItemInfo;
    FileName: myAStr;
    FilePath: myAStr;

begin
  Locator   :=  TFileLocator.Create;
  FileInfo  :=  nil;
  // * * * * * //
  result          :=  true;
  Locator.DirPath :=  DirPath;
  Locator.InitSearch('*');
  while result and Locator.NotEnd do begin
    FileName  :=  Locator.GetNextItem(CFiles.TItemInfo(FileInfo));
    if (FileName <> '.') and (FileName <> '..') then begin
      FilePath  :=  DirPath + '\' + FileName;
      if (FileInfo.Data.dwFileAttributes and Windows.FILE_ATTRIBUTE_DIRECTORY) <> 0 then begin
        result  :=  DeleteDir(FilePath);
      end else begin
        result  :=  Legacy.DeleteFile(FilePath);
      end;
    end;
    Legacy.FreeAndNil(FileInfo);
  end; // .while
  Locator.FinitSearch;
  result  :=  result and Legacy.RemoveDir(DirPath);
  // * * * * * //
  Legacy.FreeAndNil(Locator);
end; // .function DeleteDir

function GetFileSize (const FilePath: myAStr; out Res: integer): boolean;
var
{O} MyFile: TFile;

begin
  MyFile  :=  TFile.Create;
  // * * * * * //
  result  :=  MyFile.Open(FilePath, MODE_READ) and MyFile.HasKnownSize;
  if result then begin
    Res :=  MyFile.Size;
  end;
  // * * * * * //
  Legacy.FreeAndNil(MyFile);
end; // .function GetFileSize

function Scan
(
  const FileMask:         myAStr;
        AdditionalAttrs:  integer;
  const FileLowCaseExt:   myAStr;
        Callback:         TScanCallback
): boolean;

var
  SearchRec: Legacy.TSearchRec;

begin
  result := true;

  if SysUtils.FindFirst(string(FileMask), AdditionalAttrs, SearchRec) = 0 then begin
    repeat
      if
        (FileLowCaseExt = ANY_EXT) or
        (Legacy.ExtractFileExt(Legacy.AnsiLowerCase(myAStr(SearchRec.Name))) = FileLowCaseExt)
      then begin
        result  :=  Callback(SearchRec);
      end;
    until SysUtils.FindNext(SearchRec) <> 0;

    Legacy.FindClose(SearchRec);
  end; // .if
end; // .function Scan

function FileExists (const FilePath: myAStr): boolean;
var
  Attrs:  integer;

begin
  Attrs  := Windows.GetFileAttributesA(myPChar(FilePath));
  result := (Attrs <> - 1) and ((Attrs and Windows.FILE_ATTRIBUTE_DIRECTORY) = 0);
end;

function DirExists (const FilePath: myAStr): boolean;
var
  Attrs:  integer;

begin
  Attrs  := Windows.GetFileAttributesA(myPChar(FilePath));
  result := (Attrs <> - 1) and ((Attrs and Windows.FILE_ATTRIBUTE_DIRECTORY) <> 0);
end;

function ForcePath (const DirPath: myAStr): boolean;
var
  PathParts: StrLib.TArrayOfStr;
  TestPath:  myAStr;
  i:         integer;

begin
  result := true;

  if (DirPath = '') or (DirPath = '\') or (DirPath = '\\') or (DirPath = '/') then begin
    // Root or current directory always exist, do nothing
  end else begin
    PathParts := StrLib.Explode(StrLib.TrimEx(Legacy.StringReplace(DirPath, '/', '\', [Legacy.rfReplaceAll]), ['\'], [StrLib.RIGHT_SIDE]), '\');

    if length(PathParts) > 0 then begin
      TestPath := '';
      i        := 0;

      while result and (i < length(PathParts)) do begin
        if PathParts[i] <> '' then begin
          if TestPath <> '' then begin
            TestPath := TestPath + '\';
          end;

          TestPath := TestPath + PathParts[i];

          if not DirExists(TestPath) then begin
            result := Legacy.CreateDir(TestPath);
          end;
        end else if (TestPath = '') then begin
          TestPath := '\';
        end; // .elseif

        inc(i);
      end; // .while
    end; // .if
  end; // .else
end; // .function ForcePath

function MaskToFsInternalMask (const Mask: myAStr): myAStr;
var
  i: integer;

begin
  result := Legacy.AnsiLowerCase(Mask);
  i      := Length(result);

  while ((i > 0) and (result[i] = '*')) do begin
    Dec(i);
  end;

  // Almost each file name ends with "." internally in file system,
  // thus "test" mask should be actually "test."
  if (i > 0) and (result[i] <> '.') then begin
    result := result + '.';
  end;
end;

function FileNameToFsInternalFileName (const Name: myAStr): myAStr;
begin
  result := Legacy.AnsiLowerCase(Name);

  // Almost each file name ends with "." internally in file system,
  // thus "test" is actually "test."
  if (result <> '') and (result[Length(result)] <> '.') then begin
    result := result + '.';
  end;
end;

function TSearchRec.IsFile: boolean;
begin
  result := (Self.Rec.FindData.dwFileAttributes and Windows.FILE_ATTRIBUTE_DIRECTORY) = 0;
end;

function TSearchRec.IsDir: boolean;
begin
  result := (Self.Rec.FindData.dwFileAttributes and Windows.FILE_ATTRIBUTE_DIRECTORY) <> 0;
end;

constructor TLocator.Create;
begin
  inherited;
  Self.fLastOperRes := true;
end;

destructor TLocator.Destroy;
begin
  Self.FindClose;
  inherited;
end;

procedure TLocator.FindClose;
begin
  if Self.fSearchStarted then begin
    Legacy.FindClose(Self.fFoundRec);
    Self.fSearchStarted :=  false;
  end;
end;

function TLocator.MatchResult: boolean;
begin
  {!} Assert(Self.fSearchStarted and Self.fLastOperRes);
  result  :=  false;

  case Self.fSearchSubj of
    ONLY_FILES:     result  :=  (Self.fFoundRec.Attr and Legacy.faDirectory) = 0;
    ONLY_DIRS:      result  :=  (Self.fFoundRec.Attr and Legacy.faDirectory) <> 0;
    FILES_AND_DIRS: result  :=  true;
  else
    {!} Assert(false);
  end;

  result := result and StrLib.Match(FileNameToFsInternalFileName(myAStr(Self.fFoundRec.Name)), MaskToFsInternalMask(Self.fFileMask));

  if FILES_EXTRA_DEBUG then begin
    Log.Write('Files', 'TLocator.MatchResult', myAStr('Match "' + Self.fFoundRec.Name + '" to "') +
                                               Self.fFileMask + '" is ' + Legacy.IntToStr(ORD(result)));
  end;
end; // .function TLocator.MatchResult

function TLocator.FindNext: boolean;
begin
  {!} Assert(Self.fLastOperRes);
  result := false;

  if not Self.fSearchStarted then begin
    Self.fLastOperRes   := SysUtils.FindFirst(string(Self.fDir + '\*'), SysUtils.faAnyFile, Self.fFoundRec) = 0;
    Self.fSearchStarted := Self.fLastOperRes;
    result              := Self.fSearchStarted and Self.MatchResult;
  end;

  if not result and Self.fSearchStarted then begin
    while not result and (SysUtils.FindNext(Self.fFoundRec) = 0) do begin
      result := Self.MatchResult;
    end;

    Self.fLastOperRes := result;
  end;
end; // .function TLocator.FindNext

procedure TLocator.Locate (const MaskedPath: myAStr; SearchSubj: TSearchSubj);
begin
  Self.fDir := Legacy.ExtractFileDir(MaskedPath);

  if Self.fDir = '' then begin
    Self.fDir := '.';
  end;

  Self.fFileMask   := Legacy.ExtractFileName(MaskedPath);
  Self.fSearchSubj := SearchSubj;
end;

function TLocator.GetFoundName: myAStr;
begin
  {!} Assert(Self.fSearchStarted and Self.fLastOperRes);
  result  :=  myAStr(Self.fFoundRec.Name);
end;

function TLocator.GetFoundPath: myAStr;
begin
  {!} Assert(Self.fSearchStarted and Self.fLastOperRes);
  result  :=  Self.fDir + '\' + myAStr(Self.fFoundRec.Name);
end;

function TLocator.GetFoundRec: {U} PSearchRec;
begin
  {!} Assert(Self.fSearchStarted and Self.fLastOperRes);
  result  :=  @Self.fFoundRec;
end;

function Locate (const MaskedPath: myAStr; SearchSubj: TSearchSubj): ILocator;
var
{O} Locator: TLocator;

begin
  Locator := TLocator.Create;
  // * * * * * //
  Locator.Locate(MaskedPath, SearchSubj);
  result := Locator; Locator := nil;
end;

end.
