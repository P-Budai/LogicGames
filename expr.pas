unit expr;

interface

uses compiler,gener;

procedure CmpParams(var code:TCodeFragment;proc:TProcedure);
procedure CmpExpression(var ResType:TType;var Code:TCodeFragment);
procedure CmpVarAddr(var t:TType;var Code:TCodeFragment);
procedure CmpBoolExpr(var Code:TCodeFragment;LblTrue,LblFalse:longint);
function EqualTypes(Type1,Type2:TType):boolean;

implementation

uses lex;

function EqualRecords(Record1,Record2:TRecord):boolean;
var i:longint;
begin
  i:=Record1.Items.Count;
  Result:=i=Record2.Items.Count;
  while Result and (i > 0) do begin
    dec(i);
    Result:=Result and (not ((Record1.Items.Objects[i] is TVariable) or (Record2.Items.Objects[i] is TVariable)) or
                            ((Record1.Items.Objects[i] is TVariable) and (Record2.Items.Objects[i] is TVariable) and EqualTypes((Record1.Items.Objects[i] as TVariable).VarType,(Record2.Items.Objects[i] as TVariable).VarType)))
  end;
end;

function EqualArrays(Array1,Array2:TArray):boolean;
begin
  Result:=(Array1.MinIndex=Array2.MinIndex) and
          (Array1.MaxIndex=Array2.MaxIndex) and
          EqualTypes(Array1.ItemType,Array2.ItemType);
end;

function EqualTypes(Type1,Type2:TType):boolean;
begin
  Result:=(Type1=Type2) or
          ((Type1 is TRecord) and (Type2 is TRecord) and EqualRecords(Type1 as TRecord,Type2 as TRecord)) or
          ((Type1 is TArray) and (Type2 is TArray) and EqualArrays(Type1 as TArray,Type2 as TArray));
end;

function EqualTypeSimple4(t:TType):boolean;
begin Result:=EqualTypes(t,DefInt) or EqualTypes(t,DefBool); end;

procedure CmpParams(var code:TCodeFragment;proc:TProcedure);
var i:longint;
    fr:longint;
    st:TType;
begin
  if proc is TFunction then begin
    if code=nil then Code:=TCodeFragment.Create;
    code.GenInstrPushI((proc.Params.Objects[0] as TVariable).VarType.Size div 4);
    code.GenInstr(LOCINI);
    fr:=1;
  end else fr:=0;
  if proc.ParamsCount>0 then begin
    EatTokenSymbol('(');
    for i:=0 to proc.ParamsCount-1 do begin
      if i>0 then EatTokenSymbol(',');
      CmpExpression(st,code);
      GenConvTo(st,(proc.Params.Objects[fr+i] as TVariable).VarType,code);
    end;
    EatTokenSymbol(')');
  end;
  Code.GenCall(proc);
end;

function CmpFuncCall(f:TFunction;var Code:TCodeFragment):TType;
begin
  GetToken;
  CmpParams(Code,f);
  Result:=(f.Params.Objects[0] as TVariable).VarType;
end;

procedure CmpPrimary(var ResType:TType;var Code:TCodeFragment);
var i:TPrgItem;
begin
  case cur_token of
    TTInteger: begin
      if Code=nil then Code:=TCodeFragment.Create;
      Code.GenInstrPushI(cur_int);
      ResType:=DefInt;
      GetToken;
    end;
    TTReal: begin
      if Code=nil then Code:=TCodeFragment.Create;
      Code.GenInstr(PUSHF);
      Code.GenFloat(cur_real);
      ResType:=DefFloat;
      GetToken;
    end;
    TTString: begin
      if Code=nil then Code:=TCodeFragment.Create;
      Code.GenInstrPushI(Compiler.NewString(cur_str));
      ResType:=DefString;
      GetToken;
    end;
    TTAlphaNum: begin
      if TestAndEatTokenAlpha('true') then begin
        if Code=nil then Code:=TCodeFragment.Create;
        Code.GenInstrPushI(1);
        ResType:=DefBool;
      end else if TestAndEatTokenAlpha('false') then begin
        if Code=nil then Code:=TCodeFragment.Create;
        Code.GenInstrPushI(0);
        ResType:=DefBool;
      end else if Globals.FindItem(cur_str,i,'') and (i is TFunction) then begin
        ResType:=CmpFuncCall(i as TFunction,Code);
      end else begin
        CmpVarAddr(ResType,Code);
        if ResType.Size=sizeof(longint) then Code.GenInstr(LOADI)
        else if EqualTypes(ResType,DefFloat) then Code.GenInstr(LOADF)
        else begin
          Code.GenInstrPushI(ResType.Size div 4);
          Code.GenInstr(LOADM);
        end;
      end;
    end;
    TTSymbol:
      if cur_str='-' then begin
        GetToken;
        CmpPrimary(ResType,Code);
        if EqualTypes(ResType,DefInt) then Code.GenInstr(NEGI)
        else if EqualTypes(ResType,DefFloat) then Code.GenInstr(NEGF)
        else SyntaxError.Create('"-" is not applicable');
      end else if cur_str='(' then begin
        GetToken;
        CmpExpression(ResType,Code);
        EatTokenSymbol(')');
      end else raise LexError.Create('primary expected, but '+GetTokenDescr+' found');
    else raise LexError.Create('primary expected, but '+GetTokenDescr+' found');
  end;
