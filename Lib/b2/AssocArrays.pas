unit AssocArrays;
(*
  DESCRIPTION:  Associative array implementation
  AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
*)

(*
  The implementation uses binary tree and (in case of array with string keys) user provided hash function to store and retrieve data.
  Tree is automatically rebalanced when critical search depth is met which is equal to 2X of balanced tree height.
  Rebalancing is done by converting tree to linear node array and inserting nodes in empty tree.
  Possible improvement: compare hash first and preprocessed key then, thus getting rid of item chains and leaving nodes only.
  In this case no O(n^2) performance is possible.
*)

(***)  interface  (***)
uses
  Math,
  SysUtils,

  Alg,
  Crypto,
  UtilsB2, Legacy;

const
  LEFT_CHILD  = false;
  RIGHT_CHILD = true;

  NO_KEY_PREPROCESS_FUNC = nil;


type
  THashFunc          = function (const Str: myAStr): integer;
  TKeyPreprocessFunc = function (const OrigKey: myAStr): myAStr;

  TChildNodeSide = boolean;

  PStrBinTreeItem = ^TStrBinTreeItem;
  TStrBinTreeItem = record
         Key:      myAStr;
    {OUn}Value:    pointer;
    {On} NextItem: PStrBinTreeItem;
  end;

  PStrBinTreeNode = ^TStrBinTreeNode;
  TStrBinTreeNode = record
        Hash:       integer;
    {O} Item:       PStrBinTreeItem;
        ChildNodes: array [LEFT_CHILD..RIGHT_CHILD] of {On} PStrBinTreeNode;
  end;

  TStrBinTreeNodeArray = array of {O} PStrBinTreeNode;

  TStrBinTreeLinearNodeArray = record
    NodeArray: TStrBinTreeNodeArray; // Nodes are sorted by hash
    NodeCount: integer;
    ItemCount: integer;
  end;

  TStrBinTree = class (UtilsB2.TCloneable)
    (***) protected (***)
      {On}  fRoot:              PStrBinTreeNode;
            fHashFunc:          THashFunc;
      {n}   fKeyPreprocessFunc: TKeyPreprocessFunc;
            fOwnsItems:         boolean;
            fItemsAreObjects:   boolean;
            fItemGuardProc:     UtilsB2.TItemGuardProc;
      {On}  fItemGuard:         UtilsB2.TItemGuard;
            fItemCount:         integer;
            fNodeCount:         integer;
            fIterNodes:         array of {U} PStrBinTreeNode;
      {U}   fIterCurrItem:      PStrBinTreeItem;
            fIterNodeInd:       integer;
            fLocked:            boolean;


      function  CloneItem (Item: PStrBinTreeItem): {O} PStrBinTreeItem;
      function  CloneNode ({n} Node: PStrBinTreeNode): {On} PStrBinTreeNode;
      procedure FreeItemValue (Item: PStrBinTreeItem);
      procedure FreeNode ({IN} var {n} Node: PStrBinTreeNode);
      procedure RemoveNode ({n} ParentNode: PStrBinTreeNode; ItemNode: PStrBinTreeNode);
      procedure RemoveItem
      (
        {n} ParentNode: PStrBinTreeNode;
            ItemNode:   PStrBinTreeNode;
        {n} ParentItem: PStrBinTreeItem;
            Item:       PStrBinTreeItem
      );

      (*
        All nodes are placed in NodeArray and disconnected from each other.
        Original binary tree is emptied. Nodes are sorted by hash.
      *)
      procedure ConvertToLinearNodeArray (out Res: TStrBinTreeLinearNodeArray);

      function  FindItem
      (
                    Hash:       integer;
              const Key:        myAStr;
        out {ni}    ParentNode: PStrBinTreeNode;
        out {ni}    ItemNode:   PStrBinTreeNode;
        out {ni}    ParentItem: PStrBinTreeItem;
        out {ni}    Item:       PStrBinTreeItem
      ): boolean;

    (***) public (***)
      constructor Create
      (
                      HashFunc:           THashFunc;
                  {n} KeyPreprocessFunc:  TKeyPreprocessFunc;
                      OwnsItems:          boolean;
                      ItemsAreObjects:    boolean;
                      ItemGuardProc:      UtilsB2.TItemGuardProc;
        {IN} var  {n} ItemGuard:          UtilsB2.TItemGuard
      );

      destructor  Destroy; override;

      procedure Assign (Source: UtilsB2.TCloneable); override;
      procedure Clear;
      function  GetPreprocessedKey (const Key: myAStr): myAStr;
      function  IsValidValue ({n} Value: pointer): boolean;
      function  CalcCritDepth: integer; inline;
      procedure Rebuild;
      function  GetValue (const Key: myAStr): {n} pointer;
      function  HasKey (const Key: myAStr): boolean;
      function  GetExistingValue (const Key: myAStr; out {Un} Res: pointer): boolean;
      procedure SetValue (const Key: myAStr; {OUn} NewValue: pointer);
      function  DeleteItem (const Key: myAStr): boolean;

      (* Returns value with specified key and NILify it in the array *)
      function  TakeValue (Key: myAStr; out {OUn} Value: pointer): boolean;

      (* Returns old value *)
      function  ReplaceValue
      (
                  Key:      myAStr;
            {OUn} NewValue: pointer;
        out {OUn} OldValue: pointer
      ): boolean;

      procedure Merge (Source: TStrBinTree);

      procedure BeginIterate;
      function  IterateNext (out Key: myAStr; out {Un} Value: pointer): boolean;
      procedure EndIterate;

      property  HashFunc:          THashFunc read fHashFunc;
      property  KeyPreprocessFunc: TKeyPreprocessFunc read fKeyPreprocessFunc;
      property  OwnsItems:         boolean read fOwnsItems;
      property  ItemsAreObjects:   boolean read fItemsAreObjects;
      property  ItemCount:         integer read fItemCount;
      property  ItemGuardProc:     UtilsB2.TItemGuardProc read fItemGuardProc;
      property  NodeCount:         integer read fNodeCount;
      property  Locked:            boolean read fLocked;
      property  Items[const Key: myAStr]: pointer read {n} GetValue write {OUn} SetValue; default;
  end; // .class TStrBinTree

  PObjBinTreeNode = ^TObjBinTreeNode;
  TObjBinTreeNode = record
          Hash:       integer;  // Hash is encoded {U} Key: pointer
    {OUn} Value:      pointer;
          ChildNodes: array [LEFT_CHILD..RIGHT_CHILD] of {On} PObjBinTreeNode;
  end;

  TObjBinTreeNodeArray = array of {O} PObjBinTreeNode;

  TObjBinTreeLinearNodeArray = record
    NodeArray: TObjBinTreeNodeArray; // Nodes are sorted by hash
    NodeCount: integer;
  end;

  TObjBinTree = class (UtilsB2.TCloneable)
    (***) protected (***)
      {On}  fRoot:            PObjBinTreeNode;
            fOwnsItems:       boolean;
            fItemsAreObjects: boolean;
            fItemGuardProc:   UtilsB2.TItemGuardProc;
      {On}  fItemGuard:       UtilsB2.TItemGuard;
            fNodeCount:       integer;
            fIterNodes:       array of {U} PObjBinTreeNode;
            fIterNodeInd:     integer;
            fLocked:          boolean;

      function  HashToKey (Hash: integer): {n} pointer;
      function  KeyToHash (Key: {n} pointer): integer;
      procedure FreeNodeValue (Node: PObjBinTreeNode);
      procedure FreeNode ({IN} var {n} Node: PObjBinTreeNode);
      procedure RemoveNode ({n} ParentNode: PObjBinTreeNode; Node: PObjBinTreeNode);
      function  CloneNode (Node: PObjBinTreeNode): {O} PObjBinTreeNode;

      (*
        All nodes are placed in NodeArray and disconnected from each other.
        Original binary tree is emptied. Nodes are sorted by hash.
      *)
      procedure ConvertToLinearNodeArray (out Res: TObjBinTreeLinearNodeArray);

      function  FindItem
      (
            {n}   Key:        pointer;
        out {ni}  ParentNode: PObjBinTreeNode;
        out {ni}  ItemNode:   PObjBinTreeNode
      ): boolean;

    (***) public (***)
      constructor Create
      (
                      OwnsItems:        boolean;
                      ItemsAreObjects:  boolean;
                      ItemGuardProc:    UtilsB2.TItemGuardProc;
        {IN} var  {n} ItemGuard:        UtilsB2.TItemGuard
      );
      destructor  Destroy; override;
      procedure Assign (Source: UtilsB2.TCloneable); override;
      procedure Clear;
      function  IsValidValue ({n} Value: pointer): boolean;
      function  CalcCritDepth: integer; inline;
      procedure Rebuild;
      function  GetValue ({n} Key: pointer): {n} pointer;
      function  GetExistingValue ({n} Key: pointer; out {Un} Res: pointer): boolean;
      procedure SetValue ({n} Key: pointer; {OUn} NewValue: pointer);
      function  DeleteItem ({n} Key: pointer): boolean;

      (* Returns value with specified key and NILify it in the array *)
      function  TakeValue ({n} Key: pointer; out {OUn} Value: pointer): boolean;

      {Returns old value}
      function  ReplaceValue
      (
            {n}   Key:      pointer;
            {OUn} NewValue: pointer;
        out {OUn} OldValue: pointer
      ): boolean;

      procedure BeginIterate;
      function  IterateNext (out {Un} Key: pointer; out {Un} Value: pointer): boolean;
      procedure EndIterate;

      property  OwnsItems:                boolean read fOwnsItems;
      property  ItemsAreObjects:          boolean read fItemsAreObjects;
      property  ItemCount:                integer read fNodeCount;
      property  ItemGuardProc:            UtilsB2.TItemGuardProc read fItemGuardProc;
      property  NodeCount:                integer read fNodeCount;
      property  Locked:                   boolean read fLocked;
      property  Items[{n} Key: pointer]:  {OUn} pointer read GetValue write SetValue; default;
  end; // .class TObjBinTree

  PStrHashTableItem = ^TStrHashTableItem;
  TStrHashTableItem = record
    SearchDistance:  integer; // Counts from 1. 0 means empty
    Hash:            integer;
    PreprocessedKey: myAStr;
    Value:           pointer;
    Key:             myAStr;

    procedure MakeEmpty; inline;
    procedure Exchange (var OtherItem: TStrHashTableItem); inline;
  end;

  TStrHashTableItems          = array of TStrHashTableItem;
  TStrHashTableItemUnmanaged  = array [0..sizeof(TStrHashTableItem) - 1] of byte;
  TStrHashTableItemsUnmanaged = array of TStrHashTableItemUnmanaged;

  TStrHashTable = class (UtilsB2.TCloneable)
   const
    MIN_CAPACITY    = 16;                  // Must be power of 2
    MAX_LOAD_FACTOR = 0.85;
    MIN_LOAD_FACTOR = MAX_LOAD_FACTOR / 4;
    GROWTH_FACTOR   = 2;                   // Must be power of 2

   protected
         fItems:             TStrHashTableItems;
         fCapacity:          integer;
         fModCapacityMask:   integer; // (X and fModCapacityMask) = (X mod fCapacity)
         fSize:              integer;
         fMinSize:           integer;
         fMaxSize:           integer;
         fOwnsItems:         boolean;
         fItemsAreObjects:   boolean;
         fHashFunc:          THashFunc;
    {n}  fKeyPreprocessFunc: TKeyPreprocessFunc;
    {On} fItemGuard:         UtilsB2.TItemGuard;
         fItemGuardProc:     UtilsB2.TItemGuardProc;
         fIterPos:           integer;
         fLocked:            boolean;

    function GetPreprocessedKey (const Key: myAStr): myAStr; inline;
    procedure FreeItemValue (Item: PStrHashTableItem);
    procedure FreeValues;

    (* Must be called each time, the capacity is changed to maintain dependent values *)
    procedure OnChangeCapacity;

    (* Discards existing storage and recreates the new one. Be sure to free/move values first *)
    procedure CreateNewStorage (NewCapacity: integer);

    (* On failure ItemInd is index to continue checking for possible displacement *)
    function FindItem (Hash: integer; const PreprocessedKey: myAStr; var ItemInd: integer): {Un} PStrHashTableItem;

    procedure AddValue (Hash: integer; const Key, PreprocessedKey: myAStr; {OUn} NewValue: pointer; ItemInd: integer);
    procedure Rehash (NewCapacity: integer);
    procedure Grow;
    procedure Shrink;

   public
    {$IFDEF INSPECT_SEARCH_DISTANCE}
      TotalSearchDistance: integer; // Increased by item search distance during items search only, not on rehashing
      MaxSearchDistance:   integer; // Maximum search distance, met during items search
    {$ENDIF}

    constructor Create (HashFunc: THashFunc; {n} KeyPreprocessFunc: TKeyPreprocessFunc; OwnsItems, ItemsAreObjects: boolean; ItemGuardProc: UtilsB2.TItemGuardProc;
                        {On} ItemGuard: UtilsB2.TItemGuard);

    destructor  Destroy; override;

    procedure Assign (Source: UtilsB2.TCloneable); override;
    procedure Clear;
    function  IsValidValue ({n} Value: pointer): boolean;
    function  GetValue (const Key: myAStr): {n} pointer;
    function  HasKey (const Key: myAStr): boolean;
    function  GetExistingValue (const Key: myAStr; {out} var {Un} Res: pointer): boolean;
    procedure SetValue (const Key: myAStr; {OUn} NewValue: pointer);
    function  DeleteItem (const Key: myAStr): boolean;

    (* Returns value with specified key and nilify it in the array *)
    function TakeValue (const Key: myAStr; {out} var {OUn} Value: pointer): boolean;

    (* Returns old value *)
    function ReplaceValue (const Key: myAStr; {OUn} NewValue: pointer; {out} var {OUn} OldValue: pointer): boolean;

    procedure BeginIterate;
    function  IterateNext (out Key: myAStr; out {Un} Value: pointer): boolean;
    procedure EndIterate;

    property HashFunc:          THashFunc read fHashFunc;
    property KeyPreprocessFunc: TKeyPreprocessFunc read fKeyPreprocessFunc;
    property OwnsItems:         boolean read fOwnsItems;
    property ItemsAreObjects:   boolean read fItemsAreObjects;
    property ItemCount:         integer read fSize;
    property ItemGuardProc:     UtilsB2.TItemGuardProc read fItemGuardProc;
    property Locked:            boolean read fLocked;
    property Items[const Key: myAStr]: pointer read {n} GetValue write {OUn} SetValue; default;

  end; // .class TStrHashTable

  PObjHashTableItem = ^TObjHashTableItem;
  TObjHashTableItem = record
    SearchDistance: integer; // Counts from 1. 0 means empty
    Hash:           integer;
    Value:          pointer;

    procedure MakeEmpty; inline;
    procedure Exchange (var OtherItem: TObjHashTableItem); inline;
  end;

  TObjHashTableItems = array of TObjHashTableItem;

  TObjHashTable = class (UtilsB2.TCloneable)
   const
    MIN_CAPACITY    = 16;                  // Must be power of 2
    MAX_LOAD_FACTOR = 0.85;
    MIN_LOAD_FACTOR = MAX_LOAD_FACTOR / 4;
    GROWTH_FACTOR   = 2;                   // Must be power of 2

   protected
         fItems:             TObjHashTableItems;
         fCapacity:          integer;
         fModCapacityMask:   integer; // (X and fModCapacityMask) = (X mod fCapacity)
         fSize:              integer;
         fMinSize:           integer;
         fMaxSize:           integer;
         fOwnsItems:         boolean;
         fItemsAreObjects:   boolean;
    {On} fItemGuard:         UtilsB2.TItemGuard;
         fItemGuardProc:     UtilsB2.TItemGuardProc;
         fIterPos:           integer;
         fLocked:            boolean;

    function  HashToKey (Hash: integer): {n} pointer; inline;
    function  KeyToHash (Key: {n} pointer): integer; inline;
    procedure FreeItemValue (Item: PObjHashTableItem);
    procedure FreeValues;

    (* Must be called each time, the capacity is changed to maintain dependent values *)
    procedure OnChangeCapacity;

    (* Discards existing storage and recreates the new one. Be sure to free/move values first *)
    procedure CreateNewStorage (NewCapacity: integer);

    (* On failure ItemInd is index to continue checking for possible displacement *)
    function FindItem (Hash: integer; var ItemInd: integer): {Un} PObjHashTableItem;

    procedure AddValue (Hash: integer; {OUn} NewValue: pointer; ItemInd: integer);
    procedure Rehash (NewCapacity: integer);
    procedure Grow;
    procedure Shrink;

   public
    {$IFDEF INSPECT_SEARCH_DISTANCE}
      TotalSearchDistance: integer; // Increased by item search distance during items search only, not on rehashing
      MaxSearchDistance:   integer; // Maximum search distance, met during items search
    {$ENDIF}

    constructor Create (OwnsItems, ItemsAreObjects: boolean; ItemGuardProc: UtilsB2.TItemGuardProc; {On} ItemGuard: UtilsB2.TItemGuard);

    destructor  Destroy; override;

    procedure Assign (Source: UtilsB2.TCloneable); override;
    procedure Clear;
    function  IsValidValue ({n} Value: pointer): boolean;
    function  GetValue ({n} Key: pointer): {n} pointer;
    function  HasKey ({n} Key: pointer): boolean;
    function  GetExistingValue ({n} Key: pointer; {out} var {Un} Res: pointer): boolean;
    procedure SetValue ({n} Key: pointer; {OUn} NewValue: pointer);
    function  DeleteItem ({n} Key: pointer): boolean;

    (* Returns value with specified key and nilify it in the array *)
    function TakeValue ({n} Key: pointer; {out} var {OUn} Value: pointer): boolean;

    (* Returns old value *)
    function ReplaceValue ({n} Key: pointer; {OUn} NewValue: pointer; {out} var {OUn} OldValue: pointer): boolean;

    procedure BeginIterate;
    function  IterateNext (out {Un} Key: pointer; out {Un} Value: pointer): boolean;
    procedure EndIterate;

    property OwnsItems:         boolean read fOwnsItems;
    property ItemsAreObjects:   boolean read fItemsAreObjects;
    property ItemCount:         integer read fSize;
    property ItemGuardProc:     UtilsB2.TItemGuardProc read fItemGuardProc;
    property Locked:            boolean read fLocked;
    property Items[{n} Key: pointer]: pointer read {n} GetValue write {OUn} SetValue; default;

  end; // .class TObjHashTable

  TAssocArray = TStrHashTable;
  TObjArray   = TObjHashTable;

