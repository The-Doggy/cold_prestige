#if defined _CLASS_PCLIENT
 #endinput
 #endif
#define _CLASS_PCLIENT

#include <prestige/cold_prestige>
#include <prestige/PItem>

methodmap PClient < StringMap
{
	public PClient(char steamid[32], int Client, bool loadFromDB = true)
	{
		StringMap client = new StringMap();

		client.SetValue("prestige", 0);
		client.SetValue("inventory", new ArrayList());
		client.SetValue("loaded", !loadFromDB);
		client.SetValue("client_index", Client);
		client.SetValue("userid", GetClientUserId(Client));
		client.SetString("steamid", steamid);
		client.SetString("tag_text", "");
		client.SetString("name_color", "");
		client.SetString("chat_color", "");
		client.SetString("model", "");

		return view_as<PClient>(client);
	}

	property int ClientIndex
	{
		public get()
		{
			int client;
			this.GetValue("client_index", client);
			return client;
		}

		// No set method as this should only be set by the constructor
	}

	public void GetSteamID(char[] buffer, int maxlen)
	{
		this.GetString("steamid", buffer, maxlen);
	}

	// No set method as steamid should only be set by the constructor

	// I hate that this has to be all the way up here to actually be recognized by other class functions AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	public void SaveField(const char[] field, int value)
	{
		if(g_Database == null)
		{
			char sSteam[32];
			this.GetSteamID(sSteam, sizeof(sSteam));
			LogError("Database was null while trying to save player %N's (%s) %s field with value %i.", this.ClientIndex, sSteam, field, value);
			return;
		}

		char sQuery[256], sSteam[32];
		this.GetSteamID(sSteam, sizeof(sSteam));
		g_Database.Format(sQuery, sizeof(sQuery), "UPDATE cold_prestige SET %s = %i WHERE steamid = '%s';", field, value, sSteam);
		g_Database.Query(SQL_GenericQuery, sQuery);
	}

	property int Prestige
	{
		public get()
		{
			int prestige;
			this.GetValue("prestige", prestige);
			return prestige;
		}

		public set(int prestige)
		{
			if(prestige < 0)
			{
				prestige = 0;
			}

			this.SetValue("prestige", prestige);
			this.SaveField("prestige", prestige);
		}
	}

	property ArrayList Inventory
	{
		public get()
		{
			ArrayList inventory;
			this.GetValue("inventory", inventory);
			return inventory;
		}

		// No set method as the inventory ArrayList should only be created/set in the constructor
	}

	property bool Loaded
	{
		public get()
		{
			bool loaded;
			this.GetValue("loaded", loaded);
			return loaded;
		}

		public set(bool loaded)
		{
			this.SetValue("loaded", loaded);
		}
	}

	property int UserID
	{
		public get()
		{
			int userid;
			this.GetValue("userid", userid);
			return userid;
		}

		// No set method as this should only be set by the constructor
	}

	public void SaveFieldString(const char[] field, const char[] value)
	{
		if(g_Database == null)
		{
			char sSteam[32];
			this.GetSteamID(sSteam, sizeof(sSteam));
			LogError("Database was null while trying to save player %N's (%s) %s field with value %s.", this.ClientIndex, sSteam, field, value);
			return;
		}

		char sQuery[256], sSteam[32];
		this.GetSteamID(sSteam, sizeof(sSteam));
		g_Database.Format(sQuery, sizeof(sQuery), "UPDATE cold_prestige SET %s = '%s' WHERE steamid = '%s';", field, value, sSteam);
		g_Database.Query(SQL_GenericQuery, sQuery);
	}

	public PItem GetInventoryItem(int id)
	{
		PItem item;
		for(int i = 0; i < this.Inventory.Length; i++)
		{
			PItem currentItem = this.Inventory.Get(i);
			if(currentItem == null)
			{
				LogError("GetInventoryitem - Found invalid item in %N's inventory at index %i", this.ClientIndex, i);
				continue;
			}

			if(currentItem.ID == id)
			{
				item = currentItem;
			}
		}

		return item;
	}

	public void GetCustomTag(char[] buffer, int maxlen)
	{
		this.GetString("tag_text", buffer, maxlen);
	}

	public void SetCustomTag(char[] text)
	{
		this.SetString("tag_text", text);
		this.SaveFieldString("custom_tag", text);

		// Ensure that the player has a custom tag item and that it is equipped
		PItem tag = this.GetInventoryItem(GetItemFromType(ItemType_CustomTag).ID);
		if(tag != null && tag.Equipped)
		{
			HexTags_SetClientTag(this.ClientIndex, ChatTag, text);
		}
		else
		{
			HexTags_SetClientTag(this.ClientIndex, ChatTag, "");
		}
	}

	public void GetNameColor(char[] buffer, int maxlen)
	{
		this.GetString("name_color", buffer, maxlen);
	}

	public void SetNameColor(char[] color)
	{
		this.SetString("name_color", color);
		this.SaveFieldString("name_color", color);

		// If they don't have a color picked set them to the default teamcolor
		if(color[0] == '\0')
		{
			HexTags_SetClientTag(this.ClientIndex, NameColor, "{teamcolor}");
		}
		else
		{
			HexTags_SetClientTag(this.ClientIndex, NameColor, color);
		}
	}

	public void GetChatColor(char[] buffer, int maxlen)
	{
		this.GetString("chat_color", buffer, maxlen);
	}

	public void SetChatColor(char[] color)
	{
		this.SetString("chat_color", color);
		this.SaveFieldString("chat_color", color);

		HexTags_SetClientTag(this.ClientIndex, ChatColor, color);
	}

	public void GetModel(char[] buffer, int maxlen)
	{
		this.GetString("model", buffer, maxlen);
	}

	public void SetModel(char[] model)
	{
		if(!IsClientInGame(this.ClientIndex) || model[0] == '\0')
			return;

		if(!IsModelPrecached(model))
		{
			int modelIndex = PrecacheModel(model);
			if(!modelIndex)
			{
				LogError("PClient.SetModel() Error occurred while trying to precache model %s", model);
				return;
			}
		}

		this.SetString("model", model);
		this.SaveFieldString("model", model);
		SetEntityModel(this.ClientIndex, model);
	}

	public void GetInventoryItems(char[] buffer, int maxlen)
	{
		char sName[32];
		ArrayList inventory = this.Inventory;
		for(int i = 0; i < inventory.Length; i++)
		{
			PItem item = view_as<PItem>(inventory.Get(i));
			if(item == null)
			{
				LogError("Found invalid item in player %N's inventory.", this.ClientIndex);
				continue;
			}

			item.GetName(sName, sizeof(sName));
			Format(buffer, maxlen, "%s (%s %i),", buffer, sName, item.ID);
		}
	}

	public void Load()
	{
		if(g_Database == null)
		{
			LogError("Database was null while trying to load player %N's data, adding player to late load queue", this.ClientIndex);
			RequestFrame(AddToQueue, this.UserID);
			return;
		}

		char sQuery[1024], sSteam[32];
		this.GetSteamID(sSteam, sizeof(sSteam));

		g_Database.Format(sQuery, sizeof(sQuery), "SELECT * FROM cold_prestige WHERE steamid = '%s';", sSteam);
		g_Database.Query(SQL_LoadPlayerPrestige, sQuery, this);
	}

	public void Save()
	{
		if(g_Database == null)
		{
			char sItems[512], sSteam[32];
			this.GetInventoryItems(sItems, sizeof(sItems));
			this.GetSteamID(sSteam, sizeof(sSteam));
			LogError("Database was null while trying to save player %N's (%s) data. Current prestige: %i. Current Items: %s", this.ClientIndex, sSteam, this.Prestige, sItems);
			return;
		}

		Transaction txnSaveData = new Transaction();
		char sQuery[512], sTag[128], sNameColor[64], sChatColor[64], sModel[256], sSteam[32];
		this.GetCustomTag(sTag, sizeof(sTag));
		this.GetNameColor(sNameColor, sizeof(sNameColor));
		this.GetChatColor(sChatColor, sizeof(sChatColor));
		this.GetModel(sModel, sizeof(sModel));
		this.GetSteamID(sSteam, sizeof(sSteam));
		g_Database.Format(sQuery, sizeof(sQuery), "INSERT IGNORE INTO cold_prestige (prestige, custom_tag, name_color, chat_color, model, steamid) VALUES (%i, '%s', '%s', '%s', '%s', '%s') ON DUPLICATE KEY UPDATE prestige = %i, custom_tag = '%s', name_color = '%s', chat_color = '%s', model = '%s';", 
													this.Prestige, sTag, sNameColor, sChatColor, sModel, sSteam, this.Prestige, sTag, sNameColor, sChatColor, sModel, sSteam);
		txnSaveData.AddQuery(sQuery);

		for(int i = 0; i < this.Inventory.Length; i++)
		{
			PItem item = this.Inventory.Get(i);
			if(item == null)
			{
				LogError("PClient.Save - Item in player %N's inventory at index %i is invalid.", this.ClientIndex, i);
				continue;
			}

			g_Database.Format(sQuery, sizeof(sQuery), "INSERT IGNORE INTO cold_prestige_items (steamid, itemid, equipped) VALUES ('%s', %i, %i) ON DUPLICATE KEY UPDATE equipped = %i;", sSteam, item.ID, item.Equipped, item.Equipped);
			txnSaveData.AddQuery(sQuery);
		}
		g_Database.Execute(txnSaveData, _, SQL_ItemSaveFailure, this);
	}

	public void Kill()
	{
		// Delete PItem(s) in inventory and then delete the inventory itself
		ArrayList inventory = this.Inventory;
		for(int i = 0; i < inventory.Length; i++)
		{
			delete view_as<PItem>(inventory.Get(i));
		}
		inventory.Clear();
		delete inventory;

		// Delete the PClient instance
		delete this;
	}

	public void Chat(const char[] message, any ...)
	{
		if(!IsClientConnected(this.ClientIndex)) return;
		//due to the use of varargs, the code of this function is an exact line-for-line copy of the
		//CPrintToChat function from the morecolors plugin. Credit for the below code goes to that author.
		//If it wasn't for the varargs, I would have simply called CPrintToChat from here.
		char buffer[MAX_BUFFER_LENGTH], buffer2[MAX_BUFFER_LENGTH];
		SetGlobalTransTarget(LANG_SERVER);
		Format(buffer, sizeof(buffer), "\x01%s", message);
		VFormat(buffer2, sizeof(buffer2), buffer, 3);
		CReplaceColorCodes(buffer2);
		CSendMessage(this.ClientIndex, buffer2);
	}

	public void SaveItem(PItem item)
	{
		if(item == null)
		{
			LogError("SaveItem - Invalid item passed to function, not saving item");
			return;
		}

		char sQuery[512], sSteam[32];
		this.GetSteamID(sSteam, sizeof(sSteam));
		g_Database.Format(sQuery, sizeof(sQuery), "INSERT IGNORE INTO cold_prestige_items (steamid, itemid, equipped) VALUES ('%s', %i, %i) ON DUPLICATE KEY UPDATE equipped = %i;", sSteam, item.ID, item.Equipped, item.Equipped);
		g_Database.Query(SQL_GenericQuery, sQuery, this);
	}

	public void DeleteItem(PItem item)
	{
		if(item == null)
		{
			LogError("DeleteItem - Invalid item passed to function, not deleting item");
			return;
		}

		char sQuery[512], sSteam[32];
		this.GetSteamID(sSteam, sizeof(sSteam));
		g_Database.Format(sQuery, sizeof(sQuery), "DELETE FROM cold_prestige_items WHERE itemid = %i AND steamid = '%s';", item.ID, sSteam);
		g_Database.Query(SQL_GenericQuery, sQuery, this);
	}

	public void AddInventoryItem(PItem item)
	{
		if(item != null)
		{
			this.Inventory.Push(item);
			this.SaveItem(item);
		}
	}

	public void RemoveInventoryItem(PItem item)
	{
		if(item != null)
		{
			this.Inventory.Erase(this.Inventory.FindValue(item));
			this.DeleteItem(item);
			delete item;
		}
	}

	public bool HasItem(PItem item)
	{
		if(item == null) return false;

		bool found;
		ArrayList inventory = this.Inventory;
		for(int i = 0; i < inventory.Length; i++)
		{
			PItem currentItem = inventory.Get(i);
			if(currentItem == null)
			{
				LogError("Found invalid item in %N's inventory at index %i", this.ClientIndex, i);
				continue;
			}

			if(currentItem.ID == item.ID)
			{
				found = true;
				break;
			}
		}

		return found;
	}

	public PItem GetEquippedItemOfType(ItemType type)
	{
		if(type < ItemType_CustomTag || type > ItemType_Max)
		{
			ThrowError("GetEquippedItemOfType - Invalid ItemType %i given", type);
		}

		ArrayList inventory = this.Inventory;
		for(int i = 0; i < inventory.Length; i++)
		{
			PItem currentItem = inventory.Get(i);
			if(currentItem == null)
			{
				LogError("Found invalid item in %N's inventory at index %i", this.ClientIndex, i);
				continue;
			}

			if(currentItem.Type == type && currentItem.Equipped)
			{
				return currentItem.Clone();
			}
		}

		return view_as<PItem>(null);
	}

	public void UnequipItem(PItem item)
    {
        if(item == null || !this.HasItem(item)) return;

        item.Equipped = false;
        switch(item.Type)
        {
        	case ItemType_CustomTag:
        	{
        		HexTags_SetClientTag(this.ClientIndex, ChatTag, "");
        	}

        	case ItemType_NameColor:
        	{
        		this.SetNameColor("");
        	}

        	case ItemType_ChatColor:
        	{
        		this.SetChatColor("");
        	}

        	case ItemType_Model:
        	{
        		// Set the player to a random hl2 citizen model for now
        		char sModel[PLATFORM_MAX_PATH];
        		Format(sModel, sizeof(sModel), "models/humans/group0%i/%s_0%i.mdl", GetRandomInt(1, 3), GetRandomInt(1, 2) == 2 ? "male" : "female", GetRandomInt(1, 7));
        		this.SetModel(sModel);
        	}

        	case ItemType_CustomWeapon:
        	{

        	}

        	case ItemType_PaintColor:
        	{

        	}

        	case ItemType_PaintSize:
        	{

        	}
        }

        this.SaveItem(item);
    }

	public void UnequipItemsByType(ItemType type)
    {
    	ArrayList inventory = this.Inventory;
    	for(int i = 0; i < inventory.Length; i++)
    	{
    		PItem item = inventory.Get(i);
    		if(item == null)
    		{
    			LogError("Found invalid item in %N's inventory at index %i", this.ClientIndex, i);
    			continue;
    		}

    		if(item.Type == type)
    		{
    			this.UnequipItem(item);
    		}
    	}
    }

	public void EquipItem(PItem item)
    {
        if(item == null || !this.HasItem(item)) return;

        // Custom weapons are currently the only type of item that can have multiple equipped at the same time
        if(item.Type != ItemType_CustomWeapon)
        {
        	// Unequip other items of same type before equipping new item
        	this.UnequipItemsByType(item.Type);
        }

        char sVariable[256];
        item.GetVariable(sVariable, sizeof(sVariable));
        item.Equipped = true;

        switch(item.Type)
        {
        	case ItemType_CustomTag:
        	{
        		char sTag[128];
        		this.GetCustomTag(sTag, sizeof(sTag));

        		// Set tag to this if empty
        		if(sTag[0] == '\0')
        		{
        			this.SetCustomTag("[Veteran] ");
        		}
        		else
        		{
        			this.SetCustomTag(sTag);
        		}

        		this.Chat("%s Use {green}!changetag{default} to change your custom tag!", CMDTAG);
        	}

        	case ItemType_NameColor:
        	{
        		this.SetNameColor(sVariable);
        	}

        	case ItemType_ChatColor:
        	{
        		this.SetChatColor(sVariable);
        	}

        	case ItemType_Model:
        	{
        		this.SetModel(sVariable);
        	}

        	case ItemType_CustomWeapon:
        	{
        		CG_GiveGun(this.ClientIndex, sVariable);
        	}

        	case ItemType_PaintColor:
        	{

        	}

        	case ItemType_PaintSize:
        	{

        	}
        }

        this.SaveItem(item);
    }

#if defined DEBUG
	public void Dump(PClient player)
	{
		if(player == null) return;

		char sTag[128], sNameColor[32], sChatColor[32], sModel[256], sSteam[32];
		this.GetCustomTag(sTag, sizeof(sTag));
		this.GetNameColor(sNameColor, sizeof(sNameColor));
		this.GetChatColor(sChatColor, sizeof(sChatColor));
		this.GetModel(sModel, sizeof(sModel));
		this.GetSteamID(sSteam, sizeof(sSteam));

		player.Chat("%s Dumping %N's PClient data...", CMDTAG, this.ClientIndex);
		player.Chat("%s SteamID: %s", CMDTAG, sSteam);
		player.Chat("%s Prestige: %i", CMDTAG, this.Prestige);
		player.Chat("%s Inventory Handle value: %i", CMDTAG, this.Inventory);
		player.Chat("%s Loaded: %s", CMDTAG, this.Loaded ? "True" : "False");
		player.Chat("%s Client Index: %i", CMDTAG, this.ClientIndex);
		player.Chat("%s UserID: %i", CMDTAG, this.UserID);

		// Use regular PrintToChat for printing shit that has colours in it
		PrintToChat(player.ClientIndex, "%s Custom tag text: %s", CONSOLETAG, sTag);
		PrintToChat(player.ClientIndex, "%s Name color text: %s", CONSOLETAG, sNameColor);
		PrintToChat(player.ClientIndex, "%s Chat color text: %s", CONSOLETAG, sChatColor);

		player.Chat("%s Dumping items...", CMDTAG);
		ArrayList inventory = this.Inventory;
		for(int i = 0; i < inventory.Length; i++)
		{
			PItem item = inventory.Get(i);
			if(item == null)
			{
				player.Chat("%s Invalid item found at index %i", CMDTAG, i);
				LogError("Found Invalid item in %N's inventory at index %i", this.ClientIndex, i);
				continue;
			}

			char sName[64], sVariable[256];
			item.GetName(sName, sizeof(sName));
			item.GetVariable(sVariable, sizeof(sVariable));

			player.Chat("%s %s ID: %i, Type: %i, Price: %i, Variable: %s, Equipped: %s", CMDTAG, sName, item.ID, item.Type, item.Price, sVariable, item.Equipped ? "True" : "False");
		}

		player.Chat("%s Finished dumping PClient data of player %N", CMDTAG, this.ClientIndex);
	}
#endif
}

