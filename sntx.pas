unit sntx;

interface

uses sysutils,classes;

procedure CmpModule;

implementation

uses lex,compiler,gener,expr;

procedure CmpVariableDef(table:TPrgItemList); forward;

function CmpType:TType;
var minind,maxind:longint;
    itemtype:TType;
    a:TArray;
    r:TRecord;
    l:TListType;
    typeident:string;
    prgitem:TPrgItem;
begin
  if TestAndEatTokenAlpha('array') then begin
    EatTokenSymbol('[');
    EatInteger(minind);
    EatTokenSymbol('..');
    EatInteger(maxind);
    EatTokenSymbol(']');
    EatTokenAlpha('of');
    if minind>maxind then raise SyntaxError.Create('first bound is greather then second')
    else begin
      itemtype:=CmpType;
      a:=TArray.Create;
      a.ItemType:=itemtype;
      a.MinIndex:=minind;
      a.MaxIndex:=maxind;
      a.ItemSize:=a.ItemType.Size;
      a.Size:=(maxind-minind+1)*a.ItemSize;
      CmpType:=a;
    end;
  end else if TestAndEatTokenAlpha('record') then begin
    r:=TRecord.Create;
    while not TestAndEatTokenAlpha('end') do begin
      CmpVariableDef(r.Items);
      EatTokenSymbol(';');
    end;
    TestAndEatTokenAlpha('record');
    r.Size:=r.Items.GetDataSize;
    CmpType:=r;
  end else if TestAndEatTokenAlpha('list') then begin
    EatTokenAlpha('of');
    itemtype:=CmpType;
    l:=TListType.Create;
    l.ItemType:=itemtype;
    l.Size:=sizeof(longint);
    CmpType:=l;
  end else begin
    EatIdentifier(typeident,'a type');
    Globals.FindItem(typeident,prgitem,'a type');
    if not (prgitem is TType) then raise SyntaxError.Create('a type expected, but "'+typeident+'" is a '+prgitem.GetItemClass);
    CmpType:=prgitem as TType;
  end;
end;

procedure CmpVariableDef(table:TPrgItemList);
var varname:string;
    v:TVariable;
    t:TType;
begin
  if not EatIdentifier(varname,'a identifier of new variable') then
  else if table.IndexOf(varname)<>-1 then raise SyntaxError.Create('a identifier "'+varname+'" already defined')
  else if not EatTokenAlpha('as') then
  else begin
    t:=CmpType;
    v:=TVariable.Create;
    v.VarType:=t;
    if table.LastVar=-1 then v.Addr:=0
    else v.Addr:=(table.Objects[table.LastVar] as TVariable).Addr+
                 (table.Objects[table.LastVar] as TVariable).VarType.Size;
    table.LastVar:=table.AddObject(varname,v);
  end;
end;

procedure CmpTypeDef;
var typename:string;
    i:TPrgItem;
begin
  if not EatIdentifier(typename,'a identifier of new type') then
  else if Globals.IndexOf(typename)<>-1 then raise SyntaxError.Create('a identifier "'+typename+'" already defined')
  else if not EatTokenAlpha('as') then
  else Globals.AddObject(typename,CmpType);

  //if type Position is defined, we can add system procedure NewMove(Position,Name,Gamma)
  if UpperCase(typename) = 'POSITION' then begin
    Globals.FindItem(typename,i,'');
    DefPosition:=i as TType;
    DefSystemPositionObjects;
  end;
end;

procedure CmpAssign;
var dt,st:TType;
begin
  CmpVarAddr(dt,Code);
  EatTokenSymbol(':=');
  CmpExpression(st,Code);
  GenAssign(dt,st);
end;

procedure CmpProcCall(proc:TProcedure);
begin
  GetToken;
  CmpParams(Code,proc);
  if proc is TFunction then begin
    {!!!odstranit nepotrebny vysledok zo zasobnika}
  end;
end;

procedure CmpCommand; forward;

procedure CmpDo;
begin
  EatTokenAlpha('do');
  while not TestAndEatTokenAlpha('end') do begin
    CmpCommand;
    EatTokenSymbol(';');
  end;
end;

