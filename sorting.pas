unit sorting;

{Unit Sorting                 version 2.2                29.5.1998}
{           by Peter BUDAI,           NEURONsoftware 1998         }


{$ifdef Example:}

    uses sorting;
    type TArray=array [1..1000] of integer;
    var a:TArray;
    {$f+}
    procedure change(ptr:pointer;i,j:longint);
    var p:integer;
    begin
      with TArray(ptr^) do begin
        p:=a[i]; a[i]:=a[j]; a[j]:=p
      end;
    end;

    function compare(ptr:pointer;i,j:longint):boolean;
    begin
      with TArray(ptr^) do begin
        Result:=a[i]<a[j] {<..asceding  >..desceding}
      end;
    end;
    {$f-}
    begin
      ...
      quicksort(@a,10,100,change,compare);
      ...
      heapsort(@a,1,1000,change,compare);
      ...
    end.
{$endif}


interface

type TFuncPLL_B=function(Ptr:pointer;I,J:longint):boolean;
     TProcPLL=procedure(Ptr:pointer;I,J:longint);

procedure QuickSort(Ptr:pointer;A,B:longint;ChangeProc:TProcPLL;KeyFunc:TFuncPLL_B);
procedure HeapSort(Ptr:pointer;A,B:longint;ChangeProc:TProcPLL;KeyFunc:TFuncPLL_B);

implementation

procedure QuickSort;
var i,j:word;

  procedure sort(l,r:word);
  var x:word;
  begin
    if l+1=r then begin if keyfunc(Ptr,r,l) then changeproc(Ptr,l,r); exit end;
    i:=l; j:=r; x:=(l+r) div 2;
    repeat
      while keyfunc(Ptr,i,x) do inc(i);
      while keyfunc(Ptr,x,j) do dec(j);
      if i<=j then
      begin
        if (x=i) or (x=j) then begin if x=i then x:=j else x:=i end;
        changeproc(Ptr,i,j);
        inc(i); dec(j)
      end
    until i>j;
    if j-l<r-i then begin {kvoli zmenseniu max. velkosti zasobnika}
                      x:=i;
                      if l<j then sort(l,j);
                      if x<r then sort(x,r)
                    end
               else begin
                      x:=j;
                      if i<r then sort(i,r);
                      if l<x then sort(l,x)
                    end
  end; {sort}

begin
  if a<b then sort(a,b)
end; {quicksort}

procedure HeapSort;
var l,r:word;

  procedure makeheap;
  var i,j:word;
  begin
    i:=l; j:=2*i-a+1;
    while j<=r do
    begin
      if (j<r) and keyfunc(Ptr,j,j+1) then inc(j);
      if not keyfunc(Ptr,i,j) then exit;
      changeproc(Ptr,i,j); i:=j; j:=2*i-a+1
    end
  end; {makeheap}

begin
  if a>=b then exit;
  l:=(b-a+1) div 2+a; r:=b;
  while l>a do begin dec(l); makeheap end;
  while r>a do begin changeproc(Ptr,a,r); dec(r); makeheap end;
end; {heapsort}

end.
