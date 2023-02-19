program Atomix;

uses Extend,deskgame,Objects,WinProcs,WinTypes,OWindows,ODialogs,Win31;

{$r atomix}

const maxsize=8;
      startsize=6;
      border=20;
      headx=100;
      heady=10;
      minunit=30;
      medzera=1;
      menuheight=15;
      wm_mymsg=0;
      cm_Menu=100;

      playermask=$80;
      testmask=$40;
      usedmask=$20;
      nrmask=$f;

      playername='Hrac';
      Caption='Atomix ver 1.0';

      isfirst:boolean=false;

type
     patomixmove=^tatomixmove;
     tatomixmove=record x,y:integer end;
     pplayer=^tplayer;
     tplayer=record
             human:boolean;
             name:string20;  {or computer level in name[1]}
	     score:integer;
	   end;
     patomixgame=^tatomixgame;
     tAtomixGame=object(TDeskGame)
       players:array [boolean] of tplayer;
       onmove:boolean;
       board:array [1..maxsize,1..maxsize+1] of byte;
       sizex,sizey:byte;
       nearx,neary:array[1..maxsize] of byte;
       thismove:tatomixmove;
       hwindow:thandle;
       constructor init(Win:THandle;X,Y:byte);
       procedure SetSize(x,y:integer);
       procedure cleardesk;
       procedure New(var P:pointer); virtual;
       procedure Dispose(var P:pointer); virtual;
       procedure copy(var src:tdeskgame); virtual;
       procedure explode(x,y:integer);
       function GetScore:integer; virtual;
       procedure GenerInit; virtual;
       function gener(p1:pdeskgame):boolean; virtual;
       procedure push(move:pmove); virtual;
       procedure GetThisMove(move:pmove); virtual;
       function gettickcount:longint; virtual;
       procedure Yield; virtual;
     end;

procedure settestbit(var b:byte;x,y:integer); assembler;
asm
      les di,b
      mov al,$40
      or es:[di],al
      cmp x,2
      jb @1
      or es:[di-maxsize],al
@1:      cmp x,maxsize-1
      ja @2
      or es:[di+maxsize],al
@2:      cmp y,2
      jb @3
      or es:[di-1],al
@3:      cmp y,maxsize-1
      ja @4
      or es:[di+1],al
@4:
end;

constructor tatomixgame.Init(Win:THandle;X,Y:byte);
begin
  inherited init;
  hwindow:=win;
  fillchar(players,sizeof(players),0);
  players[false].human:=true;
  players[false].name:=playername;
  players[true].name[1]:=#2;
  setsize(x,y);
end;

procedure tatomixgame.SetSize(x,y:integer);
begin
  sizex:=x; sizey:=y;
  cleardesk;
end;

procedure tatomixgame.cleardesk;
var i:integer;
begin
  onmove:=false;
  players[false].score:=0; players[true].score:=0;
  fillchar(board,sizeof(board),0);
{nastavime testovaci bit}
  for i:=1 to sizex do begin board[i,1]:=testmask; board[i,sizey]:=testmask end;
  for i:=2 to sizey-1 do begin board[1,i]:=testmask; board[sizex,i]:=testmask end;
  fillchar(nearx,sizeof(nearx),2);
  nearx[1]:=1; nearx[sizex]:=1;
  fillchar(neary,sizeof(neary),2);
  neary[1]:=1; neary[sizey]:=1;
end;

procedure tatomixgame.New(var P:pointer);
begin p:=system.new(patomixgame,init(hwindow,sizex,sizey)) end;

procedure tatomixgame.Dispose(var P:pointer);
begin system.dispose(patomixgame(p),done) end;

procedure tatomixgame.copy(var src:tdeskgame);
begin self:=tatomixgame(adr(src)^); end;

