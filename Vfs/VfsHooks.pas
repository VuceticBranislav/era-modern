unit VfsHooks;
(*
  Description: WinNT code hooks package.
*)


(***)  interface  (***)

uses
  Windows, SysUtils, Math,
  UtilsB2, WinNative, Concur,
  StrLib, Alg, WinUtils,
  VfsBase, VfsUtils, VfsPatching,
  VfsDebug, VfsApiDigger, VfsOpenFiles, Legacy;


(* Installs VFS hooks, if not already installed, in a thread-safe manner *)
procedure InstallHooks;


(***)  implementation  (***)


var
  HooksCritSection: Concur.TCritSection;
  HooksInstalled:   boolean = false;

  NativeNtQueryAttributesFile:     WinNative.TNtQueryAttributesFile;
  NativeNtQueryFullAttributesFile: WinNative.TNtQueryFullAttributesFile;
  NativeNtOpenFile:                WinNative.TNtOpenFile;
  NativeNtCreateFile:              WinNative.TNtCreateFile;
  NativeNtClose:                   WinNative.TNtClose;
  NativeNtQueryDirectoryFile:      WinNative.TNtQueryDirectoryFile;
  NativeNtQueryDirectoryFileEx:    WinNative.TNtQueryDirectoryFileEx;


  NtQueryAttributesFilePatch:     VfsPatching.TAppliedPatch;
  NtQueryFullAttributesFilePatch: VfsPatching.TAppliedPatch;
  NtOpenFilePatch:                VfsPatching.TAppliedPatch;
  NtCreateFilePatch:              VfsPatching.TAppliedPatch;
  NtClosePatch:                   VfsPatching.TAppliedPatch;
  NtQueryDirectoryFilePatch:      VfsPatching.TAppliedPatch;
  NtQueryDirectoryFileExPatch:    VfsPatching.TAppliedPatch;


(* There is no 100% portable and reliable way to get file path by handle, unless file creation/opening
   was tracked. Thus we rely heavily on VfsOpenFiles.
   In Windows access to files in curren directory under relative paths is performed via [hDir, RelPath] pair,
   thus it's strongly recommended to ensure, that current directory handle is tracked by VfsOpenedFiles.
   It can be perfomed via SetCurrentDir(GetCurrentDir) after VFS was run *)
function GetFilePathByHandle (hFile: THandle): myWStr;
begin
  result := VfsOpenFiles.GetOpenedFilePath(hFile);

  if (result = '') and VfsDebug.LoggingEnabled then begin
    WriteLog('GetFilePathByHandle', Legacy.Format('Failed to get path for handle %x. Current directory is: %s', [integer(hFile), WinUtils.GetCurrentDirW]));
  end;
end;