function NewAssocArr (HashFunc: THashFunc; {n} KeyPreprocessFunc: TKeyPreprocessFunc; OwnsItems, ItemsAreObjects: boolean; ItemType: TClass; AllowNil: boolean): TAssocArray;
function NewSimpleAssocArr (HashFunc: THashFunc; {n} KeyPreprocessFunc: TKeyPreprocessFunc): TAssocArray;

function NewStrictAssocArr ({n} TypeGuard: TClass; OwnsItems: boolean = true): TAssocArray;
function NewObjArr (OwnsItems, ItemsAreObjects: boolean; ItemType: TClass; AllowNil: boolean): TObjArray;

function NewSimpleObjArr: TObjArray;
function NewStrictObjArr ({n} TypeGuard: TClass; OwnsItems: boolean = true): TObjArray;

function NewSimpleStrBinTree (HashFunc: THashFunc; {n} KeyPreprocessFunc: TKeyPreprocessFunc): TStrBinTree;

procedure MergeAssocArrays (Destination, Source: TAssocArray);
procedure MergeObjArrays (Destination, Source: TObjArray);


(***)  implementation  (***)


const
  EMPTY_ITEM_SEARCH_DISTANCE = 0;
  DEBUG_BUILD                = false;


constructor TStrBinTree.Create
(
                HashFunc:           THashFunc;
            {n} KeyPreprocessFunc:  TKeyPreprocessFunc;
                OwnsItems:          boolean;
                ItemsAreObjects:    boolean;
                ItemGuardProc:      UtilsB2.TItemGuardProc;
  {IN} var  {n} ItemGuard:          UtilsB2.TItemGuard
);
begin
  {!} Assert(@HashFunc      <> nil);
  {!} Assert(@ItemGuardProc <> nil);
  Self.fHashFunc          :=  HashFunc;
  Self.fKeyPreprocessFunc :=  KeyPreprocessFunc;
  Self.fOwnsItems         :=  OwnsItems;
  Self.fItemsAreObjects   :=  ItemsAreObjects;
  Self.fItemGuardProc     :=  ItemGuardProc;
  Self.fItemGuard         :=  ItemGuard;
  Self.fItemCount         :=  0;
  Self.fNodeCount         :=  0;
  ItemGuard               :=  nil;
end; // .constructor TStrBinTree.Create

destructor TStrBinTree.Destroy;
begin
  Self.Clear;
  Legacy.FreeAndNil(Self.fItemGuard);
end; // .destructor TStrBinTree.Destroy

function TStrBinTree.CloneItem (Item: PStrBinTreeItem): {O} PStrBinTreeItem;
begin
  {!} Assert(Item <> nil);
  {!} Assert(Self.IsValidValue(Item.Value));
  New(result);
  result.Key := Item.Key;

  if Item.NextItem <> nil then begin
    result.NextItem := Self.CloneItem(Item.NextItem);
  end else begin
    result.NextItem := nil;
  end;

  if (Item.Value = nil) or (not Self.OwnsItems) then begin
    result.Value := Item.Value;
  end else begin
    {!} Assert(Self.ItemsAreObjects);
    {!} Assert(TObject(Item.Value) is UtilsB2.TCloneable);
    result.Value := UtilsB2.TCloneable(Item.Value).Clone;
  end;
end; // .function TStrBinTree.CloneItem

function TStrBinTree.CloneNode ({n} Node: PStrBinTreeNode): {On} PStrBinTreeNode;
begin
  if Node = nil then begin
    result  := nil;
  end else begin
    New(result);
    result.Hash                    := Node.Hash;
    result.Item                    := Self.CloneItem(Node.Item);
    result.ChildNodes[LEFT_CHILD]  := Self.CloneNode(Node.ChildNodes[LEFT_CHILD]);
    result.ChildNodes[RIGHT_CHILD] := Self.CloneNode(Node.ChildNodes[RIGHT_CHILD]);
  end;
end; // .function TStrBinTree.CloneNode

procedure TStrBinTree.Assign (Source: UtilsB2.TCloneable);
var
{U} SrcArr: TStrBinTree;

begin
  {!} Assert(not Self.Locked);
  {!} Assert(Source <> nil);
  SrcArr  := Source as TStrBinTree;
  // * * * * * //
  if Self <> Source then begin
    Self.Clear;
    Self.fHashFunc          := SrcArr.HashFunc;
    Self.fKeyPreprocessFunc := SrcArr.KeyPreprocessFunc;
    Self.fOwnsItems         := SrcArr.OwnsItems;
    Self.fItemsAreObjects   := SrcArr.ItemsAreObjects;
    Self.fItemGuardProc     := SrcArr.ItemGuardProc;
    Self.fItemGuard         := SrcArr.fItemGuard.Clone;
    Self.fItemCount         := SrcArr.ItemCount;
    Self.fNodeCount         := SrcArr.NodeCount;
    Self.fRoot              := Self.CloneNode(SrcArr.fRoot);
  end; // .if
end; // .procedure TStrBinTree.Assign

procedure TStrBinTree.FreeItemValue (Item: PStrBinTreeItem);
begin
  {!} Assert(Item <> nil);
  if Self.OwnsItems then begin
    if Self.ItemsAreObjects then begin
      TObject(Item.Value).Free;
    end else begin
      FreeMem(Item.Value);
    end;
  end;

  Item.Value := nil;
end; // .procedure TStrBinTree.FreeItemValue

procedure TStrBinTree.RemoveNode ({n} ParentNode: PStrBinTreeNode; ItemNode: PStrBinTreeNode);
var
{U} RightClosestNodeParent: PStrBinTreeNode;
{U} RightClosestNode:       PStrBinTreeNode;
    ItemNodeIsRoot:         boolean;
    ItemNodeSide:           TChildNodeSide;

begin
  {!} Assert(ItemNode <> nil);
  RightClosestNodeParent := nil;
  RightClosestNode       := nil;
  ItemNodeSide           := false;
  // * * * * * //
  ItemNodeIsRoot := ParentNode = nil;

  if Self.NodeCount = 1 then begin
    {!} Assert(ItemNodeIsRoot);
    {!} Assert(ItemNode = Self.fRoot);
    Dispose(Self.fRoot); Self.fRoot := nil;
  end else begin
    if not ItemNodeIsRoot then begin
      ItemNodeSide := ItemNode.Hash >= ParentNode.Hash;
    end;

    (* N
      - -
    *)
    if
      (ItemNode.ChildNodes[LEFT_CHILD] = nil) and
      (ItemNode.ChildNodes[RIGHT_CHILD] = nil)
    then begin
      ParentNode.ChildNodes[ItemNodeSide] := nil;
      Dispose(ItemNode); ItemNode := nil;
    end // .if
    (* N
      - R
    *)
    else if ItemNode.ChildNodes[LEFT_CHILD] = nil then begin
      if ItemNodeIsRoot then begin
        Self.fRoot := ItemNode.ChildNodes[RIGHT_CHILD];
      end else begin
        ParentNode.ChildNodes[ItemNodeSide] := ItemNode.ChildNodes[RIGHT_CHILD];
      end;

      Dispose(ItemNode); ItemNode := nil;
    end // .elseif
    (* N
      L -
    *)
    else if ItemNode.ChildNodes[RIGHT_CHILD] = nil then begin
      if ItemNodeIsRoot then begin
        Self.fRoot := ItemNode.ChildNodes[LEFT_CHILD];
      end else begin
        ParentNode.ChildNodes[ItemNodeSide] := ItemNode.ChildNodes[LEFT_CHILD];
      end;

      Dispose(ItemNode); ItemNode := nil;
    end // .elseif
    (* N
      L R
    *)
    else begin
      RightClosestNodeParent := ItemNode;
      RightClosestNode       := ItemNode.ChildNodes[RIGHT_CHILD];

      while RightClosestNode.ChildNodes[LEFT_CHILD] <> nil do begin
        RightClosestNodeParent := RightClosestNode;
        RightClosestNode       := RightClosestNode.ChildNodes[LEFT_CHILD];
      end;

      ItemNode.Item := RightClosestNode.Item; RightClosestNode.Item := nil;
      ItemNode.Hash := RightClosestNode.Hash;
      Self.RemoveNode(RightClosestNodeParent, RightClosestNode);
    end; // .else
  end; // .else
