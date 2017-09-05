#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <clients>
#include <sdkhooks>
#include <smlib>




//CONVARS
ConVar zve_setup_time = null;
ConVar zve_round_time = null;
ConVar zve_tanks = null;
ConVar zve_super_zombies = null;
ConVar zve_spawn_building = null;
//Game related global variables
bool InfectionStarted = false;
bool SuperZombies = false;
int ZombieHealth = 1500;
int CountDownCounter = 0;
float ActualRoundTime = 0.0;


//Timer Handles
Handle RedWonHandle = INVALID_HANDLE;
Handle SuperZombiesTimerHandle = INVALID_HANDLE;
Handle InfectionHandle = INVALID_HANDLE;
Handle CountDownHandle = INVALID_HANDLE;
Handle CountDownStartHandle = INVALID_HANDLE;

public Plugin myinfo ={
	name = "Engineers Vs Zombies rewritten",
	author = "shewowkees",
	description = "zombie like gamemode",
	version = "1.2",
	url = "noSiteYet"
};

public void OnPluginStart (){
	PrintToServer("Successfully loaded Zombies VS Engineers.");
	HookEvent("player_spawn",Evt_PlayerSpawnChangeClass,EventHookMode_Post);
	HookEvent("player_spawn",Evt_PlayerSpawnChangeTeam,EventHookMode_Pre);
	HookEvent("player_death",Evt_PlayerDeath,EventHookMode_Post);
	HookEvent("player_disconnect",Evt_PlayerDisconnect,EventHookMode_Post);
	HookEvent("teamplay_round_start", Evt_RoundStart);
	AddCommandListener(CommandListener_Build, "build");
	AddCommandListener(CommandListener_ChangeClass, "joinclass");
	AddCommandListener(CommandListener_ChangeTeam, "jointeam");
	AddCommandListener(CommandListener_Spectate, "spectate");
	//Commands
	RegServerCmd("zve_debug_checkvictory", DebugCheckVictory);
	RegAdminCmd("sm_zvecure", Command_zvecure, ADMFLAG_KICK, "Makes an admin be a red engineer");
	RegAdminCmd("sm_zveinfect", Command_zveinfect, ADMFLAG_KICK, "Makes an admin be a Super Zombie");



	//CONVARS

	zve_round_time = CreateConVar("zve_round_time", "314", "Round time, 5 minutes by default.");
	zve_setup_time = CreateConVar("zve_setup_time", "60.0", "Setup time, 60s by default.");
	zve_super_zombies = CreateConVar("zve_super_zombies", "30.0", "How much time before round end zombies gain super abilities. Set to 0 to disable it.")
	zve_tanks = CreateConVar("zve_tanks", "60.0", "How much time after setup the first zombies have a health boost. Set to 0 to disable it.")
	zve_spawn_building = CreateConVar("zve_spawn_building","1.0","Wether or not spawn building should be activated. Set to 0 to disbale")
	AutoExecConfig(true, "plugin_zve");

	LoadTranslations("engiesVSmedics.phrases");
}

public OnMapStart(){

	PrecacheSound("vo/medic_medic03.mp3");
	PrecacheSound("vo/medic_no01.mp3");

	HookEntityOutput("trigger_capture_area", "OnStartCap", StartCap);

	CreateTimer(3.0, OpenDoors, _, TIMER_REPEAT);
}

public void OnClientPostAdminCheck(int client){

	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);

}
//Commands
public Action DebugCheckVictory(int args){

	function_CheckVictory();
	return Plugin_Handled;

}

public Action Command_zvecure(int client, int args){
	int EntProp = GetEntProp(client, Prop_Send, "m_lifeState");
	SetEntProp(client, Prop_Send, "m_lifeState", 2);
	ChangeClientTeam(client, view_as<int>(TFTeam_Red) );
	TF2_SetPlayerClass(client, TFClass_Engineer, true, true);
	SetEntProp(client, Prop_Send, "m_lifeState", EntProp);
	int MaxHealth = GetEntProp(client, Prop_Data, "m_iMaxHealth");
	SetEntProp(client, Prop_Data, "m_iHealth", MaxHealth);

	TF2_RegeneratePlayer(client);
	return Plugin_Handled;
}

public Action Command_zveinfect(int client, int args){
	function_makeZombie(client,true);
	return Plugin_Handled;
}
//events and forwards

