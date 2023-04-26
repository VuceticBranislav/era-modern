unit Lang;
{
DESCRIPTION:  Language system implementation allows to dinamically change language of the whole program
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

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

(*
Any unit which uses language system is called Client.
Writing strings directly in code is a bad idea when internationalization is required.
SomeForm.Title  :=  'Hello world!'; // BAD
The idea is to be able to write
SomeForm.Title  :=  Lng[MainFormLng.Title];
Lng is a pointer to array of strings. Strings are accessed via named constants. {UnitName}Lng is a language unit.
At unit initialization phase Client registers at Lang unit. function Lang.SetLanguage loops through client list and tries to
find language data for clients.
Language data hierarchy:
  -) Binary string (either Unicode or Ansi)
  -) array of binary strings
  -) Language unit - array of arrays of binary strings
  -) Language package - array of language units
Sources of language data:
  -) Generated and compiled with main project pascal language units. {UnitName}Lng.pas. Example: UtilsLng.pas
  -) Resource package built in exe. {ResPackName}. Example: Language.lpk
  -) File array of binary strings. {ClientName}.{wide | ansi}.{language name}. Example: Utils.ansi.eng
  -) File unit. {ClientName}.{wide | ansi}.lun. Example: Utils.wide.lun
  -) File package. {FilePackName}. Example: Language.lpk

unit usage.
  -) Client unit begin..end block: RegisterClient(...)
  -) LoadFilePack, LoadResPack (optional)
  -) SetLanguage(...)
  -) ResetLanguage (optional)
  -) UnloadFilePack (optional)
*)

(***)  interface  (***)
uses Legacy, Windows, SysUtils, Classes, Math, WinWrappers, Log, UtilsB2, Files, CLang, CBinString, CLngStrArr, CLngUnit, CLngPack;

const
  (* Lang names *)
  RUS = 'rus';
  ENG = 'eng';
  
  (* unit type *)
  IS_UNICODE  = TRUE;
  IS_ANSI     = FALSE;
  
  MAX_NUMSTRINGS  = High(integer) div sizeof(AnsiString);


type
  PClient = ^TClient;
  TClient = record
              Name:         myAStr;
              LangName:     myAStr;
              DefLangName:  myAStr;
              Unicode:      boolean;
              NumStrings:   integer;
    (* UO *)  LngVar:       PPOINTER; // pointer to client's Lng variable which is pointer to array of strings
    (* U *)   DefStrArr:    pointer;  // pointer to client's default array of language strings
  end; // .record TClient


var
  AllowLoadFromFiles: boolean = TRUE;
  LangDir:            myAStr  = '.';
  FilePackName:       myAStr  = 'Language.lpk';
  ResPackName:        myAStr  = 'LngPack';


function  GetLanguage: myAStr;
function  IsClientRegistered (const ClientName: myAStr): boolean;
function  GetClientsNum: integer;
function  GetClientList: (* O *) Classes.TStringList;
function  GetClientLang (const ClientName: myAStr): myAStr;
procedure RegisterClient
(
        ClientName:   myAStr;
  const DefLangName:  myAStr;
        Unicode:      boolean;
        NumStrings:   integer;
        LngVar:       pointer;  // pointer to client's Lng variable which is pointer to array of strings
        DefStrArr:    pointer   // pointer to client's default array of language strings
);
procedure UnloadFilePack;
function  LoadFilePack: boolean;
function  LoadResPack: boolean;
procedure ResetLanguage;
procedure SetLanguage (const NewLanguage: myAStr);
  
  
(***)  implementation  (***)


var
(* O *) ClientList:     Classes.TStringList;
(* U *) ResPack:        CLngPack.PLngPack;
(* O *) ResPackReader:  CLngPack.TLngPackReader;
(* O *) FilePack:       CLngPack.PLngPack;
(* O *) FilePackReader: CLngPack.TLngPackReader;
        Language:       myAStr;


function GetLanguage: myAStr;
begin
  result  :=  Language;
end;

function FindClient (const ClientName: myAStr; out Client: PClient): boolean;
var
  ClientInd: integer;

begin
  {!} Assert(Client = nil);
  ClientInd :=  ClientList.IndexOf(string(ClientName));
  result    :=  ClientInd <> -1;
  if result then begin
    Client  :=  pointer(ClientList.Objects[ClientInd]);
  end;
end; // .function FindClient

function IsClientRegistered (const ClientName: myAStr): boolean;
begin
  result  :=  ClientList.IndexOf(string(ClientName)) <> -1;
end;

function GetClientsNum: integer;
begin
  result  :=  ClientList.Count;
end;

function GetClientList: (* O *) Classes.TStringList;
var
  i:  integer;

