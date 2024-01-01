unit Tweaks;
(*
  Description: Game fixes, tweaks and improvements
  Author:      Alexander Shostak (aka Berserker aka EtherniDee)
*)

(***)  interface  (***)
uses
  Math,
  SysUtils,
  Types,
  Windows,
  WinSock,

  Alg,
  ApiJack,
  CFiles,
  Concur,
  ConsoleApi,
  Core,
  Crypto,
  DataLib,
  DlgMes,
  Erm,
  EventMan,
  FastRand,
  Files,
  FilesEx,
  GameExt,
  Heroes,
  Ini,
  Lodman,
  PatchApi,
  Stores,
  StrLib,
  Trans,
  UtilsB2,
  WinNative, Legacy;

type
  (* Import *)
  TStrList = DataLib.TStrList;
  TRect    = Types.TRect;

const
  // f (Value: pchar; MaxResLen: integer; DefValue, Key, SectionName, FileName: pchar): integer; cdecl;
  ZvsReadStrIni  = Ptr($773A46);
  // f (Res: PINTEGER; DefValue: integer; Key, SectionName, FileName: pchar): integer; cdecl;
  // ZvsReadIntIni  = Ptr($7739D1);
  // f (Value: pchar; Key, SectionName, FileName: pchar): integer; cdecl;
  ZvsWriteStrIni = Ptr($773B34);
  // f (Value, Key, SectionName, FileName: pchar): integer; cdecl;
  ZvsWriteIntIni = Ptr($773ACB);
  // f ()
  ZvsNoMoreTactic1 = Ptr($75D1FF);

  ZvsAppliedDamage: pinteger = Ptr($2811888);
  CurrentMp3Track:  myPChar  = pointer($6A33F4);

  FIRST_TACTICS_ROUND = -1000000000;

  DEBUG_RNG_NONE  = 0; // do not debug
  DEBUG_RNG_SRAND = 1; // debug only seeds
  DEBUG_RNG_RANGE = 2; // debug only seeds and range generations
  DEBUG_RNG_ALL   = 3; // debug all rand/srand/rand_range calls


var
  (* Desired level of CPU loading *)
  CpuTargetLevel: integer;

  FixGetHostByNameOpt:  boolean;
  UseOnlyOneCpuCoreOpt: boolean;
  DebugRng:             integer;


(* Generates random value in specified range with additional custom parameter used only in deterministic generators to produce different outputs for sequence of generations *)
function RandomRangeWithFreeParam (MinValue, MaxValue, FreeParam: integer): integer; stdcall;


(***) implementation (***)


const
  RNG_SAVE_SECTION : myAStr = 'Era.RNG';

  DL_GROUP_INDEX_MARKER = 100000; // DL frame index column is DL_GROUP_INDEX_MARKER * groupIndex + frameIndex

type
  TWogMp3Process = procedure; stdcall;

  TBattleDeterministicRngState = packed record
    fCombatRound:    integer;
    fRangeMin:       integer;
    fCombatId:       integer;
    fRangeMax:       integer;
    fCombatActionId: integer;
    fFreeParam:      integer;
  end;

  TBattleDeterministicRng = class (FastRand.TRng)
   protected
    fState:             TBattleDeterministicRngState;
    fCombatIdPtr:       pinteger;
    fCombatRoundPtr:    pinteger;
    fCombatActionIdPtr: pinteger;
    fFreeParamPtr:      pinteger;

    procedure UpdateState (RangeMin, RangeMax: integer);

   public
    constructor Create (CombatIdPtr, CombatRoundPtr, CombatActionIdPtr, FreeParamPtr: pinteger);

    procedure Seed (NewSeed: integer); override;
    function Random: integer; override;
    function GetStateSize: integer; override;
    procedure ReadState (Buf: pointer); override;
    procedure WriteState (Buf: pointer); override;
    function RandomRange (MinValue, MaxValue: integer): integer; override;
  end;

var
{O} TopLevelExceptionHandlers: DataLib.TList {OF Handler: pointer};
{O} CLangRng:                  FastRand.TClangRng;
{O} QualitativeRng:            FastRand.TXoroshiro128Rng;
{O} BattleDeterministicRng:    TBattleDeterministicRng;
{U} GlobalRng:                 FastRand.TRng;

  hTimerEvent:           THandle;
  InetCriticalSection:   Windows.TRTLCriticalSection;
  ExceptionsCritSection: Concur.TCritSection;
  ZvsLibImageTemplate:   myAStr;
  ZvsLibGamePath:        myAStr;
  IsLocalPlaceObject:    boolean = true;
  DlgLastEvent:          Heroes.TMouseEventInfo;

  Mp3TriggerHandledEvent: THandle;
  IsMp3Trigger:           boolean = false;
  WogCurrentMp3TrackPtr:  PPAnsiChar = pointer($28AB204);
  WoGMp3Process:          TWogMp3Process = pointer($77495F);

  CombatId:            integer;
  CombatRound:         integer;
  CombatActionId:      integer;
  CombatRngFreeParam:  integer;
  HadTacticsPhase:     boolean;
  NativeRngSeed:       pinteger = pointer($67FBE4);

threadvar
  (* Counter (0..100). When reaches 100, PeekMessageA does not call sleep before returning result *)
  CpuPatchCounter: integer;
  IsMainThread:    boolean;


constructor TBattleDeterministicRng.Create (CombatIdPtr, CombatRoundPtr, CombatActionIdPtr, FreeParamPtr: pinteger);
begin
  Self.fCombatIdPtr       := CombatIdPtr;
  Self.fCombatRoundPtr    := CombatRoundPtr;
  Self.fCombatActionIdPtr := CombatActionIdPtr;
  Self.fFreeParamPtr      := FreeParamPtr;
end;

procedure TBattleDeterministicRng.UpdateState (RangeMin, RangeMax: integer);
begin
  Self.fState.fCombatRound    := Crypto.Tm32Encode(Self.fCombatRoundPtr^);
  Self.fState.fRangeMin       := RangeMin;
  Self.fState.fCombatId       := Crypto.Tm32Encode(Self.fCombatIdPtr^);
  Self.fState.fRangeMax       := RangeMax;
  Self.fState.fCombatActionId := Crypto.Tm32Encode(Self.fCombatActionIdPtr^ + 1147022261);
  Self.fState.fFreeParam      := Crypto.Tm32Encode(Self.fFreeParamPtr^ + 641013956);
end;

procedure TBattleDeterministicRng.Seed (NewSeed: integer);
begin
  // Ignored
end;

function TBattleDeterministicRng.Random: integer;
begin
  Self.UpdateState(Low(result), High(result));
  result := Crypto.FastHash(@Self.fState, sizeof(Self.fState));
end;

function TBattleDeterministicRng.RandomRange (MinValue, MaxValue: integer): integer;
begin
  if MinValue >= MaxValue then begin
    result := MinValue;
    exit;
  end;

  Self.UpdateState(MinValue, MaxValue);
  result := Crypto.FastHash(@Self.fState, sizeof(Self.fState));

  if (MinValue > Low(integer)) or (MaxValue < High(integer)) then begin
    result := MinValue + integer(cardinal(result) mod cardinal(MaxValue - MinValue + 1));
  end;
end;

function TBattleDeterministicRng.GetStateSize: integer;
begin
  result := 0;
end;

procedure TBattleDeterministicRng.ReadState (Buf: pointer);
begin
  // Ignored
end;

procedure TBattleDeterministicRng.WriteState (Buf: pointer);
begin
  // Ignored
end;

function Hook_ReadIntIni
(
  Res:          PINTEGER;
  DefValue:     integer;
  Key:          myPChar;
  SectionName:  myPChar;
  FileName:     myPChar
): integer; cdecl;

var
  Value:  myAStr;
  
begin
  result  :=  0;
  
  if
    (not Ini.ReadStrFromIni(Key, SectionName, FileName, Value)) or
    not Legacy.TryStrToInt(Value, Res^)
  then begin
    Res^  :=  DefValue;
  end;
end; // .function Hook_ReadIntIni

function Hook_ReadStrIni
(
  Res:          myPChar;
  MaxResLen:    integer;
  DefValue:     myPChar;
  Key:          myPChar;
  SectionName:  myPChar;
  FileName:     myPChar
): integer; cdecl;

var
  Value:  myAStr;
  
begin
  result  :=  0;

  if
    (not Ini.ReadStrFromIni(Key, SectionName, FileName, Value)) or
    (Length(Value) > MaxResLen)
  then begin
    Value :=  DefValue;
  end;
  
  if Value <> '' then begin
    UtilsB2.CopyMem(Length(Value) + 1, pointer(Value), Res);
  end else begin
    Res^  :=  #0;
  end;
end; // .function Hook_ReadStrIni

function Hook_WriteStrIni (Value, Key, SectionName, FileName: myPChar): integer; cdecl;
begin
  result  :=  0;
  
  if Ini.WriteStrToIni(Key, Value, SectionName, FileName) then begin
    Ini.SaveIni(FileName);
  end;
end;

function Hook_WriteIntIni (Value: integer; Key, SectionName, FileName: myPChar): integer; cdecl;
begin
  result  :=  0;

  if Ini.WriteStrToIni(Key, Legacy.IntToStr(Value), SectionName, FileName) then begin
    Ini.SaveIni(FileName);
  end;
end;

function Hook_ZvsGetWindowWidth (Context: Core.PHookContext): longbool; stdcall;
begin
  Context.ECX :=  WndManagerPtr^.ScreenPcx16.Width;
  result      :=  not Core.EXEC_DEF_CODE;
end;

function Hook_ZvsGetWindowHeight (Context: Core.PHookContext): longbool; stdcall;
begin
  Context.EDX :=  WndManagerPtr^.ScreenPcx16.Height;
  result      :=  not Core.EXEC_DEF_CODE;
end;

procedure MarkFreshestSavegame;
var
{O} Locator:          Files.TFileLocator;
{O} FileInfo:         Files.TFileItemInfo;
    FileName:         myAStr;
    FreshestTime:     INT64;
    FreshestFileName: myAStr;
  
begin
  Locator   :=  Files.TFileLocator.Create;
  FileInfo  :=  nil;
  // * * * * * //
  FreshestFileName  :=  #0;
  FreshestTime      :=  0;
  
  Locator.DirPath   :=  'Games';
  Locator.InitSearch('*.*');
  
  while Locator.NotEnd do begin
    FileName  :=  Locator.GetNextItem(CFiles.TItemInfo(FileInfo));
    
    if
      ((FileInfo.Data.dwFileAttributes and Windows.FILE_ATTRIBUTE_DIRECTORY) = 0) and
      (INT64(FileInfo.Data.ftLastWriteTime) > FreshestTime)
    then begin
      FreshestFileName  :=  FileName;
      FreshestTime      :=  INT64(FileInfo.Data.ftLastWriteTime);
    end;
    Legacy.FreeAndNil(FileInfo);
  end; // .while
  
  Locator.FinitSearch;
  
  UtilsB2.CopyMem(Length(FreshestFileName) + 1, pointer(FreshestFileName), Heroes.MarkedSavegame);
  // * * * * * //
  Legacy.FreeAndNil(Locator);
end; // .procedure MarkFreshestSavegame

function Hook_SetHotseatHeroName (Context: Core.PHookContext): longbool; stdcall;
var
  PlayerName:     myAStr;
  NewPlayerName:  myAStr;
  EcxReg:         integer;

begin
  PlayerName    :=  myPChar(Context.EAX);
  NewPlayerName :=  PlayerName + ' 1';
  EcxReg        :=  Context.ECX;
  
  asm
    MOV ECX, EcxReg
    PUSH NewPlayerName
    MOV EDX, [ECX]
    CALL [EDX + $34]
  end; // .asm
  
  NewPlayerName :=  PlayerName + ' 2';
  EcxReg        :=  Context.EBX;
  
  asm
    MOV ECX, EcxReg
    MOV ECX, [ECX + $54]
    PUSH NewPlayerName
    MOV EDX, [ECX]
    CALL [EDX + $34]
  end; // .asm
  
  result := not Core.EXEC_DEF_CODE;
end; // .function Hook_SetHotseatHeroName

function Hook_PeekMessageA (Context: Core.PHookContext): longbool; stdcall;
begin
  Inc(CpuPatchCounter, CpuTargetLevel);

  if CpuPatchCounter >= 100 then begin
    Dec(CpuPatchCounter, 100);
  end else begin
    Windows.WaitForSingleObject(hTimerEvent, 1);
  end;

  result := Core.EXEC_DEF_CODE;
