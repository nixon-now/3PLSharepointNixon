xmlport 50437 "Import Pack Confirmation_EU"
{
    Direction = Import;
    Format = Xml;
    Encoding = UTF8;
    UseDefaultNamespace = false;   // sample XML has no namespace
    PreserveWhiteSpace = true;
    UseRequestPage = false;
    Permissions = 
        tabledata "Sales Header" = rimd,
        tabledata "Sales Line"   = rimd;

    schema
    {
        textelement(orders)
        {
            // (sample has only <orders><order>...</order></orders>)
            tableelement(OrderRec; Integer)
            {
                XmlName     = 'order';
                UseTemporary = true;

                // <order no="1">
                textattribute(no) { }

                textelement(header)
                {
                    // <header><number>SO1037142</number>...</header>
                    textelement(number)
                    {
                        trigger OnAfterAssignVariable()
                        var
                            LocalSalesHeader: Record "Sales Header";
                        begin
                            Clear(GotSHeader);
                            Clear(DocNo);
                            DocNo := number;

                            LocalSalesHeader.Reset();
                            LocalSalesHeader.SetRange("Document Type", LocalSalesHeader."Document Type"::Order);
                            LocalSalesHeader.SetRange("No.", DocNo);

                            if LocalSalesHeader.FindFirst() then begin
                                GotSHeader := true;
                                ShipmentCount += 1;
                                SalesHeader := LocalSalesHeader; // copy to global for line mapping

                                if GuiAllowed then
                                    Window.Update(1, DocNo);
                            end else begin
                                LogError(StrSubstNo('Order %1 not found.', DocNo));
                                ShipmentSkipCount += 1;
                            end;
                        end;
                    }
                    textelement(receipt_no) { }
                    textelement(po_no)      { }
                    textelement(created)    { }
                    textelement(packed)     { }  // sample has a <packed> date under header
                    textelement(status)     { }

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
                        textelement(phone)    { }
                        textelement(email)    { }
                    }
                }

                textelement(details)
                {
                    tableelement(LineRec; Integer)
                    {
                        XmlName = 'line';
                        UseTemporary = true;

                        // <line no="10000">
                        textattribute(line_no) 
                        {
                            XmlName = 'no';
                             } // 🔧 FIX: was line_no — must be 'no' to match sample

                        // <item>A045-000-00</item>
                        textelement(item)
                        {
                            trigger OnAfterAssignVariable()
                            begin
                                LineFound := false;

                                if not GotSHeader then
                                    exit;

                                // Primary match by Item No. from <item>
                                SalesLine.Reset();
                                SalesLine.SetRange("Document Type", SalesHeader."Document Type");
                                SalesLine.SetRange("Document No.", SalesHeader."No.");
                                SalesLine.SetRange("No.", item);

                                LineFound := SalesLine.FindFirst();

                                if not LineFound then
                                    LogError(StrSubstNo('No Sales Line for Item %1 on order %2.', item, SalesHeader."No."));
                            end;
                        }

                        // <gtin>3007001236534</gtin> (optional fallback if Item doesn’t match)
                        textelement(gtin)
                        {
                            trigger OnAfterAssignVariable()
                            begin
                                if LineFound or (gtin = '') or not GotSHeader then
                                    exit;

                                MapLineByGTIN(gtin);
                            end;
                        }

                        textelement(lot)        { }
                        textelement(serial)     { }
                        textelement(description){ }
                        textelement(on_order)   { }

                        // <packed><qty>1</qty>...</packed>
                        textelement(packedheader)
                        {
                            XmlName = 'packed';
                            textelement(qty)
                            {
                                trigger OnAfterAssignVariable()
                                var
                                    QtyPicked: Decimal;
                                begin
                                    if not GotSHeader then
                                        exit;

                                    if Evaluate(QtyPicked, qty) then
                                        ApplyPickQuantity(QtyPicked); // 🔧 FIX: call the correct helper
                                end;
                            }
                            textelement(unit)              { }
                            textelement(package_no)        { }
                            textelement(package_serial_no) { }
                            textelement(package_weight)    { }
                        }
                    }
                }

                trigger OnAfterInsertRecord()
                var
                    ShouldRelease: Boolean;
                    LocalSalesLine: Record "Sales Line";
                begin
                    if not GotSHeader then
                        exit;
                    // ✅ Mark Sales Header as having imported pick confirmation
                    SalesHeader.Validate("Imported Pick Confirmation", true);
                    SalesHeader.Validate("Imported Pick Conf. Date", TODAY);
                    SalesHeader."Posting Date" := WorkDate();
                    SalesHeader.Modify();
                    // Decide whether to auto-release (optional).
                    // Here we conservatively release only if every Item line has >0 Qty. to Ship.
                    ShouldRelease := true;

                    LocalSalesLine.Reset();
                    LocalSalesLine.SetRange("Document Type", SalesHeader."Document Type");
                    LocalSalesLine.SetRange("Document No.", SalesHeader."No.");

                    if LocalSalesLine.FindSet() then
                        repeat
                            if LocalSalesLine.Type = LocalSalesLine.Type::Item then
                                if LocalSalesLine."Qty. to Ship" <= 0 then
                                    ShouldRelease := false;
                        until LocalSalesLine.Next() = 0;

                    if ShouldRelease then
                        ReleaseDoc.Run(SalesHeader);
                end;
            }
        }
    }

    // ====== Triggers ======

    trigger OnPreXmlPort()
    begin
        if GuiAllowed then
            Window.Open('Importing pick confirm...\\Order: #1##########');
    end;

    trigger OnPostXmlPort()
    begin
        if GuiAllowed then
            Window.Close();

        if not SuppressMessages then
            Message('Imported %1 pick confirmation(s). Skipped %2.', ShipmentCount, ShipmentSkipCount);
    end;

    // ====== Globals ======

    var
        ReleaseDoc: Codeunit "Release Sales Document";
        SalesHeader: Record "Sales Header";
        SalesLine  : Record "Sales Line";
        ItemRef    : Record "Item Reference";

        DocNo             : Code[20];
        Window            : Dialog;
        SuppressMessages  : Boolean;
        GuiAllowed        : Boolean;
        GotSHeader        : Boolean;
        LineFound         : Boolean;
        ShipmentCount     : Integer;
        ShipmentSkipCount : Integer;

    // ====== Helpers ======

    local procedure MapLineByGTIN(GTINVal: Text)
    begin
        // Only used when <item> didn’t match a line
        if GTINVal = '' then
            exit;

        ItemRef.Reset();
        ItemRef.SetRange("Reference No.", GTINVal);
        ItemRef.SetRange("Reference Type", ItemRef."Reference Type"::"Bar Code"); // typical GTIN ref
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

        
        SalesLine.Validate("Qty. to Ship", QtyToShip);
        // If you want to invoice picked qty immediately, keep next line, otherwise remove it:
        SalesLine.Validate("Qty. to Invoice", QtyToShip);
        SalesLine.Modify();
    end;

    local procedure LogError(Msg: Text)
    begin
        // Minimal counting + optional telemetry hook
        ShipmentSkipCount += 1;
        // Add Session.LogMessage(...) if you want rich telemetry.
    end;

    // ====== External setters/getters ======

    procedure SetSuppressMessages(NewSuppressMessages: Boolean)
    begin
        SuppressMessages := NewSuppressMessages;
    end;

    procedure SetGuiAllowed(Allowed: Boolean)
    begin
        GuiAllowed := Allowed;
    end;

    procedure GetShipmentCount(): Integer
    begin
        exit(ShipmentCount);
    end;

    procedure GetShipSkipCount(): Integer
    begin
        exit(ShipmentSkipCount);
    end;
}
