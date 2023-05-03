unit VfsBase;
(*
  Description: Implements in-memory virtual file system data storage.
  Author:      Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
  TODO:        Use optimized hash-table storage for VfsItems instead of ansi-to-wide string keys in regular binary tree.
*)


(***)  interface  (***)

uses
  SysUtils, Math, Windows,
  UtilsB2, WinNative, Alg, Concur, TypeWrappers, Lists, DataLib,
  StrLib,
  VfsUtils, VfsMatching, Legacy;

type
  (* Import *)
  TDict    = DataLib.TDict;
  TObjDict = DataLib.TObjDict;
  TString  = TypeWrappers.TString;
  TList    = Lists.TList;

const
  OVERWRITE_EXISTING      = true;
  DONT_OVERWRITE_EXISTING = false;

  AUTO_PRIORITY                = MAXLONGINT div 2;
  INITIAL_OVERWRITING_PRIORITY = AUTO_PRIORITY + 1;
  INITIAL_ADDING_PRIORITY      = AUTO_PRIORITY - 1;

type
  (*
    Specifies the order, in which files from different mapped directories will be listed in virtual directory.
    Virtual directory sorting is performed by priorities firstly and lexicographically secondly.
    SORT_FIFO - Items of the first mapped directory will be listed before the second mapped directory items.
    SORT_LIFO - Items of The last mapped directory will be listed before all other mapped directory items.
  *)
  TDirListingSortType = (SORT_FIFO = 0, SORT_LIFO = 1);

  (* Single redirected VFS entry: file or directory *)
  TVfsItem = class
   private
    function  GetName: myWStr; inline;
    procedure SetName (const NewName: myWStr); inline;

   public
    (* Name in lower case, used for wildcard mask matching *)
    SearchName: myWStr;

    (* Absolute path to virtual file/folder location without trailing slash for non-drives *)
    VirtPath: myWStr;

    (* Absolute path to real file/folder location without trailing slash for non-drives *)
    RealPath: myWStr;

    (* The priority used in virtual directories sorting for listing *)
    Priority: integer;

    (* List of directory child items or nil *)
    {On} Children: {U} TList {OF TVfsItem};

    (* Up to 32 special non-Windows attribute flags *)
    Attrs: integer;

    (* Full file info *)
    Info: TNativeFileInfo;

    function IsDir (): boolean;

    destructor Destroy; override;

    (* Name in original case. Automatically sets/converts SearchName, Info.FileName, Info.Base.FileNameLength *)
    property Name: myWStr read GetName write SetName;
  end; // .class TVfsItem

  (* Allows to disable VFS temporarily for current thread only *)
  TThreadVfsDisabler = record
    PrevDisableVfsForThisThread: boolean;

    procedure DisableVfsForThread;
    procedure EnableVfsForThread;
    procedure RestoreVfsForThread;
  end;

  TSingleArgExternalFunc = function (Arg: pointer = nil): integer; stdcall;

var
  (* Global VFS access synchronizer *)
  VfsCritSection: Concur.TCritSection;


function GetThreadVfsDisabler: TThreadVfsDisabler;

(* Runs VFS. Higher level API must install hooks in VfsCritSection protected area.
   Listing order is ignored if VFS is resumed from pause *)
function RunVfs (DirListingOrder: TDirListingSortType): boolean;

(* Temporarily pauses VFS, but does not reset existing mappings *)
function PauseVfs: LONGBOOL; stdcall;

(* Stops VFS and clears all mappings *)
function ResetVfs: LONGBOOL; stdcall;

(* If VFS is running or paused, pauses VFS, clears cache and fully reaplies all mappings in the same order and
   with the same arguments, as MapDir routines were called earlier. Restores VFS state afterwards *)
function RefreshVfs: LONGBOOL; stdcall;

(* Refreshes VFS item attributes info for given mapped file. File must exist to succeed *)
function RefreshMappedFile (const FilePath: myWStr): boolean;

(* Returns true if VFS is active globally and for current thread *)
function IsVfsActive: boolean;

function  EnterVfs: boolean;
procedure LeaveVfs;
function  EnterVfsConfig: boolean;
procedure LeaveVfsConfig;

(* Returns real path for VFS item by its absolute virtual path or empty string. Optionally returns file info structure *)
function GetVfsItemRealPath (const AbsVirtPath: myWStr; {n} FileInfo: PNativeFileInfo = nil): myWStr;

