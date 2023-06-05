//double-include prevention
#if defined _prestige_maininclude
#endinput
#endif
#define _prestige_maininclude

public SharedPlugin __pl_prestige =
{
	name = "cold_prestige",
	file = "cold_prestige.smx",
	#if defined REQUIRE_PLUGIN
		required = 1,
	#else
		required = 0,
	#endif
};

#define CMDTAG			"{dodgerblue}[CoLD Prestige]{default}"
#define CONSOLETAG 		"[CoLD Prestige]"

enum ItemType
{
    ItemType_CustomTag = 1,
    ItemType_NameColor,
    ItemType_ChatColor,
    ItemType_Model,
    ItemType_CustomWeapon,
    ItemType_PaintColor,
    ItemType_PaintSize,
	ItemType_GrenadeModel,
	ItemType_GrenadeTrail,
    ItemType_Max
}

native PItem GetItemFromID(int id);

native PItem GetItemFromType(ItemType type);

native ArrayList GetItemsOfType(ItemType type);

native PItem GetItemFromVariable(const char[] variable);

native PClient GetPlayerPClient(int client);

// Use GetPlayerPClient to get the client's PClient inside this forward
forward void Prestige_OnPlayerLoaded(int client);

stock bool IsValidClient(int client)
{
	return client >= 1 && 
	client <= MaxClients && 
	IsClientInGame(client);
}

stock void TE_SetupWorldDecal( const float vecOrigin[3], int index )
{    
    TE_Start( "World Decal" );
    TE_WriteVector( "m_vecOrigin", vecOrigin );
    TE_WriteNum( "m_nIndex", index );
}

stock void TraceEye( int client, float pos[3] )
{
	float vAngles[3], vOrigin[3];
	GetClientEyePosition( client, vOrigin );
	GetClientEyeAngles( client, vAngles );
	
	TR_TraceRayFilter( vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer );
	
	if( TR_DidHit() )
		TR_GetEndPosition( pos );
}

bool TraceEntityFilterPlayer( int entity, int contentsMask )
{
	return ( entity > MaxClients || !entity );
}