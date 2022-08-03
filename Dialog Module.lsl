// ********************************************************************
//
// Menu Display Script 
//
// Menu command format
// string = menuidentifier | display navigate? TRUE/FALSE | menuMaintitle~subtitle1~subtitle2~subtitle3 | button1~button2~button3 {| fixedbutton1~fixedbutton2~fixedbutton3  optional}
// key = menuuser key
//
// Return is in the format
// "menuidentifier | item"
//
// menusDescription [menuchannel, key, menu & parent, return link, nav?,  titles, buttons, fixed buttons]
// menusActive      [menuchannel, menuhandle, time, page] 
//
// by SimonT Quinnell
//
// CHANGES
// 2010/10/14 - Timeout message now gets sent to the prim that called the menu, not LINK_THIS.  Also includes menuidentifier
// 2010/11/29 - Fixed Bug in RemoveUser function.  Thanks for Virtouse Lilienthal for pointing it out.
// 2010/11/29 - Tidied up a little and removed functions NewMenu and RemoveUser that are only called once
// 2014/04/28 - Clarified licence
// 2022/03/20 - ZNI CREATIONS: Updated to include a color menu
//
// NOTE: This script is licenced using the Creative Commons Attribution-Share Alike 3.0 license
//
// ********************************************************************
 
 
// ********************************************************************
// CONSTANTS
// ********************************************************************
 
// Link Commands
integer     LINK_MENU_DISPLAY = 300;
integer     LINK_MENU_CLOSE = 310; 
integer     LINK_MENU_RETURN = 320;
integer     LINK_MENU_TIMEOUT = 330;
integer     LINK_MENU_CHANNEL = 303; // Returns from the dialog module to inform what the channel is
integer     LINK_MENU_ONLYCHANNEL = 302; // Sent with a ident to make a channel. No dialog will pop up, and it will expire just like any other menu if input is not received. 
 
// Main Menu Details
string      BACK = "<<";
string      FOWARD = ">>";
string      MANUAL_ENTRY = " ";
list        MENU_NAVIGATE_BUTTONS = [ " ", " ", "-exit-"];
float       MENU_TIMEOUT_CHECK = 10.0;
integer     MENU_TIMEOUT = 120;
integer     MAX_TEXT = 510;
 
 
integer     STRIDE_DESCRIPTION = 8;
integer     STRIDE_ACTIVE = 4;
integer     DEBUG = FALSE;
 
// ********************************************************************
// Variables
// ********************************************************************
 
list    menusDescription;
list    menusActive;
 
 
// ********************************************************************
// Functions - General
// ********************************************************************
 
debug(string debug)
{
    if (DEBUG) llSay(DEBUG_CHANNEL,"DEBUG:"+llGetScriptName()+":"+debug+" : Free("+(string)llGetFreeMemory()+")");
}  
 
 
integer string2Bool (string test)
{
    if (test == "TRUE") return TRUE;
    else return FALSE;
}
 
// ********************************************************************
// Functions - Menu Helpers
// ********************************************************************
 
integer NewChannel()
{    // generates unique channel number
    integer channel;
 
    do channel = -(llRound(llFrand(999999)) + 99999);
    while (~llListFindList(menusDescription, [channel]));
 
    return channel;    
}
 
 
string  CheckTitleLength(string title)
{
    if (llStringLength(title) > MAX_TEXT) title = llGetSubString(title, 0, MAX_TEXT-1);
 
    return title;
}
 
 
list FillMenu(list buttons)
{   //adds empty buttons until the list length is multiple of 3, to max of 12
    integer i;
    list    listButtons;
 
    for(i=0;i<llGetListLength(buttons);i++)
    {
        string name = llList2String(buttons,i);
        if (llStringLength(name) > 24) name = llGetSubString(name, 0, 23);
        listButtons = listButtons + [name];
    }
 
    while (llGetListLength(listButtons) != 3 && llGetListLength(listButtons) != 6 && llGetListLength(listButtons) != 9 && llGetListLength(listButtons) < 12)
    {
        listButtons = listButtons + [" "];
    }
 
    buttons = llList2List(listButtons, 9, 11);
    buttons = buttons + llList2List(listButtons, 6, 8);
    buttons = buttons + llList2List(listButtons, 3, 5);    
    buttons = buttons + llList2List(listButtons, 0, 2); 
 
    return buttons;
}
 
