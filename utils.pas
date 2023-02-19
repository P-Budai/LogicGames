unit utils;

interface

function Min(a,b:longint):longint; overload;
function Max(a,b:longint):longint; overload;
function Min(a,b:double):double; overload;
function Max(a,b:double):double; overload;
function IIR(x,b,e:longint):boolean;
function PtrAdd(p:pointer;ofs:longint):pointer;

type TLogSeverity=(DEBUG,INFO,WARN,ERROR,FATAL);
procedure Log(sev:TLogSeverity;facility:string;msg:string);

implementation

function Min(a,b:longint):longint;
begin if a<b then Result:=a else Result:=b end;

function Max(a,b:longint):longint;
begin if a>b then Result:=a else Result:=b end;

function Min(a,b:double):double;
begin if a<b then Result:=a else Result:=b end;

function Max(a,b:double):double;
begin if a>b then Result:=a else Result:=b end;

function IIR(x,b,e:longint):boolean;
begin Result:=(b<=x) and (x<=e); end;

function PtrAdd(p:pointer;ofs:longint):pointer;
begin
  Result:=pointer(longword(p)+ofs);
end;

var flog:text;
var sev_text:array[TLogSeverity] of string;

procedure Log(sev:TLogSeverity;facility:string;msg:string);
begin
  writeln(flog,sev_text[sev],': ',facility,': ',msg);
  flush(flog);
end;

begin
  sev_text[DEBUG]:='DEBUG';
  sev_text[INFO]:='INFO';
  sev_text[WARN]:='WARN';
  sev_text[ERROR]:='ERROR';
  sev_text[FATAL]:='FATAL';

  AssignFile(flog,'log.txt');
  Rewrite(flog);
  Log(INFO,'utils','Log initialization');
end.
