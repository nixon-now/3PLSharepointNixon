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
                field("SRO Auto-Post Disabled"; Rec."SRO Auto-Post Disabled") { ApplicationArea = All; }
                field("Set Shipment Date On Ship Import"; Rec."Set Shipment Date On Ship Import") { ApplicationArea = All; }
                field("Move Failed Files To Error Folder"; Rec."Move Failed Files To Error Folder") { ApplicationArea = All; }
            }
        }
    }
}
