unit CLngPack;
{
DESCRIPTION:  Working with language packages
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses SysUtils, Math, Classes, UtilsB2, CLang, CLngUnit, Legacy;

const
  LNGPACK_SIGNATURE : myAStr = 'LPK';


type
  TUnicodeFlag  = boolean;

  PLngPackExtHeader = ^TLngPackExtHeader;
  TLngPackExtHeader = packed record
    NumLngUnits:  integer;
  end; // .record TLngPackExtHeader
  
  PLngPack = ^TLngPack;
  TLngPack = packed record (* FORMAT *)
    Header:     TLngStructHeader;
    ExtHeader:  TLngPackExtHeader;
    (*
    LngUnits:   array ExtHeader.NumLngUnits of TLngUnit
    *)
    LngUnits:   TEmptyRec;
  end; // .record TLngPack
      
  TLngPackReader = class
    (***) protected (***)
                fConnected:             boolean;
      (* Un *)  fLngPack:               PLngPack;
                fStructMemoryBlockSize: integer;
                fCurrLngUnitInd:        integer;
      (* Un *)  fCurrLngUnit:           CLngUnit.PLngUnit;
                fSearchIndexCreated:    boolean;
      (* O *)   fSearchIndex:           array [TUnicodeFlag] of Classes.TStringList;

      function  GetStructSize: integer;
      function  GetNumLngUnits: integer;
      procedure CreateSearchIndex;

    (***) public (***)
      procedure Connect (LngPack: PLngPack; StructMemoryBlockSize: integer);
      procedure Disconnect;
      function  Validate (out Error: myAStr): boolean;
      function  SeekLngUnit (SeekLngUnitInd: integer): boolean;
      function  ReadLngUnit ((* n *) var LngUnitReader: CLngUnit.TLngUnitReader): boolean;
      function  FindLngUnit (const UnitName: myAStr; Unicode: boolean; out LngUnitReader: CLngUnit.TLngUnitReader): boolean;

      constructor Create;
      destructor  Destroy; override;

      property  Connected:              boolean read fConnected;
      property  LngPack:                PLngPack read fLngPack;
      property  StructMemoryBlockSize:  integer read fStructMemoryBlockSize;
      property  StructSize:             integer read GetStructSize;
      property  NumLngUnits:            integer read GetNumLngUnits;
      property  CurrLngUnitInd:         integer read fCurrLngUnitInd;
  end; // .class TLngPackReader


(***)  implementation  (***)


constructor TLngPackReader.Create;
var
  Unicode:  boolean;

begin
  Self.fConnected :=  FALSE;
  for Unicode:=FALSE to TRUE do begin
    Self.fSearchIndex[Unicode]                :=  Classes.TStringList.Create;
    Self.fSearchIndex[Unicode].CaseSensitive  :=  TRUE;
    Self.fSearchIndex[Unicode].Duplicates     :=  Classes.dupError;
    Self.fSearchIndex[Unicode].Sorted         :=  TRUE;
  end;
end; // .constructor TLngPackReader.Create

destructor TLngPackReader.Destroy;
var
  Unicode:  boolean;

begin
  for Unicode:=FALSE to TRUE do begin
    Legacy.FreeAndNil(Self.fSearchIndex[Unicode]);
  end;
end; // .destructor TLngPackReader.Destroy

procedure TLngPackReader.Connect (LngPack: PLngPack; StructMemoryBlockSize: integer);
var
  Unicode:  boolean;

begin
  {!} Assert((LngPack <> nil) or (StructMemoryBlockSize = 0));
  {!} Assert(StructMemoryBlockSize >= 0);
  Self.fConnected             :=  TRUE;
  Self.fLngPack               :=  LngPack;
  Self.fStructMemoryBlockSize :=  StructMemoryBlockSize;
  Self.fCurrLngUnitInd        :=  0;
  Self.fCurrLngUnit           :=  nil;
  Self.fSearchIndexCreated    :=  FALSE;
  for Unicode:=FALSE to TRUE do begin
    Self.fSearchIndex[Unicode].Clear;
  end;
end; // .procedure TLngPackReader.Connect

procedure TLngPackReader.Disconnect;
begin
  Self.fConnected :=  FALSE;
end;

function TLngPackReader.Validate (out Error: myAStr): boolean;
var
        NumLngUnits:    integer;
        Unicode:        boolean;
(* O *) UnitNames:      array [TUnicodeFlag] of Classes.TStringList;
        RealStructSize: integer;
(* U *) LngUnit:        CLngUnit.PLngUnit;
(* O *) LngUnitReader:  CLngUnit.TLngUnitReader;
        i:              integer;

  function ValidateNumLngUnitsFields: boolean;
  begin
    NumLngUnits :=  Self.NumLngUnits;
    result  :=  (NumLngUnits >= 0) and ((NumLngUnits * sizeof(TLngUnit) + sizeof(TLngPack)) <= Self.StructMemoryBlockSize);
    if not result then begin
      Error :=  'Invalid NumLngUnits field: ' + Legacy.IntToStr(NumLngUnits);
    end;
  end;
  
begin
  {!} Assert(Self.Connected);
  {!} Assert(Error = '');
  RealStructSize        :=  -1;
  UnitNames[FALSE]      :=  Classes.TStringList.Create;
  UnitNames[TRUE]       :=  Classes.TStringList.Create;
  LngUnit               :=  nil;
  LngUnitReader         :=  CLngUnit.TLngUnitReader.Create;
  result                :=  CLang.ValidateLngStructHeader(@Self.LngPack.Header, Self.StructMemoryBlockSize, sizeof(TLngPack), LngPack_SIGNATURE, Error);
  // * * * * * //
  for Unicode:=FALSE to TRUE do begin
    UnitNames[Unicode].CaseSensitive  :=  TRUE;
    UnitNames[Unicode].Duplicates     :=  Classes.dupError;
    UnitNames[Unicode].Sorted         :=  TRUE;
  end;
  result  :=  result and ValidateNumLngUnitsFields;
  if result then begin
    RealStructSize  :=  sizeof(TLngPack);
    if NumLngUnits > 0 then begin
      i       :=  0;
      LngUnit :=  @Self.LngPack.LngUnits;
      while result and (i < NumLngUnits) do begin
        LngUnitReader.Connect(LngUnit, Self.StructMemoryBlockSize - RealStructSize);
        result  :=  LngUnitReader.Validate(Error);
        if result then begin
          try
            UnitNames[LngUnitReader.Unicode].Add(string(LngUnitReader.UnitNameA));
          except
            Error   :=  'Duplicate (UnitName && Unicode) combination in child structure: ' + LngUnitReader.UnitNameA +
                        '.'#13#10'Unicode: ' + Legacy.IntToStr(byte(LngUnitReader.Unicode));
            result  :=  FALSE;
          end;
        end;
        if result then begin
          RealStructSize  :=  RealStructSize + LngUnitReader.StructSize;
          Inc(integer(LngUnit), LngUnitReader.StructSize);
        end;
        Inc(i);
      end; // .while
    end; // .if
  end; // .if
  result  :=  result and CLang.ValidateStructSize(Self.LngPack.Header.StructSize, RealStructSize, Error);
  // * * * * * //
  for Unicode:=FALSE to TRUE do begin
    Legacy.FreeAndNil(UnitNames[Unicode]);
  end;
  Legacy.FreeAndNil(LngUnitReader);
end; // .function TLngPackReader.Validate

function TLngPackReader.GetStructSize: integer;
begin
  {!} Assert(Self.Connected);
  result  :=  Self.LngPack.Header.StructSize;
end;

function TLngPackReader.GetNumLngUnits: integer;
begin
  {!} Assert(Self.Connected);
  result  :=  Self.LngPack.ExtHeader.NumLngUnits;
end;

procedure TLngPackReader.CreateSearchIndex;
var
          SavedLngUnitInd:  integer;
(* on *)  LngUnitReader:    CLngUnit.TLngUnitReader;
  
begin
  {!} Assert(Self.Connected);
  LngUnitReader :=  nil;
  // * * * * * //
  if not Self.fSearchIndexCreated then begin
    SavedLngUnitInd :=  Self.CurrLngUnitInd;
    Self.SeekLngUnit(0);
    while Self.ReadLngUnit(LngUnitReader) do begin
      Self.fSearchIndex[LngUnitReader.Unicode].AddObject(string(LngUnitReader.UnitNameA), pointer(LngUnitReader.LngUnit));
    end;
    Self.SeekLngUnit(SavedLngUnitInd);
  end;
  // * * * * * //
  Legacy.FreeAndNil(LngUnitReader);
end; // .procedure TLngPackReader.CreateSearchIndex

function TLngPackReader.SeekLngUnit (SeekLngUnitInd: integer): boolean;
var
(* on *)  LngUnitReader: CLngUnit.TLngUnitReader;

begin
  {!} Assert(Self.Connected);
  {!} Assert(SeekLngUnitInd >= 0);
  LngUnitReader :=  nil;
  // * * * * * //
  result  :=  SeekLngUnitInd < Self.NumLngUnits;
  if result then begin
    if Self.fCurrLngUnitInd > SeekLngUnitInd then begin
      Self.fCurrLngUnitInd  :=  0;
    end;
    while Self.fCurrLngUnitInd < SeekLngUnitInd do begin
      Self.ReadLngUnit(LngUnitReader);
    end;
  end;
  // * * * * * //
  Legacy.FreeAndNil(LngUnitReader);
end; // .function TLngPackReader.SeekLngUnit

function TLngPackReader.ReadLngUnit ((* n *) var LngUnitReader: CLngUnit.TLngUnitReader): boolean;
begin
  {!} Assert(Self.Connected);
  result  :=  Self.fCurrLngUnitInd < Self.NumLngUnits;
  if result then begin
    if LngUnitReader = nil then begin
      LngUnitReader :=  CLngUnit.TLngUnitReader.Create;
    end;
    if Self.fCurrLngUnitInd = 0 then begin
      Self.fCurrLngUnit :=  @Self.LngPack.LngUnits;
    end;
    LngUnitReader.Connect(Self.fCurrLngUnit, Self.StructMemoryBlockSize - (integer(Self.fCurrLngUnit) - integer(Self.LngPack)));
    Inc(integer(Self.fCurrLngUnit), LngUnitReader.StructSize);
    Inc(Self.fCurrLngUnitInd);
  end; // .if
end; // .function TLngPackReader.ReadLngUnit 

function TLngPackReader.FindLngUnit (const UnitName: myAStr; Unicode: boolean; out LngUnitReader: CLngUnit.TLngUnitReader): boolean;
var
          LngUnitInd: integer;
(* Un *)  LngUnit:    CLngUnit.PLngUnit;

begin
  {!} Assert(Self.Connected);
  {!} Assert(LngUnitReader = nil);
  LngUnit :=  nil;
  result  :=  FALSE;
  // * * * * * //
  Self.CreateSearchIndex;
  LngUnitInd  :=  Self.fSearchIndex[Unicode].IndexOf(string(UnitName));
  result      :=  LngUnitInd <> -1;
  if result then begin
    LngUnit       :=  pointer(Self.fSearchIndex[Unicode].Objects[LngUnitInd]);
    LngUnitReader :=  CLngUnit.TLngUnitReader.Create;
    LngUnitReader.Connect(LngUnit, Self.StructMemoryBlockSize - (integer(LngUnit) - integer(Self.LngPack)));
  end;
end; // .function TLngPackReader.FindLngUnit

end.
