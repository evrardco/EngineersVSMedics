#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <tf2items>
#include <clients>
#include <morecolors>
#include <adminmenu>


#define LoopAlivePlayers(%1) for (int %1 = 1; %1 <= MaxClients; ++%1) if (IsClientInGame(%1) && IsPlayerAlive(%1) && !IsFakeClient(%1))
#define TEAM_BLU 3
#define TEAM_RED 2
int DiedYet[64]; //this array stores wether a player is in the game and wether a player is in blue or red team
int GameStarted=0; //this int stores the amount of time the game has been started, resets when the game ends.
int g_iRedCounter;
bool IsSettingTeam = false; //this bool switches to false when balancing teams so that the player death trackers doesn't messes up
bool ZombieStarted = false; //This variable is set to true after some time after round start to prevent victory from triggering too soon
ConVar zve_setup_time = null;
ConVar zve_round_time = null;
ConVar zve_tanks = null;
ConVar zve_super_zombies = null;
bool WaitingEnded = false;
Handle RedWonHandle = INVALID_HANDLE;
Handle SuperZombiesTimerHandle = INVALID_HANDLE;
// Glow Plugin from ReflexPoision starts here
Handle cvarEnabled;
Handle cvarRemember;
Handle Version;
Handle hAdminMenu;
Handle cvarLogs;
Handle cvarAnnounce;
// Glow plugin handles stop here
Handle:cvarCorpseDelay = INVALID_HANDLE;
Handle:cvarCorpseType = INVALID_HANDLE;
Handle:g_cvJumpBoost = INVALID_HANDLE,
Handle:g_cvJumpEnable = INVALID_HANDLE,
Handle:g_cvJumpMax = INVALID_HANDLE,
Float:g_flBoost = 250.0,
bool:g_bDoubleJump = true,
Handle:zve_last_human_hp_amount;

g_fLastButtons[MAXPLAYERS+1],
g_fLastFlags[MAXPLAYERS+1],
g_iJumps[MAXPLAYERS+1],
g_iJumpMax


bool isOutlined[MAXPLAYERS + 1] = { false, ... };
int CountDownCounter = 0;
bool SuperZombies = false;
/* HOW THIS PLUGIN WORKS:
 *	Basically, it keeps track of wether a player has died or not during a game (in the DiedYet array)
 *	when a player is connected it has its DiedYet value set to -1 if the game has started, 1 else.
 *	when a player dies, it has its DiedYet value set to -1 too.
 *  if a player has its DiedYet value set to -1, it will spawn as a blue medic
 *      if a player has its DiedYet value set to 1, it will spawn as a red engineer.
 *	Any sentry will instantly be destroyed and blue medics can only use melee weapons.
 */
 
 new const String:PLUGIN_VERSION[] = "1.0.1";

public Plugin myinfo ={
	name = "Engineers Vs Zombies",
	author = "shewowkees",
	description = "zombie like gamemode",
	version = "1.2",
	url = "noSiteYet"
};

public void OnPluginStart (){
	PrintToServer("{collectors}Engies vs Medics V1.2 by shewowkees, edited by weird fox & inspired by Muselk.");
	CreateConVar("sm_force_end_round_version", PLUGIN_VERSION, "k", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	RegAdminCmd("sm_zsfer", ForceGameEnd, ADMFLAG_BAN, "sm_zsfer [team]");
	RegAdminCmd("sm_zsforceendround", ForceGameEnd, ADMFLAG_BAN, "sm_zsforceendround [team]");
	// ReflexPoision outline code
	RegAdminCmd("sm_zve_outline", OutlineCmd, 0, "sm_zve_outline <#userid|name> <1/0> - Toggles outline on player(s)");
	LoadTranslations("common.phrases");
	HookEvent("player_spawn",Event_PlayerSpawnChangeClass,EventHookMode_Post);
	HookEvent("player_spawn",Event_PlayerSpawnChangeTeam,EventHookMode_Pre);
	HookEvent("player_death",Event_PlayerDeath,EventHookMode_Post);
	HookEvent("tf_game_over",Event_TFGameOver,EventHookMode_Post);
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("teamplay_waiting_begins",Event_WaitingBegins,EventHookMode_Post);
	HookEvent("player_disconnect",Event_PlayerDisconnect,EventHookMode_Post);
	HookEvent("player_spawn", OnPlayerSpawn);
	HookEvent("player_team", Event_PlayerTeam);
	AddCommandListener(CommandListener_Build, "build");
	AddCommandListener(CommandListener_ChangeClass, "joinclass");
	AddCommandListener(CommandListener_ChangeTeam, "jointeam");
	AddCommandListener(CommandListener_Kill, "kill");
	AddCommandListener(CommandListener_Spectate, "spectate");
	AddCommandListener(CommandListener_explode, "explode");
	// Glow Plugin from ReflexPoision starts here
	Handle topmenu;
	if(LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != INVALID_HANDLE))
    {
        OnAdminMenuReady(topmenu);
    }
	//CONVARS
	//ReflexPoison Glow Plugin Cvars start here
	cvarEnabled = CreateConVar("sm_zve_outline_enabled", "1", "Enable Player Outline\n0 = Disabled\n1 = Enabled", _, true, 0.0, true, 1.0);
	cvarRemember = CreateConVar("sm_zve_outline_remember", "0", "Enable re-toggles of outlines on spawn\n0 = Disabled\n1 = Enabled", _, true, 0.0, true, 1.0);
	cvarLogs = CreateConVar("sm_zve_outline_logs", "1", "Enable logs of outline toggles\n0 = Disabled\n1 = Enabled", _, true, 0.0, true, 1.0);
	cvarAnnounce = CreateConVar("sm_zve_outline_announce", "1", "Enable announcements of outline toggles\n0 = Disabled\n1 = Enabled", _, true, 0.0, true, 1.0);
    //ReflexPoison Glow Plugin Cvars ends here
	zve_round_time = CreateConVar("zve_round_time", "314", "Round time, 5 minutes by default.");		
	zve_setup_time = CreateConVar("zve_setup_time", "45.0", "Setup time, 30s by default.");
	zve_super_zombies = CreateConVar("zve_super_zombies", "30.0", "How much time before round end zombies gain super abilities. Set to 0 to disable it.")
	zve_tanks = CreateConVar("zve_tanks", "60.0", "How much time after setup the first zombies have a health boost. Set to 0 to disable it.")
	cvarCorpseDelay = CreateConVar("sm_zve_corpse_delay",	"2", "How much time before an players corpse dissapears / dissolves");
	cvarCorpseType = CreateConVar("sm_zve_corpsekill_type", "0", "What type of way do you want the corpse to dissapear / dissolve?");
	AutoExecConfig(true, "plugin_zve");
	AutoExecConfig(true, "plugin.zve_playeroutline");
	LoadTranslations("common.phrases");
	LoadTranslations("engiesVSmedics.phrases");
	g_iRedCounter = GetRedCount();
	g_cvJumpEnable = CreateConVar("sm_zve_doublejump_enabled", "1", "Enables double-jumping.", FCVAR_NOTIFY)
	g_cvJumpBoost = CreateConVar("sm_zve_doublejump_boost", "250.0", "The amount of vertical boost to apply to double jumps.", FCVAR_NOTIFY)
	g_cvJumpMax = CreateConVar("sm_zve_doublejump_max", "1", "The maximum number of re-jumps allowed while already jumping.", FCVAR_NOTIFY)
	zve_last_human_hp_amount = CreateConVar("sm_zve_last_human_hp_amount", "350", "Amount of life to change health to upon spawn", true, 1.0, false, _);
	HookConVarChange(g_cvJumpBoost,		convar_ChangeBoost)
	HookConVarChange(g_cvJumpEnable,	convar_ChangeEnable)
	HookConVarChange(g_cvJumpMax,		convar_ChangeMax)
	g_bDoubleJump	= GetConVarBool(g_cvJumpEnable)
	g_flBoost		= GetConVarFloat(g_cvJumpBoost)
	g_iJumpMax		= GetConVarInt(g_cvJumpMax)
	CreateTimer(0.5, Timer_GetCount, _, TIMER_REPEAT);
}

