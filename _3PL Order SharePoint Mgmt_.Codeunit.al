
codeunit 50400 "3PL Order SharePoint Mgmt"
{
    SingleInstance = false;

    var
        Graph: Codeunit "SharePoint Graph Connector";
        Setup: Record "SharePoint Setup";
        ImportedSuffixTok: Label '_imported', Locked = true;

    // =========================================================================
    // Export Functions
    // =========================================================================

    local procedure AlreadyExported(OrderNo: Code[20]; IsCOD: Boolean): Boolean
    var
        SalesHeader: Record "Sales Header";
    begin
        if not SalesHeader.Get(SalesHeader."Document Type"::Order, OrderNo) then
            exit(false);

        if SalesHeader."3PL Skipped" then
            exit(false);

        if IsCOD then
            exit(SalesHeader."3PL COD Exported")
        else
            exit(SalesHeader."3PL Order Exported");
    end;

    procedure ExportSelectedOrdersByRecordId(SelectedRecordRefs: List of [RecordID])
    var
        SalesHeader: Record "Sales Header";
        TempBlob: Codeunit "Temp Blob";
        RecordRef: RecordRef;
        i: Integer;
        SelectedRecords: Integer;
        SuccessCount: Integer;
        ErrorCount: Integer;
        Err: Text;
        Dims: Dictionary of [Text, Text];
        IdTxt: Text;
    begin
        if not Setup.Get('3PL') then begin
            Dims.Add('reason', 'setup_not_found');
            Session.LogMessage('3PL-SETUP', '3PL SharePoint Setup not found', Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, Dims);
            exit;
        end;
        SelectedRecords := SelectedRecordRefs.Count;
        for i := 1 to SelectedRecordRefs.Count() do begin
            IdTxt := Format(SelectedRecordRefs.Get(i));
            if not RecordRef.Get(SelectedRecordRefs.Get(i)) then begin
                ErrorCount += 1;
                Clear(Dims);
                Dims.Add('recordId', CopyStr(IdTxt, 1, 100));
                Session.LogMessage('3PL-RECORD-NOTFOUND', 'RecordID not found during export selection', Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, Dims);
                continue;
            end;
            RecordRef.SetTable(SalesHeader);

            if AlreadyExported(SalesHeader."No.", false) then begin
                LogExportSkipped(SalesHeader."No.", 'Already exported (flag on order is true)');
                continue;
            end;

            if TryExportOrder(SalesHeader, TempBlob, true, false, Err) then begin
                SuccessCount += 1;
                Clear(Dims);
                Dims.Add('orderNo', SalesHeader."No.");
                Session.LogMessage('3PL-EXPORT-OK', 'Order exported to SharePoint', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, Dims);
            end
            else begin
                ErrorCount += 1;
                Clear(Dims);
                Dims.Add('orderNo', SalesHeader."No.");
                Dims.Add('error', CopyStr(Err, 1, 250));
                Session.LogMessage('3PL-EXPORT-FAIL', 'Export failed', Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, Dims);
            end;
        end;
        Clear(Dims);
        Dims.Add('selected', Format(SelectedRecords));
        Dims.Add('success', Format(SuccessCount));
        Dims.Add('failed', Format(ErrorCount));
        Session.LogMessage('3PL-EXPORT-SUMMARY', 'Batch export summary (by RecordId)', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, Dims);
    end;

    procedure ExportSelectedOrders(SelectionFilter: Text)
    var
        SalesHeader: Record "Sales Header";
        SalesHeaderToExport: Record "Sales Header";
        TempBlob: Codeunit "Temp Blob";
        SuccessCount: Integer;
        ErrorCount: Integer;
        Err: Text;
        Dims: Dictionary of [Text, Text];
    begin
        if not Setup.Get('3PL') then begin
            Dims.Add('reason', 'setup_not_found');
            Session.LogMessage('3PL-SETUP', '3PL SharePoint Setup not found', Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, Dims);
            exit;
        end;
        SalesHeader.SetView(SelectionFilter);
        if SalesHeader.FindSet() then
            repeat
                if not SalesHeaderToExport.Get(SalesHeader."Document Type", SalesHeader."No.") then begin
                    ErrorCount += 1;
                    Clear(Dims);
                    Dims.Add('orderNo', SalesHeader."No.");
                    Session.LogMessage('3PL-RECORD-NOTFOUND', 'Order no longer exists', Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, Dims);
                    continue;
                end;
                if TryExportOrder(SalesHeaderToExport, TempBlob, true, false, Err) then begin
                    SuccessCount += 1;
                    Clear(Dims);
                    Dims.Add('orderNo', SalesHeaderToExport."No.");
                    Session.LogMessage('3PL-EXPORT-OK', 'Order exported to SharePoint', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, Dims);
                end
                else begin
                    ErrorCount += 1;
                    Clear(Dims);
                    Dims.Add('orderNo', SalesHeaderToExport."No.");
                    Dims.Add('error', CopyStr(Err, 1, 250));
                    Session.LogMessage('3PL-EXPORT-FAIL', 'Export failed', Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, Dims);
                end;
            until SalesHeader.Next() = 0;
        Clear(Dims);
        Dims.Add('success', Format(SuccessCount));
        Dims.Add('failed', Format(ErrorCount));
        Session.LogMessage('3PL-EXPORT-SUMMARY', 'Batch export summary (by SelectionView)', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, Dims);
    end;

    procedure ExportOrderToSharePoint(var InSalesHeader: Record "Sales Header")
    var
        TempBlob: Codeunit "Temp Blob";
        Err: Text;
        SuccessCount: Integer;
    begin
        if not CheckSetup() then exit;
        if AlreadyExported(InSalesHeader."No.", false) then begin
            LogExportSkipped(InSalesHeader."No.", 'Already exported (archive)');
            if GuiAllowed then
                Message('Order %1 was already exported previously.', InSalesHeader."No.");
            exit;
        end;

        if TryExportOrder(InSalesHeader, TempBlob, true, false, Err) then begin
            LogExportSuccess(InSalesHeader."No.", SuccessCount);
            if GuiAllowed then
                Message('Order %1 , External Doc. No. %2 has been successfully exported to SharePoint.', InSalesHeader."No.", InSalesHeader."External Document No.");
        end else begin
            LogExportFailure(InSalesHeader."No.", Err);
            if GuiAllowed then
                Error('Failed to export order %1: %2', InSalesHeader."No.", Err);
        end;
    end;

    procedure ExportOrder(var SalesHeader: Record "Sales Header"; IsCOD: Boolean): Boolean
    var
        TempBlob: Codeunit "Temp Blob";
        Err: Text;
        Success: Boolean;
    begin
        Success := TryExportOrder(SalesHeader, TempBlob, true, IsCOD, Err);
        if Success then begin
            LogExportSuccess(SalesHeader."No.", IsCOD);
            if GuiAllowed then
                Message('%1 has been successfully exported to SharePoint.', SalesHeader."No.");
        end else begin
            LogExportFailure(SalesHeader."No.", Err, IsCOD);
            if GuiAllowed then
                Error('Failed to export %1: %2: ', SalesHeader."No.", Err);
        end;
        exit(Success);
    end;

    procedure ExportAllSalesOrders(SelectionFilter: Text)
    var
        SalesHeader: Record "Sales Header";
        TempBlob: Codeunit "Temp Blob";
        SuccessCount: Integer;
        ErrorCount: Integer;
        SkippedCount: Integer;
        Err: Text;
    begin
        if not CheckSetup() then exit;

        if SelectionFilter <> '' then begin
            ExportSelectedOrders(SelectionFilter);
            exit;
        end;

        SalesHeader.Reset();
        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
        SalesHeader.SetRange(Status, SalesHeader.Status::Released);
        if Setup."Location Code" <> '' then
            SalesHeader.SetRange("Location Code", Setup."Location Code");

        SalesHeader.SetRange("3PL Order Exported", false);
        SalesHeader.SetRange("3PL Skipped", false);

        if SalesHeader.FindSet() then
            repeat
                if TryExportOrder(SalesHeader, TempBlob, true, false, Err) then begin
                    SuccessCount += 1;
                    LogExportSuccess(SalesHeader."No.", SuccessCount);
                end else begin
                    if Err = 'Order already exported' then
                        SkippedCount += 1
                    else begin
                        ErrorCount += 1;
                        LogExportFailure(SalesHeader."No.", Err, ErrorCount);
                    end;
                end;
            until SalesHeader.Next() = 0;

        LogExportSummary(SuccessCount + ErrorCount + SkippedCount, SuccessCount, ErrorCount, 'all released orders');
    end;


    procedure ResetExportStatus(OrderNo: Code[20]; ResetCOD: Boolean; ResetOrder: Boolean)
    var
        SalesHeader: Record "Sales Header";
        ThreePLArchive: Record "3PL Archive";
        Dims: Dictionary of [Text, Text];
    begin
        // 1. Reset Sales Header flags
        if not SalesHeader.Get(SalesHeader."Document Type"::Order, OrderNo) then begin
            Clear(Dims);
            Dims.Add('orderNo', OrderNo);
            Session.LogMessage('3PL-RESET-NOTFOUND', 'Order not found for reset',
                Verbosity::Warning, DataClassification::SystemMetadata,
                TelemetryScope::ExtensionPublisher, Dims);
            exit;
        end;

        if ResetCOD then begin
            SalesHeader."3PL COD Exported" := false;
            SalesHeader."3PL Export Date" := 0D;

            // Delete COD archive entries
            ThreePLArchive.SetRange("Document No.", OrderNo);
            ThreePLArchive.SetRange("Direction", ThreePLArchive."Direction"::Export);
            ThreePLArchive.SetRange("Step", ThreePLArchive."Step"::ExportCOD);
            ThreePLArchive.DeleteAll();
        end;

        if ResetOrder then begin
            SalesHeader."3PL Order Exported" := false;
            SalesHeader."3PL Exported" := false;
            SalesHeader."3PL Export Date" := 0D;

            // Delete regular order archive entries
            ThreePLArchive.SetRange("Document No.", OrderNo);
            ThreePLArchive.SetRange("Direction", ThreePLArchive."Direction"::Export);
            ThreePLArchive.SetRange("Step", ThreePLArchive."Step"::ExportOrder);
            ThreePLArchive.DeleteAll();
        end;

        if (ResetCOD or ResetOrder) then begin
            SalesHeader.Modify(true);

            // Log the reset
            Clear(Dims);
            Dims.Add('orderNo', OrderNo);
            if ResetCOD then Dims.Add('resetCOD', 'true');
            if ResetOrder then Dims.Add('resetOrder', 'true');
            Session.LogMessage('3PL-RESET-STATUS', 'Export status reset for order',
                Verbosity::Normal, DataClassification::SystemMetadata,
                TelemetryScope::ExtensionPublisher, Dims);

            if GuiAllowed then
                Message('Export status reset for order %1. The order can now be exported again.', OrderNo);
        end;
    end;

    local procedure TryExportOrder(var SalesHeader: Record "Sales Header"; var TempBlob: Codeunit "Temp Blob"; SilentMode: Boolean; IsCODExport: Boolean; var Err: Text): Boolean
    var
        OutS: OutStream;
        InS: InStream;
        XmlId: Integer;
        FileName: Text;
        ArchiveStep: Enum "3PL Archive Step";
        OneOrder: Record "Sales Header";
    begin
        // 1. Initial checks (fast)
        if AlreadyExported(SalesHeader."No.", IsCODExport) then begin
            Err := 'Order already exported';
            exit(false);
        end;

        if not ValidateExportPreconditions(SalesHeader, IsCODExport, Err) then
            exit(false);

        // 2. Prepare the export data (fast)
        if IsCODExport then begin
            XmlId := Setup."Export COD XmlPort Id";
            FileName := SalesHeader."No." + '_COD.xml';
            ArchiveStep := ArchiveStep::ExportCOD;
        end else begin
            XmlId := Setup."Export SO XmlPort Id";
            FileName := SalesHeader."No." + '_ship.xml';
            ArchiveStep := ArchiveStep::ExportOrder;
        end;

        if not PrepareSingleRecordView(SalesHeader, OneOrder, Err) then
            exit(false);

        Clear(TempBlob);
        TempBlob.CreateOutStream(OutS);

        if not RunExport(XmlId, OneOrder, OutS, IsCODExport) then begin
            Err := 'Export failed';
            exit(false);
        end;

        // 3. Upload the file (network time, a few seconds)
        TempBlob.CreateInStream(InS);
        if not Graph.UploadFile('3PL', Setup."SharePoint Export Folder", FileName, InS) then begin
            Err := Graph.GetLastError();
            exit(false);
        end;

        // 4. Update the critical record (fast)
        UpdateOrderExportStatus(SalesHeader, IsCODExport);

        // =========================================================================
        // !! CRITICAL FIX !!
        // Commit the transaction NOW. This saves the Sales Header update to the
        // database permanently. The slow logging that follows will happen in a
        // new, separate transaction. If the logging fails or times out, it will
        // NOT roll back the Sales Header update.
        // =========================================================================
        Commit();

        // 5. Perform the slow logging operation in a new transaction.
        // If this step hangs, it will not affect the main export process.
        ArchiveLog(true, "3PL Log Direction"::Export, SalesHeader."No.",
            SalesHeader."External Document No.", FileName, Setup,
            ArchiveStep, '', '');

        exit(true);
    end;

    procedure ImportShipConfirmationBatch(): Integer
    var
        FileList: List of [Text];
        FileName: Text;
        CountProcessed: Integer;
    begin
        if not CheckSetup() then exit(0);

        FileList := Graph.ListFilesInFolder('3PL', Setup."SharePoint Import Folder");

        foreach FileName in FileList do
            if IsShipFile(FileName) then begin
                if not TryImportConfirmation(FileName, "3PL Import Type"::Ship) then
                    LogFileImportFailed(FileName, 'Ship');
                CountProcessed += 1;
            end;

        LogBatchProcessed('Ship', CountProcessed);
        exit(CountProcessed);
    end;

    procedure ImportPickForOrder(SalesOrderNo: Code[20]): Boolean
    begin
        exit(ImportConfirmationForOrder(SalesOrderNo, "3PL Import Type"::Pick));
    end;

    procedure ImportShipForOrder(SalesOrderNo: Code[20]): Boolean
    begin
        exit(ImportConfirmationForOrder(SalesOrderNo, "3PL Import Type"::Ship));
    end;

    local procedure ImportConfirmationForOrder(SalesOrderNo: Code[20]; ConfType: Enum "3PL Import Type"): Boolean
    var
        FileName: Text;
    begin
        if not FirstFileForOrder(SalesOrderNo, ConfType, FileName) then
            exit(false);
        exit(TryImportConfirmation(FileName, ConfType));
    end;

    procedure ImportPickConfirmationBatch(): Integer
    var
        FileList: List of [Text];
        FileName: Text;
        CountProcessed: Integer;
    begin
        if not CheckSetup() then exit(0);

        FileList := Graph.ListFilesInFolder('3PL', Setup."SharePoint Import Folder");

        foreach FileName in FileList do
            if IsPickFile(FileName) then begin
                if not TryImportConfirmation(FileName, "3PL Import Type"::Pick) then
                    LogFileImportFailed(FileName, 'Pick');
                CountProcessed += 1;
            end;

        LogBatchProcessed('Pick', CountProcessed);
        exit(CountProcessed);
    end;

    procedure ProcessAll()
    var
        FileNames: List of [Text];
        PickFiles: List of [Text];
        ShipFiles: List of [Text];
        SROFiles: List of [Text];
        FileName: Text;
        Total: Integer;
        PickCount: Integer;
        ShipCount: Integer;
        SROCount: Integer;
        OtherCount: Integer;
        AlreadyProcessedCount: Integer;
        PickSkippedAlreadyAppliedCount: Integer;
        ShipDeferredAwaitingPickCount: Integer;
        ErrorCount: Integer;
        PeekedOrderNo: Code[20];
        Msg: Text;
        DummyBlob: Codeunit "Temp Blob";
    begin
        if not CheckSetup() then exit;
        if Setup."SharePoint Import Folder" = '' then begin
            if GuiAllowed then Message('SharePoint Import Folder is not defined.');
            exit;
        end;

        FileNames := Graph.ListFilesInFolder('3PL', Setup."SharePoint Import Folder");
        if FileNames.Count() = 0 then begin
            if GuiAllowed then Message('No files found in SharePoint import folder.');
            exit;
        end;


        foreach FileName in FileNames do begin
            if IsAlreadyProcessed(FileName) then begin
                AlreadyProcessedCount += 1;
                continue;
            end;
            case true of
                IsPickFile(FileName):
                    PickFiles.Add(FileName);
                IsShipFile(FileName):
                    ShipFiles.Add(FileName);
                IsSROFile(FileName):
                    SROFiles.Add(FileName);
                else begin
                    ArchiveLog(false, "3PL Log Direction"::Import, '', '', FileName,
                        Setup, "3PL Archive Step"::ImportConfirmation,
                        'Unrecognized file type', Setup."SharePoint Error Folder");
                    OtherCount += 1;
                end;
            end;
        end;

        foreach FileName in PickFiles do begin
            PeekedOrderNo := '';
            if TryPeekOrderNoFromInboxFile(FileName, PeekedOrderNo) then
                if OrderHasPickImported(PeekedOrderNo) then begin
                    MarkPickAlreadyApplied(FileName, PeekedOrderNo);
                    PickSkippedAlreadyAppliedCount += 1;
                    continue;
                end;
            PickCount += 1;
            if not TryImportConfirmation(FileName, "3PL Import Type"::Pick) then
                ErrorCount += 1;
        end;

        foreach FileName in ShipFiles do begin
            PeekedOrderNo := '';
            if TryPeekOrderNoFromInboxFile(FileName, PeekedOrderNo) then
                if OrderExistsButPickNotImported(PeekedOrderNo) then begin
                    LogShipDeferredAwaitingPick(FileName, PeekedOrderNo);
                    ShipDeferredAwaitingPickCount += 1;
                    continue;
                end;
            ShipCount += 1;
            if not TryImportConfirmation(FileName, "3PL Import Type"::Ship) then
                ErrorCount += 1;
        end;

        foreach FileName in SROFiles do begin
            SROCount += 1;
            if not TryImportSROConfirmation(FileName, false, DummyBlob) then
                ErrorCount += 1;
        end;

        Total := FileNames.Count();
        LogProcessAllSummary(Total, PickCount, ShipCount, SROCount, OtherCount, AlreadyProcessedCount,
            PickSkippedAlreadyAppliedCount, ShipDeferredAwaitingPickCount);
        Msg := StrSubstNo(
            '%1 file(s) processed. Errors=%2 (open the 3PL Archive for details). Picks=%3 (skipped %4 already-applied), Shipments=%5 (deferred %6 awaiting pick), Returns=%7, Unrecognized=%8, Already-imported skipped=%9',
            Total, ErrorCount, PickCount, PickSkippedAlreadyAppliedCount, ShipCount, ShipDeferredAwaitingPickCount,
            SROCount, OtherCount, AlreadyProcessedCount);
        if GuiAllowed then
            Message(Msg);
    end;

    [TryFunction]
    local procedure TryPeekOrderNoFromInboxFile(FileName: Text; var OrderNo: Code[20])
    var
        TempBlob: Codeunit "Temp Blob";
        XmlDoc: XmlDocument;
        NumberNode: XmlNode;
        InS: InStream;
        OutS: OutStream;
    begin
        OrderNo := '';
        TempBlob.CreateOutStream(OutS);
        if not Graph.DownloadFile('3PL', Setup."SharePoint Import Folder", FileName, OutS) then
            Error('Download failed for peek');

        TempBlob.CreateInStream(InS, TextEncoding::UTF8);
        if not XmlDocument.ReadFrom(InS, XmlDoc) then
            Error('XML parse failed for peek');

        if not XmlDoc.SelectSingleNode('//header/number', NumberNode) then
            Error('Order-number element not found');

        if not NumberNode.IsXmlElement() then
            Error('Order-number node is not an element');

        OrderNo := CopyStr(NumberNode.AsXmlElement().InnerText, 1, MaxStrLen(OrderNo));
        if OrderNo = '' then
            Error('Order-number element is empty');
    end;

    local procedure OrderHasPickImported(OrderNo: Code[20]): Boolean
    var
        SalesHeader: Record "Sales Header";
    begin
        if OrderNo = '' then
            exit(false);
        if not SalesHeader.Get(SalesHeader."Document Type"::Order, OrderNo) then
            exit(false);
        exit(SalesHeader."Imported Pick Confirmation");
    end;

    local procedure OrderExistsButPickNotImported(OrderNo: Code[20]): Boolean
    var
        SalesHeader: Record "Sales Header";
    begin
        if OrderNo = '' then
            exit(false);
        if not SalesHeader.Get(SalesHeader."Document Type"::Order, OrderNo) then
            exit(false);
        exit(not SalesHeader."Imported Pick Confirmation");
    end;

    local procedure MarkPickAlreadyApplied(FileName: Text; OrderNo: Code[20])
    var
        NewFileName: Text;
    begin
        NewFileName := BuildRenamedFileName(FileName, ImportedSuffixTok);
        if NewFileName <> FileName then
            if not RenameFile('3PL', Setup."SharePoint Import Folder", FileName, NewFileName) then
                LogMoveFailure(FileName, Graph.GetLastError());

        LogPickSkippedAlreadyApplied(FileName, NewFileName, OrderNo);
        ArchiveLog(
            true,
            "3PL Log Direction"::Import,
            OrderNo,
            '',
            NewFileName,
            Setup,
            "3PL Archive Step"::ImportConfirmation,
            StrSubstNo('Skipped: order %1 already has pick imported', OrderNo),
            Setup."SharePoint Import Folder"
        );
    end;

    procedure ImportSpecificPickedFile(FileName: Text): Boolean
    begin
        exit(TryImportPickFile(FileName));
    end;

    // OBSOLETE / UNUSED
    procedure ImportSpecificShippedFile(FileName: Text): Boolean
    begin
        exit(TryImportShipFile(FileName));
    end;

    [TryFunction]
    local procedure ImportConfirmationFromSharePoint_Try(FileName: Text; ConfType: Enum "3PL Import Type")
    var
        InnerErr: Text;
    begin
        if not ImportConfirmationFromSharePoint(FileName, ConfType) then begin
            InnerErr := GetLastErrorText();
            if InnerErr = '' then
                InnerErr := 'XMLport import returned failure with no error details.';
            Error(InnerErr);
        end;
    end;

    local procedure ImportConfirmationFromSharePoint(FileName: Text; ConfType: Enum "3PL Import Type"): Boolean
    var
        XmlPortId: Integer;
    begin
        if not Setup.Get('3PL') then
            Error('3PL SharePoint setup not configured');

        case ConfType of
            ConfType::Pick:
                XmlPortId := Setup."Import Pick Xmlport ID";
            ConfType::Ship:
                XmlPortId := Setup."Import Ship Xmlport ID";
        end;
        if XmlPortId = 0 then
            Error('Import XMLport ID for %1 is not configured in Setup.', ConfType);

        exit(ImportFileWithXmlPortId(FileName, XmlPortId));
    end;

    local procedure CheckSetup(): Boolean
    var
        Dims: Dictionary of [Text, Text];
    begin
        if not Setup.Get('3PL') then begin
            Dims.Add('reason', 'setup_not_found');
            Session.LogMessage('3PL-SETUP', '3PL SharePoint Setup not found',
                Verbosity::Error, DataClassification::SystemMetadata,
                TelemetryScope::ExtensionPublisher, Dims);
            exit(false);
        end;
        exit(true);
    end;

    local procedure TryGetSalesHeaderFromRecordId(RecordId: RecordId; var SalesHeader: Record "Sales Header"): Boolean
    var
        RecordRef: RecordRef;
        Dims: Dictionary of [Text, Text];
    begin
        if not RecordRef.Get(RecordId) then begin
            Dims.Add('recordId', CopyStr(Format(RecordId), 1, 100));
            Session.LogMessage('3PL-RECORD-NOTFOUND', 'RecordID not found during export selection',
                Verbosity::Warning, DataClassification::SystemMetadata,
                TelemetryScope::ExtensionPublisher, Dims);
            exit(false);
        end;

        RecordRef.SetTable(SalesHeader);
        exit(true);
    end;

    local procedure ValidateExportPreconditions(var SalesHeader: Record "Sales Header"; IsCODExport: Boolean; var Err: Text): Boolean
    begin
        if not Setup.Get('3PL') then begin
            Err := '3PL SharePoint Setup not found';
            exit(false);
        end;

        if SalesHeader."Document Type" <> SalesHeader."Document Type"::Order then begin
            Err := StrSubstNo('Only Sales Orders can be exported. Current: %1 %2',
                Format(SalesHeader."Document Type"), SalesHeader."No.");
            exit(false);
        end;

        if SalesHeader.Status <> SalesHeader.Status::Released then begin
            Err := StrSubstNo('Order %1 must be Released before export (current: %2)',
                SalesHeader."No.", Format(SalesHeader.Status));
            exit(false);
        end;

        if SalesHeader."Location Code" <> Setup."Location Code" then begin
            Err := StrSubstNo('Order %1 location "%2" does not match setup "%3"',
                SalesHeader."No.", SalesHeader."Location Code", Setup."Location Code");
            exit(false);
        end;

        if Setup."SharePoint Export Folder" = '' then begin
            Err := 'SharePoint Export Folder is not configured';
            exit(false);
        end;

        if IsCODExport and (Setup."Export COD XmlPort Id" = 0) then begin
            Err := 'COD XMLport ID is not configured in Setup';
            exit(false);
        end;

        if (not IsCODExport) and (Setup."Export SO XmlPort Id" = 0) then begin
            Err := 'Sales Order XMLport ID is not configured in Setup';
            exit(false);
        end;

        if not CheckShopifyOrderNotRefunded(SalesHeader, Err) then
            exit(false);

        exit(true);
    end;

    local procedure CheckShopifyOrderNotRefunded(var SalesHeader: Record "Sales Header"; var Err: Text): Boolean
    var
        ShopifyOrder: Record "Shpfy Order Header";
    begin
        ShopifyOrder.SetRange("Sales Order No.", SalesHeader."No.");
        if not ShopifyOrder.FindFirst() then
            exit(true);

        if ShopifyOrder."Financial Status" = ShopifyOrder."Financial Status"::Refunded then begin
            SalesHeader."3PL Skipped" := true;
            SalesHeader.Modify(true);
            Err := StrSubstNo('Order %1 cannot be exported: the linked Shopify order has been fully refunded.', SalesHeader."No.");
            exit(false);
        end;

        exit(true);
    end;

    local procedure PrepareSingleRecordView(var SourceSalesHeader: Record "Sales Header"; var TargetSalesHeader: Record "Sales Header"; var Err: Text): Boolean
    begin
        TargetSalesHeader.Reset();
        TargetSalesHeader.SetRange("Document Type", SourceSalesHeader."Document Type");
        TargetSalesHeader.SetRange("No.", SourceSalesHeader."No.");

        if not TargetSalesHeader.FindFirst() then begin
            Err := StrSubstNo('Sales order %1 no longer exists', SourceSalesHeader."No.");
            exit(false);
        end;

        exit(true);
    end;

    local procedure RunExport(XmlId: Integer; var SalesHeader: Record "Sales Header"; OutS: OutStream; IsCODExport: Boolean): Boolean
    var
        ExportOrderXmlPort: XmlPort "Export Orders to 3PL";
        ExportCODXmlPort: XmlPort "Export COD Total to 3PL";
    begin
        if (not IsCODExport) and (XmlId = XMLport::"Export Orders to 3PL") then begin
            ExportOrderXmlPort.SetTableView(SalesHeader);
            ExportOrderXmlPort.SetDestination(OutS);
            ExportOrderXmlPort.Export();
        end else
            if IsCODExport and (XmlId = XMLport::"Export COD Total to 3PL") then begin
                ExportCODXmlPort.SetTableView(SalesHeader);
                ExportCODXmlPort.SetDestination(OutS);
                ExportCODXmlPort.Export();
            end else begin
                XMLPORT.EXPORT(XmlId, OutS, SalesHeader);
            end;

        exit(true);
    end;

    local procedure UpdateOrderExportStatus(var SalesHeader: Record "Sales Header"; IsCODExport: Boolean)
    begin
        if IsCODExport then begin
            SalesHeader."3PL COD Exported" := true;
            SalesHeader."3PL Export Date" := Today;
        end else begin
            SalesHeader."3PL Order Exported" := true;
            SalesHeader."3PL Exported" := true;
            SalesHeader."3PL Export Date" := Today;
        end;

        if not SalesHeader.Modify(true) then
            Error('Failed to update Sales Header export status for order %1', SalesHeader."No.");
    end;

    local procedure ImportFileWithXmlPortId(FileName: Text; XmlPortId: Integer): Boolean
    var
        TempBlob: Codeunit "Temp Blob";
        InS: InStream;
        OutS: OutStream;
    begin
        if XmlPortId = 0 then
            exit(false);

        TempBlob.CreateOutStream(OutS);
        if not Graph.DownloadFile('3PL', Setup."SharePoint Import Folder", FileName, OutS) then
            exit(false);

        TempBlob.CreateInStream(InS, TextEncoding::UTF8);
        exit(RunXmlPortImport_Try(XmlPortId, InS));
    end;

    [TryFunction]
    local procedure RunXmlPortImport_Try(XmlPortId: Integer; InS: InStream)
    begin
        XMLPORT.IMPORT(XmlPortId, InS);
    end;

    local procedure TryImportConfirmation(FileName: Text; ConfType: Enum "3PL Import Type"): Boolean
    var
        Success: Boolean;
        ErrorMessage: Text;
        NewFileName: Text;
        LabelTxt: Text;
    begin
        if not Setup.Get('3PL') then
            exit(false);

        case ConfType of
            ConfType::Pick:
                LabelTxt := 'Pick';
            ConfType::Ship:
                LabelTxt := 'Ship';
        end;
        ClearLastError();
        Success := ImportConfirmationFromSharePoint_Try(FileName, ConfType);
        if not Success then
            ErrorMessage := GetLastErrorText();

        if Success then
            NewFileName := BuildRenamedFileName(FileName, ImportedSuffixTok)
        else
            NewFileName := BuildRenamedFileName(FileName, '_error');

        if NewFileName <> FileName then
            if not RenameFile('3PL', Setup."SharePoint Import Folder", FileName, NewFileName) then
                LogMoveFailure(FileName, Graph.GetLastError());

        if not Success then
            MoveToErrorFolder(NewFileName);

        if Success then
            LogFileImported(FileName, NewFileName, LabelTxt)
        else
            LogFileImportFailed(FileName, NewFileName, ErrorMessage, LabelTxt);

        ArchiveLog(
            Success,
            "3PL Log Direction"::Import,
            '',
            '',
            NewFileName,
            Setup,
            "3PL Archive Step"::ImportConfirmation,
            ErrorMessage,
            Setup."SharePoint Import Folder"
        );

        exit(Success);
    end;


    local procedure IsPickFile(FileName: Text): Boolean
    var
        NameLower: Text;
        NameLen: Integer;
        DotXmlPos: Integer;
        HasGenericPrefix: Boolean;
        HasPickPrefix: Boolean;
        Suffixes: List of [Text];
        Token: Text;
    begin
        if IsAlreadyProcessed(FileName) then
            exit(false);
        if not EndsWithXml(FileName) then
            exit(false);

        NameLower := LowerCase(FileName);
        NameLen := StrLen(NameLower);

        DotXmlPos := StrPos(NameLower, '.xml');
        if DotXmlPos <> (NameLen - 3) then
            exit(false);

        if not Setup.Get('3PL') then begin
            Suffixes := ParseSuffixTokens('');
            foreach Token in Suffixes do
                if (StrPos(NameLower, Token) > 0) and (StrPos(NameLower, Token) < DotXmlPos) then
                    exit(true);
            exit(false);
        end;

        HasGenericPrefix := true;
        if Setup."Import File Prefix" <> '' then
            HasGenericPrefix := StartsWithIgnoreCase(FileName, Setup."Import File Prefix");

        if HasGenericPrefix then begin
            Suffixes := ParseSuffixTokens(Setup."Import File Suffix");
            foreach Token in Suffixes do
                if (StrPos(NameLower, Token) > 0) and (StrPos(NameLower, Token) < DotXmlPos) then
                    exit(true);
        end;

        HasPickPrefix := (Setup."Import Pick File Prefix" <> '') and
                         StartsWithIgnoreCase(FileName, Setup."Import Pick File Prefix");

        if HasPickPrefix then begin
            if Setup."Import Pick File Suffix" = '' then
                exit(true);
            Suffixes := ParseSuffixTokens(Setup."Import Pick File Suffix");
            foreach Token in Suffixes do
                if (StrPos(NameLower, Token) > 0) and (StrPos(NameLower, Token) < DotXmlPos) then
                    exit(true);
        end;

        exit(false);
    end;

    local procedure IsShipFile(FileName: Text): Boolean
    var
        NameLower: Text;
        NameLen: Integer;
        DotXmlPos: Integer;
        HasShipPrefix: Boolean;
        PrefixConfigured: Boolean;
        Suffixes: List of [Text];
        Token: Text;
    begin
        if IsAlreadyProcessed(FileName) then
            exit(false);
        if not EndsWithXml(FileName) then
            exit(false);

        NameLower := LowerCase(FileName);
        NameLen := StrLen(NameLower);

        DotXmlPos := StrPos(NameLower, '.xml');
        if DotXmlPos <> (NameLen - 3) then
            exit(false);

        if not Setup.Get('3PL') then
            exit(false);

        // Mirror IsPickFile: a configured prefix must match; an empty prefix is tolerated
        // and detection falls back to the suffix tokens. This supports regions (e.g. EU)
        // that identify ship files by suffix only ("_shipped") with no prefix configured.
        PrefixConfigured := Setup."Import Ship File Prefix" <> '';
        HasShipPrefix := true;
        if PrefixConfigured then
            HasShipPrefix := StartsWithIgnoreCase(FileName, Setup."Import Ship File Prefix");
        if not HasShipPrefix then
            exit(false);

        if Setup."Import Ship File Suffix" = '' then
            // Prefix-only gating: match when a prefix was configured and matched.
            // If neither prefix nor suffix is configured, do not match (avoids matching everything).
            exit(PrefixConfigured);

        Suffixes := ParseSuffixTokens(Setup."Import Ship File Suffix");
        foreach Token in Suffixes do
            if (StrPos(NameLower, Token) > 0) and (StrPos(NameLower, Token) < DotXmlPos) then
                exit(true);

        exit(false);
    end;

    local procedure TryImportPickFile(FileName: Text): Boolean
    var
        TempBlob: Codeunit "Temp Blob";
        InStr: InStream;
        OutStr: OutStream;
        NewFileName: Text;
        ArchiveStep: Enum "3PL Archive Step";
        CustomDimensions: Dictionary of [Text, Text];
    begin
        if not Setup.Get('3PL') then
            exit(false);

        TempBlob.CreateOutStream(OutStr);
        if not Graph.DownloadFile('3PL', Setup."SharePoint Import Folder", FileName, OutStr) then begin
            CustomDimensions.Add('fileName', FileName);
            CustomDimensions.Add('error', Graph.GetLastError());
            Session.LogMessage('0000DLP', 'Pick file download failed',
                             Verbosity::Error, DataClassification::SystemMetadata,
                             TelemetryScope::ExtensionPublisher, CustomDimensions);
            exit(false);
        end;

        TempBlob.CreateInStream(InStr);
        if not RunXmlPortImport_Try(Setup."Import Pick XmlPort Id", InStr) then begin
            NewFileName := BuildRenamedFileName(FileName, '_error');
            if RenameFile('3PL', Setup."SharePoint Import Folder", FileName, NewFileName) then
                ArchiveLog(false, "3PL Log Direction"::Import, '', '', NewFileName,
                         Setup, ArchiveStep::ImportConfirmation, GetLastErrorText(),
                         Setup."SharePoint Import Folder");
            exit(false);
        end;

        NewFileName := BuildProcessedFileName(FileName);
        if not RenameFile('3PL', Setup."SharePoint Import Folder", FileName, NewFileName) then begin
            CustomDimensions.Add('fileName', FileName);
            CustomDimensions.Add('error', Graph.GetLastError());
            Session.LogMessage('0000DLP', 'Pick file download failed',
                             Verbosity::Error, DataClassification::SystemMetadata,
                             TelemetryScope::ExtensionPublisher, CustomDimensions);
        end;
        ArchiveLog(true, "3PL Log Direction"::Import, '', '', NewFileName,
                  Setup, ArchiveStep::ImportConfirmation, '',
                  Setup."SharePoint Archive Folder");

        exit(true);
    end;

    // OBSOLETE / UNUSED 
    local procedure TryImportShipFile(FileName: Text): Boolean
    var
        TempBlob: Codeunit "Temp Blob";
        InStr: InStream;
        OutStr: OutStream;
        NewFileName: Text;
        ArchiveStep: Enum "3PL Archive Step";
        CustomDimensions: Dictionary of [Text, Text];
    begin
        if not Setup.Get('3PL') then
            exit(false);

        TempBlob.CreateOutStream(OutStr);
        if not Graph.DownloadFile('3PL', Setup."SharePoint Import Folder", FileName, OutStr) then begin
            CustomDimensions.Add('fileName', FileName);
            CustomDimensions.Add('error', Graph.GetLastError());
            Session.LogMessage('0000DLP', 'Ship file download failed',
                             Verbosity::Error, DataClassification::SystemMetadata,
                             TelemetryScope::ExtensionPublisher, CustomDimensions);
            exit(false);
        end;

        TempBlob.CreateInStream(InStr);
        if not RunXmlPortImport_Try(Setup."Import Ship XmlPort Id", InStr) then begin
            NewFileName := BuildRenamedFileName(FileName, '_error');
            if RenameFile('3PL', Setup."SharePoint Import Folder", FileName, NewFileName) then
                ArchiveLog(false, "3PL Log Direction"::Import, '', '', NewFileName,
                         Setup, ArchiveStep::ImportConfirmation, GetLastErrorText(),
                         Setup."SharePoint Import Folder");
            exit(false);
        end;

        NewFileName := BuildProcessedFileName(FileName);
        if not RenameFile('3PL', Setup."SharePoint Import Folder", FileName, NewFileName) then begin
            CustomDimensions.Add('fileName', FileName);
            CustomDimensions.Add('error', Graph.GetLastError());
            Session.LogMessage('0000DLP', 'Ship file download failed',
                             Verbosity::Error, DataClassification::SystemMetadata,
                             TelemetryScope::ExtensionPublisher, CustomDimensions);
        end;
        ArchiveLog(true, "3PL Log Direction"::Import, '', '', NewFileName,
                  Setup, ArchiveStep::ImportConfirmation, '',
                  Setup."SharePoint Archive Folder");

        exit(true);
    end;

    local procedure FirstFileForOrder(OrderNo: Code[20]; ConfType: Enum "3PL Import Type"; var MatchedName: Text): Boolean
    var
        FileList: List of [Text];
        Name: Text;
        OrderLower: Text;
        IsMatch: Boolean;
    begin
        if not Setup.Get('3PL') then
            Error('3PL SharePoint setup not configured');

        FileList := Graph.ListFilesInFolder('3PL', Setup."SharePoint Import Folder");
        OrderLower := LowerCase(OrderNo);

        foreach Name in FileList do begin
            IsMatch := false;
            if StrPos(LowerCase(Name), OrderLower) > 0 then
                case ConfType of
                    ConfType::Pick:
                        IsMatch := IsPickFile(Name);
                    ConfType::Ship:
                        IsMatch := IsShipFile(Name);
                end;
            if IsMatch then begin
                MatchedName := Name;
                exit(true);
            end;
        end;
        exit(false);
    end;

    local procedure ValidateFileName(FileName: Text; FileType: Text): Boolean
    begin
        if FileName = '' then begin
            Error('File name is required.');
            exit(false);
        end;

        case FileType of
            'pick':
                if not IsPickFile(FileName) then begin
                    Error('Invalid pick file name. It must contain ''pick'' or ''picked'' and end with ''.xml''.');
                    exit(false);
                end;
            'ship':
                if not IsShipFile(FileName) then begin
                    Error('Invalid shipment file name. It must contain ''_ship'' and end with ''.xml''.');
                    exit(false);
                end;
        end;

        exit(true);
    end;

    local procedure EndsWithXml(FileName: Text): Boolean
    var
        L: Integer;
        Tail: Text;
    begin
        L := StrLen(FileName);
        if L < 4 then
            exit(false);
        Tail := LowerCase(CopyStr(FileName, L - 3));
        exit(Tail = '.xml');
    end;

    local procedure IsAlreadyProcessed(FileName: Text): Boolean
    var
        BaseLower: Text;
        L: Integer;
    begin
        if not EndsWithXml(FileName) then
            exit(false);
        L := StrLen(FileName);
        BaseLower := LowerCase(CopyStr(FileName, 1, L - 4));
        exit(StrEndsWith(BaseLower, ImportedSuffixTok) or StrEndsWith(BaseLower, '_error'));
    end;

    local procedure StartsWithIgnoreCase(Value: Text; Prefix: Text): Boolean
    var
        V: Text;
        P: Text;
        LP: Integer;
    begin
        V := LowerCase(Value);
        P := LowerCase(Prefix);
        LP := StrLen(P);
        if StrLen(V) < LP then
            exit(false);
        exit(CopyStr(V, 1, LP) = P);
    end;

    local procedure RemoveStatusSuffix(FileName: Text): Text
    var
        BaseName: Text;
        SuffixPatterns: List of [Text];
        Pattern: Text;
    begin
        if not EndsWithXml(FileName) then
            exit(FileName);

        BaseName := CopyStr(FileName, 1, StrLen(FileName) - 4);

        SuffixPatterns.Add('_picked');
        SuffixPatterns.Add('_pick');
        SuffixPatterns.Add('_shipped');
        SuffixPatterns.Add('_ship');

        foreach Pattern in SuffixPatterns do
            if StrEndsWith(BaseName, Pattern) then
                exit(CopyStr(BaseName, 1, StrLen(BaseName) - StrLen(Pattern)) + '.xml');

        exit(FileName);
    end;

    local procedure StrEndsWith(Value: Text; Suffix: Text): Boolean
    begin
        if StrLen(Suffix) > StrLen(Value) then
            exit(false);
        exit(CopyStr(Value, StrLen(Value) - StrLen(Suffix) + 1) = Suffix);
    end;

    procedure RenameFile(SetupKey: Code[10]; FolderPath: Text; OldName: Text; NewName: Text): Boolean
    var
        SharePointSetup: Record "SharePoint Setup";
        Client: HttpClient;
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        ReqHeaders: HttpHeaders;
        ContentHeaders: HttpHeaders;
        Body: JsonObject;
        BodyText: Text;
        Url: Text;
        EncodedPath: Text;
        RespTxt: Text;
    begin
        if not SharePointSetup.Get(SetupKey) then
            exit(false);

        if (OldName = '') or (NewName = '') then
            exit(false);

        if SharePointSetup."SharePoint Library Id" = '' then
            exit(false);

        FolderPath := FolderPath.Replace('\', '/');
        FolderPath := DelChr(FolderPath, '<>', '/');

        EncodedPath := FolderPath.Replace(' ', '%20') + '/' + OldName.Replace(' ', '%20');

        Url := StrSubstNo(
            'https://graph.microsoft.com/v1.0/drives/%1/root:/%2:',
            SharePointSetup."SharePoint Library Id",
            EncodedPath
        );

        Body.Add('name', NewName);
        Body.WriteTo(BodyText);

        Request.Method := 'PATCH';
        Request.SetRequestUri(Url);

        Request.GetHeaders(ReqHeaders);
        ReqHeaders.Add('Authorization', StrSubstNo('Bearer %1', Graph.GetAccessToken(SetupKey)));
        ReqHeaders.Add('Accept', 'application/json');

        Request.Content().WriteFrom(BodyText);
        Request.Content().GetHeaders(ContentHeaders);
        if ContentHeaders.Contains('Content-Type') then
            ContentHeaders.Remove('Content-Type');
        ContentHeaders.Add('Content-Type', 'application/json');

        if not Client.Send(Request, Response) then
            exit(false);

        Response.Content().ReadAs(RespTxt);

        if not Response.IsSuccessStatusCode() then
            exit(false);

        exit(true);
    end;

    local procedure MoveToErrorFolder(FileName: Text)
    begin
        if not Setup."Move Failed Files To Error Folder" then
            exit;
        if Setup."SharePoint Error Folder" = '' then
            exit;
        if not Graph.MoveFile('3PL', Setup."SharePoint Import Folder", FileName, Setup."SharePoint Error Folder") then
            LogMoveFailure(FileName, Graph.GetLastError());
    end;

    local procedure BuildProcessedFileName(OriginalName: Text): Text
    begin
        exit(BuildRenamedFileName(OriginalName, ImportedSuffixTok));
    end;

    local procedure BuildRenamedFileName(OriginalName: Text; Suffix: Text): Text
    begin
        if not EndsWithXml(OriginalName) then
            exit(OriginalName + Suffix);
        exit(CopyStr(OriginalName, 1, StrLen(OriginalName) - 4) + Suffix + '.xml');
    end;

    // OBSOLETE / UNUSED — only called by FindPickFileForOrder / FindShipFileForOrder, both also unused.
    local procedure FindFileForOrder(OrderNo: Code[20]; SuffixCfg: Text; var FileName: Text): Boolean
    var
        FileList: List of [Text];
        Name: Text;
        PrefixCfg: Text;
        SearchPrefix: Text;
        LowerName: Text;
        LowerPrefix: Text;
        NameLen: Integer;
        DotXmlPos: Integer;
        ExactFileName: Text;
        Suffixes: List of [Text];
        Suffix: Text;
    begin
        if not Setup.Get('3PL') then
            exit(false);

        Suffixes := ParseSuffixTokens(SuffixCfg);

        foreach Suffix in Suffixes do begin
            ExactFileName := BuildExpectedFileName(OrderNo, Suffix);
            if Graph.FileExistsInSharePoint(Setup."SharePoint Import Folder", ExactFileName) then begin
                FileName := ExactFileName;
                exit(true);
            end;
        end;

        PrefixCfg := Setup."Import File Prefix";
        SearchPrefix := PrefixCfg + OrderNo + '_';
        LowerPrefix := LowerCase(SearchPrefix);

        FileList := Graph.ListFilesInFolder('3PL', Setup."SharePoint Import Folder");
        foreach Name in FileList do begin
            LowerName := LowerCase(Name);
            NameLen := StrLen(LowerName);

            if NameLen < 5 then
                continue;
            DotXmlPos := StrPos(LowerName, '.xml');
            if DotXmlPos <> (NameLen - 3) then
                continue;

            if (LowerPrefix <> '') and (CopyStr(LowerName, 1, StrLen(LowerPrefix)) <> LowerPrefix) then
                continue;

            foreach Suffix in Suffixes do
                if (StrPos(LowerName, Suffix) > 0) and (StrPos(LowerName, Suffix) < DotXmlPos) then begin
                    FileName := Name;
                    exit(true);
                end;
        end;

        exit(false);
    end;

    // OBSOLETE / UNUSED — no callers in this repo.
    local procedure MakeRenamedName(OldName: Text; IsPick: Boolean): Text
    var
        L: Integer;
        Stem: Text;
        Ext: Text;
    begin
        L := StrLen(OldName);
        if (L < 5) or (LowerCase(CopyStr(OldName, L - 3)) <> '.xml') then
            exit(OldName);

        Stem := CopyStr(OldName, 1, L - 4);
        Ext := CopyStr(OldName, L - 3);

        if IsPick then begin
            Stem := ReplaceInsensitive(Stem, '_picked', '');
            Stem := ReplaceInsensitive(Stem, '_pick', '');
            Stem := ReplaceInsensitive(Stem, '_packed', '');
            Stem := ReplaceInsensitive(Stem, '-picked', '');
            Stem := ReplaceInsensitive(Stem, '-pick', '');
            Stem := ReplaceInsensitive(Stem, '-packed', '');
        end else begin
            Stem := ReplaceInsensitive(Stem, '_shipped', '');
            Stem := ReplaceInsensitive(Stem, '_ship', '');
            Stem := ReplaceInsensitive(Stem, '-shipped', '');
            Stem := ReplaceInsensitive(Stem, '-ship', '');
        end;

        Stem := ReplaceInsensitive(Stem, '__', '_');
        Stem := ReplaceInsensitive(Stem, '--', '-');

        exit(Stem + Ext);
    end;

    // OBSOLETE / UNUSED — only called by MakeRenamedName, which is also unused.
    local procedure ReplaceInsensitive(S: Text; FindTxt: Text; ReplaceTxt: Text): Text
    var
        SL: Text;
        FL: Text;
        Pos: Integer;
        LeftPart: Text;
        RightPart: Text;
    begin
        if (FindTxt = '') then
            exit(S);

        SL := LowerCase(S);
        FL := LowerCase(FindTxt);

        Pos := StrPos(SL, FL);
        while Pos > 0 do begin
            LeftPart := CopyStr(S, 1, Pos - 1);
            RightPart := CopyStr(S, Pos + StrLen(FindTxt));
            S := LeftPart + ReplaceTxt + RightPart;

            SL := LowerCase(S);
            Pos := StrPos(SL, FL);
        end;

        exit(S);
    end;

    local procedure ParseSuffixTokens(SuffixCfg: Text): List of [Text]
    var
        Tokens: List of [Text];
        Work: Text;
        Part: Text;
        CommaPos: Integer;
    begin
        Work := LowerCase(DelChr(SuffixCfg, '=', ' '));

        if Work = '' then begin
            Tokens.Add('pick');
            Tokens.Add('picked');
            Tokens.Add('packed');
            exit(Tokens);
        end;

        repeat
            CommaPos := StrPos(Work, ',');
            if CommaPos = 0 then begin
                Part := Work;
                Work := '';
            end else begin
                Part := CopyStr(Work, 1, CommaPos - 1);
                Work := CopyStr(Work, CommaPos + 1);
            end;
            Part := LowerCase(DelChr(Part, '=', ' '));
            if Part <> '' then
                Tokens.Add(Part);
        until Work = '';

        exit(Tokens);
    end;

    // OBSOLETE / UNUSED 
    local procedure FindPickFileForOrder(OrderNo: Code[20]; var FileName: Text): Boolean
    begin
        exit(FindFileForOrder(OrderNo, Setup."Import File Suffix", FileName));
    end;

    // OBSOLETE / UNUSED 
    local procedure FindShipFileForOrder(OrderNo: Code[20]; var FileName: Text): Boolean
    begin
        exit(FindFileForOrder(OrderNo, Setup."Import Ship File Suffix", FileName));
    end;

    // OBSOLETE / UNUSED 
    local procedure BuildExpectedFileName(OrderNo: Code[20]; FileType: Text): Text
    begin
        if not Setup.Get('3PL') then
            Error('SharePoint setup not configured');

        case FileType of
            'pick':
                exit(Setup."Import Pick File Prefix" + OrderNo + Setup."Import Pick File Suffix" + '.xml');
            'ship':
                exit(Setup."Import File Prefix" + OrderNo + '_ship' + Setup."Import Ship File Suffix" + '.xml');
            else
                Error('Unknown file type: %1', FileType);
        end;
    end;

    local procedure LogExportSkipped(OrderNo: Code[20]; Reason: Text)
    var
        Dims: Dictionary of [Text, Text];
    begin
        Clear(Dims);
        Dims.Add('orderNo', OrderNo);
        Dims.Add('reason', CopyStr(Reason, 1, 200));
        Session.LogMessage('3PL-EXPORT-SKIP', 'Export skipped',
            Verbosity::Normal, DataClassification::SystemMetadata,
            TelemetryScope::ExtensionPublisher, Dims);
    end;

    local procedure LogRecordNotFound(OrderNo: Code[20]; var ErrorCount: Integer)
    var
        Dims: Dictionary of [Text, Text];
    begin
        ErrorCount += 1;
        Clear(Dims);
        Dims.Add('orderNo', OrderNo);
        Session.LogMessage('3PL-RECORD-NOTFOUND', 'Order not found during export selection',
            Verbosity::Warning, DataClassification::SystemMetadata,
            TelemetryScope::ExtensionPublisher, Dims);
    end;

    local procedure LogExportSuccess(OrderNo: Code[20]; var SuccessCount: Integer)
    var
        Dims: Dictionary of [Text, Text];
    begin
        SuccessCount += 1;
        Clear(Dims);
        Dims.Add('orderNo', OrderNo);
        Session.LogMessage('3PL-EXPORT-OK', 'Order exported to SharePoint',
            Verbosity::Normal, DataClassification::SystemMetadata,
            TelemetryScope::ExtensionPublisher, Dims);
    end;

    local procedure LogExportSuccess(OrderNo: Code[20]; IsCOD: Boolean)
    var
        Dims: Dictionary of [Text, Text];
    begin
        Clear(Dims);
        Dims.Add('orderNo', OrderNo);
        if IsCOD then Dims.Add('mode', 'COD') else Dims.Add('mode', 'SO');
        Session.LogMessage('3PL-EXPORT-OK', 'Order exported to SharePoint',
            Verbosity::Normal, DataClassification::SystemMetadata,
            TelemetryScope::ExtensionPublisher, Dims);
    end;

    local procedure LogExportFailure(OrderNo: Code[20]; ErrorMessage: Text; var ErrorCount: Integer)
    var
        Dims: Dictionary of [Text, Text];
    begin
        ErrorCount += 1;
        Clear(Dims);
        Dims.Add('orderNo', OrderNo);
        Dims.Add('error', CopyStr(ErrorMessage, 1, 250));
        Session.LogMessage('3PL-EXPORT-FAIL', 'Export failed',
            Verbosity::Error, DataClassification::SystemMetadata,
            TelemetryScope::ExtensionPublisher, Dims);
    end;

    local procedure LogExportFailure(OrderNo: Code[20]; ErrorMessage: Text)
    var
        Dims: Dictionary of [Text, Text];
    begin
        Clear(Dims);
        Dims.Add('orderNo', OrderNo);
        Dims.Add('error', CopyStr(ErrorMessage, 1, 250));
        Session.LogMessage('3PL-EXPORT-FAIL', 'Export failed',
            Verbosity::Error, DataClassification::SystemMetadata,
            TelemetryScope::ExtensionPublisher, Dims);
    end;

    local procedure LogExportFailure(OrderNo: Code[20]; ErrorMessage: Text; IsCOD: Boolean)
    var
        Dims: Dictionary of [Text, Text];
    begin
        Clear(Dims);
        Dims.Add('orderNo', OrderNo);
        Dims.Add('error', CopyStr(ErrorMessage, 1, 250));
        if IsCOD then Dims.Add('mode', 'COD') else Dims.Add('mode', 'SO');
        Session.LogMessage('3PL-EXPORT-FAIL', 'Export failed',
            Verbosity::Error, DataClassification::SystemMetadata,
            TelemetryScope::ExtensionPublisher, Dims);
    end;

    local procedure LogExportSummary(Total: Integer; Success: Integer; Error: Integer; Context: Text)
    var
        Dims: Dictionary of [Text, Text];
    begin
        Clear(Dims);
        Dims.Add('total', Format(Total));
        Dims.Add('success', Format(Success));
        Dims.Add('failed', Format(Error));
        Dims.Add('context', Context);
        Session.LogMessage('3PL-EXPORT-SUMMARY', 'Batch export summary',
            Verbosity::Normal, DataClassification::SystemMetadata,
            TelemetryScope::ExtensionPublisher, Dims);
    end;

    local procedure LogBatchProcessed(BatchType: Text; ProcessedCount: Integer)
    var
        Dims: Dictionary of [Text, Text];
    begin
        Clear(Dims);
        Dims.Add('processed', Format(ProcessedCount));
        Session.LogMessage('3PL-' + BatchType + '-BATCH', BatchType + ' batch processed',
            Verbosity::Normal, DataClassification::SystemMetadata,
            TelemetryScope::ExtensionPublisher, Dims);
    end;

    local procedure LogFileImported(OriginalName: Text; NewName: Text; FileType: Text)
    var
        Dims: Dictionary of [Text, Text];
    begin
        Clear(Dims);
        Dims.Add('file', CopyStr(OriginalName, 1, 100));
        Dims.Add('newFile', CopyStr(NewName, 1, 100));
        Session.LogMessage('3PL-' + FileType + '-OK', FileType + ' file imported (renamed)',
            Verbosity::Normal, DataClassification::SystemMetadata,
            TelemetryScope::ExtensionPublisher, Dims);
    end;

    local procedure LogFileImportFailed(OriginalName: Text; NewName: Text; ErrorMessage: Text; FileType: Text)
    var
        Dims: Dictionary of [Text, Text];
    begin
        Clear(Dims);
        Dims.Add('file', CopyStr(OriginalName, 1, 100));
        Dims.Add('newFile', CopyStr(NewName, 1, 100));
        if ErrorMessage <> '' then
            Dims.Add('error', CopyStr(ErrorMessage, 1, 250));
        Session.LogMessage('3PL-' + FileType + '-FAIL', FileType + ' file import failed (renamed)',
            Verbosity::Error, DataClassification::SystemMetadata,
            TelemetryScope::ExtensionPublisher, Dims);
    end;

    local procedure LogFileImportFailed(FileName: Text; FileType: Text)
    var
        Dims: Dictionary of [Text, Text];
    begin
        Clear(Dims);
        Dims.Add('file', CopyStr(FileName, 1, 100));
        Session.LogMessage('3PL-' + FileType + '-FAIL', FileType + ' file import failed',
            Verbosity::Warning, DataClassification::SystemMetadata,
            TelemetryScope::ExtensionPublisher, Dims);
    end;

    local procedure LogMoveFailure(FileName: Text; Detail: Text)
    var
        Dims: Dictionary of [Text, Text];
        Msg: Text;
    begin
        Msg := StrSubstNo('Move failed for %1: %2', FileName, CopyStr(Detail, 1, 200));
        Dims.Add('file', CopyStr(FileName, 1, 100));
        if Detail <> '' then
            Dims.Add('error', CopyStr(Detail, 1, 250));

        Session.LogMessage('3PL-MOVE-FAIL', Msg,
            Verbosity::Warning, DataClassification::SystemMetadata,
            TelemetryScope::ExtensionPublisher, Dims);
    end;

    local procedure LogProcessAllSummary(Total: Integer; Picks: Integer; Shipments: Integer; Returns: Integer; Other: Integer; AlreadyProcessedSkipped: Integer; PicksSkippedDuplicate: Integer; ShipsDeferredAwaitingPick: Integer)
    var
        Dims: Dictionary of [Text, Text];
    begin
        Clear(Dims);
        Dims.Add('total', Format(Total));
        Dims.Add('picks', Format(Picks));
        Dims.Add('shipments', Format(Shipments));
        Dims.Add('returns', Format(Returns));
        Dims.Add('other', Format(Other));
        Dims.Add('skipped', Format(AlreadyProcessedSkipped));
        Dims.Add('picksSkippedDuplicate', Format(PicksSkippedDuplicate));
        Dims.Add('shipsDeferredAwaitingPick', Format(ShipsDeferredAwaitingPick));
        Session.LogMessage('3PL-PROCESS-ALL', 'ProcessAll completed',
            Verbosity::Normal, DataClassification::SystemMetadata,
            TelemetryScope::ExtensionPublisher, Dims);
    end;

    local procedure LogPickSkippedAlreadyApplied(OriginalName: Text; NewName: Text; OrderNo: Code[20])
    var
        Dims: Dictionary of [Text, Text];
    begin
        Clear(Dims);
        Dims.Add('orderNo', OrderNo);
        Dims.Add('file', CopyStr(OriginalName, 1, 100));
        Dims.Add('newFile', CopyStr(NewName, 1, 100));
        Session.LogMessage('3PL-PICK-DUP', 'Pick confirmation skipped: order already has pick imported',
            Verbosity::Normal, DataClassification::SystemMetadata,
            TelemetryScope::ExtensionPublisher, Dims);
    end;

    local procedure LogShipDeferredAwaitingPick(FileName: Text; OrderNo: Code[20])
    var
        Dims: Dictionary of [Text, Text];
    begin
        Clear(Dims);
        Dims.Add('orderNo', OrderNo);
        Dims.Add('file', CopyStr(FileName, 1, 100));
        Session.LogMessage('3PL-SHIP-DEFERRED', 'Ship confirmation deferred: pick not yet imported for this order',
            Verbosity::Warning, DataClassification::SystemMetadata,
            TelemetryScope::ExtensionPublisher, Dims);
    end;

    local procedure ArchiveLog(Success: Boolean; Direction: Enum "3PL Log Direction"; DocumentNo: Code[20]; ExtDocNo: Code[30]; FileName: Text; Setup: Record "SharePoint Setup"; Step: Enum "3PL Archive Step"; ErrMsg: Text; ArchiveFolder: Text): Boolean
    var
        A: Record "3PL Archive";
        CurrentDT: DateTime;
    begin
        CurrentDT := CurrentDateTime;

        A.Init();
        A."Archive Date/Time" := CurrentDT;
        A."Archive DateTime" := CurrentDT;
        A."Date/Time" := CurrentDT;
        A."Direction" := Direction;
        A."Document No." := DocumentNo;
        A."External Doc No." := ExtDocNo;
        A."File Name" := CopyStr(FileName, 1, MaxStrLen(A."File Name"));

        if Direction = Direction::Import then
            A."Sharepoint Archive Folder" := ArchiveFolder
        else
            A."Sharepoint Archive Folder" := '';

        A."Location Code" := Setup."Location Code";
        A."3PL Code" := Setup."3PL Code";
        A."Step" := Step;
        A."User ID" := UserId();
        A."Integration ID" := CreateGuid();

        if Success then
            A."ResultOption" := A."ResultOption"::Success
        else
            A."ResultOption" := A."ResultOption"::Error;

        A."Error Message" := CopyStr(ErrMsg, 1, MaxStrLen(A."Error Message"));
        exit(A.Insert(true));
    end;

    // =========================================================================
    // SRO (Sales Return Order) Export Functions
    // =========================================================================

    local procedure AlreadySROExported(OrderNo: Code[20]): Boolean
    var
        SalesHeader: Record "Sales Header";
    begin
        if not SalesHeader.Get(SalesHeader."Document Type"::"Return Order", OrderNo) then
            exit(false);
        exit(SalesHeader."3PL SRO Exported");
    end;

    procedure ExportSROToSharePoint(var InSalesHeader: Record "Sales Header"; SkipSharePointUpload: Boolean; var OutBlob: Codeunit "Temp Blob")
    var
        Err: Text;
    begin
        if not CheckSetup() then exit;

        if AlreadySROExported(InSalesHeader."No.") then begin
            LogExportSkipped(InSalesHeader."No.", 'SRO already exported');
            if GuiAllowed then
                Message('Return Order %1 was already exported previously.', InSalesHeader."No.");
            exit;
        end;

        if TryExportSRO(InSalesHeader, OutBlob, Err, SkipSharePointUpload) then begin
            LogSROExportSuccess(InSalesHeader."No.");
            if GuiAllowed and not SkipSharePointUpload then
                Message('Return Order %1 (External Doc. No. %2) has been successfully exported to SharePoint.',
                    InSalesHeader."No.", InSalesHeader."External Document No.");
        end else begin
            LogSROExportFailure(InSalesHeader."No.", Err);
            if GuiAllowed then
                Error('Failed to export Return Order %1: %2', InSalesHeader."No.", Err);
        end;
    end;

    procedure ExportAllSalesReturnOrders(SelectionFilter: Text)
    var
        SalesHeader: Record "Sales Header";
        TempBlob: Codeunit "Temp Blob";
        SuccessCount: Integer;
        ErrorCount: Integer;
        SkippedCount: Integer;
        Err: Text;
    begin
        if not CheckSetup() then exit;

        if SelectionFilter <> '' then begin
            ExportSelectedSROs(SelectionFilter);
            exit;
        end;

        SalesHeader.Reset();
        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::"Return Order");
        SalesHeader.SetRange(Status, SalesHeader.Status::Released);
        if Setup."Location Code" <> '' then
            SalesHeader.SetRange("Location Code", Setup."Location Code");
        SalesHeader.SetRange("3PL SRO Exported", false);

        if SalesHeader.FindSet() then
            repeat
                if TryExportSRO(SalesHeader, TempBlob, Err, false) then begin
                    SuccessCount += 1;
                    LogSROExportSuccess(SalesHeader."No.");
                end else begin
                    if Err = 'SRO already exported' then
                        SkippedCount += 1
                    else begin
                        ErrorCount += 1;
                        LogSROExportFailure(SalesHeader."No.", Err);
                    end;
                end;
            until SalesHeader.Next() = 0;

        LogExportSummary(SuccessCount + ErrorCount + SkippedCount, SuccessCount, ErrorCount, 'all released return orders');
    end;

    procedure ExportSelectedSROs(SelectionFilter: Text)
    var
        SalesHeader: Record "Sales Header";
        SalesHeaderToExport: Record "Sales Header";
        TempBlob: Codeunit "Temp Blob";
        SuccessCount: Integer;
        ErrorCount: Integer;
        Err: Text;
        Dims: Dictionary of [Text, Text];
    begin
        if not Setup.Get('3PL') then begin
            Dims.Add('reason', 'setup_not_found');
            Session.LogMessage('3PL-SETUP', '3PL SharePoint Setup not found', Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, Dims);
            exit;
        end;

        SalesHeader.SetView(SelectionFilter);
        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::"Return Order");

        if SalesHeader.FindSet() then
            repeat
                if not SalesHeaderToExport.Get(SalesHeader."Document Type", SalesHeader."No.") then begin
                    ErrorCount += 1;
                    Clear(Dims);
                    Dims.Add('orderNo', SalesHeader."No.");
                    Session.LogMessage('3PL-RECORD-NOTFOUND', 'Return Order no longer exists', Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, Dims);
                    continue;
                end;
                if TryExportSRO(SalesHeaderToExport, TempBlob, Err, false) then begin
                    SuccessCount += 1;
                    LogSROExportSuccess(SalesHeaderToExport."No.");
                end else begin
                    ErrorCount += 1;
                    LogSROExportFailure(SalesHeaderToExport."No.", Err);
                end;
            until SalesHeader.Next() = 0;

        Clear(Dims);
        Dims.Add('success', Format(SuccessCount));
        Dims.Add('failed', Format(ErrorCount));
        Session.LogMessage('3PL-SRO-EXPORT-SUMMARY', 'SRO batch export summary', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, Dims);
    end;

    procedure ResetSROExportStatus(OrderNo: Code[20])
    var
        SalesHeader: Record "Sales Header";
        ThreePLArchive: Record "3PL Archive";
        Dims: Dictionary of [Text, Text];
    begin
        if not SalesHeader.Get(SalesHeader."Document Type"::"Return Order", OrderNo) then begin
            Clear(Dims);
            Dims.Add('orderNo', OrderNo);
            Session.LogMessage('3PL-SRO-RESET-NOTFOUND', 'Return Order not found for reset',
                Verbosity::Warning, DataClassification::SystemMetadata,
                TelemetryScope::ExtensionPublisher, Dims);
            exit;
        end;

        SalesHeader."3PL SRO Exported" := false;
        SalesHeader."3PL SRO Export Date" := 0D;
        SalesHeader."3PL SRO Reception No." := '';
        SalesHeader.Modify(true);

        ThreePLArchive.SetRange("Document No.", OrderNo);
        ThreePLArchive.SetRange("Direction", ThreePLArchive."Direction"::Export);
        ThreePLArchive.SetRange("Step", ThreePLArchive."Step"::ExportReturnOrder);
        ThreePLArchive.DeleteAll();

        Clear(Dims);
        Dims.Add('orderNo', OrderNo);
        Session.LogMessage('3PL-SRO-RESET-STATUS', 'SRO export status reset',
            Verbosity::Normal, DataClassification::SystemMetadata,
            TelemetryScope::ExtensionPublisher, Dims);

        if GuiAllowed then
            Message('Export status reset for Return Order %1. It can now be exported again.', OrderNo);
    end;

    local procedure TryExportSRO(var SalesHeader: Record "Sales Header"; var TempBlob: Codeunit "Temp Blob"; var Err: Text; SkipSharePointUpload: Boolean): Boolean
    var
        OutS: OutStream;
        InS: InStream;
        XmlId: Integer;
        FileName: Text;
        OneOrder: Record "Sales Header";
    begin
        if AlreadySROExported(SalesHeader."No.") then begin
            Err := 'SRO already exported';
            exit(false);
        end;

        if not ValidateSROExportPreconditions(SalesHeader, Err) then
            exit(false);

        XmlId := Setup."Export SRO Xmlport ID";
        FileName := SalesHeader."No." + '_return.xml';

        if not PrepareSingleSROView(SalesHeader, OneOrder, Err) then
            exit(false);

        Clear(TempBlob);
        TempBlob.CreateOutStream(OutS);

        if not RunSROExport(XmlId, OneOrder, OutS) then begin
            Err := 'SRO export failed';
            exit(false);
        end;

        if not SkipSharePointUpload then begin
            TempBlob.CreateInStream(InS);
            if not Graph.UploadFile('3PL', Setup."SharePoint Export Folder", FileName, InS) then begin
                Err := Graph.GetLastError();
                exit(false);
            end;
        end;

        UpdateSROExportStatus(SalesHeader);

        // Critical: commit flag update before slow archive logging.
        Commit();

        ArchiveLog(true, "3PL Log Direction"::Export, SalesHeader."No.",
            SalesHeader."External Document No.", FileName, Setup,
            "3PL Archive Step"::ExportReturnOrder, '', '');

        exit(true);
    end;

    local procedure ValidateSROExportPreconditions(var SalesHeader: Record "Sales Header"; var Err: Text): Boolean
    begin
        if not Setup.Get('3PL') then begin
            Err := '3PL SharePoint Setup not found';
            exit(false);
        end;

        if SalesHeader."Document Type" <> SalesHeader."Document Type"::"Return Order" then begin
            Err := StrSubstNo('Only Sales Return Orders can be SRO-exported. Current: %1 %2',
                Format(SalesHeader."Document Type"), SalesHeader."No.");
            exit(false);
        end;

        if SalesHeader.Status <> SalesHeader.Status::Released then begin
            Err := StrSubstNo('Return Order %1 must be Released before export (current: %2)',
                SalesHeader."No.", Format(SalesHeader.Status));
            exit(false);
        end;

        if SalesHeader."Location Code" <> Setup."Location Code" then begin
            Err := StrSubstNo('Return Order %1 location "%2" does not match setup "%3"',
                SalesHeader."No.", SalesHeader."Location Code", Setup."Location Code");
            exit(false);
        end;

        if Setup."SharePoint Export Folder" = '' then begin
            Err := 'SharePoint Export Folder is not configured';
            exit(false);
        end;

        if Setup."Export SRO Xmlport ID" = 0 then begin
            Err := 'Export SRO XMLport ID is not configured in Setup';
            exit(false);
        end;

        exit(true);
    end;

    local procedure PrepareSingleSROView(var SourceSalesHeader: Record "Sales Header"; var TargetSalesHeader: Record "Sales Header"; var Err: Text): Boolean
    begin
        TargetSalesHeader.Reset();
        TargetSalesHeader.SetRange("Document Type", SourceSalesHeader."Document Type");
        TargetSalesHeader.SetRange("No.", SourceSalesHeader."No.");

        if not TargetSalesHeader.FindFirst() then begin
            Err := StrSubstNo('Return Order %1 no longer exists', SourceSalesHeader."No.");
            exit(false);
        end;

        exit(true);
    end;

    local procedure RunSROExport(XmlId: Integer; var SalesHeader: Record "Sales Header"; OutS: OutStream): Boolean
    begin
        if XmlId = 0 then
            exit(false);

        XMLPORT.EXPORT(XmlId, OutS, SalesHeader);
        exit(true);
    end;

    local procedure UpdateSROExportStatus(var SalesHeader: Record "Sales Header")
    begin
        SalesHeader."3PL SRO Exported" := true;
        SalesHeader."3PL SRO Export Date" := Today;

        if not SalesHeader.Modify(true) then
            Error('Failed to update Sales Header export status for Return Order %1', SalesHeader."No.");
    end;

    // =========================================================================
    // SRO Import Functions
    // =========================================================================

    procedure ImportSROConfirmationBatch(): Integer
    var
        FileList: List of [Text];
        FileName: Text;
        CountProcessed: Integer;
        DummyBlob: Codeunit "Temp Blob";
    begin
        if not CheckSetup() then exit(0);

        FileList := Graph.ListFilesInFolder('3PL', Setup."SharePoint Import Folder");

        foreach FileName in FileList do
            if IsSROFile(FileName) then begin
                if not TryImportSROConfirmation(FileName, false, DummyBlob) then
                    LogFileImportFailed(FileName, 'SRO');
                CountProcessed += 1;
            end;

        LogBatchProcessed('SRO', CountProcessed);
        exit(CountProcessed);
    end;

    procedure ImportSROFromStream(var UploadedBlob: Codeunit "Temp Blob"; FileNameHint: Text): Boolean
    begin
        if not CheckSetup() then exit(false);
        exit(TryImportSROConfirmation(FileNameHint, true, UploadedBlob));
    end;

    procedure ImportSROForOrder(ReturnOrderNo: Code[20]): Boolean
    var
        SROFileName: Text;
        DummyBlob: Codeunit "Temp Blob";
    begin
        if not FirstSROFileForOrder(ReturnOrderNo, SROFileName) then
            exit(false);
        exit(TryImportSROConfirmation(SROFileName, false, DummyBlob));
    end;

    local procedure TryImportSROConfirmation(FileName: Text; UseProvidedBlob: Boolean; var ProvidedBlob: Codeunit "Temp Blob"): Boolean
    var
        Success: Boolean;
        ErrorMessage: Text;
        NewFileName: Text;
        InS: InStream;
    begin
        if not Setup.Get('3PL') then
            exit(false);

        ClearLastError();
        if UseProvidedBlob then begin
            ProvidedBlob.CreateInStream(InS, TextEncoding::UTF8);
            Success := RunXmlPortImport_Try(Setup."Import SRO Xmlport ID", InS);
        end else
            Success := ImportSROConfirmationFromSharePoint_Try(FileName);

        if not Success then
            ErrorMessage := GetLastErrorText();

        if UseProvidedBlob then
            NewFileName := FileName
        else begin
            if Success then
                NewFileName := BuildRenamedFileName(FileName, ImportedSuffixTok)
            else
                NewFileName := BuildRenamedFileName(FileName, '_error');

            if NewFileName <> FileName then
                if not RenameFile('3PL', Setup."SharePoint Import Folder", FileName, NewFileName) then
                    LogMoveFailure(FileName, Graph.GetLastError());
        end;

        if Success then
            LogFileImported(FileName, NewFileName, 'SRO')
        else
            LogFileImportFailed(FileName, NewFileName, ErrorMessage, 'SRO');

        ArchiveLog(
            Success,
            "3PL Log Direction"::Import,
            '',
            '',
            NewFileName,
            Setup,
            "3PL Archive Step"::ImportReturnConfirmation,
            ErrorMessage,
            Setup."SharePoint Import Folder"
        );

        if Success then
            SweepAutoPostSROs();

        exit(Success);
    end;

    [TryFunction]
    local procedure ImportSROConfirmationFromSharePoint_Try(FileName: Text)
    var
        InnerErr: Text;
    begin
        if not ImportSROConfirmationFromSharePoint(FileName) then begin
            InnerErr := GetLastErrorText();
            if InnerErr = '' then
                InnerErr := 'SRO XMLport import returned failure with no error details.';
            Error(InnerErr);
        end;
    end;

    local procedure ImportSROConfirmationFromSharePoint(FileName: Text): Boolean
    var
        SROXmlId: Integer;
    begin
        if not Setup.Get('3PL') then
            Error('3PL SharePoint setup not configured');

        SROXmlId := Setup."Import SRO Xmlport ID";
        if SROXmlId = 0 then
            Error('Import SRO XMLport ID is not configured in Setup.');

        exit(ImportFileWithXmlPortId(FileName, SROXmlId));
    end;

    local procedure IsSROFile(FileName: Text): Boolean
    var
        NameLower: Text;
    begin
        if IsAlreadyProcessed(FileName) then
            exit(false);
        if not EndsWithXml(FileName) then
            exit(false);

        NameLower := LowerCase(FileName);
        exit((StrPos(NameLower, '_returned') > 0) or (StrPos(NameLower, 'rc_return-') > 0));
    end;

    local procedure FirstSROFileForOrder(OrderNo: Code[20]; var MatchedName: Text): Boolean
    var
        FileList: List of [Text];
        Name: Text;
    begin
        if not Setup.Get('3PL') then
            Error('3PL SharePoint setup not configured');

        FileList := Graph.ListFilesInFolder('3PL', Setup."SharePoint Import Folder");
        foreach Name in FileList do
            if MatchesSROPattern(OrderNo, Name) then begin
                MatchedName := Name;
                exit(true);
            end;
        exit(false);
    end;

    local procedure MatchesSROPattern(OrderNo: Code[20]; FileName: Text): Boolean
    var
        NameLower: Text;
        OrderLower: Text;
    begin
        if IsAlreadyProcessed(FileName) then
            exit(false);
        if not EndsWithXml(FileName) then
            exit(false);

        NameLower := LowerCase(FileName);
        OrderLower := LowerCase(OrderNo);

        // EU: RAxxxxxx..._returned.xml. AU: RC_Return-<originalSO>-*.xml.
        exit((StrPos(NameLower, OrderLower) > 0)
            and ((StrPos(NameLower, '_returned') > 0) or (StrPos(NameLower, 'rc_return-') > 0)));
    end;

    local procedure LogSROExportSuccess(OrderNo: Code[20])
    var
        Dims: Dictionary of [Text, Text];
    begin
        Clear(Dims);
        Dims.Add('orderNo', OrderNo);
        Dims.Add('mode', 'SRO');
        Session.LogMessage('3PL-SRO-EXPORT-OK', 'Return Order exported to SharePoint',
            Verbosity::Normal, DataClassification::SystemMetadata,
            TelemetryScope::ExtensionPublisher, Dims);
    end;

    local procedure LogSROExportFailure(OrderNo: Code[20]; ErrorMessage: Text)
    var
        Dims: Dictionary of [Text, Text];
    begin
        Clear(Dims);
        Dims.Add('orderNo', OrderNo);
        Dims.Add('error', CopyStr(ErrorMessage, 1, 250));
        Dims.Add('mode', 'SRO');
        Session.LogMessage('3PL-SRO-EXPORT-FAIL', 'Return Order export failed',
            Verbosity::Error, DataClassification::SystemMetadata,
            TelemetryScope::ExtensionPublisher, Dims);
    end;

    local procedure SweepAutoPostSROs()
    var
        SalesHeader: Record "Sales Header";
        Dims: Dictionary of [Text, Text];
        AutoPostDisabled: Boolean;
    begin
        if Setup.Get('3PL') then
            AutoPostDisabled := Setup."SRO Auto-Post Disabled";

        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::"Return Order");
        SalesHeader.SetRange("Imported SRO Confirmation", true);
        SalesHeader.SetRange("Imported SRO Conf. Date", Today);
        SalesHeader.SetRange("3PL SRO Requires Review", false);
        SalesHeader.SetRange("3PL SRO Auto-Post Attempted", false);
        SalesHeader.SetRange(Status, SalesHeader.Status::Released);

        if not SalesHeader.FindSet() then
            exit;

        repeat
            if AutoPostDisabled then begin
                Clear(Dims);
                Dims.Add('orderNo', SalesHeader."No.");
                Dims.Add('loopReturnId', SalesHeader."Loop Return ID");
                Dims.Add('wouldInvoice', Format(SalesHeader."Loop Return ID" = ''));
                Session.LogMessage('3PL-SRO-AUTOPOST-SKIPPED', 'SRO auto-post skipped (disabled in setup)',
                    Verbosity::Normal, DataClassification::SystemMetadata,
                    TelemetryScope::ExtensionPublisher, Dims);
            end else
                if not TryAutoPostSingleSRO(SalesHeader) then begin
                    Clear(Dims);
                    Dims.Add('orderNo', SalesHeader."No.");
                    Dims.Add('error', CopyStr(GetLastErrorText(), 1, 250));
                    Session.LogMessage('3PL-SRO-AUTOPOST-FAIL', 'SRO auto-post failed',
                        Verbosity::Warning, DataClassification::SystemMetadata,
                        TelemetryScope::ExtensionPublisher, Dims);
                end;
            MarkAutoPostAttempted(SalesHeader."No.");
        until SalesHeader.Next() = 0;
    end;

    [TryFunction]
    local procedure TryAutoPostSingleSRO(SalesHeaderToPost: Record "Sales Header")
    var
        SalesPost: Codeunit "Sales-Post";
    begin
        SalesHeaderToPost.Ship := false;
        SalesHeaderToPost.Receive := true;
        SalesHeaderToPost.Invoice := SalesHeaderToPost."Loop Return ID" = '';
        SalesHeaderToPost.Modify();
        Commit();

        SalesPost.Run(SalesHeaderToPost);
    end;

    local procedure MarkAutoPostAttempted(OrderNo: Code[20])
    var
        SalesHeader: Record "Sales Header";
    begin
        if not SalesHeader.Get(SalesHeader."Document Type"::"Return Order", OrderNo) then
            exit;
        SalesHeader."3PL SRO Auto-Post Attempted" := true;
        SalesHeader.Modify();
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnBeforePostSalesDoc', '', false, false)]
    local procedure GuardSROPostingOnBeforePostSalesDoc(var SalesHeader: Record "Sales Header"; var IsHandled: Boolean)
    begin
        if SalesHeader."Document Type" <> SalesHeader."Document Type"::"Return Order" then
            exit;
        if not SalesHeader."3PL SRO Requires Review" then
            exit;

        Error('Cannot post Return Order %1: 3PL SRO discrepancies require review. Open the return order, review the discrepancy, and click "Clear 3PL Review Flag" before posting.', SalesHeader."No.");
    end;
}