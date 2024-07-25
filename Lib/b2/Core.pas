unit Core;
(*
  Description: Low-level patching/debugging functions.
  Author:      Alexander Shostak aka Berserker
  Requires:    patcher_x86.dll by baratorch (maybe changed by replacing WriteAtCode with WriteAtCode_Standalone).
*)

(***)  interface  (***)

uses
  Math,
  PsApi,
  StrUtils,
  SysUtils,
  Windows,

  Alg,
  ApiJack,
  Concur,
  DataLib,
  DebugMaps,
  DlgMes,
  Files,
  hde32,
  PatchApi,
  StrLib,
  UtilsB2,
  WinWrappers, Legacy;

type
  (* Import *)
  TStrList = DataLib.TStrList;
  TList    = DataLib.TList;
  TObjDict = DataLib.TObjDict;

const
  (*
    Hook types

    HOOKTYPE_BRIDGE has opcode OPCODE_CALL. Creates a bridge to high-level function.
    function (Context: PHookContext): TExecuteDefaultCodeFlag; stdcall;
    if default code should be executed, it can contain any commands except jumps.
    The only jump opcodes allowed are: OPCODE_JUMP, OPCODE_CALL
  *)
  HOOKTYPE_JUMP   = 0; // jmp, 5 bytes
  HOOKTYPE_CALL   = 1; // call, 5 bytes
  HOOKTYPE_BRIDGE = 2; // call, 5 bytes

  OPCODE_JUMP    = $E9;
  OPCODE_CALL    = $E8;
  OPCODE_RET     = $C3;
  OPCODE_RET_IW  = $C2;
  OPCODE_RETF    = $CB;
  OPCODE_RETF_IW = $CA;
  OPCODE_NOP     = $90;

  RET_OPCODES = [OPCODE_RET, OPCODE_RET_IW, OPCODE_RETF, OPCODE_RETF_IW];

  EXEC_DEF_CODE   = true;
  IGNORE_DEF_CODE = not EXEC_DEF_CODE;

  ANALYZE_DATA      = true;
  DONT_ANALYZE_DATA = not ANALYZE_DATA;

type
  THookRec = packed record
    Opcode: byte;
    Ofs:    integer;
  end;

  PHookContext = ^THookContext;

  THookContext = packed record
    EDI, ESI, EBP, ESP, EBX, EDX, ECX, EAX: integer;
    RetAddr:                                pointer;
  end;

  TModuleInfo = class
    Name:       myAStr;  // evaluated: lower case without extension + capitalize
    FileName:   myAStr;  // evaluated: lower case
    Path:       myAStr;  // original data returned by WinApi
    BaseAddr:   pointer;
    EndAddr:    pointer; // evaluated
    EntryPoint: pointer;
    Size:       integer;
    IsExe:      boolean; // evaluated

    procedure EvaluateDerivatives;
    function  OwnsAddr ({n} Addr: pointer): boolean;
    function  ToStr: myAStr;
  end;

  TModuleList = {O} TStrList {of TModuleInfo};

  TModuleContext = class
   protected
    {On} fModuleList:         TModuleList;
         fModulesOrderByAddr: TArrayOfInt;
         fCritSection:        Concur.TCritSection;

    function  CompareModulesByAddr (Ind1, Ind2: integer): integer;
    procedure EnsureModuleList;
    function  GetModuleList: TModuleList;
    function  GetModuleInfo (Ind: integer): TModuleInfo;
    function  CompareModuleToAddr (OrderTableInd, Addr: integer): integer;

   public
    constructor Create;
    destructor Destroy; override;

    // Thread-safe context grab/release
    procedure Lock;
    procedure Unlock;

    procedure UpdateModuleList;
    // Uses separate index table and binary search unlike unit `FindModuleByAddr` function
    function  FindModuleByAddr ({n} Addr: pointer; out ModuleInd: integer): boolean;
    function  AddrToStr ({n} Addr: pointer;  AnalyzeData: bool = DONT_ANALYZE_DATA): myAStr;

    property ModuleList: TModuleList read GetModuleList;
    property ModuleInfo[Ind: integer]: TModuleInfo read GetModuleInfo;
  end; // .class TModuleContext


function  WriteAtCode (Count: integer; Src, Dst: pointer): boolean; stdcall;

