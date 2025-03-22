#include "src/includes/shared.lsl"


default
{
    state_entry()
    {

    }
    
    link_message(integer s,integer n,string m,key i)
    {
        if(n == LINK_MENU_TIMEOUT)
        {
            if(llGetAgentSize(i)!=ZERO_VECTOR)
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
                            llMessageLinked(LINK_SET,LINK_CHECK_UPDATE,"","");
                            //CheckUpdate();
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
                        case Checkbox(bool((g_iSettingsMask & Mask_GroupOnly)), "Obj Group"):
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
                        case Checkbox(bool((g_iSettingsMask & Mask_ListOnly)), "ACL Only"):
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

                        case Checkbox(bool((g_iSettingsMask & Mask_ChattyNotes)), "SilentNotes"):
                        {
                            g_iSettingsMask = Invert(g_iSettingsMask, Mask_ChattyNotes);
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
                        case "* SACL *":
                        {
                            iRespring=0;
                            SACLMenu(i);
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
                        integer iTimer = 0;
                        if(g_sCategory == "TIMER") iTimer=1;
                        llRegionSayTo(g_kNote, NOTE_CHANNEL, llList2Json(JSON_OBJECT, ["author", g_kNoteCreator, "dest", g_kNote, "rotate", llGetRot(), "timer", iTimer, "timer_params", g_sTimeParams, "silent", ((g_iSettingsMask & Mask_ChattyNotes)), "cmd", "load_text"]));
                        //GetArbitraryData(g_kNoteCreator,"What message do you want to post?", "note~text");

                        // MAR 22 2025 : As of this version, Sync is deferred to happen only when the note text is finalized. This is specifically to bypass the LSL restrictions on textbox length. This will allow the note to be created, and then the sync to be performed after the note is created.
                    }
                    break;
                }
                case "menu~sacl":
                {
                    iMenuType = 2;
                    iRespring=1;
                    switch(sButton)
                    {
                        case "*main*":
                        {
                            iRespring=0;
                            Main(i);
                            break;
                        }
                        case Checkbox((g_iSettingsMask&Mask_ExtraGroups), "ExtraGroups"):
                        {
                            g_iSettingsMask = Invert(g_iSettingsMask, Mask_ExtraGroups);
                            Serialize();
                            break;
                        }
                        case Checkbox((g_iSettingsMask & Mask_GroupTags), "UseTags"):
                        {
                            g_iSettingsMask = Invert(g_iSettingsMask, Mask_GroupTags);
                            Serialize();
                            break;
                        }
                        case "-exit-":
                        {
                            iRespring=0;
                            break;
                        }
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
            } else if(iMenuType == 2)
            {
                if(iRespring)SACLMenu(i);
            }
        } else if(n == LINK_SYNC_MENU)
        {
            //llMessageLinked(LINK_SET, LINK_SYNC_MENU, llList2Json(JSON_OBJECT, ["access", llList2Json(JSON_OBJECT, g_lAccess), "settings", g_iSettingsMask, "note", NOTE_CHANNEL, "board", MB_CHANNEL, "expire", EXPIRE_TIME, "categories", llList2Json(JSON_ARRAY, g_lCategories), "timer", g_iTimerNote, "sync", llList2Json(JSON_OBJECT, ["enabled", g_iSync, "out", g_iSyncDown, "in", g_iSyncUp]), "sacl", llList2Json(JSON_OBJECT, ["enable", g_iSACL, "tags", llList2Json(JSON_ARRAY, g_lGroupTags), "groups", llList2Json(JSON_ARRAY, g_lGroups)])]), "");
            /*
{
    "access": {
        "27a0ae67-30d9-4fbc-b9fb-fd388c98c202": 10
    },
    "settings": 254,
    "note": 5748376,
    "board": 14327190,
    "expire": 130,
    "categories": [
        "Request",
        "Note",
        "To Do",
        "Thank You!",
        "Important"
    ],
    "timer": 1,
    "sync": {
        "enabled": 3689269,
        "out": 1,
        "in": 1
    },
    "sacl": {
        "enable": 1,
        "tags": [
            "Test Group Tag",
            "Tag 2",
            "Developer [ZNI]"
        ],
        "groups": [
            "e40d4a13-6921-780f-15a8-46daa49b51c2"
        ]
    },
    "update": 1
}
            */
            //llOwnerSay(m);


            g_lAccess = llJson2List(llJsonGetValue(m,["access"]));
            g_iSettingsMask = (integer)llJsonGetValue(m,["settings"]);
            NOTE_CHANNEL = (integer)llJsonGetValue(m,["note"]);
            MB_CHANNEL = (integer)llJsonGetValue(m,["board"]);
            EXPIRE_TIME = (integer)llJsonGetValue(m,["expire"]);
            g_lCategories = llJson2List(llJsonGetValue(m,["categories"]));
            g_iTimerNote = (integer)llJsonGetValue(m,["timer"]);
            g_iSync = (integer)llJsonGetValue(m,["sync", "enabled"]);
            g_iSyncDown = (integer)llJsonGetValue(m,["sync", "out"]);
            g_iSyncUp = (integer)llJsonGetValue(m,["sync", "in"]);
            g_iSyncDelete = (integer)llJsonGetValue(m,["sync","delete"]);
            g_iSACL = (integer)llJsonGetValue(m,["sacl", "enable"]);
            g_lGroupTags = llJson2List(llJsonGetValue(m,["sacl", "tags"]));
            g_lGroups = llJson2List(llJsonGetValue(m,["sacl", "groups"]));
            g_iNewVer = (integer)llJsonGetValue(m,["update"]);


            llListen(MB_CHANNEL, "", "", "");
            if(g_iSync)
            {
                if(g_iSyncHandle!=-1)llListenRemove(g_iSyncHandle);
                g_iSyncHandle = llListen(g_iSync, "", "", "");
            }

            // - Do a sanity checks here -
            if((g_iSettingsMask & Mask_ExtraGroups) || (g_iSettingsMask & Mask_GroupTags)){
                if(!g_iSACL){
                    llOwnerSay("SANITY CHECK: You had enabled extra groups, or using tags, but it appears you have disabled the SACL feature in the notecard. I have disabled both options in the settings automatically");
                    g_iSettingsMask = UnsetBit(g_iSettingsMask, Mask_ExtraGroups);
                    g_iSettingsMask = UnsetBit(g_iSettingsMask, Mask_GroupTags);

                    Serialize();
                }
            }

            llWhisper(0, llGetScriptName()+" is now ready - "+(string)llGetFreeMemory()+" bytes free");
        }
    }


    object_rez(key id){
        llSleep(3);
        if(g_kToucher != NULL_KEY){
            // We are in the temporary authorization stage still
            llRegionSayTo(id, g_iTouchChan, llList2Json(JSON_OBJECT, ["cmd", "pair", "packet", llList2Json(JSON_OBJECT, ["target", g_kToucher, "callback", g_iTouchChan])]));
            return;
        }
        llRegionSayTo(id, g_iNoteBootChannel, llList2Json(JSON_OBJECT, ["dest", id, "type", "init", "board", MB_CHANNEL, "note", NOTE_CHANNEL, "expire", EXPIRE_TIME, "sync", g_iSync]));
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
            }
            if(g_iSettingsMask & Mask_ExtraGroups){
                // Spawn the extra group detector
                // We must pair with this object delicately
                // - Check if tags are also set to enforced -
                if(g_iSettingsMask & Mask_GroupTags){
                    string tagText = llList2String(llGetObjectDetails(llDetectedKey(0), [OBJECT_GROUP_TAG]),0);
                    if(llListFindList(g_lGroupTags, [tagText])==-1)
                    {
                        return; // Authorization not found!
                    }
                }
                g_kToucher = llDetectedKey(0);
                g_iTouchChan = llRound(llFrand(0xFFFF));
                g_iTouchTemp = llListen(g_iTouchChan, "", "", "");
                g_iDetectMode=1;
                llRezObject(AUTODETECT_OBJECT, llGetPos(), ZERO_VECTOR, llGetRot(), g_iTouchChan);
            } else if(g_iSettingsMask & Mask_GroupTags){
                string tagText = llList2String(llGetObjectDetails(llDetectedKey(0), [OBJECT_GROUP_TAG]),0);
                if(llListFindList(g_lGroupTags, [tagText])==-1)
                {
                    return; // Authorization not found!
                }else {
                    MakeNote(llDetectedKey(0)); // No requirement to spawn the extra group detection
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


    listen(integer c,string n,key i,string m){
        if(c == MB_CHANNEL){
            if(llJsonGetValue(m,["cmd"])=="get_auth"){
                string Note_Desc = llList2String(llGetObjectDetails(i, [OBJECT_DESC]),0);
                key kTmp = (key)llJsonGetValue(m,["id"]);
                integer iPerms=0;
                if(g_iSettingsMask & Mask_TearDown)iPerms += PERM_TEAR_DOWN;
                string access="denied";
                if(g_iSettingsMask & Mask_ListOnly){ /// Only ACL
                 //   llSay(0, "list only enabled.");
                    if(llListFindList(g_lAccess,[(string)kTmp])==-1){
                        // Allow to continue to process the SACL functions
                    }
                    else{
                        access = "granted";
                    }
                   // llSay(0, "exit list only check");
                } else access="granted";
                if(g_iSettingsMask&Mask_Deletable)iPerms+=PERM_DELETE;
                
                if(g_iSettingsMask&Mask_DeleteOwn && !(iPerms&PERM_DELETE) && (Note_Desc == llKey2Name(kTmp)+"'s note")){
                    iPerms+=PERM_DELETE; // creator's note. Allow self delete due to option being permitted in board settings
                }

                if(access=="denied" && (g_iSettingsMask & Mask_ListOnly))
                {
                    if (g_iSettingsMask & Mask_ExtraGroups)
                    {
                        if(g_iSettingsMask & Mask_GroupTags){

                            string tagText = llList2String(llGetObjectDetails(kTmp, [OBJECT_GROUP_TAG]),0);
                            if(llListFindList(g_lGroupTags, [tagText])==-1)
                            {
                                //llOwnerSay("Tag not found");
                                // Group tag not ok, do not permit access
                                return;
                            } //else llOwnerSay("Tag OK!");
                        }
                        // Extra group detection required to proceed
                        g_kReadAccessReturn = i;
                        g_iReadPerms = iPerms; // temporarily store the permissions calculated here
                        integer AccessPerms = llList2Integer(g_lAccess, llListFindList(g_lAccess,[(string)kTmp])+1);
                        if(AccessPerms  == MODE_ADMIN || AccessPerms == MODE_CFG){
                            iPerms+= PERM_ADMIN;
                        }else if(AccessPerms == MODE_DEL){
                            if(!(iPerms&PERM_DELETE))iPerms+=PERM_DELETE;
                        } else if(AccessPerms == MODE_READ){
                            access="granted";
                        }
                        // We do not care right now about the "ACCESS" flag
                        g_kToucher = kTmp;
                        g_iTouchChan = llRound(llFrand(0xFFFF));
                        g_iTouchTemp = llListen(g_iTouchChan, "", "", "");
                        g_iDetectMode=2;
                        g_kReadReturn = i;
                        llRezObject(AUTODETECT_OBJECT, llGetPos(), ZERO_VECTOR, llGetRot(), g_iTouchChan);
                        return;
                    } else if(g_iSettingsMask & Mask_GroupTags)
                    {
                        
                        string tagText = llList2String(llGetObjectDetails(kTmp, [OBJECT_GROUP_TAG]),0);
                        if(llListFindList(g_lGroupTags, [tagText])==-1)
                        {
                            //llOwnerSay("No tag found");
                            // Group tag not ok, do not permit access
                            return;
                        }else {
                            //llOwnerSay("Tag ok - grant access");
                            integer AccessPerms = llList2Integer(g_lAccess, llListFindList(g_lAccess,[(string)kTmp])+1);
                            if(AccessPerms  == MODE_ADMIN || AccessPerms == MODE_CFG){
                                iPerms+= PERM_ADMIN;
                            }else if(AccessPerms == MODE_DEL){
                                if(!(iPerms&PERM_DELETE))iPerms+=PERM_DELETE;
                            }
                            access = "granted";

                            // Send the access permissions to the note
                            llRegionSay( NOTE_CHANNEL, llList2Json(JSON_OBJECT, ["dest", i, "access", access, "perms", iPerms, "user", kTmp]));
                            return;
                        }
                    }else {
                        //llOwnerSay("Error 1");
                        return;
                    }
                } //else llOwnerSay("Error 2");
                
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
            } else if( llJsonGetValue(m, ["cmd"])== "note_finished") {
                // Note is now ready. Check if sync is enabled.
                if(!g_iSyncDown) return; // Sync is disabled, we can ignore the rest of this message.

                list lNoteExtraParams = ["type", "set", "poster", llJsonGetValue(m,["author","name"]), "note", llJsonGetValue(m,["data"]), "timer", llJsonGetValue(m,["timer"]), "timer_params", g_sTimeParams, "kID", llJsonGetValue(m,["author", "author"]), "silent", bool((g_iSettingsMask & Mask_ChattyNotes))];

                if(g_iSyncDown){
                    // Perform the sync
                    vector vLocal = (g_vTouchPos-llGetPos());
                    if(llGetRot()!=ZERO_ROTATION)vLocal /= llGetRot(); // Get the true local
                    string sCommandStr = llList2Json(JSON_OBJECT, ["pos", vLocal, "note", llList2Json(JSON_OBJECT, lNoteExtraParams)]);
                    llRegionSay(g_iSync, llList2Json(JSON_OBJECT, ["op", "make", "cmd", sCommandStr]));
                }

            }
                        
        } else if(c == g_iSync)
        {
            if(llJsonGetValue(m, ["op"]) == "delete")
            {
                if(!g_iSyncDelete){
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
        } else if(c == g_iTouchChan)
        {
            if(llJsonGetValue(m,["cmd"])!="group")return;


            key kGroup = (key)llJsonGetValue(m,["packet","group"]);
            key kUser = (key)llJsonGetValue(m,["packet","user"]);
            if(kUser==g_kToucher)
            {
                // Perform Auth Checks

                if(llListFindList(g_lGroups, [(string)kGroup]) != -1)
                {
                    //llOwnerSay("Group found, check mode");
                    if(g_iDetectMode == 1)
                        MakeNote(kUser);
                    else if(g_iDetectMode==2)
                    {
                        
                        llRegionSay( NOTE_CHANNEL, llList2Json(JSON_OBJECT, ["dest", g_kReadReturn, "access", "granted", "perms", g_iReadPerms, "user", g_kToucher]));
                    }
                } //else llOwnerSay("Failure, group not found");


                g_kToucher=NULL;
                llListenRemove(g_iTouchTemp);
            } //else llOwnerSay("User not toucher");
        }
    } 
}