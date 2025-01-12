unit virtualMachine;

interface

uses gener;

type TLineFlags=record
       Hits:UInt32;     {how many was this line executed since counter reset}
       Flags:UInt32;    {bit0 is 1 when breakpoint is set on the line}
     end;
     PLineFlags=^TLineFlags;

type TPrgMemSpace=record    //do not change thist to object
       {code info}
       CodeAddr:pointer; {pointer to code}
       CodeSize:longint; {size of code}
       InstrPtr:pointer; {pointer to next instruction}

       {data info}
       GlobAddr:pointer; {pointer to global data}
       GlobSize:longint; {size of global data}

       LocalAddr:pointer; {pointer to local data}
       LocalSize:longint; {size of local data}
       LocalTop:pointer; {top of the stack (with 4KB reserve)}

       LocalFrame:pointer; {pointer to actual frame}
       LocalStack:pointer; {pointer to actual top of stack}
       LocalOfs:longint; {offset to local frame: LocalOfs => LocalFrame-GlobAddr}

       {execution controls}
       //UserBreak:longint; {0..continue, 1..stop execution immediately}
       LineBreak:longint; {0..continue, 1..stop execution on next line}
       Returns:longint;    {counter: increased on function call, decreased on return}
       LineCount:longint;  {how many lines has source.. in code line numbers must be <LineCount}
       LineTable:PLineFlags;  {points to array of TLineFlags}

       {exception code and more info}
       StopLine:longint; {last executed line}
       PrevLine:longint; {previous executed line}
       BadInstr:longint; {code of not implemented instr}
       BoundsErrIndex,BoundsErrArray:longint; {out of array exception info}
       ExitCode:longint; {type of exception (any constant ERR?????)}

       procedure Push(var x;size:longint);    {push someting on stack}
       procedure Pop(var x;size:longint);     {pop someting from top of stack}
       procedure SetCode(Code:TCodeFragment);
       procedure SetLineTable(lines:longint;linetab: PLineFlags);
       procedure CreateMemSpace(datasize,stacksize:longint);
       procedure DestroyMemSpace;
       procedure Run;
     end;

const ERRQUIT=0;
      ERRBOUNDS=1;
      ERROVERFLOW=2;
      ERRLINEBREAK=3;
      ERRUSERBREAK=4;
      ERRNOTIMPL=5;
      ERRBADSYS=6;
      ERRSTACKOVF=7;
      ERRREADY=8;
      ERRINTERNAL=9;

      ErrDescr:array[0..9] of string=(
        'finished',
        'error - out of bounds',
        'error - overflow',
        'line break',
        'user break',
        'error - instruction not implemented',
        'error - in system procedure (bad params)',
        'stack overflow',
        'ready',
        'internal error');

var Prg:TPrgMemSpace;

implementation

uses compiler, utils;

procedure TPrgMemSpace.SetCode(Code:TCodeFragment);
begin
  CodeAddr:=Code.Code.Memory;
  CodeSize:=Code.Code.Size;
  InstrPtr:=CodeAddr;
end;

procedure TPrgMemSpace.SetLineTable(lines:longint;linetab: PLineFlags);
begin
  LineCount:=lines;
  LineTable:=linetab;
end;

procedure TPrgMemSpace.CreateMemSpace(datasize,stacksize:longint);
begin
  GlobSize:=datasize;
  GetMem(GlobAddr,GlobSize);
  FillChar(GlobAddr^,GlobSize,0);

  LocalSize:=stacksize;
  GetMem(LocalAddr,LocalSize);
  FillChar(LocalAddr^,LocalSize,0);
  LocalFrame:=LocalAddr;
  LocalStack:=LocalFrame;
  LocalTop:=pointer(longword(LocalAddr)+LocalSize-4*1024);
  LocalOfs:= longint(LocalFrame)-longint(GlobAddr);

  //UserBreak:=0;
  LineBreak:=0;

  ExitCode:=ERRQUIT;
end;

procedure TPrgMemSpace.DestroyMemSpace;
begin
  FreeMem(Prg.GlobAddr);
  FreeMem(Prg.LocalAddr);
  FreeMem(Prg.LineTable);
  ExitCode:=ERRQUIT;
end;

procedure TPrgMemSpace.Push(var x;size:longint);
begin
  if longword(LocalStack)+size > longword(LocalAddr)+LocalSize then raise InternalError.Create('stack overflow')
  else begin
    move(x,LocalStack^,size);
    LocalStack:=PtrAdd(LocalStack,size);
  end;
end;

procedure TPrgMemSpace.Pop(var x;size:longint);
begin
  if longword(LocalStack)-size < longword(LocalAddr) then raise InternalError.Create('stack underflow')
  else begin
    LocalStack:=PtrAdd(LocalStack,-size);
    move(LocalStack^,x,size);
  end;
