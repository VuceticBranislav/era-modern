unit Extern;
(*
  Description: API Wrappers for plugins
  Author:      Alexander Shostak aka Berserker
*)

(***)  interface  (***)


uses
  Math,
  ShlwApi,
  SysUtils,
  Windows,

  Alg,
  ApiJack,
  Crypto,
  DataLib,
  Debug,
  DlgMes,
  Ini,
  PatchApi,
  StrLib,
  TypeWrappers,
  UtilsB2,
  WinUtils,

  AdvErm,
  EraButtons,
  EraUtils,
  Erm,
  EventMan,
  GameExt,
  Graph,
  Heroes,
  Lodman,
  Memory,
  Network,
  Rainbow,
  Stores,
  Trans,
  Triggers,
  Tweaks, Legacy;

type
  (* Import *)
  TEventHandler = EventMan.TEventHandler;
  TDict         = DataLib.TDict;
  TString       = TypeWrappers.TString;

  PErmXVars = ^TErmXVars;
  TErmXVars = array [1..16] of integer;

  TInt32Bool = integer; // 0 or 1

  PAppliedPatch = ^TAppliedPatch;
  TAppliedPatch = packed record
  {O} Data: UtilsB2.PEndlessByteArr;
      Size: integer;
  end;


(***) implementation (***)


type
  TPlugin = class
   protected
        fName:    myAStr;
   {OI} fPatcher: PatchApi.TPatcherInstance; // external dll memory ownage

   public
    constructor Create (const Name: myAStr);
    destructor Destroy; override;

    property Name:    myAStr read fName;
    property Patcher: PatchApi.TPatcherInstance read fPatcher;
  end;

  TPluginManager = class
   protected
   {O} fPlugins: {O} TDict {of TPlugin};

   public
    constructor Create;
    destructor Destroy; override;

    function FindPlugin (const Name: myAStr): {n} TPlugin;
    function RegisterPlugin ({O} Plugin: TPlugin): boolean;
  end;

var
{O} IntRegistry:   {U} TDict {of Ptr(integer)};
{O} StrRegistry:   {O} TDict {of TString};
{O} PluginManager: TPluginManager;
{O} LegacyPlugin:  TPlugin;


const
  EXTERNAL_BUF_PREFIX_SIZE = sizeof(integer);


function AllocExternalBuf (Size: integer): {O} pointer;
begin
  {!} Assert(Size >= 0);
  GetMem(result, Size + EXTERNAL_BUF_PREFIX_SIZE);
  pinteger(result)^ := Size;
  Inc(integer(result), EXTERNAL_BUF_PREFIX_SIZE);
end;

function Externalize (const Str: myAStr): {O} pointer; overload;
begin
  result := AllocExternalBuf(Length(Str) + 1);
  UtilsB2.CopyMem(Length(Str) + 1, myPChar(Str), result);
end;

function Externalize (const Str: myWStr): {O} pointer; overload;
begin
  result := AllocExternalBuf((Length(Str) + 1) * sizeof(myWChar));
  UtilsB2.CopyMem((Length(Str) + 1) * sizeof(myWChar), myPWChar(Str), result);
end;

(* Frees buffer, that was transfered to client earlier *)
procedure MemFree ({On} Buf: pointer); stdcall;  var p: pointer;
begin
  if Buf <> nil then begin
    p:=UtilsB2.PtrOfs(Buf, -EXTERNAL_BUF_PREFIX_SIZE); Legacy.FreeMem(p);
  end;
end;

procedure NameColor (Color32: integer; Name: myPChar); stdcall;
begin
  Rainbow.NameColor(Color32, Name);
end;

procedure NameTrigger (TriggerId: integer; Name: myPChar); stdcall;
begin
  Erm.NameTrigger(TriggerId, Name);
end;

procedure ClearIniCache (FileName: myPChar); stdcall;
begin
  Ini.ClearIniCache(FileName);
end;

function ReadStrFromIni (Key, SectionName, FilePath, Res: myPChar): TInt32Bool; stdcall;
var
  ResStr: myAStr;

begin
  result := TInt32Bool(ord(Ini.ReadStrFromIni(Key, SectionName, FilePath, ResStr)));
  UtilsB2.CopyMem(Length(ResStr) + 1, myPChar(ResStr), Res);
end;

function WriteStrToIni (Key, Value, SectionName, FilePath: myPChar): TInt32Bool; stdcall;
begin
  result := TInt32Bool(ord(Ini.WriteStrToIni(Key, Value, SectionName, FilePath)));