end;

function New_Zvslib_GetPrivateProfileStringA
(
  Section:  myPChar;
  Key:      myPChar;
  DefValue: myPChar;
  Buf:      myPChar;
  BufSize:  integer;
  FileName: myPChar
): integer; stdcall;
  
var
  Res:  myAStr;

begin
  Res :=  '';

  if not Ini.ReadStrFromIni(Key, Section, FileName, Res) then begin
    Res :=  DefValue;
  end;
  
  if BufSize <= Length(Res) then begin
    SetLength(Res, BufSize - 1);
  end;
  
  UtilsB2.CopyMem(Length(Res) + 1, myPChar(Res), Buf);
  
  result :=  Length(Res) + 1;
end; // .function New_Zvslib_GetPrivateProfileStringA

procedure ReadGameSettings;
var
  GameSettingsFilePath: myAStr;

  function ReadValue (const Key: myAStr; const DefVal: myAStr = ''): myAStr;
  begin
    if Ini.ReadStrFromIni(Key, Heroes.GAME_SETTINGS_SECTION, GameSettingsFilePath, result) then begin
      result := Legacy.Trim(result);
    end else begin
      result := DefVal;
    end;
  end;

  procedure ReadInt (const Key: myAStr; Res: PINTEGER);
  var
    Value:    integer;
     
  begin
    if Legacy.TryStrToInt(ReadValue(Key, '0'), Value) then begin
      Res^  :=  Value;
    end else begin
      Res^ := 0;
    end;
  end;

  procedure ReadStr (const Key: myAStr; Res: myPChar);
  var
    StrValue: myAStr;
     
  begin
    StrValue := ReadValue(Key, '');
    UtilsB2.CopyMem(Length(StrValue) + 1, myPChar(StrValue), Res);
  end;
  
const
  UNIQUE_ID_LEN   = 3;
  UNIQUE_ID_MASK  = $FFF;

var
  RandomValue:  integer;
  RandomStr:    myAStr;
  i:            integer;
   
begin
  asm
    MOV EAX, Heroes.LOAD_DEF_SETTINGS
    CALL EAX
  end;

  GameSettingsFilePath := GameExt.GameDir + '\' + Heroes.GAME_SETTINGS_FILE;

  ReadInt('Show Intro',             Heroes.SHOW_INTRO_OPT);
  ReadInt('Music Volume',           Heroes.MUSIC_VOLUME_OPT);
  ReadInt('Sound Volume',           Heroes.SOUND_VOLUME_OPT);
  ReadInt('Last Music Volume',      Heroes.LAST_MUSIC_VOLUME_OPT);
  ReadInt('Last Sound Volume',      Heroes.LAST_SOUND_VOLUME_OPT);
  ReadInt('Walk Speed',             Heroes.WALK_SPEED_OPT);
  ReadInt('Computer Walk Speed',    Heroes.COMP_WALK_SPEED_OPT);
  ReadInt('Show Route',             Heroes.SHOW_ROUTE_OPT);
  ReadInt('Move Reminder',          Heroes.MOVE_REMINDER_OPT);
  ReadInt('Quick Combat',           Heroes.QUICK_COMBAT_OPT);
  ReadInt('Video Subtitles',        Heroes.VIDEO_SUBTITLES_OPT);
  ReadInt('Town Outlines',          Heroes.TOWN_OUTLINES_OPT);
  ReadInt('Animate SpellBook',      Heroes.ANIMATE_SPELLBOOK_OPT);
  ReadInt('Window Scroll Speed',    Heroes.WINDOW_SCROLL_SPEED_OPT);
  ReadInt('Bink Video',             Heroes.BINK_VIDEO_OPT);
  ReadInt('Blackout Computer',      Heroes.BLACKOUT_COMPUTER_OPT);
  ReadInt('First Time',             Heroes.FIRST_TIME_OPT);
  ReadInt('Test Decomp',            Heroes.TEST_DECOMP_OPT);
  ReadInt('Test Read',              Heroes.TEST_READ_OPT);
  ReadInt('Test Blit',              Heroes.TEST_BLIT_OPT);
  ReadStr('Unique System ID',       Heroes.UNIQUE_SYSTEM_ID_OPT);
  
  if Heroes.UNIQUE_SYSTEM_ID_OPT^ = #0 then begin
    Randomize;
    RandomValue :=  (integer(Windows.GetTickCount) + Random(MAXLONGINT)) and UNIQUE_ID_MASK;
    SetLength(RandomStr, UNIQUE_ID_LEN);
    
    for i:=1 to UNIQUE_ID_LEN do begin
      RandomStr[i]  :=  Legacy.UpCase(StrLib.ByteToHexChar(RandomValue and $F));
      RandomValue   :=  RandomValue shr 4;
    end;
    
    UtilsB2.CopyMem(Length(RandomStr) + 1, pointer(RandomStr), Heroes.UNIQUE_SYSTEM_ID_OPT);
    
    Ini.WriteStrToIni
    (
      'Unique System ID',
      RandomStr,
      Heroes.GAME_SETTINGS_SECTION,
      Heroes.GAME_SETTINGS_FILE
    );
    
    Ini.SaveIni(Heroes.GAME_SETTINGS_FILE);
  end; // .if
  
  ReadStr('Network default Name',   Heroes.NETWORK_DEF_NAME_OPT);
  ReadInt('Autosave',               Heroes.AUTOSAVE_OPT);
  ReadInt('Show Combat Grid',       Heroes.SHOW_COMBAT_GRID_OPT);
  ReadInt('Show Combat Mouse Hex',  Heroes.SHOW_COMBAT_MOUSE_HEX_OPT);
  ReadInt('Combat Shade Level',     Heroes.COMBAT_SHADE_LEVEL_OPT);
  ReadInt('Combat Army Info Level', Heroes.COMBAT_ARMY_INFO_LEVEL_OPT);
  ReadInt('Combat Auto Creatures',  Heroes.COMBAT_AUTO_CREATURES_OPT);
  ReadInt('Combat Auto Spells',     Heroes.COMBAT_AUTO_SPELLS_OPT);
  ReadInt('Combat Catapult',        Heroes.COMBAT_CATAPULT_OPT);
  ReadInt('Combat Ballista',        Heroes.COMBAT_BALLISTA_OPT);
  ReadInt('Combat First Aid Tent',  Heroes.COMBAT_FIRST_AID_TENT_OPT);
  ReadInt('Combat Speed',           Heroes.COMBAT_SPEED_OPT);
  ReadInt('Main Game Show Menu',    Heroes.MAIN_GAME_SHOW_MENU_OPT);
  ReadInt('Main Game X',            Heroes.MAIN_GAME_X_OPT);
  ReadInt('Main Game Y',            Heroes.MAIN_GAME_Y_OPT);
  ReadInt('Main Game Full Screen',  Heroes.MAIN_GAME_FULL_SCREEN_OPT);
  ReadStr('AppPath',                Heroes.APP_PATH_OPT);
  ReadStr('CDDrive',                Heroes.CD_DRIVE_OPT);
end; // .procedure ReadGameSettings

procedure WriteGameSettings;
  procedure WriteInt (const Key: myAStr; Value: PINTEGER);
  begin
    Ini.WriteStrToIni
    (
      Key,
      Legacy.IntToStr(Value^),
      Heroes.GAME_SETTINGS_SECTION,
      Heroes.GAME_SETTINGS_FILE
    );
  end;
  
  procedure WriteStr (const Key: myAStr; Value: myPChar);
  begin
    Ini.WriteStrToIni
    (
      Key,
      Value,
      Heroes.GAME_SETTINGS_SECTION,
      Heroes.GAME_SETTINGS_FILE
    );
  end;
   
begin
  WriteInt('Show Intro',             Heroes.SHOW_INTRO_OPT);
  WriteInt('Music Volume',           Heroes.MUSIC_VOLUME_OPT);
  WriteInt('Sound Volume',           Heroes.SOUND_VOLUME_OPT);
  WriteInt('Last Music Volume',      Heroes.LAST_MUSIC_VOLUME_OPT);
  WriteInt('Last Sound Volume',      Heroes.LAST_SOUND_VOLUME_OPT);
  WriteInt('Walk Speed',             Heroes.WALK_SPEED_OPT);
  WriteInt('Computer Walk Speed',    Heroes.COMP_WALK_SPEED_OPT);
  WriteInt('Show Route',             Heroes.SHOW_ROUTE_OPT);
  WriteInt('Move Reminder',          Heroes.MOVE_REMINDER_OPT);
  WriteInt('Quick Combat',           Heroes.QUICK_COMBAT_OPT);
  WriteInt('Video Subtitles',        Heroes.VIDEO_SUBTITLES_OPT);
  WriteInt('Town Outlines',          Heroes.TOWN_OUTLINES_OPT);
  WriteInt('Animate SpellBook',      Heroes.ANIMATE_SPELLBOOK_OPT);
  WriteInt('Window Scroll Speed',    Heroes.WINDOW_SCROLL_SPEED_OPT);
  WriteInt('Bink Video',             Heroes.BINK_VIDEO_OPT);
  WriteInt('Blackout Computer',      Heroes.BLACKOUT_COMPUTER_OPT);
  WriteInt('First Time',             Heroes.FIRST_TIME_OPT);
  WriteInt('Test Decomp',            Heroes.TEST_DECOMP_OPT);
  WriteInt('Test Write',             Heroes.TEST_READ_OPT);
  WriteInt('Test Blit',              Heroes.TEST_BLIT_OPT);
  WriteStr('Unique System ID',       Heroes.UNIQUE_SYSTEM_ID_OPT);
  WriteStr('Network default Name',   Heroes.NETWORK_DEF_NAME_OPT);
  WriteInt('Autosave',               Heroes.AUTOSAVE_OPT);
  WriteInt('Show Combat Grid',       Heroes.SHOW_COMBAT_GRID_OPT);
  WriteInt('Show Combat Mouse Hex',  Heroes.SHOW_COMBAT_MOUSE_HEX_OPT);
  WriteInt('Combat Shade Level',     Heroes.COMBAT_SHADE_LEVEL_OPT);
  WriteInt('Combat Army Info Level', Heroes.COMBAT_ARMY_INFO_LEVEL_OPT);
  WriteInt('Combat Auto Creatures',  Heroes.COMBAT_AUTO_CREATURES_OPT);
  WriteInt('Combat Auto Spells',     Heroes.COMBAT_AUTO_SPELLS_OPT);
  WriteInt('Combat Catapult',        Heroes.COMBAT_CATAPULT_OPT);
  WriteInt('Combat Ballista',        Heroes.COMBAT_BALLISTA_OPT);
  WriteInt('Combat First Aid Tent',  Heroes.COMBAT_FIRST_AID_TENT_OPT);
  WriteInt('Combat Speed',           Heroes.COMBAT_SPEED_OPT);
  WriteInt('Main Game Show Menu',    Heroes.MAIN_GAME_SHOW_MENU_OPT);
  WriteInt('Main Game X',            Heroes.MAIN_GAME_X_OPT);
  WriteInt('Main Game Y',            Heroes.MAIN_GAME_Y_OPT);
  WriteInt('Main Game Full Screen',  Heroes.MAIN_GAME_FULL_SCREEN_OPT);
  WriteStr('AppPath',                Heroes.APP_PATH_OPT);
  WriteStr('CDDrive',                Heroes.CD_DRIVE_OPT);
  
  Ini.SaveIni(Heroes.GAME_SETTINGS_FILE);
end; // .procedure WriteGameSettings

function Hook_GetHostByName (Hook: PatchApi.THiHook; Name: myPChar): WinSock.PHostEnt; stdcall;
type
  PEndlessPIntArr = ^TEndlessPIntArr;
  TEndlessPIntArr = array [0..MAXLONGINT div 4 - 1] of PINTEGER;
  
var
{U} HostEnt:  WinSock.PHostEnt;
{U} Addrs:    PEndlessPIntArr;
    i:        integer;

  function IsLocalAddr (Addr: integer): boolean;
  type
    TInt32 = packed array [0..3] of byte;
  
  begin
    result := (TInt32(Addr)[0] = 10) or ((TInt32(Addr)[0] = 172) and Math.InRange(TInt32(Addr)[1],
                                                                                  16, 31)) or
                                        ((TInt32(Addr)[0] = 192) and (TInt32(Addr)[1] = 168));
  end;
    
