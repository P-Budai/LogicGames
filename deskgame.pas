unit deskgame;

interface

uses objects,extend;

var timertick:longint absolute 0:$46c;

const maxsize=8;
      infinity=1000;
      starttime:longint=1;
type
     PMove=Pointer;
     PDeskGame=^TDeskGame;
     TDeskGame=object(tobject)
       level:byte;
       time:longint;
       constructor init;
       procedure New(var P:pointer); virtual; {call constructor}
       procedure Dispose(var P:pointer); virtual;
       procedure Copy(var src:tdeskgame); virtual;
       function GetScore:integer; virtual;
       procedure GetThisMove(move:pmove); virtual;
       function newmove(move:pmove;mylevel:integer):integer;
       function alfabeta(alfa,beta:integer):integer; virtual;
       function alfabeta2(alfa,beta:integer):integer; virtual;
       procedure GenerInit; virtual;
       function gener(p1:pDeskGame):boolean; virtual;
       procedure push(move:pmove); virtual;
       function gettickcount:longint; virtual;
       procedure Yield; virtual;
     end;

implementation

constructor tdeskgame.init; begin level:=1; time:=starttime end;

procedure tdeskgame.New(var P:pointer); begin runerror(211) end;

procedure tdeskgame.Dispose(var P:pointer); begin runerror(211) end;

procedure tdeskgame.copy; begin runerror(211) end;

function tdeskgame.GetScore:integer; begin runerror(211) end;

procedure tdeskgame.GetThisMove(move:pmove); begin runerror(211) end;

function tdeskgame.alfabeta(alfa,beta:integer):integer;
const hlbka:integer=0;
label exit;
var m:integer;
    p1:pdeskgame;

begin
  inc(hlbka);
  new(pointer(p1));
  m:=getscore; m:=m-sgn(m)*hlbka;
  if (hlbka<=level) and (abs(m)<infinity-hlbka) then begin
    m:=alfa;
    generinit;
    while gener(p1) do
    begin
      m:=max(m,-p1^.alfabeta(-beta,-m));
      if m>=beta then goto exit;
    end
  end; {if}
exit:
  dec(hlbka);
  dispose(pointer(p1));
  alfabeta:=min(max(m,alfa),beta)
end;

function tdeskgame.alfabeta2(alfa,beta:integer):integer;
var c,m:integer;
begin
  if alfa=beta then alfabeta2:=alfa
  else begin
    c:=(alfa+beta) div 2;
    m:=alfabeta(alfa,c);
    if m<c then alfabeta2:=m
         else alfabeta2:=alfabeta2(c,beta)
  end
end;

(*
function tdeskgame.newmove(move:pmove):integer;
var m,t:integer;
    p1:pdeskgame;
    timer1:longint;
begin
  m:=-infinity-1;
  new(pointer(p1));
  generinit;
  while gener(p1) do begin
    repeat
      Yield;
      timer1:=gettickcount;
      t:=-p1^.alfabeta2(-infinity,+infinity);
      if not ((abs(t)<=infinity-infinity div 10) and (gettickcount-timer1<time))
      then break;
      inc(p1^.level);
    until false;
    if gettickcount-timer1>time*2 then dec(p1^.level);
    if t>m then begin m:=t; getthismove(move) end;
    level:=p1^.level;
  end;
  dispose(pointer(p1));
  newmove:=m;
end;
*)

function tdeskgame.newmove(move:pmove;mylevel:integer):integer;
var m,t:integer;
    p1:pdeskgame;
    timer1:longint;
begin
  m:=-infinity-1;
  new(pointer(p1));
  generinit; level:=mylevel;
  while gener(p1) do begin
    Yield;
    t:=-p1^.alfabeta2(-infinity,+infinity);
    if t>=m then if (t>m) or (random(100)>80) then begin m:=t; getthismove(move) end;
    level:=p1^.level;
  end;
  dispose(pointer(p1));
  newmove:=m;
end;

procedure tdeskgame.GenerInit; begin runerror(211) end;

function tdeskgame.gener(p1:pDeskGame):boolean; begin runerror(211) end;

procedure tdeskgame.push(move:pmove); begin runerror(211) end;

function tdeskgame.gettickcount:longint;
begin gettickcount:=timertick end;

procedure tdeskgame.Yield; begin end;

end.