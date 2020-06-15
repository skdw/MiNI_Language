%using MiNI_Language
%namespace GardensPoint

%{
    public Program Program { get; private set; }

    public Parser(Scanner scanner) : base(scanner) { }
%}

%union // wszystkie mo¿liwe typy, jakie przenosi token
{
public string val;
public char type;
public Node instr;
public List<Node> instrlist;
}

%token Program If Else While Read Write Return Int Double Bool True False
%token Assignment LogicalOr LogicalAnd BitwiseOr BitwiseAnd Equality Inequality Greater GreaterOrEqual Less LessOrEqual
%token Addition Subtraction Multiplication Division LogicalNegation BitwiseNegation LeftBracket RightBracket LeftCurlyBracket RightCurlyBracket Semicolon

%token Eof Error
%token <val> Ident IntNumber RealNumber

%type <instrlist> instructions block
%type <instr> instruction declaration

%%

// nieterminal : terminale, które siê na niego sk³adaj¹ ;

start     : Program block { Program = new Program(); Program.Children = $2; }
          ;

block     : LeftCurlyBracket instructions RightCurlyBracket { $$ = $2; }
          ;

instructions : instructions instruction Semicolon { $1.Add($2); $$ = $1; }
          | { $$ = new List<Node>(); }
	  ;

instruction : declaration
	  ;

declaration : Int Ident { $$ = new Declaration($2, "int32"); }
          | Double Ident { $$ = new Declaration($2, "float64"); }
          ;

%%
