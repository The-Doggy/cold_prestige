#include <sourcemod>
#include <morecolors>
#include <hextags>
#include <sdktools>
#include <sdkhooks>
#include <customguns>

//#define DEBUG // COMMENT THIS OUT FOR PRODUCTION BUILDS

#include <prestige>
#include <prestige/cold_prestige>

#pragma newdecls required
#pragma semicolon 1
#pragma dynamic 131072

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
bool g_Busy; // This should be used whenever we need to prevent an action from occuring if there is an asynchronous task currently running
ArrayStack g_LoadQueue;
StringMap g_smTotalValue;
ArrayList g_ItemList;
static ArrayList excludedWeapons; // Used to exclude custom weapons that don't have a corresponding item in the itemlist

PClient g_Players[MAXPLAYERS + 1];
bool g_bConfirmReset[MAXPLAYERS + 1];

// Includes that need access to global vars and classes
#include "prestige/commands.sp"
#include "prestige/database.sp"
#include "prestige/ecoreset.sp"
#include "prestige/menus.sp"
#include "prestige/models.sp"
#include "prestige/natives.sp"
#include "prestige/util.sp"

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
	RegConsoleCmd("sm_preview", Command_PreviewModels, "Previews custom models");

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

	// StringMap for storing model names and file paths
	g_Models = new StringMap();

	// Hook player_spawn to setup models and custom weapons
	HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnMapStart()
{
	// Precache stuff used throughout plugin
	PrecacheSound("buttons/button8.wav"); // Failure
	PrecacheSound("vo/citadel/al_success_yes02_nr.wav"); // Success
	PrecacheSound("hl1/fvox/boop.wav"); // Item sold, I don't really like this sound, should find something better later
}

