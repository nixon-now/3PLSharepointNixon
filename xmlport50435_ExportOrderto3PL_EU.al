xmlport 50435 "Export Orders to 3PL_EU"
{
    Caption = 'Export Orders (3PL Detailed)';
    Direction = Export;
    Format = Xml;
    Encoding = UTF8;
    UseRequestPage = false;
    PreserveWhiteSpace = true;

    //──────────────────────── S C H E M A ────────────────────────
    schema
    {
        textelement(orders)
        {
            textelement(server) { }

            //----------------------------------------------------
            //  <order no="1">
            //----------------------------------------------------
            tableelement(SalesHeader; "Sales Header")
            {
                XmlName = 'order';
                AutoSave = false;
                SourceTableView = sorting("Document Type", "No.")
                                  where("Document Type" = const(Order),
                                        Status = const(Released));

                // Attribute  no="1"
                textattribute(OrderNoAttr)
                {
                    XmlName = 'no';
                    trigger OnBeforePassVariable()
                    begin
                        OrderNoAttr := '1';   // literal value required by 3 PL
                    end;
                }

                //================ HEADER =================
                textelement(header)
                {
                    textelement(location)
                    {
                        MinOccurs = Once;  // This ensures the element appears even if empty
                        trigger OnBeforePassVariable()
                        begin
                            if SalesHeader."Location Code" = '1-EU' then
                                location := 'H01'
                            else
                                location := '';  // or whatever default you want
                        end;
                    }

                    fieldelement(number; SalesHeader."No.") { }

                    // <delivery_no>
                    textelement(delivery_no)
                    {
                        trigger OnBeforePassVariable()

                        begin
                            delivery_no := BuildDeliveryNo();
                        end;
                    }


                    fieldelement(po_no; SalesHeader."External Document No.") { }
                    textelement(preparation_code)
                    {
                        MinOccurs = Once;
                        trigger OnBeforePassVariable()
                        begin
                            preparation_code := SalesHeader."3PL Prep Code";
                        end;
                    }


                    // sample shows both <ship_via> and <service>
                    textelement(ship_via)
                    {
                        trigger OnBeforePassVariable()
                        begin
                            ship_via := SalesHeader."Shipping Agent Code";
                        end;
                    }
                    textelement(service)
                    {
                        trigger OnBeforePassVariable()
                        begin
                            service := SalesHeader."Shipping Agent Service Code";
                        end;
                    }

                    fieldelement(shipment_method_code; SalesHeader."Shipment Method Code") { }
                    fieldelement(language_code; SalesHeader."Language Code") { }
                    fieldelement(contact; SalesHeader."Sell-to Phone No.") { }

                    textelement(shipping_agent_account_no) { MinOccurs = Zero; }

                    // optional / calculated tags
                    textelement(ref_no)
                    {
                        MinOccurs = Zero;
                        trigger OnBeforePassVariable()
                        begin
                            ref_no := SalesHeader."Your Reference";
                        end;
                    }

                    textelement(shipon)
                    {
                        trigger OnBeforePassVariable()
                        begin
                            shipon :=
                              Format(SalesHeader."Shipment Date", 0, '<Year4>-<Month,2>-<Day,2>');
                        end;
                    }

                    textelement(priority) { trigger OnBeforePassVariable() begin priority := '3'; end; }
                    textelement(status) { trigger OnBeforePassVariable() begin status := ''; end; }

                    textelement(comment)
                    {
                        trigger OnBeforePassVariable()
                        begin
                            comment := GetHeaderComment(SalesHeader."No.");
                        end;
                    }

                    // COD / gift / VAT blanks
                    textelement(cod) { trigger OnBeforePassVariable() begin cod := 'N'; end; }
                    textelement(cod_amount) { trigger OnBeforePassVariable() begin cod_amount := ''; end; }
                    textelement(gift_wrap) { trigger OnBeforePassVariable() begin gift_wrap := 'N'; end; }
                    //fieldelement(gift_message;  SalesHeader."Work Description")   { }
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
                    textelement(vat) { trigger OnBeforePassVariable() begin vat := ''; end; }

                    // ---------- SOLD-TO ----------
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

                        // <fax> under SOLD-TO
                        textelement(soldto_fax)
                        {
                            XmlName = 'fax';
                            trigger OnBeforePassVariable()
                            begin
                                soldto_fax := '';  // map if you have it
                            end;
                        }

                        fieldelement(email; SalesHeader."Sell-to E-Mail") { }
                    }

                    // ---------- SHIP-TO ----------
                    textelement(shipto)
                    {
                        fieldelement(code; SalesHeader."Ship-to Code") { }
                        fieldelement(name; SalesHeader."Ship-to Name") { }
                        fieldelement(name2; SalesHeader."Ship-to Name 2") { }
                        fieldelement(address1; SalesHeader."Ship-to Address") { }
                        fieldelement(address2; SalesHeader."Ship-to Address 2") { }
                        fieldelement(city; SalesHeader."Ship-to City") { }
                        fieldelement(province; SalesHeader."Ship-to County") { }
                        fieldelement(country; SalesHeader."Ship-to Country/Region Code") { }
                        fieldelement(postal; SalesHeader."Ship-to Post Code") { }
                        fieldelement(contact; SalesHeader."Ship-to Contact") { }
                        textelement(phone)
                        {
                            trigger OnBeforePassVariable()
                            begin
                                IF SalesHeader."External Document No." = 'EUR-*' THEN
                                    phone := SalesHeader."Sell-to Phone No."
                                ELSE
                                    phone := SalesHeader."Ship-to Phone No.";
                            end;
                        }

                        // separate <fax> for ship-to
                        textelement(shipto_fax)
                        {
                            XmlName = 'fax';
                            trigger OnBeforePassVariable()
                            begin
                                shipto_fax := '';
                            end;
                        }

                        fieldelement(email; SalesHeader."Sell-to E-Mail") { }
                    }

                    textelement(packlist) { trigger OnBeforePassVariable() begin packlist := ''; end; }
                }

                //================ DETAILS =================
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

                        // Attribute  no="10000"
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
                            MinOccurs = Zero;
                            trigger OnBeforePassVariable()
                            begin
                                gtin := GetGTIN(SalesLine);
                            end;
                        }
                        textelement(lot) { MinOccurs = Zero; }
                        textelement(customer_sku_no)
                        {
                            MinOccurs = Zero;
                            trigger OnBeforePassVariable()
                            begin
                                customer_sku_no := CustomerSKU(SalesLine);
                            end;
                        }
                        textelement(serial) { MinOccurs = Zero; }
                        fieldelement(description; SalesLine.Description) { }
                        fieldelement(qty; SalesLine.Quantity) { }

                        // <comment> per line
                        textelement(line_comment)
                        {
                            XmlName = 'comment';
                            MinOccurs = Zero;
                        }

                        // Prices
                        fieldelement(unit_price; SalesLine."Unit Price")
                        {


                        }
                        textelement(unit_price_discounted)
                        {
                            trigger OnBeforePassVariable()
                            var
                                DiscountedPrice: Decimal;
                            begin
                                // Simple and reliable calculation
                                if SalesLine."Line Discount %" > 0 then begin
                                    DiscountedPrice := SalesLine."Unit Price" * (1 - SalesLine."Line Discount %" / 100);
                                    DiscountedPrice := Round(DiscountedPrice, 0.01); // Round to 2 decimal places
                                end else begin
                                    DiscountedPrice := SalesLine."Unit Price";
                                end;

                                // Format the result
                                unit_price_discounted := FormatDecEU(DiscountedPrice);
                            end;

                        }

                        textelement(vat_percent)
                        {
                            trigger OnBeforePassVariable()
                            begin
                                vat_percent := FormatDecEU(SalesLine."VAT %");
                            end;
                        }

                        fieldelement(currency_code; SalesLine."Currency Code") { }
                        textelement(content) { MinOccurs = Zero; }

                        // weight fields formatted EU style
                        textelement(net_weight)
                        {
                            trigger OnBeforePassVariable()
                            begin
                                net_weight := FormatDecEU(SalesLine."Net Weight");
                            end;
                        }
                        textelement(gross_weight)
                        {
                            trigger OnBeforePassVariable()
                            begin
                                gross_weight := FormatDecEU(SalesLine."Gross Weight");
                            end;
                        }

                        // HTS code & COO from Item
                        textelement(htscode)
                        {
                            MinOccurs = Zero;
                            trigger OnBeforePassVariable()
                            var
                                Itm: Record Item;
                            begin
                                if Itm.Get(SalesLine."No.") then
                                    htscode := Itm."Tariff No.";
                            end;
                        }
                        textelement(countryoforigin)
                        {
                            MinOccurs = Zero;
                            trigger OnBeforePassVariable()
                            var
                                Itm: Record Item;
                            begin
                                if Itm.Get(SalesLine."No.") then
                                    countryoforigin := Itm."Country/Region of Origin Code";
                            end;
                        }
                    }
                }
            }
        }
    }

    //──────────────────────── V A R I A B L E S ────────────────────────
    var
        ItemRef: Record "Item Reference";
    // for attributes & triggers


    //──────────────────────── H E L P E R S ────────────────────────────
    local procedure BuildDeliveryNo(): Code[20]
    begin
        exit(
            'M' +
            Format(Today, 0, '<Year4>-<Month,2>-<Day,2>'));
    end;


    local procedure GetHeaderComment(OrderNo: Code[20]): Text[250]
    var
        CL: Record "Comment Line";
        Txt: Text[250];
    begin
        CL.SetRange("Table Name", Database::"Sales Header");
        CL.SetRange("Line No.", 0);
        CL.SetRange("No.", OrderNo);
        if CL.FindSet() then
            repeat
                Txt := CopyStr(Txt + CL.Comment + ' ', 1, MaxStrLen(Txt));
            until CL.Next() = 0;
        exit(Txt);
    end;

    local procedure CustomerSKU(SL: Record "Sales Line"): Code[20]
    var
        Ref: Record "Item Reference";
    begin
        Ref.SetRange("Item No.", SL."No.");
        Ref.SetRange("Reference Type", Ref."Reference Type"::Customer);
        if Ref.FindFirst() then
            exit(Ref."Reference No.");
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

    local procedure FormatDecEU(Val: Decimal): Text[20]
    var
        FormattedText: Text;
    begin
        // Use a standard format specifier for consistent output (e.g., 1234.56)
        // <Integer>      - The integer part
        // <.>            - Explicitly use a period for the decimal separator
        // <Decimals,2>   - Show exactly two decimal places, padding with zero if needed
        FormattedText := FORMAT(Val, 0, 9);

        // If the value was 0, the format might result in just ".00". Prepend a "0".
        if STRPOS(FormattedText, '.') = 1 then
            exit('0' + FormattedText);

        exit(FormattedText);
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
}