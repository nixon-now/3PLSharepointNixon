xmlport 50443 "Import SRO Confirmation_AU"
{
    Caption = 'Import SRO Receipt Confirmation (3PL AU)';
    Direction = Import;
    Format = Xml;
    Encoding = UTF8;
    UseDefaultNamespace = false;
    PreserveWhiteSpace = true;
    UseRequestPage = false;

    Permissions =
        tabledata "Sales Header" = rimd,
        tabledata "Sales Line" = rimd;

    schema
    {
        textelement(orders)
        {
            tableelement(OrderRec; Integer)
            {
                XmlName = 'order';
                UseTemporary = true;

                textattribute(no) { }

                textelement(header)
                {
                    textelement(number)
                    {
                        trigger OnAfterAssignVariable()
                        var
                            Trimmed: Text;
                        begin
                            Clear(GotSHeader);
                            Clear(Cancellation);
                            Clear(ReceiptNoTxt);

                            Trimmed := DelChr(number, '<>=', ' ');
                            if (Trimmed <> '') and (UpperCase(Trimmed) <> 'RETURN') then
                                LogError(StrSubstNo('Unexpected <number> value %1 (expected RETURN).', Trimmed));
                        end;
                    }

                    textelement(receipt_no)
                    {
                        trigger OnAfterAssignVariable()
                        var
                            LocalSalesHeader: Record "Sales Header";
                            Trimmed: Text;
                        begin
                            Clear(GotSHeader);
                            Trimmed := DelChr(receipt_no, '<>=', ' ');
                            ReceiptNoTxt := Trimmed;

                            if Trimmed = '' then begin
                                LogError('Empty <receipt_no>; cannot locate Return Order.');
                                ReceiptSkipCount += 1;
                                exit;
                            end;

                            LocalSalesHeader.Reset();
                            LocalSalesHeader.SetRange("Document Type", LocalSalesHeader."Document Type"::"Return Order");
                            LocalSalesHeader.SetRange("External Document No.", Trimmed);

                            if LocalSalesHeader.FindFirst() then begin
                                GotSHeader := true;
                                ReceiptCount += 1;
                                SalesHeader := LocalSalesHeader;

                                if GuiAllowed then
                                    Window.Update(1, SalesHeader."No.");
                            end else begin
                                LogError(StrSubstNo('No AU Return Order with External Document No. %1.', Trimmed));
                                ReceiptSkipCount += 1;
                            end;
                        end;
                    }

                    textelement(ref_no) { }

                    textelement(created) { }

                    textelement(closed)
                    {
                        trigger OnAfterAssignVariable()
                        begin
                            if UpperCase(DelChr(closed, '<>=', ' ')) = 'CANCELLED' then
                                Cancellation := true;
                        end;
                    }

                    textelement(status)
                    {
                        trigger OnAfterAssignVariable()
                        begin
                            if UpperCase(DelChr(status, '<>=', ' ')) = 'CANCELLED' then
                                Cancellation := true;
                        end;
                    }

                    textelement(header_location)
                    {
                        XmlName = 'location';
                    }
                }

                textelement(details)
                {
                    tableelement(LineRec; Integer)
                    {
                        XmlName = 'line';
                        UseTemporary = true;

                        textattribute(line_no)
                        {
                            XmlName = 'no';
                        }

                        textelement(item)
                        {
                            trigger OnAfterAssignVariable()
                            begin
                                LineFound := false;
                                ItemNoTxt := item;

                                if not GotSHeader then
                                    exit;
                                if Cancellation then
                                    exit;

                                SalesLine.Reset();
                                SalesLine.SetRange("Document Type", SalesHeader."Document Type");
                                SalesLine.SetRange("Document No.", SalesHeader."No.");
                                SalesLine.SetRange(Type, SalesLine.Type::Item);
                                SalesLine.SetRange("No.", ItemNoTxt);

                                LineFound := SalesLine.FindFirst();

                                if not LineFound then
                                    LogError(StrSubstNo('No Return Order line for Item %1 on %2.', ItemNoTxt, SalesHeader."No."));
                            end;
                        }

                        textelement(gtin)
                        {
                            trigger OnAfterAssignVariable()
                            begin
                                if LineFound or (gtin = '') or (not GotSHeader) or Cancellation then
                                    exit;

                                MapLineByGTIN(gtin);
                            end;
                        }

                        textelement(lot) { }
                        textelement(serial) { }
                        textelement(description) { }
                        textelement(on_order) { }

                        textelement(received_qty)
                        {
                            trigger OnAfterAssignVariable()
                            var
                                QtyReceived: Decimal;
                            begin
                                if (not GotSHeader) or Cancellation then
                                    exit;

                                if Evaluate(QtyReceived, received_qty) then
                                    ApplyReceivedQuantity(QtyReceived);
                            end;
                        }

                        textelement(line_location)
                        {
                            XmlName = 'location';
                        }

                        trigger OnBeforeInsertRecord()
                        begin
                            LineCounter += 1;
                            LineRec.Number := LineCounter;
                        end;
                    }
                }

                trigger OnAfterInsertRecord()
                begin
                    if not GotSHeader then
                        exit;

                    if Cancellation then begin
                        SalesHeader."Imported SRO Confirmation" := true;
                        SalesHeader."Imported SRO Conf. Date" := Today;
                        SalesHeader."3PL Imported" := true;
                        SalesHeader."3PL Import Date" := Today;
                        SalesHeader.Modify();
                        exit;
                    end;

                    SalesHeader.Validate("Imported SRO Confirmation", true);
                    SalesHeader.Validate("Imported SRO Conf. Date", Today);
                    if ReceiptNoTxt <> '' then
                        SalesHeader."3PL SRO Reception No." := CopyStr(ReceiptNoTxt, 1, MaxStrLen(SalesHeader."3PL SRO Reception No."));
                    SalesHeader."3PL Imported" := true;
                    SalesHeader."3PL Import Date" := Today;
                    SalesHeader."Posting Date" := WorkDate();
                    SalesHeader.Modify();
                end;
            }
        }
    }



    trigger OnPreXmlPort()
    begin
        if GuiAllowed then
            Window.Open('Importing return receipt...\\Return Order: #1##########');
    end;

    trigger OnPostXmlPort()
    begin
        if GuiAllowed then
            Window.Close();

        if ReceiptCount = 0 then
            Error('Return confirmation for receipt %1 could not be applied: no matching Return Order found in BC. The order may have been posted, archived, or deleted before this import ran.', ReceiptNoTxt);
    end;



    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        ItemRef: Record "Item Reference";

        ReceiptNoTxt: Text;
        ItemNoTxt: Text;
        Window: Dialog;
        SuppressMessages: Boolean;
        GuiAllowed: Boolean;
        GotSHeader: Boolean;
        LineFound: Boolean;
        Cancellation: Boolean;
        ReceiptCount: Integer;
        ReceiptSkipCount: Integer;
        LineCounter: Integer;

    local procedure MapLineByGTIN(GTINVal: Text)
    begin
        if GTINVal = '' then
            exit;

        ItemRef.Reset();
        ItemRef.SetRange("Reference No.", GTINVal);
        ItemRef.SetRange("Reference Type", ItemRef."Reference Type"::"Bar Code");
        if ItemRef.FindFirst() then begin
            SalesLine.Reset();
            SalesLine.SetRange("Document Type", SalesHeader."Document Type");
            SalesLine.SetRange("Document No.", SalesHeader."No.");
            SalesLine.SetRange(Type, SalesLine.Type::Item);
            SalesLine.SetRange("No.", ItemRef."Item No.");
            if ItemRef."Variant Code" <> '' then
                SalesLine.SetRange("Variant Code", ItemRef."Variant Code");

            LineFound := SalesLine.FindFirst();
            if not LineFound then
                LogError(StrSubstNo('No Return Order line via GTIN %1 for %2.', GTINVal, SalesHeader."No."));
        end else
            LogError(StrSubstNo('GTIN %1 not found in Item Reference.', GTINVal));
    end;

    local procedure ApplyReceivedQuantity(QtyReceived: Decimal)
    begin
        if not LineFound then
            exit;

        if QtyReceived > SalesLine."Outstanding Quantity" then
            QtyReceived := SalesLine."Outstanding Quantity";

        SalesLine.Validate("Return Qty. to Receive", QtyReceived);
        SalesLine.Validate("Qty. to Invoice", QtyReceived);
        SalesLine.Modify();
    end;

    local procedure LogError(Msg: Text)
    var
        Dims: Dictionary of [Text, Text];
    begin
        Dims.Add('error', CopyStr(Msg, 1, 250));
        Session.LogMessage('3PL-SRO-IMP-AU', 'AU SRO import issue',
            Verbosity::Warning, DataClassification::SystemMetadata,
            TelemetryScope::ExtensionPublisher, Dims);
    end;

    procedure SetSuppressMessages(NewSuppressMessages: Boolean)
    begin
        SuppressMessages := NewSuppressMessages;
    end;

    procedure SetGuiAllowed(Allowed: Boolean)
    begin
        GuiAllowed := Allowed;
    end;

    procedure GetReceiptCount(): Integer
    begin
        exit(ReceiptCount);
    end;

    procedure GetReceiptSkipCount(): Integer
    begin
        exit(ReceiptSkipCount);
    end;
}
