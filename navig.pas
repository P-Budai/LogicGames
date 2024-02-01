unit navig;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  Gauges, StdCtrls, Menus, Vcl.Buttons, Vcl.ExtCtrls;

const maxlevels=20;

type

  TLongintArray=array[0..10000] of longint;

  TMove=class(TCollectionItem)
  public
    Data:pointer;
    Name:string;
    Gama:double;
    AlphaBeta:double;
    ComputedLevel:longint;
    NextMoves:TCollection;
    SortArray:^TLongintArray;
    Generated,Played:boolean;
    //OnMove:boolean;  //false=player one, true=player two
    constructor Create(Collection: TCollection); override;
    destructor Destroy; override;
    procedure SetData(d:pointer;n:string;t:double);
    procedure Generate;
    procedure FreeNextMoves(depth:integer);
    procedure ComputeAlphaBeta(level,degree,depth:integer;a,b:double);
    function ComputeMovesToCheck:integer;
    function InvertSort(i:longint):longint;
  end;

  TNavigator = class(TForm)
    GrpNewMove: TGroupBox;
    LstVariants: TListBox;
    GrpHistory: TGroupBox;
    LstHistory: TListBox;
    BtnGo: TButton;
    BtnBack: TButton;
    Label1: TLabel;
    LblPlayerName: TLabel;
    Label4: TLabel;
    LblPlayerTime: TLabel;
    Label2: TLabel;
    LblAlphaBeta: TLabel;
    GroupBox2: TGroupBox;
    Gauge1: TGauge;
    Gauge2: TGauge;
    Gauge3: TGauge;
    Gauge4: TGauge;
    MainMenu: TMainMenu;
    Rules: TMenuItem;
    Game: TMenuItem;
    MnuLoadGameDefinition: TMenuItem;
    MnuSaveGameDefinition: TMenuItem;
    MnuViewGameRules: TMenuItem;
    MnuSetPlayers: TMenuItem;
    MnuSaveGame: TMenuItem;
    MnuLoadGame: TMenuItem;
    N1: TMenuItem;
    N2: TMenuItem;
    MnuStartGame: TMenuItem;
    MnuStopGame: TMenuItem;
    N3: TMenuItem;
    Development: TMenuItem;
    MnuShowDefinition: TMenuItem;
    MnuEditGameRules: TMenuItem;
    Label3: TLabel;
    LblGama: TLabel;
    DlgOpenDef: TOpenDialog;
    DlgSaveDef: TSaveDialog;
    Help1: TMenuItem;
    MnuViewREADME: TMenuItem;
    N4: TMenuItem;
    MnuAbout: TMenuItem;
    N5: TMenuItem;
    MnuOptions: TMenuItem;
    N6: TMenuItem;
    MnuStep: TMenuItem;
    MnuNext: TMenuItem;
    MnuRun: TMenuItem;
    N7: TMenuItem;
    MnuFind: TMenuItem;
    MnuToggleBreakpoint: TMenuItem;
    ImgGameState: TImage;
    N8: TMenuItem;
    procedure MnuStartGameClick(Sender: TObject);
    procedure MnuStopGameClick(Sender: TObject);
    procedure MnuShowDefinitionClick(Sender: TObject);
    procedure LstClick(Sender: TObject);
    procedure MnuSetPlayersClick(Sender: TObject);
    procedure BtnGoClick(Sender: TObject);
    procedure BtnBackClick(Sender: TObject);
    procedure MnuEditGameRulesClick(Sender: TObject);
    procedure MnuViewGameRulesClick(Sender: TObject);
    procedure MnuLoadGameDefinitionClick(Sender: TObject);
    procedure MnuSaveGameDefinitionClick(Sender: TObject);
    procedure MnuAboutClick(Sender: TObject);
    procedure MnuViewREADMEClick(Sender: TObject);
    procedure MnuOptionsClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure MnuStepClick(Sender: TObject);
    procedure MnuNextClick(Sender: TObject);
    procedure MnuRunClick(Sender: TObject);
    procedure MnuFindClick(Sender: TObject);
    procedure MnuToggleBreakpointClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure ImgGameStateMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure MnuSaveGameClick(Sender: TObject);
    procedure MnuLoadGameClick(Sender: TObject);
  private
    procedure DisplayMove(Sender:TObject);
    procedure RunGame;
    procedure NewMove(m:TMove);
  public
    procedure LoadGameDefinition(fname:string);
    procedure SaveGameDefinition(fname:string);
    procedure UpdateControls;
    procedure RefreshHistoryLst;
    procedure RefreshVariantsLst;
    procedure SetProgressMax(depth,maxvalue:longint);
    procedure SetProgress(depth,value:longint);
    procedure GameWinClick(Shift:TShiftState;x,y:integer);
    procedure SetGameImgSize(w,h:longint);
    procedure ExpandGameImgSize(w,h:longint);
  end;

  TLevel=record
    name:string[20];
    descr:string;
    depth,degree:integer;
  end;

  TLevels=record
    count:integer;
    items:array[1..maxlevels] of TLevel;
  end;

  TPlayers=array[1..2] of record
      Human:boolean;
      name:string[20];
      level:TLevel;
  end;

