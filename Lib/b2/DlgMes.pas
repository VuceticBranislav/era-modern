unit DlgMes;
{
DESCRIPTION:  Simple dialogs for messages and debugging
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
uses Legacy, Windows, SysUtils, Math, UtilsB2, StrLib, Lang, DlgMesLng;

const
  NO_WINDOW = 0;

  (* Icons *)
  NO_ICON       = Windows.MB_OK;
  ICON_ERROR    = Windows.MB_ICONSTOP;
  ICON_QUESTION = Windows.MB_ICONQUESTION;

  (* Ask results *)
  YES = TRUE;
  NO  = FALSE;

  ID_YES    = 0;
  ID_NO     = 1;
  ID_CANCEL = 2;


var
  hParentWindow:  integer = NO_WINDOW;
  DialogsTitle:   myAStr;


procedure MsgEx (const Msg, Title: myAStr; Icon: integer);
procedure MsgTitle (const Msg, Title: myAStr);
procedure Msg (const Msg: myAStr);
procedure MsgError(const Err: myAStr);
procedure OK;
function  AskYesNo (const Question: myAStr): boolean;
function  AskYesNoCancel (const Question: myAStr): integer;
function  AskOkCancel (const Question: myAStr): boolean;
function  VarToString (const VarRec: TVarRec): myAStr;
function  ToString (const Vars: array of const): myAStr;
function  PArrItemToString (var PArrItem: pointer; VarType: integer): myAStr;
function  PVarToString (PVar: pointer; VarType: integer): myAStr;
procedure VarDump (const Vars: array of const; const Title: myAStr = 'VAR DUMP');
procedure ArrDump
(
  const Arr:        pointer;
        Count:      integer;
  const ElemsType:  integer;
  const Title:      myAStr
);


(***)  implementation  (***)


var
{OU}  Lng:  DlgMesLng.PLangStringsArr;


procedure MsgEx (const Msg, Title: myAStr; Icon: integer);
begin
  Windows.MessageBoxA(hParentWindow, myPChar(Msg), myPChar(Title), Icon);
end;

procedure MsgTitle (const Msg, Title: myAStr);
begin
  MsgEx(Msg, Title, NO_ICON);
end;

procedure Msg (const Msg: myAStr);
begin
  MsgEx(Msg, DialogsTitle, NO_ICON);
end;

procedure MsgError(const Err: myAStr);
begin
  MsgEx(Err, DialogsTitle, ICON_ERROR);
end;

procedure OK;
begin
  Msg('OK');
end;

function AskYesNo (const Question: myAStr): boolean;
begin
  result  :=  NO;

  if
    Windows.MessageBoxA
    (
      hParentWindow,
      myPChar(Question),
      myPChar(Lng[STR_QUESTION]),
      Windows.MB_YESNO + ICON_QUESTION
    ) = Windows.ID_YES
  then begin
    result  :=  YES;
  end; // .if
end; // .function AskYesNo

function AskOkCancel (const Question: myAStr): boolean;
begin
  result  :=  NO;

  if Windows.MessageBoxA
  (
    hParentWindow,
    myPChar(Question),
    myPChar(Lng[STR_QUESTION]),
    Windows.MB_OKCANCEL + ICON_QUESTION
  ) = Windows.ID_OK
  then begin
    result  :=  YES;
  end;
end; // .function AskOkCancel

function AskYesNoCancel (const Question: myAStr): integer;
begin
  result  :=  0;

  case
    Windows.MessageBoxA
    (
      hParentWindow,
      myPChar(Question),
      myPChar(Lng[STR_QUESTION]),
      Windows.MB_YESNOCANCEL + ICON_QUESTION
    )
  of
    Windows.IDYES:      result  :=  ID_YES;
    Windows.IDNO:       result  :=  ID_NO;
    Windows.ID_CANCEL:  result  :=  ID_CANCEL;
  end; // .SWITCH
end; // .function AskYesNoCancel

function VarToString (const VarRec: TVarRec): myAStr;
begin
  case VarRec.vType of
    vtBoolean:
      begin
        if VarRec.vBoolean then begin
          result  :=  'boolean: TRUE';
        end else begin
          result  :=  'boolean: FALSE';
        end;
      end; // .case vtBoolean
    vtInteger:    result  :=  myAStr('integer: ' + Legacy.IntToStr(VarRec.vInteger));
    vtChar:       result  :=  myAStr('char: ' + VarRec.vChar);
    vtWideChar:   result  :=  myAStr('WIDECHAR: ' + VarRec.vWideChar);
    vtExtended:   result  :=  myAStr('REAL: ' + Legacy.FloatToStr(VarRec.vExtended^));
    vtString:     result  :=  myAStr('string: ' + VarRec.vString^);
    vtPointer:    result  :=  myAStr('pointer: $' + Legacy.Format('%x',[integer(VarRec.vPointer)]));
    vtPChar:      result  :=  myAStr('pchar: ' + VarRec.vPChar);
    vtPWideChar:  result  :=  myAStr('PWIDECHAR: ' + VarRec.vPWideChar);

    vtObject: begin
      if VarRec.vObject <> nil then begin
        result := myAStr('object: ' + VarRec.vObject.ClassName);
      end else begin
        result := myAStr('object: nil');
      end;
    end;

    vtClass:      result  :=  myAStr('class: ' + VarRec.vClass.ClassName);
    vtCurrency:   result  :=  myAStr('currency: ' + Legacy.CurrToStr(VarRec.vCurrency^));
    vtAnsiString: result  :=  myAStr('ANSISTRING: ' + myAStr(VarRec.vAnsiString));
    vtWideString: result  :=  myAStr('WIDESTRING: ' + myWStr(VarRec.vWideString));
    vtVariant:    result  :=  myAStr('VARIANT: ' + myAStr(VarRec.vVariant));
    vtInterface:  result  :=  myAStr('interface: $' + Legacy.Format('%x',[integer(VarRec.vInterface)]));
    vtInt64:      result  :=  myAStr('INT64: ' + Legacy.IntToStr(VarRec.vInt64^));
  else
    result  :=  'UNKNOWN:';
  end; // .SWITCH VarRec.vType
end; // .function VarToString

function ToString (const Vars: array of const): myAStr;
var
  ResArr: UtilsB2.TArrayOfStr;
  i:      integer;

begin
  SetLength(ResArr, Length(Vars));

  for i := 0 to High(Vars) do begin
    ResArr[i] := VarToString(Vars[i]);
  end;

  result := StrLib.Join(ResArr, #13#10);
end; // .function ToString

function PArrItemToString (var PArrItem: pointer; VarType: integer): myAStr;
var
  VarRec: TVarRec;

begin
  {!} Assert(Math.InRange(VarType, 0, vtInt64));
  VarRec.vType  :=  VarType;

  case VarType of
    vtBoolean:    begin VarRec.vBoolean     :=  PBOOLEAN(PArrItem)^; Inc(PBOOLEAN(PArrItem)); end;
    vtInteger:    begin VarRec.vInteger     :=  PINTEGER(PArrItem)^; Inc(PINTEGER(PArrItem)); end;
    vtChar:       begin VarRec.vChar        :=  myPChar(PArrItem)^; Inc(myPChar(PArrItem)); end;
    vtWideChar:   begin VarRec.vWideChar    :=  myPWChar(PArrItem)^; Inc(myPWChar(PArrItem)); end;
    vtExtended:   begin VarRec.vExtended    :=  PArrItem; Inc(PEXTENDED(PArrItem)); end;
    vtString:     begin VarRec.vString      :=  PArrItem; Inc(PShortString(PArrItem)); end;
    vtPointer:    begin VarRec.vPointer     :=  PPOINTER(PArrItem)^; Inc(PPOINTER(PArrItem)); end;
    vtPChar:      begin VarRec.vPChar       :=  myPPChar(PArrItem)^; Inc(myPPChar(PArrItem)); end;
    vtPWideChar:
      begin
                        VarRec.vPWideChar   :=  PPWideChar(PArrItem)^; Inc(PPWideChar(PArrItem));
      end;
    vtObject:     begin VarRec.vObject      :=  pobject(PArrItem)^; Inc(pobject(PArrItem)); end;
    vtClass:      begin VarRec.vClass       :=  pclass(PArrItem)^; Inc(pclass(PArrItem)); end;
    vtCurrency:   begin VarRec.vCurrency    :=  PArrItem; Inc(PCURRENCY(PArrItem)); end;
    vtAnsiString: begin VarRec.vAnsiString  :=  PPOINTER(PArrItem)^; Inc(PPOINTER(PArrItem)); end;
    vtWideString: begin VarRec.vWideString  :=  PPOINTER(PArrItem)^; Inc(PPOINTER(PArrItem)); end;
    vtVariant:    begin VarRec.vVariant     :=  PArrItem; Inc(PVARIANT(PArrItem)); end;
    vtInterface:  begin VarRec.vInterface   :=  PPOINTER(PArrItem)^; Inc(PPOINTER(PArrItem)); end;
    vtInt64:      begin VarRec.vInt64       :=  PArrItem; Inc(PINT64(PArrItem)); end;
  end; // .case PArrItem.vType
  result  :=  VarToString(VarRec);
end; // .function PArrItemToString

function PVarToString (PVar: pointer; VarType: integer): myAStr;
var
{U} Temp: pointer;

begin
  {!} Assert(Math.InRange(VarType, 0, vtInt64));
  Temp  :=  PVar;
  // * * * * * //
  result  :=  PArrItemToString(Temp, VarType);
end;

procedure VarDump (const Vars: array of const; const Title: myAStr);
begin
  MsgTitle(ToString(Vars), Title);
end;

procedure ArrDump
(
  const Arr:        pointer;
        Count:      integer;
  const ElemsType:  integer;
  const Title:      myAStr
);

const
  NUM_ITEMS_PER_DISPLAY = 20;

var
{U} CurrItem:           pointer;
    CurrItemInd:        integer;
    StrArr:             UtilsB2.TArrayOfStr;
    DisplayN:           integer;
    NumItemsToDisplay:  integer;
    i:                  integer;

begin
  CurrItemInd :=  0;
  CurrItem    :=  Arr;

  for DisplayN := 1 to Math.Ceil(Count / NUM_ITEMS_PER_DISPLAY) do begin
    NumItemsToDisplay :=  Math.Min(Count - CurrItemInd, NUM_ITEMS_PER_DISPLAY);
    SetLength(StrArr, NumItemsToDisplay);

    for i := 0 to NumItemsToDisplay - 1 do begin
      StrArr[i] :=  '[' + Legacy.IntToStr(i) + ']: ' + PArrItemToString(CurrItem, ElemsType);
    end;

    MsgTitle(StrLib.Join(StrArr, #13#10), Title);
  end;
end; // .procedure ArrDump

begin
  Lng :=  @DlgMesLng.Strs;
  Lang.RegisterClient
  (
    'DlgMes',
    Lang.ENG,
    Lang.IS_ANSI,
    ORD(High(DlgMesLng.TLangStrings)) + 1,
    @Lng,
    Lng
  );
end.
