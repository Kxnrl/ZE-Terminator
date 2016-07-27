#pragma semicolon 1
#pragma dynamic 131072

/*******************************************************

				Plugin Include
				
*******************************************************/
#include <sourcemod>
#include <sdktools>
#include <zombiereloaded>
#include <sdkhooks>
#include <emitsoundany>
#include <entWatch>
#include <zrterminator>

#pragma newdecls required
/*******************************************************

				Global Define
				
*******************************************************/
#define PLUGIN_VERSION " 1.7 "
#define PLUGIN_PREFIX "[\x0EPlaneptune\x01]  "

#define sndBeacon "maoling/ze/beacon.mp3"
#define BOMBRING "materials/sprites/bomb_planted_ring.vmt"
#define HALO "materials/sprites/halo.vmt"

/*******************************************************

				Global Variables
				
*******************************************************/
Handle g_fwdOnTerminatorExec;
Handle g_fwdOnTerminatorDown;
bool g_bIsTerminator[MAXPLAYERS+1];
bool g_bHasTerminator;
int g_bKillByT[MAXPLAYERS+1];
int g_iTerminatorType[MAXPLAYERS+1];
int g_iInfectHP[MAXPLAYERS+1];
int g_iEdgeKnife[MAXPLAYERS+1];
int g_iBombRing;
int g_iHalo;
int g_iToolsVelocity;
float g_fAttackLoc[MAXPLAYERS+1][3];

/*******************************************************

				Plugin Info
				
*******************************************************/
public Plugin myinfo =
{
    name = "Terminator",
    author = "maoling( xQy )",
    description = "For last humans",
    version = PLUGIN_VERSION,
    url = "http://steamcommunity.com/id/_xQy_/"
};

/*******************************************************

				Rest of plugin
				
*******************************************************/
public void OnPluginStart()
{
	g_iToolsVelocity = FindSendPropInfo("CBasePlayer", "m_vecVelocity[0]");

	RegAdminCmd("sm_sett", AdminSetTerminator, ADMFLAG_BAN);

	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("round_end", Event_RoundEnd);
	
	g_fwdOnTerminatorExec = CreateGlobalForward("ZE_OnTerminatorExec", ET_Ignore, Param_Cell);
	g_fwdOnTerminatorDown = CreateGlobalForward("ZE_OnTerminatorDown", ET_Ignore, Param_Cell);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("ZE_IsClientTerminator", Native_IsClientTerminator);
	CreateNative("ZE_GetTerminatorType", Native_GetTerminatorType);
	
	if(late)
		for(int i = 1; i <= MaxClients; ++i)
			if(IsClientInGame(i))
				OnClientPostAdminCheck(i);

	return APLRes_Success;
}

public int Native_IsClientTerminator(Handle plugin, int numParams)
{
	return g_bIsTerminator[GetNativeCell(1)];
}

public int Native_GetTerminatorType(Handle plugin, int numParams)
{
	return g_iTerminatorType[GetNativeCell(1)];
}

public void OnMapStart()
{
	PrecacheSoundAny(sndBeacon);
	AddFileToDownloadsTable("sound/maoling/ze/beacon.mp3");

	g_iBombRing = PrecacheModel(BOMBRING);
	g_iHalo = PrecacheModel(HALO);
}

/*******************************************************

				Client Event
				
*******************************************************/
public void OnClientPostAdminCheck(int client)
{
	g_bKillByT[client] = 0;
	g_bIsTerminator[client] = false;
	g_iTerminatorType[client] = 0;
	g_iInfectHP[client] = 0;
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action Event_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(!IsClientInGame(client))
		return;
	
	if(!IsPlayerAlive(client))
		return;
	
	if(!ZR_IsClientHuman(client))
		return;

	g_bKillByT[client] = 0;
	g_iTerminatorType[client] = 0;
	g_iInfectHP[client] = 0;
	g_iEdgeKnife[client] = 0;
	g_fAttackLoc[client][0] = 0.0;
	g_fAttackLoc[client][1] = 0.0;
	g_fAttackLoc[client][2] = 0.0;
}

