unit PatchForge;
(*
  Code/data/patching utilities, assembler/disassembler means.
  Unit without third-party dependencies except Hacker Disassembler Engine (hde32).
*)

// D2006      --> XE10.3
// String     --> myAStr
// WideString --> myWStr
// Char       --> myChar
// WideChar   --> myWChar
// PChar      --> myPChar
// PWideChar  --> myPWChar
// PPChar     --> myPPChar;
// PAnsiString--> myPAStr;
// PWideString--> myPWStr;

(***)  interface  (***)


uses
  Legacy, Windows, SysUtils, hde32, UtilsB2, Math, Alg, DataLib, TypeWrappers;

type
  (* Import *)
  TString = TypeWrappers.TString;
  TList   = DataLib.TList;

const
  (* Used in all functions, requiring pos *)
  CURRENT_POS = -1;

  (* Specifies, that fixed moved code must have the same size, as original one *)
  FIX_CODE_SAME_SIZE = 1;
  
  (* Specifies, that fixed moved code must be made position independent (movable), i.e. contain no relative jump/calls *)
  FIX_CODE_MAKE_MOVABLE = 2;

  (* Assembler opcodes and instructions *)
  OPCODE_NOP              = $90;
  OPCODE_INT3             = $CC;
  OPCODE_JMP_CONST32      = $E9;
  OPCODE_JE_CONST32       = $840F;
  OPCODE_JNE_CONST32      = $850F;
  OPCODE_JA_CONST32       = $870F;
  OPCODE_JAE_CONST32      = $830F;
  OPCODE_JB_CONST32       = $820F;
  OPCODE_JBE_CONST32      = $860F;
  OPCODE_JG_CONST32       = $8F0F;
  OPCODE_JGE_CONST32      = $8D0F;
  OPCODE_JL_CONST32       = $8C0F;
  OPCODE_JLE_CONST32      = $8E0F;
  OPCODE_JO_CONST32       = $800F;
  OPCODE_JNO_CONST32      = $810F;
  OPCODE_JS_CONST32       = $880F;
  OPCODE_JNS_CONST32      = $890F;
  OPCODE_JP_CONST32       = $8A0F;
  OPCODE_JNP_CONST32      = $8B0F;
  OPCODE_JMP_SHORT_CONST8 = $EB;
  OPCODE_JE_SHORT_CONST8  = $74;
  OPCODE_JNE_SHORT_CONST8 = $75;
  OPCODE_JA_SHORT_CONST8  = $77;
  OPCODE_JAE_SHORT_CONST8 = $73;
  OPCODE_JB_SHORT_CONST8  = $72;
  OPCODE_JBE_SHORT_CONST8 = $76;
  OPCODE_JG_SHORT_CONST8  = $7F;
  OPCODE_JGE_SHORT_CONST8 = $7D;
  OPCODE_JL_SHORT_CONST8  = $7C;
  OPCODE_JLE_SHORT_CONST8 = $7E;
  OPCODE_JO_SHORT_CONST8  = $70;
  OPCODE_JNO_SHORT_CONST8 = $71;
  OPCODE_JS_SHORT_CONST8  = $78;
  OPCODE_JNS_SHORT_CONST8 = $79;
  OPCODE_JP_SHORT_CONST8  = $7A;
  OPCODE_JNP_SHORT_CONST8 = $7B;
  OPCODE_CALL_CONST32     = $E8;
  OPCODE_PUSH_CONST32     = $68;
  OPCODE_MOV_EAX_CONST32  = $B8;
  OPCODE_RET              = $C3;
  OPCODE_RET_CONST16      = $C2;
  OPCODE_JMP_PTR_CONST32  = $25FF;
  
  INSTR_JMP_EAX                = $E0FF;
  INSTR_TEST_EAX_EAX           = $C085;
  INSTR_SUB_ESP_4              = $04EC83;
  INSTR_PUSH_PTR_ESP           = $E434FF;
  INSTR_MOV_ESP_PLUS_4_CONST32 = integer($04E444C7);
  INSTR_MOV_ESP_MIN_4_CONST32  = integer($FCE444C7);
  INSTR_JUMP_PTR_ESP_MIN_4     = integer($FCE464FF);
  INSTR_CALL_PTR_ESP_MIN_4     = integer($FCE454FF);


