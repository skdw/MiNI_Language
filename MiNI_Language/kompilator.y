%using MiNI_Language
%namespace GardensPoint

%{
    private Scanner scanner;

    public Program Program { get; private set; }

    private List<(string, string)> declarations;

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
public int ind;
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

%type <ind> ident
%type <nodelist> instructions declarations block
%type <node> instruction declaration 
%type <node> ifelse if while read write writestr return expr boolexpr unarexpr bool logicneg toint todouble add assignment anynumber
%type <val> datatype unarsub 

%%

// nieterminal : terminale, które siê na niego sk³adaj¹ ;

start     : Program block { Program = new Program(); Program.Children = $2; }
          ;

block     : LeftCurlyBracket declarations instructions RightCurlyBracket { $2.AddRange($3); $$ = $2; }
          ;

declarations : declarations declaration { $1.Add($2); $$ = $1; }
          | { $$ = new List<Node>(); }
          ;

declaration : datatype Ident Semicolon { 
                                         var str = String.Format(".locals init({0} {1})", $1, $2); 
					 $$ = new Instruction(str); 
					 declarations.Add(($1, $2));
				       }
          ;

datatype  : Int { $$ = "int32"; }
          | Double { $$ = "float64"; }
          | Bool { $$ = "bool"; }
          ;

instructions : instructions instruction { $1.Add($2); $$ = $1; }
          | { $$ = new List<Node>(); }
          ;

instruction : LeftCurlyBracket instructions RightCurlyBracket { $$ = new BlockInstruction($2); }
          | exprinstr { }
          | ifelse { $$ = $1; }
	  | if { $$ = $1; }
	  | while { $$ = $1; }
	  | read { $$ = $1; }
	  | write { $$ = $1; }
	  | return { }
          ;

exprinstr : expr Semicolon { }
          ;

ifelse    : If LeftBracket boolexpr RightBracket instruction Else instruction { }
          ;

if        : If LeftBracket boolexpr RightBracket instruction { }
          ;

while     : While LeftBracket boolexpr RightBracket instruction { }
          ;

read      : Read ident Semicolon { 
                                   var com1 = "call string [mscorlib]System.Console::ReadLine()"; 
				   var com2 = String.Format("stloc {0}", $2); 
				 }
          ;

write     : Write writestr Semicolon {
				       var com2 = new Instruction(String.Format("call void [mscorlib]System.Console::Write({0})", $2.VarType)); 
				       $$ = new NoBlockInstruction(new List<Node> { $2, com2 }); 
				     } // pobiera napis ze stosu i wypisuje
          ;

writestr  : String { 
                     var res = new Instruction(String.Format("ldstr {0}", $1)); 
		     res.VarType = "string"; 
		     $$ = res; 
		   }
          | expr { $$ = $1; }
	  ; // zostawia napis na stosie

return    : Return Semicolon { $$ = new Instruction("ret"); }
          ;

expr      : unarexpr { } 
          | bitexpr { }
	  | mult { }
	  | add { $$ = $1; }
	  | relation { }
	  | logical { }
	  | assignment { }
          ;

//boolexprs : boolexprs boolexpr {  }
 //         | { $$ = new List<Node>(); }
 //         ;

boolexpr  : logicneg { }
          | relation { }
          | logical { }
	  ;

unarexpr  : unarsub { 
                      var com1 = new Instruction(String.Format("ldloc {0}", $1)); // ldc  - sta³a, ldloc - lokalna!!!!!
		      var com2 = new Instruction("neg"); 
		      $$ = new NoBlockInstruction(new List<Node> { com1, com2 }); 
		    }
          | BitwiseNegation IntNumber { 
                                        var com1 = new Instruction(String.Format("ldloc {0}", $2)); 
                                        var com2 = new Instruction("not"); 
                                        $$ = new NoBlockInstruction(new List<Node> { com1, com2 }); 
                                      }
          | logicneg { 
	               var com1 = $1; 
	               var com2 = new Instruction("ldc.i4.0"); 
		       var com3 = new Instruction("ceq"); 
		       $$ = new NoBlockInstruction(new List<Node> { com2, com3 }); 
		     } // dokonczyc!
          | toint { }
          | todouble { }
          ;

unarsub   : Subtraction IntNumber { $$ = $2; }
          | Subtraction RealNumber { $$ = $2; }
          ;

//bitwiseneg : BitwiseNegation IntNumber { $$ = $2; }
//          ;

logicneg  : LogicalNegation bool { $$ = $2; } 
          ;

toint     : LeftBracket Int RightBracket anynumber { $$ = $4; }
          ;

todouble  : LeftBracket Double RightBracket anynumber { $$ = $4; }
          ;

bitexpr   : IntNumber BitwiseOr IntNumber { } // int
          | IntNumber BitwiseAnd IntNumber { } // int
	  | bitexpr BitwiseOr IntNumber { }
	  | bitexpr BitwiseAnd IntNumber { }
	  ;

mult      : anynumber Multiplication anynumber { } // int, jeœli oba inty
          | anynumber Division anynumber { }
	  | mult Multiplication anynumber { }
	  | mult Division anynumber { }
	  ;

add       : anynumber Addition anynumber { 
                                           var com1 = $1; 
					   var com2 = $3; 
					   var com3 = new Instruction("add");
					   var res = new NoBlockInstruction(new List<Node> { com1, com2, com3 }); 
					   res.VarType = "int32"; // int, jeœli oba inty ???????
					   $$ = res;
					 } // pozostawia wynik na stosie; 
          | anynumber Subtraction anynumber { }
	  | add Addition anynumber { }
	  | add Subtraction anynumber { }
	  ;

relation  : equal { }
          | notequal { }
	  | greater { }
	  | notless { }
	  | less { }
	  | notgreater { }
	  ;

equal     : anynumber Equality anynumber { } // input int/double/2*bool, output bool
          ;

notequal  : anynumber Inequality anynumber { } // input int/double/2*bool, output bool
          ;

greater   : anynumber Greater anynumber { } // input int/double, output bool
          ;

notless   : anynumber GreaterOrEqual anynumber { } // input int/double, output bool
          ;

less      : anynumber Less anynumber { } // input int/double, output bool
          ;

notgreater : anynumber LessOrEqual anynumber { } // input int/double, output bool
          ;


logical   : bool LogicalOr bool { } // output bool, obliczenia skrócone?
          | bool LogicalAnd bool { }
          ;

assignment : ident Assignment anynumber { // lewym musi byæ zmienna, double=double/int, int/bool=ten sam typ
                                          var com1 = $3; 
					  var com2 = new Instruction(String.Format("stloc {0}", $1)); 
					  $$ = new NoBlockInstruction(new List<Node> { com1, com2 }); 
					} 
          | ident Assignment assignment { 
	                                  var res = $3; 
					  res.Children.Insert(res.Children.Count - 1, new Instruction("dup")); // powielamy wartosc na stosie
					  var com2 = new Instruction(String.Format("stloc {0}", $1)); 
					  res.Children.Add(com2); 
					  $$ = res; 
					}
          ; // stos pozostaje taki jak przed przypisaniem

anynumber : IntNumber { $$ = new Instruction(String.Format("ldc.i4 {0}", int.Parse($1))); }
          | RealNumber { 
	                 double d = double.Parse($1,System.Globalization.CultureInfo.InvariantCulture) ;
                         $$ = new Instruction(String.Format(System.Globalization.CultureInfo.InvariantCulture, "ldc.r8 {0}", d)); 
		       }
	  | ident { $$ = new Instruction(String.Format("ldloc {0}", $1)); }
	  ; // wrzucamy wartosc na stos

ident     : Ident { 
                    $$ = declarations.FindIndex(var => var.Item2 == String.Format("{0}", $1)); 
		  }
	  ;

bool      : True { $$ = new Instruction("ldc.i4.1"); }
          | False { $$ = new Instruction("ldc.i4.0"); }
	  ; // wrzucamy wartosc na stos

%%


// yyabort - koniec pliku!