public convar_ChangeBoost(Handle:convar, const String:oldVal[], const String:newVal[]) {
	g_flBoost = StringToFloat(newVal)
}

public convar_ChangeEnable(Handle:convar, const String:oldVal[], const String:newVal[]) {
	if (StringToInt(newVal) >= 1) {
		g_bDoubleJump = true
	} else {
		g_bDoubleJump = false
	}
}

public OnGameFrame() {
	if (g_bDoubleJump) {							// double jump active
		for (new i = 1; i <= MaxClients; i++) {		// cycle through players
			if (
				IsClientInGame(i) &&				// is in the game
				IsPlayerAlive(i) &&					// is alive
				GetClientTeam(i) == 3				// is player on blue
			) {
				DoubleJump(i)						// Check for double jumping
			}
		}
	}
}

stock DoubleJump(const any:client) {
	new
		fCurFlags	= GetEntityFlags(client),		// current flags
		fCurButtons	= GetClientButtons(client)		// current buttons
	
	if (g_fLastFlags[client] & FL_ONGROUND) {		// was grounded last frame
		if (
			!(fCurFlags & FL_ONGROUND) &&			// becomes airbirne this frame
			!(g_fLastButtons[client] & IN_JUMP) &&	// was not jumping last frame
			fCurButtons & IN_JUMP					// started jumping this frame
		) {
			OriginalJump(client)					// process jump from the ground
		}
	} else if (										// was airborne last frame
		fCurFlags & FL_ONGROUND						// becomes grounded this frame
	) {
		Landed(client)								// process landing on the ground
	} else if (										// remains airborne this frame
		!(g_fLastButtons[client] & IN_JUMP) &&		// was not jumping last frame
		fCurButtons & IN_JUMP						// started jumping this frame
	) {
		ReJump(client)								// process attempt to double-jump
	}
	
	g_fLastFlags[client]	= fCurFlags				// update flag state for next frame
	g_fLastButtons[client]	= fCurButtons			// update button state for next frame
}

stock OriginalJump(const any:client) {
	g_iJumps[client]++	// increment jump count
}

stock Landed(const any:client) {
	g_iJumps[client] = 0	// reset jumps count
}

stock ReJump(const any:client) {
	if ( 1 <= g_iJumps[client] <= g_iJumpMax) {						// has jumped at least once but hasn't exceeded max re-jumps
		g_iJumps[client]++											// increment jump count
		decl Float:vVel[3]
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel)	// get current speeds
		
		vVel[2] = g_flBoost
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel)		// boost player
	}
}


public convar_ChangeMax(Handle:convar, const String:oldVal[], const String:newVal[]) {
	g_iJumpMax = StringToInt(newVal)
}

