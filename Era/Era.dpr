library Era;
(*
  Description: Heroes of Might and Magic 3.5: In The Wake of Gods (ERA)
  Author:      Alexander Shostak aka Berserker
*)
{$R 'VersionInfo.res' 'VersionInfo.rc'}
{$R *.RES}

uses
  {$define AssumeMultiThreaded}
  FastMM4, // Must be the first unit

  Math,
  SysUtils,

  (* Forced order, do not regroup or mix with other units: order dependent hooks/patches *)
  GameExt in 'GameExt.pas',
  Erm in 'Erm.pas',

  AdvErm in 'AdvErm.pas',
  Debug in 'Debug.pas',
  DebugMaps in 'DebugMaps.pas',
  Dwellings in 'Dwellings.pas',
  EraButtons in 'EraButtons.pas',
  EraSettings in 'EraSettings.pas',
  ErmTracking in 'ErmTracking.pas',
  Extern in 'Extern.pas',
  Graph in 'Graph.pas',
  Lodman in 'Lodman.pas',
  PoTweak in 'PoTweak.pas',
  Rainbow in 'Rainbow.pas',
  Scripts in 'Scripts.pas',
  SndVid in 'SndVid.pas',
  Stores in 'Stores.pas',
  Trans in 'Trans.pas',
  Triggers in 'Triggers.pas',
  Tweaks in 'Tweaks.pas',
  VfsImport in '..\Vfs\VfsImport.pas',
  WogEvo in 'WogEvo.pas',
  (* End of block*)

  BinPatching in 'BinPatching.pas',
  EraLog in 'EraLog.pas',
  EventMan in 'EventMan.pas',
  Heroes in 'Heroes.pas',
  RscLists in 'RscLists.pas',
  Legacy in '..\Lib\b2\Legacy.pas',
  UtilsB2 in '..\Lib\b2\UtilsB2.pas',
  ApiJack in '..\Lib\b2\ApiJack.pas',
  AssocArrays in '..\Lib\b2\AssocArrays.pas',
  DataLib in '..\Lib\b2\DataLib.pas',
  Files in '..\Lib\b2\Files.pas',
  Lists in '..\Lib\b2\Lists.pas',
  StrLib in '..\Lib\b2\StrLib.pas',
  TextScan in '..\Lib\b2\TextScan.pas',
  TypeWrappers in '..\Lib\b2\TypeWrappers.pas',
  Alg in '..\Lib\b2\Alg.pas',
  Crypto in '..\Lib\b2\Crypto.pas',
  WinWrappers in '..\Lib\b2\WinWrappers.pas',
  CFiles in '..\Lib\b2\CFiles.pas',
  Log in '..\Lib\b2\Log.pas',
  Concur in '..\Lib\b2\Concur.pas',
  PatchForge in '..\Lib\b2\PatchForge.pas',
  hde32 in '..\Lib\b2\hde32.pas',
  PatchApi in '..\Lib\b2\PatchApi.pas',
  DlgMes in '..\Lib\b2\DlgMes.pas',
  Lang in '..\Lib\b2\Lang.pas',
  CLang in '..\Lib\b2\CLang.pas',
  CBinString in '..\Lib\b2\CBinString.pas',
  CLngPack in '..\Lib\b2\CLngPack.pas',
  CLngStrArr in '..\Lib\b2\CLngStrArr.pas',
  CLngUnit in '..\Lib\b2\CLngUnit.pas',
  DlgMesLng in '..\Lib\b2\DlgMesLng.pas',
  FilesEx in '..\Lib\b2\FilesEx.pas',
  DataFlows in '..\Lib\b2\DataFlows.pas',
  CmdApp in '..\Lib\b2\CmdApp.pas',
  WinUtils in '..\Lib\b2\WinUtils.pas',
  ConsoleAPI in '..\Lib\b2\ConsoleAPI.pas',
  Ini in '..\Lib\b2\Ini.pas',
  WinNative in '..\Lib\b2\WinNative.pas',
  RandMt in '..\Lib\b2\RandMt.pas',
  EraAPI in 'EraAPI.pas',
  Memory in 'Memory.pas',
  EraUtils in 'EraUtils.pas',
  FpuUtils in 'FpuUtils.pas',
  ResLib in 'ResLib.pas',
  EraZip in 'EraZip.pas',
  KubaZip in 'KubaZip.pas',
  GraphTypes in 'GraphTypes.pas',
  Libspng in 'Libspng.pas',
  FastRand in '..\Lib\b2\FastRand.pas',
  Network in 'Network.pas',
  ZlibUtils in 'ZlibUtils.pas',
  Lua in 'Lua\Lua.pas',
  Json in 'Json.pas',
  EventLib in 'EventLib.pas',
  WogDialogs in 'WogDialogs.pas',
  WindowMessages in 'WindowMessages.pas';

begin
  FormatSettings.DecimalSeparator := '.';

  // set callback to GameExt unit
  Erm.v[1] := integer(@GameExt.Init);
end.

