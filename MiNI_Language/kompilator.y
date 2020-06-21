%using MiNI_Language
%namespace GardensPoint

%{
    private Scanner scanner;

    public Program Program { get; private set; }

    private List<(string, string)> declarations;

    private int labelcount = 0;

    public Parser(Scanner scanner) : base(scanner) 
    {
        this.scanner = scanner;
	this.declarations = new List<(string, string)>();
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
}

%token Program If Else While Read Write Return Int Double Bool True False
%token Assignment LogicalOr LogicalAnd BitwiseOr BitwiseAnd Equality Inequality Greater GreaterOrEqual Less LessOrEqual
%token Addition Subtraction Multiplication Division LogicalNegation BitwiseNegation LeftBracket RightBracket LeftCurlyBracket RightCurlyBracket Semicolon

%token Eof Error
%token <val> Ident IntNumber RealNumber String

%type <node> block instrs declars instr declar
%type <node> op0 op1 op2 op3 op4 op5 op6 expr
%type <node> ifelse if while read write writestr return bool anynumber stident ldident
%type <node> addchar mulchar logchar eqchar compchar bitchar unarchar convchar
%type <val> datatype

%%

// nieterminal : terminale, które siê na niego sk³adaj¹ ;

start     : Program block 
               { Program = new Program(); Program.AddChild($2); }
          ;

block     : LeftCurlyBracket declars instrs RightCurlyBracket 
               { $$ = new NoBlockInstruction(new List<Node>{ $2, $3 }); }
          ;

declars   : declars declar
               { $1.AddChild($2); }
          |    
	       { $$ = new NoBlockInstruction(); }
          ;

declar    : datatype Ident Semicolon 
               {
	       $$ = new Instruction(String.Format(".locals init({0} {1})", $1, $2));
	       declarations.Add(($1, $2));
	       }
          ;

instrs    : instrs instr 
               { $1.AddChild($2); }
          |    
	       { $$ = new NoBlockInstruction(); }
          ;

instr     : LeftCurlyBracket instrs RightCurlyBracket 
               { $$ = $2; }
          | expr Semicolon 
	       { }
          | ifelse 
	       { }
	  | if 
	       { }
	  | while 
	       { }
	  | read 
	       { }
	  | write 
	       { }
	  | return 
	       { }
          ;

ifelse    : If LeftBracket expr RightBracket instr Else instr 
               {
	       string if1label = String.Format("IL_{0}", ++labelcount);
	       string if2label = String.Format("IL_{0}", ++labelcount);
	       var boolexpr = $3; 
	       var beforeinstr = new Instruction(String.Format("brfalse.s {0}", if1label));
	       var ifinstr = $5;
	       var after1instr = new Instruction(String.Format("br.s {0}", if2label));
	       var betwinstr = new Instruction(String.Format("{0}:\t nop", if1label));
	       var elseinstr = $7;
	       var after2instr = new Instruction(String.Format("{0}:\t nop", if2label));
	       $$ = new NoBlockInstruction(new List<Node> {boolexpr, beforeinstr, ifinstr, after1instr, betwinstr, elseinstr, after2instr});
	       }
          ;

if        : If LeftBracket expr RightBracket instr 
               {
	       string iflabel = String.Format("IL_{0}", ++labelcount);
	       var boolexpr = $3;
	       var beforeinstr = new Instruction(String.Format("brfalse.s {0}", iflabel));
	       var instr = $5;
	       var afterinstr = new Instruction(String.Format("{0}:\t nop", iflabel));
	       $$ = new NoBlockInstruction(new List<Node> {boolexpr, beforeinstr, instr, afterinstr});
	       }
          ; // expr musi zwracaæ boola

while     : While LeftBracket expr RightBracket instr 
               {
	       string beforelabel = String.Format("IL_{0}", ++labelcount);
	       string exprlabel = String.Format("IL_{0}", ++labelcount);
	       var jumptoexpr = new Instruction(String.Format("br.s {0}", exprlabel));
	       var markbefore = new Instruction(String.Format("{0}:\t nop", beforelabel));
	       var instr = $5;
	       var markexpr = new Instruction(String.Format("{0}:\t nop", exprlabel));
	       var expr = $3;
	       var loopjump = new Instruction(String.Format("brtrue.s {0}", beforelabel));
	       $$ = new NoBlockInstruction(new List<Node> {jumptoexpr, markbefore, instr, markexpr, expr, loopjump});
	       }
          ;

read      : Read Ident Semicolon
               { 
	       int index = declarations.FindIndex(var => var.Item2 == String.Format("{0}", $2));
	       var com1 = "call string [mscorlib]System.Console::ReadLine()";
	       var com2 = String.Format("stloc {0}", index);
	       }
          ;

write     : Write writestr Semicolon 
               {
	       var com2 = new Instruction(String.Format("call void [mscorlib]System.Console::Write({0})", $2.VarType));
	       $$ = new NoBlockInstruction(new List<Node> { $2, com2 });
	       } // pobiera napis ze stosu i wypisuje
          ;

writestr  : String 
               { $$ = new Instruction(String.Format("ldstr {0}", $1), "string"); }
          | expr 
	       { }
	  ; // zostawia napis na stosie

return    : Return Semicolon 
               { $$ = new Instruction("ret"); }
          ;

expr      : stident Assignment expr 
               {
	       var com1 = $3;
	       var com2 = $1;
	       var res = com1;
	       if(com1.VarType != "assignment") // com1 nie jest jeszcze przypisaniem, nie trzeba duplikowaæ wartoœci
	           res = new NoBlockInstruction(new List<Node> { com1, com2 });
	       else
	           {
	           res.Children.Insert(res.Children.Count - 1, new Instruction("dup")); // powielamy wartosc na stosie
		   res.Children.Add(com2);
	           }
	       res.VarType = "assignment";
	       $$ = res;
	       } // stos pozostaje taki jak przed przypisaniem
          | op6 
	       { }
          ;

op6       : op6 logchar op5 
               { 
	       if($1.VarType == "bool" && $3.VarType == "bool") 
	           {
	           // DOPISAÆ!
	           }
	       else
	           GenError("Both arguments have to be bool");
	       } // output bool, obliczenia skrócone?
          | op5 
	       { }
          ;

op5       : op5 eqchar op4 
               { $$ = new NoBlockInstruction(new List<Node> { $1, $3, $2 }, "bool"); } // DODAÆ TYPY ARGUMENTÓW!!!!!
          | op5 compchar op4 
	       { $$ = new NoBlockInstruction(new List<Node> { $1, $3, $2 }, "bool"); } // input int/double, output bool
          | op4 
	       { }
          ;

op4       : op4 addchar op3 
               {
	       var nodelist = new List<Node> { $1 };
	       string type = ($1.VarType == "int32" && $3.VarType == "int32") ? "int32" : "float64";
	       if($1.VarType == "int32" && $3.VarType == "float64")
	           nodelist.Add(new Instruction("conv.r8")); // konwersja na double
	       nodelist.Add($3);
	       if($1.VarType == "float64" && $3.VarType == "int32")
	           nodelist.Add(new Instruction("conv.r8"));
	       nodelist.Add($2);
	       var res = new NoBlockInstruction(nodelist, type);
	       $$ = res; 
	       }
          | op3 
	       { }
	  ;

op3       : op3 mulchar op2 
               {
	       var nodelist = new List<Node> { $1 };
	       string type = ($1.VarType == "int32" && $3.VarType == "int32") ? "int32" : "float64";
	       if($1.VarType == "int32" && $3.VarType == "float64")
	           nodelist.Add(new Instruction("conv.r8")); // konwersja na double
	       nodelist.Add($3);
	       if($1.VarType == "float64" && $3.VarType == "int32")
	           nodelist.Add(new Instruction("conv.r8"));
	       nodelist.Add($2);
	       var res = new NoBlockInstruction(nodelist, type);
	       $$ = res; 
	       }
          | op2 
	       { }
	  ;

op2       : op2 bitchar op1 
               { $$ = new NoBlockInstruction(new List<Node> { $1, $3, $2 }, "int32"); } // input: INT!!!
          | op1 
	       { }
          ;

op1       : unarchar op1 
               { $$ = new NoBlockInstruction(new List<Node> { $2, $1 }, $2.VarType); } // substraction: input int/double, bitneg: int
          | convchar op1 
	       { $$ = new NoBlockInstruction(new List<Node> { $2, $1 }, $1.VarType); } 
	  | LogicalNegation op1 
	       { 
	       // $2 musi byæ boolem !!!
	       var com2 = new Instruction("ldc.i4.0", "bool");
	       var com3 = new Instruction("ceq");
	       $$ = new NoBlockInstruction(new List<Node> { $2, com2, com3 }, "bool");
	       }
          | op0 
	       { }
          ;

op0       : anynumber 
               { }
          ;

unarchar  : Subtraction 
               { $$ = new Instruction("neg"); }
          | BitwiseNegation 
	       { $$ = new Instruction("not"); }
          ;

convchar  : LeftBracket Int RightBracket 
               { $$ = new Instruction("conv.i4", "int32"); }
	  | LeftBracket Double RightBracket 
	       { $$ = new Instruction("conv.r8", "float64"); }
          ;

mulchar   : Multiplication 
               { $$ = new Instruction("mul"); }
          | Division 
	       { $$ = new Instruction("div"); }
	  ;

addchar   : Addition 
               { $$ = new Instruction("add"); }
          | Subtraction 
	       { $$ = new Instruction("sub"); }
	  ;

logchar   : LogicalOr 
               { $$ = new Instruction("or"); } 
          | LogicalAnd 
	       { $$ = new Instruction("and"); }
          ;

eqchar    : Equality 
               { $$ = new Instruction("ceq"); }
          | Inequality 
	       {
	       var ceq = new Instruction("ceq");
	       var zero = new Instruction("ldc.i4.0");
	       $$ = new NoBlockInstruction(new List<Node>{ ceq, zero, ceq });
	       }
	  ; // input int/double/2*bool, output bool

compchar  : Greater 
               { $$ = new Instruction("cgt"); }
          | GreaterOrEqual 
	       {
	       var ceq = new Instruction("ceq");
	       var clt = new Instruction("clt");
	       var zero = new Instruction("ldc.i4.0");
	       $$ = new NoBlockInstruction(new List<Node>{ clt, zero, ceq });
	       }
	  | Less 
	       { $$ = new Instruction("clt"); }
          | LessOrEqual 
	       {
	       var ceq = new Instruction("ceq");
	       var cgt = new Instruction("cgt");
	       var zero = new Instruction("ldc.i4.0");
	       $$ = new NoBlockInstruction(new List<Node>{ cgt, zero, ceq });
	       }
	  ; 

bitchar   : BitwiseOr 
               { $$ = new Instruction("or"); }
          | BitwiseAnd 
	       { $$ = new Instruction("and"); }
	  ;

anynumber : IntNumber 
               { $$ = new Instruction(String.Format("ldc.i4 {0}", int.Parse($1)), "int32"); }
          | RealNumber 
	       {
	       double d = double.Parse($1,System.Globalization.CultureInfo.InvariantCulture);
	       $$ = new Instruction(String.Format(System.Globalization.CultureInfo.InvariantCulture, "ldc.r8 {0:0.000000}", d), "float64");
	       }
	  | bool 
	       { }
	  | ldident 
	       { }
	  ; // wrzucamy wartosc na stos

bool      : True 
               { $$ = new Instruction("ldc.i4.1", "bool"); }
          | False 
	       { $$ = new Instruction("ldc.i4.0", "bool"); }
	  ; // wrzucamy wartosc na stos

stident   : Ident 
               {
	       int index = declarations.FindIndex(var => var.Item2 == String.Format("{0}", $1));
	       $$ = new Instruction(String.Format("stloc {0}", index), declarations[index].Item1);
	       }
	  ; // wrzucamy wartosc zmiennej na stos

ldident   : Ident 
               {
	       int index = declarations.FindIndex(var => var.Item2 == String.Format("{0}", $1));
	       $$ = new Instruction(String.Format("ldloc {0}", index), declarations[index].Item1);
	       }
	  ; // pobieramy wartosc ze stosu i umieszczamy w zmiennej

datatype  : Int 
               { $$ = "int32"; }
          | Double 
	       { $$ = "float64"; }
          | Bool 
	       { $$ = "bool"; }
          ;
%%


// yyabort - koniec pliku!