end;

procedure CmpTerm(var ResType:TType;var Code:TCodeFragment);
var away:boolean;
    rtype:TType;
    cf:TCodeFragment;
    lblEvalSecTerm,lblSkipSecTerm:longint;
begin
  CmpPrimary(ResType,Code);
  repeat
    away:=TRUE;
    if TestAndEatTokenSymbol('*') then begin
      cf:=nil;
      CmpPrimary(rtype,cf);
      GenConvAndAddCode(ResType,Code,rtype,cf);
      if EqualTypes(ResType,DefInt) then Code.GenInstr(MULI)
      else if EqualTypes(ResType,DefFloat) then Code.GenInstr(MULF)
      else raise SyntaxError.Create('"*" is applicable only to integer or float operands');
      away:=FALSE;
    end else if TestAndEatTokenSymbol('/') then begin
      cf:=nil;
      CmpPrimary(rtype,cf);
      GenConvAndAddCode(ResType,Code,rtype,cf);
      if EqualTypes(ResType,DefInt) then Code.GenInstr(DIVI)
      else if EqualTypes(ResType,DefFloat) then Code.GenInstr(DIVF)
      else raise SyntaxError.Create('"/" is applicable only to integer or float operands');
      away:=FALSE;
    end else if TestAndEatTokenAlpha('mod') then begin
      cf:=nil;
      CmpPrimary(rtype,cf);
      GenConvAndAddCode(ResType,Code,rtype,cf);
      if EqualTypes(ResType,DefInt) then Code.GenInstr(MODI)
      else raise SyntaxError.Create('"mod" is applicable only to integer operands');
      away:=FALSE;
    end else if TestAndEatTokenAlpha('and') then begin
      cf:=nil;
      {if first term was a boolean, then short-circuit boolean evaluation is needed }
      if EqualTypes(ResType, DefBool) then begin
        NewLabel(lblEvalSecTerm);
        NewLabel(lblSkipSecTerm);
        Code.GenInstrJmp(JNZ,lblEvalSecTerm);
        Code.GenInstr(PUSHZ);
        Code.GenInstrJmp(JMP,lblSkipSecTerm);
        Code.AssignLbl(lblEvalSecTerm,Code.GetCurAddr);
        CmpPrimary(rtype,cf);
        GenConvAndAddCode(ResType,Code,rtype,cf);
        Code.AssignLbl(lblSkipSecTerm,Code.GetCurAddr);
        if not EqualTypeSimple4(ResType) then SyntaxError.Create('"and" is applicable only to integer or boolean operands');
        away:=FALSE;
      end else begin
        CmpPrimary(rtype,cf);
        GenConvAndAddCode(ResType,Code,rtype,cf);
        if EqualTypeSimple4(ResType) then Code.GenInstr(ANDI)
        else raise SyntaxError.Create('"and" is applicable only to integer or boolean operands');
        away:=FALSE;
      end;
    end;
  until away;
end;

procedure CmpSimpleExpr(var ResType:TType;var Code:TCodeFragment);
var away:boolean;
    rtype:TType;
    cf:TCodeFragment;
    lblEvalSecTerm,lblSkipSecTerm:longint;