procedure tatomixgame.explode(x,y:integer);
var list:array [boolean] of array [1..maxsize*maxsize+1] of byte;
    length:array[boolean] of integer;
    pos:integer;
    which,player:boolean;  {which..akt, not which..new}
    p:integer;
  procedure policko(x,y:integer);
  var p:^byte;
  begin
    p:=@board[x,y];
    if (p^>=playermask)<>player then
    begin
      if player then p^:=p^ or playermask
		else p^:=p^ and not playermask;
      inc(players[player].score,p^ and nrmask);
      dec(players[not player].score,p^ and nrmask);
    end;
    inc(p^);
    settestbit(p^,x,y);
    inc(length[not which]);
    list[not which,length[not which]]:=y shl 4 or x;
  end;
begin
  length[false]:=1; list[false,1]:=y shl 4 or x;
  which:=true; player:=board[x,y]>=playermask;
  while (length[not which]>=1) and (players[not player].score>0) do begin
    pos:=1;            {nastavim sa na zaciatok}
    length[which]:=0;  {nulujem stary zoznam}
    which:=not which;  {prepnem zoznamy}
    while pos<=length[which] do begin {pre vsetky v akt. zozname..}
      x:=list[which,pos] and $f;
      y:=list[which,pos] shr 4;
      p:=nearx[x]+neary[y];
      if board[x,y] and nrmask>=p then begin
      dec(board[x,y],p);
      if y>1 then policko(x,y-1);
      if x>1 then policko(x-1,y);
      if x<sizex then policko(x+1,y);
      if y<sizey then policko(x,y+1);
      end;
      inc(pos);
    end;
  end;
end; {explode}

function tatomixgame.getscore:integer;
var p:integer;
begin
  p:=players[false].score-players[true].score;
  if players[false].score+players[true].score>=2 then {ak bolo aspon jedno kolo}
  begin
    if players[false].score=0 then p:=-infinity;
    if players[true].score=0 then p:=infinity
  end;
  if onmove then getscore:=-p else getscore:=p
end;

procedure tatomixgame.push(move:pmove);
var p:^byte;
begin
  with tatomixmove(move^) do begin
    p:=@board[x,y];
    settestbit(p^,x,y); {nastavi testovaci bit}
    setbit(p^,7,onmove); {nastavi farbu}
    inc(p^); {zvysi pocet atomov}
    inc(players[onmove].score); {upravi skore}
    if p^ and nrmask>=nearx[x]+neary[y] then explode(x,y); {necha ich vybuchovat (p1!)}
    onmove:=not onmove {druhy hrac}
  end;
end;

procedure tatomixgame.generinit;
begin with thismove do begin x:=0; y:=1 end end;

{polozi na x,y (ak sa da) a vrati true inak false}
{nova pozicia je v p1,  p sa nemeni!}
{stale posunie x a y na novu poziciu}
function tatomixgame.gener(p1:pdeskgame):boolean;
var b:byte;
begin
  with thismove do begin
{poskoci na novu poziciu}
    repeat
      inc(x); if x>sizex then begin x:=1; inc(y) end;
      b:=board[x,y];
    until (y>sizey) or (((b>=playermask)=onmove) or (b and nrmask=0)) and (b and testmask>0);
{uz sme nenasli mozny tah}
    if y>sizey then begin gener:=false; exit end;
{vytvorime novu poziciu do p1 (pridanim na x,y)}
    gener:=true;
    p1^.copy(self);
    p1^.push(@thismove);
  end;
end; {novapozicia}

procedure tatomixgame.GetThisMove(move:pmove);
begin patomixmove(move)^:=thismove end;

function tatomixgame.gettickcount:longint;
begin gettickcount:=winprocs.gettickcount end;

procedure tatomixgame.Yield;
begin {sendmessage(hwindow,wm_mymsg,0,0)} winprocs.yield end;


{*************** TOptionDialog ***************}

type
     POptionDialog=^TOptionDialog;
     TOptionDialog=object(TDialog)
       ppar1,ppar2:^byte;
       constructor Init(AParent:PWindowsObject; AName: PChar; var par1,par2:byte);
       procedure OK(var Message: TMessage); virtual id_First + id_Ok;
       procedure SetUpWindow; virtual;
       procedure WMHScroll(var Message: TMessage); virtual wm_HScroll;
     end;

constructor toptiondialog.Init;
begin
  inherited init(aparent,aname);
  ppar1:=@par1;
  ppar2:=@par2
