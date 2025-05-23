unit VfsControl;
(*
  Facade unit for high-level VFS API.
*)


(***)  interface  (***)

uses
  SysUtils,
  Windows,

  DataLib,
  Files,
  StrLib,
  TypeWrappers,
  UtilsB2,
  WinUtils,

  VfsBase,
  VfsHooks,
  VfsUtils,
  VfsWatching, Legacy;

type
  (* Import *)
  TWideString = TypeWrappers.TWideString;


(* Runs all VFS subsystems, unless VFS is already running *)
function RunVfs (DirListingOrder: VfsBase.TDirListingSortType): LONGBOOL; stdcall;

(* Loads mod list from file and maps each mod directory to specified root directory.
   File with mod list is treated as (BOM or BOM-less) UTF-8 plain text file, where each mod name is separated
   from another one via Line Feed (#10) character. Each mod named is trimmed, converted to UCS16 and validated before
   adding to list. Invalid or empty mods will be skipped. Mods are mapped in reverse order, as compared to their order in file.
   Returns true if root and mods directory existed and file with mod list was loaded successfully *)
function MapModsFromList (const RootDir, ModsDir, ModListFile: myWStr; Flags: integer = 0): boolean;

(* Serializes the last mapped mod list into buffer. Format:

  NumMods: integer;

  for i := 1 to NumMods
    ModNameLenChars: integer;
    ModName:         array ModNameLenChars of WideChar;
*)
function GetSerializedModList: {O} pointer;

(* Serializes the last mapped mod list into ansi string buffer. Format:

  NumMods: integer;

  for i := 1 to NumMods
    ModNameLenChars: integer;
    ModName:         array ModNameLenChars of AnsiChar;
*)
function GetSerializedModListA: {O} pointer;


(***)  implementation  (***)


type
  TModList = DataLib.TList {of (O) TWideString};


  var
{On} GlobalModList: TModList = nil;


function RunVfs (DirListingOrder: VfsBase.TDirListingSortType): LONGBOOL; stdcall;
var
  CurrDir: myWStr;
  SysDir:  myWStr;

begin
  with VfsBase.VfsCritSection do begin
    Enter;

    result := VfsBase.RunVfs(DirListingOrder);

    if result then begin
      VfsHooks.InstallHooks;

      // Hask: Try to ensure, that current directory handle is tracked by VfsOpenFiles
      // Windows SetCurrentDirectoryW is does not reopen directory for the same path, thus
      // not triggering NtCreateFile
      // Not thread safe
      CurrDir := WinUtils.GetCurrentDirW;
      SysDir  := WinUtils.GetSysDirW;

      if (CurrDir <> '') and (SysDir <> '') then begin
        WinUtils.SetCurrentDirW(SysDir);
        {!} Assert(WinUtils.SetCurrentDirW(CurrDir), 'Failed to restore current directory from system directory during VFS initialization');
      end;
    end;

    Leave;
  end; // .with
end; // function RunVfs

function ValidateModName (const ModName: myWStr): boolean;
const
  DISALLOWED_CHARS = ['<', '>', '"', '?', '*', '\', '/', '|', ':', #0];

var
  StrLen: integer;
  i:      integer;

begin
  StrLen := Length(ModName);
  i      := 1;

  while (i <= StrLen) and ((ord(ModName[i]) > High(byte)) or not (myChar(ModName[i]) in DISALLOWED_CHARS)) do begin
    Inc(i);
  end;

  result := (i > StrLen) and (ModName <> '') and (ModName <> '.') and (ModName <> '..') and (ModName[1] <> ' ') and (ModName[StrLen] <> ' ');
end;

function LoadModList (const ModListFilePath, ModsDir: myWStr; {O} var {out} ModList: TModList): boolean;
const
  UTF8_BOM : myAStr = #$EF#$BB#$BF;

var
  AbsFilePath:   myWStr;
  ModPathPrefix: myWStr;
  FileHandle:    integer;
  FileContents:  myAStr;
  ModDirAttrs:   integer;
  Lines:         UtilsB2.TArrayOfStr;
  ModNameUtf8:   myAStr;
  ModName:       myWStr;
  i:             integer;

begin
  AbsFilePath := VfsUtils.NormalizePath(ModListFilePath);
  FileHandle  := integer(Windows.INVALID_HANDLE_VALUE);
  result      := AbsFilePath <> '';

  if result then begin
    FileHandle := Windows.CreateFileW(myPWChar(AbsFilePath), Windows.GENERIC_READ, Windows.FILE_SHARE_READ, nil, Windows.OPEN_EXISTING, 0, 0);
    result     := FileHandle <> integer(Windows.INVALID_HANDLE_VALUE);
  end;

  if result then begin
    result := Files.ReadFileContents(FileHandle, FileContents);

    if result then begin
      Legacy.FreeAndNil(ModList);
      ModList := DataLib.NewList(UtilsB2.OWNS_ITEMS);

      if (Length(FileContents) >= 3) and (FileContents[1] = UTF8_BOM[1]) and (FileContents[2] = UTF8_BOM[2]) and (FileContents[3] = UTF8_BOM[3]) then begin
        FileContents := Copy(FileContents, Length(UTF8_BOM) + 1);
      end;

      Lines         := StrLib.Explode(FileContents, #10);
      ModPathPrefix := VfsUtils.AddBackslash(VfsUtils.NormalizePath(ModsDir));

      for i := 0 to High(Lines) do begin
        ModNameUtf8 := Lines[i];
        ModName     := StrLib.TrimW(StrLib.Utf8ToWide(ModNameUtf8, StrLib.FAIL_ON_ERROR));

        if ValidateModName(ModName) and VfsUtils.GetFileAttrs(ModPathPrefix + ModName, ModDirAttrs) and UtilsB2.Flags(ModDirAttrs).Have(Windows.FILE_ATTRIBUTE_DIRECTORY) then begin
          ModList.Add(TWideString.Create(ModName));
        end;
      end;
    end;

    Windows.CloseHandle(FileHandle);
  end; // .if
end; // .function LoadModList

function MapModsFromList_ (const RootDir, ModsDir: myWStr; ModList: TModList; Flags: integer = 0): boolean;
var
  AbsRootDir:    myWStr;
  AbsModsDir:    myWStr;
  FileInfo:      VfsUtils.TNativeFileInfo;
  ModName:       myWStr;
  ModPathPrefix: myWStr;
  i:             integer;

begin
  {!} Assert(ModList <> nil);
  // * * * * * //
  AbsRootDir := VfsUtils.NormalizePath(RootDir);
  AbsModsDir := VfsUtils.NormalizePath(ModsDir);
  result     := (AbsRootDir <> '') and (AbsModsDir <> '')  and
                VfsUtils.GetFileInfo(AbsRootDir, FileInfo) and UtilsB2.Flags(FileInfo.Base.FileAttributes).Have(Windows.FILE_ATTRIBUTE_DIRECTORY) and
                VfsUtils.GetFileInfo(AbsModsDir, FileInfo) and UtilsB2.Flags(FileInfo.Base.FileAttributes).Have(Windows.FILE_ATTRIBUTE_DIRECTORY);

  if result then begin
    ModPathPrefix := VfsUtils.AddBackslash(AbsModsDir);

    for i := ModList.Count - 1 downto 0 do begin
      ModName := TWideString(ModList[i]).Value;
      VfsBase.MapDir(AbsRootDir, ModPathPrefix + ModName, not VfsBase.OVERWRITE_EXISTING, Flags);
    end;
  end;
end;

function MapModsFromList (const RootDir, ModsDir, ModListFile: myWStr; Flags: integer = 0): boolean;
begin
  result := VfsBase.EnterVfsConfig;

  if result then begin
    try
      Legacy.FreeAndNil(GlobalModList);

      result := LoadModList(ModListFile, ModsDir, GlobalModList) and MapModsFromList_(RootDir, ModsDir, GlobalModList, Flags);
    finally
      VfsBase.LeaveVfsConfig;
    end;
  end;
end;

function GetSerializedModList: {O} pointer;
var
{O} Builder: StrLib.TStrBuilder;
    i:       integer;

begin
  Builder := StrLib.TStrBuilder.Create;
  result  := nil;
  // * * * * * //
  if GlobalModList = nil then begin
    Builder.WriteInt(0);
  end else begin
    Builder.WriteInt(GlobalModList.Count);

    for i := 0 to GlobalModList.Count - 1 do begin
      Builder.AppendWideWithLenField(TWideString(GlobalModList[i]).Value);
    end;
  end;

  Legacy.GetMem(result, Builder.Size);
  Builder.BuildTo(result, Builder.Size);
  // * * * * * //
  Legacy.FreeAndNil(Builder);
end;

function GetSerializedModListA: {O} pointer;
var
{O} Builder: StrLib.TStrBuilder;
    i:       integer;

begin
  Builder := StrLib.TStrBuilder.Create;
  result  := nil;
  // * * * * * //
  if GlobalModList = nil then begin
    Builder.WriteInt(0);
  end else begin
    Builder.WriteInt(GlobalModList.Count);

    for i := 0 to GlobalModList.Count - 1 do begin
      Builder.AppendWithLenField(AnsiString(UTF8Encode(string(TWideString(GlobalModList[i]).Value))));
    end;
  end;

  Legacy.GetMem(result, Builder.Size);
  Builder.BuildTo(result, Builder.Size);
  // * * * * * //
  Legacy.FreeAndNil(Builder);
end;

end.

