unit FastRand;
(*
  Pseudo random number generator classes and tools.
*)


(***)  interface  (***)

uses
  SysUtils,
  Windows,

  Crypto,
  UtilsB2,
  WinUtils, Legacy;


type
  TRng = class abstract
   public
    procedure Seed (NewSeed: integer); virtual; abstract;
    function Random: integer; virtual; abstract;
    function GetStateSize: integer; virtual; abstract;
    procedure ReadState (Buf: pointer); virtual; abstract;
    procedure WriteState (Buf: pointer); virtual; abstract;
    function RandomRange (MinValue, MaxValue: integer): integer; virtual;
  end;

  TCLangRng = class (TRng)
   protected
    fState: integer;

   public
    constructor Create (Seed: integer);

    procedure Seed (NewSeed: integer); override;
    function Random: integer; override;
    function GetStateSize: integer; override;
    procedure ReadState (Buf: pointer); override;
    procedure WriteState (Buf: pointer); override;
    function RandomRange (MinValue, MaxValue: integer): integer; override;
  end;

  TSplitMix32Rng = class (TRng)
   protected
    fState: integer;

   public
    constructor Create (Seed: integer);

    procedure Seed (NewSeed: integer); override;
    function Random: integer; override;
    function GetStateSize: integer; override;
    procedure ReadState (Buf: pointer); override;
    procedure WriteState (Buf: pointer); override;
  end;

  TXoroshiro128Rng = class (TRng)
   protected
       fState:  array [0..3] of integer;
   {O} fSeeder: TRng;

   public
    constructor Create (Seed: integer);
    destructor Destroy; override;

    procedure Seed (NewSeed: integer); override;
    function Random: integer; override;
    function GetStateSize: integer; override;
    procedure ReadState (Buf: pointer); override;
    procedure WriteState (Buf: pointer); override;
  end;

  TThreadSafeRng = class (TRng)
   protected
   {O} fRealRng:     TRng;
   {O} fCritSection: Windows.TRtlCriticalSection;

   public
    constructor Create ({O} RealRng: TRng);
    destructor Destroy; override;

    procedure Seed (NewSeed: integer); override;
    function Random: integer; override;
    function GetStateSize: integer; override;
    procedure ReadState (Buf: pointer); override;
    procedure WriteState (Buf: pointer); override;
    function RandomRange (MinValue, MaxValue: integer): integer; override;
  end;


function GenerateSecureSeed: integer;
function RandomRange (Rng: TRng; MinValue, MaxValue: integer): integer;


(***)  implementation  (***)


function TRng.RandomRange (MinValue, MaxValue: integer): integer;
begin
  result := FastRand.RandomRange(Self, MinValue, MaxValue);
end;

constructor TSplitMix32Rng.Create (Seed: integer);
begin
  inherited Create;

  Self.fState := Seed;
end;

procedure TSplitMix32Rng.Seed (NewSeed: integer);
begin
  Self.fState := NewSeed;
end;

function TSplitMix32Rng.Random: integer;
begin
  Inc(Self.fState, integer($9E3779B9));
  result := Self.fState xor (Self.fState shr 15);
  result := result * integer($85EBCA6B);
  result := result xor (result shr 13);
  result := result * integer($C2B2AE35);
  result := result xor (result shr 16);
end;

function TSplitMix32Rng.GetStateSize: integer;
begin
  result := sizeof(Self.fState);
end;

procedure TSplitMix32Rng.ReadState (Buf: pointer);
begin
  {!} Assert(Buf <> nil);
  UtilsB2.CopyMem(sizeof(Self.fState), Buf, @Self.fState);
end;

procedure TSplitMix32Rng.WriteState (Buf: pointer);
begin
  {!} Assert(Buf <> nil);
  UtilsB2.CopyMem(sizeof(Self.fState), @Self.fState, Buf);
end;

constructor TCLangRng.Create (Seed: integer);
begin
  inherited Create;

  Self.fState := Seed;
end;

procedure TCLangRng.Seed (NewSeed: integer);
begin
  Self.fState := NewSeed;
end;

function TCLangRng.Random: integer;
begin
  Self.fState := Self.fState * 214013 + 2531011;

  result := (Self.fState shr 16) and $7FFF;
end;

function TCLangRng.RandomRange (MinValue, MaxValue: integer): integer;
begin
  if MinValue >= MaxValue then begin
    result := MinValue;
  end else if (MinValue = Low(integer)) and (MaxValue = High(integer)) then begin
    result := Self.Random;
  end else begin
    result := MinValue + Self.Random mod (MaxValue - MinValue + 1);
  end;
end;

function TCLangRng.GetStateSize: integer;
begin
  result := sizeof(Self.fState);
end;

procedure TCLangRng.ReadState (Buf: pointer);
begin
  {!} Assert(Buf <> nil);
  UtilsB2.CopyMem(sizeof(Self.fState), Buf, @Self.fState);
end;

procedure TCLangRng.WriteState (Buf: pointer);
begin
  {!} Assert(Buf <> nil);
  UtilsB2.CopyMem(sizeof(Self.fState), @Self.fState, Buf);
end;

function rotl (Value: integer; NumBits: integer): integer; inline;
begin
  result := (Value shl NumBits) or (Value shr (32 - NumBits));
end;

constructor TXoroshiro128Rng.Create (Seed: integer);
begin
  inherited Create;

  Self.fSeeder := TSplitMix32Rng.Create(Seed);
  Self.Seed(Seed);
end;

