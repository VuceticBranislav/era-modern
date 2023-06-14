unit VersionInfo;

interface

uses
  SysUtils, VersionInfoBuilder, Utils;

  /// <summary>
  ///   Create a .rc file with file info from "VersionInfo.inc". After creating .rc file compile
  ///   it to .res file using brcc32.exe.
  /// </summary>
  /// <param name="TargetProject">
  ///   The full path to the project folder should be provided.
  /// </param>
  /// <remarks>
  ///   Errors and messages will be logged in the command line or the Output window.
  /// </remarks>
  procedure CreateVersionInfo(TargetProject: string);

implementation

procedure CreateVersionInfo(TargetProject: string);
var
    SourcePath : string;
    OutputPath : string;
    VersionInfoBuilder : TVersion;
const
    FileName   : string = 'VersionInfo.inc';
begin
    WriteLn('Version info update');
    try

    SourcePath := IncludeTrailingPathDelimiter(TargetProject) + FileName;
    OutputPath := ChangeFileExt(SourcePath, '.rc');
    Log('Update version info from "%s"', [SourcePath]);

    if not FileExists(SourcePath) then
      raise Exception.Create('"VersionInfo.inc" not found in project folder "' + TargetProject + '"');

    VersionInfoBuilder := TVersion.Create();
    VersionInfoBuilder.ReadVersionData(SourcePath);
    VersionInfoBuilder.SaveVersionData(OutputPath);
    Log('Retrived version info data. Created "%s"', [OutputPath]);

    CompileRC(OutputPath);
    Log('Successfully executed "%s"', ['brcc32 '+ OutputPath]);

    except
      on E : Exception do
      Log('Exception: %s', [E.Message]);
    end;
end;

end.
