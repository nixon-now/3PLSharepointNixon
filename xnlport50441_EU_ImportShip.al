xmlport 50441 "Import Shipped Confirmation_EU"
{
    Direction = Import;
    Format = Xml;
    Encoding = UTF8;
    UseDefaultNamespace = false; // sample has no namespace
    PreserveWhiteSpace = true;

    Permissions = 
        tabledata "Sales Header" = rimd;

    schema
    {
        textelement(orders)
        {
            tableelement(OrderRec; Integer)
            {
                XmlName = 'order';
                UseTemporary = true;

                // 👇 NEW: accept optional no="…" attribute on <order>
                textattribute(no)
                {
                   // MinOccurs = Zero;
                }

                textelement(header)
                {
                    textelement(number) { }         // SO number
                    textelement(ref_no) { }         // optional
                    textelement(delivery_no) { }    // optional
                    textelement(status) { }         // "SHIPPED" etc.
                    textelement(charge) { }         // optional
                    textelement(tracking_no) { }    // tracking to map
                    textelement(carrier) { }        // Shipping Agent Code to map
                    textelement(service) { }        // Shipping Agent Service Code to map

                    textelement(package)
                    {
                        textelement(package_no) { }             // optional
                        textelement(package_tracking_no) { }    // may duplicate tracking_no
                        textelement(package_serial_no) { }      // optional
                    }
                }

                trigger OnAfterInsertRecord()
                begin
                    ApplyShipmentToSalesHeader();
                end;
            }
        }
    }

    var
        SalesHeader: Record "Sales Header";
        Agent: Record "Shipping Agent";
        AgentService: Record "Shipping Agent Services";
        ShipAgentCode: Code[10];
        ShipServiceCode: Code[10];
        TrackingNoTxt: Text;
        OrderNo: Code[20];

    local procedure ApplyShipmentToSalesHeader()
    var
        CarrierTxt: Text;
        ServiceTxt: Text;
    begin
        OrderNo := CopyStr(number, 1, MaxStrLen(SalesHeader."No."));
        TrackingNoTxt := tracking_no;
        if (TrackingNoTxt = '') and (package_tracking_no <> '') then
            TrackingNoTxt := package_tracking_no;

        CarrierTxt := carrier;
        ServiceTxt := service;

        if OrderNo = '' then
            exit;

        if not SalesHeader.Get(SalesHeader."Document Type"::Order, OrderNo) then
            exit; // silently skip unknown orders

        // Map carrier to agent code (exact code > name match)
        ShipAgentCode := '';
        if CarrierTxt <> '' then begin
            if Agent.Get(CopyStr(CarrierTxt, 1, MaxStrLen(Agent.Code))) then
                ShipAgentCode := Agent.Code
            else
                if Agent.FindSet() then
                    repeat
                        if LowerCase(Agent.Name) = LowerCase(CarrierTxt) then begin
                            ShipAgentCode := Agent.Code;
                            break;
                        end;
                    until Agent.Next() = 0;
        end;

        ShipServiceCode := '';
        if (ShipAgentCode <> '') and (ServiceTxt <> '') then begin
            AgentService.SetRange("Shipping Agent Code", ShipAgentCode);
            if AgentService.FindSet() then
                repeat
                    if (LowerCase(AgentService.Description) = LowerCase(ServiceTxt)) or
                       (LowerCase(AgentService.Code) = LowerCase(ServiceTxt)) then begin
                        ShipServiceCode := AgentService.Code;
                        break;
                    end;
                until AgentService.Next() = 0;
        end;

        if TrackingNoTxt <> '' then
            SalesHeader."Package Tracking No." := CopyStr(TrackingNoTxt, 1, MaxStrLen(SalesHeader."Package Tracking No."));
        if ShipAgentCode <> '' then
            SalesHeader."Shipping Agent Code" := ShipAgentCode;
        if ShipServiceCode <> '' then
            SalesHeader."Shipping Agent Service Code" := ShipServiceCode;
           // ✅ Mark Sales Header as having imported pick confirmation
                    SalesHeader.Validate("Imported Shipped Confirmation", true);
                    SalesHeader.Validate("Imported Shipped Conf. Date", TODAY);
                    
        SalesHeader.Modify();
    end;
}
