unit ResltWin;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls;

type
  TResultWin = class(TForm)
    Result: TLabel;
    Button1: TButton;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  ResultWin: TResultWin;

implementation

{$R *.DFM}

end.