end;

procedure TOptionDialog.SetUpWindow;
begin
  TDialog.SetUpWindow;
  SetScrollRange(GetDlgItem(HWindow, 101), sb_Ctl, 3,8, False);
  SetScrollPos(GetDlgItem(HWindow, 101), sb_Ctl,ppar1^, True);
  SetScrollRange(GetDlgItem(HWindow, 102), sb_Ctl, 3,8, False);
  SetScrollPos(GetDlgItem(HWindow, 102), sb_Ctl,ppar2^, True);
end;

procedure TOptionDialog.WMHScroll(var Message: TMessage);
const
  PageStep = 0;
var
  Pos: Integer;
  Scroll: HWnd;
begin
  Scroll := HiWord(Message.lParam);
  Pos := GetScrollPos(Scroll, SB_Ctl);
  case Message.wParam of
    sb_LineUp: Dec(Pos);
    sb_LineDown: Inc(Pos);
    sb_PageUp: Dec(Pos, PageStep);
    sb_PageDown: Inc(Pos, PageStep);
    sb_ThumbPosition: Pos := LoWord(Message.lParam);
    sb_ThumbTrack: Pos := LoWord(Message.lParam);
  end;
  SetScrollPos(Scroll, sb_Ctl, Pos, True);
end;

procedure TOptionDialog.OK(var Message: TMessage);
begin
  ppar1^:=GetScrollPos(GetDlgItem(HWindow, 101), sb_Ctl);
  ppar2^:=GetScrollPos(GetDlgItem(HWindow, 102), sb_Ctl);
  EndDlg(id_Ok);
end;

{*************** TPlayersDialog ***************}

type
     PPlayersDialog=^TPlayersDialog;
     TPlayersDialog=object(TDialog)
       player1,player2:pplayer;
       ignore:boolean;
       constructor Init(AParent:PWindowsObject; AName: PChar; var par1,par2:tplayer);
       procedure OK(var Message: TMessage); virtual id_First + id_Ok;
       procedure Clicked1(var message:tmessage); virtual id_first+1001;
       procedure Clicked2(var message:tmessage); virtual id_first+1002;
       procedure Clicked3(var message:tmessage); virtual id_first+1003;
       procedure Clicked4(var message:tmessage); virtual id_first+1004;
       procedure Clicked5(var message:tmessage); virtual id_first+1006;
       procedure Clicked6(var message:tmessage); virtual id_first+1007;
       procedure Clicked7(var message:tmessage); virtual id_first+1008;
       procedure Clicked8(var message:tmessage); virtual id_first+1009;
       procedure SetUpWindow; virtual;
       procedure show(id:integer;vis:boolean);
     end;

constructor tplayersdialog.Init;
begin
  inherited init(aparent,aname);
  player1:=@par1;
  player2:=@par2
end;

function cstring(str:string):pchar;
begin str:=str+#0; cstring:=@str[1] end;

procedure TPlayersDialog.SetUpWindow;
  procedure setplayer(id:integer;player:pplayer);
  begin
    with player^ do begin
      if human then begin
      senddlgitemmsg(id,bm_setcheck,1,0);
      senddlgitemmsg(id+4,wm_settext,0,longint(cstring(name)));
      end else senddlgitemmsg(id+byte(name[1]),bm_setcheck,1,0);
      show(id+4,human);
    end;
  end;
begin
  ignore:=true;
  TDialog.SetUpWindow;
  setplayer(1001,player1);
  setplayer(1006,player2);
end;

procedure countlenght(var s:string);
begin s[0]:=#0; while s[byte(s[0])+1]<>#0 do inc(s[0]) end;

procedure TPlayersDialog.OK(var Message: TMessage);
  procedure getplayer(id:integer;player:pplayer);
  var i:integer;
  begin
    with player^ do begin
      human:=senddlgitemmsg(id,bm_getcheck,0,0)=1;
      if human then begin
      senddlgitemmsg(id+4,wm_gettext,high(name),longint(@name[1]));
      countlenght(name);
      end else for i:=1 to 3 do
      if senddlgitemmsg(id+i,bm_getcheck,0,0)=1 then begin
        name[1]:=chr(i); break end;
    end;
  end;
