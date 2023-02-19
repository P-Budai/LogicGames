unit RulesWin;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ComCtrls;

type
  TRules = class(TForm)
    EdRules: TRichEdit;
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    procedure SetReadOnly(b:boolean);
  end;

var
  Rules: TRules;

implementation

uses navig;

{$R *.DFM}

procedure TRules.SetReadOnly(b:boolean);
begin
  EdRules.ReadOnly:=b;
end;

procedure TRules.FormCreate(Sender: TObject);
var s:string;
begin
  if paramcount=1 then s:=paramstr(1) else s:='default.def';
  try
    Navig.Navigator.LoadGameDefinition(s);
  except
    on E:Exception do begin
      s:='Error reading definition file '+s;
      Application.MessageBox(@s[1],'ERROR',MB_APPLMODAL or MB_ICONERROR or MB_OK);
    end;
  end;
end;

end.
