unit Legacy;
{
DESCRIPTION: 
AUTHOR:      
}

interface

uses Windows, SysUtils, AnsiStrings; {$WARN SYMBOL_PLATFORM OFF}

type
  myChar  = System.AnsiChar;
  myWChar = System.WideChar;
  myPChar = System.PAnsiChar;
  myPWChar= System.PWideChar;
  myPPChar= System.PPAnsiChar;
  myAStr  = System.AnsiString;
  myPAStr = System.PAnsiString;
  myWStr  = System.UnicodeString;
  myPWStr = System.PUnicodeString;

  TFormatSettings = SysUtils.TFormatSettings;

  TReplaceFlags = set of (rfReplaceAll, rfIgnoreCase);
  Exception     = class(SysUtils.Exception) end;
  EOutOfMemory  = class(SysUtils.EOutOfMemory) end;
  EInOutError = class(Exception)
  public
    ErrorCode: Integer;
    Path: myAStr;
    constructor Create(const Msg: myAStr); overload;
    constructor Create(const Msg, Path: myAStr); overload;
    constructor CreateRes(ResStringRec: PResStringRec; const Path: myAStr); overload;
  end;
  TSearchRec = SysUtils.TSearchRec;

function IntToStr(Value: Integer): myAStr;
function IntToHex(Value: Integer; Digits: Integer): myAStr;
function TryStrToInt(const S: myAStr; out Value: Integer): Boolean;
function StrToInt(const S: myAStr): Integer;
function DirectoryExists(const Directory: myAStr; FollowLink: Boolean = True): Boolean;
function ExtractFileDir(const FileName: myAStr): myAStr;
function ChangeFileExt(const FileName, Extension: myAStr): myAStr;
function Format(const Format: myAStr; const Args: array of const): myAStr;
function LowerCase(const S: myAStr): myAStr;
function UpperCase(const S: myAStr): myAStr;
function UpCase(ch: myChar): myChar;
function ExtractFileExt(const FileName: myAStr): myAStr;
function ExtractFileName(const FileName: myAStr): myAStr;
function AnsiLowerCase(const S: myAStr): myAStr;
function AnsiCompareText(const S1, S2: myAStr): Integer;
function AnsiCompareStr(const S1, S2: myAStr): Integer;
function AnsiEndsText(const ASubText, AText: myAStr): Boolean;
function StrLen(const Str: PAnsiChar): Cardinal;
function ExpandFileName(const FileName: myAStr): myAStr;
function Trim(const S: myAStr): myAStr;
function TrimRight(const S: myAStr): myAStr;
//function AnsiEndsText(const ASubText, AText: myAStr): Boolean;
function AnsiStrAlloc(Size: Cardinal): myPChar; inline;
function ByteType(const S: myAStr; Index: Integer): TMbcsByteType;
//function FileCreate(const FileName: myAStr): THandle;
//function FileOpen(const FileName: myAStr; Mode: LongWord): THandle;
function FileCreate(const FileName: string): THandle;
function FileOpen(const FileName: string; Mode: LongWord): THandle;
procedure FileClose(Handle: THandle);
function DeleteFile(const FileName: myAStr): Boolean;
function CreateDir(const Dir: myAStr): Boolean;
function FileExists(const FileName: myAStr; FollowLink: Boolean = True): Boolean;
function ExtractFilePath(const FileName: myAStr): myAStr;
function SetCurrentDir(const Dir: myAStr): Boolean;
function Pos(const Substr, S: myAStr): Integer;
function PosEx(const SubStr, S: myAStr; Offset: Integer): Integer;
function AnsiReplaceStr(const AText, AFromText, AToText: myAStr): myAStr;
function StringReplace(const S, OldPattern, NewPattern: myAStr; Flags: TReplaceFlags): myAStr;
function RemoveDir(const Dir: myAStr): Boolean;
function ExcludeTrailingBackslash(const S: myAStr): myAStr; overload; inline; // platform specific BYME !!
function ExcludeTrailingPathDelimiter(const S: myAStr): myAStr;
function AnsiEndsStr(const ASubText, AText: myAStr): Boolean;
function IsValidIdent(const Ident: myAStr; AllowDots: Boolean): Boolean;
function AnsiPos(const Substr, S: myAStr): Integer;
function FloatToStr(Value: Extended): myAStr; overload;
function FloatToStr(Value: Extended; const AFormatSettings: TFormatSettings): myAStr; overload;
function StrToFloat(const S: myAStr): Extended; overload;
function StrToFloat(const S: myAStr; const AFormatSettings: TFormatSettings): Extended; overload;
function CurrToStr(Value: Currency): myAStr;
function TryStrToFloat(const S: myAStr; out Value: Single; const AFormatSettings: TFormatSettings): Boolean;
function DupeString(const AText: myAStr; ACount: Integer): myAStr;
function StrScan(const Str: PAnsiChar; Chr: AnsiChar): PAnsiChar;
procedure FreeAndNil(var Obj);
function FileSeek(Handle: THandle; Offset, Origin: Integer): Integer;
function FileRead(Handle: THandle; var Buffer; Count: LongWord): Integer;
function FileWrite(Handle: THandle; const Buffer; Count: LongWord): Integer;
function FindFirst(const Path: myAStr; Attr: Integer; var F: TSearchRec): Integer; inline;
function FindNext(var F: TSearchRec): Integer; inline;
procedure FindClose(var F: TSearchRec);
procedure FillChar(var Dest; Count: NativeInt; Value: myChar); overload;
procedure FillChar(var Dest; Count: NativeInt; Value: byte); overload;
procedure Move(const Source; var Dest; Count: NativeInt);
function StrPas(const Str: myPChar): myAStr;
function CompareMem(P1, P2: Pointer; Length: Integer): Boolean;
{ Interface support routines }
function Supports(const Instance: IInterface; const IID: TGUID; out Intf): Boolean; overload;
function Supports(const Instance: TObject; const IID: TGUID; out Intf): Boolean; overload;
//function Supports(const Instance: IInterface; const IID: TGUID): Boolean; overload;
//function Supports(const Instance: TObject; const IID: TGUID): Boolean; overload;
//function Supports(const AClass: TClass; const IID: TGUID): Boolean; overload;
// utilities here. Check and reorganise
procedure Buff(Dest: myPChar; Text: myAStr);
function StrAlloc(Size: Cardinal): myPChar; inline;
function Now: TDateTime; inline;
procedure StopDebugger; inline;
function sprintf(S: myPChar; const Format: PAnsiChar): Integer; cdecl; varargs; external 'msvcrt.dll';
function DeleteFileA(lpFileName: myPChar): LongBool; stdcall; external kernel32 name 'DeleteFileA';