end;


procedure SysCall(p:TProcedure; var Prg:TPrgMemSpace); register;
var pl:longint;
begin
  pl:=p.LibProc(p,longint(Prg.LocalStack));
  if pl=-1 then
    Prg.ExitCode:=ERRBADSYS
  else
    dec(longint(Prg.LocalStack),pl);
end;

var fpusave:array[byte] of byte;

{
Run1 expects parameters in registers, therefore can't have begin/end (this put parameters on stack)
input registers:
EAX - p1  (not using this)
EDX - Prg  (address of Prg)
}
procedure Run1(p1:pointer; var Prg:TPrgMemSpace);
var edxsave:longint;
asm
        mov edxsave,edx
        jmp @start

@tab:

dd @LINE
dd @QUIT
dd @ENTRY
dd @LOCINI
dd @RET
dd @CALL
dd @SYS
dd @JMP
dd @JNZ
dd @JZ
dd @CIE
dd @CINE
dd @CIL
dd @CILE
dd @CIG
dd @CIGE
dd @CFE
dd @CFNE
dd @CFL
dd @CFLE
dd @CFG
dd @CFGE
dd @ARRACC
dd @MKGLB
dd @CNVF
dd @PUSHZ
dd @PUSHO
dd @PUSH1
dd @PUSH2
dd @STORI
dd @STORF
dd @STORM
dd @LOADI
dd @LOADF
dd @LOADM
dd @PUSHI
dd @PUSHF
(* dd @MOVS *)
dd @ADDI
dd @ADDF
dd @SUBI
dd @SUBF
dd @MULI
dd @MULF
dd @DIVI
dd @DIVF
dd @NEGI
dd @NEGF
dd @MODI
dd @ORI
dd @XORI
dd @ANDI
dd @PUSHGZ
dd @PUSHGO
dd @PUSHG1
dd @PUSHG2
dd @PUSHGI
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork
dd @notwork

@ARRACC:lodsd
        mov ebx,eax
        sub edi,4
        mov eax,[edi]
        cmp eax,dword ptr [ebx+4]
        jg @boundserr
        sub eax,dword ptr [ebx]
        jnl @ARR1
        add eax,dword ptr [ebx]
        jmp @boundserr
@ARR1:  push edx
        mul dword ptr [ebx+8] {nici edx}
        pop edx
        add dword ptr [edi-4],eax   {a pøiètu to k vrcholu zásobníku}
        jmp @next

@ENTRY: mov eax,Prg.LocalFrame
        stosd
        mov Prg.LocalFrame,edi
        mov eax,edi
        sub eax,Prg.GlobAddr
        mov Prg.LocalOfs,eax
        jmp @next

@LOCINI:sub edi,4
        mov ecx,[edi]
        xor eax,eax
        rep stosd
        cmp edi,Prg.LocalTop
        jae @stackovf
        jmp @next

@RET:   mov ebx,[edi-4]
        mov edi,Prg.LocalFrame
        sub edi,8
        mov eax,[edi+4]
        mov Prg.LocalFrame,eax
        sub eax,Prg.GlobAddr
        mov Prg.LocalOfs,eax
        mov esi,[edi]
        sub edi,ebx
        dec Prg.Returns
        jmp @next

@CALL:  xchg [edi-4],esi
        add esi,Prg.CodeAddr
        inc Prg.Returns
        jmp @next

@SYS:   sub edi,4
        mov eax,[edi]
        mov Prg.InstrPtr,esi
        mov Prg.LocalStack,edi
        push edx
        call SysCall
        pop edx
        mov esi,Prg.InstrPtr
        mov edi,Prg.LocalStack
        jmp @next

@JMP:   lodsw
        cwde
        add esi,eax
        jmp @next

@JNZ:   sub edi,4
        mov eax,[edi]
        or eax,eax
        jnz @JMP
        add esi,2
        jmp @next

@JZ:    sub edi,4
        mov eax,[edi]
        or eax,eax
        jz @JMP
        add esi,2
        jmp @next

@CIE:   sub edi,8
        mov eax,[edi]
        cmp eax,[edi+4]
        je @PUSHO
        jmp @PUSHZ

@CINE:  sub edi,8
        mov eax,[edi]
        cmp eax,[edi+4]
        jne @PUSHO
        jmp @PUSHZ

@CIL:   sub edi,8
        mov eax,[edi]
        cmp eax,[edi+4]
        jl @PUSHO
        jmp @PUSHZ

@CILE:  sub edi,8
        mov eax,[edi]
        cmp eax,[edi+4]
        jle @PUSHO
        jmp @PUSHZ

@CIG:   sub edi,8
        mov eax,[edi]
        cmp eax,[edi+4]
        jg @PUSHO
        jmp @PUSHZ

