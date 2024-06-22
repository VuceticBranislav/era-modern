unit WinUtils;

interface
uses
  Windows, Legacy;

const
  OWNS_BUF    = true;
  HIDE_CURSOR = true;

  WAIT_ALL           = true;
  WAIT_SINGLE_OBJECT = not WAIT_ALL;

type
  PBgraPix = ^TBgraPix;
  TBgraPix = packed record
    case boolean of
      false: (Value: integer);
      true:
      (
        Blue:  byte;
        Green: byte;
        Red:   byte;
        Alpha: byte;
      );
  end; // .record TBgraPix

  PBgraBuf = ^TBgraBuf;
  TBgraBuf = array [0..MAXLONGINT div sizeof(TBgraPix) - 1] of TBgraPix;

  TRawImage = class
   protected
         fWidth:   integer;
         fHeight:  integer;
    {?n} fBuf:     PBgraBuf;
         fOwnsBuf: boolean;

   public
    constructor Create({?} aBuf: PBgraBuf; aOwnsBuf: boolean; aWidth, aHeight: integer);
    destructor  Destroy; override;

    property Buf:    {?} PBgraBuf read fBuf;
    property Width:  integer read fWidth;
    property Height: integer read fHeight;
  end; // .class TRawImage

  TExceptionHandler = function (ExceptionPtrs: Windows.TExceptionPointers): integer;
  TWaitResult = (WR_WAITED, WR_ABANDONED_MUTEX, WR_TIMEOUT, WR_FAILED, WR_UNKNOWN);

function IsValidHandle (Handle: THandle): boolean; inline;
function GetCursorLocalPos (Wnd: Windows.HWND): Windows.TPoint;
function TakeScreenshot (hWnd: THandle; HideCursor: boolean; out Res: TRawImage): boolean;
function GetExePath: myWStr;
function CaptureClientAreaScreenshot (Wnd: HWND; out Res: TRawImage): boolean;
function GetCurrentDirW: myWStr;
function SetCurrentDirW (const DirPath: myWStr): boolean;
function GetLongPathNameW (lpszShortPath, lpszLongPath: myPWChar; cchBuffer: integer): integer; stdcall; external kernel32;
function GetLongPathW (const FilePath: myWStr; Success: pboolean = nil): myWStr;
function GetComputerNameW: myWStr;
function WaitForObjects (Objects: array of THandle; out ResObject: THandle; TimeoutMsec: integer = integer(INFINITE); WaitAll: boolean = false): TWaitResult;
function AddVectoredExceptionHandler (First: LONGBOOL; Handler: TExceptionHandler): Windows.THandle; stdcall; external 'kernel32.dll';

(* Returns UTC time in msec since Jan 1, 1970 *)
function GetMicroTime: Int64;

(* Returns UTC time in seconds since Jan 1, 1970 *)
function GetUnixTime: Int64;

(* Returns path to system directory or empty string on error *)
function GetSysDirW: myWStr;

(* Returns attributes for file at given path *)
function GetFileAttrs (const Path: myWStr; {out} var Attrs: integer): boolean;

(* Fills buffer with cryptographically safe random data *)
function RtlGenRandom (Buf: pointer; BufSize: integer): boolean; stdcall; external advapi32 name 'SystemFunction036';


(***)  implementation  (***)


uses UtilsB2, Concur;

var
  ExePathW: myWStr = '';
  ExeDirW:  myWStr = '';
  StaticCritSection: Concur.TCritSection;


function IsValidHandle (Handle: THandle): boolean; inline;
begin
  result := (Handle <> 0) and (Handle <> INVALID_HANDLE_VALUE);
end;

constructor TRawImage.Create ({?} aBuf: PBgraBuf; aOwnsBuf: boolean; aWidth, aHeight: integer);
begin
  {!} Assert(aWidth >= 0);
  {!} Assert(aHeight >= 0);
  {!} Assert(UtilsB2.IsValidBuf(aBuf, aWidth and aHeight));
  fBuf     := aBuf;
  fOwnsBuf := aOwnsBuf;
  fWidth   := aWidth;
  fHeight  := aHeight;
end; // .constructor TRawImage.Create

destructor TRawImage.Destroy;
begin
  if fOwnsBuf and (fBuf <> nil) then begin
    FreeMem(fBuf); fBuf := nil;
  end;
end; // .destructor TRawImage.Destroy

function GetCursorLocalPos (Wnd: Windows.HWND): Windows.TPoint;
var
  CursorPos: Windows.TPoint;

begin
  GetCursorPos(CursorPos);
  ScreenToClient(Wnd, CursorPos);

  result := CursorPos;
end;

procedure InitBgraBitmapInfo (var BitmapInfo: TBitmapInfo; Width, Height: integer);
const
  BITS_PER_PIXEL  = 32;
  BYTES_PER_PIXEL = BITS_PER_PIXEL div 8;

