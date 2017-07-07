#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <clients>
#include <sdkhooks>



public Plugin myinfo ={
	name = "Engineers Vs Zombies",
	author = "shewowkees",
	description = "zombie like gamemode",
	version = "1.2",
	url = "noSiteYet"
};

public void OnPluginStart (){
	RegConsoleCmd("sm_stuck", stuckCommand);
	RegAdminCmd("sm_nextlevel", nextCommand, ADMFLAG_CHANGEMAP, "sm_nextlevel - triggers the level change");
	RegAdminCmd("sm_playerinfo", playerinfoCommand, ADMFLAG_CHANGEMAP, "sm_playerinfo Display player datamaps values");



}

	int CollisionGroup = GetEntProp(client, Prop_Data, "m_CollisionGroup");

	SetEntProp(client, Prop_Data, "m_CollisionGroup", 2);
	CreateTimer(3.0, reCollide, client, CollisionGroup);
	PrintToChat(client, "[WARNING] You now have 3 seconds to move !");
	/*CommandCount[client]--;*/
	return Plugin_Handled;


}
public Action nextCommand(int client, int args){

	ServerCommand("changelevel_next");


}
public Action playerinfoCommand(int client, int args){

	if (args < 2)
		{
			return Plugin_Handled;
		}

		char name[32];
	        int target = -1;
		GetCmdArg(1, name, sizeof(name));

		for (int i=1; i<=MaxClients; i++)
		{
			if (!IsClientConnected(i))
			{
				continue;
			}
			char other[32];
			GetClientName(i, other, sizeof(other));
			if (StrEqual(name, other))
			{
				target = i;
			}
		}

		if (target == -1)
		{
			PrintToConsole(client, "Could not find any player with the name: \"%s\"", name);
			return Plugin_Handled;
		}

		char prop[64];
		GetCmdArg(2, prop, sizeof(prop));
		int result = GetEntProp(target, Prop_Send, prop);
		char str[32];
		IntToString(result, str, sizeof(str));
		PrintToChatAll(str);


}




public Action reCollide(Handle timer, any client, any CollisionGroup){

	SetEntProp(client, Prop_Data, "m_CollisionGroup", CollisionGroup);
	PrintToChat(client, "[WARNING] You are now solid again.");

}
