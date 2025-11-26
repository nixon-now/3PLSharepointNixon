codeunit 50535 "PostedShipmentUpdate"
{
    // Use the BEFORE-insert event; set fields on the record in memory, no Modify() needed.
    // Correct signature includes an IsHandled (var) parameter in current BC.
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post",
      'OnBeforeSalesShptHeaderInsert', '', true, true)]
    local procedure OnBeforeSalesShptHeaderInsert(var SalesShptHeader: Record "Sales Shipment Header";
                                                  SalesHeader: Record "Sales Header";
                                                  var IsHandled: Boolean)
    begin
        // Populate values coming from import onto the header that is about to be inserted
        if SalesHeader."Package Tracking No." <> '' then 
            SalesShptHeader."Package Tracking No." := SalesHeader."Package Tracking No."
        else
            SalesShptHeader."Package Tracking No." := SalesHeader."3PL Tracking No.";


        if SalesHeader."Shipping Agent Code" <> '' then
            SalesShptHeader."Shipping Agent Code" := SalesHeader."Shipping Agent Code";

        if SalesHeader."Shipping Agent Service Code" <> '' then
            SalesShptHeader."Shipping Agent Service Code" := SalesHeader."Shipping Agent Service Code";

        if SalesHeader."Shipment Date" <> 0D then
            SalesShptHeader."Shipment Date" := SalesHeader."Shipment Date";

        // Do NOT call Modify() here. The framework will insert the record after this event.
        // Do NOT set IsHandled := true; we only enrich the header and let standard posting continue.
    end;
}