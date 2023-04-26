unit TypeWrappers;
{
DESCRIPTION:  Wrappers for primitive types into objects suitable for storing in containers
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

// D2006      --> XE11.0
// String     --> myAStr
// WideString --> myWStr
// Char       --> myChar
// WideChar   --> myWChar
// PChar      --> myPChar
// PWideChar  --> myPWChar
// PPChar     --> myPPChar;
// PAnsiString--> myPAStr;
// PWideString--> myPWStr;

(***)  interface  (***)
uses Legacy, UtilsB2;

type
  TString = class (UtilsB2.TCloneable)
    Value: myAStr;

    constructor Create (const Value: myAStr);
    procedure Assign (Source: UtilsB2.TCloneable); override;

    class function ToPchar ({n} Str: TString): myPChar; static;
    class function ToString ({n} Str: TString; const DefValue: myAStr = ''): myAStr; reintroduce; static;
  end;

  TInt = class (UtilsB2.TCloneable)
    Value: integer;

    constructor Create (Value: integer);
    procedure Assign (Source: UtilsB2.TCloneable); override;

    class function ToInteger ({n} Wrapper: TInt; DefValue: integer = 0): integer; static;
  end;

  TWideString = class (UtilsB2.TCloneable)
    Value: myWStr;

    constructor Create (const Value: myWStr);
    procedure Assign (Source: UtilsB2.TCloneable); override;
  end;

  TEventHandler = class (UtilsB2.TCloneable)
    Handler:  UtilsB2.TEventHandler;

    constructor Create (Handler: UtilsB2.TEventHandler);
    procedure Assign (Source: UtilsB2.TCloneable); override;
  end;


(***) implementation (***)


constructor TString.Create (const Value: myAStr);
begin
  Self.Value := Value;
end;

procedure TString.Assign (Source: UtilsB2.TCloneable);
begin
  Self.Value := (Source as TString).Value;
end;

class function TString.ToPchar ({n} Str: TString): myPChar;
begin
  if Str = nil then begin
    result := '';
  end else begin
    result := myPChar(Str.Value);
  end;
end;

class function TString.ToString ({n} Str: TString; const DefValue: myAStr = ''): myAStr;
begin
  if Str = nil then begin
    result := DefValue;
  end else begin
    result := Str.Value;
  end;
end;

constructor TInt.Create (Value: integer);
begin
  Self.Value := Value;
end;

procedure TInt.Assign (Source: UtilsB2.TCloneable);
begin
  Self.Value := (Source as TInt).Value;
end;

class function TInt.ToInteger ({n} Wrapper: TInt; DefValue: integer = 0): integer;
begin
  if Wrapper = nil then begin
    result := DefValue;
  end else begin
    result := Wrapper.Value;
  end;
end;

constructor TWideString.Create (const Value: myWStr);
begin
  Self.Value := Value;
end;

procedure TWideString.Assign (Source: UtilsB2.TCloneable);
begin
  Self.Value := (Source as TWideString).Value;
end;

constructor TEventHandler.Create (Handler: UtilsB2.TEventHandler);
begin
  Self.Handler := Handler;
end; // .constructor TEventHandler.Create

procedure TEventHandler.Assign (Source: UtilsB2.TCloneable);
begin
  Self.Handler := (Source as TEventHandler).Handler;
end;

end.
