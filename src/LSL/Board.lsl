#include "src/includes/shared.lsl"

default
{
    state_entry()
    {
        
        g_kID = (key)llGetObjectDesc();
        if(g_kID == "" || g_kID == "(No Description)" || g_kID == "FIRSTREZ" || g_kID == "0"){
            llSay(0, "First Rez!");
            llSetObjectDesc("0");
            state ready;
        }
        state ready;
    }

    link_message(integer s,integer n,string m,key i)
    {
        if(n == 0x004f)
        {
            API_SERVER = DecipherService(m,"api") + "/zni";

            state ready;
        }
    }
    on_rez(integer t){
        llResetScript();
    }
    
    changed(integer t){
        if(t&CHANGED_REGION_START)llResetScript();
    }
}


state ready
{
    state_entry()
    {
        s("Starting up");
        /// - RESET THE MENU SCRIPT -
        llResetOtherScript("Message Board Menu [AC]");
        // - Sleep to let Menu wake up and settle down -
        llSleep(2);
        //g_kAccessReader = llGetNotecardLine("Access", g_iAccessLine);
        UpdateDSRequest(NULL, llGetNotecardLine("Access", 0), SetDSMeta(["read_access",0]));
        
        s("Reading access lists");
        
        g_iStartup=1;
    }
    
    
    changed(integer t){
        if(t&CHANGED_INVENTORY || t&CHANGED_REGION_START){
            llResetScript();
        }
    }

    link_message(integer s,integer n,string m,key i){
        if(n == LINK_COMMIT_SETTINGS){
            SerializeFinal(m);
        }else if(n==LINK_CHECK_UPDATE)
        {
            CheckUpdate();
        }
    }
    
    dataserver(key r,string d){
        if(HasDSRequest(r)!=-1){
            list lMeta = GetMetaList(r);
            if(llList2String(lMeta,0) == "read_access"){
                if(d==EOF){
                    DeleteDSReq(r);
                    s("Completed reading access lists");
                    if(llListFindList(g_lAccess, [(string)llGetOwner()])==-1){
                        s("Adding object owner to access list");
                        g_lAccess += [(string)llGetOwner(), MODE_ADMIN];
                    }
                    s("Set Up Listener");
                    s("Read settings..");
                    list lSet = llParseString2List(llGetObjectDesc(), ["^"],[]);
                    g_iSettingsMask = (integer)llList2String(lSet,0);
                    s("Load globals");
                    UpdateDSRequest(NULL, llGetNotecardLine("config",0), SetDSMeta(["read_config",0]));
                } else {
                    if(llGetSubString(d,0,0)!="#" && d!=""){
                        list lLine = llParseString2List(d,[" = "],[]);
                        UpdateDSRequest(NULL, llRequestUserKey(llList2String(lLine,0)), SetDSMeta(["get_user_key",llList2String(lLine,0), llList2String(lLine,1)]));
                    }
                    integer iLine = (integer)llList2String(lMeta,1);
                    iLine++;
                    UpdateDSRequest(r, llGetNotecardLine("Access", iLine), SetDSMeta(["read_access", iLine]));
                    s("Read Line: "+(string)iLine);
                }
            } else if(llList2String(lMeta,0) == "get_user_key"){
                DeleteDSReq(r);
                if((key)d == NULL){
                    llOwnerSay("ERROR: A user key was not found for "+llList2String(lMeta,1));
                } else {
                    g_lAccess += [d, (integer)llList2String(lMeta,2)];
                    s(llList2String(lMeta,1)+" added with access level "+llList2String(lMeta,2));
                }
            } else if(llList2String(lMeta,0) == "read_config"){
                if(d==EOF){
                    DeleteDSReq(r);
                    s("Completed channel reader");
                    s("Ready");
                    llSleep(5);
                    s("");
                    llWhisper(0, "Ready - "+(string)llGetFreeMemory()+" bytes free");

                    llMessageLinked(LINK_SET, LINK_SYNC_MENU, llList2Json(JSON_OBJECT, ["access", llList2Json(JSON_OBJECT, g_lAccess), "settings", g_iSettingsMask, "note", NOTE_CHANNEL, "board", MB_CHANNEL, "expire", EXPIRE_TIME, "categories", llList2Json(JSON_ARRAY, g_lCategories), "timer", g_iTimerNote, "sync", llList2Json(JSON_OBJECT, ["enabled", g_iSync, "out", g_iSyncDown, "in", g_iSyncUp, "delete", g_iSyncDelete]), "sacl", llList2Json(JSON_OBJECT, ["enable", g_iSACL, "tags", llList2Json(JSON_ARRAY, g_lGroupTags), "groups", llList2Json(JSON_ARRAY, g_lGroups)]), "update", g_iNewVer]), "");
                } else {
                    if(llGetSubString(d,0,0)=="#" || d=="")jump ovc;
                    list lTmp = llParseString2List(d,[" = "],[]);
                    string sOp = llList2String(lTmp,0);
                    string sVal;
                    string sArg;
                    switch(sOp)
                    {
                        case "Note":
                        {
                            NOTE_CHANNEL = (integer)llList2String(lTmp,1);
                            break;
                        }
                        case "Board":
                        {
                            MB_CHANNEL = (integer)llList2String(lTmp,1);
                            break;
                        }
                        case "Expire":
                        {
                            EXPIRE_TIME = (integer)llList2String(lTmp,1);
                            break;
                        }
                        case "Categories":
                        {
                            g_lCategories = llParseString2List(llList2String(lTmp,1), [", "],[]);
                            break;
                        }
                        case "TimerNoteEnabled":
                        {
                            g_iTimerNote=(integer)llList2String(lTmp,1);
                            break;
                        }
                        case "Sync":
                        {
                            g_iSync = (integer)llList2String(lTmp,1);

                            break;
                        }
                        case "SyncOutEnabled":
                        {
                            g_iSyncDown = (integer)llList2String(lTmp,1);
                            break;
                        }
                        case "SyncDeleteEnabled":
                        {
                            g_iSyncDelete = (integer)llList2String(lTmp,1);
                            break;
                        }
                        case "SyncInputEnabled":
                        {
                            g_iSyncUp = (integer)llList2String(lTmp,1);
                            break;
                        }
                        case "SecondaryACL":
                        {
                            g_iSACL=(integer)llList2String(lTmp,1);

                            break;
                        }
                        case "SACLTag":
                        {
                            g_lGroupTags += llList2String(lTmp,1);
                            break;
                        }
                        case "SACLGroup":
                        {
                            g_lGroups += llList2String(lTmp,1);
                            break;
                        }
                    }
                    
                    @ovc;
                    integer iLine = (integer)llList2String(lMeta,1);
                    s("Config line "+(string)iLine);
                    iLine++;
                    UpdateDSRequest(r, llGetNotecardLine("config", iLine), SetDSMeta(["read_config", iLine]));
                }
            }
        }
    }
    

    
    on_rez(integer t){
        llResetScript();
    }
    
}

state ingred
{
    state_entry(){
        llSetText("Message Board Settings\n-----\nYou can load me into a updated board", <0,1,0>,1);
        llListen(ingredient_channel, "","","");
    }
    
    on_rez(integer t){
        llListen(ingredient_channel, "", "", "");
    }
    
    changed(integer t){
        if(t&CHANGED_REGION_START){
            llListen(ingredient_channel, "", "", "");
        }
    }
    
    listen(integer c,string n,key i,string m){
        if(m == (string)llGetKey()){
            llWhisper(0, "Transfering notecards...");
            llGiveInventory(i, "Access");
            llGiveInventory(i, "config");
            llSleep(5);
            llDie();
        } else if(m == "scan"){
            llRegionSayTo(i,ingredient_channel+1,"RPMSGBOARD_SETTINGS");
        }
    }
    
    touch_start(integer t){
        llSay(ingredient_channel+1, "RPMSGBOARD_SETTINGS");
    }
}