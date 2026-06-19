codeunit 50405 "3PL SRO Import Logic"
{

    procedure FlagReviewRequired(var SalesHeader: Record "Sales Header"; Reason: Text)
    var
        Existing: Text;
        Combined: Text;
    begin
        SalesHeader."3PL SRO Requires Review" := true;

        Existing := SalesHeader."3PL SRO Review Reason";
        if Existing = '' then
            Combined := Reason
        else
            Combined := Existing + ' / ' + Reason;
        SalesHeader."3PL SRO Review Reason" := CopyStr(Combined, 1, MaxStrLen(SalesHeader."3PL SRO Review Reason"));

        LogError(StrSubstNo('SRO %1 requires review: %2', SalesHeader."No.", Reason));
    end;

    procedure LocationExists(LocCode: Code[10]): Boolean
    var
        Loc: Record Location;
    begin
        if LocCode = '' then
            exit(false);
        exit(Loc.Get(LocCode));
    end;

    procedure GetNextLineNo(var SalesHeader: Record "Sales Header"): Integer
    var
        LastLine: Record "Sales Line";
    begin
        LastLine.SetRange("Document Type", SalesHeader."Document Type");
        LastLine.SetRange("Document No.", SalesHeader."No.");
        if LastLine.FindLast() then
            exit(LastLine."Line No." + 10000);
        exit(10000);
    end;

    procedure MapLineByGTIN(var SalesHeader: Record "Sales Header"; var SalesLine: Record "Sales Line"; GTINVal: Text; var LineFound: Boolean)
    var
        ItemRef: Record "Item Reference";
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

    procedure ApplyToExistingLine(var SalesHeader: Record "Sales Header"; var SalesLine: Record "Sales Line"; XmlReceivedQty: Decimal; XmlReceivedQtyValid: Boolean; XmlLineLocation: Code[10])
    var
        OriginalLocation: Code[10];
    begin
        if XmlReceivedQtyValid and (XmlReceivedQty > 0) then
            if XmlReceivedQty > SalesLine."Outstanding Quantity" then begin
                SalesLine."Return Qty. to Receive" := XmlReceivedQty;
                SalesLine."Qty. to Invoice" := XmlReceivedQty;
                FlagReviewRequired(SalesHeader,
                    StrSubstNo('Received qty %1 exceeds outstanding qty %2 for item %3.',
                        XmlReceivedQty, SalesLine."Outstanding Quantity", SalesLine."No."));
            end else begin
                SalesLine.Validate("Return Qty. to Receive", XmlReceivedQty);
                SalesLine.Validate("Qty. to Invoice", XmlReceivedQty);
            end;

        if XmlLineLocation <> '' then begin
            OriginalLocation := SalesLine."Location Code";
            if not LocationExists(XmlLineLocation) then
                FlagReviewRequired(SalesHeader,
                    StrSubstNo('3PL reported location %1 for item %2 does not exist in BC; line location not changed.',
                        XmlLineLocation, SalesLine."No."))
            else
                if (OriginalLocation <> '') and (OriginalLocation <> XmlLineLocation) then begin
                    SalesLine."Location Code" := XmlLineLocation;
                    FlagReviewRequired(SalesHeader,
                        StrSubstNo('Location changed from %1 to %2 for item %3.',
                            OriginalLocation, XmlLineLocation, SalesLine."No."));
                end else
                    if OriginalLocation = '' then
                        SalesLine."Location Code" := XmlLineLocation;
        end;

        SalesLine.Modify();
    end;

    procedure HandleUnexpectedLine(var SalesHeader: Record "Sales Header"; ItemNoTxt: Text; XmlReceivedQty: Decimal; XmlReceivedQtyValid: Boolean; XmlLineLocation: Code[10])
    var
        Item: Record Item;
        ItemNoCode: Code[20];
        Created: Boolean;
        ItemExists: Boolean;
    begin
        if ItemNoTxt = '' then begin
            LogError(StrSubstNo('Empty <item> on line for return order %1; skipping.', SalesHeader."No."));
            FlagReviewRequired(SalesHeader, 'Inbound RC line had empty item — skipped.');
            exit;
        end;

        ItemNoCode := CopyStr(ItemNoTxt, 1, MaxStrLen(ItemNoCode));
        ItemExists := Item.Get(ItemNoCode);

        if ItemExists then
            Created := TryCreateUnexpectedItemLine(SalesHeader, ItemNoCode, XmlReceivedQty, XmlReceivedQtyValid, XmlLineLocation)
        else
            Created := TryCreateUnexpectedCommentLine(SalesHeader, ItemNoCode, XmlReceivedQty, XmlReceivedQtyValid, XmlLineLocation);

        if not Created then
            LogError(StrSubstNo('Failed to create unexpected line for item %1 on %2: %3',
                ItemNoTxt, SalesHeader."No.", GetLastErrorText()));

        FlagReviewRequired(SalesHeader,
            StrSubstNo('Unexpected item %1 in return for order %2 (itemExists=%3, created=%4).',
                ItemNoTxt, SalesHeader."No.", ItemExists, Created));
    end;

    [TryFunction]
    procedure TryCreateUnexpectedItemLine(var SalesHeader: Record "Sales Header"; ItemNoCode: Code[20]; XmlReceivedQty: Decimal; XmlReceivedQtyValid: Boolean; XmlLineLocation: Code[10])
    var
        NewLine: Record "Sales Line";
        Item: Record Item;
        NextLineNo: Integer;
        LocToUse: Code[10];
    begin
        NextLineNo := GetNextLineNo(SalesHeader);

        if XmlLineLocation <> '' then
            LocToUse := XmlLineLocation
        else
            LocToUse := SalesHeader."Location Code";

        NewLine.Init();
        NewLine."Document Type" := SalesHeader."Document Type";
        NewLine."Document No." := SalesHeader."No.";
        NewLine."Line No." := NextLineNo;
        NewLine.Type := NewLine.Type::Item;
        NewLine."No." := ItemNoCode;

        if Item.Get(ItemNoCode) then begin
            NewLine.Description := Item.Description;
            NewLine."Description 2" := Item."Description 2";
            NewLine."Unit of Measure Code" := Item."Sales Unit of Measure";
            if NewLine."Unit of Measure Code" = '' then
                NewLine."Unit of Measure Code" := Item."Base Unit of Measure";
        end;

        NewLine."Location Code" := LocToUse;

        if XmlReceivedQtyValid and (XmlReceivedQty > 0) then begin
            NewLine.Quantity := XmlReceivedQty;
            NewLine."Return Qty. to Receive" := XmlReceivedQty;
            NewLine."Qty. to Invoice" := XmlReceivedQty;
        end;

        NewLine.Insert(false);
    end;

    [TryFunction]
    procedure TryCreateUnexpectedCommentLine(var SalesHeader: Record "Sales Header"; ItemNoCode: Code[20]; XmlReceivedQty: Decimal; XmlReceivedQtyValid: Boolean; XmlLineLocation: Code[10])
    var
        NewLine: Record "Sales Line";
        NextLineNo: Integer;
        LocToUse: Code[10];
        QtyText: Text;
        LocText: Text;
        DescriptionText: Text;
    begin
        NextLineNo := GetNextLineNo(SalesHeader);

        if XmlLineLocation <> '' then
            LocToUse := XmlLineLocation
        else
            LocToUse := SalesHeader."Location Code";

        if XmlReceivedQtyValid then
            QtyText := Format(XmlReceivedQty)
        else
            QtyText := '?';

        if LocToUse <> '' then
            LocText := LocToUse
        else
            LocText := '?';

        DescriptionText := StrSubstNo('[3PL Unknown Item] %1 qty %2 loc %3 — review', ItemNoCode, QtyText, LocText);

        NewLine.Init();
        NewLine."Document Type" := SalesHeader."Document Type";
        NewLine."Document No." := SalesHeader."No.";
        NewLine."Line No." := NextLineNo;
        NewLine.Type := NewLine.Type::" ";
        NewLine.Description := CopyStr(DescriptionText, 1, MaxStrLen(NewLine.Description));
        NewLine.Insert(true);
    end;

    procedure LogError(Msg: Text)
    var
        Dims: Dictionary of [Text, Text];
    begin
        Dims.Add('error', CopyStr(Msg, 1, 250));
        Session.LogMessage('3PL-SRO-IMP', 'SRO import issue',
            Verbosity::Warning, DataClassification::SystemMetadata,
            TelemetryScope::ExtensionPublisher, Dims);
    end;
}