end; // .procedure TStrBinTree.RemoveNode

procedure TStrBinTree.RemoveItem
(
  {n} ParentNode: PStrBinTreeNode;
      ItemNode:   PStrBinTreeNode;
  {n} ParentItem: PStrBinTreeItem;
      Item:       PStrBinTreeItem
);

begin
  {!} Assert(ItemNode <> nil);
  {!} Assert(Item <> nil);
  Self.FreeItemValue(Item);

  if (ItemNode.Item = Item) and (Item.NextItem = nil) then begin
    Self.RemoveNode(ParentNode, ItemNode);
    (* RemoveNode is recursive procedure not affecting the counter *)
    Dec(Self.fNodeCount);
  end else begin
    if ItemNode.Item = Item then begin
      ItemNode.Item := Item.NextItem;
    end else begin
      {!} Assert(ParentItem <> nil);
      ParentItem.NextItem := Item.NextItem;
    end;
  end; // .else

  Dispose(Item); Item := nil;
  Dec(Self.fItemCount);
end; // .procedure TStrBinTree.RemoveItem

procedure TStrBinTree.FreeNode ({IN} var {n} Node: PStrBinTreeNode);
var
{U} Item:     PStrBinTreeItem;
{U} NextItem: PStrBinTreeItem;

begin
  Item    := nil;
  NextItem := nil;
  // * * * * * //
  if Node <> nil then begin
    Item := Node.Item;

    while Item <> nil do begin
      NextItem := Item.NextItem;
      Self.FreeItemValue(Item);
      Dispose(Item); Item := nil;
      Item := NextItem;
    end;

    Self.FreeNode(Node.ChildNodes[LEFT_CHILD]);
    Self.FreeNode(Node.ChildNodes[RIGHT_CHILD]);
    Dispose(Node); Node := nil;
  end; // .if
end; // .procedure TStrBinTree.FreeNode

procedure TStrBinTree.Clear;
begin
  {!} Assert(not Self.Locked);
  Self.FreeNode(Self.fRoot);
  Self.fItemCount := 0;
  Self.fNodeCount := 0;
end;

function TStrBinTree.GetPreprocessedKey (const Key: myAStr): myAStr;
begin
  if @Self.KeyPreprocessFunc = nil then begin
    result := Key;
  end else begin
    result := Self.KeyPreprocessFunc(Key);
  end;
end;

function TStrBinTree.IsValidValue ({n} Value: pointer): boolean;
begin
  result := Self.ItemGuardProc(Value, Self.ItemsAreObjects, UtilsB2.TItemGuard(Self.fItemGuard));
end;

function TStrBinTree.CalcCritDepth: integer;
begin
  result := Alg.IntLog2(Self.NodeCount + 1) shl 1;
end;

function AssocArrayCompareNodes (A, B: integer): integer;
begin
  if PStrBinTreeNode(A).Hash > PStrBinTreeNode(B).Hash then begin
    result := +1;
  end else if PStrBinTreeNode(A).Hash < PStrBinTreeNode(B).Hash then begin
    result := -1;
  end else begin
    result := 0;
  end;
end;

procedure TStrBinTree.ConvertToLinearNodeArray (out Res: TStrBinTreeLinearNodeArray);
var
    LeftInd:              integer;
    RightInd:             integer;
    RightCheckInd:        integer;
    NumNotProcessedNodes: integer;
{U} CurrNode:             PStrBinTreeNode;
    i:                    integer;

begin
  SetLength(Res.NodeArray, Self.NodeCount);
  Res.NodeCount := Self.NodeCount;
  Res.ItemCount := Self.ItemCount;

  if Self.NodeCount > 0 then begin
    CurrNode                := Self.fRoot;
    LeftInd                 := 0;
    Res.NodeArray[LeftInd]  := CurrNode;
    RightInd                := Self.NodeCount;
    RightCheckInd           := RightInd - 1;
    NumNotProcessedNodes    := Self.NodeCount - 1;

    while NumNotProcessedNodes > 0 do begin
      if CurrNode.ChildNodes[RIGHT_CHILD] <> nil then begin
        Dec(RightInd);
        Res.NodeArray[RightInd] :=  CurrNode.ChildNodes[RIGHT_CHILD];
        Dec(NumNotProcessedNodes);
      end;

      if CurrNode.ChildNodes[LEFT_CHILD] <> nil then begin
        CurrNode  :=  CurrNode.ChildNodes[LEFT_CHILD];
        Inc(LeftInd);
        Res.NodeArray[LeftInd]  :=  CurrNode;
        Dec(NumNotProcessedNodes);
      end else begin
        CurrNode  :=  Res.NodeArray[RightCheckInd];
        Dec(RightCheckInd);
      end;
    end; // .while

    for i:=0 to Self.NodeCount - 1 do begin
      Res.NodeArray[i].ChildNodes[LEFT_CHILD]   :=  nil;
      Res.NodeArray[i].ChildNodes[RIGHT_CHILD]  :=  nil;
    end;

    Self.fRoot      :=  nil;
    Self.fNodeCount :=  0;
    Self.fItemCount :=  0;
    Alg.CustomQuickSort(pointer(Res.NodeArray), 0, Res.NodeCount - 1, AssocArrayCompareNodes);
  end; // .if
end; // .procedure TStrBinTree.ConvertToLinearNodeArray

procedure TStrBinTree.Rebuild;
var
  LinearNodeArray:  TStrBinTreeLinearNodeArray;
  NodeArray:        TStrBinTreeNodeArray;

  procedure InsertNode (InsNode: PStrBinTreeNode);
  var
  {U} ParentNode: PStrBinTreeNode;
  {U} CurrNode:   PStrBinTreeNode;

  begin
    {!} Assert(InsNode <> nil);
    ParentNode  :=  nil;
    CurrNode    :=  Self.fRoot;
    // * * * * * //
    while CurrNode <> nil do begin
      ParentNode  :=  CurrNode;
      CurrNode    :=  CurrNode.ChildNodes[InsNode.Hash >= CurrNode.Hash];
    end;

    ParentNode.ChildNodes[InsNode.Hash >= ParentNode.Hash]  :=  InsNode;
  end; // .procedure InsertNode

  procedure InsertNodeRange (MinInd, MaxInd: integer);
  var
  {U} InsNode:    PStrBinTreeNode;
      RangeLen:   integer;
      MiddleInd:  integer;

  begin
    RangeLen  :=  MaxInd - MinInd + 1;
    {!} Assert(RangeLen > 0);
    {!} Assert((MinInd >= 0) and (MaxInd < Length(NodeArray)));
    // * * * * * //
    MiddleInd :=  MinInd + (MaxInd - MinInd) shr 1;
    InsNode   :=  NodeArray[MiddleInd];

    if Self.fRoot = nil then begin
      Self.fRoot  :=  InsNode;
    end else begin
      InsertNode(InsNode);
    end;

    if RangeLen > 2 then begin
      InsertNodeRange(MinInd, MiddleInd - 1);
      InsertNodeRange(MiddleInd + 1, MaxInd);
    end else if RangeLen = 2 then begin
      InsertNode(NodeArray[MiddleInd + 1]);
    end;
  end; // .procedure InsertNodeRange

begin
  {!} Assert(not Self.Locked);
  if Self.NodeCount > 2 then begin
    Self.ConvertToLinearNodeArray(LinearNodeArray);
    Self.fNodeCount :=  LinearNodeArray.NodeCount;
    Self.fItemCount :=  LinearNodeArray.ItemCount;
    NodeArray       :=  LinearNodeArray.NodeArray;
    InsertNodeRange(0, Self.NodeCount - 1);
  end;
end; // .procedure TStrBinTree.Rebuild

function TStrBinTree.FindItem
(
           Hash:       integer;
     const Key:        myAStr;
  out {ni} ParentNode: PStrBinTreeNode;
  out {ni} ItemNode:   PStrBinTreeNode;
  out {ni} ParentItem: PStrBinTreeItem;
  out {ni} Item:       PStrBinTreeItem
): boolean;

var
  SearchDepth:     integer;
  CritSearchDepth: integer;

begin
  if DEBUG_BUILD then begin
    {!} Assert(ParentNode = nil);
    {!} Assert(ItemNode = nil);
    {!} Assert(ParentItem = nil);
    {!} Assert(Item = nil);
  end;

  result := false;

  if Self.NodeCount > 0 then begin
    CritSearchDepth := Self.CalcCritDepth;
    SearchDepth     := 1;
    ItemNode        := Self.fRoot;

    while (ItemNode <> nil) and (ItemNode.Hash <> Hash) do begin
      Inc(SearchDepth);
      ParentNode := ItemNode;
      ItemNode   := ItemNode.ChildNodes[Hash >= ItemNode.Hash];
    end;

    if SearchDepth > CritSearchDepth then begin
      Self.Rebuild;
      ParentNode := nil;
      ItemNode   := nil;
      ParentItem := nil;
      Item       := nil;
      result     := Self.FindItem(Hash, Key, ParentNode, ItemNode, ParentItem, Item);
    end else if ItemNode <> nil then begin
      Item := ItemNode.Item;

      while (Item <> nil) and (Self.GetPreprocessedKey(Item.Key) <> Key) do begin
        ParentItem := Item;
        Item       := Item.NextItem;
      end;

      result := Item <> nil;
    end; // .elseif
  end; // .if
end; // .function TStrBinTree.FindItem

function TStrBinTree.GetValue (const Key: myAStr): {n} pointer;
var
{U} ItemNode:        PStrBinTreeNode;
{U} ParentNode:      PStrBinTreeNode;
{U} Item:            PStrBinTreeItem;
{U} ParentItem:      PStrBinTreeItem;
    PreprocessedKey: myAStr;

begin
  ItemNode   := nil;
  ParentNode := nil;
  Item       := nil;
  ParentItem := nil;
  // * * * * * //

  PreprocessedKey := Self.GetPreprocessedKey(Key);
  result          := nil;

  if Self.FindItem(Self.HashFunc(PreprocessedKey), PreprocessedKey, ParentNode, ItemNode, ParentItem, Item) then begin
    result := Item.Value;
  end;
end; // .function TStrBinTree.GetValue

function TStrBinTree.HasKey (const Key: myAStr): boolean;
var
{U} ItemNode:        PStrBinTreeNode;
{U} ParentNode:      PStrBinTreeNode;
{U} Item:            PStrBinTreeItem;
{U} ParentItem:      PStrBinTreeItem;
    PreprocessedKey: myAStr;

begin
  ItemNode   := nil;
  ParentNode := nil;
  Item       := nil;
  ParentItem := nil;
  // * * * * * //

  PreprocessedKey := Self.GetPreprocessedKey(Key);
  result          := Self.FindItem(Self.HashFunc(PreprocessedKey), PreprocessedKey, ParentNode, ItemNode, ParentItem, Item);
end;

function TStrBinTree.GetExistingValue (const Key: myAStr; out {Un} Res: pointer): boolean;
var
{U} ItemNode:        PStrBinTreeNode;
{U} ParentNode:      PStrBinTreeNode;
{U} Item:            PStrBinTreeItem;
{U} ParentItem:      PStrBinTreeItem;
    PreprocessedKey: myAStr;

begin
  {!} Assert(Res = nil);
  ItemNode   := nil;
  ParentNode := nil;
  Item       := nil;
  ParentItem := nil;
  // * * * * * //

  PreprocessedKey := Self.GetPreprocessedKey(Key);
  result          := Self.FindItem(Self.HashFunc(PreprocessedKey), PreprocessedKey, ParentNode, ItemNode, ParentItem, Item);

  if result then begin
    Res := Item.Value;
  end;
end; // .function TStrBinTree.GetExistingValue

