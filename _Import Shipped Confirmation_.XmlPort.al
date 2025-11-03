xmlport 50434 "Import Shipped Confirmation"
{
    Direction = Import;
    Format = Xml;
    Encoding = UTF8;
    UseDefaultNamespace = true;
    DefaultNamespace = 'urn:3pl-integration';
    PreserveWhiteSpace = true;

    schema
    {
        textelement(root)
        {
            textelement(orders)
            {
                textelement(order)
                {
                    textattribute(server) { }
                    textattribute(time) { }

                    textelement(id) { }

                    textelement(number) 
                    {
                        trigger OnAfterAssignVariable()
                        begin
                            // Use filename as fallback if XML doesn't contain order number
                            if number = '' then
                                XmlOrderNo := GetOrderNoFromFilename()
                            else
                                XmlOrderNo := number;
                            
                            ProcessOrder();
                        end;
                    }

                    textelement(courier) 
                    {
                        trigger OnAfterAssignVariable()
                        begin
                            XmlCourier := courier;
                        end;
                    }

                    textelement(service) { }

                    textelement(status) { }

                    textelement(tracking_no) 
                    {
                        trigger OnAfterAssignVariable()
                        begin
                            XmlTrackingNo := tracking_no;
                        end;
                    }

                    textelement(shipped) 
                    {
                        trigger OnAfterAssignVariable()
                        begin
                            XmlShipped := shipped;
                        end;
                    }

                    textelement(cod) { }

                    textelement(charges)
                    {
                        textelement(charge) { }
                        textelement(invoice) { }
                    }
                }
            }
        }
    }

    trigger OnPreXmlPort()
    begin
        ShipmentCount := 0;
        ShipmentSkipCount := 0;
        if GuiAllowed then
            Window.Open(
              'Importing Shipment Confirmation...\' +
              'Sales Order No.:      #1##############\' +
              'Progress:             @2##############',
              XmlOrderNo, ShipmentCount);
    end;

    trigger OnPostXmlPort()
    begin
        if GuiAllowed then Window.Close();
        if not SuppressMessages then
            Message('Imported %1 shipment confirmation(s).', ShipmentCount);
    end;

    local procedure ProcessOrder()
    var
        SalesHeader: Record "Sales Header";
        ShipDate: Date;
    begin
        if XmlOrderNo = '' then
            exit;

        if SalesHeader.Get(SalesHeader."Document Type"::Order, XmlOrderNo) then begin
            ShipmentCount += 1;

            // Update custom 3PL fields
            SalesHeader."3PL Tracking No." := XmlTrackingNo;
            SalesHeader."Shipping Agent Code" := XmlCourier;

            if Evaluate(ShipDate, XmlShipped) then
                SalesHeader."Shipment Date" := ShipDate;

            SalesHeader.Modify();

            if GuiAllowed then
                Window.Update(1, XmlOrderNo);
        end else
            ShipmentSkipCount += 1;
    end;

    local procedure GetOrderNoFromFilename(): Code[20]
    var
        Setup: Record "SharePoint Setup";
        FileNameWithoutExt: Text;
        MaxChars: Integer;
    begin
        if not Setup.Get('3PL') then
            exit('');

        // Get the configured number of characters to parse
        MaxChars := Setup."Filename Chars to Parse";
        if MaxChars <= 0 then
            MaxChars := 20; // Default value if not configured

        // Remove .xml extension
        FileNameWithoutExt := DelChr(CurrentFilename, '=', '.xml');

        // Extract the order number portion
        if StrLen(FileNameWithoutExt) > MaxChars then
            exit(CopyStr(FileNameWithoutExt, 1, MaxChars))
        else
            exit(FileNameWithoutExt);
    end;

    var
        XmlOrderNo: Code[20];
        XmlCourier: Text[20];
        XmlTrackingNo: Text[50];
        XmlShipped: Text[30];
        ShipmentCount: Integer;
        ShipmentSkipCount: Integer;
        SuppressMessages: Boolean;
        GuiAllowed: Boolean;
        Window: Dialog;
        CurrentFilename: Text;

    procedure SetCurrentFilename(Filename: Text)
    begin
        CurrentFilename := Filename;
    end;

    procedure SetSuppressMessages(Suppress: Boolean)
    begin
        SuppressMessages := Suppress;
    end;

    procedure SetGuiAllowed(Allowed: Boolean)
    begin
        GuiAllowed := Allowed;
    end;

    procedure GetShipmentCount(): Integer
    begin
        exit(ShipmentCount);
    end;

    procedure GetShipSkipCount(): Integer
    begin
        exit(ShipmentSkipCount);
    end;
}