public OnEntityCreated(entity, const String:classname[]) {
	bool shouldKill = StrEqual(classname, "tf_logic_koth");

	shouldKill = shouldKill || StrEqual(classname, "tf_logic_arena");
	shouldKill = shouldKill || StrEqual(classname, "tf_logic_mann_vs_machine");
	shouldKill = shouldKill || StrEqual(classname, "tf_logic_medieval");
	shouldKill = shouldKill || StrEqual(classname, "passtime_logic");
	shouldKill = shouldKill || StrEqual(classname, "tf_logic_mannpower");
	shouldKill = shouldKill || StrEqual(classname, "info_powerup_spawn");
	shouldKill = shouldKill || StrEqual(classname, "item_powerup_crit");
	shouldKill = shouldKill || StrEqual(classname, "item_powerup_uber");




	if  (shouldKill){
		PrintToServer( "created = %s", classname );
		SDKHook(entity, SDKHook_Spawn, koth_spawn);
	}
}

public Action:TF2_OnPlayerTeleport(client, teleporter, &bool:result) {
		result = true;
		return Plugin_Changed;
}

/*
 * This code is from Tsunami's TF2 build restrictions. It prevents engineers
 * from even placing a sentry.
 *
 */

public Action koth_spawn(int entity){

	AcceptEntityInput(entity, "Kill")

}


public Action CommandListener_Build(client, const String:command[], argc)
{
	// Get arguments
	decl String:sObjectType[256]
	GetCmdArg(1, sObjectType, sizeof(sObjectType));

	// Get object mode, type and client's team
	new iObjectType = StringToInt(sObjectType),
	iTeam = GetClientTeam(client);

	// If invalid object type passed, or client is not on Blu or Red
	if(iObjectType < view_as<int>(TFObject_Dispenser) || iObjectType > view_as<int>(TFObject_Sentry) || iTeam < view_as<int>(TFTeam_Red) ) {
		return Plugin_Continue;
	}

	//Blocks sentry building
	else if(iObjectType==view_as<int>(TFObject_Sentry) ) {
		Client_PrintToChat(client,false, "{BLA}[EVZ]:{N} %t", "sentry_restric");
		return Plugin_Handled;
	}
	return Plugin_Continue;

}



public Action CommandListener_ChangeTeam(client, const String:command[],argc){

	Client_PrintToChat(client,false, "{BLA}[EVZ]:{N} %t", "betray_team");
	return Plugin_Handled;

}

public Action CommandListener_ChangeClass(client,const String:command[], argc){
	decl String:arg1[256];
	GetCmdArg(1, arg1, sizeof(arg1));
	if(strcmp(arg1,"medic",false)==0 && TF2_GetClientTeam(client)==TFTeam_Blue ) {

		return Plugin_Continue;

	}else if( TF2_GetClientTeam(client)==TFTeam_Blue ) {

		ClientCommand(client,"joinclass medic");

	}

	if(strcmp(arg1,"engineer",false)==0 && TF2_GetClientTeam(client)==TFTeam_Red ) {

		return Plugin_Continue;

	}else if(TF2_GetClientTeam(client)==TFTeam_Red ) {

		ClientCommand(client,"joinclass engineer");

	}

	Client_PrintToChat(client,false, "{BLA}[EVZ]:{N} %t", "change_class");
	return Plugin_Handled;

}


public Action CommandListener_Spectate(client, const String:command[], argc){
	Client_PrintToChat(client, false,"{BLA}[EVZ]:{N} %t", "change_spectator");
	return Plugin_Handled;
}


public Action Evt_PlayerSpawnChangeTeam(Event event, const char[] name, bool dontBroadcast){

	int client = GetClientOfUserId(event .GetInt("userid"));

	if(Client_IsValid(client) && Client_IsIngame(client)){

		if(InfectionStarted){

			if(TF2_GetClientTeam(client)!=TFTeam_Blue){
				function_SafeTeamChange(client,TFTeam_Blue);
				function_SafeRespawn(client);
				function_makeZombie(client,false);
			}

		}else if(TF2_GetClientTeam(client)!=TFTeam_Red){
				function_SafeTeamChange(client,TFTeam_Red);
				function_SafeRespawn(client);
		}

	}




}