(* For HOOKTYPE_BRIDGE hook functions return address to call original routine. It's expected that PatchSize covers integer number of commands *)
function  Hook (CodeAddr: pointer; HookType: integer; HandlerAddr: pointer): {n} pointer; stdcall;

procedure KillThisProcess;
procedure GenerateException;
procedure NotifyError (const Err: myAStr);
procedure FatalError (const Err: myAStr);

(* Returns address of assember ret-routine which will clean the arguments and return *)

function  Ret (NumArgs: integer): pointer;
procedure SetDebugMapsDir (const Dir: myAStr);
function  GetModuleList: TModuleList;
function  FindModuleByAddr ({n} Addr: pointer; ModuleList: TModuleList; out ModuleInd: integer): boolean;

var
  AbortOnError: boolean = false; // if set to false, NotifyError does not terminate application after showing error message

  (* Patching provider *)
  GlobalPatcher: PatchApi.TPatcher;
  p:             PatchApi.TPatcherInstance;

{O} ModuleContext: TModuleContext; // Shareable between threads, use lock methods


implementation


type
  PBridgeCodePart1 = ^TBridgeCodePart1;
  TBridgeCodePart1 = packed record
    Pushad:               byte;
    PushEsp:              byte;
    MovEaxConst32:        byte;
    HandlerAddr:          pointer;
    CallEax:              word;
    TestEaxEax:           word;
    JzOffset8:            byte;
    OffsetToAfterDefCode: byte;
    Label_ExecDefCode:    UtilsB2.TEmptyRec;
    Popad:                byte;
    AddEsp4:              array [0..2] of byte;
    // < Default code > //
  end; // .record TBridgeCodePart1

  PBridgeCodePart2 = ^TBridgeCodePart2;
  TBridgeCodePart2 = packed record
    PushConst32:           byte;
    RetAddr:               pointer;
    Ret_1:                 byte;
    Label_DontExecDefCode: UtilsB2.TEmptyRec;
    Popad:                 byte;
    Ret_2:                 byte;
  end; // .record TBridgeCodePart2

var
  BridgeCodePart1: TBridgeCodePart1 =
  (
    Pushad:        $60;
    PushEsp:       $54;
    MovEaxConst32: $B8;
    CallEax:       $D0FF;
    TestEaxEax:    $C085;
    JzOffset8:     $74;
    Popad:         $61;
    AddEsp4:       ($83, $C4, $04);
  );

  BridgeCodePart2: TBridgeCodePart2 =
  (
    PushConst32: $68;
    Ret_1:       $C3;
    Popad:       $61;
    Ret_2:       $C3;
  );

  DebugMapsDir: myAStr;

{O} Maps: {O} TDict {OF DebugMaps.TDebugMap};

procedure TModuleInfo.EvaluateDerivatives;
begin
  EndAddr  := UtilsB2.PtrOfs(BaseAddr, Size);
  FileName := Legacy.AnsiLowerCase(Legacy.ExtractFileName(Path));
  Name     := StrLib.Capitalize(Legacy.ChangeFileExt(FileName, ''));
  IsExe    := Legacy.AnsiEndsStr('.exe', FileName);
end;

function TModuleInfo.OwnsAddr ({n} Addr: pointer): boolean;
begin
  result := (cardinal(Addr) >= cardinal(BaseAddr)) and (cardinal(Addr) < cardinal(EndAddr));
end;

function TModuleInfo.ToStr: myAStr;
begin
  result := Legacy.Format('%s ("%s", size: %d, addr: %p, entry: %x)',
                   [Name, Path, Size, BaseAddr, integer(EntryPoint) - integer(BaseAddr)]);
end;

constructor TModuleContext.Create;
begin
  fCritSection.Init;
end; // .constructor TModuleContext.Create

destructor TModuleContext.Destroy;
begin
  Legacy.FreeAndNil(fModuleList);
  fCritSection.Delete;
end; // .destructor TModuleContext.Destroy

function TModuleContext.CompareModulesByAddr (Ind1, Ind2: integer): integer;
begin
  result := Alg.PtrCompare(TModuleInfo(fModuleList.Values[Ind1]).BaseAddr,
                           TModuleInfo(fModuleList.Values[Ind2]).BaseAddr);
end;

procedure SetDebugMapsDir (const Dir: myAStr);
begin
  DebugMapsDir := Dir;
end;

procedure TModuleContext.EnsureModuleList;
var
  i: integer;

begin
  if fModuleList = nil then begin
    fModuleList := Core.GetModuleList;
    fModuleList.Sort;
    SetLength(fModulesOrderByAddr, fModuleList.Count);

    for i := 0 to fModuleList.Count - 1 do begin
      fModulesOrderByAddr[i] := i;
    end;

    Alg.CustomQuickSort(pointer(fModulesOrderByAddr), 0, fModuleList.Count - 1,
                        CompareModulesByAddr);
  end; // .if
end; // .procedure TModuleContext.EnsureModuleList

function TModuleContext.GetModuleList: TModuleList;
begin
  EnsureModuleList;
  result := fModuleList;
end;

function TModuleContext.GetModuleInfo (Ind: integer): TModuleInfo;
begin
  EnsureModuleList;
  result := TModuleInfo(fModuleList.Values[Ind]);
end;

function TModuleContext.CompareModuleToAddr (OrderTableInd, Addr: integer): integer;
var
{U} ModInfo: TModuleInfo;

begin
  ModInfo := TModuleInfo(fModuleList.Values[fModulesOrderByAddr[OrderTableInd]]);

  if cardinal(Addr) < cardinal(ModInfo.BaseAddr) then begin
    result := -1;
  end else if cardinal(Addr) >= cardinal(ModInfo.EndAddr) then begin
    result := +1;
  end else begin
    result := 0;
  end;
end;

procedure TModuleContext.Lock;
begin
  fCritSection.Enter;
end;

procedure TModuleContext.Unlock;
begin
  fCritSection.Leave;
end;

procedure TModuleContext.UpdateModuleList;
begin
  Legacy.FreeAndNil(fModuleList);
  fModulesOrderByAddr := nil;
end;

function TModuleContext.FindModuleByAddr ({n} Addr: pointer; out ModuleInd: integer): boolean;
begin
  EnsureModuleList;

  result := Alg.CustomBinarySearch(pointer(fModulesOrderByAddr), 0, length(fModulesOrderByAddr) - 1,
                                   integer(Addr), CompareModuleToAddr, ModuleInd);
  if result then begin
    ModuleInd := fModulesOrderByAddr[ModuleInd];
  end;
end;

function TModuleContext.AddrToStr ({n} Addr: pointer; AnalyzeData: bool = DONT_ANALYZE_DATA): myAStr;
const
  MAX_DECIMAL_DIGIT                     = 9;
  STR_DEBUG_CHUNK_LEN                   = 32;
  BINARY_CHARS                          = [#0..#8, #11..#12, #14..#31];
  TRUSTED_CHARS                         = ['a'..'z', 'A'..'Z', '0'..'9', '_', 'à'..'ÿ', 'À'..'ß', '¸', '¨'];
  HEUR_MIN_PTR_ADDR                     = $100000;
  HEUR_MIN_STR_LEN                      = 3;
  HEUR_MIN_STR_TRUSTED_CHARS_PERCENTAGE = 50;

var
{U} ModuleInfo:          TModuleInfo;
    ModuleInd:           integer;
{U} DebugMap:            DebugMaps.TDebugMap;
    MapFilePath:         myAStr;
    MapFile:             myAStr;
    ReadableAddr:        myAStr;
    TargetStr:           myPChar;
    TargetStrChunk:      myAStr;
    TrustedCharsInChunk: integer;
    c:                   myChar;
    i:                   integer;

begin
  ModuleInfo := nil;
  DebugMap   := nil;
  // * * * * * //
  EnsureModuleList;
  result := '';

  if FindModuleByAddr(Addr, ModuleInd) then begin
    ModuleInfo := GetModuleInfo(ModuleInd);
    result     := ModuleInfo.Name + '.';

    if ModuleInfo.IsExe then begin
      result := result + Legacy.IntToHex(integer(Addr), 8);
    end else begin
      result := result + Legacy.IntToHex(integer(Addr) - integer(ModuleInfo.BaseAddr), 1);
    end;

    if DebugMapsDir <> '' then begin
      DebugMap := Maps[ModuleInfo.Name];

      if DebugMap = nil then begin
        DebugMap              := DebugMaps.TDebugMap.Create();
        Maps[ModuleInfo.Name] := DebugMap;
        MapFilePath           := DebugMapsDir + '\' + ModuleInfo.Name + '.dbgmap';

        if (Legacy.FileExists(MapFilePath) and Files.ReadFileContents(MapFilePath, MapFile)) and (length(MapFile) >= MIN_DBGMAP_FILE_SIZE) then begin
          DebugMap.LoadFromString(MapFile);
        end;
      end;

      ReadableAddr := DebugMap.GetReadableAddr(integer(Addr) - integer(ModuleInfo.BaseAddr));

      if ReadableAddr <> '' then begin
        result := result + ' (' + ReadableAddr + ')';
      end;
    end; // .if
  end else begin
    result := Legacy.IntToHex(integer(Addr), 8);
  end; // .else

  if AnalyzeData then begin
    result := result + ' (int: ' + Legacy.IntToStr(integer(Addr));

    if (cardinal(Addr) >= HEUR_MIN_PTR_ADDR) and not Windows.IsBadReadPtr(Addr, sizeof(integer)) then begin
      result := result + ', pint: ' + '0x' + Legacy.IntToHex(pinteger(Addr)^, 8);

      if pinteger(Addr)^ > MAX_DECIMAL_DIGIT then begin
        result := result + ' = ' + Legacy.IntToStr(pinteger(Addr)^);
      end;

      if not Windows.IsBadReadPtr(Addr, STR_DEBUG_CHUNK_LEN) then begin
        TargetStr           := myPChar(Addr);
        TargetStrChunk      := '';
        TrustedCharsInChunk := 0;

        for i := 0 to STR_DEBUG_CHUNK_LEN - 1 do begin
          c := TargetStr^;

          if c in BINARY_CHARS then begin
            TargetStrChunk := TargetStrChunk + '\x' + Legacy.IntToHex(ord(c), 2);
            break;
          end else begin
            TargetStrChunk := TargetStrChunk + c;

            if c in TRUSTED_CHARS then begin
              inc(TrustedCharsInChunk);
            end;
          end;

          inc(TargetStr);
        end; // .for

        if (length(TargetStrChunk) >= HEUR_MIN_STR_LEN) and (TrustedCharsInChunk * 100 div length(TargetStrChunk) >= HEUR_MIN_STR_TRUSTED_CHARS_PERCENTAGE) then begin
          result := result + ', str: "' + TargetStrChunk + '"';
        end;
      end; // .if
    end; // .if

    result := result + ')';
  end; // .if
end; // .function TModuleContext.AddrToStr

function WriteAtCode (Count: integer; Src, Dst: pointer): boolean; stdcall;
begin
  {!} Assert(UtilsB2.IsValidBuf(Dst, Count));
  {!} Assert((Src <> nil) or (Count = 0));
  result := (Count = 0) or p.Write(Dst, Src, Count, true).IsApplied();
end;

function WriteAtCode_Standalone (Count: integer; Src, Dst: pointer): boolean;
var
  OldPageProtect: integer;

begin
  {!} Assert(UtilsB2.IsValidBuf(Dst, Count));
  {!} Assert((Src <> nil) or (Count = 0));
  result := Count = 0;

  if not result then begin
    result := Windows.VirtualProtect(Dst, Count, Windows.PAGE_EXECUTE_READWRITE, @OldPageProtect);

    if result then begin
      UtilsB2.CopyMem(Count, Src, Dst);
      result := Windows.VirtualProtect(Dst, Count, OldPageProtect, @OldPageProtect);
    end;
  end;
end;

function Hook (CodeAddr: pointer; HookType: integer; HandlerAddr: pointer): {n} pointer;
var
  NopBuf:    array [0..63] of byte;
  NopCount:  integer;
  HookRec:   THookRec;
  PatchSize: integer;

begin
  {!} Assert(CodeAddr <> nil);
  {!} Assert(Math.InRange(HookType, HOOKTYPE_JUMP, HOOKTYPE_BRIDGE));
  {!} Assert(HandlerAddr <> nil);
  // * * * * * //
  if HookType = HOOKTYPE_BRIDGE then begin
    result := ApiJack.HookCode(CodeAddr, HandlerAddr);
    exit;
  end;

  result := nil;

  if HookType = HOOKTYPE_JUMP then begin
    HookRec.Opcode := OPCODE_JUMP;
  end else begin
    HookRec.Opcode := OPCODE_CALL;
  end;

  PatchSize   := ApiJack.CalcHookPatchSize(CodeAddr);
  HookRec.Ofs := integer(HandlerAddr) - integer(CodeAddr) - sizeof(THookRec);

  if not WriteAtCode(sizeof(THookRec), @HookRec, CodeAddr) then begin
    {!} Assert(false, string(Legacy.Format('Failed to write hook at %x', [integer(CodeAddr)])));
  end;

  NopCount := PatchSize - sizeof(THookRec);

  if NopCount > 0 then begin
    FillChar(NopBuf[0], NopCount, Chr(OPCODE_NOP));

    if not WriteAtCode(NopCount, @NopBuf[0], UtilsB2.PtrOfs(CodeAddr, sizeof(THookRec))) then begin
      {!} Assert(false, string(Legacy.Format('Failed to write hook at %x', [integer(CodeAddr)])));
    end;
  end;
end; // .function Hook

procedure KillThisProcess; assembler;
asm
  xor eax, eax   // zero register
  mov esp, eax   // zero stack pointer (no recovery possibly)
  mov [eax], eax // trigger exception without any possible recovery
end;

procedure GenerateException; assembler;
asm
  xor eax, eax
  mov [eax], eax
end;

procedure NotifyError (const Err: myAStr);
begin
  Windows.MessageBoxA(0, myPChar(Err), 'Error notification', Windows.MB_OK or Windows.MB_ICONEXCLAMATION);

  if AbortOnError then begin
    FatalError(Err);
  end;
end;

procedure FatalError (const Err: myAStr);
begin
  DlgMes.MsgError(Err);
  GenerateException;
end;

procedure Ret0; assembler;
asm
  // RET
end;

procedure Ret4; assembler;
asm
  ret 4
end;

procedure Ret8; assembler;
asm
  ret 8
end;

procedure Ret12; assembler;
asm
  ret 12
end;

procedure Ret16; assembler;
asm
  ret 16
end;

procedure Ret20; assembler;
asm
  ret 20
end;

procedure Ret24; assembler;
asm
  ret 24
end;

procedure Ret28; assembler;
asm
  ret 28
end;

procedure Ret32; assembler;
asm
  ret 32
end;

function Ret (NumArgs: integer): pointer;
begin
  case NumArgs of
    0: result := @Ret0;
    1: result := @Ret4;
    2: result := @Ret8;
    3: result := @Ret12;
    4: result := @Ret16;
    5: result := @Ret20;
    6: result := @Ret24;
    7: result := @Ret28;
    8: result := @Ret32;
  else
    result := nil;
    {!} Assert(false);
  end; // .SWITCH NumArgs
end; // .function Ret

function GetModuleList: TModuleList;
var
{O} ModuleInfo:     TModuleInfo;
    ModuleInfoRes:  PsApi.TModuleInfo;
    ModuleHandles:  array of HMODULE;
    CurrentProcess: THandle;
    SizeNeeded:     cardinal;
    NumModules:     integer;
    i:              integer;

begin
  ModuleInfo := nil;
  // * * * * * //
  result         := DataLib.NewStrList(UtilsB2.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  CurrentProcess := GetCurrentProcess;
  SetLength(ModuleHandles, 16000);

  if PsApi.EnumProcessModules(CurrentProcess, @ModuleHandles[0], Length(ModuleHandles) * sizeof(ModuleHandles[0]), SizeNeeded) then begin
    NumModules := SizeNeeded div sizeof(HMODULE);

    for i := 0 to NumModules - 1 do begin
      if PsApi.GetModuleInformation(CurrentProcess, ModuleHandles[i], @ModuleInfoRes, sizeof(ModuleInfoRes)) then begin
        ModuleInfo := TModuleInfo.Create;

        with ModuleInfo do begin
          Path       := WinWrappers.GetModuleFileName(ModuleHandles[i]);
          BaseAddr   := pointer(ModuleHandles[i]);
          EntryPoint := ModuleInfoRes.EntryPoint;
          Size       := ModuleInfoRes.SizeOfImage;
        end;

        ModuleInfo.EvaluateDerivatives;
        result.AddObj(ModuleInfo.Name, ModuleInfo); ModuleInfo := nil;
      end; // .if
    end; // .for
  end; // .if
  // * * * * * //
  Legacy.FreeAndNil(ModuleInfo);
end; // .function GetModuleList

function FindModuleByAddr ({n} Addr: pointer; ModuleList: TModuleList; out ModuleInd: integer): boolean;
var
  i: integer;

begin
  {!} Assert(ModuleList <> nil);
  result := Addr <> nil;

  if result then begin
    i := 0;

    while (i < ModuleList.Count) and not (TObject(ModuleList.Values[i]) as TModuleInfo).OwnsAddr(Addr) do begin
      Inc(i);
    end;

    result := i < ModuleList.Count;

    if result then begin
      ModuleInd := i;
    end;
  end; // .if
end; // .function FindModuleByAddr

begin
  ApiJack.SetCodeWriter(WriteAtCode);
  GlobalPatcher := PatchApi.GetPatcher;
  p             := GlobalPatcher.CreateInstance(myPChar(WinWrappers.GetModuleFileName(hInstance)));
  ModuleContext := TModuleContext.Create;
  Maps          := DataLib.NewDict(UtilsB2.OWNS_ITEMS, DataLib.CASE_INSENSITIVE);
end.