(* Returns virtual directory info. Adds virtual entries to specified directory listing container *)
function GetVfsDirInfo (const NormalizedVirtPath, Mask: myWStr; {OUT} var DirInfo: TNativeFileInfo; DirListing: TDirListing): boolean;

(* Maps real directory contents to virtual path. Target must exist for success *)
function MapDir (const VirtPath, RealPath: myWStr; OverwriteExisting: boolean; Flags: integer = 0): boolean;

(* Calls specified function with a single argument and returns its result. VFS is disabled for current thread during function exection *)
function CallWithoutVfs (Func: TSingleArgExternalFunc; Arg: pointer = nil): integer; stdcall;

(* Returns text with all applied mappings, separated via #13#10. If ShortenPaths is true, common part
   of real and virtual paths is stripped *)
function GetMappingsReport: myWStr;

(* Returns text with all applied mappings on per-file level, separated via #13#10. If ShortenPaths is true, common part
   of real and virtual paths is stripped *)
function GetDetailedMappingsReport: myWStr;


(***)  implementation  (***)


type
  (* Applied and remembered mapping. Used to refresh or report VFS *)
  TMapping = class
    Applied:           LONGBOOL;
    AbsVirtPath:       myWStr;
    AbsRealPath:       myWStr;
    OverwriteExisting: LONGBOOL;
    Flags:             integer;

    class function Make (Applied: boolean; const AbsVirtPath, AbsRealPath: myWStr; OverwriteExisting: boolean; Flags: integer): TMapping;
  end;

var
(*
  Global map of case-insensitive normalized path to file/directory => corresponding TVfsItem.
  Access is controlled via critical section and global/thread switchers.
  Represents the whole cached virtual file system contents.
*)
{O} VfsItems: {O} TDict {of TVfsItem};

(* Map of real (mapped) file path => VFS item. Used to update VFS info whenever mapped files are changed *)
{O} MappedFiles: {U} TDict {of TVfsItem};

(* List of all applied mappings *)
{O} Mappings: {O} TList {of TMapping};
  
  (* Global VFS state indicator. If false, all VFS search operations must fail *)
  VfsIsRunning: boolean = false;

  (* Directory listing ordering, chosen on first VFS run. Updated on any first run after reset *)
  VfsDirListingOrder: TDirListingSortType;

  (* If true, VFS file/directory hierarchy is built and no mapping is allowed untill full reset *)
  VfsTreeIsBuilt: boolean = false;
    
  (* Automatical VFS items priority management *)
  OverwritingPriority: integer = INITIAL_OVERWRITING_PRIORITY;
  AddingPriority:      integer = INITIAL_ADDING_PRIORITY;

// All threadvar variables are automatically zeroed during finalization, thus zero must be the safest default value
threadvar
  DisableVfsForThisThread: boolean;


function TVfsItem.IsDir: boolean;
begin
  result := (Self.Info.Base.FileAttributes and Windows.FILE_ATTRIBUTE_DIRECTORY) <> 0;
end;

function TVfsItem.GetName: myWStr;
begin
  result := Self.Info.FileName;
end;

procedure TVfsItem.SetName (const NewName: myWStr);
begin
  Self.Info.SetFileName(NewName);
  Self.SearchName := StrLib.WideLowerCase(NewName);
end;

destructor TVfsItem.Destroy;
begin
  Legacy.FreeAndNil(Self.Children);
end;

procedure TThreadVfsDisabler.DisableVfsForThread;
begin
  Self.PrevDisableVfsForThisThread := DisableVfsForThisThread;
  DisableVfsForThisThread          := true;
end;

procedure TThreadVfsDisabler.EnableVfsForThread;
begin
  Self.PrevDisableVfsForThisThread := DisableVfsForThisThread;
  DisableVfsForThisThread          := false;
end;

procedure TThreadVfsDisabler.RestoreVfsForThread;
begin
  DisableVfsForThisThread := Self.PrevDisableVfsForThisThread;
end;

function GetThreadVfsDisabler: TThreadVfsDisabler;
begin
end;

function EnterVfs: boolean;
begin
  result := not DisableVfsForThisThread;

  if result then begin
    VfsCritSection.Enter;
    result := VfsIsRunning;

    if not result then begin
      VfsCritSection.Leave;
    end;
  end;
end;

procedure LeaveVfs;
begin
  VfsCritSection.Leave;
