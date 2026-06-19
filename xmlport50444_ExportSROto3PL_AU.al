xmlport 50444 "Export SRO to 3PL_AU"
{
    Caption = 'Export Sales Return Orders (3PL AU)';
    Direction = Export;
    Format = Xml;
    Encoding = UTF8;
    UseRequestPage = false;
    PreserveWhiteSpace = true;

    schema
    {
        textelement(orders)
        {
            tableelement(SalesHeader; "Sales Header")
            {
                XmlName = 'order';
                AutoSave = false;
                SourceTableView = sorting("Document Type", "No.")
                                  where("Document Type" = const("Return Order"),
                                        Status = const(Released));

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

                    textelement(reception_no)
                    {
                        trigger OnBeforePassVariable()
                        begin
                            reception_no := BuildReceptionNo(SalesHeader);
                        end;
                    }

                    textelement(ref_no)
                    {
                        MinOccurs = Zero;
                        trigger OnBeforePassVariable()
                        begin
                            ref_no := SalesHeader."External Document No.";
                        end;
                    }

                    fieldelement(vendor_no; SalesHeader."Sell-to Customer No.") { }
                    fieldelement(vendor_name; SalesHeader."Sell-to Customer Name") { }

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
                        MinOccurs = Zero;
                        trigger OnBeforePassVariable()
                        begin
                            phone := SalesHeader."Sell-to Phone No.";
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
                        LinkFields = "Document Type" = field("Document Type"),
                                     "Document No." = field("No.");
                        SourceTableView = sorting("Document Type", "Document No.", "Line No.")
                                          where(Type = const(Item),
                                                "Outstanding Quantity" = filter(> 0));

                        textattribute(LineNo)
                        {
                            XmlName = 'no';
                            trigger OnBeforePassVariable()
                            begin
                                LineNo := Format(SalesLine."Line No.");
                            end;
                        }

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

                        textelement(qty)
                        {
                            trigger OnBeforePassVariable()
                            begin
                                qty := FormatDecAU(SalesLine."Outstanding Quantity");
                            end;
                        }

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

            if (CurrentChar = 13) or (CurrentChar = 10) then begin
                if PrevChar <> ' ' then
                    OutputText += ' ';
                PrevChar := ' ';
            end
            else if (CurrentChar = '<') or (CurrentChar = '>') then begin
                PrevChar := CurrentChar;
            end
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

    local procedure FormatDecAU(Val: Decimal): Text[20]
    var
        FormattedText: Text;
    begin
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