begin
  {!} Windows.EnterCriticalSection(InetCriticalSection);
  
  result := Ptr(PatchApi.Call(PatchApi.STDCALL_, Hook.GetDefaultFunc(), [Name]));
  HostEnt := result;
  
  if HostEnt.h_length = sizeof(integer) then begin
    Addrs := pointer(HostEnt.h_addr_list);
    
    if (Addrs[0] <> nil) and IsLocalAddr(Addrs[0]^) then begin
      i := 1;

      while (Addrs[i] <> nil) and IsLocalAddr(Addrs[i]^) do begin
        Inc(i);
      end;

      if Addrs[i] <> nil then begin
        UtilsB2.Exchange(Addrs[0]^, Addrs[i]^);
      end;
    end; // .if
  end; // .if
  
  {!} Windows.LeaveCriticalSection(InetCriticalSection);
end; // .function Hook_GetHostByName

function Hook_ApplyDamage_Ebx (Context: Core.PHookContext): longbool; stdcall;
begin
  Context.EBX := ZvsAppliedDamage^;
  result      := Core.EXEC_DEF_CODE;
end;

function Hook_ApplyDamage_Esi (Context: Core.PHookContext): longbool; stdcall;
begin
  Context.ESI := ZvsAppliedDamage^;
  result      := Core.EXEC_DEF_CODE;
end;

function Hook_ApplyDamage_Esi_Arg1 (Context: Core.PHookContext): longbool; stdcall;
begin
  Context.ESI                 := ZvsAppliedDamage^;
  pinteger(Context.EBP + $8)^ := ZvsAppliedDamage^;
  result                      := Core.EXEC_DEF_CODE;
end;

function Hook_ApplyDamage_Arg1 (Context: Core.PHookContext): longbool; stdcall;
begin
  pinteger(Context.EBP + $8)^ :=  ZvsAppliedDamage^;
  result                      :=  Core.EXEC_DEF_CODE;
end;

function Hook_ApplyDamage_Ebx_Local7 (Context: Core.PHookContext): longbool; stdcall;
begin
  Context.EBX                    := ZvsAppliedDamage^;
  PINTEGER(Context.EBP - 7 * 4)^ := ZvsAppliedDamage^;
  result                         := Core.EXEC_DEF_CODE;
end;

function Hook_ApplyDamage_Local7 (Context: Core.PHookContext): longbool; stdcall;
begin
  PINTEGER(Context.EBP - 7 * 4)^ := ZvsAppliedDamage^;
  result                         := Core.EXEC_DEF_CODE;
end;

function Hook_ApplyDamage_Local4 (Context: Core.PHookContext): longbool; stdcall;
begin
  PINTEGER(Context.EBP - 4 * 4)^ := ZvsAppliedDamage^;
  result                         := Core.EXEC_DEF_CODE;
end;

function Hook_ApplyDamage_Local8 (Context: Core.PHookContext): longbool; stdcall;
begin
  PINTEGER(Context.EBP - 8 * 4)^ := ZvsAppliedDamage^;
  result                         := Core.EXEC_DEF_CODE;
end;

function Hook_ApplyDamage_Local13 (Context: Core.PHookContext): longbool; stdcall;
begin
  PINTEGER(Context.EBP - 13 * 4)^ := ZvsAppliedDamage^;
  result                          := Core.EXEC_DEF_CODE;
end;

function Hook_GetWoGAndErmVersions (Context: Core.PHookContext): longbool; stdcall;
const
  NEW_WOG_VERSION = 400;
  
begin
  PINTEGER(Context.EBP - $0C)^ := NEW_WOG_VERSION;
  PINTEGER(Context.EBP - $24)^ := GameExt.ERA_VERSION_INT;
  result                       := not Core.EXEC_DEF_CODE;
end;

function Hook_ZvsLib_ExtractDef (Context: Core.PHookContext): longbool; stdcall;
const
  MIN_NUM_TOKENS = 2;
  TOKEN_LODNAME  = 0;
  TOKEN_DEFNAME  = 1;
  
  EBP_ARG_IMAGE_TEMPLATE = 16;

var
  ImageSettings: myAStr;
  Tokens:        StrLib.TArrayOfStr;
  LodName:       myAStr;
  
begin
  ImageSettings := PPAnsiChar(Context.EBP + EBP_ARG_IMAGE_TEMPLATE)^;
  Tokens        := StrLib.Explode(ImageSettings, ';');

  if
    (Length(Tokens) >= MIN_NUM_TOKENS)  and
    (FindFileLod(Tokens[TOKEN_DEFNAME], LodName))
  then begin
    Tokens[TOKEN_LODNAME] := Legacy.ExtractFileName(LodName);
    ZvsLibImageTemplate   := StrLib.Join(Tokens, ';');
    PPAnsiChar(Context.EBP + EBP_ARG_IMAGE_TEMPLATE)^ :=  myPChar(ZvsLibImageTemplate);
  end;
  
  //fatalerror(myPPChar(Context.EBP + EBP_ARG_IMAGE_TEMPLATE)^);
  
  result  :=  Core.EXEC_DEF_CODE;
end; // .function Hook_ZvsLib_ExtractDef

function Hook_ZvsLib_ExtractDef_GetGamePath (Context: Core.PHookContext): longbool; stdcall;
const
  EBP_LOCAL_GAME_PATH = 16;

begin
  ZvsLibGamePath := Legacy.ExtractFileDir(myAStr(ParamStr(0)));
  {!} Assert(Length(ZvsLibGamePath) > 0);
  // Increase string ref count for C++ Builder string
  Inc(PINTEGER(UtilsB2.PtrOfs(pointer(ZvsLibGamePath), -8))^);

  PPAnsiChar(Context.EBP - EBP_LOCAL_GAME_PATH)^ :=  myPChar(ZvsLibGamePath);
  Context.RetAddr := UtilsB2.PtrOfs(Context.RetAddr, 486);
  result          := not Core.EXEC_DEF_CODE;
end; // .function Hook_ZvsLib_ExtractDef_GetGamePath

function Hook_ZvsPlaceMapObject (Hook: PatchApi.THiHook; x, y, Level, ObjType, ObjSubtype, ObjType2, ObjSubtype2, Terrain: integer): integer; stdcall;
begin
  if IsLocalPlaceObject then begin
    Erm.FireRemoteErmEvent(Erm.TRIGGER_ONREMOTEEVENT, [Erm.REMOTE_EVENT_PLACE_OBJECT, x, y, Level, ObjType, ObjSubtype, ObjType2, ObjSubtype2, Terrain]);
  end;

  result := PatchApi.Call(PatchApi.CDECL_, Hook.GetOriginalFunc(), [x, y, Level, ObjType, ObjSubtype, ObjType2, ObjSubtype2, Terrain]);
end;

procedure OnRemoteMapObjectPlace (Event: GameExt.PEvent); stdcall;
begin
  // Switch Network event
  case Erm.x[1] of
    Erm.REMOTE_EVENT_PLACE_OBJECT: begin
      IsLocalPlaceObject := false;
      Erm.ZvsPlaceMapObject(Erm.x[2], Erm.x[3], Erm.x[4], Erm.x[5], Erm.x[6], Erm.x[7], Erm.x[8], Erm.x[9]);
      IsLocalPlaceObject := true;
    end;
  end;
end; // .procedure OnRemoteMapObjectPlace

function Hook_ZvsEnter2Monster (Context: Core.PHookContext): longbool; stdcall;
const
  ARG_MAP_ITEM  = 8;
  ARG_MIXED_POS = 16;

var
  x, y, z:  integer;
  MixedPos: integer;
  MapItem:  pointer;

begin
  MapItem  := ppointer(Context.EBP + ARG_MAP_ITEM)^;
  MapItemToCoords(MapItem, x, y, z);
  MixedPos := CoordsToMixedPos(x, y, z);
  pinteger(Context.EBP + ARG_MIXED_POS)^ := MixedPos;

  Context.RetAddr := Ptr($7577B2);
  result          := not Core.EXEC_DEF_CODE;
end; // .function Hook_ZvsEnter2Monster

function Hook_ZvsEnter2Monster2 (Context: Core.PHookContext): longbool; stdcall;
const
  ARG_MAP_ITEM  = 8;
  ARG_MIXED_POS = 16;

var
  x, y, z:  integer;
  MixedPos: integer;
  MapItem:  pointer;

begin
  MapItem  := ppointer(Context.EBP + ARG_MAP_ITEM)^;
  MapItemToCoords(MapItem, x, y, z);
  MixedPos := CoordsToMixedPos(x, y, z);
  pinteger(Context.EBP + ARG_MIXED_POS)^ := MixedPos;

  Context.RetAddr := Ptr($757A87);
  result          := not Core.EXEC_DEF_CODE;
end; // .function Hook_ZvsEnter2Monster2

function Hook_StartBattle (OrigFunc: pointer; AdvMan: Heroes.PAdvManager; PackedCoords: integer; AttackerHero: Heroes.PHero; AttackerArmy: Heroes.PArmy; DefenderPlayerId: integer;
                           DefenderTown: Heroes.PTown; DefenderHero: Heroes.PHero; DefenderArmy: Heroes.PArmy; Seed, Unk10: integer; IsBank: boolean): integer; stdcall;

const
  DEFAULT_COMBAT_ID = -1359960668;

var
  AttackerPlayerId: integer;

begin
  HadTacticsPhase := false;
  CombatRound     := FIRST_TACTICS_ROUND;
  CombatActionId  := 0;
  GlobalRng       := QualitativeRng;

  AttackerPlayerId := Heroes.PLAYER_NONE;

  if AttackerHero <> nil then begin
    AttackerPlayerId := AttackerHero.Owner;
  end;

  if Heroes.IsNetworkGame and
     Heroes.IsValidPlayerId(AttackerPlayerId) and
     Heroes.IsValidPlayerId(DefenderPlayerId) and
     Heroes.GetPlayer(AttackerPlayerId).IsHuman and
     Heroes.GetPlayer(DefenderPlayerId).IsHuman
  then begin
    GlobalRng := BattleDeterministicRng;

    // If we are network defender, the attacker already sent CombatId to us. Otherwise we should generate it and send later
    if not Heroes.GetPlayer(DefenderPlayerId).IsThisPcHumanPlayer then begin
      CombatId := Erm.UniqueRng.Random;
    end;
  end else begin
    CombatId := DEFAULT_COMBAT_ID;
  end;

  result    := PatchApi.Call(THISCALL_, OrigFunc, [AdvMan, PackedCoords, AttackerHero, AttackerArmy, DefenderPlayerId, DefenderTown, DefenderHero, DefenderArmy, Seed, Unk10, IsBank]);
  GlobalRng := QualitativeRng;
end; // .function Hook_StartBattle

function Hook_OnBeforeBattlefieldVisible (Context: Core.PHookContext): longbool; stdcall;
begin
  Erm.FireErmEvent(Erm.TRIGGER_ONBEFORE_BATTLEFIELD_VISIBLE);
  result := Core.EXEC_DEF_CODE;
end;

function Hook_OnBattlefieldVisible (Context: Core.PHookContext): longbool; stdcall;
begin
  HadTacticsPhase := Heroes.CombatManagerPtr^.IsTactics;

  if not HadTacticsPhase then begin
    CombatRound        := 0;
    pinteger($79F0B8)^ := 0;
    pinteger($79F0BC)^ := 0;
  end;

  Erm.FireErmEvent(Erm.TRIGGER_BATTLEFIELD_VISIBLE);
  Erm.v[997] := CombatRound;
  Erm.FireErmEventEx(Erm.TRIGGER_BR, [CombatRound]);

  result := true;
end;

function Hook_OnAfterTacticsPhase (Context: Core.PHookContext): longbool; stdcall;
begin
  Erm.FireErmEvent(Erm.TRIGGER_AFTER_TACTICS_PHASE);

  if HadTacticsPhase then begin
    CombatRound := 0;
    Erm.v[997]  := CombatRound;
    Erm.FireErmEvent(Erm.TRIGGER_BR);
  end;

  result := Core.EXEC_DEF_CODE;
end;