end;

function EnterVfsConfig: boolean;
begin
  VfsCritSection.Enter;
  result := not VfsIsRunning and not VfsTreeIsBuilt;

  if not result then begin
    VfsCritSection.Leave;
  end;
end;

procedure LeaveVfsConfig;
begin
  VfsCritSection.Leave;
end;

function CompareVfsItemsByPriorityDescAndNameAsc (Item1, Item2: integer): integer;
begin
  result := TVfsItem(Item2).Priority - TVfsItem(Item1).Priority;

  if result = 0 then begin
    result := StrLib.CompareBinStringsW(TVfsItem(Item1).SearchName, TVfsItem(Item2).SearchName);
  end;
end;

function CompareVfsItemsByPriorityAscAndNameAsc (Item1, Item2: integer): integer;
begin
  result := TVfsItem(Item1).Priority - TVfsItem(Item2).Priority;

  if result = 0 then begin
    result := StrLib.CompareBinStringsW(TVfsItem(Item1).SearchName, TVfsItem(Item2).SearchName);
  end;
end;

procedure SortVfsListing ({U} List: DataLib.TList {OF TVfsItem}; SortType: TDirListingSortType);
begin
  if SortType = SORT_FIFO then begin
    List.CustomSort(CompareVfsItemsByPriorityDescAndNameAsc);
  end else begin
    List.CustomSort(CompareVfsItemsByPriorityAscAndNameAsc);
  end;
end;

procedure SortVfsDirListings (SortType: TDirListingSortType);
var
{Un} Children: DataLib.TList {OF TVfsItem};

begin
  Children := nil;
  // * * * * * //
  with DataLib.IterateDict(VfsItems) do begin
    while IterNext() do begin
      Children := TVfsItem(IterValue).Children;

      if (Children <> nil) and (Children.Count > 1) then begin
        SortVfsListing(Children, SortType);
      end;
    end;
  end;
end; // .procedure SortVfsDirListings

function FindVfsItemByNormalizedPath (const Path: myWStr; {U} var {OUT} Res: TVfsItem): boolean;
var
{Un} VfsItem: TVfsItem;

begin
  VfsItem := VfsItems[WideStrToCaselessKey(Path)];
  result  := VfsItem <> nil;

  if result then begin
    Res := VfsItem;
  end;
end;

function FindVfsItemByPath (const Path: myWStr; {U} var {OUT} Res: TVfsItem): boolean;
begin
  result := FindVfsItemByNormalizedPath(NormalizePath(Path), Res);
end;

(* All children list of VFS items MUST be empty *)
procedure BuildVfsItemsTree;
var
{Un} DirVfsItem: TVfsItem;
     AbsDirPath: myWStr;

begin
  DirVfsItem := nil;
  // * * * * * //
  with DataLib.IterateDict(VfsItems) do begin
    while IterNext() do begin
      AbsDirPath := StrLib.ExtractDirPathW(CaselessKeyToWideStr(IterKey));

      if FindVfsItemByNormalizedPath(AbsDirPath, DirVfsItem) then begin
        DirVfsItem.Children.Add(IterValue);
      end;
    end;
  end;
end; // .procedure BuildVfsItemsTree

class function TMapping.Make (Applied: boolean; const AbsVirtPath, AbsRealPath: myWStr; OverwriteExisting: boolean; Flags: integer): {O} TMapping;
begin
  result                   := TMapping.Create;
  result.Applied           := Applied;
  result.AbsVirtPath       := AbsVirtPath;
  result.AbsRealPath       := AbsRealPath;
  result.OverwriteExisting := OverwriteExisting;
  result.Flags             := Flags;
end;

function RunVfs (DirListingOrder: TDirListingSortType): boolean;
begin
  result := true;

  with VfsCritSection do begin
    Enter;

    if not VfsIsRunning then begin
      if not VfsTreeIsBuilt then begin
        VfsDirListingOrder := DirListingOrder;
        BuildVfsItemsTree();
        SortVfsDirListings(DirListingOrder);
        VfsTreeIsBuilt := true;
      end;
      
      VfsIsRunning := true;
    end;

    Leave;
  end; // .with
end; // .function RunVfs

function PauseVfs: LONGBOOL; stdcall;
begin
  result := true;

  with VfsCritSection do begin
    Enter;
    VfsIsRunning := false;
    Leave;
  end;
