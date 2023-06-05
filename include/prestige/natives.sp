/* This file contains all of the natives, forwards and general cross plugin API functions */

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("cold_prestige");

	CreateNative("GetItemFromID", Native_GetItemFromID);
	CreateNative("GetItemFromType", Native_GetItemFromType);
	CreateNative("GetItemsOfType", Native_GetItemsOfType);
	CreateNative("GetItemFromVariable", Native_GetItemFromVariable);
	CreateNative("GetPlayerPClient", Native_GetPlayer);

	g_ForwardOnPlayerLoaded = CreateGlobalForward("Prestige_OnPlayerLoaded", ET_Ignore, Param_Cell);

	g_bLate = late;
	return APLRes_Success;
}

// This was originally just going to be a stock function in the main include but for some reason that broke absolutely fucking everything so now we're doing this
public any Native_GetItemFromID(Handle plugin, int numParams)
{
	int id = GetNativeCell(1);

	if(g_ItemList.Length == 0)
	{
		LogError("GetItemFromID failed. g_ItemList has not been initialized.");
		return view_as<PItem>(null);
	}

	PItem item;
	for(int i = 0; i < g_ItemList.Length; i++)
	{
		PItem currentItem = g_ItemList.Get(i);
		if(currentItem == null)
		{
			LogError("Item at index %i in g_ItemList is invalid.", i);
			continue;
		}

		// Item has been found in itemlist
		if(currentItem.ID == id)
		{
			item = currentItem;
			break;
		}
	}

	if(item != null)
	{
		// We clone the item here as we never want to be using items directly from the itemlist as they will become invalid whenever the itemlist is reloaded
		return item.Clone();
	}

	return view_as<PItem>(null);
}

// Yup...
public any Native_GetItemFromType(Handle plugin, int numParams)
{
	ItemType type = GetNativeCell(1);

	if(g_ItemList.Length == 0)
	{
		LogError("GetItemFromType failed. g_ItemList has not been initialized.");
		return view_as<PItem>(null);
	}

	PItem item;
	for(int i = 0; i < g_ItemList.Length; i++)
	{
		PItem currentItem = g_ItemList.Get(i);
		if(currentItem == null)
		{
			LogError("Item at index %i in g_ItemList is invalid.", i);
			continue;
		}

		// Item has been found in itemlist
		if(currentItem.Type == type)
		{
			item = currentItem;
			break;
		}
	}

	if(item != null)
	{
		// We clone the item here as we never want to be using items directly from the itemlist as they will become invalid whenever the itemlist is reloaded
		return item.Clone();
	}

	return view_as<PItem>(null);
}

public any Native_GetItemsOfType(Handle plugin, int numParams)
{
	ItemType type = GetNativeCell(1);
	ArrayList items = new ArrayList();

	if(g_ItemList.Length == 0)
	{
		LogError("GetItemsOfType failed. g_ItemList has not been initalized.");
		return items;
	}

	for(int i = 0; i < g_ItemList.Length; i++)
	{
		PItem item = g_ItemList.Get(i);
		if(item == null)
		{
			LogError("Item at index %i in g_ItemList is invalid.", i);
			continue;
		}

		if(item.Type == type)
		{
			// We clone the item here as we never want to be using items directly from the itemlist as they will become invalid whenever the itemlist is reloaded
			items.Push(item.Clone());
			continue;
		}
	}

	return items;
}

public any Native_GetItemFromVariable(Handle plugin, int numParams)
{
	int len;
	GetNativeStringLength(1, len);
	if(len < 0) return view_as<PItem>(null);

	char[] variable = new char[len + 1];
	GetNativeString(1, variable, len + 1);

	if(g_ItemList.Length == 0)
	{
		LogError("GetItemsOfType failed. g_ItemList has not been initalized.");
		return view_as<PItem>(null);
	}

	PItem item;
	for(int i = 0; i < g_ItemList.Length; i++)
	{
		PItem currentItem = g_ItemList.Get(i);
		if(currentItem == null)
		{
			LogError("Item at index %i in g_ItemList is invalid.", i);
			continue;
		}

		char currentVar[256];
		currentItem.GetVariable(currentVar, sizeof(currentVar));
		if(StrEqual(currentVar, variable, false))
		{
			item = currentItem;
			break;
		}
	}

	// We clone the item here as we never want to be using items directly from the itemlist as they will become invalid whenever the itemlist is reloaded
	return item.Clone();
}

public any Native_GetPlayer(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if(g_Players[client] == null || !g_Players[client].Loaded)
	{
		LogError("GetPlayerPClient failed. PClient at index %i is invalid.", client);
		return view_as<PClient>(null);
	}

	return g_Players[client];
}