unit Concur;
(* Author:      EtherniDee aka Berserker
   Desctiption: Support for concurrency *)

interface
uses Windows, SysUtils, UtilsB2;

type
  TCritSection = record
   private
    fCritSection: Windows.TRTLCriticalSection;

   public
    procedure Init;
    procedure Enter;
    procedure Leave;
    procedure Delete;
  end; // .record TCritSection


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

end.