procedure CmpIf;
var lbltrue,lblfalse,lblend:longint;
begin
  EatTokenAlpha('if');
  NewLabel(lbltrue);
  NewLabel(lblfalse);
  CmpBoolExpr(Code,lbltrue,lblfalse);
  if not TestAndEatTokenAlpha('then') then raise SyntaxError.Create('"then" expected')
  else begin
    Code.AssignLbl(lbltrue,Code.GetCurAddr);
    if not TestTokenAlpha('else') then CmpCommand;
    if TestAndEatTokenAlpha('else') then begin
      NewLabel(lblend);
      Code.GenInstrJmp(JMP,lblend);
      Code.AssignLbl(lblfalse,Code.GetCurAddr);
      CmpCommand;
    end else lblend:=lblfalse;
    Code.AssignLbl(lblend,Code.GetCurAddr);
  end;
end;

procedure CmpSwitch;
var lbltrue,lblfalse,lblend:longint;
begin
  EatTokenAlpha('switch');
  NewLabel(lblend);
  while TestAndEatTokenAlpha('case') do begin
    NewLabel(lbltrue);
    NewLabel(lblfalse);
    CmpBoolExpr(Code,lbltrue,lblfalse);
    if not TestAndEatTokenSymbol(':') then raise SyntaxError.Create('":" expected')
    else begin
      Code.AssignLbl(lbltrue,Code.Code.Size);
      while not (TestTokenAlpha('case') or TestTokenAlpha('otherwise') or TestTokenAlpha('end')) do begin
        CmpCommand;
        EatTokenSymbol(';');
      end;
      Code.GenInstrJmp(JMP,lblend);
      Code.AssignLbl(lblfalse,Code.GetCurAddr);
    end;
  end;
  if TestAndEatTokenAlpha('otherwise') then begin
    TestAndEatTokenSymbol(':');
    while not TestTokenAlpha('end') do begin
      CmpCommand;
      EatTokenSymbol(';');
    end;
  end;
  Code.AssignLbl(lblend,Code.GetCurAddr);
  EatTokenAlpha('end');
  TestAndEatTokenAlpha('switch');
end;

procedure CmpWhile;
var lblcond,lblstart,lblend:longint;
begin
  NewLabel(lblstart);
  NewLabel(lblend);
  lblcond:=Code.GetCurAddr;
  EatTokenAlpha('while');
  CmpBoolExpr(Code,lblstart,lblend);
  EatTokenAlpha('do');
  Code.AssignLbl(lblstart,Code.GetCurAddr);
  while not TestAndEatTokenAlpha('end') do begin
    CmpCommand;
    EatTokenSymbol(';');
  end;
  TestAndEatTokenAlpha('while');
  Code.GenInstrJmpAssigned(JMP,lblcond);
  Code.AssignLbl(lblend,Code.GetCurAddr);
end;

procedure CmpFor;
var lblcond,lblstart,lblend:longint;
    vart,expr1t,expr2t,expr3t:TType;
    varc,expr2c:TCodeFragment;
    direction:longint;
begin
  NewLabel(lblend);
  NewLabel(lblcond);

  EatTokenAlpha('for');

  {var:=expr1}
  varc:=nil;
  CmpVarAddr(vart,varc);
  if not (EqualTypes(vart,DefInt) or EqualTypes(vart,DefFloat))
    then raise SyntaxError.Create('for control variable must be integer or float');
  Code.Code.CopyFrom(varc.Code,0);
  EatTokenSymbol(':=');
  CmpExpression(expr1t,Code);
  GenAssign(vart,expr1t);

  {goto cond}
  Code.GenInstrJmp(JMP,lblcond);

  {start: var:=var+expr3}
  lblstart:=Code.GetCurAddr;
  if TestAndEatTokenAlpha('downto') then direction:=-1
  else begin
    EatTokenAlpha('to');
    direction:=1;
  end;
  expr2c:=nil;
  CmpExpression(expr2t,expr2c);
  Code.Code.CopyFrom(varc.Code,0);
  Code.Code.CopyFrom(varc.Code,0);
  if EqualTypes(vart,DefInt) then Code.GenInstr(LOADI) else Code.GenInstr(LOADF);
  if TestAndEatTokenAlpha('by') then begin
    CmpExpression(expr3t,Code);
    GenConvTo(expr3t,vart,Code);
  end else begin
    if EqualTypes(vart,DefInt)
      then Code.GenInstrPushI(direction)
      else Code.GenInstrPushF(direction);
  end;
  if EqualTypes(vart,DefInt) then begin
    Code.GenInstr(ADDI);
    Code.GenInstr(STORI);
  end else begin
    Code.GenInstr(ADDF);
    Code.GenInstr(STORF);
  end;

  {cond: if var>(<)expr2 goto end}
  EatTokenAlpha('do');
  Code.AssignLbl(lblcond,Code.GetCurAddr);
  Code.AddCodeFragment(varc);
  if EqualTypes(vart,DefInt) then Code.GenInstr(LOADI) else Code.GenInstr(LOADF);
  GenConvAndAddCode(vart,Code,expr2t,expr2c);
  if EqualTypes(vart,DefInt) then begin
    if direction=1 then Code.GenInstr(CIG)
                   else Code.GenInstr(CIL)
  end else begin
    if direction=1 then Code.GenInstr(CFG)
                   else Code.GenInstr(CFL)
  end;
  Code.GenInstrJmp(JNZ,lblend);

  {prikazy}
  while not TestAndEatTokenAlpha('end') do begin
    CmpCommand;
    EatTokenSymbol(';');
  end;
  TestAndEatTokenAlpha('for');

  {goto start}
  Code.GenInstrJmpAssigned(JMP,lblstart);

  {end:}
  Code.AssignLbl(lblend,Code.GetCurAddr);
