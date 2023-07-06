unit gener;

interface

uses classes,compiler;

type TInstruction=( {$i instr.inc}  INSTR_COUNT );

     TCodeFragment=class(TObject)
       Code,CodeInfo:TMemoryStream;
       constructor Create;
       destructor Destroy; override;
       procedure GenLine;
       procedure GenInstr(instr:TInstruction);
       procedure GenInstrJmp(instr:TInstruction;lbl:longint);
       procedure GenInstrJmpAssigned(instr:TInstruction;lbl:longint);
       procedure GenInstrPushI(l:longint);
       procedure GenInstrPushLocalToGlobalAddr(l:longint);
       procedure GenInstrPushF(f:double);
       procedure GenCall(p:TProcedure);
       procedure GenInt(l:longint);
       procedure GenFloat(f:double);
       procedure AddCodeFragment(CodeFrag:TCodeFragment);
       procedure DebugDisplay(fname:string;Src:Pchar);
       procedure AssignLbl(lbl,addr:longint);
       procedure AssignLblToLbl(lblfrom,lblto:longint);
       function GetCurAddr:longint;
     end;

function FindItem(str:string;var item:TPrgItem;var loc:boolean;dscr:string):boolean;
procedure NewLabel(var lbl:longint);
procedure GenConvAndAddCode(var ResType1:TType;Code1:TCodeFragment;
                                ResType2:TType;Code2:TCodeFragment);
procedure GenConvTo(SrcType,DstType:TType;Code:TCodeFragment);
procedure GenArrayInfoAddr(Arr:TArray;Code:TCodeFragment);
procedure GenAssign(dt,st:TType);

var Code:TCodeFragment;
    Locals:TPrgItemList;
    LabelCnt:longint;

implementation

uses sysutils,lex,sntx,dbgwin,expr,utils;

var LastLine:longint;
    InstrTab:array[0..ord(INSTR_COUNT)] of record
               name:string;
               op:string[1];
             end;

procedure NewLabel(var lbl:longint);
begin
  if LabelCnt>$FFFF then raise InternalError.Create('too many labels')
  else begin
    lbl:=LabelCnt;
    inc(LabelCnt);
  end;
end;

function FindItem(str:string;var item:TPrgItem;var loc:boolean;dscr:string):boolean;
begin
  Result:=false;
  if Locals.FindItem(str,item,'') then begin
    loc:=true;
    Result:=true;
  end else if Globals.FindItem(str,item,dscr) then begin
    loc:=false;
    Result:=true;
  end;
end;

constructor TCodeFragment.Create;
begin
  Code:=TMemoryStream.Create;
end;

destructor TCodeFragment.Destroy;
begin
  Code.Free;
end;

procedure TCodeFragment.GenLine;
var b:byte;
    l:longint;
begin
  b:=ord(LINE);
  l:=cur_line;
  Code.Write(b,sizeof(b));
  Code.Write(l,2);
end;

procedure TCodeFragment.GenInstr(instr:TInstruction);
var b:byte;
begin
{  if LastLine<>cur_line then begin
    LastLine:=cur_line;
    GenLine;
  end;}
  b:=ord(instr);
  Code.Write(b,sizeof(b));
end;

procedure TCodeFragment.GenInstrJmp(instr:TInstruction;lbl:longint);
begin
  if (instr<JMP) or (instr>JZ) then raise InternalError.Create('GenInstrJmp: instr is not a jump')
  else begin
    GenInstr(TInstruction(chr(ord(instr)+ord(INSTR_COUNT)-ord(JMP))));
    Code.Write(lbl,2);
  end;
end;

procedure TCodeFragment.GenInstrJmpAssigned(instr:TInstruction;lbl:longint);
begin
  if (instr<JMP) or (instr>JZ) then raise InternalError.Create('GenInstrJmp: instr is not a jump')
  else begin
    GenInstr(instr);
    lbl:=lbl-(Code.Position+2);
    Code.Write(lbl,2);
  end;
end;

