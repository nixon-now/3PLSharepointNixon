tableextension 50409 "3PL Setup Ext" extends "SharePoint Setup"
{
    fields
    {
        field(50000; "Export SO Xmlport ID"; Integer)
        {
            Caption = 'Export SO XMLport ID';
            ToolTip = 'Object ID used for exporting sales orders.';
        }
        field(50001; "Import Pick Xmlport ID"; Integer)
        {
            Caption = 'Import Pick XMLport ID';
            ToolTip = 'Object ID used for importing pick confirmations.';
        }
         field(50002; "Export COD Xmlport ID"; Integer)
        {
            Caption = 'Export COD XMLport ID';
            ToolTip = 'Object ID used for exporting sales orders.';
        }
        field(50003; "Import Ship Xmlport ID"; Integer)
        {
            Caption = 'Import Ship XMLport ID';
            ToolTip = 'Object ID used for importing ship confirmations.';
        }
    }
}