begin
  getplayer(1001,player1);
  getplayer(1006,player2);
  EndDlg(id_Ok);
end;

procedure tplayersdialog.show(id:integer;vis:boolean);
var com:integer;
begin
  if vis then com:=sw_show else com:=sw_hide;
  showwindow(getitemhandle(id),com);
end;

procedure tplayersdialog.Clicked1(var message:tmessage);
begin with message do
  if (lparamhi=bn_clicked) and not ignore then show(1005,true);
  ignore:=false;
end;

procedure tplayersdialog.Clicked2(var message:tmessage);
begin if message.lparamhi=bn_clicked then show(1005,false) end;

procedure tplayersdialog.Clicked3(var message:tmessage);
begin if message.lparamhi=bn_clicked then show(1005,false) end;

procedure tplayersdialog.Clicked4(var message:tmessage);
begin if message.lparamhi=bn_clicked then show(1005,false) end;

procedure tplayersdialog.Clicked5(var message:tmessage);
begin if message.lparamhi=bn_clicked then show(1010,true) end;

procedure tplayersdialog.Clicked6(var message:tmessage);
begin if message.lparamhi=bn_clicked then show(1010,false) end;

procedure tplayersdialog.Clicked7(var message:tmessage);
begin if message.lparamhi=bn_clicked then show(1010,false) end;

procedure tplayersdialog.Clicked8(var message:tmessage);
begin if message.lparamhi=bn_clicked then show(1010,false) end;

{***************** TAtomixWin *********************}

type
     PAtomixWin=^TAtomixWin;
     TAtomixWin=object(twindow)
       Atoms:TAtomixGame;
       crs_player1,crs_player2,crs_arrow,crs_wait,crs_no:hcursor;
       surx,sury:array [0..maxsize] of integer;
       brush1,brush2:hpen;
       playing,quiting:boolean;
       constructor Init;
       destructor Done; virtual;
       procedure paint(dc:hdc;var paintinfo:tpaintstruct); virtual;
       function GetClassName:pchar; virtual;
       procedure GetWindowClass(var WndClass:twndclass); virtual;
       function canclose:boolean; virtual;
       function GetPosition(var crs:tpoint):boolean;
       procedure kreslipolicko(dc:hdc;x,y:integer);
       procedure zmazpolicko(dc:hdc;x,y:integer);
       procedure explode(dc:hdc;x,y:integer);
       procedure push(x,y:integer);
       procedure ComputeSur;
       function StopGame:boolean;
       procedure wmgetminmaxinfo(var msg:tmessage); virtual wm_first+wm_getminmaxinfo;
       procedure WMSetCursor(var msg:tmessage); virtual wm_first+wm_setcursor;
       procedure WMLButtonDown(var msg:tmessage); virtual wm_first+wm_lbuttondown;
       procedure WMSize(var msg:tmessage); virtual wm_first+wm_size;
       procedure CMNewGame(var Msg: TMessage); virtual cm_First + cm_Menu+1;
       procedure CMPlayers(var Msg: TMessage); virtual cm_First + cm_Menu+2;
       procedure CMSize(var Msg: TMessage); virtual cm_First + cm_Menu+3;
       procedure CMQuit(var Msg: TMessage); virtual cm_First + cm_Menu+4;
       procedure CMHelp(var Msg: TMessage); virtual cm_First + cm_Menu+10+1;
       procedure CMAbout(var Msg: TMessage); virtual cm_First + cm_Menu+10+2;
     end;

type
     TAtomixApp=object(tapplication)
       procedure InitMainWindow; virtual;
       procedure InitApplication; virtual;
     end;

procedure TAtomixApp.InitMainWindow;
begin mainwindow:=new(patomixwin,init) end;

procedure tatomixapp.InitApplication;
begin isfirst:=true end;

