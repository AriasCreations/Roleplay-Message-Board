integer MB_CHANNEL = 0x61195fc;
integer NOTE_CHANNEL = 0x61195fb;
integer SYNC_CHANNEL = 0x999f;

string g_sNoteCard;
string g_sPoster;
string g_sDate;
key g_kPoster;
integer g_iNoteListen;
integer g_iMenuChan;
integer g_iMenuHandle;
integer g_iTornDown=FALSE;
integer g_iDeletable=FALSE;

integer PERM_DELETE = 1;
integer PERM_ADMIN = 2;
integer PERM_TEAR_DOWN = 4;
integer g_iValid=FALSE; // this is used to set the note to self-delete if the note has not been given a message

string g_sNoteInternalID = "";

list unix2date( integer vIntDat ){
    vIntDat -= (7*(1*60*60));
    if (vIntDat / 2145916800){
        vIntDat = 2145916800 * (1 | vIntDat >> 31);
    }
    integer vIntYrs = 1970 + ((((vIntDat %= 126230400) >> 31) + vIntDat / 126230400) << 2);
    vIntDat -= 126230400 * (vIntDat >> 31);
    integer vIntDys = vIntDat / 86400;
    list vLstRtn = [(vIntDat % 86400 / 3600), vIntDat % 3600 / 60, 0];//vIntDat % 60];
 
    if (789 == vIntDys){
        vIntYrs += 2;
        vIntDat = 2;
        vIntDys = 29;
    }else{
        vIntYrs += (vIntDys -= (vIntDys > 789)) / 365;
        vIntDys %= 365;
        vIntDys += vIntDat = 1;
        integer vIntTmp;
        while (vIntDys > (vIntTmp = (30 | (vIntDat & 1) ^ (vIntDat > 7)) - ((vIntDat == 2) << 1))){
            ++vIntDat;
            vIntDys -= vIntTmp;
        }
    }
    return [vIntYrs, vIntDat, vIntDys] + vLstRtn;
}

integer DateCompare(list lInput1, list lInput2)
{
    integer i=0;
    integer end = llGetListLength(lInput1);
    integer iResult = 0;
    
    for(i=0;i<end;i++)
    {
        integer i1 = llList2Integer(lInput1,i);
        integer i2  =  llList2Integer(lInput2, i);
        
        //llOwnerSay("i1: "+(string)i1+" - i2: "+(string)i2);
        
        if(i1 > i2){
            return 1;
        }else if(i1< i2) return -1;
    }
    
    return 0;
}


IsNote(){
    g_iValid=TRUE;
    llSetObjectDesc(g_sPoster+"'s note");
}
string tf(integer a){
    if(a)return "true";
    else return "false";
}
string Checkbox(integer a,string Text){
    if(a)return "[X] "+Text;
    else return "[ ] "+Text;
}

string Timer2Str(){
    if(llDumpList2String(g_lTimerParams,",")=="0,0,0,0")return "Timer Elapsed";

    return llList2String(g_lTimerParams,0)+" days, "+llList2String(g_lTimerParams,1)+" hours, "+llList2String(g_lTimerParams,2)+" minutes, "+llList2String(g_lTimerParams,3)+" seconds";
}

Menu(integer perms, key kID){
    list lButtons = ["-exit-"];
    string sPrompt = "Message left by: "+g_sPoster;
    
    if(g_iTornDown){
        lButtons += ["Put Back"];
        sPrompt = "This note has been torn down, put it back up to read it";
        jump diag;
    }
    sPrompt += "\nDeletable: "+tf((g_iDeletable || perms&PERM_DELETE));
    sPrompt += "\nDate posted: "+g_sDate;
    if(g_iTimerNote)sPrompt += "\nTimer: "+Timer2Str();
    sPrompt+="\n\nMessage: \n "+g_sNoteCard;
    
    if(perms&PERM_DELETE || g_iDeletable || perms&PERM_ADMIN)lButtons+=["Delete"];
    if(perms&PERM_TEAR_DOWN)lButtons+=["Tear Down"];
    if(perms&PERM_ADMIN)lButtons+=[Checkbox(g_iDeletable, "Deletable")];

    @diag;
    llListenRemove(g_iMenuHandle);
    g_iMenuChan = llRound(llFrand(5499999.9));
    g_iMenuHandle = llListen(g_iMenuChan, "", kID, "");
    llDialog(kID, sPrompt, lButtons, g_iMenuChan);
    
    llResetTime();
    llSetTimerEvent(1);
}

