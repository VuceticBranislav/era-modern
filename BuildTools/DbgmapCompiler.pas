unit DbgmapCompiler;

interface

uses
  SysUtils, StrUtils, Classes, Generics.Collections, Character, Utils;

type

  TPESection = record
    Address : Cardinal;
    Types   : string;
    Size    : Cardinal;
  end;

  TSegment = record
    Id      : Integer;
    Address : string;
  end;

  TLine = record
    ModuleId    : Integer;
    LineNumber  : Integer;
  end;

  TMapCompiler = class
  private
    BaseAddress   : Integer;
    LineId        : Integer;
    FSourceSize   : Integer;
    FCompiledSize : Integer;
    FConverted    : TMemoryStream;
    Modules       : TStringList;
    Lines         : TStringList;
    PESections    : TDictionary<Integer, TPESection>;
    Labels        : TDictionary<Integer, string>;
    LineNumbers   : TDictionary<Integer, TLine>;
    procedure PrepareForCompilation;
    procedure ReadMapFile(MapFileName: string);
    procedure ProcessSections;
    procedure ProcessStartSection;
    procedure ProcessStartSectionLines;
    procedure ProcessDetailedMapOfSectionsSection;
    procedure ProcessAddressSection;
    procedure ProcessLineNumbersSection;
    procedure ProcessLineNumbersSectionLines(ModuleInd: Integer);
    procedure WriteLabelsSection;
    procedure WriteModulesList;
    procedure WriteLineNumbersSection;
    procedure WriteStr(const Value: string);
    procedure WriteInt(const Value: Integer);
    procedure FailMessage(const Msg: string); overload;
    procedure FailMessage(const Msg: string; const Arguments: array of TVarRec); overload;
    function IsSection(Name: string = ''): Boolean;
    function IsDataLine: Boolean;
    function GotoNextSection: Boolean;
    function ReadSectionName: string;
    function SplitNextRowToValues: TStringList;
    function ReadIniCol(const ParamName: string; const Values: TStringList): string;
    function ReadLine: string;
    function GotoNextLine: Boolean;
    function EndOfFile: Boolean;
    function ParseComplexAddress(const ComplexAddr: string; out SegmentId: Cardinal): Cardinal; overload;
    function ParseComplexAddress(const ComplexAddr: string): Cardinal; overload;
    function ParseComplexField(const Address: string; const Separator: string = ':'): TSegment;
    function ParseAddress(const Address: string): Cardinal;
    function AlignSectionAddr(Address: Integer): Integer;
  public
    procedure Compile(const MapFileName: string);
    procedure SaveToFile(const OutputPath: string);
    property SourceSize: Integer read FSourceSize;
    property CompiledSize: Integer read FCompiledSize;
  end;

implementation

procedure TMapCompiler.Compile(const MapFileName: string);
begin
    PrepareForCompilation;
    ReadMapFile(MapFileName);
    ProcessSections;
    WriteLabelsSection;
    WriteModulesList;
    WriteLineNumbersSection;
    FCompiledSize := FConverted.Size;
end;

procedure TMapCompiler.SaveToFile(const OutputPath: string);
begin
    FConverted.SaveToFile(OutputPath);
end;

procedure TMapCompiler.PrepareForCompilation;
begin
    FConverted   := TMemoryStream.Create;
    LineId       := 0;
    BaseAddress  := 0;
    FSourceSize  := 0;
    FCompiledSize:= 0;
    Modules      := TStringList.Create;
    Lines        := TStringList.Create;
    PESections   := TDictionary<Integer, TPESection>.Create;
    Labels       := TDictionary<Integer, string>.Create;
    LineNumbers  := TDictionary<Integer, TLine>.Create;
end;

procedure TMapCompiler.ReadMapFile(MapFileName: string);
var
    Reader : TStreamReader;
begin
    Reader := TStreamReader.Create(MapFileName);
    try
      Lines.BeginUpdate;
      try
        Lines.Clear;
        while not Reader.EndOfStream do
          Lines.Add(Trim(Reader.ReadLine));
      finally
        Lines.EndUpdate;
      end;
      FSourceSize := Reader.BaseStream.Size;
    finally
      Reader.Free;
    end;
end;

procedure TMapCompiler.ProcessSections;
begin
    while not EndOfFile do
    begin
      if not IsSection then
        GotoNextSection
      else if IsSection('Start ') then
        ProcessStartSection
      else
      begin
        if PESections.Count = 0 then
          FailMessage('Expected "Start" section. Got: %s', [ReadSectionName]);

        if IsSection('Detailed map of segments') then
          ProcessDetailedMapOfSectionsSection
        else if IsSection('Address ') then
          ProcessAddressSection
        else if IsSection('Line numbers for ') then
          ProcessLineNumbersSection
        else
          GotoNextSection;
      end;
    end;
end;

procedure TMapCompiler.ProcessStartSection;
var
    Address, I: Cardinal;
    PESectionItem: TPESection;