end;

function SaveIni (FilePath: myPChar): TInt32Bool; stdcall;
begin
  result := TInt32Bool(ord(Ini.SaveIni(FilePath)));
end;

procedure WriteSavegameSection (DataSize: integer; {n} Data: pointer; SectionName: myPChar); stdcall;
begin
  Stores.WriteSavegameSection(DataSize, Data, SectionName);
end;

function ReadSavegameSection (DataSize: integer; {n} Dest: pointer; SectionName: myPChar): integer; stdcall;
begin
  result := Stores.ReadSavegameSection(DataSize, Dest, SectionName);
end;

procedure ExecErmCmd (CmdStr: myPChar); stdcall;
begin
  Erm.ExecErmCmd(CmdStr);
end;

(* Compiles single ERM command without !! prefix and conditions and saves its compiled code in persisted memory storage.
   Returns non-nil opaque pointer on success and nil on failure. Trailing semicolon is optional *)
function PersistErmCmd (CmdStr: myPChar): {n} pointer; stdcall;
begin
  result := Erm.CompileErmCmd(CmdStr);
end;

(* Executes previously compiled and persisted ERM command. Use PersistErmCmd API for compilation *)
procedure ExecPersistedErmCmd (PersistedCmd: pointer); stdcall;
begin
  Erm.ZvsProcessCmd(@Erm.PCompiledErmCmd(PersistedCmd).Cmd);
end;

procedure FireErmEvent (EventID: integer); stdcall;
begin
  Erm.FireErmEvent(EventID);
end;

procedure RegisterHandler (Handler: TEventHandler; EventName: myPChar); stdcall;
begin
  EventMan.GetInstance.On(EventName, Handler);
end;

procedure FireEvent (EventName: myPChar; {n} EventData: pointer; DataSize: integer); stdcall;
begin
  EventMan.GetInstance.Fire(EventName, EventData, DataSize);
end;

procedure FatalError (Err: myPChar); stdcall;
begin
  Debug.FatalError(Err);
end;

procedure NotifyError (Err: myPChar); stdcall;
begin
  Debug.NotifyError(Err);
end;

function GetButtonID (ButtonName: myPChar): integer; stdcall;
begin
  result := EraButtons.GetButtonID(ButtonName);
end;

function PatchExists (PatchName: myPChar): TInt32Bool; stdcall;
begin
  result := TInt32Bool(ord(GameExt.PatchExists(PatchName)));
end;

function PluginExists (PluginName: myPChar): TInt32Bool; stdcall;
begin
  result := TInt32Bool(ord(GameExt.PluginExists(PluginName)));
end;

procedure RedirectFile (OldFileName, NewFileName: myPChar); stdcall;
begin
  Lodman.RedirectFile(OldFileName, NewFileName);
end;

procedure GlobalRedirectFile (OldFileName, NewFileName: myPChar); stdcall;
begin
  Lodman.GlobalRedirectFile(OldFileName, NewFileName);
end;

function TakeScreenshot (FilePath: myPChar; Quality: integer; Flags: integer): TInt32Bool; stdcall;
begin
  result := ord(Graph.TakeScreenshot(FilePath, Quality, Flags));
end;

function tr (const Key: myPChar; const Params: array of myPChar): myPChar; stdcall;
var
  ParamList:   UtilsB2.TArrayOfStr;
  Translation: myAStr;
  i:           integer;

begin
  SetLength(ParamList, Length(Params) and not 1);

  for i := 0 to Length(ParamList) - 1 do begin
    ParamList[i] := Params[i];
  end;

  Translation := Trans.tr(Key, ParamList);
  result      := Externalize(Translation);
end;

var
  trTempBuf: myAStr;

function trTemp (const Key: myPChar; const Params: array of myPChar): myPChar; stdcall;
var
  ParamList: UtilsB2.TArrayOfStr;
  i:         integer;

begin
  SetLength(ParamList, Length(Params) and not 1);

  for i := 0 to Length(ParamList) - 1 do begin
    ParamList[i] := Params[i];
  end;

  trTempBuf := Trans.tr(Key, ParamList);
  result    := myPChar(trTempBuf);
end;

function trStatic (const Key: myPChar): myPChar; stdcall;
begin
  result := Memory.UniqueStrings[myPChar(Trans.tr(Key, []))];
end;

function SetLanguage (NewLanguage: myPChar): TInt32Bool; stdcall;
begin
  result := ord(Trans.SetLanguage(NewLanguage));
