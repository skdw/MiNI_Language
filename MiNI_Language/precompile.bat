cd ..\..\
GP_for_Net40\gplex.exe /out:Scanner.cs .\kompilator.lex
GP_for_Net40\Gppg.exe /gplex /out:Parser.cs .\kompilator.y
pause
exit