procedure TCodeFragment.GenInstrPushI(l:longint);
begin
  if l = 0 then GenInstr(PUSHZ)
  else if l = 1 then GenInstr(PUSHO)
  else if IIR(l,-128,127) then begin GenInstr(PUSH1); Code.Write(l,1); end
  else if IIR(l,-32768,32767) then begin GenInstr(PUSH2); Code.Write(l,2); end
  else begin GenInstr(PUSHI); GenInt(l); end
end;

//l is address of local variable
//generate code that pushes this address adjusted to global address space
procedure TCodeFragment.GenInstrPushLocalToGlobalAddr(l:longint);
begin
  if l = 0 then GenInstr(PUSHGZ)
  else if l = 1 then GenInstr(PUSHGO)
  else if IIR(l,-128,127) then begin GenInstr(PUSHG1); Code.Write(l,1); end
  else if IIR(l,-32768,32767) then begin GenInstr(PUSHG2); Code.Write(l,2); end
  else begin GenInstr(PUSHGI); GenInt(l); end
end;

procedure TCodeFragment.GenInstrPushF(f:double);
begin
  GenInstr(PUSHF);
  GenFloat(f);
end;

procedure TCodeFragment.GenCall;
begin
  if @p.LibProc = nil then begin
    GenInstrPushI(p.CodeOfs+WatchCallOfs);
    GenInstr(CALL);
  end else begin
    GenInstrPushI(longint(p));
    GenInstr(SYS);
  end;
end;

procedure TCodeFragment.GenInt(l:longint);
begin
  Code.Write(l,sizeof(l));
end;

procedure TCodeFragment.GenFloat(f:double);
begin
  Code.Write(f,sizeof(f));
end;

procedure TCodeFragment.AddCodeFragment(CodeFrag:TCodeFragment);
begin
  Code.CopyFrom(CodeFrag.Code,0); {copy entire contents of stream}
  CodeFrag.Free;
end;

procedure LoadInstrTab;
var f:text;
    i:longint;
    str:string;
begin
  AssignFile(f,'instr.inc');
  Reset(f); i:=0;
  while not eof(f) do begin
    readln(f,str);
    InstrTab[i].name:=copy(str,1,pos(',',str)-1);
    if pos(')*',str) > 0 then InstrTab[i].op:=copy(str,pos(')*',str)-1,1)
    else InstrTab[i].op:=#0;
    inc(i);
  end;
  Close(f);
end;

procedure TCodeFragment.DebugDisplay(fname:string;Src:Pchar);
var f:text;
    inst:longint;
    i1:shortint;
    i2:smallint;
    i4:longint;
    fl:double;
    hex:string;
    txt:string;
begin
  AssignFile(f,fname);
  Rewrite(f);
  Code.Position:=0;
  try
    while Code.Position < Code.Size do begin
      hex:=Format('%4.4x',[Code.Position])+' ';
      Code.Read(i1,1);
      inst:=i1;
      if inst>=ord(INSTR_COUNT) then
        inst:=inst-ord(INSTR_COUNT)+ord(JMP);   //tohle nechápu
      hex:=hex+IntToHex(i1)+' ';
      txt:=copy(InstrTab[inst].name+'          ',1,8);
      case InstrTab[inst].op[1] of
        'b': begin Code.Read(i1,1); hex:=hex+IntToHex(i1); txt:=txt+IntToStr(i1); end;
        'w': begin
               Code.Read(i2,2);
               hex:=hex+IntToHex(i2);
               if (inst>=ord(JMP)) and (inst<=ord(JZ)) then begin
                 i2:=i2+Code.Position;    //convert relative jump address to absolute
                 txt:=txt+IntToHex(i2);   //output as hexa
               end else begin
                 txt:=txt+IntToStr(i2);
               end;
             end;
        'i': begin Code.Read(i4,4); hex:=hex+IntToHex(i4); txt:=txt+IntToStr(i4); end;
        'f': begin Code.Read(fl,sizeof(fl)); hex:=hex+IntToHex(UInt64(pointer(@fl)^)); txt:=txt+Format('%f',[fl]); end;
      end;
      writeln(f,copy(hex+'                     ',1,25)+txt);
      if inst=ord(LINE) then writeln(f,'              ',GetLineByNr(Src,i2));
      //flush(f);
    end;
    except
    {!!!}
  end;
  Close(f);