constructor TAtomixWin.Init;
begin
  if not isfirst then begin
    messagebox(0, 'Tento program sa súèasne nemôže spúša viackrát.',Caption,mb_ok);
    halt($ff)
  end;
  inherited init(nil,Caption);
  attr.style:=ws_popup or ws_border or ws_caption
    or ws_sysmenu or ws_minimizebox or ws_maximizebox or ws_thickframe;
  attr.x:=100;
  attr.y:=100;
  attr.w:=300;
  attr.h:=300;
  Attr.Menu := LoadMenu(HInstance, PChar('MYMENU'));
  atoms.init(hwindow,startsize,startsize);
  brush1:=createsolidbrush(rgb(0,0,255));
  brush2:=createsolidbrush(rgb(255,0,0));
  playing:=false;
  randomize;
end;

destructor TAtomixWin.Done;
begin
  inherited done;
  deleteobject(brush1); deleteobject(brush2);
  atoms.done;
end;

function tatomixwin.GetClassName:pchar;
begin getclassname:='Atomix window' end;

function tatomixwin.canclose:boolean;
begin
  if playing then
    if inherited canclose then
      if stopgame then begin
	quiting:=true;
	canclose:=false;
      end else canclose:=false
    else canclose:=false
  else canclose:=inherited canclose
end;

procedure tatomixwin.GetWindowClass;
begin
  inherited getwindowclass(wndclass);
  wndclass.hicon:=loadicon(hinstance,'Ikonka');
  crs_player1:=loadcursor(hinstance,'CRS_BLUE');
  crs_player2:=loadcursor(hinstance,'CRS_RED');
  crs_no:=loadcursor(hinstance,'CRS_NO');
  crs_arrow:=loadcursor(0,idc_arrow);
  crs_wait:=loadcursor(0,idc_wait);
end;

procedure tatomixwin.kreslipolicko(dc:hdc;x,y:integer);
var x1,y1,x15,y15,x2,y2,poc:integer;
begin
  x1:=surx[x-1]+1; y1:=sury[y-1]+1; x2:=surx[x]; y2:=sury[y];
  x15:=(x1+x2) shr 1; y15:=(y1+y2) shr 1;
  poc:=atoms.board[x,y] and nrmask;
  if atoms.board[x,y]>=playermask then selectobject(dc,brush2)
                                  else selectobject(dc,brush1);
  inc(x1,medzera); inc(y1,medzera); dec(x2,medzera); dec(y2,medzera);
  if poc in [2,3,4,5,6] then ellipse(dc,x1,y1,x15-medzera,y15-medzera);
  if poc in [3,4,5,6] then ellipse(dc,x15+medzera,y1,x2,y15-medzera);
  if poc in [3,4,5,6] then ellipse(dc,x1,y15+medzera,x15-medzera,y2);
  if poc in [2,4,5,6] then ellipse(dc,x15+medzera,y15+medzera,x2,y2);
  if poc in [1,5,6] then ellipse(dc,(x1+x15) shr 1+medzera,(y1+y15) shr 1+medzera,
	     (x2+x15) shr 1-medzera,(y2+y15) shr 1-medzera);
end;

procedure tatomixwin.zmazpolicko(dc:hdc;x,y:integer);
var r:trect;
begin
  setrect(r,surx[x-1]+1,sury[y-1]+1,surx[x],sury[y]);
  fillrect(dc,r,getstockobject(white_brush));
end;

procedure TatomixWin.explode(dc:hdc;x,y:integer);
var list:array [boolean] of array [1..maxsize*maxsize] of byte;
    length:array[boolean] of integer;
    pos:integer;
    which,player:boolean;  {which..akt, not which..new}
    p:integer;

  procedure prekresli(x,y:integer);
  begin zmazpolicko(dc,x,y); kreslipolicko(dc,x,y) end;

  procedure policko(x,y:integer);
  type byteset=set of 0..7;
  var p:^byte;
  begin
    p:=@atoms.board[x,y];
    if (p^>=playermask)<>player then
    begin
      if player then p^:=p^ or playermask
		else p^:=p^ and not playermask;
      inc(atoms.players[player].score,p^ and nrmask);
      dec(atoms.players[not player].score,p^ and nrmask);
    end;
    inc(p^);
    settestbit(p^,x,y);
    prekresli(x,y);
    inc(length[not which]);
    list[not which,length[not which]]:=y shl 4 or x;
  end;
