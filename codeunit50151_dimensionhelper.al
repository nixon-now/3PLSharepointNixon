codeunit 50151 "3PL Dimension Helper"
{
    // Method 1: Full control with all parameters
    procedure EnsureDimensionValueExists(DimensionCode: Code[20]; DimensionValueCode: Code[20]; DimensionValueName: Text[50])
    var
        DimensionValue: Record "Dimension Value";
    begin
        if DimensionValueCode = '' then
            exit;

        if not DimensionValue.Get(DimensionCode, DimensionValueCode) then begin
            DimensionValue.Init();
            DimensionValue."Dimension Code" := DimensionCode;
            DimensionValue.Code := DimensionValueCode;
            DimensionValue.Name := CopyStr(DimensionValueName, 1, MaxStrLen(DimensionValue.Name));
            DimensionValue.Blocked := false;
            DimensionValue."Map-to IC Dimension Value Code" := '';
            DimensionValue."Consolidation Code" := '';
            DimensionValue.Insert(true);
        end;
    end;

    // Method 2: Simplified version for 3PL Prep Codes specifically
    procedure Ensure3PLPrepDimensionValueExists(PrepCode: Code[20])
    var
        DimensionCode: Code[20];
    begin
        DimensionCode := '3PL PREP CODE';
        EnsureDimensionValueExists(DimensionCode, PrepCode, PrepCode);
    end;

    // Method 3: Bulk create for all sales orders
    procedure CreateMissing3PLDimensionValues()
    var
        SalesHeader: Record "Sales Header";
        DimensionCode: Code[20];
    begin
        DimensionCode := '3PL PREP CODE';

        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
        SalesHeader.SetFilter("3PL PREP Code", '<>%1', '');

        if SalesHeader.FindSet() then
            repeat
                EnsureDimensionValueExists(DimensionCode, SalesHeader."3PL PREP Code", SalesHeader."3PL PREP Code");
            until SalesHeader.Next() = 0;

        Message('3PL dimension values creation completed.');
    end;
}