public Action ForceGameEnd(client, args)
{
	if (args != 0 && args != 1)
	{
		ReplyToCommand(client, "sm_zsfer / sm_zsforceendround [Winning Team: Red/Blue/None]");
		return Plugin_Handled;
	}
	
	new iEnt = -1;
	iEnt = FindEntityByClassname(iEnt, "game_round_win");
	
	if (iEnt < 1)
	{
		iEnt = CreateEntityByName("game_round_win");
		if (IsValidEntity(iEnt))
			DispatchSpawn(iEnt);
		else
		{
			ReplyToCommand(client, "Unable to find or create a game_round_win entity!");
			return Plugin_Handled;
		}
	}
	
	new iWinningTeam = 0;
	if (client) 
		iWinningTeam = GetClientTeam(client);
	
	if (args == 1)
	{
		decl String:buffer[32];
		GetCmdArg(1, buffer, sizeof(buffer));
	
		if (StrEqual(buffer, "blue", false))
			iWinningTeam = 3;
		else if (StrEqual(buffer, "red", false))
			iWinningTeam = 2;
		else if (StrEqual(buffer, "none", false))
			iWinningTeam = 0;
	}
	
	if (iWinningTeam == 1)
		iWinningTeam --;
		
	SetVariantInt(iWinningTeam);
	AcceptEntityInput(iEnt, "SetTeam");
	AcceptEntityInput(iEnt, "RoundWin");
	
	return Plugin_Handled;
}

/*
 * This method disables respawn times and prevents teams auto balance.
 * It also makes the server ban the idle players immediatly, only switching
 *	them to spectator mode would cause the plugin to misbehave.
 *
 */
public OnMapStart(){
	function_ResetPlugin();
	ServerCommand("mp_disable_respawn_times 1");
	ServerCommand("mp_teams_unbalance_limit 30");
	ServerCommand("mp_idledealmethod 2");
	ServerCommand("mp_autoteambalance 0");
	ServerCommand("mp_idlemaxtime 10");
	ServerCommand("mp_waitingforplayers_time 35");
	ServerCommand("mp_scrambleteams_auto 0");
	WaitingEnded = false;


}
// public OnEventShutdown()
// {
// UnHookEvent("player_spawn",Event_PlayerSpawnChangeClass);
// UnHookEvent("player_spawn",Event_PlayerSpawnChangeTeam);
// UnHookEvent("player_death",Event_PlayerDeath);
// UnHookEvent("tf_game_over",Event_TFGameOver);
// UnHookEvent("player_regenerate",Event_PlayerRegenerate);
// UnHookEvent("teamplay_round_start", Event_RoundStart);
// UnHookEvent("teamplay_waiting_begins",Event_WaitingBegins);
// UnHookEvent("player_disconnect",Event_PlayerDisconnect);
// }
/*
 * This method initializes DiedYet of the connecting client to the right value.
 */
public void OnClientPostAdminCheck(int client){
	if(function_countPlayers()==0){

		function_ResetPlugin();

	}
	if(ZombieStarted) {
		DiedYet[client]=-1;
	}else{
		DiedYet[client]=1;
	}


}

int GetTeamAliveClientCount(int iTeam) {
    int iCount;
   
    LoopAlivePlayers(i) {
        if (GetClientTeam(i) == iTeam)
            iCount++;
    }
   
    return iCount;
}


public void TF2_OnWaitingForPlayersEnd(){

	WaitingEnded = true;

}




//EVENTS




//PLAYER RELATED EVENTS

/*
 * This code is from Tsunami's TF2 build restrictions. It prevents engineers
 * from even placing a sentry.
 *
 */
