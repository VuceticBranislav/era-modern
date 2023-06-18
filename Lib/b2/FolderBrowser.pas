unit FolderBrowser;

interface
uses Windows, SysUtils, ShlObj, Legacy;

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
  BrowseInfo: TBrowseInfoA;
  ItemIDList: PItemIDList;
  JtemIDList: PItemIDList;
  Path: myPChar;
begin
  result:= False;
  Path:= Legacy.AnsiStrAlloc(MAX_PATH);
  SHGetSpecialFolderLocation(Handle, CSIDL_DRIVES, JtemIDList);
  with BrowseInfo do
  begin
    hwndOwner:= GetActiveWindow;
    pidlRoot:= JtemIDList;
    SHGetSpecialFolderLocation(hwndOwner, CSIDL_DRIVES, JtemIDList);
    pszDisplayName:= Legacy.StrAlloc(MAX_PATH);
    lpszTitle:= myPChar(Caption);
    lpfn:= @BrowseCallbackProc;
    lParam:= LongInt(myPChar(strFolder));
    ulflags :=  
      BIF_STATUSTEXT or BIF_NEWDIALOGSTYLE or BIF_RETURNONLYFSDIRS or
      BIF_SHAREABLE or BIF_NONEWFOLDERBUTTON;
  end;

  ItemIDList:= SHBrowseForFolderA(BrowseInfo);

  if (ItemIDList <> nil) then
    if SHGetPathFromIDListA(ItemIDList, Path) then
    begin
      strFolder:= Path;
      result:= True;
    end;
end;

end.