procedure TStrBinTree.SetValue (const Key: myAStr; {OUn} NewValue: pointer);
var
{U} ItemNode:         PStrBinTreeNode;
{U} ParentNode:       PStrBinTreeNode;
{U} Item:             PStrBinTreeItem;
{U} ParentItem:       PStrBinTreeItem;
{O} NewItem:          PStrBinTreeItem;
{O} NewNode:          PStrBinTreeNode;
    PreprocessedKey:  myAStr;
    Hash:             integer;

begin
  ItemNode   := nil;
  ParentNode := nil;
  Item       := nil;
  ParentItem := nil;
  NewItem    := nil;
  NewNode    := nil;
  // * * * * * //
  {!} Assert(Self.IsValidValue(NewValue));
  PreprocessedKey := Self.GetPreprocessedKey(Key);
  Hash            := Self.HashFunc(PreprocessedKey);

  if Self.FindItem(Hash, PreprocessedKey, ParentNode, ItemNode, ParentItem, Item) then begin
    if Item.Value <> NewValue then begin
      Self.FreeItemValue(Item);
      Item.Value := NewValue;
    end;
  end else begin
    {!} Assert(not Self.Locked);
    New(NewItem);
    NewItem.Key      := Key;
    NewItem.Value    := NewValue;
    NewItem.NextItem := nil;
    Inc(Self.fItemCount);

    if ItemNode <> nil then begin
      ParentItem.NextItem := NewItem; NewItem := nil;
    end else begin
      New(NewNode);
      NewNode.Hash                    := Hash;
      NewNode.ChildNodes[LEFT_CHILD]  := nil;
      NewNode.ChildNodes[RIGHT_CHILD] := nil;
      NewNode.Item                    := NewItem; NewItem := nil;
      Inc(Self.fNodeCount);

      if Self.NodeCount > 1 then begin
        ParentNode.ChildNodes[NewNode.Hash >= ParentNode.Hash] := NewNode; NewNode := nil;
      end else begin
        Self.fRoot := NewNode; NewNode := nil;
      end;
    end; // .else
  end; // .else
end; // .procedure TStrBinTree.SetValue

function TStrBinTree.DeleteItem (const Key: myAStr): boolean;
var
{U} ParentNode:      PStrBinTreeNode;
{U} ItemNode:        PStrBinTreeNode;
{U} ParentItem:      PStrBinTreeItem;
{U} Item:            PStrBinTreeItem;
    PreprocessedKey: myAStr;

begin
  {!} Assert(not Self.Locked);
  ItemNode   := nil;
  ParentNode := nil;
  Item       := nil;
  ParentItem := nil;
  // * * * * * //
  PreprocessedKey := Self.GetPreprocessedKey(Key);
  result          := Self.FindItem(Self.HashFunc(PreprocessedKey), PreprocessedKey, ParentNode, ItemNode, ParentItem, Item);

  if result then begin
    Self.RemoveItem(ParentNode, ItemNode, ParentItem, Item);
  end;
end; // .function TStrBinTree.DeleteItem

function TStrBinTree.TakeValue (Key: myAStr; out {OUn} Value: pointer): boolean;
var
{U} ParentNode: PStrBinTreeNode;
{U} ItemNode:   PStrBinTreeNode;
{U} ParentItem: PStrBinTreeItem;
{U} Item:       PStrBinTreeItem;
    Hash:       integer;


begin
  {!} Assert(Value = nil);
  ItemNode   := nil;
  ParentNode := nil;
  Item       := nil;
  ParentItem := nil;
  // * * * * * //
  Key    := Self.GetPreprocessedKey(Key);
  Hash   := Self.HashFunc(Key);
  result := Self.FindItem(Hash, Key, ParentNode, ItemNode, ParentItem, Item);

  if result then begin
    Value := Item.Value;
    {!} Assert(Self.IsValidValue(nil));
    Item.Value := nil;
  end;
end; // .function TStrBinTree.TakeValue

function TStrBinTree.ReplaceValue
(
            Key:      myAStr;
      {OUn} NewValue: pointer;
  out {OUn} OldValue: pointer
): boolean;

var
{U} ParentNode: PStrBinTreeNode;
{U} ItemNode:   PStrBinTreeNode;
{U} ParentItem: PStrBinTreeItem;
{U} Item:       PStrBinTreeItem;
    Hash:       integer;

begin
  {!} Assert(OldValue = nil);
  {!} Assert(Self.IsValidValue(NewValue));
  ItemNode   := nil;
  ParentNode := nil;
  Item       := nil;
  ParentItem := nil;
  // * * * * * //
  Key    := Self.GetPreprocessedKey(Key);
  Hash   := Self.HashFunc(Key);
  result := Self.FindItem(Hash, Key, ParentNode, ItemNode, ParentItem, Item);

  if result then begin
    OldValue   := Item.Value;
    Item.Value := NewValue;
  end;
end; // .function TStrBinTree.ReplaceValue

procedure TStrBinTree.Merge (Source: TStrBinTree);
var
{OUn} Value: pointer;
      Key:   myAStr;

begin
  {!} Assert(Source <> nil);
  {!} Assert(not Self.fOwnsItems or (Self.fItemsAreObjects and Source.fItemsAreObjects), 'Incompatible arrays for merging due to items type and ownage');
  Source.BeginIterate;

  while Source.IterateNext(Key, Value) do begin
    {!} Assert(Self.IsValidValue(Value));

    if Self.fOwnsItems then begin
      {!} Assert(TObject(Value) is UtilsB2.TCloneable, 'Cannot merge array with non-clonable items. Got item: ' + TObject(Value).ClassName);
      Self.SetValue(Key, UtilsB2.TCloneable(Value).Clone);
    end else begin
      Self.SetValue(Key, Value);
    end;
  end;

  Source.EndIterate;
end;

procedure TStrBinTree.EndIterate;
begin
  {!} Assert(Self.fLocked);
  Self.fLocked := false;
end;

procedure TStrBinTree.BeginIterate;
var
  OptimalNumIterNodes: integer;

begin
  {!} Assert(not Self.fLocked);
  OptimalNumIterNodes :=  Self.CalcCritDepth + 1;

  if Length(Self.fIterNodes) < OptimalNumIterNodes then begin
    SetLength(Self.fIterNodes, OptimalNumIterNodes);
  end;

  Self.fIterCurrItem  :=  nil;

  if Self.NodeCount > 0 then begin
    Self.fIterNodeInd   :=  0;
    Self.fIterNodes[0]  :=  Self.fRoot;
  end else begin
    Self.fIterNodeInd :=  -1;
  end;

  Self.fLocked  :=  true;
end; // .procedure TStrBinTree.BeginIterate

function TStrBinTree.IterateNext (out Key: myAStr; out {Un} Value: pointer): boolean;
var
{U} IterNode: PStrBinTreeNode;

begin
  {!} Assert(Self.Locked);
  {!} Assert(Value = nil);
  IterNode  :=  nil;
  // * * * * * //
  result  :=  (Self.fIterNodeInd >= 0) or (Self.fIterCurrItem <> nil);

  if result then begin
    if Self.fIterCurrItem = nil then begin
      IterNode            :=  Self.fIterNodes[Self.fIterNodeInd];
      Self.fIterCurrItem  :=  IterNode.Item;
      Dec(Self.fIterNodeInd);

      if IterNode.ChildNodes[LEFT_CHILD] <> nil then begin
        Inc(Self.fIterNodeInd);
        Self.fIterNodes[Self.fIterNodeInd]  :=  IterNode.ChildNodes[LEFT_CHILD];
      end;
      if IterNode.ChildNodes[RIGHT_CHILD] <> nil then begin
        Inc(Self.fIterNodeInd);
        Self.fIterNodes[Self.fIterNodeInd]  :=  IterNode.ChildNodes[RIGHT_CHILD];
      end;
    end; // .if

    Key                 :=  Self.fIterCurrItem.Key;
    Value               :=  Self.fIterCurrItem.Value;
    Self.fIterCurrItem  :=  Self.fIterCurrItem.NextItem;
  end; // .if
end; // .function TStrBinTree.IterateNext

constructor TObjBinTree.Create
(

                OwnsItems:        boolean;
                ItemsAreObjects:  boolean;
                ItemGuardProc:    UtilsB2.TItemGuardProc;
  {IN} var  {n} ItemGuard:        UtilsB2.TItemGuard
);

begin
  {!} Assert(@ItemGuardProc <> nil);
  Self.fOwnsItems       := OwnsItems;
  Self.fItemsAreObjects := ItemsAreObjects;
  Self.fItemGuardProc   := ItemGuardProc;
  Self.fItemGuard       := ItemGuard;
  ItemGuard             := nil;
end; // .constructor TObjBinTree.Create

destructor TObjBinTree.Destroy;
begin
  Self.Clear;
  Legacy.FreeAndNil(Self.fItemGuard);
end;

function TObjBinTree.KeyToHash ({n} Key: pointer): integer;
begin
  result := Crypto.Tm32Encode(integer(Key));
end;

function TObjBinTree.HashToKey (Hash: integer): {n} pointer;
begin
  result := pointer(Crypto.Tm32Decode(Hash));
end;

function TObjBinTree.IsValidValue ({n} Value: pointer): boolean;
begin
  result := Self.ItemGuardProc(Value, Self.ItemsAreObjects, UtilsB2.TItemGuard(Self.fItemGuard));
end;

function TObjBinTree.CalcCritDepth: integer;
begin
  result := Alg.IntLog2(Self.NodeCount + 1) shl 1;
end;

procedure TObjBinTree.FreeNodeValue (Node: PObjBinTreeNode);
begin
  {!} Assert(Node <> nil);
  if Self.OwnsItems then begin
    if Self.ItemsAreObjects then begin
      TObject(Node.Value).Free;
    end else begin
      FreeMem(Node.Value);
    end;
  end;

  Node.Value := nil;
end; // .procedure TObjBinTree.FreeNodeValue

procedure TObjBinTree.FreeNode ({IN} var {n} Node: PObjBinTreeNode);
begin
  if Node <> nil then begin
    Self.FreeNodeValue(Node);
    Self.FreeNode(Node.ChildNodes[LEFT_CHILD]);
    Self.FreeNode(Node.ChildNodes[RIGHT_CHILD]);
    Dispose(Node); Node := nil;
  end;
end;

procedure TObjBinTree.RemoveNode ({n} ParentNode: PObjBinTreeNode; Node: PObjBinTreeNode);
var
{U} RightClosestNodeParent: PObjBinTreeNode;
{U} RightClosestNode:       PObjBinTreeNode;
    NodeIsRoot:             boolean;
    NodeSide:               TChildNodeSide;

begin
  {!} Assert(Node <> nil);
  RightClosestNodeParent := nil;
  RightClosestNode       := nil;
  NodeSide               := false;
  // * * * * * //
  Self.FreeNodeValue(Node);
  NodeIsRoot := ParentNode = nil;

  if Self.NodeCount = 1 then begin
    {!} Assert(NodeIsRoot);
    {!} Assert(Node = Self.fRoot);
    Dispose(Self.fRoot); Self.fRoot := nil;
  end else begin
    if not NodeIsRoot then begin
      NodeSide := Node.Hash >= ParentNode.Hash;
    end;
    (* N
      - -
    *)
    if (Node.ChildNodes[LEFT_CHILD] = nil) and (Node.ChildNodes[RIGHT_CHILD] = nil) then begin
      ParentNode.ChildNodes[NodeSide] := nil;
      Dispose(Node); Node := nil;
    end // .if
    (* N
      - R
    *)
    else if Node.ChildNodes[LEFT_CHILD] = nil then begin
      if NodeIsRoot then begin
        Self.fRoot := Node.ChildNodes[RIGHT_CHILD];
      end else begin
        ParentNode.ChildNodes[NodeSide] := Node.ChildNodes[RIGHT_CHILD];
      end;

      Dispose(Node); Node := nil;
    end // .elseif
    (* N
      L -
    *)
    else if Node.ChildNodes[RIGHT_CHILD] = nil then begin
      if NodeIsRoot then begin
        Self.fRoot := Node.ChildNodes[LEFT_CHILD];
      end else begin
        ParentNode.ChildNodes[NodeSide] := Node.ChildNodes[LEFT_CHILD];
      end;

      Dispose(Node); Node := nil;
    end // .elseif
    (* N
      L R
    *)
    else begin
      RightClosestNodeParent := Node;
      RightClosestNode       := Node.ChildNodes[RIGHT_CHILD];

      while RightClosestNode.ChildNodes[LEFT_CHILD] <> nil do begin
        RightClosestNodeParent := RightClosestNode;
        RightClosestNode       := RightClosestNode.ChildNodes[LEFT_CHILD];
      end;

      Node.Value := RightClosestNode.Value; RightClosestNode.Value := nil;
      Node.Hash  := RightClosestNode.Hash;
      Self.RemoveNode(RightClosestNodeParent, RightClosestNode);
    end; // .else
  end; // .else
end; // .procedure TObjBinTree.RemoveNode

procedure TObjBinTree.Clear;
begin
  {!} Assert(not Self.Locked);
  Self.FreeNode(Self.fRoot);
  Self.fNodeCount := 0;
