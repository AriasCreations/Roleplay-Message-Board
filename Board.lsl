#include "MasterFile.lsl"



string BOARD_VERSION = "2.801.072722.1335";
string g_sActual;

integer MB_CHANNEL = 0x61195fc;
integer NOTE_CHANNEL = 0x61195fb;

integer     LINK_MENU_DISPLAY = 300;
integer     LINK_MENU_REMOVE = 310; 
integer     LINK_MENU_RETURN = 320;
integer     LINK_MENU_TIMEOUT = 330;
integer     LINK_MENU_CHANNEL = 303; // Returns from the dialog module to inform what the channel is
integer     LINK_MENU_ONLYCHANNEL = 302; // Sent with a ident to make a channel. No dialog will pop up, and it will expire just like any other menu if input is not received. 



Menu(key kAv, string sText, list lButtons, string sIdent)
{
    llMessageLinked(LINK_THIS, LINK_MENU_DISPLAY, llDumpList2String([sIdent, "TRUE", sText, llDumpList2String(lButtons, "~")], "|"), kAv);
}
GetArbitraryData(key kAv, string sText, string sIdent){
    llMessageLinked(LINK_THIS, LINK_MENU_DISPLAY, llDumpList2String([sIdent, "FALSE", sText, ""], "|"), kAv);
}

integer Invert(integer iMask, integer iBit)
{
    if(iMask&iBit)iMask-=iBit;
    else iMask+=iBit;

    return iMask;
}

integer g_iStartup=1;
integer g_iNewVer=0;

integer g_iSyncHandle=-1;

integer g_iSync=0;
integer g_iSyncDown=0;
integer g_iSyncUp=0;


integer EXPIRE_TIME = 120;

integer PERM_DELETE = 1;
integer PERM_ADMIN = 2;
integer PERM_TEAR_DOWN = 4;

integer MODE_ADMIN = 10;
integer MODE_CFG = 5;
integer MODE_DEL = 3;
integer MODE_READ = 1;

integer Mask_GroupOnly = 1;
integer Mask_Deletable = 2;
integer Mask_ListOnly = 4;
integer Mask_TearDown = 8;
integer Mask_Create = 16;
integer Mask_DeleteOwn = 32;
integer FLAG_ALIVE = 64; // Always on.

integer g_iSettingsMask = 0; // read from field 1, description

list g_lReqs;
string URL = "";
Send(string Req,string method){
    g_lReqs += [Req,method];
    Sends();
}
Sends(){
    if(g_kCurrentReq == NULL_KEY){
        DoNextRequest();
    }
    //g_lReqs += [llHTTPRequest(URL + llList2String(lTmp,0), [HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/x-www-form-urlencoded"], llDumpList2String(llList2List(lTmp,1,-1), "?"))];
}
key g_kCurrentReq = NULL_KEY;
integer DEBUG=FALSE;
DoNextRequest(){
    if(llGetListLength(g_lReqs)==0)return;
    list lTmp = llParseString2List(llList2String(g_lReqs,0),["?"],[]);
    if(DEBUG)llSay(0, "SENDING REQUEST: "+URL+llList2String(g_lReqs,0));
    
    string append = "";
    if(llList2String(g_lReqs,1) == "GET")append = "?"+llDumpList2String(llList2List(lTmp,1,-1),"?");
    
    g_kCurrentReq = llHTTPRequest(URL + llList2String(lTmp,0) + append, [HTTP_METHOD, llList2String(g_lReqs,1), HTTP_MIMETYPE, "application/x-www-form-urlencoded"], llDumpList2String(llList2List(lTmp,1,-1),"?"));
}


s(string m){
    if(m!="")llSetText(">Message Board<\n"+m,<0,1,1>,1);
    
    if(m=="")llSetText("",ZERO_VECTOR,0);
    
}

key g_kAccessReader;
integer g_iAccessLine;
list g_lAccess;

