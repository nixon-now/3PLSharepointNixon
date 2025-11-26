codeunit 50100 "Url Handler"
{
    procedure GetBaseUrl(): Text
    begin
        // Example logic to return a base URL
        exit('https://example.com');
    end;

    procedure CombineUrl(BaseUrl: Text; Path: Text): Text
var
    LastChar: Text[1];
    FirstChar: Text[1];
begin
    // Check if BaseUrl does not already end with '/'
    if StrLen(BaseUrl) > 0 then begin
        LastChar := CopyStr(BaseUrl, StrLen(BaseUrl), 1);
        if LastChar <> '/' then
            BaseUrl := BaseUrl + '/';
    end;

    // Check if Path starts with '/' and remove it
    if StrLen(Path) > 0 then begin
        FirstChar := CopyStr(Path, 1, 1);
        if FirstChar = '/' then
            Path := CopyStr(Path, 2);
    end;

    exit(BaseUrl + Path);
end;

    procedure EncodeUrl(Value: Text): Text
    begin
        // Example logic for encoding a URL
        exit(ConvertStr(Value, ' ', '%20'));
    end;
}