/* This file contains all of the commands and command related functionality */

Action Command_OpenStore(int client, int args)
{
	if(client == 0)
	{
		PrintToServer("This command can only be executed in-game.");
		return Plugin_Handled;
	}

	ShowStoreMenu(client);
	return Plugin_Handled;
}

Action Command_SetTag(int client, int args)
{
	if(client == 0)
	{
		PrintToServer("This command can only be executed in-game.");
		return Plugin_Handled;
	}

	PClient player = g_Players[client];
	if(player == null || !player.Loaded)
	{
		CReplyToCommand(client, "%s Your items have not loaded yet, please try again in a minute.", CMDTAG);
		return Plugin_Handled;
	}

	PItem tagItem = player.GetInventoryItem(GetItemFromType(ItemType_CustomTag).ID);
	if(tagItem == null)
	{
		CReplyToCommand(client, "%s You haven't bought a custom tag! You can buy one in the {green}!prestige{default} store!", CMDTAG);
		return Plugin_Handled;
	}

	if(!tagItem.Equipped)
	{
		CReplyToCommand(client, "%s You need to equip your custom tag before you can change it!", CMDTAG);
		return Plugin_Handled;
	}

	char sTag[128];
	GetCmdArgString(sTag, sizeof(sTag));
	if(sTag[0] == '\0')
	{
		CReplyToCommand(client, "%s Your custom tag cannot be empty!", CMDTAG);
		return Plugin_Handled;
	}
	
	StrCat(sTag, sizeof(sTag), " "); // Need to add a space to the end of the tag otherwise it bunches up and looks bad
	player.SetCustomTag(sTag);

	CReplyToCommand(client, "%s See supported colors here: https://bit.ly/3xig4BN", CMDTAG);
	CReplyToCommand(client, "%s Your custom tag has been set to: %s", CMDTAG, sTag);
	HexTags_SetClientTag(client, ChatTag, sTag);
	return Plugin_Handled;
}

