codeunit 50406 "3PL Location Filter"
{
    // Decides which sales lines belong in the 3PL order export. Only lines whose
    // "Location Code" points to a Location with "3PL Location" = true are sent to the 3PL;
    // lines from other locations (e.g. custom-watch spare parts from 31-EU) or with a blank
    // location are excluded. Flagged location codes are cached once per instance, so a single
    // export run reads the Location table only once instead of once per sales line.

    var
        ThreePLLocationCodes: List of [Code[10]];
        IsCacheLoaded: Boolean;

    procedure IsThreePLLocation(LocationCode: Code[10]): Boolean
    begin
        if LocationCode = '' then
            exit(false);

        LoadThreePLLocations();
        exit(ThreePLLocationCodes.Contains(LocationCode));
    end;

    procedure HasThreePLLines(SalesHeader: Record "Sales Header"): Boolean
    var
        SalesLine: Record "Sales Line";
    begin
        SalesLine.SetLoadFields("Location Code");
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetRange(Type, SalesLine.Type::Item);
        SalesLine.SetFilter("Location Code", '<>%1', '');
        if SalesLine.FindSet() then
            repeat
                if IsThreePLLocation(SalesLine."Location Code") then
                    exit(true);
            until SalesLine.Next() = 0;

        exit(false);
    end;

    local procedure LoadThreePLLocations()
    var
        Location: Record Location;
    begin
        if IsCacheLoaded then
            exit;

        Location.SetLoadFields(Code);
        Location.SetRange("3PL Location", true);
        if Location.FindSet() then
            repeat
                ThreePLLocationCodes.Add(Location.Code);
            until Location.Next() = 0;

        IsCacheLoaded := true;
    end;
}
