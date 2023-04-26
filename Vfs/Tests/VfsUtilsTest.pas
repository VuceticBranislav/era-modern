unit VfsUtilsTest;

(***)  interface  (***)

uses
  SysUtils, TestFramework,
  UtilsB2, WinUtils, DataLib,
  VfsUtils, VfsTestHelper, Legacy;

type
  TestUtils = class (TTestCase)
   published
    procedure TestAddBackslash;
    procedure TestMakePath;
    procedure TestNativeDirScanning;
    procedure TestGetDirectoryListing;
  end;


(***)  implementation  (***)


procedure TestUtils.TestAddBackslash;
begin
  CheckEquals('\', VfsUtils.AddBackslash(''));
  CheckEquals('\\', VfsUtils.AddBackslash('\\'));
  CheckEquals('Abba\', VfsUtils.AddBackslash('Abba'));
  CheckEquals('Abba\', VfsUtils.AddBackslash('Abba\'));
end;

procedure TestUtils.TestMakePath;
begin
  CheckEquals('', VfsUtils.MakePath(['', '\', '\\\']));
  CheckEquals('', VfsUtils.MakePath([]));
  CheckEquals('apple\back\hero', VfsUtils.MakePath(['apple', 'back', 'hero']));
  CheckEquals('apple\back\hero', VfsUtils.MakePath(['\\\\apple', '\\\back\\\\', '\', 'hero\\\\']));
end;

procedure TestUtils.TestNativeDirScanning;
var
  RootDir:     myWStr;
  FileInfo:    VfsUtils.TNativeFileInfo;
  DirItems:    DataLib.TStrList;
  DirContents: myAStr;

begin
  DirItems := DataLib.NewStrList(not UtilsB2.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  // * * * * * //
  RootDir := VfsTestHelper.GetTestsRootDir;

  with SysScanDir(RootDir, '*') do begin
    while IterNext(FileInfo.FileName, @FileInfo.Base) do begin
      DirItems.Add(myAStr(FileInfo.FileName));
    end;
  end;

  DirItems.Sort;
  DirContents := DirItems.ToText(#13#10);
  Check(DirContents = '.'#13#10'..'#13#10'503.html'#13#10'default'#13#10'Mods', 'Invalid directory listing. Got:'#13#10 + string(DirContents));
  // * * * * * //
  Legacy.FreeAndNil(DirItems);
end; // .procedure TestNativeDirScanning

procedure TestUtils.TestGetDirectoryListing;
var
  DirListing: VfsUtils.TDirListing;
  Exclude:    DataLib.TDict {of not nil};
  RootDir:    myWStr;
 
begin
  DirListing := VfsUtils.TDirListing.Create;
  Exclude    := DataLib.NewDict(not UtilsB2.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  // * * * * * //
  RootDir := VfsTestHelper.GetTestsRootDir;
  Exclude[VfsUtils.WideStrToCaselessKey('..')] := Ptr(1);

  VfsUtils.GetDirectoryListing(RootDir, '*', Exclude, DirListing);
  Check(DirListing.GetDebugDump() = '.'#13#10'503.html'#13#10'default'#13#10'Mods', 'Invalid directory listing. Got:'#13#10 + string(DirListing.GetDebugDump()));
  // * * * * * //
  Legacy.FreeAndNil(DirListing);
  Legacy.FreeAndNil(Exclude);
end; // .procedure TestUtils.TestGetDirectoryListing

begin
  RegisterTest(TestUtils.Suite);
end.