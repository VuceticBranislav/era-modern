program VfsTest;
uses
  TestFramework,
  GuiTestRunner,
  VfsUtils,
  VfsBase,
  VfsDebug,
  VfsApiDigger,
  VfsExport,
  VfsOpenFiles,
  VfsHooks,
  VfsControl,
  VfsMatching,
  VfsTestHelper in 'Tests\VfsTestHelper.pas',
  VfsMatchingTest in 'Tests\VfsMatchingTest.pas',
  VfsDebugTest in 'Tests\VfsDebugTest.pas',
  VfsUtilsTest in 'Tests\VfsUtilsTest.pas',
  VfsBaseTest in 'Tests\VfsBaseTest.pas',
  VfsOpenFilesTest in 'Tests\VfsOpenFilesTest.pas',
  VfsIntegratedTest in 'Tests\VfsIntegratedTest.pas',
  VfsApiDiggerTest in 'Tests\VfsApiDiggerTest.pas';

begin
  System.IsMultiThread := true;
  VfsTestHelper.InitConsole;
  TGUITestRunner.RunRegisteredTests;
end.
