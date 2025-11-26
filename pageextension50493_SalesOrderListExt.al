pageextension 50493 "Sales Order List - 3PL Export" extends "Sales Order List"
{
    //Caption = 'Sales Orders 3PL Integration';

    actions
    {
        addlast(Processing)
        { // ================================================================
            // PRIMARY ACTION: Export ONLY the highlighted rows.
            // This is the best practice method using a List of RecordIDs.
            // It is unambiguous and reliable.
            // ================================================================
            action("Export Selected to 3PL")
            {
                ApplicationArea = All;
                Caption = 'Export Selected to 3PL';
                Image = Export;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Export the currently selected (highlighted) Sales Orders to 3PL.';

                trigger OnAction()
                var
                    SalesHeader: Record "Sales Header";
                    SelectedRecordRefs: List of [RecordID];
                    SharePointMgmt: Codeunit "3PL Order SharePoint Mgmt";
                    SelectedCount: Integer;
                begin
                    // Capture the user’s multi-selection into a record list
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

                    // Call the codeunit with the list of RecordIDs.
                    // This codeunit handles all validation and logging.
                    SharePointMgmt.ExportSelectedOrdersByRecordId(SelectedRecordRefs);

                    Message('%1 order(s) have been queued for export to 3PL. Check the Archive for results.', SelectedCount);
                end;
            }

            // ================================================================
            // BATCH ACTION: Export ALL Released orders for the configured location.
            // This is intended for administrators or scheduled tasks.
            // ================================================================
            action("Export All (Batch) to 3PL")
            {
                ApplicationArea = All;
                Caption = 'Export All (Batch) to 3PL';
                Image = ExportToExcel;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = false; // Make it smaller to differentiate from the primary action
                ToolTip = 'Export all Released Sales Orders for the configured Location to 3PL. This may take a long time.';

                trigger OnAction()
                var
                    SharePointMgmt: Codeunit "3PL Order SharePoint Mgmt";
                    Setup: Record "SharePoint Setup";
                    LocText: Text;
                begin
                    if not Confirm('This will export ALL released orders for the configured location. Are you sure you want to continue?', false) then
                        exit;
                        
                    // Passing an empty filter tells the codeunit to use its default logic for all orders.
                    SharePointMgmt.ExportAllSalesOrders('');

                    if Setup.Get('3PL') then
                        LocText := Setup."Location Code";
                    if LocText = '' then
                        Message('Batch export process started for all Released orders. Check the Archive for results.')
                    else
                        Message('Batch export process started for all Released orders at location "%1". Check the Archive for results.', LocText);
                end;
            }
            // ================================================================
            // 4) Optional: Process All Files (Pick & Shipment) from SharePoint
            // ================================================================
            action(ProcessAll3PLFiles)
            {
                ApplicationArea = All;
                Caption = 'Process All Files (Pick & Shipment)';
                Image = Process;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = false;
                ToolTip = 'Scan the SharePoint import folder and process all pick and shipment files.';

                trigger OnAction()
                var
                    SharePointMgmt: Codeunit "3PL Order SharePoint Mgmt";
                begin
                    SharePointMgmt.ProcessAll(); // shows summary Message if GuiAllowed
                end;
            }
           
              
            action("Reset 3PL Export Status")
{
    ApplicationArea = All;
    Caption = 'Reset 3PL Export Status';
    Image = ResetStatus;
    Promoted = true;
    PromotedCategory = Process;
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
    }
}