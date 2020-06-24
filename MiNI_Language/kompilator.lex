
%using QUT.Gppg;
%using MiNI_Language;
%namespace GardensPoint

%{
    public int lineno = 1;

    public int Errors { get; private set; }

    public override void yyerror(string msg, params object[] args)
    {
        Console.WriteLine("Line " + lineno + ": " + msg);
        ++Errors;
    }
%}

Ident         ([a-zA-Z][a-zA-Z0-9]*)
IntNumber     (0|[1-9][0-9]*)
RealNumber    (0|[1-9][0-9]*)\.[0-9]+
Comment       \/\/.*$
String        \"(\\.|[^"\n\\])*\"

%%

"program"     { return (int)Tokens.Program; }
"if"          { return (int)Tokens.If; }
"else"        { return (int)Tokens.Else; }
"while"       { return (int)Tokens.While; }
"read"        { return (int)Tokens.Read; }
"write"       { return (int)Tokens.Write; }
"return"      { return (int)Tokens.Return; }
"int"         { return (int)Tokens.Int; }
"double"      { return (int)Tokens.Double; }
"bool"        { return (int)Tokens.Bool; }
"true"        { return (int)Tokens.True; }
"false"       { return (int)Tokens.False; }

"="           { return (int)Tokens.Assignment; }
"||"          { return (int)Tokens.LogicalOr; }
"&&"          { return (int)Tokens.LogicalAnd; }
"|"           { return (int)Tokens.BitwiseOr; }
"&"           { return (int)Tokens.BitwiseAnd; }
"=="          { return (int)Tokens.Equality; }
"!="          { return (int)Tokens.Inequality; }
">"           { return (int)Tokens.Greater; }
">="          { return (int)Tokens.GreaterOrEqual; }
"<"           { return (int)Tokens.Less; }
"<="          { return (int)Tokens.LessOrEqual; }
"+"           { return (int)Tokens.Addition; }
"-"           { return (int)Tokens.Subtraction; }
"*"           { return (int)Tokens.Multiplication; }
"/"           { return (int)Tokens.Division; }
"!"           { return (int)Tokens.LogicalNegation; }
"~"           { return (int)Tokens.BitwiseNegation; }
"("           { return (int)Tokens.LeftBracket; }
")"           { return (int)Tokens.RightBracket; }
"{"           { return (int)Tokens.LeftCurlyBracket; }
"}"           { return (int)Tokens.RightCurlyBracket; }
";"           { return (int)Tokens.Semicolon; }


"\n"          { lineno++; }
<<EOF>>       { return (int)Tokens.EOF; }
" "           { }
"\t"          { }
"\r"          { }
{Ident}       { yylval.val=yytext; return (int)Tokens.Ident; }
{IntNumber}   { yylval.val=yytext; return (int)Tokens.IntNumber; }
{RealNumber}  { yylval.val=yytext; return (int)Tokens.RealNumber; }
{String}      { yylval.val=yytext; return (int)Tokens.String; }
{Comment}     { }
.             { yyerror("Wrong token: " + yytext + "k"); return (int)Tokens.Error; }
