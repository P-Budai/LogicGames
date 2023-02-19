unit Extend; {version 3.17}
{Extended procedures and functions for DOS & WINDOWS}
{For compilers from Turbo Pascal 5.0 to Borland Pascal 7.0 for Win}
{by NEURONsoftware 1992                            date:21.03.1995}
{Peter BUDAI,  Razna 13A, KOSICE 040 01,  SLOVAKIA}

interface

{$d+}

Const
      MaxInt=32767;
      MinInt=-32768;
      MaxWord=65535;

Type
      WordRec=record
		Lo,Hi:Byte
	      end;
      PtrRec=record
	       Ofs,Seg:Word
	     end;
      LongRec=record
		Lo,Hi:word
	      end;
      PointType=record
		  X,Y:integer
		end;
      RectType=record
		 X,Y,XS,YS:integer  {xs and ys are size of rectangle}
	       end;
	{this are all far procedures}
      ProcType=procedure;
      ProcWType=procedure(a:word);
      ProcIType=procedure(a:integer);
      ProcBType=procedure(a:byte);
      ProcLType=procedure(a:boolean);   {logical}
      ProcVBType=procedure(var a:byte);
      ProcVLType=procedure(var a:boolean);
      string8=string[8];
      string10=string[10];
      string20=string[20];
      string40=string[40];
      string80=string[80];


procedure Sound(Hz:word);
procedure NoSound;
procedure Delay(Ms:word);
procedure Swap(var A,B:integer);
procedure SetBit(var B:byte;BitNr:byte;Value:boolean);
procedure NormPtr(var P:pointer); {use only in real processor mode}
function TP(p:pointer):pointer; {test any pointer ,if nil-halt proram}
function Sgn(A:integer):integer;
function Minl(A,B:longint):longint;
function Maxl(A,B:longint):longint;
function AddOfs(p:pointer;ofs:word):pointer; inline($59/$58/$5a/$01/$c8);
function Min(A,B:integer):integer; inline($58/$5b/$39/$d8/$7e/$02/$89/$d8);
function Max(A,B:integer):integer; inline($58/$5b/$39/$d8/$7d/$02/$89/$d8);
function LongDiv(x:longint;y:integer):integer; inline($59/$58/$5a/$f7/$f9);
function LongMul(x,y:integer):longint; inline($5a/$58/$f7/$ea);
function MulDiv(LeftOp,MulOp,DivOp:integer):integer; inline($59/$5a/$58/$f7/$ea/$f7/$f9);
function ConvWord(OpHi,Oplo:byte):word; inline($58/$5b/$88/$dc);
procedure FillWord(var Dst;Cnt,Data:word); inline($58/$59/$5f/$07/$fc/$f3/$ab);
procedure MoveWord(var Src,Dst;Cnt:word); {cnt,size=n. of words}
procedure SpecMove(Src,Dst:pointer;Size,DeltaS,DeltaD,Rep:integer);
procedure SpecFill(Data:word;Dst:pointer;Size,Delta,Rep:integer);
function Comp(var d1,d2;len:word):integer;
function Adr(var A):pointer; inline($58/$5a);
procedure SwapHiLo(var w:word);
procedure STI; inline($fb); {enable interrupts}
procedure CLI; inline($fa); {disable interrupts}
procedure TCR; inline($28/$43/$29/$20/$43/$6F/$70/$79/$72/$69/
		      $67/$68/$74/$20/$4E/$45/$55/$52/$4F/$4E/
		      $73/$6F/$66/$74/$77/$61/$72/$65/$20/$31/
		      $39/$39/$34);
procedure TCRC; inline($E4/$54/$55/$25/$F4/$E4/$37/$F6/$66/$47/
		       $77/$16/$27/$56/$02/$13/$93/$93/$43);

function III(x,b,s:integer):boolean; {IsInInterval}
procedure II(var b1,s1:integer; b2,s2:integer); {IntersectIntervals}
    {  <b1;b1+s1-1> := <b1;b1+s1-1> ^ <b2;b2+s2-1>  }
function IIR(x,b,e:integer):boolean; {IsInRange}
function IR(var b1,e1:integer; b2,e2:integer):boolean; {Intersect Ranges}
    { true if not empty }
    {   <b1;e1> := <b1;e1> ^ <b2;e2>   }
function MinMax(low,high,value:integer):integer;

implementation

const delcnt:word=$5c;

procedure ErrorProc;
begin writeln; writeln('ERROR: Tested pointer is NIL !') end;

procedure SwapHiLo(var w:word); assembler;
asm
	les di,w
	mov ax,es:[di]
	xchg ah,al
	mov es:[di],ax
end;

procedure specmove(src,dst:pointer;size,deltas,deltad,rep:integer); assembler;
asm
	mov cx,size
	jcxz @2
	mov cx,rep
	jcxz @2
	mov ax,cx
	mov bx,deltas
	sub bx,size
	sub bx,size
	mov dx,deltad
	sub dx,size
	sub dx,size
	push ds
	les di,dst
	lds si,src
	cld
@1:     mov cx,size
	rep movsw
	add di,dx
	add si,bx
	dec ax
	jnz @1
	pop ds
@2:
end;

procedure specfill(data:word;dst:pointer;size,delta,rep:integer); assembler;
asm
	mov cx,size
	jcxz @2
	mov cx,rep
	jcxz @2
	mov dx,cx
	mov bx,delta
	sub bx,size
	sub bx,size
	les di,dst
	cld
	mov ax,data
