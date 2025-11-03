xmlport 50433 "Export COD Total to 3PL"
{
    Direction = Export;
    Format = Xml;
    UseRequestPage = false;
    Encoding = UTF8;
    UseDefaultNamespace = false;
    Caption = 'Export COD/Total to 3PL';

    schema
    {
        textelement(invoices)
        {
            tableelement(SalesHeader; "Sales Header")
            {
                AutoSave = false;
                XmlName = 'invoice';
                SourceTableView = sorting("No.") where("Document Type" = const(Order));
                UseTemporary = false;

                textelement(order_id)
                {
                    MinOccurs = Zero;
                    trigger OnBeforePassVariable()
                    begin
                        order_id := SalesHeader."No.";
                    end;
                }

                textelement(total)
                {
                    MinOccurs = Zero;
                    trigger OnBeforePassVariable()
                    var
                        SalesLine: Record "Sales Line";
                        TotalAmount: Decimal;
                    begin
                        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
                        SalesLine.SetRange("Document No.", SalesHeader."No.");
                        SalesLine.CalcSums("Line Amount");
                        TotalAmount := SalesLine."Line Amount";
                        total := Format(TotalAmount, 0, 9);
                    end;
                }
            }
        }
    }

    var
        //order_id: Text[20];
        //total: Text[30];
        FilterSalesHeader: Record "Sales Header";

    procedure SetFilterRecord(var InFilterSalesHeader: Record "Sales Header")
    begin
        FilterSalesHeader := InFilterSalesHeader;
        FilterSalesHeader.SetRange("Document Type", InFilterSalesHeader."Document Type");
        FilterSalesHeader.SetRange("No.", InFilterSalesHeader."No.");
        CurrXmlPort.SetTableView(FilterSalesHeader);
    end;
}
