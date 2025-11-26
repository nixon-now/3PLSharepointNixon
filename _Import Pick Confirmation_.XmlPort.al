xmlport 50432 "Import Pick Confirmation"
{
    Caption = 'Import Pick Confirmation';
    Direction = Import;
    Format = Xml;
    UseDefaultNamespace = false;
    Encoding = UTF8;
    UseRequestPage = false;

    schema
    {
        // <orders timestamp="..." server="...">
        textelement(RootOrders)
        {
            XmlName = 'orders';
            textattribute(Attr_Timestamp) { XmlName = 'timestamp'; }
            textattribute(Attr_Server)    { XmlName = 'server'; }

            // <order> ... </order>
            tableelement(OrderHeaderTmp; "Sales Header")
            {
                XmlName = 'order';
                UseTemporary = true;
                AutoSave = true;
                MinOccurs = Zero;

                // ---- <header> ... </header> ----
                textelement(HeaderNode)
                {
                    XmlName = 'header';
                    textelement(XmlId)            { XmlName = 'id'; }
                    textelement(XmlOrderNumber)   { XmlName = 'number'; }
                    textelement(XmlRefNo)         { XmlName = 'ref_no'; }
                    textelement(XmlPoNo)          { XmlName = 'po_no'; }
                    textelement(XmlCreated)       { XmlName = 'created'; }
                    textelement(XmlPickedHdr)     { XmlName = 'picked'; }
                    textelement(XmlComment1)      { XmlName = 'comment'; }
                    textelement(XmlComment2)      { XmlName = 'comment2'; }
                    textelement(XmlComment3)      { XmlName = 'comment3'; }
                    textelement(XmlContact)       { XmlName = 'contact'; }
                    textelement(XmlStatus)        { XmlName = 'status'; }

                    textelement(ShipViaNode)
                    {
                        XmlName = 'ship_via';
                        textelement(XmlShipper) { XmlName = 'shipper'; }
                        textelement(XmlService) { XmlName = 'service'; }
                    }

                    textelement(ShipToNode)
                    {
                        XmlName = 'shipto';
                        textelement(XmlShipToCode)     { XmlName = 'code'; }
                        textelement(XmlShipToName)     { XmlName = 'name'; }
                        textelement(XmlShipToAddr1)    { XmlName = 'address1'; }
                        textelement(XmlShipToAddr2)    { XmlName = 'address2'; }
                        textelement(XmlShipToCity)     { XmlName = 'city'; }
                        textelement(XmlShipToProv)     { XmlName = 'province'; }
                        textelement(XmlShipToCountry)  { XmlName = 'country'; }
                        textelement(XmlShipToPostal)   { XmlName = 'postal'; }
                        textelement(XmlShipToContact)  { XmlName = 'contact'; }
                        textelement(XmlShipToPhone)    { XmlName = 'phone'; }
                        textelement(XmlShipToEmail)    { XmlName = 'email'; }
                    }
                }

                // ---- <details> ... </details> ----
                textelement(DetailsNode)
                {
                    XmlName = 'details';

                    // <line no="..."> ... </line>
                    tableelement(LineTmp; "Sales Line")
                    {
                        XmlName = 'line';
                        UseTemporary = true;
                        AutoSave = true;
                        MinOccurs = Zero;

                        // Attribute on <line>
                        textattribute(XmlLineNoAttr) { XmlName = 'no'; }

                        // Child elements
                        textelement(XmlItemTxt)      { XmlName = 'item'; }        // May be Item Reference (GTIN/barcode/customer ref)
                        textelement(XmlDescription)  { XmlName = 'description'; }
                        textelement(XmlOnOrderQty)   { XmlName = 'on_order'; }

                        // <picked><qty>..</qty><unit>..</unit></picked>
                        textelement(PickedNode)
                        {
                            XmlName = 'picked';
                            textelement(XmlPickedQtyEl)  { XmlName = 'qty'; }
                            textelement(XmlPickedUnitEl) { XmlName = 'unit'; }
                        }

                        trigger OnAfterInsertRecord()
                        begin
                            EnsureCurrentOrderPrepared();
                            if CurrentOrderExists then begin
                                UpdateQtyUsingItemReferencePreferred(); // FIXED: Call without parameters
                                // ✅ Mark Sales Header as having imported pick confirmation
                                SalesHeader.Validate("Imported Pick Confirmation", true);
                                SalesHeader.Validate("Imported Pick Conf. Date", TODAY);
                                SalesHeader.Modify();
                            end else
                            CurrXmlPort.Skip(); // discard temp line buffer
                        end;
                    }
                }

                trigger OnAfterInsertRecord()
                begin
                    PrepareCurrentOrder(); // after finishing <order>
                    CurrXmlPort.Skip();    // discard temp header buffer
                end;
            }
        }
    }

    var
        // State
        CurrentOrderNo: Code[20];
        CurrentOrderExists: Boolean;
        OrderPreparedForNo: Code[20];

        // Working records
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";

        // Stats
        SkippedOrders: Integer;
        UpdatedLines: Integer;
        SkippedLines_NoMatch: Integer;
        SkippedLines_ZeroQty: Integer;

    // FIXED: New wrapper procedure to use XML values directly
    local procedure UpdateQtyUsingItemReferencePreferred()
    begin
        UpdateQtyUsingItemReferencePreferred(
            CurrentOrderNo,
            XmlLineNoAttr,
            XmlItemTxt,
            XmlPickedUnitEl,
            XmlPickedQtyEl,
            XmlOnOrderQty
        );
    end;

    // FIXED: Added parameter list to implementation
    local procedure UpdateQtyUsingItemReferencePreferred(
        OrderNo: Code[20];
        LineNoAttr: Text;
        ItemTxtFromXml: Text;
        UOMTxt: Text;
        PickedQtyText: Text;
        OnOrderQtyText: Text
    )
    var
        QtyToApply: Decimal;
        QtyText: Text;
        TargetLineNo: Integer;
        Found: Boolean;

        ResItemNo: Code[20];
        ResVariant: Code[10];
        ResUOM: Code[10];

        ItemKey: Code[20];
        UOMKey: Code[10];
        RemainingQty: Decimal;
        customDimensions: Dictionary of [Text, Text];
    begin
        // choose qty inline
        if not IsNullOrWhitespace(PickedQtyText) then
            QtyText := PickedQtyText
        else
            QtyText := OnOrderQtyText;

        if not Evaluate(QtyToApply, QtyText) then
            QtyToApply := 0;
        if QtyToApply = 0 then begin
            SkippedLines_ZeroQty += 1;
            exit;
        end;

        // Base filter on this order
        SalesLine.Reset();
        SalesLine.SetRange("Document Type", SalesLine."Document Type"::Order);
        SalesLine.SetRange("Document No.", OrderNo);

        // 1) Try by <line no="x"> (BC "Line No." = x * 10000)
        TargetLineNo := 0;
        if not IsNullOrWhitespace(LineNoAttr) then
            if Evaluate(TargetLineNo, LineNoAttr) then
                TargetLineNo := TargetLineNo * 10000;

        if TargetLineNo > 0 then begin
            SalesLine.SetRange("Line No.", TargetLineNo);
            Found := SalesLine.FindFirst();
        end else
            Found := false;

        // 2) Prefer Item Reference lookup (GTIN/barcode/customer ref) → Item No./Variant/UOM
        if not Found then
            if ResolveItemFromReference(ItemTxtFromXml, UOMTxt, ResItemNo, ResVariant, ResUOM) then begin
                SalesLine.Reset();
                SalesLine.SetRange("Document Type", SalesLine."Document Type"::Order);
                SalesLine.SetRange("Document No.", OrderNo);
                SalesLine.SetRange(Type, SalesLine.Type::Item);
                SalesLine.SetRange("No.", ResItemNo);
                if ResVariant <> '' then
                    SalesLine.SetRange("Variant Code", ResVariant);
                if ResUOM <> '' then
                    SalesLine.SetRange("Unit of Measure Code", ResUOM)
                else if not IsNullOrWhitespace(UOMTxt) then begin
                    UOMKey := CopyStr(UOMTxt, 1, MaxStrLen(SalesLine."Unit of Measure Code"));
                    SalesLine.SetRange("Unit of Measure Code", UOMKey);
                end;

                Found := SalesLine.FindFirst();

                // Relax UOM if still not found
                if not Found then begin
                    SalesLine.SetRange("Unit of Measure Code");
                    Found := SalesLine.FindFirst();
                end;

                // Relax Variant if still not found
                if not Found then begin
                    SalesLine.SetRange("Variant Code");
                    Found := SalesLine.FindFirst();
                end;
            end;

        // 3) Last resort: direct Item No. match if XML actually contains BC Item No.
        if not Found then begin
            SalesLine.Reset();
            SalesLine.SetRange("Document Type", SalesLine."Document Type"::Order);
            SalesLine.SetRange("Document No.", OrderNo);
            SalesLine.SetRange(Type, SalesLine.Type::Item);
            ItemKey := CopyStr(ItemTxtFromXml, 1, MaxStrLen(SalesLine."No."));
            SalesLine.SetRange("No.", ItemKey);

            if not IsNullOrWhitespace(UOMTxt) then begin
                UOMKey := CopyStr(UOMTxt, 1, MaxStrLen(SalesLine."Unit of Measure Code"));
                SalesLine.SetRange("Unit of Measure Code", UOMKey);
            end;

            Found := SalesLine.FindFirst();

            if (not Found) and (not IsNullOrWhitespace(UOMTxt)) then begin
                SalesLine.SetRange("Unit of Measure Code");
                Found := SalesLine.FindFirst();
            end;
        end;

        if not Found then begin
            SkippedLines_NoMatch += 1;
            // ADDED DEBUG LOGGING
            customDimensions.Add('3PL', OrderNo);
            Session.LogMessage('0000WRN', 
                StrSubstNo('Line not matched: Order=%1, ItemTxt=%2, UOM=%3', 
                    OrderNo, ItemTxtFromXml, UOMTxt),
                Verbosity::Warning,
                DataClassification::SystemMetadata,
                TelemetryScope::ExtensionPublisher,
                customDimensions);
            exit;
        end;

        // Cap to remaining
        RemainingQty := SalesLine.Quantity - SalesLine."Quantity Shipped";
        if RemainingQty < 0 then
            RemainingQty := 0;
        if (RemainingQty > 0) and (QtyToApply > RemainingQty) then
            QtyToApply := RemainingQty;

        // ADDED DEBUG LOGGING
        Session.LogMessage('0000INF', 
            StrSubstNo('Updating: Order=%1, Line=%2, Item=%3, Qty=%4', 
                OrderNo, SalesLine."Line No.", SalesLine."No.", QtyToApply),
            Verbosity::Normal,
            DataClassification::SystemMetadata,
            TelemetryScope::ExtensionPublisher,
            customDimensions);

        SalesLine.Validate("Qty. to Ship", QtyToApply);
        SalesLine.Modify(true);
        UpdatedLines += 1;
    end;

    trigger OnPreXmlPort()
    begin
        SkippedOrders := 0;
        UpdatedLines := 0;
        SkippedLines_NoMatch := 0;
        SkippedLines_ZeroQty := 0;
        Clear(CurrentOrderNo);
        Clear(OrderPreparedForNo);
        CurrentOrderExists := false;
    end;

    // ---------------- Order context ----------------
    local procedure PrepareCurrentOrder()
    var
        Found: Boolean;
        CustomDimensions: Dictionary of [Text, Text];
    begin
        CurrentOrderNo := CopyStr(XmlOrderNumber, 1, MaxStrLen(CurrentOrderNo));

        SalesHeader.Reset();
        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
        SalesHeader.SetRange("No.", CurrentOrderNo);
        Found := SalesHeader.FindFirst();

        CurrentOrderExists := Found;
        if not Found then begin
            SkippedOrders += 1;
            // ADDED DEBUG LOGGING
            CustomDimensions.Add('3PL', CurrentOrderNo);
            Session.LogMessage('0000WRN', 
                StrSubstNo('Order not found: %1', CurrentOrderNo),
                Verbosity::Warning,
                DataClassification::SystemMetadata,
                TelemetryScope::ExtensionPublisher,
                CustomDimensions);
        end;

        OrderPreparedForNo := CurrentOrderNo;
    end;

    local procedure EnsureCurrentOrderPrepared()
    begin
        if (CurrentOrderNo <> CopyStr(XmlOrderNumber, 1, MaxStrLen(CurrentOrderNo))) or
           (OrderPreparedForNo <> CopyStr(XmlOrderNumber, 1, MaxStrLen(OrderPreparedForNo))) then
            PrepareCurrentOrder();
    end;

    // ---------------- Item Reference Resolution ----------------
    local procedure ResolveItemFromReference(ItemRefTxt: Text; UOMTxt: Text; var ItemNo: Code[20]; var VariantCode: Code[10]; var UOMCode: Code[10]): Boolean
    var
        ItemRef: Record "Item Reference";
        TryUOM: Code[10];
        RefNo: Text[50];
        CustomDimensions: Dictionary of [Text, Text];
    begin
        ItemNo := '';
        VariantCode := '';
        UOMCode := '';

        RefNo := CopyStr(ItemRefTxt, 1, MaxStrLen(RefNo));
        if not IsNullOrWhitespace(UOMTxt) then
            TryUOM := CopyStr(UOMTxt, 1, MaxStrLen(TryUOM));

        // A) Reference No. + UOM (if provided)
        ItemRef.Reset();
        ItemRef.SetRange("Reference No.", RefNo);
        if TryUOM <> '' then
            ItemRef.SetRange("Unit of Measure", TryUOM);
        if ItemRef.FindFirst() then begin
            ItemNo := ItemRef."Item No.";
            VariantCode := ItemRef."Variant Code";
            UOMCode := ItemRef."Unit of Measure";
            exit(true);
        end;

        // B) Any UOM for the same Reference No.
        ItemRef.Reset();
        ItemRef.SetRange("Reference No.", RefNo);
        if ItemRef.FindFirst() then begin
            ItemNo := ItemRef."Item No.";
            VariantCode := ItemRef."Variant Code";
            UOMCode := ItemRef."Unit of Measure";
            exit(true);
        end;

        // ADDED DEBUG LOGGING
        CustomDimensions.Add('3PL', RefNo);
        Session.LogMessage('0000WRN', 
            StrSubstNo('Item ref not found: %1', RefNo),
            Verbosity::Warning,
            DataClassification::SystemMetadata,
            TelemetryScope::ExtensionPublisher,
            CustomDimensions);
            
        exit(false);
    end;

    // ---------------- Utilities ----------------
    local procedure IsNullOrWhitespace(T: Text): Boolean
    begin
        exit(DelChr(T, '=', ' ') = '');
    end;

    // Optional stats
    procedure GetSkippedOrderCount(): Integer begin exit(SkippedOrders); end;
    procedure GetUpdatedLineCount(): Integer begin exit(UpdatedLines); end;
    procedure GetSkippedLineCount(): Integer begin exit(SkippedLines_NoMatch + SkippedLines_ZeroQty); end;
}