end;

procedure CmpCommand;
var str:string;
    item:TPrgItem;
    loc:boolean;
begin
  Code.GenLine;
  if TestIdentifier then begin
    if not FindItem(cur_str,item,loc,'a identifier of variable or a routine') then
    else if item is TVariable then CmpAssign
    else if item is TProcedure then CmpProcCall(item as TProcedure)
    else raise SyntaxError.Create('a identifier of variable or a routine expected, but "'+str+'" is a '+item.GetItemClass)
  end else
  if TestTokenAlpha('do') then CmpDo else
  if TestTokenAlpha('if') then CmpIf else
  if TestTokenAlpha('switch') then CmpSwitch else
  if TestTokenAlpha('while') then CmpWhile else
  if TestTokenAlpha('for') then CmpFor else raise SyntaxError.Create('a command expected');
end;

procedure CmpDefParams(params:TPrgItemList);
begin
  if TestAndEatTokenSymbol('(') then begin
    if not TestTokenSymbol(')') then CmpVariableDef(params);
    while TestAndEatTokenSymbol(';') do CmpVariableDef(params);
    EatTokenSymbol(')');
  end;
end;

procedure CmpDefResult(params:TPrgItemList);
var t:TType;
    v:TVariable;
begin
  t:=CmpType;
  v:=TVariable.Create;
  v.VarType:=t;
  v.Addr:=-v.VarType.Size;
  params.InsertObject(0,'Result',v);
  inc(params.LastVar);
end;

procedure CmpProcedure(cmpfnc:boolean);
var procname:string;
    p:TProcedure;
begin
  if not EatIdentifier(procname,'a identifier of new procedure') then else
  if Globals.IndexOf(procname)<>-1 then raise SyntaxError.Create('a identifier "'+procname+'" already defined') else
  begin
    if cmpfnc then p:=TFunction.Create else p:=TProcedure.Create;
    Globals.AddObject(procname,p);
    p.LineFrom:=cur_line;
    p.CodeOfs:=Code.GetCurAddr;

    CmpDefParams(p.Params);
    if cmpfnc then begin
      EatTokenAlpha('as');
      CmpDefResult(p.Params);
    end;
    p.PrepareParams;

    EatTokenSymbol(';');
    Code.GenInstr(ENTRY);
    while TestAndEatTokenAlpha('def') do begin
      CmpVariableDef(p.Params);
      EatTokenSymbol(';');
    end;

    Locals:=p.Params;
    if p.Params.GetDataSize>0 then begin
      Code.GenInstrPushI((p.Params.GetDataSize+3) div 4);
      Code.GenInstr(LOCINI);
    end;
    while not TestAndEatTokenAlpha('end') do begin
      CmpCommand;
      EatTokenSymbol(';');
    end;
    if cmpfnc then TestAndEatTokenAlpha('func') else TestAndEatTokenAlpha('proc');

    Code.GenLine;
    Code.GenInstrPushI(p.ParamsSize);
    Code.GenInstr(RET);
    Locals:=nil;
    p.LineTo:=cur_line;
  end;
end;

procedure CmpModule;
begin
  GetToken;

  while cur_token<>TTEndFile do begin
    EatTokenAlpha('def');
    if TestAndEatTokenAlpha('type') then CmpTypeDef else
    if TestAndEatTokenAlpha('proc') then CmpProcedure(false) else
    if TestAndEatTokenAlpha('func') then CmpProcedure(true) else
    CmpVariableDef(Globals);
    EatTokenSymbol(';');
  end;

end;

end.
