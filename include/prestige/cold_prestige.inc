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

stock bool IsValidClient(int client)
{
	return client >= 1 && 
	client <= MaxClients && 
	IsClientInGame(client);
}