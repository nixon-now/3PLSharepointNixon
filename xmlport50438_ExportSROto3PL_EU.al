xmlport 50438 "Export SRO to 3PL_EU"
{
    Caption = 'Export Sales Return Orders (3PL EU)';
    Direction = Export;
    Format = Xml;
    Encoding = UTF8;
    UseRequestPage = false;
    PreserveWhiteSpace = true;

    schema
    {
        textelement(orders)
        {
            //  <order no="1">
            tableelement(SalesHeader; "Sales Header")
            {
                XmlName = 'order';
                AutoSave = false;
                SourceTableView = sorting("Document Type", "No.")
                                  where("Document Type" = const("Return Order"),
                                        Status = const(Released));

                // Attribute  no="1"
                textattribute(OrderNoAttr)
                {
                    XmlName = 'no';
                    trigger OnBeforePassVariable()
                    begin
                        OrderNoAttr := '1';   // literal value required by 3PL
                    end;
                }

                //================ HEADER =================
                textelement(header)
                {
                    textelement(location)
                    {
                        MinOccurs = Once;
                        trigger OnBeforePassVariable()
                        begin
                            // Map BC location code → 3PL warehouse code
                            if SalesHeader."Location Code" = '1-EU' then
                                location := 'F01'
                            else
                                location := SalesHeader."Location Code";
                        end;
                    }

                    fieldelement(number; SalesHeader."No.") { }

                    // <reception_no>  — M40-prefixed unique reception key
                    textelement(reception_no)
                    {
                        trigger OnBeforePassVariable()
                        begin
                            reception_no := BuildReceptionNo(SalesHeader);
                        end;
                    }

                    // <ref_no> — External Document No. (customer RMA/reference)
                    textelement(ref_no)
                    {
                        trigger OnBeforePassVariable()
                        begin
                            ref_no := SalesHeader."External Document No.";
                        end;
                    }

                    fieldelement(vendor_no; SalesHeader."Sell-to Customer No.") { }
                    fieldelement(vendor_name; SalesHeader."Sell-to Customer Name") { }

                    // <eta> — expected return date (YYYY-MM-DD)
                    textelement(eta)
                    {
                        trigger OnBeforePassVariable()
                        var
                            EtaDate: Date;
                        begin
                            if SalesHeader."Shipment Date" <> 0D then
                                EtaDate := SalesHeader."Shipment Date"
                            else
                                EtaDate := WorkDate();
                            eta := Format(EtaDate, 0, '<Year4>-<Month,2>-<Day,2>');
                        end;
                    }

                    textelement(status)
                    {
                        trigger OnBeforePassVariable()
                        begin
                            // Blank = normal; 'CANCEL' = cancellation request (not currently supported)
                            status := '';
                        end;
                    }

                    textelement(comment)
                    {
                        trigger OnBeforePassVariable()
                        begin
                            comment := GetHeaderComment(SalesHeader."Document Type", SalesHeader."No.");
                        end;
                    }

                    fieldelement(contact; SalesHeader."Sell-to Contact") { }

                    textelement(phone)
                    {
                        trigger OnBeforePassVariable()
                        begin
                            phone := SalesHeader."Sell-to Phone No.";
                        end;
                    }
                }

                //================ DETAILS =================
                //  <details><details no="10000">...
                textelement(details)
                {
                    tableelement(SalesLine; "Sales Line")
                    {
                        XmlName = 'details';
                        AutoSave = false;
                        LinkTable = SalesHeader;
                        LinkFields = "Document Type" = field("Document Type"),
                                     "Document No." = field("No.");
                        SourceTableView = sorting("Document Type", "Document No.", "Line No.")
                                          where(Type = const(Item),
                                                "Outstanding Quantity" = filter(> 0));

                        // Attribute  no="10000"
                        textattribute(LineNo)
                        {
                            XmlName = 'no';
                            trigger OnBeforePassVariable()
                            begin
                                LineNo := Format(SalesLine."Line No.");
                            end;
                        }

                        // <item> — item no (with variant code if present)
                        textelement(item)
                        {
                            trigger OnBeforePassVariable()
                            begin
                                if SalesLine."Variant Code" <> '' then
                                    item := SalesLine."No." + '-' + SalesLine."Variant Code"
                                else
                                    item := SalesLine."No.";
                            end;
                        }

                        textelement(gtin)
                        {
                            MinOccurs = Zero;
                            trigger OnBeforePassVariable()
                            begin
                                gtin := GetGTIN(SalesLine);
                            end;
                        }

                        textelement(description)
                        {
                            trigger OnBeforePassVariable()
                            var
                                RawDescription: Text;
                            begin
                                RawDescription := SalesLine.Description;
                                if SalesLine."Description 2" <> '' then
                                    RawDescription := RawDescription + ' ' + SalesLine."Description 2";
                                description := CleanTextContent(RawDescription);
                            end;
                        }

                        // <qty> — Outstanding Quantity (qty still expected to return)
                        textelement(qty)
                        {
                            trigger OnBeforePassVariable()
                            begin
                                qty := FormatDecEU(SalesLine."Outstanding Quantity");
                            end;
                        }

                        // <location> — line location or header fallback
                        textelement(line_location)
                        {
                            XmlName = 'location';
                            trigger OnBeforePassVariable()
                            begin
                                if SalesLine."Location Code" <> '' then
                                    line_location := SalesLine."Location Code"
                                else
                                    line_location := SalesHeader."Location Code";
                            end;
                        }
                    }
                }
            }
        }
    }

    var
        ItemRef: Record "Item Reference";

    local procedure BuildReceptionNo(InSalesHeader: Record "Sales Header"): Code[30]
    var
        ReceptionPrefix: Text;
    begin
        // Spec v6: unique M40-prefixed reception key per order
        // Note: legacy NAV used a No. Series — here we derive from the RA number itself
        ReceptionPrefix := 'M40';
        exit(CopyStr(ReceptionPrefix + InSalesHeader."No.", 1, 30));
    end;

    local procedure GetHeaderComment(DocType: Enum "Sales Document Type"; OrderNo: Code[20]): Text[250]
    var
        SalesComment: Record "Sales Comment Line";
        Txt: Text[250];
    begin
        SalesComment.SetRange("Document Type", DocType);
        SalesComment.SetRange("No.", OrderNo);
        SalesComment.SetRange("Document Line No.", 0);
        if SalesComment.FindSet() then
            repeat
                Txt := CopyStr(Txt + SalesComment.Comment + ' ', 1, MaxStrLen(Txt));
            until SalesComment.Next() = 0;

        // Remove angle brackets (prevents malformed XML)
        Txt := CopyStr(DelChr(Txt, '=', '<>'), 1, MaxStrLen(Txt));
        exit(Txt);
    end;

    local procedure CleanTextContent(InputText: Text): Text
    var
        OutputText: Text;
        CharPos: Integer;
        CurrentChar: Char;
        PrevChar: Char;
    begin
        OutputText := '';
        PrevChar := 0;

        for CharPos := 1 to StrLen(InputText) do begin
            CurrentChar := InputText[CharPos];

            // Replace line breaks with space
            if (CurrentChar = 13) or (CurrentChar = 10) then begin
                if PrevChar <> ' ' then
                    OutputText += ' ';
                PrevChar := ' ';
            end
            // Strip angle brackets
            else if (CurrentChar = '<') or (CurrentChar = '>') then begin
                PrevChar := CurrentChar;
            end
            // Keep normal printable characters and UTF-8
            else if CurrentChar >= ' ' then begin
                OutputText += CurrentChar;
                PrevChar := CurrentChar;
            end
            else begin
                PrevChar := 0;
            end;
        end;

        exit(OutputText.Trim());
    end;

    local procedure FormatDecEU(Val: Decimal): Text[20]
    var
        FormattedText: Text;
    begin
        // Standard format specifier for consistent output (e.g., 1234.56)
        FormattedText := Format(Val, 0, 9);

        if StrPos(FormattedText, '.') = 1 then
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
        ItemRef.SetFilter("Description", 'EAN*');

        if ItemRef.FindFirst() then
            exit(ItemRef."Reference No.");

        exit('');
    end;
}