begin
  length[false]:=1; list[false,1]:=y shl 4 or x;
  which:=true; player:=atoms.board[x,y]>playermask;
  while (length[not which]>=1) and (atoms.players[not player].score>0) do begin
    pos:=1;            {nastavim sa na zaciatok}
    length[which]:=0;  {nulujem stary zoznam}
    which:=not which;  {prepnem zoznamy}
    while pos<=length[which] do begin {pre vsetky v akt. zozname..}
      x:=list[which,pos] and $f;
      y:=list[which,pos] shr 4;
      with atoms do begin
	p:=nearx[x]+neary[y];
	if board[x,y] and nrmask>=p then begin
	  dec(board[x,y],p);
          prekresli(x,y);
	  if y>1 then policko(x,y-1);
	  if x>1 then policko(x-1,y);
	  if x<sizex then policko(x+1,y);
	  if y<sizey then policko(x,y+1);
	end;
      end;
      inc(pos);
    end;
  end;
  if (atoms.players[player].score>1) and (atoms.players[not player].score=0)
    then sendmessage(hwindow,273,101,0);
end; {explode}


procedure TAtomixWin.paint;
var i,j:integer;

begin
  with atoms do begin
    for i:=0 to sizex do
    begin
      moveto(dc,surx[i],sury[0]); lineto(dc,surx[i],sury[sizey]);
    end; {for}
    for i:=0 to sizey do
    begin
      moveto(dc,surx[0],sury[i]); lineto(dc,surx[sizex],sury[i]);
    end; {for}
    for i:=1 to sizex do
      for j:=1 to sizey do kreslipolicko(dc,i,j);
  end {with}
end; {paint}

procedure tatomixwin.wmgetminmaxinfo;
begin
  with tminmaxinfo(pointer(msg.lparam)^).ptmintracksize do
  begin
    x:=atoms.sizex*minunit+2*border;
    y:=atoms.sizey*minunit+2*border+menuheight;
  end
end;

function getscopeindex(x,size,poc:integer):integer;
begin getscopeindex:=max(1,muldiv(x+size div (poc shl 1),poc,size)) end;

function tatomixwin.getposition(var crs:tpoint):boolean;
var rect:trect;
begin
  getclientrect(hwindow,rect);
  with rect do begin inc(left,border); inc(top,border);
                 dec(right,border); dec(bottom,border); end;
  with rect do
    if iir(crs.x,left,right) and iir(crs.y,top,bottom) then
      with atoms do begin
      crs.x:=getscopeindex(crs.x-border,right-left,sizex);
      crs.y:=getscopeindex(crs.y-border,bottom-top,sizey);
      getposition:=true
      end
    else getposition:=false
end;

procedure tatomixwin.WMSetCursor(var msg:tmessage);
var crs:tpoint;
begin
  with msg do
  if lparamlo<>htclient
  then defwindowproc(hwindow,wm_first+wm_setcursor,wparam,lparam)
  else begin
    getcursorpos(crs); screentoclient(hwindow,crs);
    if getposition(crs) and playing then
      with crs,atoms do
      if ((board[x,y] and nrmask)=0) or ((board[x,y]>=playermask)=onmove)
       then if onmove then setcursor(crs_player2)
                      else setcursor(crs_player1)
       else setcursor(crs_no)
    else setcursor(crs_arrow)
  end; {else}
  msg.result:=1;
end; {proc}

procedure tatomixwin.push(x,y:integer);
var p:^byte;
    dc:thandle;
begin
  dc:=getdc(hwindow);
  with atoms do begin
    p:=@board[x,y];
    inc(p^); inc(players[onmove].score);
    setbit(p^,7,onmove);
    settestbit(p^,x,y);
    zmazpolicko(dc,x,y);
    kreslipolicko(dc,x,y);
    onmove:=not onmove;
  end;
  explode(dc,x,y);
  releasedc(hwindow,dc);
end;

procedure tatomixwin.WMLButtonDown(var msg:tmessage);
var crs:tpoint;
    p:^byte;
    move:tatomixmove;
