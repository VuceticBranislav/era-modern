unit DlgMesLng;
{
DESCRIPTION:  Language unit
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

// D2006      --> XE10.3
// String     --> myAStr
// WideString --> myWStr
// Char       --> myChar
// WideChar   --> myWChar
// PChar      --> myPChar
// PWideChar  --> myPWChar
// PPChar     --> myPPChar;
// PAnsiString--> myPAStr;
// PWideString--> myPWStr;

(***)  interface   (***)
uses Legacy;

type
  TLangStrings =
  (
    STR_QUESTION
  ); // TLangStrings

  PLangStringsArr = ^TLangStringsArr;
  TLangStringsArr = array [TLangStrings] of myAStr;


var
  Strs: TLangStringsArr =
  (
    // STR_QUESTION
    'Question'
  ); // Lng


(***) implementation (***)


end.
