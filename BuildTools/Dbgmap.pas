unit Dbgmap;

{
  Compiles debug .map file into .dbgmap binary map with the following structure:
  [0] Labels section
  [4] Number of labels
    > Repeat "Number of labels" times
    [4] Label address
    [4] Label name length
    [...] Label name
  [0] Modules section (program modules = source code containers, used in line numbers tracking)
  [4] Number of modules
    > Repeat "Number of modules" times
    [4] Module name length
    [...] Module name
  [0] Line numbers section
  [4] Number of line numbers
    > Repeat "Number of line numbers" times
    [4] Address of code/data
    [4] Module index (from modules table, starting from zero)
    [4] Line number
  All addresses are relative to PE image base. Ex. for 0x401000 absolute address and 0x400000 image
  base, relative address will be 0x001000.
}

interface

uses
  SysUtils, DbgmapCompiler, Utils;

  /// <summary>
  ///   Create a .dbgmap file and place it in the DebugMaps subfolder. The provided file extension will be
  ///   ignored and replaced with .map. If the DebugMaps folder does not exist, it will be created.
  /// </summary>
  /// <param name="TargetFile">
  ///   The full path to the source file should be provided. The extension of the filename will be changed to .map.
  ///   A valid .map file must exist in the same folder as the source file.
  /// </param>
  /// <remarks>
  ///   Errors and messages will be logged in the command line or the Output window.
  /// </remarks>
  procedure CreateDbgmap(TargetFile: string);

implementation

procedure CreateDbgmap(TargetFile: string);
var
    FileName   : string;
    SourcePath : string;
    OutputPath : string;
    OutputDir  : string;
    Compiler   : TMapCompiler;
begin
    WriteLn('Map file compiler (.map -> .dbgmap)');
    try
      SourcePath := ChangeFileExt(TargetFile, '.map');
      if not FileExists(SourcePath) then
      begin
        Log('Failed to locate map file "%s"', SourcePath);
        Exit;
      end;

      OutputDir := ExtractFileDir(SourcePath) + '\DebugMaps\';
      if not DirectoryExists(OutputDir) then
      begin
        Log('Created destination folder: %s', OutputDir);
        ForceDirectories(OutputDir);
      end;

      Log('Start compile "%s" to folder "%s"', [SourcePath, OutputDir]);

      FileName  := ChangeFileExt(ExtractFileName(SourcePath), '');
      OutputPath:= IncludeTrailingPathDelimiter(OutputDir) + FileName + '.dbgmap';

      Compiler := TMapCompiler.Create;
      try
        Compiler.Compile(SourcePath);
        Compiler.SaveToFile(OutputPath);
        Log('Successfully compiled "%s" map (%d b) to binary dbgmap (%d b)', [FileName, Compiler.SourceSize, Compiler.CompiledSize]);
      finally
        Compiler.free;
      end;

      DeleteFile(PChar(SourcePath));
      DeleteFile(PChar(ChangeFileExt(TargetFile, '.drc')));
    except
      on E : Exception do
      Log('Exception: %s', [E.Message]);
    end;
end;

end.
