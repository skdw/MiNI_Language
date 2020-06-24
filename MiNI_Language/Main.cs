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
        public string VarType = null; // typ zmiennej, jaka pozostaje na stosie

        public abstract void Accept(CodeGenerator generator);
        
        public abstract void AddChild(Node child);
    }

    public class Instruction : Node
    {
        public string Val;

        public Instruction(string val, string vartype = "")
        {
            Val = val;
            VarType = vartype;
        }

        public override void AddChild(Node child) => throw new Exception("Cannot add child to a single instruction");

        public override void Accept(CodeGenerator generator) => generator.EmitCode(Val);

        public override string ToString() => Val;
    }

    public class ParentNode : Node
    {
        public bool Block = false;

        public List<Node> Children = new List<Node>();

        public ParentNode(bool block = false)
        {
            Block = block;
        }

        public ParentNode(List<Node> children, string vartype = "")
        {
            Children = children;
            VarType = vartype;
        }
        
        public override void AddChild(Node child) => Children.Add(child);
        
        public override void Accept(CodeGenerator generator) => generator.EmitNode(this, Block);
    }
    
    public class RootNode : ParentNode
    {
        public override void Accept(CodeGenerator generator) => generator.EmitRoot(this);
    }

    public class CodeGenerator
    {
        private static StreamWriter sw;

        private const int indent_lines = 4;

        private int indent_lvl = 0;

        private readonly string file;

        public CodeGenerator(string file)
        {
            this.file = file;
        }

        public void EmitCode(string instr)
        {
            // Emits a line of code, indented with spaces
            sw.WriteLine($"{new string(' ', indent_lvl * indent_lines)}{instr}");
        }

        public void EmitNode(ParentNode node, bool block)
        {
            if (block)
            {
                EmitCode("{");
                indent_lvl++;
            }
            node.Children.ForEach(x => x.Accept(this));
            if (block)
            {
                indent_lvl--;
                EmitCode("}");
            }
        }

        public void EmitRoot(RootNode rootNode)
        {
            sw = new StreamWriter(file + ".il");
            rootNode.Children.ForEach(x => x.Accept(this));
            sw.Close();
        }
    }

    public static class Compiler
    {
        public static int errors = 0;
        
        public static (int, ParentNode) Compile(string file)
        {
            // Set a new FileStream for scanning
            var source = new FileStream(file, FileMode.Open);

            Scanner scanner = new Scanner(source);
            Parser parser = new Parser(scanner);

            parser.Parse();

            source.Close();

            errors += scanner.Errors; // errors occured in scanner
            errors += parser.Errors;

            if (errors == 0)
                Console.WriteLine("Compilation successful!\n");
            else
            {
                Console.WriteLine($"Detected errors: {errors}\n");
                File.Delete(file + ".il");
            }
            return (errors, parser.Program);
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
        
        private static RootNode GetRootNode(ParentNode program)
        {
            RootNode root = new RootNode();
            root.AddChild(new Instruction(".assembly extern mscorlib { }"));
            root.AddChild(new Instruction(".assembly minilanguage { }"));
            root.AddChild(new Instruction(".method static void main()"));

            ParentNode lvl1 = new ParentNode(true);
            lvl1.AddChild(new Instruction(".entrypoint"));
            lvl1.AddChild(new Instruction(".maxstack 256"));
            lvl1.AddChild(new Instruction(".try"));

            program.AddChild(new Instruction("leave EndMain"));
            lvl1.AddChild(program);
            lvl1.AddChild(new Instruction("catch [mscorlib]System.Exception"));

            ParentNode lvl22 = new ParentNode(true);
            lvl22.AddChild(new Instruction("callvirt instance string [mscorlib]System.Exception::get_Message()"));
            lvl22.AddChild(new Instruction("call void [mscorlib]System.Console::WriteLine(string)"));
            lvl22.AddChild(new Instruction("leave EndMain"));
            lvl1.AddChild(lvl22);
            lvl1.AddChild(new Instruction("EndMain: ret"));
            root.AddChild(lvl1);
            return root;
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
                (int errors, ParentNode program) = Compiler.Compile(file);
                CodeGenerator codeGenerator = new CodeGenerator(file);

                if (errors > 0)
                    return errors;

                if(program is null)
                {
                    throw new Exception("There's no program to run!");
                }
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
