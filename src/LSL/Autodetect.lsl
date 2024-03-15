#include "src/includes/shared.lsl"

default
{
    on_rez( integer start_param)
    {
        if(start_param == 0 && llGetOwner() != RED_QUEEN) {
            llOwnerSay("/!\\ ALERT /!\\\n \n[ This must not be attached by itself ]");
            g_kUser = llGetOwner();
            state detachFromAvi;
        }
        // - Set up listener -
        //llSay(0, "debug (on_rez) : "+(string)start_param);
        if(start_param != 0)
            g_iListener = llListen(start_param, "", "", "");
    }
    listen( integer channel, string name, key id, string message )
    {
        // - Parse the command, it should be a pair request
        // - Then upon pairing, attach to avatar
        //llSay(0, message);
        if (llJsonGetValue(message, ["cmd"]) == "pair")
        {
            g_kControl = id;
            key kTarget = (key)llJsonGetValue(message,["packet", "target"]);
            g_iGroupChannel = (integer)llJsonGetValue(message,["packet", "callback"]);
            g_kUser = kTarget;
            list lOpts = llGetObjectDetails(kTarget, [OBJECT_POS]);
            vector vPos = (vector)llList2String(lOpts,0);
            llSetRegionPos(vPos+<0,0,2>);
            // - Now begin attachment process
            llRequestExperiencePermissions(kTarget, "");

            // - Close the listener -
            llListenRemove(g_iListener);
        }
    }
    experience_permissions( key agent_id )
    {
        llAttachToAvatarTemp(ATTACH_HUD_CENTER_2);
    }
    experience_permissions_denied( key agent_id, integer reason )
    {
        llRequestPermissions(agent_id, PERMISSION_ATTACH);
    }

    run_time_permissions( integer perm )
    {
        if(perm&PERMISSION_ATTACH)
            llAttachToAvatarTemp(ATTACH_HUD_CENTER_2);
    }
    attach(key kID)
    {
        // We should still have attachment permissions via experience, so we can detach after, but lets confirm!
        if(kID!=NULL)
        {
            if(!(llGetPermissions()&PERMISSION_ATTACH)){
                g_iMustRequestToDetach=1;
            }

            // - Extract the Group ID -
            list lInf = llGetObjectDetails(llGetKey(), [OBJECT_GROUP]);
            g_kGroup = (key)llList2String(lInf,0);

            // - Send it back -
            llRegionSayTo(g_kControl, g_iGroupChannel, llList2Json(JSON_OBJECT, ["cmd", "group", "packet", llList2Json(JSON_OBJECT, ["group", g_kGroup, "user", g_kUser])]));

            // - Now lets start winding down to detach from the avatar -
            if(g_iMustRequestToDetach) state detachFromAvi;
            else llDetachFromAvatar();
        }
    }
}

state detachFromAvi
{
    state_entry()
    {
        llRequestExperiencePermissions(g_kUser,"");
    }
    experience_permissions( key agent_id )
    {
        llDetachFromAvatar();
    }
    experience_permissions_denied( key agent_id, integer reason )
    {
        llRequestPermissions(agent_id, PERMISSION_ATTACH);
    }
    run_time_permissions( integer perm )
    {
        if(perm&PERMISSION_ATTACH) llDetachFromAvatar();
    }
    on_rez( integer start_param)
    {
        llResetScript();
    }
}