library Vfs;
(*
  Author: Alexander Shostak aka Berserker aka EtherniDee.
*)
uses
  VfsExport in 'VfsExport.pas',
  VfsApiDigger in 'VfsApiDigger.pas',
  VfsBase in 'VfsBase.pas',
  VfsControl in 'VfsControl.pas',
  VfsDebug in 'VfsDebug.pas',
  VfsHooks in 'VfsHooks.pas',
  VfsImport in 'VfsImport.pas',
  VfsMatching in 'VfsMatching.pas',
  VfsOpenFiles in 'VfsOpenFiles.pas',
  VfsPatching in 'VfsPatching.pas',
  VfsUtils in 'VfsUtils.pas',
  VfsWatching in 'VfsWatching.pas',
  Alg in '..\Lib\b2\Alg.pas',
  ApiJack in '..\Lib\b2\ApiJack.pas',
  AssocArrays in '..\Lib\b2\AssocArrays.pas',
  ATexts in '..\Lib\b2\ATexts.pas',
  CBinString in '..\Lib\b2\CBinString.pas',
  CFiles in '..\Lib\b2\CFiles.pas',
  CLang in '..\Lib\b2\CLang.pas',
  CLngPack in '..\Lib\b2\CLngPack.pas',
  CLngStrArr in '..\Lib\b2\CLngStrArr.pas',
  CLngUnit in '..\Lib\b2\CLngUnit.pas',
  CmdApp in '..\Lib\b2\CmdApp.pas',
  Concur in '..\Lib\b2\Concur.pas',
  ConsoleAPI in '..\Lib\b2\ConsoleAPI.pas',
  Crypto in '..\Lib\b2\Crypto.pas',
  DataLib in '..\Lib\b2\DataLib.pas',
  DebugMaps in '..\Lib\b2\DebugMaps.pas',
  DlgMes in '..\Lib\b2\DlgMes.pas',
  DlgMesLng in '..\Lib\b2\DlgMesLng.pas',
  Files in '..\Lib\b2\Files.pas',
  FolderBrowser in '..\Lib\b2\FolderBrowser.pas',
  hde32 in '..\Lib\b2\hde32.pas',
  Ini in '..\Lib\b2\Ini.pas',
  Lang in '..\Lib\b2\Lang.pas',
  Lists in '..\Lib\b2\Lists.pas',
  Log in '..\Lib\b2\Log.pas',
  PatchApi in '..\Lib\b2\PatchApi.pas',
  PatchForge in '..\Lib\b2\PatchForge.pas',
  StrLib in '..\Lib\b2\StrLib.pas',
  TextMan in '..\Lib\b2\TextMan.pas',
  Texts in '..\Lib\b2\Texts.pas',
  TextScan in '..\Lib\b2\TextScan.pas',
  Trn in '..\Lib\b2\Trn.pas',
  TypeWrappers in '..\Lib\b2\TypeWrappers.pas',
  UtilsB2 in '..\Lib\b2\UtilsB2.pas',
  WinNative in '..\Lib\b2\WinNative.pas',
  WinUtils in '..\Lib\b2\WinUtils.pas',
  WinWrappers in '..\Lib\b2\WinWrappers.pas',
  FilesEx in '..\Lib\b2\FilesEx.pas',
  DataFlows in '..\Lib\b2\DataFlows.pas',
  RandMt in '..\Lib\b2\RandMt.pas',
  Legacy in '..\Lib\b2\Legacy.pas';

{$R 'VersionInfo.res' 'VersionInfo.rc'}
{$R *.RES}
begin
  System.IsMultiThread := True;
end.