end;

function LoadImageAsPcx16 (FilePath, PcxName: myPChar; Width, Height, MaxWidth, MaxHeight, ResizeAlg: integer): {OU} Heroes.PPcx16Item; stdcall;
begin
  if FilePath = nil then begin
    FilePath := myPChar('');
  end;

  if PcxName = nil then begin
    PcxName := myPChar('');
  end;

  if (ResizeAlg < ord(Low(Graph.TResizeAlg))) or (ResizeAlg > ord(High(Graph.TResizeAlg))) then begin
    Debug.NotifyError('Invalid ResizeAlg argument for LoadImageAsPcx16: ' + Legacy.IntToStr(ResizeAlg));
    ResizeAlg := ord(Graph.ALG_DOWNSCALE);
  end;

  result := Graph.LoadImageAsPcx16(FilePath, PcxName, Width, Height, MaxWidth, MaxHeight, TResizeAlg(ResizeAlg));
end;

procedure ShowMessage (Mes: myPChar); stdcall;
begin
  Heroes.ShowMessage(Mes);
end;

function Ask (Question: myPChar): TInt32Bool; stdcall;
begin
  result := TInt32Bool(ord(Heroes.Ask(Question)));
end;

procedure ReportPluginVersion (const VersionLine: myPChar); stdcall;
begin
  GameExt.ReportPluginVersion(VersionLine);
end;

function GetVersion: myPChar; stdcall;
begin
  result := myPChar(GameExt.ERA_VERSION_STR);
end;

function GetVersionNum: integer; stdcall;
begin
  result := GameExt.ERA_VERSION_INT;
end;

function Splice (Plugin: TPlugin; OrigFunc, HandlerFunc: pointer; CallingConv: integer; NumArgs: integer; {n} CustomParam: pinteger; {n} AppliedPatch: ppointer): pointer; stdcall;
begin
  {!} Assert(Plugin <> nil);
  {!} Assert((CallingConv >= ord(ApiJack.CONV_FIRST)) and (CallingConv <= ord(ApiJack.CONV_LAST)), string(Legacy.Format('Splice: Invalid calling convention: %d', [CallingConv])));
  {!} Assert(NumArgs >= 0, string(Legacy.Format('Splice: Invalid arguments number: %d', [NumArgs])));

  if AppliedPatch <> nil then begin
    New(ApiJack.PAppliedPatch(AppliedPatch^));
    AppliedPatch := AppliedPatch^;
  end;

  PatchApi.SetMainPatcherInstance(Plugin.Patcher);
  result := ApiJack.StdSplice(OrigFunc, HandlerFunc, ApiJack.TCallingConv(CallingConv), NumArgs, CustomParam, ApiJack.PAppliedPatch(AppliedPatch));
  PatchApi.RestoreMainPatcherInstance;
end;

(* Installs new hook at specified address. Returns pointer to bridge with original code if any. Optionally specify address of a pointer to write applied patch structure
   pointer to. It will allow to rollback the patch later. MinCodeSize specifies original code size to be erased (nopped). Use 0 in most cases. *)
function Hook (Plugin: TPlugin; Addr: pointer; HandlerFunc: THookHandler; {n} AppliedPatch: ppointer; MinCodeSize, HookType: integer): {n} pointer; stdcall;


begin
  {!} Assert(Plugin <> nil);

  if AppliedPatch <> nil then begin
    New(ApiJack.PAppliedPatch(AppliedPatch^));
    AppliedPatch := AppliedPatch^;
  end;

  PatchApi.SetMainPatcherInstance(Plugin.Patcher);
  result := ApiJack.Hook(Addr, HandlerFunc, ApiJack.PAppliedPatch(AppliedPatch), MinCodeSize, ApiJack.THookType(HookType));
  PatchApi.RestoreMainPatcherInstance;
end;

(* Deprecated legacy *)
function HookCode (Addr: pointer; HandlerFunc: THookHandler; {n} AppliedPatch: ppointer): pointer; stdcall;
begin
  if AppliedPatch <> nil then begin
    New(ApiJack.PAppliedPatch(AppliedPatch^));
    AppliedPatch := AppliedPatch^;
  end;

  PatchApi.SetMainPatcherInstance(LegacyPlugin.Patcher);
  result := ApiJack.Hook(Addr, HandlerFunc, ApiJack.PAppliedPatch(AppliedPatch), 0, ApiJack.HOOKTYPE_BRIDGE);
  PatchApi.RestoreMainPatcherInstance;
