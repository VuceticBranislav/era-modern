unit WinWrappers;
{
DESCRIPTION:  Correct wrappers for many Windows/SysUtils/... functions
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses Windows, SysUtils, Legacy;

const
  INVALID_HANDLE  = -1;


function  FileCreate (const FilePath: myAStr; (* i *) out hFile: integer): boolean;
function  FileOpen (const FilePath: myAStr; OpenMode: integer; out hFile: integer): boolean;
function  GetFileSize (hFile: integer; out FileSizeL, FileSizeH: integer): boolean;
function  FileRead (hFile: integer; var Buffer; StrictCount: integer): boolean;
function  GetModuleHandle (const ModuleName: myAStr; out hModule: integer): boolean;
function  FindResource (hModule: integer; const ResName: myAStr; ResType: myPChar; out hResource: integer): boolean;
function  LoadResource (hModule, hResource: integer; out hMem: integer): boolean;
function  LockResource (hMem: integer; out ResData: pointer): boolean;
function  SizeOfResource (hResource, hInstance: integer; out ResSize: integer): boolean;
function  FindFirstFile (const Path: myAStr; out hSearch: integer; out FindData: Windows.TWin32FindDataA): boolean;
function  FindNextFile (hSearch: integer; var FindData: Windows.TWin32FindDataA): boolean;
function  GetModuleFileName (hMod: HMODULE): myAStr;


(***) implementation (***)


function FileCreate (const FilePath: myAStr; (* i *) out hFile: integer): boolean;
begin
  hFile   :=  Legacy.FileCreate(string(FilePath));
  result  :=  hFile <> INVALID_HANDLE;
end;

function FileOpen (const FilePath: myAStr; OpenMode: integer; (* i *) out hFile: integer): boolean;
begin
  hFile   :=  Legacy.FileOpen(string(FilePath), OpenMode);
  result  :=  hFile <> INVALID_HANDLE;
end;

function GetFileSize (hFile: integer; out FileSizeL, FileSizeH: integer): boolean;
begin
  FileSizeL :=  Windows.GetFileSize(hFile, @FileSizeH);
  result    :=  FileSizeL <> -1;
end;

function FileRead (hFile: integer; var Buffer; StrictCount: integer): boolean;
begin
  result  :=  Legacy.FileRead(hFile, Buffer, StrictCount) = StrictCount;
end;

function GetModuleHandle (const ModuleName: myAStr; out hModule: integer): boolean;
begin
  hModule :=  Windows.GetModuleHandleA(myPChar(ModuleName));
  result  :=  hModule <> 0;
end;

function FindResource (hModule: integer; const ResName: myAStr; ResType: myPChar; out hResource: integer): boolean;
begin
  hResource :=  Windows.FindResourceA(hModule, myPChar(ResName), ResType);
  result    :=  hResource <> 0;
end;

function LoadResource (hModule, hResource: integer; out hMem: integer): boolean;
begin
  hMem    :=  Windows.LoadResource(hModule, hResource);
  result  :=  hMem <> 0;
end;

function LockResource (hMem: integer; out ResData: pointer): boolean;
begin
  {!} Assert(ResData = nil);
  ResData :=  Windows.LockResource(hMem);
  result  :=  ResData <> nil;
end;

function SizeOfResource (hResource, hInstance: integer; out ResSize: integer): boolean;
begin
  ResSize :=  Windows.SizeOfResource(hResource, hInstance);
  result  :=  ResSize <> 0;
end;

function FindFirstFile (const Path: myAStr; out hSearch: integer; out FindData: Windows.TWin32FindDataA): boolean;
begin
  hSearch :=  Windows.FindFirstFileA(myPChar(Path), FindData);
  result  :=  hSearch <> INVALID_HANDLE;
end;

function FindNextFile (hSearch: integer; var FindData: Windows.TWin32FindDataA): boolean;
begin
  result  :=  Windows.FindNextFileA(hSearch, FindData);
end;

function GetModuleFileName (hMod: HMODULE): myAStr;
const
  INITIAL_BUF_SIZE = 1000;

begin
  SetLength(result, INITIAL_BUF_SIZE);
  SetLength(result, Windows.GetModuleFileNameA(hMod, @result[1], Length(result)));

  if (Length(result) > INITIAL_BUF_SIZE) and
     (Windows.GetModuleFileNameA(hMod, @result[1], Length(result)) <> cardinal(Length(result)))
  then begin
    result := '';
  end;
end;

end.
