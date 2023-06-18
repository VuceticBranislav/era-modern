unit ConsoleAPI;
{!INFO
NAME = 'Console API'
VERSION = '1.0'
AUTHOR = 'Berserker'
}

interface
uses Windows, SysUtils, Legacy;

type
  PWin32Cell = ^TWin32Cell;
  TWin32Cell = packed record
    Ch:     word;
    Attr:   word;
  end;

  TMenu = record
    Count: integer;
    Start: myPAStr;
    Interval: integer;
  end; // .record TMenu

  PMenu = ^TMenu;

  TConsoleBuffer = record
    Width, Height: integer;
  end; // .record TConsoleBuffer

  TCodePage = (cp1251, cp866);

  TConsole = class
    {*} protected {*}
    fWidth: integer;
    fHeight: integer;
    fBufWidth: integer;
    fBufHeight: integer;
    fTitle: myAStr;
    fColor: byte;
    fBack: byte;
    TIR: TInputRecord;
    {*} public {*}
    { FIELDS }
    hIn, hOut: integer;
    hWnd: integer;
    CodePage: TCodePage;
    { PROCEDURES }
    procedure SetWindowSize(NewWidth, NewHeight: integer);
    procedure SetWidth(NewWidth: integer);
    procedure SetHeight(NewHeight: integer);
    procedure SetBufferSize(NewWidth, NewHeight: integer);
    procedure SetBufferWidth(NewWidth: integer);
    procedure SetBufferHeight(NewHeight: integer);
    function  GetTitle: myAStr;
    procedure SetTitle(NewTitle: myAStr);
    procedure SetColors(NewColor, NewBack: byte);
    procedure SetColor(NewColor: byte);
    procedure SetBack(NewBack: byte);
    procedure Clear;
    procedure GotoXY(x,y: integer);
    procedure GotoX(x: integer);
    procedure GotoY(y: integer);
    function  WhereX: integer;
    function  WhereY: integer;
    procedure SetWindowPos(x,y: integer);
    procedure MoveWindow(dx, dy: integer);
    procedure Center;
    procedure WriteC(Attr: byte; Txt: myAStr);
    procedure Print(const Txt: myAStr);
    procedure SetCodePage(NewCodePage: integer);
    function ReadKey: myChar;
    function ReadCode: myChar;
    function Read: myAStr;
    procedure HideArea(x1, y1, x2, y2: integer; col, back: byte);
    function Menu(TitleCol, TitleBack, ItemCol, ItemBack, ChosenCol, ChosenBack,
                          FooterCol, FooterBack: byte;
                          const Title: myAStr; const Footer: myAStr; Items: PMenu): integer;
    constructor Create(const Title: myAStr; WinWidth, WinHeight, BufWidth, BufHeight: integer);
    { PROPERTIES }
    property Width: integer read fWidth write SetWidth;
    property Height: integer read fHeight write SetHeight;
    property BufWidth: integer read fBufWidth write SetBufferWidth;
    property BufHeight: integer read fBufHeight write SetBufferHeight;
    property Title: myAStr read GetTitle write SetTitle;
    property Color: byte read fColor write SetColor;
    property Back: byte read fBack write SetBack;
    property CurX: integer read WhereX write GotoX;
    property CurY: integer read WhereY write GotoY;
  end; // .class TConsole

  function GetConsole (const Title: myAStr = ''; WinWidth: integer = 120; WinHeight: integer = 50; BufWidth: integer = 120; BufHeight: integer = 1000): TConsole;


(***)  implementation  (***)


var
{On} Console: TConsole;


function PackColors(col, back: byte): byte;inline;
begin
  result:=(back shl 4) or col;
end;

procedure TConsole.SetWindowSize(NewWidth, NewHeight: integer);
var
  sr: TSmallRect;

