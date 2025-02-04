unit Stores;
(*
  Description: Provides ability to store safely data in savegames using named sections
  Author:      Alexander Shostak aka Berserker
*)

(***)  interface  (***)

uses
  Math,
  SysUtils,
  Windows,

  ApiJack,
  AssocArrays,
  Crypto,
  DataLib,
  Files,
  Log,
  StrLib,
  UtilsB2,

  EraSettings,
  EventMan,
  GameExt,
  Heroes,
  PatchApi, Legacy;

const
  DUMP_SAVEGAME_SECTIONS_DIR   = EraSettings.DEBUG_DIR + '\Savegame Sections';
  ERA_SAVEGAME_VERSION_SECTION = 'Era.SavegameVersion';
  SAVEGAME_MIN_VERSION         = 3916;
  COLOR_TAG_RED                = '{~F03333}';

type
  (* Import *)
  TAssocArray = AssocArrays.TAssocArray;
  TStrBuilder = StrLib.TStrBuilder;

  // Rider for some data source, for instance savegame section.
  IRider = interface
    procedure Write (Size: integer; {n} Addr: pbyte);
    procedure WriteByte (Value: byte);
    procedure WriteInt (Value: integer);
    procedure WriteStr (const Str: myAStr);
    procedure WritePchar ({n} Str: myPChar);
    function  Read (Size: integer; {n} Addr: pbyte): integer;
    function  ReadByte: byte;
    function  ReadInt: integer;
    function  ReadStr: myAStr;
    procedure Flush;
  end;

  TMemWriter = class (TInterfacedObject, IRider)
   public
    constructor Create;
    destructor  Destroy; override;

    procedure Write (Size: integer; {n} Addr: pbyte);
    procedure WriteByte (Value: byte);
    procedure WriteInt (Value: integer);
    procedure WriteStr (const Str: myAStr);
    procedure WritePchar ({n} Str: myPchar);
    function  Read (Size: integer; {n} Addr: pbyte): integer;
    function  ReadByte: byte;
    function  ReadInt: integer;
    function  ReadStr: myAStr;
    procedure Flush;

    function BuildBuf: UtilsB2.TArrayOfByte;

   private
    {O} fDataBuilder: TStrBuilder;
  end;

  TMemReader = class (TInterfacedObject, IRider)
   public
    constructor Create (BufSize: integer; {Un} Buf: pointer);

    procedure Write (Size: integer; {n} Addr: pbyte);
    procedure WriteByte (Value: byte);
    procedure WriteInt (Value: integer);
    procedure WriteStr (const Str: myAStr);
    procedure WritePchar ({n} Str: myPchar);
    function  Read (Size: integer; {n} Addr: pbyte): integer;
    function  ReadByte: byte;
    function  ReadInt: integer;
    function  ReadStr: myAStr;
    procedure Flush;

   private
    fReader: StrLib.IByteSource;
  end;


const
  ZvsErmTriggerBeforeSave: UtilsB2.TProcedure = Ptr($750093);


procedure WriteSavegameSection(DataSize: integer; {n} Data: pointer; const SectionName: myAStr);
function  ReadSavegameSection (DataSize: integer; {n} Dest: pointer; const SectionName: myAStr): integer;
function  NewRider (const SectionName: myAStr): IRider;


var
  DumpSavegameSectionsOpt: boolean;


(***) implementation (***)


uses
  Erm,
  Trans;


type
  TStoredData = class
    Data:       myAStr;
    ReadingPos: integer;
  end;

  // Cached I/O for sections
  TRider = class (TInterfacedObject, IRider)
   public
    constructor Create (const aSectionName: myAStr);
    destructor  Destroy; override;

    procedure Write (Size: integer; {n} Addr: pbyte);
    procedure WriteByte (Value: byte);
    procedure WriteInt (Value: integer);
    procedure WriteStr (const Str: myAStr);
    procedure WritePchar ({n} Str: myPChar);
    function  Read (Size: integer; {n} Addr: pbyte): integer;

    // if nothing to read, returns 0
    function  ReadByte: byte;

    // if nothing to read, returns 0
    function  ReadInt: integer;

    // if nothing to read, return ''
    function  ReadStr: myAStr;

    procedure Flush;

   private
    fSectionName:     myAStr;
    fReadingBuf:      array [0..8149] of byte;
    fWritingBuf:      array [0..8149] of byte;
    fReadingBufPos:   integer; // Starts from zero
    fWritingBufPos:   integer; // Starts from zero
    fBytesToReadLeft: integer;
  end; // .class TRider

  TSavegameWriteCrashDetective = record
    LastSectionName: myAStr;
    LastDataSize:    integer;
    TotalDataSize:   integer;
  end;


