unit ApiJack;
(*
  Description: Code/data patching utilities and API hooking.
               All hooks are thread-safe.
*)

// D2006      --> XE11.0
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
  Legacy, Windows, Math,
  UtilsB2, PatchForge;

type
  TCallingConv = (
    CONV_LAST = -101,

    // Left-to-right
    CONV_PASCAL = CONV_LAST,

    // Left-to-right, first three arguments in EAX, EDX, ECX
    CONV_REGISTER = -102,

    // Right-to-left, caller clean-up
    CONV_CDECL = -103,

    // Right-to-left
    CONV_STDCALL = -104,

    // Right-to-left, first argument in ECX
    CONV_THISCALL = -105,

    // Right-to-left, first two arguments in ECX, EDX
    CONV_FASTCALL = -106,

    CONV_FIRST = CONV_FASTCALL
  ); // TCallingConv

  PAppliedPatch = ^TAppliedPatch;
  TAppliedPatch = record
         Addr:   pointer;
         Bytes:  UtilsB2.TArrayOfByte;
    {OU} AuxBuf: pointer;

    procedure Rollback;
  end;

  PHookContext = ^THookContext;

  THookContext = packed record
    EDI, ESI, EBP, ESP, EBX, EDX, ECX, EAX: integer;
    RetAddr:                                pointer;
  end;

  THookHandler = function (Context: PHookContext): LONGBOOL;

  (* Writes arbitrary data to any write-protected section *)
  TWriteAtCode = function (NumBytes: integer; {n} Src, {n} Dst: pointer): boolean; stdcall;


(* Replaces original function with the new one with the same prototype and 1-2 extra arguments.
   Calling convention is changed to STDCALL. The new argument is callable pointer, which can be used to
   execute original function. The pointer is passed as THE FIRST argument. If custom parameter address
   is given, the value of custom parameter will be passed to handler as THE SECOND argument. If AppliedPatch
   pointer is given, it will be assigned an opaque pointer to applied patch data structure. This
   pointer can be used to rollback the patch (remove splicing).
   Returns address of the bridge to original function *)
function StdSplice (OrigFunc, HandlerFunc: pointer; CallingConv: TCallingConv; NumArgs: integer; {n} CustomParam: pinteger = nil; {n} AppliedPatch: PAppliedPatch = nil): pointer;

(* Writes call to user handler at specified location. If handler returns true, overwritten commands are executed
   in original way. Otherwise they are skipped and Context.RetAddr is used to determine return address. *)
function HookCode (Addr: pointer; HandlerFunc: THookHandler; {n} AppliedPatch: PAppliedPatch = nil): pointer;

(* Installs new code writing routine. Returns the previous one or nil *)
function SetCodeWriter (CodeWriter: TWriteAtCode): {n} TWriteAtCode;


(***)  implementation  (***)


type
  (* Import *)
  TPatchMaker  = PatchForge.TPatchMaker;
  TPatchHelper = PatchForge.TPatchHelper;


var
  WriteAtCode: TWriteAtCode = nil;

procedure AllocMem (var Addr; Size: integer);
begin
  {!} Assert(@Addr <> nil);
  {!} Assert(Size >= 0);
  GetMem(pointer(Addr), Size);
end;

procedure ReleaseMem (Addr: pointer);
begin
  FreeMem(Addr);
end;

function SetCodeWriter (CodeWriter: TWriteAtCode): {n} TWriteAtCode;
begin
  {!} Assert(@CodeWriter <> nil);
  result      := WriteAtCode;
  WriteAtCode := CodeWriter;
end;

(* Writes arbitrary data to any write-protected section *)
function StdWriteAtCode (NumBytes: integer; {n} Src, {n} Dst: pointer): boolean; stdcall;
var
  OldPageProtect: integer;

