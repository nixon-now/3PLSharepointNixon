xmlport 50432 "Import Pick Confirmation"
{
    Direction = Import;
    Format = Xml;
    Encoding = UTF8;
    UseDefaultNamespace = true;
    DefaultNamespace = 'urn:3pl-integration';
    PreserveWhiteSpace = true;
    Permissions = tabledata "Sales Header"=rimd,
        tabledata "Sales Line"=rimd;

    schema
    {
    textelement(orders)
    {
    textelement(timestamp)
    {
    }
    textelement(server)
    {
    }
    tableelement(OrderRec;
    Integer)
    {
    XmlName = 'order';
    UseTemporary = true;

    textelement(header)
    {
    textelement(id)
    {
    }
    textelement(number)
    {
    trigger OnAfterAssignVariable()
    begin
        GotSHeader:=false;
        DocNo:=number;
        SalesHeader.FilterGroup(2);
        SalesHeader.SetRange("No.", DocNo);
        SalesHeader.FilterGroup(0);
        SalesLine.Reset();
        SalesLine.MarkedOnly(false);
        if SalesHeader.FindFirst()then begin
            GotSHeader:=true;
            ShipmentCount+=1;
            if GuiAllowed then Window.Update(1);
            TempSalesHeader.TransferFields(SalesHeader);
            if not TempSalesHeader.Insert()then;
            if not PayTerms.Get(SalesHeader."Payment Terms Code")then Clear(PayTerms);
            SalesLine.SetRange("Document Type", SalesHeader."Document Type");
            SalesLine.SetRange("Document No.", SalesHeader."No.");
        end
        else
            ShipmentSkipCount+=1;
    end;
    }
    textelement(ref_no)
    {
    }
    textelement(po_no)
    {
    }
    textelement(created)
    {
    }
    //textelement(picked) { }
    textelement(comment)
    {
    }
    textelement(comment2)
    {
    }
    textelement(comment3)
    {
    }
    //textelement(contact) { }
    textelement(status)
    {
    }
    textelement(ship_via)
    {
    textelement(shipper)
    {
    }
    textelement(service)
    {
    }
    }
    textelement(shipto)
    {
    textelement(code)
    {
    }
    textelement(name)
    {
    }
    textelement(address1)
    {
    }
    textelement(address2)
    {
    }
    textelement(city)
    {
    }
    textelement(province)
    {
    }
    textelement(country)
    {
    }
    textelement(postal)
    {
    }
    textelement(contact)
    {
    }
    textelement(phone)
    {
    }
    textelement(email)
    {
    }
    }
    }
    textelement(details)
    {
    tableelement(LineRec;
    Integer)
    {
    XmlName = 'line';
    UseTemporary = true;

    textelement(item)
    {
    trigger OnAfterAssignVariable()
    begin
        Clear(SalesLine);
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetRange("No.", item);
    end;
    }
    textelement(description)
    {
    }
    textelement(on_order)
    {
    }
    textelement(picked)
    {
    textelement(qty)
    {
    trigger OnAfterAssignVariable()
    var
        QtyPicked: Decimal;
    begin
        if not GotSHeader then exit;
        if not Evaluate(QtyPicked, qty)then QtyPicked:=0;
        if QtyPicked = 0 then exit;
        if SalesLine.FindFirst()then begin
            SalesLine.Validate("Qty. to Ship", QtyPicked);
            SalesLine.Modify();
        end;
    end;
    }
    textelement(unit)
    {
    }
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
        if not GotSHeader then exit;
        LineCheck.SetRange("Document Type", SalesHeader."Document Type");
        LineCheck.SetRange("Document No.", SalesHeader."No.");
        ShouldRelease:=true;
        if LineCheck.FindSet()then repeat if LineCheck.Type = LineCheck.Type::Item then if LineCheck."Qty. to Ship" <= 0 then begin
                        ShouldRelease:=false;
                        break;
                    end;
            until LineCheck.Next() = 0;
        if ShouldRelease then ReleaseDoc.Run(SalesHeader);
    end;
    }
    }
    }
    trigger OnPreXmlPort()
    begin
        SalesSetup.FindFirst();
        SalesHeader.CopyFilters(FilterSalesHeader);
        ShipmentCount:=0;
        ShipmentSkipCount:=0;
        if GuiAllowed then Window.Open('Importing 3PL Sales Order Amounts...      \' + 'Document No.:         #1##################\' + 'Progress:             @2##################', SalesHeader."No.", SalesHeaderInd);
    end;
    trigger OnPostXmlPort()
    begin
        if GuiAllowed then Window.Close();
        if not SuppressMessages then Message('Imported %1 Sales Order Amount(s).', ShipmentCount);
    end;
    var ReleaseDoc: Codeunit "Release Sales Document";
    SalesSetup: Record "Sales & Receivables Setup";
    SalesHeader: Record "Sales Header";
    SalesLine: Record "Sales Line";
    PayTerms: Record "Payment Terms";
    FilterSalesHeader: Record "Sales Header";
    TempSalesHeader: Record "Sales Header" temporary;
    DocNo: Code[20];
    Window: Dialog;
    SuppressMessages: Boolean;
    GotSHeader: Boolean;
    ShipmentCount: Integer;
    ShipmentSkipCount: Integer;
    SalesHeaderInd: Integer;
    GuiAllowed: Boolean;
    procedure SetFilterRecord(var InFilterSalesHeader: Record "Sales Header")
    begin
        FilterSalesHeader.CopyFilters(InFilterSalesHeader);
    end;
    procedure SetSuppressMessages(InSuppressMessages: Boolean)
    begin
        SuppressMessages:=InSuppressMessages;
    end;
    procedure SetGuiAllowed(Allowed: Boolean)
    begin
        GuiAllowed:=Allowed;
    end;
    procedure GetShipmentCount(): Integer begin
        exit(ShipmentCount);
    end;
    procedure GetDocumentNo(): Code[20]
begin
    exit(DocNo);
end;

procedure GetExternalDocNo(): Code[30]
begin
    if TempSalesHeader.Get(DocNo) then
        exit(TempSalesHeader."External Document No.");
    exit('');
end;
    procedure GetShipSkipCount(): Integer begin
        exit(ShipmentSkipCount);
    end;
}
