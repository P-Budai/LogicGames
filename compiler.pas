unit compiler;

//tøídy reprezentující objekty pøekládaného programu (datové typy, promìnné, procedury, funkce
//dále high-level procedury vlastního pøekladaèe i bìhu programu a obèerstvování zobrazení promìnných

interface

uses sysutils,classes;

type InternalError = class(Exception);
     SyntaxError=class(Exception);
     RuntimeError=class(Exception);

     Float=double;

     TPrgItem = class(TObject)
       function GetItemClass:string; virtual;
     end;

     TPrgItemList = class;

     TType = class(TPrgItem)
       Size:longint;
       function GetItemClass:string; override;
       function ValToStr(p:pointer):string; virtual;
     end;

     TArray = class(TType)
       MinIndex,MaxIndex,ItemSize:longint;
       ItemType:TType;
       function ValToStr(p:pointer):string; override;
     end;

     TRecord = class(TType)
       Items:TPrgItemList;
       constructor Create;
       destructor Destroy; override;
       function ValToStr(p:pointer):string; override;
     end;

     TListType = class(TType)
       ItemType:TType;
       function ValToStr(p:pointer):string; override;
     end;

     TString = class(TType)
       function ValToStr(p:pointer):string; override;
     end;

     TBool = class(TType)
       function ValToStr(p:pointer):string; override;
     end;

     TVariable = class(TPrgItem)
       Addr:longint;
       VarType:TType;
       function GetItemClass:string; override;
     end;

     TProcedure = class;
     TLibProc = function(info:TProcedure;data:longint):longint;

     TParam = record
                ParType:TType;
                ParData:pointer;
              end;

     TProcedure = class(TPrgItem)
       Params:TPrgItemList;
       ParamsCount,ParamsSize,
       LineFrom,LineTo,
       CodeOfs:longint;
       Ident:string;
       LibProc:TLibProc;
       constructor Create;
       constructor CreateLib(p:TLibProc;name:string);
       destructor Destroy; override;
       function GetItemClass:string; override;
       procedure DefParameter(t:TType);
       procedure AddObject(l:TPrgItemList);
       procedure PrepareParams; virtual;
       function GetRealParams(data:longint;var par:array of TParam):longint;
       function GetFixedParams(data:longint;var pars):longint;
     end;

     TFunction = class(TProcedure)
       constructor CreateLib(p:TLibProc;name:string;res:TType);
       function GetItemClass:string; override;
       procedure PrepareParams; override;
       procedure DefResult(t:TType);
     end;

     TPrgItemList = class(TStringList)
     public
       LastVar:longint;
       constructor Create;
       function FindProc(line:longint):TProcedure;
       function FindItem(ident:string;var prgitem:TPrgItem;dscr:string):boolean;
       function GetDataSize:longint;
       procedure Display(StrList:TStrings;Addr:pointer);
       procedure AddVar(name:string;v:TVariable);
     end;

procedure Compile(Src:PChar);
procedure FreeComp;
procedure Exec(procname:string;var paramsdata;paramssize:longint);
procedure Step;
procedure Next;
procedure RunPrg;
procedure SetBreakpoint(l:longint;b:boolean);
procedure RefreshWatches;
procedure DefSystemPositionObjects;
function NewString(s:string):longint;

var
    DefInt,DefBool,DefFloat,DefString,DefList,DefVariant,DefPosition:TType;
    DefStrConcate:TProcedure;
    DefStrCompare:TProcedure;
    CompareOps:TStringList;
    Globals:TPrgItemList;
    WatchCallOfs:longint;
    Watches:TStringList;
    Compiled,Running:boolean;

implementation

uses windows,forms,utils,sntx,gener,debug,dbgwin,expr,navig,lib,lex, System.Generics.Collections, StrUtils;

var
    Errors:TStringList;
    Warnings:TStringList;

procedure RefreshWatches;
var prgsave:TPrgMemSpace;
    watchcode:TCodeFragment;
    i:integer;
    s:string;
    rtype:TType;
    p:TProcedure;
