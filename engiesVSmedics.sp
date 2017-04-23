#include<sourcemod>
#include<sdktools>
#include<tf2>
#include<tf2_stocks> 
#include<clients>

int DiedYet[64]; //this array stores wether a player is in the game and wether a player is in blue or red team
int GameStarted=0; //this int stores the amount of time the game has been started, resets when the game ends.
bool IsSettingTeam = false; //this bool switches to false when balancing teams so that the player death trackers doesn't messes up
bool ZombieStarted = false; //This variable is set to true after some time after round start to prevent victory from triggering too soon

/* HOW THIS PLUGIN WORKS:
 *	Basically, it keeps track of wether a player has died or not during a game (in the DiedYet array)
 *	when a player is connected it has its DiedYet value set to -1 if the game has started, 1 else.
 *	when a player dies, it has its DiedYet value set to -1 too.
 *  if a player has its DiedYet value set to -1, it will spawn as a blue medic
 * 	if a player has its DiedYet value set to 1, it will spawn as a red engineer.
 *	Any sentry will instantly be destroyed and blue medics can only use melee weapons.
 */ 

public Plugin myinfo ={
	name = "Engineers Vs Zombies",
	author = "shewowkees",
	description = "zombie like gamemode",
	version = "1.0",
	url = "noSiteYet"
};

public void OnPluginStart(){
	PrintToServer("Engies vs Medics V1.0 by shewowkees, inspired by Muselk.");
	HookEvent("player_spawn",Event_PlayerSpawnChangeClass,EventHookMode_Post);
	HookEvent("player_spawn",Event_PlayerSpawnChangeTeam,EventHookMode_Pre);
	HookEvent("player_death",Event_PlayerDeath,EventHookMode_Post);
	HookEvent("tf_game_over",Event_TFGameOver,EventHookMode_Post);
	HookEvent("player_regenerate",Event_PlayerRegenerate,EventHookMode_Post);
	HookEvent("player_builtobject",Event_PlayerBuiltObject,EventHookMode_Post);
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("teamplay_waiting_begins",Event_WaitingBegins,EventHookMode_Post);
	HookEvent("player_disconnect",Event_PlayerDisconnect,EventHookMode_Post);
}
/*
 * This method disables respawn times and prevents teams auto balance.
 * It also makes the server ban the idle players immediatly, only switching
 *	them to spectator mode would cause the plugin to misbehave.
 *
 */
public OnMapStart(){ 
	ServerCommand("mp_disable_respawn_times 1"); 
	ServerCommand("mp_teams_unbalance_limit 30"); 
	ServerCommand("mp_idledealmethod 2");
	
}
/*
 * This method initializes DiedYet of the connecting client to the right value.
 */
public void OnClientPostAdminCheck(int client){
	if(GameStarted>0){
		DiedYet[client]=-1;
	}else{
		DiedYet[client]=1;
	}
		
}

public void OnGameFrame(){
	new edict_index = FindEntityByClassname(-1, "tf_dropped_weapon");
	if (edict_index != -1){
		
		AcceptEntityInput(edict_index, "Kill");
		
	}
	edict_index = FindEntityByClassname(-1, "tf_ammo_pack");
	if (edict_index != -1){
		
		AcceptEntityInput(edict_index, "Kill");
		
	}
}


//EVENTS




//PLAYER RELATED EVENTS



 /*
 * This method forces the spawning player to switch to the right team BEFORE he appears
 */
 public Action:Event_PlayerSpawnChangeTeam(Event event, const char[] name, bool dontBroadcast){
	 
	 int client = GetClientOfUserId(event.GetInt("userid"));
	if(DiedYet[client]==-1){ //if client is supposed to be a blue medic
	
		TF2_ChangeClientTeam(client, TFTeam_Blue); //Always put him to team blue
				
	}else if(DiedYet[client]==1){ //if the client is supposed to be a red engineer.
		
		if( TF2_GetClientTeam(client)==TFTeam_Blue ){
			//if the client chooses blue team from the beginning, puts his DiedYet value to -1 
			TF2_ChangeClientTeam(client, TFTeam_Red);
			DiedYet[client]=-1;

			
		}
		
	}
 }
 /*
 * This method forces the player to be on the right team, the right class and to use the right weapons.
 */