end;

function ResetVfs: LONGBOOL; stdcall;
begin
  result := true;

  with VfsCritSection do begin
    Enter;
    VfsItems.Clear;
    MappedFiles.Clear;
    Mappings.Clear;
    VfsIsRunning   := false;
    VfsTreeIsBuilt := false;
    Leave;
  end;
end;

function IsVfsActive: boolean;
begin
  result := EnterVfs;

  if result then begin
    LeaveVfs;
  end;
end;

(* Returns real path for vfs item by its absolute virtual path or empty string. Optionally returns file info structure *)
function GetVfsItemRealPath (const AbsVirtPath: myWStr; {n} FileInfo: PNativeFileInfo = nil): myWStr;
var
{n} VfsItem: TVfsItem;

begin
  VfsItem := nil;
  result  := '';
  // * * * * * //
  if EnterVfs then begin
    if FindVfsItemByNormalizedPath(AbsVirtPath, VfsItem) then begin
      result := VfsItem.RealPath;

      if FileInfo <> nil then begin
        FileInfo^ := VfsItem.Info;
      end;
    end;

    LeaveVfs;
  end; // .if
end; // .function GetVfsItemRealPath

function GetVfsDirInfo (const NormalizedVirtPath, Mask: myWStr; {OUT} var DirInfo: TNativeFileInfo; DirListing: TDirListing): boolean;
var
{n} VfsItem:        TVfsItem;
    NormalizedMask: myWStr;
    MaskPattern:    UtilsB2.TArrayOfByte;
    i:              integer;

begin
  {!} Assert(DirListing <> nil);
  VfsItem := nil;
  // * * * * * //
  result := EnterVfs;

  if result then begin
    result := FindVfsItemByNormalizedPath(NormalizedVirtPath, VfsItem) and VfsItem.IsDir;

    if result then begin
      DirInfo := VfsItem.Info;

      if VfsItem.Children <> nil then begin
        NormalizedMask := StrLib.WideLowerCase(Mask);
        MaskPattern    := VfsMatching.CompilePattern(NormalizedMask);

        for i := 0 to VfsItem.Children.Count - 1 do begin
          if VfsMatching.MatchPattern(TVfsItem(VfsItem.Children[i]).SearchName, pointer(MaskPattern)) then begin
            DirListing.AddItem(@TVfsItem(VfsItem.Children[i]).Info);
          end;
        end;
      end; // .if
    end; // .if

    LeaveVfs;
  end; // .if
end; // .function GetVfsDirInfo

procedure CopyFileInfoWithoutNames (var Src, Dest: WinNative.FILE_ID_BOTH_DIR_INFORMATION);
begin
  Dest.FileIndex      := 0;
  Dest.CreationTime   := Src.CreationTime;
  Dest.LastAccessTime := Src.LastAccessTime;
  Dest.LastWriteTime  := Src.LastWriteTime;
  Dest.ChangeTime     := Src.ChangeTime;
  Dest.EndOfFile      := Src.EndOfFile;
  Dest.AllocationSize := Src.AllocationSize;
  Dest.FileAttributes := Src.FileAttributes;
  Dest.EaSize         := Src.EaSize;
end;

(* Redirects single file/directory path (not including directory contents). Returns redirected VFS item
   for given real path if VFS item was successfully created/overwritten or it already existed and OverwriteExisting = false. *)