begin
  if Watches.Count=0 then exit;

  prgsave:=Prg;
  p:=Globals.FindProc(Prg.StopLine);
  if p=nil then Locals:=TPrgItemList.Create else Locals:=p.Params;
  for i:=0 to Watches.Count-1 do begin
    s:=Watches[i]+#0;
    lex.Src:=PChar(s);
    lex.cur_line:=0;
    Errors.Clear;
    Warnings.Clear;
    watchcode:=nil;
    try
      GetToken;
      watchcode:=TCodeFragment.Create;
      watchcode.GenLine;  {need this to populate  watchcode.Code.Memory}
      WatchCallOfs:=longint(prgsave.CodeAddr)-longint(watchcode.Code.Memory);
      CmpExpression(rtype,watchcode);
      watchcode.GenInstr(QUIT);

      watchcode.Code.SaveToFile('watch_'+IntToStr(i)+'.bin');
      watchcode.DebugDisplay('watch_'+IntToStr(i)+'.txt',PChar(s));

      if Errors.Count=0 then begin
        Prg.SetCode(watchcode);
        Prg.LineBreak:=0;
        Prg.Run();
        s:=Watches[i]+': ';
        if Prg.ExitCode<>ERRQUIT then s:=s+ErrDescr[Prg.ExitCode]
        else s:=s+rtype.ValToStr(PtrAdd(Prg.LocalStack,-rtype.Size));
        DebugWin.LstWatches.Items[i]:=s;
      end;
    except
      on E:Exception do DebugWin.LstWatches.Items[i]:=Watches[i]+': '+E.Message;
    end;
    watchcode.Free;
  end;

  Prg:=prgsave;
  if p=nil then Locals.Free;
end;

procedure RefreshAutoWatch;
var p:TProcedure;
begin
  DebugWin.LstAutoWatch.Items.Clear;
  p:=Globals.FindProc(Prg.StopLine);
  if p<>nil then begin
    DebugWin.LstAutoWatch.Items.Add('*** Locals ***');
    p.Params.Display(DebugWin.LstAutoWatch.Items,Prg.LocalFrame);
  end;
  DebugWin.LstAutoWatch.Items.Add('*** Globals ***');
  Globals.Display(DebugWin.LstAutoWatch.Items,Prg.GlobAddr);
end;

procedure UpdatePrgState;
begin
  if Running then begin
    if Prg.ExitCode in [ERRBOUNDS,ERROVERFLOW,ERRLINEBREAK,ERRUSERBREAK,ERRNOTIMPL,ERRSTACKOVF] then begin
      DebugWin.Show;
      DebugWin.SelectLine(Prg.StopLine);
      //DebugWin.Caption:='Debug Window - ' + ErrDescr[Prg.ExitCode];
    end;

    if (DebugWin.Visible) and (Prg.ExitCode<>ERRQUIT) then begin
      DebugWin.Caption:='Debug Window - ' + ErrDescr[Prg.ExitCode];
      RefreshWatches;
      RefreshAutoWatch;
    end;

    if Prg.ExitCode in [ERRQUIT,ERRBOUNDS,ERROVERFLOW,ERRNOTIMPL,ERRBADSYS,ERRSTACKOVF]
      then Running:=false;

  end else begin
    DebugWin.SrcCode.SelLength:=0;
    if Compiled then DebugWin.Caption:='Debug Window - compiled'
    else DebugWin.Caption:='Debug Window - not compiled'
  end;

  DebugWin.UpdateControls;
  Navigator.UpdateControls;
end;

