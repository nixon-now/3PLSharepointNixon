xmlport 50436 "Export Orders to 3PL_AU"
{
    Caption            = 'Export Orders (3PL Detailed)';
    Direction          = Export;
    Format             = Xml;
    Encoding           = UTF8;
    UseRequestPage     = false;
    PreserveWhiteSpace = true;
    

    schema
    {
        textelement(orders)
        {
            // Removed server element as not in target XML
            tableelement(SalesHeader; "Sales Header")
            {
                XmlName  = 'order';
                AutoSave = false;
                SourceTableView = sorting("Document Type", "No.")
                                  where("Document Type" = const(Order),
                                        Status          = const(Released));

                textattribute(OrderNoAttr)
                {
                    XmlName = 'no';
                    trigger OnBeforePassVariable()
                    begin
                        OrderNoAttr := '1';
                    end;
                }

                textelement(header)
                {
                    fieldelement(location; SalesHeader."Location Code") { }
                    fieldelement(number; SalesHeader."No.") { }

                    textelement(delivery_no)
                    {
                        trigger OnBeforePassVariable()
                        begin
                            delivery_no := BuildDeliveryNo();
                        end;
                    }

                    textelement(ref_no)
                    {
                        MinOccurs = Zero;
                        trigger OnBeforePassVariable()
                        begin
                            ref_no := SalesHeader."Your Reference";
                        end;
                    }

                    fieldelement(po_no; SalesHeader."External Document No.") { }
                    
                    textelement(shipon)
                    {
                        trigger OnBeforePassVariable()
                        begin
                            shipon := Format(SalesHeader."Shipment Date", 0, '<Year4>-<Month,2>-<Day,2>');
                        end;
                    }

                    textelement(priority)
                    {
                        trigger OnBeforePassVariable()
                        begin
                            priority := '3';
                        end;
                    }

                  textelement(preparation_code)
                    {
                        MinOccurs = Once;
                        trigger OnBeforePassVariable()
                        begin
                            preparation_code := SalesHeader."3PL Prep Code";
                        end;
                    }
                    textelement(status)
                    {
                        trigger OnBeforePassVariable()
                        begin
                            // Set to empty or implement cancellation logic
                            status := '';
                        end;
                    }

                    textelement(comment2)
                    {
                        XmlName = 'comment';
                        trigger OnBeforePassVariable()
                        begin
                            comment := GetHeaderComment(SalesHeader."No.");
                        end;
                    }

                    textelement(contact)
                    {
                        MinOccurs = Zero;
                        trigger OnBeforePassVariable()
                        begin
                            contact := SalesHeader."Sell-to Phone No.";
                        end;
                    }

                    textelement(ship_via)
                    {
                        trigger OnBeforePassVariable()
                        begin
                            ship_via := SalesHeader."Shipping Agent Code";
                        end;
                    }

                    textelement(service)
                    {
                        MinOccurs = Zero;
                        trigger OnBeforePassVariable()
                        begin
                            service := SalesHeader."Shipping Agent Service Code";
                        end;
                    }

                    textelement(cod)
                    {
                        trigger OnBeforePassVariable()
                        begin
                            cod := 'N';
                        end;
                    }

                    textelement(cod_amount)
                    {
                        trigger OnBeforePassVariable()
                        begin
                            cod_amount := '';
                        end;
                    }

                    textelement(gift_wrap)
                    {
                        trigger OnBeforePassVariable()
                        begin
                            gift_wrap := 'N';
                        end;
                    }

                    textelement(gift_message)
                    {
                        trigger OnBeforePassVariable()
                        var
                        WorkDescriptionText: Text;
                    begin
                        // Get the work description as text
                        WorkDescriptionText := GetWorkDescriptionText(SalesHeader);
                        
                        // Truncate to a reasonable length if needed, but don't use '*'
                        if StrLen(WorkDescriptionText) > 250 then
                            gift_message := CopyStr(WorkDescriptionText, 1, 250)
                        else
                            gift_message := WorkDescriptionText;
                    end;
                }
                    textelement(language_code)
                    {
                        MinOccurs = Zero;
                        trigger OnBeforePassVariable()
                        begin
                            language_code := '';
                        end;
                    }                   

                    // Sold-to section
                    textelement(soldto)
                    {
                        fieldelement(code; SalesHeader."Sell-to Customer No.") { }
                        fieldelement(name; SalesHeader."Sell-to Customer Name") { }
                        fieldelement(name2; SalesHeader."Sell-to Customer Name 2") { }
                        fieldelement(address1; SalesHeader."Sell-to Address") { }
                        fieldelement(address2; SalesHeader."Sell-to Address 2") { }
                        fieldelement(city; SalesHeader."Sell-to City") { }
                        fieldelement(province; SalesHeader."Sell-to County") { }
                        fieldelement(country; SalesHeader."Sell-to Country/Region Code") { }
                        fieldelement(postal; SalesHeader."Sell-to Post Code") { }
                        fieldelement(contact; SalesHeader."Sell-to Contact") { }
                        fieldelement(phone; SalesHeader."Sell-to Phone No.") { }
                        
                        textelement(fax1)
                        {
                              MinOccurs = Zero;    
                            XmlName = 'fax';
                            trigger OnBeforePassVariable()
                            begin
                                fax := '';
                            end;
                        }
                        
                        fieldelement(email; SalesHeader."Sell-to E-Mail") { }
                    }

                    // Ship-to section
                    textelement(shipto)
                    {
                        fieldelement(code; SalesHeader."Ship-to Code") { }
                        
                        // New elements for AU
                        textelement(clientstorecode)
                        {
                            trigger OnBeforePassVariable()
                            begin
                                clientstorecode := SalesHeader."Ship-to Code";
                            end;
                        }
                        
                        fieldelement(name; SalesHeader."Ship-to Name") { }
                        fieldelement(name2; SalesHeader."Ship-to Name 2") { }
                        fieldelement(address1; SalesHeader."Ship-to Address") { }
                        fieldelement(address2; SalesHeader."Ship-to Address 2") { }
                        fieldelement(city; SalesHeader."Ship-to City") { }
                        fieldelement(province; SalesHeader."Ship-to County") { }
                        fieldelement(country; SalesHeader."Ship-to Country/Region Code") { }
                        fieldelement(postal; SalesHeader."Ship-to Post Code") { }
                        
                        // New element for AU
                        textelement(clientdepartment)
                        {
                            trigger OnBeforePassVariable()
                            begin
                                clientdepartment := '';
                            end;
                        }
                        
                        fieldelement(contact; SalesHeader."Ship-to Contact") {
                              MinOccurs = Zero;    
                         }
                        fieldelement(phone; SalesHeader."Ship-to Phone No.") { 
                              MinOccurs = Zero;    
                        }
                        
                        textelement(fax)
                        {
                              MinOccurs = Zero;    
                            trigger OnBeforePassVariable()
                            begin
                                fax := '';
                            end;
                        }
                        
                        fieldelement(email; SalesHeader."Sell-to E-Mail") { }
                    }

                    textelement(packlist)
                    {
                        trigger OnBeforePassVariable()
                        begin
                            packlist := '';
                        end;
                    }
                }

                textelement(details)
                {
                    tableelement(SalesLine; "Sales Line")
                    {
                        XmlName = 'line';
                        AutoSave = false;
                        LinkTable = SalesHeader;
                        LinkFields = "Document No." = field("No.");
                        SourceTableView = sorting("Document No.", "Line No.")
                                          where(Type = const(Item));

                        textattribute(LineNo)
                        {
                            trigger OnBeforePassVariable()
                            begin
                                LineNo := Format(SalesLine."Line No.");
                            end;
                        }

                        fieldelement(item; SalesLine."No.") { }
                        textelement(gtin)
                        {
                            trigger OnBeforePassVariable()
                            begin
                                gtin := GetGTIN(SalesLine);
                            end;
                        }
                        
                        // New element for AU
                        textelement(gtin2)
                        {
                            trigger OnBeforePassVariable()
                            begin
                                // Use same as GTIN if needed or implement separate logic
                                gtin2 := GetGTIN2(SalesLine);
                            end;
                        }
                        
                        textelement(lot) 
                        { 
                            MinOccurs = Zero;
                            trigger OnBeforePassVariable()
                            begin
                                lot := '';
                            end;
                        }
                        
                        textelement(customer_sku_no)
                        {
                            MinOccurs = Zero;
                            trigger OnBeforePassVariable()
                            begin
                                customer_sku_no := CustomerSKU(SalesLine);
                            end;
                        }
                        
                        textelement(serial) 
                        { 
                            MinOccurs = Zero;
                            trigger OnBeforePassVariable()
                            begin
                                serial := '';
                            end;
                        }
                        
                        fieldelement(description; SalesLine.Description) { }
                        fieldelement(qty; SalesLine.Quantity) { }
                        
                        textelement(comment)
                        {
                            MinOccurs = Zero;
                            trigger OnBeforePassVariable()
                            begin
                                comment := '';
                            end;
                        }
                        
                        textelement(unit_price)
{
    trigger OnBeforePassVariable()
    begin
        
        if SalesLine."Unit Price" = 0 then
            unit_price := '0'
        else
            unit_price := Format(SalesLine."Unit Price", 0, 9);
    end;
}
                        
                        fieldelement(currency_code; SalesLine."Currency Code") { }
                    }
                }
            }
        }
    }

    var
        ItemRef: Record "Item Reference";

    local procedure GetDimensionValue(DimSetID: Integer; DimCode: Code[20]): Code[20]
var
    DimEntry: Record "Dimension Set Entry";
begin
    if DimEntry.Get(DimSetID, DimCode) then
        exit(DimEntry."Dimension Value Code");
    exit('');
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

    local procedure BuildDeliveryNo(): Code[20]
    begin
        exit(
            'M' +
            Format(Today, 0, '<Year4>-<Month,2>-<Day,2>'));
    end;

    local procedure GetHeaderComment(OrderNo: Code[20]): Text[250]
    var
        CommentLine: Record "Comment Line";
        CommentText: Text[250];
    begin
        CommentLine.SetRange("Table Name", Database::"Sales Header");
        CommentLine.SetRange("Line No.", 0);
        CommentLine.SetRange("No.", OrderNo);
        if CommentLine.FindSet() then
            repeat
                CommentText := CopyStr(CommentText + CommentLine.Comment + ' ', 1, MaxStrLen(CommentText));
            until CommentLine.Next() = 0;
        exit(CommentText);
    end;

    local procedure CustomerSKU(SalesLine: Record "Sales Line"): Code[20]
    var
        ItemReference: Record "Item Reference";
    begin
        ItemReference.SetRange("Item No.", SalesLine."No.");
        ItemReference.SetRange("Reference Type", ItemReference."Reference Type"::Customer);
        if ItemReference.FindFirst() then
            exit(ItemReference."Reference No.");
        exit('');
    end;

    local procedure GetGTIN(SL: Record "Sales Line"): Code[30]
    var
        Itm: Record Item;
    begin
        if Itm.Get(SL."No.") then
            if Itm."GTIN" <> '' then
                exit(Itm."GTIN");

        ItemRef.Reset();
        ItemRef.SetRange("Item No.", SL."No.");
        ItemRef.SetRange("Variant Code", SL."Variant Code");
        ItemRef.SetRange("Unit of Measure", SL."Unit of Measure Code");
        ItemRef.SetRange("Reference Type", ItemRef."Reference Type"::"Bar Code");
        ItemRef.SetFilter("Description", 'EAN*'); //ItemRef."Reference Type"::"Bar Code");

        if ItemRef.FindFirst() then
            exit(ItemRef."Reference No.");

        exit('');
    end;
    local procedure GetGTIN2(SL: Record "Sales Line"): Code[30]
var
        Itm: Record Item;
    begin
        if Itm.Get(SL."No.") then
            if Itm."GTIN" <> '' then
                exit(Itm."GTIN");

        ItemRef.Reset();
        ItemRef.SetRange("Item No.", SL."No.");
        ItemRef.SetRange("Variant Code", SL."Variant Code");
        ItemRef.SetRange("Unit of Measure", SL."Unit of Measure Code");
        ItemRef.SetRange("Reference Type", ItemRef."Reference Type"::"Bar Code");
        ItemRef.SetFilter("Description", 'UPC*'); //ItemRef."Reference Type"::"Bar Code");

        if ItemRef.FindFirst() then
            exit(ItemRef."Reference No.");

        exit('');
    end;
}