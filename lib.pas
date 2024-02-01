unit lib;

interface

uses compiler;

procedure InitLibrary;
procedure FreeLibrary;
procedure ResetLibrary;

function Float_Int(info:TProcedure;data:longint):longint;
function List1(info:TProcedure;data:longint):longint;
function NewMove(info:TProcedure;data:longint):longint;
function DrawStrIntInt(info:TProcedure;data:longint):longint;
function StrConcate(info:TProcedure;data:longint):longint;
function StrCompare(info:TProcedure;data:longint):longint;
function StrIntInt_Str(info:TProcedure;data:longint):longint;
function Int_Str(info:TProcedure;data:longint):longint;
function IntInt_Int(info:TProcedure;data:longint):longint;
function Int_Int(info:TProcedure;data:longint):longint;
function FloatFloat_Float(info:TProcedure;data:longint):longint;
function Float_Float(info:TProcedure;data:longint):longint;

function GetString(i:integer):string;

function NewString(s:string):longint;

implementation

uses Windows,Graphics,classes,sysutils,navig,crc;

var Strings:TStringList;
    Bitmaps:TStringList;

function GetString(i:integer):string;
begin
  if (i<1) or (i>Strings.Count) then
    Result:='##Error##'
  else Result:=Strings[i];
end;


{direktiva níže je nutná, aby se struktury TParams pøesnì trefili do dat programu}
{$A4}

function Float_Int;
type TParams=record
               Res:longint;
               float1:Float;
             end;
var p:^TParams;
begin
  Result:=info.GetFixedParams(data,pointer(p));
  with p^ do begin
    if info.Ident = 'round' then Res:=round(float1) else
    if info.Ident = 'trunc' then Res:=trunc(float1) else
    Result:=-1;
  end;
end;

function List1;
var par:TParam;
begin
  Result:=info.GetRealParams(data,par);
  if info.Ident = 'Init' then TList(par.ParData^):=TList.Create else
  if info.Ident = 'Free' then TList(par.ParData^).Free else
  Result:=-1;
end;

procedure variant2;
type Params=record
              id:pointer;
              var_type:pointer;
              var_data:record end;
            end;
begin
{
  with Params(data) do begin
    if info.Ident = 'Append' then begin
      GetMem(p,TType(var_type).Size);
      Move(var_data,p^,TType(var_type).Size);
      TList(id).Add(p);
    end else
    Prg.ExitCode:=ERRBADSYS;
  end;
}
end;

function newmove;
var par:array [1..3] of TParam;
    m:TMove;
begin
  Result:=info.GetRealParams(data,par);
  m:=CurMove.NextMoves.Add as TMove;
  m.SetData(par[1].ParData,GetString(longint(par[2].ParData^)),float(par[3].ParData^));
end;

function DrawStrIntInt;
type TParams=record strid,x,y:longint; end;
var p:^TParams;
    bmpid:longint;
    bmp:TBitmap;
    s:string;
    te:TSize;
    ImgDC:thandle;
begin
  Result:=info.GetFixedParams(data,pointer(p));
  if info.Ident='DrawBitmap' then with p^ do begin
    s:=Strings[strid]+'.bmp';
    bmpid:=Bitmaps.IndexOf(s);
    if bmpid=-1 then begin
      bmp:=TBitmap.Create;
      try
        bmp.LoadFromFile(s);
        bmp.Transparent:=true;
      except
      end;
      Bitmaps.AddObject(s,bmp);
    end else bmp:=Bitmaps.Objects[bmpid] as TBitmap;
    Navigator.ExpandGameImgSize(x+bmp.Width,y+bmp.Height);
    Navigator.ImgGameState.Canvas.Draw(x,y,bmp);
  end else
  if info.Ident='DrawText' then with p^ do begin
    te:=Navigator.ImgGameState.Picture.Bitmap.Canvas.TextExtent(Strings[strid]);
    Navigator.ExpandGameImgSize(x+te.cx,y+te.cy);
    s:=Strings[strid];
    ImgDC:=CreateCompatibleDC(0);
    SelectObject(ImgDC,GetStockObject(DEFAULT_GUI_FONT));
    SelectObject(ImgDC,Navigator.ImgGameState.Picture.Bitmap.Handle);
    if length(s)>0 then TextOut(ImgDC,x,y,@s[1],length(s));
    DeleteObject(ImgDC);
  end else Result:=-1;
