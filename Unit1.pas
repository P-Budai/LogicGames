//pokus o zjednodusenie sachov
//zdaleka nedokoncene, 28.9.2022


  def type TArray8x8 as array[1 .. 8] of array[1 .. 8] of integer;
	def type TPoint2D as record
	       x as integer;
	       y as integer;
	     end;
	def type TPiece as record
	                     figtype as integer;
	                     note as integer;
	                     pos as TPoint2D;
	                     attacked_cells as integer;   {kolko policok ohrozuje, pre pesiakov su tam aj kroky dopredu}
                       attacked_weight as integer;  {váha materiálu, které tato figurka ohrozuje}
	                   end;
	{typ figurky: 1-pesiak
	              2-strelec
	              3-jazdec
	              4-veza
	              5-dama
	              6-kral
	}
	def type Position as record
	                       onmove as integer;
	                       movenr as integer;
	                       gama as float;
	                       name as string;
	                       board as TArray8x8;
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

	def proc InitVars;
	  def i as integer;
	  def bit2 as array [0 .. 31] of integer;
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
	  piece_name[1]:="p";
	  piece_name[2]:="s";
	  piece_name[3]:="j";
	  piece_name[4]:="v";
	  piece_name[5]:="d";
	  piece_name[6]:="k";
	  color_name[-1]:="c";
	  color_name[ 1]:="b";
	  border[ 1]:=1;
	  border[-1]:=8;
	  movescount[2]:=4; {Bishop moves - 4 directions diagonally}
	  movescount[3]:=8; {Knight moves - 8 "L" moves}
	  movescount[4]:=4; {Rook moves   - 4 directions}
	  movescount[5]:=8; {Queen moves  - 8 directions}
	  movescount[6]:=8; {King moves   - 8 directions}

	  moverel[2][1].x:= -1; moverel[2][1].y:= -1;
	  moverel[2][2].x:= 1;  moverel[2][2].y:= -1;
	  moverel[2][3].x:= -1; moverel[2][3].y:= 1;
	  moverel[2][4].x:= 1;  moverel[2][4].y:= 1;

	  moverel[3][1].x:= -1; moverel[3][1].y:= -2;
	  moverel[3][2].x:=1;   moverel[3][2].y:= -2;
	  moverel[3][3].x:= -2; moverel[3][3].y:= -1;
	  moverel[3][4].x:=2;   moverel[3][4].y:= -1;
	  moverel[3][5].x:= -2; moverel[3][5].y:=1;
	  moverel[3][6].x:=2;   moverel[3][6].y:=1;
	  moverel[3][7].x:= -1; moverel[3][7].y:=2;
	  moverel[3][8].x:=1;   moverel[3][8].y:=2;

	  moverel[4][1].x:= 0;  moverel[4][1].y:= -1;
	  moverel[4][2].x:= -1; moverel[4][2].y:= 0;
	  moverel[4][3].x:= 1;  moverel[4][3].y:= 0;
	  moverel[4][4].x:= 0;  moverel[4][4].y:= 1;

	  moverel[5][1].x:= -1; moverel[5][1].y:= -1;
	  moverel[5][2].x:=0;   moverel[5][2].y:= -1;
	  moverel[5][3].x:=1;   moverel[5][3].y:= -1;
	  moverel[5][4].x:= -1; moverel[5][4].y:=0;
	  moverel[5][5].x:=1;   moverel[5][5].y:=0;
	  moverel[5][6].x:= -1; moverel[5][6].y:=1;
	  moverel[5][7].x:=0;   moverel[5][7].y:=1;
	  moverel[5][8].x:=1;   moverel[5][8].y:=1;

	  moverel[6][1].x:= -1; moverel[6][1].y:= -1;
	  moverel[6][2].x:=0;   moverel[6][2].y:= -1;
	  moverel[6][3].x:=1;   moverel[6][3].y:= -1;
	  moverel[6][4].x:= -1; moverel[6][4].y:=0;
	  moverel[6][5].x:=1;   moverel[6][5].y:=0;
	  moverel[6][6].x:= -1; moverel[6][6].y:=1;
	  moverel[6][7].x:=0;   moverel[6][7].y:=1;
	  moverel[6][8].x:=1;   moverel[6][8].y:=1;
	  piece_weight[1]:=1;
	  piece_weight[2]:=2.8;
	  piece_weight[3]:=3;
	  piece_weight[4]:=5;
	  piece_weight[5]:=10;
	  piece_weight[6]:=20;
	  pieces_weight:=8;
	  pawn_weight:=1;
	  attack_weight:=1.4;
	end proc;

	def proc GenerStartPositions;
	  def p as Position;
	  def i as integer;
	  InitVars;

	  {initial chess position setup}

	  p.pieces[9].figtype:=4;
	  p.pieces[10].figtype:=3;
	  p.pieces[11].figtype:=2;
	  p.pieces[12].figtype:=5;
	  p.pieces[13].figtype:=6;
	  p.pieces[14].figtype:=2;
	  p.pieces[15].figtype:=3;
	  p.pieces[16].figtype:=4;

	  for i:=1 to 8 do
	    p.pieces[i].figtype:=1;
	    p.pieces[0-i].figtype:=1;
	    p.pieces[0-8-i].figtype:=p.pieces[8+i].figtype;
	    p.board[1][i]:=0-8-i; p.pieces[-8-i].pos.x:=i; p.pieces[-8-i].pos.y:=1;
	    p.board[2][i]:=0-i;   p.pieces[0-i].pos.x:=i;  p.pieces[0-i].pos.y:=2;
	    p.board[7][i]:=i;     p.pieces[i].pos.x:=i;    p.pieces[i].pos.y:=7;
	    p.board[8][i]:=8+i;   p.pieces[8+i].pos.x:=i;  p.pieces[8+i].pos.y:=8;
	  end for;
	  p.onmove:=1;
	  NewMove(p,"Start",0);
	end proc;


	def proc Vymen(pce as TPiece);
	end proc;

  {move a piece, update game state and gamma function and notify new position}
	def proc Presun(p as position;f as integer;destcol as integer;destline as integer);
	  def pce as TPiece;
	  def oldpce as integer;
	  def i as integer;
	  def j as integer;
	  def curcol as integer;
	  def curline as integer;
    def ft as integer;
	  gp:=p;
	  pce:=gp.pieces[f];
	  curcol:=pce.pos.x;
	  curline:=pce.pos.y;
	  oldpce:=gp.board[destline][destcol];

	  {zodvihnem presuvanu figurku}
	  gp.board[pce.pos.y][pce.pos.x]:=0;

    {ak je na novom mieste nejaka figura, tak ju vyhodím}
	  gp.pieces[oldpce].figtype:=0;

	  {polozim presuvanu figurku na nove miesto}
	  gp.board[destline][destcol]:=f;
    {ulozim si jej nove suradnice}
	  gp.pieces[f].pos.x:=destcol;
	  gp.pieces[f].pos.y:=destline;

    {zmena situacie na starom a novom mieste figurky mohla ovlivnit ohodnotenie inych figur}
    {pre rosadu budeme zmenu pozici veze ignorovat}
    {zistim teda pre ktore figurky musim pregenerovat ich ohodnotenie}
    regen[f]:=1;
 	  for i:= -16 to 16 do
      if i<>f or i=0 then {bud je to figurka ktorou taham alebo ziadna} else do
        ft=gp.pieces[i].figtype;
        x:=gp.pieces[i].pos.x;
        y:=gp.pieces[i].pos.y;
        if ft=1 then do {pesiak}
        end else ft=2 then do {strelec}
          regen[i]:=(x+y=curcol+curline) or (x=destcol) or (y=curline) or (y=destline);
        end else ft=3 then do {jazdec}
        end else ft=4 then do {veza}
          regen[i]:=(x=curcol) or (y=curline) or (x=destcol) or (y=destline);
        end else ft=5 then do {dama}
        end else ft=6 then do {kral}


      end;

	  end;



	  {vymenim hracov a zvacsim cislo tahu}
	  gp.onmove:=0-gp.onmove;
	  gp.movenr:=gp.movenr+1;

	  {zaznacim poznamku k figurke}
	  if (pce.figtype=4) or (pce.figtype=6) then gp.pieces[f].note:=1 {ak je to veza alebo kral, ze sa hybal}
	  else if (pce.figtype=1) and (abs(pce.pos.y-destline)=2) then gp.pieces[f].note:=gp.movenr; {tah skoku pesiaka}

	{
	  {ak to bola rosada, tak este presuniem vezu}
	  if (pce.type=6) and (abs(pce.pos.column-dest.x)>1) then do
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
	  if (pce.type=1) and (pce.pos.column<>dest.x) and (p.board[dest.y][dest.x]=0) then do
	    gp.pieces[gp.board[pce.pos.line,dest.column]].type=0;
	    regen[gp.board[pce.pos.line,dest.column]]:=1;
	    gp.board[pce.pos.line,dest.column]:=0;
	    for i:=9 to 16 do
	      if ((gp.pieces[i]=2) or (gp.pieces[i]=4) or (gp.pieces[i]=5)) and
	                 Ohrozuje(TPoint2D(dest.column,pce.pos.line),i) then regen[i]:=1;
	    end;
	    for i:=-16 to -9 do
	      if ((gp.pieces[i]=2) or (gp.pieces[i]=4) or (gp.pieces[i]=5)) and
	                 Ohrozuje(TPoint2D(dest.column,pce.pos.line),i) then regen[i]:=1;
	    end;
	  end;
	}

	  gp.gama:=0;
	  for i:= -16 to 16 do
	    pce:=gp.pieces[i];
	    if pce.figtype<>0 then do
	      {pripocitam pocet ohrozovanych policok + pieces_weight*typ figurky}
	      gp.gama:=gp.gama+(pieces_weight*piece_weight[pce.figtype])*sgn(i);
	      {pre pesiakov pripocitam pocet krokov*1}
	      if pce.figtype=1 then gp.gama:=gp.gama+pawn_weight*(7-abs(border[sgn(i)]-pce.pos.y))*sgn(i);
	    end;
	  end for;

	  {pripocitam nahodne cislo, aby to nehralo stale rovnako}
	  gp.gama:=gp.gama+rndf(1)-0.5;

	  p:=gp;
	  p.name:=piece_name[p.pieces[f].figtype]+" "+SubStr("ABCDEFGH",curcol,1)+IntToStr(9-curline)+":"+SubStr("ABCDEFGH",destcol,1)+IntToStr(9-destline);
	  NewMove(p,p.name,p.onmove*p.gama);
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
	    if (pce.type<>1) or (p.board[o.y][o.x]<>0) then Presun(p,f,o)
	    {este skusim, ci to je branie en-pasant}
	    else if (p.pieces[p.board[pce.pos.line,o.column]].type=1) and
	                    (p.pieces[p.board[pce.pos.line,o.column]].note=p.movenr-1) then Presun(p,f,o);
	  end for;
	}

	  if (pce.figtype=1) then do
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
	  end else if (pce.figtype=3) or (pce.figtype=6) then do
	    {tahy jazdcom a kralom su urcene vyctom relativnych pozicii}
	    for i:=1 to movescount[pce.figtype] do
	      xn:=pce.pos.x+moverel[pce.figtype][i].x;
	      yn:=pce.pos.y+moverel[pce.figtype][i].y;
	      if (xn>=1) and (xn<=8) and (yn>=1) and (yn<=8) and
	         (sgn(p.board[yn][xn])<>p.onmove) then Presun(p,f,xn,yn);
	    end for;
	  end else if (pce.figtype=2) or (pce.figtype=4) or (pce.figtype=5) then do
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
	  if (pce.type=6) and (pce.note=0) then do
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
	  {if (p.movenr=5) and (p.name="p C3") then do
	    i:=i;
	  end;}
	  {len ked mám este krála tak mozem hrat}
	  if p.pieces[13*p.onmove].figtype=6 then do
	    for i:=1 to 16 do
	      if p.pieces[p.onmove*i].figtype<>0 then TahFigurkou(p,p.onmove*i);
	    end for;
	  end;
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
	    end;
	  end else do
	    Part:=1;
	    Result:=FirstPart+":"+SubStr("ABCDEFGH",h,1)+IntToStr(9-v);
	  end;
	end func;