@CIGE:  sub edi,8
        mov eax,[edi]
        cmp eax,[edi+4]
        jge @PUSHO
        jmp @PUSHZ

@CFE:	sub edi,16
        fld qword ptr [edi]
        fcomp qword ptr [edi+8]
        fnstsw ax
        sahf
        je @PUSHO
        jmp @PUSHZ

@CFNE:  sub edi,16
        fld qword ptr [edi]
        fcomp qword ptr [edi+8]
        fnstsw ax
        sahf
        jne @PUSHO
        jmp @PUSHZ

@CFL:   sub edi,16
        fld qword ptr [edi]
        fcomp qword ptr [edi+8]
        fnstsw ax
        sahf
        jb @PUSHO
        jmp @PUSHZ

@CFLE:  sub edi,16
        fld qword ptr [edi]
        fcomp qword ptr [edi+8]
        fnstsw ax
        sahf
        jbe @PUSHO
        jmp @PUSHZ

@CFG:   sub edi,16
        fld qword ptr [edi]
        fcomp qword ptr [edi+8]
        fnstsw ax
        sahf
        ja @PUSHO
        jmp @PUSHZ

@CFGE:  sub edi,16
        fld qword ptr [edi]
        fcomp qword ptr [edi+8]
        fnstsw ax
        sahf
        jae @PUSHO
        jmp @PUSHZ

@MKGLB: mov eax,Prg.LocalOfs
        add dword ptr [edi-4],eax
        jmp @next

@CNVF:  fild dword ptr [edi-4]
        add edi,4
        fstp qword ptr [edi-8]
        jmp @next

@PUSHZ: xor eax,eax
        stosd
        jmp @next

@PUSHO: mov eax,1
        stosd
        jmp @next

@PUSH1: lodsb
        cbw
        cwde
        stosd
        jmp @next

@PUSH2: lodsw
        cwde
        stosd
        jmp @next

@PUSHI: lodsd
        stosd
        jmp @next

@PUSHGZ:
        mov eax,Prg.LocalOfs
        stosd
        jmp @next

@PUSHGO:
        mov eax,Prg.LocalOfs
        inc eax
        stosd
        jmp @next

@PUSHG1: lodsb
        cbw
        cwde
        add eax,Prg.LocalOfs
        stosd
        jmp @next

@PUSHG2: lodsw
        cwde
        add eax,Prg.LocalOfs
        stosd
        jmp @next

@PUSHGI: lodsd
        add eax,Prg.LocalOfs
        stosd
        jmp @next

@STORI: sub edi,8
        mov eax,[edi+4]
        mov ebx,[edi]
        add ebx,Prg.GlobAddr
        mov [ebx],eax
        jmp @next

@STORF: sub edi,8+4
        fld qword ptr [edi+4]
        mov ebx,[edi]
        add ebx,Prg.GlobAddr
        fstp qword ptr [ebx]
        jmp @next

@STORM: sub edi,4
        mov ecx,[edi]
        sub edi,ecx
        sub edi,ecx
        sub edi,ecx
        sub edi,ecx
        mov ebx,esi
        mov esi,edi
        sub edi,4
        push edi
        mov edi,[edi]
        add edi,Prg.GlobAddr
        rep movsd
        mov esi,ebx
        pop edi
        jmp @next

@LOADI: sub edi,4
        mov ebx,[edi]
        add ebx,Prg.GlobAddr
        mov eax,[ebx]
        stosd
        jmp @next

@LOADF: mov ebx,[edi-4]
        add ebx,Prg.GlobAddr
        fld qword ptr [ebx]
        add edi,4
        fstp qword ptr [edi-8]
        jmp @next

@LOADM: sub edi,8
        mov ebx,esi
        mov esi,[edi]
        add esi,Prg.GlobAddr
        mov ecx,[edi+4]
        cmp ecx,$1000
        jge @LOADM1
        rep movsd
        mov esi,ebx
        jmp @next
@LOADM1:mov esi,ebx
	      jmp @overflow


@PUSHF: lodsd
        stosd
        lodsd
        stosd
        jmp @next

(*
@MOVS:  sub edi,3*4
        mov ecx,[edi]     {dst}
        mov edx,[edi+4]   {src}
        mov ebx,[edi+2*4] {count}
        add ecx,ebx
        add ecx,Prg.GlobAddr
        add edx,ebx
        add edx,Prg.GlobAddr
        neg ebx
@MOVS1: mov al,[edx+ebx]
        mov [ecx+ebx],al
        inc ebx
        jnz @MOVS1
        jmp @next
*)

@ADDI:  sub edi,4
        mov eax,[edi]
        add dword ptr [edi-4],eax
        jo @overflow
        jmp @next

@SUBI:  sub edi,4
        mov eax,[edi]
        sub dword ptr [edi-4],eax
        jo @overflow
        jmp @next

