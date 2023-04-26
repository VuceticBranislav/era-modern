unit DataFlows;
(*
  Byte stream interfaces, helpers, abstract classes.
*)

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

(***)  interface  (***)

uses
  Legacy, SysUtils, UtilsB2;

const
  ENDLESS_SIZE = -1;
  SIZE_ERROR   = -2;

type
  IReadable = interface
    (* Reads up to specified number of bytes to buffer. Returns number of actually read bytes *)
    function ReadUpTo (Count: integer; {n} Buf: pointer): integer;

    (* Returns true if end of data is reached. EOF may be not detectable before data reading attempt is made. Thus
       reading 0 bytes without EOF two times one after another can be considered an IO error *)
    function IsEof: boolean;
  end;

  IWritable = interface
    (* Writes up to specified number of bytes to buffer. Returns number of actually written bytes *)
    function WriteUpTo (Count: integer; {n} Buf: pointer): integer;
  end;

  ISeekable = interface
    (* Set new caret position in data stream, if possible. NOTE: Position becomes undefined on failure *)
    function Seek (Pos: integer): boolean;
  end;

  ISizable = interface
    function GetSize: Int64;
  end;

  IEndless = interface

  end;

  (* Endless stream of zero bytes *)
  TZeroReader = class (UtilsB2.TManagedObject, IReadable)
   public
    function ReadUpTo (Count: integer; {n} Buf: pointer): integer;
    function IsEof: boolean;
  end;

  (* Endless stream, consuming all bytes without any action *)
  TNullWriter = class (UtilsB2.TManagedObject, IWritable)
   public
    function WriteUpTo (Count: integer; {n} Buf: pointer): integer;
  end;

  TBinaryReader = class abstract

  end;

  TBinaryWriter = class abstract
    class procedure WriteBytes (const Destination: IWritable; Count: integer; {n} Buf: pointer); static;
  end;

  (* All methods assert reading success *)
  IInputByteMapper = interface
    function GetSource: IReadable;
    function ReadByte: byte;
    function ReadWord: word;
    function ReadInt: integer;
    function ReadInt64: int64;
    function ReadFloat32: single;
    function ReadDouble: double;
    function ReadStr (StrLen: integer): myAStr;
    function ReadStrWithLenPrefix (StrLenPrefixSize: integer): myAStr;
  end;

  // TInputByteMapper = class (TInterfacedObject, IInputByteMapper)
  //  protected
  //   fByteSource: IReadable;

  //  public
  //   constructor Create (ByteSource: IReadable);

  //   function GetSource: IReadable;
  //   function ReadByte: byte;
  //   function ReadWord: word;
  //   function ReadInt: integer;
  //   function ReadInt64: int64;
  //   function ReadFloat32: single;
  //   function ReadDouble: double;
  //   function ReadStr (StrLen: integer): string;
  //   function ReadStrWithLenPrefix (StrLenPrefixSize: integer): string;
  // end; // .TInputByteMapper

  // NullReader
  // NullWriter

  (*
    Provides means for formatted output to external storage.
    It's recommended to internally use StrBuilder for file output.
    Default indentation must be '  ', line end marker - #13#10.
  *)
  // IFormattedOutput = interface (IWritable)
  //   (* Sets new string to use as single level indentation. Real indentation string will be multiplied by indentation level *)
  //   procedure SetIndentationTemplate (const IndentationTmpl: string);
    
  //   (* Assigns new string to use as line end marker. Markers are used to detecting, where indentation should be applied *)
  //   procedure SetLineEndMarker (const LineEndMarker: string);

  //   (* Increase indentation level by one *)
  //   procedure Indent;
    
  //   (* Decreases indentation level by one *)
  //   procedure Outdent;
    
  //   (* Sets new indentation level (>= 0) *)
  //   procedure SetIndentationLevel (Level: integer);

  //   (* Returns current indentation level (>= 0) *)
  //   function GetIndentationLevel: integer;

  //   function GetIndentationTemplate: string;
    
  //   procedure Write (const Str: string);
    
  //   // Same as Write + Write([line end marker])
  //   procedure WriteIndentation;

  //   (* Same as: set indent level to 0 + Write + restore indent level + [line end marker] *)
  //   procedure RawLine (const Str: string);
    
  //   // Same as Write([indentation]) * [indent level] + RawLine(Str)
  //   procedure Line (const Str: string);
    
  //   (* Same as Write([line end marker]) *)
  //   procedure EmptyLine;
  // end; // .interface IFormattedOutput

  // TBufferedOutput = class (TInterfacedObject, IWritable)
  //  private
  //   fDestination: IWritable;
  //   fBuf:         UtilsB2.TArrayOfByte;
  //   fSize:        integer;
  //   fPos:         integer;

  //   function Alloc (NumBytes: integer): {U} pbyte;
   
  //  public
  //   constructor Create (Destination: IWritable);

  //   function WriteUpTo (Count: integer; {n} Buf: pointer): integer;
    
  //   (* Erases any buffered data *)
  //   procedure Clear;

  //   (* Writes all buffered data to destination immeaditely *)
  //   procedure Flush;
  // end; // .class TBufferedOutput


