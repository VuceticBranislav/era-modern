unit WogDialogs;
(*
  Handy bridges to WoG (Native) dialogs.
*)


(***)  interface  (***)

uses
  Math,
  SysUtils,

  //PngImage,

  ApiJack,
  Core,
  DataLib,
  DlgMes,
  EventMan,
  Files,
  GameExt,
  Heroes,
  PatchApi,
  StrLib,
  WinUtils,
  ZlibUtils,
  UtilsB2, Legacy;


const
  MAX_OPTIONS_DLG_ITEMS = 12;


function ShowRadioDlg (const Title: myAStr; const Items: array of myAStr; SelectedItemIndex: integer = 0): integer;


(***)  implementation  (***)


type
  POptionsDlgItems = ^TOptionsDlgItems;
  TOptionsDlgItems = array [0..MAX_OPTIONS_DLG_ITEMS - 1] of myPChar;


var
  ZvsMultiCheckReq: function (Title: myPChar; StateMask: integer; Items: POptionsDlgItems; IsRadio: integer): integer cdecl = Ptr($772FED);


(*
  Displays radio dialog with up to 12 items. Returns selected item index.
*)
function ShowRadioDlg (const Title: myAStr; const Items: array of myAStr; SelectedItemIndex: integer = 0): integer;
var
  DlgItems:  TOptionsDlgItems;
  NumItems:  integer;
  ResultBit: integer;
  i:         integer;

begin
  result   := 0;
  NumItems := Math.Min(Length(DlgItems), Length(Items));

  if NumItems = 0 then begin
    exit;
  end;

  Legacy.FillChar(DlgItems, sizeof(DlgItems), #0);

  for i := 0 to NumItems - 1 do begin
    if Items[i] = '' then begin
      DlgItems[i] := ' ';
    end else begin
      DlgItems[i] := myPChar(Items[i]);
    end;
  end;

  if (SelectedItemIndex < Low(DlgItems)) or (SelectedItemIndex > High(DlgItems)) then begin
    SelectedItemIndex := 0;
  end;

  ResultBit := ZvsMultiCheckReq(myPChar(Title), 1 shl SelectedItemIndex, @DlgItems, ord(true));
  result    := -1;

  while (ResultBit <> 0) do begin
    ResultBit := ResultBit shr 1;
    Inc(result);
  end;
end;

end.