begin
  CmpTerm(ResType,Code);
  repeat
    away:=TRUE;
    if TestAndEatTokenSymbol('+') then begin
      cf:=nil;
      CmpTerm(rtype,cf);
      GenConvAndAddCode(ResType,Code,rtype,cf);
      if EqualTypes(ResType,DefInt) then Code.GenInstr(ADDI)
      else if EqualTypes(ResType,DefFloat) then Code.GenInstr(ADDF)
      else if EqualTypes(ResType,DefString) then Code.GenCall(DefStrConcate)
      else raise SyntaxError.Create('"+" is applicable only to integer, float or string operands');
      away:=FALSE;
    end else if TestAndEatTokenSymbol('-') then begin
      cf:=nil;
      CmpTerm(rtype,cf);
      GenConvAndAddCode(ResType,Code,rtype,cf);
      if EqualTypes(ResType,DefInt) then Code.GenInstr(SUBI)
      else if EqualTypes(ResType,DefFloat) then Code.GenInstr(SUBF)
      else raise SyntaxError.Create('"-" is applicable only to integer or float operands');
      away:=FALSE;
    end else if TestAndEatTokenAlpha('or') then begin
      cf:=nil;
      {if first term was a boolean, then short-circuit boolean evaluation is needed }
      if EqualTypes(ResType, DefBool) then begin
        NewLabel(lblEvalSecTerm);
        NewLabel(lblSkipSecTerm);
        Code.GenInstrJmp(JZ,lblEvalSecTerm);
        Code.GenInstr(PUSHO);
        Code.GenInstrJmp(JMP,lblSkipSecTerm);
        Code.AssignLbl(lblEvalSecTerm,Code.GetCurAddr);
        CmpTerm(rtype,cf);
        GenConvAndAddCode(ResType,Code,rtype,cf);
        Code.AssignLbl(lblSkipSecTerm,Code.GetCurAddr);
        if not EqualTypeSimple4(ResType) then SyntaxError.Create('"or" is applicable only to integer or boolean operands');
        away:=FALSE;
      end else begin
        CmpTerm(rtype,cf);
        GenConvAndAddCode(ResType,Code,rtype,cf);
        if EqualTypeSimple4(ResType) then Code.GenInstr(ORI)
        else raise SyntaxError.Create('"or" is applicable only to integer or boolean operands');
        away:=FALSE;
      end;
    end else if TestAndEatTokenAlpha('xor') then begin
      cf:=nil;
      CmpTerm(rtype,cf);
      GenConvAndAddCode(ResType,Code,rtype,cf);
      if EqualTypeSimple4(ResType) then Code.GenInstr(XORI)
      else raise SyntaxError.Create('"xor" is applicable only to integer or boolean operands');
      away:=FALSE;
    end;
  until away;
end;

procedure CmpExpression(var ResType:TType;var Code:TCodeFragment);
var CompareOp:integer;
    rtype2:TType;
    cf:TCodeFragment;
begin
  CmpSimpleExpr(ResType,Code);
  CompareOp:=CompareOps.IndexOf(cur_str);   {is it an comparison? }
  if (cur_token=TTSymbol) and (CompareOp>=0) then begin
    GetToken;
    cf:=nil;
    CmpSimpleExpr(rtype2,cf);
    GenConvAndAddCode(ResType,Code,rtype2,cf);
    if EqualTypeSimple4(ResType) then Code.GenInstr(TInstruction(chr(ord(CIE)+CompareOp))) else
    if EqualTypes(ResType,DefFloat) then Code.GenInstr(TInstruction(chr(ord(CFE)+CompareOp))) else
    if EqualTypes(ResType,DefString) then begin
      Code.GenCall(DefStrCompare);
      Code.GenInstrPushI(0);
      Code.GenInstr(TInstruction(chr(ord(CIE)+CompareOp)))
    end else raise SyntaxError.Create('comparing is applicable only to integer, float, boolean or string operands');
    ResType:=DefBool;
  end;
end;

//this basically computes address of an variable and store it at top of stack
//variable can be an item of an array, an item of a record, and combination of these
//if it is local variable, it then converts variable local address to "global address"
procedure CmpVarAddr(var t:TType;var Code:TCodeFragment);
var was_array,loc,away:boolean;
    str:string;
    p:TPrgItem;
    st:TType;
    ofs:longint;
