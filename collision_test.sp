#include <sourcemod>
#include <sdktools>
#include <clients>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <smlib>


public Plugin myinfo ={
	name = "Collision module for zve",
	author = "shewowkees",
	description = "title self explanatory",
	version = "0.1",
	url = "noSiteYet"
};


public void OnClientPostAdminCheck(int client){

	SDKHook(client, SDKHook_ShouldCollide, OnShouldCollide);

}

public bool OnShouldCollide(int entity, int collisiongroup, int contentsmask, bool originalResult){

	/*char Disp[16]= "X";

	IntToString(entity, Disp, 16);

	PrintToChat(entity,Disp);

	IntToString(collisiongroup,Disp,16);

	PrintToChat(entity,Disp);

	IntToString(contentsmask,Disp,16);

	PrintToChat(entity,Disp);

	IntToString(originalResult,Disp,16);

	PrintToChat(entity,Disp);*/

	if(Client_IsValid(entity) && Client_IsIngame(entity)){

		if(TF2_GetClientTeam(entity)==TFTeam_Red && contentsmask==33640459 ){
			return false;
		}

	}

	return originalResult;
}
