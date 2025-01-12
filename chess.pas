	def type TArray8x8 as array[1 .. 8] of array[1 .. 8] of integer;
	def type TPoint2D as record
	       x as integer;
	       y as integer;
	     end;
	def type TPiece as record
	                     figtype as integer;
	                     note as integer;
	                     pos as TPoint2D;
	                     attacked_cells as integer;   {kolko policok ohrozuje}
	                     attacked_weight as float;  {sila nepriatelskych figur, ktore ohrozuje}
	                   end;

	def type Position as record
	                       onmove as integer;
	                       movenr as integer;
	                       gama as float;
	                       name as string;
	                       board as TArray8x8;
	                       attacked as TArray8x8;
	                       pieces as array[-16 .. 16] of TPiece;
	                     end;

	def gp as Position;
	def piece_name as array[1 .. 6] of string;
	def color_name as array[-1 .. 1] of string;
	def piece_weight as array[1 .. 6] of float;
	def pieces_weight as float;
	def pawn_weight as float;
	def attack_weight as float;
	def border as array[-1 .. 1] of integer;
	def movescount as array[2 .. 6] of integer;
	def moverel as array[2 .. 6] of array [1 .. 8] of TPoint2D;
	def fig2bit as array[-16 .. 16] of integer;
	def color2bit as array[-1 .. 1] of integer;
	def Part as integer;
	def FirstPart as string;
	def drawMoves as bool;

  {"constants" for figure type}
  def pawn as integer;
  def bishop as integer;
  def knight as integer;
  def rook as integer;
  def queen as integer;
  def king as integer;

	def proc InitVars;

	  def i as integer;
	  def bit2 as array [0 .. 31] of integer;

    {compute values representing single bits from 0 to 31}
	  bit2[0]:=1;
	  for i:=0 to 29 do
	    bit2[i+1]:=bit2[i]+bit2[i];
	  end for;
	  bit2[31]:=(0-bit2[30])-bit2[30];

	  for i:=1 to 16 do
	    fig2bit[i]:=bit2[i-1];
	    fig2bit[-i]:=bit2[i+15];
	    color2bit[1]:=color2bit[1] or fig2bit[i];
	    color2bit[-1]:=color2bit[-1] or fig2bit[-i];
	  end for;

    {this sorting is needed for optimization .. for tests if fig is bishop or rook or queen}
    pawn:=1;
    knight:=2;
    king:=3;
    bishop:=4;
    rook:=5;
    queen:=6;

 	  piece_weight[pawn  ]:=1;
	  piece_weight[bishop]:=2.8;
	  piece_weight[knight]:=3;
	  piece_weight[rook  ]:=5;
	  piece_weight[queen ]:=10;
	  piece_weight[king  ]:=20;
	  pieces_weight:=8;
	  pawn_weight:=1;
	  attack_weight:=1.4;

	  piece_name[pawn  ]:="p";
	  piece_name[bishop]:="s";
	  piece_name[knight]:="j";
	  piece_name[rook  ]:="v";
	  piece_name[queen ]:="d";
	  piece_name[king  ]:="k";

	  color_name[-1]:="c";
	  color_name[ 1]:="b";
	  border[ 1]:=1;
	  border[-1]:=8;

	  movescount[bishop]:=4; {Bishop moves - 4 directions diagonally}
	  movescount[knight]:=8; {Knight moves - 8 "L" moves}
	  movescount[rook  ]:=4; {Rook moves   - 4 directions}
	  movescount[queen ]:=8; {Queen moves  - 8 directions}
	  movescount[king  ]:=8; {King moves   - 8 moves}


    i:=bishop;
	  moverel[i][1].x:= -1; moverel[i][1].y:= -1;
	  moverel[i][2].x:= 1;  moverel[i][2].y:= -1;
	  moverel[i][3].x:= -1; moverel[i][3].y:= 1;
	  moverel[i][4].x:= 1;  moverel[i][4].y:= 1;

    i:=knight;
	  moverel[i][1].x:= -1; moverel[i][1].y:= -2;
	  moverel[i][2].x:=1;   moverel[i][2].y:= -2;
	  moverel[i][3].x:= -2; moverel[i][3].y:= -1;
	  moverel[i][4].x:=2;   moverel[i][4].y:= -1;
	  moverel[i][5].x:= -2; moverel[i][5].y:=1;
	  moverel[i][6].x:=2;   moverel[i][6].y:=1;
	  moverel[i][7].x:= -1; moverel[i][7].y:=2;
	  moverel[i][8].x:=1;   moverel[i][8].y:=2;

    i:=rook;
	  moverel[i][1].x:= 0;  moverel[i][1].y:= -1;
	  moverel[i][2].x:= -1; moverel[i][2].y:= 0;
	  moverel[i][3].x:= 1;  moverel[i][3].y:= 0;
	  moverel[i][4].x:= 0;  moverel[i][4].y:= 1;

    i:=queen;
	  moverel[i][1].x:= -1; moverel[i][1].y:= -1;
	  moverel[i][2].x:=0;   moverel[i][2].y:= -1;
	  moverel[i][3].x:=1;   moverel[i][3].y:= -1;
	  moverel[i][4].x:= -1; moverel[i][4].y:=0;
	  moverel[i][5].x:=1;   moverel[i][5].y:=0;
	  moverel[i][6].x:= -1; moverel[i][6].y:=1;
	  moverel[i][7].x:=0;   moverel[i][7].y:=1;
	  moverel[i][8].x:=1;   moverel[i][8].y:=1;

    i:=king;
	  moverel[i][1].x:= -1; moverel[i][1].y:= -1;
	  moverel[i][2].x:=0;   moverel[i][2].y:= -1;
	  moverel[i][3].x:=1;   moverel[i][3].y:= -1;
	  moverel[i][4].x:= -1; moverel[i][4].y:=0;
	  moverel[i][5].x:=1;   moverel[i][5].y:=0;
	  moverel[i][6].x:= -1; moverel[i][6].y:=1;
	  moverel[i][7].x:=0;   moverel[i][7].y:=1;
	  moverel[i][8].x:=1;   moverel[i][8].y:=1;

	end proc;

	{oznaci ktore policka su ohrozovane danou figurkou a spocita kolko ich je}
	{tiez spocita "silu" ohrozovanych nepriatelskych figur}
	def proc OznacPolickaFigurky(f as integer);
	  def pce as TPiece;
	  def xn as integer;
	  def yn as integer;
	  def i as integer;
	  def pocet as integer;
	  def sila as float;
	  def f2 as integer;
	  pce:=gp.pieces[f];
	  if (pce.figtype=pawn) then do
	    {tahy pesiakom   (nevie tahy en-pasant !!!)}
	    yn:=pce.pos.y-sgn(f);
	    if (yn>=1) and (yn<=8) then do
	      xn:=pce.pos.x-1;
	      if (xn>=1) then do
		gp.attacked[yn][xn]:=gp.attacked[yn][xn] or fig2bit[f]; pocet:=pocet+1;
		f2:=gp.board[yn][xn];
		if sgn(f2)=0-sgn(f) then sila:=sila+piece_weight[gp.pieces[f2].figtype];
	      end;
	      xn:=pce.pos.x+1;
	      if (xn<=8) then do
		gp.attacked[yn][xn]:=gp.attacked[yn][xn] or fig2bit[f]; pocet:=pocet+1;
		f2:=gp.board[yn][xn];
		if sgn(f2)=0-sgn(f) then sila:=sila+piece_weight[gp.pieces[f2].figtype];
	      end;
	    end;
	  end else if (pce.figtype=knight) or (pce.figtype=king) then do
	    {tahy jazdcom a kralom su urcene vyctom relativnych pozicii}
	    for i:=1 to movescount[pce.figtype] do
	      xn:=pce.pos.x+moverel[pce.figtype][i].x;
	      yn:=pce.pos.y+moverel[pce.figtype][i].y;
	      if (xn>=1) and (xn<=8) and (yn>=1) and (yn<=8) then do
		gp.attacked[yn][xn]:=gp.attacked[yn][xn] or fig2bit[f]; pocet:=pocet+1;
		f2:=gp.board[yn][xn];
		if sgn(f2)=0-sgn(f) then sila:=sila+piece_weight[gp.pieces[f2].figtype];
	      end;
	    end for;
	  end else if (pce.figtype=bishop) or (pce.figtype=rook) or (pce.figtype=queen) then do
	    {tahy strelca,veze a damy su urcene vyctom smerov}
	    for i:=1 to movescount[pce.figtype] do
	      xn:=pce.pos.x+moverel[pce.figtype][i].x;
	      yn:=pce.pos.y+moverel[pce.figtype][i].y;
	      while (xn>=1) and (xn<=8) and (yn>=1) and (yn<=8) do
	        gp.attacked[yn][xn]:=gp.attacked[yn][xn] or fig2bit[f]; pocet:=pocet+1;
		f2:=gp.board[yn][xn];
		if sgn(f2)=0-sgn(f) then sila:=sila+piece_weight[gp.pieces[f2].figtype];
	        if f2<>0 then xn:=100;
	        xn:=xn+moverel[pce.figtype][i].x;
	        yn:=yn+moverel[pce.figtype][i].y;
	      end;
	    end;
	  end;
	  gp.pieces[f].attacked_cells:=pocet;
	  gp.pieces[f].attacked_weight:=sila;
	end proc;

	def proc GenerStartPositions;
	  def p as Position;
	  def i as integer;
	  InitVars;

	  {initial chess position setup}

	  p.pieces[9].figtype:=rook;
	  p.pieces[10].figtype:=knight;
	  p.pieces[11].figtype:=bishop;
	  p.pieces[12].figtype:=queen;
	  p.pieces[13].figtype:=king;
	  p.pieces[14].figtype:=bishop;
	  p.pieces[15].figtype:=knight;
	  p.pieces[16].figtype:=rook;

	  for i:=1 to 8 do
	    p.pieces[i].figtype:=pawn;
	    p.pieces[0-i].figtype:=pawn;
	    p.pieces[0-8-i].figtype:=p.pieces[8+i].figtype;

	    p.board[1][i]:=0-8-i; p.pieces[-8-i].pos.x:=i; p.pieces[-8-i].pos.y:=1;
	    p.board[2][i]:=0-i;   p.pieces[0-i].pos.x:=i;  p.pieces[0-i].pos.y:=2;
	    p.board[7][i]:=i;     p.pieces[i].pos.x:=i;    p.pieces[i].pos.y:=7;
	    p.board[8][i]:=8+i;   p.pieces[8+i].pos.x:=i;  p.pieces[8+i].pos.y:=8;
	  end for;
	  p.onmove:=1;
	  gp:=p;
	  for i:=1 to 16 do
	    OznacPolickaFigurky(i);
	    OznacPolickaFigurky(-i);
	  end;
	  p:=gp;
	  NewMove(p,"Start",0);
	end proc;

	{pre zadanu figurku predlzim ohrozovane policka danym smerom}
	def proc Predlz(f as integer;col as integer;line as integer);
	  def xd as integer;
	  def yd as integer;
	  def xn as integer;
	  def yn as integer;
	  def pocet as integer;
	  xn:=gp.pieces[f].pos.x;
	  yn:=gp.pieces[f].pos.y;
	  xd:=sgn(col-xn);
	  yd:=sgn(line-yn);
	  xn:=col+xd;
	  yn:=line+yd;
	  pocet:=0;
	  while (xn>=1) and (xn<=8) and (yn>=1) and (yn<=8) do
	    gp.attacked[yn][xn]:=gp.attacked[yn][xn] or fig2bit[f];
	    pocet:=pocet+1;
	    if gp.board[yn][xn]<>0 then xn:=100; {nasty trick - exit the while loop}
	    xn:=xn+xd;
	    yn:=yn+yd;
	  end while;
	  gp.pieces[f].attacked_cells:=gp.pieces[f].attacked_cells+pocet;
	end proc;

	{pre zadanu figurku skratim ohrozovane policka danym smerom}
	def proc Skrat(f as integer;col as integer;line as integer);
	  def xd as integer;
	  def yd as integer;
	  def xn as integer;
	  def yn as integer;
	  def pocet as integer;
	  xn:=gp.pieces[f].pos.x;
	  yn:=gp.pieces[f].pos.y;
	  xd:=sgn(col-xn);
	  yd:=sgn(line-yn);
	  xn:=col+xd;
	  yn:=line+yd;
	  while (xn>=1) and (xn<=8) and (yn>=1) and (yn<=8) do
	    if gp.attacked[yn][xn] and fig2bit[f]=0 then xn:=100
	    else do
	      gp.attacked[yn][xn]:=gp.attacked[yn][xn] and (-1 xor fig2bit[f]);
	      pocet:=pocet+1;
	    end;
	    xn:=xn+xd;
	    yn:=yn+yd;
	  end while;
	  gp.pieces[f].attacked_cells:=gp.pieces[f].attacked_cells-pocet;
	end proc;

	{pre vsetky damy, veze a strelcov, ktore napadalju toto policko, rozsirim ich napadane policka v tom smere}
	def proc Zdvihni(col as integer;line as integer);
	  def i as integer;
	  {zistim, ktorym figurkam budem musiet prepocitat ohrozovane policka - strelci, veze a damy}
	  for i:=-16 to 16 do
	    if (gp.pieces[i].figtype>=bishop) and (gp.attacked[line][col] and fig2bit[i]<>0) then Predlz(i,col,line);
	  end;
	end proc;

	{pre vsetky damy, veze a strelcov, ktore napadaju toto policko, zrusim ich dalsie napadane policka v tom smere}
	def proc Poloz(col as integer;line as integer);
	  def i as integer;
	  {zistim, ktorym figurkam budem musiet prepocitat ohrozovane policka - strelci, veze a damy}
	  for i:=-16 to 16 do
	    ft:=gp.pieces[i].figtype;
	    if (gp.pieces[i].figtype>=bishop) and (gp.attacked[line][col] and fig2bit[i]<>0) then Skrat(i,col,line);
	  end;
	end proc;

	def proc Vymen(pce as TPiece);
	end proc;

	def func Napadana(x as integer;y as integer;s as integer) as integer;
	  def i as integer;
	  Result:=0;
	  i:=1;
	  while i<17 do
	    if gp.attacked[y][x] and fig2bit[i*s]<>0 then do
	      Result:=i*s;
	      i:=100;
	    end else i:=i+1;
	  end while;
	end func;

	def proc Presun(p as position;f as integer;destcol as integer;destline as integer);
	  def pce as TPiece;
	  def oldpce as TPiece;
	  def regen as array [-16 .. 16] of integer;
	  def i as integer;
	  def j as integer;
	  def clr as integer;
	  def curpos as TPoint2D;
	  gp:=p;
	  pce:=gp.pieces[f];
	  curpos:=pce.pos;
	  oldpce:=gp.pieces[gp.board[destline][destcol]];

	  {v kazdom pripade prepocitam presuvanu a vyhadzovanu figurku}
	  regen[f]:=1;
	  regen[gp.board[destline][destcol]]:=1;

	  {zodvihnem presuvanu figurku}
	  gp.board[pce.pos.y][pce.pos.x]:=0;
	  {upravim napadane policka}
	  Zdvihni(pce.pos.x,pce.pos.y);

	  {polozim ju na nove miesto}
	  gp.pieces[gp.board[destline][destcol]].figtype:=0;
	  gp.pieces[gp.board[destline][destcol]].attacked_cells:=0;
	  gp.board[destline][destcol]:=f;
	  gp.pieces[f].pos.x:=destcol;
	  gp.pieces[f].pos.y:=destline;

	  if drawMoves then DrawBitmap("frame2",destcol*40-34,destline*40-35);

	  {ak je to pesiak a dosiel som na posledny riadok, tak z neho urobim kralovnu}
	  if (pce.figtype=pawn) and ((destline=1) or (destline=8)) then do
	    gp.pieces[f].figtype:=queen;
	  end;

	  {upravim napadane policka}
	  if oldpce.figtype=0
	  then Poloz(destcol,destline)
	  else Vymen(oldpce);

	  {vymenim hracov a zvacsim cislo tahu}
	  gp.onmove:=0-gp.onmove;
	  gp.movenr:=gp.movenr+1;

	  {zaznacim poznamku k figurke}
	  if (pce.figtype=rook) or (pce.figtype=king) then gp.pieces[f].note:=1 {ak je to veza alebo kral, ze sa hybal}
	  else if (pce.figtype=pawn) and (abs(pce.pos.y-destline)=2) then gp.pieces[f].note:=gp.movenr; {tah skoku pesiaka}

	{
	  {ak to bola rosada, tak este presuniem vezu}
	  if (pce.type=king) and (abs(pce.pos.column-dest.x)>1) then do
	    if destcol=7 then do
	      gp.board[destline][6]:=16*p.onmove;
	      gp.board[destline][8]:=0;
	      gp.pieces[16*p.onmove].pos.column:=6;
	      regen[16*p.onmove]:=1;
	    end else do
	      gp.board[destline][3]:=9*p.onmove;
	      gp.board[destline][1]:=0;
	      gp.pieces[9*p.onmove].pos.column:=3;
	      regen[9*p.onmove]:=1;
	    end;
	  end;

	  {a este spracujem branie en-pasant}
	  if (pce.type=pawn) and (pce.pos.column<>dest.x) and (p.board[dest.y][dest.x]=0) then do
	    gp.pieces[gp.board[pce.pos.line,dest.column]].type=0;
	    regen[gp.board[pce.pos.line,dest.column]]:=1;
	    gp.board[pce.pos.line,dest.column]:=0;
	    for i:=1 to 16 do
	      if ((gp.pieces[i]=bishop) or (gp.pieces[i]=rook) or (gp.pieces[i]=queen)) and
	                 Ohrozuje(TPoint2D(dest.column,pce.pos.line),i) then regen[i]:=1;
	    end;
	    for i:=-16 to -1 do
	      if ((gp.pieces[i]=bishop) or (gp.pieces[i]=rook) or (gp.pieces[i]=queen)) and
	                 Ohrozuje(TPoint2D(dest.column,pce.pos.line),i) then regen[i]:=1;
	    end;
	  end;
	}

	  {zistim, ktore bity budem mazat}
	  clr:=0;
	  for i:= -16 to 16 do
	    if regen[i]=1 then do
	      clr:=clr or fig2bit[i];
	      gp.pieces[i].attacked_cells:=0;
	    end;
	  end;
	  clr:= -1 xor clr;

	  {odznacim policka, ktore ohrozovali figurky, ktore budem prepocitavat}
	  for i:=1 to 8 do
	    for j:=1 to 8 do
	      gp.attacked[i][j]:=gp.attacked[i][j] and clr;
	    end for;
	  end for;

	  {pregenerujem ohrozovane policka}
	  for i:= -16 to 16 do
	    if (regen[i]=1) and (gp.pieces[i].figtype<>0) then OznacPolickaFigurky(i);
	  end;

	  gp.gama:=0;
	  for i:= -16 to 16 do
	    pce:=gp.pieces[i];
	    if pce.figtype<>0 then do
	      {pripocitam pocet ohrozovanych policok + pieces_weight*typ danej figurky}
	      gp.gama:=gp.gama+(pce.attacked_cells+pieces_weight*piece_weight[pce.figtype])*sgn(i);

	      {pre pesiakov pripocitam pocet krokov*1}
	      if pce.figtype=pawn then gp.gama:=gp.gama+pawn_weight*(7-abs(border[sgn(i)]-pce.pos.y))*sgn(i);

	      {zistim, ci je figurka ohrozovana}
	      if gp.attacked[pce.pos.y][pce.pos.x] and color2bit[0-sgn(i)]<>0 then do

	        {zistim, ci je chranena}
	        if gp.attacked[pce.pos.y][pce.pos.x] and color2bit[sgn(i)]<>0 then do
	          {ano=>zistim, ktorou najmensou figurkou je napadana}
	          j:=Napadana(pce.pos.x,pce.pos.y,0-sgn(i));
	          {odpocitam attack_weight*rozdiel napadnutej a utociacej figurky}
	          gp.gama:=gp.gama-attack_weight*maxf(0,piece_weight[pce.figtype]-piece_weight[gp.pieces[j].figtype])*sgn(i);
	        end else
	          {nie=>odpocitam attack_weight*typ napadnutej figurky}
	          gp.gama:=gp.gama-attack_weight*piece_weight[pce.figtype]*sgn(i);
	      end;


	    end;
	  end for;

	  {pripocitam nahodne cislo, aby to nehralo stale rovnako}
	  gp.gama:=gp.gama+rndf(1)-0.5;

	  p:=gp;

	  {overim, ci je ohrozovany kral hraca, ktory urobil tah}
	  pce:=p.pieces[0-13*p.onmove];
	  {ak je, tak to nieje platna pozicia}
	  if p.attacked[pce.pos.y][pce.pos.x] and color2bit[p.onmove]=0 then do
	    p.name:=piece_name[p.pieces[f].figtype]+" "+SubStr("ABCDEFGH",curpos.x,1)+IntToStr(9-curpos.y)+":"+SubStr("ABCDEFGH",destcol,1)+IntToStr(9-destline);
	    NewMove(p,p.name,p.onmove*p.gama);
	  end;
	end proc;

	def proc TahFigurkou(p as position;f as integer);
	          def pce as TPiece;
	  def xn as integer;
	  def yn as integer;
	  def i as integer;
	  pce:=p.pieces[f];

	{
	  for each o from pce.attacked do
	    {v hrozbach su sikme tahy pesiakov, ale tam mozu ist, len ked vyhodia figurku}
	    if (pce.type<>pawn) or (p.board[o.y][o.x]<>0) then Presun(p,f,o)
	    {este skusim, ci to je branie en-pasant}
	    else if (p.pieces[p.board[pce.pos.line,o.column]].type=1) and
	                    (p.pieces[p.board[pce.pos.line,o.column]].note=p.movenr-1) then Presun(p,f,o);
	  end for;
	}
	  if (pce.figtype=pawn) then do
	    {tahy pesiakom   (nevie tahy en-pasant !!!)}
	    yn:=pce.pos.y-sgn(f);
	    if (yn>=1) and (yn<=8) then do
	      xn:=pce.pos.x-1;
	      if (xn>=1) and (sgn(p.board[yn][xn])=0-p.onmove) then Presun(p,f,xn,yn);
	      xn:=pce.pos.x+1;
	      if (xn<=8) and (sgn(p.board[yn][xn])=0-p.onmove) then Presun(p,f,xn,yn);

	      {skusim krok}
	      xn:=pce.pos.x;
	      if p.board[yn][xn]=0 then do
	        Presun(p,f,xn,yn);

	        {skusim este skok o 2}
	        yn:=yn-sgn(f);
	        if (abs(pce.pos.y-border[p.onmove])=6) and (p.board[yn][xn]=0) then Presun(p,f,xn,yn);
	      end;
	    end;
	  end else if (pce.figtype=knight) or (pce.figtype=king) then do
	    {tahy jazdcom a kralom su urcene vyctom relativnych pozicii}
	    for i:=1 to movescount[pce.figtype] do
	      xn:=pce.pos.x+moverel[pce.figtype][i].x;
	      yn:=pce.pos.y+moverel[pce.figtype][i].y;
	      if (xn>=1) and (xn<=8) and (yn>=1) and (yn<=8) and
	         (sgn(p.board[yn][xn])<>p.onmove) then Presun(p,f,xn,yn);
	    end for;
	  end else if (pce.figtype=bishop) or (pce.figtype=rook) or (pce.figtype=queen) then do
	    {tahy strelca,veze a damy su urcene vyctom smerov}
	    for i:=1 to movescount[pce.figtype] do
	      xn:=pce.pos.x+moverel[pce.figtype][i].x;
	      yn:=pce.pos.y+moverel[pce.figtype][i].y;
	      while (xn>=1) and (xn<=8) and (yn>=1) and (yn<=8) and
	            (sgn(p.board[yn][xn])<>p.onmove) do
	        Presun(p,f,xn,yn);
	        if sgn(p.board[yn][xn])<>0 then xn:=100;
	        xn:=xn+moverel[pce.figtype][i].x;
	        yn:=yn+moverel[pce.figtype][i].y;
	      end;
	    end;
	  end;
	{
	  {a este rosady...}
	  if (pce.type=king) and (pce.note=0) then do
	    {skusim malu rosadu (doprava)}
	    if not JeOhrozene(TPoint2D(pce.line,5)) and
	       (p.board[pce.line][6]=0) and not JeOhrozene(TPoint2D(6,pce.line)) and
	       (p.board[pce.line][7]=0) and not JeOhrozene(TPoint2D(7,pce.line)) and
	       (pieces[p.onmove*16].type=4) and not JeOhrozene(TPoint2D(8,pce.line)) and
	       (pieces[p.onmove*16].note=0)
	            then Presun(p,f,TPoint2D(7,pce.line));

	    {a este velku rosadu (dolava)}
	    if not JeOhrozene(TPoint2D(pce.line,5)) and
	       (p.board[pce.line][4]=0) and not JeOhrozene(TPoint2D(4,pce.line)) and
	       (p.board[pce.line][3]=0) and not JeOhrozene(TPoint2D(3,pce.line)) and
	       (p.board[pce.line][2]=0) and not JeOhrozene(TPoint2D(2,pce.line)) and
	       (pieces[p.onmove*9].type=4) and not JeOhrozene(TPoint2D(1,pce.line)) and
	       (pieces[p.onmove*9].note=0)
	            then Presun(p,f,TPoint2D(2,pce.line));
	  end;
	}
	end proc;

	def proc GenerPositions(p as position);
	  def i as integer;
	  for i:=1 to 16 do
	    if p.pieces[p.onmove*i].figtype<>0 then TahFigurkou(p,p.onmove*i);
	  end for;
	end proc;

	def proc DisplayPosition(p as Position);
	  def l as integer;
	  def c as integer;
	  def f as integer;
	  def s as string;
	  gp:=p;
	  DrawBitmap("chessbrd",0,0);
	  for l:=1 to 8 do
	    for c:=1 to 8 do
	      if p.board[l][c] <> 0 then do
	        DrawBitmap(color_name[sgn(p.board[l][c])]+piece_name[p.pieces[p.board[l][c]].figtype],c*40-34,l*40-35);
	        {DrawText(IntToStr(p.pieces[p.board[l][c]].attacked_cells),c*40-34,l*40-8);}
	      end;

	      {
	      s:="";
	        for f:=1 to 16 do
	        if 0<>(p.attacked[l][c] and fig2bit[f]) then s:=s+piece_name[p.pieces[f].figtype];
	      end for;
	      DrawText(s,c*40-32,l*40-20);
	      s:="";
	      for f:=1 to 16 do
	        if 0<>(p.attacked[l][c] and fig2bit[-f]) then s:=s+piece_name[p.pieces[-f].figtype];
	      end for;
	      DrawText(s,c*40-32,l*40-34);

	      if p.attacked[l][c] and color2bit[0-sgn(p.board[l][c])]<>0 then do
	        {zistim ktorou je napadana}
	        f:=Napadana(c,l,0-sgn(p.board[l][c]));
	        DrawText(piece_name[p.pieces[f].figtype],c*40-14,l*40-20);
	      end;
	      }
	    end for;
	  end for;
	end proc;

	def func GetPositionByMouse(p as Position;x as integer;y as integer) as string;
	  def h as integer;
	  def v as integer;
	  h:=round((x-6)/40)+1;
	  v:=round((y-6)/40)+1;
	  if (Part<>2) then do
	    if (sgn(p.board[v][h])=p.onmove) then do
	      Part:=2;
	      FirstPart:=piece_name[p.pieces[p.board[v][h]].figtype]+" "+SubStr("ABCDEFGH",h,1)+IntToStr(9-v);
	      DrawBitmap("frame",h*40-34,v*40-35);
	              drawMoves:=true;
	      TahFigurkou(p,p.board[v][h]);
	              drawMoves:=false;
	    end;
	  end else do
	    Part:=1;
	    Result:=FirstPart+":"+SubStr("ABCDEFGH",h,1)+IntToStr(9-v);
	    DisplayPosition(p);
	  end;
	end func;

	def func Test(i as integer) as integer;
	  Result:=Abs(i*(-i));
	end func;

end.