RemoveMenu(integer channel, integer echo)
{
    integer index = llListFindList(menusDescription, [channel]);
 
    if (index != -1)
    {
        key     menuId = llList2Key(menusDescription, index+1);
        string  menuDetails = llList2String(menusDescription, index+2);
        integer menuLink = llList2Integer(menusDescription, index+3);
        menusDescription = llDeleteSubList(menusDescription, index, index + STRIDE_DESCRIPTION - 1);
        RemoveListen(channel);
 
        if (echo) llMessageLinked(menuLink, LINK_MENU_TIMEOUT, menuDetails, menuId);
    }
}
 
RemoveListen(integer channel)
{
    integer index = llListFindList(menusActive, [channel]);
    if (index != -1)
    {    
        llListenRemove(llList2Integer(menusActive, index + 1));
        menusActive = llDeleteSubList(menusActive, index, index + STRIDE_ACTIVE - 1);
    }
}
 
// ********************************************************************
// Functions - Menu Main
// ********************************************************************
 
DisplayMenu(key id, integer channel, integer page, integer iTextBox)
{
    string  menuTitle;
    list    menuSubTitles;
    list    menuButtonsAll;
    list    menuButtons;   
    list    menuNavigateButtons;
    list    menuFixedButtons;
 
    integer max = 12;
    
    // Populate values
    integer index = llListFindList(menusDescription, [channel]);
    

    menuButtonsAll = llParseString2List(llList2String(menusDescription, index+6), ["~"], []);
    if (llList2String(menusDescription, index+7) != "") menuFixedButtons = llParseString2List(llList2String(menusDescription, index+7), ["~"], []);
    
    if(llList2String(menuButtonsAll,0)=="colormenu" && llGetListLength(menuButtonsAll)==1){
        menuButtonsAll = ["Dark Blue", "Blue", "Red", "Dark Red", "Green", "Dark Green", "Black", "White", ">custom<"];
    }


    // Set up the menu buttons
    if (llList2Integer(menusDescription, index+4)) menuNavigateButtons= MENU_NAVIGATE_BUTTONS;
    else if (llGetListLength(menuButtonsAll) > (max-llGetListLength(menuFixedButtons))) menuNavigateButtons = [" ", MANUAL_ENTRY, " "];
     
    // FIXME: add sanity check for menu page
     
    max = max - llGetListLength(menuFixedButtons) - llGetListLength(menuNavigateButtons);
    integer     start = page*max;
    integer     stop = (page+1)*max - 1;
    menuButtons = FillMenu(menuFixedButtons + llList2List(menuButtonsAll, start, stop));
    
    // Generate the title
    list tempTitle = llParseString2List(llList2String(menusDescription, index+5), ["~"], []);
    menuTitle = llList2String(tempTitle,0);
    if (llGetListLength(tempTitle) > 1) menuSubTitles = llList2List(tempTitle, 1, -1);
    if (llGetListLength(menuSubTitles) > 0)
    {
        integer i;
        for(i=start;i<(stop+1);++i)
        {
            if (llList2String(menuSubTitles, i) != "") menuTitle += "\n"+llList2String(menuSubTitles, i);
        }
    }
    menuTitle = CheckTitleLength(menuTitle);
 
    // Add navigate buttons if necessary
    if (page > 0) menuNavigateButtons = llListReplaceList(menuNavigateButtons, [BACK], 0, 0);
    if (llGetListLength(menuButtonsAll) > (page+1)*max) menuNavigateButtons = llListReplaceList(menuNavigateButtons, [FOWARD], 2, 2); 
 
    // Set up listen and add the row details
    integer menuHandle = llListen(channel, "", id, "");
    menusActive = [channel, menuHandle, llGetUnixTime(), page] + menusActive;
 
    llSetTimerEvent(MENU_TIMEOUT_CHECK);
 
    // Display menu
    if(!iTextBox)
        llDialog(id, menuTitle, menuNavigateButtons + menuButtons, channel);
    else llTextBox(id, menuTitle, channel);
}

 
// ********************************************************************
// Event Handlers
// ********************************************************************  
 