end;

function TObjBinTree.CloneNode ({n} Node: PObjBinTreeNode): {On} PObjBinTreeNode;
begin
  if Node = nil then begin
    result := nil;
  end else begin
    New(result);
    result.Hash := Node.Hash;
    {!} Assert(Self.IsValidValue(Node.Value));

    if (Node.Value = nil) or (not Self.OwnsItems) then begin
      result.Value := Node.Value;
    end else begin
      {!} Assert(Self.ItemsAreObjects);
      {!} Assert(TObject(Node.Value) is UtilsB2.TCloneable);
      result.Value := UtilsB2.TCloneable(Node.Value).Clone;
    end;

    result.ChildNodes[LEFT_CHILD]  := Self.CloneNode(Node.ChildNodes[LEFT_CHILD]);
    result.ChildNodes[RIGHT_CHILD] := Self.CloneNode(Node.ChildNodes[RIGHT_CHILD]);
  end; // .else
end; // .function TObjBinTree.CloneNode

procedure TObjBinTree.Assign (Source: UtilsB2.TCloneable);
var
{U} SrcArr: TObjBinTree;

begin
  {!} Assert(not Self.Locked);
  {!} Assert(Source <> nil);
  SrcArr  :=  Source as TObjBinTree;
  // * * * * * //
  if Self <> Source then begin
    Self.Clear;
    Self.fOwnsItems       :=  SrcArr.OwnsItems;
    Self.fItemsAreObjects :=  SrcArr.ItemsAreObjects;
    Self.fItemGuardProc   :=  SrcArr.ItemGuardProc;
    Self.fItemGuard       :=  SrcArr.fItemGuard.Clone;
    Self.fNodeCount       :=  SrcArr.NodeCount;
    Self.fRoot            :=  Self.CloneNode(SrcArr.fRoot);
  end;
end; // .procedure TObjBinTree.Assign

function ObjArrayCompareNodes (A, B: integer): integer;
begin
  if PObjBinTreeNode(A).Hash > PObjBinTreeNode(B).Hash then begin
    result  :=  +1;
  end else if PObjBinTreeNode(A).Hash < PObjBinTreeNode(B).Hash then begin
    result  :=  -1;
  end else begin
    result  :=  0;
  end;
end;

procedure TObjBinTree.ConvertToLinearNodeArray (out Res: TObjBinTreeLinearNodeArray);
var
    LeftInd:              integer;
    RightInd:             integer;
    RightCheckInd:        integer;
    NumNotProcessedNodes: integer;
{U} CurrNode:             PObjBinTreeNode;
    i:                    integer;

begin
  SetLength(Res.NodeArray, Self.NodeCount);
  Res.NodeCount :=  Self.NodeCount;

  if Self.NodeCount > 0 then begin
    CurrNode                :=  Self.fRoot;
    LeftInd                 :=  0;
    Res.NodeArray[LeftInd]  :=  CurrNode;
    RightInd                :=  Self.NodeCount;
    RightCheckInd           :=  RightInd - 1;
    NumNotProcessedNodes    :=  Self.NodeCount - 1;

    while NumNotProcessedNodes > 0 do begin
      if CurrNode.ChildNodes[RIGHT_CHILD] <> nil then begin
        Dec(RightInd);
        Res.NodeArray[RightInd] :=  CurrNode.ChildNodes[RIGHT_CHILD];
        Dec(NumNotProcessedNodes);
      end;

      if CurrNode.ChildNodes[LEFT_CHILD] <> nil then begin
        CurrNode  :=  CurrNode.ChildNodes[LEFT_CHILD];
        Inc(LeftInd);
        Res.NodeArray[LeftInd]  :=  CurrNode;
        Dec(NumNotProcessedNodes);
      end else begin
        CurrNode  :=  Res.NodeArray[RightCheckInd];
        Dec(RightCheckInd);
      end;
    end; // .while

    for i:=0 to Self.NodeCount - 1 do begin
      Res.NodeArray[i].ChildNodes[LEFT_CHILD]   :=  nil;
      Res.NodeArray[i].ChildNodes[RIGHT_CHILD]  :=  nil;
    end;

    Self.fRoot      :=  nil;
    Self.fNodeCount :=  0;
    Alg.CustomQuickSort(pointer(Res.NodeArray), 0, Res.NodeCount - 1, ObjArrayCompareNodes);
  end; // .if
end; // .procedure TObjBinTree.ConvertToLinearNodeArray

procedure TObjBinTree.Rebuild;
var
  LinearNodeArray:  TObjBinTreeLinearNodeArray;
  NodeArray:        TObjBinTreeNodeArray;

  procedure InsertNode (InsNode: PObjBinTreeNode);
  var
  {U} ParentNode: PObjBinTreeNode;
  {U} CurrNode:   PObjBinTreeNode;

  begin
    {!} Assert(InsNode <> nil);
    ParentNode := nil;
    CurrNode   := Self.fRoot;
    // * * * * * //
    while CurrNode <> nil do begin
      ParentNode := CurrNode;
      CurrNode   := CurrNode.ChildNodes[InsNode.Hash >= CurrNode.Hash];
    end;

    ParentNode.ChildNodes[InsNode.Hash >= ParentNode.Hash] := InsNode;
  end; // .procedure InsertNode

  procedure InsertNodeRange (MinInd, MaxInd: integer);
  var
      RangeLen:  integer;
      MiddleInd: integer;
  {U} InsNode:   PObjBinTreeNode;

  begin
    RangeLen  := MaxInd - MinInd + 1;
    {!} Assert(RangeLen > 0);
    {!} Assert((MinInd >= 0) and (MaxInd < Length(NodeArray)));
    // * * * * * //
    MiddleInd := MinInd + (MaxInd - MinInd) shr 1;
    InsNode   := NodeArray[MiddleInd];

    if Self.fRoot = nil then begin
      Self.fRoot := InsNode;
    end else begin
      InsertNode(InsNode);
    end;

    if RangeLen > 2 then begin
      InsertNodeRange(MinInd, MiddleInd - 1);
      InsertNodeRange(MiddleInd + 1, MaxInd);
    end else if RangeLen = 2 then begin
      InsertNode(NodeArray[MiddleInd + 1]);
    end;
  end; // .procedure InsertNodeRange

begin
  {!} Assert(not Self.Locked);
  if Self.NodeCount > 2 then begin
    Self.ConvertToLinearNodeArray(LinearNodeArray);
    Self.fNodeCount :=  LinearNodeArray.NodeCount;
    NodeArray       :=  LinearNodeArray.NodeArray;
    InsertNodeRange(0, Self.NodeCount - 1);
  end;
end; // .procedure TObjBinTree.Rebuild

function TObjBinTree.FindItem
(
      {n}   Key:        pointer;
  out {ni}  ParentNode: PObjBinTreeNode;
  out {ni}  ItemNode:   PObjBinTreeNode
): boolean;

var
  Hash:            integer;
  SearchDepth:     integer;
  CritSearchDepth: integer;

begin
  {!} Assert(ParentNode = nil);
  {!} Assert(ItemNode = nil);
  result := false;

  if Self.NodeCount > 0 then begin
    Hash            := Self.KeyToHash(Key);
    CritSearchDepth := Self.CalcCritDepth;
    SearchDepth     := 1;
    ItemNode        := Self.fRoot;

    while (ItemNode <> nil) and (ItemNode.Hash <> Hash) do begin
      Inc(SearchDepth);
      ParentNode := ItemNode;
      ItemNode   := ItemNode.ChildNodes[Hash >= ItemNode.Hash];
    end;

    if SearchDepth > CritSearchDepth then begin
      Self.Rebuild;
      ParentNode := nil;
      ItemNode   := nil;
      result     := Self.FindItem(Key, ParentNode, ItemNode);
    end;

    result := ItemNode <> nil;
  end; // .if
end; // .function TObjBinTree.FindItem

function TObjBinTree.GetValue ({n} Key: pointer): {n} pointer;
var
{U} ItemNode:   PObjBinTreeNode;
{U} ParentNode: PObjBinTreeNode;

begin
  ItemNode    :=  nil;
  ParentNode  :=  nil;
  // * * * * * //
  if Self.FindItem(Key, ParentNode, ItemNode) then begin
    result  :=  ItemNode.Value;
  end else begin
    result  :=  nil;
  end;
end; // .function TObjBinTree.GetValue

function TObjBinTree.GetExistingValue ({n} Key: pointer; out {Un} Res: pointer): boolean;
var
{U} ItemNode:   PObjBinTreeNode;
{U} ParentNode: PObjBinTreeNode;

begin
  {!} Assert(Res = nil);
  ItemNode    :=  nil;
  ParentNode  :=  nil;
  // * * * * * //
  result  :=  Self.FindItem(Key, ParentNode, ItemNode);

  if result then begin
    Res :=  ItemNode.Value;
  end;
end; // .function TObjBinTree.GetExistingValue

procedure TObjBinTree.SetValue ({n} Key: pointer; {OUn} NewValue: pointer);
var
{U} ItemNode:   PObjBinTreeNode;
{U} ParentNode: PObjBinTreeNode;
{O} NewNode:    PObjBinTreeNode;

begin
  ItemNode   := nil;
  ParentNode := nil;
  NewNode    := nil;
  // * * * * * //
  {!} Assert(Self.IsValidValue(NewValue));
  if Self.FindItem(Key, ParentNode, ItemNode) then begin
    if ItemNode.Value <> NewValue then begin
      Self.FreeNodeValue(ItemNode);
      ItemNode.Value := NewValue;
    end;
  end else begin
    New(NewNode);
    NewNode.Hash  := Self.KeyToHash(Key);
    NewNode.Value := NewValue;
    NewNode.ChildNodes[LEFT_CHILD]  := nil;
    NewNode.ChildNodes[RIGHT_CHILD] := nil;
    Inc(Self.fNodeCount);

    if Self.NodeCount > 1 then begin
      ParentNode.ChildNodes[NewNode.Hash >= ParentNode.Hash] := NewNode; NewNode := nil;
    end else begin
      Self.fRoot  := NewNode; NewNode  := nil;
    end;
  end; // .else
end; // .procedure TObjBinTree.SetValue

function TObjBinTree.DeleteItem ({n} Key: pointer): boolean;
var
{U} ParentNode: PObjBinTreeNode;
{U} ItemNode:   PObjBinTreeNode;

begin
  {!} Assert(not Self.Locked);
  ItemNode   := nil;
  ParentNode := nil;
  // * * * * * //
  result := Self.FindItem(Key, ParentNode, ItemNode);

  if result then begin
    Self.RemoveNode(ParentNode, ItemNode);
    Dec(Self.fNodeCount);
  end;
end; // .function TObjBinTree.DeleteItem

function TObjBinTree.TakeValue ({n} Key: pointer; out {OUn} Value: pointer): boolean;
var
{U} ParentNode: PObjBinTreeNode;
{U} ItemNode:   PObjBinTreeNode;

begin
  {!} Assert(Value = nil);
  ItemNode   := nil;
  ParentNode := nil;
  // * * * * * //
  result := Self.FindItem(Key, ParentNode, ItemNode);

  if result then begin
    Value := ItemNode.Value;
    {!} Assert(Self.IsValidValue(nil));
    ItemNode.Value := nil;
  end;
end; // .function TObjBinTree.TakeValue

function TObjBinTree.ReplaceValue ({n} Key: pointer; {OUn} NewValue: pointer; out {OUn} OldValue: pointer): boolean;
var
{U} ParentNode: PObjBinTreeNode;
{U} ItemNode:   PObjBinTreeNode;

begin
  {!} Assert(OldValue = nil);
  {!} Assert(Self.IsValidValue(NewValue));
  ItemNode   := nil;
  ParentNode := nil;
  // * * * * * //
  result := Self.FindItem(Key, ParentNode, ItemNode);

  if result then begin
    OldValue       := ItemNode.Value;
    ItemNode.Value := NewValue;
  end;
end; // .function TObjBinTree.ReplaceValue

procedure TObjBinTree.EndIterate;
begin
  {!} Assert(Self.fLocked);
  Self.fLocked := false;
end;

procedure TObjBinTree.BeginIterate;
var
  OptimalNumIterNodes: integer;

begin
  {!} Assert(not Self.fLocked);
  OptimalNumIterNodes := Self.CalcCritDepth + 1;

  if Length(Self.fIterNodes) < OptimalNumIterNodes then begin
    SetLength(Self.fIterNodes, OptimalNumIterNodes);
  end;

  if Self.NodeCount > 0 then begin
    Self.fIterNodeInd  := 0;
    Self.fIterNodes[0] := Self.fRoot;
  end else begin
    Self.fIterNodeInd := -1;
  end;

  Self.fLocked := true;
end; // .procedure TObjBinTree.BeginIterate

function TObjBinTree.IterateNext (out {Un} Key: pointer; out {Un} Value: pointer): boolean;
var
{U} IterNode: PObjBinTreeNode;