DeleteNote(){
    if(SYNC_CHANNEL != 0){
        llRegionSay(SYNC_CHANNEL, llList2Json(JSON_OBJECT,["op", "delete", "subid", g_sNoteInternalID]));
    }
    llSetStatus(STATUS_PHYSICS,TRUE);
    llSleep(3);
    llDie();
}
integer g_iNoteChnLstn=-1;

integer g_iExpireTime=120;
integer g_iBootChannel;

integer g_iTimerNote = 0;
list g_lTimerParams = [0,0,0,0];

integer g_iNoteCanExpire = 1;
integer g_iTimerElapsed;

TickTimer()
{
    if(g_iTimerNote && !g_iTimerElapsed){

        integer iDays = llList2Integer(g_lTimerParams,0);
        integer iHours = llList2Integer(g_lTimerParams,1);
        integer iMinutes = llList2Integer(g_lTimerParams,2);
        integer iSeconds = llList2Integer(g_lTimerParams,3);


        if(!iDays && !iHours && !iMinutes && !iSeconds){
            g_iTimerElapsed = 1;
            g_lTimerParams=[0,0,0,0];
            llSetColor(<0,1,0>,ALL_SIDES);
            llInstantMessage(g_kPoster, "The timer for the note: '"+g_sNoteCard+"' has expired.");
            return;
        }else {
            iSeconds--;
            if(iSeconds<=0){
                if(iMinutes>0){

                    iMinutes--;
                    iSeconds=60;
                }else iSeconds=0;
            }

            if(iMinutes<=0){
                if(iHours>0){

                    iHours--;
                    iMinutes=59;
                }else iMinutes=0;
            }

            if(iHours<=0){
                if(iDays>0){

                    iDays--;
                    iHours = 23;
                }else iHours=0;
            }

            if(iDays <= 0){
                iDays=0;
            }

            g_lTimerParams=[iDays,iHours,iMinutes,iSeconds];
        }
    }
}