var Navigator:TNavigator;
    CurMove:TMove;
    Levels:TLevels;
    AutoPlay,ShowCompMove,AutoSave:boolean;
    Players:TPlayers;

const infinity:double=1.7e300;

implementation

{$R *.DFM}

uses contnrs, dbgwin,plrdlg,lib,sorting,ruleswin,about,shellapi,optdlg,
  ResltWin, utils, compiler;

var GameRunning,Computing:boolean;
    StartPositions:TMove;
    History:TObjectList;
    OnMove:integer;  //who must move: 1-first player, 2-second player

procedure TNavigator.UpdateControls;
var b:boolean;
begin
  MnuLoadGameDefinition.Enabled:=not GameRunning;
  MnuSetPlayers.Enabled:=not GameRunning;
  MnuStartGame.Enabled:=not GameRunning;
  MnuStopGame.Enabled:=GameRunning;
  {MnuLoadGame.Enabled:=not GameRunning;
  MnuSaveGame.Enabled:=GameRunning and not Computing;}

  b:=GameRunning and not Computing and (LstHistory.ItemIndex=LstHistory.Items.Count-1) and (LstVariants.ItemIndex>=0);
  if BtnGo.Enabled <> b then BtnGo.Enabled:=b;

  b:=GameRunning and (History.Count>1) and not Computing;
  if BtnBack.Enabled <> b then BtnBack.Enabled:=b;

  b:=GameRunning and not Computing;
  if LstVariants.Enabled <> b then BtnBack.Enabled:=b;

  b:=GameRunning and not Computing;
  if LstHistory.Enabled <> b then BtnBack.Enabled:=b;

  MnuStep.Enabled:=Compiler.Running and DebugWin.Visible;
  MnuNext.Enabled:=Compiler.Running and DebugWin.Visible;
  MnuRun.Enabled:=Compiler.Running and not Computing;
  MnuToggleBreakpoint.Enabled:=(DebugWin<>nil) and DebugWin.Visible;
  MnuFind.Enabled:=(DebugWin<>nil) and DebugWin.Visible;
end;

procedure TNavigator.RefreshHistoryLst;
var i:longint;
begin
  LstHistory.Clear;
  for i:=0 to History.Count-1 do
    LstHistory.Items.Add(IntToStr(i)+':'+(History.Items[i] as TMove).Name);
  if History.Count>0 then LstHistory.ItemIndex:=History.Count-1;
  RefreshVariantsLst;
end;

procedure TNavigator.RefreshVariantsLst;
var m:TMove;
    i:longint;
begin
  LstVariants.Clear;
  if History.Count=0 then exit;
  m:=History.Items[LstHistory.ItemIndex] as TMove;
  for i:=0 to m.NextMoves.Count-1 do
    LstVariants.Items.Add((m.NextMoves.Items[i] as TMove).Name);
end;

procedure TNavigator.FormCreate(Sender: TObject);
begin
  with Levels do begin
    count:=1;
    items[1].name:='Default';
    items[1].descr:='Default level';
    items[1].depth:=2;
    items[1].degree:=10;
  end;
  Players[1].Human:=true;
  Players[1].Name:='Player 1';
  Players[1].Level:=Levels.items[1];

  Players[2].Human:=false;
  Players[2].Name:='Player 2';
  Players[2].Level:=Levels.items[1];

  AutoPlay:=true;
  ShowCompMove:=false;
  AutoSave:=true;
  GameRunning:=false;
  Computing:=false;
  InitLibrary;

  ImgGameState.Picture.Bitmap.Canvas.Font:=self.Font;
  ImgGameState.Picture.Bitmap.Canvas.CopyMode:=cmSrcCopy;
  ImgGameState.Picture.Bitmap.PixelFormat:=pfDevice;