Action Command_ShowPrestige(int client, int args)
{
	if(args != 1)
	{
		CReplyToCommand(client, "%s Invalid Syntax. Usage: sm_showprestige <player>", CMDTAG);
		return Plugin_Handled;
	}

	char sTarget[MAX_NAME_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	int iTarget = FindTarget(client, sTarget, true);
	if(iTarget == -1) return Plugin_Handled;

	PClient target = g_Players[iTarget];
	if(target == null || !target.Loaded)
	{
		CReplyToCommand(client, "%s Player %N's prestige points have not been loaded yet, try again in a minute.", CMDTAG, iTarget);
		return Plugin_Handled;
	}

	CReplyToCommand(client, "%s Player %N has %i prestige points.", CMDTAG, iTarget, target.Prestige);
	return Plugin_Handled;
}

Action Command_SetPrestige(int client, int args)
{
	if(args != 2)
	{
		CReplyToCommand(client, "%s Invalid Syntax. Usage: sm_setprestige <player> <prestige>", CMDTAG);
		return Plugin_Handled;
	}

	char sTarget[MAX_NAME_LENGTH], sPrestige[8];
	GetCmdArg(1, sTarget, sizeof(sTarget));
	GetCmdArg(2, sPrestige, sizeof(sPrestige));

	int iPrestige = StringToInt(sPrestige);
	if(iPrestige <= 0)
	{
		CReplyToCommand(client, "%s Invalid prestige number, prestige must be between 1 and 2147483647", CMDTAG);
		return Plugin_Handled;
	}

	int iTarget = FindTarget(client, sTarget, true);
	if(iTarget == -1) return Plugin_Handled;

	PClient target = g_Players[iTarget];
	if(target == null || !target.Loaded)
	{
		CReplyToCommand(client, "%s Player %N's data has not been loaded yet, try again in a minute.", CMDTAG, iTarget);
		return Plugin_Handled;
	}

	target.Prestige = iPrestige;
	target.Save();

	CReplyToCommand(client, "%s Player %N's prestige set to %i", CMDTAG, iTarget, iPrestige);
	return Plugin_Handled;
}

Action Command_CreateItem(int client, int args)
{
	if(args != 4)
	{
		CReplyToCommand(client, "%s Invalid Syntax. Usage: sm_createstoreitem <name> <type> <price> <variable>", CMDTAG);
		CReplyToCommand(client, "%s Valid types are: 1 = ItemType_CustomTag, 2 = ItemType_NameColor, 3 = ItemType_ChatColor, 4 = ItemType_Model, 5 = ItemType_CustomWeapon, 6 = ItemType_PaintColor, 7 = ItemType_PaintSize, 8 = ItemType_GrenadeModel, " ...
		"9 = ItemType_GrenadeTrail, 10 = ItemType_PrinterColor, 11 = ItemType_PlantColor", CMDTAG);
		return Plugin_Handled;
	}

	char sName[64], sType[3], sPrice[9], sVariable[256];
	GetCmdArg(1, sName, sizeof(sName));
	GetCmdArg(2, sType, sizeof(sType));
	GetCmdArg(3, sPrice, sizeof(sPrice));
	GetCmdArg(4, sVariable, sizeof(sVariable));

	ItemType iType = view_as<ItemType>(StringToInt(sType));
	int iPrice = StringToInt(sPrice);

	if(iType < ItemType_CustomTag || iType >= ItemType_Max)
	{
		CReplyToCommand(client, "%s Invalid type. Valid types are: 1 = ItemType_CustomTag, 2 = ItemType_NameColor, 3 = ItemType_ChatColor, 4 = ItemType_Model, 5 = ItemType_CustomWeapon, 6 = ItemType_PaintColor, 7 = ItemType_PaintSize, 8 = ItemType_GrenadeModel, " ...
		"9 = ItemType_GrenadeTrail, 10 = ItemType_PrinterColor, 11 = ItemType_PlantColor", CMDTAG);
		return Plugin_Handled;
	}

	if(iPrice < 0)
	{
		CReplyToCommand(client, "%s Invalid price.", CMDTAG);
		return Plugin_Handled;
	}

	// Get the highest item id from the itemlist
	int highest;
	for(int i = 0; i < g_ItemList.Length; i++)
	{
		PItem currentItem = g_ItemList.Get(i);
		if(currentItem == null)
		{
			LogError("Command_CreateItem - Found invalid item in g_ItemList at index %i", i);
			continue;
		}

		if(currentItem.ID > highest)
			highest = currentItem.ID;
	}

	// We set highest to +1 cause we need the new id to be unique
	PItem item = new PItem(highest + 1, iType, sName, iPrice, sVariable);
	if(item == null)
	{
		LogError("Command_CreateItem - Created PItem is invalid somehow.");
		return Plugin_Handled;
	}

	item.Save();
	CReplyToCommand(client, "%s Created item %i %s (Type: %i) (Price: %i) (Variable: %s)", CMDTAG, item.ID, sName, item.Type, item.Price, sVariable);
	return Plugin_Handled;
}

Action Command_DeleteItem(int client, int args)
{
	if(args != 1)
	{
		CReplyToCommand(client, "%s Invalid Syntax. Usage: sm_deletestoreitem <id>", CMDTAG);
		return Plugin_Handled;
	}

	char sId[8];
	GetCmdArg(1, sId, sizeof(sId));
	int id = StringToInt(sId);
	if(id == 0)
	{
		CReplyToCommand(client, "%s Invalid id.", CMDTAG);
		return Plugin_Handled;
	}

	PItem item;
	for(int i = 0; i < g_ItemList.Length; i++)
	{
		item = g_ItemList.Get(i);
		if(item == null)
		{
			LogError("Command_DeleteItem - Found Invalid item in g_ItemList at index %i", i);
			continue;
		}

		if(item.ID == id)
		{
			break;
		}
	}

	if(item != null)
	{
		// Remove item for players that have it
		for(int i = 1; i <= MaxClients; i++)
		{
			PClient player = g_Players[i];
			if(player == null || !player.Loaded)
			{
				continue;
			}

			if(player.HasItem(item))
			{
				player.RemoveInventoryItem(player.GetInventoryItem(id));
			}
		}

		item.Delete();
		CReplyToCommand(client, "%s Deleted item %i from itemlist", CMDTAG, id);
	}
	else
	{
		CReplyToCommand(client, "%s Failed to find item with id %i", CMDTAG, id);
	}

	return Plugin_Handled;
}

Action Command_ListItems(int client, int args)
{
	if(g_ItemList.Length == 0)
	{
		CReplyToCommand(client, "%s Itemlist has no items.", CMDTAG);
		return Plugin_Handled;
	}

	for(int i = 0; i < g_ItemList.Length; i++)
	{
		PItem item = g_ItemList.Get(i);
		if(item == null)
		{
			LogError("Command_ListItems - Found invalid item in g_ItemList at index %i.", i);
			continue;
		}

		char sName[64], sVariable[256];
		item.GetName(sName, sizeof(sName));
		item.GetVariable(sVariable, sizeof(sVariable));

		CPrintToChat(client, "%s Name: %s, ID: %i, Type: %i, Price: %i, Variable: %s", CMDTAG, sName, item.ID, item.Type, item.Price, sVariable);
	}

	return Plugin_Handled;
}

Action Command_GiveItem(int client, int args)
{
	if(args != 2)
	{
		CReplyToCommand(client, "%s Invalid Syntax. Usage: sm_givestoreitem <player> <itemid>", CMDTAG);
		return Plugin_Handled;
	}

	char sTarget[MAX_NAME_LENGTH], sId[8];
	GetCmdArg(1, sTarget, sizeof(sTarget));
	GetCmdArg(2, sId, sizeof(sId));

	int id = StringToInt(sId);
	if(id <= 0)
	{
		CReplyToCommand(client, "%s Invalid item id.", CMDTAG);
		return Plugin_Handled;
	}

	int iTarget = FindTarget(client, sTarget, true);
	if(iTarget == -1) return Plugin_Handled;

	PClient target = g_Players[iTarget];
	if(target == null || !target.Loaded)
	{
		CReplyToCommand(client, "%s Player %N's data has not been loaded yet, try again in a minute.", CMDTAG, iTarget);
		return Plugin_Handled;
	}

	PItem item = GetItemFromID(id);
	if(item != null)
	{
		char sName[64];
		item.GetName(sName, sizeof(sName));
		target.AddInventoryItem(item);
		CReplyToCommand(client, "%s Added %s to %N's inventory.", CMDTAG, sName, target.ClientIndex);
		target.Chat("%s %N added an %s to your prestige items.", CMDTAG, client, sName);
	}
	else
	{
		CReplyToCommand(client, "%s Failed to find item with id %i", CMDTAG, id);
	}

	return Plugin_Handled;
}

Action Command_RemoveItem(int client, int args)
{
	if(args != 2)
	{
		CReplyToCommand(client, "%s Invalid Syntax. Usage: sm_removestoreitem <player> <itemid>", CMDTAG);
		return Plugin_Handled;
	}

	char sTarget[MAX_NAME_LENGTH], sId[8];
	GetCmdArg(1, sTarget, sizeof(sTarget));
	GetCmdArg(2, sId, sizeof(sId));

	int id = StringToInt(sId);
	if(id <= 0)
	{
		CReplyToCommand(client, "%s Invalid item id.", CMDTAG);
		return Plugin_Handled;
	}

	int iTarget = FindTarget(client, sTarget, true);
	if(iTarget == -1) return Plugin_Handled;

	PClient target = g_Players[iTarget];
	if(target == null || !target.Loaded)
	{
		CReplyToCommand(client, "%s Player %N's data has not been loaded yet, try again in a minute.", CMDTAG, iTarget);
		return Plugin_Handled;
	}

	PItem item = target.GetInventoryItem(id);
	if(item != null)
	{
		char sName[64];
		item.GetName(sName, sizeof(sName));
		target.RemoveInventoryItem(item);
		CReplyToCommand(client, "%s Removed %s from %N's inventory.", CMDTAG, sName, target.ClientIndex);
		target.Chat("%s %N removed an %s from your prestige items.", CMDTAG, client, sName);
	}
	else
	{
		CReplyToCommand(client, "%s Failed to find item with id %i", CMDTAG, id);
	}

	return Plugin_Handled;
}

Action Command_RemoveCustomGuns(int client, int args)
{
	CG_ClearInventory(client);

	// CG_ClearInventory doesn't seem to remove custom weapons if they're the active weapon so we need to remove them manually
	if(CG_IsClientHoldingCustomGun(client))
	{
		int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if(weapon != -1)
		{
			RemoveEntity(weapon);
		}
	}
	SetEntProp(client, Prop_Send, "m_bDrawViewmodel", false);
	CReplyToCommand(client, "%s Your custom guns have been removed until your next spawn.", CMDTAG);
	return Plugin_Handled;
}