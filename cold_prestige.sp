#include <sourcemod>
#include <morecolors>
#include <hextags>
#include <sdktools>
#include <sdkhooks>
#include <customguns>

#pragma newdecls required
#pragma semicolon 1
#pragma dynamic 131072

#include <prestige/cold_prestige>

//#define DEBUG // COMMENT THIS OUT FOR PRODUCTION BUILDS

public Plugin myinfo = 
{
	name = "CoLD Prestige",
	author = "The Doggy",
	description = "Prestige system for CoLD Community Roleplay",
	version = "0.2.0",
	url = "coldcommunity.com"
};

// Global vars
Database g_Database;
bool g_bLate;
ArrayStack g_LoadQueue;
StringMap g_smTotalValue;
ArrayList g_ItemList;
static ArrayList excludedWeapons; // Used to exclude custom weapons that don't have a corresponding item in the itemlist

// These need to be here otherwise we get tag mismatches >:(
#include <prestige/PItem>
#include <prestige/PClient>

PClient g_Players[MAXPLAYERS + 1];
bool g_bConfirmReset[MAXPLAYERS + 1];

// Includes that need access to global vars and classes
#include "prestige/weapons/weapon_paintgun.sp"
#include "prestige/util.sp"
#include "prestige/natives.sp"
#include "prestige/database.sp"
#include "prestige/menus.sp"
#include "prestige/commands.sp"
#include "prestige/ecoreset.sp"

#if defined DEBUG
#include "prestige/debug.sp"
#endif


public void OnPluginStart()
{
	// Connect database 
	Database.Connect(SQL_ConnectDB, "CoLD_RP");

	LoadTranslations("common.phrases");

	// Register commands
	RegAdminCmd("sm_ecoreset", Command_EcoReset, ADMFLAG_ROOT, "what do you think it does... HINT: RESETS ECONOMY");
	RegAdminCmd("sm_showprestige", Command_ShowPrestige, ADMFLAG_CUSTOM2, "Shows player prestige points.");
	RegAdminCmd("sm_setprestige", Command_SetPrestige, ADMFLAG_CUSTOM6, "Sets player prestige points.");
	RegAdminCmd("sm_createstoreitem", Command_CreateItem, ADMFLAG_CUSTOM6, "Creates an item for the prestige store");
	RegAdminCmd("sm_deletestoreitem", Command_DeleteItem, ADMFLAG_CUSTOM6, "Deletes an item from the prestige store");
	RegAdminCmd("sm_liststoreitems", Command_ListItems, ADMFLAG_CUSTOM2, "Lists all of the items in the prestige store");
	RegAdminCmd("sm_givestoreitem", Command_GiveItem, ADMFLAG_CUSTOM6, "Adds a prestige item to a players inventory");
	RegAdminCmd("sm_removestoreitem", Command_RemoveItem, ADMFLAG_CUSTOM6, "Removes a prestige item from a players inventory");

	RegConsoleCmd("sm_prestige", Command_OpenStore, "Opens the prestige store");
	RegConsoleCmd("sm_changetag", Command_SetTag, "Changes your custom tag");
	RegConsoleCmd("sm_removeguns", Command_RemoveCustomGuns, "Removes your custom guns until your next respawn");

	#if defined DEBUG
	RegConsoleCmd("sm_dump", Command_DumpInfo);
	RegConsoleCmd("sm_dump_itemlist", Command_DumpItemList);
	#endif

	// Create ArrayStack and timer for loading players that failed to auth previously
	g_LoadQueue = new ArrayStack();
	CreateTimer(60.0, Timer_LoadFromQueue, TIMER_REPEAT);

	// Create StringMap for storing the total wealth amount of each player when economy resets
	g_smTotalValue = new StringMap();

	// Create ArrayList for storing a reference to every item contained in the database
	g_ItemList = new ArrayList();

	// Hook player_spawn to setup models and custom weapons
	HookEvent("player_spawn", Event_PlayerSpawn);

	// Create StringMap for weapon_paintgun sprites
	g_PaintSprites = new StringMap();
}

public void OnMapStart()
{
	// Precache stuff used throughout plugin
	PrecacheSound("buttons/button8.wav"); // Failure
	PrecacheSound("vo/citadel/al_success_yes02_nr.wav"); // Success
	PrecacheSound("hl1/fvox/boop.wav"); // Item sold, I don't really like this sound, should find something better later

	// All of this is currently for setting up paint sprites for weapon_paintgun
	char buffer[PLATFORM_MAX_PATH];
	char spriteKey[64];
	
	AddFileToDownloadsTable( "materials/decals/paint/paint_decal.vtf" );
	for( int colour = 0; colour < sizeof( g_cPaintColours ); colour++ )
	{
		for( int size = 0; size < sizeof( g_cPaintSizes ); size++ )
		{
			Format( buffer, sizeof( buffer ), "decals/paint/%s%s.vmt", g_cPaintColours[colour][1], g_cPaintSizes[size][1] );
			Format(spriteKey, sizeof(spriteKey), "%s%s", g_cPaintColours[colour][1], g_cPaintSizes[size][1]);
			g_PaintSprites.SetValue(spriteKey, PrecachePaint(buffer));
		}
	}
}