function RedirectFile (const AbsVirtPath, AbsRealPath: myWStr; {n} FileInfoPtr: WinNative.PFILE_ID_BOTH_DIR_INFORMATION; OverwriteExisting: boolean; Priority: integer): {Un} TVfsItem;
const
  WIDE_NULL_CHAR_LEN = Length(myAStr(#0));

var
{Un} VfsItem:        TVfsItem;
     PackedVirtPath: myAStr;
     IsNewItem:      boolean;
     FileInfo:       TNativeFileInfo;
     Success:        boolean;

begin
  VfsItem := nil;
  result  := nil;
  // * * * * * //
  PackedVirtPath := WideStrToCaselessKey(AbsVirtPath);
  VfsItem        := VfsItems[PackedVirtPath];
  IsNewItem      := VfsItem = nil;
  Success        := true;

  if IsNewItem or OverwriteExisting then begin
    if FileInfoPtr = nil then begin
      Success := GetFileInfo(AbsRealPath, FileInfo);
    end;

    if Success then begin
      if IsNewItem then begin
        VfsItem                           := TVfsItem.Create();
        VfsItems[PackedVirtPath]          := VfsItem;
        VfsItem.Name                      := StrLib.ExtractFileNameW(AbsVirtPath);
        VfsItem.SearchName                := StrLib.WideLowerCase(VfsItem.Name);
        VfsItem.Info.Base.ShortNameLength := 0;
        VfsItem.Info.Base.ShortName[0]    := #0;
      end;

      if FileInfoPtr <> nil then begin
        CopyFileInfoWithoutNames(FileInfoPtr^, VfsItem.Info.Base);
      end else begin
        CopyFileInfoWithoutNames(FileInfo.Base, VfsItem.Info.Base);
      end;
 
      VfsItem.VirtPath := AbsVirtPath;
      VfsItem.RealPath := AbsRealPath;
      VfsItem.Priority := Priority;
      VfsItem.Attrs    := 0;
      MappedFiles[WideStrToCaselessKey(AbsRealPath)] := VfsItem;
    end; // .if
  end; // .if

  if Success then begin
    result := VfsItem;
  end;
end; // .function RedirectFile

function _MapDir (const AbsVirtPath, AbsRealPath: myWStr; {n} FileInfoPtr: WinNative.PFILE_ID_BOTH_DIR_INFORMATION; OverwriteExisting: boolean; Flags, Priority: integer): {Un} TVfsItem;
var
{O}  Subdirs:        {O} TList {OF TFileInfo};
{U}  SubdirInfo:     TFileInfo;
{Un} DirVfsItem:     TVfsItem;
     Success:        boolean;
     FileInfo:       TNativeFileInfo;
     VirtPathPrefix: myWStr;
     RealPathPrefix: myWStr;
     i:              integer;

begin
  DirVfsItem := nil;
  Subdirs    := DataLib.NewList(UtilsB2.OWNS_ITEMS);
  SubdirInfo := nil;
  result     := nil;
  // * * * * * //
  if Priority = AUTO_PRIORITY then begin
    if OverwriteExisting then begin
      Priority := OverwritingPriority;
      Inc(OverwritingPriority);
    end else begin
      Priority := AddingPriority;
      Dec(AddingPriority);
    end;
  end;
  
  DirVfsItem := RedirectFile(AbsVirtPath, AbsRealPath, FileInfoPtr, OverwriteExisting, Priority);
  Success    := (DirVfsItem <> nil) and ((DirVfsItem.RealPath = AbsRealPath) or VfsUtils.IsDir(AbsRealPath));

  if Success then begin
    VirtPathPrefix := AddBackslash(AbsVirtPath);
    RealPathPrefix := AddBackslash(AbsRealPath);

    if DirVfsItem.Children = nil then begin
      DirVfsItem.Children := DataLib.NewList(not UtilsB2.OWNS_ITEMS);
    end;

    with SysScanDir(AbsRealPath, '*') do begin
      while IterNext(FileInfo.FileName, @FileInfo.Base) do begin
        if UtilsB2.Flags(FileInfo.Base.FileAttributes).Have(Windows.FILE_ATTRIBUTE_DIRECTORY) then begin
          if (FileInfo.FileName <> '.') and (FileInfo.FileName <> '..') then begin
            Subdirs.Add(TFileInfo.Create(@FileInfo));
          end;
        end else begin
          RedirectFile(VirtPathPrefix + FileInfo.FileName, RealPathPrefix + FileInfo.FileName, @FileInfo, OverwriteExisting, Priority);
        end;
      end;
    end;

    for i := 0 to Subdirs.Count - 1 do begin
      SubdirInfo := TFileInfo(Subdirs[i]);
      _MapDir(VirtPathPrefix + SubdirInfo.Data.FileName, RealPathPrefix + SubdirInfo.Data.FileName, @SubdirInfo.Data, OverwriteExisting, Flags, Priority);
    end;
  end; // .if

  if Success then begin
    result := DirVfsItem;
  end;
  // * * * * * //
  Legacy.FreeAndNil(Subdirs);
end; // .function _MapDir

function MapDir (const VirtPath, RealPath: myWStr; OverwriteExisting: boolean; Flags: integer = 0): boolean;
var
  AbsVirtPath: myWStr;
  AbsRealPath: myWStr;

begin
  result := EnterVfsConfig;

  if result then begin
    AbsVirtPath := VfsUtils.NormalizePath(VirtPath);
    AbsRealPath := VfsUtils.NormalizePath(RealPath);
    result      := (AbsVirtPath <> '') and (AbsRealPath <> '');

    if result then begin
      result := _MapDir(AbsVirtPath, AbsRealPath, nil, OverwriteExisting, Flags, AUTO_PRIORITY) <> nil;
      Mappings.Add(TMapping.Make(result, AbsVirtPath, AbsRealPath, OverwriteExisting, Flags));
    end;

    LeaveVfsConfig;
  end;
end; // .function MapDir

function CallWithoutVfs (Func: TSingleArgExternalFunc; Arg: pointer = nil): integer; stdcall;
begin
  with GetThreadVfsDisabler do begin
    try
      DisableVfsForThread;
      result := Func(Arg);
    finally
      RestoreVfsForThread;
    end;
  end;
end; // .function CallWithoutVfs

function RefreshVfs: LONGBOOL; stdcall;
var
  VfsWasRunning: boolean;
  i:             integer;

begin
  with VfsCritSection do begin
    Enter;
    result := VfsTreeIsBuilt;

    if result then begin
      VfsItems.Clear;
      MappedFiles.Clear;
      VfsWasRunning  := VfsIsRunning;
      VfsIsRunning   := false;
      VfsTreeIsBuilt := false;

      for i := 0 to Mappings.Count - 1 do begin
        with TMapping(Mappings[i]) do begin
          TMapping(Mappings[i]).Applied := MapDir(AbsVirtPath, AbsRealPath, OverwriteExisting, Flags);
        end;
      end;

      if VfsWasRunning then begin
        BuildVfsItemsTree();
        SortVfsDirListings(VfsDirListingOrder);
        VfsTreeIsBuilt := true;
        VfsIsRunning   := true;
      end;
    end;

    Leave;
  end; // .with
end; // .function RefreshVfs

function RefreshMappedFile (const FilePath: myWStr): boolean;
var
{U} VfsItem:       TVfsItem;
    AbsRealPath:   myWStr;
    FileInfo:      TNativeFileInfo;
    VfsWasRunning: boolean;

begin
  VfsItem := nil;
  // * * * * * //
  with VfsCritSection do begin
    Enter;
    result := VfsTreeIsBuilt;

    if result then begin
      VfsWasRunning := VfsIsRunning;
      VfsIsRunning  := false;
      AbsRealPath   := NormalizePath(FilePath);
      VfsItem       := TVfsItem(MappedFiles[WideStrToCaselessKey(AbsRealPath)]);
      result        := (VfsItem <> nil) and GetFileInfo(AbsRealPath, FileInfo);

      if result then begin
        CopyFileInfoWithoutNames(FileInfo.Base, VfsItem.Info.Base);
      end;

      VfsIsRunning := VfsWasRunning;
    end;

    Leave;
  end; // .with
end; // .function RefreshMappedFile

function GetMappingsReport_ (Mappings: TList {of TMapping}): myWStr;
const
  COL_PATHS = 0;
  COL_META  = 1;

var
{O} Buf:             StrLib.TStrBuilder;
{O} Line:            StrLib.TStrBuilder;
    Cols:            array [0..1] of array of myWStr;
    MaxPathColWidth: integer;
    i:               integer;

  procedure WriteMapping (Mapping: TMapping; LineN: integer);
  var
    StartPathPos:     integer;
    MaxCommonPathLen: integer;
    ShortestPath:     myWStr;
    LongestPath:      myWStr;
    i:                integer;

  begin
    {!} Assert(Mapping <> nil);
    StartPathPos := 1;

    if Length(Mapping.AbsRealPath) > Length(Mapping.AbsVirtPath) then begin
      LongestPath  := Mapping.AbsRealPath;
      ShortestPath := Mapping.AbsVirtPath;
    end else begin
      LongestPath  := Mapping.AbsVirtPath;
      ShortestPath := Mapping.AbsRealPath;
    end;

    i                := 1;
    MaxCommonPathLen := Length(ShortestPath);

    while (i <= MaxCommonPathLen) and (ShortestPath[i] = LongestPath[i]) do begin
      Inc(i);
    end;

    // Handle case: [xxx\yyy] zzz and [xxx\yyy]. Common part is [xxx]
    if (Length(LongestPath) > MaxCommonPathLen) and (LongestPath[i] <> '\') then begin
      while (i >= 2) and (LongestPath[i] <> '\') do begin
        Dec(i);
      end;
    end
    // Handle case: D:\App <= D:\Mods. Common part is D:
    else if ShortestPath[i] = '\' then begin
      Dec(i);
    end;

    StartPathPos := i;
    Line.Clear;

    if StartPathPos > 1 then begin
      Line.AppendWide('$');
    end;

    Line.AppendWide(Copy(Mapping.AbsVirtPath, StartPathPos));
    Line.AppendWide(' <= ');

    if StartPathPos > 1 then begin
      Line.AppendWide('$');
    end;

    Line.AppendWide(Copy(Mapping.AbsRealPath, StartPathPos));
    
    if not Mapping.Applied then begin
      Line.AppendWide(' *MISS*');
    end;

    Cols[COL_PATHS][LineN] := Line.BuildWideStr;
    MaxPathColWidth        := Max(MaxPathColWidth, Length(Cols[COL_PATHS][LineN]));

    Line.Clear;
    Line.AppendWide(string('[Overwrite = ' + Legacy.IntToStr(ord(Mapping.OverwriteExisting)) + ', Flags = ' + Legacy.IntToStr(Mapping.Flags)));

    if StartPathPos > 1 then begin
      Line.AppendWide(', $ = "' + Copy(ShortestPath, 1, StartPathPos - 1) + '"]');
    end else begin
      Line.AppendWide(']');
    end;

    Cols[COL_META][LineN] := Line.BuildWideStr;
  end; // .procedure WriteMapping

  function FormatResultTable: myWStr;
  var
    i: integer;

  begin
    for i := 0 to Mappings.Count - 1 do begin
      Buf.AppendWide(Cols[COL_PATHS][i] + StringOfChar(myWChar(' '), MaxPathColWidth - Length(Cols[COL_PATHS][i]) + 1));
      Buf.AppendWide(Cols[COL_META][i]);
      
      if i < Mappings.Count - 1 then begin
        Buf.AppendWide(#13#10);
      end;
    end;

    result := Buf.BuildWideStr;
  end;

begin
  Buf  := StrLib.TStrBuilder.Create;
  Line := StrLib.TStrBuilder.Create;
  // * * * * * //
  SetLength(Cols[COL_PATHS], Mappings.Count);
  SetLength(Cols[COL_META],  Mappings.Count);
  MaxPathColWidth := 0;

  for i := 0 to Mappings.Count - 1 do begin
    WriteMapping(TMapping(Mappings[i]), i);
  end;

  result := FormatResultTable;
  // * * * * * //
  Legacy.FreeAndNil(Buf);
  Legacy.FreeAndNil(Line);
end; // .function GetMappingsReport_

function GetMappingsReport: myWStr;
begin
  with VfsCritSection do begin
    Enter;
    result := GetMappingsReport_(Mappings);
    Leave;
  end;
end;

function CompareMappingsByRealPath (A, B: integer): integer;
begin
  result := StrLib.CompareBinStringsW(TMapping(A).AbsRealPath, TMapping(B).AbsRealPath);
end;

function GetDetailedMappingsReport: myWStr;
var
{O}  DetailedMappings: {O} TList {of TMapping};
{Un} VfsItem:          TVfsItem;

begin
  DetailedMappings := DataLib.NewList(UtilsB2.OWNS_ITEMS);
  VfsItem          := nil;
  // * * * * * //
  with VfsCritSection do begin
    Enter;

    with DataLib.IterateDict(VfsItems) do begin
      while IterNext do begin
        VfsItem := TVfsItem(IterValue);

        // Note, item Attrs is not the same as directory mapping Flags
        DetailedMappings.Add(TMapping.Make(true, VfsItem.VirtPath, VfsItem.RealPath, false, VfsItem.Attrs));
      end;
    end;
    
    Leave;
  end;

  DetailedMappings.CustomSort(CompareMappingsByRealPath);
  result := GetMappingsReport_(DetailedMappings);
  // * * * * * //
  Legacy.FreeAndNil(DetailedMappings);
end;

begin
  VfsCritSection.Init;
  VfsItems    := DataLib.NewDict(UtilsB2.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  MappedFiles := DataLib.NewDict(not UtilsB2.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  Mappings    := DataLib.NewList(UtilsB2.OWNS_ITEMS);
end.