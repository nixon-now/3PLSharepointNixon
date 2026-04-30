xmlport 50442 "Import SRO Confirmation_EU"
{
    Caption = 'Import SRO Receipt Confirmation (3PL EU)';
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
                    // <number> — SRO Document No.
                    textelement(number)
                    {
                        trigger OnAfterAssignVariable()
                        var
                            LocalSalesHeader: Record "Sales Header";
                        begin
                            Clear(GotSHeader);
                            Clear(DocNo);
                            DocNo := CopyStr(number, 1, MaxStrLen(DocNo));

                            LocalSalesHeader.Reset();
                            LocalSalesHeader.SetRange("Document Type", LocalSalesHeader."Document Type"::"Return Order");
                            LocalSalesHeader.SetRange("No.", DocNo);

                            if LocalSalesHeader.FindFirst() then begin
                                GotSHeader := true;
                                ReceiptCount += 1;
                                SalesHeader := LocalSalesHeader;

                                if GuiAllowed then
                                    Window.Update(1, DocNo);
                            end else begin
                                LogError(StrSubstNo('Return Order %1 not found.', DocNo));
                                ReceiptSkipCount += 1;
                            end;
                        end;
                    }

                    // <receipt_no> — 3PL reception confirmation number
                    textelement(receipt_no)
                    {
                        trigger OnAfterAssignVariable()
                        begin
                            ReceiptNoTxt := receipt_no;
                        end;
                    }

                    // <ref_no> — external ref (original SO/RMA); informational only
                    textelement(ref_no) { }

                    // <reason_code> — optional header-level reason code override
                    textelement(reason_code)
                    {
                        MinOccurs = Zero;
                        trigger OnAfterAssignVariable()
                        var
                            ReasonCodeRec: Record "Reason Code";
                        begin
                            if not GotSHeader then
                                exit;
                            if reason_code = '' then
                                exit;
                            if not ReasonCodeRec.Get(reason_code) then
                                exit;
                            SalesHeader.Validate("Reason Code", reason_code);
                            SalesHeader.Modify();
                        end;
                    }

                    textelement(created) { }

                    // <closed> — value 'CANCELLED' triggers cancellation flag
                    textelement(closed)
                    {
                        trigger OnAfterAssignVariable()
                        begin
                            if UpperCase(closed) = 'CANCELLED' then
                                Cancellation := true;
                        end;
                    }

                    textelement(status)
                    {
                        trigger OnAfterAssignVariable()
                        begin
                            if UpperCase(status) = 'CANCELLED' then
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

                        // <item> — primary match by Item No.
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

                        // <gtin> — fallback when <item> did not match
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

                        // <received_qty> — maps to Return Qty. to Receive + Qty. to Invoice
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

                    // Mark Sales Header as having imported return receipt confirmation
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

    // ====== Triggers ======

    trigger OnPreXmlPort()
    begin
        if GuiAllowed then
            Window.Open('Importing return receipt...\\Return Order: #1##########');
    end;

    trigger OnPostXmlPort()
    begin
        if GuiAllowed then
            Window.Close();

        if not SuppressMessages then
            Message('Imported %1 return receipt(s). Skipped %2.', ReceiptCount, ReceiptSkipCount);
    end;

    // ====== Globals ======

    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        ItemRef: Record "Item Reference";

        DocNo: Code[20];
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

        // Guard against over-receive: cap at Outstanding Quantity
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
        Session.LogMessage('3PL-SRO-IMP', 'SRO import issue',
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