(***)  implementation  (***)


// TGrowableBuffer

// TBytesWriter

// with TFormattedOutput.Create(TBufferedOutput.Create(TFile.Create(Path), 1000000)) do begin

// end;

// with StrLib.FormatOutput(DataFlows.BufOutput(TFile.Create(Path), 1000000)) do begin

// end;

// DataFlows.Reader.ReadBytes();

//constructor TBufferedOutput.Create

function TZeroReader.ReadUpTo (Count: integer; {n} Buf: pointer): integer;
begin
  {!} Assert(UtilsB2.IsValidBuf(Buf, Count));
  Legacy.FillChar(Buf^, Count, 0);
  result := Count;
end;

function TZeroReader.IsEof: boolean;
begin
  result := false;
end;

function TNullWriter.WriteUpTo (Count: integer; {n} Buf: pointer): integer;
begin
  {!} Assert(UtilsB2.IsValidBuf(Buf, Count));
  result := Count;
end;

procedure ReadBytes (Count: integer; {n} Buf: pointer; Source: IReadable);
var
  NumBytesRead:   integer;
  TotalBytesRead: integer;

begin
  {!} Assert(UtilsB2.IsValidBuf(Buf, Count));
  {!} Assert(Source <> nil);
  TotalBytesRead := 0;

  while TotalBytesRead < Count do begin
    NumBytesRead := Source.ReadUpTo(Count, UtilsB2.PtrOfs(Buf, TotalBytesRead));

    if NumBytesRead <= 0 then begin
      raise EInOutError.Create(string(Legacy.Format('Failed to read %d bytes from IReadable. Bytes read: %d', [Count, TotalBytesRead])));
    end;

    Inc(TotalBytesRead, NumBytesRead);
  end;
end; // .procedure ReadBytes

class procedure TBinaryWriter.WriteBytes (const Destination: IWritable; Count: integer; {n} Buf: pointer);
var
  NumBytesWritten:   integer;
  TotalBytesWritten: integer;

begin
  {!} Assert(UtilsB2.IsValidBuf(Buf, Count));
  {!} Assert(Destination <> nil);
  TotalBytesWritten := 0;

  while TotalBytesWritten < Count do begin
    NumBytesWritten := Destination.WriteUpTo(Count, UtilsB2.PtrOfs(Buf, TotalBytesWritten));

    if NumBytesWritten <= 0 then begin
      raise EInOutError.Create(string(Legacy.Format('Failed to write %d bytes from IWritable. Bytes written: %d', [Count, TotalBytesWritten])));
    end;

    Inc(TotalBytesWritten, NumBytesWritten);
  end;
end; // .procedure TBinaryWriter.WriteBytes

end.