begin
  crs.x:=msg.lparamlo; crs.y:=msg.lparamhi;
  if not playing then
    if messagebox(hwindow,'Chcete novu hru ?','',mb_okcancel)=1 then
    begin
      postmessage(hwindow,273,101,0);
    end else
  else if getposition(crs) then
    with crs do
    with atoms do
    if players[onmove].human then begin
      p:=@board[x,y];
      if ((p^ and nrmask)=0) or ((p^>=playermask)=onmove) then self.push(x,y);
    end;
  msg.result:=0;
end;

procedure tatomixwin.computesur;
var i:integer;
    r:trect;
begin
  getclientrect(hwindow,r);
  with r do begin inc(left,border); inc(top,border);
              dec(right,border); dec(bottom,border); end;
  with atoms do begin
    for i:=0 to sizex do
      surx[i]:=muldiv(r.left,sizex-i,sizex)+muldiv(r.right,i,sizex);
    for i:=0 to sizey do
      sury[i]:=muldiv(r.top,sizey-i,sizey)+muldiv(r.bottom,i,sizey);
  end;
end;

procedure tatomixwin.WMSize(var msg:tmessage);
begin
  inherited wmsize(msg);
  computesur;
end;

procedure tatomixwin.CMNewGame(var Msg: TMessage);
var mymsg:tmsg;
    oldcrs:hcursor;
    move:tatomixmove;
begin
  if playing then begin
    ModifyMenu(GetMenu(HWindow), 101, mf_ByCommand,101, '&Nová hra');
    playing:=false;
    exit;
  end;
  ModifyMenu(GetMenu(HWindow), 101, mf_ByCommand,101, '&Stop');
  atoms.cleardesk;
  redrawwindow(hwindow,nil,0,rdw_erase or rdw_invalidate);
  playing:=true;
  quiting:=false;
  repeat
    with atoms do
    if not players[onmove].human then begin
      oldcrs:=setcursor(crs_wait);
      atoms.newmove(@move,4-ord(atoms.players[onmove].name[1]));
      with move do self.push(x,y);
      setcursor(oldcrs);
    end;
    while playing and PeekMessage(myMsg,hwindow, 0, 0, pm_remove) do
    begin
      TranslateMessage(mymsg);
      DispatchMessage(mymsg);
    end;
  until not playing;
  if quiting then postquitmessage(0);
end;

procedure tatomixwin.CMPlayers(var Msg: TMessage);
begin
  Application^.ExecDialog(New(PPlayersDialog, Init(@Self, 'HRACI',atoms.players[false],atoms.players[true])));
end;

function tatomixwin.StopGame:boolean;
begin
  if not playing then stopgame:=true
  else begin
    if messagebox(hwindow,'Chcete skoncit tuto hru ?','',mb_okcancel)=1 then sendmessage(hwindow,273,101,0);
    stopgame:=not playing
  end;
end;

procedure tatomixwin.CMSize(var Msg: TMessage);
begin
  if StopGame and
    (Application^.ExecDialog(New(POptionDialog, Init(@Self, 'VELKOST',atoms.sizex,atoms.sizey)))=1) then begin
    with atoms do setsize(sizex,sizey);
    computesur;
    redrawwindow(hwindow,nil,0,rdw_erase or rdw_invalidate);
    if not iszoomed(hwindow) then movewindow(hwindow,attr.x,attr.y,attr.w,attr.h,true);
  end;
end;

procedure tatomixwin.CMQuit(var Msg: TMessage);
begin if playing then if stopgame then quiting:=true else else postquitmessage(0) end;

procedure tatomixwin.CMHelp(var Msg: TMessage);
begin
  Application^.ExecDialog(New(PDialog, Init(@Self, 'PRAVIDLA')));
end;

procedure tatomixwin.CMAbout(var Msg: TMessage);
begin
  Application^.ExecDialog(New(PDialog, Init(@Self, 'ABOUT')));
end;

var atomixapp:tatomixapp;

begin
  atomixapp.init('Atomix');
  atomixapp.run;
  atomixapp.done
end.