xmlport 50440 "Import Shipped Confirmation_AU"
{
    Direction = Import;
    Format = Xml;
    Encoding = UTF8;
    UseDefaultNamespace = false;
    PreserveWhiteSpace = true;
    UseRequestPage = false;

    schema
    {
        textelement(orders)
        {
            textelement(order)
            {
                textattribute("no") { }  // Capture the order sequence attribute

                textelement(header)
                {
                    textelement(number)
                    {
                        trigger OnAfterAssignVariable()
                        begin
                            XmlOrderNo := number;  // Store order number
                        end;
                    }
                    
                    textelement(ref_no) { }        // Not used
                    textelement(delivery_no) { }   // Not used
                    textelement(status) { }        // Not used
                    textelement(charge) { }        // Not used
                    
                    textelement(tracking_no)
                    {
                        trigger OnAfterAssignVariable()
                        begin
                            XmlTrackingNo := tracking_no;  // Store tracking number
                        end;
                    }
                    
                    textelement(shipped) { }       // Not used
                    
                    textelement(carrier)           // Note: was 'courier' in old XML
                    {
                        trigger OnAfterAssignVariable()
                        begin
                            XmlCourier := carrier;  // Store carrier/shipping agent
                        end;
                    }
                    
                    textelement(service) { }       // Not used
                    
                    textelement(package)
                    {
                        textelement(package_no) { }           // Not used
                        textelement(package_tracking_no) { }  // Not used
                        textelement(package_serial_no) { }    // Not used
                    }
                }

                // Process order after all elements are read
                trigger OnAfterAssignVariable()
                begin
                    if (XmlOrderNo <> '') then
                        ProcessOrder();
                    
                    // Reset for next order
                    Clear(XmlOrderNo);
                    Clear(XmlTrackingNo);
                    Clear(XmlCourier);
                end;
            }
        }
    }

    trigger OnPreXmlPort()
    begin
        ShipmentCount := 0;
        ShipmentSkipCount := 0;
        if GuiAllowed then
            Window.Open(
              'Importing Shipment Confirmation...\' +
              'Sales Order No.:      #1##############\' +
              'Progress:             @2##############',
              XmlOrderNo, ShipmentCount);
    end;

    trigger OnPostXmlPort()
    begin
        if GuiAllowed then Window.Close();
        if not SuppressMessages then
            Message('Imported %1 shipment confirmation(s). Skipped %2.', ShipmentCount, ShipmentSkipCount);
    end;

    local procedure ProcessOrder()
    var
        SalesHeader: Record "Sales Header";
        ShippingAgent: Record "Shipping Agent";
        ConfirmManagement: Codeunit "Confirm Management";
        IsHandled: Boolean;
    begin
        if XmlOrderNo = '' then
            exit;

        OnBeforeProcessOrder(XmlOrderNo, XmlTrackingNo, XmlCourier, IsHandled);
        if IsHandled then
            exit;

        // Try to find the order
        if not SalesHeader.Get(SalesHeader."Document Type"::Order, XmlOrderNo) then begin
            ShipmentSkipCount += 1;
            LogError('OrderNotFound', XmlOrderNo, StrSubstNo('Order %1 not found', XmlOrderNo));
            exit;
        end;

        // Validate shipping agent exists
        if XmlCourier <> '' then begin
            if not ShippingAgent.Get(XmlCourier) then begin
                if GuiAllowed and not SuppressMessages then
                    if ConfirmManagement.GetResponseOrDefault(
                        StrSubstNo('Shipping agent %1 does not exist. Continue?', XmlCourier), true)
                    then
                        ShippingAgent.Init()
                    else begin
                        ShipmentSkipCount += 1;
                        exit;
                    end;
            end;
        end;

        // Update order fields
        SalesHeader."Shipping Agent Code" := XmlCourier;
        SalesHeader."Package Tracking No." := XmlTrackingNo;
        
        // Additional 3PL specific field if needed
        //if SalesHeader.FieldExist("3PL Tracking No.") then
        SalesHeader."3PL Tracking No." := XmlTrackingNo;

        if not SalesHeader.Modify() then begin
            ShipmentSkipCount += 1;
            LogError('OrderUpdateFailed', XmlOrderNo, StrSubstNo('Failed to update order %1', XmlOrderNo));
            exit;
        end;

        ShipmentCount += 1;
        if GuiAllowed then
            Window.Update(1, XmlOrderNo);

        OnAfterProcessOrder(SalesHeader, XmlTrackingNo, XmlCourier);
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeProcessOrder(OrderNo: Code[20]; TrackingNo: Text[50]; Courier: Text[20]; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterProcessOrder(var SalesHeader: Record "Sales Header"; TrackingNo: Text[50]; Courier: Text[20])
    begin
    end;

    local procedure LogError(ErrorType: Text; OrderNo: Code[20]; ErrorMessage: Text)
    var
        CustomDimensions: Dictionary of [Text, Text];
    begin
        Session.LogMessage('0000SHP', 
            StrSubstNo('%1: %2 for order %3', ErrorType, ErrorMessage, OrderNo), 
            Verbosity::Error, 
            DataClassification::SystemMetadata, 
            TelemetryScope::ExtensionPublisher, CustomDimensions);
    end;

    var
        XmlOrderNo: Code[20];
        XmlCourier: Text[20];
        XmlTrackingNo: Text[50];
        ShipmentCount: Integer;
        ShipmentSkipCount: Integer;
        SuppressMessages: Boolean;
        GuiAllowed: Boolean;
        Window: Dialog;
        CurrentFileName: Text;

    procedure SetSuppressMessages(Suppress: Boolean)
    begin
        SuppressMessages := Suppress;
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

    procedure SetCurrentFilename(Filename: Text)
    begin
        CurrentFileName := Filename;
    end;
}