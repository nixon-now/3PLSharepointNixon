codeunit 50403 "Text Cleaner"
{
    procedure CleanSharePointText(InputText: Text) OutputText: Text
    begin
        // Remove all non-printable characters
        OutputText := DelChr(InputText, '=', GetNonPrintableChars());
        
        // Trim whitespace
        OutputText := OutputText.Trim();
        
        // Replace any remaining newlines with spaces
        OutputText := ConvertStr(OutputText, '''\r\n''', '  ');
    end;

    local procedure GetNonPrintableChars(): Text
    var
        NonPrintables: List of [Char];
        c: Char;
        i: Integer;
    begin
        // Add all control characters (0-31) except tab (9)
        for i := 0 to 31 do
            if i <> 9 then
                NonPrintables.Add(i);
        
        // Add extended ASCII control chars (127-159)
        for i := 127 to 159 do
            NonPrintables.Add(i);
        
        exit(CharListToText(NonPrintables));
    end;

    local procedure CharListToText(Chars: List of [Char]): Text
    var
        Result: Text;
        c: Char;
    begin
        foreach c in Chars do
            Result += c;
        exit(Result);
    end;
}