end;

(* Deprecated legacy *)
function ApiHook (HandlerAddr: pointer; HookType: integer; CodeAddr: pointer): {n} pointer; stdcall;
const
  OLD_HOOKTYPE_JUMP   = 0;
  OLD_HOOKTYPE_CALL   = 1;
  OLD_HOOKTYPE_BRIDGE = 2;

var
  NewHookType: ApiJack.THookType;

begin
  NewHookType := ApiJack.HOOKTYPE_BRIDGE;

  if HookType = OLD_HOOKTYPE_JUMP then begin
    NewHookType := ApiJack.HOOKTYPE_JUMP;
  end else if HookType = OLD_HOOKTYPE_CALL then begin
    NewHookType := ApiJack.HOOKTYPE_CALL;
  end;

  PatchApi.SetMainPatcherInstance(LegacyPlugin.Patcher);
  result := ApiJack.Hook(CodeAddr, HandlerAddr, nil, 0, NewHookType);
  PatchApi.RestoreMainPatcherInstance;
end;

function WriteAtCode (Plugin: TPlugin; NumBytes: integer; {n} Src, {n} Dst: pointer): boolean; stdcall;
begin
  {!} Assert(Plugin <> nil);

  PatchApi.SetMainPatcherInstance(Plugin.Patcher);
  result := ApiJack.WriteAtCode(NumBytes, Src, Dst);
  PatchApi.RestoreMainPatcherInstance;
end;

(* The patch will be rollback and internal memory and freed. Do not use it anymore *)
procedure RollbackAppliedPatch ({O} AppliedPatch: pointer); stdcall;
begin
  {!} Assert(AppliedPatch <> nil);
  ApiJack.PAppliedPatch(AppliedPatch).Rollback;
  Dispose(AppliedPatch);
end;

function IsPatchOverwritten (AppliedPatch: pointer): TInt32Bool; stdcall;
begin
  {!} Assert(AppliedPatch <> nil);
  result := ord(ApiJack.PAppliedPatch(AppliedPatch).IsOverwritten);
end;