const
  fmOpenRead       = SysUtils.fmOpenRead;
  fmOpenWrite      = SysUtils.fmOpenWrite;
  fmOpenReadWrite  = SysUtils.fmOpenReadWrite;
  fmExclusive      = SysUtils.fmExclusive;
  fmShareCompat    = SysUtils.fmShareCompat;
  fmShareExclusive = SysUtils.fmShareExclusive;
  fmShareDenyWrite = SysUtils.fmShareDenyWrite;
  fmShareDenyRead  = SysUtils.fmShareDenyRead;
  fmShareDenyNone  = SysUtils.fmShareDenyNone;

  { File attribute constants - SysUtils}
  faDirectory      = SysUtils.faDirectory;
  faAnyFile        = SysUtils.faAnyFile;

  { System.SysConst }
  SInvalidFloat = '''%s'' is not a valid floating point value';

implementation

uses
  UtilsB2;

procedure FreeAndNil(var Obj); // from SysUtils
{$IF not Defined(AUTOREFCOUNT)}
var
  Temp: TObject;
begin
  Temp := TObject(Obj);
  Pointer(Obj) := nil;
  Temp.Free;
end;
{$ELSE}
begin
  TObject(Obj) := nil;
end;
{$ENDIF}

function AnsiEndsStr(const ASubText, AText: myAStr): Boolean;
var
  SubTextLocation: Integer;
begin
  SubTextLocation := Length(AText) - Length(ASubText) + 1;
  if (SubTextLocation > 0) and (ASubText <> '') and
     (AnsiStrings.ByteType(AText, SubTextLocation) <> mbTrailByte) then
    Result := AnsiStrings.AnsiStrComp(Pointer(ASubText), PAnsiChar(@AText[SubTextLocation])) = 0
  else
    Result := False;
end;

function AnsiStrAlloc(Size: Cardinal): myPChar; inline;
begin
  Result := AnsiStrings.AnsiStrAlloc(Size);
end;

function StrScan(const Str: PAnsiChar; Chr: AnsiChar): PAnsiChar;
begin
  Result := Str;
  while Result^ <> #0 do
  begin
    if Result^ = Chr then
      Exit;
    Inc(Result);
  end;
  if Chr <> #0 then
    Result := nil;
end;

function ByteTypeTest(P: PByte; Index: Integer): TMbcsByteType;
var
  I: Integer;
begin
  Result := mbSingleByte;
  if (P = nil) or (P[Index] = Ord(#$0)) then Exit;
  if (Index = 0) then
  begin
    if IsLeadChar(P[0]) then Result := mbLeadByte;
  end
  else
  begin
    I := Index - 1;
    while (I >= 0) and IsLeadChar(Byte(P[I])) do Dec(I);
    if ((Index - I) mod 2) = 0 then Result := mbTrailByte
    else if IsLeadChar(P[Index]) then Result := mbLeadByte;
  end;
end;

function ByteType(const S: AnsiString; Index: Integer): TMbcsByteType;
begin
  Result := mbSingleByte;
  if SysLocale.FarEast then
    Result := ByteTypeTest(PByte(MarshaledAString(S)), Index-1);
end;

function LastDelimiter(const Delimiters, S: myAStr): Integer;
var
  P: PAnsiChar;
begin
  Result := Length(S);
  P := PAnsiChar(Delimiters);
  while Result > 0 do
  begin
    if (S[Result] <> #0) and (StrScan(P, S[Result]) <> nil) then
      if (AnsiStrings.ByteType(S, Result) = mbTrailByte) then
        Dec(Result)
      else
        Exit;
    Dec(Result);
  end;
end;

{function DupeString(const AText: myAStr; ACount: Integer): myAStr;
var
  P: PAnsiChar;
  C: Integer;
begin
  C := Length(AText);
  SetLength(Result, C * ACount);
  P := Pointer(Result);
  if P = nil then Exit;
  while ACount > 0 do
  begin
    Move(Pointer(AText)^, P^, C);
    Inc(P, C);
    Dec(ACount);
  end;
end;}

function DirectoryExists(const Directory: myAStr; FollowLink: Boolean = True): Boolean;
var
  Code: Cardinal;
  Handle: THandle;
  LastError: Cardinal;
const
  faDirectory   = $00000010; // From System.SysUtils
  faSymLink     = $00000400; // From System.SysUtils;  platform specific
begin
  Result := False;
  Code := GetFileAttributesA(myPChar(Directory));

  if Code <> INVALID_FILE_ATTRIBUTES then
  begin
    if faSymLink and Code = 0 then
      Result := faDirectory and Code <> 0
    else
    begin
      if FollowLink then
      begin
        Handle := CreateFileA(myPChar(Directory), GENERIC_READ, FILE_SHARE_READ, nil,
          OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, 0);
        if Handle <> INVALID_HANDLE_VALUE then
        begin
          CloseHandle(Handle);
          Result := faDirectory and Code <> 0;
        end;
      end
      else if faDirectory and Code <> 0 then
        Result := True
      else
      begin
        Handle := CreateFileA(myPChar(Directory), GENERIC_READ, FILE_SHARE_READ, nil,
          OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, 0);
        if Handle <> INVALID_HANDLE_VALUE then
        begin
          CloseHandle(Handle);
          Result := False;
        end
        else
          Result := True;
      end;
    end;
  end
  else
  begin
    LastError := GetLastError;
    Result := (LastError <> ERROR_FILE_NOT_FOUND) and
      (LastError <> ERROR_PATH_NOT_FOUND) and
      (LastError <> ERROR_BAD_PATHNAME) and
      (LastError <> ERROR_INVALID_NAME) and
      (LastError <> ERROR_BAD_NETPATH) and
      (LastError <> ERROR_NOT_READY) and
      (LastError <> ERROR_BAD_NET_NAME);
  end;
end;

function ChangeFileExt(const FileName, Extension: myAStr): myAStr;
var
  I: Integer;
begin
  I := LastDelimiter(AnsiString('.' + PathDelim + DriveDelim), Filename);
  if (I = 0) or (FileName[I] <> '.') then I := MaxInt;
  Result := Copy(FileName, 1, I - 1) + Extension;
end;

const
  PathDelim  = '\';
  DriveDelim = ':';
  PathSep    = ';';

function ExtractFileName(const FileName: myAStr): myAStr;
var
  I: Integer;
begin
  I := LastDelimiter(AnsiString(PathDelim + DriveDelim), FileName);
  Result := Copy(FileName, I + 1, MaxInt);
end;

{function EndsWith(const Source, Value: myAStr; IgnoreCase: Boolean): Boolean;
var
  LSubTextLocation: Integer;
  LOptions: TCompareOptions;
begin
  if Value = '' then
    Result := True
  else
  begin
    LSubTextLocation := Length(Source) - Length(Value);
    if (LSubTextLocation >= 0) and (ByteType(Source, LSubTextLocation) <> mbLeadByte) then
    begin
      if IgnoreCase then
        LOptions := [coIgnoreCase]
      else
        LOptions := [];
      Result := string.Compare(Value, 0, Source, LSubTextLocation, Length(Value), LOptions) = 0;
    end
    else
      Result := False;
  end;
end;}

function AnsiStrIComp(S1, S2: PAnsiChar): Integer;
begin
  Result := CompareStringA(LOCALE_USER_DEFAULT, NORM_IGNORECASE, S1, -1,  S2, -1) - CSTR_EQUAL;
end;

function AnsiEndsText(const ASubText, AText: myAStr): Boolean;
var
  SubTextLocation: Integer;
begin
  SubTextLocation := Length(AText) - Length(ASubText) + 1;
  if (SubTextLocation > 0) and (ASubText <> '') and
     (ByteType(AText, SubTextLocation) <> mbTrailByte) then
    Result := AnsiStrIComp(Pointer(ASubText), PAnsiChar(@AText[SubTextLocation])) = 0
  else
    Result := False;
end;

function IntToStr(Value: Integer): myAStr;
begin // FmtStr(Result, '%d', [Value]);  // Note: Using the global FormatSettings formatting variables is not thread-safe.  BYME
  AnsiStrings.FmtStr(Result, '%d', [Value]);
end;

function IntToHex(Value: Integer; Digits: Integer): myAStr;
begin
  Result := AnsiString(SysUtils.IntToHex(Cardinal(Value), Digits));
end;

function TryStrToInt(const S: myAStr; out Value: Integer): Boolean;
var
  E: Integer;
begin
  Val(string(S), Value, E);
  Result := E = 0;
end;

function StrToInt(const S: myAStr): Integer;
begin
  Result:=SysUtils.StrToInt(string(S));
end;

function ExtractFileDir(const FileName: myAStr): myAStr;
var
  I: Integer;
begin
  I := LastDelimiter(AnsiString(PathDelim + DriveDelim), Filename);
  if (I > 1) and (FileName[I] = PathDelim) and
    (not IsDelimiter( AnsiString(PathDelim + DriveDelim), FileName, I-1)) then
    Dec(I);
  Result := Copy(FileName, 1, I);
end;

function Format(const Format: myAStr; const Args: array of const): myAStr;
begin // Note: Using the global FormatSettings formatting variables is not thread-safe.     BYME
  AnsiStrings.FmtStr(Result, Format, Args);
end;

function LowerCase(const S: myAStr): myAStr;
var
  Len: Integer;
begin
  Len := Length(S);
  SetString(Result, myPChar(S), Len);
  if Len > 0 then
    CharLowerBuffA(myPChar(Result), Len);
end;

function UpperCase(const S: myAStr): myAStr;
var
  L, I: Integer;
begin
  L := Length(S);
  SetLength(Result, L);
  SetCodePage(RawByteString(Result), StringCodePage(S), False);

  for I := 1 to L do
    if S[I] in ['a' .. 'z'] then
      Result[I] := AnsiChar(Byte(S[I]) - $20)
    else
      Result[I] := S[I];
end;

function UpCase(ch: myChar): myChar; // from System
begin
  Result := Ch;
  if Result in ['a'..'z'] then
    Dec(Result, Ord('a')-Ord('A'));
end;

function ExtractFileExt(const FileName: myAStr): myAStr;
var
  I: Integer;
begin
  I := LastDelimiter(AnsiString('.' + PathDelim + DriveDelim), FileName);
  if (I > 0) and (FileName[I] = '.') then
    Result := Copy(FileName, I, MaxInt) else
    Result := '';
end;

function AnsiLowerCase(const S: myAStr): myAStr;
var
  Len: Integer;
begin
  Len := Length(S);
  SetString(Result, myPChar(S), Len);
  if Len > 0 then CharLowerBuffA(myPChar(Result), Len);
end;

function AnsiCompareText(const S1, S2: myAStr): Integer;
begin
  Result := CompareStringA(LOCALE_USER_DEFAULT, NORM_IGNORECASE, PAnsiChar(S1), Length(S1), PAnsiChar(S2), Length(S2)) - 2;
end;

function AnsiCompareStr(const S1, S2: myAStr): Integer;
begin
  Result := CompareStringA(LOCALE_USER_DEFAULT, 0, PAnsiChar(S1), Length(S1), PAnsiChar(S2), Length(S2)) - 2;
end;

function StrLen(const Str: PAnsiChar): Cardinal;
{begin
  Result := Length(Str);
end;}
(* ***** BEGIN LICENSE BLOCK *****
 *
 * The function StrLen is licensed under the CodeGear license terms.
 *
 * The initial developer of the original code is Fastcode
 *
 * Portions created by the initial developer are Copyright (C) 2002-2007
 * the initial developer. All Rights Reserved.
 *
 * Contributor(s): Pierre le Riche
 *
 * ***** END LICENSE BLOCK ***** *)
asm //StackAlignSafe
        {Check the first byte}
        CMP BYTE PTR [EAX], 0
        JE @ZeroLength
        {Get the negative of the string start in edx}
        MOV EDX, EAX
        NEG EDX
        {Word align}
        ADD EAX, 1
        AND EAX, -2
@ScanLoop:
        MOV CX, [EAX]
        ADD EAX, 2
        TEST CL, CH
        JNZ @ScanLoop
        TEST CL, CL
        JZ @ReturnLess2
        TEST CH, CH
        JNZ @ScanLoop
        LEA EAX, [EAX + EDX - 1]
        RET
@ReturnLess2:
        LEA EAX, [EAX + EDX - 2]
        RET
@ZeroLength:
        XOR EAX, EAX
end;

function ExpandFileName(const FileName: myAStr): myAStr;
var
  FName: myPChar;
  Buffer: array[0..MAX_PATH - 1] of myChar;
  Len: Integer;
begin
  Len := GetFullPathNameA(myPChar(FileName), Length(Buffer), Buffer, FName);
  if Len <= Length(Buffer) then
    SetString(Result, Buffer, Len)
  else if Len > 0 then
  begin
    SetLength(Result, Len);
    Len := GetFullPathNameA(myPChar(FileName), Len, myPChar(Result), FName);
    if Len < Length(Result) then
      SetLength(Result, Len);
  end;
end;

function Trim(const S: myAStr): myAStr;
var
  I, L: Integer;
begin
  L := Length(S);
  I := 1;
  if (L > 0) and (S[I] > ' ') and (S[L] > ' ') then Exit(S);
  while (I <= L) and (S[I] <= ' ') do Inc(I);
  if I > L then Exit('');
  while S[L] <= ' ' do Dec(L);
  Result := Copy(S, I, L - I + 1);
end;

function DeleteFile(const FileName: myAStr): Boolean;
var
  Flags, LastError: Cardinal;
const
  faDirectory   = $00000010; // From System.SysUtils
  faSymLink     = $00000400; // From System.SysUtils;  platform specific
begin
  Result := Windows.DeleteFileA(PAnsiChar(FileName));

  if not Result then
  begin
    LastError := GetLastError;
    Flags := GetFileAttributesA(PAnsiChar(FileName));

    if (Flags <> INVALID_FILE_ATTRIBUTES) and (faSymLink and Flags <> 0) and
      (faDirectory and Flags <> 0) then
    begin
      Result := RemoveDirectoryA(PAnsiChar(FileName));
      Exit;
    end;

    SetLastError(LastError);
  end;
end;

function TrimRight(const S: myAStr): myAStr;
var
  I: Integer;
begin
  I := Length(S);
  while (I > 0) and (S[I] <= ' ') do Dec(I);
  Result := Copy(S, 1, I);
end;

function RemoveDir(const Dir: myAStr): Boolean;
begin
  Result := RemoveDirectoryA(PAnsiChar(Dir));
end;

{function FileCreate(const FileName: myAStr): THandle;
const
  Exclusive: array[0..1] of LongWord = ( CREATE_ALWAYS, CREATE_NEW);
  ShareMode: array[0..4] of LongWord = ( 0, 0, FILE_SHARE_READ, FILE_SHARE_WRITE, FILE_SHARE_READ or FILE_SHARE_WRITE);
  Mode: LongWord = fmShareExclusive;
begin
  Result := INVALID_HANDLE_VALUE;
  if (Mode and $F0) <= fmShareDenyNone then
    Result := CreateFileA(PAnsiChar(FileName), GENERIC_READ or GENERIC_WRITE,
      ShareMode[(Mode and $F0) shr 4], nil, Exclusive[(Mode and $0004) shr 2], FILE_ATTRIBUTE_NORMAL, 0);
end;

function FileOpen(const FileName: myAStr; Mode: LongWord): THandle;
const
  AccessMode: array[0..2] of LongWord = ( GENERIC_READ, GENERIC_WRITE, GENERIC_READ or GENERIC_WRITE);
  ShareMode:  array[0..4] of LongWord = ( 0, 0, FILE_SHARE_READ, FILE_SHARE_WRITE, FILE_SHARE_READ or FILE_SHARE_WRITE);
begin
  Result := INVALID_HANDLE_VALUE;
  if ((Mode and 3) <= fmOpenReadWrite) and
    ((Mode and $F0) <= fmShareDenyNone) then
    Result := CreateFileA(PAnsiChar(FileName), AccessMode[Mode and 3],
      ShareMode[(Mode and $F0) shr 4], nil, OPEN_EXISTING,
      FILE_ATTRIBUTE_NORMAL, 0);
end;}

// System.SysUtils
function FileCreate(const FileName: string): THandle;
begin
  Result := SysUtils.FileCreate(FileName, fmShareExclusive, 0);
end;

// System.SysUtils
function FileOpen(const FileName: string; Mode: LongWord): THandle;
const
  AccessMode: array[0..2] of LongWord = (
    GENERIC_READ,
    GENERIC_WRITE,
    GENERIC_READ or GENERIC_WRITE);
  ShareMode: array[0..4] of LongWord = (
    0,
    0,
    FILE_SHARE_READ,
    FILE_SHARE_WRITE,
    FILE_SHARE_READ or FILE_SHARE_WRITE);
begin
  Result := INVALID_HANDLE_VALUE;
  if ((Mode and 3) <= fmOpenReadWrite) and
    ((Mode and $F0) <= fmShareDenyNone) then
    Result := CreateFile(PChar(FileName), AccessMode[Mode and 3],
      ShareMode[(Mode and $F0) shr 4], nil, OPEN_EXISTING,
      FILE_ATTRIBUTE_NORMAL, 0);
end;

// System.SysUtils
procedure FileClose(Handle: THandle);
begin
  CloseHandle(Handle);
end;

function CreateDir(const Dir: myAStr): Boolean;
begin
  Result := Windows.CreateDirectoryA(PAnsiChar(Dir), nil);
end;

function FileExists(const FileName: myAStr; FollowLink: Boolean = True): Boolean;
begin
   Result := SysUtils.FileExists(string(FileName), FollowLink);
end;

function ExtractFilePath(const FileName: myAStr): myAStr;
var
  I: Integer;
begin
  I := LastDelimiter(PathDelim + DriveDelim, FileName);
  Result := Copy(FileName, 1, I);
end;

function SetCurrentDir(const Dir: myAStr): Boolean;
begin
  Result := Windows.SetCurrentDirectoryA(myPChar(Dir));
end;

function Pos(const Substr, S: myAStr): Integer;
var P: myPChar;
begin
  Result := 0;
  P := AnsiStrings.AnsiStrPos(myPChar(S), myPChar(SubStr));
  if P <> nil then Result := IntPtr(P) - IntPtr(myPChar(S)) + 1;
end;

function PosEx(const SubStr, S: myAStr; Offset: Integer): Integer;
begin
  Result := System.Pos(SubStr, S, Offset);
end;

function AnsiReplaceStr(const AText, AFromText, AToText: myAStr): myAStr;
begin
  Result := AnsiStrings.StringReplace(AText, AFromText, AToText, [SysUtils.rfReplaceAll]);
end;

function StringReplace(const S, OldPattern, NewPattern: myAStr; Flags: TReplaceFlags): myAStr;
begin
  Result := AnsiStrings.StringReplace(s, OldPattern, NewPattern, SysUtils.TReplaceFlags(Flags));
end;

function ExcludeTrailingBackslash(const S: myAStr): myAStr;
begin
  Result := S;
  if AnsiStrings.IsPathDelimiter(Result, Length(Result)) then SetLength(Result, Length(Result)-1);
end;

function ExcludeTrailingPathDelimiter(const S: myAStr): myAStr;
begin
  Result := S;
  if AnsiStrings.IsPathDelimiter(Result, High(Result)) then
    SetLength(Result, Length(Result)-1);
end;

function IsValidIdent(const Ident: myAStr; AllowDots: Boolean): Boolean;
//const
//  Alpha = ['A'..'Z', 'a'..'z', '_'];
//  AlphaNumeric = Alpha + ['0'..'9'];
//  AlphaNumericDot = AlphaNumeric + ['.'];
//var
//  I: Integer;
begin
  Result:= SysUtils.IsValidIdent(string(Ident), AllowDots);    // make that work BYME
//  Result := False;
//  if (Length(Ident) = 0) or not (Ident[1] in Alpha) then Exit;
//  if AllowDots then
//    for I := 2 to Length(Ident) do
//      begin
//        if not (Ident[I] in AlphaNumericDot) then Exit
//      end
//  else
//    for I := 2 to Length(Ident) do if not (Ident[I] in AlphaNumeric) then Exit;
//  Result := True;
end;

function DupeString(const AText: myAStr; ACount: Integer): myAStr;
begin
  Result:= AnsiStrings.DupeString(AText, ACount);
end;

function AnsiPos(const Substr, S: myAStr): Integer;
begin
  Result:= AnsiStrings.AnsiPos(Substr, S);
end;

function FloatToStr(Value: Extended): myAStr; overload;
begin
  Result := myAStr(SysUtils.FloatToStr(Value, FormatSettings));
end;

function FloatToStr(Value: Extended; const AFormatSettings: TFormatSettings): myAStr; overload;
begin
  Result := myAStr(SysUtils.FloatToStr(Value, AFormatSettings));
end;

function StrToFloat(const S: myAStr): Extended; overload;
begin
  Result := SysUtils.StrToFloat(string(S), FormatSettings);
end;

function StrToFloat(const S: myAStr; const AFormatSettings: TFormatSettings): Extended; overload;
begin
  Result := SysUtils.StrToFloat(string(S), AFormatSettings);
end;

function CurrToStr(Value: Currency): myAStr;
begin
  Result := myAStr(SysUtils.CurrToStr(Value, FormatSettings));
end;

function TryStrToFloat(const S: myAStr; out Value: Single; const AFormatSettings: TFormatSettings): Boolean;
var LValue: Extended;
begin
  Result := TextToFloat(string(S), LValue, AFormatSettings);
  if Result then
    if (LValue < Single.MinValue) or (LValue > Single.MaxValue) then
      Result := False;
  if Result then
    Value := LValue;
end;

function FileSeek(Handle: THandle; Offset, Origin: Integer): Integer;
begin
  Result := SetFilePointer(Handle, Offset, nil, Origin);
end;

function FileRead(Handle: THandle; var Buffer; Count: LongWord): Integer;
begin
  if not ReadFile(Handle, Buffer, Count, LongWord(Result), nil) then Result := -1;
end;

function FileWrite(Handle: THandle; const Buffer; Count: LongWord): Integer;
begin
  if not WriteFile(Handle, Buffer, Count, LongWord(Result), nil) then Result := -1;
end;

//function FindMatchingFile(var F: TSearchRec): Integer;
//var
//  LocalFileTime: TFileTime;
//begin
//  while F.FindData.dwFileAttributes and F.ExcludeAttr <> 0 do
//    if not Windows.FindNextFileW(F.FindHandle, F.FindData) then
//    begin
//      Result := GetLastError;
//      Exit;
//    end;
//  FileTimeToLocalFileTime(F.FindData.ftLastWriteTime, LocalFileTime);
//  FileTimeToDosDateTime(LocalFileTime, LongRec(F.Time).Hi, LongRec(F.Time).Lo);
//  F.Size := F.FindData.nFileSizeLow or Int64(F.FindData.nFileSizeHigh) shl 32;
//  F.Attr := F.FindData.dwFileAttributes;
//  F.Name := F.FindData.cFileName;
//  Result := 0;
//end;

//function FindFirst(const Path: myAStr; Attr: Integer; var F: TSearchRec): Integer;
//const
//  faSpecial = faHidden or faSysFile or faDirectory;
//begin
//  F.ExcludeAttr := not Attr and faSpecial;
//  F.FindHandle := Windows.FindFirstFileW(myPWChar(Path), F.FindData);
//  if F.FindHandle <> INVALID_HANDLE_VALUE then
//  begin
//    Result := FindMatchingFile(F);
//    if Result <> 0 then FindClose(F);
//  end
//  else
//    Result := GetLastError;
//end;

function FindFirst(const Path: myAStr; Attr: Integer; var F: TSearchRec): Integer; inline;
begin
    Result := Sysutils.FindFirst(string(Path), Attr, F);
end;

//function FindNext(var F: TSearchRec): Integer;
//begin
//  if Windows.FindNextFileW(F.FindHandle, F.FindData) then
//    Result := FindMatchingFile(F)
//  else
//    Result := GetLastError;
//end;

function FindNext(var F: TSearchRec): Integer; inline;
begin
    Result := SysUtils.FindNext(F);
end;

procedure FindClose(var F: TSearchRec);
begin
  if F.FindHandle <> INVALID_HANDLE_VALUE then
  begin
    Windows.FindClose(F.FindHandle);
    F.FindHandle := INVALID_HANDLE_VALUE;
  end;
end;

procedure FillChar(var Dest; Count: NativeInt; Value: myChar); overload;
begin
  System.FillChar(Dest, Count, Value);
end;

procedure FillChar(var Dest; Count: NativeInt; Value: byte); overload;
begin
  System.FillChar(Dest, Count, Value);
end;

procedure Move(const Source; var Dest; Count: NativeInt);
begin
  System.Move(Source, Dest, Count);
end;

function StrPas(const Str: myPChar): myAStr;
begin
  Result := Str;
end;

(* ***** BEGIN LICENSE BLOCK *****
 *
 * The function CompareMem is licensed under the CodeGear license terms.
 *
 * The initial developer of the original code is Fastcode
 *
 * Portions created by the initial developer are Copyright (C) 2002-2004
 * the initial developer. All Rights Reserved.
 *
 * Contributor(s): Aleksandr Sharahov
 *
 * ***** END LICENSE BLOCK ***** *)
function CompareMem(P1, P2: Pointer; Length: Integer): Boolean;
{$IFOPT Q+}
  {$DEFINE __OVERFLOWCHECKS}
  {$OVERFLOWCHECKS OFF}
{$ENDIF}
{$IFOPT R+}
  {$DEFINE __RANGECHECKS}
  {$RANGECHECKS OFF}
{$ENDIF}
{$POINTERMATH ON}
var
  Q1, Q2: PInt64;
  C: NativeUInt;
begin;
  if Length <= 0 then Exit(True);
  Result := False;
  Q1 := P1;
  Q2 := P2;
  C := NativeUInt(Length) + UIntPtr(P1) - 16;
  if C >= UIntPtr(Q1) then
  begin;
    if Q1[0] <> Q2[0] then
      Exit;
    Inc(Q1);
    Inc(Q2);
    Dec(PByte(Q2), UIntPtr(Q1));
    UIntPtr(Q1) := UIntPtr(Q1) and -8;
    Inc(PByte(Q2), UIntPtr(Q1));
    if C >= UIntPtr(Q1) then
    repeat
      if Q1[0] <> Q2[0] then
        Exit;
      if Q1[1] <> Q2[1] then
        Exit;
      Inc(Q1, 2);
      Inc(Q2, 2);
      if C < UIntPtr(Q1) then
        Break;
      if Q1[0] <> Q2[0] then
        Exit;
      if Q1[1] <> Q2[1] then
        Exit;
      Inc(Q1, 2);
      Inc(Q2, 2);
    until C < UIntPtr(Q1);
  end;
  C := C - UIntPtr(Q1) + 16;
  if Integer(C) >= 8 then
  begin
    if Q1[0] <> Q2[0] then
      Exit;
    Inc(Q1);
    Inc(Q2);
    C := C - 8;
  end;
  if Integer(C) >= 6 then
  begin;
    if PInteger(Q1)[0] <> PInteger(Q2)[0] then
      Exit;
    Inc(PInteger(Q1));
    Inc(PInteger(Q2));
    if PWord(Q1)[0] <> PWord(Q2)[0] then
      Exit;
    Inc(PWord(Q1));
    Inc(PWord(Q2));
    C := C - 6;
  end;
  if Integer(C) >= 5 then
  begin
    if PInteger(Q1)[0] <> PInteger(Q2)[0] then
      Exit;
    Inc(PInteger(Q1));
    Inc(PInteger(Q2));
    if PByte(Q1)[0] <> PByte(Q2)[0] then
      Exit;
    Inc(PByte(Q1));
    Inc(PByte(Q2));
    C := C - 5;
  end;
  if Integer(C) >= 4 then
  begin
    if PInteger(Q1)[0] <> PInteger(Q2)[0] then
      Exit;
    Inc(PInteger(Q1));
    Inc(PInteger(Q2));
    C := C - 4;
  end;
  if Integer(C) >= 2 then
  begin;
    if PWord(Q1)[0] <> PWord(Q2)[0] then
      Exit;
    Inc(PWord(Q1));
    Inc(PWord(Q2));
    C := C - 2;
  end;
  if Integer(C) >= 1 then
    if PByte(Q1)[0] <> PByte(Q2)[0] then
      Exit;
  Result := True;
end;
{$POINTERMATH OFF}
{$IFDEF __OVERFLOWCHECKS}
  {$UNDEF __OVERFLOWCHECKS}
  {$OVERFLOWCHECKS ON}
{$ENDIF}
{$IFDEF __RANGECHECKS}
  {$UNDEF __RANGECHECKS}
  {$RANGECHECKS ON}
{$ENDIF}

{ Interface support routines }

function Supports(const Instance: IInterface; const IID: TGUID; out Intf): Boolean; overload;
begin
  Result := (Instance <> nil) and (Instance.QueryInterface(IID, Intf) = 0);
end;

function Supports(const Instance: TObject; const IID: TGUID; out Intf): Boolean; overload;
var
  LUnknown: IUnknown;
begin
  Result := (Instance <> nil) and
            ((Instance.GetInterface(IUnknown, LUnknown) and Supports(LUnknown, IID, Intf)) or
             Instance.GetInterface(IID, Intf));
end;

//function Supports(const Instance: IInterface; const IID: TGUID): Boolean; overload;
//var
//  Temp: IInterface;
//begin
//  Result := Supports(Instance, IID, Temp);
//end;

//function Supports(const Instance: TObject; const IID: TGUID): Boolean; overload;
//var
//  Temp: IInterface;
//begin
//  // NOTE: Calling this overload on a ref-counted object that has REFCOUNT=0
//  // will result in it being freed upon exit from this routine.
//  Result := Supports(Instance, IID, Temp);
//end;

//function Supports(const AClass: TClass; const IID: TGUID): Boolean;
//begin
//  Result := AClass.GetInterfaceEntry(IID) <> nil;
//end;

// utilities here. Check and reorganise

procedure Buff(Dest: myPChar; Text: myAStr);
begin
  // = Ptr($697428);  // $300 (768) size slot   o_TextBuffer
  UtilsB2.SetPcharValue(Dest, Text, Length(Text) + 1);
end;

function StrAlloc(Size: Cardinal): myPChar; inline;
begin
  Result := AnsiStrAlloc(Size);
end;

function Now: TDateTime; inline;
begin
  Result := SysUtils.Now;
end;

procedure StopDebugger; inline;
begin
    {$IFDEF DEBUG}
    MessageBoxA(0, myPChar('Attach debugger.'), myPChar('Debugger'), MB_OK);
    DebugBreak();
    {$ENDIF}
end;

{ EInOutError }

constructor EInOutError.Create(const Msg: myAStr);
begin
  inherited Create(string(Msg));
end;

constructor EInOutError.Create(const Msg, Path: myAStr);
begin
  inherited Create(string(Msg));
  Self.Path := Path;
  Message := Message + sLineBreak + '[' + string(Path) + ']';
end;

constructor EInOutError.CreateRes(ResStringRec: PResStringRec; const Path: myAStr);
begin
  Create(myAStr(LoadResString(ResStringRec)), Path);
end;

end.
