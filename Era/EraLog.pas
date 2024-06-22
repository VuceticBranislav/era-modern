unit EraLog;
(*
  Description: Logging support
  Author:      Alexander Shostak aka Berserker
*)


(***)  interface  (***)

uses
  Concur,
  ConsoleAPI,
  Log,
  StrLib,
  SysUtils,
  Windows,

  EraSettings,
  VfsImport, Legacy;


type
  TLogger = class (Log.TLogger)
   protected
    {O} fCritSection: Concur.TCritSection;
        fLocked:      boolean;

   public
    constructor Create;
    destructor Destroy; override;

    function  Read (out LogRec: TLogRec): boolean; override;
    function  IsLocked: boolean; override;
    procedure Lock; override;
    procedure Unlock; override;
    function  GetPos (out Pos: integer): boolean; override;
    function  Seek (NewPos: integer): boolean; override;
    function  GetCount (out Count: integer): boolean; override;
  end;

  TFakeLogger  = class (TLogger)
    function Write (const EventSource, Operation, Description: myAStr): boolean; override;
  end;
  
  TConsoleLogger  = class (TLogger)
   protected
   {O} fCon: ConsoleAPI.TConsole;
    
   public
    constructor Create (const Title: myAStr);
    destructor  Destroy; override;

    function Write (const EventSource, Operation, Description: myAStr): boolean; override;
  end;
  
  TFileLogger = class (TLogger)
   protected
   {O} fFile: Windows.THandle;

   public
    constructor Create (const FilePath: myAStr);
    destructor  Destroy; override;

    function Write (const EventSource, Operation, Description: myAStr): boolean; override;
  end;


procedure InstallLoggers (const GameDir: myAStr);


(***) implementation (***)


const
  LOG_FILE_NAME = myAStr('log.txt');

  BR                     = myAStr(#13#10);
  RECORD_BEGIN_SEPARATOR : myAStr = '>> ';
  RECORD_END_SEPARATOR   : myAStr = BR + BR;
  OPERATION_SEPARATOR    : myAStr = ': ';
  DESCRIPTION_SEPARATOR  : myAStr = BR;
  DESCR_LINES_PREFIX     = myAStr('   ');
  DESCR_LINES_GLUE       : myAStr = BR + DESCR_LINES_PREFIX;


constructor TLogger.Create;
begin
  Self.fCritSection.Init;
  Self.fLocked := false;
end;

destructor TLogger.Destroy;
begin
  Self.fCritSection.Delete;
end;

function TLogger.Read (out LogRec: TLogRec): boolean;
begin
  result := false;
end;

function TLogger.IsLocked: boolean;
begin
  with Self.fCritSection do begin
    Enter;
    result := Self.fLocked;
    Leave;
  end;
end;

procedure TLogger.Lock;
begin
  with Self.fCritSection do begin
    Enter;
    Self.fLocked := true;
    Leave;
  end;
end;

procedure TLogger.Unlock;
begin
  with Self.fCritSection do begin
    Enter;
    Self.fLocked := false;
    Leave;
  end;
end;

function TLogger.GetPos (out Pos: integer): boolean;
begin
  Pos    := -1;
  result := false;
end;

function TLogger.Seek (NewPos: integer): boolean;
begin
  result := false;
end;

function TLogger.GetCount (out Count: integer): boolean;
begin
  Count  := -1;
  result := false;
end;

function TFakeLogger.Write (const EventSource, Operation, Description: myAStr): boolean;
begin
  result := true;
end;

constructor TConsoleLogger.Create (const Title: myAStr);
begin
  inherited Create;
  Self.fCon := ConsoleAPI.GetConsole(Title, 80, 50, 80, 1000);
end;

destructor TConsoleLogger.Destroy;
begin
  Legacy.FreeAndNil(Self.fCon);
  inherited;
end;

function TConsoleLogger.Write (const EventSource, Operation, Description: myAStr): boolean;
begin
  with Self.fCritSection do begin
    Enter;

    result := not Self.fLocked;

    if result then begin
      Self.Lock;

      Writeln
      (
        RECORD_BEGIN_SEPARATOR,
        EventSource,
        OPERATION_SEPARATOR,
        Operation,
        DESCRIPTION_SEPARATOR,
        DESCR_LINES_PREFIX,
        StrLib.Join(StrLib.Explode(Description, BR), DESCR_LINES_GLUE),
        RECORD_END_SEPARATOR
      );

      Self.Unlock;
    end; // .if

    Leave;
  end; // .with
end; // .function TConsoleLogger.Write

constructor TFileLogger.Create (const FilePath: myAStr);
begin
  inherited Create;

  Self.fFile := Windows.CreateFileA(
    myPChar(FilePath), Windows.GENERIC_WRITE, Windows.FILE_SHARE_READ or Windows.FILE_SHARE_DELETE, nil, Windows.CREATE_ALWAYS,
    Windows.FILE_ATTRIBUTE_NORMAL, 0
  );
end;

destructor TFileLogger.Destroy;
begin
  Legacy.FreeAndNil(Self.fFile);
  inherited;
end;

function TFileLogger.Write (const EventSource, Operation, Description: myAStr): boolean;
var
  Buf:          myAStr;
  BytesWritten: cardinal;

begin
  with Self.fCritSection do begin
    Enter;

    result := not Self.fLocked;

    if result then begin
      Self.Lock;

      Buf := StrLib.Concat([
        RECORD_BEGIN_SEPARATOR,
        EventSource,
        OPERATION_SEPARATOR,
        Operation,
        DESCRIPTION_SEPARATOR,
        DESCR_LINES_PREFIX,
        StrLib.Join(StrLib.Explode(Description, BR), DESCR_LINES_GLUE),
        RECORD_END_SEPARATOR
      ]);

      Windows.WriteFile(Self.fFile, myPChar(Buf)^, Length(Buf), BytesWritten, nil);

      Self.Unlock;
    end; // .if    

    Leave;
  end; // .with  
end; // .function TFileLogger.Write

procedure VfsLogger (Operation, Msg: myPChar); stdcall;
begin
  Log.Write('VFS', Operation, Msg);
end;

procedure InstallLoggers (const GameDir: myAStr);
begin
  if EraSettings.IsDebug then begin
    if Legacy.AnsiLowerCase(EraSettings.GetOpt('Debug.LogDestination').Str('File')) = 'file' then begin
      Log.InstallLogger(EraLog.TFileLogger.Create(GameDir + '\' + EraSettings.DEBUG_DIR + '\' + LOG_FILE_NAME), true);
    end else begin
      Log.InstallLogger(EraLog.TConsoleLogger.Create('Era Log'), true);
    end;
  end else begin
    Log.InstallLogger(EraLog.TFakeLogger.Create, true);
  end;

  if EraSettings.GetDebugBoolOpt('Debug.LogVirtualFileSystem', false) then begin
    VfsImport.SetLoggingProc(@VfsLogger);
  end;
end;

end.