procedure DefSystemObjects;
var p:TProcedure;
begin
  Globals.AddObject('integer',DefInt);
  Globals.AddObject('bool',DefBool);
  Globals.AddObject('float',DefFloat);
  Globals.AddObject('string',DefString);

  DefStrConcate:=TProcedure.CreateLib(lib.StrConcate,'StrConcate');
  DefStrConcate.DefParameter(DefString);
  DefStrConcate.DefParameter(DefString);
  DefStrConcate.AddObject(Globals);

  DefStrCompare:=TProcedure.CreateLib(lib.StrCompare,'StrCompare');
  DefStrCompare.DefParameter(DefString);
  DefStrCompare.DefParameter(DefString);
  DefStrCompare.AddObject(Globals);

  p:=TFunction.CreateLib(lib.StrIntInt_Str,'SubStr',DefString);
  p.DefParameter(DefString);
  p.DefParameter(DefInt);
  p.DefParameter(DefInt);
  p.AddObject(Globals);

  p:=TFunction.CreateLib(lib.Int_Str,'IntToStr',DefString);
  p.DefParameter(DefInt);
  p.AddObject(Globals);

  p:=TFunction.CreateLib(lib.Float_Int,'round',DefInt);
  p.DefParameter(DefFloat);
  p.AddObject(Globals);

  p:=TFunction.CreateLib(lib.Float_Int,'trunc',DefInt);
  p.DefParameter(DefFloat);
  p.AddObject(Globals);

  (*
  p:=TProcedure.CreateLib(lib.int3,'DrawBoard');
  p.DefParameter(DefInt);
  p.DefParameter(DefInt);
  p.DefParameter(DefInt);
  p.AddObject(Globals);

  p:=TProcedure.CreateLib(lib.int3,'DrawPiece');
  p.DefParameter(DefInt);
  p.DefParameter(DefInt);
  p.DefParameter(DefInt);
  p.AddObject(Globals);
  *)

  p:=TProcedure.CreateLib(lib.DrawStrIntInt,'DrawBitmap');
  p.DefParameter(DefString);
  p.DefParameter(DefInt);
  p.DefParameter(DefInt);
  p.AddObject(Globals);

  p:=TProcedure.CreateLib(lib.DrawStrIntInt,'DrawText');
  p.DefParameter(DefString);
  p.DefParameter(DefInt);
  p.DefParameter(DefInt);
  p.AddObject(Globals);

  p:=TFunction.CreateLib(lib.IntInt_Int,'Min',DefInt);
  p.DefParameter(DefInt);
  p.DefParameter(DefInt);
  p.AddObject(Globals);

  p:=TFunction.CreateLib(lib.IntInt_Int,'Max',DefInt);
  p.DefParameter(DefInt);
  p.DefParameter(DefInt);
  p.AddObject(Globals);

  p:=TFunction.CreateLib(lib.Int_Int,'Sgn',DefInt);
  p.DefParameter(DefInt);
  p.AddObject(Globals);

  p:=TFunction.CreateLib(lib.Int_Int,'Abs',DefInt);
  p.DefParameter(DefInt);
  p.AddObject(Globals);

  p:=TFunction.CreateLib(lib.Int_Int,'Bit',DefInt);
  p.DefParameter(DefInt);
  p.AddObject(Globals);

  p:=TFunction.CreateLib(lib.Int_Int,'Rnd',DefInt);
  p.DefParameter(DefInt);
  p.AddObject(Globals);

  p:=TFunction.CreateLib(lib.FloatFloat_Float,'Minf',DefFloat);
  p.DefParameter(DefFloat);
  p.DefParameter(DefFloat);
  p.AddObject(Globals);

  p:=TFunction.CreateLib(lib.FloatFloat_Float,'Maxf',DefFloat);
  p.DefParameter(DefFloat);
  p.DefParameter(DefFloat);
  p.AddObject(Globals);

  p:=TFunction.CreateLib(lib.Float_Float,'Sgnf',DefFloat);
  p.DefParameter(DefFloat);
  p.AddObject(Globals);

  p:=TFunction.CreateLib(lib.Float_Float,'Absf',DefFloat);
  p.DefParameter(DefFloat);
  p.AddObject(Globals);

  p:=TFunction.CreateLib(lib.Float_Float,'Rndf',DefFloat);
  p.DefParameter(DefFloat);
  p.AddObject(Globals);

  p:=TProcedure.CreateLib(lib.List1,'Init');
  p.DefParameter(DefVariant);
  {??? ako sa to priradi}
  p.AddObject(Globals);

  p:=TProcedure.CreateLib(lib.List1,'Free');
  p.DefParameter(DefVariant);
  p.AddObject(Globals);
  {
  p:=TProcedure.CreateLib(lib.list1variant1,'Append');
  p.DefParameter(DefVariant);
  p.DefParameter(DefVariant);
  p.AddObject(Globals);
  }

  DefPosition:=nil;