public Action:Event_PlayerSpawnChangeClass(Event event, const char[] name, bool dontBroadcast){

	int client = GetClientOfUserId(event.GetInt("userid"));
	if(DiedYet[client]==0){
		
		if(GameStarted>0){
			DiedYet[client]=-1;
		}else{
			DiedYet[client]=1;
		}
		
	}
	if(DiedYet[client]==-1 || DiedYet[client]==0){ //if client is supposed to be a blue medic
	
		
		if( TF2_GetPlayerClass(client) != TFClass_Medic){ //if he isn't a medic, changes his class,  him and makes him respawn.
			PrintToChat(client,"[EVZ]: In zombie team, you can only be a medic !");
			TF2_SetPlayerClass(client, TFClass_Medic, true, true);
			TF2_RespawnPlayer(client);
		}
		
		
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary); //Could be replaced by melee mode but too lazy.
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
		
	}else if(DiedYet[client]==1){ //if the client is supposed to be a red engineer.
		
		
			if( TF2_GetPlayerClass(client) != TFClass_Engineer){ //if the client isn't an engineer, changes his class, kills him and makes him respawn
				PrintToChat(client,"[EVZ]: In survivor team, you can only be an engineer !");
				TF2_SetPlayerClass(client, TFClass_Engineer, true, true);
				DiedYet[client]=1; //sets the diedyet value to 1 because the suicide would set it to -1
				TF2_RespawnPlayer(client);
			}
		

	}
	function_CheckVictory();
}
/*
 * This method updates the DiedValue of a player if needed,changes his team and checks for victory
 */
public Action:Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast){ //On player death, sets his DiedYet value to -1
	
	
	
	if(!IsSettingTeam){
	
		int client = GetClientOfUserId(event.GetInt("userid"));
		if(GameStarted>0){
			PrintToChat(client,"[EVZ]: You have been infected, you can't go back to survivor team !");
			DiedYet[client] = -1;
			TF2_ChangeClientTeam(client,TFTeam_Blue);
			TF2_SetPlayerClass(client, TFClass_Medic, true, true);
			
		}
		function_CheckVictory();
	
	}
}





/*
 *The role of this method is to prevent blue team from getting back their full 
 *equipment after regenerating (from the locker) .
 */
public Action:Event_PlayerRegenerate(Event event, const char[] name, bool dontBroadcast){ 
	
	for(int i=0;i<64;i++){
		if( DiedYet[i]==-1 ){
				
				TF2_RemoveWeaponSlot(i, TFWeaponSlot_Primary);
				TF2_RemoveWeaponSlot(i, TFWeaponSlot_Secondary);
				
		}
	}
}
/*
 * This method instantly destroys a sentry, it could be replaced by playing around with  a func_nobuild.
 * Most of the code has been found in the plugin sentryspawner's code.
 */

public Action:Event_PlayerBuiltObject(Event event, const char[] name, bool dontBroadcast){ //Instantly destroys any sentry, the destruction part is not by me.
	
	int index = event.GetInt("index");
	
	if(TF2_GetObjectType(index)==TFObject_Sentry){
		
		decl String:netclass[32];
        GetEntityNetClass(index, netclass, sizeof(netclass));

		if (!strcmp(netclass, "CObjectSentrygun") )
		{
			SetVariantInt(9999);
			AcceptEntityInput(index, "RemoveHealth");
		}
	}
}

/*
 * This method resets a player's DiedYet value when he disconnects.
 */
public Action:Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast){
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	DiedYet[client] = 0;
	function_CheckVictory();
	
	
	
	
}

//ROUND RELATED EVENTS


/*
 * This functions decrements GameStarted because it will be incremented when the waiting begins
 */
public Action:Event_WaitingBegins(Event event, const char[] name, bool dontBroadcast){
	GameStarted=-1;
}
/*
 * This method deletes all unwanted elements from the map and balances the teams
 */
public Action:Event_RoundStart(Event event, const char[] name, bool dontBroadcast){

	function_PrepareMap();
	function_ResetTeams(true);
	CreateTimer(5.0,Start);
	GameStarted++;
	PrintToChatAll("[EVZ]: This server runs Engineers vs Zombies V1.0.");
	PrintToChatAll("[EVZ]: The goal for engineers (red team) is to survive as long as they can");
	PrintToChatAll("[EVZ]: The goal for medics (blue team) is to kill all engineers to turn them into zombies (medics) !");
	PrintToChatAll("[EVZ]: This plugin can be downloaded from www.sourcemod.net (sources included)");
	//PrintToServer("GameStarted incremented");//Debugging instruction
	
	
}

public Action:Event_TFGameOver(Event event, const char[] name, bool dontBroadcast){ //Once the game is over, resets the DiedYet values
	
	GameStarted = 0;
	function_AllEngineers(false);
	
}


//TIMERS

public Action Start(Handle timer){
	ZombieStarted = true;
	
}


//FUNCTIONS



/*
 * This function deletes all element that can influence game winning from the map and deletes the doors.
 * The game winngin elements part is from perky (hide n seek plugin), the doors part is from me.
 *
 * @param -
 * @return -
 */