function Hook_OnCombatRound_Start (Context: Core.PHookContext): longbool; stdcall;
begin
  if pinteger($79F0B8)^ <> Heroes.CombatManagerPtr^.Round then begin
    Inc(CombatRound);
  end;

  result := Core.EXEC_DEF_CODE;
end;

function Hook_OnCombatRound_End (Context: Core.PHookContext): longbool; stdcall;
begin
  Erm.v[997] := CombatRound;
  Erm.FireErmEvent(Erm.TRIGGER_BR);
  result := Core.EXEC_DEF_CODE;
end;

var
  RngId: integer = 0; // Holds random generation attempt ID, auto resets at each reseeding. Used for debugging purposes

procedure OnBeforeBattleAction (Event: GameExt.PEvent); stdcall;
begin
  Inc(CombatActionId);
end;

procedure Hook_SRand (OrigFunc: pointer; Seed: integer); stdcall;
var
  CallerAddr: pointer;
  Msg:        myAStr;

begin
  asm
    mov eax, [ebp + 4]
    mov CallerAddr, eax
  end;

  GlobalRng.Seed(Seed);

  if (DebugRng <> DEBUG_RNG_NONE) and (Heroes.WndManagerPtr^ <> nil) and (Heroes.WndManagerPtr^.RootDlg <> nil) then begin
    Msg := Legacy.Format('SRand %d from %.8x', [Seed, integer(CallerAddr)]);
    Writeln(Msg);
    Heroes.PrintChatMsg('{~ffffff}' + Msg);
  end;

  RngId := 0;
end;

procedure Hook_Tracking_SRand (OrigFunc: pointer; Seed: integer); stdcall;
var
  CallerAddr: pointer;
  Msg:        myAStr;

begin
  asm
    mov eax, [ebp + 4]
    mov CallerAddr, eax
  end;

  GlobalRng.Seed(Seed);
  NativeRngSeed^ := Seed;

  if (DebugRng <> DEBUG_RNG_NONE) and (Heroes.WndManagerPtr^ <> nil) and (Heroes.WndManagerPtr^.RootDlg <> nil) then begin
    Msg := Legacy.Format('SRand %d from %.8x', [Seed, integer(CallerAddr)]);
    Writeln(Msg);
    Heroes.PrintChatMsg('{~ffffff}' + Msg);
  end;

  RngId := 0;
end;

function Hook_Rand (OrigFunc: pointer): integer; stdcall;
var
  CallerAddr: pointer;
  Msg:        myAStr;

begin
  asm
    mov eax, [ebp + 4]
    mov CallerAddr, eax
  end;

  result := GlobalRng.Random and $7FFF;

  if (DebugRng = DEBUG_RNG_ALL) and (Heroes.WndManagerPtr^ <> nil) and (Heroes.WndManagerPtr^.RootDlg <> nil) then begin
    if GlobalRng = BattleDeterministicRng then begin
      Msg := Legacy.Format('brng rand #%d from %.8x, B%d R%d A%d = %d', [RngId, integer(CallerAddr), CombatId, CombatRound, CombatActionId, result]);
    end else begin
      Msg := 'qrng ';

      if GlobalRng = CLangRng then begin
        Msg := 'crng ';
      end;

      Msg := Msg + Legacy.Format('rand #%d from %.8x = %d', [RngId, integer(CallerAddr), result]);
    end;

    Writeln(Msg);
    PrintChatMsg('{~ffffff}' + Msg);
  end;

  Inc(RngId);
end;

procedure DebugRandomRange (CallerAddr: pointer; MinValue, MaxValue, ResValue: integer);
var
  Msg:        myAStr;

begin
  if DebugRng >= DEBUG_RNG_RANGE then begin
    if GlobalRng = BattleDeterministicRng then begin
      Msg := Legacy.Format('brng rand #%d from %.8x, B%d  R%d A%d F%d: %d..%d = %d', [
        RngId, integer(CallerAddr), CombatId, CombatRound, CombatActionId, CombatRngFreeParam, MinValue, MaxValue, ResValue
      ]);
    end else begin
      Msg := 'qrng ';

      if GlobalRng = CLangRng then begin
        Msg := 'crng ';
      end;

      Msg := Msg + Legacy.Format('rand #%d from %.8x: %d..%d = %d', [RngId, integer(CallerAddr), MinValue, MaxValue, ResValue]);
    end;

    Writeln(Msg);
    PrintChatMsg('{~ffffff}' + Msg);
  end;

  Inc(RngId);
end;

function _RandomRangeWithFreeParam (CallerAddr: pointer; MinValue, MaxValue, FreeParam: integer): integer;
begin
  CombatRngFreeParam := FreeParam;
  result             := GlobalRng.RandomRange(MinValue, MaxValue);
  DebugRandomRange(CallerAddr, MinValue, MaxValue, result);
  CombatRngFreeParam := 0;
end;

function RandomRangeWithFreeParam (MinValue, MaxValue, FreeParam: integer): integer; stdcall;
var
  CallerAddr: pointer;

begin
  asm
    mov eax, [ebp + 4]
    mov CallerAddr, eax
  end;

  result := _RandomRangeWithFreeParam(CallerAddr, MinValue, MaxValue, FreeParam);
end;

function Hook_RandomRange (OrigFunc: pointer; MinValue, MaxValue: integer): integer; stdcall;
type
  PCallerContext = ^TCallerContext;
  TCallerContext = packed record EDI, ESI, EBP, ESP, EBX, EDX, ECX, EAX: integer; end;

const
  CALLER_CONTEXT_SIZE = sizeof(TCallerContext);

var
  CallerAddr: pointer;
  Context:    PCallerContext;
  CallerEbp:  integer;
  FreeParam:  integer;

begin
  asm
    mov eax, [ebp + 4]
    mov CallerAddr, eax
    pushad
    mov [Context], esp
  end;

  CallerEbp := pinteger(Context.EBP)^;
  FreeParam := 0;

  case integer(CallerAddr) of
    // Battle stack damage generation
    $442FEE, $443029: FreeParam := pinteger(CallerEbp + $8)^;
    // Bad morale
    $4647AC, $4647D5: FreeParam := StackPtrToId(Ptr(Context.EDI));
    // Magic resistence
    $5A65A3, $5A4D85, $5A061B, $5A1017, $5A1214: FreeParam := StackPtrToId(Ptr(Context.EDI));
    $5A4F5F:                                     FreeParam := StackPtrToId(Ptr(Context.ESI));
    $5A2105:                                     FreeParam := StackPtrToId(ppointer(CallerEbp + $14)^);
  end;

  result := _RandomRangeWithFreeParam(CallerAddr, MinValue, MaxValue, FreeParam);

  asm
    add esp, CALLER_CONTEXT_SIZE
  end;
end; // .function Hook_RandomRange

function Hook_PlaceBattleObstacles (OrigFunc, BattleMgr: pointer): integer; stdcall;
var
  PrevRng: FastRand.TRng;

begin
  PrevRng   := GlobalRng;
  GlobalRng := CLangRng;

  Heroes.SRand(NativeRngSeed^);

  // Skip one random generation, because random battle music selection is already performed by this moment
  Heroes.RandomRange(0, 7);

  //Erm.FireErmEvent(Erm.TRIGGER_BEFORE_BATTLE_PLACE_BATTLE_OBSTACLES);
  result := PatchApi.Call(THISCALL_, OrigFunc, [BattleMgr]);

  GlobalRng := PrevRng;
  Erm.FireErmEvent(Erm.TRIGGER_AFTER_BATTLE_PLACE_BATTLE_OBSTACLES);
end;

function Hook_ZvsAdd2Send (Context: ApiJack.PHookContext): longbool; stdcall;
const
  BUF_ADDR    = $2846C60;
  DEST_PLAYER_ID_VAR_ADDR = $281187C;
  BUF_POS_VAR = -$0C;

type
  PWoGBattleSyncBuffer = ^TWoGBattleSyncBuffer;
  TWoGBattleSyncBuffer = array [0..103816 - 1] of byte;

var
  BufPosPtr: pinteger;

begin
  BufPosPtr := Ptr(Context.EBP + BUF_POS_VAR);

  // Write chunk size + chunk bytes, adjust buffer position
  pinteger(BUF_ADDR + BufPosPtr^)^ := sizeof(integer);
  Inc(BufPosPtr^, sizeof(integer));
  pinteger(BUF_ADDR + BufPosPtr^)^ := CombatId;
  Inc(BufPosPtr^, sizeof(integer));

  result := true;
end;

function Hook_ZvsGet4Receive (Context: ApiJack.PHookContext): longbool; stdcall;
const
  BUF_VAR     = +$8;
  BUF_POS_VAR = -$4;

var
  BufAddr:   integer;
  BufPosPtr: pinteger;

begin
  BufPosPtr := Ptr(Context.EBP + BUF_POS_VAR);
  BufAddr   := pinteger(Context.EBP + BUF_VAR)^;

  if pinteger(BufAddr + BufPosPtr^)^ <> sizeof(integer) then begin
    Heroes.ShowMessage('Hook_ZvsGet4Receive: Invalid data received from remote client');
  end else begin
    Inc(BufPosPtr^, sizeof(integer));
    CombatId := pinteger(BufAddr + BufPosPtr^)^;
    Inc(BufPosPtr^, sizeof(integer));
  end;

  result := true;
end;

procedure OnBeforeBattleUniversal (Event: GameExt.PEvent); stdcall;
begin
  CombatRound    := FIRST_TACTICS_ROUND;
  CombatActionId := 0;
end;

procedure OnBattleReplay (Event: GameExt.PEvent); stdcall;
begin
  OnBeforeBattleUniversal(Event);
  Erm.FireErmEvent(TRIGGER_BATTLE_REPLAY);
end;

procedure OnBeforeBattleReplay (Event: GameExt.PEvent); stdcall;
begin
  Erm.FireErmEvent(TRIGGER_BEFORE_BATTLE_REPLAY);
end;

procedure OnSavegameWrite (Event: PEvent); stdcall;
var
  RngState: array of byte;

begin
  SetLength(RngState, GlobalRng.GetStateSize);
  GlobalRng.ReadState(pointer(RngState));

  with Stores.NewRider(RNG_SAVE_SECTION) do begin
    WriteInt(Length(RngState));
    Write(Length(RngState), pointer(RngState));
  end;
end;

procedure OnSavegameRead (Event: PEvent); stdcall;
var
  RngState: array of byte;

begin
  with Stores.NewRider(RNG_SAVE_SECTION) do begin
    SetLength(RngState, ReadInt);

    if Length(RngState) = GlobalRng.GetStateSize then begin
      Read(Length(RngState), pointer(RngState));
      GlobalRng.WriteState(pointer(RngState));
    end;
  end;
end;

function Hook_PostBattle_OnAddCreaturesExp (Context: ApiJack.PHookContext): longbool; stdcall;
var
  ExpToAdd: integer;
  FinalExp: integer;

begin
  // EAX: Old experience value
  // EBP - $C: addition
  ExpToAdd := pinteger(Context.EBP - $C)^;

  if ExpToAdd < 0 then begin
    ExpToAdd := High(integer);
  end;

  FinalExp := Math.Max(0, Context.EAX) + ExpToAdd;

  if FinalExp < 0 then begin
    FinalExp := High(integer);
  end;

  ppinteger(Context.EBP - 8)^^ := FinalExp;

  Context.RetAddr := Ptr($71922D);
  result          := false;
end; // .function Hook_PostBattle_OnAddCreaturesExp

function Hook_DisplayComplexDialog_GetTimeout (Context: ApiJack.PHookContext): longbool; stdcall;
var
  Opts:          integer;
  Timeout:       integer;
  MsgType:       integer;
  TextAlignment: integer;
  StrConfig:     integer;

begin
  Opts          := pinteger(Context.EBP + $10)^;
  Timeout       := Opts and $FFFF;
  StrConfig     := (Opts shr 24) and $FF;
  MsgType       := (Opts shr 16) and $0F;
  TextAlignment := ((Opts shr 20) and $0F) - 1;

  if MsgType = 0 then begin
    MsgType := ord(Heroes.MES_MES);
  end;

  if TextAlignment < 0 then begin
    TextAlignment := Heroes.TEXT_ALIGN_CENTER;
  end;

  Erm.SetDialog8TextAlignment(TextAlignment);

  pinteger(Context.EBP - $24)^ := Timeout;
  pinteger(Context.EBP - $2C)^ := MsgType;
  pbyte(Context.EBP - $2C0)^   := StrConfig;
  result                       := true;
