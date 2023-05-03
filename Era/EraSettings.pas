unit EraSettings;
{
DESCRIPTION:  Settings management
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses
  Math,
  SysUtils,

  Core,
  EraLog,
  Erm,
  EventMan,
  GameExt,
  Heroes,
  Ini,
  Log,
  ResLib,
  SndVid,
  Stores,
  Tweaks,
  UtilsB2,
  VfsImport, Legacy;

const
  LOG_FILE_NAME : myAStr = 'log.txt';

implementation

var
  DebugOpt:           boolean;
  DebugEverythingOpt: boolean;

function GetOptValue (const OptionName: myAStr; const DefVal: myAStr = ''): myAStr;
const
  ERA_SECTION               : myAStr = 'Era';

begin
  if Ini.ReadStrFromIni(OptionName, ERA_SECTION, GameExt.GameDir + '\' + Heroes.GAME_SETTINGS_FILE, result) then begin
    result := Legacy.Trim(result);
  end else begin
    result := DefVal;
  end;
end;

function GetOptBoolValue (const OptionName: myAStr; DefValue: boolean = false): boolean;
var
  OptVal: myAStr;

begin
  OptVal := GetOptValue(OptionName, IfThen(DefValue, '1', '0'));
  result := OptVal = '1';
end;

function GetDebugOpt (const OptionName: myAStr; DefValue: boolean = false): boolean;
begin
  result := DebugOpt and (DebugEverythingOpt or GetOptBoolValue(OptionName, DefValue));
end;

function GetOptIntValue (const OptionName: myAStr; DefValue: integer = 0): integer;
var
  OptVal: myAStr;

begin
  OptVal := GetOptValue(OptionName, Legacy.IntToStr(DefValue));

  if not Legacy.TryStrToInt(OptVal, result) then begin
    Log.Write('Settings', 'GetOptIntValue', 'Error. Invalid option "' + OptionName
                                            + '" value: "' + OptVal + '". Assumed ' + Legacy.IntToStr(DefValue));
    result := DefValue;
  end;
end;

procedure InstallLogger (Logger: Log.TLogger);
var
  LogRec: TLogRec;

begin
  {!} Assert(Logger <> nil);
  Log.Seek(0);

  while Log.Read(LogRec) do begin
    Logger.Write(LogRec.EventSource, LogRec.Operation, LogRec.Description);
  end;

  Log.InstallLogger(Logger, Log.FREE_OLD_LOGGER);
end; // .procedure InstallLogger

procedure VfsLogger (Operation, Msg: myPChar); stdcall;
begin
  Log.Write('VFS', Operation, Msg);
end;

procedure OnEraStart (Event: GameExt.PEvent); stdcall;
begin
  Ini.LoadIni(Heroes.GAME_SETTINGS_FILE);
  Ini.LoadIni(Heroes.DEFAULT_GAME_SETTINGS_FILE);
  Ini.MergeIniWithDefault(Heroes.GAME_SETTINGS_FILE, Heroes.DEFAULT_GAME_SETTINGS_FILE);

  DebugOpt           := GetOptBoolValue('Debug', true);
  DebugEverythingOpt := GetOptBoolValue('Debug.Everything', false);

  if DebugOpt then begin
    if Legacy.AnsiLowerCase(GetOptValue('Debug.LogDestination', 'File')) = 'file' then begin
      InstallLogger(EraLog.TFileLogger.Create(GameExt.DEBUG_DIR + '\' + LOG_FILE_NAME));
    end else begin
      InstallLogger(EraLog.TConsoleLogger.Create('Era Log'));
    end;
  end else begin
    InstallLogger(EraLog.TMemoryLogger.Create);
  end;

  Log.Write('Core', 'CheckVersion', 'Result: ' + GameExt.ERA_VERSION_STR);

  Core.AbortOnError              := GetDebugOpt(    'Debug.AbortOnError',          true);
  SndVid.LoadCDOpt               := GetOptBoolValue('LoadCD',                      false);
  Tweaks.CpuTargetLevel          := GetOptIntValue( 'CpuTargetLevel',              33);
  Tweaks.FixGetHostByNameOpt     := GetOptBoolValue('FixGetHostByName',            true);
  Tweaks.UseOnlyOneCpuCoreOpt    := GetOptBoolValue('UseOnlyOneCpuCore',           true);
  Stores.DumpSavegameSectionsOpt := GetDebugOpt(    'Debug.DumpSavegameSections',  false);
  GameExt.DumpVfsOpt             := GetDebugOpt(    'Debug.DumpVirtualFileSystem', false);
  ResLib.ResManCacheSize         := GetOptIntValue( 'ResourceCacheSize',           200000000);
  Tweaks.DebugRng                := GetOptIntValue( 'Debug.Rng',                   0);

  if GetDebugOpt('Debug.LogVirtualFileSystem', false) then begin
    VfsImport.SetLoggingProc(@VfsLogger);
  end;

  Erm.ErmLegacySupport := GetOptBoolValue('ErmLegacySupport', false);

  with Erm.TrackingOpts do begin
    Enabled := GetDebugOpt('Debug.TrackErm');

    if Enabled then begin
      MaxRecords          := Max(1, GetOptIntValue('Debug.TrackErm.MaxRecords',     10000));
      DumpCommands        := GetOptBoolValue('Debug.TrackErm.DumpCommands',         true);
      IgnoreEmptyTriggers := GetOptBoolValue('Debug.TrackErm.IgnoreEmptyTriggers',  true);
    end;
  end;
end; // .procedure OnEraStart

begin
  EventMan.GetInstance.On('OnEraStart', OnEraStart);
end.
