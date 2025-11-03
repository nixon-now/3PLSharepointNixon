codeunit 50411 "XmlWrapper"
{
    Access = Public;

    procedure ProcessPickConfirmation(var InStr: InStream)
    var
        ImportPickXmlPort: XmlPort "Import Pick Confirmation";
    begin
        ImportPickXmlPort.SetSource(InStr);
        ImportPickXmlPort.Import();
    end;

    procedure ProcessShipConfirmation(var InStr: InStream)
    var
        ImportShipXmlPort: XmlPort "Import Shipped Confirmation";
    begin
        ImportShipXmlPort.SetSource(InStr);
        ImportShipXmlPort.Import();
    end;

    procedure ProcessXmlByType(FileName: Text; var InStr: InStream)
    var
        LowerFileName: Text;
    begin
        LowerFileName := FileName.ToLower();

        if StrPos(LowerFileName, 'pick') > 0 then
            ProcessPickConfirmation(InStr)
        else
            if StrPos(LowerFileName, 'ship') > 0 then
                ProcessShipConfirmation(InStr)
            else
                Error('Unsupported file type: %1', FileName);
    end;
}
