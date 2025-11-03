codeunit 50435 "3PL Shipment Post Extension"
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnAfterSalesShptHeaderInsert', '', true, true)]
    local procedure Transfer3PLTrackingInfo(var SalesShipmentHeader: Record "Sales Shipment Header"; SalesHeader: Record "Sales Header")
    begin
        SalesShipmentHeader."Package Tracking No." := SalesHeader."3PL Tracking No.";
        SalesShipmentHeader."Shipping Agent Code" := SalesHeader."Shipping Agent Code";
        SalesShipmentHeader."Shipment Date" := SalesHeader."Shipment Date";
        // No Modify() needed since it's a `var` parameter
    end;
}