(* Frees applied patch structure. Use it if you don't plan to rollback it anymore *)
procedure FreeAppliedPatch ({O} AppliedPatch: pointer); stdcall;
begin
  if AppliedPatch <> nil then begin
    Dispose(AppliedPatch);
  end;
end;

function GetAppliedPatchSize (AppliedPatch: pointer): integer; stdcall;
begin
  {!} Assert(AppliedPatch <> nil);
  result := Length(ApiJack.PAppliedPatch(AppliedPatch).OldBytes);
end;

function GetArgXVars: PErmXVars; stdcall;
begin
  result := @Erm.ArgXVars;
end;

function GetRetXVars: PErmXVars; stdcall;
begin
  result := @Erm.RetXVars;
end;

function GetTriggerReadableName (EventId: integer): {O} myPChar; stdcall;
begin
  result := Externalize(Erm.GetTriggerReadableName(EventId));
end;

procedure RegisterErmReceiver (const Cmd: myPChar; {n} Handler: TErmCmdHandler; ParamsConfig: integer); stdcall;
begin
  AdvErm.RegisterErmReceiver(Cmd[0] + Cmd[1], Handler, ParamsConfig);
end;

procedure Erm_SortInt32Array (Arr: UtilsB2.PEndlessIntArr; MinInd, MaxInd: integer); stdcall;
begin
  Alg.CustomMergeSortInt32(Arr, MinInd, MaxInd, Alg.IntCompare);
end;

function CustomStrComparator (Str1, Str2: integer; {n} State: pointer): integer;
begin
  result := StrLib.ComparePchars(myPChar(Str1), myPChar(Str2));
end;

procedure Erm_SortStrArray (Arr: UtilsB2.PEndlessIntArr; MinInd, MaxInd: integer); stdcall;
begin
  Alg.CustomMergeSortInt32(Arr, MinInd, MaxInd, CustomStrComparator);
end;

type
  PErmCustomCompareFuncInfo = ^TErmCustomCompareFuncInfo;
  TErmCustomCompareFuncInfo = record
    FuncId: integer;
    State:  pointer;
  end;

function _ErmCustomCompareFuncBridge (Value1, Value2: integer; {n} State: pointer): integer;
const
  ARG_VALUE1 = 1;
  ARG_VALUE2 = 2;
  ARG_STATE  = 3;
  ARG_RESULT = 4;

begin
  Erm.ArgXVars[ARG_VALUE1] := Value1;
  Erm.ArgXVars[ARG_VALUE2] := Value2;
  Erm.ArgXVars[ARG_STATE]  := integer(PErmCustomCompareFuncInfo(State).State);
  Erm.ArgXVars[ARG_RESULT] := 0;
  Erm.FireErmEvent(PErmCustomCompareFuncInfo(State).FuncId);
  result := Erm.RetXVars[ARG_RESULT];
end;

procedure Erm_CustomStableSortInt32Array (Arr: UtilsB2.PEndlessIntArr; MinInd, MaxInd: integer; ComparatorFuncId: integer; {n} State: pointer); stdcall;
var
  CompareFuncInfo: TErmCustomCompareFuncInfo;

begin
  CompareFuncInfo.FuncId := ComparatorFuncId;
  CompareFuncInfo.State  := State;
  Alg.CustomMergeSortInt32(Arr, MinInd, MaxInd, _ErmCustomCompareFuncBridge, @CompareFuncInfo);
end;

procedure Erm_RevertInt32Array (Arr: UtilsB2.PEndlessIntArr; MinInd, MaxInd: integer); stdcall;
var
  LeftInd:  integer;
  RightInd: integer;
  Temp:     integer;

begin
  LeftInd  := MinInd;
  RightInd := MaxInd;

  while LeftInd < RightInd do begin
    Temp          := Arr[LeftInd];
    Arr[LeftInd]  := Arr[RightInd];
    Arr[RightInd] := Temp;

    Inc(LeftInd);
    Dec(RightInd);
  end;
end; // .procedure Erm_RevertInt32Array

procedure Erm_FillInt32Array (Arr: UtilsB2.PEndlessIntArr; MinInd, MaxInd, StartValue, Step: integer); stdcall;
var
  i: integer;

begin
  for i := MinInd to MaxInd do begin
    Arr[i] := StartValue;
    Inc(StartValue, Step);
  end;
end;

function Erm_Sqrt (Value: single): single; stdcall;
begin
  result := Sqrt(Value);
end;

function Erm_Pow (Base, Power: single): single; stdcall;
begin
  result := Math.Power(Base, Power);
end;

function Erm_IntLog2 (Value: integer): integer; stdcall;
begin
  result := Alg.IntLog2(Value);
end;

function Erm_CompareStrings (Addr1, Addr2: myPChar): integer; stdcall;
begin
  result := StrLib.ComparePchars(Addr1, Addr2);
end;

(* Returns substring of original string in the form of new trigger-local ert z-var index *)
function Erm_Substr (Str: myPChar; Offset, Count: integer): integer; stdcall;
var
  Res:    myAStr;
  StrLen: integer;

begin
  result := 0;

  if Erm.ErmTriggerDepth > 0 then begin
    StrLen := Windows.LStrLenA(Str);
    Res    := '';

    if Offset < 0 then begin
      Offset := Math.Max(0, StrLen + Offset);
    end;

    if Count < 0 then begin
      Inc(Count, StrLen);
    end;

    if (StrLen > 0) and (Offset < StrLen) and (Count > 0) then begin
      Count := Math.Min(StrLen - Offset, Count);
      SetLength(Res, Count);
      UtilsB2.CopyMem(Count, @Str[Offset], pointer(Res));
    end;

    result := Erm.CreateTriggerLocalErt(myPChar(Res), Length(Res));
  end;
end;

function Erm_StrPos (Where, What: myPChar; Offset: integer): integer; stdcall;
var
  WhereLen: integer;
  FoundPos: myPChar;

begin
  result := -1;

  if Offset <> 0 then begin
    if Offset < 0 then begin
      exit;
    end;

    WhereLen := StrLib.StrLen(Where);

    if Offset >= WhereLen then begin
      exit;
    end;

    FoundPos := ShlwApi.StrStrA(UtilsB2.PtrOfs(Where, Offset), What);
  end else begin
    FoundPos := ShlwApi.StrStrA(Where, What);
  end;

  if FoundPos <> nil then begin
    result := integer(FoundPos) - integer(Where);
  end;
end;

(* Replaces What strings inside Where string with Replacement strings and returns new trigger-local ert z-var index *)
function Erm_StrReplace (Where, What, Replacement: myPChar): integer; stdcall;
var
  Res: myAStr;

begin
  result := 0;

  if Erm.ErmTriggerDepth > 0 then begin
    Res    := Legacy.StringReplace(Where, What, Replacement, [Legacy.rfReplaceAll]);
    result := Erm.CreateTriggerLocalErt(myPChar(Res), Length(Res));
  end;
end;

(* Trims string and returns new trigger-local ert z-var index *)
function Erm_StrTrim (Str: myPChar): integer; stdcall;
var
  Res: myAStr;

begin
  result := 0;

  if Erm.ErmTriggerDepth > 0 then begin
    Res    := Legacy.Trim(Str);
    result := Erm.CreateTriggerLocalErt(myPChar(Res), Length(Res));
  end;
end;

(* Interpolates ERM variables inside string (%v1, etc) and returns newtrigger-local ert z-var index *)
function Erm_Interpolate (Str: myPChar): integer; stdcall;
begin
  result := 0;

  if Erm.ErmTriggerDepth > 0 then begin
    result := Erm.CreateTriggerLocalErt(Erm.InterpolateErmStr(Str));
  end;
end;

procedure ShowErmError (Error: myPChar); stdcall;
begin
  if Error = nil then begin
    Error := '';
  end;

  Erm.ZvsErmError(nil, 0, Error);
end;

function AllocErmFunc (FuncName: myPChar; {i} out FuncId: integer): TInt32Bool; stdcall;
begin
  result := TInt32Bool(ord(Erm.AllocErmFunc(FuncName, FuncId)));
end;

function FindNextObject (ObjType, ObjSubtype: integer; var x, y, z: integer; Direction: integer): integer; stdcall;
begin
  result := ord(not Heroes.ZvsFindNextObjects(ObjType, ObjSubtype, x, y, z, Direction));
end;

function ToStaticStr ({n} Str: myPChar): {n} myPChar; stdcall;
begin
  result := Memory.UniqueStrings[Str];
end;

function DecorateInt (Value: integer; Buf: myPChar; IgnoreSmallNumbers: integer): integer; stdcall;
var
  Str: myAStr;

begin
  Str := EraUtils.DecorateInt(Value, IgnoreSmallNumbers <> 0);
  UtilsB2.SetPcharValue(Buf, Str, High(integer));
  result := Length(Str);
end;

function FormatQuantity (Value: integer; Buf: myPChar; BufSize: integer; MaxLen, MaxDigits: integer): integer; stdcall;
var
  Str: myAStr;

begin
  Str := EraUtils.FormatQuantity(Value, MaxLen, MaxDigits);
  UtilsB2.SetPcharValue(Buf, Str, BufSize);
  result := Length(Str);
end;

var
  (* Global unique process GUID, generated on demand *)
  ProcessGuid: myAStr;

(* Returns 32-character unique key for current game process. The ID will be unique between multiple game runs. *)
function GetProcessGuid: myPChar; stdcall;
var
  ProcessGuidBuf: array [0..sizeof(GameExt.ProcessStartTime) - 1] of byte;

begin
  if ProcessGuid = '' then begin
    Legacy.FillChar(ProcessGuidBuf, sizeof(ProcessGuidBuf), #0);

    if not WinUtils.RtlGenRandom(@ProcessGuidBuf, sizeof(ProcessGuidBuf)) then begin
      UtilsB2.CopyMem(sizeof(GameExt.ProcessStartTime), @GameExt.ProcessStartTime, @ProcessGuidBuf);
    end;

    ProcessGuid := StrLib.BinToHex(sizeof(ProcessGuidBuf), @ProcessGuidBuf);
  end;

  result := myPChar(ProcessGuid);
end;

function IsCampaign: TInt32Bool; stdcall;
begin
  result := TInt32Bool(ord(Heroes.IsCampaign));
end;

procedure GetCampaignFileName (Buf: myPChar); stdcall;
begin
  UtilsB2.SetPcharValue(Buf, Heroes.GetCampaignFileName, sizeof(Erm.z[1]));
end;

procedure GetMapFileName (Buf: myPChar); stdcall;
begin
  UtilsB2.SetPcharValue(Buf, Heroes.GetMapFileName, sizeof(Erm.z[1]));
end;

function GetCampaignMapInd: integer; stdcall;
begin
  result := Heroes.GetCampaignMapInd;
end;

function GetAssocVarIntValue (const VarName: myPChar): integer; stdcall;
var
  AssocVar: AdvErm.TAssocVar;

begin
  AssocVar := AdvErm.AssocMem[VarName];
  result   := 0;

  if AssocVar <> nil then begin
    result := AssocVar.IntValue;
  end;
end;

function GetAssocVarStrValue (const VarName: myPChar): {O} myPChar; stdcall;
var
  AssocVar: AdvErm.TAssocVar;

begin
  AssocVar := AdvErm.AssocMem[VarName];

  if AssocVar <> nil then begin
    result := Externalize(AssocVar.StrValue);
  end else begin
    result := Externalize('');
  end;
end;

procedure SetAssocVarIntValue (const VarName: myPChar; NewValue: integer); stdcall;
begin
  AdvErm.GetOrCreateAssocVar(VarName).IntValue := NewValue;
end;

procedure SetAssocVarStrValue (const VarName, NewValue: myPChar); stdcall;
begin
  AdvErm.GetOrCreateAssocVar(VarName).StrValue := NewValue;
end;

function GetEraRegistryIntValue (const Key: myPChar): integer; stdcall;
begin
  result := integer(IntRegistry[Key]);
end;

procedure SetEraRegistryIntValue (const Key: myPChar; NewValue: integer); stdcall;
begin
  IntRegistry[Key] := Ptr(NewValue);
end;

function GetEraRegistryStrValue (const Key: myPChar): {O} myPChar; stdcall;
begin
  result := StrRegistry[Key];

  if result <> nil then begin
    result := Externalize(TString(result).Value);
  end else begin
    result := Externalize('');
  end;
end;

procedure SetEraRegistryStrValue (const Key: myPChar; NewValue: myPChar); stdcall;
begin
  StrRegistry[Key] := TString.Create(NewValue);
end;

function PcxPngExists (const PcxName: myPChar): TInt32Bool; stdcall;
begin
  result := ord(Graph.PcxPngExists(PcxName));
end;

function FireRemoteEvent (DestPlayerId: integer; EventName: myPChar; {n} Data: pointer; DataSize: integer; {n} ProgressHandler: Network.TNetworkStreamProgressHandler;
                                 {n} ProgressHandlerCustomParam: pointer): TInt32Bool; stdcall;
begin
  result := ord(Network.FireRemoteEvent(DestPlayerId, EventName, Data, DataSize, ProgressHandler, ProgressHandlerCustomParam));
end;

function Hash32 (Data: myPChar; DataSize: integer): integer; stdcall;
begin
  result := Crypto.FastHash(Data, DataSize);
end;

function _SplitMix32 (var Seed: integer): integer;
begin
  Inc(Seed, integer($9E3779B9));
  result := Seed xor (Seed shr 15);
  result := result * integer($85EBCA6B);
  result := result xor (result shr 13);
  result := result * integer($C2B2AE35);
  result := result xor (result shr 16);
end;

function SplitMix32 (var Seed: integer; MinValue, MaxValue: integer): integer; stdcall;
var
  RangeLen:         cardinal;
  MaxUnbiasedValue: cardinal;
  i:                integer;

begin
  if MinValue >= MaxValue then begin
    result := MinValue;
    exit;
  end;

  if (MinValue = Low(integer)) and (MaxValue = High(integer)) then begin
    result := _SplitMix32(Seed);
    exit;
  end;

  RangeLen         := cardinal(MaxValue - MinValue + 1);
  MaxUnbiasedValue := High(cardinal) div RangeLen * RangeLen - 1;

  for i := 0 to 100 do begin
    result := _SplitMix32(Seed);

    if cardinal(result) <= MaxUnbiasedValue then begin
      break;
    end;
  end;

  result := MinValue + integer(cardinal(result) mod RangeLen);
end;

function CreatePlugin (Name: myPChar) : {On} TPlugin; stdcall;
var
  PluginName: myAStr;

begin
  result     := nil;
  PluginName := Name;

  if PluginManager.FindPlugin(PluginName) = nil then begin
    result := TPlugin.Create(PluginName);
    PluginManager.RegisterPlugin(result);
  end;
end;

constructor TPlugin.Create (const Name: myAStr);
begin
  inherited Create;
  Self.fName    := Name;
  Self.fPatcher := PatchApi.GetPatcher.GetInstance(myPChar(Name));

  if Self.fPatcher = nil then begin
    Self.fPatcher := PatchApi.GetPatcher.CreateInstance(myPChar(Name));
  end;
end;

destructor TPlugin.Destroy;
begin
  // do nothing
  inherited;
end;

constructor TPluginManager.Create;
begin
  inherited;
  Self.fPlugins := DataLib.NewDict(UtilsB2.OWNS_ITEMS, not DataLib.CASE_SENSITIVE);
end;

destructor TPluginManager.Destroy;
begin
  Legacy.FreeAndNil(Self.fPlugins);
  inherited;
end;

function TPluginManager.FindPlugin (const Name: myAStr): {n} TPlugin;
begin
  result := Self.fPlugins[Name];
end;

function TPluginManager.RegisterPlugin ({O} Plugin: TPlugin): boolean;
begin
  result := Self.fPlugins[Plugin.Name] = nil;

  if result then begin
    Self.fPlugins[Plugin.Name] := Plugin;
  end;
end;

exports
  AdvErm.ExtendArrayLifetime,
  AllocErmFunc,
  ApiHook,
  Ask,
  ClearIniCache,
  CreatePlugin,
  DecorateInt,
  Erm.DisableErmTracking,
  Erm.EnableErmTracking,
  Erm.ExtractErm,
  Erm.GetDialog8SelectablePicsMask name '_GetDialog8SelectablePicsMask',
  Erm.GetPreselectedDialog8ItemId name '_GetPreselectedDialog8ItemId',
  Erm.ReloadErm,
  Erm.ResetErmTracking,
  Erm.RestoreErmTracking,
  Erm.SetDialog8SelectablePicsMask name '_SetDialog8SelectablePicsMask',
  Erm.SetPreselectedDialog8ItemId name '_SetPreselectedDialog8ItemId',
  Erm_CompareStrings,
  Erm_CustomStableSortInt32Array,
  Erm_FillInt32Array,
  Erm_Interpolate,
  Erm_IntLog2,
  Erm_Pow,
  Erm_RevertInt32Array,
  Erm_SortInt32Array,
  Erm_SortStrArray,
  Erm_Sqrt,
  Erm_StrPos,
  Erm_StrReplace,
  Erm_StrTrim,
  Erm_Substr,
  ExecErmCmd,
  ExecPersistedErmCmd,
  FatalError,
  FindNextObject,
  FireErmEvent,
  FireEvent,
  FireRemoteEvent,
  FormatQuantity,
  FreeAppliedPatch,
  GameExt.GenerateDebugInfo,
  GameExt.GetRealAddr,
  GameExt.RedirectMemoryBlock,
  GetAppliedPatchSize,
  GetArgXVars,
  GetAssocVarIntValue,
  GetAssocVarStrValue,
  GetButtonID,
  GetCampaignFileName,
  GetCampaignMapInd,
  GetEraRegistryIntValue,
  GetEraRegistryStrValue,
  GetMapFileName,
  GetProcessGuid,
  GetRetXVars,
  GetTriggerReadableName,
  GetVersion,
  GetVersionNum,
  GlobalRedirectFile,
  Graph.DecRef,
  Hash32,
  Heroes.GetGameState,
  Heroes.LoadTxt,
  Hook,
  HookCode,
  Ini.ClearAllIniCache,
  IsCampaign,
  IsPatchOverwritten,
  LoadImageAsPcx16,
  MemFree,
  NameColor,
  NameTrigger,
  NotifyError,
  PatchExists,
  PcxPngExists,
  PersistErmCmd,
  PluginExists,
  ReadSavegameSection,
  ReadStrFromIni,
  RedirectFile,
  RegisterErmReceiver,
  RegisterHandler,
  ReportPluginVersion,
  RollbackAppliedPatch,
  SaveIni,
  SetAssocVarIntValue,
  SetAssocVarStrValue,
  SetEraRegistryIntValue,
  SetEraRegistryStrValue,
  SetLanguage,
  ShowErmError,
  ShowMessage,
  Splice,
  SplitMix32,
  TakeScreenshot,
  ToStaticStr,
  tr,
  Trans.ReloadLanguageData,
  Triggers.FastQuitToGameMenu,
  Triggers.SetRegenerationAbility,
  Triggers.SetStdRegenerationEffect,
  trStatic,
  trTemp,
  Tweaks.RandomRangeWithFreeParam,
  WriteAtCode,
  WriteSavegameSection,
  WriteStrToIni;

begin
  IntRegistry   := DataLib.NewDict(not UtilsB2.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  StrRegistry   := DataLib.NewDict(UtilsB2.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  PluginManager := TPluginManager.Create;
  LegacyPlugin  := TPlugin.Create('__ERA_Legacy__');
  PluginManager.RegisterPlugin(LegacyPlugin);
end.