type
  (* 3 bytes integer *)
  PTribyte = ^TTribyte;
  TTribyte = packed record
    Bytes: array [0..2] of byte;
  end;

  (* Unconditional jump/call OFFSET 32 instruction *)
  PJumpCall32Rec = ^TJumpCall32Rec;
  TJumpCall32Rec = packed record
    Opcode: byte;
    Offset: integer;
  end;

  (* Unconditional jump/call OFFSET 8 instruction *)
  PJumpCall8Rec = ^TJumpCall8Rec;
  TJumpCall8Rec = packed record
    Opcode: byte;
    Offset: shortint;
  end;

  TPatchAction     = class;
  TPostponedAction = class;

  TPatchMaker = class
   private
   {O} fPostponedActions: {O} DataLib.TList {OF TPostponedAction};
   {O} fLabels:           DataLib.TDict {OF Pos: integer};
       fBuf:              UtilsB2.TArrayOfByte;
       fPos:              integer;
       fSize:             integer;
       fLabelAutoId:      integer;


    procedure SetPos (NewPos: integer); inline;
    procedure Grow (NewSize: integer);
    procedure ExecPostponedActions ({n} TargetAddr, {n} TargetRealAddr: pointer);

   public
    constructor Create;
    destructor Destroy; override;

    (* Returns true if given position is valid position *)
    function IsValidPos (Pos: integer): boolean;

    (* Returns validated position in range [0, Size] or raises exception. Value of CURRENT_POS is replaced with current position *)
    function NormalizePos (Pos: integer): integer;

    (* Writes NumBytes bytes from buffer. Increases position pointer. Returns self. *)
    function WriteBytes (NumBytes: integer; {n} Buf: pointer): {U} TPatchMaker;

    (* Writes list of [int32/int64/float32/boolean/AnsiChar/WideChar/AnsiString without #0/WideString without #0/any pointer, object, class, interface, PChar, PWideChar as pointer]
       and increases position pointer. Returns self.
       Objects, implementing IPatchCmd interface are treated specially as commands. Their Execute method is called with PatchMaker instance as the only argument. *)
    function Write (const Args: array of const): {U} TPatchMaker;

    (* Seeks to specified existing position or raises error. Returns self. *)
    function Seek (Pos: integer): {U} TPatchMaker;

    (* Ensures, that there is enough soace from current position and returns real temporary pointer to buffer part.
       Existing data is preserved. Calling any class method (except property getters) may invalid the pointer. *)
    function Alloc (NumBytes: integer): {Un} pointer;

    (* Returns real temporary pointer for existing position in buffer. Calling any class method (except property getters) may invalid the pointer. *)
    function GetPosTempAddr (Pos: integer = CURRENT_POS): {Un} pointer;

    (* Generates and returns new unique label *)
    function NewAutoLabel (out LabelName: myAStr): myAStr;

    (* Gives current position a named label. Throws exception if label with the same name is used elsewhere. *)
    function PutLabel (const LabelName: myAStr): {U} TPatchMaker;

    (* Returns label position by name or -1 for not yet resolved label *)
    function GetLabelPos (const LabelName: myAStr): integer;

    (* Enqueues action to be executed at specified position during patch application on target buffer. Actions are executed in order (FIFO). *)
    function ExecActionOnApply ({O} Action: TPatchAction; Pos: integer = CURRENT_POS): {U} TPatchMaker;

    (* Returns not applied patch in the form of raw bytes array of capacity, greater or equal to patch size. The Clear method is called afterwards automatically. *)
    function GetPatch: {O} UtilsB2.TArrayOfByte;

    (* Applies patch at specified address. Automatically fixes marked offsets. Returns pointer to memory location right after the patch.
       Memory must be writable. TargetRealAddr specifies the address, patch data is intended to be copied to in the end. This address is used to calculate
       real internal addresses, jump offsets, etc. *)
    function ApplyPatch ({n} TargetAddr, {n} TargetRealAddr: pointer): {n} pointer;

    (* Resets and truncates patch buffer and all auxiliary structures *)
    function Clear: {U} TPatchMaker;

    property Pos:  integer read fPos write SetPos;
    property Size: integer read fSize;
  end; // .class TPatchMaker

  (* Custom patch command, which can be executed either separately or as one of TPatchMaker.Write arguments *)
  IPatchCmd = interface ['{EBD3A1C8-E3F0-4059-8D76-3A164E7E1163}']
    procedure Execute (p: TPatchMaker);
  end;

  (* Custom action, that is executed at definite position in target patch buffer during patch application. It can modify data,
     resolve labels, convert local addresses to real addresses, etc. Action MUST NOT change patch maker internal data.
  *)
  TPatchAction = class
   protected
    (* Real execution routine. All arguments are already checked and valid. *)
    procedure _Execute ({n} ItemAddr, {n} RealItemAddr: pointer; ItemPos: integer; PatchMaker: {U} TPatchMaker); virtual;

   public
    (* Evaluates some expression and probably modifies item data. RealItemAddr is READONLY, it specifies future item address *)
    procedure Execute ({n} ItemAddr, {n} RealItemAddr: pointer; ItemPos: integer; PatchMaker: {U} TPatchMaker);
  end; // .class TPatchAction

  (* Patch action, postponed to be executed at specified position during patch application stage *)
  TPostponedAction = class
   protected
    {O} fAction: TPatchAction;
        fPos:    integer;

   public
    constructor Create (Action: TPatchAction; Pos: integer);
    destructor Destroy; override;

    (* RealBufAddr is readonly, specifies address, where data is intended to be copied after patch application  *)
    procedure Execute ({n} PatchBufAddr, {n} RealBufAddr: pointer; PatchMaker: TPatchMaker);
  end;

  (* Complex action holds list of other actions, that will be executed in order one by one *)
  TPatchComplexAction = class (TPatchAction)
   protected
    fActions: {O} TList {OF TPatchAction};

    procedure _Execute ({n} ItemAddr, {n} RealItemAddr: pointer; ItemPos: integer; PatchMaker: {U} TPatchMaker); override;

   public
    constructor Create (const Actions: array of TPatchAction);
    destructor Destroy; override;
  end;

  (* Adds real address of dword to dword value *)
  TAddRealAddrAction = class (TPatchAction)
   protected
    procedure _Execute ({n} ItemAddr, {n} RealItemAddr: pointer; ItemPos: integer; PatchMaker: {U} TPatchMaker); override;
  end;

  (* Adds real address of byte to byte value *)
  TAddRealAddrByteAction = class (TPatchAction)
   protected
    procedure _Execute ({n} ItemAddr, {n} RealItemAddr: pointer; ItemPos: integer; PatchMaker: {U} TPatchMaker); override;
  end;

  (* Subtracts real address of dword to dword value *)
  TSubRealAddrAction = class (TPatchAction)
   protected
    procedure _Execute ({n} ItemAddr, {n} RealItemAddr: pointer; ItemPos: integer; PatchMaker: {U} TPatchMaker); override;
  end;

  (* Subtracts real address of byte to byte value *)
  TSubRealAddrByteAction = class (TPatchAction)
   public
    procedure _Execute ({n} ItemAddr, {n} RealItemAddr: pointer; ItemPos: integer; PatchMaker: {U} TPatchMaker); override;
  end;

  (* Adds dword position in patch buffer to dword value *)
  TAddPosAction = class (TPatchAction)
   protected
    procedure _Execute ({n} ItemAddr, {n} RealItemAddr: pointer; ItemPos: integer; PatchMaker: {U} TPatchMaker); override;
  end;

  (* Subtracts dword position in patch buffer from dword value *)
  TSubPosAction = class (TPatchAction)
   protected
    procedure _Execute ({n} ItemAddr, {n} RealItemAddr: pointer; ItemPos: integer; PatchMaker: {U} TPatchMaker); override;
  end;

  (* Adds label real address to dword value *)
  TAddLabelRealAddrAction = class (TPatchComplexAction)
   public
    constructor Create (const LabelName: myAStr);
  end;

  (* Adds label position to dword value *)
  TAddLabelPosAction = class (TPatchAction)
   protected
    fLabelName: myAStr;

    procedure _Execute ({n} ItemAddr, {n} RealItemAddr: pointer; ItemPos: integer; PatchMaker: {U} TPatchMaker); override;

   public
    constructor Create (const LabelName: myAStr);
  end;

  (* Adds label position to byte value *)
  TAddLabelPosByteAction = class (TPatchAction)
   protected
    fLabelName: myAStr;

   public
    constructor Create (const LabelName: myAStr);
    
    procedure _Execute ({n} ItemAddr, {n} RealItemAddr: pointer; ItemPos: integer; PatchMaker: {U} TPatchMaker); override;
  end;

  TJumpType = (JMP, JE, JNE, JA, JAE, JB, JBE, JG, JGE, JL, JLE, JO, JNO, JS, JNS, JP, JNP,
               JMP_SHORT, JE_SHORT, JNE_SHORT, JA_SHORT, JAE_SHORT, JB_SHORT, JBE_SHORT, JG_SHORT, JGE_SHORT, JL_SHORT, JLE_SHORT, JO_SHORT, JNO_SHORT, JS_SHORT, JNS_SHORT, JP_SHORT, JNP_SHORT);

  ICodeSizeDetector = interface ['{6770C008-C686-11E8-A355-529269FB1459}']
    (* Returns size of code block in bytes. For nil function MUST return 0 *)
    function GetCodeSize ({n} CodePtr: pbyte): integer;
  end;

  (* Always returns the same code size value for any non-nil code pointer. *)
  TFixedCodeSizeDetector = class (UtilsB2.TManagedObject, ICodeSizeDetector)
   private
    fCodeSize: integer;

   public
    constructor Create (CodeSize: integer);

    function GetCodeSize ({n} CodePtr: pbyte): integer;
  end;

  (* Analyses code block of specified size. Extends block size to include the last whole instruction,
     if the instruction crosses block border. *)
  TMinCodeSizeDetector = class (UtilsB2.TManagedObject, ICodeSizeDetector)
   private
    fMinCodeSize: integer;

   public
    constructor Create (MinCodeSize: integer);

    function GetCodeSize ({n} CodePtr: pbyte): integer;
  end;

  (* Analyses function code, searching for RET instruction as end marker. Raises exception if MaxCodeSize bytes
     were scanned and RET was not found. *)
  TFuncCodeSizeDetector = class (UtilsB2.TManagedObject, ICodeSizeDetector)
   private
    fMaxCodeSize: integer;

   public
    constructor Create (MaxCodeSize: integer = 1000000);
    
    function GetCodeSize ({n} CodePtr: pbyte): integer;
  end;

  (* Powerful wrapper for TPatchMaker instance *)
  TPatchHelper = record
   public
    (* Wrapped patch making engine *)
    {OU} PatchMaker: TPatchMaker;

    (* Wraps PatchMaker into local helper wrapper and returns the helper *)
    class function Wrap ({OU} PatchMaker: TPatchMaker): {OU} TPatchHelper; inline; static;

    function IsValidPos (Pos: integer): boolean; inline;
    function NormalizePos (Pos: integer): integer; inline;
    
    function WriteByte    (Value: byte):    TPatchHelper;
    function WriteWord    (Value: word):    TPatchHelper;
    function WriteTribyte (Value: integer): TPatchHelper;
    function WriteInt     (Value: integer): TPatchHelper;
    
    function WriteBytes (NumBytes: integer; {n} Buf: pointer): TPatchHelper; inline;
    function Write (const Args: array of const): TPatchHelper;
    function WriteHex (const HexStr: myAStr): TPatchHelper;
    function Seek (Pos: integer): TPatchHelper; inline;

    (* Seeks to relative position from the current one. Returns self. *)
    function SeekRel (RelPos: integer): TPatchHelper;

    function Alloc (NumBytes: integer): {Un} pointer; inline;

    (* Allocated block of bytes and seeks to block end. See {@Alloc} *)
    function AllocAndSkip (NumBytes: integer): {Un} pointer;

    function GetPosTempAddr (Pos: integer = CURRENT_POS): {Un} pointer; inline;
    function NewAutoLabel (out LabelName: myAStr): myAStr; inline;
    function PutLabel (const LabelName: myAStr): TPatchHelper; inline;
    function GetLabelPos (const LabelName: myAStr): integer; inline;
    function ExecActionOnApply ({O} Action: TPatchAction; Pos: integer = CURRENT_POS): {U} TPatchHelper; inline;
    function GetPatch: {O} UtilsB2.TArrayOfByte; inline;
    function ApplyPatch ({n} TargetAddr, {n} TargetRealAddr: pointer): {n} pointer; inline;
    function Clear: {U} TPatchHelper; inline;
    function Pos: integer; inline;
    function Size: integer; inline;

    (* Writes assembler instruction/s to jump to patch label position. Returns self. *)
    function JumpLabel (JumpType: TJumpType; const LabelName: myAStr): TPatchHelper;
    
    (* Writes assembler instruction/s to jump to patch buffer position. Returns self. *)
    function JumpPos (JumpType: TJumpType; Pos: integer): TPatchHelper;

    (* Writes assembler instruction/s to jump to specified real address. Returns self. *)
    function Jump (JumpType: TJumpType; {n} Addr: pointer): TPatchHelper;

    (* Writes assembler instruction/s to jump to specified real address. The code will be location independent (movable). Returns self. *)
    function JumpAbs (JumpType: TJumpType; {n} Addr: pointer): TPatchHelper;

    (* Writes assembler instruction/s to call routine at patch label position. Returns self. *)
    function CallLabel (const LabelName: myAStr): TPatchHelper;
    
    (* Writes assembler instruction/s to call routine at patch buffer position. Returns self. *)
    function CallPos (Pos: integer): TPatchHelper;

    (* Writes assembler instruction/s to call routine at specified real address. Returns self. *)
    function Call ({n} Addr: pointer): TPatchHelper;

    (* Writes assembler instruction/s to call routine at specified real address. The code will be location independent (movable). Returns self. *)
    function CallAbs ({n} Addr: pointer): TPatchHelper;

    (* Writes ret instruction/s, cleaning NumArgs dword stack arguments. Returns self. *)
    function Ret (NumArgs: integer = 0): TPatchHelper;
    
    (* Fills block of memory with byte value. Returns self. *)
    function FillBytes (NumBytes: integer; Value: byte): TPatchHelper;

    (* Writes sequentional nop instructions. Returns self. *)
    function Nop (NumNops: integer = 1): TPatchHelper;

    (* Pushes const32 to stack. Returns self. *)
    function PushConst32 (Value: integer): TPatchHelper;

    (* Allocates space and copies CPU instructions from source to patch buffer. Ensures, that all relative
       addresses will be valid after patch application. Pass OrigCodeAddr if code is not in its original location.
       Returns self. *)
    function WriteCode ({n} CodeAddr: pointer; CodeSizeDetector: ICodeSizeDetector; FixCodeFlags: integer = 0; OrigCodeAddr: pointer = nil): TPatchHelper;

    (* Frees and nils wrapped PatchMaker object *)
    procedure Release;
  end; // .record TPatchHelper


const
  (* Flags for TJumpTypeAssembly.Flags *)
  JUMP_TYPE_FLAG_NEAR  = 1;
  JUMP_TYPE_FLAG_SHORT = 2;

type
  (* Info, used to create near/short jump instructions, based on jump type *)
  TJumpTypeAssembly = record
    Opcode:     integer;
    OpcodeSize: integer;
    ArgSize:    integer;
    Flags:      integer;
  end;


  (* Returns true if given opcode is short JX[X] opcode *)
  function IsShortJumpConst8Opcode (Opcode: integer): boolean;
  
  (* Returns true if given opcode is near JX[X] opcode *)
  function IsNearJumpConst32Opcode (Opcode: integer): boolean;

  (* Tries to determine jump type from opcode. Returns false on failure. *)
  function GetJumpType (Opcode: integer; {OUT} var Res: TJumpType): boolean;

  (* Returns jump of the same type, but opposite condition. Example: JAE => JB. Unconditional jumps are returned as is. *)
  function GetNegativeJumpType (JumpType: TJumpType): TJumpType;
  
  (* Returns info record, necessary to assemble jump instruction, based on jump type *)
  function GetJumpAssembly (JumpType: TJumpType): TJumpTypeAssembly;
  
  (* Returns near version of jump for short jump and vice versa. Returns other jump types as is. *)
  function ConvertBetweenShortNearJump (JumpType: TJumpType): TJumpType;
  
  (* Converts jump type to near type, if possible *)
  function JumpTypeToNear (JumpType: TJumpType): TJumpType;
  
  (* Converts jump type to short type, if possible *)
  function JumpTypeToShort (JumpType: TJumpType): TJumpType;

  (* Increases block size so, that its last instruction could be copied as a whole, not partially. Returns new block size *)
  function GetCodeSize ({n} Code: pointer; MinCodeSize: integer = 1): integer;


const
  NEAR_JUMP_TYPES  = [JMP, JE, JNE, JA, JAE, JB, JBE, JG, JGE, JL, JLE, JO, JNO, JS, JNS, JP, JNP];
  SHORT_JUMP_TYPES = [JMP_SHORT, JE_SHORT, JNE_SHORT, JA_SHORT, JAE_SHORT, JB_SHORT, JBE_SHORT, JG_SHORT, JGE_SHORT, JL_SHORT, JLE_SHORT, JO_SHORT, JNO_SHORT, JS_SHORT, JNS_SHORT, JP_SHORT, JNP_SHORT];


(***)  implementation  (***)


const
  JumpTypeAssemblyMap: array [low(TJumpType)..high(TJumpType)] of TJumpTypeAssembly = (
    (Opcode: OPCODE_JMP_CONST32;      OpcodeSize: 1; ArgSize: sizeof(integer); Flags: JUMP_TYPE_FLAG_NEAR),
    (Opcode: OPCODE_JE_CONST32;       OpcodeSize: 2; ArgSize: sizeof(integer); Flags: JUMP_TYPE_FLAG_NEAR),
    (Opcode: OPCODE_JNE_CONST32;      OpcodeSize: 2; ArgSize: sizeof(integer); Flags: JUMP_TYPE_FLAG_NEAR),
    (Opcode: OPCODE_JA_CONST32;       OpcodeSize: 2; ArgSize: sizeof(integer); Flags: JUMP_TYPE_FLAG_NEAR),
    (Opcode: OPCODE_JAE_CONST32;      OpcodeSize: 2; ArgSize: sizeof(integer); Flags: JUMP_TYPE_FLAG_NEAR),
    (Opcode: OPCODE_JB_CONST32;       OpcodeSize: 2; ArgSize: sizeof(integer); Flags: JUMP_TYPE_FLAG_NEAR),
    (Opcode: OPCODE_JBE_CONST32;      OpcodeSize: 2; ArgSize: sizeof(integer); Flags: JUMP_TYPE_FLAG_NEAR),
    (Opcode: OPCODE_JG_CONST32;       OpcodeSize: 2; ArgSize: sizeof(integer); Flags: JUMP_TYPE_FLAG_NEAR),
    (Opcode: OPCODE_JGE_CONST32;      OpcodeSize: 2; ArgSize: sizeof(integer); Flags: JUMP_TYPE_FLAG_NEAR),
    (Opcode: OPCODE_JL_CONST32;       OpcodeSize: 2; ArgSize: sizeof(integer); Flags: JUMP_TYPE_FLAG_NEAR),
    (Opcode: OPCODE_JLE_CONST32;      OpcodeSize: 2; ArgSize: sizeof(integer); Flags: JUMP_TYPE_FLAG_NEAR),
    (Opcode: OPCODE_JO_CONST32;       OpcodeSize: 2; ArgSize: sizeof(integer); Flags: JUMP_TYPE_FLAG_NEAR),
    (Opcode: OPCODE_JNO_CONST32;      OpcodeSize: 2; ArgSize: sizeof(integer); Flags: JUMP_TYPE_FLAG_NEAR),
    (Opcode: OPCODE_JS_CONST32;       OpcodeSize: 2; ArgSize: sizeof(integer); Flags: JUMP_TYPE_FLAG_NEAR),
    (Opcode: OPCODE_JNS_CONST32;      OpcodeSize: 2; ArgSize: sizeof(integer); Flags: JUMP_TYPE_FLAG_NEAR),
    (Opcode: OPCODE_JP_CONST32;       OpcodeSize: 2; ArgSize: sizeof(integer); Flags: JUMP_TYPE_FLAG_NEAR),
    (Opcode: OPCODE_JNP_CONST32;      OpcodeSize: 2; ArgSize: sizeof(integer); Flags: JUMP_TYPE_FLAG_NEAR),
    (Opcode: OPCODE_JMP_SHORT_CONST8; OpcodeSize: 1; ArgSize: sizeof(shortint); Flags: JUMP_TYPE_FLAG_SHORT),
    (Opcode: OPCODE_JE_SHORT_CONST8;  OpcodeSize: 1; ArgSize: sizeof(shortint); Flags: JUMP_TYPE_FLAG_SHORT),
    (Opcode: OPCODE_JNE_SHORT_CONST8; OpcodeSize: 1; ArgSize: sizeof(shortint); Flags: JUMP_TYPE_FLAG_SHORT),
    (Opcode: OPCODE_JA_SHORT_CONST8;  OpcodeSize: 1; ArgSize: sizeof(shortint); Flags: JUMP_TYPE_FLAG_SHORT),
    (Opcode: OPCODE_JAE_SHORT_CONST8; OpcodeSize: 1; ArgSize: sizeof(shortint); Flags: JUMP_TYPE_FLAG_SHORT),
    (Opcode: OPCODE_JB_SHORT_CONST8;  OpcodeSize: 1; ArgSize: sizeof(shortint); Flags: JUMP_TYPE_FLAG_SHORT),
    (Opcode: OPCODE_JBE_SHORT_CONST8; OpcodeSize: 1; ArgSize: sizeof(shortint); Flags: JUMP_TYPE_FLAG_SHORT),
    (Opcode: OPCODE_JG_SHORT_CONST8;  OpcodeSize: 1; ArgSize: sizeof(shortint); Flags: JUMP_TYPE_FLAG_SHORT),
    (Opcode: OPCODE_JGE_SHORT_CONST8; OpcodeSize: 1; ArgSize: sizeof(shortint); Flags: JUMP_TYPE_FLAG_SHORT),
    (Opcode: OPCODE_JL_SHORT_CONST8;  OpcodeSize: 1; ArgSize: sizeof(shortint); Flags: JUMP_TYPE_FLAG_SHORT),
    (Opcode: OPCODE_JLE_SHORT_CONST8; OpcodeSize: 1; ArgSize: sizeof(shortint); Flags: JUMP_TYPE_FLAG_SHORT),
    (Opcode: OPCODE_JO_SHORT_CONST8;  OpcodeSize: 1; ArgSize: sizeof(shortint); Flags: JUMP_TYPE_FLAG_SHORT),
    (Opcode: OPCODE_JNO_SHORT_CONST8; OpcodeSize: 1; ArgSize: sizeof(shortint); Flags: JUMP_TYPE_FLAG_SHORT),
    (Opcode: OPCODE_JS_SHORT_CONST8;  OpcodeSize: 1; ArgSize: sizeof(shortint); Flags: JUMP_TYPE_FLAG_SHORT),
    (Opcode: OPCODE_JNS_SHORT_CONST8; OpcodeSize: 1; ArgSize: sizeof(shortint); Flags: JUMP_TYPE_FLAG_SHORT),
    (Opcode: OPCODE_JP_SHORT_CONST8;  OpcodeSize: 1; ArgSize: sizeof(shortint); Flags: JUMP_TYPE_FLAG_SHORT),
    (Opcode: OPCODE_JNP_SHORT_CONST8; OpcodeSize: 1; ArgSize: sizeof(shortint); Flags: JUMP_TYPE_FLAG_SHORT)
  ); // .JumpTypeAssemblyMap

  (* Map for easy conversion between near and short jump types *)
  BetweenShortNearJumpTypeMap: array [low(TJumpType)..high(TJumpType)] of TJumpType = (
    JMP_SHORT, JE_SHORT, JNE_SHORT, JA_SHORT, JAE_SHORT, JB_SHORT, JBE_SHORT, JG_SHORT, JGE_SHORT, JL_SHORT, JLE_SHORT, JO_SHORT, JNO_SHORT, JS_SHORT, JNS_SHORT, JP_SHORT, JNP_SHORT,
    JMP, JE, JNE, JA, JAE, JB, JBE, JG, JGE, JL, JLE, JO, JNO, JS, JNS, JP, JNP
  );

  (* Map of JumpType => NOT JumpType. Example: JA => JBE. Unconditional jumps map to themselves. *)
  NegativeJumpTypeMap: array [low(TJumpType)..high(TJumpType)] of TJumpType = (
    JMP, JNE, JE, JBE, JB, JAE, JA, JLE, JL, JGE, JG, JNO, JO, JNS, JS, JNP, JP,
    JMP_SHORT, JNE_SHORT, JE_SHORT, JBE_SHORT, JB_SHORT, JAE_SHORT, JA_SHORT, JLE_SHORT, JL_SHORT, JGE_SHORT, JG_SHORT, JNO_SHORT, JO_SHORT, JNS_SHORT, JS_SHORT, JNP_SHORT, JP_SHORT
  );

  (* Map of the first Opcode byte => short jump type (ensure, that higher bytes are zero) *)
  ShortCondJumpDecodeMap: array [$70..$7F] of TJumpType = (
    JO_SHORT, JNO_SHORT, JB_SHORT, JAE_SHORT, JE_SHORT, JNE_SHORT, JBE_SHORT, JA_SHORT, JS_SHORT, JNS_SHORT, JP_SHORT, JNP_SHORT, JL_SHORT, JGE_SHORT, JLE_SHORT, JG_SHORT
  );

  (* Map of the second Opcode byte => near jump type (the first opcode byte MUST BE $0F) *)
  NearCondJumpDecodeMap: array [$80..$8F] of TJumpType = (JO, JNO, JB, JAE, JE, JNE, JBE, JA, JS, JNS, JP, JNP, JL, JGE, JLE, JG);


function IsShortJumpConst8Opcode (Opcode: integer): boolean;
begin
  result := (Opcode = $EB) or Math.InRange(Opcode, low(ShortCondJumpDecodeMap), high(ShortCondJumpDecodeMap));
end;

function IsNearJumpConst32Opcode (Opcode: integer): boolean;
begin
  result := (Opcode = $E9) or (((Opcode and $FF) = $0F) and Math.InRange(Opcode shr 8, low(NearCondJumpDecodeMap), high(NearCondJumpDecodeMap)));
end;

function GetJumpType (Opcode: integer; {OUT} var Res: TJumpType): boolean;
begin
  result := false;

  if IsShortJumpConst8Opcode(Opcode) then begin
    result := true;

    if Opcode = OPCODE_JNP_SHORT_CONST8 then begin
      Res := JMP_SHORT;
    end else begin
      Res := ShortCondJumpDecodeMap[Opcode];
    end;
  end else if IsNearJumpConst32Opcode(Opcode) then begin
    result := true;

    if Opcode = OPCODE_JMP_CONST32 then begin
      Res := JMP;
    end else begin
      Res:= NearCondJumpDecodeMap[Opcode shr 8];
    end;
  end; // .elseif
end; // .function GetJumpType

function GetNegativeJumpType (JumpType: TJumpType): TJumpType;
begin
  result := NegativeJumpTypeMap[JumpType];
end;

function GetJumpAssembly (JumpType: TJumpType): TJumpTypeAssembly;
begin
  result := JumpTypeAssemblyMap[JumpType];
end;

function ConvertBetweenShortNearJump (JumpType: TJumpType): TJumpType;
begin
  result := BetweenShortNearJumpTypeMap[JumpType];
end;

function JumpTypeToNear (JumpType: TJumpType): TJumpType;
begin
  result := JumpType;

  if UtilsB2.Flags(GetJumpAssembly(JumpType).Flags).Have(JUMP_TYPE_FLAG_SHORT) then begin
    result := ConvertBetweenShortNearJump(result);
  end;
end;

function JumpTypeToShort (JumpType: TJumpType): TJumpType;
begin
  result := JumpType;

  if UtilsB2.Flags(GetJumpAssembly(JumpType).Flags).Have(JUMP_TYPE_FLAG_NEAR) then begin
    result := ConvertBetweenShortNearJump(result);
  end;
end;

function GetCodeSize ({n} Code: pointer; MinCodeSize: integer = 1): integer;
var
{n} InstrPtr: pbyte;
    Disasm:   hde32.TDisasm;

begin
  {!} Assert(UtilsB2.IsValidBuf(Code, MinCodeSize));
  InstrPtr := Code;
  // * * * * * //
  result := 0;

  while result < MinCodeSize do begin
    Disasm.Disassemble(InstrPtr);
    result := result + Disasm.Len;
    Inc(InstrPtr, Disasm.len);
  end;
end; // .function GetCodeSize

procedure TPatchAction._Execute ({n} ItemAddr, {n} RealItemAddr: pointer; ItemPos: integer; PatchMaker: {U} TPatchMaker);
begin
end;

procedure TPatchAction.Execute ({n} ItemAddr, {n} RealItemAddr: pointer; ItemPos: integer; PatchMaker: {U} TPatchMaker);
begin
  {!} Assert(PatchMaker <> nil);
  {!} Assert(UtilsB2.IsValidBuf(ItemAddr, PatchMaker.Size));
  {!} Assert(ItemPos >= 0);
  Self._Execute(ItemAddr, RealItemAddr, ItemPos, PatchMaker);
end;

constructor TPostponedAction.Create (Action: TPatchAction; Pos: integer);
begin
  {!} Assert(Action <> nil);
  {!} Assert(Pos >= 0);
  Self.fAction := Action;
  Self.fPos    := Pos;
end;

destructor TPostponedAction.Destroy;
begin
  SysUtils.FreeAndNil(Self.fAction);
end;

procedure TPostponedAction.Execute ({n} PatchBufAddr, {n} RealBufAddr: pointer; PatchMaker: TPatchMaker);
begin
  {!} Assert(UtilsB2.IsValidBuf(PatchBufAddr, PatchMaker.Size));
  {!} Assert(PatchMaker <> nil);
  Self.fAction.Execute(UtilsB2.PtrOfs(PatchBufAddr, Self.fPos), UtilsB2.PtrOfs(RealBufAddr, Self.fPos), Self.fPos, PatchMaker);
end;

constructor TPatchComplexAction.Create (const Actions: array of TPatchAction);
var
  i: integer;

begin
  Self.fActions := DataLib.NewList(UtilsB2.OWNS_ITEMS);
  Self.fActions.SetCapacity(Length(Actions));

  for i := 0 to high(Actions) do begin
    Self.fActions.Add(Actions[i]);
  end;
end; // .constructor TPatchComplexAction.Create

destructor TPatchComplexAction.Destroy;
begin
  SysUtils.FreeAndNil(Self.fActions);
end;

procedure TPatchComplexAction._Execute ({n} ItemAddr, {n} RealItemAddr: pointer; ItemPos: integer; PatchMaker: {U} TPatchMaker);
var
  i: integer;

begin
  for i := 0 to Self.fActions.Count - 1 do begin
    TPatchAction(Self.fActions[i]).Execute(ItemAddr, RealItemAddr, ItemPos, PatchMaker);
  end;
end;

procedure TAddRealAddrAction._Execute ({n} ItemAddr, {n} RealItemAddr: pointer; ItemPos: integer; PatchMaker: {U} TPatchMaker);
begin
  Inc(pinteger(ItemAddr)^, integer(RealItemAddr));
end;

procedure TAddRealAddrByteAction._Execute ({n} ItemAddr, {n} RealItemAddr: pointer; ItemPos: integer; PatchMaker: {U} TPatchMaker);
begin
  Inc(pbyte(ItemAddr)^, integer(RealItemAddr));
end;

procedure TSubRealAddrAction._Execute ({n} ItemAddr, {n} RealItemAddr: pointer; ItemPos: integer; PatchMaker: {U} TPatchMaker);
begin
  Dec(pinteger(ItemAddr)^, integer(RealItemAddr));
end;

procedure TSubRealAddrByteAction._Execute ({n} ItemAddr, {n} RealItemAddr: pointer; ItemPos: integer; PatchMaker: {U} TPatchMaker);
begin
  Dec(pbyte(ItemAddr)^, integer(RealItemAddr));
end;

procedure TAddPosAction._Execute ({n} ItemAddr, {n} RealItemAddr: pointer; ItemPos: integer; PatchMaker: {U} TPatchMaker);
begin
  Inc(pinteger(ItemAddr)^, ItemPos);
end;

procedure TSubPosAction._Execute ({n} ItemAddr, {n} RealItemAddr: pointer; ItemPos: integer; PatchMaker: {U} TPatchMaker);
begin
  Dec(pinteger(ItemAddr)^, ItemPos);
end;

constructor TAddLabelRealAddrAction.Create (const LabelName: myAStr);
begin
  // ItemRealAddr + (OFFSET to label = LabelPos - ItemPos)
  inherited Create([
    TAddRealAddrAction.Create(),
    TAddLabelPosAction.Create(LabelName),
    TSubPosAction.Create()
  ]);
end;

constructor TAddLabelPosAction.Create (const LabelName: myAStr);
begin
  Self.fLabelName := LabelName;
end;

procedure TAddLabelPosAction._Execute ({n} ItemAddr, {n} RealItemAddr: pointer; ItemPos: integer; PatchMaker: {U} TPatchMaker);
var
  LabelPos: integer;

begin
  LabelPos := PatchMaker.GetLabelPos(Self.fLabelName);
  {!} Assert(LabelPos >= 0, Format('Unresolved label "%s". Cannot apply action for position %d', [Self.fLabelName, ItemPos]));
  Inc(pinteger(ItemAddr)^, LabelPos);
end;

constructor TAddLabelPosByteAction.Create (const LabelName: myAStr);
begin
  Self.fLabelName := LabelName;
end;

procedure TAddLabelPosByteAction._Execute ({n} ItemAddr, {n} RealItemAddr: pointer; ItemPos: integer; PatchMaker: {U} TPatchMaker);
var
  LabelPos: integer;

begin
  LabelPos := PatchMaker.GetLabelPos(Self.fLabelName);
  {!} Assert(LabelPos >= 0, Format('Unresolved label "%s". Cannot apply action for position %d', [Self.fLabelName, ItemPos]));
  Inc(pbyte(ItemAddr)^, LabelPos);
end;

constructor TPatchMaker.Create;
begin
  Self.fPostponedActions := DataLib.NewList(UtilsB2.OWNS_ITEMS);
  Self.fLabels           := DataLib.NewDict(not UtilsB2.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  Self.fLabelAutoId      := 1;
end;

destructor TPatchMaker.Destroy;
begin
  SysUtils.FreeAndNil(Self.fPostponedActions);
  SysUtils.FreeAndNil(Self.fLabels);
  inherited;
end;

constructor TFixedCodeSizeDetector.Create (CodeSize: integer);
begin
  {!} Assert(CodeSize >= 0);
  Self.fCodeSize := CodeSize;
end;

function TFixedCodeSizeDetector.GetCodeSize ({n} CodePtr: pbyte): integer;
begin
  result := UtilsB2.IfThen(CodePtr <> nil, Self.fCodeSize, 0);
end;

constructor TMinCodeSizeDetector.Create (MinCodeSize: integer);
begin
  {!} Assert(MinCodeSize >= 0);
  Self.fMinCodeSize := MinCodeSize;
end;

function TMinCodeSizeDetector.GetCodeSize ({n} CodePtr: pbyte): integer;
begin
  result := 0;

  if (CodePtr <> nil) and (Self.fMinCodeSize > 0) then begin
    result := PatchForge.GetCodeSize(CodePtr, Self.fMinCodeSize);
  end;
end;

constructor TFuncCodeSizeDetector.Create (MaxCodeSize: integer = 1000000);
begin
  {!} Assert(MaxCodeSize >= 0);
  Self.fMaxCodeSize := MaxCodeSize;
end;

function TFuncCodeSizeDetector.GetCodeSize ({n} CodePtr: pbyte): integer;
var
{n} CmdPtr:   pbyte;
    Disasm:   hde32.TDisasm;
    RetFound: boolean;

begin
  CmdPtr := CodePtr;
  result := 0;

  if (CodePtr <> nil) and (Self.fMaxCodeSize > 0) then begin
    RetFound := false;

    while (result < Self.fMaxCodeSize) and not RetFound do begin
      Disasm.Disassemble(CmdPtr);

      if (Disasm.Opcode = OPCODE_RET) or (Disasm.Opcode = OPCODE_RET_CONST16) then begin
        RetFound := true;
      end;

      Inc(CmdPtr, Disasm.Len);
      Inc(result, Disasm.Len);
    end;

    {!} Assert(RetFound and (result <= Self.fMaxCodeSize), Format('Failed to find end of function at %x. Checked %d bytes', [integer(CodePtr), Self.fMaxCodeSize]));
  end; // .if
end; // .function TFuncCodeSizeDetector.GetCodeSize

function TPatchMaker.IsValidPos (Pos: integer): boolean;
begin
  result := Math.InRange(Pos, 0, Self.Size);
end;

function TPatchMaker.NormalizePos (Pos: integer): integer;
begin
  result := UtilsB2.IfThen(Pos = CURRENT_POS, Self.fPos, Pos);
  {!} Assert(Self.IsValidPos(result));
end;

procedure TPatchMaker.SetPos (NewPos: integer);
begin
  Self.Seek(NewPos);
end;

procedure TPatchMaker.Grow (NewSize: integer);
const
  MIN_FREE_SPACE           = 16;
  HEUR_MEMORY_MANAGER_LOAD = 32;

begin
  {!} Assert(NewSize > Length(Self.fBuf));

  SetLength(Self.fBuf, (1 shl Alg.IntLog2(NewSize + MIN_FREE_SPACE + HEUR_MEMORY_MANAGER_LOAD)) - HEUR_MEMORY_MANAGER_LOAD);
  Self.fSize := NewSize;
end;

function TPatchMaker.WriteBytes (NumBytes: integer; {n} Buf: pointer): {U} TPatchMaker;
begin
  result := Self;
  UtilsB2.CopyMem(NumBytes, Buf, Self.Alloc(NumBytes));
  Inc(Self.fPos, NumBytes);
end;

function TPatchMaker.Write (const Args: array of const): {U} TPatchMaker;
var
  FloatValue: single;
  NumArgs:    integer;
  Cmd:        IPatchCmd;
  i:          integer;

begin
  result  := Self;
  NumArgs := Length(Args);
  i       := 0;

  while i < NumArgs do begin
    with Args[i] do begin
      case vType of
        vtBoolean:    Self.WriteBytes(sizeof(vBoolean),                @vBoolean);
        vtInteger:    Self.WriteBytes(sizeof(vInteger),                @vInteger);
        vtChar:       Self.WriteBytes(sizeof(vChar),                   @vChar);
        vtWideChar:   Self.WriteBytes(sizeof(vWideChar),               @vWideChar);
        vtExtended:   begin FloatValue := vExtended^; Self.WriteBytes(sizeof(FloatValue), @FloatValue); end;
        vtString:     Self.WriteBytes(Length(vString^),                @vString^[1]);
        vtPointer:    Self.WriteBytes(sizeof(vPointer),                @vPointer);
        vtPChar:      Self.WriteBytes(sizeof(vPChar),                  @vPChar);
        vtPWideChar:  Self.WriteBytes(sizeof(myPWChar),               @vPWideChar);
        
        vtObject: begin
          if SysUtils.Supports(vObject, IPatchCmd, Cmd) then begin
            Cmd.Execute(Self);
          end else begin
            Self.WriteBytes(sizeof(vObject), @vObject);
          end;
        end;
        
        vtClass:      Self.WriteBytes(sizeof(vClass),                  @vClass);
        vtAnsiString: Self.WriteBytes(Length(myAStr(vAnsiString)),     vAnsiString);
        vtWideString: Self.WriteBytes(Length(myWStr(vWideString)), vWideString);
        vtInterface:  Self.WriteBytes(sizeof(vInterface),              @vInterface);
        vtInt64:      Self.WriteBytes(sizeof(vInt64),                  @vInt64);
      else
        {!} Assert(false, 'TPatchMaker.Write: unsupported vType: ' + Legacy.IntToStr(vType));
      end; // .case
    end; // .with

    Inc(i);
  end; // .while
end; // .function TPatchMaker.Write

function TPatchMaker.Seek (Pos: integer): {U} TPatchMaker;
begin
   Self.fPos := Self.NormalizePos(Pos);
   result    := Self;
end;

function TPatchMaker.Alloc (NumBytes: integer): {Un} pointer;
var
  NewSize: integer;

begin
  {!} Assert(NumBytes >= 0);

  NewSize := Self.Pos + NumBytes;

  if NewSize > Self.Size then begin
    if NewSize > Length(Self.fBuf) then begin
      Self.Grow(NewSize);
    end else begin
      Self.fSize := NewSize;
    end;
  end;

  result := @Self.fBuf[Self.Pos];
end; // .function TPatchMaker.Alloc

function TPatchMaker.GetPosTempAddr (Pos: integer = CURRENT_POS): {Un} pointer;
begin
  result := @Self.fBuf[Self.NormalizePos(Pos)];
end;

function TPatchMaker.NewAutoLabel (out LabelName: myAStr): myAStr;
begin
  result    := '`' + Legacy.IntToStr(Self.fLabelAutoId);
  LabelName := result;
  Inc(Self.fLabelAutoId);
end;

function TPatchMaker.PutLabel (const LabelName: myAStr): {U} TPatchMaker;
var
  LabelPos: integer;

begin
  result   := Self;
  LabelPos := integer(Self.fLabels[LabelName]) - 1;
  {!} Assert((LabelPos = -1) or (LabelPos = Self.Pos), Format('TPatchMaker: Label "%s" is already binded to %d position. Cannot reassign it to %d position', [LabelName, LabelPos, Self.Pos]));
  Self.fLabels[LabelName] := Ptr(Self.Pos + 1);
end;

function TPatchMaker.GetLabelPos (const LabelName: myAStr): integer;
begin
  result := integer(Self.fLabels[LabelName]) - 1;
end;

function TPatchMaker.ExecActionOnApply ({O} Action: TPatchAction; Pos: integer = CURRENT_POS): {U} TPatchMaker;
begin
  result := Self;
  Self.fPostponedActions.Add(TPostponedAction.Create(Action, Self.NormalizePos(Pos)));
end;

function TPatchMaker.GetPatch: {O} UtilsB2.TArrayOfByte;
begin
  result := Self.fBuf; Self.fBuf := nil;
  Self.Clear;
end;

procedure TPatchMaker.ExecPostponedActions ({n} TargetAddr, {n} TargetRealAddr: pointer);
var
  i: integer;

begin
  for i := 0 to Self.fPostponedActions.Count - 1 do begin
    TPostponedAction(Self.fPostponedActions[i]).Execute(TargetAddr, TargetRealAddr, Self);
  end;
end;

function TPatchMaker.ApplyPatch ({n} TargetAddr, {n} TargetRealAddr: pointer): {n} pointer;
begin
  {!} Assert(UtilsB2.IsValidBuf(TargetAddr, Self.Size));
  result := UtilsB2.PtrOfs(TargetAddr, Self.Size);
  // * * * * * //
  UtilsB2.CopyMem(Self.Size, pointer(Self.fBuf), TargetAddr);
  Self.ExecPostponedActions(TargetAddr, TargetRealAddr);
end;

function TPatchMaker.Clear: {U} TPatchMaker;
begin
  result            := Self;
  Self.fBuf         := nil;
  Self.fPos         := 0;
  Self.fSize        := 0;
  Self.fLabelAutoId := 1;
  Self.fPostponedActions.Clear;
  Self.fLabels.Clear;
end;

class function TPatchHelper.Wrap ({OU} PatchMaker: TPatchMaker): {OU} TPatchHelper;
begin
  result.PatchMaker := PatchMaker;
end;

function TPatchHelper.IsValidPos (Pos: integer): boolean;
begin
  result := Self.PatchMaker.IsValidPos(Pos);
end;

function TPatchHelper.NormalizePos (Pos: integer): integer;
begin
  result := Self.PatchMaker.NormalizePos(Pos);
end;

function TPatchHelper.WriteByte (Value: byte): TPatchHelper;
begin
  result := Self;
  pbyte(Self.AllocAndSkip(sizeof(byte)))^ := Value;
end;

function TPatchHelper.WriteWord (Value: word): TPatchHelper;
begin
  result := Self;
  pword(Self.AllocAndSkip(sizeof(word)))^ := Value;
end;

function TPatchHelper.WriteTribyte (Value: integer): TPatchHelper;
begin
  result := Self;

  with PTribyte(Self.AllocAndSkip(sizeof(TTribyte)))^ do begin
    pword(@Bytes[0])^ := word(Value);
    Bytes[2]          := Value shr 16;
  end;
end;

function TPatchHelper.WriteInt (Value: integer): TPatchHelper;
begin
  result := Self;
  pinteger(Self.AllocAndSkip(sizeof(integer)))^ := Value;
end;

function TPatchHelper.WriteBytes (NumBytes: integer; {n} Buf: pointer): TPatchHelper;
begin
  result := Self;
  Self.PatchMaker.WriteBytes(NumBytes, Buf);
end;

function TPatchHelper.Write (const Args: array of const): TPatchHelper;
begin
  result := Self;
  Self.PatchMaker.Write(Args);
end;

function TPatchHelper.WriteHex (const HexStr: myAStr): TPatchHelper;
const
  HEX_CHAR      = ['0'..'9', 'a'..'f', 'A'..'F'];
  HEX_CHAR_SIZE = 2;

var
{n} Buf:      pbyte;
    StrLen:   integer;
    i:        integer;
    LoChar:   myChar;
    HiChar:   myChar;
    HexToVal: array [0..2] of integer;

begin
  {!} Assert((Length(HexStr) and 1) = 0);
  result := Self;
  i      := 1;
  StrLen := Length(HexStr);
  Buf    := Self.AllocAndSkip(StrLen div HEX_CHAR_SIZE);

  HexToVal[0] := 48;
  HexToVal[1] := 55;
  HexToVal[2] := 87;

  while i <= StrLen do begin
    HiChar := HexStr[i];
    LoChar := HexStr[i + 1];
    {!} Assert((LoChar in HEX_CHAR) and (HiChar in HEX_CHAR), Legacy.Format('Invalid hex char "%s" at position %d', [Copy(HexStr, i, 2), i]));

    Buf^ := ((ord(HiChar) - HexToVal[ord(HiChar) shr 5 - 1]) shl 4) or (ord(LoChar) - HexToVal[ord(LoChar) shr 5 - 1]);
    Inc(i, HEX_CHAR_SIZE);
    Inc(Buf);
  end;
end; // .function WriteHex

function TPatchHelper.Seek (Pos: integer): TPatchHelper;
begin
  result := Self;
  Self.PatchMaker.Seek(Pos);
end;

function TPatchHelper.SeekRel (RelPos: integer): TPatchHelper;
begin
  result := Self.Seek(Self.Pos + RelPos);
end;

function TPatchHelper.Alloc (NumBytes: integer): {Un} pointer;
begin
  result := Self.PatchMaker.Alloc(NumBytes);
end;

function TPatchHelper.AllocAndSkip (NumBytes: integer): {Un} pointer;
begin
  result := Self.Alloc(NumBytes);
  Self.Seek(Self.Pos + NumBytes);
end;

function TPatchHelper.GetPosTempAddr (Pos: integer = CURRENT_POS): {Un} pointer;
begin
  result := Self.PatchMaker.GetPosTempAddr(Pos);
end;

function TPatchHelper.NewAutoLabel (out LabelName: myAStr): myAStr;
begin
  result := Self.PatchMaker.NewAutoLabel(LabelName);
end;

function TPatchHelper.PutLabel (const LabelName: myAStr): TPatchHelper;
begin
  result := Self;
  Self.PatchMaker.PutLabel(LabelName);
end;

function TPatchHelper.GetLabelPos (const LabelName: myAStr): integer;
begin
  result := Self.PatchMaker.GetLabelPos(LabelName);
end;

function TPatchHelper.ExecActionOnApply ({O} Action: TPatchAction; Pos: integer = CURRENT_POS): {U} TPatchHelper;
begin
  result := Self;
  Self.PatchMaker.ExecActionOnApply(Action, Pos);
end;

function TPatchHelper.GetPatch: {O} UtilsB2.TArrayOfByte;
begin
  result := Self.PatchMaker.GetPatch();
end;

function TPatchHelper.ApplyPatch ({n} TargetAddr, {n} TargetRealAddr: pointer): {n} pointer;
begin
  result := Self.PatchMaker.ApplyPatch(TargetAddr, TargetRealAddr);
end;

function TPatchHelper.Clear: {U} TPatchHelper;
begin
  result := Self;
  Self.PatchMaker.Clear;
end;

function TPatchHelper.Pos: integer;
begin
  result := Self.PatchMaker.Pos;
end;

function TPatchHelper.Size: integer;
begin
  result := Self.PatchMaker.Size;
end;

function TPatchHelper.JumpLabel (JumpType: TJumpType; const LabelName: myAStr): TPatchHelper;
var
  JumpAssembly: TJumpTypeAssembly;

begin
  JumpAssembly := GetJumpAssembly(JumpType);
  Self.WriteBytes(JumpAssembly.OpcodeSize, @JumpAssembly.Opcode);

  if JumpAssembly.ArgSize > 1 then begin
    Self.ExecActionOnApply(TAddLabelPosAction.Create(LabelName));
    result := Self.WriteInt(-Self.Pos - sizeof(PJumpCall32Rec(nil)^.Offset));
  end else begin
    Self.ExecActionOnApply(TAddLabelPosByteAction.Create(LabelName));
    result := Self.WriteByte(-Self.Pos - sizeof(PJumpCall8Rec(nil)^.Offset));
  end;
end; // .function TPatchHelper.JumpLabel

function TPatchHelper.JumpPos (JumpType: TJumpType; Pos: integer): TPatchHelper;
var
  JumpAssembly: TJumpTypeAssembly;
  Offset:       integer;

begin
  Pos          := Self.NormalizePos(Pos);
  JumpAssembly := GetJumpAssembly(JumpType);
  Self.WriteBytes(JumpAssembly.OpcodeSize, @JumpAssembly.Opcode);

  if JumpAssembly.ArgSize > 1 then begin
    result := Self.WriteInt(Pos - Self.Pos - sizeof(PJumpCall32Rec(nil)^.Offset));
  end else begin
    Offset := Pos - Self.Pos - sizeof(PJumpCall8Rec(nil)^.Offset);
    {!} Assert(Math.InRange(Offset, low(shortint), high(shortint)), Format('Cannot write short jump, offset is too high: %d', [Offset]));
    result := Self.WriteByte(Offset);
  end;
end; // .function TPatchHelper.JumpPos

function TPatchHelper.Jump (JumpType: TJumpType; {n} Addr: pointer): TPatchHelper;
var
  JumpAssembly: TJumpTypeAssembly;

begin
  JumpAssembly := GetJumpAssembly(JumpType);
  Self.WriteBytes(JumpAssembly.OpcodeSize, @JumpAssembly.Opcode);

  if JumpAssembly.ArgSize > 1 then begin
    Self.ExecActionOnApply(TSubRealAddrAction.Create);
    result := Self.WriteInt(integer(Addr) - sizeof(PJumpCall32Rec(nil)^.Offset));
  end else begin
    Self.ExecActionOnApply(TSubRealAddrByteAction.Create);
    result := Self.WriteByte(integer(Addr) - sizeof(PJumpCall8Rec(nil)^.Offset));
  end;
end; // .function TPatchHelper.Jump

function TPatchHelper.JumpAbs (JumpType: TJumpType; {n} Addr: pointer): TPatchHelper;
var
  JumpAssembly:    TJumpTypeAssembly;
  CondFailedLabel: myAStr;

begin
  result := Self;

  if (JumpType = JMP) or (JumpType = JMP_SHORT) then begin
    Self.WriteInt(INSTR_MOV_ESP_MIN_4_CONST32);
    Self.WriteInt(integer(Addr));
    Self.WriteInt(INSTR_JUMP_PTR_ESP_MIN_4);
  end else begin
    JumpAssembly := GetJumpAssembly(GetNegativeJumpType(JumpTypeToShort(JumpType)));
    Self.WriteBytes(JumpAssembly.OpcodeSize, @JumpAssembly.Opcode);
    Self.ExecActionOnApply(TAddLabelPosByteAction.Create(Self.NewAutoLabel(CondFailedLabel)));
    Self.WriteByte(-Self.Pos - sizeof(PJumpCall8Rec(nil)^.Offset));
    Self.JumpAbs(JMP, Addr);
    Self.PutLabel(CondFailedLabel);
  end; // .else
end; // .function TPatchHelper.JumpAbs

function TPatchHelper.CallLabel (const LabelName: myAStr): TPatchHelper;
begin
  result := Self;
  Self.WriteByte(OPCODE_CALL_CONST32);
  Self.ExecActionOnApply(TAddLabelPosAction.Create(LabelName));
  Self.WriteInt(-Self.Pos - sizeof(PJumpCall32Rec(nil)^.Offset));
end;

function TPatchHelper.CallPos (Pos: integer): TPatchHelper;
begin
  result := Self;
  Self.WriteByte(OPCODE_CALL_CONST32);
  Self.WriteInt(Self.NormalizePos(Pos) - Self.Pos - sizeof(PJumpCall32Rec(nil)^.Offset));
end;

function TPatchHelper.Call ({n} Addr: pointer): TPatchHelper;
begin
  result := Self;
  Self.WriteByte(OPCODE_CALL_CONST32);
  Self.ExecActionOnApply(TSubRealAddrAction.Create);
  Self.WriteInt(integer(Addr) - sizeof(PJumpCall32Rec(nil)^.Offset));
end;

function TPatchHelper.CallAbs ({n} Addr: pointer): TPatchHelper;
begin
  result := Self;
  Self.WriteInt(INSTR_MOV_ESP_MIN_4_CONST32);
  Self.WriteInt(integer(Addr));
  Self.WriteInt(INSTR_CALL_PTR_ESP_MIN_4);
end;

function TPatchHelper.Ret (NumArgs: integer = 0): TPatchHelper;
begin
  {!} Assert(NumArgs >= 0);
  result := Self.WriteByte(UtilsB2.IfThen(NumArgs = 0, OPCODE_RET, OPCODE_RET_CONST16));

  if NumArgs > 0 then begin
    Self.WriteWord(NumArgs * sizeof(integer));
  end;
end;

function TPatchHelper.FillBytes (NumBytes: integer; Value: byte): TPatchHelper;
begin
  {!} Assert(NumBytes >= 0);
  result := Self;

  if NumBytes > 0 then begin
    Legacy.FillChar(pbyte(Self.AllocAndSkip(NumBytes))^, NumBytes, Value);
  end;
end;

function TPatchHelper.Nop (NumNops: integer = 1): TPatchHelper;
begin
  result := Self.FillBytes(NumNops, OPCODE_NOP);
end;

function TPatchHelper.PushConst32 (Value: integer): TPatchHelper;
begin
  Self.WriteByte(OPCODE_PUSH_CONST32);
  result := Self.WriteInt(Value);
end;

function TPatchHelper.WriteCode ({n} CodeAddr: pointer; CodeSizeDetector: ICodeSizeDetector; FixCodeFlags: integer = 0; OrigCodeAddr: pointer = nil): TPatchHelper;
var
{n} CmdPtr:     pbyte;
{n} EndPtr:     pbyte;
    OrigCmdPtr: integer;
    OrigEndPtr: integer;
    CodeSize:   integer;
    Disasm:     hde32.TDisasm;

TYPE
  TAddrDedication = (FOR_JUMP, FOR_CALL);

  (* Returns true if address points to original block of code. For jump instructions the EOF is considered
     local, while for calls EOF is considered external procedure location. *)
  function IsOrigLocalAddr (Addr: integer; AddrDedication: TAddrDedication): boolean;
  begin
    if AddrDedication = FOR_JUMP then begin
      result := (Addr >= OrigCmdPtr) and (Addr <= OrigEndPtr);
    end else begin
      result := (Addr >= OrigCmdPtr) and (Addr < OrigEndPtr);
    end;
  end;

  procedure HandleCallConst32 (CmdPtr: pointer; OrigCmdPtr: integer);
  var
    CallTargetAddr: integer;

  begin
    CallTargetAddr := OrigCmdPtr + sizeof(TJumpCall32Rec) + pinteger(integer(CmdPtr) + Disasm.PrefixedOpcodeSize)^;

    if not IsOrigLocalAddr(CallTargetAddr, FOR_CALL) then begin
      if UtilsB2.Flags(FixCodeFlags).Have(FIX_CODE_MAKE_MOVABLE) then begin
        Self.CallAbs(Ptr(CallTargetAddr));
      end else begin
        Self.Call(Ptr(CallTargetAddr));
      end;
    end else begin
      Self.WriteBytes(Disasm.Len, CmdPtr);
    end;
  end; // .procedure HandleCallConst32

  procedure HandleJumpConst (CmdPtr: pointer; OrigCmdPtr: integer);
  var
    JumpTargetAddr: integer;
    JumpType:       TJumpType;

  begin
    if IsShortJumpConst8Opcode(Disasm.Opcode) then begin
      JumpTargetAddr := OrigCmdPtr + Disasm.PrefixedOpcodeSize + sizeof(PJumpCall8Rec(nil)^.Offset) + pshortint(integer(CmdPtr) + Disasm.PrefixedOpcodeSize)^;
    end else begin
      JumpTargetAddr := OrigCmdPtr + Disasm.PrefixedOpcodeSize + sizeof(PJumpCall32Rec(nil)^.Offset) + pinteger(integer(CmdPtr) + Disasm.PrefixedOpcodeSize)^;
    end;

    if not IsOrigLocalAddr(JumpTargetAddr, FOR_JUMP) then begin
      if not GetJumpType(Disasm.Opcode, JumpType) then begin
        Assert(false, Format('Failed to get jump type for opcode: %x', [Disasm.Opcode]));
      end;

      if UtilsB2.Flags(FixCodeFlags).Have(FIX_CODE_MAKE_MOVABLE) then begin
        Self.JumpAbs(JumpType, Ptr(JumpTargetAddr));
      end else begin
        Self.Jump(JumpTypeToNear(JumpType), Ptr(JumpTargetAddr));
      end;
    end else begin
      Self.WriteBytes(Disasm.Len, CmdPtr);
    end; // .else
  end; // .procedure HandleJumpConst

begin
  {!} Assert(CodeSizeDetector <> nil);
  {!} Assert(not UtilsB2.Flags(FixCodeFlags).Have(FIX_CODE_SAME_SIZE) or not UtilsB2.Flags(FixCodeFlags).Have(FIX_CODE_MAKE_MOVABLE), 'FIX_CODE_SAME_SIZE and FIX_CODE_MAKE_MOVABLE flags cannot be used at the same time');
  CmdPtr := nil;
  EndPtr := nil;
  result := Self;
  // * * * * * //
  CodeSize := CodeSizeDetector.GetCodeSize(CodeAddr);

  if CodeSize > 0 then begin
    // Code is in its original location
    if OrigCodeAddr = nil then begin
      OrigCodeAddr := CodeAddr;
    end;

    // Prepare pointers to disassemble and analyse code 
    CmdPtr     := pointer(CodeAddr);
    EndPtr     := UtilsB2.PtrOfs(CmdPtr, CodeSize);
    OrigCmdPtr := integer(OrigCodeAddr);
    OrigEndPtr := OrigCmdPtr + CodeSize;

    while cardinal(CmdPtr) < cardinal(EndPtr) do begin
      Disasm.Disassemble(CmdPtr);

      if Disasm.Opcode = OPCODE_CALL_CONST32 then begin
        HandleCallConst32(CmdPtr, OrigCmdPtr);
      end else if IsNearJumpConst32Opcode(Disasm.Opcode) or (IsShortJumpConst8Opcode(Disasm.Opcode) and not UtilsB2.Flags(FixCodeFlags).Have(FIX_CODE_SAME_SIZE)) then begin
        HandleJumpConst(CmdPtr, OrigCmdPtr);
      end else begin
        Self.WriteBytes(Disasm.Len, CmdPtr);
      end;

      Inc(CmdPtr, Disasm.Len);
      Inc(OrigCmdPtr, Disasm.Len);
    end; // .while
  end; // .if
end; // .function TPatchHelper.WriteCode

procedure TPatchHelper.Release;
begin
  SysUtils.FreeAndNil(Self.PatchMaker);
end;

end.