begin
  {!} Assert(UtilsB2.IsValidBuf(Src, NumBytes));
  {!} Assert(UtilsB2.IsValidBuf(Dst, NumBytes));
  result := NumBytes = 0;

  if not result then begin
    try
      result := Windows.VirtualProtect(Dst, NumBytes, Windows.PAGE_EXECUTE_READWRITE, @OldPageProtect);

      if result then begin
        UtilsB2.CopyMem(NumBytes, Src, Dst);
        Windows.VirtualProtect(Dst, NumBytes, OldPageProtect, @OldPageProtect);
      end;
    except
      result := false;
    end;
  end; // .if
end; // .function StdWriteAtCode

(* Writes patch to any write-protected section *)
function WritePatchAtCode (PatchMaker: TPatchMaker; {n} Dst: pointer): boolean;
var
  Buf: UtilsB2.TArrayOfByte;

begin
  {!} Assert(PatchMaker <> nil);
  {!} Assert((Dst <> nil) or (PatchMaker.Size = 0));
  // * * * * * //
  result := true;

  if PatchMaker.Size > 0 then begin
    SetLength(Buf, PatchMaker.Size);
    PatchMaker.ApplyPatch(pointer(Buf), Dst);
    result := WriteAtCode(Length(Buf), pointer(Buf), Dst);
  end;
end; // .function WritePatchAtCode

function StdSplice (OrigFunc, HandlerFunc: pointer; CallingConv: TCallingConv; NumArgs: integer; {n} CustomParam: pinteger = nil; {n} AppliedPatch: PAppliedPatch = nil): pointer;
const
  CODE_ADDR_ALIGNMENT = 8;

var
{O}  p:                      PatchForge.TPatchHelper;
{OI} SpliceBridge:           pbyte; // Memory is owned by AppliedPatch or never freed
     NumStackArgs:           integer;
     ShouldDuplicateArgs:    boolean;
     OrigCodeBridgeStartPos: integer;
     OverwrittenCodeSize:    integer;

