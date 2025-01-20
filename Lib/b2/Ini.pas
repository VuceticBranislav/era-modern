unit Ini;
(*
  Description: Memory cached ini files management
  Author:      Alexander Shostak (aka Berserker aka EtherniDee)
*)

(***)  interface  (***)

uses
  SysUtils,

  AssocArrays,
  Files,
  Lists,
  Log,
  StrLib,
  TextScan,
  TypeWrappers,
  UtilsB2, Legacy;

type
  (* Import *)
  TString     = TypeWrappers.TString;
  TAssocArray = AssocArrays.TAssocArray;


(* Forgets all cached data for specified ini file. Any read/write operation will lead to its re-reading and re-parsing *)
procedure ClearIniCache (const FileName: myAStr);

(* Forgets all cached data for all ini files *)
procedure ClearAllIniCache;

(* Replaces ini file cache in memory with an empty one. Use it for recreating ini files from scratch, when you don't need previously cached data and original file on disk *)
procedure EmptyIniCache (const FileName: myAStr);

(* Reads entry from in-memory cache. Automatically loads ini file from disk if it's not cached yet *)
function ReadStrFromIni (const Key: myAStr; const SectionName: myAStr; FilePath: myAStr; out Res: myAStr): boolean;

(* Writes and entry to in-memory cache. Automatically loads ini file from disk if it's not cached yet *)
function WriteStrToIni (const Key, Value, SectionName: myAStr; FilePath: myAStr): boolean;

(* Loads and parses ini file. Creates in-memory cache for it to prevent further disk accesses. Returns true only if file existed, was successfully read and parsed
   Creates empty cache entry in case of any error *)
function LoadIni (FilePath: myAStr): boolean;

(* Saves cached ini to the specified file on a disk. Automatically recreates all directories in a path to the file. Loads file contents from disk if it was not cached earlier *)
function SaveIni (FilePath: myAStr): boolean;

(* Loads two ini files and merges source ini entries with target ini entries in cache without overwriting existing entries *)
procedure MergeIniWithDefault (TargetPath, SourcePath: myAStr);


(***) implementation (***)


var
{O} CachedIniFiles: {O} TAssocArray {OF TAssocArray};


procedure ClearIniCache (const FileName: myAStr);
begin
  CachedIniFiles.DeleteItem(Legacy.ExpandFileName(FileName));
end;

procedure ClearAllIniCache;
begin
  CachedIniFiles.Clear;
end;

procedure EmptyIniCache (const FileName: myAStr);
begin
  CachedIniFiles[Legacy.ExpandFileName(FileName)] := AssocArrays.NewStrictAssocArr(TAssocArray);
end;

function LoadIni (FilePath: myAStr): boolean;
const
  LINE_END_MARKER     = #10;
  LINE_END_MARKERS    = [#10, #13];
  BLANKS              = [#0..#32];
  DEFAULT_DELIMS      = [';'] + LINE_END_MARKERS;
  SECTION_NAME_DELIMS = [']'] + DEFAULT_DELIMS;
  KEY_DELIMS          = ['='] + DEFAULT_DELIMS;

var
{O} TextScanner:  TextScan.TTextScanner;
{O} Sections:     {O} TAssocArray {OF TAssocArray};
{U} CurrSection:  {O} TAssocArray {OF TString};
    FileContents: myAStr;
    SectionName:  myAStr;
    Key:          myAStr;
    Value:        myAStr;
    c:            myChar;

 procedure GotoNextLine;
 begin
   TextScanner.FindChar(LINE_END_MARKER);
   TextScanner.GotoNextChar;
 end;

begin
  TextScanner := TextScan.TTextScanner.Create;
  Sections    := AssocArrays.NewStrictAssocArr(TAssocArray);
  CurrSection := nil;
  // * * * * * //
  FilePath := Legacy.ExpandFileName(FilePath);
  CachedIniFiles.DeleteItem(FilePath);

  result := Files.ReadFileContents(FilePath, FileContents);

  if result and (Length(FileContents) > 0) then begin
    TextScanner.Connect(FileContents, LINE_END_MARKER);

    while result and (not TextScanner.EndOfText) do begin
      TextScanner.SkipCharset(BLANKS);

      if TextScanner.GetCurrChar(c) then begin
        if c = ';' then begin
          GotoNextLine;
        end else begin
          if c = '[' then begin
            TextScanner.GotoNextChar;

            result :=
              TextScanner.ReadTokenTillDelim(SECTION_NAME_DELIMS, SectionName) and
              TextScanner.GetCurrChar(c)                                       and
              (c = ']');

            if result then begin
              SectionName := Legacy.Trim(SectionName);
              GotoNextLine;
              CurrSection := Sections[SectionName];

              if CurrSection = nil then begin
                CurrSection           := AssocArrays.NewStrictAssocArr(TString);
                Sections[SectionName] := CurrSection;
              end;
            end;
          end else begin
            TextScanner.ReadTokenTillDelim(KEY_DELIMS, Key);
            result := TextScanner.GetCurrChar(c) and (c = '=');

            if result then begin
              Key := Legacy.Trim(Key);
              TextScanner.GotoNextChar;

              if not TextScanner.ReadTokenTillDelim(DEFAULT_DELIMS, Value) then begin
                Value := '';
              end else begin
                Value := Legacy.Trim(Value);
              end;

              if CurrSection = nil then begin
                CurrSection  := AssocArrays.NewStrictAssocArr(TString);
                Sections[''] := CurrSection;
              end;

              CurrSection[Key]  :=  TString.Create(Value);
            end; // .if
          end; // .else
        end; // .else
      end; // .if
    end; // .while

    if not result then begin
      // Do not preserve semi-parsed ini file data
      Sections.Clear;

      Log.Write
      (
        myAStr('Ini'),
        myAStr('LoadIni'),
        StrLib.Concat([myAStr('The file "'), FilePath, myAStr('" has invalid format.'#13#10), myAStr('Scanner stopped at position '), Legacy.IntToStr(TextScanner.Pos)])
      );
    end;
  end; // .if

  CachedIniFiles[FilePath] := Sections; Sections := nil;
  // * * * * * //
  Legacy.FreeAndNil(TextScanner);
  Legacy.FreeAndNil(Sections);
end; // .function LoadIni

function SaveIni (FilePath: myAStr): boolean;
var
{O} StrBuilder:   StrLib.TStrBuilder;
{O} SectionNames: Lists.TStringList {OF TAssocArray};
{O} SectionKeys:  Lists.TStringList {OF TString};
{U} CachedIni:    {O} TAssocArray {OF TAssocArray};
{U} Section:      {O} TAssocArray {OF TString};
{U} Value:        TString;
    SectionName:  myAStr;
    Key:          myAStr;
    i:            integer;
    j:            integer;

begin
  StrBuilder   := StrLib.TStrBuilder.Create;
  SectionNames := Lists.NewSimpleStrList;
  SectionKeys  := Lists.NewSimpleStrList;
  CachedIni    := nil;
  Section      := nil;
  Value        := nil;
  // * * * * * //
  FilePath  := Legacy.ExpandFileName(FilePath);
  CachedIni := CachedIniFiles[FilePath];

  if CachedIni = nil then begin
    LoadIni(FilePath);
    CachedIni := CachedIniFiles[FilePath];
  end;

  if CachedIni <> nil then begin
    CachedIni.BeginIterate;

    while CachedIni.IterateNext(SectionName, pointer(Section)) do begin
      SectionNames.AddObj(SectionName, Section);
      Section := nil;
    end;

    CachedIni.EndIterate;

    SectionNames.Sorted := true;

    for i := 0 to SectionNames.Count - 1 do begin
      if SectionNames[i] <> '' then begin
        StrBuilder.Append('[');
        StrBuilder.Append(SectionNames[i]);
        StrBuilder.Append(']'#13#10);
      end;

      Section := SectionNames.Values[i];

      Section.BeginIterate;

      while Section.IterateNext(Key, pointer(Value)) do begin
        SectionKeys.AddObj(Key, Value);
        Value :=  nil;
      end;

      Section.EndIterate;

      SectionKeys.Sorted := true;

      for j := 0 to SectionKeys.Count - 1 do begin
        StrBuilder.Append(SectionKeys[j]);
        StrBuilder.Append('=');
        StrBuilder.Append(TString(SectionKeys.Values[j]).Value);
        StrBuilder.Append(#13#10);
      end;

      SectionKeys.Clear;
      SectionKeys.Sorted := false;
    end; // .for
  end; // .if

  Files.ForcePath(Legacy.ExtractFileDir(FilePath));
  result := Files.WriteFileContents(StrBuilder.BuildStr, FilePath);
  // * * * * * //
  Legacy.FreeAndNil(StrBuilder);
  Legacy.FreeAndNil(SectionNames);
  Legacy.FreeAndNil(SectionKeys);
end; // .function SaveIni

function ReadStrFromIni (const Key: myAStr; const SectionName: myAStr; FilePath: myAStr; out Res: myAStr): boolean;
var
{U} CachedIni: {O} TAssocArray {OF TAssocArray};
{U} Section:   {O} TAssocArray {OF TString};
{U} Value:     TString;

begin
  CachedIni := nil;
  Section   := nil;
  Value     := nil;
  // * * * * * //
  FilePath  := Legacy.ExpandFileName(FilePath);
  CachedIni := CachedIniFiles[FilePath];

  if CachedIni = nil then begin
    LoadIni(FilePath);
    CachedIni := CachedIniFiles[FilePath];
  end;

  result := CachedIni <> nil;

  if result then begin
    Section := CachedIni[SectionName];
    result  := Section <> nil;

    if result then begin
      Value  := Section[Key];
      result := Value <> nil;

      if result then begin
        Res := Value.Value;
      end;
    end;
  end; // .if
end; // .function ReadStrFromIni

function WriteStrToIni (const Key, Value, SectionName: myAStr; FilePath: myAStr): boolean;
var
{U} CachedIni:      {O} TAssocArray {OF TAssocArray};
{U} Section:        {O} TAssocArray {OF TString};
    InvalidCharPos: integer;

begin
  CachedIni := nil;
  Section   := nil;
  // * * * * * //
  FilePath  := Legacy.ExpandFileName(FilePath);
  CachedIni := CachedIniFiles[FilePath];

  if CachedIni = nil then begin
    LoadIni(FilePath);
    CachedIni := CachedIniFiles[FilePath];
  end;

  result :=
    (CachedIni <> nil)                                                        and
    not StrLib.FindCharset([';', #10, #13, ']'], SectionName, InvalidCharPos) and
    not StrLib.FindCharset([';', #10, #13, '='], Key, InvalidCharPos)         and
    not StrLib.FindCharset([';', #10, #13], Value, InvalidCharPos);

  if result then begin
    Section := CachedIni[SectionName];

    if Section = nil then begin
      Section                := AssocArrays.NewStrictAssocArr(TString);
      CachedIni[SectionName] := Section;
    end;

    Section[Key] := TString.Create(Value);
  end; // .if
end; // .function WriteStrToIni

procedure MergeIniWithDefault (TargetPath, SourcePath: myAStr);
var
{U} TargetIni:     {O} TAssocArray {OF TAssocArray};
{U} SourceIni:     {O} TAssocArray {OF TAssocArray};
{U} TargetSection: {O} TAssocArray {OF TString};
{U} SourceSection: {O} TAssocArray {OF TString};
{U} Value:         TString;
    SectionName:   myAStr;
    Key:           myAStr;

begin
  TargetIni     := nil;
  SourceIni     := nil;
  TargetSection := nil;
  SourceSection := nil;
  Value         := nil;
  // * * * * * //
  TargetPath := Legacy.ExpandFileName(TargetPath);
  SourcePath := Legacy.ExpandFileName(SourcePath);
  TargetIni  := CachedIniFiles[TargetPath];
  SourceIni  := CachedIniFiles[SourcePath];

  if SourceIni <> nil then begin
    if TargetIni = nil then begin
      CachedIniFiles[TargetPath] := TAssocArray(SourceIni.Clone);
    end else begin
      SourceIni.BeginIterate;

      while SourceIni.IterateNext(SectionName, pointer(SourceSection)) do begin
        TargetSection := TargetIni[SectionName];

        if TargetSection = nil then begin
          TargetIni[SectionName] := TAssocArray(SourceSection.Clone);
        end else begin
          SourceSection.BeginIterate;

          while SourceSection.IterateNext(Key, pointer(Value)) do begin
            if not TargetSection.HasKey(Key) then begin
              TargetSection[Key] := Value.Clone;
            end;

            Value := nil;
          end;

          SourceSection.EndIterate;
        end; // .else

        SourceSection := nil;
      end; // .while

      SourceIni.EndIterate;
    end; // .else
  end; // .if
end; // .procedure MergeIniWithDefault

begin
  CachedIniFiles := AssocArrays.NewStrictAssocArr(TAssocArray);
end.
