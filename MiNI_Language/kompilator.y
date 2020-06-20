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
%type <node> ifelse if while read write writestr return expr unarexpr bool logicneg toint todouble anynumber stident ldident
%type <node> addchar mulchar logchar eqchar compchar
%type <node> op0 op1 op2 op3 op4 op5 op6 op7
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

ifelse    : If LeftBracket expr RightBracket instruction Else instruction { }
          ;

if        : If LeftBracket expr RightBracket instruction { }
          ;

while     : While LeftBracket expr RightBracket instruction { }
          ;

read      : Read Ident Semicolon { 
                                   int index = declarations.FindIndex(var => var.Item2 == String.Format("{0}", $2)); 
                                   var com1 = "call string [mscorlib]System.Console::ReadLine()"; 
				   var com2 = String.Format("stloc {0}", index); 
				 }
          ;

write     : Write writestr Semicolon {
				       var com2 = new Instruction(String.Format("call void [mscorlib]System.Console::Write({0})", $2.VarType)); 
				       $$ = new NoBlockInstruction(new List<Node> { $2, com2 }); 
				     } // pobiera napis ze stosu i wypisuje
          ;

writestr  : String { 
                     var res = new Instruction(String.Format("ldstr {0}", $1), "string");
		     $$ = res; 
		   }
          | expr { $$ = $1; }
	  ; // zostawia napis na stosie

return    : Return Semicolon { $$ = new Instruction("ret"); }
          ;

//expr      : unarexpr { } 
//          | bitexpr { }
//	  | mult { $$ = $1; }
//	  | add { $$ = $1; }
//	  | relation { }
//	  | logical { }
//	  | assignment { }
//         ;


expr      : op7 { $$ = $1; }
          ;

op7       : stident Assignment op7 {
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
          | op6 { $$ = $1; }
          ;

op6       : op6 logchar op5 { 
                              if($1.VarType == "bool" && $3.VarType == "bool") 
			      {
			        
			      }
			      else
			        GenError("Both arguments have to be bool");
                            } // output bool, obliczenia skrócone?
          | op5 { $$ = $1; }
          ;

op5       : op5 eqchar op4 { $$ = new NoBlockInstruction(new List<Node> { $1, $3, $2 }, "bool"); }
          | op5 compchar op4 { $$ = new NoBlockInstruction(new List<Node> { $1, $3, $2 }, "bool"); }
          | op4 { $$ = $1; }
          ;

op4       : op4 addchar op3 { 		   var nodelist = new List<Node> { $1 };
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
          | op3 { $$ = $1; }
	  ;

op3       : op3 mulchar op2 {              var nodelist = new List<Node> { $1 };
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
          | op2 { $$ = $1; }
	  ;

op2       : op1 { $$ = $1; }
          ;

op1       : op0 { $$ = $1; }
          ;

op0       : anynumber { $$ = $1; }
          ;

//relation  : add LeftBracket Equality RightBracket 
//          ;

//boolexprs : boolexprs boolexpr {  }
 //         | { $$ = new List<Node>(); }
 //         ;

//boolexpr  : logicneg { }
        //  | relation { }
        //  | logexpr { }
//	  ;

//logexpr   : {}
//          ;

//relation  : {}
 //         ;

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


mulchar   : Multiplication { $$ = new Instruction("mul"); }
          | Division { $$ = new Instruction("div"); }
	  ;

addchar   : Addition { $$ = new Instruction("add"); }
          | Subtraction { $$ = new Instruction("sub"); }
	  ;

logchar   : LogicalOr { $$ = new Instruction("or"); } 
          | LogicalAnd { $$ = new Instruction("and"); }
          ;

eqchar    : Equality { $$ = new Instruction("ceq"); }
          | Inequality { 
	                 var ceq = new Instruction("ceq"); 
			 var zero = new Instruction("ldc.i4.0"); 
			 $$ = new NoBlockInstruction(new List<Node>{ ceq, zero, ceq }); 
		       }
	  ; // input int/double/2*bool, output bool

compchar  : Greater { $$ = new Instruction("cgt"); }
          | GreaterOrEqual { 
	                     var ceq = new Instruction("ceq"); 
			     var clt = new Instruction("clt"); 
			     var zero = new Instruction("ldc.i4.0"); 
			     $$ = new NoBlockInstruction(new List<Node>{ clt, zero, ceq }); 
			   }
	  | Less { $$ = new Instruction("clt"); }
          | LessOrEqual { 
	                  var ceq = new Instruction("ceq"); 
			  var cgt = new Instruction("cgt"); 
			  var zero = new Instruction("ldc.i4.0"); 
			  $$ = new NoBlockInstruction(new List<Node>{ cgt, zero, ceq }); 
			}
	  ; // input int/double, output bool

anynumber : IntNumber { $$ = new Instruction(String.Format("ldc.i4 {0}", int.Parse($1)), "int32"); }
          | RealNumber { 
	                 double d = double.Parse($1,System.Globalization.CultureInfo.InvariantCulture) ;
                         var res = new Instruction(String.Format(System.Globalization.CultureInfo.InvariantCulture, "ldc.r8 {0:0.000000}", d), "float64");
			 $$ = res;
		       }
	  | bool { $$ = $1; }
	  | ldident { $$ = $1; }
	  ; // wrzucamy wartosc na stos

bool      : True { $$ = new Instruction("ldc.i4.1", "bool"); }
          | False { $$ = new Instruction("ldc.i4.0", "bool"); }
	  ; // wrzucamy wartosc na stos

stident     : Ident { 
                    int index = declarations.FindIndex(var => var.Item2 == String.Format("{0}", $1)); 
		    $$ = new Instruction(String.Format("stloc {0}", index), declarations[index].Item1);
		  }
	  ; // wrzucamy wartosc zmiennej na stos

ldident     : Ident { 
                    int index = declarations.FindIndex(var => var.Item2 == String.Format("{0}", $1)); 
		    $$ = new Instruction(String.Format("ldloc {0}", index), declarations[index].Item1);
		  }
	  ; // pobieramy wartosc ze stosu i umieszczamy w zmiennej
%%


// yyabort - koniec pliku!