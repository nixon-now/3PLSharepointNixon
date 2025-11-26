xmlport 50431 "Export Orders to 3PL"
{
    Caption = 'Export Orders to 3PL';
    Direction = Export;
    Format = Xml;
    Encoding = UTF8;
    UseRequestPage = false;
    PreserveWhiteSpace = true;

    schema
    {
        textelement(orders)
        {
            textelement(server) { }

            tableelement(SalesHeader; "Sales Header")
            {
                XmlName = 'order';
                SourceTableView = sorting("Document Type", "No.");
                AutoSave = false;

                fieldelement(document_type; SalesHeader."Document Type") { }
                fieldelement(no; SalesHeader."No.") { }

                textelement(header)
                {
                    fieldelement(number; SalesHeader."No.") { }

                    textelement(ref_no) { }

                    fieldelement(po_no; SalesHeader."External Document No.") { }

                    textelement(type) { }
                    textelement(comment1) { }

                    fieldelement(contact; SalesHeader."Sell-to Contact") { }
                    
                    fieldelement(ship_via; SalesHeader."Shipping Agent Code") { }
                    fieldelement(service; SalesHeader."Shipping Agent Service Code") { }

                    textelement(soldto)
                    {
                        fieldelement(code; SalesHeader."Sell-to Customer No.") { }
                        fieldelement(name; SalesHeader."Sell-to Customer Name") { }
                        fieldelement(address1; SalesHeader."Sell-to Address") { }
                        fieldelement(address2; SalesHeader."Sell-to Address 2") { }
                        fieldelement(city; SalesHeader."Sell-to City") { }
                        fieldelement(province; SalesHeader."Sell-to County") { }
                        fieldelement(country; SalesHeader."Sell-to Country/Region Code") { }
                        fieldelement(postal; SalesHeader."Sell-to Post Code") { }
                        fieldelement(contact; SalesHeader."Sell-to Contact") { }
                        fieldelement(phone; SalesHeader."Sell-to Phone No.") { }
                        fieldelement(email; SalesHeader."Sell-to E-Mail") { }
                    }

                    textelement(shipto)
                    {
                        textelement(code)
                        {
                         trigger OnBeforePassVariable()
                            begin
                                code := GetShipToCode();
                            end;
                        }
                        
                        //fieldelement(name; SalesHeader."Ship-to Name") { }

                        textelement(name)
                        {
                            trigger OnBeforePassVariable()
                            begin
                                if SalesHeader."Ship-to Name" = '' then
                                    name := SalesHeader."Sell-to Customer Name"
                                else
                                    name := SalesHeader."Ship-to Name";
                            end;
                        }
                       

                        fieldelement(address1; SalesHeader."Ship-to Address") { }
                        fieldelement(address2; SalesHeader."Ship-to Address 2") { }
                        fieldelement(city; SalesHeader."Ship-to City") { }
                        fieldelement(province; SalesHeader."Ship-to County") { }
                        fieldelement(country; SalesHeader."Ship-to Country/Region Code") { }
                        fieldelement(postal; SalesHeader."Ship-to Post Code") { }
                        fieldelement(contact; SalesHeader."Ship-to Contact") { }
                        fieldelement(phone; SalesHeader."Sell-to Phone No.") { }
                        fieldelement(email; SalesHeader."Sell-to E-Mail") { }
                    }

                    textelement(packlist) { }
                }

                textelement(details)
                {
                    tableelement(SalesLine; "Sales Line")
                    {
                        XmlName = 'line';
                        LinkTable = SalesHeader;
                        LinkFields = "Document Type" = field("Document Type"), "Document No." = field("No.");
                        AutoSave = false;
                        SourceTableView = sorting("Document Type", "Document No.", "Line No.") where(Type = const(Item));

                        textelement(item)
                        {
                            MinOccurs = Once;
                            trigger OnBeforePassVariable()
                            begin
                                item := GetGTIN(SalesLine);
                            end;
                        }
                        //textelement(lot) { }
                        textelement(serial) { }
                        fieldelement(description; SalesLine.Description) { }
                        
                        //fieldelement(description2; SalesLine.Description) { }
                        fieldelement(qty; SalesLine.Quantity) { }
                        textelement(comment) { }
                    }
                }
            }
        }
    }

    var
        serveratt: Text;
        "3PLSetup": Record "Sharepoint Setup";
        SalesSetup: Record "Sales & Receivables Setup";
        FilterSalesHeader: Record "Sales Header";
        Window: Dialog;
        SuppressMessages: Boolean;
        GuiAllowed: Boolean;

    trigger OnPreXmlPort()
    begin
        if not "3PLSetup".Get('3PL') then
            Error('SP Setup not configured');

        SalesSetup.Get();

        SalesHeader.Reset();
        SalesHeader.SetRange("Document Type", FilterSalesHeader."Document Type");
        SalesHeader.SetRange("No.", FilterSalesHeader."No.");

        serveratt := 'van';

        if GuiAllowed and GUIALLOWED then
            Window.Open('Exporting order #1##########', SalesHeader."No.");
    end;

    trigger OnPostXmlPort()
    begin
        if GuiAllowed and GUIALLOWED then
            Window.Close();

        if not SuppressMessages and GUIALLOWED then
            Message('Successfully exported order %1 to 3PL', SalesHeader."No.");
    end;

    procedure SetFilterRecord(var InFilterSalesHeader: Record "Sales Header")
    begin
        FilterSalesHeader := InFilterSalesHeader;
        FilterSalesHeader.SetRange("Document Type", InFilterSalesHeader."Document Type");
        FilterSalesHeader.SetRange("No.", InFilterSalesHeader."No.");
    end;
     local procedure GetWorkDescriptionText(SalesHeader: Record "Sales Header"): Text
var
    TypeHelper: Codeunit "Type Helper";
    InStream: InStream;
    WorkDescriptionText: Text;
begin
    SalesHeader.CalcFields("Work Description");
    if not SalesHeader."Work Description".HasValue then
        exit('');

    SalesHeader."Work Description".CreateInStream(InStream);
    WorkDescriptionText := TypeHelper.ReadAsTextWithSeparator(InStream, TypeHelper.LFSeparator());
    
    exit(WorkDescriptionText);
end;

    procedure SetSuppressMessages(Suppress: Boolean)
    begin
        SuppressMessages := Suppress;
    end;

    procedure SetGuiAllowed(Allowed: Boolean)
    begin
        GuiAllowed := Allowed;
    end;

    local procedure GetShipToCode(): Code[20]
    begin
        if SalesHeader."Ship-to Code" = '' then
            exit('DEFAULT');
        exit(SalesHeader."Ship-to Code");
    end;

    local procedure GetGTIN(SL: Record "Sales Line"): Code[30]
    var
        Item: Record Item;
        ItemRef: Record "Item Reference";
    begin
        if Item.Get(SL."No.") then
            if Item."GTIN" <> '' then
                exit(Item."GTIN");

        ItemRef.Reset();
        ItemRef.SetRange("Item No.", SL."No.");
        ItemRef.SetRange("Variant Code", SL."Variant Code");
        ItemRef.SetRange("Unit of Measure", SL."Unit of Measure Code");
        ItemRef.SetRange("Reference Type", ItemRef."Reference Type"::"Bar Code");
        ItemRef.SetFilter("Description", '@%1*', 'UPC'); // begins with 'UPC' (case-insensitive)
        if ItemRef.FindFirst() then
            exit(ItemRef."Reference No.");

        exit('');
    end;
}