begin
  was_array:=false;
  if not EatIdentifier(str,'a identifier of variable') then
  else if not FindItem(str,p,loc,'a identifier of variable') then
  else if not (p is TVariable) then raise SyntaxError.Create('a identifier of variable expected, but "'+str+'" is a '+p.GetItemClass)
  else begin
    t:=(p as TVariable).VarType;
    ofs:=(p as TVariable).Addr;
    repeat
      away:=true;
      if (t is TArray) and TestAndEatTokenSymbol('[') then begin
        CmpExpression(st,Code);
        if not EqualTypes(st,DefInt) then raise SyntaxError.Create('array index must be integer');
        Code.GenInstr(ARRACC);
        GenArrayInfoAddr(t as TArray,Code);
        if was_array then Code.GenInstr(ADDI) else was_array:=true;
        EatTokenSymbol(']');
        t:=(t as TArray).ItemType;
        away:=false;
      end;
      if (t is TRecord) and TestAndEatTokenSymbol('.') then begin
        if not TestIdentifier then raise SyntaxError.Create('a identifier of record item expected, but '+GetTokenDescr+' found')
        else if not (t as TRecord).Items.FindItem(cur_str,p,'a identifier of record item') then
        else if not (p is TVariable) then raise InternalError.Create('vyskytla sa metoda...')
        else begin
          GetToken; {identifier}
          ofs:=ofs+(p as TVariable).Addr;
          t:=(p as TVariable).VarType;
          away:=false;
        end;
      end;
    until away;
    if Code=nil then Code:=TCodeFragment.Create;
    if loc then Code.GenInstrPushLocalToGlobalAddr(ofs) else Code.GenInstrPushI(ofs);
    if was_array then Code.GenInstr(ADDI);
  end;
end;

procedure CmpBoolExpr(var Code:TCodeFragment;LblTrue,LblFalse:longint);
var rtype:TType;
begin
  CmpExpression(rtype,Code);
  if rtype.Size <> 4 then SyntaxError.Create('operand length must be 4 bytes') else
  begin
    Code.GenInstrJmp(JNZ,LblTrue);
    Code.GenInstrJmp(JMP,LblFalse);
  end;
end;


(*

not needed anymore - it was bad grammar anyway - it couldn't compile "if ((a and b)=0) then" (a,b are numbers) }


procedure CmpBoolPrimary(var Code:TCodeFragment;LblTrue,LblFalse:longint);
var rtype:TType;
begin
  if TestAndEatTokenAlpha('true') then begin
    if Code=nil then Code:=TCodeFragment.Create;
    Code.GenInstrJmp(JMP,LblTrue);
  end else if TestAndEatTokenAlpha('false') then begin
    if Code=nil then Code:=TCodeFragment.Create;
    Code.GenInstrJmp(JMP,LblFalse);
  end else if TestAndEatTokenAlpha('not') then
    CmpBoolPrimary(Code,LblFalse,LblTrue)
  else if TestAndEatTokenSymbol('(') then begin
    CmpBoolExpr(Code,LblTrue,LblFalse);
    EatTokenSymbol(')');
  end else begin
    CmpExpression(rtype,Code);
    if rtype.Size <> 4 then SyntaxError.Create('operand length must be 4 bytes') else
    begin
      Code.GenInstrJmp(JNZ,LblTrue);
      Code.GenInstrJmp(JMP,LblFalse);
    end;
  end;
end;


procedure CmpBoolTerm(var Code:TCodeFragment;LblTrue,LblFalse:longint);
var cf:TCodeFragment;
    LblTmp:longint;
begin
  NewLabel(LblTmp);
  CmpBoolPrimary(Code,LblTmp,LblFalse);
  while TestAndEatTokenAlpha('and') do begin
    Code.AssignLbl(LblTmp,Code.GetCurAddr);
    cf:=nil;
    NewLabel(LblTmp);
    CmpBoolPrimary(cf,LblTmp,LblFalse);
    Code.AddCodeFragment(cf);
  end;
  Code.AssignLblToLbl(LblTmp,LblTrue);
end;

procedure CmpBoolExpr_orig(var Code:TCodeFragment;LblTrue,LblFalse:longint);
var cf:TCodeFragment;
    LblTmp:longint;
begin
  NewLabel(LblTmp);
  CmpBoolTerm(Code,LblTrue,LblTmp);
  while TestAndEatTokenAlpha('or') do begin
    Code.AssignLbl(LblTmp,Code.GetCurAddr);
    cf:=nil;
    NewLabel(LblTmp);
    CmpBoolTerm(cf,LblTrue,LblTmp);
    Code.AddCodeFragment(cf);
  end;
  Code.AssignLblToLbl(LblTmp,LblFalse);
end;


*)

end.
