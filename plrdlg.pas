unit plrdlg;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  ComCtrls, StdCtrls, Mask;

type
  TDlgPlayer = class(TForm)
    GroupBox1: TGroupBox;
    Player1: TPageControl;
    Human: TTabSheet;
    Computer: TTabSheet;
    Label1: TLabel;
    Player1Name: TEdit;
    BtnOk: TButton;
    BtnCancel: TButton;
    Player1Level: TComboBox;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Player1Descr: TEdit;
    Player1Depth: TEdit;
    Player1Degree: TEdit;
    GroupBox2: TGroupBox;
    Player2: TPageControl;
    TabSheet1: TTabSheet;
    Label2: TLabel;
    Player2Name: TEdit;
    TabSheet2: TTabSheet;
    Label7: TLabel;
    Label8: TLabel;
    Label9: TLabel;
    Label10: TLabel;
    Player2Level: TComboBox;
    Player2Descr: TEdit;
    Player2Depth: TEdit;
    Player2Degree: TEdit;
    procedure FormShow(Sender: TObject);
    procedure BtnOkClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  DlgPlayer: TDlgPlayer;

implementation

uses navig;

{$R *.DFM}

procedure TDlgPlayer.FormShow(Sender: TObject);
begin
  with Players[1] do begin
    Player1.ActivePage:=Player1.Pages[1-ord(human)];
    Player1Name.Text:=name;
    Player1Level.Text:=level.name;
    Player1Degree.Text:=IntToStr(level.degree);
    Player1Depth.Text:=IntToStr(level.depth);
    Player1Descr.Text:=level.descr;
  end;

  with Players[2] do begin
    Player2.ActivePage:=Player1.Pages[1-ord(human)];
    Player2Name.Text:=name;
    Player2Level.Text:=level.name;
    Player2Degree.Text:=IntToStr(level.degree);
    Player2Depth.Text:=IntToStr(level.depth);
    Player2Descr.Text:=level.descr;
  end;
end;

procedure TDlgPlayer.BtnOkClick(Sender: TObject);
begin
  with Players[1] do begin
    human:=Player1.ActivePage=Player1.Pages[0];
    name:=Player1Name.Text;
    level.name:=Player1Level.Text;
    level.degree:=StrToInt(Player1Degree.Text);
    level.depth:=StrToInt(Player1Depth.Text);
    level.descr:=Player1Descr.Text;
  end;

  with Players[2] do begin
    human:=Player2.ActivePage=Player2.Pages[0];
    name:=Player2Name.Text;
    level.name:=Player2Level.Text;
    level.degree:=StrToInt(Player2Degree.Text);
    level.depth:=StrToInt(Player2Depth.Text);
    level.descr:=Player2Descr.Text;
  end;
end;

end.
