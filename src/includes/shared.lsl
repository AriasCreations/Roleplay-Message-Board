/*

Common Code FROM Masterfile.lsl

*/
#define RED_QUEEN "27a0ae67-30d9-4fbc-b9fb-fd388c98c202"
string SLURL(key kID){
    return "secondlife:///app/agent/"+(string)kID+"/about";
}
integer bool(integer a){
    if(a)return TRUE;
    else return FALSE;
}
list g_lCheckboxes=["□","▣"];
string Checkbox(integer iValue, string sLabel) {
    return llList2String(g_lCheckboxes, bool(iValue))+" "+sLabel;
}

key g_kLastOwner;
list g_lDSRequests;
key NULL=NULL_KEY;
UpdateDSRequest(key orig, key new, string meta){
    if(orig == NULL){
        g_lDSRequests += [new,meta];
    }else {
        integer index = HasDSRequest(orig);
        if(index==-1)return;
        else{
            g_lDSRequests = llListReplaceList(g_lDSRequests, [new,meta], index,index+1);
        }
    }
}

string GetDSMeta(key id){
    integer index=llListFindList(g_lDSRequests,[id]);
    if(index==-1){
        return "N/A";
    }else{
        return llList2String(g_lDSRequests,index+1);
    }
}

integer HasDSRequest(key ID){
    return llListFindList(g_lDSRequests, [ID]);
}

DeleteDSReq(key ID){
    if(HasDSRequest(ID)!=-1)
        g_lDSRequests = llDeleteSubList(g_lDSRequests, HasDSRequest(ID), HasDSRequest(ID)+1);
    else return;
}

string MkMeta(list lTmp){
    return llDumpList2String(lTmp, ":");
}
string SetMetaList(list lTmp){
    return llDumpList2String(lTmp, ":");
}

string SetDSMeta(list lTmp){
    return llDumpList2String(lTmp, ":");
}

list GetMetaList(key kID){
    return llParseStringKeepNulls(GetDSMeta(kID), [":"],[]);
}


/*

END MasterFile.lsl common code

*/



integer g_iMustRequestToDetach=0;
key g_kGroup;
integer g_iGroupChannel;
integer g_iListener;
key g_kControl;



integer MB_CHANNEL = 0x61195fc;
integer NOTE_CHANNEL = 0x61195fb;

Menu(key kAv, string sText, list lButtons, string sIdent)
{
    llMessageLinked(LINK_THIS, LINK_MENU_DISPLAY, llDumpList2String([sIdent, "TRUE", sText, llDumpList2String(lButtons, "~")], "|"), kAv);
}
GetArbitraryData(key kAv, string sText, string sIdent){
    llMessageLinked(LINK_THIS, LINK_MENU_DISPLAY, llDumpList2String([sIdent, "FALSE", sText, ""], "|"), kAv);
}

integer     LINK_MENU_DISPLAY = 300;
integer     LINK_MENU_REMOVE = 310; 
integer     LINK_MENU_RETURN = 320;
integer     LINK_MENU_TIMEOUT = 330;
integer     LINK_MENU_CHANNEL = 303; // Returns from the dialog module to inform what the channel is
integer     LINK_MENU_ONLYCHANNEL = 302; // Sent with a ident to make a channel. No dialog will pop up, and it will expire just like any other menu if input is not received. 

integer LINK_SYNC_MENU = 450; 
integer LINK_COMMIT_SETTINGS = 451;
integer LINK_CHECK_UPDATE=452; // only in official distributed versions!!!
// Sync Menu:
/* 

*/


integer g_iSyncDelete=0;
integer g_iNoteBootChannel;


integer Mask_GroupOnly = 1;
integer Mask_Deletable = 2;
integer Mask_ListOnly = 4;
integer Mask_TearDown = 8;
integer Mask_Create = 16;
integer Mask_DeleteOwn = 32;
integer FLAG_ALIVE = 64; // Always on.
integer Mask_GroupTags = 128;
integer Mask_ExtraGroups = 256;
integer Mask_ChattyNotes = 512;

string g_sDiscord= "https://discord.gg/QfEEKhyuY2";


string DecipherService(string payload, string ident)
{
    if(llJsonValueType(payload,[ident]) == JSON_INVALID)
    {
        return "";
    }

    return llJsonGetValue(payload, [ident,"protocol"]) + "://" + llJsonGetValue(payload,[ident,"host"]) + ":" + llJsonGetValue(payload,[ident,"port"]);
}

vector g_vTouchPos;
key g_kNote;
key g_kNoteCreator;
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

list g_lCategories;
list g_lAccess;




string BOARD_VERSION = "2.901.032225.0853";// (NOT FROM AC)";
string g_sActual;

string AUTODETECT_OBJECT = "Autodetect Group ID [AC]";
integer g_iAutodetect=0;
list g_lGroups = [];
list g_lGroupTags = [];

integer g_iGroupTags = 0;
integer g_iGroupIDs = 0;



integer Invert(integer iMask, integer iBit)
{
    if(iMask&iBit)iMask-=iBit;
    else iMask+=iBit;

    return iMask;
}