public Action Evt_PlayerSpawnChangeClass(Event event, const char[] name, bool dontBroadcast){

	int client = GetClientOfUserId(event .GetInt("userid"));

	if(Client_IsValid(client) && Client_IsIngame(client)){

		if(TF2_GetClientTeam(client) == TFTeam_Red ){

			if(TF2_GetPlayerClass(client)!=TFClass_Engineer){
				TF2_SetPlayerClass(client,TFClass_Engineer);
				TF2_RespawnPlayer(client);
			}


		}
		if(TF2_GetClientTeam(client)==TFTeam_Blue){
			function_makeZombie(client, false);
			function_StripToMelee(client);
		}

		function_CheckVictory();
	}


}

public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] weaponname, bool &result){

	if(TF2_GetClientTeam(client)==TFTeam_Red){
		int itemDefIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");

		if(itemDefIndex==527){//Prevents crits for widow maker
			PrintToChat(client,"Widow Maker detected");
			result=false;
			return Plugin_Handled;
		}
		if(GetPlayerWeaponSlot(client,1)==weapon){
			result=false;
			return Plugin_Handled;
		}

		result = true;
	}
	return Plugin_Handled;


}


public Action OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
		if(!Client_IsValid(victim)||!Client_IsValid(attacker)){
			return Plugin_Continue;
		}
		if(TF2_GetClientTeam(victim)==TFTeam_Red && TF2_GetClientTeam(attacker)==TFTeam_Blue){//that number is the one of the melee medic weapon
			if(damagetype==134221952){

				if(damage>Entity_GetHealth(victim)){
					function_makeZombie(victim,false);
					Client_SetScore(attacker,Client_GetScore(attacker)+1);
					function_CheckVictory();
					return Plugin_Handled;
				}
				if(SuperZombies){
					damage=damage*1000.0;
					return Plugin_Continue;
				}
				return Plugin_Continue;
			}

			return Plugin_Handled;
		}


		return Plugin_Continue;
}

public Action Evt_PlayerDeath(Event event, const char[] name, bool dontBroadcast){
	if( InfectionStarted) {

		int client = GetClientOfUserId(event.GetInt("userid"));
		Client_PrintToChat(client, false,"{BLA}[EVZ]:{N} %t", "infected");
		function_CheckVictory();
		TF2_ChangeClientTeam(client,TFTeam_Blue);
		TF2_SetPlayerClass(client, TFClass_Medic, true, true);


	}

}

public Action Evt_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast){
	function_CheckVictory();
}

public StartCap(const String:output[], caller, activator, Float:delay)
{
	AcceptEntityInput(caller, "Disable");

}


public Action Evt_RoundStart(Event event, const char[] name, bool dontBroadcast){
	function_serverCommands();
	function_AllEngineers();
	SuperZombies = false;
	InfectionStarted = false;
	ServerCommand("sm_gravity @all 1");
	ServerCommand("sm_cvar tf_boost_drain_time 0");

	if(RedWonHandle!=INVALID_HANDLE) {
		CloseHandle(RedWonHandle);
		RedWonHandle=INVALID_HANDLE;
	}

	if(SuperZombiesTimerHandle!=INVALID_HANDLE) {
		CloseHandle(SuperZombiesTimerHandle);
		SuperZombiesTimerHandle=INVALID_HANDLE;
	}

	if(InfectionHandle!=INVALID_HANDLE) {
		CloseHandle(InfectionHandle);
		InfectionHandle=INVALID_HANDLE;
	}

	if(CountDownHandle!=INVALID_HANDLE) {
		CloseHandle(CountDownHandle);
		CountDownHandle=INVALID_HANDLE;
	}

	if(CountDownStartHandle!=INVALID_HANDLE) {
		CloseHandle(CountDownStartHandle);
		CountDownStartHandle=INVALID_HANDLE;
	}

	ActualRoundTime = GetConVarFloat(zve_round_time)+GetConVarFloat(zve_setup_time);
	RedWonHandle = CreateTimer(ActualRoundTime,RedWon);
	if(GetConVarFloat(zve_super_zombies)>0.0) {
		SuperZombiesTimerHandle = CreateTimer(ActualRoundTime-GetConVarFloat(zve_super_zombies), SuperZombiesTimer);
	}

	float setupTime = GetConVarFloat(zve_setup_time);
	InfectionHandle = CreateTimer(setupTime, Infection);
	if(setupTime>11.0) {
		CountDownStartHandle = CreateTimer(setupTime-11.0, CountDownStart);
	}

	function_PrepareMap();

	Client_PrintToChatAll(false,"{BLA}[EVZ]:{N} %t", "version");
	Client_PrintToChatAll(false,"{BLA}[EVZ]:{N} %t", "red_goal");
	Client_PrintToChatAll(false,"{BLA}[EVZ]:{N} %t", "blue_goal");
	Client_PrintToChatAll(false,"{BLA}[EVZ]:{N} %t", "source_plugin");

}