void SQL_LoadPlayerPrestige(Database db, DBResultSet results, const char[] error, PClient player)
{
	if(results == null)
	{
		LogError("SQL_LoadPlayerPrestige - Failed to load player data. Error: %s", error);
		return;
	}

	if(player == null)
	{
		LogError("SQL_LoadPlayerPrestige - Failed to load player data. Error: PClient instance is null.");
		return;
	}

	if(!results.FetchRow())
	{
		player.Loaded = true;
		return;
	}

	int prestigeCol, tagCol, nameCol, chatCol, modelCol, steamCol;
	results.FieldNameToNum("prestige", prestigeCol);
	results.FieldNameToNum("custom_tag", tagCol);
	results.FieldNameToNum("name_color", nameCol);
	results.FieldNameToNum("chat_color", chatCol);
	results.FieldNameToNum("model", modelCol);
	results.FieldNameToNum("steamid", steamCol);

	player.Prestige = results.FetchInt(prestigeCol);
	char sTag[128]; results.FetchString(tagCol, sTag, sizeof(sTag)); player.SetCustomTag(sTag);
	char sName[64]; results.FetchString(nameCol, sName, sizeof(sName)); player.SetNameColor(sName);
	char sChat[64]; results.FetchString(chatCol, sChat, sizeof(sChat)); player.SetChatColor(sChat);
	char sModel[256]; results.FetchString(modelCol, sModel, sizeof(sModel)); player.SetModel(sModel);
	char sSteam[32]; results.FetchString(steamCol, sSteam, sizeof(sSteam));

	char sQuery[128];
	g_Database.Format(sQuery, sizeof(sQuery), "SELECT * FROM cold_prestige_items WHERE steamid = '%s';", sSteam);
	g_Database.Query(SQL_LoadPlayerItems, sQuery, player);
}