end;

procedure TNavigator.FormShow(Sender: TObject);
begin
  UpdateControls;
end;

procedure TNavigator.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if AutoSave then SaveGameDefinition('default.def');
end;

procedure TNavigator.MnuStartGameClick(Sender: TObject);
begin
  if AutoSave then SaveGameDefinition('default.def');
  History.Free;
  SetGameImgSize(1,1);
  self.Repaint;
  ResetLibrary;
  Compiler.FreeComp;
  try
    Compiler.Compile(PChar(DebugWin.SrcCode.Text));
  except
      on E: Exception do begin
          Dialogs.MessageDlg(E.Message, mtInformation, [mbOk], 0, mbOk);
      end;
  end;
  if not Compiled then exit;

  if not IsPositiveResult(DlgPlayer.ShowModal) then exit;

  try
    GameRunning:=true;
    OnMove:=1;
    History:=TObjectList.Create;
    History.OwnsObjects:=false;
    StartPositions:=TMove.Create(nil);
    RefreshHistoryLst;
    Computing:=true;
    UpdateControls;
    StartPositions.Generate;
    Computing:=false;
    UpdateControls;
    if StartPositions.NextMoves.Count=1 then NewMove(StartPositions.NextMoves.Items[0] as TMove);
    RunGame;
  except
    Compiler.FreeComp;
    GameRunning:=false;
    Computing:=false;
    raise;
  end;
end;

procedure TNavigator.NewMove(m:TMove);
begin
  History.Add(m);
  m.Played:=true;
  OnMove:=3-OnMove;
  if not m.Generated then begin
    Computing:=true;
    UpdateControls;
    m.Generate;
    Computing:=false;
    UpdateControls;
  end;
  RefreshHistoryLst;
  DisplayMove(LstHistory);
  if m.NextMoves.Count=0 then begin
    if m.Gama=0 then ResultWin.Result.Caption:='Draw Game !'
    else if m.Gama>0 then ResultWin.Result.Caption:=Players[OnMove].name+' wins !'
    else ResultWin.Result.Caption:=Players[3-OnMove].name+' wins !';
    ResultWin.ShowModal;
    //GameRunning:=false;
  end else begin
    if History.Count>1 then begin
      //OnMove:=3-OnMove;
      (History.Items[History.Count-2] as TMove).FreeNextMoves(1);
    end;
  end;
  UpdateControls;
end;

procedure TNavigator.RunGame;
var m:TMove;
    i:integer;
begin
  while GameRunning and (Players[OnMove].Human=false) and (History.Count>0) do begin
    m:=History.Last as TMove;
    if m.NextMoves.Count=0 then exit;    
    Computing:=true;
    UpdateControls;
    m.ComputeAlphaBeta(Players[OnMove].level.depth,Players[OnMove].level.degree,1,-infinity,infinity);
    Computing:=false;
    UpdateControls;
    if not GameRunning then exit;
    i:=0; while (m.NextMoves.Items[m.SortArray^[i]] as TMove).AlphaBeta <> -m.AlphaBeta do inc(i);
    m:=m.NextMoves.Items[m.SortArray^[i]] as TMove;
    NewMove(m);
  end;
end;

procedure TNavigator.BtnGoClick(Sender: TObject);
{LstHistory je nastavene na posledny tah,LstVariants na vybranu variantu}
var m:TMove;
begin
  if History.Count=0 then begin
    m:=StartPositions;
  end else begin
    m:=History.Items[LstHistory.ItemIndex] as TMove;
  end;
  m:=m.NextMoves.Items[LstVariants.ItemIndex] as TMove;
  NewMove(m);
  RunGame;
end;

procedure TNavigator.MnuStopGameClick(Sender: TObject);
begin
  GameRunning:=false;
  FreeComp;
  UpdateControls;
  StartPositions.Free;
end;

