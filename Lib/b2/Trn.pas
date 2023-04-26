unit Trn;
(* Author:      EtherniDee aka Berserker
   Description: Light-weight non-unicode internationalization support *)

(*
Language file format (extended ini)
===================================
encoding: ansi, #0 not used
===================================
any_char             = #1..#255
blank                = #1..#32
line_end             = #10
comment_marker       = ';'
section_header_start = '['
section_header_end   = ']'
key_value_separator  = '='
string_marker        = '"'

inline_blank   = blank - line_end;
inline_char    = any_char - line_end
instring_char  = any_char - string_marker
comment        = comment_marker {inline_char} [line_end]
garbage        = (blank | comment) {blank | comment}
g              = garbage
special_char   = section_header_start | section_header_end | key_value_separator | comment_marker
ident_char     = inline_char - special_char
ident          = ident_char {ident_char}
item_value     = {inline_blank}
                 (
                   {ident_char - string_marker} |
                   (string_marker {instring_char | string_marker string_marker} string_marker)
                 )
item_key       = ident_char
item           = item_key key_value_separator item_value
section_body   = item {[g] item}
section header = section_header_start {ident_char} section_header_end
section        = section_header [g] [section_body]
main           = {[g] section}
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

interface
uses UtilsB2, Legacy;

const
  NO_LANG          = '';
  CURRENT_LANG     = 'current';
  DEFAULT_LANG_DIR = 'Language';
  TEMPLATE_CHAR    = '`';
  LANG_FILE_EXT    = 'ini';

type
  TMissingTranslHandler = procedure (const aKey, aSection, aLang: myAStr) of object;
  TParseErrorHandler    = procedure (const Err: myAStr) of object;

  ALangMan = class abstract
   protected
    function  GetLangDir: myAStr;                                      virtual; abstract;
    procedure SetLangDir (const aLangDir: myAStr);                     virtual; abstract;
    function  GetLangAutoload: boolean;                                virtual; abstract;
    procedure SetLangAutoload (aLangAutoload: boolean);                virtual; abstract;
    function  GetMainLang: myAStr;                                     virtual; abstract;
    procedure SetMainLang (const aMainLang: myAStr);                   virtual; abstract;
    function  GetReservLang: myAStr;                                   virtual; abstract;
    procedure SetReservLang (const aReservLang: myAStr);               virtual; abstract;
    function  GetOnMissingTranslation: {n} TMissingTranslHandler;      virtual; abstract;
    procedure SetOnMissingTranslation ({n} aMissingTranslHandler: TMissingTranslHandler);
                                                                       virtual; abstract;
    function  GetOnParseError: {n} TParseErrorHandler;                 virtual; abstract;
    procedure SetOnParseError ({n} aOnParseError: TParseErrorHandler); virtual; abstract;
    
   public
    (* !IsValidLang(aLang) *)
    function  LoadLangData (const aLang, aLangData, aDataSource: myAStr): boolean;
                                                                       virtual; abstract;
    procedure UnloadLang (const aLang: myAStr);                        virtual; abstract;
    procedure UnloadAllLangs;                                          virtual; abstract;
    function  Translate (const aKey, aSection: myAStr; aLang: myAStr; var Res: myAStr): boolean;
                                                                       virtual; abstract;
    (* Returns aKey if no translation is found and calls OnMissingTranslation, if it is set *)
    function  tr (const aKey, aSection: myAStr; aLang: myAStr = CURRENT_LANG)
                  : myAStr; overload;                                  virtual; abstract;
    (* Combines tr and StrLib.BuildStr. uses current language and TEMPLATE_CHAR *)
    function  tr (const aKey, aSection: myAStr; aTemplArgs: array of myAStr): myAStr; overload;

    property LangDir:      myAStr read GetLangDir write SetLangDir;
    property LangAutoload: boolean read GetLangAutoload write SetLangAutoload;
    property MainLang:     myAStr read GetMainLang write SetMainLang;
    property ReservLang:   myAStr read GetReservLang write SetReservLang;
    property OnMissingTranslation: {n} TMissingTranslHandler read GetOnMissingTranslation
                                                             write SetOnMissingTranslation;
    property OnParseError: {n} TParseErrorHandler read GetOnParseError write SetOnParseError;
  end; // .class ALangMan

(* Valid language name is: ('a'..'z' | 'A'..'Z' | '0'..'9' | '_') * 1..64 *)
function  IsValidLang (const aLang: myAStr): boolean;

(* === Wrappers to access currently installed language manager in a thread-safe way === *)
function  GetLangDir: myAStr;
procedure SetLangDir (const aLangDir: myAStr);
function  GetLangAutoload: boolean;
procedure SetLangAutoload (aLangAutoload: boolean);
function  GetMainLang: myAStr;
procedure SetMainLang (const aMainLang: myAStr);
function  GetReservLang: myAStr;
procedure SetReservLang (const aReservLang: myAStr);
function  GetOnMissingTranslation: {n} TMissingTranslHandler;
procedure SetOnMissingTranslation ({n} aMissingTranslHandler: TMissingTranslHandler);
function  GetOnParseError: {n} TParseErrorHandler;
procedure SetOnParseError ({n} aOnParseError: TParseErrorHandler);  
function  LoadLangData (const aLang, aLangData, aDataSource: myAStr): boolean;
procedure UnloadLang (const aLang: myAStr);
procedure UnloadAllLangs;
function  Translate (const aKey, aSection: myAStr; aLang: myAStr; var Res: myAStr): boolean;
function  tr (const aKey, aSection: myAStr; aLang: myAStr = CURRENT_LANG): myAStr; overload;
function  tr (const aKey, aSection: myAStr; aTemplArgs: array of myAStr): myAStr; overload;

(* Returns previously installed manager *)
function  InstallLangMan ({?} NewLangMan: ALangMan): {?} ALangMan;

implementation
uses SysUtils, DataLib, Files, TextScan, TypeWrappers, StrLib, Concur;

const
  ANY_CHARS      = [#1..#255];
  LINE_END       = #10;
  BLANKS         = [#1..#32];
  COMMENT_MARKER = ';';
  INLINE_CHARS   = ANY_CHARS - [LINE_END];

  SECTION_HEADER_START = '[';
  SECTION_HEADER_END   = ']';
  KEY_VALUE_SEPARATOR  = '=';
  SPECIAL_CHARS        = [SECTION_HEADER_START, SECTION_HEADER_END, COMMENT_MARKER,
                          KEY_VALUE_SEPARATOR];
  IDENT_CHARS          = INLINE_CHARS - SPECIAL_CHARS;
  STRING_MARKER        = '"';
  INSTRING_CHARS       = ANY_CHARS - [STRING_MARKER];
  GARBAGE_CHARS        = BLANKS + [COMMENT_MARKER];
  INLINE_BLANKS        = BLANKS - [LINE_END];


type
  (* import *)
  TDict   = DataLib.TDict;
  TString = TypeWrappers.TString;

  TLangMan = class (ALangMan)
   private
    {O} fLangs:                {O} TDict (* of {O} Sections of {O} Strings *);
    {O} fLangIsLoaded:         {U} TDict {of Ptr(1)};
    {O} fScanner:              TextScan.TTextScanner;
        fLangDir:              myAStr;
        fLangAutoload:         boolean;
        fMainLang:             myAStr;
        fReservLang:           myAStr;
        fDataSourceForParsing: myAStr;
    {n} fOnMissingTranslation: TMissingTranslHandler;
    {n} fOnParseError:         TParseErrorHandler;

    procedure ParsingError (const Err: myAStr);
    function  SkipGarbage: boolean;
    function  ParseChar (c: myChar): boolean;
    function  ParseToken (const Charset: UtilsB2.TCharset; const lngTokenName: myAStr;
                          var Token: myAStr): boolean;
    function  ParseSectionHeader (Sections: TDict; out Section: TDict): boolean;
    function  ParseString (var Str: myAStr): boolean;
    function  ParseItem (Section: TDict): boolean;
    function  ParseSectionBody (Section: TDict): boolean;
    function  ParseSection (Sections: TDict): boolean;
    function  ParseLangData (const aLang: myAStr): boolean;

    procedure LoadLang (const aLang: myAStr);
    (* Does not try using ReservLang on fail as opposed to Translate *)
    function  TranslateIntoLang (const aKey, aSection, aLang: myAStr; var Res: myAStr): boolean;

   public
    constructor Create;
    destructor  Destroy; override;

    function  GetLangDir: myAStr;                                      override;
    procedure SetLangDir (const aLangDir: myAStr);                     override;
    function  GetLangAutoload: boolean;                                override;
    procedure SetLangAutoload (aLangAutoload: boolean);                override;
    function  GetMainLang: myAStr;                                     override;
    procedure SetMainLang (const aMainLang: myAStr);                   override;
    function  GetReservLang: myAStr;                                   override;
    procedure SetReservLang (const aReservLang: myAStr);               override;
    function  GetOnMissingTranslation: {n} TMissingTranslHandler;      override;
    procedure SetOnMissingTranslation ({n} aMissingTranslHandler: TMissingTranslHandler);
                                                                       override;
    function  GetOnParseError: {n} TParseErrorHandler;                 override;
    procedure SetOnParseError ({n} aOnParseError: TParseErrorHandler); override;
    function  LoadLangData (const aLang, aLangData, aDataSource: myAStr): boolean;
                                                                       override;
    procedure UnloadLang (const aLang: myAStr);                        override;
    procedure UnloadAllLangs;                                          override;
    function  Translate (const aKey, aSection: myAStr; aLang: myAStr; var Res: myAStr): boolean;
                                                                       override;
    function  tr (const aKey, aSection: myAStr; aLang: myAStr = CURRENT_LANG): myAStr;
                                                                       override;
  end; // .class TLangMan

var
{?} LangMan: ALangMan;
    Lock:    Concur.TCritSection;

function IsValidLang (const aLang: myAStr): boolean;
var
  i: integer;

begin
  result := (Length(aLang) >= 1) and (Length(aLang) <= 64);
  i      := 1;

  while ((i < Length(aLang)) and result) do begin
    result := aLang[i] in ['a'..'z', 'A'..'Z', '0'..'9', '_'];
    Inc(i);
  end;
end; // .function IsValidLang

function ALangMan.tr (const aKey, aSection: myAStr; aTemplArgs: array of myAStr): myAStr;
begin
  result := StrLib.BuildStr(tr(aKey, aSection, CURRENT_LANG), aTemplArgs, TEMPLATE_CHAR);
end;

constructor TLangMan.Create;
begin
  fLangs                := DataLib.NewDict(UtilsB2.OWNS_ITEMS, not DataLib.CASE_SENSITIVE);
  fLangIsLoaded         := DataLib.NewDict(not UtilsB2.OWNS_ITEMS, not DataLib.CASE_SENSITIVE);
  fScanner              := TextScan.TTextScanner.Create;
  fLangDir              := DEFAULT_LANG_DIR;
  fLangAutoload         := true;
  fMainLang             := NO_LANG;
  fReservLang           := NO_LANG;
  fDataSourceForParsing := '';
  fOnMissingTranslation := nil;
  fOnParseError         := nil;
end; // .constructor TLangMan.Create

destructor TLangMan.Destroy;
begin
  SysUtils.FreeAndNil(fLangs);
  SysUtils.FreeAndNil(fLangIsLoaded);
  SysUtils.FreeAndNil(fScanner);
end; // .destructor TLangMan.Destroy

function TLangMan.GetLangDir: myAStr;
begin
  result := fLangDir;
end;

procedure TLangMan.SetLangDir (const aLangDir: myAStr);
begin
  fLangDir := aLangDir;
end;

function TLangMan.GetLangAutoload: boolean;
begin
  result := fLangAutoload;
end;

procedure TLangMan.SetLangAutoload (aLangAutoload: boolean);
begin
  fLangAutoload := aLangAutoload;
end;

function TLangMan.GetMainLang: myAStr;
begin
  result := fMainLang;
end;

procedure TLangMan.SetMainLang (const aMainLang: myAStr);
begin
  fMainLang := aMainLang;
end;

function TLangMan.GetReservLang: myAStr;
begin
  result := fReservLang;
end;

procedure TLangMan.SetReservLang (const aReservLang: myAStr);
begin
  fReservLang := aReservLang;
end;

function TLangMan.GetOnMissingTranslation: {n} TMissingTranslHandler;
begin
  result := fOnMissingTranslation;
end;

procedure TLangMan.SetOnMissingTranslation ({n} aMissingTranslHandler: TMissingTranslHandler);
begin
  fOnMissingTranslation := aMissingTranslHandler;
end;

function TLangMan.GetOnParseError: {b} TParseErrorHandler;
begin
  result := fOnParseError;
end;

procedure TLangMan.SetOnParseError ({n} aOnParseError: TParseErrorHandler);
begin
  fOnParseError := aOnParseError;
end;

procedure TLangMan.ParsingError (const Err: myAStr);
begin
  if Assigned(fOnParseError) then begin
    fOnParseError(tr('Trn.Parsing error', '2b', ['error', Err, 'source', fDataSourceForParsing,
                                                 'line', Legacy.IntToStr(fScanner.LineN),
                                                 'pos', Legacy.IntToStr(fScanner.Pos)]));
  end;
end;

function TLangMan.SkipGarbage: boolean;
begin
  while fScanner.c in GARBAGE_CHARS do begin
    if fScanner.c = COMMENT_MARKER then begin
      fScanner.GotoNextLine;
    end else begin
      fScanner.SkipCharset(BLANKS);
    end; // ,else
  end;

  result := not fScanner.Eot;
end; // .function TLangMan.SkipGarbage

function TLangMan.ParseChar (c: myChar): boolean;
begin
  result := fScanner.c = c;
  
  if result then begin
    fScanner.GotoNextChar;
  end else begin
    ParsingError(tr('Trn.char x expected', '2b', ['char', c]));
  end;
end;

function TLangMan.ParseToken (const Charset: UtilsB2.TCharset; const lngTokenName: myAStr;
                              var Token: myAStr): boolean;
begin
  result := fScanner.ReadToken(Charset, Token);

  if not result then begin
    ParsingError(tr('Trn.Token x expected', '2b', ['token', tr(lngTokenName, '2b')]));
  end;
end;

function TLangMan.ParseSectionHeader (Sections: TDict; out Section: TDict): boolean;
var
{U} NewSection:  TDict;
    SectionName: myAStr;

begin
  {!} Assert(Sections <> nil);
  {!} Assert(Section = nil);
  NewSection := nil;
  // * * * * * //
  result := ParseChar(SECTION_HEADER_START)                          and
            ParseToken(IDENT_CHARS, 'Trn.section name', SectionName) and
            ParseChar(SECTION_HEADER_END);

  if result then begin
    NewSection := Sections[SectionName];

    if NewSection = nil then begin
      NewSection            := DataLib.NewDict(UtilsB2.OWNS_ITEMS, not DataLib.CASE_SENSITIVE);
      Sections[SectionName] := NewSection;
    end;
    
    Section := NewSection;
  end;
end; // .function TLangMan.ParseSectionHeader

function TLangMan.ParseString (var Str: myAStr): boolean;
var
  StartPos:         integer;
  NeedsPostProcess: boolean;

begin
  result := true;
  fScanner.SkipCharset(INLINE_BLANKS);

  if fScanner.c = STRING_MARKER then begin
    fScanner.GotoNextChar;
    StartPos         := fScanner.Pos;
    NeedsPostProcess := false;

    while fScanner.SkipCharset(INSTRING_CHARS) and (fScanner.c = STRING_MARKER) and
          (fScanner.CharsRel[+1] = STRING_MARKER)
    do begin
      NeedsPostProcess := true;
      fScanner.GotoRelPos(+2);
    end;

    result := not fScanner.Eot;

    if not result then begin
      ParsingError(Tr('Trn.Closing quote expected', '2b'));
    end else begin
      Str := fScanner.GetSubstrAtPos(StartPos, fScanner.Pos - StartPos);
      fScanner.GotoNextChar;

      if NeedsPostProcess then begin
        Str := Legacy.StringReplace(Str, STRING_MARKER + STRING_MARKER, STRING_MARKER,
                                      [Legacy.rfReplaceAll]);
      end;
    end; // .else
  end else if not fScanner.Eot then begin
    fScanner.ReadToken(IDENT_CHARS, Str);
    Str := Legacy.TrimRight(Str);
  end else begin
    Str := '';
  end; // .else
end; // .function TLangMan.ParseString

function TLangMan.ParseItem (Section: TDict): boolean;
var
  ItemKey:   myAStr;
  ItemValue: myAStr;

begin
  {!} Assert(Section <> nil);
  result := ParseToken(IDENT_CHARS, 'Trn.item key', ItemKey) and
            ParseChar(KEY_VALUE_SEPARATOR)                   and
            ParseString(ItemValue);

  if result then begin
    ItemKey := Legacy.TrimRight(ItemKey);

    if Section[ItemKey] = nil then begin
      Section[ItemKey] := TString.Create(ItemValue);
    end;
  end;
end; // .function TLangMan.ParseItem

function TLangMan.ParseSectionBody (Section: TDict): boolean;
begin
  result := ParseItem(Section);

  while result and SkipGarbage and (fScanner.c in IDENT_CHARS) do begin
    result := ParseItem(Section);
  end;
end;

function TLangMan.ParseSection (Sections: TDict): boolean;
var
{U} Section: TDict;

begin
  Section := nil;
  // * * * * * //
  result := ParseSectionHeader(Sections, Section);

  if result and SkipGarbage and (fScanner.c in IDENT_CHARS) then begin
    result := ParseSectionBody(Section);
  end;
end; // .function TLangMan.ParseSection

function TLangMan.ParseLangData (const aLang: myAStr): boolean;
var
{U} Sections: TDict;

begin
  Sections := fLangs[aLang];
  // * * * * * //
  if Sections = nil then begin
    Sections      := DataLib.NewDict(UtilsB2.OWNS_ITEMS, not DataLib.CASE_SENSITIVE);
    fLangs[aLang] := Sections;
  end;

  result := true;

  while result and SkipGarbage do begin
    result := ParseSection(Sections);
  end;
end; // .function TLangMan.ParseLangData

function TLangMan.LoadLangData (const aLang, aLangData, aDataSource: myAStr): boolean;
begin
  {!} Assert(IsValidLang(aLang));
  fScanner.Connect(aLangData, LINE_END);
  fDataSourceForParsing := aDataSource;
  result                := ParseLangData(aLang);
end;

procedure TLangMan.UnloadLang (const aLang: myAStr);
begin
  fLangs.DeleteItem(aLang);
  fLangIsLoaded.DeleteItem(aLang);
end;

procedure TLangMan.UnloadAllLangs;
begin
  fLangs.Clear;
  fLangIsLoaded.Clear;
end;

procedure TLangMan.LoadLang (const aLang: myAStr);
var
  LangDirPath:      myAStr;
  LangFilePath:     myAStr;
  LangFileContents: myAStr;

begin
  if fLangIsLoaded[aLang] = nil then begin
    fLangIsLoaded[aLang] := Ptr(1);
    LangDirPath          := fLangDir + '\' + aLang + '\';

    with Files.Locate(LangDirPath + '*.' + LANG_FILE_EXT, Files.ONLY_FILES) do begin
      while FindNext do begin
        LangFilePath := LangDirPath + FoundName;

        if Files.ReadFileContents(LangFilePath, LangFileContents) then begin
          LoadLangData(aLang, LangFileContents, LangFilePath);
        end;
      end;
    end;
  end; // .if
end; // .procedure TLangMan.LoadLang

function TLangMan.TranslateIntoLang (const aKey, aSection, aLang: myAStr; var Res: myAStr)
                                     : boolean;
var
{U} Sections: {O} TDict {of Section};
{U} Section:  {O} TDict {of TString};
{U} Str:      TString;

begin
  Sections := fLangs[aLang];
  Section  := nil;
  Str      := nil;
  // * * * * * //
  result := false;

  if aLang <> NO_LANG then begin
    if (Sections = nil) and fLangAutoload then begin
      LoadLang(aLang);
      Sections := fLangs[aLang];
    end;

    if Sections <> nil then begin
      Section := Sections[aSection];

      if Section <> nil then begin
        Str := Section[aKey];

        if Str <> nil then begin
          result := true;
          Res    := Str.Value;
        end;
      end;
    end;
  end;
end; // .function TLangMan.TranslateIntoLang

function TLangMan.Translate (const aKey, aSection: myAStr; aLang: myAStr; var Res: myAStr): boolean;
begin
  if aLang = CURRENT_LANG then begin
    aLang := fMainLang;
  end;

  result := TranslateIntoLang(aKey, aSection, aLang, Res) or
            TranslateIntoLang(aKey, aSection, fReservLang, Res);
end;

function TLangMan.tr (const aKey, aSection: myAStr; aLang: myAStr = CURRENT_LANG): myAStr;
begin
  result := aKey;

  if not Translate(aKey, aSection, aLang, result) and Assigned(fOnMissingTranslation) then begin
    fOnMissingTranslation(aKey, aSection, aLang);
  end;
end;

function GetLangDir: myAStr;
begin
  Lock.Enter; result := LangMan.LangDir; Lock.Leave;
end;

procedure SetLangDir (const aLangDir: myAStr);
begin
  Lock.Enter; LangMan.LangDir := aLangDir; Lock.Leave;
end;

function GetLangAutoload: boolean;
begin
  Lock.Enter; result := LangMan.LangAutoload; Lock.Leave;
end;

procedure SetLangAutoload (aLangAutoload: boolean);
begin
  Lock.Enter; LangMan.LangAutoload := aLangAutoload; Lock.Leave;
end;

function GetMainLang: myAStr;
begin
  Lock.Enter; result := LangMan.MainLang; Lock.Leave;
end;

procedure SetMainLang (const aMainLang: myAStr);
begin
  Lock.Enter; LangMan.MainLang := aMainLang; Lock.Leave;
end;

function GetReservLang: myAStr;
begin
  Lock.Enter; result := LangMan.ReservLang; Lock.Leave;
end;

procedure SetReservLang (const aReservLang: myAStr);
begin
  Lock.Enter; LangMan.ReservLang := aReservLang; Lock.Leave;
end;

function GetOnMissingTranslation: {n} TMissingTranslHandler;
begin
  Lock.Enter; result := LangMan.OnMissingTranslation; Lock.Leave;
end;

procedure SetOnMissingTranslation ({n} aMissingTranslHandler: TMissingTranslHandler);
begin
  Lock.Enter; LangMan.OnMissingTranslation := aMissingTranslHandler; Lock.Leave;
end;

function GetOnParseError: {n} TParseErrorHandler;
begin
  Lock.Enter; result := LangMan.OnParseError; Lock.Leave;
end;

procedure SetOnParseError ({n} aOnParseError: TParseErrorHandler);
begin
  Lock.Enter; LangMan.OnParseError := aOnParseError; Lock.Leave;
end;
  
function LoadLangData (const aLang, aLangData, aDataSource: myAStr): boolean;
begin
  Lock.Enter; result := LangMan.LoadLangData(aLang, aLangData, aDataSource); Lock.Leave;
end;

procedure UnloadLang (const aLang: myAStr);
begin
  Lock.Enter; LangMan.UnloadLang(aLang); Lock.Leave;
end;

procedure UnloadAllLangs;
begin
  Lock.Enter; LangMan.UnloadAllLangs; Lock.Leave;
end;

function Translate (const aKey, aSection: myAStr; aLang: myAStr; var Res: myAStr): boolean;
begin
  Lock.Enter; result := LangMan.Translate(aKey, aSection, aLang, Res); Lock.Leave;
end;

function tr (const aKey, aSection: myAStr; aLang: myAStr = CURRENT_LANG): myAStr;
begin
  Lock.Enter; result := LangMan.tr(aKey, aSection, aLang); Lock.Leave;
end;

function  tr (const aKey, aSection: myAStr; aTemplArgs: array of myAStr): myAStr;
begin
  Lock.Enter; result := LangMan.tr(aKey, aSection, aTemplArgs); Lock.Leave;
end;

function InstallLangMan ({?} NewLangMan: ALangMan): {?} ALangMan;
begin
  Lock.Enter;
  result  := LangMan;
  LangMan := NewLangMan;
  Lock.Leave;
end;

begin
  Lock.Init;
  InstallLangMan(TLangMan.Create);
end.
