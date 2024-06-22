unit EraSettings;
(*
DESCRIPTION:  Settings management
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
*)

(***)  interface  (***)
uses
  Math,
  SysUtils,

  Core,
  Ini,
  Log, Legacy;

const
  (* Globally used common directories *)
  DEBUG_DIR = myAStr( 'Debug\Era');

  (* Game settings *)
  DEFAULT_GAME_SETTINGS_FILE : myAStr = 'default heroes3.ini';
  GAME_SETTINGS_FILE         : myAStr = 'heroes3.ini';
  ERA_SETTINGS_SECTION       : myAStr = 'Era';
  GAME_SETTINGS_SECTION      : myAStr = 'Settings';

type
  TOption = record
    Value: myAStr;
    Dummy: integer; // This is field is necessary to prevent Delphi 2009 bug, when it tries to optimize 4 byte structures
                    // Memory corruption occurs quite often, while 8 byte structure will be passed as var-parameter and is thus safe

    function Str (const Default: myAStr = ''): myAStr;
    function Int (Default: integer = 0): integer;
    function Bool (Default: boolean = false): boolean;
  end;

(* Load Era settings *)
procedure LoadSettings (const GameDir: myAStr);

(* Returns Era settings option by name *)
function GetOpt (const OptionName: myAStr): TOption;

function IsDebug: boolean;

(* Returns Era debug option by name. The result is influenced by 'Debug' and 'Debug.Evenything' options *)
function GetDebugBoolOpt (const OptionName: myAStr; Default: boolean = false): boolean;


(***)  implementation  (***)


var
  DebugOpt:             boolean;
  DebugEverythingOpt:   boolean;
  GameSettingsFilePath: myAStr;


function TOption.Str (const Default: myAStr = ''): myAStr;
begin
  result := Self.Value;

  if Self.Value = '' then begin
    result := Default;
  end;
end;

function TOption.Int (Default: integer = 0): integer;
begin
  if (Self.Value = '') or not Legacy.TryStrToInt(Self.Value, result) then begin
    result := Default;
  end;
end;

function TOption.Bool (Default: boolean = false): boolean;
begin
  result := Default;

  if Self.Value <> '' then begin
    result := Self.Value <> '0';
  end;
end;

function GetOpt (const OptionName: myAStr): TOption;
begin
  result.Value := '';

  if Ini.ReadStrFromIni(OptionName, ERA_SETTINGS_SECTION, GameSettingsFilePath, result.Value) then begin
    result.Value := Legacy.Trim(result.Value);
  end;
end;

function IsDebug: boolean;
begin
  result := DebugOpt;
end;

function GetDebugBoolOpt (const OptionName: myAStr; Default: boolean = false): boolean;
begin
  result := DebugOpt and (DebugEverythingOpt or GetOpt(OptionName).Bool(Default));
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

procedure LoadSettings (const GameDir: myAStr);
var
  DefaultGameSettingsPath: myAStr;

begin
  GameSettingsFilePath    := GameDir + '\' + GAME_SETTINGS_FILE;
  DefaultGameSettingsPath := GameDir + '\' + DEFAULT_GAME_SETTINGS_FILE;

  Ini.LoadIni(GameSettingsFilePath);
  Ini.LoadIni(DefaultGameSettingsPath);
  Ini.MergeIniWithDefault(GameSettingsFilePath, DefaultGameSettingsPath);

  DebugOpt           := GetOpt('Debug').Bool(true);
  DebugEverythingOpt := GetOpt('Debug.Everything').Bool(false);
  Core.AbortOnError  := GetDebugBoolOpt('Debug.AbortOnError', false);
end;

end.
