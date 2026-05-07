codeunit 50535 "PostedShipmentUpdate"
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post",
      'OnBeforeSalesShptHeaderInsert', '', true, true)]
    local procedure OnBeforeSalesShptHeaderInsert(var SalesShptHeader: Record "Sales Shipment Header";
                                                  SalesHeader: Record "Sales Header";
                                                  var IsHandled: Boolean)
    begin
        if SalesHeader."Package Tracking No." <> '' then
            SalesShptHeader."Package Tracking No." := SalesHeader."Package Tracking No.";

        if SalesHeader."Shipping Agent Code" <> '' then
            SalesShptHeader."Shipping Agent Code" := SalesHeader."Shipping Agent Code";

        if SalesHeader."Shipping Agent Service Code" <> '' then
            SalesShptHeader."Shipping Agent Service Code" := SalesHeader."Shipping Agent Service Code";

        if SalesHeader."Shipment Date" <> 0D then
            SalesShptHeader."Shipment Date" := SalesHeader."Shipment Date";
    end;
}