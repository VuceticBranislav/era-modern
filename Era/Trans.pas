unit Trans;
{
DESCRIPTION:  Game localization support.
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses
  Windows, SysUtils, UtilsB2, DataLib, TypeWrappers,
  Files, StrLib, Json, Core,
  GameExt, RscLists, Heroes, EventMan, Legacy;


type
  TDict   = DataLib.TDict;
  TString = TypeWrappers.TString;

const
  LANG_DIR   : myAStr = 'Lang';
  TEMPL_CHAR : myChar = '@';

  MAP_LANG_DATA_SECTION : myAStr = 'Era.MapLangData';

  OVERRIDE_KEYS      = true;
  DONT_OVERRIDE_KEYS = false;


function SetLanguage (NewLanguage: myAStr): boolean;
procedure ReloadLanguageData; stdcall;
function  tr (const Key: myAStr; const Params: array of myAStr): myAStr;


var
  LocalDecimalSeparator:  myChar = '.';
  LocalThousandSeparator: myChar = ' ';
  NonBreakingSpace:       myChar = #160;
  DefMetricSuffixes:      array [0..2] of myAStr = ('K', 'M', 'G');
  MetricSuffixes:         array [0..2] of myAStr = ('K', 'M', 'G');


(***) implementation (***)


type
  TLangDict = {O} TDict {of TString};

var
{O} LangDict:         TLangDict;
{O} MapLangResources: RscLists.TResourceList;
    CurrentLanguage:  myAStr = 'en';


const
  BoolToStr: array [false..true] of myAStr = ('0', '1');

function SetLanguage (NewLanguage: myAStr): boolean;
var
  i: integer;

begin
  result := true;

  if NewLanguage = CurrentLanguage then begin
    exit;
  end;

  if (NewLanguage = '') or (Length(NewLanguage) > 20) then begin
    result := false;
    exit;
  end;

  for i := 1 to Length(NewLanguage) do begin
    if not (NewLanguage[i] in ['a'..'z', 'A'..'Z', '_']) then begin
      result := false;
      exit;
    end;
  end;

  CurrentLanguage := NewLanguage;
end;

function tr (const Key: myAStr; const Params: array of myAStr): myAStr;
var
{Un} Translation: TString;

begin
  Translation := LangDict[Key];
  // * * * * * //
  if Translation <> nil then begin
    result := StrLib.BuildStr(Translation.Value, Params, TEMPL_CHAR);
  end else begin
    result := Key;
  end;
end; // .function tr

function trDef (const Key: myAStr; const Params: array of myAStr; const DefValue: myAStr): myAStr;
var
{Un} Translation: TString;

begin
  Translation := LangDict[Key];
  // * * * * * //
  if Translation <> nil then begin
    result := StrLib.BuildStr(Translation.Value, Params, TEMPL_CHAR);
  end else begin
    result := DefValue;
  end;
end; // .function trDef

procedure UpdateLocaleConfig;
var
  Str: myAStr;
  i:   integer;

begin
  Str := trDef('era.locale.decimal_separator', [], '.');

  if Str = '' then begin
    Str := '.';
  end;

  LocalDecimalSeparator := Str[1];

  // ---------------------------------

  Str := trDef('era.locale.thousand_separator', [], ' ');

  if Str = '' then begin
    Str := ' ';
  end;

  LocalThousandSeparator := Str[1];

  // ---------------------------------

  Str := trDef('era.locale.non_breaking_space', [], #160);

  if Str = '' then begin
    Str := #160;
  end;

  NonBreakingSpace := Str[1];

  // ---------------------------------

  for i := Low(MetricSuffixes) to High(MetricSuffixes) do begin
    Str := trDef('era.locale.metric_suffixes.' + Legacy.IntToStr(i), [], DefMetricSuffixes[i]);

    if Str = '' then begin
      Str := DefMetricSuffixes[i];
    end;

    MetricSuffixes[i] := Str;
  end;
end; // .procedure UpdateLocaleConfig

procedure LoadLangData (const ItemName, FileContents: myAStr; OverrideExistingKeys: boolean);
var
{O} LangData: TlkJSONcustomlist;

  procedure ProcessBox (Box: TlkJSONcustomlist; const KeyPrefix: myAStr);
  var
    BoxIsObject: boolean;
    Key:         myAStr;
    Value:       Json.TlkJsonBase;
    ValueType:   TlkJSONtypes;
    i:           integer;

  begin
    BoxIsObject := Box.SelfType = Json.jsObject;

    for i := 0 to Box.Count - 1 do begin
      Key := KeyPrefix;

      if BoxIsObject then begin
        Key   := Key + myAStr(Json.TlkJsonObject(Box).NameOf[i]);
        Value := Json.TlkJsonObject(Box).FieldByIndex[i];
      end else begin
        Key   := Key + Legacy.IntToStr(i);
        Value := Box.Child[i];
      end;

      ValueType := Value.SelfType;

      if ValueType in [Json.jsObject, Json.jsList] then begin
        ProcessBox(Json.TlkJSONcustomlist(Value), Key + '.');
      end else if (ValueType <> Json.jsNull) and (OverrideExistingKeys or (LangDict[Key] = nil)) then begin
        if ValueType = Json.jsString then begin
          LangDict[Key] := TString.Create(Box.GetString(i));
        end else if ValueType = Json.jsNumber then begin
          LangDict[Key] := TString.Create(Legacy.FloatToStr(Box.GetDouble(i)));
        end else if ValueType = Json.jsBoolean then begin
          LangDict[Key] := TString.Create(BoolToStr[Box.GetBoolean(i)]);
        end;
      end;
    end; // .for
  end; // .procedure ProcessBox

begin
  LangData := nil;
  // * * * * * //
  UtilsB2.CastOrFree(TlkJson.ParseText(FileContents), Json.TlkJSONcustomlist, LangData);

  if LangData <> nil then begin
    ProcessBox(LangData, '');
  end else begin
    Core.NotifyError('Invalid language json file: "' + ItemName + '"');
  end;
  // * * * * * //
  Legacy.FreeAndNil(LangData);
end; // .procedure LoadLangData

procedure LoadLangFile (const FilePath: myAStr; OverrideExistingKeys: boolean);
var
  LangFileContents: myAStr;

begin
  if Files.ReadFileContents(FilePath, LangFileContents) then begin
    LoadLangData(FilePath, LangFileContents, OverrideExistingKeys);
  end;
end;

procedure LoadLangFiles (const Dir: myAStr; OverrideKeys: boolean);
begin
  with Files.Locate(Legacy.ExcludeTrailingPathDelimiter(Dir) + '\' + CurrentLanguage + '\*.json', Files.ONLY_FILES) do begin
    while FindNext do begin
      LoadLangFile(FoundPath, OverrideKeys);
    end;
  end;

  with Files.Locate(Legacy.ExcludeTrailingPathDelimiter(Dir) + '\*.json', Files.ONLY_FILES) do begin
    while FindNext do begin
      LoadLangFile(FoundPath, OverrideKeys);
    end;
  end;
end;

(* Loads global language files and imports data from them without overriding existing keys *)
procedure LoadGlobalLangFiles;
begin
  LoadLangFiles(GameExt.GameDir + '\' + LANG_DIR, DONT_OVERRIDE_KEYS);
  UpdateLocaleConfig;
end;

(* Loads map langauge files as resource list without any parsing *)
function LoadMapLangResources: {O} RscLists.TResourceList;
var
  MapDirName:   myAStr;
  FileContents: myAStr;

begin
  result     := RscLists.TResourceList.Create;
  MapDirName := GameExt.GetMapDirName;

  with Files.Locate(GameExt.GetMapResourcePath(LANG_DIR) + '\' + CurrentLanguage + '\*.json', Files.ONLY_FILES) do begin
    while FindNext do begin
      if Files.ReadFileContents(FoundPath, FileContents) then begin
        result.Add(RscLists.TResource.Create(MapDirName + '\' + FoundName, FileContents));
      end;
    end;
  end;

  with Files.Locate(GameExt.GetMapResourcePath(LANG_DIR) + '\*.json', Files.ONLY_FILES) do begin
    while FindNext do begin
      if Files.ReadFileContents(FoundPath, FileContents) then begin
        result.Add(RscLists.TResource.Create(MapDirName + '\' + FoundName, FileContents));
      end;
    end;
  end;
end;

procedure ImportMapLangResources;
var
{Un} Item: RscLists.TResource;
     i:    integer;

begin
  Item := nil;
  // * * * * * //
  for i := 0 to MapLangResources.Count - 1 do begin
    Item := RscLists.TResource(MapLangResources[i]);
    LoadLangData(Item.Name, Item.Contents, DONT_OVERRIDE_KEYS);
  end;
end;

procedure ReloadLanguageData; stdcall;
begin
  LangDict.Clear;
  Legacy.FreeAndNil(MapLangResources);
  MapLangResources := LoadMapLangResources;
  ImportMapLangResources;
  LoadGlobalLangFiles;
  EventMan.GetInstance.Fire('OnAfterReloadLanguageData');
end;

procedure OnAfterWoG (Event: GameExt.PEvent); stdcall;
begin
  LoadGlobalLangFiles;
end;

procedure OnBeforeScriptsReload (Event: GameExt.PEvent); stdcall;
begin
  ReloadLanguageData;
end;

procedure OnEraMapStart (Event: GameExt.PEvent); stdcall;
var
{On} UpdatedMapLangResources: RscLists.TResourceList;

begin
  UpdatedMapLangResources := LoadMapLangResources;
  // * * * * * //
  if not UpdatedMapLangResources.FastCompare(MapLangResources) then begin
    LangDict.Clear;
    UtilsB2.Exchange(int(MapLangResources), int(UpdatedMapLangResources));
    ImportMapLangResources;
    LoadGlobalLangFiles;
  end;
  // * * * * * //
  Legacy.FreeAndNil(UpdatedMapLangResources);
end;

procedure OnEraSaveScripts (Event: GameExt.PEvent); stdcall;
begin
  MapLangResources.Save(MAP_LANG_DATA_SECTION);
end;

procedure OnEraLoadScripts (Event: GameExt.PEvent); stdcall;
var
{O} LoadedMapLangResources: RscLists.TResourceList;

begin
  LoadedMapLangResources := RscLists.TResourceList.Create;
  // * * * * * //
  LoadedMapLangResources.LoadFromSavedGame(MAP_LANG_DATA_SECTION);

  if not LoadedMapLangResources.FastCompare(MapLangResources) then begin
    LangDict.Clear;
    UtilsB2.Exchange(int(MapLangResources), int(LoadedMapLangResources));
    ImportMapLangResources;
    LoadGlobalLangFiles;
  end;
  // * * * * * //
  Legacy.FreeAndNil(LoadedMapLangResources);
end;

procedure OnGenerateDebugInfo (Event: PEvent); stdcall;
var
  Error: myAStr;

begin
  Error := MapLangResources.Export(GameExt.GameDir + '\' + GameExt.DEBUG_DIR);

  if Error <> '' then begin
    Heroes.PrintChatMsg('{~r}' + Error + '{~r}');
  end;
end;

begin
  LangDict         := DataLib.NewDict(UtilsB2.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  MapLangResources := RscLists.TResourceList.Create;
  EventMan.GetInstance.On('OnAfterWoG', OnAfterWoG);
  EventMan.GetInstance.On('OnBeforeScriptsReload', OnBeforeScriptsReload);
  EventMan.GetInstance.On('OnGenerateDebugInfo', OnGenerateDebugInfo);
  EventMan.GetInstance.On('$OnEraMapStart', OnEraMapStart);
  EventMan.GetInstance.On('$OnEraSaveScripts', OnEraSaveScripts);
  EventMan.GetInstance.On('$OnEraLoadScripts', OnEraLoadScripts);
end.