begin
    if PESections.Count > 0 then
      FailMessage('Duplicate start section');

    GotoNextLine;
    ProcessStartSectionLines;

    if PESections.Count = 0 then
      FailMessage('Invalid start section without any segments');

    Address := $1000;

    for I := 1 to PESections.Count do
    begin
      PESectionItem         := PESections.Items[I];
      PESectionItem.Address := Address;
      PESections.Items[I]   := PESectionItem;
      Address               := AlignSectionAddr(Address + PESectionItem.Size);
    end;
end;

procedure TMapCompiler.ProcessStartSectionLines;
var
    SegmentAddress  : Cardinal;
    SegmentLength   : Cardinal;
    RowValues       : TStringList;
    Segment         : TPESection;
    ComplexAddress  : TSegment;
begin
    while not EndOfFile and IsDataLine do
    begin
      RowValues := SplitNextRowToValues;
      if RowValues.Count < 2 then
        FailMessage('Invalid section line');

      SegmentLength := ParseAddress(RowValues[1]);

      if SegmentLength > 0 then
      begin
        ComplexAddress  := ParseComplexField(RowValues[0]);
        SegmentAddress  := ParseAddress(ComplexAddress.Address);

        Segment.Address := SegmentAddress;
        Segment.Types   := IfThen(RowValues.Count >= 4, RowValues[3], '');
        Segment.Size    := SegmentLength;

        PESections.AddOrSetValue(ComplexAddress.Id, Segment);
      end;

      GotoNextLine;
    end;
end;

procedure TMapCompiler.ProcessDetailedMapOfSectionsSection;
var
    Values      : TStringList;
    ModuleName  : string;
    Address     : Cardinal;
    SegmentId   : Cardinal;
begin
    GotoNextLine;

    while not EndOfFile and IsDataLine do
    begin
      Values    := SplitNextRowToValues;
      ModuleName:= ReadIniCol('M', Values);

      if ModuleName <> '' then
      begin
        Address := ParseComplexAddress(Values[0], SegmentId);
        if Address <> 0 then
        begin
          if PESections.ContainsKey(SegmentId) then
            Labels.Add(Address, ModuleName + ':' + PESections[SegmentId].Types)
          else
            Labels.Add(Address, ModuleName + ':MOD');
        end;
      end;

      GotoNextLine;
    end;
end;

procedure TMapCompiler.ProcessAddressSection;
var
    Values    : TStringList;
    Address   : Cardinal;
    SegmentId : Cardinal;
begin
    GotoNextLine;

    while not EndOfFile and IsDataLine do
    begin
      Values := SplitNextRowToValues;

      if Values.Count > 1 then
      begin
        Address := ParseComplexAddress(Values[0], SegmentId);
        if PESections.ContainsKey(SegmentId) then
          Labels.AddOrSetValue(Address, Values[1]);
      end;

      GotoNextLine;
    end;
end;

procedure TMapCompiler.ProcessLineNumbersSection;
var
    SectionName   : string;
    ModuleFileName: string;
    ModuleName    : string;
    Module        : string;
    ModuleInd     : Integer;
    FromPos       : Integer;
    ToPos         : Integer;
const
    SearchString = 'Line numbers for ';
begin
    SectionName := ReadSectionName;

    FromPos         := StrIPos(SearchString, SectionName) + Length(SearchString);
    ToPos           := StrIPos('(', SectionName);
    ModuleName      := Copy(SectionName, FromPos, ToPos - FromPos);
    FromPos         := ToPos + 1;
    ToPos           := StrIPos(')', SectionName);
    ModuleFileName  := Copy(SectionName, FromPos, ToPos - FromPos);

    if ModuleName = '' then
    begin
      GotoNextSection;
      Exit;
    end;

    if ModuleFileName <> '' then
      Module := ModuleFileName
    else
      Module := ModuleName;

    ModuleInd := Modules.IndexOf(Module);
    if ModuleInd = -1 then
      ModuleInd := Modules.Add(Module);

    GotoNextLine;
    ProcessLineNumbersSectionLines(ModuleInd);
end;

procedure TMapCompiler.ProcessLineNumbersSectionLines(ModuleInd: Integer);
var
    LineId  : Integer;
    Values  : TStringList;
    Address : Integer;
    NewLine : TLine;
    I       : Cardinal;
begin
    while not EndOfFile and IsDataLine do
    begin
      Values := SplitNextRowToValues;

      for I := 0 to Values.Count div 2 - 1 do
      begin
        LineId  := StrToInt(Values[I * 2]);
        Address := ParseComplexAddress(Values[I * 2 + 1]);

        if Address <> 0 then
        begin
          NewLine.ModuleId   := ModuleInd;
          NewLine.LineNumber := LineId;
          LineNumbers.AddOrSetValue(Address, NewLine);
        end;
      end;

      GotoNextLine;
    end;
end;

procedure TMapCompiler.WriteLabelsSection;
var
    LabelsList: TList<Integer>;
    Address   : Integer;
begin
    LabelsList := TList<Integer>.Create;
    try
      LabelsList.AddRange(Labels.Keys);
      LabelsList.Sort;
      LabelsList.Add(LabelsList[0]);
      LabelsList.Remove(0);

      WriteInt(LabelsList.Count);

      for Address in LabelsList do
      begin
        WriteInt(Address);
        WriteStr(Labels[Address]);
      end;

    finally
      LabelsList.Free;
    end;
