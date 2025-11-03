permissionset 50400 "3PL Admin"
{
    Assignable = true;
    
    Permissions = TableData "Sales Header"=RMID,
        TableData "SharePoint Setup"=RMID,
        TableData "3PL Integration Log"=RMID,
        TableData "3PL Setup"=RMID,
        TableData "3PL Archive"=RMID,
        //TableData "Warehouse Manager Setup"=RMID,
        Codeunit "SharePoint Graph Connector"=X,
    
        Page "SharePoint Connection Test"=X,
        Page "SharePoint Setup"=X,
        
        Page "3PL Archive List"=X,
        Page "3PL Archive Card"=X;
    
    ;
}
