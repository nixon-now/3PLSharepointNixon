pageextension 50411 "SalesOrderCard.3PLExport" extends "Sales Order"
{
    actions
    {
        addlast(Processing)
        {
            group("3PL Integration")
            {
                Caption = '3PL Integration';
                Image = ExportFile;

                // — Single‑Order Actions —
                group("Single Order")
                {
                    Caption = 'Single Order';

                    action("Export Order to SharePoint")
                    {
                        ApplicationArea = All;
                        Caption = 'Export Order';
                        Image = ExportFile;
                        ToolTip = 'Export this sales order to SharePoint as an XML file';
                        Promoted = true; PromotedCategory = Process; PromotedIsBig = true;
                        trigger OnAction()
                        var
                            SalesHeader: Record "Sales Header";
                            SharePointMgmt: Codeunit "3PL Order SharePoint Mgmt";
                        begin
                            CurrPage.SetSelectionFilter(SalesHeader);
                            if not SalesHeader.FindFirst() then Error(Err_NoOrderSelectedLbl);
                            if not Confirm(Qst_ExportOrderLbl, true, SalesHeader."No.") then exit;
                            SharePointMgmt.ExportOrderToSharePoint(SalesHeader);
                        end;
                    }

                    action("Import Pick Confirmation")
                    {
                        ApplicationArea = All;
                        Caption = 'Import Pick Confirmation';
                        Image = Import;
                        ToolTip = 'Import pick confirmation from SharePoint';
                        Promoted = true; PromotedCategory = Process;
                        trigger OnAction()
                        var
                            SalesHeader: Record "Sales Header";
                            SharePointMgmt: Codeunit "3PL Order SharePoint Mgmt";
                            FileName: Text;
                        begin
                            CurrPage.SetSelectionFilter(SalesHeader);
                            if not SalesHeader.FindFirst() then Error(Err_NoOrderSelectedLbl);
                            if not Confirm(Qst_ImportPickLbl, true, SalesHeader."No.") then exit;
                            FileName := SalesHeader."No." + '_pick.xml';
                            SharePointMgmt.ImportPickConfirmationFromSharePoint(FileName);
                        end;
                    }

                    action("Export COD Total")
                    {
                        ApplicationArea = All;
                        Caption = 'Export COD Total';
                        Image = ExportElectronicDocument;
                        ToolTip = 'Export COD total amount to SharePoint';
                        Promoted = true; PromotedCategory = Process;
                        trigger OnAction()
                        var
                            SalesHeader: Record "Sales Header";
                            SharePointMgmt: Codeunit "3PL Order SharePoint Mgmt";
                        begin
                            CurrPage.SetSelectionFilter(SalesHeader);
                            if not SalesHeader.FindFirst() then Error(Err_NoOrderSelectedLbl);
                            if not Confirm(Qst_ExportCODLbl, true, SalesHeader."No.") then exit;
                            SharePointMgmt.ExportCODTotal(SalesHeader);
                        end;
                    }

                    action("Import Shipped Confirmation")
                    {
                        ApplicationArea = All;
                        Caption = 'Import Shipped Confirmation';
                        Image = ImportLog;
                        ToolTip = 'Import shipment confirmation from SharePoint';
                        Promoted = true; PromotedCategory = Process;
                        trigger OnAction()
                        var
                            SalesHeader: Record "Sales Header";
                            SharePointMgmt: Codeunit "3PL Order SharePoint Mgmt";
                            FileName: Text;
                        begin
                            CurrPage.SetSelectionFilter(SalesHeader);
                            if not SalesHeader.FindFirst() then Error(Err_NoOrderSelectedLbl);
                            if not Confirm(Qst_ImportShippedLbl, true, SalesHeader."No.") then exit;
                            FileName := SalesHeader."No." + '_ship.xml';
                            SharePointMgmt.ImportShipmentTrackingFromSharePoint(FileName);
                        end;
                    }
                }

                // — Bulk‑Order Actions —
                group("Bulk Processing")
                {
                    Caption = 'Bulk Processing';

                    action("Export All Sales Orders")
                    {
                        ApplicationArea = All;
                        Caption = 'Export All Orders';
                        ToolTip = 'Export all released sales orders for the current location';
                        Promoted = true;
                        PromotedCategory = Process;
                        trigger OnAction()
                        var
                            SharePointMgmt: Codeunit "3PL Order SharePoint Mgmt";
                        begin
                            SharePointMgmt.ExportAllSalesOrders();
                            Message(AllOrdersExportedMsgLbl);
                        end;
                    }
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

                    action("Process All")
                    {
                        ApplicationArea = All;
                        Caption = 'Process All';
                        ToolTip = 'Run all 3PL integration steps for pending orders';
                        trigger OnAction()
                        var
                            SharePointMgmt: Codeunit "3PL Order SharePoint Mgmt";
                        begin
                            SharePointMgmt.ProcessAll();
                            Message(AllProcessedMsgLbl);
                        end;
                    }
                    action(ViewArchive)
                {
                    ApplicationArea = All;
                    Caption = 'View Integration Archive';
                    Image = Archive;
                    RunObject = Page "3PL Archive List";
                    ToolTip = 'View history of 3PL integration transactions';
                }
                }

                // — SharePoint Connection Management —
                group("Connection Management")
                {
                    Caption = 'Connection Management';
                    Image = Setup;

                    action("Test SharePoint Connection")
                    {
                        ApplicationArea = All;
                        Caption = 'Test Connection';
                        Image = TestDatabase;
                        ToolTip = 'Test the connection to SharePoint';
                        trigger OnAction()
                        var
                            SharePointConnector: Codeunit "SharePoint Graph Connector";
                        begin
                            if SharePointConnector.TestConnection('3PL') then
                                Message(ConnectionSuccessMsg)
                            else
                                Error(ConnectionFailedErr, SharePointConnector.GetLastError());
                        end;
                    }

                    action("List SharePoint Files")
                    {
                        ApplicationArea = All;
                        Caption = 'List Files';
                        Image = List;
                        ToolTip = 'List available files in SharePoint import folder';
                        trigger OnAction()
                        var
                            SharePointConnector: Codeunit "SharePoint Graph Connector";
                            FileList: List of [Text];
                            FileName: Text;
                            FileNames: Text;
                        begin
                            FileList := SharePointConnector.ListFilesFromSetup('3PL');
                            foreach FileName in FileList do
                                FileNames += FileName + '\n';
                            
                            if FileNames = '' then
                                Message(NoFilesFoundMsg)
                            else
                                Message(FilesFoundMsg, FileNames);
                        end;
                    }

                    action("Refresh SharePoint Token")
                    {
                        ApplicationArea = All;
                        Caption = 'Refresh Token';
                        Image = Refresh;
                        ToolTip = 'Refresh the SharePoint access token';
                        trigger OnAction()
                        var
                            SharePointConnector: Codeunit "SharePoint Graph Connector";
                        begin
                            SharePointConnector.GetAccessToken('3PL');
                            Message(TokenRefreshedMsg);
                        end;
                    }
                }
            }
        }
    }

    var
        Err_NoOrderSelectedLbl: Label 'No sales order selected';
        Qst_ExportOrderLbl: Label 'Export sales order %1 to SharePoint?';
        Qst_ImportPickLbl: Label 'Import pick confirmation for order %1 from SharePoint?';
        Qst_ExportCODLbl: Label 'Export COD total for order %1 to SharePoint?';
        Qst_ImportShippedLbl: Label 'Import shipped confirmation for order %1 from SharePoint?';
        AllOrdersExportedMsgLbl: Label 'All eligible sales orders have been exported.';
        AllProcessedMsgLbl: Label 'All pending 3PL integration steps have been processed.';
        ConnectionSuccessMsg: Label 'SharePoint connection test successful.';
        ConnectionFailedErr: Label 'SharePoint connection failed: %1';
        NoFilesFoundMsg: Label 'No files found in SharePoint import folder.';
        FilesFoundMsg: Label 'Files in SharePoint import folder:\n%1';
        TokenRefreshedMsg: Label 'SharePoint access token refreshed successfully.';
}