begin
  {!} Assert(OrigFunc <> nil);
  {!} Assert(HandlerFunc <> nil);
  {!} Assert(NumArgs >= 0);
  p            := TPatchHelper.Wrap(TPatchMaker.Create);
  SpliceBridge := nil;
  result       := nil;
  // * * * * * //
  if NumArgs = 0 then begin
    CallingConv := CONV_STDCALL;
  end;

  if (NumArgs = 1) and (CallingConv = CONV_FASTCALL) then begin
    CallingConv := CONV_THISCALL;
  end;

  NumStackArgs := NumArgs;

  if CallingConv = CONV_FASTCALL then begin
    Dec(NumStackArgs, 2);
  end else if CallingConv = CONV_THISCALL then begin
    Dec(NumStackArgs);
  end else if CallingConv = CONV_REGISTER then begin
    Dec(NumStackArgs, Min(3, NumArgs));
  end;

  ShouldDuplicateArgs := (NumStackArgs > 0) and ((CallingConv = CONV_PASCAL) or (CallingConv = CONV_REGISTER) or (CallingConv = CONV_CDECL));

  // === BEGIN generating SpliceBridge ===
  if ShouldDuplicateArgs then begin
    (* Prepare to duplicate arguments *)
    //   PUSH ESI
    //   PUSH EDI
    //   LEA ESI, [ESP + 12.]
    //   MOV EDI, ESI
    //   ADD ESI, NumStackArgs * 4
    p.WriteHex(myAStr('56578D74E40C89F781C6')).WriteInt(NumStackArgs * sizeof(integer));
  end;

  (* Push pascal/delphi register arguments and extra arguments *)
  if (CallingConv = CONV_PASCAL) or (CallingConv = CONV_REGISTER) then begin
    // PUSH OrigFuncBridge
    p.WriteByte($68).ExecActionOnApply(PatchForge.TAddLabelRealAddrAction.Create('OrigFuncBridge')).WriteInt(0);

    if CustomParam <> nil then begin
      // PUSH CustomParam
      p.WriteByte($68).WriteInt(CustomParam^);
    end;

    if CallingConv = CONV_REGISTER then begin
      // PUSH EAX
      p.WriteByte($50);

      if NumArgs >= 2 then begin
        // PUSH EDX
        p.WriteByte($52);
      end;

      if NumArgs >= 3 then begin
        // PUSH ECX
        p.WriteByte($51);
      end;
    end; // .if
  end; // .if

  if ShouldDuplicateArgs then begin
    (* Duplicate stack arguments *)
    // @Loop:
    //   SUB ESI, 4
    //   PUSH [DWORD ESI]
    //   CMP ESI, EDI
    //   JNE @Loop
    p.PutLabel('LoopCopyArgs').WriteHex(myAStr('83EE04FF3639FE'));
    p.JumpLabel(PatchForge.JNE, 'LoopCopyArgs');
  end;

  if not ShouldDuplicateArgs then begin
    // POP EAX; remember return address
    p.WriteByte($58);
  end;

  (* Push register arguments and extra parameters for right-to-left conventions *)
  if CallingConv = CONV_THISCALL then begin
    // PUSH ECX
    p.WriteByte($51);
  end else if CallingConv = CONV_FASTCALL then begin
    // PUSH EDX
    p.WriteByte($52);
    // PUSH ECX
    p.WriteByte($51);
  end;

  if (CallingConv <> CONV_PASCAL) and (CallingConv <> CONV_REGISTER) then begin
    if CustomParam <> nil then begin
      // PUSH CustomParam
      p.WriteByte($68).WriteInt(CustomParam^);
    end;

    // PUSH OrigFuncBridge
    p.WriteByte($68).ExecActionOnApply(PatchForge.TAddLabelRealAddrAction.Create('OrigFuncBridge')).WriteInt(0);
  end;

  if ShouldDuplicateArgs then begin
    // Call new handler
    p.Call(HandlerFunc);

    // POP EDI
    // POP ESI
    p.WriteWord($5E5F);

    // Perform stack cleanup for non-cdecl
    if CallingConv <> CONV_CDECL then begin
      // RET NumStackArgs * 4
      {!} Assert(NumStackArgs <= high(word), 'Too big number of stack arguments');
      p.WriteByte($C2).WriteWord(NumStackArgs * 4);
    end else begin
      // RET; original function will perform stack cleanup manually
      p.WriteByte($C3);
    end;
  end else begin
    // PUSH EAX; push return address
    p.WriteByte($50);

    // Jump to new handler, the return will lead to original calling function
    p.Jump(PatchForge.JMP, HandlerFunc);
  end; // .else

  // Ensure original code bridge is aligned
  p.Nop(p.Pos mod CODE_ADDR_ALIGNMENT);

  // Set result to offset from splice bridge start to original function bridge
  result := pointer(p.Pos);

  // Write original function bridge
  p.PutLabel('OrigFuncBridge');
  OrigCodeBridgeStartPos := p.Pos;
  p.WriteCode(OrigFunc, PatchForge.TMinCodeSizeDetector.Create(sizeof(PatchForge.TJumpCall32Rec)));
  OverwrittenCodeSize := p.Pos - OrigCodeBridgeStartPos;
  p.Jump(PatchForge.JMP, UtilsB2.PtrOfs(OrigFunc, OverwrittenCodeSize));
  // === END generating SpliceBridge ===

  // Persist splice bridge
  AllocMem(SpliceBridge, p.Size);
  WritePatchAtCode(p.PatchMaker, SpliceBridge);

  // Turn result from offset to absolute address
  result := Ptr(integer(SpliceBridge) + integer(result));

  // Create and apply hook at target function start
  p.Clear();
  p.Jump(PatchForge.JMP, SpliceBridge);
  p.Nop(OverwrittenCodeSize - p.Pos);

  if AppliedPatch <> nil then begin
    AppliedPatch.Addr := OrigFunc;
    SetLength(AppliedPatch.Bytes, p.Size);
    UtilsB2.CopyMem(p.Size, OrigFunc, @AppliedPatch.Bytes[0]);
    AppliedPatch.AuxBuf := SpliceBridge;
  end;

  WritePatchAtCode(p.PatchMaker, OrigFunc);
  // * * * * * //
  p.Release;
