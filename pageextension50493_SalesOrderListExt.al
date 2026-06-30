pageextension 50493 "Sales Order List - 3PL Export" extends "Sales Order List"
{
    actions
    {
        addlast(Processing)
        {
            // ================================================================
            // PRIMARY ACTION: Export ONLY the highlighted rows.
            // ================================================================
            action("Export Selected to 3PL")
            {
                ApplicationArea = All;
                Caption = 'Export Selected to 3PL';
                Image = Export;
                ToolTip = 'Send each highlighted Sales Order to the SharePoint outbox.';

                trigger OnAction()
                var
                    SalesHeader: Record "Sales Header";
                    SelectedRecordRefs: List of [RecordID];
                    SharePointMgmt: Codeunit "3PL Order SharePoint Mgmt";
                    SelectedCount: Integer;
                begin
                    CurrPage.SetSelectionFilter(SalesHeader);

                    if SalesHeader.IsEmpty() then begin
                        Message('Please select one or more Sales Orders first, then run this action.');
                        exit;
                    end;

                    if SalesHeader.FindSet() then
                        repeat
                            SelectedRecordRefs.Add(SalesHeader.RecordId);
                        until SalesHeader.Next() = 0;

                    SelectedCount := SelectedRecordRefs.Count();

                    SharePointMgmt.ExportSelectedOrdersByRecordId(SelectedRecordRefs);

                    Message('%1 order(s) have been queued for export to 3PL. Check the Archive for results.', SelectedCount);
                end;
            }

            // ================================================================
            // BATCH ACTION: Export ALL eligible orders for the configured location.
            // ================================================================
            action("Export All (Batch) to 3PL")
            {
                ApplicationArea = All;
                Caption = 'Export All (Batch) to 3PL';
                Image = ExportToExcel;
                ToolTip = 'Send every eligible Released order at the configured location to the SharePoint outbox.';

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

                    EligibleOrders.SetRange("Document Type", EligibleOrders."Document Type"::Order);
                    EligibleOrders.SetRange(Status, EligibleOrders.Status::Released);
                    if Setup."Location Code" <> '' then
                        EligibleOrders.SetRange("Location Code", Setup."Location Code");
                    EligibleOrders.SetRange("3PL Order Exported", false);
                    EligibleOrders.SetRange("3PL Skipped", false);
                    EligibleCount := EligibleOrders.Count();

                    if EligibleCount = 0 then begin
                        Message('No eligible orders to export (Released, not already exported, not 3PL Skipped, at location "%1").', Setup."Location Code");
                        exit;
                    end;

                    LocText := Setup."Location Code";
                    if LocText = '' then
                        ConfirmMsg := StrSubstNo('Export %1 Released order(s) to the 3PL SharePoint outbox?', EligibleCount)
                    else
                        ConfirmMsg := StrSubstNo('Export %1 Released order(s) at location "%2" to the 3PL SharePoint outbox?', EligibleCount, LocText);

                    if not Confirm(ConfirmMsg, false) then
                        exit;

                    SharePointMgmt.ExportAllSalesOrders('');

                    Message('Batch export started for %1 order(s). Check the Archive for results.', EligibleCount);
                end;
            }

            // ================================================================
            // Process All Files (Pick & Shipment) from SharePoint
            // ================================================================
            action(ProcessAll3PLFiles)
            {
                ApplicationArea = All;
                Caption = 'Process All Files (Pick & Shipment)';
                Image = Process;
                ToolTip = 'Import every pick, shipment, and return confirmation in the SharePoint inbox.';

                trigger OnAction()
                var
                    SharePointMgmt: Codeunit "3PL Order SharePoint Mgmt";
                begin
                    SharePointMgmt.ProcessAll();
                end;
            }

            action("Reset 3PL Export Status")
            {
                ApplicationArea = All;
                Caption = 'Reset 3PL Export Status';
                Image = ResetStatus;
                ToolTip = 'Reset the export status for selected orders so they can be exported again.';

                trigger OnAction()
                var
                    ThreePLMgmt: Codeunit "3PL Order SharePoint Mgmt";
                    SelectedSalesHeader: Record "Sales Header";
                    Count: Integer;
                begin
                    CurrPage.SetSelectionFilter(SelectedSalesHeader);
                    Count := SelectedSalesHeader.Count;

                    if Count = 0 then
                        Error('Please select at least one order to reset export status.');

                    if not Confirm('Reset 3PL export status for %1 selected order(s)?\\This will reset the export flags and remove archive entries.', true, Count) then
                        exit;

                    if SelectedSalesHeader.FindSet() then
                        repeat
                            ThreePLMgmt.ResetExportStatus(SelectedSalesHeader."No.", false, true);
                        until SelectedSalesHeader.Next() = 0;

                    Message('Export status reset for %1 order(s). You can now export them again.', Count);
                end;
            }
        }

        addlast(Promoted)
        {
            group(Category_3PL)
            {
                Caption = '3PL';
                Image = Allocate;

                actionref(Promoted_ExportSelected; "Export Selected to 3PL") { }
                actionref(Promoted_ExportAllBatch; "Export All (Batch) to 3PL") { }
                actionref(Promoted_ProcessAll; ProcessAll3PLFiles) { }
                actionref(Promoted_ResetExport; "Reset 3PL Export Status") { }
            }
        }
    }
}
