codeunit 50400 "3PL Order SharePoint Mgmt"
{
    // Handles 3PL SharePoint import/export and archives processed files

    var
        MyTempBlob: Codeunit "Temp Blob";

    procedure ExportOrderToSharePoint(var SalesHeader: Record "Sales Header")
    begin
        if not TryExportOrder(SalesHeader, MyTempBlob, false, false) then
            Error(GetLastErrorText());
    end;

    procedure ExportCODTotal(var SalesHeader: Record "Sales Header")
    var
        TempBlob: Codeunit "Temp Blob";
    begin
        if not TryExportOrder(SalesHeader, TempBlob, false, true) then
            Error(GetLastErrorText());
    end;

    procedure ExportAllSalesOrders()
    var
        SalesHeader: Record "Sales Header";
        SharePointSetup: Record "SharePoint Setup";
        TempBlob: Codeunit "Temp Blob";
        ErrorCount, SuccessCount, SkippedCount, CurrentOrder, OrderCount: Integer;
        Window: Dialog;
    begin
        if not SharePointSetup.Get('3PL') then
            Error('SharePoint Setup not configured for 3PL');

        SalesHeader.SetRange(Status, SalesHeader.Status::Released);
        SalesHeader.SetRange("Location Code", SharePointSetup."Location Code");
        OrderCount := SalesHeader.Count();

        if OrderCount = 0 then
            exit;

        Window.Open('Exporting orders...\\Order #1##########\\Status #2##########\\Progress: @3@@@@@@@@@');

        if SalesHeader.FindSet() then
            repeat
                CurrentOrder += 1;
                Window.Update(1, SalesHeader."No.");
                Window.Update(3, Round(CurrentOrder / OrderCount * 10000, 1));

                if IsRecentlyExported(SalesHeader) then begin
                    SkippedCount += 1;
                    Window.Update(2, 'Skipped (recent)');
                    continue;
                end;

                Window.Update(2, 'Exporting...');
                if TryExportOrder(SalesHeader, TempBlob, true, false) then
                    SuccessCount += 1
                else
                    ErrorCount += 1;
            until SalesHeader.Next() = 0;

        Window.Close();
        Message('Export completed: %1 successful, %2 skipped, %3 failed', SuccessCount, SkippedCount, ErrorCount);
    end;

    local procedure TryExportOrder(
        var SalesHeader: Record "Sales Header";
        var TempBlob: Codeunit "Temp Blob";
        SilentMode: Boolean;
        IsCODExport: Boolean
    ): Boolean
    var
        Setup: Record "SharePoint Setup";
        GraphConn: Codeunit "SharePoint Graph Connector";
        ExportOrderXmlPort: XmlPort "Export Orders to 3PL";
        ExportCODXmlPort: XmlPort "Export COD Total to 3PL";
        OutStr: OutStream;
        InStr: InStream;
        ExportFileName: Text;
        ArchiveFolder: Text;
        ArchiveStep: Enum "3PL Archive Step";
    begin
        if not Setup.Get('3PL') then
            exit(false);

        if not (SalesHeader."Document Type" = SalesHeader."Document Type"::Order) or
           not (SalesHeader.Status = SalesHeader.Status::Released) or
           not (SalesHeader."Location Code" = Setup."Location Code")
        then
            exit(false);

        if IsCODExport then begin
            ExportFileName := SalesHeader."No." + '_COD.xml';
            ArchiveStep := ArchiveStep::ExportCOD;

            TempBlob.CreateOutStream(OutStr);
            ExportCODXmlPort.SetTableView(SalesHeader);
            ExportCODXmlPort.SetDestination(OutStr);

            if not ExportCODXmlPort.Export() then begin
                LogError('ExportFailed', SalesHeader."No.", GetLastErrorText());
                exit(false);
            end;
        end else begin
            ExportFileName := SalesHeader."No." + '_ship.xml';
            ArchiveStep := ArchiveStep::ExportOrder;

            TempBlob.CreateOutStream(OutStr);
            ExportOrderXmlPort.SetTableView(SalesHeader);
            ExportOrderXmlPort.SetDestination(OutStr);

            if not ExportOrderXmlPort.Export() then begin
                LogError('ExportFailed', SalesHeader."No.", GetLastErrorText());
                exit(false);
            end;
        end;

        TempBlob.CreateInStream(InStr);
        if not GraphConn.UploadFileFromSetup('3PL', ExportFileName, InStr) then begin
            LogError('UploadFailed', SalesHeader."No.", GraphConn.GetLastError());
            exit(false);
        end;

        if IsCODExport then
            SalesHeader."3PL Exported" := true
        else
            SalesHeader."3PL Order Exported" := true;

        SalesHeader.Modify();
        GraphConn.MoveFileFromSetup('3PL', ExportFileName, Setup."SharePoint Archive Folder");

        ArchiveLog(
            true,
            "3PL Log Direction"::Export,
            SalesHeader."No.",
            SalesHeader."External Document No.",
            ExportFileName,
            Setup,
            ArchiveStep,
            '',
            Setup."SharePoint Archive Folder"
        );

        exit(true);
    end;

    procedure ImportPickConfirmationFromSharePoint(FileName: Text)
    var
        Setup: Record "SharePoint Setup";
        ArchiveRec: Record "3PL Archive";
        GraphConn: Codeunit "SharePoint Graph Connector";
        XmlPickPort: XmlPort "Import Pick Confirmation";
        TempBlob: Codeunit "Temp Blob";
        OutStr: OutStream;
        InStr: InStream;
    begin
        Setup.Get('3PL');

        TempBlob.CreateOutStream(OutStr);
        if not GraphConn.DownloadFileFromSetup('3PL', FileName, OutStr) then begin
            ArchiveLog(false, ArchiveRec."Direction"::Import, '', '', FileName, Setup,
              "3PL Archive Step"::ImportConfirmation, 'Download failed: ' + GraphConn.GetLastError(), Setup."SharePoint Archive Folder");
            exit;
        end;

        TempBlob.CreateInStream(InStr);
        XmlPickPort.SetSource(InStr);
        XmlPickPort.Run();

        GraphConn.MoveFileFromSetup('3PL', FileName, Setup."SharePoint Archive Folder");
        ArchiveLog(true, ArchiveRec."Direction"::Import, '', '', FileName, Setup,
          "3PL Archive Step"::ImportConfirmation, '', Setup."SharePoint Archive Folder");
    end;

    procedure ImportShipmentTrackingFromSharePoint(FileName: Text)
    var
        Setup: Record "SharePoint Setup";
        ArchiveRec: Record "3PL Archive";
        GraphConn: Codeunit "SharePoint Graph Connector";
        ImportShipments: XmlPort "Import Shipped Confirmation";
        TempBlob: Codeunit "Temp Blob";
        OutStr: OutStream;
        InStr: InStream;
    begin
        Setup.Get('3PL');

        TempBlob.CreateOutStream(OutStr);
        if not GraphConn.DownloadFileFromSetup('3PL', FileName, OutStr) then begin
            ArchiveLog(false, ArchiveRec."Direction"::Import, '', '', FileName, Setup,
              "3PL Archive Step"::ImportShipment, 'Download failed: ' + GraphConn.GetLastError(), Setup."SharePoint Archive Folder");
            exit;
        end;

        TempBlob.CreateInStream(InStr);
        ImportShipments.SetCurrentFilename(FileName);
        ImportShipments.SetSource(InStr);
        ImportShipments.Run();

        GraphConn.MoveFileFromSetup('3PL', FileName, Setup."SharePoint Archive Folder");
        ArchiveLog(true, ArchiveRec."Direction"::Import, '', '', FileName, Setup,
          "3PL Archive Step"::ImportShipment, '', Setup."SharePoint Archive Folder");
    end;

    local procedure IsRecentlyExported(SalesHeader: Record "Sales Header"): Boolean
    var
        Archive: Record "3PL Archive";
        YesterdayDateTime: DateTime;
    begin
        YesterdayDateTime := CreateDateTime(CalcDate('<-1D>', Today), 000000T);
        Archive.SetRange("Document No.", SalesHeader."No.");
        Archive.SetRange("Direction", Archive."Direction"::Export);
        Archive.SetRange(ResultOption, Archive.ResultOption::Success);
        Archive.SetRange("Archive Date/Time", YesterdayDateTime, CurrentDateTime);
        exit(not Archive.IsEmpty());
    end;

    local procedure ArchiveLog(
        Success: Boolean;
        Direction: Enum "3PL Log Direction";
        DocumentNo: Code[20];
        ExtDocNo: Code[30];
        FileName: Text;
        Setup: Record "SharePoint Setup";
        Step: Enum "3PL Archive Step";
        ErrMsg: Text;
        ArchiveFolder: Text
    ): Boolean
    var
        Archive: Record "3PL Archive";
    begin
        Archive.Init();
        Archive."Archive Date/Time" := CurrentDateTime;
        Archive."Direction" := Direction;
        Archive."Document No." := DocumentNo;
        Archive."External Doc No." := ExtDocNo;
        Archive."File Name" := CopyStr(FileName, 1, MaxStrLen(Archive."File Name"));
        Archive."Sharepoint Archive Folder" := ArchiveFolder;
        Archive."Location Code" := Setup."Location Code";
        Archive."3PL Code" := Setup."3PL Code";
        Archive."Step" := Step;
        Archive."User ID" := UserId();
        Archive."Integration ID" := CreateGuid();
        if Success then
    Archive."ResultOption" := Archive."ResultOption"::Success
else
    Archive."ResultOption" := Archive."ResultOption"::Error;
        Archive."Error Message" := CopyStr(ErrMsg, 1, MaxStrLen(Archive."Error Message"));
        exit(Archive.Insert(true));
    end;

    local procedure LogError(ErrorType: Text; OrderNo: Code[20]; ErrorMessage: Text)
    var
        Dimensions: Dictionary of [Text, Text];
    begin
        Dimensions.Add('OrderNo', OrderNo);
        Dimensions.Add('Error', ErrorMessage);
        Session.LogMessage(
            '0000ERR',
            StrSubstNo('%1 for order %2', ErrorType, OrderNo),
            Verbosity::Error,
            DataClassification::SystemMetadata,
            TelemetryScope::ExtensionPublisher,
            Dimensions
        );
    end;
    procedure ExportSelectedOrders(var SalesHeaderFilter: Record "Sales Header")
var
    SalesHeader: Record "Sales Header";
    TempBlob: Codeunit "Temp Blob";
    ErrorCount: Integer;
    SuccessCount: Integer;
    Window: Dialog;
begin
    Window.Open('Processing selected orders...\\Order #1##########\\Status #2##########');

    SalesHeader.CopyFilters(SalesHeaderFilter);
    if SalesHeader.FindSet() then begin
        repeat
            Window.Update(1, SalesHeader."No.");
            Window.Update(2, 'Processing...');
            
            if not TryExportOrder(SalesHeader, TempBlob, true, false) then
                ErrorCount += 1
            else
                SuccessCount += 1;
        until SalesHeader.Next() = 0;
        
        Window.Close();
        Message('Export completed: %1 successful, %2 failed', SuccessCount, ErrorCount);
    end else begin
        Window.Close();
        Message('No orders match the selected filters.');
    end;
end;
procedure ProcessAll()
var
    GraphConn: Codeunit "SharePoint Graph Connector";
    Setup: Record "SharePoint Setup";
    FileNames: List of [Text];
    FileName: Text;
    TempBlob: Codeunit "Temp Blob";
begin
    Setup.Get('3PL');
    FileNames := GraphConn.ListFilesFromSetup('3PL');

    if FileNames.Count() = 0 then begin
        Message('No files found in SharePoint import folder.');
        exit;
    end;

    foreach FileName in FileNames do begin
        case true of
            FileName.ToLower().Contains('pick'):
                ImportPickConfirmationFromSharePoint(FileName);
            FileName.ToLower().Contains('ship'):
                ImportShipmentTrackingFromSharePoint(FileName);
            else
                ArchiveLog(
                    false, 
                    "3PL Log Direction"::Import, 
                    '', 
                    '', 
                    FileName, 
                    Setup,
                    "3PL Archive Step"::ImportConfirmation, 
                    'Unrecognized file type', 
                    Setup."SharePoint Archive Folder"
                );
        end;
    end;
    Message('%1 files processed from SharePoint.', FileNames.Count());
end;
}
