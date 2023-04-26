{ ******************************************************************
    Mersenne Twister Random Number Generator for pascal by Alex Vergara Gil
    Ported and improved by Alexander Shostak.
  ******************************************************************}

unit RandMt;

(***)  interface  (***)

uses
  Windows,

  WinUtils, Legacy;

const
  N          = 624;
  M          = 397;
  MATRIX_A   = integer($9908b0df);  { constant vector a }
  UPPER_MASK = integer($80000000);  { most significant w-r bits }
  LOWER_MASK = integer($7fffffff);  { least significant r bits }

type
  TRngStateVector = array [0..(N - 1)] of integer;

  PRngState = ^TRngState;
  TRngState = packed record
    mt:  TRngStateVector;
    mti: word;
    _z1: word;
  end;

  TRngMt = class
   protected
   {O} fCritSection: Windows.TRtlCriticalSection;
       mt:           TRngStateVector;
       mti:          word;

   public
    constructor Create; overload;
    constructor Create (Seed: integer); overload;
    constructor Create (SeedKeys: array of integer; NumSeedKeys: integer); overload;
    destructor Destroy; override;

    procedure Init; overload;
    procedure Init (Seed: integer); overload;
    procedure Init (InitKey: array of integer; KeyLength: word); overload;
    function  Random: integer; overload;
    function  Random (Min, Max: integer): integer; overload;

    function GetState: TRngState;
    procedure SetState (const State: TRngState);
  end; // .class TRngMt


var
{O} GlobalRng: TRngMt;


(***)  implementation  (***)


const
  mag01: array [0..1] of integer = (0, MATRIX_A);


constructor TRngMt.Create;
begin
  Windows.InitializeCriticalSection(Self.fCritSection);
  Self.Init;
end;

constructor TRngMt.Create (Seed: integer);
begin
  Windows.InitializeCriticalSection(Self.fCritSection);
  Self.Init(Seed);
end;

constructor TRngMt.Create (SeedKeys: array of integer; NumSeedKeys: integer);
begin
  Windows.InitializeCriticalSection(Self.fCritSection);
  Self.Init(SeedKeys, NumSeedKeys);
end;

destructor TRngMt.Destroy;
begin
  Windows.DeleteCriticalSection(Self.fCritSection);
end;

procedure TRngMt.Init;
var
  Seed: integer;

begin
  if not WinUtils.RtlGenRandom(@Seed, sizeof(Seed)) then begin
    Seed := WinUtils.GetMicroTime;
  end;

  Self.Init(Seed);
end;

procedure TRngMt.Init (Seed: integer);
var
  i: word;

begin
  Windows.EnterCriticalSection(Self.fCritSection);

  mt[0] := Seed and $ffffffff;

  for i := 1 to N - 1 do begin
    mt[i] := (1812433253 * (mt[i - 1] xor (mt[i - 1] shr 30)) + i);
      { See Knuth TAOCP Vol2. 3rd Ed. P.106 For multiplier.
        In the previous versions, MSBs of the seed affect
        only MSBs of the array mt[].
        2002/01/09 modified by Makoto Matsumoto }
    mt[i] := mt[i] and $ffffffff;
      { For >32 Bit machines }
  end;

  mti := N;

  Windows.LeaveCriticalSection(Self.fCritSection);
end; // .procedure TRngMt.Init

procedure TRngMt.Init (InitKey: array of integer; KeyLength: word);
var
  i, j, k, k1 : word;

begin
  Windows.EnterCriticalSection(Self.fCritSection);

  Self.Init(19650218);

  i := 1;
  j := 0;

  if N > KeyLength then k1 := N else k1 := KeyLength;

  for k := k1 downto 1 do
    begin
      mt[i] := (mt[i] xor ((mt[i-1] xor (mt[i-1] shr 30)) * 1664525)) + InitKey[j] + j; { non linear }
      mt[i] := mt[i] and $ffffffff; { for WORDSIZE > 32 machines }
      i     := i + 1;
      j     := j + 1;

      if i >= N then begin
        mt[0] := mt[N-1];
        i := 1;
      end;

      if j >= KeyLength then j := 0;
    end;

  for k := N-1 downto 1 do begin
    mt[i] := (mt[i] xor ((mt[i-1] xor (mt[i-1] shr 30)) * 1566083941)) - i; { non linear }
    mt[i] := mt[i] and $ffffffff; { for WORDSIZE > 32 machines }
    i     := i + 1;

    if i >= N then begin
      mt[0] := mt[N-1];
      i := 1;
    end;
  end;

  mt[0] := integer($80000000); { MSB is 1; assuring non-zero initial array }

  Windows.LeaveCriticalSection(Self.fCritSection);
end; // .procedure TRngMt.Init

function TRngMt.Random: integer;
var
  y : integer;
  k : word;

begin
  Windows.EnterCriticalSection(Self.fCritSection);

  if mti >= N then begin
    for k := 0 to (N-M)-1 do begin
      y     := (mt[k] and UPPER_MASK) or (mt[k+1] and LOWER_MASK);
      mt[k] := mt[k+M] xor (y shr 1) xor mag01[y and $1];
    end;

    for k := (N-M) to (N-2) do begin
      y     := (mt[k] and UPPER_MASK) or (mt[k+1] and LOWER_MASK);
      mt[k] := mt[k - (N - M)] xor (y shr 1) xor mag01[y and $1];
    end;

    y       := (mt[N-1] and UPPER_MASK) or (mt[0] and LOWER_MASK);
    mt[N-1] := mt[M-1] xor (y shr 1) xor mag01[y and $1];

    mti := 0;
  end;

  y   := mt[mti];
  mti := mti + 1;

  { Tempering }
  y := y xor (y shr 11);
  y := y xor ((y shl  7) and integer($9d2c5680));
  y := y xor ((y shl 15) and integer($efc60000));
  y := y xor (y shr 18);

  result := y;

  Windows.LeaveCriticalSection(Self.fCritSection);
end; // .function TRngMt.Random

function TRngMt.Random (Min, Max: integer): integer;
var
  Interval:    cardinal;
  IntervalCap: cardinal;
  Mask:        cardinal;

begin
  if Min >= Max then begin
    result := Min;
    exit;
  end;

  if (Min = Low(integer)) and (Max = High(integer)) then begin
    result := Self.Random();
    exit;
  end;

  Interval := cardinal(Max - Min) + 1;
  Mask     := $ffffffff;

  if Interval < (cardinal(1) shl 31) then begin
    IntervalCap := 1;

    while IntervalCap < Interval do begin
      IntervalCap := IntervalCap shl 1;
    end;

    Mask := IntervalCap - 1;
  end;

  repeat
    result := Self.Random() and Mask;
  until cardinal(result) < Interval;

  Inc(result, Min);
end; // .function TRngMt.Random

function TRngMt.GetState: TRngState;
begin
  Windows.EnterCriticalSection(Self.fCritSection);

  result.mt  := Self.mt;
  result.mti := Self.mti;
  result._z1 := 0;

  Windows.LeaveCriticalSection(Self.fCritSection);
end; // .function GetState

procedure TRngMt.SetState (const State: TRngState);
begin
  Windows.EnterCriticalSection(Self.fCritSection);

  Self.mt  := State.mt;
  Self.mti := State.mti;

  Windows.LeaveCriticalSection(Self.fCritSection);
end;

begin
  GlobalRng := TRngMt.Create;
end.