public Action OpenDoors(Handle timer){

	function_sendEntitiesInput("func_door","Open");
}

public Action CountDownStart(Handle timer){

	CountDownHandle = CreateTimer(1.0, CountDown, _, TIMER_REPEAT);
	Client_PrintToChatAll(false,"{BLA}[EVZ]:{N} %t", "infection_start");
	CountDownStartHandle = INVALID_HANDLE;
}

public Action SuperZombiesTimer(Handle timer){
	Client_PrintToChatAll(false,"{BLA}[EVZ]:{N} %t", "power_up");
	SuperZombies = true;
	//Loop from smlib
	for (new client=1; client <= MaxClients; client++) {

		if (!IsClientConnected(client)) {
			continue;
		}

		if (!IsClientInGame(client)) {
			continue;
		}



		TFTeam team = TF2_GetClientTeam(client);
		TF2_AddCondition(client, view_as<TFCond>(29), 9999.0);
		if(team==TFTeam_Blue){

			SetEntProp(client, Prop_Send, "m_iHealth", 9999);
			SetEntProp(client, Prop_Data, "m_iHealth", 9999);

		}

	}

	SuperZombiesTimerHandle = INVALID_HANDLE;

}

public Action CountDown(Handle timer){
	if(CountDownCounter<10) {

		char message[] = "{R}[EVZ]:{N} ";
		char timeLeft[3];
		IntToString(10-CountDownCounter, timeLeft, 3);
		StrCat(message, sizeof(message)+3,timeLeft);
		Client_PrintToChatAll(false,message);
		CountDownCounter++;
		return Plugin_Continue;

	}else{

		CountDownCounter = 0;
		CountDownHandle = INVALID_HANDLE;
		return Plugin_Stop;

	}

}


public Action Infection(Handle timer){
	function_SelectFirstZombies();

	Client_PrintToChatAll(false,"{BLA}[EVZ]:{N} %t", "infection_unleashed");
	ServerCommand("sm_cvar tf_boost_drain_time 999");
	InfectionStarted = true;
	function_sendEntitiesInput("func_regenerate", "Disable");
	InfectionHandle = INVALID_HANDLE;

}

public Action RedWon(Handle timer){
	function_teamWin(TFTeam_Red)
	RedWonHandle=INVALID_HANDLE;

}

//FUNCTIONS
public Action function_sendEntitiesInput(const char[] entityname, const char[] input){

	int x = -1
	int EntIndex;
	bool HasFound = true;

	while(HasFound) {

		EntIndex = FindEntityByClassname (x, entityname); //finds doors

		if(EntIndex==-1) {//breaks the loop if no matching entity has been found

			HasFound=false;

		}else{

			if (IsValidEntity(EntIndex)) {

				AcceptEntityInput(EntIndex, input); //Deletes the door it.
				x = EntIndex;
			}
		}
	}

	return Plugin_Handled;
}


public Action function_AllEngineers(){
	//loop from smlib
	for (new client=1; client <= MaxClients; client++) {

		if (!IsClientConnected(client)) {
			continue;
		}

		if (!IsClientInGame(client)) {
			continue;
		}

		function_SafeTeamChange(client,TFTeam_Red);
		TF2_RespawnPlayer(client);

	}

	return Plugin_Handled;

}

public Action function_StripToMelee(int client){
	if(Client_IsValid(client) && Client_IsIngame(client)){

		TF2_AddCondition(client, view_as<TFCond>(85), TFCondDuration_Infinite, 0);
		TF2_AddCondition(client, view_as<TFCond>(41), TFCondDuration_Infinite, 0);
		TF2_RemoveCondition(client, view_as<TFCond>(85) );
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);

		return Plugin_Handled;


	}

	return Plugin_Stop;


}