begin
  result                :=  Classes.TStringList.Create;
  result.CaseSensitive  :=  TRUE;
  result.Sorted         :=  TRUE;
  result.Duplicates     :=  Classes.dupError;
  for i:=0 to ClientList.Count - 1 do begin
    result.Add(ClientList[i]);
  end;
end; // .function GetClientList

function GetClientLang (const ClientName: myAStr): myAStr;
begin
  {!} Assert(IsClientRegistered(ClientName));
  result  :=  PClient(ClientList.Objects[ClientList.IndexOf(string(ClientName))]).LangName;
end;

procedure RegisterClient
(
        ClientName:   myAStr;
  const DefLangName:  myAStr;
        Unicode:      boolean;
        NumStrings:   integer;
        LngVar:       pointer;
        DefStrArr:    pointer
);
var
(* O *) Client: PClient;
  
begin
  ClientName  :=  Legacy.AnsiLowerCase(ClientName);
  {!} Assert(CLang.IsValidClientName(ClientName));
  {!} Assert(not IsClientRegistered(ClientName));
  {!} Assert(CLang.IsValidLangName(DefLangName));
  {!} Assert(Math.InRange(NumStrings, 1, MAX_NUMSTRINGS));
  {!} Assert(LngVar <> nil);
  {!} Assert(DefStrArr <> nil);
  Client  :=  nil;
  // * * * * * //
  New(Client);
  Client.Name         :=  ClientName;
  Client.LangName     :=  DefLangName;
  Client.DefLangName  :=  DefLangName;
  Client.Unicode      :=  Unicode;
  Client.NumStrings   :=  NumStrings;
  Client.LngVar       :=  LngVar;
  Client.DefStrArr    :=  DefStrArr;
  ClientList.AddObject(string(ClientName), pointer(Client)); Client:=nil;
end; // .procedure RegisterClient

procedure ResetClientLang (Client: PClient);
var
(* on *)  ArrOfStr: PEndlessAnsiStrArr;
          i:        integer;

begin
  {!} Assert(Client <> nil);
  ArrOfStr  :=  nil;
  // * * * * * //
  if Client.LangName <> Client.DefLangName then begin
    ArrOfStr  :=  Client.LngVar^; Client.LngVar^  :=  nil;
    for i:=0 to Client.NumStrings - 1 do begin
      ArrOfStr[i] :=  '';
    end;
    FreeMem(ArrOfStr); ArrOfStr :=  nil;
    Client.LngVar^  :=  Client.DefStrArr;
  end;
end; // .procedure ResetClientLang

procedure UnloadFilePack;
begin
  FilePackReader.Disconnect;
  FreeMem(FilePack); FilePack := nil;
end;

function LoadFilePack: boolean;
var
(* O *) FileObj:      Files.TFile;
        FilePackPath: myAStr;
        FilePackSize: integer;
        Error:        myAStr;

