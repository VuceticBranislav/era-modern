unit CmdApp;
{
DESCRIPTION:  Provides new-style command line handling and some inter-process functions
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
New style command line: ArgName=ArgValue "Arg Name"="Arg Value"
Simple "ArgName" means ArgName:1.
Argument names are case-insensitive.
Duplicate arguments override the previous ones.
*)

(***)  interface  (***)
uses Legacy, Windows, SysUtils, UtilsB2, TypeWrappers, Crypto, TextScan, AssocArrays, Lists; {$WARN SYMBOL_PLATFORM OFF}

const
  (* RunProcess *)
  WAIT_PROCESS_END  = TRUE;


type
  (* IMPORT *)
  TString = TypeWrappers.TString;


function  ArgExists (const ArgName: myAStr): boolean;
function  GetArg (const ArgName: myAStr): myAStr;
procedure SetArg (const ArgName, NewArgValue: myAStr);
function  RunProcess (const ExeFilePath, ExeArgs, ExeCurrentDir: myAStr; WaitEnd: boolean): boolean;


var
{O} Args:     {O} AssocArrays.TAssocArray {OF TString};
{O} ArgsList: Lists.TStringList;
    AppPath:  myAStr;


(***)  implementation  (***)


function ArgExists (const ArgName: myAStr): boolean;
begin
  result := Args[ArgName] <> nil;
end;

function GetArg (const ArgName: myAStr): myAStr;
var
{U} ArgValue: TString;

begin
  ArgValue  :=  Args[ArgName];
  // * * * * * //
  if ArgValue <> nil then begin
    result  :=  ArgValue.Value;
  end else begin
    result  :=  '';
  end;
end; // .function GetArg

procedure SetArg (const ArgName, NewArgValue: myAStr);
var
{U} ArgValue: TString;
  
begin
  ArgValue  :=  Args[ArgName];
  // * * * * * //
  if ArgValue <> nil then begin
    ArgValue.Value  :=  NewArgValue;
  end else begin
    Args[ArgName] :=  TString.Create(NewArgValue);
  end;
end; // .procedure SetArg

procedure ProcessArgs;
const
  BLANKS    = [#0..#32];
  ARGDELIM  = BLANKS + ['='];

var
{O} Scanner:  TextScan.TTextScanner;
    CmdLine:  myAStr;
    ArgName:  myAStr;
    ArgValue: myAStr;
    SavedPos: integer;
    c:        myChar;

  function ReadToken (const ArgDelimCharset: UtilsB2.TCharSet): myAStr;
  begin
    {!} Assert(Scanner.GetCurrChar(c));
    
    if c = '"' then begin
      Scanner.GotoNextChar;
      Scanner.ReadTokenTillDelim(['"'], result);
      Scanner.GotoNextChar;
    end else begin
      Scanner.ReadTokenTillDelim(ArgDelimCharset, result);
    end;
  end; // .function ReadToken

begin
  Scanner :=  TextScan.TTextScanner.Create;
  // * * * * * //
  CmdLine  := myAStr(System.CmdLine);
  Args     := AssocArrays.NewStrictAssocArr(TString);
  ArgsList := Lists.NewSimpleStrList;
  Scanner.Connect(CmdLine, #10);
  
  if Scanner.SkipCharset(BLANKS) then begin
    AppPath :=  ReadToken(BLANKS);
  end;
  
  while Scanner.SkipCharset(BLANKS) do begin
    SavedPos := Scanner.Pos;
    ArgsList.Add(ReadToken(BLANKS));
    Scanner.GotoPos(SavedPos);
    ArgName := ReadToken(ARGDELIM);
    
    if Scanner.GetCurrChar(c) then begin
      if c = '=' then begin
        Scanner.GotoNextChar;
        ArgValue := ReadToken(BLANKS);
      end else begin
        ArgValue := '1';
      end;
    end else begin
      ArgValue := '1';
    end;
    
    Args[ArgName] := TString.Create(ArgValue);
  end; // .while
  // * * * * * //
  SysUtils.FreeAndNil(Scanner);
end; // .procedure ProcessArgs

function RunProcess (const ExeFilePath, ExeArgs, ExeCurrentDir: myAStr; WaitEnd: boolean): boolean;
const
  NO_APPLICATION_NAME        = nil;
  DEFAULT_PROCESS_ATTRIBUTES = nil;
  DEFAULT_THREAD_ATTRIBUTES  = nil;
  INHERIT_HANDLES            = TRUE;
  NO_CREATION_FLAGS          = 0;
  INHERIT_ENVIROMENT         = nil;

var
  StartupInfo:  Windows.TStartupInfoA;
  ProcessInfo:  Windows.TProcessInformation;
  
begin
  Legacy.FillChar(StartupInfo, sizeof(StartupInfo), #0);
  StartupInfo.cb  :=  sizeof(StartupInfo);
  result          :=  Windows.CreateProcessA
  (
    NO_APPLICATION_NAME,
    myPChar('"' + ExeFilePath + '" ' + ExeArgs),
    DEFAULT_PROCESS_ATTRIBUTES,
    DEFAULT_THREAD_ATTRIBUTES,
    not INHERIT_HANDLES,
    NO_CREATION_FLAGS,
    INHERIT_ENVIROMENT,
    pointer(ExeCurrentDir),
    StartupInfo,
    ProcessInfo
  );
  
  if result and WaitEnd then begin
    Windows.WaitForSingleObject(ProcessInfo.hProcess, Windows.INFINITE);
  end;
end; // .function RunProcess

begin
  ProcessArgs;
end.
