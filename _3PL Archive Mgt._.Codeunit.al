codeunit 50401 "3PL Archive Mgt."
{
    // Enhanced archive management for 3PL integrations
    // Version with corrected telemetry logging
    var CurrentIntegrationID: Guid;
    procedure LogExport(DocumentNo: Code[20]; ExtDocNo: Code[35]; FileName: Text; Step: Option ExportOrder, ExportCOD, ImportPick, ImportShipment; Success: Boolean; ErrorMessage: Text)
    var
        Archive: Record "3PL Archive";
        Setup: Record "Sharepoint Setup";
    begin
        if not Setup.Get()then exit;
        Archive.Init();
        Archive."Entry No.":=GetNextEntryNo();
        Archive."Archive Date/Time":=CurrentDateTime;
        Archive."Direction":=Archive."Direction"::Export;
        Archive."Document No.":=DocumentNo;
        Archive."External Doc No.":=ExtDocNo;
        Archive."File Name":=CopyStr(FileName, 1, MaxStrLen(Archive."File Name"));
        Archive."Step":="3PL Archive Step"::ExportOrder;
        Archive."User ID":=CopyStr(UserId(), 1, MaxStrLen(Archive."User ID"));
        Archive."Integration ID":=GetCurrentIntegrationID();
        Archive."ResultOption":=Archive.ResultOption::Success;
        Archive."Error Message":=CopyStr(ErrorMessage, 1, MaxStrLen(Archive."Error Message"));
        Archive."3PL Code":=Setup."3PL Code";
        Archive."Location Code":=Setup."Location Code";
        Archive.Insert(true);
        LogArchiveEvent('ARCH100', Archive, DocumentNo);
    end;
    procedure LogImport(DocumentNo: Code[20]; ExtDocNo: Code[35]; FileName: Text; Step: Option ExportOrder, ExportCOD, ImportPick, ImportShipment; Success: Boolean; ErrorMessage: Text)
    var
        Archive: Record "3PL Archive";
        Setup: Record "Sharepoint Setup";
    begin
        if not Setup.Get()then exit;
        Archive.Init();
        Archive."Entry No.":=GetNextEntryNo();
        Archive."Archive Date/Time":=CurrentDateTime;
        Archive."Direction":=Archive."Direction"::Import;
        Archive."Document No.":=DocumentNo;
        Archive."External Doc No.":=ExtDocNo;
        Archive."File Name":=CopyStr(FileName, 1, MaxStrLen(Archive."File Name"));
        Archive."Step":="3PL Archive Step"::ImportConfirmation;
        Archive."User ID":=CopyStr(UserId(), 1, MaxStrLen(Archive."User ID"));
        Archive."Integration ID":=GetCurrentIntegrationID();
        Archive."ResultOption":=Archive.ResultOption::Success;
        Archive."Error Message":=CopyStr(ErrorMessage, 1, MaxStrLen(Archive."Error Message"));
        Archive."3PL Code":=Setup."3PL Code";
        Archive."Location Code":=Setup."Location Code";
        Archive.Insert(true);
        LogArchiveEvent('ARCH101', Archive, DocumentNo);
    end;
    local procedure GetNextEntryNo(): Integer var
        Archive: Record "3PL Archive";
    begin
        Archive.LockTable();
        if Archive.FindLast()then exit(Archive."Entry No." + 1);
        exit(1);
    end;
    local procedure GetCurrentIntegrationID(): Guid begin
        if IsNullGuid(CurrentIntegrationID)then CurrentIntegrationID:=CreateGuid();
        exit(CurrentIntegrationID);
    end;
    local procedure GetResult(Success: Boolean): Option Success, Failed begin
        if Success then exit(0); // Success
        exit(1); // Failed
    end;
    procedure GetStep()Step: Option ExportOrder, ExportCOD, ImportPick, ImportShipment begin
    // Public getter for step options
    end;
    procedure PurgeOldEntries(RetentionDays: Integer)
    var
        Archive: Record "3PL Archive";
        PurgeDate: Date;
        EntryCount: Integer;
    begin
        if RetentionDays <= 0 then exit;
        PurgeDate:=CalcDate(StrSubstNo('<-%1D>', RetentionDays), Today());
        Archive.SetRange("Archive Date/Time", 0DT, CreateDateTime(PurgeDate, 0T));
        EntryCount:=Archive.Count();
        if EntryCount > 0 then begin
            Archive.DeleteAll();
            Session.LogMessage('ARCH200', StrSubstNo('Purged %1 archive entries older than %2', EntryCount, PurgeDate), Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'Category_Archive', '3PL Integration');
        end;
    end;
    local procedure LogArchiveEvent(EventId: Text; var Archive: Record "3PL Archive"; DocumentNo: Code[20])
    begin
        Session.LogMessage(EventId, StrSubstNo('%1 %2 for %3 (%4)', FORMAT(Archive."Direction"), FORMAT(Archive."Step"), DocumentNo, FORMAT(Archive."Result")), Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'Category_Archive', '3PL Integration');
    end;
}
