pageextension 50411 "SalesOrderCard.3PLExport" extends "Sales Order"
{
    //Caption = 'Sales Order 3PL Integration';

    layout
    {
        addlast(General)
        {
            group("3PL Debug")
            {
                Caption = '3PL Debug';
                field(SelectedFileName; SelectedFileName)
                {
                    ApplicationArea = All;
                    Caption = 'Selected File Name';
                    ToolTip = 'Used by debug actions to download/import a specific file from the SharePoint import folder.';
                }
            }
        }
    }

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
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    SharePointMgmt: Codeunit "3PL Order SharePoint Mgmt";
                    SalesHeader: Record "Sales Header";
                begin
                    // You don't need to copy, you can just get the record.
        if not SalesHeader.Get(Rec."Document Type", Rec."No.") then
            Error('Could not retrieve the current sales order.');

        // *** THE FIX: Apply a filter to the primary key ***
        // This ensures the XMLport only "sees" this one specific record.
        SalesHeader.SetRange("Document Type", SalesHeader."Document Type");
        SalesHeader.SetRange("No.", SalesHeader."No.");

        // Optional pre-check in UI layer
        if SalesHeader.Status <> SalesHeader.Status::Released then
            Error('Order must be released before export.');

        // Headless export (no UI inside codeunit)
        // The SalesHeader variable now carries the correct filter with it.
        SharePointMgmt.ExportOrderToSharePoint(SalesHeader);

        // Refresh UI record (safer to re-get it)
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
                Promoted = true;
                PromotedCategory = Process;
                

                trigger OnAction()
                var
                    SharePointMgmt: Codeunit "3PL Order SharePoint Mgmt";
                    SalesHeader: Record "Sales Header";
                begin
                    if not SalesHeader.Get(Rec."Document Type", Rec."No.") then
                Error('Could not retrieve the current sales order.');

                // *** THE FIX: Apply a filter to the primary key ***
                // This ensures the XMLport only "sees" this one specific record.
                SalesHeader.SetRange("Document Type", SalesHeader."Document Type");
                SalesHeader.SetRange("No.", SalesHeader."No.");
                    if Rec.Status <> Rec.Status::Released then
                        Error('Order must be released before export.');

                    // Uses existing signature: ExportOrder(var SalesHeader; IsCOD: Boolean): Boolean
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

                trigger OnAction()
                var
                    SharePointMgmt: Codeunit "3PL Order SharePoint Mgmt";
                begin
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
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    SharePointMgmt: Codeunit "3PL Order SharePoint Mgmt";
                begin
                    if SharePointMgmt.ImportShipForOrder(Rec."No.") then
                        Message('Shipment imported for %1.', Rec."No.")
                    else
                        Message('No shipment file found or import failed for %1.', Rec."No.");
                end;
            }

            // -----------------------------------------------------------------
            // Import: All shipment confirmations (batch)
            // -----------------------------------------------------------------
            action(ImportAllShipment)
            {
                ApplicationArea = All;
                Caption = 'Import All Shipments (Batch)';
                Image = Import;

                trigger OnAction()
                var
                    SharePointMgmt: Codeunit "3PL Order SharePoint Mgmt";
                    Cnt: Integer;
                begin
                    // Returns count of processed shipment files
                    Cnt := SharePointMgmt.ImportShipConfirmationBatch();
                    Message('%1 shipment file(s) processed.', Cnt);
                end;
            }

            // -----------------------------------------------------------------
            // Process All: Pick & Shipment in one pass (uses ProcessAll())
            // -----------------------------------------------------------------
            action(ProcessAll3PLFiles)
            {
                ApplicationArea = All;
                Caption = 'Process All Files (Pick & Shipment)';
                Image = Process;

                trigger OnAction()
                var
                    SharePointMgmt: Codeunit "3PL Order SharePoint Mgmt";
                    connector: codeunit "SharePoint Graph Connector";
                begin
                    // Runs both pick + shipment detection and processing
                    // (This procedure shows its own Messages; it is safe in UI context.)
                    SharePointMgmt.ProcessAll();
                end;
            }
             action(TestShipXmlPortDebug)
            {
                ApplicationArea = All;
                Caption = 'Test Ship XMLPort';
                Image = TestFile;
                ToolTip = 'Test Ship XMLPort with selected file without renaming or archiving';

                trigger OnAction()
                var
                    Setup: Record "SharePoint Setup";
                    Graph: Codeunit "SharePoint Graph Connector";
                    OutS: OutStream;
                    FileStream: InStream;
                    XMLPortId: Integer;
                    TempBlob: codeunit "Temp Blob";
                begin
                    if not Setup.Get('3PL') then
                        Error('3PL SharePoint setup not configured.');

                    if SelectedFileName = '' then
                        Error('Set the "Selected File Name" in the 3PL Debug group first.');
                    TempBlob.CreateOutStream(OutS);
                    if not Graph.DownloadFile('3PL', Setup."SharePoint Import Folder", SelectedFileName, OutS) then
                        Error('Download failed: %1', Graph.GetLastError());

                    XMLPortId := Setup."Import Ship XmlPort Id";
                    TempBlob.CreateInStream(FileStream);
                    if TryXmlPortImport(XMLPortId, FileStream) then
                        Message('XMLPort import successful for file: %1', SelectedFileName)
                    else
                        Error('XMLPort import failed: %1', GetLastErrorText());
                end;
            }

            // ===========================
            // Debug helpers
            // ===========================
            action(ListSharePointFilesDebug)
            {
                ApplicationArea = All;
                Caption = 'List Import Files';
                Image = List;

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

            action(ShowDownloadUrlDebug)
            {
                ApplicationArea = All;
                Caption = 'Show Download URL';
                Image = View;

                trigger OnAction()
                var
                    Connector: Codeunit "SharePoint Graph Connector";
                    Setup: Record "SharePoint Setup";
                    Url: Text;
                begin
                    if not Setup.Get('3PL') then
                        Error('3PL SharePoint setup is not configured.');

                    if SelectedFileName = '' then
                        Error('Set the "Selected File Name" in the 3PL Debug group first.');

                    Url := Connector.BuildFileContentUrl('3PL', Setup."SharePoint Import Folder", SelectedFileName);
                    Message('Download URL (Debug):\n%1', Url);
                end;
            }

            action(DownloadSelectedFileDebug)
            {
                ApplicationArea = All;
                Caption = 'Download Selected File';
                Image = Download;

                trigger OnAction()
                var
                    Connector: Codeunit "SharePoint Graph Connector";
                    Setup: Record "SharePoint Setup";
                    TempBlob: Codeunit "Temp Blob";
                    OutS: OutStream;
                    InS: InStream;
                begin
                    if not Setup.Get('3PL') then
                        Error('3PL SharePoint setup not configured.');

                    if SelectedFileName = '' then
                        Error('Set the "Selected File Name" in the 3PL Debug group first.');

                    TempBlob.CreateOutStream(OutS);
                    if not Connector.DownloadFile('3PL', Setup."SharePoint Import Folder", SelectedFileName, OutS) then
                        Error('Download failed: %1', Connector.GetLastError());

                    TempBlob.CreateInStream(InS);
                    DownloadFromStream(InS, 'Save file', '', '', SelectedFileName);
                end;
            }

            action(ImportSelectedPickDebug)
            {
                ApplicationArea = All;
                Caption = 'Import Selected Pick';
                Image = Import;

                trigger OnAction()
                var
                    SharePointMgmt: Codeunit "3PL Order SharePoint Mgmt";
                begin
                    if SelectedFileName = '' then
                        Error('Set the "Selected File Name" in the 3PL Debug group first.');

                    if SharePointMgmt.ImportSpecificPickedFile(SelectedFileName) then
                        Message('Pick file %1 imported.', SelectedFileName)
                    else
                        Message('Import failed or file not valid: %1', SelectedFileName);
                end;
            }
        }
    }

    var
        SelectedFileName: Text[250];
    local procedure TryXmlPortImport(XmlPortId: Integer; var InStream: InStream): Boolean
    begin
        ClearLastError();
        if not XMLPORT.Import(XmlPortId, InStream) then exit(false);
        exit(true);
    end;
}
