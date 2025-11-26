xmlport 50439 "Import Pick Confirmation_AU"
{
    Direction = Import;
    Format = Xml;
    Encoding = UTF8;
    UseDefaultNamespace = false; // XML has no namespace
    UseRequestPage = false;
    PreserveWhiteSpace = true;

    // Only keep permissions if you actually modify records here
    Permissions =
        tabledata "Sales Header" = rimd,
        tabledata "Sales Line"   = rimd;

    schema
    {
        textelement(orders)
        {
            tableelement(OrderRec; Integer)
            {
                XmlName = 'order';
                UseTemporary = true;

                // <order no="1">
                textattribute(headerno) { 
                    XmlName = 'no';
                }

                textelement(header)
                {
                    // Only what the XML contains
                    // (id/ref_no/comment nodes removed to avoid confusion)
                    textelement(number)
                    {
                        trigger OnAfterAssignVariable()
                        var
                            LocalSalesHeader: Record "Sales Header";
                        begin
                            GotSHeader := false;
                            DocNo := number;

                            LocalSalesHeader.Reset();
                            LocalSalesHeader.SetRange("Document Type", LocalSalesHeader."Document Type"::Order);
                            LocalSalesHeader.SetRange("No.", DocNo);

                            if LocalSalesHeader.FindFirst() then begin
                                GotSHeader := true;
                                ShipmentCount += 1;
                                SalesHeader := LocalSalesHeader;

                                if GuiAllowed then
                                    Window.Update(1, DocNo);

                               
                                TempSalesHeader.TransferFields(SalesHeader);
                                if not TempSalesHeader.Insert() then;

                                if not PayTerms.Get(SalesHeader."Payment Terms Code") then
                                    Clear(PayTerms);
                            end else begin
                                ShipmentSkipCount += 1;
                                LogError(StrSubstNo('Order %1 not found', DocNo));
                            end;
                        end;
                    }
                    textelement(receipt_no) {
                        MinOccurs = Zero;                     }
                    textelement(po_no)      { 
                          MinOccurs = Zero;    
                    }
                    textelement(created)    { 
                          MinOccurs = Zero;    
                    }
                    textelement(packedheader)     {
                        XmlName = 'packed';
                     }
                    textelement(status)     {
                          MinOccurs = Zero;    
                     }

                    textelement(ship_via)
                    {
                        textelement(shipper) { }
                        textelement(service) { }
                    }

                    textelement(shipto)
                    {
                        textelement(code)     { }
                        textelement(name)     { }
                        textelement(name2)    { } 
                        textelement(address1) { }
                        textelement(address2) { }
                        textelement(city)     { }
                        textelement(province) { }
                        textelement(country)  { }
                        textelement(postal)   { }
                        textelement(phone)    { 
                              //MinOccurs = Zero;    
                        }
                        textelement(email)    { 
                            //  MinOccurs = Zero;    
                        }
                    }
                }

                textelement(details)
                {
                    tableelement(LineRec; Integer)
                    {
                        XmlName = 'line';
                        UseTemporary = true;

                        // <line no="10000">
                        textattribute(no) { }

                        // <item>A1311-100-00</item>
                        textelement(item)
                        {
                            trigger OnAfterAssignVariable()
                            begin
                                LineFound := false;
                                if not GotSHeader then
                                    exit;

                                // primary match by Item No.
                                SalesLine.Reset();
                                SalesLine.SetRange("Document Type", SalesHeader."Document Type");
                                SalesLine.SetRange("Document No.", SalesHeader."No.");
                                SalesLine.SetRange("No.", item);
                                LineFound := SalesLine.FindFirst();

                                if not LineFound then
                                    LogError(StrSubstNo('No Sales Line for Item %1 on order %2.', item, SalesHeader."No."));
                            end;
                        }

                        // <gtin>3608701101063</gtin> — optional fallback
                        textelement(gtin)
                        {
                            trigger OnAfterAssignVariable()
                            begin
                                if LineFound or (gtin = '') or not GotSHeader then
                                    exit;
                                MapLineByGTIN(gtin);
                            end;
                        }

                        // present in XML — keep them so the xmlport consumes them
                        textelement(lot)         { }
                        textelement(serial)      { }
                        textelement(description) { }
                        textelement(on_order)    { }

                        // <packed> ... </packed>
                        textelement(packed)
                        {
                            textelement(qty)
                            {
                                trigger OnAfterAssignVariable()
                                var
                                    QtyPicked: Decimal;
                                begin
                                    if not GotSHeader then
                                        exit;

                                    if Evaluate(QtyPicked, qty) then
                                        ApplyPickQuantity(QtyPicked);
                                end;
                            }
                            textelement(unit)              { }
                            textelement(package_no)        { }
                            textelement(package_serial_no) { }
                            textelement(package_weight)    { }
                        }
                    }
                }

                trigger OnAfterInitRecord()
                begin
                    Clear(OrderRec);
                end;

                trigger OnAfterInsertRecord()
                var
                    LineCheck: Record "Sales Line";
                    ShouldRelease: Boolean;
                begin
                    if not GotSHeader then
                        exit;
                        // ✅ Mark Sales Header as having imported pick confirmation
                    SalesHeader.Validate("Imported Pick Confirmation", true);
                    SalesHeader.Validate("Imported Pick Conf. Date", TODAY);
                    SalesHeader.Modify();

                    // Release if every Item line on the order now has Qty. to Ship > 0
                    ShouldRelease := true;
                    LineCheck.SetRange("Document Type", SalesHeader."Document Type");
                    LineCheck.SetRange("Document No.", SalesHeader."No.");

                    if LineCheck.FindSet() then
                        repeat
                            if LineCheck.Type = LineCheck.Type::Item then
                                if LineCheck."Qty. to Ship" <= 0 then
                                    ShouldRelease := false;
                        until LineCheck.Next() = 0;

                    if ShouldRelease then
                        ReleaseDoc.Run(SalesHeader);
                end;
            }
        }
    }

    trigger OnPreXmlPort()
    begin
        if GuiAllowed then
            Window.Open('Importing pick confirmation for #1##########', DocNo);
    end;

    trigger OnPostXmlPort()
    begin
        if GuiAllowed then
            Window.Close();

        if not SuppressMessages then
            Message('Imported %1 pick confirmation(s). Skipped %2.', ShipmentCount, ShipmentSkipCount);
    end;

    var
        ReleaseDoc: Codeunit "Release Sales Document";
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        PayTerms: Record "Payment Terms";
        TempSalesHeader: Record "Sales Header" temporary;
        ItemRef: Record "Item Reference";

        DocNo: Code[20];
        Window: Dialog;
        SuppressMessages: Boolean;
        GuiAllowed: Boolean;

        GotSHeader: Boolean;
        LineFound: Boolean;
        ShipmentCount: Integer;
        ShipmentSkipCount: Integer;

    // --- helpers ---

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
            SalesLine.SetRange("No.", ItemRef."Item No.");
            if ItemRef."Variant Code" <> '' then
                SalesLine.SetRange("Variant Code", ItemRef."Variant Code");

            LineFound := SalesLine.FindFirst();
            if not LineFound then
                LogError(StrSubstNo('No Sales Line found via GTIN %1 for order %2.', GTINVal, SalesHeader."No."));
        end else
            LogError(StrSubstNo('GTIN %1 not found in Item Reference.', GTINVal));
    end;

    local procedure ApplyPickQuantity(QtyToShip: Decimal)
    begin
        if not LineFound then
            exit;
        if QtyToShip = 0 then
            exit;

        if SalesLine.FindFirst() then begin
            SalesLine.Validate("Qty. to Ship", QtyToShip);
            // If you also invoice on pick, uncomment next line:
            // SalesLine.Validate("Qty. to Invoice", QtyToShip);
            SalesLine.Modify();
        end;
    end;

    local procedure LogError(Msg: Text)
    begin
        ShipmentSkipCount += 1;
        // Optional: add telemetry or error table logging here
    end;

    procedure SetSuppressMessages(Value: Boolean)
    begin
        SuppressMessages := Value;
    end;

    procedure SetGuiAllowed(Value: Boolean)
    begin
        GuiAllowed := Value;
    end;

    procedure GetShipmentCount(): Integer
    begin
        exit(ShipmentCount);
    end;

    procedure GetShipSkipCount(): Integer
    begin
        exit(ShipmentSkipCount);
    end;

    procedure GetDocumentNo(): Code[20]
    begin
        exit(DocNo);
    end;
}
