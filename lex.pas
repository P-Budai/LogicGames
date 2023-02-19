unit lex;

interface

uses SysUtils;

type TCharSet = set of char;
     TTokenType=(TTError,
                 TTEndFile,
                 TTAlphaNum,
                 TTInteger,
                 TTReal,
                 TTSymbol,
                 TTString);
     LexError = class(Exception);

const TokenName:array[TTokenType] of string=('error',
                                             'end of file',
                                             'word',
                                             'integer number',
                                             'real number',
                                             'symbol',
                                             'string');
      CSAlpha    = ['a'..'z','A'..'Z','_'];
      CSNum      = ['0'..'9'];
      CSAlphaNum = CSAlpha + CSNum;
      CSSymbols  = ['`','~','!','@','#','$','%','^','&','*','(',')','+','|','-','=','\','[',']','{','}',';','''',':','"',',','.','/','<','>','?'];
      CSNonGroupSyms = [',',';','(',')','[',']','"'];
      CSSpaces   = [' ',#9,#10,#13,'#','{','}'];

      Keywords=',def,as,type,array,of,record,end,proc,func,if,then,else,switch,for,to,downto,do,repeat,until,while,result,';

var cur_token:TTokenType;
    cur_str:string;
    cur_int:longint;
    cur_real:double;
    cur_pos:PChar;
    cur_line:longint;
    src:PChar;

function GetOneChar:char;
function GetWord(AcceptedChars:TCharSet):string;
function GetToken:TTokenType;
function EatToken(token:TTokenType):boolean;
function EatTokenStr(token:TTokenType;str:string):boolean;
function EatTokenSymbol(str:string):boolean;
function EatTokenAlpha(str:string):boolean;
function EatIdentifier(var ident:string;descr:string):boolean;
function EatInteger(var l:longint):boolean;
function TestAndEatTokenAlpha(str:string):boolean;
function TestAndEatTokenSymbol(str:string):boolean;
function TestAndEatIdentifier(var ident:string):boolean;
function TestTokenSymbol(str:string):boolean;
function TestTokenAlpha(str:string):boolean;
function TestIdentifier:boolean;

function GetTokenDescr:string;

implementation

function GetOneChar:char;
begin
  Result:=src^;
  if Result<>#0 then inc(src);
  if Result=#13 then inc(cur_line);
end;

function GetWord(AcceptedChars:TCharSet):string;
begin
  result:='';
  AcceptedChars:=AcceptedChars-[#0];
  while src^ in AcceptedChars do begin
    result:=result+src^;
    if src^='#' then begin            {preskocim preprocesor}
      GetOneChar;
      GetWord([#0..#255]-['#']);
    end else if src^='{' then begin   {preskocim komentare}
      GetOneChar;
      GetWord([#0..#255]-['}']);
    end;
    GetOneChar;
  end;
end;

procedure read_alphanum;
begin
  cur_token:=TTAlphaNum;
  cur_str:=GetWord(CSAlphaNum);
end;

procedure read_number;
var s:string;
    rescode:integer;
begin
  s:=GetWord(CSNum);
  if src^ in ['.','e','E'] then begin
    cur_token:=TTReal;
    s:=s+GetOneChar;
    if ((src-1)^ in ['e','E']) and (src^ in ['+','-']) then s:=s+GetOneChar;
    if not (src^ in CSNum) then raise LexError.Create('a digit expected');
    s:=s+GetWord(CSNum);
    val(s,cur_real,rescode);
  end else begin
    cur_token:=TTInteger;
    val(s,cur_int,rescode);
  end;
  if rescode<>0 then raise LexError.Create('bad format of number');
end;

procedure read_symbol;
begin
  cur_token:=TTSymbol;
  if src^ in CSNonGroupSyms
    then cur_str:=GetOneChar
    else cur_str:=GetWord(CSSymbols - CSNonGroupSyms);
end;

procedure read_string;
begin
  cur_token:=TTString;
  GetOneChar;
  cur_str:=GetWord([#0..#255] - ['"']);
  GetOneChar;
end;

function IsKeyword(str:string):boolean;
begin IsKeyword:=pos(','+str+',',Keywords)>0; end;

function GetTokenDescr:string;
begin
  case cur_token of
    TTAlphaNum:if IsKeyword(cur_str) then result:='keyword "'+cur_str+'"'
               else result:=TokenName[cur_token]+' "'+cur_str+'"';
    TTInteger: result:=TokenName[cur_token]+' "'+IntToStr(cur_int)+'"';
    TTReal:    result:=TokenName[cur_token]+' "'+FloatToStr(cur_real)+'"';
    TTSymbol:  result:=TokenName[cur_token]+' "'+cur_str+'"';
    TTString:  result:=TokenName[cur_token]+' "'+cur_str+'"';
    else result:=TokenName[cur_token];
  end;
end;

function GetToken:TTokenType;
begin
  GetWord(CSSpaces);                                   {preskocim medzery}
  cur_pos:=src;
  if src^ in CSAlpha then read_alphanum
  else if src^ in CSNum then read_number
  else if src^ = '"' then read_string
  else if src^ in CSSymbols then read_symbol
  else if src^ = #0 then cur_token:=TTEndFile
  else cur_token:=TTError;
  GetToken:=cur_token;
end;

function EatToken(token:TTokenType):boolean;
begin
  if cur_token <> token then
    raise LexError.Create(TokenName[token]+' expected, but '+TokenName[cur_token]+' found');
  GetToken;
  EatToken:=true;
end;

function EatTokenStr(token:TTokenType;str:string):boolean;
begin
  if cur_token <> token then
    raise LexError.Create(TokenName[token]+' "'+str+'" expected, but '+TokenName[cur_token]+' found')
  else if cur_str <> str then
    raise LexError.Create('"'+str+'"'+' expected, but '+'"'+cur_str+'"'+' found');
  GetToken;
  EatTokenStr:=true;
end;

function EatTokenSymbol(str:string):boolean;
begin
  if cur_token <> TTSymbol then
    raise LexError.Create(TokenName[TTSymbol]+' "'+str+'" expected, but '+TokenName[cur_token]+' found')
  else if cur_str <> str then
    raise LexError.Create('"'+str+'"'+' expected, but '+'"'+cur_str+'"'+' found');
  GetToken;
  Result:=true;
end;

function EatTokenAlpha(str:string):boolean;
begin
  if cur_token <> TTAlphaNum then
    raise LexError.Create(TokenName[TTAlphaNum]+' "'+str+'" expected, but '+TokenName[cur_token]+' found')
  else if cur_str <> str then
    raise LexError.Create('"'+str+'"'+' expected, but '+'"'+cur_str+'"'+' found');
  GetToken;
  Result:=true;
end;

function EatIdentifier(var ident:string;descr:string):boolean;
begin
  Result:=(cur_token=TTAlphaNum) and not IsKeyword(cur_str);
  if not Result then
    raise LexError.Create(descr+' expected, but '+GetTokenDescr+' found')
  else begin
    ident:=cur_str;
    GetToken;
  end;
end;

function TestAndEatIdentifier(var ident:string):boolean;
begin
  Result:=(cur_token=TTAlphaNum) and not IsKeyword(cur_str);
  if Result then begin
    ident:=cur_str;
    GetToken;
  end;
end;

function TestIdentifier:boolean;
begin
  Result:=(cur_token=TTAlphaNum) and not IsKeyword(cur_str);
end;

function EatInteger(var l:longint):boolean;
var minus:boolean;
begin
  minus:=TestAndEatTokenSymbol('-');
  Result:=(cur_token=TTInteger);
  if not Result then
    raise LexError.Create('integer number expected, but '+GetTokenDescr+' found')
  else begin
    l:=cur_int;
    if minus then l:=-l;
    GetToken;
  end;
end;

function TestAndEatTokenAlpha(str:string):boolean;
begin
  Result:=(cur_token = TTAlphaNum) and (cur_str = str);
  if Result then GetToken;
end;

function TestAndEatTokenSymbol(str:string):boolean;
begin
  Result:=(cur_token = TTSymbol) and (cur_str = str);
  if Result then GetToken;
end;

function TestTokenSymbol(str:string):boolean;
begin
  Result:=(cur_token = TTSymbol) and (cur_str = str);
end;

function TestTokenAlpha(str:string):boolean;
begin
  Result:=(cur_token = TTAlphaNum) and (cur_str = str);
end;

{
function EvalFunction(name:string):double;
begin
  if name='sin' then begin readparams(result); result:=sin(result); end
  else if name='cos' then begin readparams(result); result:=cos(result); end
  else raise LexError.Create('unknown function "'+name+'"');
end;


}

(*
void main() {
  cout << "\n";
  for (;;) {
    get_token();
    if (cur_token==ENDFILE) return;
    double d=expression();
    if (cur_token==SYMBOL && strcmp(cur_str,"=")==0) cout << d << "\n";
    else {
      if(cur_token!=ERROR) error("Syntax error");
      cin.ignore(1000,'\n');
    }
  }
}
*)

end.
