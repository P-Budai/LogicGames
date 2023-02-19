program diplomka;

uses
  Forms,
  dbgwin in 'dbgwin.pas' {DebugWin},
  lex in 'lex.pas',
  compiler in 'compiler.pas',
  sntx in 'sntx.pas',
  gener in 'gener.pas',
  debug in 'debug.pas',
  expr in 'expr.pas',
  watchdlg in 'watchdlg.pas' {DlgWatchProp},
  lib in 'lib.pas',
  plrdlg in 'plrdlg.pas' {DlgPlayer},
  crc in 'crc.pas',
  RulesWin in 'RulesWin.pas' {Rules},
  about in 'about.pas' {AboutBox},
  optdlg in 'optdlg.pas' {OptionDlg},
  ResltWin in 'ResltWin.pas' {ResultWin},
  navig in 'navig.pas' {Navigator},
  utils in 'utils.pas',
  sorting in 'sorting.pas';

{$R *.RES}

begin
  Application.Initialize;
  Application.CreateForm(TNavigator, Navigator);
  Application.CreateForm(TDebugWin, DebugWin);
  Application.CreateForm(TDlgWatchProp, DlgWatchProp);
  Application.CreateForm(TDlgPlayer, DlgPlayer);
  Application.CreateForm(TRules, Rules);
  Application.CreateForm(TAboutBox, AboutBox);
  Application.CreateForm(TOptionDlg, OptionDlg);
  Application.CreateForm(TResultWin, ResultWin);
  Application.Run;
end.
