using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using GardensPoint;

namespace MiNI_Language
{
    public abstract class Node
    {
        public abstract void Accept(CodeGenerator visitor);

        public List<Node> Children = null;

        public void AddChild(Node child)
        {
            try
            {
                Children.Add(child);
            }
            catch (Exception e)
            {
                Console.WriteLine(e.ToString());
                throw;
            }
        }
    }

    public class BlankNode : Node
    {
        public BlankNode()
        {
            Children = new List<Node>();
        }

        public override void Accept(CodeGenerator visitor) => visitor.EmitBlock(this);
    }

    public class RootNode : BlankNode
    {
        public override void Accept(CodeGenerator visitor) => visitor.Visit(this);
    }

    public class Program : Node
    {
        public override void Accept(CodeGenerator visitor) => visitor.EmitBlock(this);
    }

    public class Instruction : Node
    {
        public string Val;

        public Instruction(string val)
        {
            Val = val;  
        }

        public override void Accept(CodeGenerator visitor)
        {
            visitor.EmitCode(Val);
        }
    }

    public class Declaration : Instruction
    {
        public string Type;

        public Declaration(string val, string type) : base(val)
        {
            Type = type;
        }

        public override void Accept(CodeGenerator visitor)
        {
            visitor.EmitCode($".locals init({Type} {Val})");
        }
    }


    public class CodeGenerator
    {
        private static StreamWriter sw;

        private const int indent_lines = 4;

        private int indent_lvl = 0;

        public CodeGenerator(string file)
        {
            sw = new StreamWriter(file + ".il");
        }

        public void EmitCode(string instr)
        {
            sw.WriteLine($"{new string(' ', indent_lvl * indent_lines)}{instr}");
        }

        public void EmitBlock(Node node)
        {
            EmitCode("{");
            indent_lvl++;
            node.Children.ForEach(x => x.Accept(this));
            indent_lvl--;
            EmitCode("}");
        }

        public void Visit(RootNode rootNode)
        {
            EmitCode(".assembly extern mscorlib { }");
            EmitCode(".assembly minilanguage { }");
            EmitCode(".method static void main()");
            EmitBlock(rootNode);
            sw.Close();
        }
    }

    public static class Compiler
    {
        public static int errors = 0;
        
        public static Program Compile(string file)
        {
            // Set a new FileStream for scanning
            var source = new FileStream(file, FileMode.Open);

            Scanner scanner = new Scanner(source);
            Parser parser = new Parser(scanner);

            parser.Parse();

            source.Close();

            errors += scanner.Errors; // errors occured in scanner

            if (errors == 0)
                Console.WriteLine("compilation successful\n");
            else
            {
                Console.WriteLine($"\n  {errors} errors detected\n");
                File.Delete(file + ".il");
            }
            return parser.Program;
        }
    }

    public class MainCompiler
    {
        public static List<string> source;

        static void Read(string file)
        {
            // Read lines from file
            var sr = new StreamReader(file);
            string str = sr.ReadToEnd();
            sr.Close();
            source = new List<string>(str.Split(new string[] { "\r\n" }, StringSplitOptions.None));
        }
        
        private static RootNode GetRootNode(Program program)
        {
            RootNode lvl1 = new RootNode();
            lvl1.AddChild(new Instruction(".entrypoint"));
            lvl1.AddChild(new Instruction(".try"));

            program.AddChild(new Instruction("leave EndMain"));
            lvl1.AddChild(program);
            lvl1.AddChild(new Instruction("catch [mscorlib]System.Exception"));

            BlankNode lvl22 = new BlankNode();
            lvl22.AddChild(new Instruction("callvirt instance string [mscorlib]System.Exception::get_Message()"));
            lvl22.AddChild(new Instruction("call void [mscorlib]System.Console::WriteLine(string)"));
            lvl22.AddChild(new Instruction("leave EndMain"));
            lvl1.AddChild(lvl22);
            lvl1.AddChild(new Instruction("EndMain: ret"));
            return lvl1;
        }

        public static int Main(string[] args)
        {
            string file;

            if (args.Length >= 1)
                file = args[0];
            else
            {
                Console.Write("\nsource file:  ");
                file = Console.ReadLine();
            }
            try
            {
                Read(file);
                Program program = Compiler.Compile(file);
                CodeGenerator codeGenerator = new CodeGenerator(file);

                RootNode rootNode = GetRootNode(program);
                rootNode.Accept(codeGenerator);
            }
            catch (Exception e)
            {
                Console.WriteLine(e.ToString());
                return 1;
            }
            return 0;
        }
    }
}
