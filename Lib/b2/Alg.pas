unit Alg;
{
DESCRIPTION:  Additional math/algorithmic functions
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

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
uses UtilsB2;

type
  TOnRangeMinMaxConflict = (FORCE_MIN_VALUE, FORCE_MAX_VALUE);

  TCompareFunc   = function (Value1, Value2: integer): integer;
  TCompareMethod = function (Value1, Value2: integer): integer of object;
  TCompareFuncEx = function (Value1, Value2: integer; {n} State: pointer): integer;

  TQuickSortAdapter = class abstract
    function  CompareItems (Ind1, Ind2: integer): integer; virtual; abstract;
    procedure SwapItems (Ind1, Ind2: integer); virtual; abstract;
    procedure SavePivotItem (PivotItemInd: integer); virtual; abstract;
    function  CompareToPivot (Ind: integer): integer; virtual; abstract;
  end;

  function Max3 (A, B, C: integer): integer; inline;
  function Min3 (A, B, C: integer): integer; inline;

(* Rounds integer to given boundary. If ceil is true, rounding is performed to higher value, otherwise to lower one.
   Example: f(21, 4, true) = 24 *)
function IntRoundToBoundary (Value, Boundary: integer; Ceil: boolean = true): integer;

function  ToRange (Value, MinValue, MaxValue: integer; OnRangeMinMaxConflict: TOnRangeMinMaxConflict = FORCE_MIN_VALUE): integer;
function  InRange (Value, MinValue, MaxValue: cardinal): boolean; overload; inline;
function  InRange (Value, MinValue, MaxValue: integer): boolean; overload; inline;
function  IntLog2 (Num: integer): integer; {=> Ceil(Log2(cardinal(N)))}

(* Returns number of decimal digits in integer *)
function CountDigits (Num: integer): integer;

(* Raises 10 to specified power. Possible powers must be in 0..9 range *)
function IntPow10 (Power: integer): integer;

function  IntCompare (Int1, Int2: integer): integer; overload;
function  IntCompare (Int1, Int2: integer; {n} State: pointer): integer; overload;
function  CardCompare (Card1, Card2: cardinal): integer;
function  PtrCompare (Ptr1, Ptr2: pointer): integer;
function  Int64To32 (Value: INT64): integer; {No overflow, bounds to LOW(INT32)..HIGH(IN32)}
function  IsSortedArr (Arr: UtilsB2.PEndlessIntArr; MinInd, MaxInd: integer): boolean; { Ascendantly }
function  IsCustomSortedArr (Arr: UtilsB2.PEndlessIntArr; MinInd, MaxInd: integer; CompareItems: TCompareFunc): boolean; overload;
function  IsCustomSortedArr (Arr: UtilsB2.PEndlessIntArr; MinInd, MaxInd: integer; CompareItems: TCompareMethod): boolean; overload;
function  IsDescSortedArr (Arr: UtilsB2.PEndlessIntArr; MinInd, MaxInd: integer): boolean;
function  IsCustomDescSortedArr (Arr: UtilsB2.PEndlessIntArr; MinInd, MaxInd: integer; CompareItems: TCompareFunc): boolean; overload;
function  IsCustomDescSortedArr (Arr: UtilsB2.PEndlessIntArr; MinInd, MaxInd: integer; CompareItems: TCompareMethod): boolean; overload;
procedure QuickSort (Arr: UtilsB2.PEndlessIntArr; MinInd, MaxInd: integer);
procedure CustomQuickSort (Arr: UtilsB2.PEndlessIntArr; MinInd: integer; MaxInd: integer; CompareItems: TCompareFunc); overload;
procedure CustomQuickSort (Arr: UtilsB2.PEndlessIntArr; MinInd: integer; MaxInd: integer; CompareItems: TCompareMethod); overload;
procedure QuickSortEx (Obj: TQuickSortAdapter; MinInd, MaxInd: integer);
function  CustomBinarySearch (Arr: PEndlessIntArr; MinInd, MaxInd: integer; Needle: integer; CompareItems: TCompareFunc; out ResInd: integer): boolean; overload;
procedure InsertionSortInt32 (Arr: PEndlessIntArr; MinInd, MaxInd: integer);
procedure CustomInsertionSortInt32 (Arr: PEndlessIntArr; MinInd, MaxInd: integer; CompareItems: TCompareFuncEx; {n} State: pointer = nil);
procedure CustomMergeSortInt32 (Arr: PEndlessIntArr; MinInd, MaxInd: integer; CompareItems: TCompareFuncEx; {n} State: pointer = nil);

function  CustomBinarySearch (Arr: PEndlessIntArr; MinInd, MaxInd: integer; Needle: integer;
                              CompareItems: TCompareMethod; out ResInd: integer): boolean; overload;


(***)  implementation  (***)


const
  Pow10Table: array [0..8] of integer = (10, 100, 1000, 10000, 100000, 1000000, 10000000, 100000000, 1000000000);


function Max3 (A, B, C: integer): integer;
begin
  result := A;

  if B > A then begin
    result := B;
  end;

  if C > result then begin
    result := C;
  end;
end;

function Min3 (A, B, C: integer): integer;
begin
  result := A;

  if B < A then begin
    result := B;
  end;

  if C < result then begin
    result := C;
  end;
end;

function IntRoundToBoundary (Value, Boundary: integer; Ceil: boolean = true): integer;
begin
  {!} Assert(Boundary >= 1);
  result := (Value + (Boundary - 1)) and not (Boundary - 1);
end;

function ToRange (Value, MinValue, MaxValue: integer; OnRangeMinMaxConflict: TOnRangeMinMaxConflict = FORCE_MIN_VALUE): integer;
begin
  result := Value;

  if OnRangeMinMaxConflict = FORCE_MIN_VALUE then begin
    if result > MaxValue then begin
      result := MaxValue;
    end;

    if result < MinValue then begin
      result := MinValue;
    end;
  end else begin
    if result < MinValue then begin
      result := MinValue;
    end;

    if result > MaxValue then begin
      result := MaxValue;
    end;
  end; // .else
end; // .function ToRange

function InRange (Value, MinValue, MaxValue: cardinal): boolean; overload;
begin
  result := (Value >= MinValue) and (Value <= MaxValue);
end;

function InRange (Value, MinValue, MaxValue: integer): boolean; overload;
begin
  result := (Value >= MinValue) and (Value <= MaxValue);
end;

function IntLog2 (Num: integer): integer; assembler;
asm
  test eax, eax
  jz @ret0
  bsr ecx, eax
  mov edx, 1
  shl edx, cl
  sub edx, eax
  shr edx, 31
  lea eax, [ecx + edx]
  ret
@ret0:
  xor eax, eax
end; // .function IntLog2

function CountDigits (Num: integer): integer;
var
  i: integer;

begin
  if Num < 0 then begin
    Num := -Num;

    if Num < 0 then begin
      Num := High(integer);
    end;
  end;

  i := Low(Pow10Table);

  while (i < High(Pow10Table)) and (Num >= Pow10Table[i]) do begin
    Inc(i);
  end;

  result := i + 1;
end; // .function IntLog2

function IntPow10 (Power: integer): integer;
begin
  {!} Assert((Power >= 0) and (Power <= High(Pow10Table) + 1));
  result := 1;

  if Power <> 0 then begin
    result := Pow10Table[Power - 1];
  end;
end;

function IntCompare (Int1, Int2: integer): integer;
begin
  if Int1 > Int2 then begin
    result := +1;
  end else if Int1 < Int2 then begin
    result := -1;
  end else begin
    result := 0;
  end;
end;

function IntCompare (Int1, Int2: integer; {n} State: pointer): integer;
begin
  if Int1 > Int2 then begin
    result := +1;
  end else if Int1 < Int2 then begin
    result := -1;
  end else begin
    result := 0;
  end;
end;

function CardCompare (Card1, Card2: cardinal): integer;
begin
  if Card1 > Card2 then begin
    result := +1;
  end else if Card1 < Card2 then begin
    result := -1;
  end else begin
    result := 0;
  end;
end;

function PtrCompare (Ptr1, Ptr2: pointer): integer;
begin
  if cardinal(Ptr1) > cardinal(Ptr2) then begin
    result := +1;
  end else if cardinal(Ptr1) < cardinal(Ptr2) then begin
    result := -1;
  end else begin
    result := 0;
  end;
end;

function Int64To32 (Value: INT64): integer;
begin
  if Value > High(integer) then begin
    result  :=  High(integer);
  end else if Value < Low(integer) then begin
    result  :=  Low(integer);
  end else begin
    result  :=  Value;
  end;
end;

function IsSortedArr (Arr: UtilsB2.PEndlessIntArr; MinInd, MaxInd: integer): boolean;
var
  i: integer;

begin
  result := true;

  for i := MinInd + 1 to MaxInd do begin
    if Arr[i - 1] > Arr[i] then begin
      result := false;
      break;
    end;
  end;
end; // .function IsSortedArr

function IsCustomSortedArr (Arr: UtilsB2.PEndlessIntArr; MinInd, MaxInd: integer; CompareItems: TCompareFunc): boolean;
var
  i: integer;

begin
  result := true;

  for i := MinInd + 1 to MaxInd do begin
    if CompareItems(Arr[i - 1], Arr[i]) > 0 then begin
      result := false;
      break;
    end;
  end;
end; // .function IsCustomSortedArr

function IsCustomSortedArr (Arr: UtilsB2.PEndlessIntArr; MinInd, MaxInd: integer; CompareItems: TCompareMethod): boolean;
var
  i: integer;

begin
  result := true;

  for i := MinInd + 1 to MaxInd do begin
    if CompareItems(Arr[i - 1], Arr[i]) > 0 then begin
      result := false;
      break;
    end;
  end;
end; // .function IsCustomSortedArr

function IsDescSortedArr (Arr: UtilsB2.PEndlessIntArr; MinInd, MaxInd: integer): boolean;
var
  i: integer;

begin
  result := true;

  for i := MinInd + 1 to MaxInd do begin
    if Arr[i - 1] > Arr[i] then begin
      result := false;
      break;
    end;
  end;
end; // .function IsDescSortedArr

function IsCustomDescSortedArr (Arr: UtilsB2.PEndlessIntArr; MinInd, MaxInd: integer; CompareItems: TCompareFunc): boolean;
var
  i: integer;

begin
  result := true;

  for i := MinInd + 1 to MaxInd do begin
    if CompareItems(Arr[i - 1], Arr[i]) > 0 then begin
      result := false;
      break;
    end;
  end;
end; // .function IsCustomDescSortedArr

function IsCustomDescSortedArr (Arr: UtilsB2.PEndlessIntArr; MinInd, MaxInd: integer; CompareItems: TCompareMethod): boolean;
var
  i: integer;

begin
  result := true;

  for i := MinInd + 1 to MaxInd do begin
    if CompareItems(Arr[i - 1], Arr[i]) > 0 then begin
      result := false;
      break;
    end;
  end;
end; // .function IsCustomDescSortedArr

procedure QuickSort (Arr: UtilsB2.PEndlessIntArr; MinInd, MaxInd: integer);
begin
  CustomQuickSort(Arr, MinInd, MaxInd, IntCompare);
end;

procedure CustomQuickSort (Arr: UtilsB2.PEndlessIntArr; MinInd: integer; MaxInd: integer;
                           CompareItems: TCompareFunc); overload;
var
  RangeLen:  integer;
  LeftInd:   integer;
  RightInd:  integer;
  PivotItem: integer;

  procedure ExchangeItems (Ind1, Ind2: integer);
  var
    TransfValue: integer;

  begin
    TransfValue := Arr[Ind1];
    Arr[Ind1]   := Arr[Ind2];
    Arr[Ind2]   := TransfValue;
  end;

begin
  RangeLen := MaxInd - MinInd + 1;
  {!} Assert(RangeLen >= 0);
  {!} Assert(UtilsB2.IsValidBuf(Arr, RangeLen));
  {!} Assert(MinInd >= 0);

  while MinInd < MaxInd do begin
    LeftInd   := MinInd;
    RightInd  := MaxInd;
    PivotItem := Arr[MinInd + (MaxInd - MinInd) div 2];

    while LeftInd <= RightInd do begin
      while CompareItems(Arr[LeftInd], PivotItem) < 0 do begin
        Inc(LeftInd);
      end;

      while CompareItems(Arr[RightInd], PivotItem) > 0 do begin
        Dec(RightInd);
      end;

      if LeftInd <= RightInd then begin
        if CompareItems(Arr[LeftInd], Arr[RightInd]) > 0 then begin
          ExchangeItems(LeftInd, RightInd);
        end else begin
          Inc(LeftInd);
          Dec(RightInd);
        end;
      end;
    end; // .while

    (* MIN__RIGHT|{PIVOT}|LEFT__MAX *)

    if (RightInd - MinInd) < (MaxInd - LeftInd) then begin
      if RightInd > MinInd then begin
        CustomQuickSort(Arr, MinInd, RightInd, CompareItems);
      end;

      MinInd := LeftInd;
    end else begin
      if MaxInd > LeftInd then begin
        CustomQuickSort(Arr, LeftInd, MaxInd, CompareItems);
      end;

      MaxInd := RightInd;
    end; // .else
  end; // .while
end; // .procedure CustomQuickSort

procedure CustomQuickSort (Arr: UtilsB2.PEndlessIntArr; MinInd: integer; MaxInd: integer;
                           CompareItems: TCompareMethod); overload;
var
  RangeLen:  integer;
  LeftInd:   integer;
  RightInd:  integer;
  PivotItem: integer;

  procedure ExchangeItems (Ind1, Ind2: integer);
  var
    TransfValue: integer;

  begin
    TransfValue := Arr[Ind1];
    Arr[Ind1]   := Arr[Ind2];
    Arr[Ind2]   := TransfValue;
  end;

begin
  RangeLen := MaxInd - MinInd + 1;
  {!} Assert(RangeLen >= 0);
  {!} Assert(UtilsB2.IsValidBuf(Arr, RangeLen));
  {!} Assert(MinInd >= 0);

  while MinInd < MaxInd do begin
    LeftInd   := MinInd;
    RightInd  := MaxInd;
    PivotItem := Arr[MinInd + (MaxInd - MinInd) div 2];

    while LeftInd <= RightInd do begin
      while CompareItems(Arr[LeftInd], PivotItem) < 0 do begin
        Inc(LeftInd);
      end;

      while CompareItems(Arr[RightInd], PivotItem) > 0 do begin
        Dec(RightInd);
      end;

      if LeftInd <= RightInd then begin
        if CompareItems(Arr[LeftInd], Arr[RightInd]) > 0 then begin
          ExchangeItems(LeftInd, RightInd);
        end else begin
          Inc(LeftInd);
          Dec(RightInd);
        end;
      end;
    end; // .while

    (* MIN__RIGHT|{PIVOT}|LEFT__MAX *)

    if (RightInd - MinInd) < (MaxInd - LeftInd) then begin
      if RightInd > MinInd then begin
        CustomQuickSort(Arr, MinInd, RightInd, CompareItems);
      end;

      MinInd := LeftInd;
    end else begin
      if MaxInd > LeftInd then begin
        CustomQuickSort(Arr, LeftInd, MaxInd, CompareItems);
      end;

      MaxInd := RightInd;
    end; // .else
  end; // .while
end; // .procedure CustomQuickSort

procedure QuickSortEx (Obj: TQuickSortAdapter; MinInd, MaxInd: integer);
var
  RangeLen: integer;
  LeftInd:  integer;
  RightInd: integer;

begin
  RangeLen := MaxInd - MinInd + 1;
  {!} Assert(RangeLen >= 0);
  {!} Assert(UtilsB2.IsValidBuf(pointer(Obj), RangeLen));
  {!} Assert(MinInd >= 0);

  while MinInd < MaxInd do begin
    LeftInd  := MinInd;
    RightInd := MaxInd;
    Obj.SavePivotItem(MinInd + (MaxInd - MinInd) div 2);

    while LeftInd <= RightInd do begin
      while Obj.CompareToPivot(LeftInd) < 0 do begin
        Inc(LeftInd);
      end;

      while Obj.CompareToPivot(RightInd) > 0 do begin
        Dec(RightInd);
      end;

      if LeftInd <= RightInd then begin
        if Obj.CompareItems(LeftInd, RightInd) > 0 then begin
          Obj.SwapItems(LeftInd, RightInd);
        end else begin
          Inc(LeftInd);
          Dec(RightInd);
        end;
      end;
    end; // .while

    (* MIN__RIGHT|{PIVOT}|LEFT__MAX *)

    if (RightInd - MinInd) < (MaxInd - LeftInd) then begin
      if RightInd > MinInd then begin
        QuickSortEx(Obj, MinInd, RightInd);
      end;

      MinInd :=  LeftInd;
    end else begin
      if MaxInd > LeftInd then begin
        QuickSortEx(Obj, LeftInd, MaxInd);
      end;

      MaxInd  :=  RightInd;
    end; // .else
  end; // .while
end; // .procedure QuickSortEx

procedure InsertionSortInt32 (Arr: PEndlessIntArr; MinInd, MaxInd: integer);
var
  CurrItem: integer;
  i, j, k: integer;

begin
  for i := MinInd + 1 to MaxInd do begin
    CurrItem := Arr[i];

    j := i - 1;

    // Find insertion index = j + 1
    while (j >= MinInd) and (Arr[j] > CurrItem) do begin
      Dec(j);
    end;

    Inc(j);

    // Move items from insertion position to the right by 1
    k := i;

    while k > j do begin
      Arr[k] := Arr[k - 1];
      Dec(k);
    end;

    Arr[j] := CurrItem;
  end; // .for
end; // .procedure InsertionSortInt32

procedure CustomInsertionSortInt32 (Arr: PEndlessIntArr; MinInd, MaxInd: integer; CompareItems: TCompareFuncEx; {n} State: pointer = nil);
var
  CurrItem: integer;
  i, j, k: integer;

begin
  for i := MinInd + 1 to MaxInd do begin
    CurrItem := Arr[i];

    j := i - 1;

    // Find insertion index = j + 1
    while (j >= MinInd) and (CompareItems(Arr[j], CurrItem, State) > 0) do begin
      Dec(j);
    end;

    Inc(j);

    // Move items from insertion position to the right by 1
    k := i;

    while k > j do begin
      Arr[k] := Arr[k - 1];
      Dec(k);
    end;

    Arr[j] := CurrItem;
  end; // .for
end; // .procedure CustomInsertionSortInt32

procedure _CustomMergeSortInt32 (Arr: PEndlessIntArr; MinInd, MaxInd: integer; CompareItems: TCompareFuncEx; {n} State: pointer; Buf: PEndlessIntArr);
var
  RangeLen:    integer;
  LeftInd:     integer;
  LeftEndInd:  integer;
  RightInd:    integer;
  RightEndInd: integer;
  MiddleInd:   integer;
  ArrPos:      integer;
  Item:        integer;
  i:           integer;

begin
  RangeLen := MaxInd - MinInd + 1;

  if RangeLen = 2 then begin
    if CompareItems(Arr[MinInd], Arr[MaxInd], State) > 0 then begin
      Item        := Arr[MinInd];
      Arr[MinInd] := Arr[MaxInd];
      Arr[MaxInd] := Item;
    end;
  end else if RangeLen <= 10 then begin
    CustomInsertionSortInt32(Arr, MinInd, MaxInd, CompareItems, State);
  end else begin
    MiddleInd := MinInd + RangeLen div 2;
    CustomMergeSortInt32(Arr, MinInd, MiddleInd - 1, CompareItems, State);
    CustomMergeSortInt32(Arr, MiddleInd, MaxInd, CompareItems, State);

    // Do not sort already sorted list
    if CompareItems(Arr[MiddleInd - 1], Arr[MiddleInd], State) <= 0 then begin
      exit;
    end;

    // Copy left partition to buffer
    for i := MinInd to MiddleInd - 1 do begin
      Buf[i - MinInd] := Arr[i];
    end;

    // Merge partitions
    LeftEndInd  := MiddleInd - 1 - MinInd;
    LeftInd     := 0;
    RightEndInd := MaxInd;
    RightInd    := MiddleInd;
    ArrPos      := MinInd;

    while (LeftInd <= LeftEndInd) and (RightInd <= RightEndInd) do begin
      if CompareItems(Arr[RightInd], Buf[LeftInd], State) < 0 then begin
        Item := Arr[RightInd];
        Inc(RightInd);
      end else begin
        Item := Buf[LeftInd];
        Inc(LeftInd);
      end;

      Arr[ArrPos] := Item;
      Inc(ArrPos);
    end;

    // Copy rest of left partition items, if any
    while (LeftInd <= LeftEndInd) do begin
      Arr[ArrPos] := Buf[LeftInd];
      Inc(ArrPos);
      Inc(LeftInd);
    end;
  end; // .else
end; // .procedure _CustomMergeSortInt32

procedure CustomMergeSortInt32 (Arr: PEndlessIntArr; MinInd, MaxInd: integer; CompareItems: TCompareFuncEx; {n} State: pointer = nil);
var
{O} Buf:      PEndlessIntArr;
    RangeLen: integer;

begin
  RangeLen := MaxInd - MinInd + 1;

  if RangeLen <= 10 then begin
    CustomInsertionSortInt32(Arr, MinInd, MaxInd, CompareItems, State);
  end else begin
    Buf := nil;
    GetMem(Buf, (RangeLen div 2 + 1) * sizeof(Buf[0]));
    _CustomMergeSortInt32(Arr, MinInd, MaxInd, CompareItems, State, Buf);
    FreeMem(Buf);
  end;
end;

function CustomBinarySearch (Arr: PEndlessIntArr; MinInd, MaxInd: integer; Needle: integer;
                             CompareItems: TCompareFunc; out ResInd: integer): boolean; overload;
var
  PivotInd:   integer;
  CompareRes: integer;

begin
  result := false;

  while not result and (MinInd <= MaxInd) do begin
    PivotInd   := MinInd + (MaxInd - MinInd) div 2;
    CompareRes := CompareItems(PivotInd, Needle);

    if CompareRes < 0 then begin
      MaxInd := PivotInd - 1;
    end else if CompareRes > 0 then begin
      MinInd := PivotInd + 1;
    end else begin
      ResInd := PivotInd;
      result := true;
    end;
  end; // .while
end; // .function CustomBinarySearch

function CustomBinarySearch (Arr: PEndlessIntArr; MinInd, MaxInd: integer; Needle: integer;
                             CompareItems: TCompareMethod; out ResInd: integer): boolean; overload;
var
  PivotInd:   integer;
  CompareRes: integer;

begin
  result := false;

  while not result and (MinInd <= MaxInd) do begin
    PivotInd   := MinInd + (MaxInd - MinInd) div 2;
    CompareRes := CompareItems(PivotInd, Needle);

    if CompareRes < 0 then begin
      MaxInd := PivotInd - 1;
    end else if CompareRes > 0 then begin
      MinInd := PivotInd + 1;
    end else begin
      ResInd := PivotInd;
      result := true;
    end;
  end; // .while
end; // .function CustomBinarySearch

end.