end;

procedure DefSystemPositionObjects;
var p:TProcedure;
begin
  p:=TProcedure.CreateLib(lib.newmove,'NewMove');
  p.DefParameter(DefPosition);
  p.DefParameter(DefString);
  p.DefParameter(DefFloat);
  p.AddObject(Globals);
end;


//Compile creates compiled code and also program objects (types, variables, procedures)
procedure Compile(Src:PChar);
var linetab:PLineFlags;
begin
  FreeComp;

  Globals:=TPrgItemList.Create;

  lex.Src:=Src;
  lex.cur_line:=0;
  Errors.Clear;
  Warnings.Clear;
  gener.LabelCnt:=0;
  WatchCallOfs:=0;

  Code:=TCodeFragment.Create;

  try
    DefSystemObjects;
    CmpModule;
    {vygenerujem este quit, tam sa vratia neskor volane procedury}
    Code.GenInstr(QUIT);
  except
    DebugWin.SelectLine(lex.cur_line);
    DebugWin.Visible:=true;
    Code.Code.SaveToFile('output.bin');
    Code.DebugDisplay('output.txt',Src);
    Globals.Free;
    raise;
  end;

  Code.Code.SaveToFile('output.bin');
  Code.DebugDisplay('output.txt',Src);

  Compiled:=Errors.Count=0;

  if not Compiled then FreeComp
  else begin
    Prg.CreateMemSpace(Globals.GetDataSize,1024*128);
    GetMem(linetab,lex.cur_line*sizeof(TLineFlags));
    FillMemory(linetab,lex.cur_line*sizeof(TLineFlags),0);
    Prg.SetCode(Code);
    Prg.SetLineTable(lex.cur_line,linetab);
  end;
  UpdatePrgState;
end;

procedure WriteLineTable();
var f:text;
    i:integer;
    p:PLineFlags;
begin
  AssignFile(f,'LineHistogram.csv');
  Rewrite(f);
  p:=Prg.LineTable;
  for i:=1 to Prg.LineCount-1 do begin
    inc(p);
    writeln(f,i,';',p.Hits,';"',AnsiReplaceStr(DebugWin.SrcCode.Lines[i],'"','""'),'"');
  end;
  close(f);
end;

procedure FreeComp;
begin
  Running:=false;
  if Compiled then begin
    Log(INFO,'Runtime','Destroying program memory space, code, globals');
    WriteLineTable();
    Prg.DestroyMemSpace;
    Code.Free;
    Globals.Free;
    Compiled:=false;
  end;
end;

procedure RunWhileRunning;
begin
  RunPrg;
  repeat
    Application.ProcessMessages;
{    WaitMessage;}
  until not Running;
end;


//Runs program to a next line of source code (traces into procedures)
//Sets LineBreak=1 and then executes pcode
procedure Step;
begin
  if not Compiled or not Running then exit;
  Prg.LineBreak:=1;
  Prg.Returns:=0;
  Prg.Run();
  UpdatePrgState;
end;

//Runs program to a next line of source code (steps over procedures)
//Sets LineBreak=1 and then executes pcode until not in same procedure
procedure Next;
begin
  if not Compiled or not Running then exit;
  Prg.LineBreak:=1;
  Prg.Returns:=0;
  repeat
    Prg.Run();
  until (Prg.ExitCode<>ERRLINEBREAK) or (Prg.Returns<=0);
  UpdatePrgState;
end;

procedure SetBreakpoint(l:longint;b:boolean);
var i:integer;
    p:PLineFlags;
begin
  p:=Prg.LineTable;
  if l>=Prg.LineCount then exit;
  inc(p,l);
  if b then p^.Flags:=1 else p^.Flags:=0;
