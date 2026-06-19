pageextension 50495 "SalesReturnOrder3PLExt" extends "Sales Return Order"
{
    layout
    {
        addlast(General)
        {
            group(ThreePLSROInfo)
            {
                Caption = '3PL Integration';

                field("3PL Skipped"; Rec."3PL Skipped")
                {
                    ApplicationArea = All;
                    Caption = '3PL Skipped';
                    ToolTip = 'Exclude this return order from the 3PL integration.';
                }

                field("3PL SRO Exported"; Rec."3PL SRO Exported")
                {
                    ApplicationArea = All;
                    Caption = '3PL Return Order Exported';
                    Editable = false;
                }
                field("3PL SRO Export Date"; Rec."3PL SRO Export Date")
                {
                    ApplicationArea = All;
                    Caption = '3PL Return Order Export Date';
                    Editable = false;
                }

                field("Imported SRO Confirmation"; Rec."Imported SRO Confirmation")
                {
                    ApplicationArea = All;
                    Caption = 'Imported Return Receipt Confirmation';
                    Editable = false;
                }
                field("Imported SRO Conf. Date"; Rec."Imported SRO Conf. Date")
                {
                    ApplicationArea = All;
                    Caption = 'Imported Return Receipt Conf. Date';
                    Editable = false;
                }
                field("3PL SRO Reception No."; Rec."3PL SRO Reception No.")
                {
                    ApplicationArea = All;
                    Caption = '3PL Return Reception No.';
                    Editable = false;
                }

                field("3PL SRO Requires Review"; Rec."3PL SRO Requires Review")
                {
                    ApplicationArea = All;
                    Caption = '3PL SRO Requires Review';
                    Editable = false;
                    StyleExpr = ReviewStyleExpr;
                    ToolTip = 'A discrepancy was detected during the 3PL return import. Posting is blocked until this flag is cleared.';
                }
                field("3PL SRO Review Reason"; Rec."3PL SRO Review Reason")
                {
                    ApplicationArea = All;
                    Caption = '3PL SRO Review Reason';
                    Editable = false;
                    MultiLine = true;
                    StyleExpr = ReviewStyleExpr;
                    ToolTip = 'Details of discrepancies detected during the most recent 3PL return import. Multiple reasons are separated by " / ".';
                }
                field("3PL SRO Auto-Post Attempted"; Rec."3PL SRO Auto-Post Attempted")
                {
                    ApplicationArea = All;
                    Caption = '3PL SRO Auto-Post Attempted';
                    Editable = false;
                    ToolTip = 'Set to true after the auto-post sweep has considered this return order. Prevents repeated auto-post attempts.';
                }
            }
        }
    }

    actions
    {
        addlast(Processing)
        {
            action(ExportSROTo3PL)
            {
                ApplicationArea = All;
                Caption = 'Export SRO';
                Image = Export;
                ToolTip = 'Send this return order to the SharePoint outbox for 3PL processing.';

                trigger OnAction()
                var
                    SharePointMgmt: Codeunit "3PL Order SharePoint Mgmt";
                    SalesHeader: Record "Sales Header";
                    TempBlob: Codeunit "Temp Blob";
                begin
                    if not SalesHeader.Get(Rec."Document Type", Rec."No.") then
                        Error('Could not retrieve the current return order.');

                    if SalesHeader."3PL Skipped" then
                        Error('Return order %1 is marked "3PL Skipped" and will not be sent to the 3PL.', SalesHeader."No.");

                    if SalesHeader.Status <> SalesHeader.Status::Released then
                        Error('Return order must be released before export.');

                    SharePointMgmt.ExportSROToSharePoint(SalesHeader, false, TempBlob);

                    Rec.Get(SalesHeader."Document Type", SalesHeader."No.");
                    CurrPage.Update(false);
                end;
            }

            action(ImportSROForOrder)
            {
                ApplicationArea = All;
                Caption = 'Import SRO Confirmation for this Order';
                Image = Import;
                ToolTip = 'Import the return receipt confirmation file for this order from the SharePoint inbox.';

                trigger OnAction()
                var
                    SharePointMgmt: Codeunit "3PL Order SharePoint Mgmt";
                begin
                    if Rec."3PL Skipped" then
                        Error('Return order %1 is marked "3PL Skipped" — no 3PL confirmations are expected.', Rec."No.");

                    if not Rec."3PL SRO Exported" then
                        Error('Return order %1 has not been exported to the 3PL yet. Export the return order before importing the confirmation.', Rec."No.");

                    if SharePointMgmt.ImportSROForOrder(Rec."No.") then
                        Message('SRO confirmation imported for %1.', Rec."No.")
                    else
                        Message('No SRO confirmation file found or import failed for %1.', Rec."No.");
                end;
            }

            // DEBUG
            /*
            action(ClearSROExportFields3PL)
            {
                ApplicationArea = All;
                Caption = 'Clear SRO Export Fields';
                Image = ClearLog;
                ToolTip = 'Reset the 3PL return export flags and date on this return order.';

                trigger OnAction()
                var
                    SalesHeader: Record "Sales Header";
                begin
                    if not Confirm('Clear the 3PL SRO export fields on return order %1?', false, Rec."No.") then
                        exit;
                    if not SalesHeader.Get(Rec."Document Type", Rec."No.") then
                        Error('Could not retrieve the current return order.');
                    SalesHeader.ClearSROExport3PLFields();
                    CurrPage.Update(false);
                    Message('SRO export fields cleared on return order %1.', Rec."No.");
                end;
            }

            action(ClearSROConfirmation3PL)
            {
                ApplicationArea = All;
                Caption = 'Clear SRO Confirmation Fields';
                Image = ClearLog;
                ToolTip = 'Reset the imported return receipt confirmation flag, date, reception number, and review flag on this return order.';

                trigger OnAction()
                var
                    SalesHeader: Record "Sales Header";
                begin
                    if not Confirm('Clear the SRO confirmation fields on return order %1?', false, Rec."No.") then
                        exit;
                    if not SalesHeader.Get(Rec."Document Type", Rec."No.") then
                        Error('Could not retrieve the current return order.');
                    SalesHeader.ClearSROConfirmation3PLFields();
                    CurrPage.Update(false);
                    Message('SRO confirmation fields cleared on return order %1.', Rec."No.");
                end;
            }
            */

            action(ClearSROReviewFlag3PL)
            {
                ApplicationArea = All;
                Caption = 'Clear 3PL Review Flag';
                Image = ClearLog;
                ToolTip = 'Clear the SRO review-required flag so the return order can be posted.';

                trigger OnAction()
                var
                    SalesHeader: Record "Sales Header";
                begin
                    if not Rec."3PL SRO Requires Review" then begin
                        Message('Review flag is already clear on return order %1.', Rec."No.");
                        exit;
                    end;
                    if not Confirm('Clear the 3PL SRO review flag on return order %1? This will allow the return to be posted.', false, Rec."No.") then
                        exit;
                    if not SalesHeader.Get(Rec."Document Type", Rec."No.") then
                        Error('Could not retrieve the current return order.');
                    SalesHeader.ClearSROReviewFlag();
                    CurrPage.Update(false);
                    Message('Review flag cleared on return order %1.', Rec."No.");
                end;
            }

            // DEBUG — commented out for deployment.
            /*
            action(ListSharePointFilesDebugSRO)
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
            */
        }

        addlast(Promoted)
        {
            group(Category_3PL_SRO)
            {
                Caption = '3PL';
                Image = Allocate;

                actionref(Promoted_ExportSRO; ExportSROTo3PL) { }
                actionref(Promoted_ImportSRO; ImportSROForOrder) { }
                actionref(Promoted_ClearSROReviewFlag; ClearSROReviewFlag3PL) { }
                // DEBUG/DEMO refs — commented out alongside their actions.
                /*
                actionref(Promoted_ClearSROExport; ClearSROExportFields3PL) { }
                actionref(Promoted_ClearSROConfirmation; ClearSROConfirmation3PL) { }
                actionref(Promoted_ListFilesSRO; ListSharePointFilesDebugSRO) { }
                */
            }
        }
    }

    var
        ReviewStyleExpr: Text;

    trigger OnAfterGetCurrRecord()
    begin
        if Rec."3PL SRO Requires Review" then
            ReviewStyleExpr := 'Attention'
        else
            ReviewStyleExpr := '';
    end;
}
