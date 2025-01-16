unit RscLists;
(*
  Description: Implements support for loaded resources (crc32 and name tracked) and resource lists.
               Resources can be stored in savegames, compared to each other by size and hash and
               smartly reloaded.
*)


(***)  interface  (***)

uses
  SysUtils, Math,
  UtilsB2, Crypto, DataLib, Files,
  Stores, Legacy;

type
  TResource = class
   private
     fName:     myAStr;
     fContents: myAStr;
     fCrc32:    integer;
     fTag:      integer;

    procedure Init (const Name, Contents: myAStr; Crc32: integer; Tag: integer = 0);

   public
    constructor CreateWithCrc32 (const Name, Contents: myAStr; Crc32: integer; Tag: integer = 0); overload;
    constructor Create (const Name, Contents: myAStr; Tag: integer = 0); overload;

    function  Assign (OtherResource: TResource): TResource;
    function  UpdateContentsAndHash (const Contents: myAStr): TResource;
    function  FastCompare (OtherResource: TResource): boolean;
    function  OwnsAddr ({n} Addr: myPChar): boolean;
    function  GetPtr: myPChar;

    property Name:     myAStr  read fName     write fName;
    property Contents: myAStr  read fContents write fContents;
    property Crc32:    integer read fCrc32    write fCrc32;
    property Tag:      integer read fTag    write fTag;
  end; // .class TResource

  TResourceList = class
   private
    {O} fItems:        {O} TList {OF TResource};
    {O} fItemIsLoaded: {U} TDict {OF ItemName => Ptr(boolean)};

    function GetItemsCount: integer;
    function GetItem (Ind: integer): TResource;

   public
    constructor Create;
    destructor  Destroy; override;

    procedure Clear;
    function  ItemExists (const ItemName: myAStr): boolean;
    function  Add ({O} Item: TResource): boolean;
    procedure Truncate (NewCount: integer);
    procedure Save (const SectionName: myAStr);
    procedure LoadFromSavedGame (const SectionName: myAStr);
    function  FastCompare (OtherResourceList: TResourceList): boolean;

    (* Returns error string *)
    function Export (const DestDir: myAStr): myAStr;

    property Count: integer read GetItemsCount;
    property Items[Ind: integer]: TResource read GetItem; default;
  end; // .class TResourceList


(***)  implementation  (***)


procedure TResource.Init (const Name, Contents: myAStr; Crc32: integer; Tag: integer);
begin
  Self.fName     := Name;
  Self.fContents := Contents;
  Self.fCrc32    := Crc32;
  Self.fTag      := Tag;
end;

constructor TResource.CreateWithCrc32 (const Name, Contents: myAStr; Crc32: integer; Tag: integer = 0);
begin
  Self.Init(Name, Contents, Crc32, Tag);
end;

constructor TResource.Create (const Name, Contents: myAStr; Tag: integer = 0);
begin
  Init(Name, Contents, Crypto.AnsiCrc32(Contents), Tag);
end;

function TResource.Assign (OtherResource: TResource): TResource;
begin
  {!} Assert(OtherResource <> nil);
  Self.fName     := OtherResource.fName;
  Self.fContents := OtherResource.fContents;
  Self.fCrc32    := OtherResource.fCrc32;
  result         := Self;
end;

function TResource.UpdateContentsAndHash (const Contents: myAStr): TResource;
begin
  Self.fContents := Contents;
  Self.fCrc32    := Crypto.AnsiCrc32(Contents);
  result         := Self;
end;

function TResource.FastCompare (OtherResource: TResource): boolean;
begin
  {!} Assert(OtherResource <> nil);
  result := (Self.fCrc32 = OtherResource.fCrc32) and (Length(Self.fContents) = Length(OtherResource.fContents));
end;

function TResource.OwnsAddr ({n} Addr: myPChar): boolean;
begin
  result := (cardinal(Addr) >= cardinal(Self.fContents)) and (cardinal(Addr) < cardinal(Self.fContents) + cardinal(Length(Self.fContents)));
end;

function TResource.GetPtr: myPChar;
begin
  result := myPChar(Self.fContents);
end;

constructor TResourceList.Create;
begin
  Self.fItems        := DataLib.NewList(UtilsB2.OWNS_ITEMS);
  Self.fItemIsLoaded := DataLib.NewDict(not UtilsB2.OWNS_ITEMS, DataLib.CASE_INSENSITIVE);
end;