Serialize(){
    llSetObjectDesc(llDumpList2String([g_iSettingsMask], "^"));
}
string Checkbox(integer a,string Lbl){
    if(a)return "[X] "+Lbl;
    else return "[ ] "+Lbl;
}
integer bool(integer test){
    if(test!=0)return TRUE;
    return FALSE;
}

Main(key kID){
    // Admin menu
    list lButtons = [];
    string sPrompt = "Message Board: "+BOARD_VERSION+"\nCopyright 2022 ZNI Creations\n";
    integer user_mode = llList2Integer(g_lAccess, llListFindList(g_lAccess, [(string)kID])+1);
    if(g_iNewVer){
        sPrompt+="\n*UPDATE AVAILABLE*";
    }
    if(user_mode == MODE_DEL || user_mode == MODE_READ){
        // create a note instead
        MakeNote(kID);
    } else {
        if(user_mode >= MODE_CFG){
            lButtons += [Checkbox(bool((g_iSettingsMask & Mask_GroupOnly)), "Group Only"), Checkbox(bool((g_iSettingsMask&Mask_Deletable)),"Deletable"), "NEW NOTE", Checkbox(bool((g_iSettingsMask&Mask_Create)), "Create"), Checkbox(bool((g_iSettingsMask&Mask_DeleteOwn)), "DeleteOwn"), "*HELP*"];
            sPrompt+="\n\nGroup Only => Only allow reading by group members\nDeletable => If enabled all who can read, can delete. If off, only those defined in Access notecard\nCreate => Allow or disallow all to create notes regardless of ACL or group\nDeleteOwn => Allows note poster to delete their own notes";
        }
        if(user_mode == MODE_ADMIN){
            lButtons += ["List Access", Checkbox(bool((g_iSettingsMask & Mask_ListOnly)), "List Only"), Checkbox(bool((g_iSettingsMask & Mask_TearDown)), "TearDown"), "Delete All"];
            sPrompt+="\nList Only => Only those with read permissions or above can read the notes or perform any actions\nDelete All => Deletes all notes";
        }
    }

    Menu(kID, sPrompt, lButtons, "menu~main");
    
}

HelpMenu(key kID)
{
    list lButtons = ["*main*"];
    string sPrompt = "Message Board: "+BOARD_VERSION+"\n \n*Help Menu*";

    integer user_mode = llList2Integer(g_lAccess, llListFindList(g_lAccess, [(string)kID])+1);
    if(user_mode == MODE_ADMIN && kID == llGetOwner())
    {
        // Add update button
        lButtons += ["CheckUpdate"];
    }
    lButtons += ["Discord.."];

    Menu(kID, sPrompt, lButtons, "menu~help");
}

vector g_vTouchPos;
key g_kNote;
integer g_iNoteBootChannel;
key g_kNoteCreator;

list g_lCategories;
MakeNote(key kID){
    g_kNoteCreator = kID;
    list lAppend;
    if(g_iTimerNote)lAppend += ["# Timer"];
    
    Menu(kID, "Select a category", g_lCategories+lAppend, "menu~category");
}

GetNoteText(key kID){
    g_kNoteCreator=kID;
    llMessageLinked(LINK_SET, LINK_MENU_ONLYCHANNEL, "note~bootchan", "");
}
RezNote()
{
    if(g_iSyncOp != 0)g_vTouchPos = (g_vTouchPos*llGetRot())+llGetPos();
    llRezObject("NOTE", g_vTouchPos, ZERO_VECTOR, llGetRot(), g_iNoteBootChannel);
}

key g_kConfigReader;
integer g_iConfigLine;

string g_sCategory;
integer g_iTimerNote=0;



CopyPosRot(key ID){
    list lTmp = llGetObjectDetails(ID, [OBJECT_POS, OBJECT_ROT]);
    llSetRegionPos(llList2Vector(lTmp,0));
    llSetRot(llList2Rot(lTmp,1));
}

key g_kUser;
string g_sTimeParams;
integer ingredient_channel = -8392888;
integer g_iUser;
key g_kID;
string g_sPath;
string g_sDiscord= "https://discord.gg/DrWwmMT9WJ";