public Action CommandListener_Build(client, const String:command[], argc)
{

	// Get arguments
	decl String:sObjectType[256]
	GetCmdArg(1, sObjectType, sizeof(sObjectType));

	// Get object mode, type and client's team
	new iObjectType = StringToInt(sObjectType),
	iTeam       = GetClientTeam(client);

	// If invalid object type passed, or client is not on Blu or Red
	if(iObjectType < view_as<int>(TFObject_Dispenser) || iObjectType > view_as<int>(TFObject_Sentry) || iTeam < view_as<int>(TFTeam_Red) ) {

		return Plugin_Continue;
	}

	//Blocks sentry building
	else if(iObjectType==view_as<int>(TFObject_Sentry) ) {
		CPrintToChat(client, "{whitesmoke}[{red}EVZ{whitesmoke}] {fullred}You can't build sentries in this gamemode!");
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action CommandListener_ChangeTeam(client, const String:command[],argc){
	decl String:arg1[256]
	GetCmdArg(1, arg1, sizeof(arg1));
	if(strcmp(arg1,"blue",false)==0 && DiedYet[client] == -1) {

		return Plugin_Continue;

	}else if(DiedYet[client]==-1) {

		ClientCommand(client,"jointeam blue");

	}
	if(strcmp(arg1,"red",false)==0 && DiedYet[client]== 1) {

		return Plugin_Continue;

	}else if(DiedYet[client]==1) {

		ClientCommand(client,"jointeam red");

	}
	CPrintToChat(client, "{whitesmoke}[{red}EVZ{whitesmoke}] {fullred}You can't betray your team in this gamemode!");
	return Plugin_Handled;
	// decl String:arg1[256]
	// GetCmdArgString(arg1, sizeof(arg1));
	// PrintToChatAll(arg1);
	// return Plugin_Continue;

}

public Action CommandListener_ChangeClass(client,const String:command[], argc){
	decl String:arg1[256]
	GetCmdArg(1, arg1, sizeof(arg1));
	if(strcmp(arg1,"medic",false)==0 && DiedYet[client] == -1) {

		return Plugin_Continue;

	}else if(DiedYet[client]==-1) {

		ClientCommand(client,"joinclass medic");

	}
	if(strcmp(arg1,"engineer",false)==0 && DiedYet[client]== 1) {

		return Plugin_Continue;

	}else if(DiedYet[client]==1) {

		ClientCommand(client,"joinclass engineer");

	}
	CPrintToChat(client, "{whitesmoke}[{red}EVZ{whitesmoke}] {fullred}You can't change your class in this gamemode!");
	return Plugin_Handled;
	// decl String:arg1[256]
	// GetCmdArgString(arg1, sizeof(arg1));
	// PrintToChatAll(arg1);
	// return Plugin_Continue;
}

public Action CommandListener_Kill(client, const String:command[], argc){
	CPrintToChat(client, "{whitesmoke}[{red}EVZ{whitesmoke}] {fullred}You can't kill yourself in this gamemode!");
	return Plugin_Handled;

}

public Action CommandListener_explode(client, const String:command[], argc){
	CPrintToChat(client, "{whitesmoke}[{red}EVZ{whitesmoke}] {fullred}You can't kill yourself in this gamemode!");
	return Plugin_Handled;

}

public Action CommandListener_Spectate(client, const String:command[], argc){
	CPrintToChat(client, "{whitesmoke}[{red}EVZ{whitesmoke}] {fullred}You can't go spectator in this gamemode!");
	return Plugin_Handled;
}

/*
 * This method forces the spawning player to switch to the right team BEFORE he appears
 */
public Action Event_PlayerSpawnChangeTeam(Event event, const char[] name, bool dontBroadcast){

	int client = GetClientOfUserId(event .GetInt("userid"));
	if(DiedYet[client]==-1 && TF2_GetClientTeam(client)==TFTeam_Red) { //if client is supposed to be a blue medic
		function_SafeTeamChange(client,TFTeam_Blue);
		TF2_RespawnPlayer(client);

	}else if(DiedYet[client]==1) { //if the client is supposed to be a red engineer.

		if( TF2_GetClientTeam(client)==TFTeam_Blue ) {
			DiedYet[client]=-1;
		}

	}
}
/*
 * This method forces the player to be on the right team, the right class and to use the right weapons.
 */
public Action Event_PlayerSpawnChangeClass(Event event, const char[] name, bool dontBroadcast){

	int client = GetClientOfUserId(event .GetInt("userid"));
	if(DiedYet[client]==0) {

		if(GameStarted>0) {
			DiedYet[client]=-1;
		}else{
			DiedYet[client]=1;
		}

	}
	if(DiedYet[client]==-1 || DiedYet[client]==0) { //if client is supposed to be a blue medic


		if( TF2_GetPlayerClass(client) != TFClass_Medic) { //if he isn't a medic, changes his class,  him and makes him respawn.
			CPrintToChat(client,"{whitesmoke}[{red}EVZ{whitesmoke}] {fullred}As a zombie, you can only be a medic!");
			TF2_SetPlayerClass(client, TFClass_Medic, true, true);
			TF2_RegeneratePlayer(client);
		}


		function_StripToMelee(client);
		function_MakeSuperZombie(client);

	}else if(DiedYet[client]==1) { //if the client is supposed to be a red engineer.


		if( TF2_GetPlayerClass(client) != TFClass_Engineer) {        //if the client isn't an engineer, changes his class, kills him and makes him respawn
			CPrintToChat(client,"{whitesmoke}[{red}EVZ{whitesmoke}] {fullred}As a human, you can only be engineer!");
			TF2_SetPlayerClass(client, TFClass_Engineer, true, true);
			DiedYet[client]=1;         //sets the diedyet value to 1 because the suicide would set it to -1
			TF2_RegeneratePlayer(client);
		}


	}
	function_CheckVictory();
}
/*
 * This method updates the DiedValue of a player if needed,changes his team and checks for victory
 */
public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast){ //On player death, sets his DiedYet value to -1
	

	RequestFrame(NextFrame_CheckPlayerCount);
	
	int client = GetClientOfUserId(event .GetInt("userid"));
	
	new Float:corpsedelay = GetConVarFloat(cvarCorpseDelay);
	if (corpsedelay>0.0)
	{
    	CreateTimer(corpsedelay, Dissolve, client); 
  	}
  	else
  	{
    	Dissolve(INVALID_HANDLE, client);
  	}

	if(WaitingEnded && ZombieStarted && !IsSettingTeam) {
		
		if(GameStarted>0) {
			CPrintToChat(client,"{whitesmoke}[{red}EVZ{whitesmoke}] {fullred}You have been infected, you cannot change to humans again!");
			DiedYet[client] = -1;
			TF2_ChangeClientTeam(client,TFTeam_Blue);
			TF2_SetPlayerClass(client, TFClass_Medic, true, true);

		}
		function_CheckVictory();
	}

	if (TF2_GetClientTeam(client) != TFTeam_Red)
		return Plugin_Continue;
		
	FindLastPlayer();
	
	return Plugin_Continue;
}

public void NextFrame_CheckPlayerCount(any data)
{
	if (GetTeamAliveClientCount(TEAM_RED) == 1)
    {
    	ServerCommand("sm_zve_outline @red 1");	
    }
	else if (GetTeamAliveClientCount(TEAM_RED) == 0)
	{
		ServerCommand("sm_zsfer blue");
		ServerCommand("sm_zve_outline @red 0");
	}
}


/*
 * This method resets a player's DiedYet value when he disconnects.
 */
public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast){

	int client = GetClientOfUserId(event .GetInt("userid"));
	DiedYet[client] = 0;
	function_CheckVictory();




}

//ROUND RELATED EVENTS


/*
 * This functions decrements GameStarted because it will be incremented when the waiting begins
 */
public Action Event_WaitingBegins(Event event, const char[] name, bool dontBroadcast){
	GameStarted=-1;
}
/*
 * This method deletes all unwanted elements from the map and balances the teams
 */
