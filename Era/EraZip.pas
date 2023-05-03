unit EraZip;
(*
  Provides joined file system support for contents from zip-archives and real directories.
*)


(***)  interface  (***)

uses
  Math,
  SysUtils,
  Windows,

  DataLib,
  DlgMes,
  EventMan,
  Files,
  GameExt,
  KubaZip,
  StrLib,
  UtilsB2, Legacy; {$WARN SYMBOL_PLATFORM OFF}

type
  (* Import *)
  TDict       = DataLib.TDict;
  TList       = DataLib.TList;
  PZipStruct  = KubaZip.PZipStruct;
  TSearchSubj = Files.TSearchSubj;
  ILocator    = Files.ILocator;

  TZipItem = class
   protected
    {On} fChildren:   {U} TList {of TZipItem};
    {Un} fZip:        PZipStruct;
         fEntryIndex: integer;
         fName:       myAStr;
         fPath:       myAStr;
         fSize:       integer;

   public
    constructor Create (Zip: PZipStruct; EntryIndex: integer; const Path: myAStr; Size: integer);
    destructor Destroy; override;

    function  CountChildren: integer;
    function  IsDir: boolean;
    procedure AddChild (Child: TZipItem);
    function  ReadAsString: myAStr;

    property Zip:         {Un} PZipStruct read fZip write fZip;
    property EntryIndex:  integer   read fEntryIndex write fEntryIndex;
    property Name:        myAStr    read fName;
    property Path:        myAStr    read fPath;
    property Size:        integer   read fSize write fSize;
    property Children:    {n} TList read fChildren;
    property NumChildren: integer   read CountChildren;
  end; // .class TZipItem

  TZipItemIterator = class (TInterfacedObject, ILocator)
    protected
    {U}  fZipItem:       TZipItem;
         fSearchStarted: boolean;
         fZipItemPos:    integer;
    {Un} fCurrChild:     TZipItem;
         fFileMask:      myAStr;
         fSearchSubj:    TSearchSubj;
         fFoundRec:      Legacy.TSearchRec;

      function IsValidPos:    boolean;
      function GotoNextChild: boolean;
      function MatchResult:   boolean;

    public
      constructor Create (ZipItem: TZipItem);
      destructor Destroy; override;

      procedure Locate (const MaskedPath: myAStr; SearchSubj: TSearchSubj);
      function  FindNext: boolean;
      procedure FindClose;
      function  GetFoundName: myAStr;
      function  GetFoundPath: myAStr;
      function  GetFoundRec:  {U} PSearchRec;
  end; // .class TZipItemIterator

  TVirtualFsIterator = class (TInterfacedObject, ILocator)
    protected
    {O} fSeenNames:     {U} TDict {of Ptr(1)};
    {S} fIterators:     array of ILocator;
        fIterIndex:     integer;
        fSearchStarted: boolean;

    public
      constructor Create (const Iterators: array of ILocator);
      destructor Destroy; override;

      procedure Locate (const MaskedPath: myAStr; SearchSubj: TSearchSubj);
      function  FindNext: boolean;
      procedure FindClose;
      function  GetFoundName: myAStr;
      function  GetFoundPath: myAStr;
      function  GetFoundRec:  {U} PSearchRec;
  end;

  TZipFs = class
   protected
   {O} fZipFiles:    {O} TList {of PZipStruct};
   {O} fZipItemsMap: {O} TDict {of TZipItem};
   {O} fZipRootItem: TZipItem;

    function ForcePath (const Path: myAStr): {U} TZipItem;

   public
    constructor Create;
    destructor Destroy; override;

    procedure Clear;
    procedure AddZipsFromDir (const Dir: myAStr);
    function FindItem (const RelPath: myAStr): {Un} TZipItem;
  end;


var
{O} ZipFs: TZipFs;