end;

function IsBreakpoint(l:longint):boolean;
var i:integer;
    p:PLineFlags;
begin
  result:=false;
  p:=Prg.LineTable;
  if l>=Prg.LineCount then exit;
  inc(p,l);
  result:=(p^.Flags=1);
end;

procedure SetBreakpoints;
var i:integer;
    p:PLineFlags;
begin
  p:=Prg.LineTable;
  for i := 0 to Prg.LineCount-1 do begin
    if (pos('#break#',DebugWin.GetPrgText.Strings[i])>0) then
      p^.Flags:=1
    else
      p^.Flags:=0;
    inc(p);
  end;
end;

//Runs program
//When debug window is not visible, it runs pcode until QUIT or any ERROR occurs
//When debug window is visible, it checks at every line if it is a breakpoint on that line
procedure RunPrg;
begin
  if not Compiled or not Running then exit;

{
  if DebugWin.Visible then begin
    Prg.LineBreak:=1;
  end else Prg.LineBreak:=0;
}
  SetBreakpoints();

  Prg.ExitCode:=ERRREADY;
  repeat
    Prg.Run();
  until (Prg.ExitCode<>ERRLINEBREAK) or IsBreakpoint(Prg.StopLine);
  Application.ProcessMessages;

  UpdatePrgState;
end;

//
procedure Exec(procname:string;var paramsdata;paramssize:longint);
var p:TPrgItem;
    q:longint;
    prevstack,previnstrptr:pointer;
begin
  Log(INFO,'Runtime','Executing proc:'+procname);
  if not Compiled then raise InternalError.Create('program is not compiled');
  if Running then exit; {!!raise InternalError.Create('program is already running');}

  Globals.FindItem(procname,p,'the procedure or function "'+procname+'"');
  if not (p is TProcedure) then raise RuntimeError.Create('the "'+procname+'" must be procedure or function')
  else begin
    {ulozim si adresu zasobniku a instrukcie}
    prevstack:=Prg.LocalStack;
    previnstrptr:=Prg.InstrPtr;
    {vlozim parametre na zasobnik}
    if paramssize<>0 then Prg.Push(paramsdata,paramssize);
    {vypocitam navratovu adresu...adresa instrukcie quit}
    q:=longint(Prg.CodeAddr)+Code.Code.Size-1;
    Prg.Push(q,sizeof(q)); {vlozim ju na zasobnik return addr}
    {nastavim adresu vykonavanej instrukcie na zaciatok procedury}
    Prg.InstrPtr:=PtrAdd(Prg.CodeAddr,(p as TProcedure).CodeOfs);
    {spustim to}
    Running:=true;
    RunWhileRunning;
    {skopirujem si naspat parametre}
    if paramssize<>0 then Move(prevstack^,paramsdata,paramssize);
    {obnovim zasobnik a ip}
    Prg.LocalStack:=prevstack;
    Prg.InstrPtr:=previnstrptr;
//    if Prg.ExitCode<>ERRQUIT then raise InterpretError.Create('any error occurs by interpreting code');
  end;

end;

constructor TPrgItemList.Create;
begin
  inherited Create;
  LastVar:=-1;
end;

function TPrgItemList.FindItem(ident:string;var prgitem:TPrgItem;dscr:string):boolean;
var ind:longint;
begin
  ind:=IndexOf(ident);
  Result:=ind<>-1;
  if Result then prgitem:=Objects[ind] as TPrgItem
  else if dscr<>'' then raise SyntaxError.Create(dscr + ' expected, but "'+ident+'" is not defined')
end;

function TPrgItemList.FindProc(line:longint):TProcedure;
var i:integer;
begin
  for i:=0 to Count-1 do
    if Objects[i] is TProcedure then begin
      Result:=Objects[i] as TProcedure;
      if IIR(line,Result.LineFrom,Result.LineTo) then exit;
    end;
  Result:=nil;
end;

function TPrgItemList.GetDataSize:longint;
var v:TVariable;
begin
  if LastVar=-1 then Result:=0
  else begin
    v:=Objects[LastVar] as TVariable;
    Result:=v.Addr+v.VarType.Size;
  end;
