pageextension 50411 "SalesOrderCard.3PLExport" extends "Sales Order"
{
    actions
    {
        addlast(Processing)
        {
            // -----------------------------------------------------------------
            // Export: Order (Standard)
            // -----------------------------------------------------------------
            action(ExportOrderTo3PL)
            {
                ApplicationArea = All;
                Caption = 'Export Order';
                Image = Export;
                ToolTip = 'Send this order to the SharePoint outbox for 3PL fulfilment.';

                trigger OnAction()
                var
                    SharePointMgmt: Codeunit "3PL Order SharePoint Mgmt";
                    SalesHeader: Record "Sales Header";
                begin
                    if not SalesHeader.Get(Rec."Document Type", Rec."No.") then
                        Error('Could not retrieve the current sales order.');

                    if SalesHeader."3PL Skipped" then
                        Error('Order %1 is marked "3PL Skipped" and will not be sent to the 3PL.', SalesHeader."No.");

                    SalesHeader.SetRange("Document Type", SalesHeader."Document Type");
                    SalesHeader.SetRange("No.", SalesHeader."No.");

                    if SalesHeader.Status <> SalesHeader.Status::Released then
                        Error('Order must be released before export.');

                    SharePointMgmt.ExportOrderToSharePoint(SalesHeader);

                    Rec.Get(SalesHeader."Document Type", SalesHeader."No.");
                    CurrPage.Update(false);

                    Message('Order %1 , External Doc. No. %2 sent to 3PL Outbox.', Rec."No.", Rec."External Document No.");
                End;
            }

            // -----------------------------------------------------------------
            // Export: COD (uses codeunit ExportOrder(SalesHeader, true))
            // -----------------------------------------------------------------
            action(ExportCODTo3PL)
            {
                ApplicationArea = All;
                Caption = 'Export COD';
                Image = Export;
                ToolTip = 'Send the COD-payment variant of this order to the SharePoint outbox.';

                trigger OnAction()
                var
                    SharePointMgmt: Codeunit "3PL Order SharePoint Mgmt";
                    SalesHeader: Record "Sales Header";
                begin
                    if not SalesHeader.Get(Rec."Document Type", Rec."No.") then
                        Error('Could not retrieve the current sales order.');

                    if SalesHeader."3PL Skipped" then
                        Error('Order %1 is marked "3PL Skipped" and will not be sent to the 3PL.', SalesHeader."No.");

                    SalesHeader.SetRange("Document Type", SalesHeader."Document Type");
                    SalesHeader.SetRange("No.", SalesHeader."No.");
                    if Rec.Status <> Rec.Status::Released then
                        Error('Order must be released before export.');

                    if SharePointMgmt.ExportOrder(Rec, true) then
                        Message('COD for order %1 sent to 3PL Outbox.', Rec."No.")
                    else
                        Message('COD export failed for order %1. Check telemetry/Archive for details.', Rec."No.");
                end;
            }

            // -----------------------------------------------------------------
            // Import: Pick for this order
            // -----------------------------------------------------------------
            action(ImportPickForOrder)
            {
                ApplicationArea = All;
                Caption = 'Import Pick for this Order';
                Image = Import;
                ToolTip = 'Import the pick confirmation file for this order from the SharePoint inbox.';

                trigger OnAction()
                var
                    SharePointMgmt: Codeunit "3PL Order SharePoint Mgmt";
                begin
                    if Rec."3PL Skipped" then
                        Error('Order %1 is marked "3PL Skipped" — no 3PL confirmations are expected.', Rec."No.");
                    if not Rec."3PL Order Exported" then
                        Error('Order %1 has not been exported to the 3PL yet. Export the order before importing the pick confirmation.', Rec."No.");

                    if Rec."Imported Shipped Confirmation" then
                        Error('Cannot import a pick after the ship confirmation has been imported for order %1.', Rec."No.");

                    if SharePointMgmt.ImportPickForOrder(Rec."No.") then
                        Message('Pick imported for %1.', Rec."No.")
                    else
                        Message('No pick file found or import failed for %1.', Rec."No.");
                end;
            }

            // -----------------------------------------------------------------
            // Import: Ship for this order
            // -----------------------------------------------------------------
            action(ImportShipForOrder)
            {
                ApplicationArea = All;
                Caption = 'Import Ship for this Order';
                Image = Import;
                ToolTip = 'Import the shipment confirmation file for this order from the SharePoint inbox.';

                trigger OnAction()
                var
                    SharePointMgmt: Codeunit "3PL Order SharePoint Mgmt";
                begin
                    if Rec."3PL Skipped" then
                        Error('Order %1 is marked "3PL Skipped" — no 3PL confirmations are expected.', Rec."No.");

                    if not Rec."3PL Order Exported" then
                        Error('Order %1 has not been exported to the 3PL yet. Export the order before importing the ship confirmation.', Rec."No.");

                    if not Rec."Imported Pick Confirmation" then
                        Error('Import the pick confirmation for order %1 before importing the ship confirmation.', Rec."No.");

                    if SharePointMgmt.ImportShipForOrder(Rec."No.") then
                        Message('Shipment imported for %1.', Rec."No.")
                    else
                        Message('No shipment file found or import failed for %1.', Rec."No.");
                end;
            }

            // -----------------------------------------------------------------
            // -----------------------------------------------------------------
            action(ClearExportFields3PL)
            {
                ApplicationArea = All;
                Caption = 'Clear Export Fields';
                Image = ClearLog;
                ToolTip = 'Reset the 3PL export flags and export date on this order.';

                trigger OnAction()
                var
                    SalesHeader: Record "Sales Header";
                begin
                    if not Confirm('Clear the 3PL export fields on order %1?', false, Rec."No.") then
                        exit;
                    if not SalesHeader.Get(Rec."Document Type", Rec."No.") then
                        Error('Could not retrieve the current sales order.');
                    SalesHeader.ClearExport3PLFields();
                    CurrPage.Update(false);
                    Message('Export fields cleared on order %1.', Rec."No.");
                end;
            }

            action(ClearPickConfirmation3PL)
            {
                ApplicationArea = All;
                Caption = 'Clear Pick Confirmation Fields';
                Image = ClearLog;
                ToolTip = 'Reset the imported pick confirmation flag and date on this order.';

                trigger OnAction()
                var
                    SalesHeader: Record "Sales Header";
                begin
                    if not Confirm('Clear the pick confirmation fields on order %1?', false, Rec."No.") then
                        exit;
                    if not SalesHeader.Get(Rec."Document Type", Rec."No.") then
                        Error('Could not retrieve the current sales order.');
                    SalesHeader.ClearPickConfirmation3PLFields();
                    CurrPage.Update(false);
                    Message('Pick confirmation fields cleared on order %1.', Rec."No.");
                end;
            }

            action(ClearShipConfirmation3PL)
            {
                ApplicationArea = All;
                Caption = 'Clear Ship Confirmation Fields';
                Image = ClearLog;
                ToolTip = 'Reset the imported shipment confirmation flag and date on this order.';

                trigger OnAction()
                var
                    SalesHeader: Record "Sales Header";
                begin
                    if not Confirm('Clear the ship confirmation fields on order %1?', false, Rec."No.") then
                        exit;
                    if not SalesHeader.Get(Rec."Document Type", Rec."No.") then
                        Error('Could not retrieve the current sales order.');
                    SalesHeader.ClearShipConfirmation3PLFields();
                    CurrPage.Update(false);
                    Message('Ship confirmation fields cleared on order %1.', Rec."No.");
                end;
            }

            action(ListSharePointFilesDebug)
            {
                ApplicationArea = All;
                Caption = 'List Import Files';
                Image = List;
                ToolTip = 'Show the file names currently in the SharePoint inbox.';

                trigger OnAction()
                var
                    Connector: Codeunit "SharePoint Graph Connector";
                    Setup: Record "SharePoint Setup";
                    FileList: List of [Text];
                    Name: Text;
                    Output: Text;
                begin
                    if not Setup.Get('3PL') then
                        Error('3PL SharePoint setup not configured.');

                    FileList := Connector.ListFilesInFolder('3PL', Setup."SharePoint Import Folder");

                    foreach Name in FileList do
                        Output := Output + Name + '\n';

                    if Output = '' then
                        Output := '(no files)';

                    Message(Output);
                end;
            }
        }

        addlast(Promoted)
        {
            group(Category_3PL)
            {
                Caption = '3PL';
                Image = Allocate;

                actionref(Promoted_ExportOrder; ExportOrderTo3PL) { }
                actionref(Promoted_ExportCOD; ExportCODTo3PL) { }
                actionref(Promoted_ImportPick; ImportPickForOrder) { }
                actionref(Promoted_ImportShip; ImportShipForOrder) { }
                actionref(Promoted_ClearExport; ClearExportFields3PL) { }
                actionref(Promoted_ClearPick; ClearPickConfirmation3PL) { }
                actionref(Promoted_ClearShip; ClearShipConfirmation3PL) { }
                actionref(Promoted_ListFiles; ListSharePointFilesDebug) { }
            }
        }
    }
}
