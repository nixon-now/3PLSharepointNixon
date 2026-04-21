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
        field(50004; "Export SRO Xmlport ID"; Integer)
        {
            Caption = 'Export SRO XMLport ID';
            ToolTip = 'Object ID used for exporting sales return orders to 3PL.';
        }
        field(50005; "Import SRO Xmlport ID"; Integer)
        {
            Caption = 'Import SRO XMLport ID';
            ToolTip = 'Object ID used for importing return receipt confirmations from 3PL.';
        }
    }
}