end;

procedure TPrgitemList.AddVar(name:string;v:TVariable);
begin
  if LastVar=-1 then v.Addr:=0
  else v.Addr:=(Objects[LastVar] as TVariable).Addr+
               (Objects[LastVar] as TVariable).VarType.Size;
  LastVar:=AddObject(name,v);
end;

procedure TPrgItemList.Display(StrList:TStrings;Addr:pointer);
var i:integer;
    v:TVariable;
begin
  for i:=0 to Count-1 do
    if GetObject(i) is TVariable then begin
      v:=GetObject(i) as TVariable;
      if (Strings[i]<>'_ReturnAddr') and (Strings[i]<>'_PrevFrame')
        then StrList.Add(Strings[i]+':'+v.VarType.ValToStr(PtrAdd(Addr,v.Addr)));
    end;
end;

function TPrgItem.GetItemClass:string;
begin
  GetItemClass:='program item';
end;

function TType.GetItemClass:string;
begin
  GetItemClass:='type';
end;

function TType.ValToStr(p:pointer):string;
begin
  if Size = sizeof(longint) then Result:=IntToStr(longint(p^)) else
  if Size = sizeof(float) then Result:=FloatToStr(float(p^)) else
  raise InternalError.Create('variable is''nt integer nor float');
end;

constructor TRecord.Create;
begin
  inherited Create;
  Items:=TPrgItemList.Create;
end;

destructor TRecord.Destroy;
begin
  Items.Free;
  inherited Destroy;
end;

function TRecord.ValToStr(p:pointer):string;
var s:TStringList;
    i:longint;
begin
  Result:='(';
  s:=TStringList.Create;
  Items.Display(s,p);
  for i:=0 to s.Count-1 do begin
    if length(Result)>1 then Result:=Result+'; ';
    Result:=Result+s[i];
  end;
  s.Free;
  Result:=Result+')';
end;

function TVariable.GetItemClass:string;
begin
  GetItemClass:='variable';
end;

function TArray.ValToStr(p:pointer):string;
var i:longint;
begin
  Result:='['+IntToStr(MinIndex)+':'+IntToStr(MaxIndex)+'](';
  for i:=MinIndex to MaxIndex do begin
    if i>MinIndex then Result:=Result+'; ';
    Result:=Result+ItemType.ValToStr(PtrAdd(p,(i-MinIndex)*ItemSize));
  end;
  Result:=Result+')';
end;

function TListType.ValToStr(p:pointer):string;
var i:longint;
    l:TList;
begin
  l:=TList(p^);
  if (l=nil) or not (l is TList) then Result:=''
  else begin
    Result:='(';
    for i:=0 to l.Count-1 do begin
      if length(Result)>1 then Result:=Result+'; ';
      Result:=Result+ItemType.ValToStr(l.Items[i]);
    end;
    Result:=Result+')';
  end;
end;

function TString.ValToStr(p:pointer):string;
begin
  if longint(p^)=0 then Result:=''''''
  else Result:=''''+lib.GetString(longint(p^))+'''';
end;

function TBool.ValToStr(p:pointer):string;
begin
  if longint(p^)<>0 then Result:='true' else Result:='false'; 
end;

constructor TProcedure.Create;
begin
  inherited Create;
  Params:=TPrgItemList.Create;
  LibProc:=nil;
end;

constructor TProcedure.CreateLib(p:TLibProc;name:string);
begin
  inherited Create;
  Params:=TPrgItemList.Create;
  LibProc:=p;
  Ident:=name;
end;

destructor TProcedure.Destroy;
begin
  Params.Free;
  inherited Destroy;
end;

function TProcedure.GetItemClass:string;
begin
  GetItemClass:='procedure';
end;

