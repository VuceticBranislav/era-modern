unit FolderBrowser;

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
uses Legacy, Windows, SysUtils, ShlObj, AnsiStrings;

function GetFolderDialog(Handle: integer; Caption: myAStr; var strFolder: myAStr): boolean;

implementation

function BrowseCallbackProc(hwnd: HWND; uMsg: UINT; lParam: LPARAM; lpData: LPARAM): integer; stdcall;
begin
  if (uMsg = BFFM_INITIALIZED) then
    SendMessage(hwnd, BFFM_SETSELECTION, 1, lpData);
  BrowseCallbackProc:= 0;
end;

function GetFolderDialog(Handle: integer; Caption: myAStr; var strFolder: myAStr): boolean;
const
  BIF_STATUSTEXT           = $0004;
  BIF_EDITBOX              = $0010;
  BIF_NEWDIALOGSTYLE       = $0040;
  BIF_RETURNONLYFSDIRS     = $0080;
  BIF_SHAREABLE            = $0100;
  BIF_NONEWFOLDERBUTTON    = $0200;
  BIF_USENEWUI             = BIF_EDITBOX or BIF_NEWDIALOGSTYLE;

var
  BrowseInfo: TBrowseInfo;
  ItemIDList: PItemIDList;
  JtemIDList: PItemIDList;
  Path: PAnsiChar;
begin
  result:= False;
  Path:= AnsiStrings.AnsiStrAlloc(MAX_PATH);
  SHGetSpecialFolderLocation(Handle, CSIDL_DRIVES, JtemIDList);
  with BrowseInfo do
  begin
    hwndOwner:= GetActiveWindow;
    pidlRoot:= JtemIDList;
    SHGetSpecialFolderLocation(hwndOwner, CSIDL_DRIVES, JtemIDList);
    pszDisplayName:= StrAlloc(MAX_PATH);
    lpszTitle:= pChar(string(Caption));
    lpfn:= @BrowseCallbackProc;
    lParam:= LongInt(myPChar(strFolder));
    ulflags :=  
      BIF_STATUSTEXT or BIF_NEWDIALOGSTYLE or BIF_RETURNONLYFSDIRS or
      BIF_SHAREABLE or BIF_NONEWFOLDERBUTTON;
  end;

  ItemIDList:= SHBrowseForFolder(BrowseInfo);

  if (ItemIDList <> nil) then
    if SHGetPathFromIDListA(ItemIDList, Path) then
    begin
      strFolder:= Path;
      result:= True;
    end;
end;

end.
