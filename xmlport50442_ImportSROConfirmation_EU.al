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
                                SalesHeader."3PL SRO Requires Review" := false;
                                SalesHeader."3PL SRO Review Reason" := '';

                                if GuiAllowed then
                                    Window.Update(1, DocNo);
                            end else begin
                                Logic.LogError(StrSubstNo('Return Order %1 not found.', DocNo));
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
                                Clear(XmlReceivedQty);
                                Clear(XmlReceivedQtyValid);
                                Clear(XmlLineLocation);

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
                            end;
                        }

                        // <gtin> — fallback when <item> did not match
                        textelement(gtin)
                        {
                            trigger OnAfterAssignVariable()
                            begin
                                if LineFound or (gtin = '') or (not GotSHeader) or Cancellation then
                                    exit;

                                Logic.MapLineByGTIN(SalesHeader, SalesLine, gtin, LineFound);
                            end;
                        }

                        textelement(lot) { }
                        textelement(serial) { }
                        textelement(description) { }
                        textelement(on_order) { }

                        textelement(received_qty)
                        {
                            trigger OnAfterAssignVariable()
                            begin
                                if (not GotSHeader) or Cancellation then
                                    exit;

                                XmlReceivedQtyValid := Evaluate(XmlReceivedQty, received_qty);
                            end;
                        }

                        textelement(line_location)
                        {
                            XmlName = 'location';
                            trigger OnAfterAssignVariable()
                            begin
                                XmlLineLocation := CopyStr(DelChr(line_location, '<>=', ' '), 1, MaxStrLen(XmlLineLocation));
                            end;
                        }

                        trigger OnBeforeInsertRecord()
                        begin
                            LineCounter += 1;
                            LineRec.Number := LineCounter;

                            if (not GotSHeader) or Cancellation then
                                exit;

                            if LineFound then
                                Logic.ApplyToExistingLine(SalesHeader, SalesLine, XmlReceivedQty, XmlReceivedQtyValid, XmlLineLocation)
                            else
                                Logic.HandleUnexpectedLine(SalesHeader, ItemNoTxt, XmlReceivedQty, XmlReceivedQtyValid, XmlLineLocation);
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

        if ReceiptCount = 0 then
            Error('Return confirmation for order %1 could not be applied: Return Order not found in BC. The order may have been posted, archived, or deleted before this import ran.', DocNo);
    end;

    // ====== Globals ======

    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        Logic: Codeunit "3PL SRO Import Logic";

        DocNo: Code[20];
        ReceiptNoTxt: Text;
        ItemNoTxt: Text;
        XmlLineLocation: Code[10];
        XmlReceivedQty: Decimal;
        Window: Dialog;
        SuppressMessages: Boolean;
        GuiAllowed: Boolean;
        GotSHeader: Boolean;
        LineFound: Boolean;
        Cancellation: Boolean;
        XmlReceivedQtyValid: Boolean;
        ReceiptCount: Integer;
        ReceiptSkipCount: Integer;
        LineCounter: Integer;

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
