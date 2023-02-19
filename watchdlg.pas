unit watchdlg;

interface

uses Windows, SysUtils, Classes, Graphics, Forms, Controls, StdCtrls, 
  Buttons;

type
  TDlgWatchProp = class(TForm)
    OKBtn: TButton;
    CancelBtn: TButton;
    CBWatchExpr: TComboBox;
    Label1: TLabel;
    procedure OKBtnClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  DlgWatchProp: TDlgWatchProp;

implementation

{$R *.DFM}

procedure TDlgWatchProp.OKBtnClick(Sender: TObject);
begin
  CBWatchExpr.Items.Add(CBWatchExpr.Text);
end;

procedure TDlgWatchProp.FormShow(Sender: TObject);
begin
  CBWatchExpr.SetFocus;
end;

end.
 
