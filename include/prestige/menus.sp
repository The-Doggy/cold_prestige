/* This file contains all of the menus and menu related functionality */

void ShowStoreMenu(int client)
{
	PClient player = g_Players[client];
	if(player == null || !player.Loaded)
	{
		CReplyToCommand(client, "%s Your prestige data has not loaded yet, try again in a minute.", CMDTAG);
		return;
	}

	Menu storeMenu = new Menu(StoreHandler);
	storeMenu.SetTitle("Your Prestige Points: %i", player.Prestige);
	storeMenu.AddItem("buy", "[Buy Items]");
	storeMenu.AddItem("inventory", "[Your Items]");
	storeMenu.ExitButton = true;
	storeMenu.Display(client, MENU_TIME_FOREVER);
}

int StoreHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sInfo[16];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if(StrEqual(sInfo, "buy"))
			{
				ShowStoreCategoriesMenu(param1);
			}
			else if(StrEqual(sInfo, "inventory"))
			{
				ShowInventoryMenu(param1);
			}
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}

	return 1;
}

void ShowStoreCategoriesMenu(int client)
{
	if(g_ItemList.Length == 0)
	{
		LogError("ShowStoreCategoriesMenu failed. g_ItemList is empty.");
		return;
	}

	Menu categoryMenu = new Menu(StoreCategoryHandler);
	categoryMenu.SetTitle("Choose a Category:");
	categoryMenu.ExitBackButton = true;
	categoryMenu.ExitButton = true;

	ArrayList itemTypes = new ArrayList();
	for(int i = 0; i < g_ItemList.Length; i++)
	{
		PItem item = g_ItemList.Get(i);
		if(item == null)
		{
			LogError("ShowStoreCategoriesMenu - Invalid item found in g_ItemList at index %i", i);
			continue;
		}

		if(itemTypes.FindValue(item.Type) == -1)
			itemTypes.Push(item.Type);
	}

	if(itemTypes.FindValue(ItemType_CustomTag) != -1)
		categoryMenu.AddItem("1", "[Custom Tags]");
	if(itemTypes.FindValue(ItemType_NameColor) != -1)
		categoryMenu.AddItem("2", "[Name Colors]");
	if(itemTypes.FindValue(ItemType_ChatColor) != -1)
		categoryMenu.AddItem("3", "[Chat Colors]");
	if(itemTypes.FindValue(ItemType_Model) != -1)
		categoryMenu.AddItem("4", "[Models]");
	if(itemTypes.FindValue(ItemType_CustomWeapon) != -1)
		categoryMenu.AddItem("5", "[Custom Weapons]");
	if(itemTypes.FindValue(ItemType_PaintColor) != -1)
		categoryMenu.AddItem("6", "[Paint Colors]");
	if(itemTypes.FindValue(ItemType_PaintSize) != -1)
		categoryMenu.AddItem("7", "[Paint Sizes]");

	delete itemTypes;
	categoryMenu.Display(client, MENU_TIME_FOREVER);
}

void ShowInventoryMenu(int client)
{
	PClient player = g_Players[client];
	if(player == null || !player.Loaded)
	{
		LogError("ShowInventoryMenu failed. Player %N's data has not been loaded yet.", client);
		return;
	}

	if(player.Inventory.Length == 0)
	{
		player.Chat("%s You have not bought any items!", CMDTAG);
		return;
	}

	Menu inventoryMenu = new Menu(InventoryHandler);
	inventoryMenu.SetTitle("Choose a Category:");
	inventoryMenu.ExitBackButton = true;
	inventoryMenu.ExitButton = true;

	ArrayList itemTypes = new ArrayList();
	ArrayList inventory = player.Inventory;
	for(int i = 0; i < inventory.Length; i++)
	{
		PItem item = inventory.Get(i);
		if(item == null)
		{
			LogError("ShowInventoryMenu - Invalid item found in player %N's inventory at index %i", client, i);
			continue;
		}

		if(itemTypes.FindValue(item.Type) == -1)
			itemTypes.Push(item.Type);
	}

	if(itemTypes.FindValue(ItemType_CustomTag) != -1)
		inventoryMenu.AddItem("1", "[Custom Tags]");
	if(itemTypes.FindValue(ItemType_NameColor) != -1)
		inventoryMenu.AddItem("2", "[Name Colors]");
	if(itemTypes.FindValue(ItemType_ChatColor) != -1)
		inventoryMenu.AddItem("3", "[Chat Colors]");
	if(itemTypes.FindValue(ItemType_Model) != -1)
		inventoryMenu.AddItem("4", "[Models]");
	if(itemTypes.FindValue(ItemType_CustomWeapon) != -1)
		inventoryMenu.AddItem("5", "[Custom Weapons]");
	if(itemTypes.FindValue(ItemType_PaintColor) != -1)
		inventoryMenu.AddItem("6", "[Paint Colors]");
	if(itemTypes.FindValue(ItemType_PaintSize) != -1)
		inventoryMenu.AddItem("7", "[Paint Sizes]");

	delete itemTypes;
	inventoryMenu.Display(client, MENU_TIME_FOREVER);
}

int StoreCategoryHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sInfo[4];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			ItemType type = view_as<ItemType>(StringToInt(sInfo));
			ShowStoreItemsMenu(param1, type);
		}

		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
			{
				ShowStoreMenu(param1);
			}
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}

	return 1;
}

int InventoryHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sInfo[4];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			ItemType type = view_as<ItemType>(StringToInt(sInfo));
			ShowPlayerItemsMenu(param1, type);
		}

		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
			{
				ShowStoreMenu(param1);
			}
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}

	return 1;
}

void ShowStoreItemsMenu(int client, ItemType type)
{
	PClient player = g_Players[client];
	if(player == null || !player.Loaded)
	{
		LogError("ShowPlayerItemsMenu failed. Player %N's prestige data has not loaded yet.", client);
		return;
	}

	Menu itemsMenu = new Menu(StoreItemsHandler);
	itemsMenu.SetTitle("Choose an item:");
	itemsMenu.ExitBackButton = true;
	itemsMenu.ExitButton = true;

	ArrayList items = GetItemsOfType(type);
	if(items.Length == 0) return;

	for(int i = 0; i < items.Length; i++)
	{
		PItem item = items.Get(i);
		if(item == null)
		{
			LogError("ShowStoreItemsMenu - Invalid item found in items list");
			continue;
		}

		// Get item ID and name
		char sID[9], sFormatName[64];
		IntToString(item.ID, sID, sizeof(sID));

		bool owned = player.HasItem(item);
		item.GetName(sFormatName, sizeof(sFormatName));
		Format(sFormatName, sizeof(sFormatName), "[%s%s]", owned ? "Owned - " : "", sFormatName);

		itemsMenu.AddItem(sID, sFormatName);
	}

	itemsMenu.Display(client, MENU_TIME_FOREVER);
}

void ShowPlayerItemsMenu(int client, ItemType type)
{
	PClient player = g_Players[client];
	if(player == null || !player.Loaded)
	{
		LogError("ShowPlayerItemsMenu failed. Player %N's prestige data has not loaded yet.", client);
		return;
	}

	Menu itemsMenu = new Menu(PlayerItemsHandler);
	itemsMenu.SetTitle("Choose an item:");
	itemsMenu.ExitBackButton = true;
	itemsMenu.ExitButton = true;

	ArrayList inventory = player.Inventory;
	for(int i = 0; i < inventory.Length; i++)
	{
		PItem item = inventory.Get(i);
		if(item == null)
		{
			LogError("ShowPlayerItemsMenu - Found invalid item in %N's inventory at index %i", client, i);
			continue;
		}

		if(item.Type != type) continue;

		char sID[9], sFormattedItem[64];
		IntToString(item.ID, sID, sizeof(sID));

		item.GetName(sFormattedItem, sizeof(sFormattedItem));
		Format(sFormattedItem, sizeof(sFormattedItem), "[%s]", sFormattedItem);

		itemsMenu.AddItem(sID, sFormattedItem);
	}
	itemsMenu.Display(client, MENU_TIME_FOREVER);
}

int StoreItemsHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sInfo[9];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			PItem item = GetItemFromID(StringToInt(sInfo));
			if(item == null)
			{
				LogError("StoreItemsHandler - Got invalid item from id %s", sInfo);
				CPrintToChat(param1, "%s An error has occurred, please try again.", CMDTAG);
				return 1;
			}

			PClient player = g_Players[param1];
			if(player != null && player.Loaded && player.HasItem(item))
			{
				player.Chat("%s You already own this item.", CMDTAG);
				EmitSoundToClient(param1, "buttons/button8.wav");
				ShowStoreCategoriesMenu(param1);
				return 1;
			}

			ShowPurchaseMenu(param1, item);
		}

		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
			{
				ShowStoreCategoriesMenu(param1);
			}
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}

	return 1;
}

int PlayerItemsHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			PClient player = g_Players[param1];
			if(player == null || !player.Loaded)
			{
				LogError("PlayerItemsHandler - Player %N's data has not loaded.", param1);
				return 1;
			}

			char sInfo[9];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			PItem item = player.GetInventoryItem(StringToInt(sInfo));
			if(item == null)
			{
				LogError("PlayerItemsHandler - Invalid item from %N's inventory with %s ID", param1, sInfo);
				return 1;
			}

			ShowItemMenu(param1, item);
		}

		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
			{
				ShowInventoryMenu(param1);
			}
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}

	return 1;
}

void ShowPurchaseMenu(int client, PItem item)
{
	if(item == null)
	{
		LogError("ShowPurchaseMenu - Item is invalid");
		return;
	}

	Menu purchaseMenu = new Menu(PurchaseHandler);
	purchaseMenu.SetTitle("Price: %i Prestige", item.Price);
	purchaseMenu.ExitBackButton = true;
	purchaseMenu.ExitButton = true;

	char sID[9];
	IntToString(item.ID, sID, sizeof(sID));
	purchaseMenu.AddItem(sID, "[Purchase]");
	purchaseMenu.Display(client, MENU_TIME_FOREVER);
}