ReListen()
{
    if(g_iNoteChnLstn!=-1)llListenRemove(g_iNoteChnLstn);
    g_iNoteChnLstn=llListen(NOTE_CHANNEL, "", "","");
}
default
{
    state_entry()
    {
        g_sNoteCard="Note was reset";
        g_sPoster = llKey2Name(llGetOwner());
        g_sDate = llGetDate();
        llSetText("", ZERO_VECTOR,0);
        llSay(0, "Note reset done");
        g_iNoteChnLstn = llListen(NOTE_CHANNEL, "","","");
        llResetTime();
        llSetTimerEvent(1);
    }
    
    timer(){
        if(g_iNoteCanExpire){

            if(llGetTime() > (float)g_iExpireTime && g_iNoteListen!=0){
                g_iNoteCanExpire=0;
                llWhisper(0, "Note did not receive a message");
                DeleteNote();
                llListenRemove(g_iNoteListen);
            }
            if(!g_iValid){
                llSetText("Note will expire in "+(string)(g_iExpireTime-llGetTime()), <1,0,0>,1);
                return; // <-- Prevent the note from turning the timer off when not initialized.
            }
        }
        
        
        if(llGetTime() > 30.0 && g_iMenuChan!=0){
            g_iMenuChan = 0;
            llListenRemove(g_iMenuHandle);
            llWhisper(0, "menu timed out");
        }

        // Process timer

        TickTimer();
        
    }
    
    changed(integer c){
        if(c&CHANGED_REGION_START)ReListen();
    }
    on_rez(integer c){
        
        integer StartParam = c;
        if(StartParam==0){
            llSay(0, "This note is not valid because it was not rezzed by the message board");
            g_sNoteCard = "Note not rezzed by message board";
            g_sPoster = "Notecard";
            g_sDate = llGetDate();
            
            llResetTime();
            llSetTimerEvent(1);
        }else {
            g_iBootChannel = StartParam;
            g_iNoteListen = llListen(StartParam, "", "", "");
            //llSay(StartParam, llList2Json(JSON_OBJECT, ["cmd","note_is_ready"]));
            g_iValid=FALSE;
            llResetTime();
            llSetTimerEvent(1);
        }
        //llListen(NOTE_CHANNEL, "","","");
    }
    
    listen(integer c,string n,key i,string m){
        //llOwnerSay("I heard on ("+(string)c+"): "+m);
        if(c == NOTE_CHANNEL){
            if(llJsonGetValue(m,["dest"])==(string)llGetKey() || llJsonGetValue(m,["dest"])==(string)NULL_KEY){
                if(llJsonGetValue(m,["access"]) == "granted"){
                    Menu((integer)llJsonGetValue(m,["perms"]), (key)llJsonGetValue(m, ["user"]));
                }else{
                    if(llJsonGetValue(m,["cmd"])=="rotate"){
                        //list lTmp = llGetObjectDetails(i, [OBJECT_POS]);
                        //llSetRot(llRotBetween(llGetPos(), llList2Vector(lTmp,0)));
                        llSetRot((rotation)llJsonGetValue(m,["rotate"]));
                    } else if(llJsonGetValue(m,["cmd"])=="delete"){
                        DeleteNote();
                    } else if(llJsonGetValue(m,["type"])=="set"){
                        
                        //list lTmp = llGetObjectDetails(i, [OBJECT_POS]);
                        //llSetRot(llRotBetween(llGetPos(), llList2Vector(lTmp,0)));
                        
                        // Note now ready
                        // Apply data from message board
                        llSetTimerEvent(0);
                        g_sPoster = llJsonGetValue(m,["poster"]);
                        g_kPoster = (key)llJsonGetValue(m,["kID"]);
                        g_sDate = llGetDate();
                        g_sNoteCard = llBase64ToString(llJsonGetValue(m,["note"]));
                        integer iChatty = (integer)llJsonGetValue(m,["silent"]);

                        g_iTimerNote = (integer)llJsonGetValue(m,["timer"]);
                        g_lTimerParams = llParseString2List(llJsonGetValue(m,["timer_params"]), [", ",","],[]);
                        if(g_iTimerNote)llSetTimerEvent(1);

                        g_sNoteInternalID = llMD5String(g_sNoteCard, 0);

                        IsNote();
                        llListenRemove(g_iNoteListen);
                        g_iNoteListen=0;
                        llSetText("",ZERO_VECTOR,0);
                        
                        if(iChatty)return;
                        llSay(0, "((Note Posted)) "+g_sPoster+": "+g_sNoteCard);
                    } else if(llJsonGetValue(m,["type"]) == "deletebyid")
                    {
                        // Delete note if SubID matches
                        if(llJsonGetValue(m,["subid"])==g_sNoteInternalID)DeleteNote();
                        //else llSay(0, "SUBID ["+llJsonGetValue(m,["subid"])+"] != ["+g_sNoteInternalID+"]");
                    }
                        
                }

            }
            
        } else if(c == g_iMenuChan){
            if(m == "-exit-"){
                llListenRemove(g_iMenuHandle);
                g_iMenuChan=0;
                return;
            } else if(m == Checkbox(g_iDeletable, "Deletable")){
                g_iDeletable = 1-g_iDeletable;
            } else if(m == "Delete"){
                // do delete
                DeleteNote();
            } else if(m == "Tear Down"){
                // tear the note down
                llSetAlpha(0.5,ALL_SIDES);
                g_iTornDown=TRUE;
            } else if(m == "Put Back"){
                llSetAlpha(1,ALL_SIDES);
                g_iTornDown=FALSE;
            } 
            
            llSay(MB_CHANNEL, llList2Json(JSON_OBJECT, ["cmd", "get_auth", "id", i]));
        }else if(c==g_iBootChannel){
        
            
            if(llJsonGetValue(m, ["type"]) == "init" && llGetOwnerKey(i)==llGetOwner() && llJsonGetValue(m,["dest"])==(string)llGetKey()){
                MB_CHANNEL = (integer)llJsonGetValue(m,["board"]);
                NOTE_CHANNEL = (integer)llJsonGetValue(m,["note"]);
                SYNC_CHANNEL = (integer)llJsonGetValue(m,["sync"]);
                if(llJsonGetValue(m,["expire"])!="") g_iExpireTime = (integer)llJsonGetValue(m,["expire"]);
                llListenRemove(g_iNoteChnLstn);
                g_iNoteChnLstn = llListen(NOTE_CHANNEL, "", "", "");
                llSay(c, llList2Json(JSON_OBJECT, ["cmd","note_is_ready"]));
            }
                
        }
    }
            

    touch_start(integer total_number)
    {
        if(!g_iValid){
            llInstantMessage(llDetectedKey(0), "This note has not been initialized. Clicking a non-initialized note will delete it");
            DeleteNote();
            return;
        }
        // Ask Message board for auth rights
        llSay(MB_CHANNEL, llList2Json(JSON_OBJECT, ["cmd", "get_auth", "id", llDetectedKey(0)]));


        if(g_iTimerElapsed){
            llSetColor(<1,1,1>, ALL_SIDES);
        }
    }
}