procedure TProcedure.DefParameter(t:TType);
var v:TVariable;
begin
  v:=TVariable.Create;
  v.VarType:=t;
  if Params.LastVar=-1 then v.Addr:=0
  else v.Addr:=(Params.Objects[Params.LastVar] as TVariable).Addr+
               (Params.Objects[Params.LastVar] as TVariable).VarType.Size;
  Params.LastVar:=Params.AddObject('Par'+inttostr(Params.Count),v);
end;

procedure TFunction.DefResult(t:TType);
var v:TVariable;
begin
  v:=TVariable.Create;
  v.VarType:=t;
  v.Addr:=-v.VarType.Size;
  params.InsertObject(0,'Result',v);
  inc(params.LastVar);
end;

procedure TProcedure.PrepareParams;
var v:TVariable;
    s,i:longint;
begin
  {zapisem si pocet a velkost parametrov}
  ParamsCount:=Params.Count;
  ParamsSize:=Params.GetDataSize;
  if @LibProc=nil then begin
    {pridam navratovu adresu a pointer na predch. frame}
    v:=TVariable.Create;
    v.VarType:=DefInt;
    Params.AddVar('_ReturnAddr',v);
    v:=TVariable.Create;
    v.VarType:=DefInt;
    Params.AddVar('_PrevFrame',v);
  end;
  {posuniem adresy vsetkych parametrov tak, aby lokalne prem. zacinali na 0}
  s:=Params.GetDataSize;
  for i:=0 to Params.Count-1 do
    if Params.Objects[i] is TVariable then dec((Params.Objects[i] as TVariable).Addr,s);
end;

procedure TProcedure.AddObject(l:TPrgItemList);
begin
  PrepareParams;
  l.AddObject(Ident,self);
end;

function TProcedure.GetRealParams(data:longint;var par:array of TParam):longint;
var i:longint;
    addr:longint;
    t:TType;
begin
  if high(par) <> ParamsCount-1 then raise InternalError.Create('bad numbers of real params in system procedure');
  addr:=data;
  for i:=ParamsCount-1 downto 0 do begin
    t:=(Params.Objects[i] as TVariable).VarType;
    if t=DefVariant then begin
      addr:=addr-4;
      t:=TType(pointer(pointer(addr)^));
    end;
    par[i].ParType:=t;
    addr:=addr-t.size;
    par[i].ParData:=pointer(addr);
  end;
  Result:=ParamsSize;
end;

function TProcedure.GetFixedParams(data:longint;var pars):longint;
begin
  Result:=ParamsSize;
  pointer(pars):=pointer(data+(Params.Objects[0] as TVariable).Addr);
end;

constructor TFunction.CreateLib(p:TLibProc;name:string;res:TType);
var v:TVariable;
begin
  inherited CreateLib(p,name);
  v:=TVariable.Create;
  v.VarType:=res;
  v.Addr:=-v.VarType.Size;
  Params.LastVar:=Params.AddObject('Result',v);
end;

function TFunction.GetItemClass:string;
begin
  GetItemClass:='function';
end;

procedure TFunction.PrepareParams;
begin
  inherited PrepareParams;
  {odpocitam vysledok}
  dec(ParamsCount);
  {velkost vysledku tam uz nieje zahrnuta}
end;

function NewString(s:string):longint;
begin
  result:=lib.NewString(s);
end;

begin
  Errors:=TStringList.Create;
  Warnings:=TStringList.Create;
  Running:=false;
  Compiled:=false;

  DefInt:=TType.Create;
  DefInt.size:=sizeof(longint);

  DefBool:=TBool.Create;
  DefBool.size:=sizeof(longint);
  DefFloat:=TType.Create;
  DefFloat.size:=sizeof(Float);
  DefString:=TString.Create;
  DefString.size:=sizeof(longint);

  DefList:=TType.Create;
  DefList.size:=sizeof(longint);
  DefVariant:=TType.Create;
  DefVariant.size:=sizeof(longint);

  CompareOps:=TStringList.Create;
  CompareOps.Add('=');
  CompareOps.Add('<>');
  CompareOps.Add('<');
  CompareOps.Add('<=');
  CompareOps.Add('>');
  CompareOps.Add('>=');

  Watches:=TStringList.Create;
end.