begin
  fWidth:=NewWidth;
  fHeight:=NewHeight;
  sr.Left:=0;
  sr.Top:=0;
  sr.Right:=NewWidth-1;
  sr.Bottom:=NewHeight-1;
  SetConsoleWindowInfo(hOut, TRUE, sr);
end; // .procedure TConsole.SetWindowSize

procedure TConsole.SetWidth(NewWidth: integer);
begin
  fWidth:=NewWidth;
  SetWindowSize(NewWidth, Height);
end;

procedure TConsole.SetHeight(NewHeight: integer);
begin
  fHeight:=NewHeight;
  SetWindowSize(Width, NewHeight);
end;

procedure TConsole.SetBufferSize(NewWidth, NewHeight: integer);
var
  tc: TCoord;

begin
  fBufWidth:=NewWidth;
  fBufHeight:=NewHeight;
  tc.x:=NewWidth;
  tc.y:=NewHeight;
  SetConsoleScreenBufferSize(hOut, tc);
end; // .procedure TConsole.SetBufferSize

procedure TConsole.SetBufferWidth(NewWidth: integer);
begin
  fBufWidth:=NewWidth;
  SetBufferSize(NewWidth, BufHeight);
end;

procedure TConsole.SetBufferHeight(NewHeight: integer);
begin
  fBufHeight:=NewHeight;
  SetBufferSize(BufWidth, NewHeight);
end;

function TConsole.GetTitle: myAStr;
var
  NewTitle: myAStr;
  C: myChar;

begin
  NewTitle:=fTitle;
  if CodePage=cp1251 then begin
    C:=NewTitle[1];
    NewTitle[1]:=C;
    OEMToCharBuff(@NewTitle[1], @NewTitle[1], Length(NewTitle));
  end;
  result:=NewTitle;
end; // .procedure TConsole.GetTitle

procedure TConsole.SetTitle(NewTitle: myAStr);
begin
  if NewTitle='' then Exit;
  fTitle:=NewTitle;
  if CodePage=cp1251 then CharToOEMBuff(@NewTitle[1], @NewTitle[1], Length(NewTitle));
  Windows.SetConsoleTitleA(@fTitle[1]);
end;

procedure TConsole.SetColors(NewColor, NewBack: byte);
begin
  fColor:=NewColor;
  fBack:=NewBack;
  SetConsoleTextAttribute(hOut, PackColors(NewColor, NewBack));
end;

procedure TConsole.SetColor(NewColor: byte);
begin
  fColor:=NewColor;
  SetColors(NewColor, Back);
end;

procedure TConsole.SetBack(NewBack: byte);
begin
  fBack:=NewBack;
  SetColors(Color, NewBack);
end;

procedure TConsole.Clear;
var
  sr: TSmallRect;
  c: TWin32Cell;
  cr: TCoord;

begin
  sr.Left:=0;
  sr.Top:=0;
  sr.Right:=BufWidth-1;
  sr.Bottom:=BufHeight-1;
  c.Ch:=32;
  c.Attr:=PackColors(Color, Back);
  cr.x:=0;
  cr.y:=BufHeight;
  ScrollConsoleScreenBuffer(hOut, sr, @sr, cr, TCharInfo(c));
  GotoXY(0,0);
end; // .procedure TConsole.Clear

procedure TConsole.GotoXY(x, y: integer);
var
  pos: TCoord;

begin
  pos.x:=x;
  pos.y:=y;
  SetConsoleCursorPosition(hOut, pos);
end;

procedure TConsole.GotoX(x: integer);
begin
  GotoXY(x, CurY);
end;

procedure TConsole.GotoY(y: integer);
begin
  GotoXY(CurX, y);
end;

function TConsole.WhereX: integer;
var
  info: TConsoleScreenBufferInfo;

begin
  GetConsoleScreenBufferInfo(hOut, info);
  result:=info.dwCursorPosition.x;
end;

function TConsole.WhereY: integer;
var
  info: TConsoleScreenBufferInfo;

