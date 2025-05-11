unit Concur;
(*
  Author:      Alexander Shostak aka Berserker.
  Description: Support for concurrency.
*)

(***)  interface  (***)

uses
  SysUtils,
  Windows,

  UtilsB2, Legacy;

type
  TCritSection = record
   private
    fCritSection: Windows.TRTLCriticalSection;

   public
    procedure Init;
    procedure Enter;
    procedure Leave;
    procedure Delete;
  end;

procedure AtomicAdd (var Dest: integer; Value: integer);
procedure AtomicSub (var Dest: integer; Value: integer);


(***)  implementation  (***)


procedure TCritSection.Init;
begin
  Windows.InitializeCriticalSection(fCritSection);
end;

procedure TCritSection.Enter;
begin
  Windows.EnterCriticalSection(fCritSection);
end;

procedure TCritSection.Leave;
begin
  Windows.LeaveCriticalSection(fCritSection);
end;

procedure TCritSection.Delete;
begin
  Windows.DeleteCriticalSection(fCritSection);
end;

procedure AtomicAdd (var Dest: integer; Value: integer); assembler;
asm
  lock add [eax], edx
end;

procedure AtomicSub (var Dest: integer; Value: integer); assembler;
asm
  lock sub [eax], edx
end;

end.