public Action function_SafeTeamChange(int client, TFTeam team){

	if(IsValidEntity(client) && IsClientInGame(client)) {

		int EntProp = GetEntProp(client, Prop_Send, "m_lifeState");
		SetEntProp(client, Prop_Send, "m_lifeState", 2);
		ChangeClientTeam(client, view_as<int>(team) );
		SetEntProp(client, Prop_Send, "m_lifeState", EntProp);

		return Plugin_Handled;


	}

	return Plugin_Stop;
}
public void function_SafeRespawn(int client){
	if(IsValidEntity(client) && IsClientInGame(client)) {

		int EntProp = GetEntProp(client, Prop_Send, "m_lifeState");
		SetEntProp(client, Prop_Send, "m_lifeState", 2);
		TF2_RespawnPlayer(client);
		SetEntProp(client, Prop_Send, "m_lifeState", EntProp);


	}


}


public Action function_CheckVictory(){

	if(InfectionStarted==false) {
		return Plugin_Stop;
	}
	bool AllEngineersDead = true;
	bool AllMedicsDead = true;
	bool NoPlayer = true;
	//loop from smlib
	for (new client=1; client <= MaxClients; client++) {

		if (!IsClientConnected(client)) {
			continue;
		}

		if (!IsClientInGame(client)) {
			continue;
		}



		TFTeam team = TF2_GetClientTeam(client);

		if(team==TFTeam_Blue){
			AllMedicsDead = false;

		}else if(team==TFTeam_Red){
			AllEngineersDead = false;
		}

	}

	if(AllEngineersDead && AllMedicsDead){
		PrintToServer("Tried to trigger victory on an empty server !");
		return Plugin_Stop;
	}

	if(InfectionStarted){

		if(AllMedicsDead){
			PrintToServer("Red team won !");
			function_teamWin(TFTeam_Red);
			return Plugin_Handled;
		}

		if(AllEngineersDead){
			PrintToServer("Blue team won !");
			function_teamWin(TFTeam_Blue);
			return Plugin_Handled;

		}

	}




}

public Action function_SelectFirstZombies(){


	int PlayerCount = Client_GetCount(true,true);
	if(PlayerCount==0){
		return Plugin_Stop;
	}

	//following code will compute the needed starting blue Medics, depending on the player count.
	int StartingMedics = 0;
	if(PlayerCount > 1) { //if there is 2 or more players

		StartingMedics=1;

	}
	if(PlayerCount>5) {

		StartingMedics=2;

	}
	if(PlayerCount >10) {

		StartingMedics=3;

	}
	if(PlayerCount >18) {

		StartingMedics=4;

	}

	//following code will make needed players start as medic
	while(StartingMedics>0) {
			int client = Client_GetRandom(CLIENTFILTER_INGAMEAUTH);
			if(TF2_GetClientTeam(client)==TFTeam_Blue){
				continue;
			}
			function_makeZombie(client,true);
			StartingMedics--;
	}

	return Plugin_Handled;

}
public function_PrepareMap(){

//Disabling all other game related entities
	SetVariantInt(0);
	function_sendEntitiesInput("filter_activator_tfteam", "Kill");
	function_sendEntitiesInput("trigger_capture_area","SetTeam");
	function_sendEntitiesInput("trigger_capture_area","Disable");
	function_sendEntitiesInput("item_teamflag","Disable");
	function_sendEntitiesInput("func_respawnroomvisualizer","Disable");

	if(GetConVarFloat(zve_spawn_building)>0.0){
		function_sendEntitiesInput("func_respawnroom","Kill");
		function_sendEntitiesInput("func_nobuild", "Kill");
	}
	SetVariantBool(false);

	function_sendEntitiesInput("team_round_timer","ShowInHUD");
	function_sendEntitiesInput("team_round_timer","Pause");
	function_CreateRoundTimer();


	function_sendEntitiesInput("func_door", "Open");
	SetVariantInt(99999);
	function_sendEntitiesInput("trigger_hurt","SetDamage");
	SetVariantInt(3);

}