(* Scans files in both real directories and ZipFs (if path is game directory relative). Paths from ZipFS are prefixed with "zip:\" *)
function LocateInZipFs (const MaskedPath: myAStr; SearchSubj: TSearchSubj): ILocator;

(* Reads either file from real FS or from zip FS. Automatically detects paths in game directory or prefixed with "zip:\". *)
function ReadFileContentsFromZipFs (const FilePath: myAStr; var FileContents: myAStr): boolean;

(* Convers real FS or zip FS path into relative path or returns empty string. Any path in zip is considered relative *)
function ToRelativePath (FilePath, BasePath: myAStr): myAStr;

(* Convers real FS or zip FS path into relative path or returns original string. Any path in zip is considered relative *)
function ToRelativePathIfPossible (FilePath, BasePath: myAStr): myAStr;


(***)  implementation  (***)


function UnixPathToWinPath (const UnixPath: myAStr): myAStr;
var
  i: integer;

begin
  result := UnixPath;

  for i := 1 to Length(result) do begin
    if result[i] = '/' then begin
      result[i] := '\';
    end;
  end;
end;

constructor TZipItem.Create ({n} Zip: PZipStruct; EntryIndex: integer; const Path: myAStr; Size: integer);
begin
  inherited Create;

  Self.fZip        := Zip;
  Self.fEntryIndex := EntryIndex;
  Self.fName       := Legacy.ExtractFileName(Path);
  Self.fPath       := Path;
  Self.fSize       := Size;
end;

destructor TZipItem.Destroy;
begin
  Legacy.FreeAndNil(Self.fChildren);
  inherited;
end;

function TZipItem.CountChildren: integer;
begin
  result := 0;

  if Self.fChildren <> nil then begin
    result := Self.fChildren.Count;
  end;
end;

function TZipItem.IsDir: boolean;
begin
  result := Self.CountChildren > 0;
end;

procedure TZipItem.AddChild (Child: TZipItem);
begin
  if Self.fChildren = nil then begin
    Self.fChildren := DataLib.NewList(not UtilsB2.OWNS_ITEMS);
  end;

  Self.fChildren.Add(Child);
end;

function TZipItem.ReadAsString: myAStr;
begin
  result := '';

  if (Self.fSize > 0) and (KubaZip.zip_entry_openbyindex(Self.fZip, Self.fEntryIndex) = KubaZip.ZIP_NO_ERROR) then begin
    SetLength(result, Self.fSize);
    KubaZip.zip_entry_noallocread(Self.fZip, pointer(result), Self.fSize);
    KubaZip.zip_entry_close(Self.fZip);
  end;
end;

constructor TZipItemIterator.Create (ZipItem: TZipItem);
begin
  inherited Create;

  {!} Assert(ZipItem <> nil);
  Self.fZipItem    := ZipItem;
  Self.fZipItemPos := -1;
end;

destructor TZipItemIterator.Destroy;
begin
  Self.FindClose;

  inherited;
end;

function TZipItemIterator.IsValidPos: boolean;
begin
  result := Math.InRange(Self.fZipItemPos, 0, Self.fZipItem.NumChildren - 1);
end;

function TZipItemIterator.GotoNextChild: boolean;
begin
  if Self.fZipItemPos < Self.fZipItem.NumChildren then begin
    Inc(Self.fZipItemPos);
  end;

  result := Self.IsValidPos;

  if result then begin
    Self.fCurrChild     := TZipItem(Self.fZipItem.Children[Self.fZipItemPos]);
    {!} Assert(Self.fCurrChild.Name <> '');
    Self.fFoundRec.Name := string(Self.fCurrChild.Name);
    Self.fFoundRec.Size := Self.fCurrChild.Size;
    Self.fFoundRec.Attr := Legacy.faDirectory * ord(Self.fCurrChild.IsDir);
    Self.fFoundRec.FindData.dwFileAttributes := Windows.FILE_ATTRIBUTE_DIRECTORY * ord(Self.fCurrChild.IsDir);
  end;
end;

function TZipItemIterator.MatchResult: boolean;
begin
  {!} Assert(Self.IsValidPos);
  result := false;

  case Self.fSearchSubj of
    Files.ONLY_FILES:     result := (Self.fFoundRec.Attr and Legacy.faDirectory) = 0;
    Files.ONLY_DIRS:      result := (Self.fFoundRec.Attr and Legacy.faDirectory) <> 0;
    Files.FILES_AND_DIRS: result := true;
  else
    {!} Assert(false);
  end;

  result := result and StrLib.Match(Files.FileNameToFsInternalFileName(myAStr(Self.fFoundRec.Name)), Files.MaskToFsInternalMask(Self.fFileMask));
end;

procedure TZipItemIterator.Locate (const MaskedPath: myAStr; SearchSubj: TSearchSubj);
begin
  Self.fFileMask   := Legacy.ExtractFileName(MaskedPath);
  Self.fSearchSubj := SearchSubj;
end;

function TZipItemIterator.FindNext: boolean;
begin
  result := Self.GotoNextChild;

  if result then begin
    result := Self.MatchResult;

    while not result and Self.GotoNextChild do begin
      result := Self.MatchResult;
    end;
  end;
end;

procedure TZipItemIterator.FindClose;
begin
  Self.fZipItemPos := -1;
end;

function TZipItemIterator.GetFoundName: myAStr;
begin
  {!} Assert(Self.IsValidPos);
  result := myAStr(Self.fFoundRec.Name);
end;

function TZipItemIterator.GetFoundPath: myAStr;
begin
  {!} Assert(Self.IsValidPos);

  if Self.fZipItem.Path <> '' then begin
    result := 'zip:\' + Self.fZipItem.Path + '\' + myAStr(Self.fFoundRec.Name);
  end else begin
    result := myAStr('zip:\' + Self.fFoundRec.Name);
  end;
end;

function TZipItemIterator.GetFoundRec: {U} PSearchRec;
begin
  {!} Assert(Self.IsValidPos);
  result := @Self.fFoundRec;
end;

constructor TVirtualFsIterator.Create (const Iterators: array of ILocator);
var
  i: integer;

begin
  inherited Create;

  Self.fSeenNames := DataLib.NewDict(not UtilsB2.OWNS_ITEMS, DataLib.CASE_INSENSITIVE);
  SetLength(Self.fIterators, Length(Iterators));

  for i := 0 to High(Iterators) do begin
    {!} Assert(Iterators[i] <> nil);
    Self.fIterators[i] := Iterators[i];
  end;
end;

destructor TVirtualFsIterator.Destroy;
begin
  Self.FindClose;
  Legacy.FreeAndNil(Self.fSeenNames);

  inherited;
end;

procedure TVirtualFsIterator.Locate (const MaskedPath: myAStr; SearchSubj: TSearchSubj);
var
  i: integer;

begin
  for i := 0 to Length(Self.fIterators) - 1 do begin
    Self.fIterators[i].Locate(MaskedPath, SearchSubj);
  end;
end;

function TVirtualFsIterator.FindNext: boolean;
var
  FileName: myAStr;

begin
  result := false;

  while not result and (Self.fIterIndex < Length(Self.fIterators)) do begin
    result := Self.fIterators[Self.fIterIndex].FindNext;

    if result then begin
      FileName := Self.fIterators[Self.fIterIndex].GetFoundName;
      result   := Self.fSeenNames[FileName] = nil;

      if result then begin
        Self.fSeenNames[FileName] := Ptr(1);
      end;
    end else begin
      Inc(Self.fIterIndex);
    end;
  end; // .while
end;

procedure TVirtualFsIterator.FindClose;
var
  i: integer;

begin
  Self.fSeenNames.Clear;
  Self.fIterIndex := 0;

  for i := 0 to Length(Self.fIterators) - 1 do begin
    Self.fIterators[i].FindClose;
  end;
end;

function TVirtualFsIterator.GetFoundName: myAStr;
begin
  result := Self.fIterators[Self.fIterIndex].GetFoundName;
end;

function TVirtualFsIterator.GetFoundPath: myAStr;
begin
  result := Self.fIterators[Self.fIterIndex].GetFoundPath;
end;

function TVirtualFsIterator.GetFoundRec: {U} PSearchRec;
begin
  result := Self.fIterators[Self.fIterIndex].GetFoundRec;
end;

constructor TZipFs.Create;
begin
  inherited Create;

  Self.fZipFiles        := DataLib.NewList(not UtilsB2.OWNS_ITEMS);
  Self.fZipItemsMap     := DataLib.NewDict(UtilsB2.OWNS_ITEMS, DataLib.CASE_INSENSITIVE);
  Self.fZipItemsMap[myAStr('')] := TZipItem.Create(nil, 0, '', 0);
end;

destructor TZipFs.Destroy;
begin
  Self.Clear;
  Legacy.FreeAndNil(Self.fZipItemsMap);
  Legacy.FreeAndNil(Self.fZipFiles);

  inherited;
end;

procedure TZipFs.Clear;
var
  i: integer;

begin
  Self.fZipItemsMap.Clear;

  for i := 0 to Self.fZipFiles.Count - 1 do begin
    KubaZip.zip_close(PZipStruct(Self.fZipFiles[i]));
  end;

  Self.fZipFiles.Clear;

  Self.fZipItemsMap[myAStr('')] := TZipItem.Create(nil, 0, '', 0);
end;

function TZipFs.ForcePath (const Path: myAStr): {U} TZipItem;
var
{Un} Item:       TZipItem;
{Un} ParentItem: TZipItem;
     PathParts:  UtilsB2.TArrayOfStr;
     ItemPath:   myAStr;
     ParentPath: myAStr;
     i:          integer;

begin
  Item       := nil;
  ParentItem := nil;
  // * * * * * //
  PathParts := StrLib.Explode(Path, '\');
  ItemPath  := '';

  for i := 0 to High(PathParts) do begin
    ParentPath := ItemPath;

    if ItemPath <> '' then begin
      ItemPath := ItemPath + '\';
    end;

    ItemPath := ItemPath + PathParts[i];

    ParentItem := Self.fZipItemsMap[ParentPath];

    if ParentItem = nil then begin
      ParentItem                  := TZipItem.Create(nil, 0, ItemPath, 0);
      Self.fZipItemsMap[ItemPath] := ParentItem;
    end;

    Item := Self.fZipItemsMap[ItemPath];

    if Item = nil then begin
      Item                        := TZipItem.Create(nil, 0, ItemPath, 0);
      Self.fZipItemsMap[ItemPath] := Item;
      ParentItem.AddChild(Item);
    end;
  end; // .for

  result := Self.fZipItemsMap[Path];
  {!} Assert(result <> nil);
end; // .function TZipFs.ForcePath

procedure TZipFs.AddZipsFromDir (const Dir: myAStr);
var
{Un} ZipFile:        PZipStruct;
{Un} ZipItem:        TZipItem;
     ZipItemPath:    myAStr;
     ZipItemDirPath: myAStr;
     ZipItemSize:    integer;
     NumEntries:     integer;
     i:              integer;

begin
  ZipFile := nil;
  ZipItem := nil;
  // * * * * * //
  with Files.Locate(Dir + myAStr('\*.zip'), Files.ONLY_FILES) do begin
    while FindNext do begin
      if FoundRec.Rec.Size > 0 then begin
        ZipFile := KubaZip.zip_open(myPChar(FoundPath), 6, 'r');

        if ZipFile <> nil then begin
          NumEntries := KubaZip.zip_entries_total(ZipFile);

          for i := 0 to NumEntries - 1 do begin
            KubaZip.zip_entry_openbyindex(ZipFile, i);

            if KubaZip.zip_entry_isdir(ZipFile) <> ord(true) then begin
              ZipItemPath    := UnixPathToWinPath(KubaZip.zip_entry_name(ZipFile));
              ZipItemSize    := KubaZip.zip_entry_size(ZipFile);
              ZipItemDirPath := Legacy.ExtractFileDir(ZipItemPath);
              ZipItem        := Self.fZipItemsMap[ZipItemPath];

              // It should be either new item with valid path or existing directory with file data
              // "xxx" is A.zip is directory, while "xxx" in B.zip is file
              if (ZipItemPath <> '') and ((ZipItem = nil) or (ZipItem.Zip = nil)) then begin
                if ZipItem = nil then begin
                  ZipItem                        := TZipItem.Create(ZipFile, i, ZipItemPath, ZipItemSize);
                  Self.fZipItemsMap[ZipItemPath] := ZipItem;
                end else begin
                  ZipItem.Zip        := ZipFile;
                  ZipItem.EntryIndex := i;
                  ZipItem.Size       := ZipItemSize;
                end;

                Self.ForcePath(ZipItemDirPath).AddChild(ZipItem);
              end; // .if
            end; // .if

            KubaZip.zip_entry_close(ZipFile);
          end; // .for
        end; // .if
      end; // .if
    end; // .while
  end; // .with
end; // .procedure TZipFs.AddZipsFromDir

function TZipFs.FindItem (const RelPath: myAStr): {Un} TZipItem;
begin
  result := Self.fZipItemsMap[RelPath];
end;

function ToRelativePath (FilePath, BasePath: myAStr): myAStr;
begin
  if Copy(FilePath, 1, 5) = 'zip:\' then begin
    result := Files.NormalizePathSeparators(Copy(FilePath, 6));
  end else begin
    result := Files.ToRelativePath(FilePath, BasePath);
  end;
end;

function ToRelativePathIfPossible (FilePath, BasePath: myAStr): myAStr;
begin
  if Copy(FilePath, 1, 5) = 'zip:\' then begin
    result := Files.NormalizePathSeparators(Copy(FilePath, 6));
  end else begin
    result := Files.ToRelativePathIfPossible(FilePath, BasePath);
  end;
end;

function LocateInZipFs (const MaskedPath: myAStr; SearchSubj: TSearchSubj): ILocator;
var
{Un} ZipItem: TZipItem;
     RelPath: myAStr;
     Iters:   array [0..1] of Files.ILocator;

begin
  RelPath := ToRelativePath(MaskedPath, GameExt.GameDir);
  result  := Files.Locate(MaskedPath, SearchSubj);

  if RelPath <> '' then begin
    ZipItem := ZipFs.FindItem(Legacy.ExtractFileDir(RelPath));

    if ZipItem <> nil then begin
      Iters[0] := result;
      Iters[1] := TZipItemIterator.Create(ZipItem);
      result   := TVirtualFsIterator.Create(Iters);
      result.Locate(MaskedPath, SearchSubj);
    end;
  end;
end;

function ReadFileContentsFromZipFs (const FilePath: myAStr; var FileContents: myAStr): boolean;
var
{Un} ZipItem: TZipItem;
     RelPath: myAStr;

begin
  ZipItem := nil;
  // * * * * * //
  if Files.FileExists(FilePath) then begin
    result := Files.ReadFileContents(FilePath, FileContents);
  end else begin
    RelPath := ToRelativePath(FilePath, GameExt.GameDir);
    result  := RelPath <> '';

    if result then begin
      ZipItem := ZipFs.FindItem(RelPath);
      result  := ZipItem <> nil;

      if result then begin
        FileContents := ZipItem.ReadAsString;
      end;
    end;
  end; // .else
end; // .function ReadFileContentsFromZipFs

procedure OnAfterWoG (Event: GameExt.PEvent); stdcall;
begin
  ZipFs.AddZipsFromDir(GameExt.GameDir + myAStr('\Data'));
end;

begin
  ZipFs := TZipFs.Create;

  EventMan.GetInstance.On('OnAfterWoG', OnAfterWoG);
end.