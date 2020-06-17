%using MiNI_Language
%namespace GardensPoint

%{
    private Scanner scanner;

    public Program Program { get; private set; }

    public Parser(Scanner scanner) : base(scanner) 
    {
        this.scanner = scanner;
    }

    public void GenError(string msg)
    {
        Console.Error.WriteLine("Line " + scanner.lineno + ": " + msg); // nie ma odwo³añ !!!!!
    }
%}

%union // wszystkie mo¿liwe typy, jakie przenosi token
{
public string val;
public char type;
public Node node;
public List<Node> nodelist;

public Instruction instrr;
}

%token Program If Else While Read Write Return Int Double Bool True False
%token Assignment LogicalOr LogicalAnd BitwiseOr BitwiseAnd Equality Inequality Greater GreaterOrEqual Less LessOrEqual
%token Addition Subtraction Multiplication Division LogicalNegation BitwiseNegation LeftBracket RightBracket LeftCurlyBracket RightCurlyBracket Semicolon

%token Eof Error
%token <val> Ident IntNumber RealNumber String

%type <nodelist> instructions declarations block
%type <node> instruction declaration 
%type <node> ifelse if while read write1 write2
%type <val> datatype

%%

// nieterminal : terminale, które siê na niego sk³adaj¹ ;

start     : Program block { Program = new Program(); Program.Children = $2; }
          ;

block     : LeftCurlyBracket declarations instructions RightCurlyBracket { $2.AddRange($3); $$ = $2; }
          ;

declarations : declarations declaration { $1.Add($2); $$ = $1; }
          | { $$ = new List<Node>(); }
          ;

declaration : datatype Ident Semicolon { var str = String.Format(".locals init({0}, {1})", $1, $2); $$ = new Instruction(str); }
          ;

datatype  : Int { $$ = "int32"; }
          | Double { $$ = "float64"; }
          | Bool { $$ = "bool"; }
          ;

instructions : instructions instruction { $1.Add($2); $$ = $1; }
          | { $$ = new List<Node>(); }
          ;

instruction : LeftCurlyBracket instructions RightCurlyBracket { $$ = new BlockInstruction($2); }
          | ifelse { $$ = $1; }
	  | if { $$ = $1; }
	  | while { $$ = $1; }
	  | read { $$ = $1; }
	  | write1 { $$ = $1; }
	  | write2 { $$ = $1; }
          ;

ifelse    : If LeftBracket boolexpr RightBracket instruction Else instruction { }
          ;

if        : If LeftBracket boolexpr RightBracket instruction { }
          ;

while     : While LeftBracket boolexpr RightBracket instruction { }
          ;

read      : Read Ident Semicolon { var com1 = "call string [mscorlib]System.Console::ReadLine()"; var com2 = String.Format("stloc {0}", $2); }
          ;

write1    : Write expr Semicolon { }
          ;

write2    : Write String Semicolon { 
                                     var com1 = new Instruction(String.Format("ldstr {0}", $2)); 
				     var com2 = new Instruction("call void [mscorlib]System.Console::Write(string)"); 
				     $$ = new NoBlockInstruction(new List<Node> { com1, com2 }); 
				   }
          ;

expr      : boolexpr { }
          ;

boolexpr  : 
          ;

%%


// yyabort - koniec pliku!