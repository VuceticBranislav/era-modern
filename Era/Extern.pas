unit Extern;
(*
  DESCRIPTION: API Wrappers for plugins
  AUTHOR:      Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
*)

(***)  interface  (***)


uses
  Math,
  SysUtils,
  Windows,

  AdvErm,
  Alg,
  ApiJack,
  Core,
  Crypto,
  DataLib,
  EraButtons,
  EraUtils,
  Erm,
  EventMan,
  GameExt,
  Graph,
  Heroes,
  Ini,
  Lodman,
  Memory,
  Network,
  Rainbow,
  Stores,
  StrLib,
  Trans,
  Triggers,
  Tweaks,
  TypeWrappers,
  UtilsB2,
  WinUtils, Legacy;

type
  (* Import *)
  TEventHandler = EventMan.TEventHandler;
  TDict         = DataLib.TDict;
  TString       = TypeWrappers.TString;

  PErmXVars = ^TErmXVars;
  TErmXVars = array [1..16] of integer;

  TDwordBool = integer; // 0 or 1


(***) implementation (***)


var
{O} IntRegistry: {U} TDict {of Ptr(integer)};
{O} StrRegistry: {O} TDict {of TString};


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
procedure MemFree ({On} Buf: pointer); stdcall;
begin
  if Buf <> nil then begin
    FreeMem(UtilsB2.PtrOfs(Buf, -EXTERNAL_BUF_PREFIX_SIZE));
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

function ReadStrFromIni (Key, SectionName, FilePath, Res: myPChar): TDwordBool; stdcall;
var
  ResStr: myAStr;

begin
  result := TDwordBool(ord(Ini.ReadStrFromIni(Key, SectionName, FilePath, ResStr)));
  UtilsB2.CopyMem(Length(ResStr) + 1, myPChar(ResStr), Res);
end;

function WriteStrToIni (Key, Value, SectionName, FilePath: myPChar): TDwordBool; stdcall;
begin
  result := TDwordBool(ord(Ini.WriteStrToIni(Key, Value, SectionName, FilePath)));
end;

function SaveIni (FilePath: myPChar): TDwordBool; stdcall;
begin
  result := TDwordBool(ord(Ini.SaveIni(FilePath)));
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
  Core.FatalError(Err);
end;

procedure NotifyError (Err: myPChar); stdcall;
begin
  Core.NotifyError(Err);
end;

function GetButtonID (ButtonName: myPChar): integer; stdcall;
begin
  result := EraButtons.GetButtonID(ButtonName);
end;

function PatchExists (PatchName: myPChar): TDwordBool; stdcall;
begin
  result := TDwordBool(ord(GameExt.PatchExists(PatchName)));
end;

function PluginExists (PluginName: myPChar): TDwordBool; stdcall;
begin
  result := TDwordBool(ord(GameExt.PluginExists(PluginName)));
end;

procedure RedirectFile (OldFileName, NewFileName: myPChar); stdcall;
begin
  Lodman.RedirectFile(OldFileName, NewFileName);
end;

procedure GlobalRedirectFile (OldFileName, NewFileName: myPChar); stdcall;
begin
  Lodman.GlobalRedirectFile(OldFileName, NewFileName);
end;

function tr (const Key: myPChar; const Params: array of myPChar): myPChar; stdcall;
var
  ParamList:   UtilsB2.TArrayOfStr;
  Translation: myAStr;
  i:           integer;

begin
  SetLength(ParamList, length(Params));

  for i := 0 to High(Params) do begin
    ParamList[i] := Params[i];
  end;

  Translation := Trans.tr(Key, ParamList);
  result      := Externalize(Translation);
end; // .function tr

function SetLanguage (NewLanguage: myPChar): TDwordBool; stdcall;
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
    Core.NotifyError('Invalid ResizeAlg argument for LoadImageAsPcx16: ' + Legacy.IntToStr(ResizeAlg));
    ResizeAlg := ord(Graph.ALG_DOWNSCALE);
  end;

  result := Graph.LoadImageAsPcx16(FilePath, PcxName, Width, Height, MaxWidth, MaxHeight, TResizeAlg(ResizeAlg));
end;

procedure ShowMessage (Mes: myPChar); stdcall;
begin
  Heroes.ShowMessage(Mes);
end;

function Ask (Question: myPChar): TDwordBool; stdcall;
begin
  result := TDwordBool(ord(Heroes.Ask(Question)));
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

