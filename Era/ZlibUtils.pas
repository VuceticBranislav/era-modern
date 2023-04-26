unit ZlibUtils;
(*
  ZLib function wrappers over zlibpas from pngimage package.
  Single-thread only currently, uses global growth-only buffer.
*)


(***)  interface  (***)

uses
  Math,
  SysUtils,

  Zlib,

  StrLib,
  UtilsB2, Legacy;


type
  (* Import *)
  TStrBuilder = StrLib.TStrBuilder;
  TZStreamRec = Zlib.TZStreamRec;


const
  COMPRESSION_LEVEL_NONE    = 0;
  COMPRESSION_LEVEL_MIN     = 1;
  COMPRESSION_LEVEL_DEFAULT = 6;
  COMPRESSION_LEVEL_MAX     = 9;
  COMPRESSION_LEVEL_0       = 0;
  COMPRESSION_LEVEL_1       = 1;
  COMPRESSION_LEVEL_2       = 2;
  COMPRESSION_LEVEL_3       = 3;
  COMPRESSION_LEVEL_4       = 4;
  COMPRESSION_LEVEL_5       = 5;
  COMPRESSION_LEVEL_6       = 6;
  COMPRESSION_LEVEL_7       = 7;
  COMPRESSION_LEVEL_8       = 8;
  COMPRESSION_LEVEL_9       = 9;


(* Compresses data in memory and returns temporary pointer to result buffer. The pointer may be invalidated after any module function call. *)
function Compress ({n} Buf: pointer; BufSize: integer; CompressionLevel: integer = COMPRESSION_LEVEL_DEFAULT): UtilsB2.TArrayOfByte;

(* Decompresses previously compressed data and returns temporary pointer to result buffer or nil on error. The pointer may be invalidated after any module function call. *)
function Decompress ({n} Buf: pointer; BufSize: integer): {n} UtilsB2.TArrayOfByte;


(***)  implementation  (***)


const
  BUF_MIN_SIZE    = 65000;
  BUF_GROWTH_KOEF = 1.5;


function Compress ({n} Buf: pointer; BufSize, CompressionLevel: integer): UtilsB2.TArrayOfByte;
var
  StreamRec:       TZStreamRec;
  RequiredBufSize: integer;
  DeflateRet:      integer;

begin
  {!} Assert(UtilsB2.IsValidBuf(Buf, BufSize));

  System.FillChar(StreamRec, sizeof(TZStreamRec), #0);
  Zlib.DeflateInit_(StreamRec, CompressionLevel, Zlib.zlib_version, sizeof(TZStreamRec));

  RequiredBufSize := Zlib.DeflateBound(StreamRec, BufSize);
  result          := nil;
  SetLength(result, RequiredBufSize);

  StreamRec.next_in   := Buf;
  StreamRec.avail_in  := BufSize;
  StreamRec.next_out  := pointer(result);
  StreamRec.avail_out := Length(result);
  DeflateRet          := deflate(StreamRec, Zlib.Z_FINISH);
  {!} Assert(DeflateRet = Zlib.Z_STREAM_END);
  SetLength(result, StreamRec.total_out);

  Zlib.DeflateEnd(StreamRec);
end;

function EstimateDecompressedSize (CompressedSize: integer): integer;
begin
  result := CompressedSize * 2;
end;

function Decompress ({n} Buf: pointer; BufSize: integer): {n} UtilsB2.TArrayOfByte;
var
  StreamRec:       TZStreamRec;
  RequiredBufSize: integer;
  InflateRet:      integer;

begin
  {!} Assert(UtilsB2.IsValidBuf(Buf, BufSize));

  System.FillChar(StreamRec, sizeof(TZStreamRec), #0);
  Zlib.InflateInit_(StreamRec, Zlib.zlib_version, sizeof(TZStreamRec));

  RequiredBufSize := EstimateDecompressedSize(BufSize);
  result          := nil;
  SetLength(result, Math.Max(BUF_MIN_SIZE, RequiredBufSize));

  StreamRec.next_in   := Buf;
  StreamRec.avail_in  := BufSize;
  StreamRec.next_out  := pointer(result);
  StreamRec.avail_out := Length(result);
  InflateRet          := inflate(StreamRec, Zlib.Z_NO_FLUSH);

  while InflateRet <> Zlib.Z_STREAM_END do begin
    if InflateRet < 0 then begin
      result := nil;
      exit;
    end;

    {!} Assert(StreamRec.avail_out = 0);
    RequiredBufSize     := trunc(Length(result) * BUF_GROWTH_KOEF) + 1;
    StreamRec.avail_out := RequiredBufSize - Length(result);
    SetLength(result, RequiredBufSize);
    StreamRec.next_out  := @result[StreamRec.total_out];
    InflateRet          := inflate(StreamRec, Zlib.Z_NO_FLUSH);
  end;

  SetLength(result, StreamRec.total_out);

  Zlib.InflateEnd(StreamRec);
end;

end.