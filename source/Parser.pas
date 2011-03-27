{
HtmlViewer Version 12
Copyright (c) 2011 by Bernd Gabriel

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Note that the source modules HTMLGIF1.PAS and DITHERUNIT.PAS
are covered by separate copyright notices located in those modules.
}

{$I htmlcons.inc}

unit Parser;

interface

uses
  Graphics, Variants, SysUtils, Math,
  //
  HtmlGlobals,
  HtmlSymbols;

function ReadURL(Item: Variant): ThtString;
function TryStrToColor(S: ThtString; NeedPound: Boolean; var Color: TColor): Boolean;

implementation

//-- BG ---------------------------------------------------------- 17.02.2011 --
function FindChar(const S: ThtString; C: ThtChar; I, L: Integer): Integer;
begin
  while (I <= L) and (S[I] <> C) do
    Inc(I);
  Result := I;
end;

//-- BG ---------------------------------------------------------- 17.02.2011 --
function SkipWhiteSpace(const S: ThtString; I, L: Integer): Integer;
begin
  while I <= L do
  begin
    case S[I] of
      ' ',
      #10,
      #12,
      #13:;
    else
      break;
    end;
    Inc(I);
  end;
  Result := I;
end;

{----------------ReadURL}

function ReadURL(Item: Variant): ThtString;
{
  If Item is a string try to find and parse:

    url( ["<url>"|'<url>'|<url>] )

  and if successful return the <url>.

  ReadURL tolerates
  - any substring before url
  - any substring after the (optionally quoted) <url>
  - nested '(' ')' pairs even in the unquoted <url>
}
var
  S: ThtString;
  I, J, L, N: Integer;
  Q: ThtChar;
begin
  Result := '';
  if VarIsStr(Item) then
  begin
    S := Item;
    I := Pos('url(', S);
    if I > 0 then
    begin
      L := Length(S);

      // optional white spaces
      I := SkipWhiteSpace(S, I + 4, L);

      // optional quote char
      Q := #0;
      if I < L then
        case S[I] of
          '''', '"':
          begin
            Q := S[I];
            Inc(I);
          end;
        end;

      // read url
      if Q <> #0 then
        // up to quote char
        J := FindChar(S, Q, I, L)
      else
      begin
        // unquoted: up to whitespace or ')'
        // beyond CSS: tolerate nested '(' ')' pairs as part of the name.
        N := 0;
        J := I;
        while J <= L do
        begin
          case S[J] of
            ' ',
            #10,
            #12,
            #13:
              if N = 0 then
                break;

            '(':
              Inc(N);

            ')':
            begin
              if N = 0 then
                break;
              Dec(N);
            end;
          end;
          Inc(J);
        end;
      end;
      Result := Copy(S, I, J - I);

      // ignore the rest: optional whitespaces and ')'
    end;
  end;
end;

function TryStrToColor(S: ThtString; NeedPound: Boolean; var Color: TColor): Boolean;
{Translate StyleSheet color ThtString to Color.  If NeedPound is true, a '#' sign
 is required to preceed a hexidecimal value.}
const
  LastS: ThtString = '?&%@';
  LastColor: TColor = 0;

var
  I, Rd, Bl: Integer;
  S1: ThtString;

  function FindRGBColor(S: ThtString): Boolean;
  type
    Colors = (red, green, blue);
  var
    A: array[red..blue] of ThtString;
    C: array[red..blue] of Integer;
    I, J: Integer;
    K: Colors;
  begin
    I := Pos('(', S);
    J := Pos(')', S);
    if (I > 0) and (J > 0) then
    begin
      S := copy(S, 1, J - 1);
      S := Trim(Copy(S, I + 1, 255));
      for K := Red to Green do
      begin
        I := Pos(',', S);
        A[K] := Trim(copy(S, 1, I - 1));
        S := Trim(Copy(S, I + 1, 255));
      end;
      A[Blue] := S;
      for K := Red to Blue do
      begin
        I := Pos('%', A[K]);
        if I > 0 then
        begin
          Delete(A[K], I, 1);
          try
            C[K] := Round(StrToFloat(A[K]) * 2.55);
          except
            C[K] := 0;
          end;
        end
        else
          C[K] := StrToIntDef(A[K], 0);
        C[K] := Max(0, Min(255, C[K]));
      end;
      Color := (C[Blue] shl 16) or (C[Green] shl 8) or C[Red];
      Result := True;
    end
    else
      Result := False;
  end;

//BG, 26.08.2009: exceptions are very slow
var
  Int, Idx: Integer;
//BG, 26.08.2009
begin
  if S = '' then
  begin
    Result := False;
    Exit;
  end;
  S := Lowercase(Trim(S));
  if S = LastS then
  begin {inquiries often come in pairs, this saves some recomputing}
    Color := LastColor;
    Result := True;
    Exit;
  end;
  I := Pos('rgb', S);
  if (I = 0) and (S[1] <> '#') then
  begin
    if TryNameToColor(S, Color) then
    begin
      Result := True;
      LastS := S;
      LastColor := Color;
      Exit;
    end;
  end;
  S1 := S;
  if (I > 0) then
    Result := FindRGBColor(Copy(S, I + 3, 255))
  else
  begin
//    try
      I := Pos('#', S);
      if I > 0 then
        while I > 0 do {sometimes multiple ##}
        begin
          Delete(S, 1, I);
          I := Pos('#', S);
        end
      else if NeedPound then
      begin
        Result := False;
        Exit;
      end;
      S := Trim(S);
      if Length(S) <= 3 then
        for I := Length(S) downto 1 do
          Insert(S[I], S, I); {Double each character}
      Result := TryStrToInt('$' + S, Int);
      if Result then
      begin
      {ok, but bytes are backwards!}
        Rd := Int and $FF;
        Bl := Int and $FF0000;
        Color := (Int and $00FF00) + (Rd shl 16) + (Bl shr 16) or PalRelative;
      end;
//    except
//      Result := False;
//    end;
  end;
  if Result then
  begin
    LastS := S1;
    LastColor := Color;
  end;
end;

end.