public void function_CreateRoundTimer(){

	char disp[8] ="";
	int entIndex = CreateEntityByName("team_round_timer");
	IntToString(entIndex,disp,8);
	PrintToServer(disp);
	char round_length[8]="";
	char setup_length[8]="";
	IntToString(GetConVarInt(zve_round_time),round_length,8);
	PrintToServer(round_length);
	IntToString(RoundFloat(GetConVarFloat(zve_setup_time)),setup_length,8);
	DispatchKeyValue(entIndex,"timer_length",round_length);
	DispatchKeyValue(entIndex,"setup_length",setup_length);
	DispatchKeyValue(entIndex,"start_paused","0");
	DispatchKeyValue(entIndex,"show_in_hud","1");
	DispatchSpawn(entIndex);
	ActivateEntity(entIndex);
	AcceptEntityInput(entIndex,"Enable");
	SetVariantBool(true);
	AcceptEntityInput(entIndex,"ShowInHUD")


}


public Action function_makeZombie(int client, bool firstInfected){
	if(!(Client_IsValid(client) && Client_IsIngame(client))){

		return Plugin_Stop;

	}

	int EntProp = GetEntProp(client, Prop_Send, "m_lifeState");
	SetEntProp(client, Prop_Send, "m_lifeState", 2);
	ChangeClientTeam(client, view_as<int>(TFTeam_Blue) );
	TF2_SetPlayerClass(client, TFClass_Medic, true, true);
	SetEntProp(client, Prop_Send, "m_lifeState", EntProp);
	TF2_RegeneratePlayer(client);
	function_StripToMelee(client);

	SetEntProp(client, Prop_Send, "m_iHealth", ZombieHealth);
	SetEntProp(client, Prop_Data, "m_iHealth", ZombieHealth);

	float clientPos[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", clientPos);
	Explode(clientPos, 0.0, 500.0, "merasmus_bomb_explosion_blast", "vo/medic_medic03.mp3");
	if(firstInfected){
		TF2_AddCondition(client, view_as<TFCond>(29), 30.0);
		SetEntProp(client, Prop_Send, "m_iHealth", ZombieHealth*2);
		SetEntProp(client, Prop_Data, "m_iHealth", ZombieHealth*2);
	}

	return Plugin_Handled;

}
//code found in snippets section of the forum
public void Explode(float flPos[3], float flDamage, float flRadius, const char[] strParticle, const char[] strSound)
{
    int iBomb = CreateEntityByName("tf_generic_bomb");
    DispatchKeyValueVector(iBomb, "origin", flPos);
    DispatchKeyValueFloat(iBomb, "damage", flDamage);
    DispatchKeyValueFloat(iBomb, "radius", flRadius);
    DispatchKeyValue(iBomb, "health", "1");
    DispatchKeyValue(iBomb, "explode_particle", strParticle);
    DispatchKeyValue(iBomb, "sound", strSound);
    DispatchSpawn(iBomb);

    AcceptEntityInput(iBomb, "Detonate");
}
public Action function_teamWin(TFTeam team) //modified version of code in smlib
{
	//avoiding team not initialized crash
	if(Client_GetCount(true,true)<2){
		return Plugin_Stop;
	}

	InfectionStarted = false;
	new game_round_win = FindEntityByClassname(-1, "game_round_win");

	if (game_round_win == -1) {
		game_round_win = CreateEntityByName("game_round_win");

		if (game_round_win == -1) {
			ThrowError("Unable to find or create entity \"game_round_win\"");
		}
	}

	SetEntProp(game_round_win, Prop_Data,"m_bForceMapReset",1);
	SetEntProp(game_round_win, Prop_Data,"m_bSwitchTeamsOnWin",0);

	SetVariantInt(view_as<int>(team));
	AcceptEntityInput(game_round_win, "SetTeam");
	AcceptEntityInput(game_round_win, "RoundWin");

	return Plugin_Handled;

}

public void function_serverCommands(){

	ServerCommand("mp_disable_respawn_times 1");
	ServerCommand("mp_teams_unbalance_limit 30");
	ServerCommand("mp_idledealmethod 2");
	ServerCommand("mp_autoteambalance 0");
	ServerCommand("mp_scrambleteams_auto 0");
	ServerCommand("tf_weapon_criticals_melee 0");
	ServerCommand("sm_cvar tf_fastbuild 1");
	ServerCommand("tf_bot_kick all");
}