begin
  {!} Assert(Self.Locked);
  {!} Assert(Key = nil);
  {!} Assert(Value = nil);
  IterNode := nil;
  // * * * * * //
  result := Self.fIterNodeInd >= 0;

  if result then begin
    IterNode := Self.fIterNodes[Self.fIterNodeInd];
    Dec(Self.fIterNodeInd);

    if IterNode.ChildNodes[LEFT_CHILD] <> nil then begin
      Inc(Self.fIterNodeInd);
      Self.fIterNodes[Self.fIterNodeInd] := IterNode.ChildNodes[LEFT_CHILD];
    end;

    if IterNode.ChildNodes[RIGHT_CHILD] <> nil then begin
      Inc(Self.fIterNodeInd);
      Self.fIterNodes[Self.fIterNodeInd] := IterNode.ChildNodes[RIGHT_CHILD];
    end;

    Key   := Self.HashToKey(IterNode.Hash);
    Value := IterNode.Value;
  end; // .if
end; // .function TObjBinTree.IterateNext

procedure TStrHashTableItem.MakeEmpty;
begin
  if Self.SearchDistance <> EMPTY_ITEM_SEARCH_DISTANCE then begin
    Self.Key             := '';
    Self.PreprocessedKey := '';
    Self.SearchDistance  := EMPTY_ITEM_SEARCH_DISTANCE;
  end;
end;

procedure TStrHashTableItem.Exchange (var OtherItem: TStrHashTableItem);
var
  TempBuf: TStrHashTableItemUnmanaged;

begin
  System.Move(Self,      TempBuf,   sizeof(Self));
  System.Move(OtherItem, Self,      sizeof(Self));
  System.Move(TempBuf,   OtherItem, sizeof(Self));
end;

constructor TStrHashTable.Create (HashFunc: THashFunc; {n} KeyPreprocessFunc: TKeyPreprocessFunc; OwnsItems, ItemsAreObjects: boolean; ItemGuardProc: UtilsB2.TItemGuardProc;
                               {On} ItemGuard: UtilsB2.TItemGuard);
begin
  {!} Assert(@HashFunc      <> nil);
  {!} Assert(@ItemGuardProc <> nil);
  Self.fHashFunc          := HashFunc;
  Self.fKeyPreprocessFunc := KeyPreprocessFunc;
  Self.fOwnsItems         := OwnsItems;
  Self.fItemsAreObjects   := ItemsAreObjects;
  Self.fItemGuardProc     := ItemGuardProc;
  Self.fItemGuard         := ItemGuard;
  Self.CreateNewStorage(Self.MIN_CAPACITY);
end;

destructor TStrHashTable.Destroy;
begin
  Self.FreeValues;
  Legacy.FreeAndNil(Self.fItemGuard);
end;

procedure TStrHashTable.FreeItemValue (Item: PStrHashTableItem);
begin
  if Self.fOwnsItems then begin
    if Self.fItemsAreObjects then begin
      TObject(Item.Value).Free;
    end else begin
      FreeMem(Item.Value);
    end;
  end;
end;

procedure TStrHashTable.FreeValues;
var
  Item:     PStrHashTableItem;
  ItemsEnd: PStrHashTableItem;

begin
  if Self.fOwnsItems then begin
    Item     := @Self.fItems[0];
    ItemsEnd := @Self.fItems[Self.fCapacity];

    while cardinal(Item) < cardinal(ItemsEnd) do begin
      if Item.SearchDistance <> EMPTY_ITEM_SEARCH_DISTANCE then begin
        Self.FreeItemValue(Item);
      end;

      Inc(Item);
    end;
  end;
end;

procedure TStrHashTable.OnChangeCapacity;
begin
  Self.fMinSize         := trunc(Self.fCapacity * Self.MIN_LOAD_FACTOR);
  Self.fMaxSize         := trunc(Self.fCapacity * Self.MAX_LOAD_FACTOR) - 1;
  Self.fModCapacityMask := (1 shl Alg.IntLog2(Self.fCapacity)) - 1;
end;

procedure TStrHashTable.CreateNewStorage (NewCapacity: integer);
begin
  // Disallow null-capacity hash tables and non power of 2 capacities
  {!} Assert((NewCapacity > 0) and ((1 shl Alg.IntLog2(NewCapacity)) = NewCapacity));

  Self.fCapacity := NewCapacity;
  Self.fItems    := nil;
  SetLength(Self.fItems, Self.fCapacity);
  Self.OnChangeCapacity;
end;

procedure TStrHashTable.Clear;
begin
  Self.FreeValues;
  Self.fSize := 0;
  Self.CreateNewStorage(Self.MIN_CAPACITY);
end;

function TStrHashTable.IsValidValue ({n} Value: pointer): boolean;
begin
  result := Self.fItemGuardProc(Value, Self.fItemsAreObjects, UtilsB2.TItemGuard(Self.fItemGuard));
end;

function TStrHashTable.GetPreprocessedKey (const Key: myAStr): myAStr;
begin
  if @Self.fKeyPreprocessFunc = nil then begin
    result := Key;
  end else begin
    result := Self.fKeyPreprocessFunc(Key);
  end;
end;

function TStrHashTable.FindItem (Hash: integer; const PreprocessedKey: myAStr; var ItemInd: integer): {Un} PStrHashTableItem;
var
  Item:            PStrHashTableItem;
  SearchDistance:  integer;
  ModCapacityMask: integer;

begin
  result          := nil;
  ModCapacityMask := Self.fModCapacityMask;
  ItemInd         := Hash and ModCapacityMask;
  Item            := @Self.fItems[ItemInd];
  SearchDistance  := 1;

  while true do begin
    if (Item.SearchDistance = EMPTY_ITEM_SEARCH_DISTANCE) or (SearchDistance > Item.SearchDistance) then begin
      {$IFDEF INSPECT_SEARCH_DISTANCE}
        Inc(Self.TotalSearchDistance, SearchDistance);
        Self.MaxSearchDistance := Max(Self.MaxSearchDistance, SearchDistance);
      {$ENDIF}

      exit;
    end;

    if (Item.Hash = Hash) and (Item.PreprocessedKey = PreprocessedKey) then begin
      {$IFDEF INSPECT_SEARCH_DISTANCE}
        Inc(Self.TotalSearchDistance, SearchDistance);
        Self.MaxSearchDistance := Max(Self.MaxSearchDistance, SearchDistance);
      {$ENDIF}

      result := Item;
      exit;
    end;

    Inc(Item);
    Inc(SearchDistance);

    ItemInd := (ItemInd + 1) and ModCapacityMask;

    if ItemInd = 0 then begin
      Item := @Self.fItems[0];
    end;
  end; // .while
end; // .function TStrHashTable.FindItem

procedure TStrHashTable.SetValue (const Key: myAStr; {OUn} NewValue: pointer);
var
{U} Item:            PStrHashTableItem;
    PreprocessedKey: myAStr;
    Hash:            integer;
    ItemInd:         integer;

begin
  {!} Assert(Self.IsValidValue(NewValue));
  PreprocessedKey := Self.GetPreprocessedKey(Key);
  Hash            := Self.fHashFunc(PreprocessedKey);
  Item            := Self.FindItem(Hash, PreprocessedKey, ItemInd);

  if Item <> nil then begin
    if Item.Value <> NewValue then begin
      Self.FreeItemValue(Item);
      Item.Value := NewValue;
    end;
  end else begin
    Self.AddValue(Hash, Key, PreprocessedKey, NewValue, ItemInd);
  end;
end; // .procedure TStrHashTable.SetValue

procedure TStrHashTable.AddValue (Hash: integer; const Key, PreprocessedKey: myAStr; {OUn} NewValue: pointer; ItemInd: integer);
var
  ModCapacityMask: integer;
  Item:            PStrHashTableItem;
  NewItem:         TStrHashTableItem;

begin
  {!} Assert(not Self.fLocked);
  Item                    := @Self.fItems[ItemInd];
  ModCapacityMask         := Self.fModCapacityMask;
  NewItem.Hash            := Hash;
  NewItem.Key             := Key;
  NewItem.PreprocessedKey := PreprocessedKey;
  NewItem.Value           := NewValue;
  NewItem.SearchDistance  := ItemInd - (Hash and ModCapacityMask) + 1;

  if NewItem.SearchDistance <= 0 then begin
    Inc(NewItem.SearchDistance, Self.fCapacity);
  end;

  while Item.SearchDistance <> EMPTY_ITEM_SEARCH_DISTANCE do begin
    if NewItem.SearchDistance > Item.SearchDistance then begin
      NewItem.Exchange(Item^);
    end;

    Inc(Item);
    Inc(NewItem.SearchDistance);

    ItemInd := (ItemInd + 1) and ModCapacityMask;

    if ItemInd = 0 then begin
      Item := @Self.fItems[0];
    end;
  end;

  // Finally swap with empty item
  NewItem.Exchange(Item^);

  Inc(Self.fSize);

  if Self.fSize >= Self.fMaxSize then begin
    Self.Grow;
  end;
end; // .procedure TStrHashTable.AddValue

function TStrHashTable.GetValue (const Key: myAStr): {n} pointer;
var
{U} Item:            PStrHashTableItem;
    ItemInd:         integer;
    PreprocessedKey: myAStr;

begin
  PreprocessedKey := Self.GetPreprocessedKey(Key);
  Item            := Self.FindItem(Self.fHashFunc(PreprocessedKey), PreprocessedKey, ItemInd);
  result          := nil;

  if Item <> nil then begin
    result := Item.Value;
  end;
end;

function TStrHashTable.HasKey (const Key: myAStr): boolean;
var
{U} Item:            PStrHashTableItem;
    ItemInd:         integer;
    PreprocessedKey: myAStr;

begin
  PreprocessedKey := Self.GetPreprocessedKey(Key);
  Item            := Self.FindItem(Self.fHashFunc(PreprocessedKey), PreprocessedKey, ItemInd);
  result          := Item <> nil;
end;

function TStrHashTable.GetExistingValue (const Key: myAStr; {out} var {Un} Res: pointer): boolean;
var
{U} Item:            PStrHashTableItem;
    ItemInd:         integer;
    PreprocessedKey: myAStr;

begin
  PreprocessedKey := Self.GetPreprocessedKey(Key);
  Item            := Self.FindItem(Self.fHashFunc(PreprocessedKey), PreprocessedKey, ItemInd);
  result          := Item <> nil;

  if result then begin
    Res := Item.Value;
  end;
end;

function TStrHashTable.TakeValue (const Key: myAStr; {out} var {OUn} Value: pointer): boolean;
var
{U} Item:            PStrHashTableItem;
    ItemInd:         integer;
    PreprocessedKey: myAStr;

begin
  {!} Assert(Self.IsValidValue(nil));
  PreprocessedKey := Self.GetPreprocessedKey(Key);
  Item            := Self.FindItem(Self.fHashFunc(PreprocessedKey), PreprocessedKey, ItemInd);
  result          := Item <> nil;

  if Item <> nil then begin
    Value      := Item.Value;
    Item.Value := nil;
  end;
end;

function TStrHashTable.ReplaceValue (const Key: myAStr; {OUn} NewValue: pointer; {out} var {OUn} OldValue: pointer): boolean;
var
{U} Item:            PStrHashTableItem;
    ItemInd:         integer;
    PreprocessedKey: myAStr;

begin
  {!} Assert(Self.IsValidValue(NewValue));
  PreprocessedKey := Self.GetPreprocessedKey(Key);
  Item            := Self.FindItem(Self.fHashFunc(PreprocessedKey), PreprocessedKey, ItemInd);
  result          := Item <> nil;

  if Item <> nil then begin
    OldValue   := Item.Value;
    Item.Value := NewValue;
  end;
end;

function TStrHashTable.DeleteItem (const Key: myAStr): boolean;
var
{Un} PrevItem:        PStrHashTableItem;
{Un} Item:            PStrHashTableItem;
     PreprocessedKey: myAStr;
     ItemInd:         integer;
     StartInd:        integer;
     ModCapacityMask: integer;

