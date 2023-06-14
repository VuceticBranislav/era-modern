unit Utils;

interface

uses
  SysUtils, Windows;

  /// <summary>
  ///   Log debug message to console or output window using provided message string and arguments.
  /// </summary>
  /// <param name="LogMessage">
  ///   Log message support formating <see cref="SysUtils|WideFormatBuf">WideFormatBuf</see>.
  /// </param>
  /// <param name="LogArguments">
  ///   Array of message arguments.
  /// </param>
  /// <remarks>
  ///   Method is based on <see cref="WriteLn"/>.
  /// </remarks>
  procedure Log(const LogMessage: string; const LogArguments: array of TVarRec); overload;

  /// <summary>
  ///   Log debug message to console or output window using provided message string and argument.
  /// </summary>
  /// <param name="LogMessage">
  ///   Log message support formating <see cref="SysUtils|WideFormatBuf">WideFormatBuf</see>.
  /// </param>
  /// <param name="LogArgument">
  ///   Message argument.
  /// </param>
  /// <remarks>
  ///   Method is based on <see cref="WriteLn"/>.
  /// </remarks>
  procedure Log(const LogMessage: string; const LogArgument: string); overload;

  /// <summary>
  ///   Log debug message to console or output window using provided message.
  /// </summary>
  /// <param name="LogMessage">
  ///   Log message support formating <see cref="SysUtils|WideFormatBuf">WideFormatBuf</see>.
  /// </param>
  /// <remarks>
  ///   Method is based on <see cref="WriteLn"/>.
  /// </remarks>
  procedure Log(const LogMessage: string); overload;

  /// <summary>
  /// Rounds variables up toward positive infinity.
  /// </summary>
  function Ceil(const X: Single): Integer;

  /// <summary>
  /// Case insensitive <see cref="Pos"/> method.
  /// </summary>
  function StrIPos(const SubStr, Str: string): Integer;

  /// <summary>
  ///   Compile .rc to .res file and wait for process to complete. Raise exception if compiling fails.
  /// </summary>
  /// <param name="FilePath">
  ///   Patch to .rc file to compile.
  /// </param>
  procedure CompileRC(const FilePath: string);

implementation

procedure Log(const LogMessage: string; const LogArguments: array of TVarRec); overload;
begin
    WriteLn(Format(LogMessage, LogArguments));
end;

procedure Log(const LogMessage: string; const LogArgument: string); overload;
begin
    WriteLn(Format(LogMessage, [LogArgument]));
end;

procedure Log(const LogMessage: string); overload;
begin
    WriteLn(LogMessage);
end;

function Ceil(const X: Single): Integer;
begin
    Result := Integer(Trunc(X));
    if Frac(X) > 0 then
      Inc(Result);
end;

function StrIPos(const SubStr, Str: string): Integer;
begin
    Result := Pos(UpperCase(SubStr), UpperCase(Str));
end;

function Execute(Cmd: string; const StartDir: string; HideOutput: Boolean): Integer;
var
    ProcessInfo: TProcessInformation;
    StartupInfo: TStartupInfo;
begin
    StartupInfo.cb := SizeOf(StartupInfo);
    GetStartupInfo(StartupInfo);

    if HideOutput then
    begin
      StartupInfo.hStdOutput:= 0;
      StartupInfo.hStdError := 0;
      StartupInfo.dwFlags   := STARTF_USESTDHANDLES;
    end;

    UniqueString(Cmd);
    if CreateProcess(nil, PChar(Cmd), nil, nil, True, 0, nil, Pointer(StartDir), StartupInfo, ProcessInfo) then
    begin
      CloseHandle(ProcessInfo.hThread);
      WaitForSingleObject(ProcessInfo.hProcess, INFINITE);
      GetExitCodeProcess (ProcessInfo.hProcess, Cardinal(Result));
      CloseHandle(ProcessInfo.hProcess);
    end
    else
      Result := -1;
end;

procedure CompileRC(const FilePath: string);
begin
    if Execute('brcc32 '+ FilePath, GetCurrentDir, True) = -1 then
      raise Exception.Create('Resource file compiling error');
end;

end.