begin
  GetConsoleScreenBufferInfo(hOut, info);
  result:=info.dwCursorPosition.y;
end;

function GetConsoleWindow: integer; external 'kernel32.dll' name 'GetConsoleWindow';

procedure TConsole.SetWindowPos(x, y: integer);
var
  r: TRect;

begin
  GetWindowRect(hWnd, r);
  Windows.MoveWindow(hWnd, x, y, r.Right-r.Left+1, r.Bottom-r.Top+1, TRUE);
end;

procedure TConsole.MoveWindow(dx, dy: integer);
var
  r: TRect;

begin
  GetWindowRect(hWnd, r);
  Windows.MoveWindow(hWnd, r.Left+dx, r.Top+dy, r.Right-r.Left+1, r.Bottom-r.Top+1, TRUE);
end;

procedure TConsole.Center;
var
  r: TRect;
  w, h, x, y: integer;

begin
  GetWindowRect(hWnd, r);
  w:=r.Right-r.Left+1;
  h:=r.Bottom-r.Top+1;
  GetWindowRect(GetDesktopWindow, r);
  x:=(r.Right-r.Left-w) div 2;
  y:=(r.Bottom-r.Top-h) div 2;
  if y<0 then y:=0;
  if (x>0) then Windows.MoveWindow(hWnd, x, y, w, h, TRUE);
end; // .procedure TConsole.Center

procedure TConsole.WriteC(Attr: byte; Txt: myAStr);
var
  col: byte;

begin
  col:=Color;
  SetColors(Attr and $0F, (Attr and $F0) shr 4);
  if CodePage=cp1251 then begin
    CharToOEMBuff(@Txt[1], @Txt[1], Length(Txt));
    Write(Txt);
    OEMToCharBuff(@Txt[1], @Txt[1], Length(Txt));
  end // .if
  else begin
    Write(Txt);
  end;
  Color:=col;
end; // .procedure TConsole.WriteC

procedure TConsole.Print(const Txt: myAStr);
begin
  if CodePage=cp1251 then begin
    CharToOEMBuff(@Txt[1], @Txt[1], Length(Txt));
    Write(Txt);
    OEMToCharBuff(@Txt[1], @Txt[1], Length(Txt));
  end // .if
  else begin
    Write(Txt);
  end;
end; // .procedure TConsole.Print

procedure TConsole.SetCodePage(NewCodePage: integer);
begin
  CodePage:=TCodePage(NewCodePage);
end;

function TConsole.ReadKey: myChar;
var
  Temp: integer;

begin
  repeat
    Windows.ReadConsoleInput(hIn, TIR, 1, DWORD(Temp));
  until ((TIR.EventType and 1)=1) and TIR.Event.KeyEvent.bKeyDown;
  result:=TIR.Event.KeyEvent.AsciiChar;
end;

function TConsole.ReadCode: myChar;
begin
  result:=myChar(byte(TIR.Event.KeyEvent.wVirtualScanCode));
end;

function TConsole.Read: myAStr;
var
  s: myAStr;
  temp: integer;

begin
  SetLength(s, 256);
  Windows.ReadFile(hIn, s[1], 256, DWORD(temp), nil);
  SetLength(s, temp);
  result:=s;
end; // .function Read

procedure TConsole.HideArea(x1, y1, x2, y2: integer; col, back: byte);
var
  tc: TCoord;
  temp: integer;

begin
  tc.x:=x1;
  tc.y:=y1;
  FillConsoleOutputAttribute(hOut, PackColors(col, back), (y2-y1+1)*(Width)-x1, tc, DWORD(temp));
end;

function TConsole.Menu(TitleCol, TitleBack, ItemCol, ItemBack, ChosenCol, ChosenBack, FooterCol, FooterBack: byte;
                      const Title: myAStr; const Footer: myAStr; Items: PMenu): integer;

const
  C_ERROR_TOO_LARGE = -2;
  C_ESC = -1;

