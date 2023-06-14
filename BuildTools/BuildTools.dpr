program BuildTools;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  Dbgmap in 'Dbgmap.pas',
  DbgmapCompiler in 'DbgmapCompiler.pas',
  VersionInfo in 'VersionInfo.pas',
  VersionInfoBuilder in 'VersionInfoBuilder.pas',
  Utils in 'Utils.pas';

begin
    //ReportMemoryLeaksOnShutdown := True;
    WriteLn('>  Project utils v1.0  <------------------------------------');

    if ParamStr(1) = '-DebugMaps'   then CreateDbgmap(ParamStr(2));
    if ParamStr(1) = '-VersionInfo' then CreateVersionInfo(ParamStr(2));

    WriteLn('------------------------------------------------------------');
end.

