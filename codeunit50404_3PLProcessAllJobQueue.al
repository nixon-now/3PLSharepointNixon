codeunit 50404 "3PL Process All Job Queue"
{
    TableNo = "Job Queue Entry";

    trigger OnRun()
    var
        ThreePLMgmt: Codeunit "3PL Order SharePoint Mgmt";
    begin
        ThreePLMgmt.ProcessAll();
    end;
}