default
{
    listen(integer channel, string name, key id, string message)
    {
        if (message == BACK) 
        { 
            integer index = llListFindList(menusActive, [channel]);
            integer page = llList2Integer(menusActive, index+3)-1;
            RemoveListen(channel);            
            DisplayMenu(id, channel, page, FALSE);
        }
        else if (message == FOWARD)
        { 
            integer index = llListFindList(menusActive, [channel]);
            integer page = llList2Integer(menusActive, index+3)+1;
            RemoveListen(channel);
            DisplayMenu(id, channel, page, FALSE);
        }else if(message == MANUAL_ENTRY)
        {
            integer index = llListFindList(menusActive, [channel]);
            integer page = llList2Integer(menusActive, index+3);
            RemoveListen(channel);
            DisplayMenu(id, channel, 0, TRUE);
        }
        else if (message == " ")
        { 
            integer index = llListFindList(menusActive, [channel]);
            integer page = llList2Integer(menusActive, index+3);
            RemoveListen(channel);
            DisplayMenu(id, channel, page, FALSE);
        }
        else 
        {
            integer index = llListFindList(menusDescription, [channel]);
            if(llList2String(menusDescription,index+6)=="colormenu")
            {
                switch(message)
                {
                    case "Dark Blue":
                    {
                        message = "<0,0,0.5>";
                        break;
                    }
                    case "Blue":
                    {
                        message = "<0,0,1>";
                        break;
                    }
                    case "Red":
                    {
                        message = "<1,0,0>";
                        break;
                    }
                    case "Dark Red":
                    {
                        message = "<0.5,0,0>";
                        break;
                    }
                    case ">custom<":
                    {
                        llTextBox(id, "Enter the color using the format: <R,G,B> including the brackets.", channel);
                        return;
                    }
                    case "Green":
                    {
                        message = "<0,1,0>";
                        break;
                    }
                    case "Dark Green":
                    {
                        message = "<0,0.5,0>";
                        break;
                    }
                    case "Black":
                    {
                        message = "<0,0,0>";
                        break;
                    }
                    case "White":
                    {
                        message = "<1,1,1>";
                        break;
                    }
                    default:
                    {
                        break;
                    }
                }
            }
            llMessageLinked(llList2Integer(menusDescription, index+3), LINK_MENU_RETURN, llList2String(menusDescription, index+2)+"|"+message, id);
            RemoveMenu(channel, FALSE);
        }
    }
 
    link_message(integer senderNum, integer num, string message, key id) 
    {
        if (num == LINK_MENU_DISPLAY)
        {   // Setup New Menu
            list    temp = llParseStringKeepNulls(message, ["|"], []);
            integer iTextBox=0;
            if(llList2String(temp,3)=="")iTextBox = 1;
            integer channel = NewChannel();
 
            if (llGetListLength(temp) > 2)
            {
                menusDescription = [channel, id, llList2String(temp, 0), senderNum,  string2Bool(llList2String(temp, 1)), llList2String(temp, 2), llList2String(temp, 3), llList2String(temp, 4)] + menusDescription;
                DisplayMenu(id, channel, 0, iTextBox);
            }
            else llSay (DEBUG_CHANNEL, "ERROR in "+llGetScriptName()+": Dialog Script. Incorrect menu format");
        }
        else if (num == LINK_MENU_CLOSE)
        {    // Will remove all menus that have the user id.
             integer index_id = llListFindList(menusDescription, [id]);
 
             while (~index_id) 
             {
                 integer channel = llList2Integer(menusDescription, index_id-1);
                 RemoveMenu(channel, FALSE);
 
                 // Check for another menu by same user
                 index_id = llListFindList(menusDescription, [id]);
             }
        } else if(num == LINK_MENU_ONLYCHANNEL)
        {
            integer channel = NewChannel();
            integer handle = llListen(channel, "", "", "");
            menusActive = [channel, handle, llGetUnixTime(), 0] + menusActive;
            menusDescription = [channel, id, message, senderNum, 0, " ", " ", " "]+menusDescription;
            llMessageLinked(LINK_SET, LINK_MENU_CHANNEL, (string)channel, message);
        }
    }
 
    timer()
    {   // Check through timers and close if necessary
        integer i;
        list toRemove;
        integer currentTime = llGetUnixTime();
        integer length = llGetListLength(menusActive);   
 
        for(i=0;i<length;i+=STRIDE_ACTIVE)
        {
            if (currentTime - llList2Integer(menusActive, i+2) > MENU_TIMEOUT) toRemove = [llList2Integer(menusActive, i)] + toRemove;
        }
 
        length = llGetListLength(toRemove);
        if (length > 0)
        {
            for(i=0;i<length;i++)
            {
                RemoveMenu(llList2Integer(toRemove, i), TRUE);
            }
        }        
    }
}