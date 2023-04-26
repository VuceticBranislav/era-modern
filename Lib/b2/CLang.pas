unit CLang;
{
DESCRIPTION:  Auxiliary unit for Lang
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

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
uses Legacy, SysUtils, Math, UtilsB2, Crypto;

const
  (* Names sizes restrictions *)
  CLIENTNAME_MAXLEN = 64;
  LANGNAME_LEN      = 3;


type
  PLngStructHeader = ^TLngStructHeader;
  TLngStructHeader = packed record
    Signature:    array [0..3] of myChar;
    StructSize:   integer;
    BodyCRC32Sum: integer;
    Body:         UtilsB2.TEmptyRec;
  end; // .record TLngStructHeader


function  GetCharSize (Unicode: boolean): integer; // BYME should be removed. may give wrong length
function  IsValidLangName (const LangName: myAStr): boolean;
function  IsValidClientName (const ClientName: myAStr): boolean;
function  ValidateLngStructHeader
(
  (* n *)       Header:                 PLngStructHeader;
                StructMemoryBlockSize:  integer;
                MinStructSize:          integer;
          const Signature:              myAStr;
          out   Error:                  myAStr
): boolean;
function  ValidateStructSize (FormalSize, RealSize: integer; out Error: myAStr): boolean;
function  GetEncodingPrefix (Unicode: boolean): myAStr;


(***)  implementation  (***)


function GetCharSize (Unicode: boolean): integer;
begin
  if Unicode then begin
    result  :=  2;
  end else begin
    result  :=  1;
  end;
end;

function IsValidLangName (const LangName: myAStr): boolean;
const
  ALLOWED = ['a'..'z'];

var
  i:            integer;
  LangNameLen:  integer;
  
begin
  LangNameLen :=  Length(LangName);
  result      :=  LangNameLen = LANGNAME_LEN;
  // * * * * * //
  i :=  1;
  while (i <= LANGNAME_LEN) and result do begin
    result  :=  LangName[i] in ALLOWED;
    Inc(i);
  end;
end; // .function IsValidLangName

function IsValidClientName (const ClientName: myAStr): boolean;
const
  NO_DOTS_ALLOWED = FALSE;

begin
  result  :=  (Length(ClientName) <= CLIENTNAME_MAXLEN) and Legacy.IsValidIdent(ClientName, NO_DOTS_ALLOWED);
end;

function ValidateLngStructHeader
(
  (* Un *)        Header:                 PLngStructHeader;
                  StructMemoryBlockSize:  integer;
                  MinStructSize:          integer;
            const Signature:              myAStr;
            out   Error:                  myAStr
): boolean;

var
  StructSize: integer;
  
  function ValidateMinStructSize: boolean;
  begin
    result  :=  StructMemoryBlockSize >= MinStructSize;
    if not result then begin
      Error :=  'The size of structure is too small: ' + Legacy.IntToStr(StructMemoryBlockSize) + '/' + Legacy.IntToStr(MinStructSize);
    end;
  end;

  function ValidateSignatureField: boolean;
  begin
    result  :=  Header.Signature = Signature;
    if not result then begin
      Error :=  myAStr('Structure signature is invalid: ') +
      Header.Signature + #13#10'. Expected: ' +
      Signature;
    end;
  end;
  
  function ValidateStructSizeField: boolean;
  begin
    StructSize  :=  Header.StructSize;
    result      :=  Math.InRange(StructSize, MinStructSize, StructMemoryBlockSize);
    if not result then begin
      Error :=  'Invalid StructSize field: ' + Legacy.IntToStr(StructSize);
    end;
  end;
  
  function ValidateBodyCrc32Field: boolean;
  var
    RealCRC32:  integer;
  
  begin
    RealCRC32 :=  Crypto.CRC32(@Header.Body, StructSize - sizeof(TLngStructHeader));
    result    :=  Header.BodyCRC32Sum = RealCRC32;
    if not result then begin
      Error :=  'CRC32 check failed. Original: ' + Legacy.IntToStr(Header.BodyCRC32Sum) + '. Current: ' + Legacy.IntToStr(RealCRC32);
    end;
  end; // .function ValidateBodyCrc32Field

begin
  {!} Assert((Header <> nil) or (StructMemoryBlockSize = 0));
  {!} Assert(StructMemoryBlockSize >= 0);
  {!} Assert(MinStructSize >= sizeof(TLngStructHeader));
  {!} Assert(Error = '');
  result  :=
    ValidateMinStructSize and
    ValidateSignatureField and
    ValidateStructSizeField and
    ValidateBodyCrc32Field;
end; // .function ValidateLngStructHeader

function ValidateStructSize (FormalSize, RealSize: integer; out Error: myAStr): boolean;
begin
  {!} Assert(FormalSize > 0);
  {!} Assert(RealSize >= 0);
  {!} Assert(Error = '');
  result  :=  FormalSize = RealSize;
  if not result then begin
    Error :=  'Invalid StructSize field: ' + Legacy.IntToStr(FormalSize) + '. Real size: ' + Legacy.IntToStr(RealSize);
  end;
end;

function GetEncodingPrefix (Unicode: boolean): myAStr;
begin
  if Unicode then begin
    result  :=  'wide';
  end else begin
    result  :=  'ansi';
  end;
end;

end.
