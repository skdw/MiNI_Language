%using MiNI_Language
%using System.Linq;
%namespace GardensPoint

%{
    private Scanner scanner;

    public Program Program { get; private set; }

    private List<(string, string)> declarations;

    private int labelcount = 0;

    public int Errors = 0;

    public Parser(Scanner scanner) : base(scanner) 
    {
        this.scanner = scanner;
	this.declarations = new List<(string, string)>();
    }

    private void GenError(string msg)
    {
        Console.Error.WriteLine("Line " + scanner.lineno + ": " + msg);
	Errors++;
    }

    private void CheckType(string type, params string[] allowedTypes)
    {
        if(!allowedTypes.Any(type.Contains))
           GenError(String.Format("Wrong variable type: {0}. Allowed types: {1}", type, String.Join(", ", allowedTypes)));
    }

    private string GetLabel()
    {
        return String.Format("IL_{0}", ++labelcount);
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
%type <node> addchar mulchar eqchar compchar bitchar convchar
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
	       if(declarations.Any(d => d.Item2 == $2))
	           GenError(String.Format("Variable named {0} is already declared!", $2));
	       $$ = new Instruction(String.Format(".locals init({0} _{1})", $1, $2));
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
	       CheckType($3.VarType, "bool");
	       string if1label = GetLabel();
	       string if2label = GetLabel();
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
	       CheckType($3.VarType, "bool");
	       string iflabel = GetLabel();
	       var boolexpr = $3;
	       var beforeinstr = new Instruction(String.Format("brfalse.s {0}", iflabel));
	       var instr = $5;
	       var afterinstr = new Instruction(String.Format("{0}:\t nop", iflabel));
	       $$ = new NoBlockInstruction(new List<Node> {boolexpr, beforeinstr, instr, afterinstr});
	       }
          ; // expr musi zwracaæ boola

while     : While LeftBracket expr RightBracket instr 
               {
	       CheckType($3.VarType, "bool");
	       string beforelabel = GetLabel();
	       string exprlabel = GetLabel();
	       var jumptoexpr = new Instruction(String.Format("br.s {0}", exprlabel));
	       var markbefore = new Instruction(String.Format("{0}:\t nop", beforelabel));
	       var instr = $5;
	       var markexpr = new Instruction(String.Format("{0}:\t nop", exprlabel));
	       var expr = $3;
	       var loopjump = new Instruction(String.Format("brtrue.s {0}", beforelabel));
	       $$ = new NoBlockInstruction(new List<Node> {jumptoexpr, markbefore, instr, markexpr, expr, loopjump});
	       }
          ;

read      : Read stident Semicolon
               {
	       var com1 = new Instruction("call string [mscorlib]System.Console::ReadLine()");
	       var com2 = $2;
	       $$ = new NoBlockInstruction(new List<Node> {com1, com2});
	       }
          ; // zapisuje do zmiennej, nie zmienia stosu

write     : Write writestr Semicolon 
               {
	       var res = new NoBlockInstruction();
	       var type = $2.VarType;
	       if(type == "float64")
	       {
		   var conv1 = new Instruction("call class [mscorlib]System.Globalization.CultureInfo [mscorlib]System.Globalization.CultureInfo::get_InvariantCulture()");
		   var conv2 = new Instruction("ldstr \"{0:0.000000}\"");
		   var conv3 = $2;
		   var conv4 = new Instruction("box [mscorlib]System.Double");
		   var conv5 = new Instruction("call string [mscorlib]System.String::Format(class [mscorlib]System.IFormatProvider, string, object)");
		   res.AddChild(conv1);
		   res.AddChild(conv2);
		   res.AddChild(conv3);
		   res.AddChild(conv4);
		   res.AddChild(conv5);
		   type = "string";
	       }
	       else
	           res.AddChild($2);
	       var com2 = new Instruction(String.Format("call void [mscorlib]System.Console::Write({0})", type));
	       res.AddChild(com2);
	       $$ = res;
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
	       bool isAssignment = com1.GetType().Name == "Assignment"; // sprawdza, czy przypisujemy wartosc z kolejnego przypisania
	       string com1type = isAssignment ? (com1 as Assignment).AssignedType : com1.VarType; // typ przypisywanych danych
	       if(com2.VarType == "float64")
	           CheckType(com1type, "float64", "int");
	       if(com2.VarType == "int32")
	           CheckType(com1type, "int32");
	       if(com2.VarType == "bool")
	           CheckType(com1type, "bool");
	       Assignment res;
	       if(isAssignment == false) // wyrazenie com1 nie jest jeszcze przypisaniem, nie trzeba duplikowac wartosci
	           res = new Assignment(new List<Node> { com1, com2 });
	       else // wyrazenie com1 jest juz przypisaniem
	           {
		   res = new Assignment(com1.Children);
	           res.Children.Insert(res.Children.Count - 1, new Instruction("dup")); // powielamy wartosc na stosie
		   res.Children.Add(com2);
	           }
	       res.AssignedType = com2.VarType; // przypisany typ jest taki, jak typ zmiennej, ktora nadpisujemy
	       $$ = res;
	       } // stos pozostaje taki jak przed przypisaniem
          | op6 
	       { }
          ;

op6       : op6 LogicalOr op5
               { 
	       CheckType($1.VarType, "bool");
	       CheckType($3.VarType, "bool");
	       var label1 = GetLabel();
	       var label2 = GetLabel();
	       var com1 = $1;
	       var com2 = new Instruction(String.Format("brtrue.s {0}", label1)); // jesli com1 zwraca true, to nie liczymy juz com3 (wynik = true)
	       var com3 = $3;
	       var com4 = new Instruction(String.Format("br.s {0}", label2)); // jesli liczylismy com3, to przeskakujemy ponizsza linijke
	       var com5 = new Instruction(String.Format("{0}:\t ldc.i4.1", label1)); // jesli nie liczylismy com3, to zwracamy true
	       var com6 = new Instruction(String.Format("{0}:\t nop", label2)); // doszlismy do konca, na stosie lezy wynik
	       $$ = new NoBlockInstruction(new List<Node> { com1, com2, com3, com4, com5, com6 }, "bool"); 
	       } // output bool, obliczenia skrocone
	  | op6 LogicalAnd op5
	       {
	       CheckType($1.VarType, "bool");
	       CheckType($3.VarType, "bool");
	       var label1 = GetLabel();
	       var label2 = GetLabel();
	       var com1 = $1;
	       var com2 = new Instruction(String.Format("brfalse.s {0}", label1)); // jesli com1 zwraca false, to nie liczymy juz com3 (wynik = false)
	       var com3 = $3;
	       var com4 = new Instruction(String.Format("br.s {0}", label2)); // jesli liczylismy com3, to przeskakujemy ponizsza linijke
	       var com5 = new Instruction(String.Format("{0}:\t ldc.i4.0", label1)); // jesli nie liczylismy com3, to zwracamy false
	       var com6 = new Instruction(String.Format("{0}:\t nop", label2)); // doszlismy do konca, na stosie lezy wynik
	       $$ = new NoBlockInstruction(new List<Node> { com1, com2, com3, com4, com5, com6 }, "bool"); 
	       } // output bool, obliczenia skrocone
          | op5 
	       { }
          ;

op5       : op5 eqchar op4 
               { 
	       CheckType($1.VarType, "int32", "float64", "bool");
	       CheckType($3.VarType, "int32", "float64", "bool");
	       $$ = new NoBlockInstruction(new List<Node> { $1, $3, $2 }, "bool"); 
	       } // input int/double/bool, output bool
          | op5 compchar op4 
	       {
	       CheckType($1.VarType, "int32", "float64");
	       CheckType($3.VarType, "int32", "float64");
	       $$ = new NoBlockInstruction(new List<Node> { $1, $3, $2 }, "bool"); 
	       } // input int/double, output bool
          | op4 
	       { }
          ;

op4       : op4 addchar op3 
               {
	       CheckType($1.VarType, "int32", "float64");
	       CheckType($3.VarType, "int32", "float64");
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
	       CheckType($1.VarType, "int32", "float64");
	       CheckType($3.VarType, "int32", "float64");
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
               { 
	       CheckType($1.VarType, "int32");
	       CheckType($3.VarType, "int32");
	       $$ = new NoBlockInstruction(new List<Node> { $1, $3, $2 }, "int32"); 
	       }
          | op1 
	       { }
          ;

op1       : Subtraction op1 
               { 
	       var com1 = new Instruction("neg");
	       CheckType($2.VarType, "int32", "float64");
	       $$ = new NoBlockInstruction(new List<Node> { $2, com1 }, $2.VarType);
	       }
	  | BitwiseNegation op1 
	       {
	       var com1 = new Instruction("not");
	       CheckType($2.VarType, "int32");
	       $$ = new NoBlockInstruction(new List<Node> { $2, com1 }, $2.VarType);
	       }
          | convchar op1 
	       { $$ = new NoBlockInstruction(new List<Node> { $2, $1 }, $1.VarType); } 
	  | LogicalNegation op1 
	       {
	       var com2 = new Instruction("ldc.i4.0", "bool");
	       var com3 = new Instruction("ceq");
	       CheckType($2.VarType, "bool");
	       $$ = new NoBlockInstruction(new List<Node> { $2, com2, com3 }, $2.VarType);
	       }
          | op0 
	       { }
          ;

op0       : anynumber 
               { }
	  | LeftBracket expr RightBracket 
	       { $$ = $2; }
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
	       $$ = new Instruction(String.Format(System.Globalization.CultureInfo.InvariantCulture, "ldc.r8 {0}", d), "float64");
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
	  ; // pobieramy wartosc ze stosu i umieszczamy w zmiennej

ldident   : Ident 
               {
	       int index = declarations.FindIndex(var => var.Item2 == String.Format("{0}", $1));
	       $$ = new Instruction(String.Format("ldloc {0}", index), declarations[index].Item1);
	       }
	  ; // wrzucamy wartosc zmiennej na stos

datatype  : Int 
               { $$ = "int32"; }
          | Double 
	       { $$ = "float64"; }
          | Bool 
	       { $$ = "bool"; }
          ;
%%


// yyabort - koniec pliku!