public void OnClientPutInServer(int client)
{
	// Reset client vars
	g_bConfirmReset[client] = false;
	g_InPreview[client] = false;
	g_ModelEnt[client] = -1;

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
	if(g_InPreview[client])
	{
		ExitPreview(client);
	}

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
		if(!client) continue;

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

	// Because bluerp is hot trash and i don't want this plugin to have any affiliation with it by using it's forwards/natives i've decided 
	// to set the clients targetname to "cuffed" whenever they are cuffed, this is a very dumb and hacky way of checking whether a player is
	// cuffed but i really don't care at this point
	char isCuffed[16];
	GetEntPropString(player.ClientIndex, Prop_Data, "m_iName", isCuffed, sizeof(isCuffed));
	if(!StrEqual(isCuffed, "cuffed")) // Ensure player is not cuffed
	{
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

public void OnEntityCreated(int entity, const char[] classname)
{
	// Checking for creation of env_spritetrail instead of npc_grenade_frag means that this will be called whenever a grenade
	// is picked up by a phys gun which recreates the env_sprite and env_spritetrail entities
	if(StrContains(classname, "env_spritetrail", false) != -1)
	{
		// We need to request frame as some properties aren't assigned on creation
		RequestFrame(CheckSprite, EntIndexToEntRef(entity));
	}
}

// This only exists to ensure that the env_spritetrail that was created is actually a child of a grenade entity
void CheckSprite(int trailRef)
{
	int trailEnt = EntRefToEntIndex(trailRef);
	if(trailEnt != -1)
	{
		// Get parent of spritetrail ent
		int parent = GetEntPropEnt(trailEnt, Prop_Data, "m_hMoveParent");
		if(parent != -1)
		{
			char class[64];
			GetEntityClassname(parent, class, sizeof(class));
			if(StrContains(class, "npc_grenade_frag", false) != -1)
			{
				// Handle grenade models and trails
				RequestFrame(SetupGrenades, EntIndexToEntRef(parent));
			}
		}
	}
}

void SetupGrenades(int grenadeRef)
{
	// Make sure the grenade reference is still valid
	int grenadeEnt = EntRefToEntIndex(grenadeRef);
	if(grenadeEnt != -1)
	{
		// Get grenade thrower
		int thrower = GetEntPropEnt(grenadeEnt, Prop_Send, "m_hThrower");
		if(thrower != -1 && IsClientInGame(thrower))
		{
			PClient player = g_Players[thrower];
			if(player == null || !player.Loaded || g_ItemList.Length == 0)
			{
				return;
			}

			// Make sure the player actually has a grenade model equipped
			PItem grenadeModel = player.GetEquippedItemOfType(ItemType_GrenadeModel);
			if(grenadeModel != null)
			{
				char model[128];
				grenadeModel.GetVariable(model, sizeof(model));
				if(!IsModelPrecached(model))
				{
					PrecacheModel(model); // Precache the model if it isn't already
				}
				SetEntityModel(grenadeEnt, model);
				delete grenadeModel;
			}

			// Make sure the player actually has a grenade trail equipped
			PItem grenadeTrail = player.GetEquippedItemOfType(ItemType_GrenadeTrail);
			if(grenadeTrail != null)
			{
				char color[32];
				grenadeTrail.GetVariable(color, sizeof(color));

				int colors[4];
				if(StrEqual(color, "random", false))
				{
					colors[0] = GetRandomInt(0, 255);
					colors[1] = GetRandomInt(0, 255);
					colors[2] = GetRandomInt(0, 255);
				}
				else
				{
					// Colours are stored in rgb value so we can split them into separate parts using ExplodeString
					char splitColors[3][4];
					ExplodeString(color, " ", splitColors, sizeof(splitColors), sizeof(splitColors[]));
					colors[0] = StringToInt(splitColors[0]);
					colors[1] = StringToInt(splitColors[1]);
					colors[2] = StringToInt(splitColors[2]);
				}

				// Here we grab the grenade child and it's peer which are the env_sprite and env_spritetrail entities of the
				// grenade to set their colours
				int child = grenadeEnt;
				while ((child = GetEntPropEnt(child, Prop_Data, "m_hMoveChild")) != -1)
				{
					SetEntityRenderColor(child, colors[0], colors[1], colors[2], 200); // The 200 alpha value comes from https://cs.github.com/ValveSoftware/source-sdk-2013/blob/0d8dceea4310fde5706b3ce1c70609d72a38efdf/mp/src/game/server/hl2/grenade_frag.cpp#L166
					
					int peer = child;
					while ((peer = GetEntPropEnt(peer, Prop_Data, "m_hMovePeer")) != -1)
					{
						SetEntityRenderColor(peer, colors[0], colors[1], colors[2], 255); // The 255 alpha value comes from https://cs.github.com/ValveSoftware/source-sdk-2013/blob/0d8dceea4310fde5706b3ce1c70609d72a38efdf/mp/src/game/server/hl2/grenade_frag.cpp#L178
					}
				}
				delete grenadeTrail;
			}
		}
	}
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	PClient player = g_Players[client];
	if(player == null || !player.Loaded || g_ItemList.Length == 0 || GetClientTeam(client) == 2)
	{
		return;
	}

	// Checking if model has been changed by another plugin/game function
	char curModel[128], equipModel[128];
	player.GetModel(equipModel, sizeof(equipModel));
	if(equipModel[0] != '\0') // Ensure equipped model isn't empty
	{
		GetEntPropString(client, Prop_Data, "m_ModelName", curModel, sizeof(curModel));
		if(!StrEqual(curModel, equipModel)) // Set model back to equipped model if it has changed
		{
			player.SetModel(equipModel);
		}
	}

	// Setting models while in preview mode
	if(g_InPreview[client])
	{
		if(!IsPlayerAlive(client))
		{
			ExitPreview(client);
		}

		static float lastPress[MAXPLAYERS + 1];

		if(buttons & IN_MOVELEFT && GetGameTime() - lastPress[client] >= 0.25)
		{
			g_CurrentModel[client] -= 1;

			// Wrap around to last model if we go below 0
			if(g_CurrentModel[client] < 0)
			{
				g_CurrentModel[client] = g_Models.Size - 1;
			}

			lastPress[client] = GetGameTime();
		}
		else if(buttons & IN_MOVERIGHT && GetGameTime() - lastPress[client] >= 0.25)
		{
			g_CurrentModel[client] += 1;

			// Wrap around to first model if we hit max size
			if(g_CurrentModel[client] >= g_Models.Size)
			{
				g_CurrentModel[client] = 0;
			}

			lastPress[client] = GetGameTime();
		}
		
		char modelName[128], modelPath[128];
		StringMapSnapshot snapshot = g_Models.Snapshot();
		snapshot.GetKey(g_CurrentModel[client], modelName, sizeof(modelName));
		g_Models.GetString(modelName, modelPath, sizeof(modelPath));
		delete snapshot;

		// Change model to selected one
		PrecacheModel(modelPath);
		if(IsValidEntity(g_ModelEnt[client]))
		{
			SetEntityModel(g_ModelEnt[client], modelPath);

			// Rotate model
			float ang[3];
			GetEntPropVector(g_ModelEnt[client], Prop_Send, "m_angRotation", ang);
			ang[1] += 2.5;
			TeleportEntity(g_ModelEnt[client], NULL_VECTOR, ang, NULL_VECTOR);
		}

		if(g_HudSync == null)
		{
			g_HudSync = CreateHudSynchronizer();
		}

		ClearSyncHud(client, g_HudSync);
		SetHudTextParams(-1.0, 0.9, 0.1, 0, 255, 0, 255);
		ShowSyncHudText(client, g_HudSync, "%i/%i\n%s", g_CurrentModel[client] + 1, g_Models.Size, modelName);

		if(buttons & IN_USE && GetGameTime() - lastPress[client] >= 0.25)
		{
			lastPress[client] = GetGameTime();

			PItem item = GetItemFromVariable(modelPath);
			if(item == null)
			{
				CPrintToChat(client, "%s Unable to purchase model at this time, please try again later.", CMDTAG);
				return;
			}

			if(item.Price > player.Prestige)
			{
				player.Chat("%s You don't have enough prestige to purchase this item. (Need: %i - Have: %i)", CMDTAG, item.Price, player.Prestige);
				EmitSoundToClient(client, "buttons/button8.wav");
				delete item;
				return;
			}

			player.AddInventoryItem(item);
			player.Prestige -= item.Price;
			player.EquipItem(item);
			player.Save();

			CPrintToChat(client, "%s Successfully purchased and equipped {green}%s{default} model!", CMDTAG, modelName);
			EmitSoundToClient(client, "vo/citadel/al_success_yes02_nr.wav");

			ExitPreview(client);
		}
		else if(buttons & IN_ATTACK)
		{
			// If player had a model equipped previously set them back to it
			PItem item = player.GetEquippedItemOfType(ItemType_Model);
			if(item != null)
			{
				char model[128];
				item.GetVariable(model, sizeof(model));
				player.SetModel(model);
				delete item;
			}
			else // Player doesn't have a model equipped
			{
				// Set the player to a random hl2 citizen model for now
				char sModel[PLATFORM_MAX_PATH];
				Format(sModel, sizeof(sModel), "models/humans/group0%i/%s_0%i.mdl", GetRandomInt(1, 3), GetRandomInt(1, 2) == 2 ? "male" : "female", GetRandomInt(1, 7));
				player.SetModel(sModel);
			}

			ExitPreview(client);
			return;
		}
	}
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