begin
  BitmapInfo.bmiHeader.biSize         := sizeof(BITMAPINFOHEADER);
  BitmapInfo.bmiHeader.biWidth        := Width;
  BitmapInfo.bmiHeader.biHeight       := -Height; // Top to bottom line scan
  BitmapInfo.bmiHeader.biPlanes       := 1;
  BitmapInfo.bmiHeader.biBitCount     := BITS_PER_PIXEL;
  BitmapInfo.bmiHeader.biCompression  := BI_RGB;
  BitmapInfo.bmiHeader.biSizeImage    := Width * Height * BYTES_PER_PIXEL;
  BitmapInfo.bmiHeader.biClrUsed      := 0;
  BitmapInfo.bmiHeader.biClrImportant := 0;
end;

function TakeScreenshot (hWnd: THandle; HideCursor: boolean; out Res: TRawImage): boolean;
var
{U} Buf:                 PBgraBuf;
    WindowDeviceContext: HDC;
    ImageDeviceContext:  HDC;
    WindowInfo:          TWindowInfo;
    ScreenWidth:         integer;
    ScreenHeight:        integer;
    VisibleRect:         TRect;
    VisibleRectWidth:    integer;
    VisibleRectHeight:   integer;
    ImageHandle:         HBITMAP;
    BitmapInfo:          TBitmapInfo;
    OldImage:            HGDIOBJ;

  function IsWndVisible: boolean;
  begin
    result := (WindowInfo.rcWindow.Right  >= 0) and (WindowInfo.rcWindow.Left < ScreenWidth) and
              (WindowInfo.rcWindow.Bottom >= 0) and (WindowInfo.rcWindow.Top  < ScreenHeight)
  end;

  procedure GetVisibleRect;
  begin
    if WindowInfo.rcWindow.Left < 0 then begin
      VisibleRect.Left := Abs(WindowInfo.rcWindow.Left);
    end else begin
      VisibleRect.Left := 0;
    end;

    VisibleRect.Right := WindowInfo.rcWindow.Right - WindowInfo.rcWindow.Left;

    if WindowInfo.rcWindow.Right >= ScreenWidth then begin
      VisibleRect.Right := VisibleRect.Right + ScreenWidth - 1 - WindowInfo.rcWindow.Right;
    end;

    if WindowInfo.rcWindow.Top < 0 then begin
      VisibleRect.Top := Abs(WindowInfo.rcWindow.Top);
    end else begin
      VisibleRect.Top := 0;
    end;

    VisibleRect.Bottom := WindowInfo.rcWindow.Bottom - WindowInfo.rcWindow.Top;

    if WindowInfo.rcWindow.Bottom >= ScreenHeight then begin
      VisibleRect.Bottom := VisibleRect.Bottom + ScreenHeight - 1 - WindowInfo.rcWindow.Bottom;
    end;
  end; // .procedure GetVisibleRect

  procedure DrawCursor;
  var
    hCursor:    HICON;
    CursorInfo: TCursorInfo;
    IconInfo:   TIconInfo;

  begin
    if not HideCursor then begin
      CursorInfo.cbSize := sizeof(CursorInfo);
      GetCursorInfo(CursorInfo);

      if true or (CursorInfo.flags = CURSOR_SHOWING) then begin
        hCursor := CopyIcon(CursorInfo.hCursor);

        if hCursor <> 0 then begin
          GetIconInfo(hCursor, IconInfo);
          DrawIcon(ImageDeviceContext,
                   CursorInfo.ptScreenPos.x - WindowInfo.rcWindow.Left - VisibleRect.Left
                     - integer(IconInfo.xHotspot),
                   CursorInfo.ptScreenPos.y - WindowInfo.rcWindow.Top - VisibleRect.Top
                     - integer(IconInfo.yHotspot),
                   CursorInfo.hCursor);
          DestroyIcon(hCursor);
        end;
      end; // .if
    end; // .if
  end; // .procedure DrawCursor