begin
  FileObj :=  Files.TFile.Create;
  result  :=  FALSE;
  // * * * * * //
  UnloadFilePack;
  if AllowLoadFromFiles then begin
    FilePackPath  :=  LangDir + '\' + FilePackName;
    if Legacy.FileExists(FilePackPath) then begin
      result  :=
        FileObj.Open(LangDir + '\' + FilePackName, Files.MODE_READ) and
        FileObj.ReadAllToBuf(pointer(FilePack), FilePackSize);
      if not result then begin
        Log.Write('LanguageSystem', 'LoadFilePack', 'Cannot load language pack "' + FilePackPath + '"');
      end;
    end;
    if result then begin
      FilePackReader.Connect(FilePack, FilePackSize);
      result  :=  FilePackReader.Validate(Error);
      if not result then begin
        Log.Write('LanguageSystem', 'LoadFilePack', 'Validation of language pack "' + FilePackPath + '" failed.'#13#10'Error: ' + Error);
        UnloadFilePack;
      end;
    end;
  end; // .if
  // * * * * * //
  SysUtils.FreeAndNil(FileObj);
end; // .function LoadFilePack

function LoadResPack: boolean;
var
  hResource:    integer;
  hMem:         integer;
  ResPackSize:  integer;
  Error:        myAStr;
  
begin
  result  :=
    ResPackReader.Connected and
    WinWrappers.FindResource(SysInit.HInstance, ResPackName, myPChar(Windows.RT_RCDATA), hResource) and
    WinWrappers.LoadResource(SysInit.HInstance, hResource, hMem) and
    WinWrappers.SizeOfResource(hResource, System.MainInstance, ResPackSize);
  if result then begin
    ResPackReader.Connect(ResPack, ResPackSize);
    result  :=  ResPackReader.Validate(Error);
    if not result then begin
      Log.Write('LanguageSystem', 'LoadResPack', 'Validation of language pack "' + ResPackName + '" failed.'#13#10'Error: ' + Error);
      ResPackReader.Disconnect;
      ResPack :=  nil;        
    end;
  end;
end; // .function LoadResPack

procedure SetClientLngStrArr (Client: PClient; LngStrArrReader: CLngStrArr.TLngStrArrReader);
var
(* O *) ArrOfStr:         PEndlessAnsiStrArr;
(* O *) BinStringReader:  CBinString.TBinStringReader;
        i:                integer;

begin
  {!} Assert(Client <> nil);
  {!} Assert(LngStrArrReader <> nil);
  ArrOfStr        :=  nil;
  BinStringReader :=  nil;
  // * * * * * //
  ResetClientLang(Client);
  GetMem(ArrOfStr, Client.NumStrings * 4); Legacy.FillChar(ArrOfStr^, Client.NumStrings * 4, #0);
  LngStrArrReader.SeekBinString(0);
  i :=  0;
  while LngStrArrReader.ReadBinString(BinStringReader) do begin
    if Client.Unicode then begin
      ArrOfStr[i] :=  myAStr(BinStringReader.GetWideString);
    end else begin
      ArrOfStr[i] :=  BinStringReader.GetAnsiString;
    end;
    Inc(i);
  end;
  Client.LangName :=  LngStrArrReader.LangName;
  Client.LngVar^  :=  ArrOfStr; ArrOfStr  :=  nil;
end; // .procedure SetClientLngStrArr

function LoadClientLangFromResPack (Client: PClient; const NewLanguage: myAStr): boolean;
var
(* on *)  LngUnitReader:    CLngUnit.TLngUnitReader;
(* on *)  LngStrArrReader:  CLngStrArr.TLngStrArrReader;

begin
  {!} Assert(Client <> nil);
  {!} Assert(CLang.IsValidLangName(NewLanguage));
  LngUnitReader   :=  nil;
  LngStrArrReader :=  nil;
  // * * * * * //
  result  :=
    ResPackReader.Connected and
    ResPackReader.FindLngUnit(Client.Name, Client.Unicode, LngUnitReader) and
    LngUnitReader.FindLngStrArr(NewLanguage, LngStrArrReader);
  if result then begin
    SetClientLngStrArr(Client, LngStrArrReader);
  end;
  // * * * * * //
  SysUtils.FreeAndNil(LngStrArrReader);
  SysUtils.FreeAndNil(LngUnitReader);
end; // .function LoadClientLangFromResPack

function LoadClientLangFromFilePack (Client: PClient; const NewLanguage: myAStr): boolean;
var
(* on *)  LngUnitReader:    CLngUnit.TLngUnitReader;
(* on *)  LngStrArrReader:  CLngStrArr.TLngStrArrReader;

begin
  {!} Assert(Client <> nil);
  {!} Assert(CLang.IsValidLangName(NewLanguage));
  LngUnitReader   :=  nil;
  LngStrArrReader :=  nil;
  // * * * * * //
  result  :=
    FilePackReader.Connected and
    FilePackReader.FindLngUnit(Client.Name, Client.Unicode, LngUnitReader) and
    LngUnitReader.FindLngStrArr(NewLanguage, LngStrArrReader);
  if result then begin
    SetClientLngStrArr(Client, LngStrArrReader);
  end;
  // * * * * * //
  SysUtils.FreeAndNil(LngStrArrReader);
  SysUtils.FreeAndNil(LngUnitReader);
end; // .function LoadClientLangFromFilePack

function LoadClientLangFromFileUnit (Client: PClient; const NewLanguage: myAStr): boolean;
var
(* O  *)  FileObj:          Files.TFile;
(* on *)  LngUnit:          CLngUnit.PLngUnit;
(* on *)  LngUnitReader:    CLngUnit.TLngUnitReader;
(* on *)  LngStrArrReader:  CLngStrArr.TLngStrArrReader;
          FileUnitSize:     integer;
          FileUnitPath:     myAStr;
          Error:            myAStr;

begin
  {!} Assert(Client <> nil);
  {!} Assert(CLang.IsValidLangName(NewLanguage));
  FileObj         :=  Files.TFile.Create;
  LngUnit         :=  nil;
  LngUnitReader   :=  nil;
  LngStrArrReader :=  nil;
  result          :=  FALSE;
  // * * * * * //
  FileUnitPath  :=  LangDir + '\' + Client.Name + '.' + CLang.GetEncodingPrefix(Client.Unicode) +'.lun';
  if AllowLoadFromFiles and Legacy.FileExists(FileUnitPath) then begin
    result  :=
      FileObj.Open(FileUnitPath, Files.MODE_READ) and
      FileObj.ReadAllToBuf(pointer(LngUnit), FileUnitSize);
    if not result then begin
      Log.Write('LanguageSystem', 'LoadClientLangFromFileUnit', 'Cannot load language unit "' + FileUnitPath + '"');
    end else begin
      LngUnitReader :=  CLngUnit.TLngUnitReader.Create;
      LngUnitReader.Connect(LngUnit, FileUnitSize);
      result  :=  LngUnitReader.Validate(Error);
      if not result then begin
        Log.Write('LanguageSystem', 'LoadClientLangFromFileUnit', 'Validation of language unit "' + FileUnitPath + '" failed.'#13#10'Error: ' + Error);
      end;
    end;
    if result then begin
      result  :=  LngUnitReader.FindLngStrArr(NewLanguage, LngStrArrReader);
      if result then begin
        SetClientLngStrArr(Client, LngStrArrReader);
      end;
    end;
  end; // .if
  // * * * * * //
  SysUtils.FreeAndNil(FileObj);
  FreeMem(LngUnit); LngUnit :=  nil;
  SysUtils.FreeAndNil(LngStrArrReader);
  SysUtils.FreeAndNil(LngUnitReader);
end; // .function LoadClientLangFromFileUnit

function LoadClientLangFromFileStrArr (Client: PClient; const NewLanguage: myAStr): boolean;
var
(* O  *)  FileObj:          Files.TFile;
(* on *)  LngStrArr:        CLngStrArr.PLngStrArr;
(* on *)  LngStrArrReader:  CLngStrArr.TLngStrArrReader;
          FileStrArrSize:   integer;
          FileStrArrPath:   myAStr;
          Error:            myAStr;

begin
  {!} Assert(Client <> nil);
  {!} Assert(CLang.IsValidLangName(NewLanguage));
  FileObj         :=  Files.TFile.Create;
  LngStrArr       :=  nil;
  LngStrArrReader :=  nil;
  result          :=  FALSE;
  // * * * * * //
  FileStrArrPath  :=  LangDir + '\' + Client.Name + '.' + CLang.GetEncodingPrefix(Client.Unicode) + '.' + NewLanguage;
  if AllowLoadFromFiles and Legacy.FileExists(FileStrArrPath) then begin
    result  :=
      FileObj.Open(FileStrArrPath, Files.MODE_READ) and
      FileObj.ReadAllToBuf(pointer(LngStrArr), FileStrArrSize);
    if not result then begin
      Log.Write('LanguageSystem', 'LoadClientLangFromFileStrArr', 'Cannot load language strings array "' + FileStrArrPath + '"');
    end else begin
      LngStrArrReader :=  CLngStrArr.TLngStrArrReader.Create;
      LngStrArrReader.Connect(LngStrArr, FileStrArrSize);
      result  :=  LngStrArrReader.Validate(Error);
      if not result then begin
        Log.Write('LanguageSystem', 'LoadClientLangFromFileStrArr', 'Validation of language strings array "' + FileStrArrPath + '" failed.'#13#10'Error: ' + Error);
      end else begin
        SetClientLngStrArr(Client, LngStrArrReader);
      end;
    end; // .else
  end; // .if
  // * * * * * //
  SysUtils.FreeAndNil(FileObj);
  FreeMem(LngStrArr); LngStrArr :=  nil;
  SysUtils.FreeAndNil(LngStrArrReader);
end; // .function LoadClientLangFromFileStrArr

function SetClientLang (Client: PClient; const NewLanguage: myAStr): boolean;
begin
  {!} Assert(Client <> nil);
  {!} Assert(CLang.IsValidLangName(NewLanguage));
  result  :=  NewLanguage = Client.LangName;
  if not result then begin
    ResetClientLang(Client);
  end;
  result  :=
    (NewLanguage = Client.LangName) or
    LoadClientLangFromResPack     (Client, NewLanguage) or
    LoadClientLangFromFilePack    (Client, NewLanguage) or
    LoadClientLangFromFileUnit    (Client, NewLanguage) or
    LoadClientLangFromFileStrArr  (Client, NewLanguage);
end; // .function SetClientLang

procedure ResetLanguage;
var
  i:  integer;

begin
  Language  :=  '';
  for i:=0 to ClientList.Count - 1 do begin
    ResetClientLang(pointer(ClientList.Objects[i]));
  end;
end;

procedure SetLanguage (const NewLanguage: myAStr);
var
  i:  integer;

begin
  {!} Assert(CLang.IsValidLangName(NewLanguage));
  for i:=0 to ClientList.Count - 1 do begin
    SetClientLang(pointer(ClientList.Objects[i]), NewLanguage)
  end;
end;

begin
  ClientList                :=  Classes.TStringList.Create;
  ClientList.Sorted         :=  TRUE;
  ClientList.Duplicates     :=  Classes.dupError;
  ClientList.CaseSensitive  :=  FALSE;
  ResPackReader             :=  CLngPack.TLngPackReader.Create;
  FilePackReader            :=  CLngPack.TLngPackReader.Create;
end.
