unit dbgwin;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics,
  Controls, Forms, Dialogs, StdCtrls, ExtCtrls, Menus;

type
  TDebugWin = class(TForm)
    SrcCode: TMemo;
    PnlButtons: TPanel;
    BtnStep: TButton;
    BtnRun: TButton;
    BtnBreak: TButton;
    Splitter1: TSplitter;
    WatchPopup: TPopupMenu;
    Edit1: TMenuItem;
    New1: TMenuItem;
    Remove1: TMenuItem;
    N1: TMenuItem;
    Up1: TMenuItem;
    Down1: TMenuItem;
    Autowatch1: TMenuItem;
    LstWatches: TListBox;
    LstAutoWatch: TListBox;
    Splitter2: TSplitter;
    BtnNext: TButton;
    BtnFind: TButton;
    EdFind: TComboBox;
    procedure FormDestroy(Sender: TObject);
    procedure BtnStepClick(Sender: TObject);
    procedure BtnRunClick(Sender: TObject);
    procedure SrcCodeExit(Sender: TObject);
    procedure BtnBreakClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);

    procedure EditWatch(Sender: TObject);
    procedure NewWatch(Sender: TObject);
    procedure RemoveWatch(Sender: TObject);
    procedure UpWatch(Sender: TObject);
    procedure DownWatch(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure BtnNextClick(Sender: TObject);
    procedure BtnFindClick(Sender: TObject);
    procedure FormHide(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    procedure SelectLine(nr:integer);
    procedure UpdateControls;
    function GetPrgText:TStrings;
  end;

function FindLineOffset(const txt:string;nr:longint):longint;
function FindLine(const txt:string;ofs:longint):longint;
function GetLineByNr(txt:PChar;nr:longint):string;

var
  DebugWin: TDebugWin;

implementation

uses WatchDlg,Compiler,Navig, utils;

const TABCHAR=#9;

{$R *.DFM}

//Returns char offset of a text where line number nr begins
function FindLineOffset(const txt:string;nr:longint):longint;
begin
  result:=1;
  while nr>0 do begin
    while ((txt[result] <> #0) and (txt[result] <> #10)) do inc(result);
    if txt[result] = #0 then exit;
    inc(result);
    dec(nr);
  end;
end;

//Returns nth line of a text
function GetLineByNr(txt:PChar;nr:longint):string;
var strlist:TStringList;
begin
  strlist:=TStringList.Create;
  strlist.Text:=txt;
  result:=strlist[nr];
  strlist.Free;
end;

//Returns the line number of the line which contains char at given offset
function FindLine(const txt:string;ofs:longint):longint;
var i:longint;
begin
  result:=0;
  i:=1;
  while i<ofs do begin
    if (txt[i]=#13) then inc(result);
    inc(i);
  end;
end;

procedure ProcessLine(var s:string);
begin
  if (pos(TABCHAR,s)<>1) and (pos('#break#'+TABCHAR,s)<>1) then s:=TABCHAR+s;
end;

procedure ProcessText(Lines:TStrings);
var i:integer;
    s:string;
    lin:TStringList;
begin
  lin:=TStringList.Create;
  lin.Text:=Lines.Text;
  for i:=0 to Lin.Count-1 do begin
    s:=Lin[i];
    ProcessLine(s);
    Lin[i]:=s;
  end;
  Lines.Text:=lin.Text;
  lin.Free;
end;

procedure TDebugWin.SelectLine(nr:integer);
begin
  SrcCode.SelStart:=FindLineOffset(SrcCode.Text,nr);
  SrcCode.SelLength:=FindLineOffset(SrcCode.Text,nr+1)-SrcCode.SelStart-1;
end;

procedure TDebugWin.UpdateControls;
begin
  BtnStep.Enabled:=Running;
  BtnNext.Enabled:=Running;
  BtnRun.Enabled:=Running;
end;

function TDebugWin.GetPrgText:TStrings;
begin
  Result:=SrcCode.Lines;
end;

procedure TDebugWin.FormDestroy(Sender: TObject);
begin
  FreeComp;
end;

procedure TDebugWin.BtnStepClick(Sender: TObject);
begin
  Step;
end;

procedure TDebugWin.BtnRunClick(Sender: TObject);
begin
  RunPrg;
end;

procedure TDebugWin.BtnNextClick(Sender: TObject);
begin
  Compiler.Next;
end;

procedure TDebugWin.BtnFindClick(Sender: TObject);
var i:longint;
begin
  if EdFind.ItemIndex=-1 then EdFind.Items.Add(EdFind.Text);
  i:=pos(UpperCase(EdFind.Text),UpperCase(copy(SrcCode.Text,SrcCode.SelStart+2,64000)));
  if i>0 then begin SrcCode.SelStart:=SrcCode.SelStart+i; SrcCode.SelLength:=length(EdFind.Text) end
  else begin
    i:=pos(UpperCase(EdFind.Text),UpperCase(SrcCode.Text));
    if i>0 then begin SrcCode.SelStart:=i-1; SrcCode.SelLength:=length(EdFind.Text) end
  end;
end;

procedure TDebugWin.SrcCodeExit(Sender: TObject);
var l:longint;
begin
  l:=FindLine(SrcCode.Text,SrcCode.SelStart);
  ProcessText(SrcCode.Lines);
  SrcCode.SelStart:=FindLineOffset(SrcCode.Text,l);
end;

procedure TDebugWin.BtnBreakClick(Sender: TObject);
var l:longint;
    s:string;
begin
  l:=FindLine(SrcCode.Text,SrcCode.SelStart);
  s:=SrcCode.Lines[l];
  if pos('#break#',s)=1 then s:=copy(s,8,255) else s:='#break#'+s;
  SrcCode.Lines[l]:=s;
end;

procedure TDebugWin.FormCreate(Sender: TObject);
begin
  ProcessText(SrcCode.Lines);
end;

procedure TDebugWin.EditWatch(Sender: TObject);
var i:integer;
begin
  i:=LstWatches.ItemIndex;
  if i<>-1 then begin
    DlgWatchProp.CBWatchExpr.Text:=Watches[i];
    if DlgWatchProp.ShowModal=mrOK then begin
      Watches[i]:=DlgWatchProp.CBWatchExpr.Text;
      LstWatches.Items[i]:=DlgWatchProp.CBWatchExpr.Text;
    end;
  end;
  Compiler.RefreshWatches;
end;

procedure TDebugWin.NewWatch(Sender: TObject);
var i:integer;
begin
  if DlgWatchProp.ShowModal=mrOK then begin
    i:=max(0,LstWatches.Items.Count);
    Watches.Add(DlgWatchProp.CBWatchExpr.Text);
    LstWatches.Items.Add(DlgWatchProp.CBWatchExpr.Text);
    LstWatches.ItemIndex:=i;
  end;
  Compiler.RefreshWatches;
end;

procedure TDebugWin.RemoveWatch(Sender: TObject);
var i:integer;
begin
  i:=LstWatches.ItemIndex;
  if i<>-1 then begin
    Watches.Delete(LstWatches.ItemIndex);
    LstWatches.Items.Delete(LstWatches.ItemIndex);
    LstWatches.ItemIndex:=min(i,LstWatches.Items.Count-1);
  end;
end;

procedure TDebugWin.UpWatch(Sender: TObject);
var f,t:longint;
begin
  f:=LstWatches.ItemIndex;
  t:=max(0,f-1);
  if t=f then exit;
  Watches.Exchange(f,t);
  LstWatches.Items.Exchange(f,t);
  LstWatches.ItemIndex:=t;
end;

procedure TDebugWin.DownWatch(Sender: TObject);
var f,t:longint;
begin
  f:=LstWatches.ItemIndex;
  t:=min(LstWatches.Items.Count-1,f+1);
  if t=f then exit;
  Watches.Exchange(f,t);
  LstWatches.Items.Exchange(f,t);
  LstWatches.ItemIndex:=t;
end;

procedure TDebugWin.FormShow(Sender: TObject);
begin
  UpdateControls;
end;

procedure TDebugWin.FormHide(Sender: TObject);
begin
  if Navigator<>nil then Navigator.UpdateControls;
end;

end.