void SQL_LoadPlayerItems(Database db, DBResultSet results, const char[] error, PClient player)
{
	if(results == null)
	{
		LogError("SQL_LoadPlayerItems - Failed to load player items. Error: %s", error);
		return;
	}

	if(player == null)
	{
		LogError("SQL_LoadPlayerItems - Failed to load player items. Error: PClient instance is null.");
		return;
	}

	if(!results.FetchRow())
	{
		player.Loaded = true;
		return;
	}

	int idCol, equippedCol;
	results.FieldNameToNum("itemid", idCol);
	results.FieldNameToNum("equipped", equippedCol);

	do
	{
		int itemID = results.FetchInt(idCol);
		int equipped = results.FetchInt(equippedCol);

		PItem item = GetItemFromID(itemID);
		if(item == null)
		{
			LogError("SQL_LoadPlayerItems - Player %N has invalid item with id %i in database.", player.ClientIndex, itemID);
			return;
		}

		item.Equipped = view_as<bool>(equipped);
		player.AddInventoryItem(item);
		if(item.Equipped) player.EquipItem(item);

	} while(results.FetchRow());

	// As of now this is the last thing that gets loaded for players, if this changes in the future this function call needs to move
	OnPlayerLoaded(player);
}

void SQL_ItemSaveFailure(Database db, PClient player, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	if(player == null || !IsClientInGame(GetClientOfUserId(player.UserID)))
	{
		LogError("Transaction failed trying to save player data. Transaction failed at query %i of %i. Error: %s", failIndex, numQueries, error);
		return;
	}

	char sItems[512], sSteam[32];
	player.GetInventoryItems(sItems, sizeof(sItems));
	player.GetSteamID(sSteam, sizeof(sSteam));
	LogError("Transaction failed trying to save player %N's (%s) data. Transaction failed at query %i of %i. Error: %s. Current prestige: %i. Current items: %s", player.ClientIndex, sSteam, failIndex, numQueries, error, player.Prestige, sItems);
	player.Chat("%s Failed to save your data, please try reconnecting and/or contact a developer about this issue.", CMDTAG);
}