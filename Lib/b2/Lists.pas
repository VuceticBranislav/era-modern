unit Lists;
{
DESCRIPTION:  Implementation of data structure "List" in several variants.
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses Windows, SysUtils, Math, Classes, UtilsB2, Alg, StrLib, Legacy;

type
  TList = class (UtilsB2.TCloneable)
    (***) protected (***)
      const
        FIRST_ALLOC_COUNT   = 16;
        DEFAULT_GROWTH_RATE = 200;
      
      var
      (* O  *)  fData:            (* OUn *) UtilsB2.PEndlessPtrArr;
                fCapacity:        integer;
                fCount:           integer;
                fGrowthRate:      integer;  // in percents, ex: 120 = 1.2 growth koefficient
                fOwnsItems:       boolean;
                fItemsAreObjects: boolean;
                fItemGuardProc:   UtilsB2.TItemGuardProc;
      (* on *)  fItemGuard:       UtilsB2.TItemGuard;

      procedure FreeItem (Ind: integer);
      procedure Put (Ind: integer; (* OUn *) Item: pointer);
      function  Get (Ind: integer): (* n *) pointer;
      function  AddEmpty: integer;
    
    (***) public (***)
      constructor Create (OwnsItems: boolean; ItemsAreObjects: boolean; ItemGuardProc: UtilsB2.TItemGuardProc; (* n *) var (* in *) ItemGuard: UtilsB2.TItemGuard);
      destructor  Destroy; override;
      procedure Assign (Source: UtilsB2.TCloneable); override;
      procedure Clear;
      function  IsValidItem ((* n *) Item: pointer): boolean;
      procedure SetGrowthRate (NewGrowthRate: integer);
      procedure SetCapacity (NewCapacity: integer);
      procedure SetCount (NewCount: integer);
      function  Add ((* OUn *) Item: pointer): integer;
      function  Top: (* n *) pointer;
      function  Pop: (* OUn *) pointer;
      procedure Delete (Ind: integer);
      procedure Insert ((* OUn *) Item: pointer; Ind: integer);
      procedure Exchange (SrcInd, DstInd: integer);
      procedure Move (SrcInd, DstInd: integer);
      procedure Shift (StartInd, Count, ShiftBy: integer);
      {Returns item with specified index and NILify it in the list}
      function  Take (Ind: integer): (* OUn *) pointer;
      {Returns old item}
      function  Replace (Ind: integer; (* OUn *) NewValue: pointer): (* OUn *) pointer;
      procedure Pack;
      function  Find ((* n *) Item: pointer; out Ind: integer): boolean;
      {Binary search assuming list is sorted}
      function  QuickFind ((* n *) Item: pointer; out Ind: integer): boolean;

      procedure Sort;
      procedure CustomSort (Compare: Alg.TCompareFunc); overload;
      procedure CustomSort (Compare: Alg.TCompareMethod); overload;
      
      property Capacity:             integer read fCapacity;
      property Count:                integer read fCount;
      property GrowthRate:           integer read fGrowthRate;
      property OwnsItems:            boolean read fOwnsItems;
      property ItemsAreObjects:      boolean read fItemsAreObjects;
      property ItemGuardProc:        UtilsB2.TItemGuardProc read fItemGuardProc;
      property Items[Ind: integer]:  (* n *) pointer read Get write Put; default;
  end; // .class TList
  
  TStringList = class;

  TStringListCompareFunc = function (const Key1, Key2: myAStr; {Un} Value1, Value2: pointer): integer of object;

  TStringListQuickSortAdapter = class (Alg.TQuickSortAdapter)
   protected
    {U}  fList:        TStringList;
         fCompareFunc: TStringListCompareFunc;
         fPivotKey:    myAStr;
    {Un} fPivotValue:  pointer;

   public
    constructor Create ({U} List: TStringList; {n} CompareFunc: TStringListCompareFunc);
    
    function  DefaultCompareFunc (const Key1, Key2: myAStr; {Un} Value1, Value2: pointer): integer; virtual;
    function  CompareItems (Ind1, Ind2: integer): integer; override;
    procedure SwapItems (Ind1, Ind2: integer); override;
    procedure SavePivotItem (PivotItemInd: integer); override;
    function  CompareToPivot (Ind: integer): integer; override;
  end;
  
  TStringList = class (UtilsB2.TCloneable)
    (***) protected (***)
      const
        FIRST_ALLOC_COUNT   = 16;
        DEFAULT_GROWTH_RATE = 200;
      
      var
                fKeys:              UtilsB2.TArrayOfStr;
      (* O  *)  fValues:            (* OUn *) UtilsB2.PEndlessPtrArr;
                fCapacity:          integer;
                fCount:             integer;
                fGrowthRate:        integer;  // in percents, ex: 120 = 1.2 grow koefficient
                fOwnsItems:         boolean;
                fItemsAreObjects:   boolean;
                fItemGuardProc:     UtilsB2.TItemGuardProc;
      (* on *)  fItemGuard:         UtilsB2.TItemGuard;
                fCaseInsensitive:   boolean;
                fForbidDuplicates:  boolean;
                fSorted:            boolean;
                fCustomSorted:      boolean;

      procedure FreeValue (Ind: integer);
      function  ValidateKey (const Key: myAStr): boolean;
      procedure PutKey (Ind: integer; const Key: myAStr);
      function  GetKey (Ind: integer): myAStr;
      procedure PutValue (Ind: integer; (* OUn *) Item: pointer);
      function  GetValue (Ind: integer): (* n *) pointer;
      function  AddEmpty: integer;
      procedure QuickSort (MinInd, MaxInd: integer);
      function  QuickFind (const Key: myAStr; (* i *) out Ind: integer): boolean;
      procedure SetSorted (IsSorted: boolean);
      procedure EnsureNoDuplicates;
      procedure SetCaseInsensitive (NewCaseInsensitive: boolean);
      procedure SetForbidDuplicates (NewForbidDuplicates: boolean);
      function  GetItem (const Key: myAStr): (* n *) pointer;
      procedure PutItem (const Key: myAStr; (* OUn *) Value: pointer);
    
    (***) public (***)
      constructor Create (OwnsItems: boolean; ItemsAreObjects: boolean; ItemGuardProc: UtilsB2.TItemGuardProc; (* n *) var {IN} ItemGuard: UtilsB2.TItemGuard);
      destructor  Destroy; override;
      procedure Assign (Source: UtilsB2.TCloneable); override;
      procedure Clear;
      function  IsValidItem ((* n *) Item: pointer): boolean;
      procedure SetGrowthRate (NewGrowthRate: integer);
      procedure SetCapacity (NewCapacity: integer);
      procedure SetCount (NewCount: integer);
      function  AddObj (const Key: myAStr; (* OUn *) Value: pointer): integer;
      function  Add (const Key: myAStr): integer;
      function  Top: myAStr;
      function  Pop ((* OUn *) out Item: pointer): myAStr;
      procedure Delete (Ind: integer);
      procedure InsertObj (const Key: myAStr; Value: (* OUn *) pointer; Ind: integer);
      procedure Insert (const Key: myAStr; Ind: integer);
      procedure Exchange (SrcInd, DstInd: integer);
      procedure Move (SrcInd, DstInd: integer);
      procedure Shift (StartInd, Count, ShiftBy: integer);
      {Returns value with specified index and NILify it in the list}
      function  TakeValue (Ind: integer): (* OUn *) pointer;
      {Returns old value}
      function  ReplaceValue (Ind: integer; (* OUn *) NewValue: pointer): (* OUn *) pointer;
      procedure Pack;
      function  CompareStrings (const Str1, Str2: myAStr): integer;
      {If not success then returns index, where new item should be insert to keep list sorted}
      function  Find (const Key: myAStr; (* i *) out Ind: integer): boolean;
      procedure Sort;
      procedure CustomSort (CompareFunc: TStringListCompareFunc; MinInd, MaxInd: integer);
      procedure LoadFromText (const Text, EndOfLineMarker: myAStr);
      function  ToText (const EndOfLineMarker: myAStr): myAStr;
      
      property  Capacity:                 integer read fCapacity;
      property  Count:                    integer read fCount;
      property  GrowthRate:               integer read fGrowthRate { = DEFAULT_GROWTH_RATE};
      property  OwnsItems:                boolean read fOwnsItems;
      property  ItemsAreObjects:          boolean read fItemsAreObjects;
      property  ItemGuardProc:            UtilsB2.TItemGuardProc read fItemGuardProc;
      property  Keys[Ind: integer]:       myAStr read GetKey write PutKey; default;
      property  Values[Ind: integer]:     (* n *) pointer read GetValue write PutValue;
      property  CaseInsensitive:          boolean read fCaseInsensitive write SetCaseInsensitive;
      property  ForbidDuplicates:         boolean read fForbidDuplicates write SetForbidDuplicates;
      property  Sorted:                   boolean read fSorted write SetSorted;
      property  Items[const Key: myAStr]: (* n *) pointer read GetItem write PutItem;
  end; // .class TStringList


function  NewStrList (OwnsItems: boolean; ItemsAreObjects: boolean; ItemType: TClass; AllowNIL: boolean): TStringList;
function  NewStrictList ({n} TypeGuard: TClass): TList;
function  NewSimpleList: TList;
function  NewList (OwnsItems: boolean; ItemsAreObjects: boolean; ItemType: TClass; AllowNIL: boolean): TList;
function  NewStrictStrList ({n} TypeGuard: TClass): TStringList;
function  NewSimpleStrList: TStringList;
  

(***) implementation (***)


constructor TList.Create (OwnsItems: boolean; ItemsAreObjects: boolean; ItemGuardProc: UtilsB2.TItemGuardProc; (* n *) var (* in *) ItemGuard: UtilsB2.TItemGuard);
begin
  {!} Assert(@ItemGuardProc <> nil);
  Self.fGrowthRate      := Self.DEFAULT_GROWTH_RATE;
  Self.fOwnsItems       := OwnsItems;
  Self.fItemsAreObjects := ItemsAreObjects;
  Self.fItemGuardProc   := ItemGuardProc;
  Self.fItemGuard       := ItemGuard;
  ItemGuard             := nil;
end; // .constructor TList.Create

destructor TList.Destroy;
begin
  Self.Clear;
  Legacy.FreeAndNil(Self.fItemGuard);
end; // .destructor TList.Destroy

procedure TList.Assign (Source: UtilsB2.TCloneable);
var
(* U *) SrcList:  TList;
        i:        integer;
  
begin
  {!} Assert(Source <> nil);
  SrcList :=  Source AS TList;
  // * * * * * //
  if Self <> Source then begin
    Self.Clear;
    Self.fCapacity        := SrcList.Capacity;
    Self.fCount           := SrcList.Count;
    Self.fGrowthRate      := SrcList.GrowthRate;
    Self.fOwnsItems       := SrcList.OwnsItems;
    Self.fItemsAreObjects := SrcList.ItemsAreObjects;
    Self.fItemGuardProc   := SrcList.ItemGuardProc;
    Self.fItemGuard       := SrcList.fItemGuard.Clone;
    GetMem(Self.fData, Self.Capacity * sizeof(pointer));

    for i:=0 to SrcList.Count - 1 do begin
      if (SrcList.fData[i] = nil) or (not Self.OwnsItems) then begin
        Self.fData[i] := SrcList.fData[i];
      end else begin
        {!} Assert(Self.ItemsAreObjects);
        {!} Assert(TObject(SrcList.fData[i]) IS UtilsB2.TCloneable);
        Self.fData[i] := UtilsB2.TCloneable(SrcList.fData[i]).Clone;
      end;
    end;
  end; // .if
end; // .procedure TList.Assign

procedure TList.FreeItem (Ind: integer);
begin
  {!} Assert(Math.InRange(Ind, 0, Self.Count - 1));
  if Self.OwnsItems then begin
    if Self.ItemsAreObjects then begin
      Legacy.FreeAndNil(TObject(Self.fData[Ind]));
    end else begin
      FreeMem(Self.fData[Ind]); Self.fData[Ind] :=  nil;
    end;
  end;
end;

procedure TList.Clear;
var
  i:  integer;
  
begin
  if Self.OwnsItems then begin
    for i:=0 to Self.Count - 1 do begin
      Self.FreeItem(i);
    end;
  end;

  FreeMem(Self.fData); Self.fData :=  nil;
  Self.fCapacity  :=  0;
  Self.fCount     :=  0;
end; // .procedure TList.Clear

function TList.IsValidItem ((* n *) Item: pointer): boolean;
begin
  result  :=  Self.ItemGuardProc(Item, Self.ItemsAreObjects, Self.fItemGuard);
end;

procedure TList.Put (Ind: integer; (* OUn *) Item: pointer);
begin
  {!} Assert(Math.InRange(Ind, 0, Self.Count - 1));
  {!} Assert(Self.IsValidItem(Item));
  Self.FreeItem(Ind);
  Self.fData[Ind] :=  Item;
end;

function TList.Get (Ind: integer): (* n *) pointer;
begin
  {!} Assert(Math.InRange(Ind, 0, Self.Count - 1), string(Legacy.Format('List index %d is invalid for list of size %d', [Ind, Self.Count])));
  result  :=  Self.fData[Ind];
end;

procedure TList.SetGrowthRate (NewGrowthRate: integer);
begin
  {!} Assert(NewGrowthRate >= 100);
  Self.fGrowthRate  :=  NewGrowthRate;
end;

procedure TList.SetCapacity (NewCapacity: integer);
var
  i:  integer;
  
begin
  {!} Assert(NewCapacity >= 0);
  if NewCapacity < Self.Count then begin
    for i:=NewCapacity to Self.Count - 1 do begin
      Self.FreeItem(i);
    end;
  end;
  Self.fCapacity  :=  NewCapacity;
  ReallocMem(Self.fData, Self.Capacity * sizeof(pointer));
end; // .procedure TList.SetCapacity

procedure TList.SetCount (NewCount: integer);
var
  i:  integer;
  
begin
  {!} Assert(NewCount >= 0);
  if NewCount < Self.Count then begin
    for i:=NewCount to Self.Count - 1 do begin
      Self.FreeItem(i);
    end;
  end else if NewCount > Self.Count then begin
    if NewCount > Self.Capacity then begin
      Self.SetCapacity(NewCount);
    end;
    for i:=Self.Count to NewCount - 1 do begin
      Self.fData[i] :=  nil;
    end;
  end; // .elseif
  Self.fCount :=  NewCount;
end; // .procedure TList.SetCount

function TList.AddEmpty: integer;
begin
  result  :=  Self.Count;
  if Self.Count = Self.Capacity then begin
    if Self.Capacity = 0 then begin
      Self.fCapacity  :=  Self.FIRST_ALLOC_COUNT;
    end else begin
      Self.fCapacity  :=  Math.Max(Self.Capacity + 1, INT64(Self.Capacity) * Self.GrowthRate div 100);
    end;
    ReallocMem(Self.fData, Self.Capacity * sizeof(pointer));
  end;
  Self.fData[Self.Count]  :=  nil;
  Inc(Self.fCount);
end; // .function TList.AddEmpty

function TList.Add ((* OUn *) Item: pointer): integer;
begin
  {!} Assert(Self.IsValidItem(Item));
  result              :=  Self.AddEmpty;
  Self.fData[result]  :=  Item;
end;

function TList.Top: (* n *) pointer;
begin
  {!} Assert(Self.Count > 0);
  result  :=  Self.fData[Self.Count - 1];
end;

function TList.Pop: (* OUn *) pointer;
begin
  result  :=  Self.Top;
  Dec(Self.fCount);
end;

procedure TList.Delete (Ind: integer);
begin
  {!} Assert(Math.InRange(Ind, 0, Self.Count - 1));
  Self.FreeItem(Ind);
  Dec(Self.fCount);
  if Ind < Self.Count then begin
    UtilsB2.CopyMem((Self.Count - Ind) * sizeof(pointer), @Self.fData[Ind + 1], @Self.fData[Ind]);
  end;
end;

procedure TList.Insert ((* OUn *) Item: pointer; Ind: integer);
begin
  {!} Assert(Math.InRange(Ind, 0, Self.Count));
  if Ind = Self.Count then begin
    Self.Add(Item);
  end else begin
    {!} Assert(Self.IsValidItem(Item));
    Self.AddEmpty;
    UtilsB2.CopyMem((Self.Count - Ind - 1) * sizeof(pointer), @Self.fData[Ind], @Self.fData[Ind + 1]);
    Self.fData[Ind] :=  Item;
  end;
end; // .procedure TList.Insert

procedure TList.Exchange (SrcInd, DstInd: integer);
begin
  {!} Assert(Math.InRange(SrcInd, 0, Self.Count - 1));
  {!} Assert(Math.InRange(DstInd, 0, Self.Count - 1));
  UtilsB2.Exchange(integer(Self.fData[SrcInd]), integer(Self.fData[DstInd]));
end;

procedure TList.Move (SrcInd, DstInd: integer);
var
(* Un *)  SrcItem:  pointer;
          Dist:     integer;
  
begin
  {!} Assert(Math.InRange(SrcInd, 0, Self.Count - 1));
  {!} Assert(Math.InRange(DstInd, 0, Self.Count - 1));
  if SrcInd <> DstInd then begin
    Dist  :=  ABS(SrcInd - DstInd);
    if Dist = 1 then begin
      Self.Exchange(SrcInd, DstInd);
    end else begin
      SrcItem :=  Self.fData[SrcInd];
      if DstInd > SrcInd then begin
        UtilsB2.CopyMem(Dist * sizeof(pointer), @Self.fData[SrcInd + 1],  @Self.fData[SrcInd]);
      end else begin
        UtilsB2.CopyMem(Dist * sizeof(pointer), @Self.fData[DstInd],      @Self.fData[DstInd + 1]);
      end;
      Self.fData[DstInd]  :=  SrcItem;
    end; // .else
  end; // .if
end; // .procedure TList.Move

procedure TList.Shift (StartInd, Count, ShiftBy: integer);
var
  EndInd: integer;
  Step:   integer;
  i:      integer;
  
begin
  {!} Assert(Math.InRange(StartInd, 0, Self.Count - 1));
  {!} Assert(Count >= 0);
  Count :=  Math.EnsureRange(Count, 0, Self.Count - StartInd);
  if (ShiftBy <> 0) and (Count > 0) then begin
    if ShiftBy > 0 then begin
      StartInd  :=  StartInd + Count - 1;
    end;
    EndInd  :=  StartInd + ShiftBy;
    Step    :=  -SIGN(ShiftBy);
    for i:=1 to Count do begin
      if Math.InRange(EndInd, 0, Self.Count - 1) then begin
        Self.FreeItem(EndInd);
        UtilsB2.Exchange(integer(Self.fData[StartInd]), integer(Self.fData[EndInd]));
        StartInd  :=  StartInd + Step;
        EndInd    :=  EndInd + Step;
      end;
    end;
  end; // .if
end; // .procedure TList.Shift

function TList.Take (Ind: integer): (* OUn *) pointer;
begin
  {!} Assert(Math.InRange(Ind, 0, Self.Count - 1));
  {!} Assert(Self.IsValidItem(nil));
  result          :=  Self.fData[Ind];
  Self.fData[Ind] :=  nil;
end;

function TList.Replace (Ind: integer; (* OUn *) NewValue: pointer): (* OUn *) pointer;
begin
  {!} Assert(Math.InRange(Ind, 0, Self.Count - 1));
  {!} Assert(Self.IsValidItem(NewValue));
  result          :=  Self.fData[Ind];
  Self.fData[Ind] :=  NewValue;
end;

procedure TList.Pack;
var
  EndInd: integer;
  i:      integer;
  
begin
  i :=  0;
  while (i < Self.Count) and (Self.fData[i] <> nil) do begin
    Inc(i);
  end;
  if i < Count then begin
    EndInd    :=  i;
    for i:=i + 1 to Self.Count - 1 do begin
      if Self.fData[i] <> nil then begin
        Self.fData[EndInd]  :=  Self.fData[i];
        Inc(EndInd);
      end;
    end;
    Self.fCount :=  EndInd;
  end;
end; // .procedure TList.Pack

function TList.Find ((* n *) Item: pointer; out Ind: integer): boolean;
begin
  Ind :=  0;
  while (Ind < Self.Count) and (Self.fData[Ind] <> Item) do begin
    Inc(Ind);
  end;
  result  :=  Ind < Self.Count;
end;

function TList.QuickFind ((* n *) Item: pointer; out Ind: integer): boolean;
var
  LeftInd:    integer;
  RightInd:   integer;
  MiddleItem: integer;

begin
  result   := false;
  LeftInd  := 0;
  RightInd := Self.Count - 1;
  
  while (not result) and (LeftInd <= RightInd) do begin
    Ind        := LeftInd + (RightInd - LeftInd) shr 1;
    MiddleItem := integer(Self.fData[Ind]);
    
    if integer(Item) < MiddleItem then begin
      RightInd := Ind - 1;
    end else if integer(Item) > MiddleItem then begin
      LeftInd := Ind + 1;
    end else begin
      result := TRUE;
    end;
  end;
  
  if not result then begin
    Ind := LeftInd;
  end else begin
    Inc(Ind);
    
    while (Ind < Self.fCount) and (Self.fData[Ind] = Item) do begin
      Inc(Ind);
    end;
    
    Dec(Ind);
  end;
end; // .function TList.QuickFind

procedure TList.Sort;
begin
  if not Alg.IsSortedArr(pointer(Self.fData), 0, Self.Count - 1) then begin
    Alg.QuickSort(pointer(Self.fData), 0, Self.Count - 1);
  end;
end;

procedure TList.CustomSort (Compare: Alg.TCompareFunc);
begin
  if not Alg.IsCustomSortedArr(pointer(Self.fData), 0, Self.Count - 1, Compare) then begin
    Alg.CustomQuickSort(@Self.fData[0], 0, Self.Count - 1, Compare);
  end;
end;

procedure TList.CustomSort (Compare: Alg.TCompareMethod);
begin
  if not Alg.IsCustomSortedArr(pointer(Self.fData), 0, Self.Count - 1, Compare) then begin
    Alg.CustomQuickSort(@Self.fData[0], 0, Self.Count - 1, Compare);
  end;
end;

constructor TStringListQuickSortAdapter.Create ({U} List: TStringList; {n} CompareFunc: TStringListCompareFunc);
begin
  {!} Assert(List <> nil);
  // * * * * * //
  fList := List;

  if @CompareFunc <> nil then begin
    fCompareFunc := CompareFunc;
  end else begin
    fCompareFunc := Self.DefaultCompareFunc;
  end;

  fPivotKey   := '';
  fPivotValue := nil;
end; // .constructor TStringListQuickSortAdapter.Create

function TStringListQuickSortAdapter.DefaultCompareFunc (const Key1, Key2: myAStr; {Un} Value1, Value2: pointer): integer;
begin
  result := fList.CompareStrings(Key1, Key2);
end;

function TStringListQuickSortAdapter.CompareItems (Ind1, Ind2: integer): integer;
begin
  result := fCompareFunc(fList[Ind1], fList[Ind2], fList.Values[Ind1], fList.Values[Ind2]);
end;

procedure TStringListQuickSortAdapter.SwapItems (Ind1, Ind2: integer);
var
{Un} TempValue: pointer;
     TempKey:   myAStr;

begin
  TempKey            := fList[Ind1];
  TempValue          := fList.Values[Ind1];
  fList[Ind1]        := fList[Ind2];
  fList.Values[Ind1] := fList.Values[Ind2];
  fList[Ind2]        := TempKey;
  fList.Values[Ind2] := TempValue;
end;

procedure TStringListQuickSortAdapter.SavePivotItem (PivotItemInd: integer);
begin
  fPivotKey   := fList[PivotItemInd];
  fPivotValue := fList.Values[PivotItemInd];
end;

function TStringListQuickSortAdapter.CompareToPivot (Ind: integer): integer;
begin
  result := fCompareFunc(fList[Ind], fPivotKey, fList.Values[Ind], fPivotValue);
end;

constructor TStringList.Create (OwnsItems: boolean; ItemsAreObjects: boolean; ItemGuardProc: UtilsB2.TItemGuardProc; (* n *) var {IN} ItemGuard: UtilsB2.TItemGuard);
begin
  {!} Assert(@ItemGuardProc <> nil);
  Self.fGrowthRate      :=  Self.DEFAULT_GROWTH_RATE;
  Self.fOwnsItems       :=  OwnsItems;
  Self.fItemsAreObjects :=  ItemsAreObjects;
  Self.fItemGuardProc   :=  ItemGuardProc;
  Self.fItemGuard       :=  ItemGuard;
  ItemGuard             :=  nil;
end; // .constructor TStringList.Create

destructor TStringList.Destroy;
begin
  Self.Clear;
  Legacy.FreeAndNil(Self.fItemGuard);
end; // .destructor TStringList.Destroy

procedure TStringList.Assign (Source: UtilsB2.TCloneable);
var
(* U *) SrcList:  TStringList;
        i:        integer;
  
begin
  {!} Assert(Source <> nil);
  SrcList   :=  Source AS TStringList;
  // * * * * * //
  if Self <> Source then begin
    Self.Clear;
    Self.fKeys              :=  System.COPY(SrcList.fKeys);
    Self.fCapacity          :=  SrcList.Capacity;
    Self.fCount             :=  SrcList.Count;
    Self.fGrowthRate        :=  SrcList.GrowthRate;
    Self.fOwnsItems         :=  SrcList.OwnsItems;
    Self.fItemsAreObjects   :=  SrcList.ItemsAreObjects;
    Self.fItemGuardProc     :=  SrcList.ItemGuardProc;
    Self.fItemGuard         :=  SrcList.fItemGuard.Clone;
    Self.fCaseInsensitive   :=  SrcList.CaseInsensitive;
    Self.fForbidDuplicates  :=  SrcList.ForbidDuplicates;
    Self.fSorted            :=  SrcList.Sorted;
    GetMem(Self.fValues, Self.Count * sizeof(pointer));
    for i:=0 to SrcList.Count - 1 do begin
      if (SrcList.fValues[i] = nil) or (not Self.OwnsItems) then begin
        Self.fValues[i] :=  SrcList.fValues[i];
      end else begin
        {!} Assert(Self.ItemsAreObjects);
        {!} Assert(TObject(SrcList.fValues[i]) IS UtilsB2.TCloneable);
        Self.fValues[i] :=  UtilsB2.TCloneable(SrcList.fValues[i]).Clone;
      end;
    end;
  end; // .if
end; // .procedure TStringList.Assign

procedure TStringList.FreeValue (Ind: integer);
begin
  {!} Assert(Math.InRange(Ind, 0, Self.Count - 1));
  if Self.OwnsItems then begin
    if Self.ItemsAreObjects then begin
      Legacy.FreeAndNil(TObject(Self.fValues[Ind]));
    end else begin
      FreeMem(Self.fValues[Ind]); Self.fValues[Ind] :=  nil;
    end;
  end;
end; // .procedure TStringList.FreeValue

procedure TStringList.Clear;
var
  i:  integer;
  
begin
  if Self.OwnsItems then begin
    for i:=0 to Self.Count - 1 do begin
      Self.FreeValue(i);
    end;
  end;
  Self.fKeys  :=  nil;
  FreeMem(Self.fValues); Self.fValues :=  nil;
  Self.fCapacity  :=  0;
  Self.fCount     :=  0;
end; // .procedure TStringList.Clear

function TStringList.IsValidItem ((* n *) Item: pointer): boolean;
begin
  result  :=  Self.ItemGuardProc(Item, Self.ItemsAreObjects, Self.fItemGuard);
end;

function TStringList.ValidateKey (const Key: myAStr): boolean;
var
  KeyInd: integer;

begin
  result  :=  not Self.ForbidDuplicates;
  if not result then begin
    result  :=  not Self.Find(Key, KeyInd);
  end;
end;

procedure TStringList.PutKey (Ind: integer; const Key: myAStr);
begin
  {!} Assert(Math.InRange(Ind, 0, Self.Count - 1));
  {!} Assert(not Self.Sorted);
  if Self.ForbidDuplicates then begin
    {!} Assert((Self.CompareStrings(Self.fKeys[Ind], Key) = 0) or Self.ValidateKey(Key));
  end;
  Self.fKeys[Ind] :=  Key;
end;

function TStringList.GetKey (Ind: integer): myAStr;
begin
  {!} Assert(Math.InRange(Ind, 0, Self.Count - 1));
  result  :=  Self.fKeys[Ind];
end;

procedure TStringList.PutValue (Ind: integer; (* OUn *) Item: pointer);
begin
  {!} Assert(Math.InRange(Ind, 0, Self.Count - 1));
  if Item <> Self.fValues[Ind] then begin
    {!} Assert(Self.IsValidItem(Item));
    Self.FreeValue(Ind);
    Self.fValues[Ind] :=  Item;
  end;
end;

function TStringList.GetValue (Ind: integer): (* n *) pointer;
begin
  {!} Assert(Math.InRange(Ind, 0, Self.Count - 1));
  result  :=  Self.fValues[Ind];
end;

function TStringList.AddEmpty: integer;
begin
  result  :=  Self.Count;
  if Self.Count = Self.Capacity then begin
    if Self.Capacity = 0 then begin
      Self.fCapacity  :=  Self.FIRST_ALLOC_COUNT;
    end else begin
      Self.fCapacity  :=  Math.Max(Self.Capacity + 1, INT64(Self.Capacity) * Self.GrowthRate div 100);
    end;
    ReallocMem(Self.fValues, Self.Capacity * sizeof(pointer));
    SetLength(Self.fKeys, Self.Capacity);
  end;
  Self.fKeys[Self.Count]    :=  '';
  Self.fValues[Self.Count]  :=  nil;
  Inc(Self.fCount);
end; // .function TStringList.AddEmpty

procedure TStringList.SetGrowthRate (NewGrowthRate: integer);
begin
  {!} Assert(NewGrowthRate >= 100);
  Self.fGrowthRate  :=  NewGrowthRate;
end;

procedure TStringList.SetCapacity (NewCapacity: integer);
var
  i:  integer;
  
begin
  {!} Assert(NewCapacity >= 0);
  if NewCapacity < Self.Count then begin
    for i:=NewCapacity to Self.Count - 1 do begin
      Self.FreeValue(i);
    end;
  end;
  Self.fCapacity  :=  NewCapacity;
  ReallocMem(Self.fValues, Self.Capacity * sizeof(pointer));
  SetLength(Self.fKeys, Self.Capacity);
end; // .procedure TStringList.SetCapacity

procedure TStringList.SetCount (NewCount: integer);
var
  i:  integer;
  
begin
  {!} Assert(NewCount >= 0);
  if NewCount < Self.Count then begin
    for i:=NewCount to Self.Count - 1 do begin
      Self.FreeValue(i);
    end;
  end else if NewCount > Self.Count then begin
    if NewCount > Self.Capacity then begin
      Self.SetCapacity(NewCount);
    end;
    for i:=Self.Count to NewCount - 1 do begin
      Self.fKeys[i]   :=  '';
      Self.fValues[i] :=  nil;
    end;
  end; // .elseif
  Self.fCount :=  NewCount;
end; // .procedure TStringList.SetCount

function TStringList.AddObj (const Key: myAStr; (* OUn *) Value: pointer): integer;
var
  KeyInd:     integer;
  KeyFound:   boolean;

begin
  {!} Assert(Self.IsValidItem(Value));
  if Self.ForbidDuplicates or Self.Sorted then begin
    KeyFound  :=  Self.Find(Key, KeyInd);
    if Self.ForbidDuplicates then begin
      {!} Assert(not KeyFound);
    end;
  end;
  result                :=  Self.AddEmpty;
  Self.fKeys[result]    :=  Key;
  Self.fValues[result]  :=  Value;
  if Self.Sorted then begin
    Self.fSorted  :=  false;
    Self.Move(result, KeyInd);
    result        :=  KeyInd;
    Self.fSorted  :=  TRUE;
  end;
end; // .function TStringList.AddObj

function TStringList.Add (const Key: myAStr): integer;
begin
  result  :=  Self.AddObj(Key, nil);
end;

function TStringList.Top: myAStr;
begin
  {!} Assert(Self.Count > 0);
  result  :=  Self.fKeys[Self.Count - 1];
end;

function TStringList.Pop ((* OUn *) out Item: pointer): myAStr;
begin
  {!} Assert(Item = nil);
  {!} Assert(Self.Count > 0);
  result  :=  Self.fKeys[Self.Count - 1];
  Item    :=  Self.fValues[Self.Count - 1];
  Dec(Self.fCount);
end;

procedure TStringList.Delete (Ind: integer);
begin
  {!} Assert(Math.InRange(Ind, 0, Self.Count - 1));
  Self.FreeValue(Ind);
  Self.fKeys[Ind] :=  '';
  Dec(Self.fCount);
  if Ind < Self.Count then begin
    UtilsB2.CopyMem((Self.Count - Ind) * sizeof(myAStr),  @Self.fKeys[Ind + 1],   @Self.fKeys[Ind]);
    pointer(Self.fKeys[Self.Count]) :=  nil;
    UtilsB2.CopyMem((Self.Count - Ind) * sizeof(pointer), @Self.fValues[Ind + 1], @Self.fValues[Ind]);
  end;
end; // .procedure TStringList.Delete

procedure TStringList.InsertObj (const Key: myAStr; Value: (* OUn *) pointer; Ind: integer);
var
  LastInd:  integer;

begin
  {!} Assert(Math.InRange(Ind, 0, Self.Count));
  if Ind = Self.Count then begin
    Self.AddObj(Key, Value);
  end else begin
    {!} Assert(not Self.Sorted);
    {!} Assert(Self.IsValidItem(Value));
    LastInd :=  Self.AddEmpty;
    UtilsB2.CopyMem((LastInd - Ind) * sizeof(myAStr),   @Self.fKeys[Ind],   @Self.fKeys[Ind + 1]);
    UtilsB2.CopyMem((LastInd - Ind) * sizeof(pointer),  @Self.fValues[Ind], @Self.fValues[Ind + 1]);
    pointer(Self.fKeys[Ind])  :=  nil;
    Self.fKeys[Ind]           :=  Key;
    Self.fValues[Ind]         :=  Value;
  end; // .else
end; // .procedure TStringList.InsertObj

procedure TStringList.Insert ({!} const Key: myAStr; {!} Ind: integer);
begin
  {!} Self.InsertObj(Key, nil, Ind);
end;

procedure TStringList.Exchange (SrcInd, DstInd: integer);
begin
  {!} Assert(Math.InRange(SrcInd, 0, Self.Count - 1));
  {!} Assert(Math.InRange(DstInd, 0, Self.Count - 1));
  if SrcInd <> DstInd then begin
    {!} Assert(not Self.Sorted);
    UtilsB2.Exchange(integer(Self.fKeys[SrcInd]),   integer(Self.fKeys[DstInd]));
    UtilsB2.Exchange(integer(Self.fValues[SrcInd]), integer(Self.fValues[DstInd]));
  end;
end;

procedure TStringList.Move (SrcInd, DstInd: integer);
var
(* Un *)  SrcValue: pointer;
          SrcKey:   pointer;
          Dist:     integer;
  
begin
  {!} Assert(Math.InRange(SrcInd, 0, Self.Count - 1));
  {!} Assert(Math.InRange(DstInd, 0, Self.Count - 1));
  SrcValue  :=  nil;
  SrcKey    :=  nil;
  // * * * * * //
  if SrcInd <> DstInd then begin
    {!} Assert(not Self.Sorted);
    Dist  :=  SrcInd - DstInd;
    if ABS(Dist) = 1 then begin
      Self.Exchange(SrcInd, DstInd);
    end else begin
      SrcKey    :=  pointer(Self.fKeys[SrcInd]);
      SrcValue  :=  Self.fValues[SrcInd];
      UtilsB2.CopyMem(ABS(Dist) * sizeof(myAStr),   @Self.fKeys[DstInd],    @Self.fKeys[DstInd + Math.Sign(Dist)]);
      UtilsB2.CopyMem(ABS(Dist) * sizeof(pointer),  @Self.fValues[DstInd],  @Self.fValues[DstInd + Math.Sign(Dist)]);
      pointer(Self.fKeys[DstInd]) :=  SrcKey;
      Self.fValues[DstInd]        :=  SrcValue;
    end;
  end; // .if
end; // .procedure TStringList.Move

procedure TStringList.Shift (StartInd, Count, ShiftBy: integer);
var
  EndInd: integer;
  Step:   integer;
  i:      integer;
  
begin
  {!} Assert(Math.InRange(StartInd, 0, Self.Count - 1));
  {!} Assert(Count >= 0);
  Count :=  Math.EnsureRange(Count, 0, Self.Count - StartInd);
  if (ShiftBy <> 0) and (Count > 0) then begin
    if ShiftBy > 0 then begin
      StartInd  :=  StartInd + Count - 1;
    end;
    EndInd  :=  StartInd + ShiftBy;
    Step    :=  -SIGN(ShiftBy);
    for i:=1 to Count do begin
      if Math.InRange(EndInd, 0, Self.Count - 1) then begin
        Self.FreeValue(EndInd);
        Self.fKeys[EndInd]  :=  '';
        UtilsB2.Exchange(integer(Self.fKeys[StartInd]),   integer(Self.fKeys[EndInd]));
        UtilsB2.Exchange(integer(Self.fValues[StartInd]), integer(Self.fValues[EndInd]));
        StartInd  :=  StartInd + Step;
        EndInd    :=  EndInd + Step;
      end;
    end;
  end; // .if
end; // .procedure TStringList.Shift

function TStringList.TakeValue (Ind: integer): (* OUn *) pointer;
begin
  {!} Assert(Math.InRange(Ind, 0, Self.Count - 1));
  {!} Assert(Self.IsValidItem(nil));
  result            :=  Self.fValues[Ind];
  Self.fValues[Ind] :=  nil;
end;

function TStringList.ReplaceValue (Ind: integer; (* OUn *) NewValue: pointer): (* OUn *) pointer;
begin
  {!} Assert(Math.InRange(Ind, 0, Self.Count - 1));
  {!} Assert(Self.IsValidItem(NewValue));
  result            :=  Self.fValues[Ind];
  Self.fValues[Ind] :=  NewValue;
end;

procedure TStringList.Pack;
var
  EndInd: integer;
  i:      integer;
  
begin
  if Self.Sorted then begin
    i := 0;
    
    while (i < Self.Count) and (Self.fKeys[i] = '') do begin
      Inc(i);
    end;
    
    if i > 0 then begin
      UtilsB2.CopyMem(i * sizeof(myAStr), @Self.fKeys[i], @Self.fKeys[0]);
      Legacy.FillChar(Self.fKeys[Count - i], i * sizeof(myAStr), 0);
      UtilsB2.CopyMem(i * sizeof(pointer), @Self.fValues[i], @Self.fValues[0]);
      Self.fCount :=  Self.fCount - i;
    end;
  end else begin
    i :=  0;
    
    while (i < Self.Count) and (Self.fKeys[i] <> '') do begin
      Inc(i);
    end;
    
    if i < Count then begin
      EndInd := i;
      Self.FreeValue(i);
      
      for i := i + 1 to Self.Count - 1 do begin
        if Self.fKeys[i] <> '' then begin
          UtilsB2.Exchange(integer(Self.fKeys[EndInd]), integer(Self.fKeys[i]));
          Self.fValues[EndInd]  :=  Self.fValues[i];
          Inc(EndInd);
        end else begin
          Self.FreeValue(i);
        end;
      end;
      
      Self.fCount :=  EndInd;
    end; // .if
  end; // .else
end; // .procedure TStringList.Pack

function TStringList.CompareStrings (const Str1, Str2: myAStr): integer;
begin
  if Self.fCaseInsensitive then begin
    result := Legacy.AnsiCompareText(Str1, Str2);
  end else begin
    result := Legacy.AnsiCompareStr(Str1, Str2);
  end;
end;

function TStringList.QuickFind (const Key: myAStr; (* i *) out Ind: integer): boolean;
var
  LeftInd:    integer;
  RightInd:   integer;
  CmpRes:     integer;

begin
  result    :=  false;
  LeftInd   :=  0;
  RightInd  :=  Self.Count - 1;
  while (not result) and (LeftInd <= RightInd) do begin
    Ind     :=  LeftInd + (RightInd - LeftInd + 1) shr 1;
    CmpRes  :=  Self.CompareStrings(Key, Self.fKeys[Ind]);
    if CmpRes < 0 then begin
      RightInd  :=  Ind - 1;
    end else if CmpRes > 0 then begin
      LeftInd :=  Ind + 1;
    end else begin
      result  :=  TRUE;
    end;
  end; // .while
  
  if not result then begin
    Ind :=  LeftInd;
  end else if not Self.fForbidDuplicates then begin
    Inc(Ind);
    
    while (Ind < Self.fCount) and (Self.CompareStrings(Key, Self.fKeys[Ind]) = 0) do begin
      Inc(Ind);
    end;
    
    Dec(Ind);
  end; // .elseif
end; // .function TStringList.QuickFind

function TStringList.Find (const Key: myAStr; (* i *) out Ind: integer): boolean;
begin
  if Self.Sorted then begin
    result  :=  Self.QuickFind(Key, Ind);
  end else begin
    Ind :=  0;
    while (Ind < Self.Count) and (Self.CompareStrings(Self.fKeys[Ind], Key) <> 0) do begin
      Inc(Ind);
    end;
    result  :=  Ind < Self.Count;
    if not result then begin
      Dec(Ind);
    end;
  end; // .else
end; // .function TStringList.Find

procedure TStringList.QuickSort (MinInd, MaxInd: integer);
var
  LeftInd:    integer;
  RightInd:   integer;
  PivotItem:  myAStr;
  
begin
  {!} Assert(Self.fKeys <> nil);
  {!} Assert(MinInd >= 0);
  {!} Assert(MaxInd >= MinInd);
  
  while MinInd < MaxInd do begin
    LeftInd   :=  MinInd;
    RightInd  :=  MaxInd;
    PivotItem :=  Self.fKeys[MinInd + (MaxInd - MinInd) div 2];
    
    while LeftInd <= RightInd do begin
      while CompareStrings(Self.fKeys[LeftInd], PivotItem) < 0 do begin
        Inc(LeftInd);
      end;
      
      while CompareStrings(Self.fKeys[RightInd], PivotItem) > 0 do begin
        Dec(RightInd);
      end;
      
      if LeftInd <= RightInd then begin
        if CompareStrings(Self.fKeys[LeftInd], Self.fKeys[RightInd]) > 0 then begin
          UtilsB2.Exchange(integer(Self.fKeys[LeftInd]),    integer(Self.fKeys[RightInd]));
          UtilsB2.Exchange(integer(Self.fValues[LeftInd]),  integer(Self.fValues[RightInd]));
        end;
        
        Inc(LeftInd);
        Dec(RightInd);
      end;
    end; // .while
    
    (* MIN__RIGHT|{PIVOT}|LEFT__MAX *)
    
    if (RightInd - MinInd) < (MaxInd - LeftInd) then begin
      if RightInd > MinInd then begin
        Self.QuickSort(MinInd, RightInd);
      end;
      
      MinInd := LeftInd;
    end else begin
      if MaxInd > LeftInd then begin
        Self.QuickSort(LeftInd, MaxInd);
      end;
      
      MaxInd := RightInd;
    end; // .else
  end; // .while
end; // .procedure TStringList.QuickSort

procedure TStringList.Sort;
begin
  if not Self.Sorted then begin
    Self.fSorted := true;
    
    if Self.fCount > 1 then begin
      Self.QuickSort(0, Self.Count - 1);
    end;
  end;
end;

procedure TStringList.CustomSort (CompareFunc: TStringListCompareFunc; MinInd, MaxInd: integer);
begin
  {!} Assert(@CompareFunc <> nil);
  {!} Assert(MaxInd < fCount);

  fSorted := false;

  if Self.fCount > 1 then begin
    with TStringListQuickSortAdapter.Create(Self, CompareFunc) do begin
      Alg.QuickSortEx(TStringListQuickSortAdapter(UtilsB2.ObjFromMethod(FreeInstance)), MinInd, MaxInd);
      Free;
    end;
  end;
end; // .procedure TStringList.CustomSort

procedure TStringList.SetSorted (IsSorted: boolean);
begin
  if IsSorted then begin
    Self.Sort;
  end else begin
    Self.fSorted := false;
  end;
end;

procedure TStringList.EnsureNoDuplicates;
var
  Etalon: myAStr;
  i:      integer;
  y:      integer;
  
begin
  if Self.Sorted then begin
    for i:=1 to Self.Count - 1 do begin
      {!} Assert(Self.CompareStrings(Self.fKeys[i], Self.fKeys[i - 1]) <> 0);
    end;
  end else begin
    for i:=0 to Self.Count - 1 do begin
      Etalon := Self.fKeys[i];
      for y := i + 1 to Self.Count - 1 do begin
        {!} Assert(Self.CompareStrings(Etalon, Self.fKeys[y]) <> 0);
      end;
    end;
  end; // .else
end; // .procedure TStringList.EnsureNoDuplicates

procedure TStringList.SetCaseInsensitive (NewCaseInsensitive: boolean);
begin
  if (not Self.CaseInsensitive) and NewCaseInsensitive then begin
    Self.fCaseInsensitive :=  NewCaseInsensitive;
    Self.EnsureNoDuplicates;
  end;
  Self.fCaseInsensitive :=  NewCaseInsensitive;
end;

procedure TStringList.SetForbidDuplicates (NewForbidDuplicates: boolean);
begin
  if NewForbidDuplicates <> Self.ForbidDuplicates then begin
    if NewForbidDuplicates then begin
      Self.EnsureNoDuplicates;
    end;
    Self.fForbidDuplicates  :=  NewForbidDuplicates;
  end;
end;

procedure TStringList.LoadFromText (const Text, EndOfLineMarker: myAStr);
begin
  Self.Clear;
  Self.fKeys      :=  StrLib.Explode(Text, EndOfLineMarker);
  Self.fCapacity  :=  Length(Self.fKeys);
  Self.fCount     :=  Self.Capacity;
  GetMem(Self.fValues, Self.Count * sizeof(pointer));
  Legacy.FillChar(Self.fValues[0], Self.Count * sizeof(pointer), 0);
  if Self.Sorted then begin
    Self.fSorted  :=  false;
    Self.Sort;
  end;
  if Self.ForbidDuplicates then begin
    Self.EnsureNoDuplicates;
  end;
end; // .procedure TStringList.LoadFromText

function TStringList.ToText (const EndOfLineMarker: myAStr): myAStr;
var
  ClonedKeys: UtilsB2.TArrayOfStr;

begin
  if Self.Count = Self.Capacity then begin
    result := StrLib.Join(Self.fKeys, EndOfLineMarker);
  end else begin
    ClonedKeys := Self.fKeys;
    SetLength(ClonedKeys, Self.Count);
    result := StrLib.Join(ClonedKeys, EndOfLineMarker);
  end;
end; // .function TStringList.ToText

function TStringList.GetItem (const Key: myAStr): (* n *) pointer;
var
  Ind:  integer;

begin
  if Self.Find(Key, Ind) then begin
    result  :=  Self.fValues[Ind];
  end else begin
    result  :=  nil;
  end;
end; // .function TStringList.GetItem

procedure TStringList.PutItem (const Key: myAStr; (* OUn *) Value: pointer);
var
  Ind:  integer;

begin
  if Self.Find(Key, Ind) then begin
    Self.PutValue(Ind, Value);
  end else begin
    Self.AddObj(Key, Value);
  end;
end; // .procedure TStringList.PutItem

function NewList (OwnsItems: boolean; ItemsAreObjects: boolean; ItemType: TClass; AllowNIL: boolean): TList;
var
(* O *) ItemGuard:  UtilsB2.TDefItemGuard;

begin
  {!} Assert(ItemsAreObjects or (ItemType = UtilsB2.NO_TYPEGUARD));
  ItemGuard :=  UtilsB2.TDefItemGuard.Create;
  // * * * * * //
  ItemGuard.ItemType  :=  ItemType;
  ItemGuard.AllowNIL  :=  AllowNIL;
  result              :=  TList.Create(OwnsItems, ItemsAreObjects, @UtilsB2.DefItemGuardProc, UtilsB2.TItemGuard(ItemGuard));
end; // .function NewList

function NewStrictList ({n} TypeGuard: TClass): TList;
begin
  result  :=  NewList(UtilsB2.OWNS_ITEMS, UtilsB2.ITEMS_ARE_OBJECTS, TypeGuard, UtilsB2.ALLOW_NIL);
end;

function NewSimpleList: TList;
var
(* n *) ItemGuard:  UtilsB2.TCloneable;

begin
  ItemGuard :=  nil;
  // * * * * * //
  result  :=  TList.Create(not UtilsB2.OWNS_ITEMS, not UtilsB2.ITEMS_ARE_OBJECTS, @UtilsB2.NoItemGuardProc, ItemGuard);
end;

function NewStrList (OwnsItems: boolean; ItemsAreObjects: boolean; ItemType: TClass; AllowNIL: boolean): TStringList;
var
(* O *) ItemGuard:  UtilsB2.TDefItemGuard;

begin
  {!} Assert(ItemsAreObjects or (ItemType = UtilsB2.NO_TYPEGUARD));
  ItemGuard :=  UtilsB2.TDefItemGuard.Create;
  // * * * * * //
  ItemGuard.ItemType  :=  ItemType;
  ItemGuard.AllowNIL  :=  AllowNIL;
  result              :=  TStringList.Create(OwnsItems, ItemsAreObjects, @UtilsB2.DefItemGuardProc, UtilsB2.TItemGuard(ItemGuard));
end; // .function NewStrList

function NewStrictStrList ({n} TypeGuard: TClass): TStringList;
begin
  result  :=  NewStrList(UtilsB2.OWNS_ITEMS, UtilsB2.ITEMS_ARE_OBJECTS, TypeGuard, UtilsB2.ALLOW_NIL);
end;

function NewSimpleStrList: TStringList;
var
(* n *) ItemGuard:  UtilsB2.TCloneable;

begin
  ItemGuard :=  nil;
  // * * * * * //
  result  :=  TStringList.Create(not UtilsB2.OWNS_ITEMS, not UtilsB2.ITEMS_ARE_OBJECTS, @UtilsB2.NoItemGuardProc, ItemGuard);
end;

end.