@1:     mov cx,size
	rep stosw
	add di,bx
	dec dx
	jnz @1
@2:
end;

procedure Sound(Hz:word); assembler;
asm
	mov bx,hz
	mov dx,$12
	cmp dx,bx
	jnb @2
	in al,$61
	test al,3
	jnz @1
	or al,3
	out $61,al
	mov al,$b6
	out $43,al
@1:     mov ax,$34dd
	div bx
	out $42,al
	mov al,ah
	out $42,al
@2:
end;

procedure NoSound; assembler;
asm
	in al,$61
	and al,$fc
	out $61,al
end;

procedure DelProc; assembler;
asm
@1:	sub ax,1
	sbb dx,0
	jb @2
	cmp bl,es:[di]
	je @1
@2:
end;

procedure scandelay; assembler;
asm
	mov ax,$0040
	mov es,ax
	mov di,6ch
	mov bl,es:[di]
@1:     cmp bl,es:[di]
	jz @1
	mov bl,es:[di]
	mov ax,0ffe4h
	cwd
	call delproc
	not ax
	not dx
	mov cx,37h
	div cx
	mov delcnt,ax
	push ax
	push ax
	call tp
end;

procedure Delay(Ms:word); assembler;
asm
	mov cx,ms
	jcxz @2
	xor di,di
	mov ax,$0040
	mov es,ax
	mov bl,es:[di]
@1:	mov ax,delcnt
	xor dx,dx
	call delproc
	loop @1
@2:
end;

procedure Swap(var A,B:integer); assembler;
asm
	les di,a
	mov ax,es:[di]
	les di,b
	xchg ax,es:[di]
	les di,a
	mov es:[di],ax
end;

procedure SetBit(var B:byte;BitNr:byte;Value:boolean); assembler;
asm
	les di,b
	mov al,1
	mov cl,bitnr
	shl al,cl
	mov cl,value
	or cl,cl
	jz @clear
	or es:[di],al
	jmp @end
@clear:	not al
	and es:[di],al
@end:
end;

procedure NormPtr(var P:pointer); assembler;
asm
	les di,p
	mov ax,es:[di]
	mov cl,4
	shr ax,cl
	add es:[di+2],ax
	mov ax,$f
	and es:[di],ax
end;

function Sgn(A:integer):integer; assembler;
asm
	mov ax,a
	or ax,ax
	jz @1
	js @2
	mov ax,1
	jmp @1
@2:	mov ax,-1
@1:
end;

function Minl(A,B:longint):longint; assembler;
asm
	mov ax,word ptr [a]
	mov dx,word ptr [a+2]
	cmp dx,word ptr [b+2]
	jl @minla
	jg @minlb
	cmp ax,word ptr [b]
	jb @minla
@minlb:	mov ax,word ptr [b]
	mov dx,word ptr [b+2]
@minla:
end;

function Maxl(A,B:longint):longint; assembler;
asm
	mov ax,word ptr [a]
	mov dx,word ptr [a+2]
	cmp dx,word ptr [b+2]
	jg @maxla
	jl @maxlb
	cmp ax,word ptr [b]
	ja @maxla
@maxlb: mov ax,word ptr [b]
	mov dx,word ptr [b+2]
@maxla:
end;

function tp(p:pointer):pointer;
begin
  asm
	mov ax,word ptr p
	mov dx,word ptr p+2
	or ax,dx
	mov ax,word ptr p
	jz @err
{$ifdef WINDOWS}
        mov sp,bp
        pop bp
        dec bp
{$else}
	leave
{$endif}
	retf 4
@err:	mov sp,bp
	pop bp
	call errorproc
        mov ax,204
	jmp dword ptr cs:[@errjmp+4] {3 bajty ma mov ax,204; 1 bajt call}
@errjmp:
  end;
  runerror(204);
  tcr;
  tcrc;
end;

function Comp(var d1,d2;len:word):integer; assembler;
asm
	mov dx,ds
	les di,d1
	lds si,d2
	cld
	mov cx,len
	xor al,al
	jcxz @end
@loop:	lodsb
	inc di
	sub al,es:byte ptr [di-1]
	jnz @end
	dec cx
	jnz @loop
@end:	cbw
	mov ds,dx
end;

procedure MoveWord(var Src,Dst;Cnt:word); assembler;
asm
	push ds
	lds si,src
	les di,dst
	mov cx,cnt
	cld
	rep movsw
	pop ds
end;

function III(x,b,s:integer):boolean; {IsInInterval}
begin iii:=(b<=x) and (x<=b+s-1) end;

procedure II(var b1,s1:integer; b2,s2:integer);
{  <b1;b1+s1-1> := <b1;b1+s1-1> ^ <b2;b2+s2-1>  }
begin
  s1:=min(b1+s1-1,b2+s2-1); b1:=max(b1,b2);
  if s1<b1 then s1:=0 else s1:=s1-b1+1
end;

function IR(var b1,e1:integer; b2,e2:integer):boolean;
begin b1:=max(b1,b2); e1:=min(e1,e2); ir:=b1<=e1 end;

function IIR(x,b,e:integer):boolean;
begin iir:=(b<=x) and (x<=e) end;

function MinMax(low,high,value:integer):integer;
begin
  MinMax:=Min(high,Max(value,low));
end;

begin
  Scandelay;
end.
