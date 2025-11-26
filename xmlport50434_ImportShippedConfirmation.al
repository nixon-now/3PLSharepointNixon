xmlport 50434 "Import Shipped Confirmation"
{
    Direction = Import;
    Format = Xml;
    UseRequestPage = false;
    Encoding = UTF8;
    UseDefaultNamespace = false;

    Permissions =
        tabledata "Sales Header" = rimd;

    schema
    {
        // The root element is <order>
        textelement(order)
        {
            XmlName = 'order';

            textattribute(server) { }
            textattribute(time) { }

            textelement(id) { }
            textelement(number)
            {
                trigger OnAfterAssignVariable()
                begin
                    Message('Processing Order: %1', number); // Debug log
                    InitPerOrder();
                    FindSalesHeaderByNumber(number);
                end;
            }
            textelement(courier)
            {
                trigger OnAfterAssignVariable()
                begin
                    if GotSHeader then
                        MappedShipAgent := MapCourierToAgent(courier);
                end;
            }
            textelement(service)
            {
                trigger OnAfterAssignVariable()
                begin
                    if GotSHeader then
                        MappedService := CopyStr(service, 1, MaxStrLen(SalesHeader."Shipping Agent Service Code"));
                end;
            }
            textelement(status)
            {
                trigger OnAfterAssignVariable()
                begin
                    LastStatus := UpperCase(status);
                end;
            }
            textelement(tracking_no)
            {
                trigger OnAfterAssignVariable()
                begin
                    if GotSHeader then
                        TrackingNoTxt := CopyStr(tracking_no, 1, MaxStrLen(SalesHeader."Package Tracking No."));
                end;
            }
            textelement(shipped)
            {
                trigger OnAfterAssignVariable()
    begin
        ShippedRaw := shipped;
        if GotSHeader then begin 
            ApplyShipmentToOrder();
               // ✅ Mark Sales Header as having imported pick confirmation
                    SalesHeader.Validate("Imported Shipped Confirmation", true);
                    SalesHeader.Validate("Imported Shipped Conf. Date", TODAY);
                    SalesHeader.Modify();
        end;
    end;
            }
            textelement(cod)
            {
                trigger OnAfterAssignVariable()
    begin
        CODTxt := UpperCase(cod);
        if GotSHeader then begin
            ApplyShipmentToOrder();
             // ✅ Mark Sales Header as having imported pick confirmation
                    SalesHeader.Validate("Imported Shipped Confirmation", true);
                    SalesHeader.Validate("Imported Shipped Conf. Date", TODAY);
                    SalesHeader.Modify();
        end;
    end;
            }
            textelement(Charges) {
             XmlName = 'charges'; 
             MinOccurs = Zero; 
                textelement(charge){
                    MinOccurs = Zero;
                }
                textelement(invoice){
                    MinOccurs = Zero;
                }
            }
           
        }
    }

    var
        SalesHeader: Record "Sales Header";
        GotSHeader: Boolean;
        MappedShipAgent: Code[10];
        MappedService: Code[10];
        TrackingNoTxt: Text;
        ShippedRaw: Text;
        CODTxt: Text;
        LastStatus: Text;

    local procedure InitPerOrder()
    begin
        Clear(SalesHeader);
        GotSHeader := false;
        Clear(MappedShipAgent);
        Clear(MappedService);
        Clear(TrackingNoTxt);
        Clear(ShippedRaw);
        Clear(CODTxt);
        Clear(LastStatus);
    end;

    local procedure FindSalesHeaderByNumber(OrderNo: Code[20])
    begin
        SalesHeader.Reset();
        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
        SalesHeader.SetRange("No.", OrderNo);
        GotSHeader := SalesHeader.FindFirst();
        

        if not GotSHeader then
            Message('Order %1 not found.', OrderNo); // Debug log
    end;

    local procedure ApplyShipmentToOrder()
    var
        Changed: Boolean;
        ReleasedSalesDoc:  Codeunit "Release Sales Document";
    begin
        Changed := false;
        IF SalesHeader.Status = SalesHeader.Status::Released then
            ReleasedSalesDoc.Reopen(SalesHeader);

        if MappedShipAgent <> '' then begin
            SalesHeader.Validate("Shipping Agent Code", MappedShipAgent);
            Changed := true;
        end;

        if MappedService <> '' then begin
            SalesHeader.Validate("Shipping Agent Service Code", MappedService);
            Changed := true;
        end;

        if TrackingNoTxt <> '' then begin
            SalesHeader.Validate("Package Tracking No.", TrackingNoTxt);
            SalesHeader.Validate("3PL Tracking No.", TrackingNoTxt);
            Changed := true;
        end;

        if Changed then
            SalesHeader.Modify(true);

        Message('Shipment applied to Order %1 successfully.', SalesHeader."No."); // Debug log
    end;

    local procedure MapCourierToAgent(CourierTxt: Text): Code[10]
    begin
        exit(CopyStr(UpperCase(CourierTxt), 1, 10));
    end;
}