begin
  {!} Assert(not Self.fLocked);
  ModCapacityMask := Self.fModCapacityMask;
  PreprocessedKey := Self.GetPreprocessedKey(Key);
  PrevItem        := nil;
  Item            := Self.FindItem(Self.fHashFunc(PreprocessedKey), PreprocessedKey, ItemInd);
  result          := Item <> nil;

  if result then begin
    Self.FreeItemValue(Item);
    Item.MakeEmpty;
    Dec(Self.fSize);
    StartInd := (ItemInd + 1) and ModCapacityMask;

    while true do begin
      PrevItem := Item;
      Inc(Item);

      ItemInd := (ItemInd + 1) and ModCapacityMask;

      if ItemInd = 0 then begin
        Item := @Self.fItems[0];
      end;

      // Chain is ended, because this item is empty or on its own place
      if Item.SearchDistance <= 1 then begin
        break;
      end;

      Dec(Item.SearchDistance);
      System.Move(Item^, PrevItem^, sizeof(Item^));
    end; // .while

    // If displacement took place, the previous item is the moved one, we need to erase it memory
    if ItemInd <> StartInd then begin
      System.FillChar(PrevItem^, sizeof(PrevItem^), #0);
    end;

    if (Self.fSize <= Self.fMinSize) and (Self.fCapacity > Self.MIN_CAPACITY) then begin
      Self.Shrink;
    end;
  end; // .if
end; // .function TStrHashTable.DeleteItem

procedure TStrHashTable.Grow;
begin
  Self.Rehash(Self.fCapacity * Self.GROWTH_FACTOR);
end;

procedure TStrHashTable.Shrink;
begin
  Self.Rehash(Self.fCapacity div Self.GROWTH_FACTOR);
end;

procedure TStrHashTable.Rehash (NewCapacity: integer);
var
  OldItems:        TStrHashTableItems;
  OldItemsEnd:     PStrHashTableItem;
  OldItem:         PStrHashTableItem;
  Item:            PStrHashTableItem;
  ItemInd:         integer;
  NewItem:         TStrHashTableItem;
  ModCapacityMask: integer;

begin
  OldItems        := Self.fItems;
  OldItem         := @OldItems[0];
  OldItemsEnd     := @OldItems[Self.fCapacity];
  Self.CreateNewStorage(NewCapacity);
  ModCapacityMask := Self.fModCapacityMask;

  NewItem.MakeEmpty;

  while cardinal(OldItem) < cardinal(OldItemsEnd) do begin
    if OldItem.SearchDistance <> EMPTY_ITEM_SEARCH_DISTANCE then begin
      NewItem.Exchange(OldItem^);
      NewItem.SearchDistance := 1;

      ItemInd := NewItem.Hash and ModCapacityMask;
      Item    := @Self.fItems[ItemInd];

      while Item.SearchDistance <> EMPTY_ITEM_SEARCH_DISTANCE do begin
        if NewItem.SearchDistance > Item.SearchDistance then begin
          NewItem.Exchange(Item^);
        end;

        Inc(Item);
        Inc(NewItem.SearchDistance);

        ItemInd := (ItemInd + 1) and ModCapacityMask;

        if ItemInd = 0 then begin
          Item := @Self.fItems[0];
        end;
      end;

      // Finally swap with empty item
      NewItem.Exchange(Item^);
    end; // .if

    Inc(OldItem);
  end; // .for

  // All old items strings must be '' and OldItems.RefCount = 1
  // Fast items deallocation without calling finalizer for each item to free string memory
  TStrHashTableItemsUnmanaged(OldItems) := nil;
end; // .procedure TStrHashTable.Rehash

procedure TStrHashTable.BeginIterate;
begin
  Self.fIterPos := 0;
  Self.fLocked  := true;
end;

function TStrHashTable.IterateNext (out Key: myAStr; out {Un} Value: pointer): boolean;
var
{Un} Item: PStrHashTableItem;

begin
  {!} Assert(Self.fLocked);
  Item := @Self.fItems[Self.fIterPos];

  while (Self.fIterPos < Self.fCapacity) and (Item.SearchDistance = EMPTY_ITEM_SEARCH_DISTANCE) do begin
    Inc(Item);
    Inc(Self.fIterPos);
  end;

  result := Self.fIterPos < Self.fCapacity;

  if result then begin
    Value := Item.Value;
    Key   := Item.Key;
    Inc(Self.fIterPos);
  end;
end;

procedure TStrHashTable.EndIterate;
begin
  Self.fLocked := false;
end;

procedure TStrHashTable.Assign (Source: UtilsB2.TCloneable);
var
{U} SrcTable: TStrHashTable;
    Item:     PStrHashTableItem;
    ItemsEnd: PStrHashTableItem;

begin
  {!} Assert(Source <> nil);
  {!} Assert(not Self.fLocked);
  SrcTable := Source as TStrHashTable;
  // * * * * * //
  if Self <> Source then begin
    {!} Assert(not SrcTable.fOwnsItems or SrcTable.fItemsAreObjects, 'Impossible to clone hash table if it contains owned non-object pointers');
    Self.FreeValues;
    Self.fHashFunc          := SrcTable.fHashFunc;
    Self.fKeyPreprocessFunc := SrcTable.fKeyPreprocessFunc;
    Self.fOwnsItems         := SrcTable.fOwnsItems;
    Self.fItemsAreObjects   := SrcTable.fItemsAreObjects;
    Self.fItemGuardProc     := SrcTable.fItemGuardProc;
    Self.fItemGuard         := SrcTable.fItemGuard.Clone;
    Self.fSize              := SrcTable.fSize;
    Self.fCapacity          := SrcTable.fCapacity;
    Self.OnChangeCapacity;
    Self.fItems             := Copy(SrcTable.fItems);

    if Self.fOwnsItems and Self.fItemsAreObjects then begin
      Item     := @Self.fItems[0];
      ItemsEnd := @Self.fItems[Self.fCapacity];

      while cardinal(Item) < cardinal(ItemsEnd) do begin
        if Item.Value <> nil then begin
          Item.Value := (TObject(Item.Value) as UtilsB2.TCloneable).Clone;
        end;

        Inc(Item);
      end;
    end; // .if
  end; // .if
end; // .procedure TStrHashTable.Assign

procedure MergeAssocArrays (Destination, Source: TAssocArray);
var
{OUn} Value: pointer;
      Key:   myAStr;

begin
  {!} Assert(Source <> nil);
  {!} Assert(not Destination.OwnsItems or (Destination.ItemsAreObjects and Source.ItemsAreObjects), 'Incompatible hash tables for merging due to items type and ownage');
  Source.BeginIterate;

  while Source.IterateNext(Key, Value) do begin
    {!} Assert(Destination.IsValidValue(Value));

    if Destination.OwnsItems then begin
      {!} Assert(TObject(Value) is UtilsB2.TCloneable, 'Cannot merge array with non-clonable items. Got item: ' + TObject(Value).ClassName);
      Destination.SetValue(Key, UtilsB2.TCloneable(Value).Clone);
    end else begin
      Destination.SetValue(Key, Value);
    end;
  end;

  Source.EndIterate;
end;

function TObjHashTable.KeyToHash ({n} Key: pointer): integer;
begin
  result := Crypto.Tm32Encode(integer(Key));
end;

function TObjHashTable.HashToKey (Hash: integer): {n} pointer;
begin
  result := pointer(Crypto.Tm32Decode(Hash));
end;

procedure TObjHashTableItem.MakeEmpty;
begin
  Self.SearchDistance := EMPTY_ITEM_SEARCH_DISTANCE;
end;

procedure TObjHashTableItem.Exchange (var OtherItem: TObjHashTableItem);
var
  TempBuf: TObjHashTableItem;

begin
  System.Move(Self,      TempBuf,   sizeof(Self));
  System.Move(OtherItem, Self,      sizeof(Self));
  System.Move(TempBuf,   OtherItem, sizeof(Self));
end;

constructor TObjHashTable.Create (OwnsItems, ItemsAreObjects: boolean; ItemGuardProc: UtilsB2.TItemGuardProc; {On} ItemGuard: UtilsB2.TItemGuard);
begin
  {!} Assert(@ItemGuardProc <> nil);
  Self.fOwnsItems       := OwnsItems;
  Self.fItemsAreObjects := ItemsAreObjects;
  Self.fItemGuardProc   := ItemGuardProc;
  Self.fItemGuard       := ItemGuard;
  Self.CreateNewStorage(Self.MIN_CAPACITY);
end;

destructor TObjHashTable.Destroy;
begin
  Self.FreeValues;
  Legacy.FreeAndNil(Self.fItemGuard);
end;

procedure TObjHashTable.FreeItemValue (Item: PObjHashTableItem);
begin
  if Self.fOwnsItems then begin
    if Self.fItemsAreObjects then begin
      TObject(Item.Value).Free;
    end else begin
      FreeMem(Item.Value);
    end;
  end;
end;

procedure TObjHashTable.FreeValues;
var
  Item:     PObjHashTableItem;
  ItemsEnd: PObjHashTableItem;

begin
  if Self.fOwnsItems then begin
    Item     := @Self.fItems[0];
    ItemsEnd := @Self.fItems[Self.fCapacity];

    while cardinal(Item) < cardinal(ItemsEnd) do begin
      if Item.SearchDistance <> EMPTY_ITEM_SEARCH_DISTANCE then begin
        Self.FreeItemValue(Item);
      end;

      Inc(Item);
    end;
  end;
end;

procedure TObjHashTable.OnChangeCapacity;
begin
  Self.fMinSize         := trunc(Self.fCapacity * Self.MIN_LOAD_FACTOR);
  Self.fMaxSize         := trunc(Self.fCapacity * Self.MAX_LOAD_FACTOR) - 1;
  Self.fModCapacityMask := (1 shl Alg.IntLog2(Self.fCapacity)) - 1;
end;

procedure TObjHashTable.CreateNewStorage (NewCapacity: integer);
begin
  // Disallow null-capacity hash tables and non power of 2 capacities
  {!} Assert((NewCapacity > 0) and ((1 shl Alg.IntLog2(NewCapacity)) = NewCapacity));

  Self.fCapacity := NewCapacity;
  Self.fItems    := nil;
  SetLength(Self.fItems, Self.fCapacity);
  Self.OnChangeCapacity;
end;

procedure TObjHashTable.Clear;
begin
  Self.FreeValues;
  Self.fSize := 0;
  Self.CreateNewStorage(Self.MIN_CAPACITY);
end;

function TObjHashTable.IsValidValue ({n} Value: pointer): boolean;
begin
  result := Self.fItemGuardProc(Value, Self.fItemsAreObjects, UtilsB2.TItemGuard(Self.fItemGuard));
end;

function TObjHashTable.FindItem (Hash: integer; var ItemInd: integer): {Un} PObjHashTableItem;
var
  Item:            PObjHashTableItem;
  SearchDistance:  integer;
  ModCapacityMask: integer;

begin
  result          := nil;
  ModCapacityMask := Self.fModCapacityMask;
  ItemInd         := Hash and ModCapacityMask;
  Item            := @Self.fItems[ItemInd];
  SearchDistance  := 1;

  while true do begin
    if (Item.SearchDistance = EMPTY_ITEM_SEARCH_DISTANCE) or (SearchDistance > Item.SearchDistance) then begin
      {$IFDEF INSPECT_SEARCH_DISTANCE}
        Inc(Self.TotalSearchDistance, SearchDistance);
        Self.MaxSearchDistance := Max(Self.MaxSearchDistance, SearchDistance);
      {$ENDIF}

      exit;
    end;

    if Item.Hash = Hash then begin
      {$IFDEF INSPECT_SEARCH_DISTANCE}
        Inc(Self.TotalSearchDistance, SearchDistance);
        Self.MaxSearchDistance := Max(Self.MaxSearchDistance, SearchDistance);
      {$ENDIF}

      result := Item;
      exit;
    end;

    Inc(Item);
    Inc(SearchDistance);

    ItemInd := (ItemInd + 1) and ModCapacityMask;

    if ItemInd = 0 then begin
      Item := @Self.fItems[0];
    end;
  end; // .while
end; // .function TObjHashTable.FindItem

procedure TObjHashTable.SetValue ({n} Key: pointer; {OUn} NewValue: pointer);
var
{U} Item:    PObjHashTableItem;
    Hash:    integer;
    ItemInd: integer;

begin
  {!} Assert(Self.IsValidValue(NewValue));
  Hash := Self.KeyToHash(Key);
  Item := Self.FindItem(Hash, ItemInd);

  if Item <> nil then begin
    if Item.Value <> NewValue then begin
      Self.FreeItemValue(Item);
      Item.Value := NewValue;
    end;
  end else begin
    Self.AddValue(Hash, NewValue, ItemInd);
  end;
end; // .procedure TObjHashTable.SetValue

procedure TObjHashTable.AddValue (Hash: integer; {OUn} NewValue: pointer; ItemInd: integer);
var
  ModCapacityMask: integer;
  Item:            PObjHashTableItem;
  NewItem:         TObjHashTableItem;

begin
  {!} Assert(not Self.fLocked);
  Item                   := @Self.fItems[ItemInd];
  ModCapacityMask        := Self.fModCapacityMask;
  NewItem.Hash           := Hash;
  NewItem.Value          := NewValue;
  NewItem.SearchDistance := ItemInd - (Hash and ModCapacityMask) + 1;

  if NewItem.SearchDistance <= 0 then begin
    Inc(NewItem.SearchDistance, Self.fCapacity);
  end;

  while Item.SearchDistance <> EMPTY_ITEM_SEARCH_DISTANCE do begin
    if NewItem.SearchDistance > Item.SearchDistance then begin
      NewItem.Exchange(Item^);
    end;

    Inc(Item);
    Inc(NewItem.SearchDistance);

    ItemInd := (ItemInd + 1) and ModCapacityMask;

    if ItemInd = 0 then begin
      Item := @Self.fItems[0];
    end;
  end;

  // Finally swap with empty item
  NewItem.Exchange(Item^);

  Inc(Self.fSize);

  if Self.fSize >= Self.fMaxSize then begin
    Self.Grow;
  end;
end; // .procedure TObjHashTable.AddValue

function TObjHashTable.GetValue ({n} Key: pointer): {n} pointer;
var
{U} Item:    PObjHashTableItem;
    ItemInd: integer;

begin
  Item   := Self.FindItem(Self.KeyToHash(Key), ItemInd);
  result := nil;

  if Item <> nil then begin
    result := Item.Value;
  end;
end;

function TObjHashTable.HasKey ({n} Key: pointer): boolean;
var
  ItemInd: integer;

begin
  result := Self.FindItem(Self.KeyToHash(Key), ItemInd) <> nil;
end;

function TObjHashTable.GetExistingValue ({n} Key: pointer; {out} var {Un} Res: pointer): boolean;
var
{U} Item:    PObjHashTableItem;
    ItemInd: integer;

begin
  Item   := Self.FindItem(Self.KeyToHash(Key), ItemInd);
  result := Item <> nil;

  if result then begin
    Res := Item.Value;
  end;
end;

function TObjHashTable.TakeValue ({n} Key: pointer; {out} var {OUn} Value: pointer): boolean;
var
{U} Item:    PObjHashTableItem;
    ItemInd: integer;

begin
  {!} Assert(Self.IsValidValue(nil));
  Item   := Self.FindItem(Self.KeyToHash(Key), ItemInd);
  result := Item <> nil;

  if Item <> nil then begin
    Value      := Item.Value;
    Item.Value := nil;
  end;
end;

function TObjHashTable.ReplaceValue ({n} Key: pointer; {OUn} NewValue: pointer; {out} var {OUn} OldValue: pointer): boolean;
var
{U} Item:    PObjHashTableItem;
    ItemInd: integer;

begin
  {!} Assert(Self.IsValidValue(NewValue));
  Item   := Self.FindItem(Self.KeyToHash(Key), ItemInd);
  result := Item <> nil;

  if Item <> nil then begin
    OldValue   := Item.Value;
    Item.Value := NewValue;
  end;
end;

function TObjHashTable.DeleteItem ({n} Key: pointer): boolean;
var
{Un} PrevItem:        PObjHashTableItem;
{Un} Item:            PObjHashTableItem;
     ItemInd:         integer;
     StartInd:        integer;
     ModCapacityMask: integer;

begin
  {!} Assert(not Self.fLocked);
  ModCapacityMask := Self.fModCapacityMask;
  PrevItem        := nil;
  Item            := Self.FindItem(Self.KeyToHash(Key), ItemInd);
  result          := Item <> nil;

  if result then begin
    Self.FreeItemValue(Item);
    Item.MakeEmpty;
    Dec(Self.fSize);
    StartInd := (ItemInd + 1) and ModCapacityMask;

    while true do begin
      PrevItem := Item;
      Inc(Item);

      ItemInd := (ItemInd + 1) and ModCapacityMask;

      if ItemInd = 0 then begin
        Item := @Self.fItems[0];
      end;

      // Chain is ended, because this item is empty or on its own place
      if Item.SearchDistance <= 1 then begin
        break;
      end;

      Dec(Item.SearchDistance);
      System.Move(Item^, PrevItem^, sizeof(Item^));
    end; // .while

    // If displacement took place, the previous item is the moved one, we need to erase it memory
    if ItemInd <> StartInd then begin
      System.FillChar(PrevItem^, sizeof(PrevItem^), #0);
    end;

    if (Self.fSize <= Self.fMinSize) and (Self.fCapacity > Self.MIN_CAPACITY) then begin
      Self.Shrink;
    end;
  end; // .if
end; // .function TObjHashTable.DeleteItem

procedure TObjHashTable.Grow;
begin
  Self.Rehash(Self.fCapacity * Self.GROWTH_FACTOR);
end;

procedure TObjHashTable.Shrink;
begin
  Self.Rehash(Self.fCapacity div Self.GROWTH_FACTOR);
end;

procedure TObjHashTable.Rehash (NewCapacity: integer);
var
  OldItems:        TObjHashTableItems;
  OldItemsEnd:     PObjHashTableItem;
  OldItem:         PObjHashTableItem;
  Item:            PObjHashTableItem;
  ItemInd:         integer;
  NewItem:         TObjHashTableItem;
  ModCapacityMask: integer;

begin
  OldItems        := Self.fItems;
  OldItem         := @OldItems[0];
  OldItemsEnd     := @OldItems[Self.fCapacity];
  Self.CreateNewStorage(NewCapacity);
  ModCapacityMask := Self.fModCapacityMask;

  NewItem.MakeEmpty;

  while cardinal(OldItem) < cardinal(OldItemsEnd) do begin
    if OldItem.SearchDistance <> EMPTY_ITEM_SEARCH_DISTANCE then begin
      NewItem.Exchange(OldItem^);
      NewItem.SearchDistance := 1;

      ItemInd := NewItem.Hash and ModCapacityMask;
      Item    := @Self.fItems[ItemInd];

      while Item.SearchDistance <> EMPTY_ITEM_SEARCH_DISTANCE do begin
        if NewItem.SearchDistance > Item.SearchDistance then begin
          NewItem.Exchange(Item^);
        end;

        Inc(Item);
        Inc(NewItem.SearchDistance);

        ItemInd := (ItemInd + 1) and ModCapacityMask;

        if ItemInd = 0 then begin
          Item := @Self.fItems[0];
        end;
      end;

      // Finally swap with empty item
      NewItem.Exchange(Item^);
    end; // .if

    Inc(OldItem);
  end; // .for
end; // .procedure TObjHashTable.Rehash

procedure TObjHashTable.BeginIterate;
begin
  Self.fIterPos := 0;
  Self.fLocked  := true;
end;

function TObjHashTable.IterateNext (out {Un} Key: pointer; out {Un} Value: pointer): boolean;
var
{Un} Item: PObjHashTableItem;

begin
  {!} Assert(Self.fLocked);
  Item := @Self.fItems[Self.fIterPos];

  while (Self.fIterPos < Self.fCapacity) and (Item.SearchDistance = EMPTY_ITEM_SEARCH_DISTANCE) do begin
    Inc(Item);
    Inc(Self.fIterPos);
  end;

  result := Self.fIterPos < Self.fCapacity;

  if result then begin
    Value := Item.Value;
    Key   := Self.HashToKey(Item.Hash);
    Inc(Self.fIterPos);
  end;
end;

procedure TObjHashTable.EndIterate;
begin
  Self.fLocked := false;
end;

procedure TObjHashTable.Assign (Source: UtilsB2.TCloneable);
var
{U} SrcTable: TObjHashTable;
    Item:     PObjHashTableItem;
    ItemsEnd: PObjHashTableItem;

begin
  {!} Assert(Source <> nil);
  {!} Assert(not Self.fLocked);
  SrcTable := Source as TObjHashTable;
  // * * * * * //
  if Self <> Source then begin
    {!} Assert(not SrcTable.fOwnsItems or SrcTable.fItemsAreObjects, 'Impossible to clone hash table if it contains owned non-object pointers');
    Self.FreeValues;
    Self.fOwnsItems       := SrcTable.fOwnsItems;
    Self.fItemsAreObjects := SrcTable.fItemsAreObjects;
    Self.fItemGuardProc   := SrcTable.fItemGuardProc;
    Self.fItemGuard       := SrcTable.fItemGuard.Clone;
    Self.fSize            := SrcTable.fSize;
    Self.fCapacity        := SrcTable.fCapacity;
    Self.OnChangeCapacity;
    Self.fItems           := Copy(SrcTable.fItems);

    if Self.fOwnsItems and Self.fItemsAreObjects then begin
      Item     := @Self.fItems[0];
      ItemsEnd := @Self.fItems[Self.fCapacity];

      while cardinal(Item) < cardinal(ItemsEnd) do begin
        if Item.Value <> nil then begin
          Item.Value := (TObject(Item.Value) as UtilsB2.TCloneable).Clone;
        end;

        Inc(Item);
      end;
    end; // .if
  end; // .if
end; // .procedure TObjHashTable.Assign

procedure MergeObjArrays (Destination, Source: TObjArray);
var
{OUn} Value: pointer;
{Un}  Key:   pointer;

begin
  {!} Assert(Source <> nil);
  {!} Assert(not Destination.OwnsItems or (Destination.ItemsAreObjects and Source.ItemsAreObjects), 'Incompatible hash tables for merging due to items type and ownage');
  Source.BeginIterate;

  while Source.IterateNext(Key, Value) do begin
    {!} Assert(Destination.IsValidValue(Value));

    if Destination.OwnsItems then begin
      {!} Assert(TObject(Value) is UtilsB2.TCloneable, 'Cannot merge array with non-clonable items. Got item: ' + TObject(Value).ClassName);
      Destination.SetValue(Key, UtilsB2.TCloneable(Value).Clone);
    end else begin
      Destination.SetValue(Key, Value);
    end;
  end;

  Source.EndIterate;
end;

function NewAssocArr (HashFunc: THashFunc; {n} KeyPreprocessFunc: TKeyPreprocessFunc; OwnsItems,ItemsAreObjects: boolean; ItemType: TClass; AllowNil: boolean): TAssocArray;
var
{O} ItemGuard: UtilsB2.TDefItemGuard;

begin
  {!} Assert(ItemsAreObjects or (ItemType = UtilsB2.NO_TYPEGUARD));
  ItemGuard := UtilsB2.TDefItemGuard.Create;
  // * * * * * //
  ItemGuard.ItemType := ItemType;
  ItemGuard.AllowNil := AllowNil;
  result             := TAssocArray.Create(HashFunc, KeyPreprocessFunc, OwnsItems, ItemsAreObjects, @UtilsB2.DefItemGuardProc, UtilsB2.TItemGuard(ItemGuard));
end;

function NewSimpleAssocArr (HashFunc: THashFunc; {n} KeyPreprocessFunc: TKeyPreprocessFunc): TAssocArray;
var
{O} ItemGuard: UtilsB2.TCloneable;

begin
  ItemGuard := nil;
  result    := TAssocArray.Create (HashFunc, KeyPreprocessFunc, not UtilsB2.OWNS_ITEMS, not UtilsB2.ITEMS_ARE_OBJECTS, @UtilsB2.NoItemGuardProc, ItemGuard);
end;

function NewStrictAssocArr ({n} TypeGuard: TClass; OwnsItems: boolean = true): TAssocArray;
begin
  result := NewAssocArr(Crypto.FastAnsiHash, Legacy.AnsiLowerCase, OwnsItems, UtilsB2.ITEMS_ARE_OBJECTS, TypeGuard, UtilsB2.ALLOW_NIL);
end;

function NewObjArr (OwnsItems, ItemsAreObjects: boolean; ItemType: TClass; AllowNil: boolean): TObjArray;

var
{O} ItemGuard: UtilsB2.TDefItemGuard;

begin
  {!} Assert(ItemsAreObjects or (ItemType = UtilsB2.NO_TYPEGUARD));
  ItemGuard :=  UtilsB2.TDefItemGuard.Create;
  // * * * * * //
  ItemGuard.ItemType := ItemType;
  ItemGuard.AllowNil := AllowNil;
  result             := TObjArray.Create(OwnsItems, ItemsAreObjects, @UtilsB2.DefItemGuardProc, UtilsB2.TItemGuard(ItemGuard));
end; // .function NewObjArr

function NewSimpleObjArr: TObjArray;
var
{O} ItemGuard: UtilsB2.TCloneable;

begin
  ItemGuard :=  nil;
  result    := TObjArray.Create (not UtilsB2.OWNS_ITEMS, not UtilsB2.ITEMS_ARE_OBJECTS, @UtilsB2.NoItemGuardProc, ItemGuard);
end; // .function NewSimpleObjArr

function NewSimpleStrBinTree (HashFunc: THashFunc; {n} KeyPreprocessFunc: TKeyPreprocessFunc): TStrBinTree;
var
{O} ItemGuard: UtilsB2.TCloneable;

begin
  ItemGuard := nil;
  result    := TStrBinTree.Create (HashFunc, KeyPreprocessFunc, not UtilsB2.OWNS_ITEMS, not UtilsB2.ITEMS_ARE_OBJECTS, @UtilsB2.NoItemGuardProc, ItemGuard);
end;

function NewStrictObjArr ({n} TypeGuard: TClass; OwnsItems: boolean = true): TObjArray;
begin
  result := NewObjArr(OwnsItems, UtilsB2.ITEMS_ARE_OBJECTS, TypeGuard, UtilsB2.ALLOW_NIL);
end;

end.
