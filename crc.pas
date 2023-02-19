unit crc;

interface

function GetCrc(var data;size:longint):longint;

implementation

var CrcTable:array[byte] of longint;

function GetCrc(var data;size:longint):longint;
var crc,c:longint;
    p:^byte;
    i:longint;
begin
  p:=@data;
  crc:= $FFFFFFFF;
  for i:=1 to size do begin
    c:=p^;
    inc(p);
    crc:=((crc shr 8) and $FFFFFF) xor CrcTable[(crc xor c) and $FF];
  end;
  Result:=crc xor $FFFFFFFF;
end;

procedure ComputeCrcTab;
var crc, poly,i, j:longint;
begin
  {$R-}
  poly:=$EDB88320;
  for i:=0 to 255 do begin
    crc:=i;
    for j:=8 downto 0 do if odd(crc) then crc:=(crc shr 1) xor poly else crc:=crc shr 1;
    CrcTable[i]:=crc;
  end;
end;

begin
  ComputeCrcTab;
end.