public Action Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	if(!g_bHasTerminator)
		return;

	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if(client == attacker || !client || !attacker || !g_bIsTerminator[attacker])
		return;
	
	if(!IsClientInGame(attacker) || !IsClientInGame(client))
		return;
	
	if(!IsPlayerAlive(attacker) || !ZR_IsClientHuman(attacker))
		return;
	
	g_bKillByT[client]++;
}

public Action Event_RoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
	//Reset Terminator
	if(g_bHasTerminator)
	{
		g_bHasTerminator = false;
		for(int client=1; client<=MaxClients; ++client)
		{
			if(IsClientInGame(client))
			{
				g_bKillByT[client] = 0;
				if(g_bIsTerminator[client])
				{
					g_bIsTerminator[client] = false;
					g_iTerminatorType[client] = 0;
					g_iInfectHP[client] = 0;
					if(IsPlayerAlive(client))
					{
						int weapon_index=-1;
						char weapon_string[20];
						if(((weapon_index = GetPlayerWeaponSlot(client, 1)) != -1) && GetEdictClassname(weapon_index, weapon_string, 20))
						{
							RemovePlayerItem(client, weapon_index);
							RemoveEdict(weapon_index);
						}
						if(((weapon_index = GetPlayerWeaponSlot(client, 2)) != -1) && GetEdictClassname(weapon_index, weapon_string, 20))
						{
							RemovePlayerItem(client, weapon_index);
							RemoveEdict(weapon_index);
						}
						GivePlayerItem(client, "weapon_knife");
					}
				}
			}
		}
	}
}

/*******************************************************

				ZombieReloaded Forward
				
*******************************************************/
public Action ZR_OnClientInfect(int &client, int &attacker, bool &motherInfect, bool &respawnOverride, bool &respawn)
{
	if(motherInfect)
		return Plugin_Continue;

	if(g_bHasTerminator)
		if(g_bIsTerminator[client])
			return Plugin_Handled;

	return Plugin_Continue;
}

public int ZR_OnClientInfected(int client, int attacker, bool motherInfect, bool respawnOverride, bool respawn)
{
	//Fixing arm bug
	if(IsClientInGame(client))
	{
		if(IsPlayerAlive(client))
		{
			if(ZR_IsClientZombie(client))
			{
				int weapon_index=-1;
				char weapon_string[20];
				if(((weapon_index = GetPlayerWeaponSlot(client, 2)) != -1) && GetEdictClassname(weapon_index, weapon_string, 20))
				{
					RemovePlayerItem(client, weapon_index);
					RemoveEdict(weapon_index);
				}
				GivePlayerItem(client, "weapon_knife");
			}
		}
	}

	if(!g_bHasTerminator)
	{
		int Humans = 0;
		int Zombie = 0;
		for(int i=1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && IsPlayerAlive(i) && ZR_IsClientHuman(i))
				Humans++;
				
			if (IsClientInGame(i) && IsPlayerAlive(i) && ZR_IsClientZombie(i))
				Zombie++;
		}

		int total = Zombie + Humans;
			
		if (total<= 10 && Humans==1)
			PrintToChatAll("%s \x07人数不足10人,终结者变身失败!", PLUGIN_PREFIX);
		else if(10<total<= 20 && Humans == 1)
			SetTerminator();
		else if(20<total<=30 && Humans == 2)
			SetTerminator();
		else if(30<total<=40 && Humans == 3)
			SetTerminator();
		else if(40<total<=50 && Humans == 4)
			SetTerminator();
		else if(total>50 && Humans == 6)
			SetTerminator();
	}
}

public Action ZR_OnClientRespawn(int &client, ZR_RespawnCondition &condition)
{
	if(!g_bHasTerminator)
		return Plugin_Continue;

	if(g_bKillByT[client] >= 3)
		return Plugin_Handled;

	if(g_bIsTerminator[client])
		return Plugin_Handled;

	return Plugin_Continue;
}