procedure TNavigator.BtnBackClick(Sender: TObject);
begin
  History.Delete(History.Count-1);
  OnMove:=3-OnMove;
  RefreshHistoryLst;
  UpdateControls;
  LstHistory.ItemIndex:=LstHistory.Items.Count-1;
  DisplayMove(LstHistory);
end;

procedure TNavigator.MnuShowDefinitionClick(Sender: TObject);
begin
  DebugWin.Show;
  UpdateControls;
end;

procedure TNavigator.DisplayMove(Sender:TObject);
var m:TMove;
    f:float;
begin
  if not (Sender is TListBox) then exit;
  m:=History.Items[LstHistory.ItemIndex] as TMove;
  if Sender=LstVariants then begin
    m:=m.NextMoves.Items[LstVariants.ItemIndex] as TMove;
  end else begin
    RefreshVariantsLst;
  end;

  if odd(LstHistory.ItemIndex) then f:=1 else f:=-1;

  LblGama.Caption:=FloatToStr(f*m.Gama);
  LblAlphaBeta.Caption:=FloatToStr(f*m.AlphaBeta);
  Computing:=true;
  UpdateControls;
  Compiler.Exec('DisplayPosition',m.Data^,DefPosition.Size);
  Computing:=false;
  UpdateControls;
end;

procedure TNavigator.LstClick(Sender: TObject);
begin
  DisplayMove(Sender);
end;

procedure TNavigator.GameWinClick(Shift:TShiftState;x,y:integer);
var m:TMove;
    p:TMemoryStream;
    i,strid:longint;
begin
  if GameRunning and (LstHistory.ItemIndex>=0) and (LstHistory.ItemIndex=LstHistory.Items.Count-1) then begin
    m:=History.Items[LstHistory.ItemIndex] as TMove;
    strid:=0;
    p:=TMemoryStream.Create;
    try
      p.Write(strid,sizeof(strid));
      p.Write(m.Data^,DefPosition.Size);
      p.Write(x,DefInt.Size);
      p.Write(y,DefInt.Size);
      Compiler.Exec('GetPositionByMouse',p.Memory^,p.Size);
      p.Seek(0,soFromBeginning);
      p.Read(strid,sizeof(strid));
    finally
      p.Free;
    end;
    for i:=0 to m.NextMoves.Count-1 do
      if (m.NextMoves.Items[i] as TMove).Name=lib.GetString(strid) then begin
        LstVariants.ItemIndex:=i;
        DisplayMove(LstVariants);
        if AutoPlay then BtnGo.OnClick(self);
        exit;
      end;
  end;
end;

procedure TNavigator.ImgGameStateMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var scale:float;
begin
  with ImgGameState do begin
    scale:=max(Picture.Bitmap.Width/Width,Picture.Bitmap.Height/Height);
    GameWinClick(Shift,round(x*scale),round(y*scale));
  end;
end;

procedure TNavigator.MnuSetPlayersClick(Sender: TObject);
begin
  DlgPlayer.ShowModal;
end;

procedure TNavigator.SetProgressMax(depth,maxvalue:longint);
begin
  if maxvalue>1 then
    case depth of
      1: navigator.gauge1.maxvalue:=maxvalue;
      2: navigator.gauge2.maxvalue:=maxvalue;
      3: navigator.gauge3.maxvalue:=maxvalue;
      4: navigator.gauge4.maxvalue:=maxvalue;
    end;
end;

procedure TNavigator.SetProgress(depth,value:longint);
begin
  case depth of
    1: navigator.gauge1.progress:=value;
    2: navigator.gauge2.progress:=value;
    3: navigator.gauge3.progress:=value;
    4: navigator.gauge4.progress:=value;
  end;
end;


{********************** TMove ************************}

procedure Change(ptr:pointer;i,j:longint);
var l:longint;
begin
  with TMove(ptr) do begin
    l:=SortArray^[i]; SortArray^[i]:=SortArray^[j]; SortArray^[j]:=l;
  end;
end;

function Compare(ptr:pointer;i,j:longint):boolean;
begin
  with TMove(ptr) do begin
    Result:=(NextMoves.Items[SortArray^[i]] as TMove).AlphaBeta
           <(NextMoves.Items[SortArray^[j]] as TMove).AlphaBeta;
           {<..asceding  >..desceding}
  end;