end;

procedure TMapCompiler.WriteModulesList;
var
    ModuleName: string;
begin
    WriteInt(Modules.Count);

    for ModuleName in Modules do
      WriteStr(ModuleName);
end;

procedure TMapCompiler.WriteLineNumbersSection;
var
    I       : Integer;
    Address : TLine;
    Keys    : TList<Integer>;
begin
    Keys := TList<Integer>.Create;
    Keys.AddRange(LineNumbers.Keys);
    Keys.Sort;

    WriteInt(LineNumbers.Count);

    for I in Keys do
    begin
      Address := LineNumbers[I];
      WriteInt(I);
      WriteInt(Address.ModuleId);
      WriteInt(Address.LineNumber);
    end;
end;

procedure TMapCompiler.WriteStr(const Value: string);
var
    Str: AnsiString;
begin
    Str := AnsiString(Value);
    WriteInt(Length(Str));
    FConverted.WriteBuffer(PAnsiChar(Str)^, Length(Str))
end;

procedure TMapCompiler.WriteInt(const Value: Integer);
begin
    FConverted.Write(Value, SizeOf(Value));
end;

procedure TMapCompiler.FailMessage(const Msg: string);
begin
    Log('%s. Error on line %d. Content: %s', [Msg, LineId+1, Lines[LineId]]);
    raise Exception.Create('Operation aborted.');
end;

procedure TMapCompiler.FailMessage(const Msg: string; const Arguments: array of TVarRec);
begin
    FailMessage(Format(Msg, Arguments));
end;

function TMapCompiler.IsSection(Name: string = ''): Boolean;
var
    SectionName: string;
begin
    SectionName := ReadSectionName();
    if Name <> '' then
      Result := (SectionName <> '') and (StrIPos(Name, sectionName) = 1)
    else
      Result := SectionName <> '';
end;

function TMapCompiler.IsDataLine: Boolean;
begin
    Result := not IsSection();
end;

function TMapCompiler.GotoNextSection: Boolean;
begin
    while GotoNextLine and (ReadSectionName = '') do
    begin
      // Next
    end;

    Result := not EndOfFile;
end;

function TMapCompiler.ReadSectionName: string;
var
    Line: string;
begin
    Line := Lines[LineId];
    if Line <> '' then
      if Line[1].IsLetter then
        Exit(Line);
    Result := '';
end;

function TMapCompiler.ReadIniCol(const ParamName: string; const Values: TStringList): string;
var
    SearchPrefix: string;
    Value       : string;
begin
    SearchPrefix := ParamName + '=';

    for Value in Values do
      if StartsText(SearchPrefix, Value) then
        Exit(Copy(Value, Length(SearchPrefix) + 1, Length(Value)));

    Result := '';
end;

function TMapCompiler.SplitNextRowToValues: TStringList;
begin
    Result := TStringList.Create;
    Result.StrictDelimiter := True;
    ExtractStrings([' '], [], PChar(ReadLine), Result);
end;

function TMapCompiler.ReadLine: string;
begin
    if (LineId >= 0) and (LineId < Lines.Count) then
      Result := Lines[LineId]
    else
      FailMessage('Map EOF reached');
end;

function TMapCompiler.GotoNextLine: Boolean;
begin
    Inc(LineId);

    if LineId >= Lines.Count - 1 then
    begin
      LineId := Lines.Count;
      Exit(False);
    end;

    while (Lines[LineId] = '') do
      Inc(LineId);

    Result := Lines[LineId] <> '';
    if not Result then
      LineId := Lines.Count;
end;

function TMapCompiler.EndOfFile: Boolean;
begin
    Result := LineId >= Lines.Count;
end;

function TMapCompiler.ParseComplexAddress(const ComplexAddr: string; out SegmentId: Cardinal): Cardinal;
var
    Segment: TSegment;
begin
    Segment   := ParseComplexField(ComplexAddr);
    SegmentId := Segment.Id;

    if PESections.ContainsKey(Segment.Id) then
      Result := PESections[Segment.Id].Address + ParseAddress(Segment.Address)
    else
      Result := 0;
end;

function TMapCompiler.ParseComplexAddress(const ComplexAddr: string): Cardinal;
var
    Dummy: Cardinal;
begin
    Result := ParseComplexAddress(ComplexAddr, Dummy);
end;

function TMapCompiler.ParseComplexField(const Address: string; const Separator: string = ':'): TSegment;
var
    Fields: TArray<string>;
begin
    Fields := SplitString(Address, Separator);

    if Length(Fields) <= 1 then
      FailMessage('Field "%s" is not a valid complex field with "%s" subfield separator', [Address, Separator]);

    Result.Id      := StrToInt(Fields[0]);
    Result.Address := Fields[1];
end;

function TMapCompiler.ParseAddress(const Address: string): Cardinal;
begin
    Result := StrToUIntDef('$' + Address.TrimRight(['H']), 0);
end;

function TMapCompiler.AlignSectionAddr(Address: Integer): Integer;
begin
    Result := Ceil(Address / $1000) * $1000;
end;

end.