(* Returns single absolute path, not dependant on RootDirectory member. '\??\' prefix is always removed, \\.\ and \\?\ paths remain not touched. *)
function GetFileObjectPath (ObjectAttributes: POBJECT_ATTRIBUTES): myWStr;
var
  FilePath: myWStr;
  DirPath:  myWStr;

begin
  FilePath := ObjectAttributes.ObjectName.ToWideStr();
  result   := '';

  if FilePath <> '' then begin
    if FilePath[1] = '\' then begin
      FilePath := VfsUtils.StripNtAbsPathPrefix(FilePath);
    end;

    if ObjectAttributes.RootDirectory <> 0 then begin
      DirPath := GetFilePathByHandle(ObjectAttributes.RootDirectory);

      if DirPath <> '' then begin
        if DirPath[Length(DirPath)] <> '\' then begin
          result := DirPath + '\' + FilePath;
        end else begin
          result := DirPath + FilePath;
        end;
      end;
    end else begin
      result := FilePath;
    end;
  end; // .if
end; // .function GetFileObjectPath

function Hook_NtQueryAttributesFile (OrigFunc: WinNative.TNtQueryAttributesFile; ObjectAttributes: POBJECT_ATTRIBUTES; FileInformation: PFILE_BASIC_INFORMATION): NTSTATUS; stdcall;
var
  ExpandedPath:      myWStr;
  RedirectedPath:    myWStr;
  ReplacedObjAttrs:  WinNative.TObjectAttributes;
  ReplacedPath:      WinNative.UNICODE_STRING;
  FileInfo:          TNativeFileInfo;
  HadTrailingDelim_: array [0..3] of byte; // Fix Delphi bug: HadTrailingDelim causes stack 4-bytes misalignment
  HadTrailingDelim:  boolean absolute HadTrailingDelim_;

begin
  if VfsDebug.LoggingEnabled then begin
    WriteLog('[ENTER] NtQueryAttributesFile', Legacy.Format('Dir: %d.'#13#10'Path: "%s"', [ObjectAttributes.RootDirectory, ObjectAttributes.ObjectName.ToWideStr()]));
  end;

  ReplacedObjAttrs        := ObjectAttributes^;
  ReplacedObjAttrs.Length := sizeof(ReplacedObjAttrs);
  ExpandedPath            := GetFileObjectPath(ObjectAttributes);
  RedirectedPath          := '';

  if ExpandedPath <> '' then begin
    RedirectedPath := VfsBase.GetVfsItemRealPath(StrLib.ExcludeTrailingBackslashW(ExpandedPath, @HadTrailingDelim), @FileInfo);
  end;

  // Return cached VFS file info
  if RedirectedPath <> '' then begin
    if not HadTrailingDelim or UtilsB2.Flags(FileInfo.Base.FileAttributes).Have(FILE_ATTRIBUTE_DIRECTORY) then begin
      FileInformation.CreationTime   := FileInfo.Base.CreationTime;
      FileInformation.LastAccessTime := FileInfo.Base.LastAccessTime;
      FileInformation.LastWriteTime  := FileInfo.Base.LastWriteTime;
      FileInformation.ChangeTime     := FileInfo.Base.ChangeTime;
      FileInformation.FileAttributes := FileInfo.Base.FileAttributes;
      result                         := WinNative.STATUS_SUCCESS;
    end else begin
      result := WinNative.STATUS_NO_SUCH_FILE;
    end;
  end
  // Query file with real path
  else begin
    RedirectedPath := ExpandedPath;

    if RedirectedPath <> '' then begin
      if RedirectedPath[1] <> '\' then begin
        RedirectedPath := '\??\' + RedirectedPath;
      end;

      ReplacedObjAttrs.RootDirectory := 0;
      ReplacedObjAttrs.Attributes    := ReplacedObjAttrs.Attributes or WinNative.OBJ_CASE_INSENSITIVE;
      ReplacedObjAttrs.ObjectName    := @ReplacedPath;
      ReplacedObjAttrs.ObjectName.AssignExistingStr(RedirectedPath);
    end;
    
    result := OrigFunc(@ReplacedObjAttrs, FileInformation);
  end; // .else

  if VfsDebug.LoggingEnabled then begin
    WriteLog('[LEAVE] NtQueryAttributesFile', Legacy.Format('Result: %x. Attrs: 0x%x.'#13#10'Expanded:   "%s"'#13#10'Redirected: "%s"', [result, FileInformation.FileAttributes, myAStr(ExpandedPath), myAStr(RedirectedPath)]));
  end;
end; // .function Hook_NtQueryAttributesFile

function Hook_NtQueryFullAttributesFile (OrigFunc: WinNative.TNtQueryFullAttributesFile; ObjectAttributes: POBJECT_ATTRIBUTES; FileInformation: PFILE_NETWORK_OPEN_INFORMATION): NTSTATUS; stdcall;
var
  ExpandedPath:      myWStr;
  RedirectedPath:    myWStr;
  ReplacedObjAttrs:  WinNative.TObjectAttributes;
  ReplacedPath:      WinNative.UNICODE_STRING;
  FileInfo:          TNativeFileInfo;
  HadTrailingDelim_: array [0..3] of byte; // Fix Delphi bug: HadTrailingDelim causes stack 4-bytes misalignment
  HadTrailingDelim:  boolean absolute HadTrailingDelim_;

begin
  if VfsDebug.LoggingEnabled then begin
    WriteLog('[ENTER] NtQueryFullAttributesFile', Legacy.Format('Dir: %d.'#13#10'Path: "%s"', [ObjectAttributes.RootDirectory, ObjectAttributes.ObjectName.ToWideStr()]));
  end;

  ReplacedObjAttrs        := ObjectAttributes^;
  ReplacedObjAttrs.Length := sizeof(ReplacedObjAttrs);
  ExpandedPath            := GetFileObjectPath(ObjectAttributes);
  RedirectedPath          := '';

  if ExpandedPath <> '' then begin
    RedirectedPath := VfsBase.GetVfsItemRealPath(StrLib.ExcludeTrailingBackslashW(ExpandedPath, @HadTrailingDelim), @FileInfo);
  end;

  // Return cached VFS file info
  if RedirectedPath <> '' then begin
    if not HadTrailingDelim or UtilsB2.Flags(FileInfo.Base.FileAttributes).Have(FILE_ATTRIBUTE_DIRECTORY) then begin
      FileInformation.CreationTime   := FileInfo.Base.CreationTime;
      FileInformation.LastAccessTime := FileInfo.Base.LastAccessTime;
      FileInformation.LastWriteTime  := FileInfo.Base.LastWriteTime;
      FileInformation.ChangeTime     := FileInfo.Base.ChangeTime;
      FileInformation.AllocationSize := FileInfo.Base.AllocationSize;
      FileInformation.EndOfFile      := FileInfo.Base.EndOfFile;
      FileInformation.FileAttributes := FileInfo.Base.FileAttributes;
      FileInformation.Reserved       := 0;
      result                         := WinNative.STATUS_SUCCESS;
    end else begin
      result := WinNative.STATUS_NO_SUCH_FILE;
    end;
  end
  // Query file with real path
  else begin
    RedirectedPath := ExpandedPath;

    if RedirectedPath <> '' then begin
      if RedirectedPath[1] <> '\' then begin
        RedirectedPath := '\??\' + RedirectedPath;
      end;

      ReplacedObjAttrs.RootDirectory := 0;
      ReplacedObjAttrs.Attributes    := ReplacedObjAttrs.Attributes or WinNative.OBJ_CASE_INSENSITIVE;
      ReplacedObjAttrs.ObjectName    := @ReplacedPath;
      ReplacedObjAttrs.ObjectName.AssignExistingStr(RedirectedPath);
    end;
    
    result := OrigFunc(@ReplacedObjAttrs, FileInformation);
  end; // .else

  if VfsDebug.LoggingEnabled then begin
    WriteLog('[LEAVE] NtQueryFullAttributesFile', Legacy.Format('Result: %x. Attrs: 0x%x.'#13#10'Expanded:   "%s"'#13#10'Redirected: "%s"', [result, FileInformation.FileAttributes, myAStr(ExpandedPath), myAStr(RedirectedPath)]));
  end;
end; // .Hook_NtQueryFullAttributesFile

function Hook_NtOpenFile (OrigFunc: WinNative.TNtOpenFile; FileHandle: PHANDLE; DesiredAccess: ACCESS_MASK; ObjectAttributes: POBJECT_ATTRIBUTES;
                          IoStatusBlock: PIO_STATUS_BLOCK; ShareAccess: ULONG; OpenOptions: ULONG): NTSTATUS; stdcall;
begin
  if VfsDebug.LoggingEnabled then begin
    WriteLog('NtOpenFile', myAStr(ObjectAttributes.ObjectName.ToWideStr()));
  end;

  result := WinNative.NtCreateFile(FileHandle, DesiredAccess, ObjectAttributes, IoStatusBlock, nil, 0, ShareAccess, WinNative.FILE_OPEN, OpenOptions, nil, 0);
end;

function Hook_NtCreateFile (OrigFunc: WinNative.TNtCreateFile; FileHandle: PHANDLE; DesiredAccess: ACCESS_MASK; ObjectAttributes: POBJECT_ATTRIBUTES; IoStatusBlock: PIO_STATUS_BLOCK;
                            AllocationSize: PLARGE_INTEGER; FileAttributes: ULONG; ShareAccess: ULONG; CreateDisposition: ULONG; CreateOptions: ULONG; EaBuffer: PVOID; EaLength: ULONG): NTSTATUS; stdcall;
var
  ExpandedPath:      myWStr;
  RedirectedPath:    myWStr;
  ReplacedObjAttrs:  WinNative.TObjectAttributes;
  ReplacedPath:      WinNative.UNICODE_STRING;
  HadTrailingDelim_: array [0..3] of byte; // Fix Delphi bug: HadTrailingDelim causes stack 4-bytes misalignment
  HadTrailingDelim:  boolean absolute HadTrailingDelim_;

begin
  if VfsDebug.LoggingEnabled then begin
    WriteLog('[ENTER] NtCreateFile', Legacy.Format('Access: 0x%x. CreateDisposition: 0x%x'#13#10'Path: "%s"', [Int(DesiredAccess), Int(CreateDisposition), ObjectAttributes.ObjectName.ToWideStr()]));
  end;

  ReplacedObjAttrs        := ObjectAttributes^;
  ReplacedObjAttrs.Length := sizeof(ReplacedObjAttrs);
  ExpandedPath            := GetFileObjectPath(ObjectAttributes);
  RedirectedPath          := '';

  if (ExpandedPath <> '') and ((DesiredAccess and WinNative.DELETE) = 0) and (CreateDisposition = WinNative.FILE_OPEN) then begin
    RedirectedPath := VfsBase.GetVfsItemRealPath(StrLib.ExcludeTrailingBackslashW(ExpandedPath, @HadTrailingDelim));
  end;

  if RedirectedPath = '' then begin
    RedirectedPath := ExpandedPath;
  end else if HadTrailingDelim then begin
    RedirectedPath := RedirectedPath + '\';
  end;

  if RedirectedPath <> '' then begin
    if RedirectedPath[1] <> '\' then begin
      RedirectedPath := '\??\' + RedirectedPath;
    end;

    ReplacedObjAttrs.RootDirectory := 0;
    ReplacedObjAttrs.Attributes    := ReplacedObjAttrs.Attributes or WinNative.OBJ_CASE_INSENSITIVE;
    ReplacedObjAttrs.ObjectName    := @ReplacedPath;
    ReplacedObjAttrs.ObjectName.AssignExistingStr(RedirectedPath);
  end;

  with VfsOpenFiles.OpenFilesCritSection do begin
    Enter;

    result := OrigFunc(FileHandle, DesiredAccess, @ReplacedObjAttrs, IoStatusBlock, AllocationSize, FileAttributes, ShareAccess, CreateDisposition, CreateOptions, EaBuffer, EaLength);

    if (result = WinNative.STATUS_SUCCESS) and (ExpandedPath <> '') then begin
      VfsOpenFiles.SetOpenedFileInfo(FileHandle^, TOpenedFile.Create(FileHandle^, VfsUtils.NormalizeAbsPath(ExpandedPath)));
    end;

    Leave;
  end;  

  if VfsDebug.LoggingEnabled then begin
    if ExpandedPath <> StripNtAbsPathPrefix(RedirectedPath) then begin
      WriteLog('[LEAVE] NtCreateFile', Legacy.Format('Handle: %x. Status: %x.'#13#10'Expanded:   "%s"'#13#10'Redirected: "%s"', [FileHandle^, result, ExpandedPath, StripNtAbsPathPrefix(RedirectedPath)]));
    end else begin
      WriteLog('[LEAVE] NtCreateFile', Legacy.Format('Handle: %x. Status: %x.'#13#10'Expanded: "%s"', [FileHandle^, result, ExpandedPath]));
    end;
  end;
end; // .function Hook_NtCreateFile

function Hook_NtClose (OrigFunc: WinNative.TNtClose; hData: HANDLE): NTSTATUS; stdcall;
begin
  if VfsDebug.LoggingEnabled then begin
    WriteLog('[ENTER] NtClose', Legacy.Format('Handle: %x', [integer(hData)]));
  end;

  with VfsOpenFiles.OpenFilesCritSection do begin
    Enter;

    result := OrigFunc(hData);

    if WinNative.NT_SUCCESS(result) then begin
      VfsOpenFiles.DeleteOpenedFileInfo(hData);
    end;

    Leave;
  end;
  
  if VfsDebug.LoggingEnabled then begin
    WriteLog('[LEAVE] NtClose', Legacy.Format('Status: %x', [integer(result)]));
  end;
end; // .function Hook_NtClose

function IsSupportedFileInformationClass (FileInformationClass: integer): boolean;
begin
  result := (FileInformationClass <= High(byte)) and (FILE_INFORMATION_CLASS(byte(FileInformationClass)) in [FileBothDirectoryInformation, FileDirectoryInformation, FileFullDirectoryInformation, FileIdBothDirectoryInformation, FileIdFullDirectoryInformation, FileNamesInformation]);
end;

type
  TFileInfoConvertResult  = (TOO_SMALL_BUF, COPIED_ALL, TRUNCATED_NAME);
  TTruncatedNamesStrategy = (DONT_TRUNCATE_NAMES, TRUNCATE_NAMES);

function ConvertFileInfoStruct (SrcInfo: PNativeFileInfo; TargetFormat: FILE_INFORMATION_CLASS; {n} Buf: pointer; BufSize: integer; TruncatedNamesStrategy: TTruncatedNamesStrategy;
                                {OUT} var BytesWritten: integer): TFileInfoConvertResult;
var
{n} FileNameBuf:     pointer;
    FileNameBufSize: integer;
    StructBaseSize:  integer;
    StructFullSize:  integer;

begin
  {!} Assert(SrcInfo <> nil);
  {!} Assert(IsSupportedFileInformationClass(ord(TargetFormat)), string(Legacy.Format('Unsupported file information class: %d', [ord(TargetFormat)])));
  FileNameBuf := nil;
  // * * * * * //
  BytesWritten   := 0;
  StructBaseSize := WinNative.GetFileInformationClassSize(TargetFormat);
  StructFullSize := StructBaseSize + Int(SrcInfo.Base.FileNameLength);

  if (Buf = nil) or (BufSize < StructBaseSize)  then begin
    result := TOO_SMALL_BUF;
    exit;
  end;

  result := COPIED_ALL;

  if BufSize < StructFullSize then begin
    result := TRUNCATED_NAME;

    if TruncatedNamesStrategy = DONT_TRUNCATE_NAMES then begin
      exit;
    end;
  end;

  case TargetFormat of
    FileNamesInformation: PFILE_NAMES_INFORMATION(Buf).FileNameLength := SrcInfo.Base.FileNameLength;
   
    FileBothDirectoryInformation, FileDirectoryInformation, FileFullDirectoryInformation, FileIdBothDirectoryInformation, FileIdFullDirectoryInformation: begin
      UtilsB2.CopyMem(StructBaseSize, @SrcInfo.Base, Buf);
    end;
  else
    {!} Assert(IsSupportedFileInformationClass(ord(TargetFormat)), string(Legacy.Format('Unexpected unsupported file information class: %d', [ord(TargetFormat)])));
  end;

  FileNameBufSize := Min(BufSize - StructBaseSize, SrcInfo.Base.FileNameLength) and not $00000001;
  FileNameBuf     := UtilsB2.PtrOfs(Buf, StructBaseSize);

  UtilsB2.CopyMem(FileNameBufSize, myPWChar(SrcInfo.FileName), FileNameBuf);

  BytesWritten := StructBaseSize + FileNameBufSize;
end; // .function ConvertFileInfoStruct

const
  MASK_ALL_FILES: myWStr = '*'#0;

function Hook_NtQueryDirectoryFile (OrigFunc: WinNative.TNtQueryDirectoryFile; FileHandle: HANDLE; Event: HANDLE; ApcRoutine: pointer; ApcContext: PVOID; Io: PIO_STATUS_BLOCK; Buffer: PVOID;
                                    BufLength: ULONG; InfoClass: integer (* FILE_INFORMATION_CLASS *); SingleEntry: BOOLEAN; {n} Mask: PUNICODE_STRING; RestartScan: BOOLEAN): NTSTATUS; stdcall;
const
  ENTRIES_ALIGNMENT = 8;

type
  PPrevEntry = ^TPrevEntry;
  TPrevEntry = packed record
    NextEntryOffset: ULONG;
    FileIndex:       ULONG;
  end;

var
{Un} OpenedFile:             TOpenedFile;
{Un} FileInfo:               TFileInfo;
{n}  BufCaret:               pointer;
{n}  PrevEntry:              PPrevEntry;
     BufSize:                integer;
     BufSizeLeft:            integer;
     BytesWritten:           integer;
     IsFirstEntry:           boolean;
     Proceed:                boolean;
     TruncatedNamesStrategy: TTruncatedNamesStrategy;
     StructConvertResult:    TFileInfoConvertResult;
     EmptyMask:              UNICODE_STRING;
     EntryName:              myWStr;
     VfsIsActive:            boolean;

begin
  OpenedFile := nil;
  FileInfo   := nil;
  BufCaret   := nil;
  PrevEntry  := nil;
  BufSize    := BufLength;
  // * * * * * //
  with VfsOpenFiles.OpenFilesCritSection do begin
    if VfsDebug.LoggingEnabled then begin
      WriteLog('[ENTER] NtQueryDirectoryFile', Legacy.Format('Handle: %x. InfoClass: %s. Mask: %s. SingleEntry: %d', [Int(FileHandle), WinNative.FileInformationClassToStr(InfoClass), myAStr(Mask.ToWideStr()), ord(SingleEntry)]));
    end;

    Enter;

    OpenedFile  := VfsOpenFiles.GetOpenedFile(FileHandle);
    VfsIsActive := VfsBase.IsVfsActive;

    if RestartScan then begin
      Legacy.FreeAndNil(OpenedFile.DirListing);
    end;

    if (OpenedFile = nil) or (not IsSupportedFileInformationClass(InfoClass) and (OpenedFile.DirListing = nil)) or (Event <> 0) or (ApcRoutine <> nil) or (ApcContext <> nil) or (not VfsIsActive) then begin
      Leave;
      WriteLog('[INNER] NtQueryDirectoryFile', Legacy.Format('Calling native NtQueryDirectoryFile. OpenedFileRec: %x, VfsIsOn: %d, Event: %d. ApcRoutine: %d. ApcContext: %d', [Int(OpenedFile), ord(VfsIsActive), Int(Event), Int(ApcRoutine), Int(ApcContext)]));
      result := OrigFunc(FileHandle, Event, ApcRoutine, ApcContext, Io, Buffer, BufLength, InfoClass, SingleEntry, Mask, RestartScan);
    end else begin
      int(Io.Information) := 0;
      result              := STATUS_SUCCESS;
      Proceed             := true;

      // Disallow nil buffer
      if Proceed and (Buffer = nil) then begin
        Proceed := false;
        result  := STATUS_ACCESS_VIOLATION;
      end;

      // Validate buffer size
      if Proceed and (int(BufLength) < WinNative.GetFileInformationClassSize(InfoClass)) then begin
        Proceed := false;
        result  := STATUS_INFO_LENGTH_MISMATCH;
      end;
  
      // Validate information class
      if Proceed and not IsSupportedFileInformationClass(InfoClass) then begin
        Proceed := false;
        result  := STATUS_INVALID_INFO_CLASS;
      end;

      // Fill internal listing
      if OpenedFile.DirListing = nil then begin
        // NIL mask must treated as *
        if Mask = nil then begin
          EmptyMask.AssignExistingStr(MASK_ALL_FILES);
          Mask := @EmptyMask;
        end;

        OpenedFile.FillDirListing(Mask.ToWideStr());
      end;

      // Signal of scanning end, if necessary
      if Proceed and OpenedFile.DirListing.IsEnd then begin
        Proceed := false;

        if OpenedFile.DirListing.Count > 0 then begin
          result := STATUS_NO_MORE_FILES;
        end else begin
          result := STATUS_NO_SUCH_FILE;
        end;
      end;

      // Scan directory
      if Proceed then begin
        if VfsDebug.LoggingEnabled then begin
          WriteLog('[INNER] NtQueryDirectoryFile', Legacy.Format('Writing entries for buffer of size %d. Single entry: %d', [BufSize, ord(SingleEntry)]));
        end;

        BufCaret     := Buffer;
        BytesWritten := 1;

        while (BytesWritten > 0) and OpenedFile.DirListing.GetNextItem(FileInfo) do begin
          // Align next record to 8-bytes boundary from Buffer start
          BufCaret    := pointer(int(Buffer) + Alg.IntRoundToBoundary(int(Io.Information), ENTRIES_ALIGNMENT));
          BufSizeLeft := BufSize - (int(BufCaret) - int(Buffer));

          IsFirstEntry := OpenedFile.DirListing.FileInd = 1;

          if IsFirstEntry then begin
            TruncatedNamesStrategy := TRUNCATE_NAMES;
          end else begin
            TruncatedNamesStrategy := DONT_TRUNCATE_NAMES;
          end;

          StructConvertResult := ConvertFileInfoStruct(@FileInfo.Data, FILE_INFORMATION_CLASS(byte(InfoClass)), BufCaret, BufSizeLeft, TruncatedNamesStrategy, BytesWritten);

          if VfsDebug.LoggingEnabled then begin
            EntryName := Copy(FileInfo.Data.FileName, 1, Min(BytesWritten - WinNative.GetFileInformationClassSize(InfoClass), FileInfo.Data.Base.FileNameLength) div 2);
            WriteLog('[INNER] NtQueryDirectoryFile', myAStr('Written entry: ' + EntryName));
          end;

          if StructConvertResult <> TOO_SMALL_BUF then begin
            with PFILE_ID_BOTH_DIR_INFORMATION(BufCaret)^ do begin
              NextEntryOffset := 0;
              FileIndex       := 0;
            end;
          end;

          if StructConvertResult = TOO_SMALL_BUF then begin
            OpenedFile.DirListing.SeekRel(-1);

            if IsFirstEntry then begin
              result := STATUS_INFO_LENGTH_MISMATCH;
            end;            
          end else if StructConvertResult = TRUNCATED_NAME then begin
            if IsFirstEntry then begin
              result := STATUS_BUFFER_OVERFLOW;
              Inc(int(Io.Information), BytesWritten);
            end else begin
              OpenedFile.DirListing.SeekRel(-1);
            end;
          end else if StructConvertResult = COPIED_ALL then begin
            if PrevEntry <> nil then begin
              int(Io.Information) := int(BufCaret) - int(Buffer) + BytesWritten;
            end else begin
              int(Io.Information) := BytesWritten;
            end;
          end; // .else

          if (BytesWritten > 0) and (PrevEntry <> nil) then begin
            PrevEntry.NextEntryOffset := cardinal(int(BufCaret) - int(PrevEntry));
          end;

          PrevEntry := BufCaret;

          if SingleEntry then begin
            BytesWritten := 0;
          end;
        end; // .while
      end; // .if    

      Io.Status.Status := result;

      Leave;
    end; // .else
  end; // .with

  if VfsDebug.LoggingEnabled then begin
    WriteLog('[LEAVE] NtQueryDirectoryFile', Legacy.Format('Handle: %x. Status: %x. Written: %d bytes', [int(FileHandle), int(result), int(Io.Information)]));
  end;
end; // .function Hook_NtQueryDirectoryFile

function Hook_NtQueryDirectoryFileEx (OrigFunc: WinNative.TNtQueryDirectoryFileEx; FileHandle: HANDLE; Event: HANDLE; ApcRoutine: pointer; ApcContext: PVOID; Io: PIO_STATUS_BLOCK;
                                      Buffer: PVOID; BufLength: ULONG; InfoClass: integer (* FILE_INFORMATION_CLASS *); QueryFlags: integer; Mask: PUNICODE_STRING): NTSTATUS; stdcall;
var
  SingleEntry: LONGBOOL;
  RestartScan: LONGBOOL;

begin
  if VfsDebug.LoggingEnabled then begin
    WriteLog('NtQueryDirectoryFileEx', Legacy.Format('Handle: %x. QueryFlags: %x', [FileHandle, QueryFlags]));
  end;

  RestartScan := UtilsB2.Flags(QueryFlags).Have(WinNative.SL_RESTART_SCAN);
  SingleEntry := UtilsB2.Flags(QueryFlags).Have(WinNative.SL_RETURN_SINGLE_ENTRY);
  result      := WinNative.NtQueryDirectoryFile(FileHandle, Event, ApcRoutine, ApcContext, Io, Buffer, BufLength, InfoClass, SingleEntry, Mask, RestartScan);
end;

procedure InstallHooks;
var
  SetProcessDEPPolicy:        function (dwFlags: integer): LONGBOOL; stdcall;
  hDll:                       Windows.THandle;
  NtdllHandle:                integer;
  NtQueryDirectoryFileExAddr: WinNative.TNtQueryDirectoryFileEx;

begin
  with HooksCritSection do begin
    Enter;

    if not HooksInstalled then begin
      HooksInstalled := true;

      (* Trying to turn off DEP *)
      SetProcessDEPPolicy := Windows.GetProcAddress(Windows.GetModuleHandle('kernel32.dll'), myAStr('SetProcessDEPPolicy'));

      if @SetProcessDEPPolicy <> nil then begin
        if SetProcessDEPPolicy(0) then begin
          WriteLog('SetProcessDEPPolicy', 'DEP was turned off');
        end else begin
          WriteLog('SetProcessDEPPolicy', 'Failed to turn DEP off');
        end;
      end;

      // Ensure, that library with VFS hooks installed is never unloaded
      if System.IsLibrary then begin
        WinNative.GetModuleHandleExW(WinNative.GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS or WinNative.GET_MODULE_HANDLE_EX_FLAG_PIN, @InstallHooks, hDll);
      end;

      NtdllHandle:= Windows.GetModuleHandleA('ntdll.dll');
      {!} Assert(NtdllHandle <> 0, 'Failed to load ntdll.dll library');

      WriteLog('InstallHook', 'Installing NtQueryAttributesFile hook');
      NativeNtQueryAttributesFile := VfsPatching.SpliceWinApi
      (
        VfsApiDigger.GetRealProcAddress(NtdllHandle, 'NtQueryAttributesFile'),
        @Hook_NtQueryAttributesFile,
        @NtQueryAttributesFilePatch
      );

      WriteLog('InstallHook', 'Installing NtQueryFullAttributesFile hook');
      NativeNtQueryFullAttributesFile := VfsPatching.SpliceWinApi
      (
        VfsApiDigger.GetRealProcAddress(NtdllHandle, 'NtQueryFullAttributesFile'),
        @Hook_NtQueryFullAttributesFile,
        @NtQueryFullAttributesFilePatch
      );

      WriteLog('InstallHook', 'Installing NtOpenFile hook');
      NativeNtOpenFile := VfsPatching.SpliceWinApi
      (
        VfsApiDigger.GetRealProcAddress(NtdllHandle, 'NtOpenFile'),
        @Hook_NtOpenFile,
        @NtOpenFilePatch
      );

      WriteLog('InstallHook', 'Installing NtCreateFile hook');
      NativeNtCreateFile := VfsPatching.SpliceWinApi
      (
        VfsApiDigger.GetRealProcAddress(NtdllHandle, 'NtCreateFile'),
        @Hook_NtCreateFile,
        @NtCreateFilePatch
      );

      WriteLog('InstallHook', 'Installing NtClose hook');
      NativeNtClose := VfsPatching.SpliceWinApi
      (
        VfsApiDigger.GetRealProcAddress(NtdllHandle, 'NtClose'),
        @Hook_NtClose,
        @NtClosePatch
      );

      WriteLog('InstallHook', 'Installing NtQueryDirectoryFile hook');
      NativeNtQueryDirectoryFile := VfsPatching.SpliceWinApi
      (
        VfsApiDigger.GetRealProcAddress(NtdllHandle, 'NtQueryDirectoryFile'),
        @Hook_NtQueryDirectoryFile,
        @NtQueryDirectoryFilePatch
      );

      NtQueryDirectoryFileExAddr := VfsApiDigger.GetRealProcAddress(NtdllHandle, 'NtQueryDirectoryFileEx');

      if @NtQueryDirectoryFileExAddr <> nil then begin
        WriteLog('InstallHook', 'Installing NtQueryDirectoryFileEx hook');
        NativeNtQueryDirectoryFileEx := VfsPatching.SpliceWinApi
        (
          @NtQueryDirectoryFileExAddr,
          @Hook_NtQueryDirectoryFileEx,
          @NtQueryDirectoryFileExPatch
        );
      end;
    end; // .if

    Leave;
  end; // .with
end; // .procedure InstallHooks

procedure UninstallHooks;
begin
  with HooksCritSection do begin
    Enter;

    NtQueryAttributesFilePatch.Rollback;
    NtQueryFullAttributesFilePatch.Rollback;
    NtOpenFilePatch.Rollback;
    NtCreateFilePatch.Rollback;
    NtClosePatch.Rollback;
    NtQueryDirectoryFilePatch.Rollback;
    NtQueryDirectoryFileExPatch.Rollback;

    Leave;
  end;
end;

initialization
  System.IsMultiThread := true;
  HooksCritSection.Init;
finalization
  with VfsBase.VfsCritSection do begin
    Enter;
    VfsBase.ResetVfs;
    UninstallHooks;
    Leave;
  end;
end.