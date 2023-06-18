unit DebugMaps;
{
DESCRIPTION:  Adds support for *.dbgmap binary debug map files. Allows to convert offset from PE module
              base into human-readable label with possible source file/line information.
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

interface

uses
  SysUtils, UtilsB2, Math, Legacy;

const
  MIN_DBGMAP_FILE_SIZE = 12;

type
  TDebugMapLabel = record
    Offset: integer;
    Name:   myAStr;
  end;

  TDebugMapModule = record
    Name: myAStr;
  end;

  TDebugMapLineInfo = record
    Offset:    integer;
    ModuleInd: integer;
    Line:      integer;
  end;

  TDebugMap = class
   protected
    Labels:    array of TDebugMapLabel;
    Modules:   array of TDebugMapModule;
    LineInfos: array of TDebugMapLineInfo;

   public
    function  IsEmpty: boolean;
    procedure LoadFromString (const MapContents: myAStr);
    function  GetReadableAddr (Offset: integer): myAStr;
  end; // .class TDebugMap


implementation

function TDebugMap.IsEmpty: boolean;
begin
  result := (Self.Labels = nil) and (Self.Modules = nil) and (Self.LineInfos = nil);
end;

procedure TDebugMap.LoadFromString (const MapContents: myAStr);
var
  {U} DataPtr:         pointer;
      NumLabels:       integer;
      NumModules:      integer;
      NumLineInfoRecs: integer;
      i:               integer;

  function ReadInt: integer;
  begin
    result  := pinteger(DataPtr)^;
    DataPtr := UtilsB2.PtrOfs(DataPtr, sizeof(integer));
  end;

  function ReadStr: myAStr;
  var
    StrLen: integer;

  begin
    result := '';
    StrLen := ReadInt();
    SetLength(result, StrLen);

    if StrLen > 0 then begin
      UtilsB2.CopyMem(StrLen, DataPtr, @result[1]);
      DataPtr := UtilsB2.PtrOfs(DataPtr, StrLen);
    end;
  end; // .function ReadStr

begin
  DataPtr := nil;
  // * * * * * //
  Self.Labels    := nil;
  Self.Modules   := nil;
  Self.LineInfos := nil;

  if length(MapContents) > 0 then begin
    DataPtr := @MapContents[1];

    (* Read Labels section *)

    NumLabels := ReadInt();
    {!} Assert(NumLabels >= 0);
    SetLength(Self.Labels, NumLabels);

    for i := 0 to NumLabels - 1 do begin
      Self.Labels[i].Offset := ReadInt();
      Self.Labels[i].Name   := ReadStr();
    end;

    (* Read Modules section *)

    NumModules := ReadInt();
    {!} Assert(NumModules >= 0);
    SetLength(Self.Modules, NumModules);

    for i := 0 to NumModules - 1 do begin
      Self.Modules[i].Name := ReadStr();
    end;

    (* Read Line Numbers section *)

    NumLineInfoRecs := ReadInt();
    {!} Assert(NumLineInfoRecs >= 0);
    SetLength(Self.LineInfos, NumLineInfoRecs);

    for i := 0 to NumLineInfoRecs - 1 do begin
      Self.LineInfos[i].Offset    := ReadInt();
      Self.LineInfos[i].ModuleInd := ReadInt();
      Self.LineInfos[i].Line      := ReadInt();
    end;
  end; // .if
end; // .procedure TDebugMap.LoadFromString

function TDebugMap.GetReadableAddr (Offset: integer): myAStr;
var
  Left:          integer;
  Right:         integer;
  MiddleInd:     integer;
  MiddleLabel:   TDebugMapLabel;
  MiddleLineRec: TDebugMapLineInfo;
  LabelOffset:   integer;
  LineOffset:    integer;

begin
  if Self.Labels <> nil then begin
    Left      := 0;
    Right     := high(Self.Labels);
    MiddleInd := -1;

    while Left <= Right do begin
      MiddleInd   := Left + (Right - Left) div 2;
      MiddleLabel := Self.Labels[MiddleInd];

      if uint(Offset) < uint(MiddleLabel.Offset) then begin
        Right := MiddleInd - 1;
      end else if uint(Offset) > uint(MiddleLabel.Offset) then begin
        Left  := MiddleInd + 1;
      end else begin
        break;
      end;
    end; // .while
    
    if (Left <= Right) or (Right >= 0) then begin
      LabelOffset := Offset - Self.Labels[Right].Offset;
      result      := Self.Labels[Right].Name;

      if LabelOffset > 0 then begin
        result := result + ' + ' + Legacy.IntToStr(uint(LabelOffset));
      end;
    end;
  end; // .if

  if Self.LineInfos <> nil then begin
    Left      := 0;
    Right     := high(Self.LineInfos);
    MiddleInd := -1;

    while Left <= Right do begin
      MiddleInd     := Left + (Right - Left) div 2;
      MiddleLineRec := Self.LineInfos[MiddleInd];

      if uint(Offset) < uint(MiddleLineRec.Offset) then begin
        Right := MiddleInd - 1;
      end else if uint(Offset) > uint(MiddleLineRec.Offset) then begin
        Left  := MiddleInd + 1;
      end else begin
        break;
      end;
    end; // .while
    
    if ((Left <= Right) or (Right >= 0)) and Math.InRange(Self.LineInfos[Right].ModuleInd, 0, length(Self.Modules) - 1) then begin
      LineOffset := Offset - Self.LineInfos[Right].Offset;

      if result <> '' then begin
        result := result + ' ';
      end;
      
      result := result + 'in ' + Self.Modules[Self.LineInfos[Right].ModuleInd].Name + ' on line ' + Legacy.IntToStr(uint(Self.LineInfos[Right].Line));

      if LineOffset > 0 then begin
        result := result + ' offset ' + Legacy.IntToStr(uint(LineOffset));
      end;
    end; // .if
  end; // .if
end; // .function TDebugMap.GetReadableAddr

end.