unit VersionInfoBuilder;

interface

uses
  SysUtils, Classes, Utils;

type

  TVersionData = record
    Major           : Word;
    Minor           : Word;
    Build           : Word;
    Revision        : Word;
    Sufix           : string;
    CompanyName     : string;
    FileDescription : string;
    InternalName    : string;
    LegalCopyright  : string;
    LegalTrademarks : string;
    OriginalFilename: string;
    ProductName     : string;
    Comments        : string;
  end;

  TVersion = class
    private
      Lines       : TStringList;
      FVersionData: TVersionData;
      Output      : TStringList;
      procedure PrepareLines(FileName: string);
      procedure ProcessLines;
      function ReadWord(Key: string): Word;
      function ReadString(Key: string): string;
      procedure AddLine(const Msg : String); overload;
      procedure AddLine(const Msg : String; const Arguments : array of TVarRec); overload;
      procedure CreateStream();
    public
      constructor Create();
      procedure ReadVersionData(FileName: string);
      procedure SaveVersionData(FileName: string);
      property VersionData : TVersionData read FVersionData;
  end;

implementation

constructor TVersion.Create;
begin
    inherited;
    Lines := TStringList.Create;
    Output := TStringList.Create;
end;

procedure TVersion.PrepareLines(FileName: string);
begin
    Lines.LoadFromFile(FileName);
end;

procedure TVersion.ProcessLines;
begin
    FVersionData.Major            := ReadWord('VER_Major');
    FVersionData.Minor            := ReadWord('VER_Minor');
    FVersionData.Build            := ReadWord('VER_Build');
    FVersionData.Revision         := ReadWord('VER_Revision');
    FVersionData.Sufix            := ReadString('VER_Sufix');
    FVersionData.CompanyName      := ReadString('VER_CompanyName');
    FVersionData.FileDescription  := ReadString('VER_FileDescription');
    FVersionData.InternalName     := ReadString('VER_InternalName');
    FVersionData.LegalCopyright   := ReadString('VER_LegalCopyright');
    FVersionData.LegalTrademarks  := ReadString('VER_LegalTrademarks');
    FVersionData.OriginalFilename := ReadString('VER_OriginalFilename');
    FVersionData.ProductName      := ReadString('VER_ProductName');
    FVersionData.Comments         := ReadString('VER_Comments');
end;

function TVersion.ReadWord(Key: string): Word;
var
    I, PosFrom, PosTo: integer;
    S: string;
begin
    Result := 0;
    for I := 0 to Lines.Count - 1 do
    begin
      S := Lines[I].Trim;
      if S.StartsWith(Key) then
      begin
        PosFrom := StrIPos('=', S) + 1;
        PosTo   := StrIPos(';', S);
        Result  := StrToInt(Copy(S, PosFrom, PosTo - PosFrom));
        Exit;
      end;
    end;
end;

function TextBetweenQuotes( const s : String; quoteChar : Char) : String;
var
    p,p1 : Integer;
begin
    Result := '';
    p := Pos(quoteChar,s);
    if p > 0 then begin
      p1 := Pos(quoteChar,s,p+1);
      if p1 > 0 then begin
        Result := Copy(s,p+1,p1-p-1);
      end;
    end;
end;

function TVersion.ReadString(Key: string): string;
var
    I: integer;
    S: string;
begin
    for I := 0 to Lines.Count - 1 do
    begin
      S := Lines[I].Trim;
      if S.StartsWith(Key) then
        Result  := TextBetweenQuotes(S, '''');
    end;
end;

procedure TVersion.AddLine(const Msg : String);
begin
    Output.Add(Msg);
end;

procedure TVersion.AddLine(const Msg : String; const Arguments : array of TVarRec);
begin
    AddLine(Format(Msg, Arguments));
end;

procedure TVersion.CreateStream();
begin
    Output.Clear;
    AddLine('#define VER_PRIVATEBUILD              0');
    AddLine('');
    AddLine('#ifndef RELEASE');
    AddLine('#define VER_PRERELEASE                VS_FF_PRERELEASE');
    AddLine('#else');
    AddLine('#define VER_PRERELEASE                0');
    AddLine('#endif');
    AddLine('');
    AddLine('#ifndef DEBUG');
    AddLine('#define VER_DEBUG                     0');
    AddLine('#else');
    AddLine('#define VER_DEBUG                     VS_FF_DEBUG');
    AddLine('#endif');
    AddLine('');
    AddLine('VS_VERSION_INFO VERSIONINFO');
    AddLine('FILEVERSION                           %d,%d,%d,%d', [FVersionData.Major, FVersionData.Minor, FVersionData.Build, FVersionData.Revision]);
    AddLine('PRODUCTVERSION                        %d,%d,%d,%d', [FVersionData.Major, FVersionData.Minor, FVersionData.Build, FVersionData.Revision]);
    AddLine('FILEFLAGSMASK                         VS_FFI_FILEFLAGSMASK');
    AddLine('FILEFLAGS                             (VER_PRIVATEBUILD | VER_PRERELEASE | VER_DEBUG)');
    AddLine('FILEOS                                VOS_NT | VOS__WINDOWS32');
    AddLine('FILETYPE                              VFT_DLL');
    AddLine('FILESUBTYPE                           VFT2_UNKNOWN');
    AddLine('BEGIN');
    AddLine('    BLOCK "StringFileInfo"');
    AddLine('    BEGIN');
    AddLine('        BLOCK "000004E4"');
    AddLine('        BEGIN');
    AddLine('            VALUE "ProductVersion",   "%d.%d.%d.%d\0"', [FVersionData.Major, FVersionData.Minor, FVersionData.Build, FVersionData.Revision]);
    AddLine('            VALUE "FileVersion",      "%d.%d.%d.%d\0"', [FVersionData.Major, FVersionData.Minor, FVersionData.Build, FVersionData.Revision]);
    AddLine('            VALUE "CompanyName",      "%s\0"', [FVersionData.CompanyName]);
    AddLine('            VALUE "FileDescription",  "%s\0"', [FVersionData.FileDescription]);
    AddLine('            VALUE "InternalName",     "%s\0"', [FVersionData.InternalName]);
    AddLine('            VALUE "LegalCopyright",   "%s\0"', [FVersionData.LegalCopyright]);
    AddLine('            VALUE "LegalTrademarks",  "%s\0"', [FVersionData.LegalTrademarks]);
    AddLine('            VALUE "OriginalFilename", "%s\0"', [FVersionData.OriginalFilename]);
    AddLine('            VALUE "ProductName",      "%s\0"', [FVersionData.ProductName]);
    AddLine('            VALUE "Comments",         "%s\0"', [FVersionData.Comments]);
    AddLine('        END');
    AddLine('    END');
    AddLine('    BLOCK "VarFileInfo"');
    AddLine('    BEGIN');
    AddLine('        VALUE "Translation", 0x0000, 1252');
    AddLine('    END');
    AddLine('END');
end;

procedure TVersion.ReadVersionData(FileName: string);
begin
    PrepareLines(FileName);
    ProcessLines();
    ProcessLines();
    CreateStream();
end;

procedure TVersion.SaveVersionData(FileName: string);
begin
    Output.SaveToFile(FileName);
end;

end.
