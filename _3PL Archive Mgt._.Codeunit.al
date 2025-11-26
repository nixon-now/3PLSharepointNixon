codeunit 50401 "3PL Archive Mgt."
{
    // Keeps track of what we send to and get from our warehouse partners
    // Fixed some logging issues
    // Might want to add performance tracking someday
    
    var 
        CurrentRunId: Guid;

    procedure LogExport(DocNo: Code[20]; ExternalNo: Code[35]; FileName: Text; WhatStep: Option ExportOrder, ExportCOD, ImportPick, ImportShipment; ItWorked: Boolean; ProblemText: Text)
    var
        Arch: Record "3PL Archive";
        Config: Record "Sharepoint Setup";
    begin
        // Need the setup to know where we're sending stuff
        if not Config.Get() then 
            exit;
            
        Arch.Init();
        Arch."Entry No." := GetNextNo();
        Arch."Archive Date/Time" := CurrentDateTime;
        Arch."Direction" := Arch."Direction"::Export;
        Arch."Document No." := DocNo;
        Arch."External Doc No." := ExternalNo;
        Arch."File Name" := CopyStr(FileName, 1, MaxStrLen(Arch."File Name"));
        Arch."Step" := "3PL Archive Step"::ExportOrder;
        Arch."User ID" := CopyStr(UserId(), 1, MaxStrLen(Arch."User ID"));
        Arch."Integration ID" := GetThisRunId();
        
        if ItWorked then
            Arch."ResultOption" := Arch.ResultOption::Success
        else
            Arch."ResultOption" := Arch.ResultOption::Error;
            
        Arch."Error Message" := CopyStr(ProblemText, 1, MaxStrLen(Arch."Error Message"));
        Arch."3PL Code" := Config."3PL Code";
        Arch."Location Code" := Config."Location Code";
        Arch."SharePoint Export Folder" := Config."SharePoint Export Folder";
        Arch.Insert(true);
        
        // Let's remember we did this
        WriteToLog('ARCH100', Arch, DocNo);
    end;

    procedure LogImport(DocNo: Code[20]; ExternalNo: Code[35]; FileName: Text; WhatStep: Option ExportOrder, ExportCOD, ImportPick, ImportShipment; ItWorked: Boolean; ProblemText: Text)
    var
        Arch: Record "3PL Archive";
        Config: Record "Sharepoint Setup";
    begin
        // No config? Nothing to do here
        if not Config.Get() then 
            exit;
            
        Arch.Init();
        Arch."Entry No." := GetNextNo();
        Arch."Archive Date/Time" := CurrentDateTime;
        Arch."Direction" := Arch."Direction"::Import;
        Arch."Document No." := DocNo;
        Arch."External Doc No." := ExternalNo;
        Arch."File Name" := CopyStr(FileName, 1, MaxStrLen(Arch."File Name"));
        Arch."Step" := "3PL Archive Step"::ImportConfirmation;
        Arch."User ID" := CopyStr(UserId(), 1, MaxStrLen(Arch."User ID"));
        Arch."Integration ID" := GetThisRunId();
        
        if ItWorked then
            Arch."ResultOption" := Arch.ResultOption::Success
        else
            Arch."ResultOption" := Arch.ResultOption::Error;
            
        Arch."Error Message" := CopyStr(ProblemText, 1, MaxStrLen(Arch."Error Message"));
        Arch."3PL Code" := Config."3PL Code";
        Arch."Location Code" := Config."Location Code";
        Arch.Insert(true);
        
        WriteToLog('ARCH101', Arch, DocNo);
    end;

    local procedure GetNextNo(): Integer 
    var
        Arch: Record "3PL Archive";
    begin
        // Grab the next available number
        Arch.LockTable();
        if Arch.FindLast() then 
            exit(Arch."Entry No." + 1);
        exit(1);
    end;

    local procedure GetThisRunId(): Guid 
    begin
        // Make sure we have an ID for this batch of work
        if IsNullGuid(CurrentRunId) then 
            CurrentRunId := CreateGuid();
        exit(CurrentRunId);
    end;

    procedure WasOrderExported(OrderNumber: Code[20]; IsCODOrder: Boolean): Boolean
    var
        Arch: Record "3PL Archive";
    begin
        // Check if we already sent this one out
        Arch.Reset();
        Arch.SetRange("Document No.", OrderNumber);
        Arch.SetRange(Direction, Arch.Direction::Export);
        
        if IsCODOrder then
            Arch.SetRange(Step, Arch.Step::ExportCOD)
        else
            Arch.SetRange(Step, Arch.Step::ExportOrder);
            
        Arch.SetRange("ResultOption", Arch."ResultOption"::Success);
        
        exit(Arch.FindFirst());
    end;

    procedure GetStepOptions() StepOptions: Option ExportOrder, ExportCOD, ImportPick, ImportShipment 
    begin
        // Just returns the options - might not really need this
    end;

    procedure CleanupOldStuff(KeepDays: Integer)
    var
        Arch: Record "3PL Archive";
        RemoveBefore: Date;
        HowMany: Integer;
    begin
        // Get rid of old records to keep things tidy
        if KeepDays <= 0 then 
            exit;
            
        RemoveBefore := CalcDate(StrSubstNo('<-%1D>', KeepDays), Today());
        Arch.SetRange("Archive Date/Time", 0DT, CreateDateTime(RemoveBefore, 0T));
        HowMany := Arch.Count();
        
        if HowMany > 0 then begin
            Arch.DeleteAll();
            Session.LogMessage('ARCH200', StrSubstNo('Cleaned out %1 old records from before %2', HowMany, RemoveBefore), Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'Category_Archive', '3PL Integration');
        end;
    end;

    local procedure WriteToLog(LogId: Text; var Arch: Record "3PL Archive"; DocNo: Code[20])
    begin
        // Write a note about what we're doing
        Session.LogMessage(LogId, StrSubstNo('%1 %2 for %3 (%4)', FORMAT(Arch."Direction"), FORMAT(Arch."Step"), DocNo, FORMAT(Arch."Result")), Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'Category_Archive', '3PL Integration');
    end;
}