integer g_iSyncOp;
string g_sSyncCommandStr;


CheckUpdate()
{
    
    llSay(0, "Update checker removed");

}

Question(string sQuestion, string sPath, list lButtons, string sHeader){
    if(lButtons!=[])
        llDialog(g_kUser, "["+sHeader+"]\n[->Roleplay Message Board "+BOARD_VERSION+"<-]\n\n© ZNI Creations 2022\n\n"+sQuestion, lButtons, g_iUser);
    else
        llTextBox(g_kUser, "["+sHeader+"]\n[->Roleplay Message Board "+BOARD_VERSION+"<-]\n\n© ZNI Creations 2022\n\n"+sQuestion, g_iUser);
    
    g_sPath = sPath;
}
default
{
    state_entry()
    {
        llSay(0, "Stand by..");
        g_kID = (key)llGetObjectDesc();
        if(g_kID == "" || g_kID == "(No Description)" || g_kID == "FIRSTREZ" || g_kID == "0"){
            llSay(0, "First Rez!");
            state setup;
        }
        state ready;
    }
    on_rez(integer t){
        llResetScript();
    }
    
    changed(integer t){
        if(t&CHANGED_REGION_START)llResetScript();
    }
    /*
    Currently this product does not use server side memory storage.
    http_response(key r,integer s,list m,string b){
        if(r==g_kCurrentReq){
            g_kCurrentReq=NULL_KEY;
            g_lReqs = llDeleteSubList(g_lReqs,0,1);
            
            list lTmp = llParseString2List(b,[";;",";"],[]);
            string Script = llList2String(lTmp,0);
            if(Script == "Get_Product_Data"){
                if(llList2String(lTmp,1)=="Settings"){
                    if(llList2String(lTmp,2) == "0"){
                        llWhisper(0, "No settings found");
                        state ready;
                    } else {
                        list lTmp2 = llParseStringKeepNulls(llBase64ToString(llList2String(lTmp,2)), ["~"],[]);
                        g_sPackIngred = llList2String(lTmp2,0);
                        g_iQuantity = (integer)llList2String(lTmp2,1);
                        g_iSecurity = (integer)llList2String(lTmp2,2);
                        state ready;
                    }
                }
            }
            
            Sends();
        }
    }*/
}

state setup
{
    state_entry(){
        llSetText("First Rez\n* Setup mode",<1,0,0>,1);
        g_kUser = llGetOwner();
        g_iUser = llRound(llFrand(5487358));
        llListen(g_iUser,"",g_kUser,"");
        Question("Is this a new message board, or an updated one?", "/setup", ["New", "Update"], "SETUP");
    }
    on_rez(integer t){
        llResetScript();
    }
    changed(integer t){
        if(t&CHANGED_REGION_START)llResetScript();
        else if(t&CHANGED_OWNER)llResetScript();
    }
    listen(integer c,string n,key i,string m){
        if(c == g_iUser){
            if(m == "New"){
                llSay(0, "Thank you for your purchase of a ZNI Creations product!\nPlease consider joining our discord for support: "+g_sDiscord);
                g_kID = (string)FLAG_ALIVE;
                llSetObjectDesc((string)g_kID);
                llResetScript();
            } else if(m == "Update"){
                llSay(0, "Starting upgrade process. Please consider joining our discord for support: "+g_sDiscord);

                llWhisper(0, "Deleting existing sample notecards...");
                llRemoveInventory("Access");
                llRemoveInventory("config");
                llSleep(1);
                llWhisper(0, "Scanning for old board...");
                
                llListen(ingredient_channel+1, "", "", "");
                llSay(0, "Ready - You can now touch the old board to transfer your settings");
            }
        } else if(c == ingredient_channel+1){
            if(m == "RPMSGBOARD_SETTINGS" || m == "rezzed RPMSGBOARD_SETTINGS"){
                CopyPosRot(i);
                llSetObjectDesc(llList2String(llGetObjectDetails(i,[OBJECT_DESC]),0));
                llRegionSayTo(i,ingredient_channel,(string)i);
                llWhisper(0, "Settings loaded!");
                llResetScript();
            }
        }
    }
}