public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast){
	g_iRedCounter = GetRedCount();
	ServerCommand("sm_zve_outline @red 0");
	RequestFrame(NextFrame_CheckPlayerCount);
	SuperZombies = false;
	ServerCommand("sv_gravity 800");
	if(RedWonHandle!=INVALID_HANDLE) {
		KillTimer(RedWonHandle,false);
		RedWonHandle=INVALID_HANDLE;
	}
	if(SuperZombiesTimerHandle!=INVALID_HANDLE) {
		KillTimer(SuperZombiesTimerHandle,false);
		SuperZombiesTimerHandle=INVALID_HANDLE;
	}
	float ActualRoundTime = GetConVarFloat(zve_round_time)+GetConVarFloat(zve_setup_time);
	RedWonHandle = CreateTimer(ActualRoundTime,RedWon);
	if(GetConVarFloat(zve_super_zombies)>0.0) {
		SuperZombiesTimerHandle = CreateTimer(ActualRoundTime-GetConVarFloat(zve_super_zombies), SuperZombiesTimer);
	}

	function_PrepareMap();
	if(WaitingEnded) {
		function_ResetTeams(true);
	}

	CreateTimer(2.30,Stun);
	GameStarted++;
	CPrintToChatAll("{whitesmoke}[{red}EVZ{whitesmoke}] {gold}This server is running Engineers vs Zombies V1.2 edited by weird fox / SnowTigerVidz");
	CPrintToChatAll("{whitesmoke}[{red}EVZ{whitesmoke}] {gold}The goal for the humans (red team) is to survive as long as they can.");
	CPrintToChatAll("{whitesmoke}[{red}EVZ{whitesmoke}] {gold}The goal for the zombies (blue team) is to kill all humans and turn them into zombies (medics)!");
	CPrintToChatAll("{whitesmoke}[{red}EVZ{whitesmoke}] {gold}This plugin can be downloaded from www.sourcemod.net (sources included)");
	//PrintToServer("GameStarted incremented");//Debugging instruction


}

public Action Event_TFGameOver(Event event, const char[] name, bool dontBroadcast){ //Once the game is over, resets the DiedYet values

	GameStarted = 0;


}


//TIMERS
public Action SuperZombiesTimer(Handle timer){
	CPrintToChatAll("{whitesmoke}[{red}EVZ{whitesmoke}] {fullred}Zombies have gained crits and a jump boost!");
	SuperZombies = true;
	ServerCommand("sm_zve_doublejump_boost 450");
	for(int i=0; i<64; i++) {
		if(DiedYet[i]==-1) {

			function_MakeSuperZombie(i);

		}
	}
	SuperZombiesTimerHandle = INVALID_HANDLE;


}

public Action Stun(Handle timer){
	function_StunTeam(TFTeam_Blue);
	if(WaitingEnded) {
		float setupTime = GetConVarFloat(zve_setup_time);
		CreateTimer(setupTime, Infection);
		if(setupTime>11.0) {
			CreateTimer(setupTime-11.0, CountDownStart);
		}
	}


}
public Action CountDownStart(Handle timer){

	CreateTimer(1.0, CountDown, _, TIMER_REPEAT);
	CPrintToChatAll("{whitesmoke}[{red}EVZ{whitesmoke}] {fullred}Infection starts in...");

}
public Action CountDown(Handle timer){
	if(CountDownCounter<10) {
		char message[] = "{whitesmoke}[{red}EVZ{whitesmoke}] {fullred}";
		char timeLeft[3];
		IntToString(10-CountDownCounter, timeLeft, 3);
		StrCat(message, sizeof(message)+3,timeLeft);
		CPrintToChatAll(message);
		CountDownCounter++;
		return Plugin_Continue;
	}else{
		CountDownCounter = 0;
		KillTimer(timer, false);
		return Plugin_Stop;

	}


}

public Action Infection(Handle timer){
	CPrintToChatAll("{whitesmoke}[{red}EVZ{whitesmoke}] {fullred}The Zombies have been unleashed!");
	ZombieStarted = true;
	function_DeleteDoors();
}
public Action RedWon(Handle timer){

	function_teamWin(TFTeam_Red);
	ServerCommand("sm_zsfer red");	
	RedWonHandle=INVALID_HANDLE;

}


//FUNCTIONS



/*
 * This function deletes all element that can influence game winning from the map.
 * The game winngin elements part is from perky (hide n seek plugin).
 *
 * @param -
 * @return -
 */
public function_PrepareMap(){

	//code below is from Perky in Hide n seek plugin, it disables cp and ctf gamemodes.
	//following code disables cp and pl
	SetVariantInt(0);
	function_sendEntitiesInput("trigger_capture_area","SetTeam");
	function_sendEntitiesInput("trigger_capture_area","Disable");
	function_sendEntitiesInput("item_teamflag","Disable");
	SetVariantInt(0);
	function_sendEntitiesInput("team_round_timer","SetSetupTime");
	SetVariantInt(GetConVarInt(zve_round_time)+GetConVarInt(zve_setup_time));
	function_sendEntitiesInput("team_round_timer","SetTime");


}
/*
 * This function deletes door and spawnroom things
 */
public function_DeleteDoors(){ //following code opens all doors. This part was made by myself

	function_deleteEntities("func_door",true);
	function_deleteEntities("func_door_rotating",true);
	function_deleteEntities("func_respawnroomvisualizer",false);
	function_deleteEntities("func_regenerate", false);
	function_sendEntitiesInput("trigger_teleport","Enable");

}
/*
 * This functions makes a team given in argument win.
 * The code is from perky, author of the hide n seek plugin
 *
 * @param team		The TFTeam that will win.
 * @return -
 */
