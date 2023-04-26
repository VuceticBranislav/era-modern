unit BinPatching;
{
DESCRIPTION:  Unit allows to load and apply binary patches in Era *.bin and *.json formats
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

interface
uses SysUtils, UtilsB2, PatchApi, Core, DataLib, Files, Legacy;

type
  (* Import *)
  TStrList = DataLib.TStrList;

  PBinPatchFile = ^TBinPatchFile;
  TBinPatchFile = packed record (* format *)
    NumPatches: integer;
    (*
    Patches:    array NumPatches of TBinPatch;
    *)
    Patches:    UtilsB2.TEmptyRec;
  end; // .record TBinPatchFile

  PBinPatch = ^TBinPatch;
  TBinPatch = packed record (* format *)
    Addr:     pointer;
    NumBytes: integer;
    (*
    Bytes:    array NumBytes of byte;
    *)
    Bytes:    UtilsB2.TEmptyRec;
  end; // .record TBinPatch

var
{O} PatchList:   {U} TStrList {of PatchSize: integer};
    PatchAutoId: integer = 1;

procedure ApplyPatches (const DirPath: myAStr);


implementation


function GetUniquePatchName (const BasePatchName: myAStr): myAStr;
begin
  result := Legacy.IntToStr(PatchAutoId) + ':' + BasePatchName;
  Inc(PatchAutoId);
end;

procedure ApplyBinPatch (const BinPatchSource: myAStr; BinPatchFile: PBinPatchFile);
const
  IS_CODE_PATCH = true;

var
{O} Patcher:    PatchApi.TPatcherInstance; // unmanaged
{U} Patch:      PBinPatch;
    PatchName:  myAStr;
    NumPatches: integer;
    i:          integer;  
  
begin
  {!} Assert(BinPatchFile <> nil);
  Patch := @BinPatchFile.Patches;
  // * * * * * //
  NumPatches := BinPatchFile.NumPatches;
  PatchName  := GetUniquePatchName(BinPatchSource);

  try
    Patcher := Core.GlobalPatcher.CreateInstance(myPChar(PatchName));

    for i := 1 to NumPatches do begin
      if not Patcher.Write(Patch.Addr, @Patch.Bytes, Patch.NumBytes, IS_CODE_PATCH).IsApplied() then begin
        Core.FatalError('Failed to write binary patch data at address '
                        + Legacy.IntToHex(integer(Patch.Addr), 8));
      end;

      Patch := UtilsB2.PtrOfs(Patch, sizeof(Patch^) + Patch.NumBytes);
    end;
  except
    Core.FatalError('Failed to apply binary patch "' + PatchName + '"');
  end; // .try
end; // .procedure ApplyBinPatch

function LoadBinPatch (const FilePath: myAStr; out PatchContents: myAStr): boolean;
var
  FileContents: myAStr;

begin
  result := Files.ReadFileContents(FilePath, FileContents) and
            (Length(FileContents) >= sizeof(TBinPatchFile));

  if result then begin
    PatchContents := FileContents;
  end;
end; // .function LoadBinPatch

procedure ApplyPatches (const DirPath: myAStr);
var
  FileContents: myAStr;
  
begin
  with Files.Locate(DirPath + '\*.bin', Files.ONLY_FILES) do begin
    while FindNext do begin
      if LoadBinPatch(DirPath + '\' + FoundName, FileContents) then begin
        PatchList.AddObj(FoundName, Ptr(Length(FileContents)));
        ApplyBinPatch(FoundName, pointer(FileContents));
      end;
    end;
  end;
end; // .procedure ApplyPatches

begin
  PatchList := DataLib.NewStrList(not UtilsB2.OWNS_ITEMS, DataLib.CASE_INSENSITIVE);
end.