destructor TXoroshiro128Rng.Destroy;
begin
  Legacy.FreeAndNil(Self.fSeeder);

  inherited;
end;

procedure TXoroshiro128Rng.Seed (NewSeed: integer);
var
  i: integer;

begin
  Self.fSeeder.Seed(NewSeed);

  for i := 0 to High(Self.fState) do begin
    Self.fState[i] := Self.fSeeder.Random;
  end;
end;

function TXoroshiro128Rng.Random: integer;
var
  Temp: integer;

begin
  result         := rotl(Self.fState[1] * 5, 7) * 9;
  Temp           := Self.fState[1] shl 9;
  Self.fState[2] := Self.fState[2] xor Self.fState[0];
  Self.fState[3] := Self.fState[3] xor Self.fState[1];
  Self.fState[1] := Self.fState[1] xor Self.fState[2];
  Self.fState[0] := Self.fState[0] xor Self.fState[3];
  Self.fState[2] := Self.fState[2] xor Temp;
  Self.fState[3] := rotl(Self.fState[3], 11);
end;

function TXoroshiro128Rng.GetStateSize: integer;
begin
  result := sizeof(Self.fState);
end;

procedure TXoroshiro128Rng.ReadState (Buf: pointer);
begin
  {!} Assert(Buf <> nil);
  UtilsB2.CopyMem(sizeof(Self.fState), Buf, @Self.fState);
end;

procedure TXoroshiro128Rng.WriteState (Buf: pointer);
begin
  {!} Assert(Buf <> nil);
  UtilsB2.CopyMem(sizeof(Self.fState), @Self.fState, Buf);
end;

constructor TThreadSafeRng.Create ({O} RealRng: TRng);
begin
  {!} Assert(RealRng <> nil);
  inherited Create;

  Self.fRealRng := RealRng;
  Windows.InitializeCriticalSection(Self.fCritSection);
end;

destructor TThreadSafeRng.Destroy;
begin
  Windows.DeleteCriticalSection(Self.fCritSection);
  Legacy.FreeAndNil(Self.fRealRng);

  inherited;
end;

procedure TThreadSafeRng.Seed (NewSeed: integer);
begin
  Windows.EnterCriticalSection(Self.fCritSection);

  try
    Self.fRealRng.Seed(NewSeed);
  except
    on E: Exception do begin
      Windows.LeaveCriticalSection(Self.fCritSection);

      raise E;
    end;
  end;
end;

function TThreadSafeRng.Random: integer;
begin
  Windows.EnterCriticalSection(Self.fCritSection);

  try
    result := Self.fRealRng.Random;
  except
    on E: Exception do begin
      Windows.LeaveCriticalSection(Self.fCritSection);

      raise E;
    end;
  end;
end;

function TThreadSafeRng.GetStateSize: integer;
begin
  Windows.EnterCriticalSection(Self.fCritSection);

  try
    result := Self.fRealRng.GetStateSize();
  except
    on E: Exception do begin
      Windows.LeaveCriticalSection(Self.fCritSection);

      raise E;
    end;
  end;
end;

procedure TThreadSafeRng.ReadState (Buf: pointer);
begin
  Windows.EnterCriticalSection(Self.fCritSection);

  try
    Self.fRealRng.ReadState(Buf);
  except
    on E: Exception do begin
      Windows.LeaveCriticalSection(Self.fCritSection);

      raise E;
    end;
  end;
end;

procedure TThreadSafeRng.WriteState (Buf: pointer);
begin
  Windows.EnterCriticalSection(Self.fCritSection);

  try
    Self.fRealRng.WriteState(Buf);
  except
    on E: Exception do begin
      Windows.LeaveCriticalSection(Self.fCritSection);

      raise E;
    end;
  end;
end;

function TThreadSafeRng.RandomRange (MinValue, MaxValue: integer): integer;
begin
  Windows.EnterCriticalSection(Self.fCritSection);

  try
    result := FastRand.RandomRange(Self, MinValue, MaxValue);
  except
    on E: Exception do begin
      Windows.LeaveCriticalSection(Self.fCritSection);

      raise E;
    end;
  end;
end;

function GenerateSecureSeed: integer;
begin
  if not WinUtils.RtlGenRandom(@result, sizeof(result)) then begin
    result := Crypto.Tm32Encode(WinUtils.GetMicroTime);
  end;
end;

function RandomRange (Rng: TRng; MinValue, MaxValue: integer): integer;
const
  MAX_UNBIAS_ATTEMPTS = 100;

var
  RangeLen:         cardinal;
  BiasedRangeLen:   cardinal;
  MaxUnbiasedValue: cardinal;
  i:                integer;

begin
  {!} Assert(Rng <> nil);

  if MinValue >= MaxValue then begin
    result := MinValue;
    exit;
  end;

  result := Rng.Random;

  if (MinValue > Low(integer)) or (MaxValue < High(integer)) then begin
    i                := 2;
    RangeLen         := cardinal(MaxValue - MinValue) + 1;
    BiasedRangeLen   := High(cardinal) mod RangeLen + 1;

    if BiasedRangeLen = RangeLen then begin
      BiasedRangeLen := 0;
    end;

    MaxUnbiasedValue := High(cardinal) - BiasedRangeLen;

    while (cardinal(result) > MaxUnbiasedValue) and (i <= MAX_UNBIAS_ATTEMPTS) do begin
      result := Rng.Random;
      Inc(i);
    end;

    result := MinValue + integer(cardinal(result) mod RangeLen);
  end;
end;

end.