public void function_teamWin(TFTeam team) //code from hide n seek
{
	//this code kills the timer that makes redteam win

	//this is the code that actually makes a team win
	int edict_index = FindEntityByClassname(-1, "team_control_point_master");
	if (edict_index == -1)
	{
		int g_ctf = CreateEntityByName("team_control_point_master");
		DispatchSpawn(g_ctf);
		AcceptEntityInput(g_ctf, "Enable");
	}

	int search = FindEntityByClassname(-1, "team_control_point_master")
	SetVariantInt(view_as<int>(team) );
	AcceptEntityInput(search, "SetWinner");

	//AcceptEntityInput(search, "SetTeam");
	//AcceptEntityInput(search, "RoundWin");
	//AcceptEntityInput(search, "kill");





}
/*
 * This function computes the teams balance depending on the player counts and
 * puts them in the right team and if kills is true, it kills all the players.
 *
 * @param kills		Wether the function should kill the players or not.
 * @return -
 *
 *
 */



public void function_ResetTeams(bool kills){

	IsSettingTeam=true;
	function_AllEngineers(false);
	//following code counts the connected players
	int PlayerCount=0;
	for(int i=0; i<64; i++) {

		if(DiedYet[i]!=0) {

			PlayerCount++;

		}

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
		int i = GetRandomInt(0,63);
		if(DiedYet[i]==1) {
			DiedYet[i]=-1;
			StartingMedics--;

		}
	}
	//Kills all the players
	if(kills) {

		for(int i=0; i<64; i++) {

			if(DiedYet[i]==-1) {

				if(IsClientInGame(i)) {
					function_SafeTeamChange(i,TFTeam_Blue);
					TF2_RespawnPlayer(i);

				}

			}

		}

	}

	IsSettingTeam=false;


}
/*
 * This function checks if victory conditions for blue team are met and
 * triggers the victory and resets teams if needed.
 *
 * @param -
 * @return -
 *
 *
 */
public void function_CheckVictory(){

	if(ZombieStarted==false) {
		return;
	}

	bool AllEngineersDead = true;
	for(int i=0; i<64; i++) {
		if(DiedYet[i]==1) {

			AllEngineersDead=false;

		}

	}
	if(AllEngineersDead) {
		function_teamWin(TFTeam_Blue);
		ZombieStarted=false;
	}

}

/*
 * This function puts all players to red engineers.
 *
 * @param kill          if true, will kill the players and force their respawn.
 * @return -
 *
 *
 */
public void function_AllEngineers(bool kill){
	for(int i=0; i<64; i++) {
		if(DiedYet[i]!=0) {
			DiedYet[i]=1;
			function_SafeTeamChange(i,TFTeam_Red);
			TF2_RespawnPlayer(i);
			if(kill==true) {
				ForcePlayerSuicide(i);
				TF2_RegeneratePlayer(i);
			}

		}

	}

}
/* This function stuns all the players of a given team
 *
 */

public void function_StunTeam(TFTeam team){
	float time = GetConVarFloat(zve_setup_time);
	if(time>30.0) {
		time=30.0
	}
	int cmp=-10;
	if(team==TFTeam_Blue) {
		cmp=-1;
	}else if(team==TFTeam_Red) {
		cmp=1;
	}

	for(int i=0; i<64; i++) {

		if(DiedYet[i]==cmp) {
			TF2_StunPlayer(i, time, 0.0, TF_STUNFLAG_BONKSTUCK, 0);
			TF2_AddCondition(i,view_as<TFCond>(55), GetConVarFloat(zve_setup_time)+GetConVarFloat(zve_tanks), 0);
		}

	}
}
/*
 * This function resets every global scope variable
 */
public void function_ResetPlugin(){
	int EmptyDiedYet[64];
	DiedYet = EmptyDiedYet;
	GameStarted=0;   //this int stores the amount of time the game has been started, resets when the game ends.
	IsSettingTeam = false;   //this bool switches to false when balancing teams so that the player death trackers doesn't messes up
	ZombieStarted = false;
}

public void function_StripToMelee(int client){

	TF2_AddCondition(client, view_as<TFCond>(85), TFCondDuration_Infinite, 0);
	TF2_AddCondition(client, view_as<TFCond>(41), TFCondDuration_Infinite, 0);
	TF2_RemoveCondition(client, view_as<TFCond>(85) );
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);

}

public void function_MakeSuperZombie(int client){

	if(SuperZombies) {
		TF2_AddCondition(client, view_as<TFCond>(38), TFCondDuration_Infinite, 0);
	}


}

public void function_SafeTeamChange(int client, TFTeam team){

	if(IsValidEntity(client) && IsClientInGame(client)) {

		int EntProp = GetEntProp(client, Prop_Send, "m_lifeState");
		SetEntProp(client, Prop_Send, "m_lifeState", 2);
		ChangeClientTeam(client, view_as<int>(team) );
		SetEntProp(client, Prop_Send, "m_lifeState", EntProp);


	}
}

public void function_sendEntitiesInput(const char[] entityname, const char[] input){

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
}

public void function_deleteEntities(const char[] entityname, bool isDoor){

	if(isDoor){
		function_sendEntitiesInput(entityname, "Open");
	}
	function_sendEntitiesInput(entityname,"Kill");

}

public int function_countPlayers(){
	int count=0;
	for(int i=0;i<64;i++){

		if(DiedYet[i]!=0){
			count++;
		}

	}
	return count;
}

