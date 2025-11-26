permissionset 50400 "3PL Admin"
{
    Assignable = true;
    
     // Pull in Microsoft's standard permissions for core usage + sales posting
    //IncludedPermissionSets = 'D365 SALES, DOC, POST';

    // additional permissions (kept minimal and focused)
    Permissions =
        // ===== Core Sales docs touched by integration =====
        TableData "Sales Header"                  = RIMD,   // export flags; ship import sets tracking/agent
        TableData "Sales Line"                    = RIMD,   // pick import sets Qty. to Ship
        TableData "Sales Shipment Header"         = RIMD,   // posting creates header (pre-insert subscriber enriches)
        TableData "Sales Shipment Line"           = RIMD,

        // ===== Integration setup + logs =====
        TableData "SharePoint Setup"              = R,      // operators read setup, do not edit
        TableData "3PL Setup"                     = R,
        TableData "3PL Archive"                   = RIMD,   // ArchiveLog() inserts
        TableData "3PL Integration Log"           = RIMD,
        TableData "String List Buffer"            = RIMD,
        TableData "3PL Prep Code Setup"         = RIMD,

        // ===== Codeunits (execute) =====
        Codeunit "3PL Order SharePoint Mgmt"      = X,      // 50400 – exports/imports/process-all
        Codeunit "SharePoint Graph Connector"     = X,      // 50402 – list/download/rename
        Codeunit "PostedShipmentUpdate"           = X,      // 50535 – pre-insert shipment subscriber

        // ===== XmlPorts (execute) =====
        XmlPort  "Import Pick Confirmation"       = X,      // e.g., 50432
        XmlPort  "Import Pick Confirmation_AU" = X,
         XmlPort  "Import Pack Confirmation_eU" = X,
        XmlPort  "Import Shipped Confirmation"    = X,
        XmlPort  "Import Shipped Confirmation_AU"            = X,      // e.g., 50441
        XmlPort  "Import Shipped Confirmation_EU"            = X,      // e.g., 50441
        xmlport "Export Orders to 3PL_EU" = X,
        xmlport "Export Orders to 3PL_AU" = X,
        xmlport "Export Orders to 3PL" = X,
        xmlport "Export COD Total to 3PL" = X,
        // ===== Pages for ops visibility (no setup edits) =====
        Page     "3PL Archive List"               = X,
        Page     "3PL Archive Card"               = X;
}

