unit EventMan;
(*
  Global event dispatcher.
*)

(***)  interface  (***)

uses
  SysUtils,

  DataLib,
  Debug,
  FilesEx,
  UtilsB2, Legacy;

type
  (* Import *)
  TStrList = DataLib.TStrList;
  TList    = DataLib.TList;
  TDict    = DataLib.TDict;

type
  (* Generated event info *)
  PEvent = ^TEvent;
  TEvent = packed record
      Name:     myAStr;
  {n} Data:     pointer;
      DataSize: integer;
  end;

  TEventHandler = procedure (Event: PEvent); stdcall;

  (* Container for single event handlers with additional statistics support *)
  TEventInfo = class sealed
   private
    {On} fHandlers:      TList {of TEventHandler};
         fNumTimesFired: integer;

    function GetNumHandlers: integer;
   public
    destructor Destroy; override;

    procedure AddHandler (Handler: pointer);

    property Handlers:      {n} TList {of TEventHandler} read fHandlers;
    property NumHandlers:   integer                      read GetNumHandlers;
    property NumTimesFired: integer                      read fNumTimesFired write fNumTimesFired;
  end; // .class TEventInfo

  TEventManager = class sealed

   private
    {On} class var Instance: TEventManager;

    {O} fEvents: {O} TDict {OF TEventInfo};

   public
    (* Returns globally shared event manager instance *)
    class function GetInstance: {U} TEventManager;

    constructor Create;
    destructor Destroy; override;

    procedure On (const EventName: myAStr; Handler: TEventHandler);
    procedure Fire (const EventName: myAStr; {n} EventData: pointer = nil; DataSize: integer = 0);
    function  HasEventHandlers (const EventName: myAStr): boolean;
    procedure DumpEventList (const FilePath: myAStr);
  end; // .class TEventManager

  (* Returns globally shared event manager instance *)
  function GetInstance: {U} TEventManager;


(***)  implementation  (***)


destructor TEventInfo.Destroy;
begin
  Legacy.FreeAndNil(Self.fHandlers);
end;

procedure TEventInfo.AddHandler (Handler: pointer);
begin
  {!} Assert(Handler <> nil);

  if Self.fHandlers = nil then begin
    Self.fHandlers := DataLib.NewList(not UtilsB2.OWNS_ITEMS);
  end;

  Self.fHandlers.Add(Handler);
end;

function TEventInfo.GetNumHandlers: integer;
begin
  result := 0;

  if Self.fHandlers <> nil then begin
    result := Self.fHandlers.Count;
  end;
end;

class function TEventManager.GetInstance: {U} TEventManager;
begin
  if Self.Instance = nil then begin
    Self.Instance := TEventManager.Create;
  end;

  result := Self.Instance;
end;

constructor TEventManager.Create;
begin
  Self.fEvents := DataLib.NewDict(UtilsB2.OWNS_ITEMS, DataLib.CASE_INSENSITIVE);
end;

destructor TEventManager.Destroy;
begin
  Legacy.FreeAndNil(Self.fEvents);
end;

procedure TEventManager.On (const EventName: myAStr; Handler: TEventHandler);
var
{U} EventInfo: TEventInfo;

begin
  {!} Assert(@Handler <> nil);
  EventInfo := Self.fEvents[EventName];
  // * * * * * //
  if EventInfo = nil then begin
    EventInfo               := TEventInfo.Create;
    Self.fEvents[EventName] := EventInfo;
  end;

  EventInfo.AddHandler(@Handler);
end; // .procedure TEventManager.On

procedure TEventManager.Fire (const EventName: myAStr; {n} EventData: pointer = nil; DataSize: integer = 0);
var
    Event:     TEvent;
{U} EventInfo: TEventInfo;
    i:         integer;

begin
  {!} Assert(UtilsB2.IsValidBuf(EventData, DataSize), string(Legacy.Format('TEventManager.Fire: Invalid event data for event "%s". Address: %x. Size: %d', [EventName, integer(EventData), DataSize])));
  EventInfo := Self.fEvents[EventName];
  // * * * * * //
  if EventInfo = nil then begin
    EventInfo               := TEventInfo.Create;
    Self.fEvents[EventName] := EventInfo;
  end;

  Event.Name     := EventName;
  Event.Data     := EventData;
  Event.DataSize := DataSize;

  EventInfo.NumTimesFired := EventInfo.NumTimesFired + 1;

  if EventInfo.Handlers <> nil then begin
    for i := 0 to EventInfo.Handlers.Count - 1 do begin
      TEventHandler(EventInfo.Handlers[i])(@Event);
    end;
  end;
end; // .procedure TEventManager.Fire

function TEventManager.HasEventHandlers (const EventName: myAStr): boolean;
var
{U} EventInfo: TEventInfo;

begin
  EventInfo := Self.fEvents[EventName];
  // * * * * * //
  result := (EventInfo <> nil) and (EventInfo.GetNumHandlers() > 0);
end;

procedure TEventManager.DumpEventList (const FilePath: myAStr);
var
{O} EventList: TStrList {of TEventInfo};
{U} EventInfo: TEventInfo;
    i, j:      integer;

begin
  EventList := nil;
  EventInfo := nil;
  // * * * * * //
  {!} Debug.ModuleContext.Lock;

  with FilesEx.WriteFormattedOutput(FilePath) do begin
    Line('> Format: [Event name] ([Number of handlers], [Fired N times])');
    EmptyLine;

    EventList := DataLib.DictToStrList(Self.fEvents, DataLib.CASE_INSENSITIVE);
    EventList.Sort;

    for i := 0 to EventList.Count - 1 do begin
      EventInfo := TEventInfo(EventList.Values[i]);
      Line(Legacy.Format('%s (%d, %d)', [EventList[i], EventInfo.NumHandlers, EventInfo.NumTimesFired]));
    end;

    EmptyLine; EmptyLine;
    Line('> Event handlers');
    EmptyLine;

    for i := 0 to EventList.Count - 1 do begin
      EventInfo := TEventInfo(EventList.Values[i]);

      if EventInfo.NumHandlers > 0 then begin
        Line(EventList[i] + ':');
      end;

      Indent;

      for j := 0 to EventInfo.NumHandlers - 1 do begin
        Line(Debug.ModuleContext.AddrToStr(EventInfo.Handlers[j]));
      end;

      Unindent;
    end; // .for
  end; // .with

  {!} Debug.ModuleContext.Unlock;
  // * * * * * //
  Legacy.FreeAndNil(EventList);
end; // .procedure TEventManager.DumpEventList

function GetInstance: {U} TEventManager;
begin
  result := TEventManager.GetInstance;
end;

end.
