unit optdlg;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls;

type
  TOptionDlg = class(TForm)
    Button1: TButton;
    Button2: TButton;
    GroupBox1: TGroupBox;
    CheckBox1: TCheckBox;
    CheckBox2: TCheckBox;
    CheckBox3: TCheckBox;
    procedure FormShow(Sender: TObject);
    procedure Button1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  OptionDlg: TOptionDlg;

implementation

uses navig;

{$R *.DFM}

procedure TOptionDlg.FormShow(Sender: TObject);
begin
  CheckBox1.Checked:=AutoPlay;
  CheckBox2.Checked:=ShowCompMove;
  CheckBox3.Checked:=AutoSave;
end;

procedure TOptionDlg.Button1Click(Sender: TObject);
begin
  AutoPlay:=CheckBox1.Checked;
  ShowCompMove:=CheckBox2.Checked;
  AutoSave:=CheckBox3.Checked;
end;

end.