integer g_iStartup=1;
integer g_iNewVer=1;

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
string API_SERVER = "";
DoNextRequest(){
    if(llGetListLength(g_lReqs)==0)return;
    list lTmp = llParseString2List(llList2String(g_lReqs,0),["?"],[]);
    if(DEBUG)llSay(0, "SENDING REQUEST: "+API_SERVER+llList2String(g_lReqs,0));
    
    string append = "";
    if(llList2String(g_lReqs,1) == "GET")append = "?"+llDumpList2String(llList2List(lTmp,1,-1),"?");
    
    g_kCurrentReq = llHTTPRequest(API_SERVER + llList2String(lTmp,0) + append, [HTTP_METHOD, llList2String(g_lReqs,1), HTTP_MIMETYPE, "application/x-www-form-urlencoded"], llDumpList2String(llList2List(lTmp,1,-1),"?"));
}



s(string m){
    if(m!="")llSetText(">Message Board<\n"+m,<0,1,1>,1);
    
    if(m=="")llSetText("",ZERO_VECTOR,0);
    
}

key g_kAccessReader;
integer g_iAccessLine;

integer g_iSACL=0;

Serialize(){
    llMessageLinked(LINK_SET, LINK_COMMIT_SETTINGS, llDumpList2String([g_iSettingsMask], "^"), "");
}
SerializeFinal(string sSerialized){
    llSetObjectDesc(sSerialized);
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
    string sPrompt = "Message Board: "+BOARD_VERSION+"\nCopyright 2025 Aria's Creations\n";
    integer user_mode = llList2Integer(g_lAccess, llListFindList(g_lAccess, [(string)kID])+1);
    if(user_mode <= MODE_DEL){
        // create a note instead
        MakeNote(kID);
        return;
    } else {
        if(user_mode >= MODE_CFG){
            lButtons += [Checkbox(bool((g_iSettingsMask & Mask_GroupOnly)), "Obj Group"), Checkbox(bool((g_iSettingsMask&Mask_Deletable)),"Deletable"), "NEW NOTE", Checkbox(bool((g_iSettingsMask&Mask_Create)), "Create"), Checkbox(bool((g_iSettingsMask&Mask_DeleteOwn)), "DeleteOwn"), "*HELP*", Checkbox(bool((g_iSettingsMask & Mask_ChattyNotes)), "SilentNotes")];

            if(g_iSACL){
                lButtons += ["* SACL *"];
            }
            sPrompt+="\n\nGroup Only => Only allow reading by group members\nDeletable => If enabled all who can read, can delete. If off, only those defined in Access notecard\nCreate => Allow or disallow all to create notes regardless of ACL or group\nDeleteOwn => Allows note poster to delete their own notes";
        }
        if(user_mode == MODE_ADMIN){
            lButtons += ["List Access", Checkbox(bool((g_iSettingsMask & Mask_ListOnly)), "ACL Only"), Checkbox(bool((g_iSettingsMask & Mask_TearDown)), "TearDown"), "Delete All"];
            sPrompt+="\nACL Only => Only those with read permissions or above can read the notes or perform any actions\nDelete All => Deletes all notes";
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

key g_kToucher=NULL_KEY;
integer g_iTouchChan;
integer g_iTouchTemp;

integer g_iDetectMode = 0; // 1 = make, 2 = auth for read
key g_kReadAccessReturn = "";
integer g_iReadPerms;
key g_kReadReturn;


SACLMenu(key kID)
{
    list lButtons = ["*main*"];
    string sPrompt = "Message Board: "+BOARD_VERSION+"\n \n* Secondary Access Control System *";

    integer user_mode = llList2Integer(g_lAccess, llListFindList(g_lAccess, [(string)kID])+1);
    lButtons += [Checkbox(bool(g_iSettingsMask&Mask_ExtraGroups), "ExtraGroups"), Checkbox(bool(g_iSettingsMask&Mask_GroupTags), "UseTags")];

    Menu(kID, sPrompt, lButtons, "menu~sacl");
}

integer UnsetBit(integer Mask, integer BitMask)
{
    if(Mask & BitMask) Mask-=BitMask;
    return Mask;
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

integer g_iSyncOp;
string g_sSyncCommandStr;

CheckUpdate()
{
    llSay(0, "As of Mar 22 2025, the latest version has removed the internal update checks. Please check the marketplace for the latest version.");
}


Question(string sQuestion, string sPath, list lButtons, string sHeader){
    if(lButtons!=[])
        llDialog(g_kUser, "["+sHeader+"]\n[->Roleplay Message Board "+BOARD_VERSION+"<-]\n\n© Aria's Creations 2025\n\n"+sQuestion, lButtons, g_iUser);
    else
        llTextBox(g_kUser, "["+sHeader+"]\n[->Roleplay Message Board "+BOARD_VERSION+"<-]\n\n© Aria's Creations 2025\n\n"+sQuestion, g_iUser);
    
    g_sPath = sPath;
}