state ready
{
    state_entry()
    {
        s("Starting up");
        //g_kAccessReader = llGetNotecardLine("Access", g_iAccessLine);
        UpdateDSRequest(NULL, llGetNotecardLine("Access", 0), "read_access:0");
        
        s("Reading access lists");
        
        g_iStartup=1;
        CheckUpdate();
    }
    
    object_rez(key id){
        llSleep(2);
        llRegionSayTo(id, g_iNoteBootChannel, llList2Json(JSON_OBJECT, ["dest", id, "type", "init", "board", MB_CHANNEL, "note", NOTE_CHANNEL, "expire", EXPIRE_TIME, "sync", g_iSync]));
    }
    
    changed(integer t){
        if(t&CHANGED_INVENTORY || t&CHANGED_REGION_START){
            llResetScript();
        }
    }
    
    dataserver(key r,string d){
        if(HasDSRequest(r)!=-1){
            string meta = GetDSMeta(r);
            list lMeta = llParseString2List(meta,[":"],[]);
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
                    UpdateDSRequest(NULL, llGetNotecardLine("config",0), "read_config:0");
                } else {
                    if(llGetSubString(d,0,0)!="#" && d!=""){
                        list lLine = llParseString2List(d,[" = "],[]);
                        UpdateDSRequest(NULL, llRequestUserKey(llList2String(lLine,0)), "get_user_key:"+llList2String(lLine,0)+":"+llList2String(lLine,1));
                    }
                    integer iLine = (integer)llList2String(lMeta,1);
                    iLine++;
                    UpdateDSRequest(r, llGetNotecardLine("Access", iLine), "read_access:"+(string)iLine);
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
                    llListen(MB_CHANNEL, "", "", "");
                    s("Ready");
                    llSleep(5);
                    s("");
                    llWhisper(0, "Ready");
                } else {
                    if(llGetSubString(d,0,0)=="#")jump ovc;
                    list lTmp = llParseString2List(d,[" = "],[]);
                    if(llList2String(lTmp,0) == "Note"){
                        NOTE_CHANNEL = (integer)llList2String(lTmp,1);
                    } else if(llList2String(lTmp,0) == "Board"){
                        MB_CHANNEL = (integer)llList2String(lTmp,1);
                    } else if(llList2String(lTmp,0) == "Expire"){
                        EXPIRE_TIME = (integer)llList2String(lTmp,1);
                    } else if(llList2String(lTmp,0) == "Categories"){
                        g_lCategories = llParseString2List(llList2String(lTmp,1), [", "],[]);
                    } else if(llList2String(lTmp,0) == "TimerNoteEnabled"){
                        g_iTimerNote=1;
                    } else if(llList2String(lTmp,0) == "Sync"){
                        g_iSync = (integer)llList2String(lTmp,1);

                        if(g_iSync)
                        {
                            if(g_iSyncHandle!=-1)llListenRemove(g_iSyncHandle);
                            g_iSyncHandle = llListen(g_iSync, "", "", "");
                        }
                    } else if(llList2String(lTmp,0) == "SyncOutEnabled"){
                        g_iSyncDown = (integer)llList2String(lTmp,1);
                    } else if(llList2String(lTmp,0) == "SyncInputEnabled"){
                        g_iSyncUp = (integer)llList2String(lTmp,1);
                    }
                    
                    @ovc;
                    integer iLine = (integer)llList2String(lMeta,1);
                    s("Config line "+(string)iLine);
                    iLine++;
                    UpdateDSRequest(r, llGetNotecardLine("config", iLine), "read_config:"+(string)iLine);
                }
            }
        }
    }
    

    touch_start(integer total_number)
    {
        g_vTouchPos = llDetectedTouchPos(0);
        
        if(llListFindList(g_lAccess, [(string)llDetectedKey(0)])!=-1){
            Main(llDetectedKey(0));
            //llWhisper(0, "admin menu");
        }else {
            if(g_iSettingsMask&Mask_GroupOnly){
                if(llSameGroup(llDetectedKey(0))){
                    MakeNote(llDetectedKey(0));
                    //llWhisper(0, "make new note 0");
                }
            } else if(g_iSettingsMask & Mask_ListOnly){
                if(llListFindList(g_lAccess, [(string)llDetectedKey(0)])!=-1)
                {
                    //llWhisper(0, "make note 2");
                    MakeNote(llDetectedKey(0));
                }
            }else if(g_iSettingsMask & Mask_Create){
                // allow any others to create a note
                //llWhisper(0, "make note 3");
                MakeNote(llDetectedKey(0));
            } else {
                //llWhisper(0, "error");
            }
        }
    }
    
    link_message(integer s,integer n,string m,key i)
    {
        if(n == LINK_MENU_TIMEOUT)
        {
            llInstantMessage(i, "Menu Timed out!");
        } else if(n == LINK_MENU_CHANNEL)
        {
            if(i == "note~bootchan")
            {
                g_iNoteBootChannel = (integer)m;
                RezNote();
            }
        } else if(n == LINK_MENU_RETURN)
        {
            list returnMenu = llParseString2List(m,["|"],[]);
            string sIdent = llList2String(returnMenu,0);
            string sButton = llList2String(returnMenu,1);

            integer iMenuType;
            integer iRespring;
            switch(sIdent)
            {
                case "menu~help":{
                    iMenuType=1;
                    iRespring=1;
                    switch(sButton){
                        case "*main*":
                        {
                            iRespring=0;
                            Main(i);
                            break;
                        }
                        case "Discord..":
                        {
                            llLoadURL(i, "Join the discord?", g_sDiscord);
                            iRespring=0;
                            break;
                        }
                        case "CheckUpdate":
                        {
                            // Do update check
                            llWhisper(0, "Checking for update...");
                            CheckUpdate();
                            break;
                        }
                        case "-exit-":
                        {
                            llMessageLinked(LINK_SET, LINK_MENU_REMOVE, "", i);
                            iRespring=0;
                            break;
                        }
                    }
                    break;
                }
                case "menu~main":{
                    iMenuType=0;
                    iRespring=1;
                    switch(sButton)
                    {
                        case "-exit-":
                        {
                            llMessageLinked(LINK_SET, LINK_MENU_REMOVE, "", i);
                            iRespring=0;
                            break;
                        }
                        case Checkbox(bool((g_iSettingsMask & Mask_GroupOnly)), "Group Only"):
                        {
                            g_iSettingsMask = Invert(g_iSettingsMask, Mask_GroupOnly);
                            Serialize();
                            break;
                        }
                        case Checkbox(bool((g_iSettingsMask & Mask_Deletable)), "Deletable"):
                        {
                            g_iSettingsMask = Invert(g_iSettingsMask, Mask_Deletable);
                            Serialize();
                            break;
                        }
                        case "NEW NOTE":
                        {
                            MakeNote(i);
                            iRespring=0;
                            break;
                        }
                        case Checkbox(bool((g_iSettingsMask & Mask_ListOnly)), "List Only"):
                        {
                            g_iSettingsMask = Invert(g_iSettingsMask, Mask_ListOnly);
                            Serialize();
                            break;
                        }
                        case "List Access":
                        {
                            integer x=0;
                            integer e = llGetListLength(g_lAccess);
                            for(x=0;x<e;x+=2){
                                llRegionSayTo(i,0,SLURL(llList2String(g_lAccess,x))+" = "+llList2String(g_lAccess, x+1));
                            }
                            break;
                        }
                        case Checkbox(bool((g_iSettingsMask & Mask_TearDown)), "TearDown"):
                        {
                            g_iSettingsMask = Invert(g_iSettingsMask, Mask_TearDown);
                            Serialize();

                            break;
                        }

                        case Checkbox(bool((g_iSettingsMask & Mask_Create)), "Create"):
                        {
                            g_iSettingsMask = Invert(g_iSettingsMask, Mask_Create);
                            Serialize();

                            break;
                        }

                        case Checkbox(bool((g_iSettingsMask & Mask_DeleteOwn)), "DeleteOwn"):
                        {
                            g_iSettingsMask = Invert(g_iSettingsMask, Mask_DeleteOwn);
                            Serialize();

                            break;
                        }

                        case "Delete All":
                        {
                            llRegionSay(NOTE_CHANNEL, llList2Json(JSON_OBJECT, ["dest", NULL_KEY, "cmd", "delete"]));
                            break;
                        }
                        case "*HELP*":
                        {
                            iRespring=0;
                            HelpMenu(i);
                            break;
                        }
                    }
                    break;
                }
                case "menu~category":
                {
                    if(sButton == "-exit-")
                    {
                        llMessageLinked(LINK_SET,LINK_MENU_REMOVE,"",i);
                        iRespring=0;
                        break;
                    }
                    if(g_iTimerNote && sButton == "# Timer"){
                        g_sCategory="TIMER";
                        GetArbitraryData(i, "Please specify the timer using the following format:\n \n#d#h#m#s\nExample: 2s = 2 seconds\n1m5s = 1 minute 5 seconds", "note~timer" );
                    }else {
                        g_sCategory=sButton;
                        GetNoteText(i);
                    }
                    break;
                }
                case "note~bootchan":
                {
                    if(llJsonGetValue(sButton,["cmd"]) == "note_is_ready")
                    {
                        g_kNote=i;
                        if(g_iSyncOp == 1){
                            // Ok
                            // Note is now ready, proceed with note initialization from commandstring
                            llRegionSayTo(g_kNote, NOTE_CHANNEL, llList2Json(JSON_OBJECT, ["dest", g_kNote, "rotate", llGetRot()]));

                            llRegionSayTo(g_kNote, NOTE_CHANNEL, llList2Json(JSON_OBJECT, ["dest", g_kNote]+llJson2List(llJsonGetValue(g_sSyncCommandStr,["note"]))));

                            g_iSyncOp = 0;
                            g_sSyncCommandStr="{}";

                            break;
                        }
                        GetArbitraryData(g_kNoteCreator,"What message do you want to post?", "note~text");
                    }
                    break;
                }
                case "note~text":
                {
                    llRegionSayTo(g_kNote, NOTE_CHANNEL, llList2Json(JSON_OBJECT, ["dest", g_kNote, "rotate", llGetRot()]));
                    integer iTimerNote=0;
                    if(g_sCategory=="TIMER")iTimerNote=1;
                    string sFinalNoteText = llStringToBase64("Type of note: "+g_sCategory+"\n\n"+sButton);

                    list lNoteExtraParams = ["type", "set", "poster", llKey2Name(i), "note", sFinalNoteText, "timer", iTimerNote, "timer_params", g_sTimeParams, "kID", i];

                    llRegionSayTo(g_kNote, NOTE_CHANNEL, llList2Json(JSON_OBJECT, ["dest", g_kNote]+lNoteExtraParams));

                    if(g_iSyncDown){
                        // Perform the sync
                        vector vLocal = (g_vTouchPos-llGetPos());
                        if(llGetRot()!=ZERO_ROTATION)vLocal /= llGetRot(); // Get the true local
                        string sCommandStr = llList2Json(JSON_OBJECT, ["pos", vLocal, "note", llList2Json(JSON_OBJECT, lNoteExtraParams)]);
                        llRegionSay(g_iSync, llList2Json(JSON_OBJECT, ["op", "make", "cmd", sCommandStr]));
                    }

                    break;
                }
            }

            if(iMenuType==0)
            {
                if(iRespring)Main(i);
            } else if(iMenuType==1)
            {
                if(iRespring)HelpMenu(i);
            }
        }
    }


    listen(integer c,string n,key i,string m){
        if(c == MB_CHANNEL){
            if(llJsonGetValue(m,["cmd"])=="get_auth"){
                string Note_Desc = llList2String(llGetObjectDetails(i, [OBJECT_DESC]),0);
                key kTmp = (key)llJsonGetValue(m,["id"]);
                integer iPerms=0;
                if(g_iSettingsMask & Mask_TearDown)iPerms += PERM_TEAR_DOWN;
                string access="denied";
                if(g_iSettingsMask & Mask_ListOnly){
                 //   llSay(0, "list only enabled.");
                    if(llListFindList(g_lAccess,[(string)kTmp])==-1)return;
                    else{
                        access = "granted";
                    }
                   // llSay(0, "exit list only check");
                } else access="granted";
                if(g_iSettingsMask&Mask_Deletable)iPerms+=PERM_DELETE;
                
                if(g_iSettingsMask&Mask_DeleteOwn && !(iPerms&PERM_DELETE) && (Note_Desc == llKey2Name(kTmp)+"'s note")){
                    iPerms+=PERM_DELETE; // creator's note. Allow self delete due to option being permitted in board settings
                }
                
                if(g_iSettingsMask&Mask_GroupOnly){
                    if(llSameGroup(kTmp)){
                        // get permissions for user
                        integer AccessPerms = llList2Integer(g_lAccess, llListFindList(g_lAccess,[(string)kTmp])+1);
                        if(AccessPerms  == MODE_ADMIN || AccessPerms == MODE_CFG){
                            iPerms+= PERM_ADMIN;
                        }else if(AccessPerms == MODE_DEL){
                            if(!(iPerms&PERM_DELETE))iPerms+=PERM_DELETE;
                        } else if(AccessPerms == MODE_READ){
                            access="granted";
                        }
                       // llSay(0, "group only with permissions: "+(string)iPerms);
                        
                        llRegionSay( NOTE_CHANNEL, llList2Json(JSON_OBJECT, ["dest", i, "access", access, "perms", iPerms, "user", kTmp]));
                    }
                } else {
                    // all can read
                    // check permissions
                    
                    integer AccessPerms = llList2Integer(g_lAccess, llListFindList(g_lAccess,[(string)kTmp])+1);
                    if(AccessPerms  == MODE_ADMIN || AccessPerms == MODE_CFG){
                        iPerms+= PERM_ADMIN;
                    }else if(AccessPerms == MODE_DEL){
                        if(!(iPerms&PERM_DELETE))iPerms+=PERM_DELETE;
                    } else if(AccessPerms == MODE_READ){
                        access="granted";
                    }
                        
                    //llSay(0, "non-group with permissions: "+(string)iPerms);
                    llRegionSay( NOTE_CHANNEL, llList2Json(JSON_OBJECT, ["dest", i, "access", access, "perms", iPerms, "user", kTmp]));
                }
            }
                        
        } else if(c == g_iSync)
        {
            if(llJsonGetValue(m, ["op"]) == "delete")
            {
                if(!g_iSyncDown){
                    //llSay(0, "SyncOut is disabled");
                    return;
                }

                // Delete the indicated note by SubID
                
                llRegionSay(NOTE_CHANNEL, llList2Json(JSON_OBJECT, ["type", "deletebyid", "subid", llJsonGetValue(m,["subid"]), "dest", NULL_KEY]));
            } else if(llJsonGetValue(m,["op"])=="make"){
                if(!g_iSyncUp)return;

                // New note creation, store this in the operation value
                g_iSyncOp=1;
                g_sSyncCommandStr = llJsonGetValue(m,["cmd"]);
                g_vTouchPos = (vector)(llJsonGetValue(m,["cmd", "pos"]));
                // First we must now begin the note creation process
                GetNoteText(llGetKey());
            }
        }
    }
    
    on_rez(integer t){
        llResetScript();
    }
    
    http_response(key r,integer s,list m,string b){
        if(r == g_kCurrentReq){
            g_kCurrentReq=NULL;
            g_lReqs = llDeleteSubList(g_lReqs,0,1);
            
            // UPDATE CHECKER / REQUESTER CODE REMOVED
            
            Sends();
        }
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