end; // .function Hook_DisplayComplexDialog_GetTimeout

function Hook_ShowParsedDlg8Items_CreateTextField (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  pinteger(Context.EBP - 132)^ := GetDialog8TextAlignment();
  result := true;
end;

function Hook_ShowParsedDlg8Items_Init (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  // WoG Native Dialogs uses imported function currently and manually determines selected item
  // Heroes.ComplexDlgResItemId^ := Erm.GetPreselectedDialog8ItemId();
  result := true;
end;

function Hook_ZvsDisplay8Dialog_BeforeShow (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  Context.EAX     := DisplayComplexDialog(ppointer(Context.EBP + $8)^, Ptr($8403BC), Heroes.TMesType(pinteger(Context.EBP + $10)^),
                                          pinteger(Context.EBP + $14)^);
  result          := false;
  Context.RetAddr := Ptr($716A04);
end;

const
  PARSE_PICTURE_VAR_SHOW_ZERO_QUANTITIES = -$C0;

function Hook_ParsePicture_Start (Context: ApiJack.PHookContext): longbool; stdcall;
const
  PIC_TYPE_ARG = +$8;

var
  PicType: integer;

begin
  PicType := pinteger(Context.EBP + PIC_TYPE_ARG)^;

  if PicType <> -1 then begin
    pinteger(Context.EBP + PARSE_PICTURE_VAR_SHOW_ZERO_QUANTITIES)^ := PicType shr 31;
    pinteger(Context.EBP + PIC_TYPE_ARG)^                           := PicType and not (1 shl 31);
  end else begin
    pinteger(Context.EBP + PARSE_PICTURE_VAR_SHOW_ZERO_QUANTITIES)^ := 0;
  end;

  (* Not ideal but still solution. Apply runtime patches to allow/disallow displaying of zero quantities *)
  if pinteger(Context.EBP + PARSE_PICTURE_VAR_SHOW_ZERO_QUANTITIES)^ <> 0 then begin
    pbyte($4F55EC)^ := $7C;   // resources
    pbyte($4F5EB3)^ := $EB;   // experience
    pword($4F5BCA)^ := $9090; // monsters
    pbyte($4F5ACC)^ := $EB;   // primary skills
    pbyte($4F5725)^ := $7C;   // money
    pbyte($4F5765)^ := $EB;   // money
  end else begin
    pbyte($4F55EC)^ := $7E;   // resources
    pbyte($4F5EB3)^ := $75;   // experience
    pword($4F5BCA)^ := $7A74; // monsters
    pbyte($4F5ACC)^ := $75;   // primary skills
    pbyte($4F5725)^ := $7E;   // money
    pbyte($4F5765)^ := $75;   // money
  end;

  result := true;
end; // .function Hook_ParsePicture_Start

function Hook_HDlg_BuildPcx (OrigFunc: pointer; x, y, dx, dy, ItemId: integer; PcxFile: myPChar; Flags: integer): pointer; stdcall;
const
  DLG_ITEM_STRUCT_SIZE = 52;

var
  FileName:       myAStr;
  FileExt:        myAStr;
  PcxConstructor: pointer;

begin
  FileName       := PcxFile;
  FileExt        := Legacy.AnsiLowerCase(StrLib.ExtractExt(FileName));
  PcxConstructor := Ptr($44FFA0);

  if FileExt = 'pcx16' then begin
    FileName       := Legacy.ChangeFileExt(FileName, '') + '.pcx';
    PcxConstructor := Ptr($450340);
  end;

  result := Ptr(PatchApi.Call(THISCALL_, PcxConstructor, [Heroes.MAlloc(DLG_ITEM_STRUCT_SIZE), x, y, dx, dy, ItemId, myPChar(FileName), Flags]));
end;

function Hook_HandleMonsterCast_End (Context: ApiJack.PHookContext): longbool; stdcall;
const
  CASTER_MON         = 1;
  NO_EXT_TARGET_POS  = -1;

  FIELD_ACTIVE_SPELL = $4E0;
  FIELD_NUM_MONS     = $4C;
  FIELD_MON_ID       = $34;

  MON_FAERIE_DRAGON   = 134;
  MON_SANTA_GREMLIN   = 173;
  MON_COMMANDER_FIRST = 174;
  MON_COMMANDER_LAST  = 191;

  WOG_GET_NPC_MAGIC_POWER = $76BEEA;

var
  Spell:      integer;
  TargetPos:  integer;
  Stack:      pointer;
  MonId:      integer;
  NumMons:    integer;
  SkillLevel: integer;
  SpellPower: integer;

begin
  TargetPos  := pinteger(Context.EBP + $8)^;
  Stack      := Ptr(Context.ESI);
  MonId      := pinteger(integer(Stack) + FIELD_MON_ID)^;
  Spell      := pinteger(integer(Stack) + FIELD_ACTIVE_SPELL)^;
  NumMons    := pinteger(integer(Stack) + FIELD_NUM_MONS)^;
  SpellPower := NumMons;
  SkillLevel := 2;

  if (TargetPos >= 0) and (TargetPos < 187) then begin
    if MonId = MON_FAERIE_DRAGON then begin
      SpellPower := NumMons * 5;
    end else if MonId = MON_SANTA_GREMLIN then begin
      SkillLevel := 0;
      SpellPower := (NumMons - 1) div 2;

      if (((NumMons - 1) and 1) <> 0) and (ZvsRandom(0, 1) = 1) then begin
        Inc(SpellPower);
      end;
    end else if Math.InRange(MonId, MON_COMMANDER_FIRST, MON_COMMANDER_LAST) then begin
      SpellPower := PatchApi.Call(CDECL_, Ptr(WOG_GET_NPC_MAGIC_POWER), [Stack]);
    end;

    Context.EAX := PatchApi.Call(THISCALL_, Ptr($5A0140), [Heroes.CombatManagerPtr^, Spell, TargetPos, CASTER_MON, NO_EXT_TARGET_POS, SkillLevel, SpellPower]);
  end;

  result          := false;
  Context.RetAddr := Ptr($4483DD);
end; // .function Hook_HandleMonsterCast_End

function Hook_ErmDlgFunctionActionSwitch (Context: ApiJack.PHookContext): longbool; stdcall;
const
  ARG_DLG_ID = 1;

  DLG_MOUSE_EVENT_INFO_VAR = $887654;
  DLG_USER_COMMAND_VAR     = $887658;
  DLG_BODY_VAR             = -$5C;
  DLG_BODY_ID_FIELD        = 200;
  DLG_COMMAND_CLOSE        = 1;
  MOUSE_OK_CLICK           = 10;
  MOUSE_LMB_PRESSED        = 12;
  MOUSE_LMB_RELEASED       = 13;
  MOUSE_RMB_PRESSED        = 14;
  ACTION_KEY_PRESSED       = 20;
  ITEM_INSIDE_DLG          = -1;
  ITEM_OUTSIDE_DLG         = -2;

var
  MouseEventInfo: Heroes.PMouseEventInfo;
  SavedEventX:    integer;
  SavedEventY:    integer;
  SavedEventZ:    integer;
  PrevUserCmd:    integer;

begin
  MouseEventInfo := ppointer(Context.EBP + $8)^;
  result         := false;

  case MouseEventInfo.ActionType of
    Heroes.DLG_ACTION_INDLG_CLICK:  begin end;
    Heroes.DLG_ACTION_SCROLL_WHEEL: begin MouseEventInfo.Item := ITEM_INSIDE_DLG; end;

    Heroes.DLG_ACTION_KEY_PRESSED: begin
      MouseEventInfo.Item := ITEM_INSIDE_DLG;
    end;

    Heroes.DLG_ACTION_OUTDLG_RMB_PRESSED: begin
      MouseEventInfo.Item          := ITEM_OUTSIDE_DLG;
      MouseEventInfo.ActionSubtype := MOUSE_RMB_PRESSED;
    end;

    Heroes.DLG_ACTION_OUTDLG_LMB_PRESSED: begin
      MouseEventInfo.Item          := ITEM_OUTSIDE_DLG;
      MouseEventInfo.ActionSubtype := MOUSE_LMB_PRESSED;
    end;

    Heroes.DLG_ACTION_OUTDLG_LMB_RELEASED: begin
      MouseEventInfo.Item          := ITEM_OUTSIDE_DLG;
      MouseEventInfo.ActionSubtype := MOUSE_LMB_RELEASED;
    end;
  else
    result := true;
  end; // .switch MouseEventInfo.ActionType

  if result then begin
    exit;
  end;

  ppointer(DLG_MOUSE_EVENT_INFO_VAR)^ := MouseEventInfo;

  SavedEventX := Erm.ZvsEventX^;
  SavedEventY := Erm.ZvsEventY^;
  SavedEventZ := Erm.ZvsEventZ^;
  PrevUserCmd := pinteger(DLG_USER_COMMAND_VAR)^;

  Erm.ArgXVars[ARG_DLG_ID] := pinteger(pinteger(Context.EBP + DLG_BODY_VAR)^ + DLG_BODY_ID_FIELD)^;

  Erm.ZvsEventX^ := Erm.ArgXVars[ARG_DLG_ID];
  Erm.ZvsEventY^ := MouseEventInfo.Item;
  Erm.ZvsEventZ^ := MouseEventInfo.ActionSubtype;

  pinteger(DLG_USER_COMMAND_VAR)^ := 0;
  Erm.FireMouseEvent(Erm.TRIGGER_DL, MouseEventInfo);

  Erm.ZvsEventX^ := SavedEventX;
  Erm.ZvsEventY^ := SavedEventY;
  Erm.ZvsEventZ^ := SavedEventZ;

  Context.EAX := 1;
  ppointer(DLG_MOUSE_EVENT_INFO_VAR)^ := nil;

  if pinteger(DLG_USER_COMMAND_VAR)^ = DLG_COMMAND_CLOSE then begin
    Context.EAX                     := 2;
    MouseEventInfo.ActionType       := Heroes.DLG_ACTION_INDLG_CLICK;
    MouseEventInfo.ActionSubtype    := MOUSE_OK_CLICK;

    // Assign result item
    pinteger(pinteger(Context.EBP - $10)^ + 56)^ := MouseEventInfo.Item;
  end;

  pinteger(DLG_USER_COMMAND_VAR)^ := PrevUserCmd;

  result          := false;
  Context.RetAddr := Ptr($7297C6);
end; // .function Hook_ErmDlgFunctionActionSwitch

const
  SET_DEF_ITEM_FRAME_INDEX_FUNC = $4EB0D0;
  HDLG_BUILD_DEF_FUNC           = $728DA1;
  HDLG_ADD_ITEM_FUNC            = $7287A1;
  HDLG_SET_ANIM_DEF_FUNC        = $7286A0;

type
  PAnimDefDlgItem = ^TAnimDefDlgItem;
  TAnimDefDlgItem = packed record
    _Unk1:    array [1..52] of byte;
    FrameInd: integer; // +0x34
    GroupInd: integer; // +0x38
    // ...
  end;

  PAnimatedDefWrapper = ^TAnimatedDefWrapper;
  TAnimatedDefWrapper = packed record
    ZvsDefFrameInd: integer;
    DefItem:        PAnimDefDlgItem;
  end;

function Hook_DL_D_ItemCreation (Context: ApiJack.PHookContext): longbool; stdcall;
var
  DefItem:  PAnimDefDlgItem;
  GroupInd: integer;
  FrameInd: integer;

begin
  DefItem  := ppointer(Context.EBP - $4)^;
  FrameInd := pinteger(Context.EBP - $44)^;
  GroupInd := 0;

  // DL frame index column is DL_GROUP_INDEX_MARKER * groupIndex + frameIndex
  if FrameInd >= DL_GROUP_INDEX_MARKER then begin
    GroupInd := FrameInd div DL_GROUP_INDEX_MARKER;
    FrameInd := FrameInd mod DL_GROUP_INDEX_MARKER;
  end;

  DefItem.GroupInd := GroupInd;

  PatchApi.Call(THISCALL_, Ptr(SET_DEF_ITEM_FRAME_INDEX_FUNC), [DefItem, FrameInd]);

  // Animated defs must contain 'animated' substring in name
  if Legacy.Pos('animated', myPPChar(Context.EBP - $74)^) <> 0 then begin
    PatchApi.Call(THISCALL_, Ptr(HDLG_SET_ANIM_DEF_FUNC), [pinteger(Context.EBP - $78)^, DefItem]);
  end;

  result := true;
end; // .function Hook_DL_D_ItemCreation

function Hook_ErmDlgFunction_HandleAnimatedDef (Context: ApiJack.PHookContext): longbool; stdcall;
var
  AnimatedDefWrapper: PAnimatedDefWrapper;
  AnimatedDefItem:    PAnimDefDlgItem;

begin
  AnimatedDefWrapper := ppointer(Context.EBP - $28)^;
  AnimatedDefItem    := AnimatedDefWrapper.DefItem;

  PatchApi.Call(THISCALL_, Ptr(SET_DEF_ITEM_FRAME_INDEX_FUNC), [AnimatedDefItem, AnimatedDefItem.FrameInd + 1]);

  result          := false;
  Context.RetAddr := Ptr($7294E8);
end; // .function Hook_ErmDlgFunction_HandleAnimatedDef

function Hook_OpenMainMenuVideo (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  if not Math.InRange(Heroes.a2i(myPChar(Trans.Tr('era.acredit_pos.x', []))), 0, 800 - 1) or
     not Math.InRange(Heroes.a2i(myPChar(Trans.Tr('era.acredit_pos.y', []))), 0, 600 - 1)
  then begin
    pinteger($699568)^ := Context.EAX;
    Context.RetAddr    := Ptr($4EEF07);
    result := false;
  end else begin
    result := true;
  end;
end;

function Hook_ShowMainMenuVideo (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  pinteger(Context.EBP - $0C)^ := Heroes.a2i(myPChar(Trans.Tr('era.acredit_pos.x', [])));
  pinteger(Context.EBP + $8)^  := Heroes.a2i(myPChar(Trans.Tr('era.acredit_pos.y', [])));

  result          := false;
  Context.RetAddr := Ptr($706630);
end;

function Hook_ZvsPlaceCreature_End (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  // Here we rely on the fact, that ZvsLeaveCreature is simple wrapper with pushad + extra data upon b_MsgBox (4F6C00)
  PatchApi.Call(FASTCALL_, Ptr($4F6C00), [pinteger(Context.EBP - $38)^, 4, pinteger(Context.EBP + 60)^, pinteger(Context.EBP + 64)^, -1, 0, -1, 0, -1, 0, -1, 0]);

  result          := false;
  Context.RetAddr := Ptr($7575B3);
end;

function Hook_Dlg_SendMsg (OrigFunc: pointer; Dlg: Heroes.PDlg; Msg: Heroes.PMouseEventInfo): integer; stdcall;
begin
  if
    (Msg.ActionType = DLG_ACTION_OUTDLG_LMB_PRESSED) or
    (Msg.ActionType = DLG_ACTION_OUTDLG_LMB_RELEASED) or
    (Msg.ActionType = DLG_ACTION_OUTDLG_RMB_PRESSED) or
    (Msg.ActionType = DLG_ACTION_OUTDLG_RMB_RELEASED) or
    (Msg.ActionType = DLG_ACTION_INDLG_CLICK)
  then begin
    DlgLastEvent := Msg^;
  end;

  result := PatchApi.Call(THISCALL_, OrigFunc, [Dlg, Msg]);
end;

function Hook_Show3PicDlg_PrepareDialogStruct (Context: ApiJack.PHookContext): longbool; stdcall;
type
  PDlgStruct = ^TDlgStruct;
  TDlgStruct = packed record
    _1: array [1..16] of byte;
    x:      integer;
    y:      integer;
    Width:  integer;
    Height: integer;
  end;

const
  FUNC_PREPARE_DLG_STRUCT = $4F6410;
  MIN_OFFSET_FROM_BORDERS = 8;
  STD_GAME_WIDTH          = 800;
  STD_GAME_HEIGHT         = 600;
  SMALLEST_DLG_HEIGHT     = 256;

var
  DlgStruct:   PDlgStruct;
  MessageType: integer;
  OrigX:       integer;
  OrigY:       integer;
  CurrDlgId:   integer;
  CurrDlg:     Heroes.PDlg;
  BoxRect:     TRect;
  ClickX:      integer;
  ClickY:      integer;

begin
  DlgStruct := Ptr(Context.ECX);
  OrigX     := DlgStruct.x;
  OrigY     := DlgStruct.y;

  PatchApi.Call(THISCALL_, Ptr(FUNC_PREPARE_DLG_STRUCT), [DlgStruct]);

  MessageType := pinteger(Context.EBP - $10)^;
  CurrDlgId   := Heroes.WndManagerPtr^.GetCurrentDlgId;

  if
    //(OrigX = -1) and (OrigY = -1) and
    (MessageType = ord(Heroes.MES_RMB_HINT))
  then begin
    CurrDlg := Heroes.WndManagerPtr^.CurrentDlg;
    ClickX  := DlgLastEvent.x;
    ClickY  := DlgLastEvent.y;
    BoxRect := Types.Bounds(0, 0, Heroes.ScreenWidth^, Heroes.ScreenHeight^);

    if CurrDlgId <> Heroes.ADVMAP_DLGID then begin
      BoxRect := Types.Bounds((Heroes.ScreenWidth^ - CurrDlg.Width) div 2, (Heroes.ScreenHeight^ - CurrDlg.Height) div 2, CurrDlg.Width, CurrDlg.Height);
    end;

    DlgStruct.x := ClickX - DlgStruct.Width div 2;

    if DlgStruct.x < (BoxRect.Left + MIN_OFFSET_FROM_BORDERS) then begin
      DlgStruct.x := (BoxRect.Left + MIN_OFFSET_FROM_BORDERS);
    end;

    if DlgStruct.x + DlgStruct.Width > BoxRect.Right then begin
      DlgStruct.x := BoxRect.Right - (DlgStruct.Width + MIN_OFFSET_FROM_BORDERS);
    end;

    if DlgStruct.x < BoxRect.Left then begin
      DlgStruct.x := (Heroes.ScreenWidth^ - DlgStruct.Width) div 2;
    end;

    // Center small dialogs vertically, show taller dialog 65 pixels above the cursor
    if DlgStruct.Height <= SMALLEST_DLG_HEIGHT then begin
      DlgStruct.y := ClickY - DlgStruct.Height div 2;
    end else begin
      DlgStruct.y := ClickY - 65;
    end;

    if DlgStruct.y < (BoxRect.Top + MIN_OFFSET_FROM_BORDERS) then begin
      DlgStruct.y := (BoxRect.Top + MIN_OFFSET_FROM_BORDERS);
    end;

    if DlgStruct.y + DlgStruct.Height > BoxRect.Bottom then begin
      DlgStruct.y := BoxRect.Bottom - (DlgStruct.Height + MIN_OFFSET_FROM_BORDERS);
    end;

    if DlgStruct.y < BoxRect.Top then begin
      DlgStruct.y := (Heroes.ScreenHeight^ - DlgStruct.Height) div 2;
    end;
  end;

  result          := false;
  Context.RetAddr := Ptr($4F6D59);
end; // .function Hook_Show3PicDlg_PrepareDialogStruct

procedure DumpWinPeModuleList;
const
  DEBUG_WINPE_MODULE_LIST_PATH = GameExt.DEBUG_DIR + '\pe modules.txt';

var
  i: integer;

begin
  {!} Core.ModuleContext.Lock;
  Core.ModuleContext.UpdateModuleList;

  with FilesEx.WriteFormattedOutput(GameExt.GameDir + '\' + DEBUG_WINPE_MODULE_LIST_PATH) do begin
    Line('> Win32 executable modules');
    EmptyLine;

    for i := 0 to Core.ModuleContext.ModuleList.Count - 1 do begin
      Line(Core.ModuleContext.ModuleInfo[i].ToStr);
    end;
  end;

  {!} Core.ModuleContext.Unlock;
end; // .procedure DumpWinPeModuleList

procedure DumpExceptionContext (ExcRec: PExceptionRecord; Context: Windows.PContext);
const
  DEBUG_EXCEPTION_CONTEXT_PATH = GameExt.DEBUG_DIR + '\exception context.txt';

var
  ExceptionText: myAStr;
  LineText:      myAStr;
  Ebp:           integer;
  Esp:           integer;
  RetAddr:       integer;
  i:             integer;

begin
  {!} Core.ModuleContext.Lock;
  Core.ModuleContext.UpdateModuleList;

  with FilesEx.WriteFormattedOutput(GameExt.GameDir + '\' + DEBUG_EXCEPTION_CONTEXT_PATH) do begin
    case ExcRec.ExceptionCode of
      $C0000005: begin
        if ExcRec.ExceptionInformation[0] <> 0 then begin
          ExceptionText := 'Failed to write data at ' + Legacy.Format('%x', [integer(ExcRec.ExceptionInformation[1])]);
        end else begin
          ExceptionText := 'Failed to read data at ' + Legacy.Format('%x', [integer(ExcRec.ExceptionInformation[1])]);
        end;
      end; // .case $C0000005

      $C000008C: ExceptionText := 'Array index is out of bounds';
      $80000003: ExceptionText := 'Breakpoint encountered';
      $80000002: ExceptionText := 'Data access misalignment';
      $C000008D: ExceptionText := 'One of the operands in a floating-point operation is denormal';
      $C000008E: ExceptionText := 'Attempt to divide a floating-point value by a floating-point divisor of zero';
      $C000008F: ExceptionText := 'The result of a floating-point operation cannot be represented exactly as a decimal fraction';
      $C0000090: ExceptionText := 'Invalid floating-point exception';
      $C0000091: ExceptionText := 'The exponent of a floating-point operation is greater than the magnitude allowed by the corresponding type';
      $C0000092: ExceptionText := 'The stack overflowed or underflowed as the result of a floating-point operation';
      $C0000093: ExceptionText := 'The exponent of a floating-point operation is less than the magnitude allowed by the corresponding type';
      $C000001D: ExceptionText := 'Attempt to execute an illegal instruction';
      $C0000006: ExceptionText := 'Attempt to access a page that was not present, and the system was unable to load the page';
      $C0000094: ExceptionText := 'Attempt to divide an integer value by an integer divisor of zero';
      $C0000095: ExceptionText := 'Integer arithmetic overflow';
      $C0000026: ExceptionText := 'An invalid exception disposition was returned by an exception handler';
      $C0000025: ExceptionText := 'Attempt to continue from an exception that isn''t continuable';
      $C0000096: ExceptionText := 'Attempt to execute a privilaged instruction.';
      $80000004: ExceptionText := 'Single step exception';
      $C00000FD: ExceptionText := 'Stack overflow';
      else       ExceptionText := 'Unknown exception';
    end; // .switch ExcRec.ExceptionCode
    
    Line(ExceptionText + '.');
    Line(Legacy.Format('EIP: %s. Code: %x', [Core.ModuleContext.AddrToStr(Ptr(Context.Eip)), ExcRec.ExceptionCode]));
    EmptyLine;
    Line('> Registers');

    Line('EAX: ' + Core.ModuleContext.AddrToStr(Ptr(Context.Eax), Core.ANALYZE_DATA));
    Line('ECX: ' + Core.ModuleContext.AddrToStr(Ptr(Context.Ecx), Core.ANALYZE_DATA));
    Line('EDX: ' + Core.ModuleContext.AddrToStr(Ptr(Context.Edx), Core.ANALYZE_DATA));
    Line('EBX: ' + Core.ModuleContext.AddrToStr(Ptr(Context.Ebx), Core.ANALYZE_DATA));
    Line('ESP: ' + Core.ModuleContext.AddrToStr(Ptr(Context.Esp), Core.ANALYZE_DATA));
    Line('EBP: ' + Core.ModuleContext.AddrToStr(Ptr(Context.Ebp), Core.ANALYZE_DATA));
    Line('ESI: ' + Core.ModuleContext.AddrToStr(Ptr(Context.Esi), Core.ANALYZE_DATA));
    Line('EDI: ' + Core.ModuleContext.AddrToStr(Ptr(Context.Edi), Core.ANALYZE_DATA));

    EmptyLine;
    Line('> Callstack');
    Ebp     := Context.Ebp;
    RetAddr := 1;

    try
      while (Ebp <> 0) and (RetAddr <> 0) do begin
        RetAddr := pinteger(Ebp + 4)^;

        if RetAddr <> 0 then begin
          Line(Core.ModuleContext.AddrToStr(Ptr(RetAddr)));
          Ebp := pinteger(Ebp)^;
        end;
      end;
    except
      // Stop processing callstack
    end; // .try

    EmptyLine;
    Line('> Stack');
    Esp := Context.Esp - sizeof(integer) * 5;

    try
      for i := 1 to 40 do begin
        LineText := Legacy.IntToHex(Esp, 8);

        if Esp = integer(Context.Esp) then begin
          LineText := LineText + '*';
        end;

        LineText := LineText + ': ' + Core.ModuleContext.AddrToStr(ppointer(Esp)^, Core.ANALYZE_DATA);
        Inc(Esp, sizeof(integer));
        Line(LineText);
      end; // .for
    except
      // Stop stack traversing
    end; // .try
  end; // .with

  {!} Core.ModuleContext.Unlock;
end; // .procedure DumpExceptionContext

function TopLevelExceptionHandler (const ExceptionPtrs: TExceptionPointers): integer; stdcall;
const
  EXCEPTION_CONTINUE_SEARCH = 0;

begin
  DumpExceptionContext(ExceptionPtrs.ExceptionRecord, ExceptionPtrs.ContextRecord);
  EventMan.GetInstance.Fire('OnGenerateDebugInfo');
  DlgMes.Msg('Game crashed. All debug information is inside ' + DEBUG_DIR + ' subfolder');
  
  result := EXCEPTION_CONTINUE_SEARCH;
end; // .function TopLevelExceptionHandler

function OnUnhandledException (const ExceptionPtrs: TExceptionPointers): integer; stdcall;
type
  THandler = function (const ExceptionPtrs: TExceptionPointers): integer; stdcall;

const
  EXCEPTION_CONTINUE_SEARCH = 0;

var
  i: integer;

begin
  {!} ExceptionsCritSection.Enter;

  for i := 0 to TopLevelExceptionHandlers.Count - 1 do begin
    THandler(TopLevelExceptionHandlers[i])(ExceptionPtrs);
  end;

  {!} ExceptionsCritSection.Leave;
  
  result := EXCEPTION_CONTINUE_SEARCH;
end; // .function OnUnhandledException

function Hook_SetUnhandledExceptionFilter (Context: Core.PHookContext): longbool; stdcall;
var
{Un} NewHandler: pointer;

begin
  NewHandler := ppointer(Context.ESP + 8)^;
  // * * * * * //
  if (NewHandler <> nil) and ((cardinal(NewHandler) < $401000) or (cardinal(NewHandler) > $7845FA)) then begin
    {!} ExceptionsCritSection.Enter;
    TopLevelExceptionHandlers.Add(NewHandler);
    {!} ExceptionsCritSection.Leave;
  end;

  (* result = nil *)
  Context.EAX := 0;

  (* return to calling routine *)
  Context.RetAddr := Core.Ret(1);
  
  result := Core.IGNORE_DEF_CODE;
end; // .function Hook_SetUnhandledExceptionFilter

procedure OnGenerateDebugInfo (Event: PEvent); stdcall;
begin
  DumpWinPeModuleList;
end;

procedure OnAfterWoG (Event: GameExt.PEvent); stdcall;
const
  ZVSLIB_EXTRACTDEF_OFS             = 100668;
  ZVSLIB_EXTRACTDEF_GETGAMEPATH_OFS = 260;
  
  NOP7: myAStr = #$90#$90#$90#$90#$90#$90#$90;

var
  Zvslib1Handle:  integer;
  Addr:           integer;
  NewAddr:        pointer;
  MinTimerResol:  cardinal;
  MaxTimerResol:  cardinal;
  CurrTimerResol: cardinal;

begin
  if DebugRng <> DEBUG_RNG_NONE then begin
    ConsoleApi.GetConsole();
  end;

  (* Ini handling *)
  Core.Hook(@Hook_ReadStrIni, Core.HOOKTYPE_JUMP, 5, ZvsReadStrIni);
  Core.Hook(@Hook_WriteStrIni, Core.HOOKTYPE_JUMP, 5, ZvsWriteStrIni);
  Core.Hook(@Hook_WriteIntIni, Core.HOOKTYPE_JUMP, 5, ZvsWriteIntIni);
  
  (* DL dialogs centering *)
  Core.Hook(@Hook_ZvsGetWindowWidth, Core.HOOKTYPE_BRIDGE, 5, Ptr($729C5A));
  Core.Hook(@Hook_ZvsGetWindowHeight, Core.HOOKTYPE_BRIDGE, 5, Ptr($729C6D));
  
  (* Mark the freshest savegame *)
  MarkFreshestSavegame;
  
  (* Fix multi-thread CPU problem *)
  if UseOnlyOneCpuCoreOpt then begin
    Windows.SetProcessAffinityMask(Windows.GetCurrentProcess, 1);
  end;
  
  (* Fix HotSeat second hero name *)
  Core.Hook(@Hook_SetHotseatHeroName, Core.HOOKTYPE_BRIDGE, 6, Ptr($5125B0));
  Core.WriteAtCode(Length(NOP7), pointer(NOP7), Ptr($5125F9));
  
  (* Universal CPU patch *)
  if CpuTargetLevel < 100 then begin
    // Try to set timer resolution to at least 1ms = 10000 ns
    if (WinNative.NtQueryTimerResolution(MinTimerResol, MaxTimerResol, CurrTimerResol) = STATUS_SUCCESS) and (CurrTimerResol > 10000) and (MaxTimerResol < CurrTimerResol) then begin
      WinNative.NtSetTimerResolution(Math.Max(10000, MaxTimerResol), true, CurrTimerResol);
    end;

    hTimerEvent := Windows.CreateEvent(nil, true, false, nil);
    Core.ApiHook(@Hook_PeekMessageA, Core.HOOKTYPE_BRIDGE, Windows.GetProcAddress(GetModuleHandleA(myPChar('user32.dll')), myPChar('PeekMessageA')));
  end;

  (* Remove duplicate ResetAll call *)
  PINTEGER($7055BF)^ :=  integer($90909090);
  PBYTE($7055C3)^    :=  $90;
  
  (* Optimize zvslib1.dll ini handling *)
  Zvslib1Handle   :=  Windows.GetModuleHandleA(myPChar('zvslib1.dll'));
  Addr            :=  Zvslib1Handle + 1666469;
  Addr            :=  PINTEGER(Addr + PINTEGER(Addr)^ + 6)^;
  NewAddr         :=  @New_Zvslib_GetPrivateProfileStringA;
  Core.WriteAtCode(sizeof(NewAddr), @NewAddr, pointer(Addr));

  (* Redirect reading/writing game settings to ini *)
  // No saving settings after reading them
  PBYTE($50B964)^    := $C3;
  PINTEGER($50B965)^ := integer($90909090);
  
  PPOINTER($50B920)^ := Ptr(integer(@ReadGameSettings) - $50B924);
  PPOINTER($50BA2F)^ := Ptr(integer(@WriteGameSettings) - $50BA33);
  PPOINTER($50C371)^ := Ptr(integer(@WriteGameSettings) - $50C375);
  
  (* Fix game version to enable map generator *)
  Heroes.GameVersion^ :=  Heroes.SOD_AND_AB;
  
  (* Fix gethostbyname function to return external IP address at first place *)
  if FixGetHostByNameOpt then begin
    Core.p.WriteHiHook
    (
      Windows.GetProcAddress(Windows.GetModuleHandleA(myPChar('ws2_32.dll')), myPChar('gethostbyname')),
      PatchApi.SPLICE_,
      PatchApi.EXTENDED_,
      PatchApi.STDCALL_,
      @Hook_GetHostByName
    );
  end;

  (* Fix ApplyDamage calls, so that !?MF1 damage is displayed correctly in log *)
  Core.ApiHook(@Hook_ApplyDamage_Ebx_Local7,  Core.HOOKTYPE_BRIDGE, Ptr($43F95B + 5));
  Core.ApiHook(@Hook_ApplyDamage_Ebx,         Core.HOOKTYPE_BRIDGE, Ptr($43FA5E + 5));
  Core.ApiHook(@Hook_ApplyDamage_Local7,      Core.HOOKTYPE_BRIDGE, Ptr($43FD3D + 5));
  Core.ApiHook(@Hook_ApplyDamage_Ebx,         Core.HOOKTYPE_BRIDGE, Ptr($4400DF + 5));
  Core.ApiHook(@Hook_ApplyDamage_Esi_Arg1,    Core.HOOKTYPE_BRIDGE, Ptr($440858 + 5));
  Core.ApiHook(@Hook_ApplyDamage_Ebx,         Core.HOOKTYPE_BRIDGE, Ptr($440E70 + 5));
  Core.ApiHook(@Hook_ApplyDamage_Arg1,        Core.HOOKTYPE_BRIDGE, Ptr($441048 + 5));
  Core.ApiHook(@Hook_ApplyDamage_Esi,         Core.HOOKTYPE_BRIDGE, Ptr($44124C + 5));
  Core.ApiHook(@Hook_ApplyDamage_Local4,      Core.HOOKTYPE_BRIDGE, Ptr($441739 + 5));
  Core.ApiHook(@Hook_ApplyDamage_Local8,      Core.HOOKTYPE_BRIDGE, Ptr($44178A + 5));
  Core.ApiHook(@Hook_ApplyDamage_Arg1,        Core.HOOKTYPE_BRIDGE, Ptr($46595F + 5));
  Core.ApiHook(@Hook_ApplyDamage_Ebx,         Core.HOOKTYPE_BRIDGE, Ptr($469A93 + 5));
  Core.ApiHook(@Hook_ApplyDamage_Local13,     Core.HOOKTYPE_BRIDGE, Ptr($5A1065 + 5));

  (* Fix negative offsets handling in fonts *)
  Core.p.WriteDataPatch(Ptr($4B534A), [myAStr('B6')]);
  Core.p.WriteDataPatch(Ptr($4B53E6), [myAStr('B6')]);

  (* Fix WoG/ERM versions *)
  Core.Hook(@Hook_GetWoGAndErmVersions, Core.HOOKTYPE_BRIDGE, 14, Ptr($73226C));

  (*  Fix zvslib1.dll ExtractDef function to support mods  *)
  Core.ApiHook
  (
    @Hook_ZvsLib_ExtractDef, Core.HOOKTYPE_BRIDGE, Ptr(Zvslib1Handle + ZVSLIB_EXTRACTDEF_OFS + 3)
  );
  
  Core.ApiHook
  (
    @Hook_ZvsLib_ExtractDef_GetGamePath,
    Core.HOOKTYPE_BRIDGE,
    Ptr(Zvslib1Handle + ZVSLIB_EXTRACTDEF_OFS + ZVSLIB_EXTRACTDEF_GETGAMEPATH_OFS)
  );

  Core.p.WriteHiHook(Ptr($71299E), PatchApi.SPLICE_, PatchApi.EXTENDED_, PatchApi.CDECL_, @Hook_ZvsPlaceMapObject);
  
  (* Syncronise object creation at local and remote PC *)
  EventMan.GetInstance.On('OnTrigger ' + Legacy.IntToStr(Erm.TRIGGER_ONREMOTEEVENT), OnRemoteMapObjectPlace);

  (* Fixed bug with combined artifact (# > 143) dismounting in heroes meeting screen *)
  Core.p.WriteDataPatch(Ptr($4DC358), [myAStr('A0')]);

  (* Fix WoG bug: do not rely on MixedPos argument for Enter2Monster(2), get coords from map object instead
     EDIT: no need anymore, fixed MixedPos *)
  if FALSE then begin
    Core.Hook(@Hook_ZvsEnter2Monster,  Core.HOOKTYPE_BRIDGE, 19, Ptr($75779F));
    Core.Hook(@Hook_ZvsEnter2Monster2, Core.HOOKTYPE_BRIDGE, 19, Ptr($757A74));
  end;

  (* Fix MixedPos to not drop higher order bits and not treat them as underground flag *)
  Core.p.WriteDataPatch(Ptr($711F4F), [myAStr('8B451425FFFFFF048945149090909090909090')]);

  (* Fix WoG bug: double !?OB54 event generation when attacking without moving due to Enter2Object + Enter2Monster2 calling *)
  Core.p.WriteDataPatch(Ptr($757AA0), [myAStr('EB2C90909090')]);

  (* Fix battle round counting: no !?BR before battlefield is shown, negative FIRST_TACTICS_ROUND incrementing for the whole tactics phase, the
     first real round always starts from 0 *)
  Core.ApiHook(@Hook_OnBeforeBattlefieldVisible, Core.HOOKTYPE_BRIDGE, Ptr($75EAEA));
  Core.ApiHook(@Hook_OnBattlefieldVisible,       Core.HOOKTYPE_BRIDGE, Ptr($462E2B));
  Core.ApiHook(@Hook_OnAfterTacticsPhase,        Core.HOOKTYPE_BRIDGE, Ptr($75D137));
  // Call ZvsNoMoreTactic1 in network game for the opposite side
  Core.ApiHook(ZvsNoMoreTactic1,                 Core.HOOKTYPE_CALL,   Ptr($473E89));

  Core.ApiHook(@Hook_OnCombatRound_Start,        Core.HOOKTYPE_BRIDGE, Ptr($76065B));
  Core.ApiHook(@Hook_OnCombatRound_End,          Core.HOOKTYPE_BRIDGE, Ptr($7609A3));
  // Disable BACall2 function, generating !?BR event, because !?BR will be the same as OnCombatRound now
  Core.p.WriteDataPatch(Ptr($74D1AB), [myAStr('C3')]);

  // Disable WoG AppearAfterTactics hook. We will call BR0 manually a bit after to reduce crashing probability
  Core.p.WriteDataPatch(Ptr($462C19), [myAStr('E8F2051A00')]);

  // Use CombatRound instead of combat manager field to summon creatures every nth turn via creature experience system
  Core.p.WriteDataPatch(Ptr($71DFBE), [myAStr('8B15 %d'), @CombatRound]);

  // Apply battle RNG seed right before placing obstacles, so that rand() calls in !?BF trigger would not influence battle obstacles
  ApiJack.StdSplice(Ptr($465E70), @Hook_PlaceBattleObstacles, ApiJack.CONV_THISCALL, 1);

  // Restore Nagash and Jeddite specialties
  Core.p.WriteDataPatch(Ptr($753E0B), [myAStr('E9990000009090')]); // PrepareSpecWoG => ignore new WoG settings
  Core.p.WriteDataPatch(Ptr($79C3D8), [myAStr('FFFFFFFF')]);       // HeroSpecWoG[0].Ind = -1

  // Fix check for multiplayer in attack type selection dialog, causing wrong "This feature does not work in Human vs Human network baced battle" message
  Core.p.WriteDataPatch(Ptr($762604), [myAStr('C5')]);

  // Fix creature experience overflow after battle
  ApiJack.HookCode(Ptr($719225), @Hook_PostBattle_OnAddCreaturesExp);

  // Fix DisplayComplexDialog to overload the last argument
  // closeTimeoutMsec is now TComplexDialogOpts
  //  16 bits for closeTimeoutMsec.
  //  4 bits for msgType (1 - ok, 2 - question, 4 - popup, etc), 0 is treated as 1.
  //  4 bits for text alignment + 1.
  //  8 bits for H3 string internal purposes (0 mostly).
  ApiJack.HookCode(Ptr($4F7D83), @Hook_DisplayComplexDialog_GetTimeout);
  // Nop dlg.closeTimeoutMsec := closeTimeoutMsec
  Core.p.WriteDataPatch(Ptr($4F7E19), [myAStr('909090')]);
  // Nop dlg.msgType := MSG_TYPE_MES
  Core.p.WriteDataPatch(Ptr($4F7E4A), [myAStr('90909090909090')]);

  (* Fix ShowParsedDlg8Items function to allow custom text alignment and preselected item *)
  ApiJack.HookCode(Ptr($4F72B5), @Hook_ShowParsedDlg8Items_CreateTextField);
  ApiJack.HookCode(Ptr($4F7136), @Hook_ShowParsedDlg8Items_Init);

  (* Fix ZvsDisplay8Dialog to 2 extra arguments (msgType, alignment) and return -1 or 0..7 for chosen picture or 0/1 for question *)
  ApiJack.HookCode(Ptr($7169EB), @Hook_ZvsDisplay8Dialog_BeforeShow);

  (* Patch ParsePicture function to allow "0 something" values in generic h3 dialogs *)
  // Allocate new local variables EBP - $0B4
  Core.p.WriteDataPatch(Ptr($4F555A), [myAStr('B4000000')]);
  // Unpack highest bit of Type parameter as "display 0 quantities" flag into new local variable
  ApiJack.HookCode(Ptr($4F5564), @Hook_ParsePicture_Start);

  (* Fix WoG HDlg::BuildPcx to allow .pcx16 virtual file extension to load image as pcx16 *)
  ApiJack.StdSplice(Ptr($7287FB), @Hook_HDlg_BuildPcx, ApiJack.CONV_STDCALL, 7);

  (* Fix Santa-Gremlins *)
  // Remove WoG FairePower hook
  Core.p.WriteDataPatch(Ptr($44836D), [myAStr('8B464C8D0480')]);
  // Add new FairePower hook
  ApiJack.HookCode(Ptr($44836D), @Hook_HandleMonsterCast_End);
  // Disable Santa's every day growth
  Core.p.WriteDataPatch(Ptr($760D6D), [myAStr('EB')]);
  // Restore Santa's normal growth
  Core.p.WriteDataPatch(Ptr($760C56), [myAStr('909090909090')]);
  // Disable Santa's gifts
  Core.p.WriteDataPatch(Ptr($75A964), [myAStr('9090')]);

  (* Fix multiplayer crashes: disable orig/diff.dat generation, always send packed whole savegames *)
  Core.p.WriteDataPatch(Ptr($4CAE51), [myAStr('E86A5EFCFF')]);       // Disable WoG BuildAllDiff hook
  Core.p.WriteDataPatch(Ptr($6067E2), [myAStr('E809000000')]);       // Disable WoG GZ functions hooks
  Core.p.WriteDataPatch(Ptr($4D6FCC), [myAStr('E8AF001300')]);       // ...
  Core.p.WriteDataPatch(Ptr($4D700D), [myAStr('E8DEFE1200')]);       // ...
  Core.p.WriteDataPatch(Ptr($4CAF32), [myAStr('EB')]);               // do not create orig.dat on send
  if false then Core.p.WriteDataPatch(Ptr($4CAF37), [myAStr('01')]); // save orig.dat on send compressed
  Core.p.WriteDataPatch(Ptr($4CAD91), [myAStr('E99701000090')]);     // do not perform savegame diffs
  Core.p.WriteDataPatch(Ptr($41A0D1), [myAStr('EB')]);               // do not create orig.dat on receive
  if false then Core.p.WriteDataPatch(Ptr($41A0DC), [myAStr('01')]); // save orig.dat on receive compressed
  Core.p.WriteDataPatch(Ptr($4CAD5A), [myAStr('31C040')]);           // Always gzip the data to be sent
  Core.p.WriteDataPatch(Ptr($589EA4), [myAStr('EB10')]);             // Do not create orig on first savegame receive from server

  (* Splice WoG Get2Battle function, handling any battle *)
  ApiJack.StdSplice(Ptr($75ADD9), @Hook_StartBattle, ApiJack.CONV_THISCALL, 11);

  (* Send and receive unique identifier for each battle to use in deterministic PRNG in multiplayer *)
  ApiJack.HookCode(Ptr($763796), @Hook_ZvsAdd2Send);
  ApiJack.HookCode(Ptr($763BA4), @Hook_ZvsGet4Receive);

  (* Replace Heroes PRNG with custom switchable PRNGs *)
  ApiJack.StdSplice(Ptr($61841F), @Hook_SRand, ApiJack.CONV_CDECL, 1);
  ApiJack.StdSplice(Ptr($61842C), @Hook_Rand, ApiJack.CONV_STDCALL, 0);
  ApiJack.StdSplice(Ptr($50C7B0), @Hook_Tracking_SRand, ApiJack.CONV_THISCALL, 1);
  ApiJack.StdSplice(Ptr($50C7C0), @Hook_RandomRange, ApiJack.CONV_FASTCALL, 2);

  (* Allow to handle dialog outer clicks and provide full mouse info for event *)
  ApiJack.HookCode(Ptr($7295F1), @Hook_ErmDlgFunctionActionSwitch);

  (* Add up to 10 animated DEFs support in DL-dialogs by restoring commented ZVS code *)
  ApiJack.HookCode(Ptr($72A1F6), @Hook_DL_D_ItemCreation);
  ApiJack.HookCode(Ptr($729513), @Hook_ErmDlgFunction_HandleAnimatedDef);

  (* Move acredits.smk video positon to json config and treat out-of-bounds coordinates as video switch-off *)
  ApiJack.HookCode(Ptr($706609), @Hook_ShowMainMenuVideo);
  ApiJack.HookCode(Ptr($4EEEE8), @Hook_OpenMainMenuVideo);

  (* Fix Blood Dragons aging change from 20% to 40% *)
  Core.p.WriteDataPatch(Ptr($75DE31), [myAStr('7509C6055402440028EB07C6055402440064')]);

  (* Use click coords to show popup dialogs almost everywhere *)
  ApiJack.HookCode(Ptr($4F6D54), @Hook_Show3PicDlg_PrepareDialogStruct);
  ApiJack.StdSplice(Ptr($5FF3A0), @Hook_Dlg_SendMsg, ApiJack.CONV_THISCALL, 2);

  if FALSE then begin
    // Disabled, the patch simply restores SOD behavior on adventure map
    ApiJack.HookCode(Ptr($7575A3), @Hook_ZvsPlaceCreature_End);
  end;

  (* Fix PrepareDialog3Struct inner width calculation: dlgWidth - 50 => dlgWidth - 40, centering the text *)
  Core.p.WriteDataPatch(Ptr($4F6696), [myAStr('D7')]);

  (* Increase number of quick battle rounds before fast finish from 30 to 100 *)
  Core.p.WriteDataPatch(Ptr($475C35), [myAStr('64')]);
end; // .procedure OnAfterWoG

procedure OnAfterVfsInit (Event: GameExt.PEvent); stdcall;
begin
  (* Install global top-level exception filter *)
  Windows.SetErrorMode(SEM_NOGPFAULTERRORBOX);
  Windows.SetUnhandledExceptionFilter(@OnUnhandledException);
  Core.ApiHook(@Hook_SetUnhandledExceptionFilter, Core.HOOKTYPE_BRIDGE, Windows.GetProcAddress(Windows.LoadLibraryA(myPChar('kernel32.dll')), myPChar('SetUnhandledExceptionFilter')));
  Windows.SetUnhandledExceptionFilter(@TopLevelExceptionHandler);
end;

begin
  Windows.InitializeCriticalSection(InetCriticalSection);
  ExceptionsCritSection.Init;
  TopLevelExceptionHandlers := DataLib.NewList(not UtilsB2.OWNS_ITEMS);
  CLangRng                  := FastRand.TClangRng.Create(FastRand.GenerateSecureSeed);
  QualitativeRng            := FastRand.TXoroshiro128Rng.Create(FastRand.GenerateSecureSeed);
  BattleDeterministicRng    := TBattleDeterministicRng.Create(@CombatId, @CombatRound, @CombatActionId, @CombatRngFreeParam);
  GlobalRng                 := QualitativeRng;
  IsMainThread              := true;
  Mp3TriggerHandledEvent    := Windows.CreateEvent(nil, false, false, nil);

  EventMan.GetInstance.On('OnAfterVfsInit', OnAfterVfsInit);
  EventMan.GetInstance.On('OnAfterWoG', OnAfterWoG);
  EventMan.GetInstance.On('OnBattleReplay', OnBattleReplay);
  EventMan.GetInstance.On('OnBeforeBattleAction', OnBeforeBattleAction);
  EventMan.GetInstance.On('OnBeforeBattleReplay', OnBeforeBattleReplay);
  EventMan.GetInstance.On('OnBeforeBattleUniversal', OnBeforeBattleUniversal);
  EventMan.GetInstance.On('OnGenerateDebugInfo', OnGenerateDebugInfo);

  if FALSE then begin
    (* Save global generator state in saved games *)
    (* Makes game predictable. Disabled. *)
    EventMan.GetInstance.On('OnSavegameWrite', OnSavegameWrite);
    EventMan.GetInstance.On('OnSavegameRead',  OnSavegameRead);
  end;
end.
