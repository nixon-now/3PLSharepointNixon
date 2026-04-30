pageextension 50412 "3PL Setup Ext Card" extends "SharePoint Setup"
{
    layout
    {
        addlast(Content)
        {
            group("Company-specific XMLports")
            {
                field("Export Xmlport ID"; rec."Export SO Xmlport ID") { ApplicationArea = All; }
                field("Import Xmlport ID"; rec."Import Pick Xmlport ID") { ApplicationArea = All; }
                field("Export COD Xmlport ID"; rec."Export COD Xmlport ID") { ApplicationArea = All; }
                field("Import Ship ID"; rec."Import Ship Xmlport ID") { ApplicationArea = All; }
                field("Export SRO Xmlport ID"; Rec."Export SRO Xmlport ID") { ApplicationArea = All; }
                field("Import SRO Xmlport ID"; Rec."Import SRO Xmlport ID") { ApplicationArea = All; }
            }
        }
    }
}
