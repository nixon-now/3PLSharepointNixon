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
            textelement(server)
            {
            }
            tableelement(SalesHeader; "Sales Header")
            {
                XmlName = 'order';
                SourceTableView = sorting("Document Type", "No.");
                AutoSave = false;

                fieldelement(document_type; SalesHeader."Document Type")
                {
                }
                fieldelement(no; SalesHeader."No.")
                {
                }

                textelement(header)
                {
                    fieldelement(number; SalesHeader."No.")
                    {
                    }
                    textelement(ref_no)
                    {
                    }
                    fieldelement(po_no; SalesHeader."External Document No.")
                    {
                    }
                    textelement(type)
                    {
                    }
                    textelement(comment1)
                    {
                    }
                    fieldelement(contact; SalesHeader."Sell-to Contact")
                    {
                    }
                    fieldelement(ship_via; SalesHeader."Shipment Method Code")
                    {
                    }
                    fieldelement(service; SalesHeader."Shipping Agent Service Code")
                    {
                    }

                    textelement(soldto)
                    {
                        fieldelement(code; SalesHeader."Sell-to Customer No.")
                        {
                        }
                        fieldelement(name; SalesHeader."Sell-to Customer Name")
                        {
                        }
                        fieldelement(address1; SalesHeader."Sell-to Address")
                        {
                        }
                        fieldelement(address2; SalesHeader."Sell-to Address 2")
                        {
                        }
                        fieldelement(city; SalesHeader."Sell-to City")
                        {
                        }
                        fieldelement(province; SalesHeader."Sell-to County")
                        {
                        }
                        fieldelement(country; SalesHeader."Sell-to Country/Region Code")
                        {
                        }
                        fieldelement(postal; SalesHeader."Sell-to Post Code")
                        {
                        }
                        fieldelement(contact; SalesHeader."Sell-to Contact")
                        {
                        }
                        fieldelement(phone; SalesHeader."Sell-to Phone No.")
                        {
                        }
                        //textelement(fax) { }
                        fieldelement(email; SalesHeader."Sell-to E-Mail")
                        {
                        }
                    }

                    textelement(shipto)
                    {
                        // Filled directly from the Sales Header, as requested
                        fieldelement(code; SalesHeader."Ship-to Code")
                        {
                        }
                        fieldelement(name; SalesHeader."Ship-to Name")
                        {
                        }
                        fieldelement(address1; SalesHeader."Ship-to Address")
                        {
                        }
                        fieldelement(address2; SalesHeader."Ship-to Address 2")
                        {
                        }
                        fieldelement(city; SalesHeader."Ship-to City")
                        {
                        }
                        fieldelement(province; SalesHeader."Ship-to County")
                        {
                        }
                        fieldelement(country; SalesHeader."Ship-to Country/Region Code")
                        {
                        }
                        fieldelement(postal; SalesHeader."Ship-to Post Code")
                        {
                        }
                        fieldelement(contact; SalesHeader."Ship-to Contact")
                        {
                        }
                        // Note: BC standard doesn't have "Ship-to Phone No." on Sales Header; keeping Sell-to Phone No. as in your version.
                        fieldelement(phone; SalesHeader."Sell-to Phone No.")
                        {
                        }
                        //textelement(fax1) { }
                        fieldelement(email; SalesHeader."Sell-to E-Mail")
                        {
                        }
                    }

                    textelement(packlist)
                    {
                    }
                }

                textelement(details)
                {
                    tableelement(SalesLine; "Sales Line")
                    {
                        XmlName = 'line';
                        LinkTable = SalesHeader;
                        LinkFields = "Document Type" = field("Document Type"), "Document No." = field("No.");
                        AutoSave = false;

                        // === CHANGE #1: Only export Item lines ===
                        SourceTableView = sorting("Document Type", "Document No.", "Line No.")
                                          where(Type = const(Item));

                        fieldelement(item; SalesLine."No.")
                        {
                        }
                        textelement(serial)
                        {
                        }
                        fieldelement(description; SalesLine.Description)
                        {
                        }
                        fieldelement(qty; SalesLine.Quantity)
                        {
                        }
                        textelement(comment)
                        {
                        }
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

        // Clear any existing filters
        SalesHeader.Reset();

        // Apply the exact filters from FilterSalesHeader
        SalesHeader.SetRange("Document Type", FilterSalesHeader."Document Type");
        SalesHeader.SetRange("No.", FilterSalesHeader."No.");

        serveratt := 'van';

        if GuiAllowed then
            Window.Open('Exporting order #1##########', SalesHeader."No.");
    end;

    trigger OnPostXmlPort()
    begin
        if GuiAllowed then
            Window.Close();

        if not SuppressMessages then
            Message('Successfully exported order %1 to 3PL', SalesHeader."No.");
    end;

    procedure SetFilterRecord(var InFilterSalesHeader: Record "Sales Header")
    begin
        FilterSalesHeader := InFilterSalesHeader;
        FilterSalesHeader.SetRange("Document Type", InFilterSalesHeader."Document Type");
        FilterSalesHeader.SetRange("No.", InFilterSalesHeader."No.");
    end;

    procedure SetSuppressMessages(Suppress: Boolean)
    begin
        SuppressMessages := Suppress;
    end;

    procedure SetGuiAllowed(Allowed: Boolean)
    begin
        GuiAllowed := Allowed;
    end;
}