public function_PrepareMap(){
	
	//code below is from Perky in Hide n seek plugin, it disables cp and ctf gamemodes.
	//following code disables cp and pl 
	new edict_index;
	new x = -1;
	for (new i = 0; i < 5; i++){
			edict_index = FindEntityByClassname(x, "trigger_capture_area"); //finds any capture area
			if (IsValidEntity(edict_index)){
				SetVariantInt(0); //Argument value is 0 if the input needs any
				AcceptEntityInput(edict_index, "SetTeam"); //set its team to 0
				AcceptEntityInput(edict_index, "Disable"); // Disables it
				x = edict_index;
			}
	}
	//following code disables flags
	x = -1;
	new flag_index;
	for (new i = 0; i < 5; i++){
		flag_index = FindEntityByClassname(x, "item_teamflag"); //finds flags
		if (IsValidEntity(flag_index)){
			AcceptEntityInput(flag_index, "Disable"); //disables them
			x = flag_index;
		}
	}
	//following code opens all doors. This part was made by myself
	x = -1
	new RespawnRoomIndex;
	bool HasFound = true;
	
	while(HasFound){
	
		RespawnRoomIndex = FindEntityByClassname (x, "func_door"); //finds doors
		
		if(RespawnRoomIndex==-1){//breaks the loop if no matching entity has been found
			
			HasFound=false;
			
		}else{
		
			if (IsValidEntity(RespawnRoomIndex)){
				AcceptEntityInput(RespawnRoomIndex,"Open");
				AcceptEntityInput(RespawnRoomIndex, "Kill"); //Deletes the door it.
				x = RespawnRoomIndex;
				
			}
		
		}
		
	}
	//following code disables respawnroom player blocking. This part was made by myself
	x = -1
	new RespawnRoomBlockerIndex;
	HasFound = true;
	
	while(HasFound){
	
		RespawnRoomBlockerIndex = FindEntityByClassname (x, "func_respawnroomvisualizer"); //finds blockers
		
		if(RespawnRoomBlockerIndex==-1){//breaks the loop if no matching entity has been found
			
			HasFound=false;
			
		}else{
		
			if (IsValidEntity(RespawnRoomBlockerIndex)){
			
				AcceptEntityInput(RespawnRoomBlockerIndex, "Kill"); //Deletes the blocker
				x = RespawnRoomBlockerIndex;
				
			}
		
		}
		
	}
	
	
	
	
	
	
}
/*
 * This functions makes a team given in argument win.
 * The code is from perky, author of the hide n seek plugin
 * 
 * @param team		The TFTeam that will win.
 * @return -
 */
public function_teamWin(team) //code from hide n seek
{
		new edict_index = FindEntityByClassname(-1, "team_control_point_master");
			if (edict_index == -1)
			{
				new g_ctf = CreateEntityByName("team_control_point_master");
				DispatchSpawn(g_ctf);
				AcceptEntityInput(g_ctf, "Enable");
			}
			
			new search = FindEntityByClassname(-1, "team_control_point_master")
			SetVariantInt(team);
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



public function_ResetTeams(bool kills){
	
	IsSettingTeam=true;
	function_AllEngineers(false);
	//following code counts the connected players
	int PlayerCount=0;
	for(int i=0;i<64;i++){
		
		if(DiedYet[i]!=0){
			
			PlayerCount++;
			
		}	
	
	}
	
	//following code will compute the needed starting blue Medics, depending on the player count.
	int StartingMedics = 0;
	if(PlayerCount > 1){ //if there is 2 or more players
	
		StartingMedics=1;
		
	}
	if(PlayerCount>5){
	
		StartingMedics=2;
		
	}
	if(PlayerCount >10){
	
		StartingMedics=3;
		
	}
	if(PlayerCount >18){
		
		StartingMedics=4;
	
	}
	
	//following code will make needed players start as medic
	while(StartingMedics>0){
		int i = GetRandomInt(0,63);
			if(DiedYet[i]==1){
				DiedYet[i]=-1;
				StartingMedics--;
			
			}
	}
	//Kills all the players
	if(kills){
		
		for(int i=0;i<64;i++){
		
		if(DiedYet[i]==-1){
			
			if(IsClientInGame(i)){
						ForcePlayerSuicide(i);
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
public function_CheckVictory(){
		
		if(ZombieStarted==false){
			return;
		}
	
		bool AllEngineersDead = true;
		for(int i=0;i<64;i++){
			if(DiedYet[i]==1){
				
				AllEngineersDead=false;
			
			}
		
		}
		if(AllEngineersDead){
			function_teamWin(TFTeam_Blue);
			ZombieStarted=false;
		}
		
}
	
/*
 * This function puts all players to red engineers.
 *
 * @param kill 		if true, will kill the players and force their respawn.
 * @return -
 *
 *
 */
 public function_AllEngineers(bool kill){
	 for(int i=0;i<64;i++){
		if(DiedYet[i]!=0){
			DiedYet[i]=1;
			TF2_ChangeClientTeam(i, TFTeam_Red);
			if(kill==true){
				ForcePlayerSuicide(i);
				TF2_RespawnPlayer(i);
			}
			
		}
			
	}
	 
 }





