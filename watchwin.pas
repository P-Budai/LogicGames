unit watchwin;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, Menus,Compiler,WatchDlg, ExtCtrls;

type
  TFrmWatches = class(TForm)
    WatchPopup: TPopupMenu;
    Remove1: TMenuItem;
    Up1: TMenuItem;
    Down1: TMenuItem;
    New1: TMenuItem;
    Edit1: TMenuItem;
    N1: TMenuItem;
    LstWatches: TListBox;
    Splitter1: TSplitter;
    LstAutoWatch: TListBox;
    Autowatch1: TMenuItem;
    procedure NewWatch(Sender: TObject);
    procedure RemoveWatch(Sender: TObject);
    procedure UpWatch(Sender: TObject);
    procedure DownWatch(Sender: TObject);
    procedure Edit1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  FrmWatches: TFrmWatches;

implementation

{$R *.DFM}

procedure TFrmWatches.Edit1Click(Sender: TObject);
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
end;

procedure TFrmWatches.NewWatch(Sender: TObject);
var i:integer;
begin
  if DlgWatchProp.ShowModal=mrOK then begin
    i:=max(0,LstWatches.Items.Count);
    Watches.Add(DlgWatchProp.CBWatchExpr.Text);
    LstWatches.Items.Add(DlgWatchProp.CBWatchExpr.Text);
    LstWatches.ItemIndex:=i;
  end;
end;

procedure TFrmWatches.RemoveWatch(Sender: TObject);
var i:integer;
begin
  i:=LstWatches.ItemIndex;
  if i<>-1 then begin
    Watches.Delete(LstWatches.ItemIndex);
    LstWatches.Items.Delete(LstWatches.ItemIndex);
    LstWatches.ItemIndex:=min(i,LstWatches.Items.Count-1);
  end;
end;

procedure TFrmWatches.UpWatch(Sender: TObject);
var f,t:longint;
begin
  f:=LstWatches.ItemIndex;
  t:=max(0,f-1);
  if t=f then exit;
  Watches.Exchange(f,t);
  LstWatches.Items.Exchange(f,t);
  LstWatches.ItemIndex:=t;
end;

procedure TFrmWatches.DownWatch(Sender: TObject);
var f,t:longint;
begin
  f:=LstWatches.ItemIndex;
  t:=min(LstWatches.Items.Count-1,f+1);
  if t=f then exit;
  Watches.Exchange(f,t);
  LstWatches.Items.Exchange(f,t);
  LstWatches.ItemIndex:=t;
end;

end.
