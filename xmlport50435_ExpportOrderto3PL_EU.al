xmlport 50435 "Export Orders (3PL Detailed)"
{
    Caption = 'Export Orders (3PL Detailed)';
    Direction = Export;
    Format = Xml;
    Encoding = UTF8;
    UseRequestPage = false;
    PreserveWhiteSpace = true;

    //--------------------------------------------------------------------
    //  S C H E M A
    //--------------------------------------------------------------------
    schema
    {
        // <orders>
        textelement(orders)
        {
            // optional <server/> – kept for parity with 50431
            textelement(server) { }

            // one <order> per Sales Header
            tableelement(SalesHeader; "Sales Header")
            {
                XmlName = 'order';
                AutoSave = false;
                SourceTableView = sorting("Document Type", "No.")
                                  where("Document Type" = const(Order),
                                        Status = const(Released));

                // ATTRIBUTE  <order no="SO1037090">
                fieldelement(no; SalesHeader."No.") { }

                //================ HEADER =================
                textelement(header)
                {
                    fieldelement(location; SalesHeader."Location Code") { }
                    fieldelement(number; SalesHeader."No.") { }

                    textelement(delivery_no) //MinOccurs = Zero;
                    { }
                    trigger OnBeforePassVariable()
                    begin
                        delivery_no := SalesHeader."No.";

                    end;
                }
                fieldelement(ref_no; RefNo) { }
                fieldelement(po_no; SalesHeader."External Document No.") { }
                fieldelement(shipon; ShipOn) { }
                fieldelement(priority; Priority) { }
                fieldelement(preparation_code; SalesHeader."3PL Preparation Code") { }
                fieldelement(status; StatusTxt) { }
                fieldelement(comment; HeaderComment) { }
                fieldelement(contact; SalesHeader."Sell-to Phone No.") { }
                fieldelement(ship_via; ShipVia) { }
                fieldelement(service; Service) { }
                fieldelement(shipment_method_code; SalesHeader."Shipment Method Code") { }
                fieldelement(shipping_agent_account_no; SalesHeader."Shipping Agent Account No.") { }
                fieldelement(cod; CodYN) { }
                fieldelement(cod_amount; CodAmountTxt) { }
                fieldelement(gift_wrap; GiftYN) { }
                fieldelement(gift_message; GiftMessage) { }
                fieldelement(language_code; SalesHeader."Language Code") { }
                fieldelement(vat; VatTxt) { }

                //----------- SOLD-TO block -----------
                textelement(soldto)
                {
                    fieldelement(code; SalesHeader."Sell-to Customer No.") { }
                    fieldelement(name; SalesHeader."Sell-to Customer Name") { }
                    fieldelement(name2; SalesHeader."Sell-to Customer Name 2") { }
                    fieldelement(address1; SalesHeader."Sell-to Address") { }
                    fieldelement(address2; SalesHeader."Sell-to Address 2") { }
                    fieldelement(city; SalesHeader."Sell-to City") { }
                    fieldelement(province; SalesHeader."Sell-to County") { }
                    fieldelement(country; SalesHeader."Sell-to Country/Region Code") { }
                    fieldelement(postal; SalesHeader."Sell-to Post Code") { }
                    fieldelement(contact; SalesHeader."Sell-to Contact") { }
                    fieldelement(phone; SalesHeader."Sell-to Phone No.") { }
                    fieldelement(fax; SoldFax) { }
                    fieldelement(email; SalesHeader."Sell-to E-Mail") { }
                }

                //----------- SHIP-TO block -----------
                textelement(shipto)
                {
                    fieldelement(code; SalesHeader."Ship-to Code") { }
                    fieldelement(name; SalesHeader."Ship-to Name") { }
                    fieldelement(name2; SalesHeader."Ship-to Name 2") { }
                    fieldelement(address1; SalesHeader."Ship-to Address") { }
                    fieldelement(address2; SalesHeader."Ship-to Address 2") { }
                    fieldelement(city; SalesHeader."Ship-to City") { }
                    fieldelement(province; SalesHeader."Ship-to County") { }
