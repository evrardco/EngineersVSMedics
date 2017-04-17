#include<sourcemod>
#include<sdktools>
#include<tf2>
#include<tf2_stocks> 
#include<clients>

int DiedYet[64];
int GameStarted=0;
bool IsSettingTeam = false;

/* HOW THIS PLUGIN WORKS:
 *	Basically, it keeps track of wether a player has died or not during a game (in the DiedYet array)
 *	when a player is connected it has its DiedYet value set to -1 if the game has started, 1 else.
 *	when a player dies, it has its DiedYet value set to -1 too.
 *  if a player has its DiedYet value set to -1, it will spawn as a blue medic
 * 	if a player has its DiedYet value set to 1, it will spawn as a red engineer.
 *	Any sentry will instantly be destroyed and blue medics can only use melee weapons.
 */ 

public Plugin myinfo ={
	name = "Engies vs Medics",
	author = "shewowkees",
	description = "zombie like gamemode",
	version = "0.8",
	url = "noSiteYet"
};

public void OnPluginStart(){
	PrintToServer("Engies vs Medics V0.8 by shewowkees, inspired by Muselk.");
	HookEvent("player_spawn",Event_PlayerSpawn,EventHookMode_Post);
	HookEvent("player_death",Event_PlayerDeath,EventHookMode_Post);
	HookEvent("tf_game_over",Event_PlayerGameOver,EventHookMode_Post);
	HookEvent("player_regenerate",Event_PlayerRegenerate,EventHookMode_Post);
	HookEvent("player_builtobject",Event_PlayerBuiltObject,EventHookMode_Post);
	HookEvent("teamplay_round_start", Event_RoundStart,EventHookMode_Post);
}

public OnMapStart(){ //Disabling respawn times and making team unbalance unlimited.
	ServerCommand("mp_disable_respawn_times 1");
	ServerCommand("mp_teams_unbalance_limit 30");
	
}
public void OnClientPostAdminCheck(int client){ //Initializes DiedYet of the connecting client to the right value
	if(GameStarted>1){
		DiedYet[client]=-1;
	}else{
		DiedYet[client]=1;
	}
		
}

public Action:Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast){

	int client = GetClientOfUserId(event.GetInt("userid"));

	if(DiedYet[client]==-1){ //if client is supposed to be a blue medic
	
		TF2_ChangeClientTeam(client, TFTeam_Blue); //Always put him to team blue
		
		if( TF2_GetPlayerClass(client) != TFClass_Medic){ //if he isn't a medic, changes his class, kills him and makes him respawn.
			TF2_SetPlayerClass(client, TFClass_Medic, true, true);
			ForcePlayerSuicide(client);
			TF2_RespawnPlayer(client);
		}
		
		
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary); //Could be replaced by melee mode but too lazy.
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
		
	}else if(DiedYet[client]==1){ //if the client is supposed to be a red engineer.
		
		if( TF2_GetClientTeam(client)==TFTeam_Blue ){ //if the client chooses blue team from the beginning, puts his DiedYet value to 1 
			TF2_ChangeClientTeam(client, TFTeam_Red);
			ForcePlayerSuicide(client);
			DiedYet[client]=1;
			TF2_RespawnPlayer(client);
			
		}else{
			if( TF2_GetPlayerClass(client) != TFClass_Engineer){ //if the client isn't an engineer, changes his class, kills him and makes him respawn
				TF2_SetPlayerClass(client, TFClass_Engineer, true, true);
				ForcePlayerSuicide(client);
				DiedYet[client]=1; //sets the diedyet value to 1 because the suicide would set it to -1
				TF2_RespawnPlayer(client);
			}
		}
		

	}
	function_CheckVictory();
}
public Action:Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast){ //On player death, sets his DiedYet value to -1
	
	if(!IsSettingTeam){
	
		int client = GetClientOfUserId(event.GetInt("userid"));
		if(GameStarted>1){
		
			DiedYet[client] = -1; 
			
		}
		function_CheckVictory();
	
	}
	
	
}
public Action:Event_PlayerGameOver(Event event, const char[] name, bool dontBroadcast){ //Once the game is over, resets the DiedYet values
	
	
	GameStarted = 0;
	
}
/*
 *The role of this function is to prevent blue team from getting back their full 
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
public Action:Event_RoundStart(Event event, const char[] name, bool dontBroadcast){
	
	function_PrepareMap();
	function_ResetTeams();

	GameStarted++;
	PrintToServer("GameStarted incremented");
	
	
}






//functions
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
public function_teamWin (team) //code from hide n seek
{
	if(!IsSettingTeam){
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
		
		
		
}




public function_ResetTeams(){
	IsSettingTeam=true;
	for(int i=0;i<64;i++){
		if(DiedYet[i]!=0){
			DiedYet[i]=1;
			TF2_RespawnPlayer(i);
		}
			
	}
	
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
	//looping backwards
	while(StartingMedics>0){
		int i = GetRandomInt(0,63);
			if(DiedYet[i]==1){
				DiedYet[i]=-1;
				StartingMedics--;
			
			}
	}
	//Kills all the players
	for(int i=0;i<64;i++){
		
		if(DiedYet[i]!=0){
			
			if(IsClientInGame(i)){
						ForcePlayerSuicide(i);
						TF2_RespawnPlayer(i);
			}
			
		}	
	
	}
	IsSettingTeam=false;

}
public function_CheckVictory(){
	if(GameStarted>1){
	
		bool AllEngineersDead = true;
		for(int i=0;i<64;i++){
			if(DiedYet[i]==1){
				
				AllEngineersDead=false;
			
			}
		
		}
		if(AllEngineersDead){
			function_teamWin(TFTeam_Blue);
			function_ResetTeams();
		}
		
	}
	
	
}