// ReflexPoison Most of Outline Player Code Starts here
public CVarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
    if(convar == cvarEnabled && !GetConVarBool(cvarEnabled))
    {
        for(new i = 1; i <= MaxClients; i++)
        {
            isOutlined[i] = false;
            SetEntProp(i, Prop_Send, "m_bGlowEnabled", 0);
        }
    }
    if(convar == Version)
    {
        SetConVarString(Version, PLUGIN_VERSION);
    }
}

public OnClientPutInServer(client)
{
    isOutlined[client] = false;
}

public Action OutlineCmd(client, args)
{
    if(!GetConVarBool(cvarEnabled))
    {
        return Plugin_Continue;
    }
    if(args == 0)
    {
        if(client == 0)
        {
            PrintToServer("Usage: sm_zve_outline <#userid|name> <1/0>");
            return Plugin_Handled;
        }
        else if(!isOutlined[client])
        {
            Outline(client, true);
            if(GetConVarBool(cvarLogs))
            {
                LogAction(client, client, "\"%L\" added player outline on \"%L\"", client, client);
            }
            return Plugin_Handled;
        }
        else if(isOutlined[client])
        {
            Outline(client, false);
            if(GetConVarBool(cvarLogs))
            {
                LogAction(client, client, "\"%L\" removed player outline from \"%L\"", client, client);
            }
            return Plugin_Handled;
        }
    }
    if(args == 1)
    {
        if(!CheckCommandAccess(client, "sm_zve_outline_target", ADMFLAG_GENERIC))
        {
            ReplyToCommand(client, "[SM] %t.", "No Access");
            return Plugin_Handled;
        }
        ReplyToCommand(client, "[SM] Usage: sm_zve_outline <#userid|name> <1/0>");
        return Plugin_Handled;
    }
    if(args == 2)
    {
        if(!CheckCommandAccess(client, "sm_zve_outline_target", ADMFLAG_GENERIC))
        {
            ReplyToCommand(client, "[SM] %t.", "No Access");
            return Plugin_Handled;
        }
        new String:arg1[64];
        new String:arg2[64];
        GetCmdArg(1, arg1, sizeof(arg1));
        GetCmdArg(2, arg2, sizeof(arg2));
        new toggle = StringToInt(arg2);
        if(toggle == 0 && !StrEqual(arg2, "0"))
        {
            toggle = -1;
        }
        new String:target_name[MAX_TARGET_LENGTH];
        new target_list[MAXPLAYERS];
        new target_count;
        new bool:tn_is_ml;
        if((target_count = ProcessTargetString(
                        arg1,
                        client,
                        target_list,
                        MAXPLAYERS,
                        COMMAND_FILTER_ALIVE,
                        target_name,
                        sizeof(target_name),
                        tn_is_ml)) <= 0)
        {
            ReplyToTargetError(client, target_count);
            return Plugin_Handled;
        }
        if(toggle != 0 && toggle != 1)
        {
            ReplyToCommand(client, "[SM] Usage: sm_zve_outline <#userid|name> <1/0>");
            return Plugin_Handled;
        }
        if(toggle == 1)
        {
            ShowActivity2(client, "[SM] ", "Added outline on %s.", target_name);
            for(new i = 0; i < target_count; i++)
            {
                if(IsValidClient(target_list[i]) && !isOutlined[target_list[i]])
                {
                    Outline(target_list[i], true);
                    if(GetConVarBool(cvarLogs))
                    {
                        LogAction(client, target_list[i], "\"%L\" added player outline on \"%L\"", client, target_list[i]);
                    }
                }
            }
        }
        if(toggle == 0)
        {
            ShowActivity2(client, "[SM] ", "Removed outline from %s.", target_name);
            for(new i = 0; i < target_count; i++)
            {
                if(IsValidClient(target_list[i]) && isOutlined[target_list[i]])
                {
                    Outline(target_list[i], false);
                    if(GetConVarBool(cvarLogs))
                    {
                        LogAction(client, target_list[i], "\"%L\" removed player outline from \"%L\"", client, target_list[i]);
                    }
                }
            }
        }
    }
    return Plugin_Handled;
}

public OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if(isOutlined[client] && GetConVarBool(cvarEnabled) && GetConVarBool(cvarRemember))
    {
        SetEntProp(client, Prop_Send, "m_bGlowEnabled", 1);
    }
    else
    {
        isOutlined[client] = false;
    }
	
    if (TF2_GetClientTeam(client) != TFTeam_Red)
		return Plugin_Continue;
	
    g_iRedCounter++;
    return Plugin_Continue;
}

public OnLibraryRemoved(const String:name[])
{
    if(StrEqual(name, "adminmenu"))
    {
        hAdminMenu = INVALID_HANDLE;
    }
}

public OnAdminMenuReady(Handle:topmenu)
{
    if(topmenu == hAdminMenu)
    {
        return;
    }
    hAdminMenu = topmenu;
    new TopMenuObject:player_commands = FindTopMenuCategory(hAdminMenu, ADMINMENU_PLAYERCOMMANDS);
    if(player_commands != INVALID_TOPMENUOBJECT)
    {
        AddToTopMenu(hAdminMenu, "sm_zve_outline", TopMenuObject_Item, AdminMenu_Outline, player_commands, "sm_zve_outline_target", ADMFLAG_GENERIC);
    }
}

public AdminMenu_Outline( Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength )
{
    if(action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "Outline player");
    }
    else if(action == TopMenuAction_SelectOption)
    {
        DisplayOutlineMenu(param);
    }
}

