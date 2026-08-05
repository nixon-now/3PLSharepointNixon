pageextension 50494 "Sales Return Order List - 3PL" extends "Sales Return Order List"
{
    actions
    {
        addlast(Processing)
        {
            // ================================================================
            // BATCH ACTION: Export ALL eligible return orders for the configured location.
            // ================================================================
            action("Export All (Batch) to 3PL")
            {
                ApplicationArea = All;
                Caption = 'Export All (Batch) to 3PL';
                Image = ExportToExcel;
                ToolTip = 'Send every eligible Released return order at the configured location to the SharePoint outbox.';

                trigger OnAction()
                var
                    SharePointMgmt: Codeunit "3PL Order SharePoint Mgmt";
                    Setup: Record "SharePoint Setup";
                    EligibleOrders: Record "Sales Header";
                    EligibleCount: Integer;
                    LocText: Text;
                    ConfirmMsg: Text;
                begin
                    if not Setup.Get('3PL') then
                        Error('3PL SharePoint setup not configured.');

                    EligibleOrders.SetRange("Document Type", EligibleOrders."Document Type"::"Return Order");
                    EligibleOrders.SetRange(Status, EligibleOrders.Status::Released);
                    if Setup."Location Code" <> '' then
                        EligibleOrders.SetRange("Location Code", Setup."Location Code");
                    EligibleOrders.SetRange("3PL SRO Exported", false);
                    EligibleOrders.SetRange("3PL Skipped", false);
                    EligibleCount := EligibleOrders.Count();

                    if EligibleCount = 0 then begin
                        Message('No eligible return orders to export (Released, not already exported, at location "%1").', Setup."Location Code");
                        exit;
                    end;

                    LocText := Setup."Location Code";
                    if LocText = '' then
                        ConfirmMsg := StrSubstNo('Export %1 Released return order(s) to the 3PL SharePoint outbox?', EligibleCount)
                    else
                        ConfirmMsg := StrSubstNo('Export %1 Released return order(s) at location "%2" to the 3PL SharePoint outbox?', EligibleCount, LocText);

                    if not Confirm(ConfirmMsg, false) then
                        exit;

                    SharePointMgmt.ExportAllSalesReturnOrders('');

                    Message('Batch export started for %1 return order(s). Check the Archive for results.', EligibleCount);
                end;
            }
        }

        addlast(Promoted)
        {
            group(Category_3PL_SROList)
            {
                Caption = '3PL';
                Image = Allocate;

                actionref(Promoted_ExportAllBatch; "Export All (Batch) to 3PL") { }
            }
        }
    }
}
