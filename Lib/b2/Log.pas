unit Log;
{
  DESCRIPTION: Logging support
  AUTHOR:      Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(*
  Log is viewed as abstract list of records with sequential access. Every record contains time stamp.
  There is a possibility to turn off/on logging functions which may be useful, for example, in protection unit.
  All operations may return error because log storage usually depends on environment.
  Loggers must be implemented in a thread-safe manner.
*)

(***) interface (***)
uses Windows, SysUtils, Classes, Concur, Legacy;

const
  FREE_OLD_LOGGER = TRUE;


type
  PLogRec = ^TLogRec;
  TLogRec = record
    TimeStamp:    TDateTime;
    EventSource:  myAStr;
    Operation:    myAStr;
    Description:  myAStr;
  end; // .record TLogRec

  TLogger = class abstract
    function  Write (const EventSource, Operation, Description: myAStr): boolean; virtual; abstract;
    function  Read (out LogRec: TLogRec): boolean; virtual; abstract;
    function  IsLocked: boolean; virtual; abstract;
    procedure Lock; virtual; abstract;
    procedure Unlock; virtual; abstract;
    function  GetPos (out Pos: integer): boolean; virtual; abstract;
    function  Seek (NewPos: integer): boolean; virtual; abstract;
    function  GetCount (out Count: integer): boolean; virtual; abstract;
  end; // .class TLogger

  TMemLogger = class (TLogger)
    (***) protected (***)
      {O} fCritSection:   Concur.TCritSection;
          fListOfRecords: Classes.TList;
          fPos:           integer;
          fLocked:        boolean;

    (***) public (***)
      constructor Create;
      destructor Destroy; override;

      function  Write (const EventSource, Operation, Description: myAStr): boolean; override;
      function  Read (out LogRec: TLogRec): boolean; override;
      function  IsLocked: boolean; override;
      procedure Lock; override;
      procedure Unlock; override;
      function  GetPos (out Pos: integer): boolean; override;
      function  Seek (NewPos: integer): boolean; override;
      function  GetCount(out Count: integer): boolean; override;
  end; // .class TMemLogger


(*-----------------  unit WRAPPERS for TLOGGER METHODS  ----------------------*)

function  Write (const EventSource, Operation, Description: myAStr): boolean;
function  Read (out LogRec: TLogRec): boolean;
function  IsLocked: boolean;
procedure Lock;
procedure Unlock;
function  GetPos (out Pos: integer): boolean;
function  Seek (NewPos: integer): boolean;
function  GetCount(out Count: integer): boolean;

(*----------------------------------------------------------------------------*)


procedure InstallLogger (NewLogger: TLogger; FreeOldLogger: boolean);


(***)  implementation  (***)


var
{OU} Logger: TLogger;


constructor TMemLogger.Create;
begin
  inherited;
  Self.fCritSection.Init;
  Self.fListOfRecords := Classes.TList.Create;
  Self.fPos           := 0;
  Self.fLocked        := FALSE;
end;

destructor TMemLogger.Destroy;
begin
  Self.fCritSection.Delete;
  Legacy.FreeAndNil(Self.fListOfRecords);
end;

function TMemLogger.Write (const EventSource, Operation, Description: myAStr): boolean;
var
{U} LogRec: PLogRec;

begin
  LogRec := nil;
  // * * * * * //
  with Self.fCritSection do begin
    Enter;

    result := not Self.fLocked;

    if result then begin
      Self.Lock;

      New(LogRec);
      LogRec.TimeStamp   := Legacy.Now;
      LogRec.EventSource := EventSource;
      LogRec.Operation   := Operation;
      LogRec.Description := Description;
      Self.fListOfRecords.Add(LogRec);

      Self.Unlock;
    end;

    Leave;
  end; // .if
end; // .function TMemLogger.Write

function TMemLogger.Read (out LogRec: TLogRec): boolean;
begin
  with Self.fCritSection do begin
    Enter;

    result := Self.fPos < Self.fListOfRecords.Count;

    if result then begin
      LogRec := PLogRec(Self.fListOfRecords[Self.fPos])^;
      Inc(Self.fPos);
    end;

    Leave;
  end;
end; // .function TMemLogger.Read

function TMemLogger.IsLocked: boolean;
begin
  with Self.fCritSection do begin
    Enter;

    result := Self.fLocked;

    Leave;
  end;
end;

procedure TMemLogger.Lock;
begin
  with Self.fCritSection do begin
    Enter;

    Self.fLocked := true;

    Leave;
  end;
end;

procedure TMemLogger.Unlock;
begin
  with Self.fCritSection do begin
    Enter;

    Self.fLocked := false;

    Leave;
  end;
end;

function TMemLogger.GetPos (out Pos: integer): boolean;
begin
  with Self.fCritSection do begin
    Enter;

    result := true;
    Pos    := Self.fPos;

    Leave;
  end;
end;

function TMemLogger.Seek (NewPos: integer): boolean;
begin
  {!} Assert(NewPos >= 0);
  with Self.fCritSection do begin
    Enter;

    result := NewPos < Self.fListOfRecords.Count;

    if result then begin
      Self.fPos := NewPos;
    end;

    Leave;
  end; // .with
end; // .function TMemLogger.Seek

function TMemLogger.GetCount (out Count: integer): boolean;
begin
  with Self.fCritSection do begin
    Enter;

    result := true;
    Count  := Self.fListOfRecords.Count;

    Leave;
  end;
end;

function Write (const EventSource, Operation, Description: myAStr): boolean;
begin
  result := Logger.Write(EventSource, Operation, Description);
end;

function Read (out LogRec: TLogRec): boolean;
begin
  result := Logger.Read(LogRec);
end;

function IsLocked: boolean;
begin
  result := Logger.IsLocked;
end;

procedure Lock;
begin
  Logger.Lock;
end;

procedure Unlock;
begin
  Logger.Unlock;
end;

function GetPos (out Pos: integer): boolean;
begin
  result := Logger.GetPos(Pos);
end;

function Seek ({!} NewPos: integer): boolean;
begin
  result := Logger.Seek(NewPos);
end;

function GetCount (out Count: integer): boolean;
begin
  result := Logger.GetCount(Count);
end;

procedure InstallLogger (NewLogger: TLogger; FreeOldLogger: boolean);
begin
  {!} Assert(NewLogger <> nil);

  if FreeOldLogger then begin
    Legacy.FreeAndNil(Logger);
  end;

  Logger := NewLogger;
end;

begin
  Logger := TMemLogger.Create;
end.
