unit Rainbow;
(*
  DESCRIPTION: Adds markup language support to all Heroes texts (EML - Era Markup Language).
  AUTHOR:      Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
*)

(***)  interface  (***)
uses
  Math,
  SysUtils,
  Windows,

  Libspng,

  ApiJack,
  AssocArrays,
  Core,
  Crypto,
  DataLib,
  DlgMes,
  EventMan,
  GameExt,
  Graph,
  GraphTypes,
  Heroes,
  Lists,
  Memory,
  PatchApi,
  StrLib,
  TextScan,
  TypeWrappers,
  UtilsB2, Legacy;

type
  (* Import *)
  TList   = DataLib.TList;
  TDict   = DataLib.TDict;
  TString = TypeWrappers.TString;

const
  MAX_CHINESE_LATIN_CHARACTER = #160;

  DEF_COLOR     = 0;
  DEF_ALIGNMENT = -1;


type
  TGraphemWidthEstimator = function (Font: Heroes.PFontItem): integer; stdcall;

var
  (* Chinese loader support: {~color}...{~} => {...} *)
  ChineseLoaderOpt:             boolean;
  ChineseHandler:               pointer;
  ChineseGraphemWidthEstimator: TGraphemWidthEstimator;


procedure NameColor (Color32: integer; const Name: myAStr); stdcall;

function  ChineseGetCharColor: integer; stdcall;
procedure ChineseGotoNextChar; stdcall;
procedure ChineseSetTextAlignmentParamPtr (NewParamPtr: pinteger); stdcall;
procedure SetChineseGraphemWidthEstimator (Estimator: TGraphemWidthEstimator); stdcall;
procedure UpdateTextAttrsFromNextChar; stdcall;


(***) implementation (***)