begin
  {!} Assert(Res = nil);
  Buf := nil;
  // * * * * * //
  WindowDeviceContext := GetWindowDC(hWnd);
  result              := (WindowDeviceContext <> 0) and GetWindowInfo(hWnd, WindowInfo);

  if result then begin
    ScreenWidth  := GetDeviceCaps(WindowDeviceContext, HORZRES);
    ScreenHeight := GetDeviceCaps(WindowDeviceContext, VERTRES);
    result       := IsWndVisible;

    if result then begin
      GetVisibleRect;
      VisibleRectWidth  := VisibleRect.Right  - VisibleRect.Left + 1;
      VisibleRectHeight := VisibleRect.Bottom - VisibleRect.Top  + 1;
      InitBgraBitmapInfo(BitmapInfo, VisibleRectWidth, VisibleRectHeight);
      GetMem(Buf, BitmapInfo.bmiHeader.biSizeImage);
      Res := TRawImage.Create(Buf, OWNS_BUF, VisibleRectWidth, VisibleRectHeight);

      ImageDeviceContext := CreateCompatibleDC(WindowDeviceContext);
      ImageHandle        := CreateCompatibleBitmap(WindowDeviceContext, VisibleRectWidth, VisibleRectHeight);

      OldImage := SelectObject(ImageDeviceContext, ImageHandle);
      BitBlt(ImageDeviceContext, 0, 0, VisibleRectWidth, VisibleRectHeight, WindowDeviceContext, VisibleRect.Left, VisibleRect.Top, SRCCOPY);
      ReleaseDC(hWnd, WindowDeviceContext); WindowDeviceContext := 0;
      DrawCursor;

      SelectObject(ImageDeviceContext, OldImage);
      GetDIBits(ImageDeviceContext, ImageHandle, 0, VisibleRectHeight, Buf, BitmapInfo, DIB_RGB_COLORS);

      DeleteObject(ImageHandle);
      DeleteDC(ImageDeviceContext);
    end; // .if
  end; // .if
  // * * * * * //
  if WindowDeviceContext <> 0 then begin
    ReleaseDC(hWnd, WindowDeviceContext);
  end;
end; // .function TakeScreenshot

(* Captures windows client area as bgra screenshot even if window is partially shown *)
function CaptureClientAreaScreenshot (Wnd: HWND; out Res: TRawImage): boolean;
var
{U} Buf:               PBgraBuf;
    WndDeviceContext:  HDC;
    TempDeviceContext: HDC;
    ClientRect:        TRect;
    Width:             integer;
    Height:            integer;
    OldGraphic:        HGDIOBJ;
    ScreenshotBitmap:  HBITMAP;
    BitmapInfo:        TBitmapInfo;

begin
  {!} Assert(Res = nil);
  Buf               := nil;
  WndDeviceContext  := GetDC(Wnd);
  TempDeviceContext := 0;
  OldGraphic        := 0;
  ScreenshotBitmap  := 0;
  result            := WndDeviceContext <> 0;

  if not result then begin
    exit;
  end;

  try
    GetClientRect(Wnd, &ClientRect);
    Width             := ClientRect.Right  - ClientRect.Left;
    Height            := ClientRect.Bottom - ClientRect.Top;
    TempDeviceContext := CreateCompatibleDC(WndDeviceContext);
    ScreenshotBitmap  := CreateCompatibleBitmap(WndDeviceContext, Width, Height);
    OldGraphic        := SelectObject(TempDeviceContext, ScreenshotBitmap);

    BitBlt(TempDeviceContext, 0, 0, Width, Height, WndDeviceContext, ClientRect.Left, ClientRect.Top, SRCCOPY);

    SelectObject(TempDeviceContext, OldGraphic);

    InitBgraBitmapInfo(BitmapInfo, Width, Height);
    GetMem(Buf, BitmapInfo.bmiHeader.biSizeImage);
    Res := TRawImage.Create(Buf, OWNS_BUF, Width, Height);

    GetDIBits(TempDeviceContext, ScreenshotBitmap, 0, Height, Buf, BitmapInfo, DIB_RGB_COLORS);
  finally
    if WndDeviceContext <> 0 then begin
      ReleaseDC(Wnd, WndDeviceContext);
    end;

    if TempDeviceContext <> 0 then begin
      DeleteDC(TempDeviceContext);
    end;

    if ScreenshotBitmap <> 0 then begin
      DeleteObject(ScreenshotBitmap);
    end;
  end;
end; // .function CaptureClientAreaScreenshot

function GetExePath: myWStr;
const
  MAX_UNICODE_PATH_LEN = 32768;

var
  NumCharsCopied: integer;

begin
  with StaticCritSection do begin
    Enter;

    if ExePathW = '' then begin
      SetLength(ExePathW, MAX_UNICODE_PATH_LEN - 1);
      NumCharsCopied := Windows.GetModuleFileNameW(Windows.GetModuleHandle(nil), myPWChar(ExePathW), MAX_UNICODE_PATH_LEN);

      if NumCharsCopied > 0 then begin
        SetLength(ExePathW, NumCharsCopied);
      end else begin
        ExePathW := '';
      end;
    end;

    result := ExePathW;

    Leave;
  end; // .with
end; // .function GetExePath

function GetCurrentDirW: myWStr;
var
  Buf:    array [0..32767 - 1] of myWChar;
  ResLen: integer;