var
  Count: integer; // Number of menu items
  X, Y: integer;  // Top border of the first menu item
  index: integer;
  bExit: boolean;
  i: integer;
  C: myChar;
  Chosen: integer;
  P: pointer;
  Interval: integer;

begin
  // Determine whether menu will fit on the screen, if not, do not display it
  Count:=Items^.Count;
  P:=Items^.Start;
  Interval:=Items^.Interval;
  if (Height-CurY-Count-2)<0 then begin
    result:=C_ERROR_TOO_LARGE; exit;
  end;
  X:=CurX;
  WriteC(PackColors(TitleCol, TitleBack), Title); GotoXY(X, CurY+1);
  Y:=CurY;
  index:=0;
  bExit:=FALSE;
  Chosen := -1;

  while not bExit do begin
    // Render cycle
    GotoXY(X, Y);
    for i:=0 to Count-1 do begin
      if i=index then begin
        WriteC(PackColors(ChosenCol, ChosenBack), myPAStr(integer(P)+i*Interval)^); GotoXY(X, Y+i+1);
      end // .if
      else begin
        WriteC(PackColors(ItemCol, ItemBack), myPAStr(integer(P)+i*Interval)^); GotoXY(X, Y+i+1);
      end;
    end;

    WriteC(PackColors(FooterCol, FooterBack), Footer);
    // Keyboard read cycle
    while TRUE do begin
      C:=ReadKey;
      case C of
        #13:
          begin
            Chosen:=index;
            bExit:=TRUE;
            BREAK;
          end;
        #27:
          begin
            Chosen:=-1;
            bExit:=TRUE;
            BREAK;
          end;
        #0:
          begin
            C:=ReadCode;
            case C of
              #72:
                begin
                  Dec(index);
                  if index<0 then begin
                    index:=Count-1;
                  end;
                  BREAK;
                end;
              #80:
                begin
                  Inc(index);
                  if index=Count then begin
                    index:=0;
                  end;
                  BREAK;
                end;
            end; // .case
          end;
      end; // .case C
    end; // .while
  end; // .while
  // Clear screen from menu and restore cursor position
  Dec(Y);
  HideArea(X, Y, Width-1, Y+Count+1, Self.Back, Self.Back);
  GotoXY(X, Y);
  result:=Chosen;
end; // .function Menu

function console_handler( dwCtrlType: dword ): BOOL; stdcall;
begin
  // Avoid console terminating problems
  if ( dwCtrlType in [CTRL_C_EVENT, CTRL_BREAK_EVENT, CTRL_CLOSE_EVENT] ) then result := true else result := false;
end;

constructor TConsole.Create(const Title: myAStr; WinWidth, WinHeight, BufWidth, BufHeight: integer);
begin
  AllocConsole;
  hWnd               :=GetConsoleWindow;
  SetConsoleCtrlHandler(@console_handler, true);
  hIn                :=GetStdHandle(STD_INPUT_HANDLE);
  hOut               :=GetStdHandle(STD_OUTPUT_HANDLE);
  PInteger(@Input)^  :=hIn;
  PInteger(@Output)^ :=hOut;
  CodePage           :=cp1251;
  Self.Title         :=Title;
  SetBufferSize(BufWidth, BufHeight);
  SetWindowSize(WinWidth, WinHeight);
  SetColors(15, 0);
  Windows.ShowWindow(hWnd, SW_NORMAL);
end; // .constructor TConsole.Create

function GetConsole (const Title: myAStr = ''; WinWidth: integer = 120; WinHeight: integer = 50; BufWidth: integer = 120; BufHeight: integer = 1000): TConsole;
begin
  if Console = nil then begin
    Console := TConsole.Create(Title, WinWidth, WinHeight, BufWidth, BufHeight);
  end;

  result := Console;
end;

function c (): TConsole;
begin
  result := GetConsole();
end;

begin
end.