end;

procedure TMove.Generate;
var i:longint;
begin
  if not Generated then begin
    if NextMoves.Count>0 then raise InternalError.Create('Non-generated move has already next moves !');
    CurMove:=self;
    if self=StartPositions
      then Compiler.Exec('GenerStartPositions',nil^,0)
      else Compiler.Exec('GenerPositions',Data^,DefPosition.Size);
    if not GameRunning then exit;
    GetMem(SortArray,NextMoves.Count*sizeof(longint));
    Generated:=true;
  end;
  ComputedLevel:=0;
  AlphaBeta:=Gama;
  if NextMoves.Count=0 then begin
    if Gama>0 then AlphaBeta:=infinity else
    if Gama<0 then AlphaBeta:=-infinity
  end else for i:=0 to NextMoves.Count-1 do begin
    (NextMoves.Items[i] as TMove).AlphaBeta:=(NextMoves.Items[i] as TMove).Gama;         //TODO: je to nutne?
    SortArray^[i]:=i;
  end;
end;


procedure test(var m:float);
var s:string;
begin
  if (m<>infinity) and (m<>-infinity) and (m<>round(m)) then begin
    s:=FloatToStr(m);
    s:=s+' ';
  end;
end;

function TMove.ComputeMovesToCheck:integer;
begin
  Generate;
  QuickSort(self,0,NextMoves.Count-1,Change,Compare);
  {
  i:=4;
  while (i+1<NextMoves.Count) and
        ((NextMoves.Items[i] as TMove).Gama/2 < (NextMoves.Items[i+1] as TMove).Gama)
     do inc(i);
  }
  Result:=NextMoves.Count;
end;

var stoplevel:integer=4;

procedure TMove.ComputeAlphaBeta;
var i:longint;
    m:double;
    moveschecked:longint;
    pm:TMove;
label exit_proc;
begin
  if level<=ComputedLevel then exit;
  moveschecked:=min(ComputeMovesToCheck,degree)-1;
  if moveschecked<0 then exit;
  if level=1 then m:=-(NextMoves.Items[SortArray^[0]] as TMove).AlphaBeta
  else
  begin
    Navigator.SetProgressMax(depth,moveschecked);
    m:=a;
    for i:=0 to moveschecked do begin
      if not GameRunning then goto exit_proc;
      pm:=(NextMoves.Items[SortArray^[i]] as TMove);
      if ShowCompMove and (depth=1) then Compiler.Exec('DisplayPosition',pm.Data^,DefPosition.Size);
      Navigator.SetProgress(depth,i);
      pm.ComputeAlphaBeta(level-1,degree,depth+1,-b,-m);
      m:=Max(m,-pm.AlphaBeta);
      if m>=b then goto exit_proc;
    end;
exit_proc:
  end;
  ComputedLevel:=level;
  AlphaBeta:=m; {minf(maxf(a,m),b);}
end;

procedure TMove.FreeNextMoves(depth:integer);
var i:integer;
begin
  if Played then
    depth:=1;
  if depth<=0 then begin NextMoves.Clear; Generated:=false; FreeMem(SortArray); SortArray:=nil; end
  else for i:=0 to NextMoves.Count-1 do (NextMoves.Items[i] as TMove).FreeNextMoves(depth-1);
  Played:=false;
end;

procedure TMove.SetData(d:pointer;n:string;t:double);
begin
  GetMem(Data,DefPosition.Size);
  Move(d^,Data^,DefPosition.Size);
  Name:=n;
  Gama:=t;
  AlphaBeta:=t;
  ComputedLevel:=0;
  Generated:=false;
  SortArray:=nil;
  //OnMove:=player;
end;

constructor TMove.Create;
begin
  NextMoves:=TCollection.Create(TMove);
  ComputedLevel:=0;
  //if Collection=nil then OnMove:=false else OnMove:=not (Collection.Items[0] as TMove).OnMove;
  inherited;
end;

destructor TMove.Destroy;
begin
  NextMoves.Clear;
  NextMoves.Free;
  if Data<>nil then FreeMem(Data);
  if SortArray<>nil then FreeMem(SortArray);
  inherited Destroy;
end;