destructor TResourceList.Destroy;
begin
  Legacy.FreeAndNil(Self.fItems);
  Legacy.FreeAndNil(Self.fItemIsLoaded);
  inherited;
end;

procedure TResourceList.Clear;
begin
  Self.fItems.Clear;
  Self.fItemIsLoaded.Clear;
end;

function TResourceList.ItemExists (const ItemName: myAStr): boolean;
begin
  result := Self.fItemIsLoaded[ItemName] <> nil;
end;

function TResourceList.Add ({O} Item: TResource): boolean;
begin
  result := Self.fItemIsLoaded[Item.Name] = nil;

  if result then begin
    Self.fItemIsLoaded[Item.Name] := Ptr(1);
    Self.fItems.Add(Item);
  end;
end;

procedure TResourceList.Truncate (NewCount: integer);
var
  i: integer;

begin
  {!} Assert(NewCount >= 0);
  // * * * * * //
  for i := NewCount + 1 to Self.fItems.Count - 1 do begin
    Self.fItemIsLoaded.DeleteItem(TResource(Self.fItems[i]).Name);
  end;

  Self.fItems.SetCount(NewCount);
end;

procedure TResourceList.Save (const SectionName: myAStr);
var
{Un} Item: TResource;
     i:    integer;

begin
  Item := nil;
  // * * * * * //
  with Stores.NewRider(SectionName) do begin
    WriteInt(Self.fItems.Count);

    for i := 0 to Self.fItems.Count - 1 do begin
      Item := TResource(Self.fItems[i]);
      WriteStr(Item.Name);
      WriteInt(Item.Tag);
      WriteInt(Item.Crc32);
      WriteStr(Item.Contents);
    end;
  end;
end;

procedure TResourceList.LoadFromSavedGame (const SectionName: myAStr);
var
  NumItems:     integer;
  ItemContents: myAStr;
  ItemName:     myAStr;
  ItemTag:      integer;
  ItemCrc32:    integer;
  i:            integer;

begin
  with Stores.NewRider(SectionName) do begin
    NumItems := ReadInt;

    for i := 1 to NumItems do begin
      ItemName     := ReadStr;
      ItemTag      := ReadInt;
      ItemCrc32    := ReadInt;
      ItemContents := ReadStr;
      Self.Add(TResource.Create(ItemName, ItemContents, ItemCrc32));
    end;
  end;
end;

function TResourceList.Export (const DestDir: myAStr): myAStr;
var
  Res:      boolean;
  ItemName: myAStr;
  ItemPath: myAStr;
  i:        integer;

begin
  result := '';
  Res    := Legacy.DirectoryExists(DestDir) or Legacy.CreateDir(DestDir);

  if not Res then begin
    result := 'Cannot recreate directory "' + DestDir + '"';
  end else begin
    i := 0;

    while Res and (i < Self.fItems.Count) do begin
      ItemName := TResource(Self.fItems[i]).Name;
      ItemPath := DestDir + '\' + ItemName;

      if Legacy.Pos('\', ItemName) <> 0 then begin
        Res := Files.ForcePath(Legacy.ExtractFilePath(ItemPath));

        if not Res then begin
          result := 'Cannot create directory "' + Legacy.ExtractFilePath(ItemPath) + '"';
        end;
      end;

      if Res then begin
        Res := Files.WriteFileContents(TResource(Self.fItems[i]).Contents, ItemPath);

        if not Res then begin
          result := 'Error writing to file "' + ItemPath + '"';
        end;
      end;

      Inc(i);
    end;
  end; // .else
end; // .function TResourceList.ExtractItems

function TResourceList.GetItemsCount: integer;
begin
  result := Self.fItems.Count;
end;

function TResourceList.GetItem (Ind: integer): TResource;
begin
  {!} Assert(Math.InRange(Ind, 0, Self.fItems.Count - 1), string(Legacy.Format('Cannot get item with index %d for resource list. Item is out of bounds', [Ind])));
  result := Self.fItems[Ind];
end;

function TResourceList.FastCompare (OtherResourceList: TResourceList): boolean;
var
  i: integer;

begin
  result := Self.fItems.Count = OtherResourceList.fItems.Count;

  if result then begin
    for i := 0 to Self.fItems.Count - 1 do begin
      if not TResource(Self.fItems[i]).FastCompare(TResource(OtherResourceList.fItems[i])) then begin
        result := false;
        exit;
      end;
    end;
  end;
end;

end.