end;

function StrConcate;
type TParams=record
               str1,str2:longint;
             end;
var p:^TParams;
begin
  Result:=4; {vyhodim iba jeden string}
  info.GetFixedParams(data,pointer(p));
  with p^ do str1:=NewString(GetString(str1)+GetString(str2));
end;

function StrCompare;
type TParams=record
               str1,str2:longint;
             end;
var p:^TParams;
    s1,s2:string;
begin
  Result:=4; {vyhodim iba jeden string}
  info.GetFixedParams(data,pointer(p));
  with p^ do begin
    s1:=GetString(str1)+#0;
    s2:=GetString(str2)+#0;
    str1:=StrComp(@s1[1],@s2[1]);
  end;
end;

function StrIntInt_Str;
type TParams=record
               res:longint; {str}
               str,int1,int2:longint;
             end;
var p:^TParams;
    s:string;
begin
  Result:=info.GetFixedParams(data,pointer(p));
  with p^ do begin
    s:=GetString(str);
    res:=NewString(Copy(s,int1,int2));
  end;  
end;

function Int_Str;
type TParams=record
               res:longint; {str}
               int:longint;
             end;
var p:^TParams;
begin
  Result:=info.GetFixedParams(data,pointer(p));
  with p^ do res:=NewString(IntToStr(int));
end;

function IntInt_Int;
type TParams=record
               res:longint;
               a:longint;
               b:longint;
             end;
var p:^TParams;
begin
  Result:=info.GetFixedParams(data,pointer(p));
  with p^ do
  if info.Ident='Min' then if a<b then res:=a else res:=b else
  if info.Ident='Max' then if a>b then res:=a else res:=b else
  Result:=-1;
end;

function Int_Int;
type TParams=record
               res:longint;
               a:longint;
             end;
var p:^TParams;
begin
  Result:=info.GetFixedParams(data,pointer(p));
  with p^ do
  if info.Ident='Sgn' then if a>0 then res:=1 else if a<0 then res:=-1 else res:=0 else
  if info.Ident='Abs' then res:=abs(a) else
  if (info.Ident='Bit') and (a>=0) and (a<=31) then res:=1 shl a else
  if (info.Ident='Rnd') and (a>0) then res:=random(a) else
  Result:=-1;
end;

function FloatFloat_Float;
type TParams=record
               res:float;
               a:float;
               b:float;
             end;
var p:^TParams;
begin
  Result:=info.GetFixedParams(data,pointer(p));
  with p^ do
  if info.Ident='Minf' then if a<b then res:=a else res:=b else
  if info.Ident='Maxf' then if a>b then res:=a else res:=b else
  Result:=-1;
end;

function Float_Float;
type TParams=record
               res:float;
               a:float;
             end;
var p:^TParams;
begin
  Result:=info.GetFixedParams(data,pointer(p));
  with p^ do
  if info.Ident='Sgnf' then if a>0 then res:=1 else if a<0 then res:=-1 else res:=0 else
  if info.Ident='Absf' then res:=abs(a) else
  if (info.Ident='Rndf') and (a>0) then res:=random*a else
  Result:=-1;
end;

function NewString(s:string):longint;
begin
  Result:=Strings.Add(s);
end;

procedure InitLibrary;
begin
  Strings:=TStringList.Create;
  Strings.Add('');
  Bitmaps:=TStringList.Create;
end;

procedure FreeLibrary;
begin
  ResetLibrary;
  Strings.Free;
  Bitmaps.Free;
end;

procedure ResetLibrary;
var i:longint;
begin
  for i:=0 to Bitmaps.Count-1 do (Bitmaps.Objects[i] as TBitmap).Free;
  Bitmaps.Clear;
end;

end.
