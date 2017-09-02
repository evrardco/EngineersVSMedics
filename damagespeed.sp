#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <clients>
#include <sdkhooks>

ConVar sm_dmgspeed_speed_multiplier = null;
ConVar sm_dmgspeed_team_restriction = null;


public Plugin myinfo ={
	name = "damage speed",
	author = "shewowkees",
	description = "adds an option to multiply the force caused by damege",
	version = "1.0",
	url = "noSiteYet"
};

public void OnPluginStart (){
	PrintToServer("damage speed V1.O by shewowkees.");

	//CONVARS
	sm_dmgspeed_speed_multiplier = CreateConVar("sm_dmgspeed_speed_multiplier","50.0","by how much the damage forces are multiplied");
	sm_dmgspeed_team_restriction = CreateConVar("sm_dmgspeed_team_restriction","-1","selects the team to be affected by the augmented forces -1 for all teams");
	AutoExecConfig(true, "plugin_dmgspeed");
}

public OnMapStart(){


	HookEvent("player_spawn",Evt_PlayerSpawnChangeClass,EventHookMode_Post);




}

public void OnClientPostAdminCheck(int client){

	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);

}


public Action Evt_PlayerSpawnChangeClass(Event event, const char[] name, bool dontBroadcast){
	int client = GetClientOfUserId(event .GetInt("userid"));
	SetEntPropFloat(client, Prop_Data, "m_flFriction", 0.0);

}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3]){
		float mult = GetConVarFloat(sm_dmgspeed_speed_multiplier);
		int team = GetConVarInt(sm_dmgspeed_team_restriction);
    if(victim==attacker){
			return Plugin_Continue;
		}
		if(IsClientInGame(victim)){
			if(GetClientTeam(victim)==team || team==-1){
				float victimPos[3];
				GetEntPropVector(victim, Prop_Send, "m_vecOrigin",victimPos);
				float attackerPos[3];
				GetEntPropVector(attacker, Prop_Send, "m_vecOrigin", attackerPos);

				for(int i=0;i<3;i++){
					victimPos[i]=(victimPos[i]-attackerPos[i]);
				}
				NormalizeVector(victimPos, victimPos);
				for(int i=0;i<3;i++){
					victimPos[i]=damage*mult*victimPos[i]
				}
				TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, victimPos)
			}

		}

		if(TF2_GetClientTeam(attacker)==TFTeam_Red && TF2_GetClientTeam(victim)==TFTeam_Blue){

			PrintToServer("[DEBUG]: Red attacking a blu");
			if(GetPlayerWeaponSlot(attacker,1)==weapon){
				//528 is itemDefIndex of short circuit
				PrintToServer("[DEBUG]: Holding weapon slot 1");
				SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", 3.0);
				int itemDefIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");

				if(itemDefIndex==528){
					PrintToServer("[DEBUG]: Holding short circuit");
					new offset = FindSendPropOffs("CTFPlayer", "m_iAmmo");
					new ammo = 3;
					int current_metal = GetEntData(attacker, offset + (ammo * 4), 4);
					SetEntData(attacker, offset + (ammo * 4), current_metal-50, 4);  

				}


			}




		}


    return Plugin_Continue;
}