/*******************************************************

				Terminator Damage Reset
				
*******************************************************/
public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{	
	if(!g_bHasTerminator)
		return Plugin_Continue;

	if(damage <= 0.0 || victim < 1 || victim > MaxClients || attacker < 1 || attacker > MaxClients)
		return Plugin_Continue;
	
	if(!IsValidEdict(weapon))
		return Plugin_Continue;

	if(IsPlayerAlive(attacker) && ZR_IsClientZombie(attacker) && g_bIsTerminator[victim])
	{	
		g_iInfectHP[victim]--;
		
		PrintHintText(victim, "<font size='40' color='#00FF00'>剩余HP: <strong>%d</strong>点HP</font>", g_iInfectHP[victim]);
		PrintToChat(victim, "%s  受到攻击来源\x07%N\x01的1点伤害,剩余HP:\x07 %d", PLUGIN_PREFIX, attacker, g_iInfectHP[victim]);
		
		if(g_iInfectHP[victim] <= 0)
		{
			damagetype = DMG_SHOCK;
			damage = 99999.0;
			OnTerminatorDown(victim);
			return Plugin_Changed;
		}
		
		CreateTimer(0.0, Timer_SetHealth, victim);

		return Plugin_Handled;
	}

	if(g_bIsTerminator[attacker])
	{
		char clsname[32];
		GetEdictClassname(weapon, clsname, 32);	
		
		if(StrContains(clsname, "deagle", false ) != -1)
		{
			damage *= 6;
	
			if(damage >= 800)
				damage = 800.0;
	
			if(g_iTerminatorType[attacker] == 2)
				damage *= 0.250000;
		}
		else if(StrContains(clsname, "knife", false ) != -1)
		{
			if(damage >= 165.0)
				damage *= 100.0;
			else if(65.0 >= damage >= 45.0)
				damage *= 80.0;
			else
				damage = 3000.00;

			if(g_iTerminatorType[attacker] == 2)
			{
				damage *= 0.250000;
	
				if(IsPlayerAlive(victim) && ZR_IsClientZombie(victim))
					g_iInfectHP[attacker]++;
				
				if(damage >= 1.0 && IsClientInGame(attacker) && IsPlayerAlive(attacker) && IsClientInGame(victim) && IsPlayerAlive(victim) && ZR_IsClientHuman(attacker) && ZR_IsClientZombie(victim))
					DoTerminatorKnockBack(attacker, victim, damage);
			}
			
			//Fucking camp
			float loc[3];
			GetClientAbsOrigin(attacker, loc);
			
			float Distance = GetVectorDistance(g_fAttackLoc[attacker], loc);
			
			GetClientAbsOrigin(attacker, g_fAttackLoc[attacker]);
			
			if(Distance < 35.0)
				g_iEdgeKnife[attacker]++;
			
			if(g_iEdgeKnife[attacker] > 10)
			{
				ForcePlayerSuicide(attacker);
				PrintToChatAll("%s  \x04%N\x01因为蹲墙角被天谴了", PLUGIN_PREFIX, attacker);
			}
			
			return Plugin_Changed;
		}
		else
		{
			damage *= 2.0;
			damagetype = DMG_SHOCK;
			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}

/*******************************************************

				Terminator Exec
				
*******************************************************/
void SetTerminator()
{
	for(int client=1; client<=MaxClients; ++client)
	{
		if(IsClientInGame(client) && IsPlayerAlive(client) && ZR_IsClientHuman(client))
		{
			g_bIsTerminator[client] = true;
			ExecTerminator(client, GetRandomInt(1,2));
		}
	}

	PrintCenterTextAll("<font color='#0066CC' size='30'>终结者已经出现!");
	g_bHasTerminator = true;
	SetupBeacon();
	SetupCure();
}

void ExecTerminator(int client, int type)
{
	g_iTerminatorType[client] = type;

	//prevent remove ent
	int weapon_index = -1;
	if(!ZE_IsClientTakeEnt(client))
	{	
		if(((weapon_index = GetPlayerWeaponSlot(client, 1)) != -1))
		{	
			RemovePlayerItem(client, weapon_index);
			RemoveEdict(weapon_index);
			GivePlayerItem(client, "weapon_revolver");
		}

		if(((weapon_index = GetPlayerWeaponSlot(client, 2)) != -1))
		{
			RemovePlayerItem(client, weapon_index);
			RemoveEdict(weapon_index);
			GivePlayerItem(client, "weapon_knifegg");
		}
	}
	
	PrintToChatAll("%s \x07%N \x0C已经成为终结者!", PLUGIN_PREFIX, client);
	
	if(g_iTerminatorType[client] == 1)
	{
		GivePlayerItem(client, "weapon_decoy");
		GivePlayerItem(client, "weapon_decoy");
		GivePlayerItem(client, "weapon_molotov");
		GivePlayerItem(client, "weapon_hegrenade");
		GivePlayerItem(client, "weapon_hegrenade");
		PrintToChat(client,"%s \x0C你已获得终结者手雷补给", PLUGIN_PREFIX);

		g_iInfectHP[client] = 10;
		SetTerminatorHealth(client);
		PrintToChat(client,"%s \x0C你已成为终结者(Type-800)[\x02伤害\x07++++\x0C]|[\x02击退\x07++++\x0C]", PLUGIN_PREFIX);
	}

	if(g_iTerminatorType[client] == 2)
	{
		GivePlayerItem(client, "weapon_flashbang");
		GivePlayerItem(client, "weapon_decoy");
		GivePlayerItem(client, "weapon_hegrenade");
		GivePlayerItem(client, "weapon_hegrenade");
		PrintToChat(client,"%s \x0C你已获得终结者手雷补给", PLUGIN_PREFIX);

		g_iInfectHP[client] = 20;
		SetTerminatorHealth(client);
		PrintToChat(client,"%s \x0C你已成为终结者(Type-T)[\x02伤害\x07+\x0C]|[\x02移速\x07++\x0C]|[\x02重力\x07--\x0C]|[\x02吸血\x07++\x0C]", PLUGIN_PREFIX);
		
		
		SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", 1.2);
		SetEntityGravity(client, 0.88);

		//should keep speed and gravity
		CreateTimer(5.0, Timer_SetSpeed, client, TIMER_REPEAT);
	}

	OnTerminatorExec(client);
}

public Action AdminSetTerminator(int client, int args)
{
	g_bHasTerminator = true;
	g_bIsTerminator[client] = true;
	ExecTerminator(client, GetRandomInt(1,2));
	SetupBeacon();
}

public Action Timer_SetSpeed(Handle timer, int client)
{
	if(!IsClientInGame(client))
		return Plugin_Stop;
	
	if(!IsPlayerAlive(client))
		return Plugin_Stop;
		
	if(!g_bHasTerminator)
	{
		SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", 1.000000);
		return Plugin_Stop;
	}

	if(!g_bIsTerminator[client])
	{
		SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", 1.000000);
		return Plugin_Stop;
	}
	
	float m_flLaggedMovementValue = GetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue");
	if(m_flLaggedMovementValue < 1.2)
		SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", 1.2);
	
	SetEntityGravity(client, 0.88);

	return Plugin_Continue;
}

public Action Timer_Beacon(Handle timer, any data)
{
	if(!g_bHasTerminator)
		return Plugin_Stop;

	CreateBeacons();

	return Plugin_Continue;
}

public Action Timer_Cure(Handle timer, any data)
{
	if(!g_bHasTerminator)
		return Plugin_Stop;

	CureTerminator();

	return Plugin_Continue;
}

void SetupBeacon()
{
	CreateTimer(2.0, Timer_Beacon, _, TIMER_REPEAT);
}

void SetupCure()
{
	CreateTimer(5.0, Timer_Cure, _, TIMER_REPEAT);
}

void CreateBeacons()
{
	for(int i=1; i<=MaxClients; ++i)
	{
		if(!IsClientInGame(i))
			continue;
		
		if(!IsPlayerAlive(i))
			continue;
		
		if(!ZR_IsClientHuman(i))
			continue;
		
		if(!g_bIsTerminator[i])
			continue;

		float fPos[3];
		GetClientAbsOrigin(i, fPos);
		fPos[2] += 8;
		
		TE_SetupBeamRingPoint(fPos, 10.0, 750.0, g_iBombRing, g_iHalo, 0, 10, 0.6, 10.0, 0.5, {255, 75, 75, 255}, 5, 0);
		TE_SendToAll();
		
		EmitSoundToAllAny(sndBeacon, i);
	}
}

void CureTerminator()
{
	for(int i=1; i<=MaxClients; ++i)
	{
		if(!IsClientInGame(i))
			continue;
		
		if(!IsPlayerAlive(i))
			continue;
		
		if(!ZR_IsClientHuman(i))
			continue;
		
		if(!g_bIsTerminator[i])
			continue;

		if(g_iInfectHP[i] < 20)
			g_iInfectHP[i]++;
		
		SetTerminatorHealth(i);
		PrintCenterText(i, "<font size='40' color='#00FF00'>你恢复了<strong>1</strong>点HP</font>");
		PrintToChat(i, "%s  你恢复了\x041\x01点HP,当前剩余HP:\x07 %d", PLUGIN_PREFIX, g_iInfectHP[i]);
	}
}

void OnTerminatorExec(int client)
{
	Call_StartForward(g_fwdOnTerminatorExec);
	Call_PushCell(client);
	Call_Finish();
}

void OnTerminatorDown(int client)
{
	Call_StartForward(g_fwdOnTerminatorDown);
	Call_PushCell(client);
	Call_Finish();
}

//knockback from zombiereloaded
void DoTerminatorKnockBack(int attacker, int victim, float damage)
{
	float clientloc[3];
	float attackerloc[3];
	
	//multiple
	float knockback = 2.0;
	
	GetClientAbsOrigin(victim, clientloc);

	GetClientEyePosition(attacker, attackerloc);

	float attackerang[3];
	GetClientEyeAngles(attacker, attackerang);
        
	TR_TraceRayFilter(attackerloc, attackerang, MASK_ALL, RayType_Infinite, KnockbackTRFilter);
	TR_GetEndPosition(clientloc);
	
	knockback *= damage;
	
	KnockbackSetVelocity(victim, attackerloc, clientloc, knockback);
}

void KnockbackSetVelocity(int client, const float startpoint[3], const float endpoint[3], float magnitude)
{
	float vector[3];
	MakeVectorFromPoints(startpoint, endpoint, vector);
    
	NormalizeVector(vector, vector);
    
	ScaleVector(vector, magnitude);
    
	ToolsClientVelocity(client, vector);
}

	
public bool KnockbackTRFilter(int entity, int contentsMask)
{
	if(entity > 0 && entity < MAXPLAYERS)
		return false;
	return true;
}

stock void ToolsClientVelocity(int client, float vecVelocity[3], bool apply = true, bool stack = true)
{
	if(!apply)
	{
		for(int x = 0; x < 3; x++)
		{
			vecVelocity[x] = GetEntDataFloat(client, g_iToolsVelocity + (x*4));
		}

		return;
	}
    
	if(stack)
	{
		float vecClientVelocity[3];

		for(int x = 0; x < 3; x++)
		{
			vecClientVelocity[x] = GetEntDataFloat(client, g_iToolsVelocity + (x*4));
		}

		AddVectors(vecClientVelocity, vecVelocity, vecVelocity);
	}

	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vecVelocity);
}

stock void SetTerminatorHealth(int client)
{
	if(IsClientInGame(client) && IsPlayerAlive(client))
		SetEntityHealth(client, g_iInfectHP[client]*10);
}

public Action Timer_SetHealth(Handle timer, int client)
{
	SetTerminatorHealth(client);
}