#include <sourcemod>
#include <sdktools>
#include <clients>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <smlib>

int ClientArray[MAXPLAYERS+1];
public Plugin myinfo ={
	name = "Collision module for zve",
	author = "shewowkees",
	description = "title self explanatory",
	version = "0.1",
	url = "noSiteYet"
};

public void OnPluginStart(){

	for(int i=0;i<MAXPLAYERS+1;i++){
		ClientArray[i] = 0;
	}

	RegConsoleCmd("sm_nocollide", nocollide);


}
public Action nocollide(int client, int args){
	char client_s[16]="";
	IntToString(client,client_s,sizeof(client_s));
	PrintToChat(client,"Disabling collisions for client n°%s...",client_s)

	ClientArray[client] = 1;
	CreateTimer(5.0,reset,client);
	return Plugin_Handled;

}

public Action reset(Handle timer, any client){
	char client_s[16]="";
	IntToString(client,client_s,sizeof(client_s));
	PrintToChat(client,"Enabling collisions for client n°%s...",client_s)

	ClientArray[client] = 0;
	return Plugin_Handled;
}

public void OnClientPostAdminCheck(int client){

	SDKHook(client, SDKHook_ShouldCollide, OnShouldCollide);

	SDKHook(client, SDKHook_StartTouch, OnStartTouch);
	SDKHook(client, SDKHook_EndTouch, OnEndTouch);

}
public Action OnStartTouch(int entity, int other){

	if (entity < 1 || entity > MaxClients) {
		return Plugin_Continue;
	}
	if (other < 1 || other > MaxClients) {
		return Plugin_Continue;
	}
	if(!IsValidEntity(entity) || !IsValidEntity(other)){
		return Plugin_Continue;
	}
	if(!IsClientInGame(entity)||!IsClientInGame(other)){
		return Plugin_Continue;
	}


	//If i am the guy who called the command
	if(ClientArray[entity] == 1){
		//set the other guy so that he won't collide either
		ClientArray[other]=2;
		return Plugin_Continue;
	}

	if(ClientArray[entity] == 2){

		if(ClientArray[other]==2){
			ClientArray[other]=0;
		}

		if(ClientArray[other]==0){
			ClientArray[entity]=0;
		}

		return Plugin_Continue;

	}

	return Plugin_Continue;
}
public Action OnEndTouch(int entity, int other){

	if (entity < 1 || entity > MaxClients) {
		return Plugin_Continue;
	}
	if (other < 1 || other > MaxClients) {
		return Plugin_Continue;
	}
	if(!IsValidEntity(entity) || !IsValidEntity(other)){
		return Plugin_Continue;
	}
	if(!IsClientInGame(entity)||!IsClientInGame(other)){
		return Plugin_Continue;
	}



	if(ClientArray[entity]!=1){
		ClientArray[entity]=0;
	}

	return Plugin_Continue;
}
public bool OnShouldCollide(int entity, int collisiongroup, int contentsmask, bool originalResult){

	char entity_s[16]= "";
	char group_s[16]= "";
	char mask_s[16]= "";

	IntToString(entity, entity_s, 16);

	PrintToChat(entity,"For enttity %s",entity_s);

	IntToString(collisiongroup,group_s,16);

	PrintToChat(entity,"Collision group is %s",group_s);

	IntToString(contentsmask,mask_s,16);

	PrintToChat(entity,"Mask is %s",mask_s);



	if(Client_IsValid(entity) && Client_IsIngame(entity)){

		if(TF2_GetClientTeam(entity)==TFTeam_Red && contentsmask==33640459 || TF2_GetClientTeam(entity)==TFTeam_Red && contentsmask==3579073){
			PrintToServer("Disabling Collisions for two red players");
			return false;
		}
		if(TF2_GetClientTeam(entity)==TFTeam_Blue && contentsmask==33638411 || TF2_GetClientTeam(entity)==TFTeam_Blue && contentsmask == 33570881){
			if(ClientArray[entity]==1 || ClientArray[entity]==2){
				PrintToServer("Disabling Collisions for two blu players");
				return false;
			}
			PrintToServer("Enabling Collisions for two blu players");
		}

	}


	return originalResult;
}
