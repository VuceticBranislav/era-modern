unit CBinString;
{
DESCRIPTION:  Working with binary strings
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses SysUtils, UtilsB2, StrLib, CLang, Legacy;

(*
Binary string is an atom in language system. It is either unicode or ansi string.
*)

type
  PBinStringHeader = ^TBinStringHeader;
  TBinStringHeader = record
    StrSize:  integer;
  end; // .record TBinStringHeader
  
  PBinString = ^TBinString;
  TBinString = packed record (* FORMAT *)
    Header:   TBinStringHeader;
    (*
    Chars:    array Header.StrSize of byte;
    *)
    Chars:    UtilsB2.TEmptyRec;
  end; // .record TBinString

  TBinStringReader = class
    (***) protected (***)
                fConnected:             boolean;
      (* Un *)  fBinString:             PBinString;
                fStructMemoryBlockSize: integer;
                fUnicode:               boolean;

      function  GetStrSize: integer;
      function  GetStructSize: integer;

    (***) public (***)
      procedure Connect (BinString: PBinString; StructMemoryBlockSize: integer; Unicode: boolean);
      procedure Disconnect;
      function  Validate (out Error: myAStr): boolean;
      function  GetAnsiString:  AnsiString;
      function  GetWideString:  myWStr;

      constructor Create;
      
      property  Connected:              boolean read fConnected;
      property  BinString:              PBinString read fBinString;
      property  StructMemoryBlockSize:  integer read fStructMemoryBlockSize;
      property  Unicode:                boolean read fUnicode;
      property  StrSize:                integer read GetStrSize;
      property  StructSize:             integer read GetStructSize;
  end; // .class TBinStringReader


(***)  implementation  (***)
  
  
constructor TBinStringReader.Create;
begin
  Self.fConnected :=  FALSE;
end; // .constructor TBinStringReader.Create

procedure TBinStringReader.Connect (BinString: PBinString; StructMemoryBlockSize: integer; Unicode: boolean);
begin
  {!} Assert((BinString <> nil) or (StructMemoryBlockSize = 0));
  {!} Assert(StructMemoryBlockSize >= 0);
  Self.fConnected             :=  TRUE;
  Self.fBinString             :=  BinString;
  Self.fStructMemoryBlockSize :=  StructMemoryBlockSize;
  Self.fUnicode               :=  Unicode;
end;

procedure TBinStringReader.Disconnect;
begin
  Self.fConnected :=  FALSE;
end;

function TBinStringReader.Validate (out Error: myAStr): boolean;
  function ValidateMinStructSize: boolean;
  begin
    result  :=  Self.StructMemoryBlockSize >= sizeof(TBinString);
    if not result then begin
      Error :=  'The size of structure is too small: ' + Legacy.IntToStr(Self.StructMemoryBlockSize) + '/' + Legacy.IntToStr(sizeof(TBinString));
    end;
  end;

  function ValidateStrSizeField: boolean;
  var
    StrSize:  integer;

  begin
    StrSize :=  Self.StrSize;
    result  :=  (StrSize >= 0) and ((sizeof(TBinString) + StrSize) <= Self.StructMemoryBlockSize);
    if not result then begin
      Error :=  'Invalid StrSize field: ' + Legacy.IntToStr(StrSize);
    end;
  end; // .function ValidateStrSizeField

begin
  {!} Assert(Self.Connected);
  {!} Assert(Error = '');
  result  :=
    ValidateMinStructSize and
    ValidateStrSizeField;
end; // .function TBinStringReader.Validate

function TBinStringReader.GetStrSize: integer;
begin
  {!} Assert(Self.Connected);
  result  :=  Self.BinString.Header.StrSize;
end;

function TBinStringReader.GetStructSize: integer;
begin
  {!} Assert(Self.Connected);
  result  :=  sizeof(TBinString) + Self.StrSize;
end;

function TBinStringReader.GetAnsiString: AnsiString;
begin
  {!} Assert(Self.Connected);
  {!} Assert(not Self.Unicode);
  result  :=  StrLib.BytesToAnsiString(@Self.fBinString.Chars, Self.StrSize);
end;

function TBinStringReader.GetWideString: myWStr;
begin
  {!} Assert(Self.Connected);
  {!} Assert(Self.Unicode);
  result  :=  StrLib.BytesToWideString(@Self.fBinString.Chars, Self.StrSize);
end;
  
end.
