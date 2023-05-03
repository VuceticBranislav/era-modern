unit EraUtils;
(*
  Miscellaneous useful functions, used by other modules.
*)


(***)  interface  (***)

uses
  SysUtils, Math,
  UtilsB2, Alg, StrLib, Legacy,
  Trans;


(* Converts integer to string, separating each three digit group by ThousandSeparator characer.
   Specify IgnoreSmallNumbers to leave values <= 9999 as is. Uses game locale settings.
   Example: 2138945 => "2 138 945" *)
function DecorateInt (Value: integer; IgnoreSmallNumbers: boolean = false): myAStr;

(* Formats given positive or negative quantity to human-readable string with desired constraints on length
   and maximal number of digits. Uses game locale settings and metric suffixes like "K", "M" and "G".
   Examples:
    FormatQuantity(1234567890, 10, 10) = '1234567890'
    FormatQuantity(-1234567890, 6, 4)  = '-1.23G'
    FormatQuantity(123, 2, 4)          = '0K'
    FormatQuantity(1234567890, 6, 2)   = '1G'
    FormatQuantity(1234567890, 1, 2)   = '9'
    FormatQuantity(1234567890, 1, 0)   = ''
   *)
function FormatQuantity (Value, MaxLen, MaxDigits: integer): myAStr;


(***)  implementation  (***)


function DecorateInt (Value: integer; IgnoreSmallNumbers: boolean = false): myAStr;
const
  GROUP_LEN = 3;

var
  StrLen:      integer;
  IsNegative:  boolean;
  NumDelims:   integer;
  FinalStrLen: integer;
  i, j:        integer;

begin
  result := Legacy.IntToStr(Value);

  if (Value >= 1000) or (Value < -1000) then begin
    IsNegative  := Value < 0;
    StrLen      := Length(result);
    NumDelims   := (StrLen - 1 - ord(IsNegative)) div GROUP_LEN;
    FinalStrLen := StrLen + NumDelims;
    SetLength(result, FinalStrLen);
    
    j := FinalStrLen;

    for i := 0 to StrLen - 1 - ord(IsNegative) do begin
      if (i > 0) and (i mod 3 = 0) then begin
        result[j] := Trans.LocalThousandSeparator;
        Dec(j);
      end;

      result[j] := result[StrLen - i];
      Dec(j);
    end;    
  end; // .if
end; // .function DecorateInt

function FormatQuantity (Value, MaxLen, MaxDigits: integer): myAStr;
const
  METRIC_STEP_MULTIPLIER  = 1000;
  METRIC_STEP_DIGITS      = 3;
  MIN_FRACTIONAL_PART_LEN = 2;
  METRIC_SUFFIX_LEN       = 1;
  DECIMAL_SEPARATOR_LEN   = 1;

var
  Str:                    myAStr;
  IsNegative:             boolean;
  SignLen:                integer;
  MetricSuffixInd:        integer;
  MetricSuffixMultiplier: integer;
  IntPart:                integer;
  FractPart:              integer;
  NumIntPartDigits:       integer;
  NumFractPartDigits:     integer;
  MaxNumFractPartDigits:  integer;

begin
  result     := '';
  IsNegative := Value < 0;

  if IsNegative then begin
    result := '-';
  end;

  // Exit if no space for any sensibile result, '-' for single character negative number
  if (MaxLen <= 0) or (MaxDigits <= 0) or ((MaxLen <= 1) and IsNegative) then begin
    exit;
  end;

  SignLen   := ord(IsNegative);
  MaxDigits := Min(MaxLen - SignLen, MaxDigits);
  Str       := Legacy.IntToStr(Value);

  // Exit if simple int => str conversion fits all requirements
  if (Length(result) <= MaxLen) and (Length(Str) - SignLen <= MaxDigits) then begin
    result := Str;
    exit;
  end;

  // No space for metric suffix like "K", just bound value to -9..+9 range.
  if MaxDigits <= 1 then begin
    result := Legacy.IntToStr(Alg.ToRange(Value, -9, 9));
    exit;
  end;

  (* From now there is a space for at least one digit and a metric suffix
     Metric suffix will always be used from this point, with or without decimal point *)

  // Convert number to positive
  if Value < 0 then begin
    Value := -Value;

    if Value < 0 then begin
      Value := High(integer);
    end;
  end;

  // Exclude sign and metric suffix from constraints
  Dec(MaxLen, METRIC_SUFFIX_LEN + SignLen);
  MaxDigits := Min(MaxLen, MaxDigits);

  // Determine order of magnitude
  MetricSuffixMultiplier := METRIC_STEP_MULTIPLIER;
  MetricSuffixInd        := Low(Trans.MetricSuffixes);

  while (MetricSuffixInd < High(Trans.MetricSuffixes)) and (Value >= (MetricSuffixMultiplier * METRIC_STEP_MULTIPLIER)) do begin
    MetricSuffixMultiplier := MetricSuffixMultiplier * METRIC_STEP_MULTIPLIER;
    Inc(MetricSuffixInd);
  end;

  // Calculate integer part
  IntPart := Value div MetricSuffixMultiplier;

  // If there is no space even for full integer part digits, produce value with zero int part and one step higher
  // order of magnitude like "0K" for 700 or "0M" for 19 350
  NumIntPartDigits := Alg.CountDigits(IntPart);

  if NumIntPartDigits > MaxLen then begin
    result := result + '0' + Trans.MetricSuffixes[MetricSuffixInd + 1];
    exit;
  end;

  // Handle case, where is no space for fractional part like "0K", "36K" or "5M".
  if MaxLen < (NumIntPartDigits + MIN_FRACTIONAL_PART_LEN) then begin
    result := result + Legacy.IntToStr(IntPart) + Trans.MetricSuffixes[MetricSuffixInd];
    exit;
  end;

  // Allocate space for decimal separator
  Dec(MaxLen, DECIMAL_SEPARATOR_LEN);
  MaxDigits := Min(MaxLen, MaxDigits);

  // Calculate fractional part
  FractPart := Value mod MetricSuffixMultiplier;

  (* Here we know, that there is definitely space for integer part and probably not full fractional part *)

  NumFractPartDigits    := METRIC_STEP_DIGITS * (MetricSuffixInd + 1);
  MaxNumFractPartDigits := MaxDigits - NumIntPartDigits;

  // Truncate fractional part
  if NumFractPartDigits > MaxNumFractPartDigits then begin
    FractPart := FractPart div Alg.IntPow10(NumFractPartDigits - MaxNumFractPartDigits);
  end;

  if FractPart <> 0 then begin
    // Make fractional part leading zeroes prefix
    NumFractPartDigits := Min(MaxNumFractPartDigits, NumFractPartDigits);
    SetLength(Str, NumFractPartDigits - Alg.CountDigits(FractPart));

    if Str <> '' then begin
      Legacy.FillChar(Str[1], Length(Str), '0');
    end;

    // Produce final result with integer part, fractional part and metric suffix
    result := StrLib.Concat([result, Legacy.IntToStr(IntPart), Trans.LocalDecimalSeparator, Str, Legacy.IntToStr(FractPart), Trans.MetricSuffixes[MetricSuffixInd]]);
  end else begin
    // Got zero length fractional part, skip it
    result := StrLib.Concat([result, Legacy.IntToStr(IntPart), Trans.MetricSuffixes[MetricSuffixInd]]);
  end;
end; // .function FormatQuantity

end.