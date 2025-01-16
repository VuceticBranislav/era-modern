unit Debug;
(*
  Description: Low-level debugging functions: process termination, warnings, mapping addresses to source code locations, etc.
  Author:      Alexander Shostak aka Berserker
*)

(***)  interface  (***)

uses
  Math,
  PsApi,
  StrUtils,
  SysUtils,
  Windows,

  Alg,
  Concur,
  DataLib,
  DebugMaps,
  DlgMes,
  Files,
  StrLib,
  UtilsB2,
  WinWrappers, Legacy;

type
  (* Import *)
  TStrList = DataLib.TStrList;
  TList    = DataLib.TList;
  TObjDict = DataLib.TObjDict;

const
  OPCODE_RET     = $C3;
  OPCODE_RET_IW  = $C2;
  OPCODE_RETF    = $CB;
  OPCODE_RETF_IW = $CA;

  RET_OPCODES = [OPCODE_RET, OPCODE_RET_IW, OPCODE_RETF, OPCODE_RETF_IW];

  ANALYZE_DATA      = true;
  DONT_ANALYZE_DATA = not ANALYZE_DATA;

type
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


procedure KillThisProcess;
procedure GenerateException;
procedure NotifyError (const Err: myAStr);
procedure FatalError (const Err: myAStr);
procedure SetDebugMapsDir (const Dir: myAStr);
function  GetModuleList: TModuleList;
function  FindModuleByAddr ({n} Addr: pointer; ModuleList: TModuleList; out ModuleInd: integer): boolean;

var
  AbortOnError: boolean = false; // if set to false, NotifyError does not terminate application after showing error message

{O} ModuleContext: TModuleContext; // Shareable between threads, use lock methods


(***)  implementation  (***)


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
  FreeAndNil(fModuleList);
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
    fModuleList := Debug.GetModuleList;
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
  FreeAndNil(fModuleList);
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
      result := result + IntToHex(integer(Addr), 8);
    end else begin
      result := result + IntToHex(integer(Addr) - integer(ModuleInfo.BaseAddr), 1);
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
    result := IntToHex(integer(Addr), 8);
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
  FreeAndNil(ModuleInfo);
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
  ModuleContext := TModuleContext.Create;
  Maps          := DataLib.NewDict(UtilsB2.OWNS_ITEMS, DataLib.CASE_INSENSITIVE);
end.
