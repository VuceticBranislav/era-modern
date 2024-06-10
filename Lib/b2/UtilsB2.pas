unit UtilsB2;
{
DESCRIPTION:  Addition to System unit
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

{$ASSERTIONS ON}

(***)  interface  (***)
uses Math, SysUtils, Windows, Legacy;

const
  (* Relations between containers and their items *)
  OWNS_ITEMS        = TRUE;
  ITEMS_ARE_OBJECTS = TRUE;

  (* Items guards *)
  ALLOW_NIL     = TRUE;
  NO_TYPEGUARD  = nil;

  (* For any bit-flags: no flags at all is 0 *)
  NO_FLAGS = 0;


type

  int  = integer;
  uint = cardinal;

  (* Item pointers *)
  pobject   = ^TObject;
  pclass    = ^TClass;
  PCharByte = ^myChar;
  plongbool = ^LONGBOOL;

  (* Array pointers *)
  TEndlessByteArr       = array [0..MAXLONGINT div sizeof(byte) - 1] of byte;
  PEndlessByteArr       = ^TEndlessByteArr;
  TEndlessWordArr       = array [0..MAXLONGINT div sizeof(word) - 1] of word;
  PEndlessWordArr       = ^TEndlessWordArr;
  TEndlessIntArr        = array [0..MAXLONGINT div sizeof(integer) - 1] of integer;
  PEndlessIntArr        = ^TEndlessIntArr;
  TEndlessSmallIntArr   = array [0..MAXLONGINT div sizeof(smallint) - 1] of smallint;
  PEndlessSmallIntArr   = ^TEndlessSmallIntArr;
  TEndlessShortIntArr   = array [0..MAXLONGINT div sizeof(shortint) - 1] of shortint;
  PEndlessShortIntArr   = ^TEndlessShortIntArr;
  TEndlessBoolArr       = array [0..MAXLONGINT div sizeof(boolean) - 1] of boolean;
  PEndlessBoolArr       = ^TEndlessBoolArr;
  TEndlessCharArr       = array [0..MAXLONGINT div sizeof(myChar) - 1] of myChar;
  PEndlessCharArr       = ^TEndlessCharArr;
  TEndlessWideCharArr   = array [0..MAXLONGINT div sizeof(myWChar) - 1] of myWChar;
  PEndlessWideCharArr   = ^TEndlessWideCharArr;
  TEndlessSingleArr     = array [0..MAXLONGINT div sizeof(single) - 1] of single;
  PEndlessSingleArr     = ^TEndlessSingleArr;
  TEndlessExtArr        = array [0..MAXLONGINT div sizeof(extended) - 1] of extended;
  PEndlessExtArr        = ^TEndlessExtArr;
  TEndlessShortStrArr   = array [0..MAXLONGINT div sizeof(ShortString) - 1] of ShortString;
  PEndlessShortStrArr   = ^TEndlessShortStrArr;
  TEndlessPtrArr        = array [0..MAXLONGINT div sizeof(pointer) - 1] of pointer;
  PEndlessPtrArr        = ^TEndlessPtrArr;
  TEndlessPCharArr      = array [0..MAXLONGINT div sizeof(myPChar) - 1] of myPChar;
  PEndlessPCharArr      = ^TEndlessPCharArr;
  TEndlessPWideCharArr  = array [0..MAXLONGINT div sizeof(myPWChar) - 1] of myPWChar;
  PEndlessPWideCharArr  = ^TEndlessPWideCharArr;
  TEndlessObjArr        = array [0..MAXLONGINT div sizeof(TObject) - 1] of TObject;
  PEndlessObjArr        = ^TEndlessObjArr;
  TEndlessCurrArr       = array [0..MAXLONGINT div sizeof(currency) - 1] of currency;
  PEndlessCurrArr       = ^TEndlessCurrArr;
  TEndlessAnsiStrArr    = array [0..MAXLONGINT div sizeof(AnsiString) - 1] of AnsiString;
  PEndlessAnsiStrArr    = ^TEndlessAnsiStrArr;

  TArrayOfByte     = array of byte;
  TArrayOfInt      = array of integer;
  TArrayOfStr      = array of myAStr;
  TArrayOfWideChar = array of myWChar;

  TCharSet  = set of myChar;

  TEmptyRec = packed record end;

  TProcedure    = procedure;
  TObjProcedure = procedure of object;

  TCloneable  = class
    procedure Assign (Source: TCloneable); virtual;
    function  Clone: TCloneable;
  end; // .class TCloneable

  (* Containers items guards *)
  TItemGuard      = TCloneable;
  TItemGuardProc  = function ({n} Item: pointer; ItemIsObject: boolean; {n} Guard: TCloneable): boolean;

  TDefItemGuard = class (TCloneable)
    ItemType: TClass;
    AllowNil: boolean;

    procedure Assign (Source: TCloneable); override;
  end; // .class TDefItemGuard

  TEventHandler = procedure ({n} Msg: TObject) of object;

  (* Any Delphi's interface implementation, capable to be converted back to object *)
  IGetSelf = interface ['{96F10D1D-56EE-4997-BFE3-645D12ED24F9}']
    (* Fastest and reliable way to convert interface to object *)
    function GetSelf: TObject;
  end;

  TInterfaceAwareObject = class;

  IObjInterface = interface ['{DFB594D8-CCAF-40F3-985C-6C5C50A0A16B}']
    (* Converts interface to TInterfaceAwareObject, increasing RefCount and preserving all interface references.
       If HasMainOwner() is true, an exception will be thrown. *)
    function BecomeMainOwner: {O} TInterfaceAwareObject;

    (* Returns true if object has main owner in the form of regular object pointer *)
    function HasMainOwner: boolean;

    (* Fastest and reliable way to convert interface to object *)
    function GetSelf: TInterfaceAwareObject;
  end;

  (* Improved System.TInterfacedObject class, capable to be converted from interface back to raw object
     pointer. Has 0 ref count after construction and is totally interface driven, unless _AddRef is called. *)
  TInterfaceAwareObject = class (System.TInterfacedObject, IObjInterface)
   protected
    fHasMainOwner: integer;

   public
    procedure AfterConstruction; override;
    procedure BeforeDestruction; override;

    (* Makes object fully managable via interfaces only if HasMainOwner() is true. Raw object pointer must not be used afterwards *)
    procedure ReleaseMainOwnage;

    function GetSelf: TInterfaceAwareObject;
    function HasMainOwner: boolean;
    function BecomeMainOwner: {O} TInterfaceAwareObject;
  end; // .class TInterfaceAwareObject

  (* Object must be accessible via interface reference only and cannot be Freed manually by default. *)
  TManagedObject = class (TInterfaceAwareObject)
   public
    procedure AfterConstruction; override;
  end;

  (* Set of bits/flags, stored in integer. Fast wrapper with easy to write and understand methods *)
  TFlags = record
   private
    Flags: integer;

   public
    (* Check if all bits from CombinedFlag are set in flags *)
    function Have (CombinedFlag: integer): boolean; inline;

    (* Check if any bit from CombinedFlag is set in flags *)
    function HaveAny (CombinedFlag: integer): boolean; inline;

    (* Check if at least single bit from CombinedFlag is not set in flags *)
    function DontHave (CombinedFlag: integer): boolean; inline;

    (* Check if at all bits from CombinedFlag are not set in flags *)
    function DontHaveAny (CombinedFlag: integer): boolean; inline;

    (* If all bits from WhatCombinedFlag are set, unsets them, sets all bits from WithCombinedFlag. Returns new TFlags structure *)
    function Replace (WhatCombinedFlag, WithCombinedFlag: integer): TFlags; inline;

    (* Sets all bits from CombinedFlag. Same as OR operator. Returns new TFlags structure *)
    function Include (CombinedFlag: integer): TFlags; inline;

    (* Unsets all bits from CombinedFlag. Same as AND NOT operator. Returns new TFlags structure *)
    function Exclude (CombinedFlag: integer): TFlags; inline;

    (* Return flags value as integer *)
    function GetValue: integer; inline;
  end; // TFlags

  (* Fast wrapper over bit-flags integer, allowing to modify integer in place, unlike TFlags*)
  TFlagsChanger = record
   private
    FlagsPtr: pinteger;

   public
    (* If all bits from WhatCombinedFlag are set, unsets them, sets all bits from WithCombinedFlag. Returns self *)
    function Replace (WhatCombinedFlag, WithCombinedFlag: integer): TFlagsChanger; inline;

    (* Sets all bits from CombinedFlag. Same as OR operator. Returns self *)
    function Include (CombinedFlag: integer): TFlagsChanger; inline;

    (* Unsets all bits from CombinedFlag. Same as AND NOT operator. Returns self *)
    function Exclude (CombinedFlag: integer): TFlagsChanger; inline;

    (* Changes whole flags value and returns self *)
    function SetValue (Value: integer): TFlagsChanger; inline;
  end;

function IsSse42Supported: boolean;

(* Wraps integer in TFlags structure *)
function Flags (Value: integer): TFlags; inline;

(* Wraps integer in TFlagsChanger structure *)
function ChangeFlags (var Value: integer): TFlagsChanger; inline;

(* Low level functions *)
function  PtrOfs ({n} BasePtr: pointer; Offset: integer): pointer; overload; inline;
function  PtrOfs ({n} BasePtr: pointer; ItemIndex, ItemSize: integer): pointer; overload; inline;
function  ItemPtrToIndex ({n} ItemPtr, {n} ArrPtr: pointer; ItemSize: integer): integer; inline;
function  IsValidBuf ({n} Buf: pointer; BufSize: integer): boolean;
procedure CopyMem (Count: integer; {n} Source, Destination: pointer);
procedure Exchange (var A, B); inline;
procedure SetPcharValue (What: myPChar; const Value: myAStr; BufSize: integer); overload;
procedure SetPcharValue (What: myPChar; {n} Value: myPChar; BufSize: integer); overload;
function  GetPcharValue (Str: myPChar; MaxLen: integer = -1): myAStr;

(* Returns true if simple or complex bit flag is set *)
function  HasFlag (Flag, Flags: integer): boolean; inline;

(* Extra system functions *)
function  Even (Num: integer): boolean;

(* Item guards *)
function  NoItemGuardProc ({n} Item: pointer; ItemIsObject: boolean; {n} Guard: TCloneable): boolean;
function  DefItemGuardProc ({n} Item: pointer; ItemIsObject: boolean; {n} Guard: TCloneable): boolean;

function  EqualMethods (A, B: TMethod): boolean;

// Casts Obj to Class and assigns Res to Obj. Frees object on fail and assings nil to Res.
procedure CastOrFree ({On} Obj: TObject; CastToType: TClass; out {O} Res);

(* Given method. Returns its object/class *)
function ObjFromMethod (Method: TObjProcedure): TObject; inline;
function ClassFromMethod (Method: TObjProcedure): TClass; inline;

(*
  Ternary operator.
  WARNING. If compiler decides, that expression has side effects, evaluation will NOT be lazy.
  Future compiler versions must be checked carefully. Use in simple expressions without side effects.
 *)
function IfThen (const Condition: boolean; const SuccessResult, FailureResult: myAStr): myAStr; inline; overload;
function IfThen (const Condition: boolean; const SuccessResult, FailureResult: integer): integer; inline; overload;
function IfThen (const Condition: boolean; const SuccessResult, FailureResult: pointer): pointer; inline; overload;

(* Attemps to convert interface to TObject. Currently object MUST implement IGetSelf for success *)
function ToObject (Intf: System.IInterface): {n} TObject;


(***)  implementation  (***)


function IsSse42Supported: boolean; assembler;
asm
  push ebx
  mov eax, 1
  cpuid
  shr ecx, 20
  and ecx, 1
  mov eax, ecx
  pop ebx
end;

function Flags (Value: integer): TFlags;
begin
  result.Flags := Value;
end;

function ChangeFlags (var Value: integer): TFlagsChanger;
begin
  result.FlagsPtr := @Value;
end;

function TFlags.Have (CombinedFlag: integer): boolean;
begin
  result := (Self.Flags and CombinedFlag) = CombinedFlag;
end;

function TFlags.HaveAny (CombinedFlag: integer): boolean;
begin
  result := (Self.Flags and CombinedFlag) <> 0;
end;

function TFlags.DontHave (CombinedFlag: integer): boolean;
begin
  result := (Self.Flags and CombinedFlag) <> CombinedFlag;
end;

function TFlags.DontHaveAny (CombinedFlag: integer): boolean;
begin
  result := (Self.Flags and CombinedFlag) = 0;
end;

function TFlags.Replace (WhatCombinedFlag, WithCombinedFlag: integer): TFlags;
begin
  if Self.Have(WhatCombinedFlag) then begin
    result.Flags := (Self.Flags and not WhatCombinedFlag) or WithCombinedFlag;
  end else begin
    result.Flags := Self.Flags;
  end;
end;

function TFlags.Include (CombinedFlag: integer): TFlags;
begin
  result.Flags := Self.Flags or CombinedFlag;
end;

function TFlags.Exclude (CombinedFlag: integer): TFlags;
begin
  result.Flags := Self.Flags and not CombinedFlag;
end;

function TFlags.GetValue: integer;
begin
  result := Self.Flags;
end;

function TFlagsChanger.Replace (WhatCombinedFlag, WithCombinedFlag: integer): TFlagsChanger;
begin
  if (Self.FlagsPtr^ and WhatCombinedFlag) = WhatCombinedFlag then begin
    Self.FlagsPtr^ := (Self.FlagsPtr^ and not WhatCombinedFlag) or WithCombinedFlag;
  end;

  result := Self;
end;

function TFlagsChanger.Include (CombinedFlag: integer): TFlagsChanger;
begin
  Self.FlagsPtr^ := Self.FlagsPtr^ or CombinedFlag;
  result         := Self;
end;

function TFlagsChanger.Exclude (CombinedFlag: integer): TFlagsChanger;
begin
  Self.FlagsPtr^ := Self.FlagsPtr^ and not CombinedFlag;
  result         := Self;
end;

function TFlagsChanger.SetValue (Value: integer): TFlagsChanger;
begin
  Self.FlagsPtr^ := Value;
  result         := Self;
end;

function PtrOfs ({n} BasePtr: pointer; Offset: integer): pointer; overload;
begin
  result := pointer(integer(BasePtr) + Offset);
end;

function PtrOfs ({n} BasePtr: pointer; ItemIndex, ItemSize: integer): pointer; overload;
begin
  result := pointer(cardinal(BasePtr) + cardinal(ItemIndex) * cardinal(ItemSize));
end;

function ItemPtrToIndex ({n} ItemPtr, {n} ArrPtr: pointer; ItemSize: integer): integer; inline;
begin
  result := integer((cardinal(ItemPtr) - cardinal(ArrPtr)) div cardinal(ItemSize));
end;

function IsValidBuf ({n} Buf: pointer; BufSize: integer): boolean;
begin
  {Buf <> NIL and BufSize = 0 is OK. Buf = NIL and BufSize > 0 is BAD. !BufSize >= 0}
  result := (BufSize >= 0) and ((Buf <> nil) or (BufSize = 0));
end;

procedure CopyMem (Count: integer; {n} Source, Destination: pointer);
begin
  {!} Assert(Count >= 0);
  {!} Assert((Count = 0) or ((Source <> nil) and (Destination <> nil)));
  System.Move(Source^, Destination^, Count);
end;

procedure Exchange (var A, B); inline;
var
  C: integer;

begin
  C             := pinteger(@A)^;
  pinteger(@A)^ := pinteger(@B)^;
  pinteger(@B)^ := pinteger(@C)^;
end;

procedure SetPcharValue (What: myPChar; const Value: myAStr; BufSize: integer); overload;
var
  NumBytesToCopy: integer;

begin
  {!} Assert(What <> nil);
  {!} Assert(BufSize > 0);
  NumBytesToCopy := Math.Min(Length(Value), BufSize - 1);

  if NumBytesToCopy > 0 then begin
    CopyMem(NumBytesToCopy, myPChar(Value), What);
  end;

  PCharByte(PtrOfs(What, NumBytesToCopy))^ := #0;
end; // .procedure SetPcharValue

procedure SetPcharValue (What: myPChar; {n} Value: myPChar; BufSize: integer); overload;
var
  NumBytesToCopy: integer;

begin
  {!} Assert(What <> nil);
  {!} Assert(BufSize > 0);
  if Value = nil then begin
    What^ := #0;
  end else begin
    NumBytesToCopy := Math.Min(Windows.LStrLenA(Value), BufSize - 1);

    if NumBytesToCopy > 0 then begin
      CopyMem(NumBytesToCopy, Value, What);
    end;

    PCharByte(PtrOfs(What, NumBytesToCopy))^ := #0;
  end;
end; // .procedure SetPcharValue

function GetPcharValue (Str: myPChar; MaxLen: integer = -1): myAStr;
var
  NumBytesToCopy: integer;

begin
  if MaxLen < 0 then begin
    result := Str;
  end else begin
    NumBytesToCopy := Math.Min(Windows.LStrLenA(Str), MaxLen);
    SetLength(result, NumBytesToCopy);
    CopyMem(NumBytesToCopy, Str, pointer(result));
  end;
end;

function HasFlag (Flag, Flags: integer): boolean;
begin
  result := (Flags and Flag) = Flag;
end;

procedure TCloneable.Assign (Source: TCloneable);
begin
end;

function TCloneable.Clone: TCloneable;
begin
  result := TCloneable(Self.ClassType.Create);
  result.Assign(Self);
end;

procedure TDefItemGuard.Assign (Source: TCloneable);
var
(* U *) SrcItemGuard: TDefItemGuard;

begin
  {!} Assert(Source <> nil);
  SrcItemGuard := Source as TDefItemGuard;
  // * * * * * //
  Self.ItemType := SrcItemGuard.ItemType;
  Self.AllowNil := SrcItemGuard.AllowNil;
end;

function Even (Num: integer): boolean;
begin
  result := not ODD(Num);
end;

function NoItemGuardProc ({n} Item: pointer; ItemIsObject: boolean; {n} Guard: TCloneable): boolean;
begin
  result := TRUE;
end;

function DefItemGuardProc ({n} Item: pointer; ItemIsObject: boolean; {n} Guard: TCloneable): boolean;
var
(* U *) MyGuard: TDefItemGuard;

begin
  {!} Assert(Guard <> nil);
  MyGuard :=  Guard as TDefItemGuard;
  // * * * * * //
  result := (Item <> nil) or (MyGuard.AllowNil);

  if ItemIsObject and (Item <> nil) and (MyGuard.ItemType <> NO_TYPEGUARD) then begin
    result := result and (TObject(Item) is MyGuard.ItemType);
  end;
end; // .function DefItemGuardProc

function EqualMethods (A, B: TMethod): boolean;
begin
  result := (A.Code = B.Code) and (A.Data = B.Data);
end;

procedure CastOrFree ({On} Obj: TObject; CastToType: TClass; out {O} Res);
begin
  if Obj is CastToType then begin
    TObject(Res) := Obj;
  end else begin
    Obj.Free;
    TObject(Res) := nil;
  end;
end;

function ObjFromMethod (Method: TObjProcedure): TObject; inline;
begin
  result := TObject(TMethod(Method).Data);
end;

function ClassFromMethod (Method: TObjProcedure): TClass; inline;
begin
  result := TClass(TMethod(Method).Data);
end;

function IfThen (const Condition: boolean; const SuccessResult, FailureResult: myAStr): myAStr; inline; overload;   begin if Condition then result := SuccessResult else result := FailureResult; end;
function IfThen (const Condition: boolean; const SuccessResult, FailureResult: integer): integer; inline; overload; begin if Condition then result := SuccessResult else result := FailureResult; end;
function IfThen (const Condition: boolean; const SuccessResult, FailureResult: pointer): pointer; inline; overload; begin if Condition then result := SuccessResult else result := FailureResult; end;

function InterlockedCompareExchange (var Destination: integer; NewValue, Comperand: integer): integer; stdcall; external 'kernel32' name 'InterlockedCompareExchange';
function InterlockedIncrement       (var Value: integer): integer; stdcall; external 'kernel32' name 'InterlockedIncrement';
function InterlockedDecrement       (var Value: integer): integer; stdcall; external 'kernel32' name 'InterlockedDecrement';

procedure TInterfaceAwareObject.AfterConstruction;
begin
  Self.fHasMainOwner := 1;
end;

procedure TInterfaceAwareObject.BeforeDestruction;
begin
  {!} Assert(Self.fHasMainOwner = (Self.fRefCount and $8000000), 'TInterfaceAwareObject consistency was broken. An attempt to destroy object with non-zero reference count or existing external owner');
end;

procedure TInterfaceAwareObject.ReleaseMainOwnage;
begin
  if (Self.fHasMainOwner <> 0) and (InterlockedCompareExchange(Self.fHasMainOwner, 0, 1) = 0) then begin
    Self._Release();
  end;
end;

function TInterfaceAwareObject.GetSelf: TInterfaceAwareObject;
begin
  result := Self;
end;

function TInterfaceAwareObject.HasMainOwner: boolean;
begin
  result := Self.fHasMainOwner <> 0;
end;

function TInterfaceAwareObject.BecomeMainOwner: {O} TInterfaceAwareObject;
begin
  {!} Assert(InterlockedIncrement(Self.fRefCount) > 1, 'Error trying to become main owner of freed interfaced object');
  {!} Assert((Self.fHasMainOwner = 0) and (InterlockedCompareExchange(Self.fHasMainOwner, 1, 0) = 1), 'Another pointer is main owner of interfaced object. Cannot become main owner');
  result := Self;
end;

procedure TManagedObject.AfterConstruction;
begin
  Self.fRefCount := 0;
end;

function ToObject (Intf: System.IInterface): {n} TObject;
var
  SelfGetter:  IObjInterface;
  SelfGetter2: IGetSelf;

begin
  result := nil;

  if Legacy.Supports(Intf, IObjInterface, SelfGetter) then begin
    result := SelfGetter.GetSelf();
  end else if Legacy.Supports(Intf, IGetSelf, SelfGetter2) then begin
    result := SelfGetter2.GetSelf();
  end;
end;

end.