public DisplayOutlineMenu(client)
{
    new Handle:menu = CreateMenu(MenuHandler_Outline);
    decl String:title[100];
    Format(title, sizeof(title), "Outline Player:");
    SetMenuTitle(menu, title);
    SetMenuExitBackButton(menu, true);
    AddTargetsToMenu(menu, client, true, true);
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public MenuHandler_Outline(Handle:menu, MenuAction:action, param1, param2)
{
    if(action == MenuAction_End)
    {
        CloseHandle(menu);
    }
    else if(action == MenuAction_Cancel)
    {
        if(param2 == MenuCancel_ExitBack && hAdminMenu != INVALID_HANDLE)
        {
            DisplayTopMenu(hAdminMenu, param1, TopMenuPosition_LastCategory);
        }
    }
    else if(action == MenuAction_Select)
    {
        decl String:info[32];
        new userid;
        new target;
        GetMenuItem(menu, param2, info, sizeof(info));
        userid = StringToInt(info);
        if((target = GetClientOfUserId(userid)) == 0)
        {
            PrintToChat(param1, "[SM] %s", "Player no longer available.");
        }
        else if(!CanUserTarget(param1, target))
        {
            PrintToChat(param1, "[SM] %s", "Unable to target player.");
        }
        else if(IsValidClient(target))
        {
            if(!isOutlined[target])
            {
                Outline(target, true);
                ShowActivity2(param1, "[SM] ","Added outline on %N.", target);
                if(GetConVarBool(cvarLogs))
                {
                    LogAction(param1, target, "\"%L\" added player outline on \"%L\"", param1, target);
                }
            }
            else if(isOutlined[target])
            {
                Outline(target, false);
                ShowActivity2(param1, "[SM] ","Removed outline from %N.", target);
                if(GetConVarBool(cvarLogs))
                {
                    LogAction(param1, target, "\"%L\" removed player outline from \"%L\"", param1, target);
                }
            }
        }
        if(IsValidClient(param1) && !IsClientInKickQueue(param1))
        {
            DisplayOutlineMenu(param1);
        }
    }
}
 
stock Outline(client, bool:add = true)
{
    if(add)
    {
        SetEntProp(client, Prop_Send, "m_bGlowEnabled", 1);
        if(GetConVarBool(cvarAnnounce))
        {
            PrintToChat(client, "[SM] Player outline enabled.");
        }
        isOutlined[client] = true;
    }
    else
    {
        SetEntProp(client, Prop_Send, "m_bGlowEnabled", 0);
        if(GetConVarBool(cvarAnnounce))
        {
            PrintToChat(client, "[SM] Player outline disabled.");
        }
        isOutlined[client] = false;
    }
}
 
stock IsValidClient(client, bool:replaycheck = true)
{
    if(client <= 0 || client > MaxClients || !IsClientInGame(client) || GetEntProp(client, Prop_Send, "m_bIsCoaching"))
    {
        return false;
    }
    if(replaycheck)
    {
        if(IsClientSourceTV(client) || IsClientReplay(client))
        {
            return false;
        }
    }
    return true;
}
// ReflexPoison Most of Outline Player Code Ends here

public Action Dissolve(Handle timer, any client)
{
  if (!IsValidEntity(client))
    return;
    
  new ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
  if (ragdoll<0)
  {
    PrintToServer("[ZVE] Couldn't grab a ragdoll from the players");  
    return;
  }
    
  new String:dname[32], String:dtype[32];
  Format(dname, sizeof(dname), "dis_%d", client);
  Format(dtype, sizeof(dtype), "%d", GetConVarInt(cvarCorpseType));
  
  new ent = CreateEntityByName("env_entity_dissolver");
  if (ent>0)
  {
    DispatchKeyValue(ragdoll, "targetname", dname);
    DispatchKeyValue(ent, "dissolvetype", dtype);
    DispatchKeyValue(ent, "target", dname);
    AcceptEntityInput(ent, "Dissolve");
    AcceptEntityInput(ent, "kill");
  }
}

int GetRedCount()
{
	int r;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || TF2_GetClientTeam(i) != TFTeam_Red)
			continue;
		r++;
	}
	return r;
}

void FindLastPlayer()
{
	if (--g_iRedCounter == 1)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || !IsPlayerAlive(i) || TF2_GetClientTeam(i) != TFTeam_Red)
				continue;
			SetEntityHealth(i, 350);
			new MaxHealth = GetConVarInt(zve_last_human_hp_amount);
			SetEntData(i, FindDataMapInfo(i, "m_iMaxHealth"), MaxHealth, 4, true);
			SetEntData(i, FindDataMapInfo(i, "m_iHealth"), MaxHealth, 4, true);
			TF2_AddCondition(i, view_as<TFCond>(19), TFCondDuration_Infinite, 0);
            //Break as we should only be getting 1 player alive on red
			break;
		}
	}
}


public Action Timer_GetCount(Handle hTimer)
{
	int count, client;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || TF2_GetClientTeam(i) != TFTeam_Red)
			continue;
		client = i;
		count++;
	}
	
	if (count == 1)
	{
			SetEntityHealth(client, 350);
			new MaxHealth = GetConVarInt(zve_last_human_hp_amount);
			SetEntData(client, FindDataMapInfo(client, "m_iMaxHealth"), MaxHealth, 4, true);
			SetEntData(client, FindDataMapInfo(client, "m_iHealth"), MaxHealth, 4, true);
			TF2_AddCondition(client, view_as<TFCond>(19), TFCondDuration_Infinite, 0);
	}
}

public Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (TF2_GetClientTeam(client) != TFTeam_Red)
	{
		g_iRedCounter++;
		return Plugin_Continue;
	}
	
	if (!IsPlayerAlive(client))
		return Plugin_Continue;
	
	FindLastPlayer();
	
	return Plugin_Continue;
}
