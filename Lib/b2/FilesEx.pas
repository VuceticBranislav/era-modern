unit FilesEx;
(*
  DESCRIPTION:  High-level finctions for working with files
  AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
*)

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

(***)  interface  (***)
uses Legacy, SysUtils, UtilsB2, Files, DataLib, StrLib, Classes, DataFlows;

type
  (* Import *)
  TStrList    = DataLib.TStrList;
  TDict       = DataLib.TDict;
  TSearchSubj = Files.TSearchSubj;

  (*
    Provides means for formatted output to external storage.
    It's recommended to internally use StrBuilder for file output.
    Default indentation must be '  ', line end marker - #13#10.
  *)
  IFormattedOutput = interface
    procedure SetIndentation (const Identation: myAStr);
    procedure SetLineEndMarker (const aLineEndMarker: myAStr);

    // Increase or decrease indentation
    procedure Indent;
    procedure Unindent;
    procedure SetIndentLevel (Level: integer);
    
    procedure Write (const Str: myAStr);
    // Same as Write + Write([line end marker])
    procedure WriteIndentation;
    procedure RawLine (const Str: myAStr);
    // Same as Write([indentation]) * [indent level] + RawLine(Str)
    procedure Line (const Str: myAStr);
    // Same as Write([line end marker])
    procedure EmptyLine;

    property Indentation:   myAStr write SetIndentation;
    property LineEndMarker: myAStr write SetLineEndMarker;
  end; // .interface IFormattedOutput

  TFileFormattedOutput = class (TInterfacedObject, IFormattedOutput)
   protected
    {O} fOutputBuf:     StrLib.TStrBuilder;
        fFilePath:      myAStr;
        fIndentation:   myAStr;
        fIndentLevel:   integer;
        fLineEndMarker: myAStr;

   public
    constructor Create (const aFilePath: myAStr);
    destructor Destroy; override;

    procedure SetIndentation (const aIndentation: myAStr);
    procedure SetLineEndMarker (const aLineEndMarker: myAStr);
    procedure Indent;
    procedure Unindent;
    procedure SetIndentLevel (Level: integer);
    procedure WriteIndentation;
    procedure Write (const Str: myAStr);
    procedure RawLine (const Str: myAStr);
    procedure Line (const Str: myAStr);
    procedure EmptyLine;
  end; // .class TFileFormattedOutput
  

// List does not own its objects. It simply contains case insensitive file names
function  GetFileList (const MaskedPath: myAStr; SearchSubj: TSearchSubj): {O} TStrList;
procedure MergeFileLists (MainList, DependantList: TStrList);
function  WriteFormattedOutput (const FilePath: myAStr): IFormattedOutput;


(***) implementation (***)


destructor TFileFormattedOutput.Destroy;
begin
  Files.WriteFileContents(fOutputBuf.BuildStr, fFilePath);
  FreeAndNil(fOutputBuf);
  inherited;
end;

procedure TFileFormattedOutput.SetIndentation (const aIndentation: myAStr);
begin
  fIndentation := aIndentation;
end;

procedure TFileFormattedOutput.SetLineEndMarker (const aLineEndMarker: myAStr);
begin
  fLineEndMarker := aLineEndMarker;
end;

procedure TFileFormattedOutput.Indent;
begin
  Inc(fIndentLevel);
end;

procedure TFileFormattedOutput.Unindent;
begin
  if fIndentLevel > 0 then begin
    Dec(fIndentLevel);
  end;
end;

procedure TFileFormattedOutput.SetIndentLevel (Level: integer);
begin
  if Level <= 0 then begin
    fIndentLevel := 0;
  end else begin
    fIndentLevel := Level;
  end;
end;

procedure TFileFormattedOutput.WriteIndentation;
var
  i: integer;

begin
  for i := 1 to fIndentLevel do begin
    fOutputBuf.Append(fIndentation);
  end;
end;

procedure TFileFormattedOutput.Write (const Str: myAStr);
begin
  fOutputBuf.Append(Str);
end;

procedure TFileFormattedOutput.RawLine (const Str: myAStr);
begin
  fOutputBuf.Append(Str);
  fOutputBuf.Append(fLineEndMarker);
end;

procedure TFileFormattedOutput.Line (const Str: myAStr);
var
  i: integer;

begin
  for i := 1 to fIndentLevel do begin
    fOutputBuf.Append(fIndentation);
  end;

  fOutputBuf.Append(Str);
  fOutputBuf.Append(fLineEndMarker);
end; // .procedure TFileFormattedOutput.Line

procedure TFileFormattedOutput.EmptyLine;
begin
  fOutputBuf.Append(fLineEndMarker);
end;

constructor TFileFormattedOutput.Create (const aFilePath: myAStr);
begin
  fFilePath      := aFilePath;
  fOutputBuf     := StrLib.TStrBuilder.Create;
  fIndentation   := '  ';
  fIndentLevel   := 0;
  fLineEndMarker := #13#10;
end;

function GetFileList (const MaskedPath: myAStr; SearchSubj: TSearchSubj): {O} TStrList;
begin
  result := DataLib.NewStrList(not UtilsB2.OWNS_ITEMS, DataLib.CASE_INSENSITIVE);
  
  with Files.Locate(MaskedPath, SearchSubj) do begin
    while FindNext do begin
      result.Add(FoundName);
    end;
  end; 
end;

procedure MergeFileLists (MainList, DependantList: TStrList);
var
{O} NamesDict: TDict {OF FileName: myAStr => Ptr(1)};
    i: integer;
   
begin
  {!} Assert(MainList <> nil);
  {!} Assert(DependantList <> nil);
  NamesDict := DataLib.NewDict(not UtilsB2.OWNS_ITEMS, DataLib.CASE_INSENSITIVE);
  // * * * * * //
  for i := 0 to MainList.Count - 1 do begin
    NamesDict[MainList[i]] := Ptr(1);
  end;
  
  for i := 0 to DependantList.Count - 1 do begin
    if NamesDict[DependantList[i]] = nil then begin
      NamesDict[DependantList[i]] := Ptr(1);
      MainList.Add(DependantList[i]);
    end;
  end;
  // * * * * * //
  SysUtils.FreeAndNil(NamesDict);
end; // .procedure MergeFileLists

function WriteFormattedOutput (const FilePath: myAStr): IFormattedOutput;
var
{O} FormattedOutputObj: TFileFormattedOutput;

begin
  FormattedOutputObj := TFileFormattedOutput.Create(FilePath);
  // * * * * * //
  result := FormattedOutputObj; FormattedOutputObj := nil;
end;

end.