{
procedure TMove.Assign(src:TPersistent);
begin
  if not (src is TMove) then inherited Assign(src)
  else begin
    SetData((src as TMove).Data,(src as TMove).Name,(src as TMove).AlphaBeta);
    ComputedLevel:=(src as TMove).ComputedLevel;
  end;
end;
}

function TMove.InvertSort(i:longint):longint;
var ind:longint;
begin
  if SortArray=nil then Result:=i
  else begin
    for ind:=0 to NextMoves.Count-1 do
      if SortArray^[ind]=i then begin
        Result:=ind;
        exit;
      end;
    Result:=-1;
  end;
end;

procedure TNavigator.MnuEditGameRulesClick(Sender: TObject);
begin
  RulesWin.Rules.SetReadOnly(false);
  RulesWin.Rules.Visible:=true;
end;

procedure TNavigator.MnuViewGameRulesClick(Sender: TObject);
begin
  RulesWin.Rules.SetReadOnly(true);
  RulesWin.Rules.Visible:=true;
end;

procedure TNavigator.LoadGameDefinition(fname:string);
var s:TFileStream;
    r:TReader;
begin
  s:=TFileStream.Create(fname,fmOpenRead or fmShareDenyWrite);
  if s<>nil then
  try
    r:=TReader.Create(s,1024);
    try
      dbgwin.DebugWin.SrcCode.Lines.Text:=r.ReadString;
      RulesWin.Rules.EdRules.Lines.Text:=r.ReadString;
    finally
      r.Free;
    end;
  finally
    s.Free;
  end;
end;

procedure TNavigator.SaveGameDefinition(fname:string);
var s:TStream;
    w:TWriter;
begin
  s:=TFileStream.Create(fname,fmCreate or fmShareExclusive);
  try
    w:=TWriter.Create(s,1024);
    try
      w.WriteString(dbgwin.DebugWin.SrcCode.Lines.Text);
      w.WriteString(RulesWin.Rules.EdRules.Lines.Text);
    finally
      w.Free;
    end;
  finally
    s.Free;
  end;
end;

procedure TNavigator.MnuLoadGameClick(Sender: TObject);
begin
  {TODO: implement loading game state}
end;

procedure TNavigator.MnuLoadGameDefinitionClick(Sender: TObject);
begin
  if DlgOpenDef.Execute then LoadGameDefinition(DlgOpenDef.FileName);
end;

procedure TNavigator.MnuSaveGameClick(Sender: TObject);
begin
  {TODO: implement saving game state}
end;

procedure TNavigator.MnuSaveGameDefinitionClick(Sender: TObject);
begin
  if DlgSaveDef.Execute then SaveGameDefinition(DlgSaveDef.FileName);
end;

procedure TNavigator.MnuAboutClick(Sender: TObject);
begin
  About.AboutBox.Visible:=true;
end;

procedure TNavigator.MnuViewREADMEClick(Sender: TObject);
begin
  ShellExecute(self.Handle,'open','readme.doc','','',SW_MAXIMIZE);
end;

procedure TNavigator.MnuOptionsClick(Sender: TObject);
begin
  OptionDlg.ShowModal;
end;

procedure TNavigator.MnuStepClick(Sender: TObject);
begin
  DebugWin.BtnStep.OnClick(sender);
end;

procedure TNavigator.MnuNextClick(Sender: TObject);
begin
  DebugWin.BtnNext.OnClick(Sender);
end;

procedure TNavigator.MnuRunClick(Sender: TObject);
begin
  DebugWin.BtnRun.OnClick(Sender);
end;

procedure TNavigator.MnuFindClick(Sender: TObject);
begin
  DebugWin.BtnFind.OnClick(Sender);
end;

procedure TNavigator.MnuToggleBreakpointClick(Sender: TObject);
begin
  DebugWin.BtnBreak.OnClick(Sender);
end;

procedure TNavigator.SetGameImgSize(w,h:longint);
begin
  ImgGameState.Picture.Bitmap.Width:=w;
  ImgGameState.Picture.Bitmap.Height:=h;
end;

procedure TNavigator.ExpandGameImgSize(w,h:longint);
begin
  ImgGameState.Picture.Bitmap.Width:=max(ImgGameState.Picture.Bitmap.Width,w);
  ImgGameState.Picture.Bitmap.Height:=max(ImgGameState.Picture.Bitmap.Height,h);
end;


end.