var
{O} WritingStorage: {O} TAssocArray {OF SectionName => StrLib.TStrBuilder};
{O} ReadingStorage: {O} TAssocArray {OF SectionName => StoredData: TStoredData};
    ZeroBuf:        myAStr;

    (* Investigate bug: crash during saving game, probably on _LStrAssign
       Candidates: out-of-memory error, StrBuilder.ToString, or internal bug *)
    SavegameWriteCrashDetective: record
      LastSectionName: myAStr;
      LastDataPtr:     pointer;
      LastDataSize:    integer;
      TotalDataSize:   integer;
    end;


procedure WriteSavegameSection (DataSize: integer; {n} Data: pointer; const SectionName: myAStr);
var
{U} Section: StrLib.TStrBuilder;

begin
  {!} Assert(UtilsB2.IsValidBuf(Data, DataSize), Legacy.Format('An attempt to write wrong buffer data at 0x%x of size %d to section "%s"', [integer(Data), DataSize, SectionName]));
  Section := nil;
  // * * * * * //
  if DataSize > 0 then begin
    with SavegameWriteCrashDetective do begin
      LastSectionName := SectionName;
      LastDataPtr     := Data;
      LastDataSize    := DataSize;
      Inc(TotalDataSize, DataSize);
    end;

    Section := WritingStorage[SectionName];

    if Section = nil then begin
      Section                     := StrLib.TStrBuilder.Create;
      WritingStorage[SectionName] := Section;
    end;

    Section.AppendBuf(DataSize, Data);

    if DumpSavegameSectionsOpt then begin
      Files.AppendFileContents(StrLib.BufToStr(Data, DataSize), GameExt.GameDir + '\' + DUMP_SAVEGAME_SECTIONS_DIR + '\' + SectionName + '.chunks.txt');
    end;
  end; // .if
end;

function ReadSavegameSection (DataSize: integer; {n} Dest: pointer; const SectionName: myAStr): integer;
var
{U} Section: TStoredData;

begin
  {!} Assert(UtilsB2.IsValidBuf(Dest, DataSize));
  Section := nil;
  // * * * * * //
  result := 0;

  if DataSize > 0 then begin
    Section := ReadingStorage[SectionName];

    if Section <> nil then begin
      result := Math.Min(DataSize, Length(Section.Data) - Section.ReadingPos);
      UtilsB2.CopyMem(result, pointer(@Section.Data[1 + Section.ReadingPos]), Dest);
      Inc(Section.ReadingPos, result);
    end;
  end;
end;

constructor TRider.Create (const aSectionName: myAStr);
begin
  fSectionName     := aSectionName;
  fReadingBufPos   := 0;
  fWritingBufPos   := 0;
  fBytesToReadLeft := 0;
end;

destructor TRider.Destroy;
begin
  Self.Flush;

  inherited Destroy;
end;

procedure TRider.Flush;
begin
  WriteSavegameSection(Self.fWritingBufPos, @Self.fWritingBuf[0], Self.fSectionName);
  Self.fWritingBufPos := 0;
end;

procedure TRider.Write (Size: integer; {n} Addr: pbyte);
begin
  {!} Assert(UtilsB2.IsValidBuf(Addr, Size));

  if Size > 0 then begin
    // if no more space in cache - flush the cache
    if sizeof(Self.fWritingBuf) - Self.fWritingBufPos < Size then begin
      Self.Flush;
    end;

    // if it's enough space in cache to hold passed data then write data to cache
    if sizeof(Self.fWritingBuf) - Self.fWritingBufPos >= Size then begin
      UtilsB2.CopyMem(Size, Addr, @Self.fWritingBuf[Self.fWritingBufPos]);
      Inc(Self.fWritingBufPos, Size);
    end
    // else cache is too small, write directly to section
    else begin
      WriteSavegameSection(Size, Addr, Self.fSectionName);
    end;
  end;
end;

procedure TRider.WriteByte (Value: byte);
begin
  Self.Write(sizeof(Value), @Value);
end;

procedure TRider.WriteInt (Value: integer);
begin
  Self.Write(sizeof(Value), @Value);
end;

procedure TRider.WriteStr (const Str: myAStr);
var
  StrLen: integer;

begin
  StrLen := Length(Str);
  Self.WriteInt(StrLen);

  if StrLen > 0 then begin
    Self.Write(StrLen, pointer(Str));
  end;
end;

procedure TRider.WritePchar ({n} Str: myPChar);
var
  StrLen: integer;

begin
  StrLen := 0;

  if Str <> nil then begin
    StrLen := Windows.LStrLenA(Str);
  end;

  Self.WriteInt(StrLen);

  if StrLen > 0 then begin
    Self.Write(StrLen, pointer(Str));
  end;
end;

function TRider.Read (Size: integer; {n} Addr: pbyte): integer;
var
  NumBytesToCopy: integer;

begin
  {!} Assert(UtilsB2.IsValidBuf(Addr, Size));
  result := 0;

  if Size > 0 then begin
    // if there is some data in cache
    if Self.fBytesToReadLeft > 0 then begin
      result := Math.Min(Size, Self.fBytesToReadLeft);
      UtilsB2.CopyMem(result, @Self.fReadingBuf[Self.fReadingBufPos], Addr);
      Dec(Size,                  result);
      Dec(Self.fBytesToReadLeft, result);
      Inc(pbyte(Addr),           result);
      Inc(Self.fReadingBufPos,   result);
    end;

    // if client expects more data to be read than it's in cache. Cache is empty
    if Size > 0 then begin
      // if requested data chunk is too big, no sense to cache it
      if Size >= sizeof(Self.fReadingBuf) then begin
        Inc(result, ReadSavegameSection(Size, Addr, Self.fSectionName));
      end // .if
      // try to fill cache with New data and pass its portion to the client
      else begin
        Self.fBytesToReadLeft := ReadSavegameSection(sizeof(Self.fReadingBuf), @Self.fReadingBuf[0], Self.fSectionName);

        if Self.fBytesToReadLeft > 0 then begin
          NumBytesToCopy := Math.Min(Size, Self.fBytesToReadLeft);
          UtilsB2.CopyMem(NumBytesToCopy, @Self.fReadingBuf[0], Addr);
          Self.fReadingBufPos := NumBytesToCopy;
          Dec(Self.fBytesToReadLeft, NumBytesToCopy);
          Inc(result, NumBytesToCopy);
        end;
      end; // .else
    end; // .if
  end; // .if
end; // .procedure TRider.Read

function TRider.ReadByte: byte;
var
  NumBytesRead: integer;

begin
  result       := 0;
  NumBytesRead := Read(sizeof(result), @result);
  {!} Assert((NumBytesRead = sizeof(result)) or (NumBytesRead = 0));
end;

function TRider.ReadInt: integer;
var
  NumBytesRead: integer;

begin
  result       := 0;
  NumBytesRead := Read(sizeof(result), @result);
  {!} Assert((NumBytesRead = sizeof(result)) or (NumBytesRead = 0));
end;

function TRider.ReadStr: myAStr;
var
  StrLen:       integer;
  NumBytesRead: integer;

begin
  StrLen := Self.ReadInt;
  {!} Assert(StrLen >= 0);
  SetLength(result, StrLen);

  if StrLen > 0 then begin
    NumBytesRead := Read(StrLen, pointer(result));
    {!} Assert(NumBytesRead = StrLen);
  end;
end;

function NewRider (const SectionName: myAStr): IRider;
begin
  result := TRider.Create(SectionName);
end;

constructor TMemWriter.Create;
begin
  Self.fDataBuilder := TStrBuilder.Create;
end;

destructor TMemWriter.Destroy;
begin
  Legacy.FreeAndNil(Self.fDataBuilder);
end;

procedure TMemWriter.Write (Size: integer; {n} Addr: pbyte);
begin
  Self.fDataBuilder.AppendBuf(Size, Addr);
end;

procedure TMemWriter.WriteByte (Value: byte);
begin
  Self.fDataBuilder.WriteByte(Value);
end;

procedure TMemWriter.WriteInt (Value: integer);
begin
  Self.fDataBuilder.WriteInt(Value);
end;

procedure TMemWriter.WriteStr (const Str: myAStr);
begin
  Self.fDataBuilder.WriteInt(Length(Str));
  Self.fDataBuilder.Append(Str);
end;

procedure TMemWriter.WritePchar ({n} Str: myPchar);
var
  StrLen: integer;

begin
  StrLen := 0;

  if Str <> nil then begin
    StrLen := Windows.LStrLenA(Str);
  end;

  Self.fDataBuilder.WriteInt(StrLen);

  if StrLen > 0 then begin
    Self.fDataBuilder.AppendBuf(StrLen, pointer(Str));
  end;
end;

procedure TMemWriter.Flush;
begin
  // Do nothing
end;

function TMemWriter.Read (Size: integer; {n} Addr: pbyte): integer;
begin
  {!} Assert(false, 'TMemWriter.Read is not implemented');
  result := 0;
end;

function TMemWriter.ReadByte: byte;
begin
  {!} Assert(false, 'TMemWriter.ReadByte is not implemented');
  result := 0;
end;

function TMemWriter.ReadInt: integer;
begin
  {!} Assert(false, 'TMemWriter.ReadInt is not implemented');
  result := 0;
end;

function TMemWriter.ReadStr: myAStr;
begin
  {!} Assert(false, 'TMemWriter.ReadStr is not implemented');
  result := '';
end;

function TMemWriter.BuildBuf: UtilsB2.TArrayOfByte;
begin
  result := Self.fDataBuilder.BuildBuf;
end;

constructor TMemReader.Create (BufSize: integer; {Un} Buf: pointer);
begin
  Self.fReader := StrLib.BufAsByteSource(Buf, BufSize);
end;

procedure TMemReader.Write (Size: integer; {n} Addr: pbyte);
begin
  {!} Assert(false, 'TMemReader.Write is not implemented');
end;

procedure TMemReader.WriteByte (Value: byte);
begin
  {!} Assert(false, 'TMemReader.WriteByte is not implemented');
end;

procedure TMemReader.WriteInt (Value: integer);
begin
  {!} Assert(false, 'TMemReader.WriteInt is not implemented');
end;

procedure TMemReader.WriteStr (const Str: myAStr);
begin
  {!} Assert(false, 'TMemReader.WriteStr is not implemented');
end;

procedure TMemReader.WritePchar ({n} Str: myPchar);
begin
  {!} Assert(false, 'TMemReader.WritePchar is not implemented');
end;

procedure TMemReader.Flush;
begin
  // Do nothing
end;

function TMemReader.Read (Size: integer; {n} Addr: pbyte): integer;
begin
  result := Self.fReader.Read(Size, Addr);
end;

function TMemReader.ReadByte: byte;
var
  NumBytesRead: integer;

begin
  result       := 0;
  NumBytesRead := Self.fReader.Read(sizeof(result), @result);
  {!} Assert((NumBytesRead = sizeof(result)) or (NumBytesRead = 0));
end;

function TMemReader.ReadInt: integer;
var
  NumBytesRead: integer;

begin
  result       := 0;
  NumBytesRead := Self.fReader.Read(sizeof(result), @result);
  {!} Assert((NumBytesRead = sizeof(result)) or (NumBytesRead = 0));
end;

function TMemReader.ReadStr: myAStr;
var
  StrLen:       integer;
  NumBytesRead: integer;

begin
  StrLen := Self.ReadInt;
  {!} Assert(StrLen >= 0);
  SetLength(result, StrLen);

  if StrLen > 0 then begin
    NumBytesRead := Self.fReader.Read(StrLen, pointer(result));
    {!} Assert(NumBytesRead = StrLen);
  end;
end;

function Hook_SaveGame (Context: ApiJack.PHookContext): longbool; stdcall;
const
  PARAM_SAVEGAME_NAME = 1;

var
{U} OldSavegameName: myPChar;
{U} SavegameName:    myPChar;
    SavegameNameLen: integer;

begin
  OldSavegameName := ppointer(Context.EBP + 8)^;
  SavegameName    := nil;
  // * * * * * //
  Erm.ArgXVars[PARAM_SAVEGAME_NAME] := integer(OldSavegameName);
  ZvsErmTriggerBeforeSave;
  SavegameName    := Ptr(Erm.RetXVars[PARAM_SAVEGAME_NAME]);
  SavegameNameLen := Legacy.StrLen(SavegameName);

  if SavegameName <> OldSavegameName then begin
    UtilsB2.CopyMem(SavegameNameLen + 1, SavegameName, OldSavegameName);
    PINTEGER(Context.EBP + 12)^ := -1;
  end;

  result := true;
end;

function Hook_SaveGameWrite (Context: ApiJack.PHookContext): longbool; stdcall;
var
{U} StrBuilder:     StrLib.TStrBuilder;
    NumSections:    integer;
    SectionNameLen: integer;
    DataLen:        integer;
    BuiltData:      myAStr;
    TotalWritten:   integer; // Trying to fix game diff algorithm in online games
    IsException:    longbool;

  procedure GzipWrite (Count: integer; {n} Addr: pointer);
  begin
    Inc(TotalWritten, Count);
    Heroes.GzipWrite(Count, Addr);
  end;

begin
  StrBuilder := nil;
  // * * * * * //
  if DumpSavegameSectionsOpt then begin
    Files.DeleteDir(GameExt.GameDir    + '\' + DUMP_SAVEGAME_SECTIONS_DIR);
    Legacy.CreateDir(GameExt.GameDir + '\' + DUMP_SAVEGAME_SECTIONS_DIR);
  end;

  TotalWritten := 0;
  NumSections  := 0;
  IsException  := true;

  try
    WritingStorage.Clear;

    with NewRider(ERA_SAVEGAME_VERSION_SECTION) do begin
      WriteInt(GameExt.ERA_VERSION_INT);
      Flush;
    end;

    Erm.FireErmEventEx(Erm.TRIGGER_SAVEGAME_WRITE, []);
    EventMan.GetInstance.Fire('$OnEraSaveScripts', GameExt.NO_EVENT_DATA, 0);

    NumSections := WritingStorage.ItemCount;
    GzipWrite(sizeof(NumSections), @NumSections);

    with DataLib.IterateDict(WritingStorage) do begin
      while IterNext do begin
        SectionNameLen := Length(IterKey);
        GzipWrite(sizeof(SectionNameLen), @SectionNameLen);
        GzipWrite(SectionNameLen, pointer(IterKey));

        BuiltData := (IterValue as StrLib.TStrBuilder).BuildStr;
        DataLen   := Length(BuiltData);
        GzipWrite(sizeof(DataLen), @DataLen);
        GzipWrite(Length(BuiltData), pointer(BuiltData));

        if DumpSavegameSectionsOpt then begin
          Files.WriteFileContents(BuiltData, DUMP_SAVEGAME_SECTIONS_DIR + '\' + IterKey + '.data');
        end;
      end; // .while
    end; // .with

    IsException := false;
  finally
    if IsException then begin
      with SavegameWriteCrashDetective do begin
        Log.Write('Stores', 'SavegameWrite',
          '(!) Exception is raised during game saving. Report:' + #13#10#13#10 +
          Legacy.Format('NumSections: %d, Last section: %s. Last data ptr: 0x%x. Last data size: %d. Total bytes written: %d.', [
            NumSections,
            LastSectionName,
            integer(LastDataPtr),
            LastDataSize,
            TotalDataSize
          ])
        );
      end;

      // Error notification and ability to save game twice is disabled for now. Crash with valid IP address is preferred currently.
      if false then begin
        DumpSavegameSectionsOpt := true;
        Heroes.ShowMessage(COLOR_TAG_RED + Trans.tr('era.debug.game_saving_exception_warning', []) + '{~}');
      end;
    end;
  end; // .try

  // Default code
  if PINTEGER(Context.EBP - 4)^ = 0 then begin
    Context.RetAddr := Ptr($704EF2);
  end else begin
    Context.RetAddr := Ptr($704F10);
  end;

  result := false;
end; // .function Hook_SaveGameWrite

function Hook_SaveGameRead (Context: ApiJack.PHookContext): longbool; stdcall;
var
{U} StoredData:      TStoredData;
    BytesRead:       integer;
    NumSections:     integer;
    SectionNameLen:  integer;
    SectionName:     myAStr;
    DataLen:         integer;
    SectionData:     myAStr;
    SavegameVersion: integer;
    i:               integer;

  procedure ForceGzipRead (Count: integer; {n} Addr: pointer);
  begin
    BytesRead := Heroes.GzipRead(Count, Addr);
    {!} Assert(BytesRead = Count);
  end;

begin
  StoredData := nil;
  // * * * * * //
  ReadingStorage.Clear;
  NumSections := 0;
  BytesRead   := Heroes.GzipRead(sizeof(NumSections), @NumSections);
  {!} Assert((BytesRead = sizeof(NumSections)) or (BytesRead = 0), 'Failed to read NumSections:integer from saved game');

  for i := 1 to NumSections do begin
    ForceGzipRead(sizeof(SectionNameLen), @SectionNameLen);
    {!} Assert(SectionNameLen >= 0);
    SetLength(SectionName, SectionNameLen);
    ForceGzipRead(SectionNameLen, pointer(SectionName));

    ForceGzipRead(sizeof(DataLen), @DataLen);
    {!} Assert(DataLen >= 0);
    SetLength(SectionData, DataLen);
    ForceGzipRead(DataLen, pointer(SectionData));

    StoredData                  := TStoredData.Create;
    StoredData.Data             := SectionData; SectionData := '';
    StoredData.ReadingPos       := 0;
    ReadingStorage[SectionName] := StoredData;
  end; // .for

  with NewRider(ERA_SAVEGAME_VERSION_SECTION) do begin
    SavegameVersion := ReadInt;

    if SavegameVersion < SAVEGAME_MIN_VERSION then begin
      Heroes.ShowMessage(COLOR_TAG_RED + Trans.tr('era.incompatible_savegame_version_warning', [
        'old_version', Legacy.IntToStr(SavegameVersion), 'current_version', Legacy.IntToStr(GameExt.ERA_VERSION_INT)
      ]) + '{~}');
    end else begin
      EventMan.GetInstance.Fire('$OnEraLoadScripts', GameExt.NO_EVENT_DATA, 0);
      Erm.FireErmEventEx(Erm.TRIGGER_SAVEGAME_READ, []);
    end;
  end;


  // default code
  if PINTEGER(Context.EBP - $14)^ = 0 then begin
    Context.RetAddr := Ptr($7051BE);
  end else begin
    Context.RetAddr := Ptr($7051DC);
  end;

  result := false;
end; // .function Hook_SaveGameRead

procedure OnLoadEraSettings (Event: GameExt.PEvent); stdcall;
begin
  DumpSavegameSectionsOpt := EraSettings.GetDebugBoolOpt('Debug.DumpSavegameSections', false);
end;

procedure OnAfterWoG (Event: GameExt.PEvent); stdcall;
begin
  ApiJack.Hook(Ptr($4BEB65), @Hook_SaveGame);
  ApiJack.Hook(Ptr($704EEC), @Hook_SaveGameWrite, nil, 6);
  ApiJack.Hook(Ptr($7051B8), @Hook_SaveGameRead, nil, 6);

  (* Remove Erm trigger "BeforeSaveGame" call *)
  PatchApi.p.WriteDataPatch(Ptr($7051F5), [myAStr('9090909090')]);
end;

begin
  WritingStorage := AssocArrays.NewStrictAssocArr(StrLib.TStrBuilder);
  ReadingStorage := AssocArrays.NewStrictAssocArr(TStoredData);
  EventMan.GetInstance.On('$OnLoadEraSettings', OnLoadEraSettings);
  EventMan.GetInstance.On('OnAfterWoG', OnAfterWoG);
end.