public void OnClientPutInServer(int client)
{
	// Reset client vars
	g_bConfirmReset[client] = false;

	// If the PClient that was last occupying this slot is still valid, kill it
	if(g_Players[client] != null)
	{
		g_Players[client].Kill(); // We need to use a custom destructor-like method to clean up all the other Handles contained inside our PClient such as inventory before we delete the PClient Handle itself to avoid memory leaks
		g_Players[client] = null;
	}

	SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
}

public void OnClientPostAdminCheck(int client)
{
	LoadClientData(client);
}

public void OnClientDisconnect(int client)
{
	if(g_Players[client] != null)
	{
		// Only save players that are loaded
		if(g_Players[client].Loaded)
			g_Players[client].Save();

		g_Players[client].Kill();
		g_Players[client] = null;
	}
}

Action Timer_LoadFromQueue(Handle timer, any data)
{
	while(!g_LoadQueue.Empty)
	{
		int client = GetClientOfUserId(g_LoadQueue.Pop());
		if(!IsValidClient(client)) continue;

		LoadClientData(client);
	}

	return Plugin_Continue;
}

void LoadClientData(int client)
{
	// If the player has already been loaded we're done here
	if(g_Players[client] != null && g_Players[client].Loaded) return;

	char sSteam[32];
	if(!GetClientAuthId(client, AuthId_SteamID64, sSteam, sizeof(sSteam)))
	{
		LogError("Failed to get client %N steamid, adding client to late load queue.", client);
		RequestFrame(AddToQueue, GetClientUserId(client));
		return;
	}

	// Load player data
	PClient player = new PClient(sSteam, client);
	if(player == null)
	{
		LogError("Failed to create PClient of client %N", client);
		return;
	}

	g_Players[client] = player;
	player.Load(); // player.Load will setup all of the PClients values and mark them as loaded when complete
}

void AddToQueue(int userid)
{
	// If the load queue isn't empty then we just request frame this function until it is to prevent infinte player load loops
	if(!g_LoadQueue.Empty)
	{
		RequestFrame(AddToQueue, userid);
		return;
	}

	g_LoadQueue.Push(userid);
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	PClient player = g_Players[GetClientOfUserId(event.GetInt("userid"))];
	if(player != null && player.Loaded)
	{
		RequestFrame(SetupSpawn, player);
	}
}

void SetupSpawn(PClient player)
{
	if(player == null || !player.Loaded) return;

	// Ensure the player has their model and custom weapons given to them on spawn
	char sModel[256];
	player.GetModel(sModel, sizeof(sModel));

	// Only set model if their model property is not empty
	if(sModel[0] != '\0')
	{
		player.SetModel(sModel); // This is kinda redundant but we already use SetEntityModel in that method so no reason to duplicate it here
	}

	// Loop the players inventory and give them any custom weapons that they have equipped
	ArrayList inventory = player.Inventory;
	for(int i = 0; i < inventory.Length; i++)
	{
		PItem item = inventory.Get(i);
		if(item == null)
		{
			LogError("Found invalid item in player %N's inventory at index %i", player.ClientIndex, i);
			continue;
		}

		char sWeaponClass[64];
		if(item.Type == ItemType_CustomWeapon && item.Equipped)
		{
			item.GetVariable(sWeaponClass, sizeof(sWeaponClass));
			CG_GiveGun(player.ClientIndex, sWeaponClass);
		}
	}
}

// It might be better to use a weapon_canuse sdkhook or something here but I've already done this so yolo
public void CG_ItemPostFrame(int client, int weapon)
{
	PClient player = g_Players[client];
	if(player == null || !player.Loaded || g_ItemList.Length == 0) return;

	char class[64];
	GetEntityClassname(weapon, class, sizeof(class));

	if(excludedWeapons == null)
	{
		excludedWeapons = new ArrayList(ByteCountToCells(sizeof(class)));
	}

	if(excludedWeapons.FindString(class) != -1) return;

	PItem item = GetItemFromVariable(class);
	if(item == null)
	{
		LogError("Custom weapon %s does not have a corresponding item in the itemlist", class);
		excludedWeapons.PushString(class);
		return;
	}

	if(!player.HasItem(item))
	{
		RemoveEntity(weapon);
		SetEntProp(client, Prop_Send, "m_bDrawViewmodel", false);
		player.Chat("%s You need to buy this weapon before you can use it!", CMDTAG);
	}

	// The GetItem* natives return item clones so we need to delete them to avoid mem leaks
	delete item;
}

void OnWeaponSwitchPost(int client, int weapon)
{
	SetEntProp(client, Prop_Send, "m_bDrawViewmodel", true);
}

public void HexTags_OnTagsUpdated(int client)
{
	PClient player = g_Players[client];
	if(player == null) return;

	char sTag[128], sChatColor[32], sNameColor[32];
	player.GetCustomTag(sTag, sizeof(sTag));
	player.GetChatColor(sChatColor, sizeof(sChatColor));
	player.GetNameColor(sNameColor, sizeof(sNameColor));

	HexTags_SetClientTag(client, ChatTag, sTag);
	HexTags_SetClientTag(client, ChatColor, sChatColor);
	HexTags_SetClientTag(client, NameColor, sNameColor);
}