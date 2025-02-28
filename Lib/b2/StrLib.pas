unit StrLib;
(*
  DESCRIPTION: Strings processing
  AUTHOR:      Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
  WARNING:     The unit uses asserts for meaningfull operations, which will lead to bugs if assertions will be turned off.
               Such assertions should probably be replaced with custom exception generating function, not dependent on compiler flags.
*)

(***)  interface  (***)
uses Windows, Math, SysUtils, Classes, StrUtils, UtilsB2, Legacy;

const
  (* ExplodeEx *)
  INCLUDE_DELIM = True;
  LIMIT_TOKENS  = True;

  BINARY_CHARACTERS:     set of myChar = [#0..#8, #11..#12, #14..#31];
  CHARACTERS_TILL_SPACE: set of myChar = [#0..#32];

  PATH_DELIMS = ['\', '/'];

  (* Windows 7+ *)
  // Translate any Unicode characters that do not translate directly to multibyte equivalents to the default character specified by lpDefaultChar
  WC_NO_BEST_FIT_CHARS = $00000400;

  // Raise error on invalid character for ansi page
  WC_ERR_INVALID_CHARS = $80;

  FAIL_ON_ERROR = True;

type
  (* IMPORT *)
  TArrayOfStr  = UtilsB2.TArrayOfStr;

  TTrimSide  = (LEFT_SIDE, RIGHT_SIDE);
  TTrimSides = set of LEFT_SIDE..RIGHT_SIDE;

  PStrBulderItem = ^TStrBulderItem;
  TStrBulderItem = record
        Data:     array of myChar;
        DataSize: integer;
  {On}  NextItem: PStrBulderItem;
  end;

  IStrBuilder = interface
    procedure Append (const Str: myAStr);
    procedure AppendBuf (BufSize: integer; {n} Buf: pointer);
    procedure WriteByte (Value: byte);
    procedure WriteWord (Value: word);
    procedure WriteInt (Value: integer);
    function  BuildStr: myAStr;
    function  BuildBuf: UtilsB2.TArrayOfByte;
    procedure BuildTo ({n} Buf: pointer; BufSize: integer);
    procedure Clear;
  end;

  TStrBuilderChunkConsumer = function (Buf: pointer; BufSize: integer; Context: pointer = nil): boolean;

  TStrBuilder = class (TInterfacedObject, IStrBuilder)
   protected
    const
      MIN_BLOCK_SIZE = 65000;

    var
      {On} fRootItem: PStrBulderItem;
      {Un} fCurrItem: PStrBulderItem;
           fSize:     integer;
           fLocked:   boolean;

   public
    destructor Destroy; override;

    procedure Append (const Str: myAStr);
    procedure AppendWide (const Str: myWStr);
    procedure AppendBuf (BufSize: integer; {n} Buf: pointer);
    procedure AppendWithLenField (const Str: myAStr);
    procedure AppendWideWithLenField (const Str: myWStr);
    procedure WriteByte (Value: byte);
    procedure WriteWord (Value: word);
    procedure WriteInt (Value: integer);
    function  BuildStr: myAStr;
    function  BuildWideStr: myWStr;
    function  BuildBuf: UtilsB2.TArrayOfByte;
    procedure BuildTo ({n} Buf: pointer; BufSize: integer);
    procedure Clear;

    (* Iteratively passes all buffered contents by implementation specific chunks to user provided chunk consumer function. The function stops when all data is processed
       or when callback function returns false. Returns number of consumed bytes *)
    function PipeThrough (ChunkConsumer: TStrBuilderChunkConsumer; Context: pointer = nil): integer;

    property  Size: integer read fSize;
  end; // .class TStrBuilder

  IByteSource = interface
    (* Reads up to specified number of bytes to buffer. Returns number of actually read bytes *)
    function Read (Count: integer; {Un} Buf: pointer): integer;
  end;

  TStrByteSource = class (TInterfacedObject, IByteSource)
   protected
    fData:    myAStr;
    fDataLen: integer;
    fPos:     integer;

   public
    constructor Create (const Data: myAStr);

    function Read (Count: integer; {Un} Buf: pointer): integer;
  end;

  TBufByteSource = class (TInterfacedObject, IByteSource)
   protected
    {Un} fBuf:     pointer;
         fBufSize: integer;
         fPos:     integer;

   public
    constructor Create ({Un} Buf: pointer; BufSize: integer);

    function Read (Count: integer; {Un} Buf: pointer): integer;
  end;

  IByteMapper = interface
    function GetSource: IByteSource;
    procedure ReadToBuf (Count: integer; {n} Buf: pointer);
    function ReadByte: byte;
    function ReadWord: word;
    function ReadInt: integer;
    function ReadStr (StrLen: integer): myAStr;
    function ReadStrWithLenField (StrLenFieldSize: integer = sizeof(integer)): myAStr;
  end;

  (* All methods assert reading success *)
  TByteMapper = class (TInterfacedObject, IByteMapper)
   protected
    fByteSource: IByteSource;

   public
    constructor Create (ByteSource: IByteSource);

    function GetSource: IByteSource;
    procedure ReadToBuf (Count: integer; {n} Buf: pointer);
    function ReadByte: byte;
    function ReadWord: word;
    function ReadInt: integer;
    function ReadStr (StrLen: integer): myAStr;
    function ReadStrWithLenField (StrLenFieldSize: integer = sizeof(integer)): myAStr;
  end;

function  MakeStr: IStrBuilder;
function  StrAsByteSource (const Str: myAStr): IByteSource;
function  BufAsByteSource ({Un} Buf: pointer; BufSize: integer): IByteSource;
function  MapBytes (ByteSource: IByteSource): IByteMapper;
function  InStrBounds (Pos: integer; const Str: myAStr): boolean;
function  BytesToAnsiString (PBytes: PBYTE; NumBytes: integer): myAStr;
function  BytesToWideString (PBytes: PBYTE; NumBytes: integer): myWStr;
function  StrLen ({n} Str: myPChar): integer;
function  FindChar (Ch: myChar; const Str: myAStr; var {out} CharPos: integer): boolean;
function  FindCharEx (Ch: myChar; const Str: myAStr; StartPos: integer; var {out} CharPos: integer): boolean;
function  ReverseFindCharEx (Ch: myChar; const Str: myAStr; StartPos: integer; var {out} CharPos: integer): boolean;
function  ReverseFindChar (Ch: myChar; const Str: myAStr; var {out} CharPos: integer): boolean;
function  FindCharW (Ch: myWChar; const Str: myWStr; var {out} CharPos: integer): boolean;
function  FindCharExW (Ch: myWChar; const Str: myWStr; StartPos: integer; var {out} CharPos: integer): boolean;
function  FindCharsetEx (const Charset: UtilsB2.TCharSet; const Str: myAStr; StartPos: integer; var {out} CharPos: integer): boolean;
function  SkipCharsetEx (const Charset: UtilsB2.TCharSet; const Str: myAStr; StartPos: integer; var {out} CharPos: integer): boolean;
function  FindCharset (const Charset: UtilsB2.TCharSet; const Str: myAStr; var {out} CharPos: integer): boolean;

(* Both FindSubstr routines are wrappers around Delphi Pos function *)
function  FindSubstrEx (const Substr, Str: myAStr; StartPos: integer; var {out} SubstrPos: integer): boolean;

function  FindSubstr (const Substr, Str: myAStr; var {out} SubstrPos: integer): boolean;

(*
  Knuth-Morris-Pratt stable speed fast search algorithm.
  F('', Haystack, StartPos in range of Haystack) => true, StartPos
  F('', Haystack, StartPos out of range of Haystack) => false
*)
function  FindStr (const Needle, Haystack: myAStr; var {out} FoundPos: integer): boolean;

function  FindStrEx (const Needle, Haystack: myAStr; Pos: integer; var {out} FoundPos: integer): boolean;
function  ReplaceChar (WhatChar, WithChar: myChar; const Str: myAStr): myAStr;

(* Replaces characters from WhatChars string with correspoding characters in WithChars string in original string *)
function TranslateStr (const WhatChars, WithChars, Str: myAStr): myAStr;

(*
  f('') => NIL
  f(Str, '') => [Str]
*)
function  ExplodeEx (const Str, Delim: myAStr; InclDelim: boolean; LimitTokens: boolean; MaxTokens: integer): TArrayOfStr;
function  Explode (const Str: myAStr; const Delim: myAStr): TArrayOfStr;
function  Join (const Arr: TArrayOfStr; const Glue: myAStr): myAStr;

(* Returns true if string consists of #0..#32 characters only *)
function  IsEmpty (const Str: myAStr): boolean; overload;
function  IsEmpty ({n} Buf: myPChar): boolean; overload;

(*
  TemplArgs - pairs of (ArgName, ArgValue).
  Example: f('Hello, ~UserName~. You are ~Years~ years old.', ['Years', '20', 'UserName', 'Bob'], '~') =>
  => 'Hello, Bob. You are 20 years old'.
*)
function  BuildStr (const Template: myAStr; const TemplArgs: array of myAStr; TemplChar: myChar): myAStr;
function  CharsetToStr (const Charset: UtilsB2.TCharSet): myAStr;
function  IntToRoman (Value: integer): myAStr;
function  CharToLower (c: myChar): myChar;
function  CharToUpper (c: myChar): myChar;
function  Capitalize (const Str: myAStr): myAStr;
function  HexCharToByte (HexChar: myChar): byte;
function  ByteToHexChar (ByteValue: byte): myChar;
function  BinToHex (NumBytes: integer; Bytes: UtilsB2.PEndlessByteArr): myAStr;
function  Concat (const Strings: array of myAStr): myAStr; overload;

(* Routine can safely copy two pchars to buffer or concat existing pchar with another one (if Buf = Str1, i.e).
   Pass -1 for autodetecting null-terminating string lengths. Returns length of final string without null char *)
function  Concat ({n} Buf: myPChar; BufSize: integer; {n} Str1: myPChar; StrLen1: integer; {n} Str2: myPChar; StrLen2: integer = -1): integer; overload;

function  TrimEx (const Str: myAStr; const TrimCharSet: UtilsB2.TCharSet; TrimSides: TTrimSides = [LEFT_SIDE, RIGHT_SIDE]): myAStr;
function  TrimW (const Str: myWStr): myWStr;
function  TrimExW (const Str: myWStr; const TrimCharSet: UtilsB2.TCharSet; TrimSides: TTrimSides = [LEFT_SIDE, RIGHT_SIDE]): myWStr;

function  ExtractBaseFileName (const FilePath: myAStr): myAStr;
function  ExtractExt (const FilePath: myAStr): myAStr;
function  Substr ({n} Buf: myPChar; StartPos: integer; SubstrLen: integer = -1): myAStr;
function  SubstrBeforeChar (const Str: myAStr; Ch: myChar): myAStr;
function  Match (const Str, Pattern: myAStr): boolean;
function  MatchW (const Str, Pattern: myWStr): boolean;
function  ExtractFromPchar (Str: myPChar; Count: integer): myAStr;

(* Reads and parses [+-]\d++ value from buffer and returns true, if at least single digit is processed.
   BufPos is adjusted to point to next character. Overflows are allowed *)
function ParseIntFromPchar (var BufPos: myPChar; var Res: integer): boolean;

(* Consider using SetString (string, pchar, length) *)
function  BufToStr ({n} Buf: pointer; BufSize: integer): myAStr;

(*) Detects characters in the BINARY_CHARACTERS set *)
function  IsBinaryStr (const Str: myAStr): boolean;

function  Utf8ToAnsi (const Str: myAStr): myAStr;

(* Returns empty string on failure *)
function  Utf8ToWide (const Str: myAStr; FailOnError: boolean = false): myWStr;

(* Returns empty string on failure *)
function  WideToUtf8 (const Str: myWStr): myAStr;

function  PWideCharToAnsi (const Str: myPWChar; out Res: myAStr; FailOnError: boolean = false): boolean;

(* Converts null-terminated WideString to string, substituting invalid characters with special character *)
function  WideToAnsiSubstitute (const Str: myWStr): myAStr;

function  WideStringFromBuf ({n} Buf: myPWChar; NumChars: integer = -1): myWStr;
function  WideStringToBuf (const Str: myWStr; Buf: myPWChar): myPWChar;
function  WideLowerCase (const Str: myWStr): myWStr;
function  ExcludeLeadingBackslashW (const Str: myWStr; {n} HadLeadingBackslash: pboolean = nil): myWStr;
function  ExcludeTrailingBackslashW (const Str: myWStr; {n} HadTrailingBackslash: pboolean = nil): myWStr;
function  TrimBackslashesW (const Str: myWStr): myWStr;
function  ExtractDirPathW (const Path: myWStr): myWStr;
function  ExtractFileNameW (const Path: myWStr): myWStr;
function  ComparePchars ({n} Str1Ptr, {n} Str2Ptr: myPChar): integer;
function  CompareWideChars (Str1Ptr, Str2Ptr: myPWChar; Len: integer = -1): integer;
function  CompareBinStringsW (const Str1, Str2: myWStr): integer;


(***) implementation (***)


const
  BITS_IN_BYTE = 8;

destructor TStrBuilder.Destroy;
begin
  Self.Clear;
end;

procedure TStrBuilder.Append (const Str: myAStr);
begin
  Self.AppendBuf(Length(Str), pointer(Str));
end;

procedure TStrBuilder.AppendWithLenField (const Str: myAStr);
var
  StrLen: integer;

begin
  StrLen := Length(Str);
  Self.AppendBuf(sizeof(StrLen), @StrLen);
  Self.AppendBuf(StrLen, pointer(Str));
end;

procedure TStrBuilder.AppendWideWithLenField (const Str: myWStr);
var
  StrLen: integer;

begin
  StrLen := Length(Str);
  Self.AppendBuf(sizeof(StrLen), @StrLen);
  Self.AppendBuf(StrLen * sizeof(Str[1]), pointer(Str));
end;

procedure TStrBuilder.AppendWide (const Str: myWStr);
begin
  Self.AppendBuf(Length(Str) * sizeof(myWChar), pointer(Str));
end;

procedure TStrBuilder.AppendBuf (BufSize: integer; {n} Buf: pointer);
var
  LeftPartSize:  integer;
  RightPartSize: integer;

begin
  {!} Assert(UtilsB2.IsValidBuf(Buf, BufSize));
  {!} Assert(not Self.fLocked, 'Cannot append to TStrBuilder in a locked state');

  if BufSize > 0 then begin
    if Self.fRootItem = nil then begin
      New(Self.fRootItem);
      Self.fCurrItem := Self.fRootItem;
      SetLength(Self.fCurrItem.Data, Math.Max(BufSize, Self.MIN_BLOCK_SIZE));
      Self.fCurrItem.DataSize := 0;
      Self.fCurrItem.NextItem := nil;
    end;

    LeftPartSize  := Math.Min(BufSize, Length(Self.fCurrItem.Data) - Self.fCurrItem.DataSize);
    RightPartSize := BufSize - LeftPartSize;

    if LeftPartSize > 0 then begin
      UtilsB2.CopyMem(LeftPartSize, Buf, @Self.fCurrItem.Data[Self.fCurrItem.DataSize]);
    end;

    Inc(Self.fCurrItem.DataSize, LeftPartSize);

    if RightPartSize > 0 then begin
      New(Self.fCurrItem.NextItem);
      Self.fCurrItem          := Self.fCurrItem.NextItem;
      SetLength(Self.fCurrItem.Data, Math.Max(RightPartSize, Self.MIN_BLOCK_SIZE));
      Self.fCurrItem.DataSize := RightPartSize;
      Self.fCurrItem.NextItem := nil;
      UtilsB2.CopyMem(RightPartSize, UtilsB2.PtrOfs(Buf, LeftPartSize), @Self.fCurrItem.Data[0]);
    end;

    Self.fSize := Self.fSize + BufSize;
  end; // .if
end; // .procedure TStrBuilder.AppendBuf

procedure TStrBuilder.WriteByte (Value: byte);
begin
  Self.AppendBuf(sizeof(Value), @Value);
end;

procedure TStrBuilder.WriteWord (Value: word);
begin
  Self.AppendBuf(sizeof(Value), @Value);
end;

procedure TStrBuilder.WriteInt (Value: integer);
begin
  Self.AppendBuf(sizeof(Value), @Value);
end;

function TStrBuilder.BuildStr: myAStr;
var
{U} CurrItem: PStrBulderItem;
    Pos:      integer;

begin
  CurrItem := Self.fRootItem;
  // * * * * * //
  SetLength(result, Self.fSize);
  Pos := 0;

  while CurrItem <> nil do begin
    UtilsB2.CopyMem(CurrItem.DataSize, @CurrItem.Data[0], UtilsB2.PtrOfs(pointer(result), Pos));
    Pos      := Pos + CurrItem.DataSize;
    CurrItem := CurrItem.NextItem;
  end;
end;

function TStrBuilder.BuildWideStr: myWStr;
var
{U} CurrItem: PStrBulderItem;
    Pos:      integer;

begin
  CurrItem := Self.fRootItem;
  // * * * * * //
  SetLength(result, Ceil(Self.fSize / sizeof(myWChar)));
  Pos := 0;

  while CurrItem <> nil do begin
    UtilsB2.CopyMem(CurrItem.DataSize, @CurrItem.Data[0], UtilsB2.PtrOfs(pointer(result), Pos));
    Pos      := Pos + CurrItem.DataSize;
    CurrItem := CurrItem.NextItem;
  end;
end;

function TStrBuilder.BuildBuf: TArrayOfByte;
var
{U} CurrItem: PStrBulderItem;
    Pos:      integer;

begin
  CurrItem := Self.fRootItem;
  // * * * * * //
  SetLength(result, Self.fSize);
  Pos := 0;

  while CurrItem <> nil do begin
    UtilsB2.CopyMem(CurrItem.DataSize, @CurrItem.Data[0], UtilsB2.PtrOfs(pointer(result), Pos));
    Pos      := Pos + CurrItem.DataSize;
    CurrItem := CurrItem.NextItem;
  end;
end;

procedure TStrBuilder.BuildTo ({n} Buf: pointer; BufSize: integer);
var
{U} CurrItem: PStrBulderItem;
    Pos:      integer;

begin
  {!} Assert(UtilsB2.IsValidBuf(Buf, BufSize));
  CurrItem := Self.fRootItem;
  // * * * * * //
  Pos := 0;

  while (CurrItem <> nil) and (Pos < BufSize) do begin
    UtilsB2.CopyMem(Math.Min(BufSize - Pos, CurrItem.DataSize), @CurrItem.Data[0], UtilsB2.PtrOfs(pointer(Buf), Pos));
    Inc(Pos, CurrItem.DataSize);
    CurrItem := CurrItem.NextItem;
  end;
end;

procedure TStrBuilder.Clear;
var
{Un}  CurrItem: PStrBulderItem;
{Un}  NextItem: PStrBulderItem;

begin
  {!} Assert(not Self.fLocked, 'Cannot clear TStrBuilder in a locked state');

  CurrItem := Self.fRootItem;
  NextItem := nil;
  // * * * * * //
  while CurrItem <> nil do begin
    NextItem := CurrItem.NextItem;
    Dispose(CurrItem);
    CurrItem := NextItem;
  end;

  Self.fRootItem := nil;
  Self.fCurrItem := nil;
  Self.fSize     := 0;
end;

function TStrBuilder.PipeThrough (ChunkConsumer: TStrBuilderChunkConsumer; Context: pointer = nil): integer;
var
  PrevLocked: longbool;
  ChunkItem:  PStrBulderItem;

begin
  result     := 0;
  PrevLocked := Self.fLocked;

  try
    Self.fLocked := true;
    ChunkItem    := Self.fRootItem;

    while ChunkItem <> nil do begin
      if ChunkItem.DataSize > 0 then begin
        ChunkConsumer(@ChunkItem.Data[0], ChunkItem.DataSize, Context);
        Inc(result, ChunkItem.DataSize);
        ChunkItem := ChunkItem.NextItem;
      end;
    end;
  finally
    Self.flocked := PrevLocked;
  end;
end;

constructor TStrByteSource.Create (const Data: myAStr);
begin
  inherited Create;

  fData    := Data;
  fDataLen := length(Data);
  fPos     := 0;
end;

function TStrByteSource.Read (Count: integer; {Un} Buf: pointer): integer;
begin
  {!} Assert(UtilsB2.IsValidBuf(Buf, Count));

  if Count = 0 then begin
    result := 0;
  end else begin
    result := Min(Count, fDataLen - fPos);

    if result > 0 then begin
      UtilsB2.CopyMem(Count, @fData[fPos + 1], Buf);
      inc(fPos, result);
    end;
  end;
end;

constructor TBufByteSource.Create ({Un} Buf: pointer; BufSize: integer);
begin
  {!} Assert(UtilsB2.IsValidBuf(Buf, BufSize));

  inherited Create;

  fBuf     := Buf;
  fBufSize := BufSize;
  fPos     := 0;
end;

function TBufByteSource.Read (Count: integer; {Un} Buf: pointer): integer;
begin
  {!} Assert(UtilsB2.IsValidBuf(Buf, Count));

  if Count = 0 then begin
    result := 0;
  end else begin
    result := Min(Count, fBufSize - fPos);

    if result > 0 then begin
      UtilsB2.CopyMem(Count, UtilsB2.PtrOfs(fBuf, fPos), Buf);
      inc(fPos, result);
    end;
  end;
end;

constructor TByteMapper.Create (ByteSource: IByteSource);
begin
  inherited Create;

  fByteSource := ByteSource;
end;

function TByteMapper.GetSource: IByteSource;
begin
  result := fByteSource;
end;

procedure TByteMapper.ReadToBuf (Count: integer; {n} Buf: pointer);
begin
  {!} Assert(fByteSource.Read(Count, Buf) = Count);
end;

function TByteMapper.ReadByte: byte;
begin
  {!} Assert(fByteSource.Read(sizeof(result), @result) = sizeof(result));
end;

function TByteMapper.ReadWord: word;
begin
  {!} Assert(fByteSource.Read(sizeof(result), @result) = sizeof(result));
end;

function TByteMapper.ReadInt: integer;
begin
  {!} Assert(fByteSource.Read(sizeof(result), @result) = sizeof(result));
end;

function TByteMapper.ReadStr (StrLen: integer): myAStr;
begin
  {!} Assert(StrLen >= 0);
  SetLength(result, StrLen);

  if StrLen > 0 then begin
    {!} Assert(fByteSource.Read(StrLen, @result[1]) = StrLen);
  end;
end;

function TByteMapper.ReadStrWithLenField (StrLenFieldSize: integer = sizeof(integer)): myAStr;
var
  StrLen: integer;

begin
  {!} Assert(StrLenFieldSize in [1, 2, 4, sizeof(integer)]);
  StrLen := 0;
  result := '';
  {!} Assert(fByteSource.Read(StrLenFieldSize, @StrLen) = StrLenFieldSize);
  {!} Assert(StrLen >= 0);

  if StrLen > 0 then begin
    SetLength(result, StrLen);
    {!} Assert(fByteSource.Read(StrLen, @result[1]) = StrLen);
  end;
end;

function MakeStr: IStrBuilder;
begin
  result := TStrBuilder.Create;
end;

function StrAsByteSource (const Str: myAStr): IByteSource;
begin
  result := TStrByteSource.Create(Str);
end;

function BufAsByteSource ({Un} Buf: pointer; BufSize: integer): IByteSource;
begin
  result := TBufByteSource.Create(Buf, BufSize);
end;

function MapBytes (ByteSource: IByteSource): IByteMapper;
begin
  result := TByteMapper.Create(ByteSource);
end;

function InStrBounds (Pos: integer; const Str: myAStr): boolean;
begin
  result := Math.InRange(Pos, 1, Length(Str));
end;

function StrLen ({n} Str: myPChar): integer;
begin
  result := 0;

  if (Str <> nil) and (Str^ <> #0) then begin
    result := Windows.LStrLenA(Str);
  end;
end;

function BytesToAnsiString (PBytes: PBYTE; NumBytes: integer): myAStr;
begin
  {!} Assert(PBytes <> nil);
  {!} Assert(NumBytes >= 0);
  SetLength(result, NumBytes);
  UtilsB2.CopyMem(NumBytes, PBytes, pointer(result));
end;

function BytesToWideString (PBytes: PBYTE; NumBytes: integer): myWStr;
begin
  {!} Assert(PBytes <> nil);
  {!} Assert(NumBytes >= 0);
  {!} Assert(UtilsB2.EVEN(NumBytes));
  SetLength(result, NumBytes shr 1);
  UtilsB2.CopyMem(NumBytes, PBytes, pointer(result));
end;

function FindCharEx (Ch: myChar; const Str: myAStr; StartPos: integer; var {out} CharPos: integer): boolean;
var
  StrLen: integer;
  i:      integer;

begin
  StrLen := Length(Str);
  result := Math.InRange(StartPos, 1, StrLen);

  if result then begin
    i :=  StartPos;

    while (i <= StrLen) and (Str[i] <> Ch) do begin
      Inc(i);
    end;

    result := i <= StrLen;

    if result then begin
      CharPos :=  i;
    end;
  end;
end; // .function FindCharEx

function ReverseFindCharEx (Ch: myChar; const Str: myAStr; StartPos: integer; var {out} CharPos: integer): boolean;
var
  StrLen: integer;
  i:      integer;

begin
  StrLen := Length(Str);
  result := Math.InRange(StartPos, 1, StrLen);

  if result then begin
    i :=  StartPos;

    while (i >= 1) and (Str[i] <> Ch) do begin
      Dec(i);
    end;

    result := i >= 1;

    if result then begin
      CharPos :=  i;
    end;
  end;
end; // .function ReverseFindCharEx

function FindChar (Ch: myChar; const Str: myAStr; var {out} CharPos: integer): boolean;
begin
  result := FindCharEx(Ch, Str, 1, CharPos);
end;

function ReverseFindChar (Ch: myChar; const Str: myAStr; var {out} CharPos: integer): boolean;
begin
  result := ReverseFindCharEx(Ch, Str, Length(Str), CharPos);
end;

function FindCharExW (Ch: myWChar; const Str: myWStr; StartPos: integer; var {out} CharPos: integer): boolean;
var
  CharPtr: myPWChar;
  StrLen:  integer;

begin
  CharPtr := nil;
  // * * * * * //
  StrLen := Length(Str);
  result := Math.InRange(StartPos, 1, StrLen);

  if result then begin
    CharPtr := myPWChar(Str) + (StartPos - 1);

    while (CharPtr^ <> #0) and (CharPtr^ <> Ch) do begin
      Inc(CharPtr);
    end;

    result := CharPtr^ <> #0;

    if result then begin
      CharPos := (CharPtr - myPWChar(Str)) + 1;
    end;
  end; // .if
end; // .function FindCharExW

function FindCharW (Ch: myWChar; const Str: myWStr; var {out} CharPos: integer): boolean;
begin
  result := FindCharExW(Ch, Str, 1, CharPos);
end;

function FindCharsetEx (const Charset: UtilsB2.TCharSet; const Str: myAStr; StartPos: integer; var {out} CharPos: integer): boolean;
var
  StrLen: integer;
  i:      integer;

begin
  {!} Assert(StartPos >= 1);
  StrLen := Length(Str);
  result := StartPos <= StrLen;

  if result then begin
    i :=  StartPos;

    while (i <= StrLen) and not (Str[i] in Charset) do begin
      Inc(i);
    end;

    result := i <= StrLen;

    if result then begin
      CharPos :=  i;
    end;
  end;
end; // .function FindCharsetEx

function FindCharset (const Charset: UtilsB2.TCharSet; const Str: myAStr; var {out} CharPos: integer): boolean;
begin
  result := FindCharsetEx(Charset, Str, 1, CharPos);
end;

function SkipCharsetEx (const Charset: UtilsB2.TCharSet; const Str: myAStr; StartPos: integer; var {out} CharPos: integer): boolean;
var
  StrLen: integer;
  i:      integer;

begin
  {!} Assert(StartPos >= 1);
  StrLen := Length(Str);
  result := StartPos <= StrLen;

  if result then begin
    i :=  StartPos;

    while (i <= StrLen) and (Str[i] in Charset) do begin
      Inc(i);
    end;

    result := i <= StrLen;

    if result then begin
      CharPos := i;
    end;
  end;
end; // .function SkipCharsetEx

function FindSubstrEx (const Substr, Str: myAStr; StartPos: integer; var {out} SubstrPos: integer): boolean;
var
  Pos: integer;

begin
  Pos := Legacy.PosEx(Substr, Str, StartPos);

  if Pos <> 0 then begin
    SubstrPos := Pos;
    result    := true;
  end else begin
    result    := false;
  end;
end; // .function FindSubstrEx

function FindSubstr (const Substr, Str: myAStr; var {out} SubstrPos: integer): boolean;
begin
  result := FindSubstrEx(Substr, Str, 1, SubstrPos);
end;

function FindStrEx (const Needle, Haystack: myAStr; Pos: integer; var {out} FoundPos: integer): boolean;
const
  MAX_STATIC_FALLBACK_TABLE_LEN = 255;
  START_STRING_POS              = 1;

var
{O} FallbackTableBuf:          PEndlessIntArr;
    FallbackTableStackStorage: array [0..MAX_STATIC_FALLBACK_TABLE_LEN] of integer;
{U} FallbackTable:             PEndlessIntArr;

    NeedleLen:               integer;
    HaystackLen:             integer;
    FirstNeedleChar:         myChar;
    FirstFourNeedleChars:    integer;
    FarthestStartPos:        integer; // Last pos where there is any sense to start searching
    FallbackPos:             integer;
    HaystackPtr:             pinteger;
    HaystackEndMinusFourPtr: pinteger;
    i:                       integer;

  procedure GenerateFallbackTable;
  var
    k: integer;

  begin
    // Initialize fallback table pointer to either stack storage or memory buffer
    if NeedleLen <= MAX_STATIC_FALLBACK_TABLE_LEN then begin
      FallbackTable := @FallbackTableStackStorage[0];
    end else begin
      Legacy.GetMem(pointer(FallbackTableBuf), (NeedleLen + 1) * sizeof(integer));
      FallbackTable := FallbackTableBuf;
    end;

    // First not matched char always redirect to start, starting analysis from the the second one
    FallbackTable[START_STRING_POS] := START_STRING_POS;
    k                               := START_STRING_POS + 1;

    while k <= NeedleLen do begin
      // Search for the next occurense of needle prefix in the needle itself
      repeat
        FallbackTable[k] := START_STRING_POS;
        Inc(k);
      until (k > NeedleLen) or (Needle[k - 1] = FirstNeedleChar);

      // First char is already checked, starting from the second one
      i := START_STRING_POS + 1;

      if k <= NeedleLen then begin
        // While characters match needle prefix, fallback offsets grow
        // ab[abababab]c[ab]d
        // 11[12345678]1[12]1
        repeat
          FallbackTable[k] := i;
          Inc(i);
          Inc(k);
        until (k > NeedleLen) or (Needle[i] <> Needle[k]);
      end;
    end; // .while
  end; // .procedure GenerateFallbackTable

  procedure FindFirstNeedleChars;
  begin
    if Pos <= FarthestStartPos then begin
      HaystackPtr := @Haystack[Pos];

      while (cardinal(HaystackPtr) <= cardinal(HaystackEndMinusFourPtr)) and
            (HaystackPtr^ <> FirstFourNeedleChars)
      do begin
        Inc(pbyte(HaystackPtr));
      end;

      i := START_STRING_POS + sizeof(integer);

      if cardinal(HaystackPtr) <= cardinal(HaystackEndMinusFourPtr) then begin
        Pos := Pos + (integer(HaystackPtr) - integer(@Haystack[Pos])) + sizeof(integer);
      end else begin
        Pos := MAXINT;
      end;
    end; // .if
  end; // .procedure FindFirstNeedleChars

begin
  FallbackTableBuf := nil;
  FallbackTable    := nil;
  // * * * * * //
  if Pos < START_STRING_POS then begin
    Pos := START_STRING_POS;
  end;

  NeedleLen        := Length(Needle);
  HaystackLen      := Length(Haystack);
  FarthestStartPos := HaystackLen - NeedleLen + 1;
  result           := (Pos <= FarthestStartPos) and (HaystackLen > 0);

  if result then begin
    if NeedleLen = 0 then begin
      FoundPos := START_STRING_POS;
    end else if NeedleLen <= sizeof(integer) then begin
      result := FindSubstrEx(Needle, Haystack, Pos, FoundPos);
    end else begin
      FirstNeedleChar         := Needle[START_STRING_POS];
      FirstFourNeedleChars    := pinteger(@Needle[START_STRING_POS])^;
      HaystackEndMinusFourPtr := @Haystack[HaystackLen - sizeof(integer) + 1];
      GenerateFallbackTable;

      i := START_STRING_POS;
      FindFirstNeedleChars;

      while (Pos <= HaystackLen) and (i <= NeedleLen) do begin
        if Haystack[Pos] = Needle[i] then begin
          Inc(Pos);
          Inc(i);
        end else begin
          FallbackPos := FallbackTable[i];

          if FallbackPos = START_STRING_POS then begin
            FindFirstNeedleChars;
          end else begin
            i := FallbackPos;
          end;
        end; // .else
      end; // .while

      result := i > NeedleLen;

      if result then begin
        FoundPos := Pos - NeedleLen;
      end;
    end; // .else
  end; // .if
  // * * * * * //
  Legacy.FreeMem(pointer(FallbackTableBuf));
end; // .function FindStrEx

function FindStr (const Needle, Haystack: myAStr; var {out} FoundPos: integer): boolean;
begin
  result := FindStrEx(Needle, Haystack, 1, FoundPos);
end;

function ReplaceChar (WhatChar, WithChar: myChar; const Str: myAstr): myAstr;
var
  i: integer;

begin
  result := Str;

  for i := 1 to Length(result) do begin
    if result[i] = WhatChar then begin
      result[i] := WithChar;
    end;
  end;
end;

function TranslateStr (const WhatChars, WithChars, Str: myAstr): myAstr;
var
  ReplaceCharSet: set of myChar;
  Replacements:   array [Low(myChar)..High(myChar)] of myChar;
  i:              integer;

begin
  ReplaceCharSet := [];

  for i := 1 to Math.Min(Length(WhatChars), Length(WithChars)) do begin
    Include(ReplaceCharSet, WhatChars[i]);
    Replacements[AnsiChar(i)] := WithChars[i];
  end;

  result := Str;

  for i := 1 to Length(result) do begin
    if result[i] in ReplaceCharSet then begin
      result[i] := Replacements[AnsiChar(i)];
    end;
  end;
end;

function ExplodeEx (const Str, Delim: myAStr; InclDelim: boolean; LimitTokens: boolean; MaxTokens: integer): TArrayOfStr;
var
(* O *) DelimPosList:   Classes.TList {OF INTEGER};
        StrLen:         integer;
        DelimLen:       integer;
        DelimPos:       integer;
        DelimsLimit:    integer;
        NumDelims:      integer;
        TokenStartPos:  integer;
        TokenEndPos:    integer;
        TokenLen:       integer;
        i:              integer;

begin
  {!} Assert(not LimitTokens or (MaxTokens > 0));
  DelimPosList := Classes.TList.Create;
  result       := nil;
  // * * * * * //
  StrLen   := Length(Str);
  DelimLen := Length(Delim);

  if StrLen > 0 then begin
    if not LimitTokens then begin
      MaxTokens := MAXLONGINT;
    end;

    if DelimLen = 0 then begin
      SetLength(result, 1);
      result[0] := Str;
    end else begin
      DelimsLimit := MaxTokens - 1;
      NumDelims   := 0;
      DelimPos    := 1;

      while (NumDelims < DelimsLimit) and FindSubstrEx(Delim, Str, DelimPos, DelimPos) do begin
        DelimPosList.Add(pointer(DelimPos));
        Inc(DelimPos);
        Inc(NumDelims);
      end;

      DelimPosList.Add(pointer(StrLen + 1));
      SetLength(result, NumDelims + 1);
      TokenStartPos := 1;

      for i := 0 to NumDelims do begin
        TokenEndPos := integer(DelimPosList[i]);
        TokenLen    := TokenEndPos - TokenStartPos;

        if InclDelim and (i < NumDelims) then begin
          TokenLen := TokenLen + DelimLen;
        end;

        result[i]     := Copy(Str, TokenStartPos, TokenLen);
        TokenStartPos := TokenStartPos + DelimLen + TokenLen - ord(InclDelim);
      end; // .for
    end; // .else
  end; // .if
  // * * * * * //
  Legacy.FreeAndNil(DelimPosList);
end; // .function ExplodeEx

function Explode (const Str: myAStr; const Delim: myAStr): TArrayOfStr;
begin
  result := ExplodeEx(Str, Delim, not INCLUDE_DELIM, not LIMIT_TOKENS, 0);
end;

function Join (const Arr: TArrayOfStr; const Glue: myAStr): myAStr;
var
(* U *) Mem:        pointer;
        ArrLen:     integer;
        GlueLen:    integer;
        NumPairs:   integer;
        ResultSize: integer;
        i:          integer;

begin
  Mem    := nil;
  result := '';
  // * * * * * //
  ArrLen  := Length(Arr);
  GlueLen := Length(Glue);

  if ArrLen > 0 then begin
    NumPairs   := ArrLen - 1;
    ResultSize := 0;

    for i := 0 to ArrLen - 1 do begin
      ResultSize := ResultSize + Length(Arr[i]);
    end;

    ResultSize := ResultSize + NumPairs * GlueLen;
    SetLength(result, ResultSize);
    Mem := pointer(result);

    if GlueLen = 0 then begin
      for i := 0 to NumPairs - 1 do begin
        UtilsB2.CopyMem(Length(Arr[i]), pointer(Arr[i]), Mem);
        Mem :=  UtilsB2.PtrOfs(Mem, Length(Arr[i]));
      end;
    end else begin
      for i := 0 to NumPairs - 1 do begin
        UtilsB2.CopyMem(Length(Arr[i]), pointer(Arr[i]), Mem);
        Mem :=  UtilsB2.PtrOfs(Mem, Length(Arr[i]));
        UtilsB2.CopyMem(Length(Glue), pointer(Glue), Mem);
        Mem :=  UtilsB2.PtrOfs(Mem, Length(Glue));
      end;
    end; // .else

    UtilsB2.CopyMem(Length(Arr[NumPairs]), pointer(Arr[NumPairs]), Mem);
  end; // .if
end; // .function Join

function IsEmpty (const Str: myAStr): boolean; overload;
begin
  result := (Str = '') or IsEmpty(myPChar(Str));
end;

function IsEmpty ({n} Buf: myPChar): boolean; overload;
begin
  result := true;

  if Buf <> nil then begin
    while Buf^ <> #0 do begin
      if not (Buf^ in [#1..#32]) then begin
        result := false;
        exit;
      end;

      Inc(Buf);
    end;
  end;
end;

function BuildStr (const Template: myAStr; const TemplArgs: array of myAStr; TemplChar: myChar): myAStr;
var
  TemplTokens:    TArrayOfStr;
  NumTemplTokens: integer;
  NumTemplSlots:  integer;
  NumTemplArgs:   integer;
  i:              integer;

  function GetParam (const ParamName: myAStr): myAStr;
  var
    j: integer;

  begin
    j := 0;

    while (j < NumTemplArgs) do begin
      if TemplArgs[j] = ParamName then begin
        result := TemplArgs[j + 1];
        exit;
      end;

      inc(j, 2);
    end;

    result := TemplChar + ParamName + TemplChar;
  end;

begin
  NumTemplArgs := Length(TemplArgs);
  {!} Assert(UtilsB2.Even(NumTemplArgs));
  result := '';
  // * * * * * //
  if NumTemplArgs = 0 then begin
    result := Template;
  end else begin
    TemplTokens    := Explode(Template, TemplChar);
    NumTemplTokens := Length(TemplTokens);
    NumTemplSlots  := (NumTemplTokens - 1) div 2;

    if NumTemplSlots = 0 then begin
      result := Template;
    end else begin
      i := 1;

      while (i < NumTemplTokens) do begin
        TemplTokens[i] := GetParam(TemplTokens[i]);
        inc(i, 2);
      end;

      result := StrLib.Join(TemplTokens, '');
    end; // .else
  end; // .else
end; // .function BuildStr

function CharsetToStr (const Charset: UtilsB2.TCharSet): myAStr;
const
  CHARSET_CAPACITY  = 256;
  SPACE_PER_ITEM    = 3;
  DELIMETER         = myAStr(', ');
  DELIM_LEN         = Length(DELIMETER);

var
(* U *) BufPos:       ^myChar;
        Buffer:       array [0..(SPACE_PER_ITEM * CHARSET_CAPACITY + DELIM_LEN * (CHARSET_CAPACITY - 1)) - 1] of myChar;
        BufSize:      integer;
        StartItemInd: integer;
        FinitItemInd: integer;
        RangeLen:     integer;

  procedure WriteItem (c: myChar);
  begin
    if ORD(c) < ORD(' ') then begin
      BufPos^ :=  '#';                            Inc(BufPos);
      BufPos^ :=  myChar(ORD(c) div 10 + ORD('0'));  Inc(BufPos);
      BufPos^ :=  myChar(ORD(c) mod 10 + ORD('0'));  Inc(BufPos);
    end else begin
      BufPos^ :=  '"';  Inc(BufPos);
      BufPos^ :=  c;    Inc(BufPos);
      BufPos^ :=  '"';  Inc(BufPos);
    end;
    Inc(BufSize, SPACE_PER_ITEM);
  end; // .procedure WriteItem

begin
  BufPos := @Buffer[0];
  // * * * * * //
  BufSize      := 0;
  StartItemInd := 0;

  while StartItemInd < CHARSET_CAPACITY do begin
    if myChar(StartItemInd) in Charset then begin
      if BufSize > 0 then begin
        BufPos^ :=  DELIMETER[1]; Inc(BufPos);
        BufPos^ :=  DELIMETER[2]; Inc(BufPos);
        Inc(BufSize, DELIM_LEN);
      end;

      FinitItemInd := StartItemInd + 1;

      while (FinitItemInd < CHARSET_CAPACITY) and (myChar(FinitItemInd) in Charset) do begin
        Inc(FinitItemInd);
      end;

      RangeLen := FinitItemInd - StartItemInd;
      WriteItem(myChar(StartItemInd));

      if RangeLen > 1 then begin
        if RangeLen > 2 then begin
          BufPos^ :=  '-';
          Inc(BufPos);
          Inc(BufSize);
        end;

        WriteItem(myChar(FinitItemInd - 1));
      end;

      StartItemInd := FinitItemInd;
    end else begin
      Inc(StartItemInd);
    end; // .else
  end; // .while

  SetLength(result, BufSize);
  UtilsB2.CopyMem(BufSize, @Buffer[0], pointer(result));
end; // .function CharsetToStr

function IntToRoman (Value: integer): myAStr;
const
  Arabics:  array [0..12] of integer  = (1, 4, 5, 9, 10, 40, 50, 90, 100, 400, 500, 900, 1000);
  Romans:   array [0..12] of myAStr   = ('I', 'IV', 'V', 'IX', 'X', 'XL', 'L', 'XC', 'C', 'CD', 'D', 'CM', 'M');

var
  i:  integer;

begin
  {!} Assert(Value > 0);
  result := '';

  for i := 12 downto 0 do begin
    while Value >= Arabics[i] do begin
      Value  := Value - Arabics[i];
      result := result + Romans[i];
    end;
  end;
end; // .function IntToRoman

function CharToLower (c: myChar): myChar;
begin
  result := myChar(integer(Windows.CharLowerA(Ptr(ORD(c)))));
end;

function CharToUpper (c: myChar): myChar;
begin
  result := myChar(integer(Windows.CharUpperA(Ptr(ORD(c)))));
end;

function Capitalize (const Str: myAStr): myAStr;
begin
  result := Str;

  if result <> '' then begin
    result[1] := CharToUpper(result[1]);
  end;
end;

function HexCharToByte (HexChar: myChar): byte;
begin
  HexChar :=  CharToLower(HexChar);

  if HexChar in ['0'..'9'] then begin
    result := ORD(HexChar) - ORD('0');
  end else if HexChar in ['a'..'f'] then begin
    result := ORD(HexChar) - ORD('a') + 10;
  end else begin
    result := 0;
    {!} Assert(FALSE);
  end;
end; // .function HexCharToByte

function ByteToHexChar (ByteValue: byte): myChar;
begin
  {!} Assert(Math.InRange(ByteValue, $00, $0F));

  if ByteValue < 10 then begin
    result := myChar(ByteValue + ORD('0'));
  end else begin
    result := myChar(ByteValue - 10 + ORD('A'));
  end;
end;

function BinToHex (NumBytes: integer; Bytes: UtilsB2.PEndlessByteArr): myAStr;
const
  HEX_CHARS_PER_BYTE = 2;

var
  HalfByte: integer;
  i, j, k:  integer;

begin
  {!} Assert(UtilsB2.IsValidBuf(Bytes, NumBytes));
  result := '';

  if NumBytes > 0 then begin
    SetLength(result, NumBytes * HEX_CHARS_PER_BYTE);

    j := 1;

    for i := 0 to NumBytes - 1 do begin
      for k := 0 to 1 do begin
        HalfByte := (Bytes[i] shr (k shl 2)) and $0F;

        if HalfByte < 10 then begin
          result[j + 1 - k] := AnsiChar(HalfByte + ord('0'));
        end else begin
          result[j + 1 - k] := AnsiChar(HalfByte + ord('A') - 10);
        end;
      end;

      Inc(j, 2);
    end; // .for
  end; // .if
end; // .function BinToHex

function Concat (const Strings: array of myAStr): myAStr; overload;
var
  ResLen: integer;
  Offset: integer;
  StrLen: integer;
  i:      integer;

begin
  ResLen := 0;

  for i := 0 to High(Strings) do begin
    ResLen := ResLen + Length(Strings[i]);
  end;

  SetLength(result, ResLen);

  Offset := 0;

  for i := 0 to High(Strings) do begin
    StrLen := Length(Strings[i]);

    if StrLen > 0 then begin
      UtilsB2.CopyMem(StrLen, pointer(Strings[i]), UtilsB2.PtrOfs(pointer(result), Offset));
      Offset := Offset + StrLen;
    end;
  end;
end; // .function Concat

function Concat ({n} Buf: myPChar; BufSize: integer; {n} Str1: myPChar; StrLen1: integer; {n} Str2: myPChar; StrLen2: integer = -1): integer; overload;
var
{n} Caret: myPChar;

begin
  {!} Assert(UtilsB2.IsValidBuf(Buf, BufSize));
  Caret := Buf;
  // * * * * * //
  result := 0;

  if BufSize > 0 then begin
    Dec(BufSize);

    if (BufSize > 0) and (Str1 <> nil) and (Str1^ <> #0) and (StrLen1 <> 0) then begin
      if StrLen1 < 0 then begin
        StrLen1 := Windows.LStrLenA(Str1);
      end;

      StrLen1 := Math.Min(BufSize, StrLen1);
      Inc(result, StrLen1);

      if Str1 <> Buf then begin
        UtilsB2.CopyMem(StrLen1, Str1, Caret);
      end;

      Inc(Caret, StrLen1);
      Dec(BufSize, StrLen1);
    end; // .if

    if (BufSize > 0) and (Str2 <> nil) and (Str2^ <> #0) and (StrLen2 <> 0) then begin
      if StrLen2 < 0 then begin
        StrLen2 := Windows.LStrLenA(Str2);
      end;

      StrLen2 := Math.Min(BufSize, StrLen2);
      Inc(result, StrLen2);

      if (Str2 <> Buf) or (Caret <> Buf) then begin
        UtilsB2.CopyMem(StrLen2, Str2, Caret);
      end;

      Inc(Caret, StrLen2);
    end; // .if

    Caret^ := #0;
  end; // .if
end; // .function Concat

function TrimEx (const Str: myAStr; const TrimCharSet: UtilsB2.TCharSet; TrimSides: TTrimSides = [LEFT_SIDE, RIGHT_SIDE]): myAStr;
var
  StrLen: integer;
  Left:   integer;
  Right:  integer;

begin
  result := '';

  if Str <> '' then begin
    StrLen := length(Str);
    Left   := 1;
    Right  := StrLen;

    if LEFT_SIDE in TrimSides then begin
      while (Left <= Right) and (Str[Left] in TrimCharSet) do begin
        inc(Left);
      end;
    end;

    if (RIGHT_SIDE in TrimSides) and (Left <= Right) then begin
      while (Right >= 1) and (Str[Right] in TrimCharSet) do begin
        dec(Right);
      end;
    end;

    if Left <= Right then begin
      result := Copy(Str, Left, Right - Left + 1);
    end;
  end; // .if
end; // .function TrimEx

function TrimW (const Str: myWStr): myWStr;
begin
  result := TrimExW(Str, CHARACTERS_TILL_SPACE, [LEFT_SIDE, RIGHT_SIDE]);
end;

function TrimExW (const Str: myWStr; const TrimCharSet: UtilsB2.TCharSet; TrimSides: TTrimSides = [LEFT_SIDE, RIGHT_SIDE]): myWStr;
var
  StrLen: integer;
  Left:   integer;
  Right:  integer;

begin
  result := '';

  if Str <> '' then begin
    StrLen := Length(Str);
    Left   := 1;
    Right  := StrLen;

    if LEFT_SIDE in TrimSides then begin
      while (Left <= Right) and (ord(Str[Left]) < 255) and (myChar(Str[Left]) in TrimCharSet) do begin
        inc(Left);
      end;
    end;

    if (RIGHT_SIDE in TrimSides) and (Left <= Right) then begin
      while (Right >= 1) and (ord(Str[Right]) < 255) and (myChar(Str[Right]) in TrimCharSet) do begin
        dec(Right);
      end;
    end;

    if Left <= Right then begin
      result := Copy(Str, Left, Right - Left + 1);
    end;
  end; // .if
end; // .function TrimExW

function ExtractBaseFileName (const FilePath: myAStr): myAStr;
var
  DotPos: integer;

begin
  result := Legacy.ExtractFileName(FilePath);

  if ReverseFindChar('.', result, DotPos) then begin
    SetLength(result, DotPos - 1);
  end;
end;

function ExtractExt (const FilePath: myAStr): myAStr;
var
  DotPos: integer;

begin
  result := '';
  DotPos := Length(FilePath);

  while (DotPos > 0) and not (FilePath[DotPos] in ['.', '/', '\']) do begin
    Dec(DotPos);
  end;

  if (DotPos > 0) and (FilePath[DotPos] = '.') then begin
    result := Copy(FilePath, DotPos + 1);
  end;
end;

function Substr ({n} Buf: myPChar; StartPos: integer; SubstrLen: integer = -1): myAStr;
var
  StrLen: integer;

begin
  result := '';
  StrLen := 0;

  if SubstrLen = 0 then begin
    exit;
  end;

  if Buf <> nil then begin
    StrLen := Windows.LStrLenA(Buf);
  end;

  if StrLen = 0 then begin
    exit;
  end;

  StartPos := Math.Max(0, Math.Min(StartPos, StrLen));

  if StartPos >= StrLen then begin
    exit;
  end;

  if SubstrLen < 0 then begin
    SubstrLen := StrLen - StartPos;
  end else begin
    SubstrLen := Math.Min(StrLen - StartPos, SubstrLen);
  end;

  SetLength(result, SubstrLen);
  UtilsB2.CopyMem(SubstrLen, @Buf[StartPos], pointer(result));
end; // .function Substr

function SubstrBeforeChar (const Str: myAStr; Ch: myChar): myAStr;
var
  CharPos:  integer;

begin
  if FindChar(Ch, Str, CharPos) then begin
    result := COPY(Str, 1, CharPos - 1);
  end else begin
    result := Str;
  end;
end; // .function SubstrBeforeChar

function Match (const Str, Pattern: myAStr): boolean;
const
  ONE_SYM_WILDCARD  = '?';
  ANY_SYMS_WILDCARD = '*';
  WILDCARDS         = [ONE_SYM_WILDCARD, ANY_SYMS_WILDCARD];

type
  TState  =
  (
    STATE_STRICT_COMPARE,       // [abc]*?*?**cde?x*
    STATE_SKIP_WILDCARDS,       // abc[*?*?**]cde?x*
    STATE_FIRST_LETTER_SEARCH,  // abc*?*?**[c]de?x*
    STATE_MATCH_SUBSTR_TAIL,    // abc*?*?**c[de?x]*
    STATE_EXIT
  );

(*
  Non-greedy algorithm tries to treat ANY_SYMS_WILLCARD as the shortest possible string.
  Token is a substring between Base position and ANY_SYMS_WILLCARD or end of string in the template
  and corresponding matching substring in the string.

  Match "abcecd78e" against "a*cd*e": (Token is wrapped in parenthesis)

  (abcecd78e)
  (a*cd*e)

  => STRICT_COMPARE until * (success)

  (a  )(bcecd78e)
  (a* )(cd*e)

  => FIRST_LETTER_SEARCH "c" (success)

  (ab )(cecd78e)
  (a* )(cd*e)

  => MATCH_SUBSTR_TAIL "d" (fail)

  (abc)(ecd78e)
  (a* )(cd*e)

  => FIND_FIRST_LETTER "c" (success)

  (abce)(cd78e)
  (a*  )(cd*e)

  => MATCH_SUBSTR_TAIL "d" (success)

  (abce)(cd  )(78e)
  (a*  )(cd* )(e)

  => FIND_FIRST_LETTER "e" (success)

  (abce)(cd78)(e)
  (a*  )(cd* )(e)

  => exit
*)

(*
  Contracts for states:
    STATE_STRICT_COMPARE:
      - Entry state, not-reenterable
      - Matches character-to-character, including ONE_SYM_WILLCARD
      - Exits on mismatch
      - => STATE_SKIP_WILDCARDS
    STATE_SKIP_WILDCARDS:
      - Skips sequence of WILDCARDS
      - Increases position in the string for each ONE_SYM_WILDCARD
      - Exits on end of pattern
      - Initializes character "c" to current pattern character
      - => STATE_FIRST_LETTER_SEARCH
    STATE_FIRST_LETTER_SEARCH
      - Character [c] must be initialized before entering
      - Searches for character [c] in the string
      - Exits on end of string
      - Sets New token positions for string and token to current positions
      - => STATE_MATCH_SUBSTR_TAIL
    STATE_MATCH_SUBSTR_TAIL:
      - Matches character-to-character, including ONE_SYM_WILLCARD
      - Exits on end of string
      - Increases current token position in string by 1 and roll-backs to tokens positions in
        string and template on end of template or last character mismatch
      - => STATE_SKIP_WILDCARDS
*)

var
  State:          TState;
  StrLen:         integer;
  PatternLen:     integer;
  StrBasePos:     integer;  // Start position of current token
  PatternBasePos: integer;  // Start position of current token
  s:              integer;  // Pos in Pattern
  p:              integer;  // Pos in Str
  c:              myChar;     // First letter to search for

  procedure SkipMatchingSubstr;
  begin
    while
      (p <= PatternLen)                 and
      (s <= StrLen)                     and
      (Pattern[p] <> ANY_SYMS_WILDCARD) and
      (
        (Str[s]     = Pattern[p]) or
        (Pattern[p] = ONE_SYM_WILDCARD)
      )
    do begin
      Inc(p);
      Inc(s);
    end; // .while
  end; // .procedure SkipMatchingSubstr

begin
  StrLen         := Length(Str);
  PatternLen     := Length(Pattern);
  StrBasePos     := 1;
  PatternBasePos := 1;
  s              := 1;
  p              := 1;
  c              := #0;
  State          := STATE_STRICT_COMPARE;
  result         := FALSE;

  while State <> STATE_EXIT do begin
    case State of
      STATE_STRICT_COMPARE:
        begin
          SkipMatchingSubstr;

          if (p > PatternLen) or (Pattern[p] <> ANY_SYMS_WILDCARD) then begin
            State :=  STATE_EXIT;
          end else begin
            STATE :=  STATE_SKIP_WILDCARDS;
          end;
        end; // .case STATE_STRICT_COMPARE

      STATE_SKIP_WILDCARDS:
        begin
          while (p <= PatternLen) and (Pattern[p] in WILDCARDS) do begin
            if Pattern[p] = ONE_SYM_WILDCARD then begin
              Inc(s);
            end;

            Inc(p);
          end;

          if p <= PatternLen then begin
            c     := Pattern[p];
            State := STATE_FIRST_LETTER_SEARCH;
          end else begin
            if s <= StrLen then begin
              s := StrLen + 1;
            end;

            State := STATE_EXIT;
          end;
        end; // .case STATE_SKIP_WILDCARDS

      STATE_FIRST_LETTER_SEARCH:
        begin
          while (s <= StrLen) and (Str[s] <> c) do begin
            Inc(s);
          end;

          if s > StrLen then begin
            State := STATE_EXIT;
          end else begin
            StrBasePos     := s;
            PatternBasePos := p;
            Inc(p);
            Inc(s);
            State          := STATE_MATCH_SUBSTR_TAIL;
          end;
        end; // .case STATE_FIRST_LETTER_SEARCH

      STATE_MATCH_SUBSTR_TAIL:
        begin
          SkipMatchingSubstr;

          if (p > PatternLen) or (Pattern[p] = ANY_SYMS_WILDCARD) then begin
            State := STATE_STRICT_COMPARE;
          end else if ((PAttern[p]) = ONE_SYM_WILDCARD) or (s > StrLen) then begin
            STATE := STATE_EXIT;
          end else begin
            Inc(StrBasePos);
            p     := PatternBasePos;
            s     := StrBasePos;
            State := STATE_FIRST_LETTER_SEARCH;
          end;
        end; // .case STATE_MATCH_SUBSTR_TAIL
    end; // .switch State
  end; // .while

  result := (s = (StrLen + 1)) and (p = (PatternLen + 1));
end; // .function Match

function MatchW (const Str, Pattern: myWStr): boolean;
var
{n} StrAnchor:      myPWChar;
{n} PatternAnchor:  myPWChar;
    StrCharPtr:     myPWChar;
    PatternCharPtr: myPWChar;

begin
  StrAnchor      := nil;
  PatternAnchor  := nil;
  StrCharPtr     := myPWChar(Str);
  PatternCharPtr := myPWChar(Pattern);
  // * * * * * //
  while (StrCharPtr^ <> #0) and (PatternCharPtr^ <> '*') do begin
    if (PatternCharPtr^ <> StrCharPtr^) and (PatternCharPtr^ <> '?') then begin
      result := false;
      exit;
    end;

    Inc(StrCharPtr);
    Inc(PatternCharPtr);
  end;

  while StrCharPtr^ <> #0 do begin
    if PatternCharPtr^ = '*' then begin
      Inc(PatternCharPtr);

      if PatternCharPtr^ = #0 then begin
        result := true;
        exit;
      end;

      PatternAnchor := PatternCharPtr;
      StrAnchor     := StrCharPtr + 1;
    end else if (StrCharPtr^ = PatternCharPtr^) or (PatternCharPtr^ = '?') then begin
      Inc(StrCharPtr);
      Inc(PatternCharPtr);
    end else begin
      PatternCharPtr := PatternAnchor;
      StrCharPtr     := StrAnchor;
      Inc(StrAnchor);
    end;
  end; // .while

  while PatternCharPtr^ = '*' do begin
    Inc(PatternCharPtr);
  end;

  result := PatternCharPtr^ = #0;
end; // .function MatchW

function ExtractFromPchar (Str: myPChar; Count: integer): myAStr;
var
  Buf:    myPChar;
  StrLen: integer;

begin
  {!} Assert(Str <> nil);
  {!} Assert(Count >= 0);
  Buf := Str;
  // * * * * * //
  if Count > 0 then begin
    while (Count > 0) and (Str^ <> #0) do begin
      Dec(Count);
      Inc(Str);
    end;

    StrLen := Str - Buf;
    SetLength(result, StrLen);
    UtilsB2.CopyMem(StrLen, Buf, pointer(result));
  end;
end; // .function ExtractFromPchar

function ParseIntFromPchar (var BufPos: myPChar; var Res: integer): boolean;
var
  Value: integer;
  c:     myChar;
  IsNeg: boolean;

begin
  Value := 0;
  c     := BufPos^;
  IsNeg := c = '-';

  if IsNeg or (c = '+') then begin
    Inc(BufPos);
    c := BufPos^;
  end;

  result := c in ['0'..'9'];

  while c in ['0'..'9'] do begin
    Value := Value * 10 + (ord(c) - ord('0'));
    Inc(BufPos);
    c := BufPos^;
  end;

  if result then begin
    if IsNeg then begin
      Value := -Value;
    end;

    Res := Value;
  end;
end; // .function ParseIntFromPchar

function BufToStr ({n} Buf: pointer; BufSize: integer): myAStr;
begin
  {!} Assert(UtilsB2.IsValidBuf(Buf, BufSize));
  SetLength(result, BufSize);

  if BufSize > 0 then begin
    UtilsB2.CopyMem(BufSize, Buf, @result[1]);
  end;
end;

function IsBinaryStr (const Str: myAStr): boolean;
var
  i: integer;

begin
  i := 1;

  while (i <= Length(Str)) and not (Str[i] in BINARY_CHARACTERS) do begin
    Inc(i);
  end;

  result := i <= Length(Str);
end; // .function IsBinaryStr

function Utf8ToAnsi (const Str: myAStr): myAStr;
var
  TempBuf:    myAStr;
  TempBufLen: integer;
  ResBufLen:  integer;

begin
  result := '';

  if Str <> '' then begin
    TempBufLen := Windows.MultiByteToWideChar(Windows.CP_UTF8, 0, pointer(Str), length(Str), nil, 0);

    if TempBufLen <> 0 then begin
      SetLength(TempBuf, TempBufLen * sizeof(myWChar));
      TempBufLen := Windows.MultiByteToWideChar(Windows.CP_UTF8, 0, pointer(Str), length(Str), @TempBuf[1], TempBufLen);
      ResBufLen  := Windows.WideCharToMultiByte(Windows.CP_ACP, WC_NO_BEST_FIT_CHARS, pointer(TempBuf), TempBufLen, nil, 0, nil, nil);
      SetLength(result, ResBufLen * sizeof(myChar));
      ResBufLen  := Windows.WideCharToMultiByte(Windows.CP_ACP, WC_NO_BEST_FIT_CHARS, pointer(TempBuf), TempBufLen, @result[1], ResBufLen, nil, nil);

      if length(result) <> ResBufLen then begin
        SetLength(result, ResBufLen);
      end;
    end;
  end; // .if
end; // .function Utf8ToAnsi

function Utf8ToWide (const Str: myAStr; FailOnError: boolean = false): myWStr;
const
  MB_ERR_INVALID_CHARS = $8;

var
  ResBufLen: integer;

begin
  result := '';

  if Str <> '' then begin
    SetLength(result, Length(Str));
    ResBufLen := Windows.MultiByteToWideChar(Windows.CP_UTF8, MB_ERR_INVALID_CHARS * ord(FailOnError), pointer(Str), Length(Str), pointer(result), Length(result));

    if ResBufLen > 0 then begin
      if ResBufLen > Length(result) then begin
        SetLength(result, ResBufLen);
        ResBufLen := Windows.MultiByteToWideChar(Windows.CP_UTF8, MB_ERR_INVALID_CHARS * ord(FailOnError), pointer(Str), Length(Str), pointer(result), Length(result));
      end else begin
        SetLength(result, ResBufLen);
      end;
    end;

    if ResBufLen <> Length(result) then begin
      result := '';
    end;
  end; // .if
end; // .function Utf8ToWide

function WideToUtf8 (const Str: myWStr): myAStr;
const
  MAX_UTF8_CHARS_PER_WIDE_CHAR = 4;

var
  ResBufLen: integer;

begin
  result := '';

  if Str <> '' then begin
    SetLength(result, Length(Str) * MAX_UTF8_CHARS_PER_WIDE_CHAR);
    ResBufLen := Windows.WideCharToMultiByte(Windows.CP_UTF8, 0, myPWChar(Str), Length(Str), pointer(result), Length(result), nil, nil);

    if ResBufLen > 0 then begin
      SetLength(result, ResBufLen);
    end else begin
      result := '';
    end;
  end; // .if
end; // .function WideToUtf8

function PWideCharToAnsi (const Str: myPWChar; out Res: myAStr; FailOnError: boolean = false): boolean;
const
  AUTO_LEN      = -1;
  NULL_CHAR_LEN = sizeof(myChar);

var
  Flags:     integer;
  ResBufLen: integer;

begin
  result := true;
  Res    := '';

  if (Str <> nil) and (Str^ <> #0) then begin
    Flags := WC_NO_BEST_FIT_CHARS;

    if FailOnError then begin
      Flags := Flags or WC_ERR_INVALID_CHARS;
    end;

    ResBufLen := Windows.WideCharToMultiByte(Windows.CP_ACP, Flags, Str, AUTO_LEN, nil, 0, nil, nil);
    result    := ResBufLen > NULL_CHAR_LEN;

    if result then begin
      SetLength(Res, ResBufLen * sizeof(myChar) - NULL_CHAR_LEN);
      ResBufLen := Windows.WideCharToMultiByte(Windows.CP_ACP, Flags, Str, AUTO_LEN, @Res[1], ResBufLen, nil, nil);
      result    := ResBufLen = length(Res) + NULL_CHAR_LEN;
    end;

    if not result then begin
      Res := '';
    end;
  end; // .if
end; // .function PWideCharToAnsi

function WideToAnsiSubstitute (const Str: myWStr): myAStr;
begin
  PWideCharToAnsi(myPWChar(Str), result, not FAIL_ON_ERROR);
end;

function WideStringFromBuf ({n} Buf: myPWChar; NumChars: integer = -1): myWStr;
begin
  if NumChars < 0 then begin
    result := Buf;
  end else begin
    {!} Assert(UtilsB2.IsValidBuf(Buf, NumChars));
    result := '';

    if NumChars > 0 then begin
      SetLength(result, NumChars);

      if NumChars > 0 then begin
        UtilsB2.CopyMem(NumChars * sizeof(myWChar), Buf, @result[1]);
      end;
    end;
  end; // .else
end; // .function WideStringFromBuf

function WideStringToBuf (const Str: myWStr; Buf: myPWChar): myPWChar;
begin
  {!} Assert(Buf <> nil);
  result := Buf;
  // * * * * * //
  if Str <> '' then begin
    UtilsB2.CopyMem(length(Str) * sizeof(myWChar) + sizeof(myWChar), pointer(Str), Buf);
  end else begin
    Buf^ := #0;
  end;
end; // .function WideStringToBuf

function WideLowerCase (const Str: myWStr): myWStr;
begin
  result := Str;

  if result <> '' then begin
    UniqueString(result);
    Windows.CharLowerW(myPWChar(result));
  end;
end;

function ExcludeLeadingBackslashW (const Str: myWStr; {n} HadLeadingBackslash: pboolean = nil): myWStr;
var
  StrLen: integer;
  Pos:    integer;

begin
  result := Str;

  if result <> '' then begin
    StrLen := Length(result);
    Pos    := 1;

    while (Pos <= StrLen) and ((result[Pos] = '\') or (result[Pos] = '/')) do begin
      Inc(Pos);
    end;

    if Pos <> StrLen then begin
      SetLength(result, Pos);
    end;
  end;

  if HadLeadingBackslash <> nil then begin
    HadLeadingBackslash^ := Length(result) <> Length(Str);
  end;
end; // .function ExcludeTrailingBackslashW

function ExcludeTrailingBackslashW (const Str: myWStr; {n} HadTrailingBackslash: pboolean = nil): myWStr;
var
  StrLen: integer;
  Pos:    integer;

begin
  result := Str;

  if result <> '' then begin
    StrLen := Length(result);
    Pos    := StrLen;

    while (Pos >= 1) and ((result[Pos] = '\') or (result[Pos] = '/')) do begin
      Dec(Pos);
    end;

    if Pos <> StrLen then begin
      SetLength(result, Pos);
    end;
  end;

  if HadTrailingBackslash <> nil then begin
    HadTrailingBackslash^ := Length(result) <> Length(Str);
  end;
end; // .function ExcludeTrailingBackslashW

function TrimBackslashesW (const Str: myWStr): myWStr;
var
  StrLen:   integer;
  StartPos: integer;
  EndPos:   integer;
  ResLen:   integer;

begin
  result := Str;

  if result <> '' then begin
    StrLen   := Length(result);
    StartPos := 1;

    while (StartPos <= StrLen) and ((result[StartPos] = '\') or (result[StartPos] = '/')) do begin
      Inc(StartPos);
    end;

    EndPos := StrLen;

    while (EndPos >= StartPos) and ((result[EndPos] = '\') or (result[EndPos] = '/')) do begin
      Dec(EndPos);
    end;

    if (StartPos > 1) or (EndPos < StrLen) then begin
      ResLen := EndPos - StartPos + 1;
      SetLength(result, ResLen);

      if ResLen > 0 then begin
        UtilsB2.CopyMem(ResLen * sizeof(myWChar), @Str[StartPos], @result[1]);
      end;
    end;
  end; // .if
end; // .function TrimBackslashesW

function ExtractDirPathW (const Path: myWStr): myWStr;
var
  StartPtr: myPWChar;
  CharPtr:  myPWChar;

begin
  StartPtr := myPWChar(Path);
  CharPtr  := StartPtr + Length(Path);
  // * * * * * //
  result := '';

  while (CharPtr >= StartPtr) and not ((CharPtr^ = '\') or (CharPtr^ = '/')) do begin
    Dec(CharPtr);
  end;

  if CharPtr > StartPtr then begin
    while (CharPtr >= StartPtr) and ((CharPtr^ = '\') or (CharPtr^ = '/')) do begin
      Dec(CharPtr);
    end;

    Inc(CharPtr);
  end;

  if CharPtr > StartPtr then begin
    SetLength(result, CharPtr - StartPtr);
    UtilsB2.CopyMem((CharPtr - StartPtr) * sizeof(CharPtr^), StartPtr, @result[1]);
  end;

  if result = '' then begin
    result := '.';
  end;
end; // .function ExtractDirPathW

function ExtractFileNameW (const Path: myWStr): myWStr;
var
  StartPtr: myPWChar;
  EndPtr:   myPWChar;
  CharPtr:  myPWChar;

begin
  StartPtr := myPWChar(Path);
  EndPtr   := StartPtr + Length(Path);
  CharPtr  := EndPtr;
  // * * * * * //
  result := '';

  while (CharPtr >= StartPtr) and not ((CharPtr^ = '\') or (CharPtr^ = '/')) do begin
    Dec(CharPtr);
  end;

  Inc(CharPtr);

  if CharPtr < EndPtr then begin
    SetLength(result, EndPtr - CharPtr);
    UtilsB2.CopyMem((EndPtr - CharPtr) * sizeof(CharPtr^), CharPtr, @result[1]);
  end;
end; // .function ExtractFileNameW

function CompareUnalignedPchars (Str1Ptr, Str2Ptr: myPChar): integer;
begin
  while (Str1Ptr^ <> #0) and (Str1Ptr^ = Str2Ptr^) do begin
    Inc(Str1Ptr);
    Inc(Str2Ptr);
  end;

  result := ord(Str1Ptr^) - ord(Str2Ptr^);
end;

function CompareAlignedPchars (Str1Ptr, Str2Ptr: myPChar): integer; assembler
const
  LO_MAGIC = $01010101;
  HI_MAGIC = $80808080;

asm
  push esi
  push edi
@loop:
  mov esi, [eax]
  mov edi, [edx]
  cmp esi, edi
  jnz @perbyte_checking
  mov ecx, esi
  and ecx, HI_MAGIC
  not ecx
  sub esi, LO_MAGIC
  and esi, HI_MAGIC
  and esi, ecx
  jnz @perbyte_checking
  mov ecx, edi
  and ecx, HI_MAGIC
  not ecx
  sub edi, LO_MAGIC
  and edi, HI_MAGIC
  and edi, ecx
  jnz @perbyte_checking
  add eax, 4
  add edx, 4
  jmp @loop
@perbyte_checking:
  mov ecx, eax
  xor eax, eax
@perbyte_checking_loop:
  movzx eax, [byte ptr ecx]
  mov esi, eax
  movzx edi, [byte ptr edx]
  sub eax, edi
  jnz @ret
  test esi, esi
  jz @ret
  inc ecx
  inc edx
  jmp @perbyte_checking_loop
@ret:
  pop edi
  pop esi
end; // .function CompareAlignedPchars

function ComparePchars ({n} Str1Ptr, {n} Str2Ptr: myPChar): integer;
const
  ALIGNMENT_MASK = sizeof(integer) - 1;

begin
  if Str1Ptr = nil then begin
    Str1Ptr := '';
  end;

  if Str2Ptr = nil then begin
    Str2Ptr := '';
  end;

  // Fast check for Str1Ptr = Str2Ptr or first unequal character
  result := ord(Str1Ptr^) - ord(Str2Ptr^);

  if result = 0 then begin
    if ((integer(Str1Ptr) and ALIGNMENT_MASK) or (integer(Str2Ptr) and ALIGNMENT_MASK)) = 0 then begin
      result := CompareAlignedPchars(Str1Ptr, Str2Ptr);
    end else begin
      result := CompareUnalignedPchars(Str1Ptr, Str2Ptr);
    end;
  end;
end;

function CompareWideChars (Str1Ptr, Str2Ptr: myPWChar; Len: integer = -1): integer;
var
  Char1: myWChar;
  Char2: myWChar;
  Pos:   integer;

begin
  {!} Assert(Str1Ptr <> nil);
  {!} Assert(Str2Ptr <> nil);
  // * * * * * //
  Char1  := #0;
  Char2  := #0;
  Pos    := 0;
  result := 0;

  if Len < 0 then begin
    Len := high(integer);
  end;

  while Pos < Len do begin
    Char1 := Str1Ptr^;
    Char2 := Str2Ptr^;

    if Char1 = Char2 then begin
      if Char1 = #0 then begin
        exit;
      end;

      Inc(Str1Ptr);
      Inc(Str2Ptr);
    end else begin
      break;
    end;

    Inc(Pos);
  end; // .while

  // Characters differ, fix up each one if they're both in or above the surrogate range, then compare them
  if (ord(Char1) >= $D800) and (ord(Char2) >= $D800) then begin
    if ord(Char1) >= $E000 then begin
      Char1 := myWChar(ord(Char1) - $800);
    end else begin
      Char1 := myWChar(ord(Char1) + $2000);
    end;

    if ord(Char2) >= $E000 then begin
      Char2 := myWChar(ord(Char2) - $800);
    end else begin
      Char2 := myWChar(ord(Char2) + $2000);
    end;
  end;

  // Now both characters are in code point order
  result := ord(Char1) - ord(Char2);
end; // .function CompareWideChars

function CompareBinStringsW (const Str1, Str2: myWStr): integer;
begin
  result := CompareWideChars(myPWChar(Str1), myPWChar(Str2));
end;

end.