@MULI:  sub edi,4
        mov eax,[edi]
        push edx
        imul dword ptr [edi-4] {meni edx}
        pop edx
        mov dword ptr [edi-4],eax
        jo @overflow
        jmp @next

@DIVI:  sub edi,8
        mov eax,[edi]
        mov ebx,[edi+4]
        push edx
        xor edx,edx
        idiv ebx             {pouziva edx}
        pop edx
        stosd
        jo @overflow
        jmp @next

@MODI:  sub edi,8
        mov eax,[edi]
        mov ebx,[edi+4]
        push edx
        xor edx,edx
        idiv ebx             {pouziva edx}
        mov eax,edx
        pop edx
        stosd
        jo @overflow
        jmp @next

@ORI:   sub edi,4
        mov eax,[edi]
        or dword ptr [edi-4],eax
        jmp @next

@XORI:  sub edi,4
        mov eax,[edi]
        xor dword ptr [edi-4],eax
        jmp @next

@ANDI:  sub edi,4
        mov eax,[edi]
        and dword ptr [edi-4],eax
        jmp @next

@NEGI:  neg dword ptr [edi-4]
        jmp @next

@ADDF:  sub edi,8
        fld qword ptr [edi-8]
        fadd qword ptr [edi]
        fstp qword ptr [edi-8]
        jmp @next

@SUBF:  sub edi,8
        fld qword ptr [edi-8]
        fsub qword ptr [edi]
        fstp qword ptr [edi-8]
        jmp @next

@MULF:  sub edi,8
        fld qword ptr [edi-8]
        fmul qword ptr [edi]
        fstp qword ptr [edi-8]
        jmp @next

@DIVF:  sub edi,8
        fld qword ptr [edi-8]
        fdiv qword ptr [edi]
        fstp qword ptr [edi-8]
        jmp @next

@NEGF:  fld qword ptr [edi-8]
	      fchs
        fstp qword ptr [edi-8]
        jmp @next

@LINE:  mov eax,Prg.StopLine       //store previous completed line nr
        mov Prg.PrevLine, eax
        xor eax,eax                //load next line number
        lodsw
        mov Prg.StopLine,eax       //set current line

        mov ebx,Prg.LineTable
        inc dword ptr [ebx+eax*8]        //increase line hits count
        mov eax,dword ptr [ebx+eax*8+4]  //breakpoint is set when <>0
        or eax,Prg.LineBreak      //test if it should stop at this line (or any line)
        jnz @linebreak
@next:

        //cmp edx, edxsave
        //jnz @internalerr

        //mov eax,Prg.UserBreak      //test if should break immediatelly
        //or eax,eax
        //jnz @userbreak
        xor eax,eax                //get next instruction code
        lodsb
        mov ebx,dword ptr [@tab+eax*4]  //jump to its routine
        jmp ebx

@notwork:    {instrukcia neimplementovana, nezacala sa vykonavat}
        shr eax,2
        mov Prg.BadInstr,eax
        mov eax,ERRNOTIMPL
        dec esi
        jmp @exit

@boundserr:  {eax-index, ebx-ptr na array info, instrukcia prerusena (neulozeny vysledok(i))}
        mov [edi],eax
        add edi,4
        mov Prg.BoundsErrIndex,eax
        mov Prg.BoundsErrArray,ebx
        mov eax,ERRBOUNDS
        jmp @exit

@overflow:   {aritmeticka chyba, instrukcia je prevedena cela}
        mov eax,ERROVERFLOW
        jmp @exit

@stackovf:   {po vykonani LOCINI ostava malo miesta na zasobniku}
        mov eax,ERRSTACKOVF
        jmp @exit

@userbreak:  {instr. sa nezacala vykonavat}
        mov eax,ERRUSERBREAK
        jmp @exit

@linebreak:  {instr. sa nezacala vykonavat}
        mov eax,ERRLINEBREAK
        jmp @exit

@internalerr:  {zmìnila se hodnota EDX, což je adresa Prg}
        mov edx,edxsave
        mov eax,ERRINTERNAL
        jmp @exit

@QUIT:       {normal exit}
        mov eax,ERRQUIT
        jmp @exit

@start:
	      mov eax,offset fpusave
        fsave [eax]
        push esi
        push edi
        push ebx

{esi ... program pointer}
{edi ... stack pointer}

        mov esi,Prg.InstrPtr
        mov edi,Prg.LocalStack
        jmp @next

@exit:  mov Prg.InstrPtr,esi
        mov Prg.LocalStack,edi
        mov Prg.ExitCode,eax

        pop ebx
        pop edi
        pop esi
	      mov eax,offset fpusave
        frstor [eax]
end;

procedure TPrgMemSpace.Run;
begin
  Run1(nil,self);
end;

begin
end.
