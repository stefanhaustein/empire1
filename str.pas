type 
  str16 = String[16];

function ToUpper(S: String): String;
var
  I: Integer;
begin
  for I := 1 to Length(S) do
    S[I] := UpCase(S[I]);
  ToUpper := S;
end;

function Real2Str(R: Real): str16;
var
  S: str16;
begin
  Str(R:0:0, S);
  Real2Str := S;
end;

function Int2Str(I: Integer): str16;
var
  S: str16;
begin
  Str(I, S);
  Int2Str := S;
end;

function TrimStr(S: String): String;
var
  I, J: Integer;
begin
  I := 1;
  while ((I <= Length(S)) and (S[I] <= ' ')) do
    I := I + 1;
  J := Length(S);
  while ((J >= I) and (S[J] <= ' ')) do
    J := J - 1;
  TrimStr := Copy(S, I, J - I + 1);
end;

function AlignStr(S: String; N: Integer): String;
const
  Spaces = '                ';
begin
  if Length(S) >= Abs(N) then
    AlignStr := S
  else if N > 0 then
  begin
    while Length(S) < N do
      S := S + Spaces;
    AlignStr := Copy(S, 1, N);  
  end
  else begin
    N := -N;
    while Length(S) < N do
      S := Spaces + S;
    AlignStr := Copy(S, Length(S) - N + 1, N);
  end;
end;