end; // .function StdSplice

function HookCode (Addr: pointer; HandlerFunc: THookHandler; {n} AppliedPatch: PAppliedPatch = nil): pointer;
const
  INSTR_PUSHAD       = $60;
  INSTR_PUSH_ESP     = $54;
  INSTR_TEST_EAX_EAX = $C085;
  INSTR_POPAD        = $61;
  INSTR_ADD_ESP_4    = $04C483;


var
{O}  p:                      PatchForge.TPatchHelper;
{OI} HandlerBridge:          pbyte; // Memory is owned by AppliedPatch or never freed
     DontExecOrigCodeLabel:  myAStr;
     OverwrittenCodeSize:    integer;

begin
  {!} Assert(Addr <> nil);
  {!} Assert(@HandlerFunc <> nil);
  p             := TPatchHelper.Wrap(TPatchMaker.Create);
  HandlerBridge := nil;
  result        := nil;
  // * * * * * //

  // === BEGIN generating HandlerBridge ===
  // Preserve registers and Push registers context as the only argument
  p.WriteByte(INSTR_PUSHAD);
  p.WriteByte(INSTR_PUSH_ESP);

  // Call new handler
  p.Call(@HandlerFunc);

  // If result is TRUE then restore registers and execute default code
  p.WriteWord(INSTR_TEST_EAX_EAX);
  p.JumpLabel(PatchForge.JE, p.NewAutoLabel(DontExecOrigCodeLabel));
  p.WriteByte(INSTR_POPAD);
  p.WriteTribyte(INSTR_ADD_ESP_4);

  // Set result to offset from handler bridge start to original code bridge
  result := pointer(p.Pos);

  // Write original code bridge
  OverwrittenCodeSize    := PatchForge.GetCodeSize(Addr, sizeof(PatchForge.TJumpCall32Rec));
  p.WriteCode(Addr, PatchForge.TFixedCodeSizeDetector.Create(OverwrittenCodeSize));
  p.Jump(PatchForge.JMP, UtilsB2.PtrOfs(Addr, OverwrittenCodeSize));

  // :DontExecOrigCodeLabel
  p.PutLabel(DontExecOrigCodeLabel);
  p.WriteByte(INSTR_POPAD);
  p.WriteByte(PatchForge.OPCODE_RET);
  // === END generating HandlerBridge ===

  // Persist handler bridge
  AllocMem(HandlerBridge, p.Size);
  WritePatchAtCode(p.PatchMaker, HandlerBridge);

  // Turn result from offset to absolute address
  result := Ptr(integer(HandlerBridge) + integer(result));

  // Create and apply hook at target address
  p.Clear();
  p.Call(HandlerBridge);
  p.Nop(OverwrittenCodeSize - p.Pos);

  if AppliedPatch <> nil then begin
    AppliedPatch.Addr   := Addr;
    SetLength(AppliedPatch.Bytes, p.Size);
    UtilsB2.CopyMem(p.Size, Addr, @AppliedPatch.Bytes[0]);
    AppliedPatch.AuxBuf := HandlerBridge;
  end;

  WritePatchAtCode(p.PatchMaker, Addr);
  // * * * * * //
  p.Release;
end; // .function HookCode

procedure TAppliedPatch.Rollback;
begin
  if Self.Bytes <> nil then begin
    WriteAtCode(Length(Self.Bytes), @Self.Bytes[0], Self.Addr);
    Self.Bytes := nil;

    if Self.AuxBuf <> nil then begin
      ReleaseMem(Self.AuxBuf); Self.AuxBuf := nil;
    end;
  end;
end;

begin
  WriteAtCode := StdWriteAtCode;
end.