void ShowItemMenu(int client, PItem item)
{
	if(item == null)
	{
		LogError("ShowItemMenu - Item is invalid");
		return;
	}

	Menu itemMenu = new Menu(ItemOptionsHandler);

	char sName[64];
	item.GetName(sName, sizeof(sName));
	itemMenu.SetTitle("%s\nPrice: %i\nSell Price: %i", sName, item.Price, (item.Price / 2));
	itemMenu.ExitBackButton = true;
	itemMenu.ExitButton = true;

	char sID[9], sFormattedInfo[32], sFormattedItem[32];
	IntToString(item.ID, sID, sizeof(sID));

	// Equip/Unequip item
	Format(sFormattedInfo, sizeof(sFormattedInfo), "use-%s", sID);
	Format(sFormattedItem, sizeof(sFormattedItem), "[%s]", item.Equipped ? "Unequip" : "Equip");
	itemMenu.AddItem(sFormattedInfo, sFormattedItem);

	// Sell item
	Format(sFormattedInfo, sizeof(sFormattedInfo), "sell-%s", sID);
	itemMenu.AddItem(sFormattedInfo, "[Sell]");

	itemMenu.Display(client, MENU_TIME_FOREVER);
}

int PurchaseHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sInfo[9];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			PItem item = GetItemFromID(StringToInt(sInfo));
			if(item == null)
			{
				LogError("PurchaseHandler - Item returned by GetItemFromID(%s) is invalid", sInfo);
				return 1;
			}

			PClient player = g_Players[param1];
			if(player == null || !player.Loaded)
			{
				LogError("PurchaseHandler - Player %N's data has not loaded yet.", param1);
				return 1;
			}

			if(item.Price > player.Prestige)
			{
				player.Chat("%s You don't have enough prestige to purchase this item. (Need: %i - Have: %i)", CMDTAG, item.Price, player.Prestige);
				EmitSoundToClient(param1, "buttons/button8.wav");
				return 1;
			}

			player.AddInventoryItem(item);
			player.Prestige -= item.Price;
			player.Save();

			char sName[32], sType[32];
			item.GetName(sName, sizeof(sName));
			item.GetTypeString(sType, sizeof(sType));
			player.Chat("%s You have bought a %s%s! Equip your new item in the {green}!prestige{default} menu!", CMDTAG, sName, sType);
			EmitSoundToClient(param1, "vo/citadel/al_success_yes02_nr.wav");
		}

		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
			{
				ShowStoreCategoriesMenu(param1);
			}
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}

	return 1;
}

int ItemOptionsHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sInfo[16];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			char sBuffer[2][9];
			ExplodeString(sInfo, "-", sBuffer, sizeof(sBuffer), sizeof(sBuffer[]));

			PClient player = g_Players[param1];
			if(player == null || !player.Loaded)
			{
				LogError("ItemOptionsHandler - Player %N's prestige data has not loaded yet.", param1);
				return 1;
			}

			PItem item = player.GetInventoryItem(StringToInt(sBuffer[1]));
			if(item == null)
			{
				LogError("ItemOptionsHandler - Item returned by GetInventoryItem(%s) is invalid.", sBuffer[1]);
				return 1;
			}

			char sName[32], sType[32];
			if(StrEqual(sBuffer[0], "use"))
			{
				item.GetName(sName, sizeof(sName));
				item.GetTypeString(sType, sizeof(sType));
				player.Chat("%s You have %s your %s%s!", CMDTAG, item.Equipped ? "{red}unequipped{default}" : "{green}equipped{default}", sName, sType);
				item.Equipped ? player.UnequipItem(item) : player.EquipItem(item);
				ShowInventoryMenu(param1);
			}
			else if(StrEqual(sBuffer[0], "sell"))
			{
				item.GetName(sName, sizeof(sName));
				item.GetTypeString(sType, sizeof(sType));
				#if defined DEBUG
				CPrintToChatAll("price = %i", item.Price);
				CPrintToChatAll("divide sell price = %i", item.Price / 2);
				CPrintToChatAll("multiply sell price = %i", item.Price * 0.5);
				#endif
				player.Chat("%s You have sold your %s%s for %i prestige!", CMDTAG, sName, sType, item.Price / 2); // for some reason using item.Price * 0.5 here would make the sell price go into the billions so I guess we just divide instead

				player.Prestige += (item.Price / 2);
				player.UnequipItem(item);
				player.RemoveInventoryItem(item);
				player.Save();

				EmitSoundToClient(param1, "hl1/fvox/boop.wav");

				ShowInventoryMenu(param1);
			}
		}

		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
			{
				ShowInventoryMenu(param1);
			}
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}

	return 1;
}