begin
  result := '';
  ResLen := Windows.GetCurrentDirectoryW(sizeof(Buf), @Buf);

  if ResLen > 0 then begin
    SetLength(result, ResLen);
    UtilsB2.CopyMem(ResLen * sizeof(myWChar), @Buf, myPWChar(result));
  end;
end;

function SetCurrentDirW (const DirPath: myWStr): boolean;
begin
  result := Windows.SetCurrentDirectoryW(myPWChar(DirPath));
end;

(* Returns path as is on failure *)
function GetLongPathW (const FilePath: myWStr; Success: pboolean = nil): myWStr;
var
  Buf:       UtilsB2.TArrayOfWideChar;
  ResLen:    integer;
  IsSuccess: boolean;

begin
  SetLength(Buf, 1000);
  ResLen := GetLongPathNameW(myPWChar(FilePath), pointer(Buf), Length(Buf) + 1);

  if ResLen > Length(Buf) + 1 then begin
    SetLength(Buf, ResLen - 1);
    ResLen := GetLongPathNameW(myPWChar(FilePath), pointer(Buf), Length(Buf) + 1);
  end;

  IsSuccess := (ResLen > 0) and (ResLen <= Length(Buf));

  if Success <> nil then begin
    Success^ := IsSuccess;
  end;

  if IsSuccess then begin
    SetLength(result, ResLen);
    UtilsB2.CopyMem(ResLen * sizeof(myWChar), pointer(Buf), pointer(result));
  end else begin
    result := FilePath;
  end;
end; // .function GetLongPathW

function GetComputerNameW: myWStr;
var
  Buffer: array [0..31] of myWChar;
  BufLen: cardinal;

begin
  result := '';
  BufLen := Length(Buffer);

  if Windows.GetComputerNameW(@Buffer, BufLen) then begin
    result := myPWChar(@Buffer);
  end;
end;

function WaitForObjects (Objects: array of THandle; out ResObject: THandle; TimeoutMsec: integer = integer(INFINITE); WaitAll: boolean = false): TWaitResult;
var
  NumObjects: integer;
  WaitRes:    cardinal;
  i:          integer;

begin
  ResObject  := INVALID_HANDLE_VALUE;
  result     := WR_FAILED;
  i          := 0;
  NumObjects := 0;

  while (i < Length(Objects)) do begin
    if IsValidHandle(Objects[i]) then begin
      Objects[NumObjects] := Objects[i];
      Inc(NumObjects);
    end;

    Inc(i);
  end;

  if NumObjects > 0 then begin
    if NumObjects = 1 then begin
      WaitRes := WaitForSingleObject(Objects[0], TimeoutMsec);
    end else begin
      WaitRes := WaitForMultipleObjects(NumObjects, @Objects, WaitAll, TimeoutMsec);
    end;

    if WaitRes < cardinal(NumObjects) then begin
      result   := WR_WAITED;
      ResObject := Objects[WaitRes - WAIT_OBJECT_0];
    end else if (WaitRes >= WAIT_ABANDONED_0) and (WaitRes <= WAIT_ABANDONED_0 + cardinal(NumObjects) - 1) then begin
      result    := WR_ABANDONED_MUTEX;
      ResObject := Objects[WaitRes - WAIT_ABANDONED_0];
    end else if WaitRes = WAIT_TIMEOUT then begin
      result := WR_TIMEOUT;
    end else if WaitRes = WAIT_FAILED then begin
      result := WR_FAILED;
    end else begin
      result := WR_UNKNOWN;
    end;
  end; // .if
end; // .function WaitForObjects

function GetMicroTime: Int64;
var
  Time: Windows.TFileTime;

begin
  Windows.GetSystemTimeAsFileTime(Time);
  result := (PInt64(@Time)^ + Int64(116444736000000000)) div 10000;
end;

function GetUnixTime: Int64;
begin
  result := GetMicroTime div 1000;
end;

function GetSysDirW: myWStr;
var
  PathLen: integer;

begin
  result  := '';
  PathLen := Windows.GetSystemDirectoryW(@PathLen, 0);

  if PathLen > 1 then begin
    SetLength(result, PathLen - 1);
    PathLen := Windows.GetSystemDirectoryW(pointer(result), PathLen);

    if PathLen <> Length(result) then begin
      result := '';
    end;
  end;
end; // .function GetSysDirW

function GetFileAttrs (const Path: myWStr; {out} var Attrs: integer): boolean;
const
  INVALID_FILE_ATTRIBUTES = -1;

var
  Res: integer;

begin
  Res    := integer(Windows.GetFileAttributesW(myPWChar(Path)));
  result := Res <> INVALID_FILE_ATTRIBUTES;

  if result then begin
    Attrs := Res;
  end;
end;

initialization
  StaticCritSection.Init;
finalization
  StaticCritSection.Delete;
end.