exports
  (* Chinese only: temporal *)
  ChineseGetCharColor,
  ChineseGotoNextChar,
  ChineseSetTextAlignmentParamPtr,
  SetChineseGraphemWidthEstimator,
  UpdateTextAttrsFromNextChar;


  const
  BLANKS = [#0..#32];

  TOKEN_HASH_TOP    = 517545930;
  TOKEN_HASH_MIDDLE = -1635771697;
  TOKEN_HASH_BOTTOM = -1990233436;
  TOKEN_HASH_LEFT   = 2053629800;
  TOKEN_HASH_CENTER = 1089530660;
  TOKEN_HASH_RIGHT  = -1261800172;


type
  TTextBlockType = (TEXT_BLOCK_CHARS, TEXT_BLOCK_DEF);

  PEmlChars = ^TEmlChars;
  TEmlChars = record
    Color32: integer;
  end;

  PEmlImg = ^TEmlImg;
  TEmlImg = record
    IsBlock:       boolean;
    DrawFlags:     Graph.TDrawDefFrameFlags;
    OffsetX:       integer;
    OffsetY:       integer;
    SliceStartY:   integer;
    SliceHeight:   integer;
    NumFillChars:  integer;
    Height:        integer;
    NumLines:      integer;
    AttrVertAlign: integer;
  end;

  PEmlDef = ^TEmlDef;
  TEmlDef = record
  {U} Def:      Heroes.PDefItem;
      DefName:  myPChar; // Pointer to persisted string
      GroupInd: integer;
      FrameInd: integer;
  end;

  PTextBlock = ^TTextBlock;
  TTextBlock = record
    BlockType:      TTextBlockType;
    BlockLen:       integer;
    HorizAlignment: integer;

    case TTextBlockType of
      TEXT_BLOCK_CHARS: (
        CharsBlock: TEmlChars;
      );

      TEXT_BLOCK_DEF: (
        ImgBlock: TEmlImg;
        DefBlock: TEmlDef;
      );
  end; // .record TTextBlock

  TParsedText = class
   public
   {O} Blocks:        {O} TList {of PTextBlock};
   {U} Font:          PFontItem;
       RefCount:      integer;
       OrigText:      myAStr;
       ProcessedText: myAStr;
       NumBlocks:     integer;

    constructor Create (const OrigText: myAStr; {U} Font: Heroes.PFontItem);
    destructor  Destroy; override;

    (* Returns list of TParsedTextLine, suitable to be displayed in the box of given size *)
    function ToLines (BoxWidth: integer): {O} TList {of TParsedTextLine};

    function CountLines (BoxWidth: integer): integer;
  end; // .class TParsedText

  TParsedTextLine = class
   public
    Offset:   integer;
    Len:      integer;
    BlockInd: integer;
    BlockPos: integer;

    procedure ToTaggedText (ParsedText: TParsedText; Res: StrLib.TStrBuilder);
  end;

var
{O} NamedColors:       {U} AssocArrays.TAssocArray {of Color32: integer};
{O} LoadedResources:   {U} TDict {of loaded H3 resource};
{O} TextAttrsStack:    {U} Lists.TList {of (Color32, HorizAlign: integer)...};
{O} TextScanner:       TextScan.TTextScanner;
{O} TaggedLineBuilder: StrLib.TStrBuilder;

{O} CurrParsedText:        TParsedText = nil;
{U} CurrTextBlock:         PTextBlock  = nil;
    CurrTextNumLines:      integer     = 1;
    CurrTextAlignPtr:      pinteger    = nil;
    CurrTextDefHorizAlign: integer     = 0;

    CurrBlockInd:   integer;
    CurrBlockPos:   integer;
    CurrColor:      integer = DEF_COLOR;
    CurrHorizAlign: integer = DEF_ALIGNMENT;

    GlobalBuffer: array [0..1024 * 1024 - 1] of myChar;


procedure NameStdColors;
begin
  NamedColors[myAStr('AliceBlue')]            := Ptr($F0F8FF);
  NamedColors[myAStr('AntiqueWhite')]         := Ptr($FFFAEBD7);
  NamedColors[myAStr('Aqua')]                 := Ptr($FF00FFFF);
  NamedColors[myAStr('Aquamarine')]           := Ptr($FF7FFFD4);
  NamedColors[myAStr('Azure')]                := Ptr($FFF0FFFF);
  NamedColors[myAStr('Beige')]                := Ptr($FFF5F5DC);
  NamedColors[myAStr('Bisque')]               := Ptr($FFFFE4C4);
  NamedColors[myAStr('Black')]                := Ptr($FF000000);
  NamedColors[myAStr('BlanchedAlmond')]       := Ptr($FFFFEBCD);
  NamedColors[myAStr('Blue')]                 := Ptr($FF0000FF);
  NamedColors[myAStr('BlueViolet')]           := Ptr($FF8A2BE2);
  NamedColors[myAStr('Brown')]                := Ptr($FFA52A2A);
  NamedColors[myAStr('BurlyWood')]            := Ptr($FFDEB887);
  NamedColors[myAStr('CadetBlue')]            := Ptr($FF5F9EA0);
  NamedColors[myAStr('Chartreuse')]           := Ptr($FF7FFF00);
  NamedColors[myAStr('Chocolate')]            := Ptr($FFD2691E);
  NamedColors[myAStr('Coral')]                := Ptr($FFFF7F50);
  NamedColors[myAStr('CornflowerBlue')]       := Ptr($FF6495ED);
  NamedColors[myAStr('Cornsilk')]             := Ptr($FFFFF8DC);
  NamedColors[myAStr('Crimson')]              := Ptr($FFDC143C);
  NamedColors[myAStr('Cyan')]                 := Ptr($FF00FFFF);
  NamedColors[myAStr('DarkBlue')]             := Ptr($FF00008B);
  NamedColors[myAStr('DarkCyan')]             := Ptr($FF008B8B);
  NamedColors[myAStr('DarkGoldenRod')]        := Ptr($FFB8860B);
  NamedColors[myAStr('DarkGray')]             := Ptr($FFA9A9A9);
  NamedColors[myAStr('DarkGreen')]            := Ptr($FF006400);
  NamedColors[myAStr('DarkGrey')]             := Ptr($FFA9A9A9);
  NamedColors[myAStr('DarkKhaki')]            := Ptr($FFBDB76B);
  NamedColors[myAStr('DarkMagenta')]          := Ptr($FF8B008B);
  NamedColors[myAStr('DarkOliveGreen')]       := Ptr($FF556B2F);
  NamedColors[myAStr('Darkorange')]           := Ptr($FFFF8C00);
  NamedColors[myAStr('DarkOrchid')]           := Ptr($FF9932CC);
  NamedColors[myAStr('DarkRed')]              := Ptr($FF8B0000);
  NamedColors[myAStr('DarkSalmon')]           := Ptr($FFE9967A);
  NamedColors[myAStr('DarkSeaGreen')]         := Ptr($FF8FBC8F);
  NamedColors[myAStr('DarkSlateBlue')]        := Ptr($FF483D8B);
  NamedColors[myAStr('DarkSlateGrey')]        := Ptr($FF2F4F4F);
  NamedColors[myAStr('DarkTurquoise')]        := Ptr($FF00CED1);
  NamedColors[myAStr('DarkViolet')]           := Ptr($FF9400D3);
  NamedColors[myAStr('DeepPink')]             := Ptr($FFFF1493);
  NamedColors[myAStr('DeepSkyBlue')]          := Ptr($FF00BFFF);
  NamedColors[myAStr('DimGray')]              := Ptr($FF696969);
  NamedColors[myAStr('DodgerBlue')]           := Ptr($FF1E90FF);
  NamedColors[myAStr('FireBrick')]            := Ptr($FFB22222);
  NamedColors[myAStr('FloralWhite')]          := Ptr($FFFFFAF0);
  NamedColors[myAStr('ForestGreen')]          := Ptr($FF228B22);
  NamedColors[myAStr('Fuchsia')]              := Ptr($FFFF00FF);
  NamedColors[myAStr('Gainsboro')]            := Ptr($FFDCDCDC);
  NamedColors[myAStr('GhostWhite')]           := Ptr($FFF8F8FF);
  NamedColors[myAStr('Gold')]                 := Ptr($FFFFD700);
  NamedColors[myAStr('GoldenRod')]            := Ptr($FFDAA520);
  NamedColors[myAStr('Gray')]                 := Ptr($FF808080);
  NamedColors[myAStr('Green')]                := Ptr($FF008000);
  NamedColors[myAStr('GreenYellow')]          := Ptr($FFADFF2F);
  NamedColors[myAStr('Grey')]                 := Ptr($FF808080);
  NamedColors[myAStr('HoneyDew')]             := Ptr($FFF0FFF0);
  NamedColors[myAStr('HotPink')]              := Ptr($FFFF69B4);
  NamedColors[myAStr('IndianRed')]            := Ptr($FFCD5C5C);
  NamedColors[myAStr('Indigo')]               := Ptr($FF4B0082);
  NamedColors[myAStr('Ivory')]                := Ptr($FFFFFFF0);
  NamedColors[myAStr('Khaki')]                := Ptr($FFF0E68C);
  NamedColors[myAStr('Lavender')]             := Ptr($FFE6E6FA);
  NamedColors[myAStr('LavenderBlush')]        := Ptr($FFFFF0F5);
  NamedColors[myAStr('LawnGreen')]            := Ptr($FF7CFC00);
  NamedColors[myAStr('LemonChiffon')]         := Ptr($FFFFFACD);
  NamedColors[myAStr('LightBlue')]            := Ptr($FFADD8E6);
  NamedColors[myAStr('LightCoral')]           := Ptr($FFF08080);
  NamedColors[myAStr('LightCyan')]            := Ptr($FFE0FFFF);
  NamedColors[myAStr('LightGoldenRodYellow')] := Ptr($FFFAFAD2);
  NamedColors[myAStr('LightGray')]            := Ptr($FFD3D3D3);
  NamedColors[myAStr('LightGreen')]           := Ptr($FF90EE90);
  NamedColors[myAStr('LightGrey')]            := Ptr($FFD3D3D3);
  NamedColors[myAStr('LightPink')]            := Ptr($FFFFB6C1);
  NamedColors[myAStr('LightSalmon')]          := Ptr($FFFFA07A);
  NamedColors[myAStr('LightSeaGreen')]        := Ptr($FF20B2AA);
  NamedColors[myAStr('LightSkyBlue')]         := Ptr($FF87CEFA);
  NamedColors[myAStr('LightSlateGray')]       := Ptr($FF778899);
  NamedColors[myAStr('LightSteelBlue')]       := Ptr($FFB0C4DE);
  NamedColors[myAStr('LightYellow')]          := Ptr($FFFFFFE0);
  NamedColors[myAStr('Lime')]                 := Ptr($FF00FF00);
  NamedColors[myAStr('LimeGreen')]            := Ptr($FF32CD32);
  NamedColors[myAStr('Linen')]                := Ptr($FFFAF0E6);
  NamedColors[myAStr('Magenta')]              := Ptr($FFFF00FF);
  NamedColors[myAStr('Maroon')]               := Ptr($FF800000);
  NamedColors[myAStr('MediumAquaMarine')]     := Ptr($FF66CDAA);
  NamedColors[myAStr('MediumBlue')]           := Ptr($FF0000CD);
  NamedColors[myAStr('MediumOrchid')]         := Ptr($FFBA55D3);
  NamedColors[myAStr('MediumPurple')]         := Ptr($FF9370D8);
  NamedColors[myAStr('MediumSeaGreen')]       := Ptr($FF3CB371);
  NamedColors[myAStr('MediumSlateBlue')]      := Ptr($FF7B68EE);
  NamedColors[myAStr('MediumSpringGreen')]    := Ptr($FF00FA9A);
  NamedColors[myAStr('MediumTurquoise')]      := Ptr($FF48D1CC);
  NamedColors[myAStr('MediumVioletRed')]      := Ptr($FFC71585);
  NamedColors[myAStr('MidnightBlue')]         := Ptr($FF191970);
  NamedColors[myAStr('MintCream')]            := Ptr($FFF5FFFA);
  NamedColors[myAStr('MistyRose')]            := Ptr($FFFFE4E1);
  NamedColors[myAStr('Moccasin')]             := Ptr($FFFFE4B5);
  NamedColors[myAStr('NavajoWhite')]          := Ptr($FFFFDEAD);
  NamedColors[myAStr('Navy')]                 := Ptr($FF000080);
  NamedColors[myAStr('OldLace')]              := Ptr($FFFDF5E6);
  NamedColors[myAStr('Olive')]                := Ptr($FF808000);
  NamedColors[myAStr('OliveDrab')]            := Ptr($FF6B8E23);
  NamedColors[myAStr('Orange')]               := Ptr($FFFFA500);
  NamedColors[myAStr('OrangeRed')]            := Ptr($FFFF4500);
  NamedColors[myAStr('Orchid')]               := Ptr($FFDA70D6);
  NamedColors[myAStr('PaleGoldenRod')]        := Ptr($FFEEE8AA);
  NamedColors[myAStr('PaleGreen')]            := Ptr($FF98FB98);
  NamedColors[myAStr('PaleTurquoise')]        := Ptr($FFAFEEEE);
  NamedColors[myAStr('PaleVioletRed')]        := Ptr($FFD87093);
  NamedColors[myAStr('PapayaWhip')]           := Ptr($FFFFEFD5);
  NamedColors[myAStr('PeachPuff')]            := Ptr($FFFFDAB9);
  NamedColors[myAStr('Peru')]                 := Ptr($FFCD853F);
  NamedColors[myAStr('Pink')]                 := Ptr($FFFFC0CB);
  NamedColors[myAStr('Plum')]                 := Ptr($FFDDA0DD);
  NamedColors[myAStr('PowderBlue')]           := Ptr($FFB0E0E6);
  NamedColors[myAStr('Purple')]               := Ptr($FF800080);
  NamedColors[myAStr('Red')]                  := Ptr($FFFF0000);
  NamedColors[myAStr('RosyBrown')]            := Ptr($FFBC8F8F);
  NamedColors[myAStr('RoyalBlue')]            := Ptr($FF4169E1);
  NamedColors[myAStr('SaddleBrown')]          := Ptr($FF8B4513);
  NamedColors[myAStr('Salmon')]               := Ptr($FFFA8072);
  NamedColors[myAStr('SandyBrown')]           := Ptr($FFF4A460);
  NamedColors[myAStr('SeaGreen')]             := Ptr($FF2E8B57);
  NamedColors[myAStr('SeaShell')]             := Ptr($FFFFF5EE);
  NamedColors[myAStr('Sienna')]               := Ptr($FFA0522D);
  NamedColors[myAStr('Silver')]               := Ptr($FFC0C0C0);
  NamedColors[myAStr('SkyBlue')]              := Ptr($FF87CEEB);
  NamedColors[myAStr('SlateBlue')]            := Ptr($FF6A5ACD);
  NamedColors[myAStr('SlateGray')]            := Ptr($FF708090);
  NamedColors[myAStr('Snow')]                 := Ptr($FFFFFAFA);
  NamedColors[myAStr('SpringGreen')]          := Ptr($FF00FF7F);
  NamedColors[myAStr('SteelBlue')]            := Ptr($FF4682B4);
  NamedColors[myAStr('Tan')]                  := Ptr($FFD2B48C);
  NamedColors[myAStr('Teal')]                 := Ptr($FF008080);
  NamedColors[myAStr('Thistle')]              := Ptr($FFD8BFD8);
  NamedColors[myAStr('Tomato')]               := Ptr($FFFF6347);
  NamedColors[myAStr('Turquoise')]            := Ptr($FF40E0D0);
  NamedColors[myAStr('Violet')]               := Ptr($FFEE82EE);
  NamedColors[myAStr('Wheat')]                := Ptr($FFF5DEB3);
  NamedColors[myAStr('White')]                := Ptr($FFFFFFFF);
  NamedColors[myAStr('WhiteSmoke')]           := Ptr($FFF5F5F5);
  NamedColors[myAStr('Yellow')]               := Ptr($FFFFFF00);
  NamedColors[myAStr('YellowGreen')]          := Ptr($FF9ACD32);
  NamedColors[myAStr('r')]                    := Ptr($FFF2223E);
  NamedColors[myAStr('g')]                    := Ptr(Heroes.HEROES_GOLD_COLOR_CODE);
  NamedColors[myAStr('b')]                    := NamedColors[myAStr('Blue')];
  NamedColors[myAStr('y')]                    := NamedColors[myAStr('Yellow')];
  NamedColors[myAStr('w')]                    := NamedColors[myAStr('White')];
  NamedColors[myAStr('o')]                    := NamedColors[myAStr('Orange')];
  NamedColors[myAStr('p')]                    := NamedColors[myAStr('Purple')];
  NamedColors[myAStr('a')]                    := NamedColors[myAStr('Aqua')];
end; // .procedure NameStdColors

procedure NameColor (Color32: integer; const Name: myAStr);
begin
  NamedColors[Name] := Ptr(Color32);
end;

function IsChineseLoaderPresent (out ChineseHandler: pointer): boolean;
begin
  result  :=  pbyte($4B5202)^ = $E9;

  if result then begin
    ChineseHandler  :=  Ptr(pinteger($4B5203)^ + integer($4B5207));
  end;
end;

(* Loads def image and caches it forever for fast drawing *)
function LoadDefImage (const FileName: myAStr): {n} Heroes.PDefItem;
begin
  result := LoadedResources[FileName];

  if result = nil then begin
    result := Heroes.LoadDef(FileName);

    if result <> nil then begin
      LoadedResources[FileName] := result;
    end;
  end;
end;

function GetGraphemWidth (Font: Heroes.PFontItem; Graphem: myPChar; out GraphemSize: integer): integer;
var
  CharInfo: Heroes.PFontCharInfo;

begin
  if ChineseLoaderOpt and (Graphem^ > MAX_CHINESE_LATIN_CHARACTER) and (Graphem[1] > MAX_CHINESE_LATIN_CHARACTER) then begin
    result      := ChineseGraphemWidthEstimator(Font);
    GraphemSize := 2;
  end else begin
    CharInfo    := @Font.CharInfos[Graphem^];
    result      := CharInfo.SpaceBefore + CharInfo.Width + CharInfo.SpaceAfter;
    GraphemSize := 1;
  end;
end;

function ReadEmlValue: myAStr;
begin
  result := '';

  if TextScanner.c = '"' then begin
    TextScanner.GotoNextChar();
    TextScanner.ReadTokenTillDelim(['"'], result);
    TextScanner.GotoNextChar();
  end else begin
    TextScanner.ReadTokenTillDelim([' ', ':', '}'], result);
  end;
end;

function ReadEmlIntValue (DefValue: integer): integer;
begin
  if not Legacy.TryStrToInt(ReadEmlValue, result) then begin
    result := DefValue;
  end;
end;

(* Either reuses existing array or creates new one if nil is passed *)
function ParseEmlAttrs ({On} Attrs: {O} TDict {of TString}): {UO} TDict {of TString};
var
  Key:   myAStr;
  Value: myAStr;
  c:     myChar;

begin
  result := Attrs;

  if result <> nil then begin
    result.Clear;
  end else begin
    result := DataLib.NewDict(UtilsB2.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  end;

  TextScanner.SkipCharset(BLANKS);
  c := TextScanner.c;

  while not (c in [#0, '}']) do begin
    TextScanner.ReadTokenTillDelim(['}', ' ', '='], Key);
    Value := '';

    if TextScanner.c = '=' then begin
      TextScanner.GotoNextChar;
      Value := ReadEmlValue;
    end;

    result[Key] := TString.Create(Value);

    TextScanner.SkipCharset(BLANKS);
    c := TextScanner.c;
  end; // .while
end; // .function ParseEmlAttrs

// var
//   List: TList;

constructor TParsedText.Create (const OrigText: myAStr; {U} Font: Heroes.PFontItem);
const
  LINE_END_MARKER         = #10;
  NBSP                    = #160;
  RGBA_COLOR_CODE_MIN_LEN = 7;

var
{U} Buf:      myPChar;
    StartPos: integer;
    c:        myChar;

{U}  TextBlock:       PTextBlock;
{On} EmlAttrs:        {O} TDict {of TString};
{Un} AttrValue:       TString;
     BlockLen:        integer;
     IsTag:           boolean;
     IsEraTag:        boolean;
     IsEmbeddedImage: boolean;
     NumSpaceChars:   integer;
     VertAlignHash:   integer;
     ValueHash:       integer;
     LinesHeight:     integer;
     ImageWidth:      integer;

     TempStr:     myAStr;
     FontName:    myAStr absolute TempStr;
     ColorName:   myAStr absolute TempStr;
     DefName:     myAStr absolute TempStr;
     FrameIndStr: myAStr absolute TempStr;
     TagName:     myAStr;

     NativeTag:      myChar;
     NbspWidth:      integer;
     NumFillChars:   integer;
     CharInfo:       Heroes.PFontCharInfo;
     CurrColor:      integer;
     CurrHorizAlign: integer;
     ResLen:         integer;
     i:              integer;

  procedure BeginNewColorBlock;
  begin
    if (TextBlock.BlockType <> TEXT_BLOCK_CHARS) or (TextBlock.BlockLen > 0) then begin
      New(TextBlock);
      Self.Blocks.Add(TextBlock);
      TextBlock.BlockLen       := 0;
      TextBlock.BlockType      := TEXT_BLOCK_CHARS;
      TextBlock.HorizAlignment := CurrHorizAlign;
    end;
  end;

  procedure PopTextAttrsTuple;
  const
    TEXT_ATTRS_TUPLE_SIZE = 2;

  var
    StackSize: integer;

  begin
    StackSize := TextAttrsStack.Count;

    if StackSize > 0 then begin
      TextAttrsStack.SetCount(StackSize - TEXT_ATTRS_TUPLE_SIZE);
    end;

    if StackSize > TEXT_ATTRS_TUPLE_SIZE then begin
      CurrColor      := integer(TextAttrsStack[StackSize - TEXT_ATTRS_TUPLE_SIZE - 2]);
      CurrHorizAlign := integer(TextAttrsStack[StackSize - TEXT_ATTRS_TUPLE_SIZE - 1]);
    end else begin
      CurrColor      := DEF_COLOR;
      CurrHorizAlign := DEF_ALIGNMENT;
    end;
  end;

  procedure HandleColorTag (const ColorName: myAStr);
  begin
    CurrColor := 0;

    if NamedColors.GetExistingValue(ColorName, pointer(CurrColor)) then begin
      // Ok
    end else if Legacy.TryStrToInt('$' + ColorName, CurrColor) then begin
      if Length(ColorName) < RGBA_COLOR_CODE_MIN_LEN then begin
        CurrColor := CurrColor or GraphTypes.FULLY_OPAQUE_MASK_32;
      end else begin
        CurrColor := ((CurrColor and $FF) shl 24) or ((CurrColor shr 8) and GraphTypes.RGB_CHANNELS_MASK_32);
      end;
    end else begin
      CurrColor := DEF_COLOR;
    end;
  end;

  procedure HandleHorizAlignTag (const AttrValue: myAStr);
  begin
    ValueHash := Crypto.AnsiCrc32(AttrValue);

    case ValueHash of
      TOKEN_HASH_LEFT:   CurrHorizAlign := Heroes.TEXT_ALIGN_LEFT;
      TOKEN_HASH_CENTER: CurrHorizAlign := Heroes.TEXT_ALIGN_CENTER;
      TOKEN_HASH_RIGHT:  CurrHorizAlign := Heroes.TEXT_ALIGN_RIGHT;
    end;
  end;

begin
  inherited Create;

  Buf       := @GlobalBuffer[0];
  EmlAttrs  := nil;
  AttrValue := nil;
  // * * * * * //
  Self.Blocks   := Lists.NewList(UtilsB2.OWNS_ITEMS, not UtilsB2.ITEMS_ARE_OBJECTS, UtilsB2.NO_TYPEGUARD, not UtilsB2.ALLOW_NIL);
  Self.OrigText := OrigText;
  Self.Font     := Font;
  New(TextBlock);
  Self.Blocks.Add(TextBlock);

  TextBlock.BlockLen           := Length(OrigText);
  TextBlock.BlockType          := TEXT_BLOCK_CHARS;
  TextBlock.CharsBlock.Color32 := DEF_COLOR;
  TextBlock.HorizAlignment     := DEF_ALIGNMENT;
  CurrColor                    := DEF_COLOR;
  CurrHorizAlign               := DEF_ALIGNMENT;
  NativeTag                    := #0;

  FontName := myPChar(@Font.Name);

  if LoadedResources[FontName] = nil then begin
    LoadedResources[FontName] := Font;
    Inc(Font.RefCount);
  end;

  if Length(OrigText) <= sizeof(GlobalBuffer) - 1 then begin
    TextAttrsStack.Clear;
    TextScanner.Connect(OrigText, LINE_END_MARKER);

    while not TextScanner.EndOfText do begin
      StartPos        := TextScanner.Pos;
      NumSpaceChars   := 0;
      IsTag           := false;
      IsEraTag        := false;
      IsEmbeddedImage := false;

      while not IsTag and TextScanner.GetCurrChar(c) do begin
        if c in ['{', '}'] then begin
          IsTag           := true;
          NativeTag       := c;
          IsEraTag        := TextScanner.CharsRel[1] = '~';
          IsEmbeddedImage := IsEraTag and (TextScanner.CharsRel[2] = '>');
        end else if c in [#10, ' '] then begin
          Inc(NumSpaceChars);
        end else if ChineseLoaderOpt and (c > MAX_CHINESE_LATIN_CHARACTER) and (TextScanner.CharsRel[1] > MAX_CHINESE_LATIN_CHARACTER) then begin
          Inc(NumSpaceChars);
          TextScanner.GotoNextChar;
        end;

        if not IsTag then begin
          TextScanner.GotoNextChar;
        end;
      end; // .while

      // Output normal characters to result buffer
      BlockLen           := TextScanner.Pos - StartPos;
      UtilsB2.CopyMem(BlockLen, pointer(@OrigText[StartPos]), Buf);
      Buf                := UtilsB2.PtrOfs(Buf, BlockLen);
      TextBlock.BlockLen := BlockLen - NumSpaceChars;

      // Text ended
      if not IsTag then begin
        break;
      end;

      if IsEmbeddedImage then begin
        TextScanner.GotoRelPos(+3);

        New(TextBlock);
        Self.Blocks.Add(TextBlock);
        TextBlock.BlockLen               := 0;
        TextBlock.BlockType              := TEXT_BLOCK_DEF;
        TextBlock.HorizAlignment         := CurrHorizAlign;
        TextBlock.ImgBlock.IsBlock       := false;
        TextBlock.ImgBlock.DrawFlags     := [Graph.DDF_CROP];
        TextBlock.ImgBlock.NumFillChars  := 0;
        TextBlock.ImgBlock.OffsetX       := 0;
        TextBlock.ImgBlock.OffsetY       := 0;
        TextBlock.ImgBlock.SliceStartY   := 0;
        TextBlock.ImgBlock.SliceHeight   := 0;
        TextBlock.ImgBlock.Height        := 0;
        TextBlock.ImgBlock.NumLines      := 1;
        TextBlock.DefBlock.Def           := nil;
        TextBlock.DefBlock.GroupInd      := 0;
        TextBlock.DefBlock.FrameInd      := 0;
        TextBlock.ImgBlock.AttrVertAlign := TOKEN_HASH_MIDDLE;

        DefName := ReadEmlValue;

        if DefName <> '' then begin
          DefName                    := Legacy.AnsiLowerCase(DefName);
          TextBlock.DefBlock.DefName := Memory.UniqueStrings[myPChar(DefName)];

          if Length(DefName) <= 4096 then begin
            TextBlock.DefBlock.Def := LoadDefImage(DefName);
          end;

          if TextScanner.c = ':' then begin
            TextScanner.GotoNextChar();
            TextBlock.DefBlock.FrameInd := ReadEmlIntValue(0);

            if TextScanner.c = ':' then begin
              TextScanner.GotoNextChar();
              TextBlock.DefBlock.GroupInd := TextBlock.DefBlock.FrameInd;
              TextBlock.DefBlock.FrameInd := ReadEmlIntValue(0);
            end;
          end; // .if
        end; // .if

        EmlAttrs                   := ParseEmlAttrs(EmlAttrs);
        TextBlock.ImgBlock.IsBlock := EmlAttrs[myAStr('block')] <> nil;

        if EmlAttrs[myAStr('mirror')] <> nil then begin
          System.Include(TextBlock.ImgBlock.DrawFlags, Graph.DDF_MIRROR);
        end;

        if TextBlock.DefBlock.Def <> nil then begin
          CharInfo                        := @Font.CharInfos[NBSP];
          NbspWidth                       := Math.Max(1, CharInfo.SpaceBefore + CharInfo.Width + CharInfo.SpaceAfter);
          ImageWidth                      := Graph.GetDefFrameWidth(TextBlock.DefBlock.Def, TextBlock.DefBlock.GroupInd, TextBlock.DefBlock.FrameInd);
          NumFillChars                    := (ImageWidth + NbspWidth - 1) div NbspWidth;
          TextBlock.ImgBlock.NumFillChars := NumFillChars;
          TextBlock.ImgBlock.Height       := Graph.GetDefFrameHeight(TextBlock.DefBlock.Def, TextBlock.DefBlock.GroupInd, TextBlock.DefBlock.FrameInd);
          TextBlock.ImgBlock.SliceHeight  := TextBlock.ImgBlock.Height;
          TextBlock.ImgBlock.OffsetX      := (NumFillChars * NbspWidth - ImageWidth) div 2;
          TextBlock.BlockLen              := NumFillChars;

          if TextBlock.ImgBlock.IsBlock then begin
            // Handle image slicing (internal purposes only)
            AttrValue := EmlAttrs[myAStr('from-y')];

            if AttrValue <> nil then begin
              Legacy.TryStrToInt(AttrValue.Value, TextBlock.ImgBlock.SliceStartY);
            end;

            AttrValue := EmlAttrs[myAStr('height')];

            if AttrValue <> nil then begin
              Legacy.TryStrToInt(AttrValue.Value, TextBlock.ImgBlock.SliceHeight);
            end;

            TextBlock.ImgBlock.NumLines := (TextBlock.ImgBlock.SliceHeight + Font.Height - 1) div Font.Height;
          end; // .if

          LinesHeight   := TextBlock.ImgBlock.NumLines * Font.Height;
          VertAlignHash := TOKEN_HASH_MIDDLE;
          AttrValue     := EmlAttrs[myAStr('valign')];

          if AttrValue <> nil then begin
            ValueHash := Crypto.AnsiCrc32(AttrValue.Value);

            if (ValueHash = TOKEN_HASH_TOP) or (ValueHash = TOKEN_HASH_BOTTOM) then begin
              VertAlignHash := ValueHash;
            end;
          end;

          case VertAlignHash of
            TOKEN_HASH_MIDDLE: TextBlock.ImgBlock.OffsetY := (LinesHeight - TextBlock.ImgBlock.SliceHeight) div 2;
            TOKEN_HASH_BOTTOM: TextBlock.ImgBlock.OffsetY := LinesHeight - TextBlock.ImgBlock.SliceHeight;
          end;

          TextBlock.ImgBlock.AttrVertAlign := VertAlignHash;

          if TextBlock.ImgBlock.IsBlock then begin
            AttrValue := EmlAttrs[myAStr('offset-y')];

            if AttrValue <> nil then begin
              Legacy.TryStrToInt(AttrValue.Value, TextBlock.ImgBlock.OffsetY);
            end;
          end;

          // Force line break for block image not at line start
          if TextBlock.ImgBlock.IsBlock and (Buf <> @GlobalBuffer) and (Buf[-1] <> LINE_END_MARKER) then begin
            Buf^ := LINE_END_MARKER;
            Inc(Buf);
          end;

          // Output serie of non-breaking spaces to compensate image width
          for i := 0 to NumFillChars - 1 do begin
            Buf^ := NBSP;
            Inc(Buf);
          end;

          // For block images output serie (LINE_END, NBSP) lines to compensate image height
          if TextBlock.ImgBlock.IsBlock then begin
            for i := 1 to TextBlock.ImgBlock.NumLines - 1 do begin
              Buf^ := LINE_END_MARKER;
              Inc(Buf);
              Buf^ := NBSP;
              Inc(Buf);
            end;

            Inc(TextBlock.BlockLen, TextBlock.ImgBlock.NumLines - 1);

            // Force line end after image block, unless it's already present
            if not (TextScanner.CharsRel[+1] in [#0, LINE_END_MARKER]) then begin
              Buf^ := LINE_END_MARKER;
              Inc(Buf);
            end;
          end; // .if

          BeginNewColorBlock;
          TextBlock.CharsBlock.Color32 := CurrColor;
          TextBlock.HorizAlignment     := CurrHorizAlign;
        end; // .if

        TextScanner.GotoNextChar();

        continue;
      end; // .if

      // Handle native '{', '}' tags
      if not IsEraTag then begin
        BeginNewColorBlock;

        if NativeTag = '}' then begin
          PopTextAttrsTuple;
        end else begin
          CurrColor := HEROES_GOLD_COLOR_CODE;
          TextAttrsStack.Add(Ptr(CurrColor));
          TextAttrsStack.Add(Ptr(CurrHorizAlign));
        end;

        TextBlock.CharsBlock.Color32 := CurrColor;
        TextBlock.HorizAlignment     := CurrHorizAlign;
        TextScanner.GotoNextChar;
      // Handle other ERL open/close tags
      end else if TextScanner.GotoRelPos(+2) and TextScanner.ReadTokenTillDelim(['}', ' '], TagName) then begin
        BeginNewColorBlock;

        if TagName = '' then begin
          TextScanner.FindChar('}');
          PopTextAttrsTuple;
        end else begin
          EmlAttrs := ParseEmlAttrs(EmlAttrs);

          // Treat '{~xxx' as color tag, unless it's new text tag with optional "color" attribute
          if TagName <> 'text' then begin
            HandleColorTag(TagName);
          end else begin
            AttrValue := EmlAttrs[myAStr('color')];

            if AttrValue <> nil then begin
              HandleColorTag(AttrValue.Value);
            end;
          end;

          AttrValue := EmlAttrs[myAStr('align')];

          if AttrValue <> nil then begin
            HandleHorizAlignTag(AttrValue.Value);
          end;

          TextAttrsStack.Add(Ptr(CurrColor));
          TextAttrsStack.Add(Ptr(CurrHorizAlign));
        end; // .else

        TextBlock.CharsBlock.Color32 := CurrColor;
        TextBlock.HorizAlignment     := CurrHorizAlign;
        TextScanner.GotoNextChar;
      end; // .elseif
    end; // .while
  end; // .if

  ResLen := integer(Buf) - integer(@GlobalBuffer[0]);
  {!} Assert(ResLen < sizeof(GlobalBuffer), 'Huge text exceeded ERA ParseText buffer capacity');

  SetLength(Self.ProcessedText, ResLen);

  if ResLen > 0 then begin
    UtilsB2.CopyMem(ResLen, @GlobalBuffer[0], @Self.ProcessedText[1]);
  end;

  Self.NumBlocks := Self.Blocks.Count;

  // if Self.NumBlocks > 1 then begin
  //   List := Self.ToLines(400);

  //   for i := 0 to List.Count - 1 do begin
  //     TParsedTextLine(List[i]).ToTaggedText(Self, TaggedLineBuilder);
  //     VarDump(myAStr(['LineN:', i + 1, TaggedLineBuilder.BuildStr())]);
  //   end;
  // end;

  // * * * * * //
  Legacy.FreeAndNil(EmlAttrs);
end; // .function TParsedText.Create

destructor TParsedText.Destroy;
begin
  Legacy.FreeAndNil(Self.Blocks);
end;

function TParsedText.ToLines (BoxWidth: integer): {O} TList {of TParsedTextLine};
type
  TSavepoint = record
    TextPtr:  myPChar;
    BlockInd: integer;
    BlockPos: integer;
    Len:      integer;
  end;

var
{O} Line:            TParsedTextLine;
    LineStart:       TSavepoint;
    LastWordEnd:     TSavepoint;
    Cursor:          TSavepoint;
    CurrBlock:       PTextBlock;
    LineWidth:       integer;
    GraphemWidth:    integer;
    GraphemSize:     integer;
    PrevGraphemSize: integer;
    TextStart:       myPChar;
    NumBlocks:       integer;
    c:               myChar;

begin
  Line := nil;
  // * * * * * //
  result := DataLib.NewList(UtilsB2.OWNS_ITEMS);

  if Self.ProcessedText = '' then begin
    exit;
  end;

  NumBlocks := Self.NumBlocks;
  CurrBlock := Self.Blocks[0];

  TextStart := myPChar(Self.ProcessedText);
  c         := #0;

  LineStart.TextPtr  := TextStart;
  LineStart.BlockInd := 0;
  LineStart.BlockPos := 0;
  LineStart.Len      := 0;

  LastWordEnd := LineStart;
  Cursor      := LineStart;

  // Handle all lines
  repeat
    LineWidth       := 0;
    PrevGraphemSize := 0;

    // Handle single line
    while true do begin
      c := Cursor.TextPtr^;

      // End of text/line
      if c in [#0, #10] then begin
        break;
      end;

      GraphemWidth := GetGraphemWidth(Self.Font, Cursor.TextPtr, GraphemSize);
      Inc(LineWidth, GraphemWidth);

      if LineWidth > BoxWidth then begin
        if c = ' ' then begin
          break;
        // This word should be wrapped, fallback to the previous word
        end else if LastWordEnd.TextPtr <> LineStart.TextPtr then begin
          Cursor    := LastWordEnd;
          CurrBlock := Self.Blocks[Cursor.BlockInd];
          break;
        end;
      end;

      // Track word end
      if (GraphemSize > 1) or (PrevGraphemSize > 1) or ((Cursor.TextPtr <> LineStart.TextPtr) and (((c = ' ') and (Cursor.TextPtr[-1] <> ' ') or ((c <> ' ') and (Cursor.TextPtr[-1] = ' '))))) then begin
        LastWordEnd := Cursor;
      end;

      // Move position in text
      Inc(Cursor.TextPtr, GraphemSize);
      Inc(Cursor.Len,     GraphemSize);

      PrevGraphemSize := GraphemSize;

      // Move position in block
      if c <> ' ' then begin
        // First skip empty blocks
        while (Cursor.BlockPos >= CurrBlock.BlockLen) and (Cursor.BlockInd + 1 < NumBlocks) do begin
          Inc(Cursor.BlockInd);
          Cursor.BlockPos := 0;
          CurrBlock       := Self.Blocks[Cursor.BlockInd];
        end;

        // It's guaranteed to move by at least single meaningful character and start at next, probably empty, block
        Inc(Cursor.BlockPos);

        if (Cursor.BlockPos >= CurrBlock.BlockLen) and (Cursor.BlockInd + 1 < NumBlocks) then begin
          Inc(Cursor.BlockInd);
          Cursor.BlockPos := 0;
          CurrBlock       := Self.Blocks[Cursor.BlockInd];
        end;
      end;
    end; // .while

    // Create new line
    Line          := TParsedTextLine.Create;
    Line.Offset   := integer(LineStart.TextPtr) - integer(TextStart);
    Line.BlockInd := LineStart.BlockInd;
    Line.BlockPos := LineStart.BlockPos;
    Line.Len      := Cursor.Len;

    // if Self.NumBlocks > 1 then begin
    //   VarDump([myAStr('#ToLines#'), Copy(Self.ProcessedText, Line.Offset + 1, Line.Len), Line.BlockInd, Line.BlockPos, Line.Offset, Line.Len]);
    // end;

    // Add the line to the result
    result.Add(Line); Line := nil;

    // Skip line end character
    if c = #10 then begin
      Inc(Cursor.TextPtr);
    // Skip trailing spaces
    end else begin
      while Cursor.TextPtr^ = ' ' do begin
        Inc(Cursor.TextPtr);
      end;
    end;

    // Init next line
    Cursor.Len  := 0;
    LineStart   := Cursor;
    LastWordEnd := Cursor;
  until Cursor.TextPtr^ = #0;
  // * * * * * //
  {!} Assert(Line = nil);
end; // .function TParsedText.ToLines

function TParsedText.CountLines (BoxWidth: integer): integer;
var
  {O} Lines: {O} TList {of TParsedTextLine};

begin
  Lines  := Self.ToLines(BoxWidth);
  result := Lines.Count;
  Legacy.FreeAndNil(Lines);
end;

procedure TParsedTextLine.ToTaggedText (ParsedText: TParsedText; Res: StrLib.TStrBuilder);
var
  Text:              myPChar;
  TextEnd:           myPChar;
  SliceStart:        myPChar;
  SliceLen:          integer;
  BlockInd:          integer;
  BlockPos:          integer;
  CurrBlock:         PTextBlock;
  NumBlocks:         integer;
  InitialHorizAlign: integer;
  SliceStartY:       integer;
  SliceHeight:       integer;
  ImageLineN:        integer;
  OffsetY:           integer;

begin
  Res.Clear;

  if Self.Len <= 0 then begin
    exit;
  end;

  // Init
  Text      := UtilsB2.PtrOfs(myPChar(ParsedText.ProcessedText), Self.Offset);
  TextEnd   := UtilsB2.PtrOfs(Text, Self.Len);
  BlockInd  := Self.BlockInd;
  BlockPos  := Self.BlockPos;
  NumBlocks := ParsedText.NumBlocks;
  CurrBlock := ParsedText.Blocks[BlockInd];

  // Always output text alignment tag as whole line wrapper tag, unless it's default alignment
  InitialHorizAlign := CurrBlock.HorizAlignment;

  if InitialHorizAlign <> DEF_ALIGNMENT then begin
    case InitialHorizAlign of
      Heroes.TEXT_ALIGN_LEFT:   Res.Append('{~text align=left}');
      Heroes.TEXT_ALIGN_CENTER: Res.Append('{~text align=center}');
      Heroes.TEXT_ALIGN_RIGHT:  Res.Append('{~text align=right}');
    end;
  end;

  // Process each physical line character
  while Text < TextEnd do begin
    SliceStart := Text;

    // Skip spacy characters, which do not belong to blocks
    while (Text < TextEnd) and (Text^ in [#10, ' ']) do begin
      Inc(Text);
    end;

    // Exit if there is no meaningful character to process
    if Text >= TextEnd then begin
      break;
    end;

    // Output spacy characters and start new slice
    SliceLen := integer(Text) - integer(SliceStart);
    Res.AppendBuf(SliceLen, SliceStart);
    SliceStart := Text;

    // Output block opening tag
    case CurrBlock.BlockType of
      TEXT_BLOCK_CHARS: begin
        Res.Append('{~');
        Res.Append(GraphTypes.Color32ToCode(CurrBlock.CharsBlock.Color32));

        if CurrBlock.HorizAlignment <> DEF_ALIGNMENT then begin
          case CurrBlock.HorizAlignment of
            Heroes.TEXT_ALIGN_LEFT:   Res.Append(' align=left');
            Heroes.TEXT_ALIGN_CENTER: Res.Append(' align=center');
            Heroes.TEXT_ALIGN_RIGHT:  Res.Append(' align=right');
          end;
        end;

        Res.Append('}');
      end;

      TEXT_BLOCK_DEF: begin
        Res.Append('{~>');
        Res.AppendBuf(Windows.LStrLenA(CurrBlock.DefBlock.DefName), CurrBlock.DefBlock.DefName);

        if (CurrBlock.DefBlock.GroupInd <> 0) or (CurrBlock.DefBlock.FrameInd <> 0) then begin
          Res.Append(':' + Legacy.IntToStr(CurrBlock.DefBlock.GroupInd));
          Res.Append(':' + Legacy.IntToStr(CurrBlock.DefBlock.FrameInd));
        end;

        if CurrBlock.ImgBlock.AttrVertAlign <> TOKEN_HASH_MIDDLE then begin
          case CurrBlock.ImgBlock.AttrVertAlign of
            TOKEN_HASH_TOP:    Res.Append(' valign=top');
            TOKEN_HASH_BOTTOM: Res.Append(' valign=bottom');
          end;
        end;

        if Graph.DDF_MIRROR in CurrBlock.ImgBlock.DrawFlags then begin
          Res.Append(' mirror');
        end;

        if CurrBlock.ImgBlock.IsBlock then begin
          Res.Append(' block');

          if BlockPos >= CurrBlock.ImgBlock.NumFillChars then begin
            ImageLineN  := BlockPos - CurrBlock.ImgBlock.NumFillChars + 1;
            SliceStartY := ImageLineN * ParsedText.Font.Height - CurrBlock.ImgBlock.OffsetY;
            SliceHeight := Min(CurrBlock.ImgBlock.Height - SliceStartY, ParsedText.Font.Height);
            OffsetY     := 0;
          end else begin
            SliceStartY := 0;
            SliceHeight := Min(CurrBlock.ImgBlock.Height, ParsedText.Font.Height - CurrBlock.ImgBlock.OffsetY);
            OffsetY     := CurrBlock.ImgBlock.OffsetY;
          end;

          Res.Append(' from-y=' + Legacy.IntToStr(SliceStartY));
          Res.Append(' offset-y=' + Legacy.IntToStr(OffsetY));
          Res.Append(' height=' + Legacy.IntToStr(SliceHeight));
        end; // .if

        Res.Append('}');
      end; // TEXT_BLOCK_DEF
    else
      {!} Assert(false, 'ToTaggedText: unsupported BlockType = ' + Legacy.IntToStr(ord(CurrBlock.BlockType)));
    end; // .switch CurrBlock.BlockType

    // Skip block meaningful characters
    while (Text < TextEnd) and (BlockPos < CurrBlock.BlockLen) do begin
      if not (Text^ in [#10, ' ']) then begin
        Inc(BlockPos);

        if ChineseLoaderOpt and (Text^ > MAX_CHINESE_LATIN_CHARACTER) and (Text[1] > MAX_CHINESE_LATIN_CHARACTER) then begin
          Inc(Text);
        end;
      end;

      Inc(Text);
    end;

    // Do not output image placeholder characters
    if CurrBlock.BlockType <> TEXT_BLOCK_CHARS then begin
      SliceStart := Text;
    end;

    SliceLen := integer(Text) - integer(SliceStart);
    Res.AppendBuf(SliceLen, SliceStart);

    // Output closing block tag
    case CurrBlock.BlockType of
      TEXT_BLOCK_CHARS: begin
        Res.Append('{~}');
      end;
    end;

    // Proceed to the next block
    if (BlockPos >= CurrBlock.BlockLen) and (BlockInd + 1 < NumBlocks) then begin
      Inc(BlockInd);
      BlockPos  := 0;
      CurrBlock := ParsedText.Blocks[BlockInd];
    end;
  end; // .while

  // Always output text alignment tag as whole line wrapper tag, unless it's default alignment
  if InitialHorizAlign <> DEF_ALIGNMENT then begin
    Res.Append('{~}');
  end;
end; // .procedure TParsedTextLine.ToTaggedText

function UpdateCurrParsedText (Font: Heroes.PFontItem; OrigStr: myPChar; OrigTextLen: integer = -1): {U} TParsedText;
var
  OrigText: myAStr;

begin
  if OrigTextLen < 0 then begin
    OrigTextLen := Windows.LStrLenA(OrigStr);
  end;

  if (CurrParsedText <> nil) and ((OrigTextLen <> Length(CurrParsedText.OrigText)) or (StrLib.ComparePchars(OrigStr, myPChar(CurrParsedText.OrigText)) <> 0)) then begin
    Legacy.FreeAndNil(CurrParsedText);
  end;

  if CurrParsedText = nil then begin
    OrigText       := '';
    SetString(OrigText, OrigStr, OrigTextLen);
    CurrParsedText := TParsedText.Create(OrigText, Font);
  end;

  result := CurrParsedText;
end; // .function UpdateCurrParsedText

(* Determines current block, based on position in block, number of blocks left and block length.
   Automatically skips/applies empty blocks. Updates current color if necessary *)
procedure UpdateCurrBlock; stdcall;
begin
  if (CurrParsedText <> nil) and (CurrTextBlock <> nil) then begin
    if CurrBlockPos < CurrTextBlock.BlockLen then begin
      CurrHorizAlign := CurrTextBlock.HorizAlignment;

      if CurrHorizAlign = DEF_ALIGNMENT then begin
        CurrHorizAlign := CurrTextDefHorizAlign;
      end;

      CurrTextAlignPtr^ := (CurrTextAlignPtr^ and not Heroes.HORIZ_TEXT_ALIGNMENT_MASK) or CurrHorizAlign;

      if CurrTextBlock.BlockType = TEXT_BLOCK_CHARS then begin
        CurrColor := CurrTextBlock.CharsBlock.Color32;
      end;
    end else begin
      while CurrBlockPos >= CurrTextBlock.BlockLen do begin
        CurrBlockPos := 0;
        Inc(CurrBlockInd);

        // Normal, valid case
        if CurrBlockInd < CurrParsedText.NumBlocks then begin
          CurrTextBlock  := CurrParsedText.Blocks[CurrBlockInd];
          CurrHorizAlign := CurrTextBlock.HorizAlignment;

          if CurrHorizAlign = DEF_ALIGNMENT then begin
            CurrHorizAlign := CurrTextDefHorizAlign;
          end;

          CurrTextAlignPtr^ := (CurrTextAlignPtr^ and not Heroes.HORIZ_TEXT_ALIGNMENT_MASK) or CurrHorizAlign;

          if CurrTextBlock.BlockType = TEXT_BLOCK_CHARS then begin
            CurrColor := CurrTextBlock.CharsBlock.Color32;
          end;
        // Something is broken, like invalid GBK character (missing second part of code point), mixed language, etc.
        // Empty string, probably. Recover to use the last attributes.
        end else begin
          CurrBlockInd := CurrParsedText.NumBlocks - 1;
          CurrBlockPos := CurrTextBlock.BlockLen;

          break;
        end;
      end; // .while
    end; // .else
  end; // .if
end; // .procedure UpdateCurrBlock

procedure UpdateTextAttrsFromNextChar; stdcall;
var
  SavedCurrBlockInd:  integer;
  SavedCurrBlockPos:  integer;
  SavedCurrTextBlock: PTextBlock;

begin
  SavedCurrBlockInd  := CurrBlockInd;
  SavedCurrBlockPos  := CurrBlockPos;
  SavedCurrTextBlock := CurrTextBlock;

  Inc(CurrBlockPos);
  UpdateCurrBlock;

  CurrBlockInd  := SavedCurrBlockInd;
  CurrBlockPos  := SavedCurrBlockPos;
  CurrTextBlock := SavedCurrTextBlock;
end;

function Hook_BeginParseText (Context: Core.PHookContext): longbool; stdcall;
begin
  UpdateCurrParsedText(Heroes.PFontItem(Context.EBX), myPChar(Context.EDX), Context.ECX);
  CurrTextNumLines := CurrParsedText.CountLines(pinteger(Context.EBP + $18)^);

  CurrColor             := DEF_COLOR;
  CurrHorizAlign        := DEF_ALIGNMENT;
  CurrTextAlignPtr      := Ptr(Context.EBP + $24);
  CurrTextDefHorizAlign := CurrTextAlignPtr^ and Heroes.HORIZ_TEXT_ALIGNMENT_MASK;
  CurrTextBlock         := CurrParsedText.Blocks[0];
  CurrBlockPos          := 0;
  CurrBlockInd          := 0;

  UpdateCurrBlock;
  CurrBlockPos := -1;

  Context.ECX                  := Length(CurrParsedText.ProcessedText);
  Context.EDX                  := integer(myPChar(CurrParsedText.ProcessedText));
  pinteger(Context.EBP - $14)^ := Context.ECX;
  pinteger(Context.EBP + $8)^  := Context.EDX;

  if ChineseLoaderOpt then begin
    Context.ECX     := Context.EBX;
    Context.RetAddr := ChineseHandler;
  end else begin
    // Overwritten Code
    if (pinteger(Context.EBP + $24)^ and 4) = 0 then begin
      Context.RetAddr := Ptr($4B52B2);
    end else begin
      Context.RetAddr := Ptr($4B525B);
    end;
  end; // .else

  result := not Core.EXEC_DEF_CODE;
end; // .function Hook_BeginParseText

function Hook_CountNumTextLines (Text: myPChar; BoxWidth: integer): integer; stdcall;
begin
  result := CurrTextNumLines;
end;

function Hook_ScrollTextDlg_CreateLineTextItem: integer; stdcall; assembler;
const
  SCROLLBAR_WIDTH = 24;
  SCROLLBAR_FIELD_OFFSET = $54;

asm
  cmp [ebx + SCROLLBAR_FIELD_OFFSET], 0
  je @finish
  sub dword [esp + $0C], SCROLLBAR_WIDTH
@finish:
  mov eax, $5BC6A0
  jmp eax
end;

function Hook_Font_DrawTextToPcx16_DetermineLineAlignment (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  UpdateTextAttrsFromNextChar;
  result := true;
end;

function Hook_Font_DrawTextToPcx16_End (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  CurrColor     := DEF_COLOR;
  CurrTextBlock := nil;
  result        := true;
end;

function Hook_GetCharColor (Context: Core.PHookContext): longbool; stdcall;
begin
  result := CurrColor = DEF_COLOR;

  if not result then begin
    Context.EAX := CurrColor;
  end;
end;

function Hook_HandleTags (Context: Core.PHookContext): longbool; stdcall;
var
  c:  myChar;

begin
  c                           := PCharByte(Context.EDX)^;
  PCharByte(Context.EBP - 4)^ := c;
  Context.RetAddr             := Ptr($4B50BA);

  if not (c in [#10, ' ']) then begin
    Inc(CurrBlockPos);
    UpdateCurrBlock;
  end;

  result := not Core.EXEC_DEF_CODE;
end; // .function Hook_HandleTags

function New_Font_CountNumTextLines (OrigFunc: pointer; Font: Heroes.PFontItem; Text: myPChar; BoxWidth: integer): integer; stdcall;
begin
  UpdateCurrParsedText(Font, Text);
  result := CurrParsedText.CountLines(BoxWidth);
end;

function New_Font_GetLineWidth (OrigFunc: pointer; Font: Heroes.PFontItem; Line: myPChar): integer; stdcall;
begin
  UpdateCurrParsedText(Font, Line);

  result := PatchApi.Call(THISCALL_, OrigFunc, [Font, myPChar(CurrParsedText.ProcessedText)]);
end;

function New_Font_GetMaxLineWidth (OrigFunc: pointer; Font: Heroes.PFontItem; Line: myPChar): integer; stdcall;
begin
  UpdateCurrParsedText(Font, Line);

  result := PatchApi.Call(THISCALL_, OrigFunc, [Font, myPChar(CurrParsedText.ProcessedText)]);
end;

function New_Font_GetMaxWordWidth (OrigFunc: pointer; Font: Heroes.PFontItem; Line: myPChar): integer; stdcall;
begin
  UpdateCurrParsedText(Font, Line);

  result := PatchApi.Call(THISCALL_, OrigFunc, [Font, myPChar(CurrParsedText.ProcessedText)]);
end;

function New_Font_GetTextWidthForBox (OrigFunc: pointer; Font: Heroes.PFontItem; Line: myPChar; BoxWidth: integer): integer; stdcall;
begin
  UpdateCurrParsedText(Font, Line);

  result := PatchApi.Call(THISCALL_, OrigFunc, [Font, myPChar(CurrParsedText.ProcessedText), BoxWidth]);
end;

function New_Font_TextToLines (OrigFunc: pointer; Font: Heroes.PFontItem; Text: myPChar; BoxWidth: integer; var DlgTextLines: Heroes.TDlgTextLines): integer; stdcall;
var
{O} Lines:   {O} TList {of TParsedTextLine};
    LineStr: myAStr;
    i:       integer;

begin
  Lines := nil;
  // * * * * * //
  UpdateCurrParsedText(Font, Text);
  Lines := CurrParsedText.ToLines(BoxWidth);
  DlgTextLines.Reset;

  for i := 0 to Lines.Count - 1 do begin
    TParsedTextLine(Lines[i]).ToTaggedText(CurrParsedText, TaggedLineBuilder);
    LineStr := TaggedLineBuilder.BuildStr();
    DlgTextLines.AppendLine(myPChar(LineStr), Length(LineStr));
  end;

  result := 0;
  // * * * * * //
  Legacy.FreeAndNil(Lines);
end; // .function New_Font_TextToLines

function ChineseGetCharColor: integer; stdcall;
begin
  result := CurrColor;
end;

procedure ChineseGotoNextChar; stdcall;
begin
  Inc(CurrBlockPos);
  UpdateCurrBlock;
end;

procedure ChineseSetTextAlignmentParamPtr (NewParamPtr: pinteger); stdcall;
begin
  CurrTextAlignPtr := NewParamPtr;
end;

procedure SetChineseGraphemWidthEstimator (Estimator: TGraphemWidthEstimator); stdcall;
begin
  ChineseGraphemWidthEstimator := Estimator;
end;

function DrawCharacterToPcx (Font: Heroes.PFontItem; Ch: integer; Canvas: Heroes.PPcx16Item; x, y: integer; ColorInd: integer): Heroes.PPcx16Item;
var
  CharWidth:       integer;
  FontHeight:      integer;
  CharPixelPtr:    pbyte;
  OutRowStartPtr:  pword;
  OutPixelPtr:     pword;
  BytesPerPixel:   integer;
  CharPixel:       integer;
  Color32:         integer;
  CurrColor32:     integer;
  ShadowColor32:   integer;
  ColorOpacity:    integer;
  i, j:            integer;
  c:               myChar;

begin
  result := Heroes.PPcx16Item(Ch); // Vanilla code. Like error marker?

  if (Ch >= 0) and (Ch <= 255) then begin
    BytesPerPixel := Heroes.BytesPerPixelPtr^;
    c             := AnsiChar(Ch);
    CharWidth     := Font.CharInfos[c].Width;
    FontHeight    := Font.Height;
    ShadowColor32 := GraphTypes.Color16To32(Font.Palette16.Colors[32]);
    CurrColor32   := CurrColor;

    if CurrColor32 = DEF_COLOR then begin
      CurrColor32 := GraphTypes.Color16To32(Font.Palette16.Colors[ColorInd]);
    end;

    if (CharWidth > 0) and (FontHeight > 0) then begin
      CurrColor32   := GraphTypes.PremultiplyColorChannelsByAlpha(CurrColor32);
      ShadowColor32 := GraphTypes.PremultiplyColorChannelsByAlpha(ShadowColor32);
      ColorOpacity  := 255 - ((CurrColor32 and GraphTypes.ALPHA_CHANNEL_MASK_32) shr 24);

      CharPixelPtr   := @Font.CharsDataPtr[Font.CharDataOffsets[c]];
      OutRowStartPtr := UtilsB2.PtrOfs(Canvas.Buffer, y * Canvas.ScanlineSize + (x + Font.CharInfos[c].SpaceBefore) * BytesPerPixel);

      for j := 0 to FontHeight - 1 do begin
        OutPixelPtr := OutRowStartPtr;

        for i := 0 to CharWidth - 1 do begin
          CharPixel := CharPixelPtr^;

          if CharPixel <> 0 then begin
            if CharPixel = 255 then begin
              Color32 := CurrColor32;
            end else begin
              Color32 := (ShadowColor32 and GraphTypes.RGB_CHANNELS_MASK_32) or (GraphTypes.ALPHA_CHANNEL_MASK_32 - ((((256 - CharPixel) * ColorOpacity) and $FF00) shl 16));
            end;

            if BytesPerPixel = sizeof(GraphTypes.TColor32) then begin
              pinteger(OutPixelPtr)^ := GraphTypes.AlphaBlend32OpaqueBackWithPremultiplied(pinteger(OutPixelPtr)^, Color32);
            end else begin
              pword(OutPixelPtr)^ := GraphTypes.Color32To16(GraphTypes.AlphaBlend32OpaqueBackWithPremultiplied(GraphTypes.Color16To32(pword(OutPixelPtr)^), Color32));
            end;
          end; // .if

          Inc(pbyte(OutPixelPtr), BytesPerPixel);
          Inc(CharPixelPtr);
        end; // .for

        Inc(pbyte(OutRowStartPtr), Canvas.ScanlineSize);
      end; // .for
    end; // .if

    result := Canvas;
  end; // .if
end; // .function DrawCharacterToPcx

function New_Font_DrawCharacter (OrigFunc: pointer; Font: Heroes.PFontItem; Ch: integer; Canvas: Heroes.PPcx16Item; x, y: integer; ColorInd: integer): Heroes.PPcx16Item; stdcall;
var
  Def: Heroes.PDefItem;

begin
  if (CurrParsedText <> nil) and (CurrTextBlock <> nil) and (CurrTextBlock.BlockType = TEXT_BLOCK_DEF) and (CurrTextBlock.DefBlock.Def <> nil) then begin
    Def := CurrTextBlock.DefBlock.Def;

    if CurrBlockPos = 0 then begin
      Graph.DrawInterfaceDefFrameEx(
        Def,
        CurrTextBlock.DefBlock.GroupInd,
        CurrTextBlock.DefBlock.FrameInd,
        0,
        CurrTextBlock.ImgBlock.SliceStartY,
        GraphTypes.MAX_IMAGE_WIDTH,
        CurrTextBlock.ImgBlock.SliceHeight,
        Canvas.Buffer,
        x + CurrTextBlock.ImgBlock.OffsetX, y + CurrTextBlock.ImgBlock.OffsetY,
        Canvas.Width, Canvas.Height,
        Canvas.ScanlineSize,
        CurrTextBlock.ImgBlock.DrawFlags
      );
    end;

    result := Canvas;
  end else begin
    result := DrawCharacterToPcx(Font, Ch, Canvas, x, y, ColorInd);
  end;
end; // .function New_Font_DrawCharacter

function New_Pcx16_FillRect (OrigFunc: pointer; Canvas: Heroes.PPcx16Item; x, y, Width, Height, FillColor16: integer): integer; stdcall;
const
  MAGIC_COLOR = $1;

var
  BytesPerPixel:  integer;
  Color32:        integer;
  OutPixelPtr:    pinteger;
  OutRowStartPtr: pinteger;
  i, j:           integer;

begin
  BytesPerPixel := Heroes.BytesPerPixelPtr^;

  if BytesPerPixel = sizeof(GraphTypes.TColor16) then begin
    result := PatchApi.Call(THISCALL_, OrigFunc, [Canvas, x, y, Width, Height, FillColor16]);
  end else begin
    result := Height;

    if x < 0 then begin
      x := 0;
      Inc(Width, x);
    end;

    if y < 0 then begin
      y := 0;
      Inc(Height, y);
    end;

    Width  := Min(Canvas.Width - x, Width);
    Height := Min(Canvas.Height - y, Height);

    if (x >= Canvas.Width) or (y >= Canvas.Height) or (Width <= 0) or (Height <= 0) then begin
      exit;
    end;

    if FillColor16 = MAGIC_COLOR then begin
      Color32 := MAGIC_COLOR;
    end else begin
      Color32 := GraphTypes.Color16To32(FillColor16);
    end;

    OutRowStartPtr := UtilsB2.PtrOfs(Canvas.Buffer, y * Canvas.ScanlineSize + x * BytesPerPixel);

    for j := y to y + Height - 1 do begin
      OutPixelPtr := OutRowStartPtr;

      for i := x to x + Width - 1 do begin
        OutPixelPtr^ := Color32;
        Inc(OutPixelPtr);
      end;

      Inc(pbyte(OutRowStartPtr), Canvas.ScanlineSize);
    end;
  end; // .else
end; // .function New_Pcx16_FillRect

procedure OnAfterCreateWindow (Event: GameExt.PEvent); stdcall;
begin
  NameStdColors;

  ApiJack.StdSplice(Ptr($4B4F00), @New_Font_DrawCharacter, ApiJack.CONV_THISCALL, 6);
  ApiJack.StdSplice(Ptr($44E190), @New_Pcx16_FillRect, ApiJack.CONV_THISCALL, 6);
end;

procedure OnAfterWoG (Event: GameExt.PEvent); stdcall;
begin
  ChineseLoaderOpt := IsChineseLoaderPresent(ChineseHandler);

  if ChineseLoaderOpt then begin
    (* Remove Chinese loader hook *)
    pword($4B5202)^    := word($840F); // JE
    pinteger($4B5204)^ := $02E7;       // 4B54EF
  end else begin
    Core.Hook(@Hook_HandleTags, Core.HOOKTYPE_BRIDGE, 7, Ptr($4B509B));
  end;

  Core.Hook(@Hook_GetCharColor, Core.HOOKTYPE_BRIDGE, 8, Ptr($4B4F74));
  Core.Hook(@Hook_BeginParseText, Core.HOOKTYPE_BRIDGE, 6, Ptr($4B5255));
  Core.Hook(@Hook_CountNumTextLines, Core.HOOKTYPE_CALL, 5, Ptr($4B5275));
  Core.Hook(@Hook_CountNumTextLines, Core.HOOKTYPE_CALL, 5, Ptr($4B52CA));
  Core.Hook(@Hook_ScrollTextDlg_CreateLineTextItem, Core.HOOKTYPE_CALL, 5, Ptr($5BA547));
  ApiJack.HookCode(Ptr($4B547B), @Hook_Font_DrawTextToPcx16_DetermineLineAlignment);
  ApiJack.HookCode(Ptr($4B54EF), @Hook_Font_DrawTextToPcx16_End);
  ApiJack.StdSplice(Ptr($4B5680), @New_Font_GetLineWidth, ApiJack.CONV_THISCALL, 2);
  ApiJack.StdSplice(Ptr($4B5580), @New_Font_CountNumTextLines, ApiJack.CONV_THISCALL, 3);
  ApiJack.StdSplice(Ptr($4B56F0), @New_Font_GetMaxLineWidth, ApiJack.CONV_THISCALL, 2);
  ApiJack.StdSplice(Ptr($4B5770), @New_Font_GetMaxWordWidth, ApiJack.CONV_THISCALL, 2);
  ApiJack.StdSplice(Ptr($4B57E0), @New_Font_GetTextWidthForBox, ApiJack.CONV_THISCALL, 3);
  ApiJack.StdSplice(Ptr($4B58F0), @New_Font_TextToLines, ApiJack.CONV_THISCALL, 4);

  // Fix TransformInputKey routine to allow entering "{" and "}"
  Core.p.WriteDataPatch(Ptr($5BAFB5), [myAStr('EB08')]);
end; // .procedure OnAfterWoG

begin
  NamedColors       := AssocArrays.NewSimpleAssocArr(Crypto.AnsiCrc32, Legacy.AnsiLowerCase);
  LoadedResources   := DataLib.NewDict(not UtilsB2.OWNS_ITEMS, DataLib.CASE_INSENSITIVE);
  TextAttrsStack    := Lists.NewSimpleList;
  TextScanner       := TextScan.TTextScanner.Create;
  TaggedLineBuilder := StrLib.TStrBuilder.Create;

  EventMan.GetInstance.On('OnAfterWoG',          OnAfterWoG);
  EventMan.GetInstance.On('OnAfterCreateWindow', OnAfterCreateWindow);
end.
