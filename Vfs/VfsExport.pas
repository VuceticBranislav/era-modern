unit VfsExport;
(*

*)


(***)  interface  (***)

uses
  Windows,
  UtilsB2,
  VfsDebug, VfsBase, VfsControl, VfsWatching, VfsUtils, Legacy;

exports
  VfsDebug.SetLoggingProc,
  VfsDebug.WriteLog_ name 'WriteLog',
  VfsControl.RunVfs,
  VfsBase.PauseVfs,
  VfsBase.ResetVfs,
  VfsBase.RefreshVfs,
  VfsBase.CallWithoutVfs;


(***)  implementation  (***)


function Externalize (const Str: myAStr): {O} pointer; overload;
begin
  GetMem(result, Length(Str) + 1);
  UtilsB2.CopyMem(Length(Str) + 1, myPChar(Str), result);
end;

function Externalize (const Str: myWStr): {O} pointer; overload; // BYME remove this one
begin
  GetMem(result, (Length(Str) + 1) * sizeof(WideChar));
  UtilsB2.CopyMem((Length(Str) + 1) * sizeof(WideChar), myPWChar(Str), result);
end;

function MapDir (const VirtPath, RealPath: myPWChar; OverwriteExisting: Boolean; Flags: Integer = 0): LONGBOOL; stdcall;
begin
  Result := VfsBase.MapDir(myWStr(VirtPath), myWStr(RealPath), OverwriteExisting, Flags);
end;

function MapDirA (const VirtPath, RealPath: myPChar; OverwriteExisting: Boolean; Flags: Integer = 0): LONGBOOL; stdcall;
begin
  Result := VfsBase.MapDir(myWStr(VirtPath), myWStr(RealPath), OverwriteExisting, Flags);
end;

function MapModsFromList (const RootDir, ModsDir, ModListFile: myPWChar; Flags: Integer = 0): LONGBOOL; stdcall;
begin
  Result := VfsControl.MapModsFromList(myWStr(RootDir), myWStr(ModsDir), myWStr(ModListFile), Flags);
end;

function MapModsFromListA (const RootDir, ModsDir, ModListFile: myPChar; Flags: Integer = 0): LONGBOOL; stdcall;
begin
  Result := VfsControl.MapModsFromList(myWStr(RootDir), myWStr(ModsDir), myWStr(ModListFile), Flags);
end;

function RunWatcher (const WatchDir: myPWChar; DebounceInterval: Integer): LONGBOOL; stdcall;
begin
  Result := VfsWatching.RunWatcher(WatchDir, DebounceInterval);
end;

function RunWatcherA (const WatchDir: myPChar; DebounceInterval: Integer): LONGBOOL; stdcall;
begin
  Result := VfsWatching.RunWatcher(string(WatchDir), DebounceInterval);
end;

(* Frees buffer, that was transfered to client earlier using other VFS API *)
procedure MemFree ({O} Buf: Pointer); stdcall;
begin
  FreeMem(Buf);
end;

(* Returns text with all applied mappings, separated via #13#10. If ShortenPaths is true, common part
   of real and virtual paths is stripped. Call MemFree to release result buffer *)
function GetMappingsReport: {O} myPWChar; stdcall;
begin
  Result := Externalize(VfsBase.GetMappingsReport);
end;

function GetMappingsReportA: {O} myPChar; stdcall;
begin
  Result := Externalize(myAStr(VfsBase.GetMappingsReport));
end;

(* Returns text with all applied mappings on per-file level, separated via #13#10. If ShortenPaths is true, common part
   of real and virtual paths is stripped *)
function GetDetailedMappingsReport: {O} myPWChar; stdcall;
begin
  Result := Externalize(VfsBase.GetDetailedMappingsReport);
end;

function GetDetailedMappingsReportA: {O} myPChar; stdcall;
begin
  Result := Externalize(myAStr(VfsBase.GetDetailedMappingsReport));
end;

procedure ConsoleLoggingProc (Operation, Msg: myPChar); stdcall;
begin
  WriteLn('>> ', myAStr(Operation), ': ', myAStr(Msg), #13#10);
end;

(* Allocates console and install logger, writing messages to console *)
procedure InstallConsoleLogger; stdcall;
var
  Rect:    TSmallRect;
  BufSize: TCoord;
  hIn:     THandle;
  hOut:    THandle;

begin
  AllocConsole;
  SetConsoleCP(GetACP);
  SetConsoleOutputCP(GetACP);
  hIn                       := GetStdHandle(STD_INPUT_HANDLE);
  hOut                      := GetStdHandle(STD_OUTPUT_HANDLE);
  pinteger(@System.Input)^  := hIn;
  pinteger(@System.Output)^ := hOut;
  BufSize.x                 := 120;
  BufSize.y                 := 1000;
  SetConsoleScreenBufferSize(hOut, BufSize);
  Rect.Left                 := 0;
  Rect.Top                  := 0;
  Rect.Right                := 120 - 1;
  Rect.Bottom               := 50 - 1;
  SetConsoleWindowInfo(hOut, True, Rect);
  SetConsoleTextAttribute(hOut, (0 shl 4) or $0F);

  VfsDebug.SetLoggingProc(@ConsoleLoggingProc);
end; // .procedure InitConsole;

(* Returns real path for vfs item by its virtual path or empty string on error *)
function GetRealPath (const VirtPath: myWStr): {O} myPWChar; stdcall;
begin
  result := Externalize(VfsBase.GetVfsItemRealPath(VfsUtils.NormalizePath(VirtPath)));
end;

function GetRealPathA (const VirtPath: myAStr): {O} myPChar; stdcall;
begin
  result := Externalize(myAStr(VfsBase.GetVfsItemRealPath(VfsUtils.NormalizePath(string(VirtPath)))));
end;

exports
  GetDetailedMappingsReport,
  GetDetailedMappingsReportA,
  GetMappingsReport,
  GetMappingsReportA,
  GetRealPath,
  GetRealPathA,
  InstallConsoleLogger,
  MapDir,
  MapDirA,
  MapModsFromList,
  MapModsFromListA,
  MemFree,
  RunWatcher,
  RunWatcherA;
end.
