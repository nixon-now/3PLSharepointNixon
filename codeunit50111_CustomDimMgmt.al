codeunit 50199 "Sales Header Dim Handler"
{
    // This codeunit manages dimension logic for the Sales Header.
    // It automatically updates dimensions when the custom field changes,
    // and provides helper functions for getting dimension values.

    // ====================================================================================
    // THIS IS THE REAL-TIME FUNCTIONALITY YOU ARE ASKING FOR
    // This "Event Subscriber" listens for when a user changes the '3PL_Preparation_Code'
    // field on the Sales Header page.
    // ====================================================================================
    [EventSubscriber(ObjectType::Table, Database::"Sales Header", 'OnAfterValidateEvent', '3PL_Preparation_Code', false, false)]
    local procedure OnAfterValidate3PLPrepCode(var Rec: Record "Sales Header")
    begin
        // When the field is changed, this code calls our reusable procedure to update the dimension.
        SetDimension(Rec, '3PL PREP CODE', Rec."3PL Prep Code");
    end;

    // This procedure updates or creates a dimension value in a given dimension set.
    // It is called by both the event subscriber (for future changes) and the report (for historical fixes).
    procedure SetDimension(var SalesHeader: Record "Sales Header"; DimensionCode: Code[20]; DimensionValueCode: Code[20])
    var
        DimMgt: Codeunit "DimensionManagement";
        TempDimSetEntry: Record "Dimension Set Entry" temporary;
        NewDimSetID: Integer;
    begin
        DimMgt.GetDimensionSet(TempDimSetEntry, SalesHeader."Dimension Set ID");

        if TempDimSetEntry.Get(SalesHeader."Dimension Set ID", DimensionCode) then
            TempDimSetEntry.Delete();

        if DimensionValueCode <> '' then begin
            TempDimSetEntry.Init();
            TempDimSetEntry."Dimension Set ID" := SalesHeader."Dimension Set ID";
            TempDimSetEntry."Dimension Code" := DimensionCode;
            TempDimSetEntry."Dimension Value Code" := DimensionValueCode;
            TempDimSetEntry.Insert();
        end;

        NewDimSetID := DimMgt.GetDimensionSetID(TempDimSetEntry);

        if NewDimSetID <> SalesHeader."Dimension Set ID" then begin
            SalesHeader."Dimension Set ID" := NewDimSetID;
            SalesHeader.Modify();
        end;
    end;

    // This is a helper function that finds and returns the value for a specific dimension code.
    procedure GetDimensionValue(DimSetID: Integer; DimensionCode: Code[20]): Code[20]
    var
        DimSetEntry: Record "Dimension Set Entry";
    begin
        if DimSetID = 0 then
            exit('');

        DimSetEntry.SetRange("Dimension Set ID", DimSetID);
        DimSetEntry.SetRange("Dimension Code", DimensionCode);
        if DimSetEntry.FindFirst() then
            exit(DimSetEntry."Dimension Value Code");

        exit('');
    end;
}