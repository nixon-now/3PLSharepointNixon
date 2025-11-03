pageextension 50413 "Sales Orders 3PL" extends "Sales Order List"
{
    actions
    {
        addlast(Processing)
        {
            action("Export Selected Orders")
            {
                ApplicationArea = All;
                Caption = 'Export Selected Orders';
                Image = Export;
                ToolTip = 'Export the currently selected orders';
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    SalesHeader: Record "Sales Header";
                    SharePointMgmt: Codeunit "3PL Order SharePoint Mgmt";
                begin
                    CurrPage.SetSelectionFilter(SalesHeader);
                    if SalesHeader.FindSet() then
                    begin
                        if Confirm('Export %1 selected orders?', false, SalesHeader.Count) then
                            SharePointMgmt.ExportSelectedOrders(SalesHeader);
                    end;
                end;
            }
        }
    }
}