function Splice (OrigFunc, HandlerFunc: pointer; CallingConv: integer; NumArgs: integer; {n} CustomParam: pinteger; {n} AppliedPatch: ppointer): pointer; stdcall;
begin
  {!} Assert((CallingConv >= ord(ApiJack.CONV_FIRST)) and (CallingConv <= ord(ApiJack.CONV_LAST)), string(Legacy.Format('Splice: Invalid calling convention: %d', [CallingConv])));
  {!} Assert(NumArgs >= 0, string(Legacy.Format('Splice>> Invalid arguments number: %d', [NumArgs])));
  if AppliedPatch <> nil then begin
    New(ApiJack.PAppliedPatch(AppliedPatch^));
    AppliedPatch := AppliedPatch^;
  end;

  result := ApiJack.StdSplice(OrigFunc, HandlerFunc, ApiJack.TCallingConv(CallingConv), NumArgs, CustomParam, ApiJack.PAppliedPatch(AppliedPatch));
end;

function HookCode (Addr: pointer; HandlerFunc: THookHandler; {n} AppliedPatch: ppointer): pointer; stdcall;
begin
  if AppliedPatch <> nil then begin
    New(ApiJack.PAppliedPatch(AppliedPatch^));
    AppliedPatch := AppliedPatch^;
  end;

  result := ApiJack.HookCode(Addr, HandlerFunc, ApiJack.PAppliedPatch(AppliedPatch));
end;

function GetArgXVars: PErmXVars; stdcall;
begin
  result := @Erm.ArgXVars;
end;

function GetRetXVars: PErmXVars; stdcall;
begin
  result := @Erm.RetXVars;
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

procedure ShowErmError (Error: myPChar); stdcall;
begin
  if Error = nil then begin
    Error := '';
  end;

  Erm.ZvsErmError(nil, 0, Error);
end;

function AllocErmFunc (FuncName: myPChar; {i} out FuncId: integer): TDwordBool; stdcall;
begin
  result := TDwordBool(ord(Erm.AllocErmFunc(FuncName, FuncId)));
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
procedure GetProcessGuid (Buf: myPChar); stdcall;
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

  UtilsB2.CopyMem(Length(ProcessGuid) + 1, myPChar(ProcessGuid), Buf);
end;

function IsCampaign: TDwordBool; stdcall;
begin
  result := TDwordBool(ord(Heroes.IsCampaign));
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

function PcxPngExists (const PcxName: myPChar): TDwordBool; stdcall;
begin
  result := ord(Graph.PcxPngExists(PcxName));
end;

function FireRemoteEvent (DestPlayerId: integer; EventName: myPChar; {n} Data: pointer; DataSize: integer; {n} ProgressHandler: Network.TNetworkStreamProgressHandler;
                                 {n} ProgressHandlerCustomParam: pointer): TDwordBool; stdcall;
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

exports
  AdvErm.ExtendArrayLifetime,
  AllocErmFunc,
  Ask,
  ClearIniCache,
  Core.ApiHook,
  Core.Hook,
  Core.WriteAtCode,
  DecorateInt,
  Erm.ExtractErm,
  Erm.GetDialog8SelectablePicsMask name '_GetDialog8SelectablePicsMask',
  Erm.GetPreselectedDialog8ItemId name '_GetPreselectedDialog8ItemId',
  Erm.ReloadErm,
  Erm.SetDialog8SelectablePicsMask name '_SetDialog8SelectablePicsMask',
  Erm.SetPreselectedDialog8ItemId name '_SetPreselectedDialog8ItemId',
  Erm_CompareStrings,
  Erm_CustomStableSortInt32Array,
  Erm_FillInt32Array,
  Erm_IntLog2,
  Erm_Pow,
  Erm_RevertInt32Array,
  Erm_SortInt32Array,
  Erm_SortStrArray,
  Erm_Sqrt,
  ExecErmCmd,
  FatalError,
  FindNextObject,
  FireErmEvent,
  FireEvent,
  FireRemoteEvent,
  FormatQuantity,
  GameExt.GenerateDebugInfo,
  GameExt.GetRealAddr,
  GameExt.RedirectMemoryBlock,
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
  GetVersion,
  GetVersionNum,
  GlobalRedirectFile,
  Graph.DecRef,
  Hash32,
  Heroes.GetGameState,
  Heroes.LoadTxt,
  HookCode,
  Ini.ClearAllIniCache,
  IsCampaign,
  LoadImageAsPcx16,
  MemFree,
  NameColor,
  NameTrigger,
  NotifyError,
  PatchExists,
  PcxPngExists,
  PluginExists,
  ReadSavegameSection,
  ReadStrFromIni,
  RedirectFile,
  RegisterErmReceiver,
  RegisterHandler,
  ReportPluginVersion,
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
  ToStaticStr,
  tr,
  Trans.ReloadLanguageData,
  Triggers.FastQuitToGameMenu,
  Triggers.SetRegenerationAbility,
  Triggers.SetStdRegenerationEffect,
  Tweaks.RandomRangeWithFreeParam,
  WriteSavegameSection,
  WriteStrToIni;

begin
  IntRegistry := DataLib.NewDict(not UtilsB2.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  StrRegistry := DataLib.NewDict(UtilsB2.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
end.
