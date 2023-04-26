unit EraAPI;
{
DESCRIPTION:  Era SDK
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses Windows, Legacy;

const
  (* Hooks *)
  HOOKTYPE_JUMP = 0;  // jmp, 5 bytes
  HOOKTYPE_CALL = 1;  // call, 5 bytes
  (*
    Opcode: call, 5 bytes.
    Automatically creates safe bridge to high-level function "F".
    Function (Context: PHookContext): longbool; stdcall; Should return true to execute default code.
    If default code should be executed, it can contain any commands except jumps.
  *)
  HOOKTYPE_BRIDGE = 2;

  OPCODE_JUMP = $E9;
  OPCODE_CALL = $E8;
  OPCODE_RET  = $C3;

  EXEC_DEF_CODE = true;

  (* Erm triggers *)
  TRIGGER_FU1       = 1;
  TRIGGER_FU29999   = 29999;
  TRIGGER_TM1       = 30000;
  TRIGGER_TM100     = 30099;
  TRIGGER_HE0       = 30100;
  TRIGGER_HE198     = 30298;
  TRIGGER_BA0       = 30300;
  TRIGGER_BA1       = 30301;
  TRIGGER_BR        = 30302;
  TRIGGER_BG0       = 30303;
  TRIGGER_BG1       = 30304;
  TRIGGER_MW0       = 30305;
  TRIGGER_MW1       = 30306;
  TRIGGER_MR0       = 30307;
  TRIGGER_MR1       = 30308;
  TRIGGER_MR2       = 30309;
  TRIGGER_CM0       = 30310;
  TRIGGER_CM1       = 30311;
  TRIGGER_CM2       = 30312;
  TRIGGER_CM3       = 30313;
  TRIGGER_CM4       = 30314;
  TRIGGER_AE0       = 30315;
  TRIGGER_AE1       = 30316;
  TRIGGER_MM0       = 30317;
  TRIGGER_MM1       = 30318;
  TRIGGER_CM5       = 30319;
  TRIGGER_MP        = 30320;
  TRIGGER_SN        = 30321;
  TRIGGER_MG0       = 30322;
  TRIGGER_MG1       = 30323;
  TRIGGER_TH0       = 30324;
  TRIGGER_TH1       = 30325;
  TRIGGER_IP0       = 30330;
  TRIGGER_IP1       = 30331;
  TRIGGER_IP2       = 30332;
  TRIGGER_IP3       = 30333;
  TRIGGER_CO0       = 30340;
  TRIGGER_CO1       = 30341;
  TRIGGER_CO2       = 30342;
  TRIGGER_CO3       = 30343;
  TRIGGER_BA50      = 30350;
  TRIGGER_BA51      = 30351;
  TRIGGER_BA52      = 30352;
  TRIGGER_BA53      = 30353;
  TRIGGER_GM0       = 30360;
  TRIGGER_GM1       = 30361;
  TRIGGER_PI        = 30370;
  TRIGGER_DL        = 30371;
  TRIGGER_HM        = 30400;
  TRIGGER_HM0       = 30401;
  TRIGGER_HM198     = 30599;
  TRIGGER_HL        = 30600;
  TRIGGER_HL0       = 30601;
  TRIGGER_HL198     = 30799;
  TRIGGER_BF        = 30800;
  TRIGGER_MF1       = 30801;
  TRIGGER_TL0       = 30900;
  TRIGGER_TL1       = 30901;
  TRIGGER_TL2       = 30902;
  TRIGGER_TL3       = 30903;
  TRIGGER_TL4       = 30904;
  TRIGGER_OB_POS    = integer($10000000);
  TRIGGER_LE_POS    = integer($20000000);
  TRIGGER_OB_LEAVE  = integer($08000000);
  TRIGGER_INVALID   = -1;

  (* Era Triggers *)
  FIRST_ERA_TRIGGER                      = 77001;
  TRIGGER_SAVEGAME_WRITE                 = 77001;
  TRIGGER_SAVEGAME_READ                  = 77002;
  TRIGGER_KEYPRESS                       = 77003;
  TRIGGER_OPEN_HEROSCREEN                = 77004;
  TRIGGER_CLOSE_HEROSCREEN               = 77005;
  TRIGGER_STACK_OBTAINS_TURN             = 77006;
  TRIGGER_REGENERATE_PHASE               = 77007;
  TRIGGER_AFTER_SAVE_GAME                = 77008;
  TRIGGER_BEFOREHEROINTERACT             = 77010;
  TRIGGER_AFTERHEROINTERACT              = 77011;
  TRIGGER_ONSTACKTOSTACKDAMAGE           = 77012;
  TRIGGER_ONAICALCSTACKATTACKEFFECT      = 77013;
  TRIGGER_ONCHAT                         = 77014;
  TRIGGER_ONGAMEENTER                    = 77015;
  TRIGGER_ONGAMELEAVE                    = 77016;
  TRIGGER_ONREMOTEEVENT                  = 77017;
  TRIGGER_DAILY_TIMER                    = 77018;
  TRIGGER_ONBEFORE_BATTLEFIELD_VISIBLE   = 77019;
  TRIGGER_BATTLEFIELD_VISIBLE            = 77020;
  TRIGGER_AFTER_TACTICS_PHASE            = 77021;
  TRIGGER_COMBAT_ROUND                   = 77022;
  TRIGGER_OPEN_RECRUIT_DLG               = 77023;
  TRIGGER_CLOSE_RECRUIT_DLG              = 77024;
  TRIGGER_RECRUIT_DLG_MOUSE_CLICK        = 77025;
  TRIGGER_TOWN_HALL_MOUSE_CLICK          = 77026;
  TRIGGER_KINGDOM_OVERVIEW_MOUSE_CLICK   = 77027;
  TRIGGER_RECRUIT_DLG_RECALC             = 77028;
  TRIGGER_RECRUIT_DLG_ACTION             = 77029;
  TRIGGER_LOAD_HERO_SCREEN               = 77030;
  TRIGGER_BUILD_TOWN_BUILDING            = 77031;
  TRIGGER_OPEN_TOWN_SCREEN               = 77032;
  TRIGGER_CLOSE_TOWN_SCREEN              = 77033;
  TRIGGER_SWITCH_TOWN_SCREEN             = 77034;
  TRIGGER_PRE_TOWN_SCREEN                = 77035;
  TRIGGER_POST_TOWN_SCREEN               = 77036;
  TRIGGER_PRE_HEROSCREEN                 = 77037;
  TRIGGER_POST_HEROSCREEN                = 77038;
  TRIGGER_DETERMINE_MON_INFO_DLG_UPGRADE = 77039;
  TRIGGER_ADVMAP_TILE_HINT               = 77040;
  {!} LAST_ERA_TRIGGER                   = TRIGGER_DETERMINE_MON_INFO_DLG_UPGRADE;

type
  PHookContext = ^THookContext;
  THookContext = packed record
    EDI, ESI, EBP, ESP, EBX, EDX, ECX, EAX: integer;
    RetAddr:                                pointer;
  end; // .record THookContext

  (* Generated event info *)
  PEvent = ^TEvent;
  TEvent = packed record
      Name:     myAStr;
  {n} Data:     pointer;
      DataSize: integer;
  end;

  TEventHandler = procedure (Event: PEvent) stdcall;

  PErmVVars      = ^TErmVVars;
  TErmVVars      = array [1..10000] of integer;
  PWVars         = ^TWVars;
  TWVars         = array [0..255, 1..200] of integer;
  TErmZVar       = array [0..511] of myChar;
  PErmZVars      = ^TErmZVars;
  TErmZVars      = array [1..1000] of TErmZVar;
  PErmNZVars     = ^TErmNZVars;
  TErmNZVars     = array [1..10] of TErmZVar;
  PErmYVars      = ^TErmYVars;
  TErmYVars      = array [1..100] of integer;
  PErmNYVars     = ^TErmNYVars;
  TErmNYVars     = array [1..100] of integer;
  PErmXVars      = ^TErmXVars;
  TErmXVars      = array [1..16] of integer;
  PErmFlags      = ^TErmFlags;
  TErmFlags      = array [1..1000] of boolean;
  PErmEVars      = ^TErmEVars;
  TErmEVars      = array [1..100] of single;
  PErmNEVars     = ^TErmNEVars;
  TErmNEVars     = array [1..100] of single;
  PErmQuickVars  = ^TErmQuickVars;
  TErmQuickVars  = array [1..15] of integer;
  PZvsTriggerIfs = ^TZvsTriggerIfs;
  TZvsTriggerIfs = array [0..10] of shortint;

  PGameState  = ^TGameState;
  TGameState  = packed record
    RootDlgId:    integer;
    CurrentDlgId: integer;
  end; // .record TGameState

const
  (* WoG vars *)
  QuickVars: PErmQuickVars = Ptr($27718D0);
  v:  PErmVVars = Ptr($887668);
  w:  PWVars    = Ptr($A4AB10);
  z:  PErmZVars = Ptr($9273E8);
  y:  PErmYVars = Ptr($A48D80);
  x:  PErmXVars = Ptr($91DA38);
  f:  PErmFlags = Ptr($91F2E0);
  e:  PErmEVars = Ptr($A48F18);
  nz: PErmNZVars = Ptr($A46D28);
  ny: PErmNYVars = Ptr($A46A30);
  ne: PErmNEVars = Ptr($27F93B8);

function  GetButtonID (ButtonName: myPChar): integer; stdcall; external 'era.dll' name 'GetButtonID';
function  GetRealAddr (Addr: pointer): pointer; stdcall; external 'era.dll' name 'GetRealAddr';
function  PatchExists (PatchName: myPChar): longbool; stdcall; external 'era.dll' name 'PatchExists';
function  PluginExists (PluginName: myPChar): longbool; stdcall; external 'era.dll' name 'PluginExists';
function  ReadSavegameSection (DataSize: integer; {n} Dest: pointer; SectionName: myPChar ): integer; stdcall; external 'era.dll' name 'ReadSavegameSection';
function  ReadStrFromIni (Key, SectionName, FilePath, Res: myPChar): longbool; stdcall; external 'era.dll' name 'ReadStrFromIni';
function  SaveIni (FilePath: myPChar): longbool; stdcall; external 'era.dll' name 'SaveIni';
function  WriteStrToIni (Key, Value, SectionName, FilePath: myPChar): longbool; stdcall; external 'era.dll' name 'WriteStrToIni';
procedure ApiHook (HandlerAddr: pointer; HookType: integer; CodeAddr: pointer); stdcall; external 'era.dll' name 'ApiHook';
procedure ClearAllIniCache; external 'era.dll' name 'ClearAllIniCache';
procedure ClearIniCache (FileName: myPChar); stdcall; external 'era.dll' name 'ClearIniCache';
procedure ExecErmCmd (CmdStr: myPChar); stdcall; external 'era.dll' name 'ExecErmCmd';
procedure ExtractErm; external 'era.dll' name 'ExtractErm';
procedure FatalError (Err: myPChar); stdcall; external 'era.dll' name 'FatalError';
procedure FireErmEvent (EventID: integer); stdcall; external 'era.dll' name 'FireErmEvent';
procedure FireEvent (EventName: myPChar; {n} EventData: pointer; DataSize: integer); stdcall; external 'era.dll' name 'FireEvent';
procedure GenerateDebugInfo; external 'era.dll' name 'GenerateDebugInfo';
procedure GetGameState (var GameState: TGameState); stdcall; external 'era.dll' name 'GetGameState';
procedure GlobalRedirectFile (OldFileName, NewFileName: myPChar); stdcall; external 'era.dll' name 'GlobalRedirectFile';
procedure Hook (HandlerAddr:  pointer; HookType: integer; PatchSize: integer; CodeAddr: pointer ); stdcall; external 'era.dll' name 'Hook';
procedure NameColor (Color32: integer; Name: myPChar); stdcall; external 'era.dll' name 'NameColor';
procedure RedirectFile (OldFileName, NewFileName: myPChar); stdcall; external 'era.dll' name 'RedirectFile';
procedure RedirectMemoryBlock (OldAddr: pointer; BlockSize: integer; NewAddr: pointer); stdcall; external 'era.dll' name 'RedirectMemoryBlock';
procedure RegisterHandler (Handler: TEventHandler; EventName: myPChar); stdcall; external 'era.dll' name 'RegisterHandler';
procedure ReloadErm; external 'era.dll' name 'ReloadErm';
procedure WriteAtCode (Count: integer; Src, Dst: pointer); stdcall; external 'era.dll' name 'WriteAtCode';
procedure WriteSavegameSection (DataSize: integer; {n} Data: pointer; SectionName: myPChar); stdcall; external 'era.dll' name 'WriteSavegameSection';

(***)  implementation  (***)

end.
