unit VfsDebug;
(*
  Author:      Alexander Shostak aka Berserker aka Ethernidee.
  Description: Provides logging and debugging capabilities for VFS project.
*)


(***)  interface  (***)

uses
  Windows, SysUtils,
  UtilsB2, StrLib, Concur, DlgMes, Legacy;

type
  TLoggingProc = procedure (Operation, Msg: myPChar); stdcall;

  EAssertFailure = class (Exception)
  end;


function  SetLoggingProc ({n} Handler: TLoggingProc): {n} TLoggingProc; stdcall;
procedure WriteLog (const Operation, Msg: myAStr);
procedure WriteLog_ (const Operation, Msg: myPChar); stdcall;


var
  (* For external non-100% reliable fast checks of logging subsystem state *)
  LoggingEnabled: boolean = false;


(***)  implementation  (***)


var
    LogCritSection: Concur.TCritSection;
{n} LoggingProc:    TLoggingProc;


function SetLoggingProc ({n} Handler: TLoggingProc): {n} TLoggingProc; stdcall;
begin
  with LogCritSection do begin
    Enter;
    result         := @LoggingProc;
    LoggingProc    := Handler;
    LoggingEnabled := @LoggingProc <> nil;
    Leave;
  end;
end;

procedure WriteLog (const Operation, Msg: myAStr);
begin
  WriteLog_(myPChar(Operation), myPChar(Msg));
end;

procedure WriteLog_ (const Operation, Msg: myPChar);
begin
  if LoggingEnabled then begin
    with LogCritSection do begin
      Enter;

      if @LoggingProc <> nil then begin
        LoggingProc(Operation, Msg);
      end;
      
      Leave;
    end;
  end;
end;

procedure AssertHandler (const Msg, FileName: string; LineNumber: integer; Address: pointer);
var
  CrashMes: myAStr;

begin
  CrashMes := StrLib.BuildStr
  (
    'Assert violation in file "~FileName~" on line ~Line~.'#13#10'Error at address: $~Address~.'#13#10'Message: "~Message~"',
    [
     myAStr('FileName'), myAStr(FileName),
     myAStr('Line'),     Legacy.IntToStr(LineNumber),
     myAStr('Address'),  Legacy.Format('%x', [integer(Address)]),
     myAStr('Message'),  myAStr(Msg)
    ],
    '~'
  );
  
  WriteLog('AssertHandler', CrashMes);

  DlgMes.MsgError(CrashMes);

  raise EAssertFailure.Create(string(CrashMes)) at Address;
end; // .procedure AssertHandler


begin
  LogCritSection.Init;
  AssertErrorProc := AssertHandler;
end.