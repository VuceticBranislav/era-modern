unit CFiles;
{
DESCRIPTION:  Abstract interface of virtual device with sequential access
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses Math, SysUtils, UtilsB2, Legacy;

const
  MODE_OFF        = 0;
  MODE_READ       = 1;
  MODE_WRITE      = 2;
  MODE_READWRITE  = 3;

type
  TDeviceMode = MODE_OFF..MODE_READWRITE;

  (*
  Note about detecting Input/Output (IO) errors.
  if an error occurs during any operation functions will return FALSE.
  But FALSE is also returned if end of file (EOF) is reached.
  The solution is to check EOF flag after FALSE result.
  if EOF is true, then nothing more can be read/written, otherwise IO error occured.
  
  Example:
  while File.ReadByte(Arr[File.Pos]) do begin end;
  if not File.EOF then begin /* ERROR! */ end;
  *)
  
  TAbstractFile = class abstract
    (***) protected (***)
      const
        MIN_BUF_SIZE  = 64 * 1024;
        MAX_BUF_SIZE  = 1024 * 1024;
    
      var
        fMode:          TDeviceMode;
        fHasKnownSize:  boolean;
        fSizeIsConst:   boolean;
        fSize:          integer;
        fPos:           integer;
        fEOF:           boolean;
  
    (***) public (***)
      (* Core *)
      
      // Reads 1..Count bytes
      function  ReadUpTo
      (
                Count:      integer;
            {n} Buf:        pointer;
        out     BytesRead:  integer
      ): boolean; virtual; abstract;
      
      // Writes 1..Count bytes
      function  WriteUpTo
      (
                Count:        integer;
            {n} Buf:          pointer;
        out     ByteWritten:  integer
      ): boolean; virtual; abstract;

      function  Seek (NewPos: integer): boolean; virtual; abstract;
    
      (* Reading *)
      function  Read (Count: integer; {n} Buf: pointer): boolean;
      procedure DoRead (Count: integer; {n} Buf: pointer);
      function  ReadByte (out Res: byte): boolean;
      function  DoReadByte: byte;
      function  ReadInt (out Res: integer): boolean;
      function  DoReadInt: integer;
      function  ReadStr (Count: integer; out Res: myAStr): boolean;
      function  DoReadStr (Len: integer): myAStr;
      function  ReadAllToBuf (out Buf: pointer; out Size: integer): boolean;
      function  ReadAllToStr (out Str: myAStr): boolean;

      (* Writing *)
      function  Write (Count: integer; {n} Buf: pointer): boolean;
      procedure DoWrite (Count: integer; {n} Buf: pointer);
      function  WriteByte (Data: byte): boolean;
      procedure DoWriteByte (Data: byte);
      function  WriteWord (Data: word): boolean;
      procedure DoWriteWord (Data: word);
      function  WriteInt (Data: integer): boolean;
      procedure DoWriteInt (Data: integer);
      function  WriteStr (const Data: myAStr): boolean;
      procedure DoWriteStr (const Data: myAStr);
      function  WriteFrom (Count: integer; Source: TAbstractFile): boolean;
      function  WriteAllFrom (Source: TAbstractFile): boolean;

      property  Mode:         TDeviceMode read fMode;
      property  HasKnownSize: boolean read fHasKnownSize;
      property  SizeIsConst:  boolean read fSizeIsConst;
      property  Size:         integer read fSize;
      property  Pos:          integer read fPos;
      property  EOF:          boolean read fEOF;
  end; // .class TAbstractFile
  
  TItemInfo = class
    IsDir:        boolean;
    HasKnownSize: boolean;
    FileSize:     integer;
  end; // .class TItemInfo
  
  TAbstractLocator  = class
    (***) protected (***)
      fNotEnd:      boolean;
      fSearchMask:  myAStr;
      
    (***) public (***)
      destructor  Destroy; override;
      procedure FinitSearch; virtual; abstract;
      procedure InitSearch (const Mask: myAStr); virtual; abstract;
      function  GetNextItem (out ItemInfo: TItemInfo): myAStr; virtual; abstract;
      function  GetItemInfo
      (
        const ItemName: myAStr;
        out   ItemInfo: TItemInfo
      ): boolean; virtual; abstract;
      
      property  NotEnd:     boolean read fNotEnd;
      property  SearchMask: myAStr read fSearchMask;
  end; // .class TAbstractLocator


(***) implementation (***)


function TAbstractFile.Read (Count: integer; {n} Buf: pointer): boolean;
var
  TotalBytesRead: integer;
  BytesRead:      integer;

begin
  {!} Assert(Count >= 0);
  TotalBytesRead := 0;
  
  while
    (TotalBytesRead < Count)  and
    Self.ReadUpTo(Count - TotalBytesRead, UtilsB2.PtrOfs(Buf, TotalBytesRead), BytesRead)
  do begin
    TotalBytesRead := TotalBytesRead + BytesRead;
  end;
  
  result := TotalBytesRead = Count;
end;

procedure TAbstractFile.DoRead (Count: integer; {n} Buf: pointer);
var
  Res: boolean;

begin
  Res := Self.Read(Count, Buf);
  {!} Assert(Res, string('Failed to read ' + Legacy.IntToStr(Count) + ' bytes from TAbstractFile'));
end;

function TAbstractFile.ReadByte (out Res: byte): boolean;
var
  BytesRead: integer;

begin
  result  :=  Self.ReadUpTo(sizeof(Res), @Res, BytesRead);
end;

function TAbstractFile.DoReadByte: byte;
begin
  Self.DoRead(sizeof(result), @result);
end;

function TAbstractFile.ReadInt (out Res: integer): boolean;
begin
  result  :=  Self.Read(sizeof(Res), @Res);
end;

function TAbstractFile.DoReadInt: integer;
begin
  Self.DoRead(sizeof(result), @result);
end;

function TAbstractFile.ReadStr (Count: integer; out Res: myAStr): boolean;
begin
  SetLength(Res, Count);
  result := Self.Read(Count, pointer(Res));
  
  if not result then begin
    Res :=  '';
  end;
end;

function TAbstractFile.DoReadStr (Len: integer): myAStr;
begin
  SetLength(result, Len);
  Self.DoRead(Len, pointer(result));
end;

function TAbstractFile.ReadAllToBuf (out Buf: pointer; out Size: integer): boolean;
var
  TotalBytesRead: integer;
  BytesRead:      integer;
  BufSize:        integer;

begin
  {!} Assert(Buf = nil);
  if Self.HasKnownSize then begin
    Size  :=  Self.Size;
    GetMem(Buf, Size);
    result  :=  Self.Read(Size, Buf);
  end else begin
    BufSize :=  Self.MIN_BUF_SIZE;
    GetMem(Buf, BufSize);
    TotalBytesRead  :=  0;
    
    while
      Self.ReadUpTo(BufSize - TotalBytesRead, UtilsB2.PtrOfs(Buf, TotalBytesRead), BytesRead) and
      not Self.EOF
    do begin
      TotalBytesRead  :=  TotalBytesRead + BytesRead;
      
      if TotalBytesRead = BufSize then begin
        BufSize :=  BufSize * 2;
        ReallocMem(Buf, BufSize);
      end;
    end; // .while
    
    result  :=  Self.EOF;
    
    if result and (BufSize > TotalBytesRead) then begin
      ReallocMem(Buf, TotalBytesRead);
    end;
  end; // .else
  // * * * * * //
  if not result then begin
    FreeMem(Buf); Buf :=  nil;
  end;
end; // .function TAbstractFile.ReadAllToBuf

function TAbstractFile.ReadAllToStr (out Str: myAStr): boolean;
var
  TotalBytesRead: integer;
  BytesRead:      integer;
  StrLen:         integer;

begin
  if Self.HasKnownSize then begin
    result  :=  Self.ReadStr(Self.Size, Str);
  end else begin
    StrLen  :=  Self.MIN_BUF_SIZE;
    SetLength(Str, StrLen);
    TotalBytesRead  :=  0;
    
    while
      Self.ReadUpTo(StrLen - TotalBytesRead, @Str[1 + TotalBytesRead], BytesRead) and
      not Self.EOF
    do begin
      TotalBytesRead  :=  TotalBytesRead + BytesRead;
      
      if TotalBytesRead = StrLen then begin
        StrLen  :=  StrLen * 2;
        SetLength(Str, StrLen);
      end;
    end; // .while
    
    result := Self.EOF;
    
    if result and (StrLen > TotalBytesRead) then begin
      SetLength(Str, TotalBytesRead);
    end;
  end; // .else
  // * * * * * //
  if not result then begin
    Str :=  '';
  end;
end; // .function TAbstractFile.ReadAllToStr

function TAbstractFile.Write (Count: integer; {n} Buf: pointer): boolean;
var
  TotalBytesWritten:  integer;
  BytesWritten:       integer;

begin
  {!} Assert(Count >= 0);
  TotalBytesWritten :=  0;
  
  while
    (TotalBytesWritten < Count) and
    Self.WriteUpTo(Count - TotalBytesWritten, UtilsB2.PtrOfs(Buf, TotalBytesWritten), BytesWritten)
  do begin
    TotalBytesWritten :=  TotalBytesWritten + BytesWritten;
  end;
  
  result  :=  TotalBytesWritten = Count;
end; // .function TAbstractFile.Write

procedure TAbstractFile.DoWrite (Count: integer; {n} Buf: pointer);
begin
  if not Self.Write(Count, Buf) then begin
    {!} Assert(false, string('Failed to write ' + Legacy.IntToStr(Count) + ' bytes to TAbstractFile'));
  end;
end;

function TAbstractFile.WriteByte (Data: byte): boolean;
var
  BytesWritten: integer;

begin
  result := Self.WriteUpTo(sizeof(Data), @Data, BytesWritten);
end;

procedure TAbstractFile.DoWriteByte (Data: byte);
begin
  Self.DoWrite(sizeof(Data), @Data);
end;

function TAbstractFile.WriteWord (Data: word): boolean;
begin
  result := Self.Write(sizeof(Data), @Data);
end;

procedure TAbstractFile.DoWriteWord (Data: word);
begin
  Self.DoWrite(sizeof(Data), @Data);
end;

function TAbstractFile.WriteInt (Data: integer): boolean;
begin
  result := Self.Write(sizeof(Data), @Data);
end;

procedure TAbstractFile.DoWriteInt (Data: integer);
begin
  Self.DoWrite(sizeof(Data), @Data);
end;

function TAbstractFile.WriteStr (const Data: myAStr): boolean;
begin
  result := Self.Write(Length(Data), pointer(Data));
end;

procedure TAbstractFile.DoWriteStr (const Data: myAStr);
begin
  Self.DoWrite(Length(Data), pointer(Data));
end;

function TAbstractFile.WriteFrom (Count: integer; Source: TAbstractFile): boolean;
var
  StrBuf:           myAStr;
  NumWriteOpers:    integer;
  NumBytesToWrite:  integer;
  i:                integer;

begin
  {!} Assert(Count >= 0);
  {!} Assert(Source <> nil);
  result  :=  FALSE;
  SetLength(StrBuf, Math.Min(Count, Self.MAX_BUF_SIZE));

  if Count <= MAX_BUF_SIZE then begin
    result  :=
      Source.Read(Count, pointer(StrBuf)) and
      Self.Write(Count, pointer(StrBuf));
  end else begin
    NumWriteOpers   :=  Math.Ceil(Count / MAX_BUF_SIZE);
    NumBytesToWrite :=  MAX_BUF_SIZE;
    i               :=  1;
    
    while (i <= NumWriteOpers) and result do begin
      if i = NumWriteOpers then begin
        NumBytesToWrite :=  Count - (MAX_BUF_SIZE * (NumWriteOpers - 1));
      end;
      
      result  :=
        Source.Read(NumBytesToWrite, pointer(StrBuf)) and
        Self.Write(NumBytesToWrite, pointer(StrBuf));
      
      Inc(i);
    end; // .while
  end; // .else
end; // .function TAbstractFile.WriteFrom

function TAbstractFile.WriteAllFrom (Source: TAbstractFile): boolean;
var
  StrBuf:     myAStr;
  BytesRead:  integer;

begin
  {!} Assert(Source <> nil);
  result  :=  TRUE;
  
  if Source.HasKnownSize then begin
    result  :=  Self.WriteFrom(Source.Size, Source);
  end else begin
    SetLength(StrBuf, Self.MAX_BUF_SIZE);
    
    while result and Source.ReadUpTo(Self.MAX_BUF_SIZE, pointer(StrBuf), BytesRead) do begin
      result  :=  Self.Write(BytesRead, pointer(StrBuf));
    end;

    result  :=  result and Source.EOF;
  end; // .else
end; // .function TAbstractFile.WriteAllFrom

destructor TAbstractLocator.Destroy;
begin
  Self.FinitSearch;
end; // .destructor TAbstractLocator.Destroy

end.