end;

procedure TCodeFragment.AssignLbl(lbl,addr:longint);
var i,tmplbl:longint;
    fl:double;
begin
  tmplbl:=0;
  Code.Position:=0;
  while Code.Position < Code.Size do begin
    i:=0;
    Code.Read(i,1);
    if i<ord(INSTR_COUNT) then
      case InstrTab[i].op[1] of
        'b': Code.Read(i,1);
        'w': Code.Read(i,2);
        'i': Code.Read(i,4);
        'f': Code.Read(fl,sizeof(fl));
      end
    else if i-ord(INSTR_COUNT)+ord(JMP)<=ord(JZ) then begin
      Code.Read(tmplbl,2);
      if tmplbl=lbl then begin
        Code.Position:=Code.Position-3;
        i:=i-ord(INSTR_COUNT)+ord(JMP);
        Code.Write(i,1);  {instr}
        i:=addr-(Code.Position+2);
        Code.Write(i,2);  {relative addr}
      end;
    end else raise InternalError.Create('unknown instruction');
  end;
end;

procedure TCodeFragment.AssignLblToLbl(lblfrom,lblto:longint);
var i,tmplbl:longint;
    fl:double;
begin
  tmplbl:=0;
  Code.Position:=0;
  while Code.Position < Code.Size do begin
    i:=0;
    Code.Read(i,1);
    if i<ord(INSTR_COUNT) then
      case InstrTab[i].op[1] of
        'b': Code.Read(i,1);
        'w': Code.Read(i,2);
        'i': Code.Read(i,4);
        'f': Code.Read(fl,sizeof(fl));
      end
    else if i-ord(INSTR_COUNT)+ord(JMP)<=ord(JZ) then begin
      Code.Read(tmplbl,2);
      if tmplbl=lblfrom then begin
        Code.Position:=Code.Position-2;
        Code.Write(lblto,2);  {label}
      end;
    end else raise InternalError.Create('unknown instruction');
  end;
end;

function TCodeFragment.GetCurAddr:longint;
begin Result:=Code.Position; end;

procedure GenArrayInfoAddr(Arr:TArray;Code:TCodeFragment);
begin
  Code.GenInt(longint(@Arr.MinIndex));
end;

procedure GenAssign(dt,st:TType);
begin
  GenConvTo(st,dt,Code);
  if EqualTypes(dt,DefInt) then Code.GenInstr(STORI)
  else if EqualTypes(dt,DefFloat) then Code.GenInstr(STORF)
  else if EqualTypes(dt,DefVariant) then raise SyntaxError.Create('assign to variant variable is not supported')
  else begin
    Code.GenInstrPushI(dt.Size div 4);
    Code.GenInstr(STORM);
  end;
end;

procedure GenConvAndAddCode(var ResType1:TType;Code1:TCodeFragment;
                                ResType2:TType;Code2:TCodeFragment);
begin
  if EqualTypes(ResType1,ResType2) then
  else if EqualTypes(ResType1,DefInt) and EqualTypes(ResType2,DefFloat) then begin
    Code1.GenInstr(CNVF);
    ResType1:=DefFloat;
  end else if EqualTypes(ResType1,DefFloat) and EqualTypes(ResType2,DefInt) then
    Code2.GenInstr(CNVF)
  else raise SyntaxError.Create('incompatible types');
  Code1.AddCodeFragment(Code2);
end;

procedure GenConvTo(SrcType,DstType:TType;code:TCodeFragment);
begin
  if EqualTypes(SrcType,DstType) then else
  if EqualTypes(SrcType,DefInt) and EqualTypes(DstType,DefFloat) then code.GenInstr(CNVF) else
  if DstType = DefVariant then code.GenInstrPushI(longint(SrcType)) else
  raise SyntaxError.Create('incompatible types');
end;

begin
  LastLine:=-1;
  LoadInstrTab;
end.
