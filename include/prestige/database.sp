/* This file contains all of the Database/SQL functions and callbacks */

void SQL_ConnectDB(Database db, const char[] error, any data)
{
	if(db == null)
		SetFailState("Failed to connect to databse. Error: %s", error);

	g_Database = db;
	g_Database.SetCharset("utf8mb4");
	LogMessage("Database connection successful");

	CreateTables();
}

void CreateTables()
{
	char sQuery[1024];
	Transaction createTableTxn = new Transaction();
	g_Database.Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS cold_prestige (" ...
												"prestige INTEGER NOT NULL DEFAULT 0, " ...
												"rank INTEGER NOT NULL DEFAULT 0, " ...
												"custom_tag VARCHAR(128) DEFAULT '', " ...
												"chat_color VARCHAR(32) DEFAULT '', " ...
												"name_color VARCHAR(32) DEFAULT '', " ...
												"model VARCHAR(128) DEFAULT '', " ...
												"steamid VARCHAR(20) NOT NULL, " ...
												"PRIMARY KEY(steamid)" ...
												");");
	createTableTxn.AddQuery(sQuery);

	g_Database.Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS cold_prestige_itemlist (" ...
												"itemid INTEGER NOT NULL, " ...
												"type INTEGER NOT NULL, " ...
												"name VARCHAR(64) NOT NULL, " ...
												"price INTEGER NOT NULL, " ...
												"variable VARCHAR(256) NOT NULL DEFAULT '', " ...
												"PRIMARY KEY(itemid)" ...
												");");
	createTableTxn.AddQuery(sQuery);

	g_Database.Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS cold_prestige_items (" ...
												"steamid VARCHAR(20) NOT NULL, " ...
												"itemid INTEGER NOT NULL, " ...
												"equipped INTEGER NOT NULL DEFAULT 0, " ...
												"PRIMARY KEY(steamid, itemid), " ...
												"FOREIGN KEY(itemid) REFERENCES cold_prestige_itemlist(itemid) " ...
												"ON DELETE CASCADE" ...
												");");
	createTableTxn.AddQuery(sQuery);
	g_Database.Execute(createTableTxn, SQL_CreateTableSuccess, SQL_CreateTableFailure);
}

void SQL_CreateTableSuccess(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	LogMessage("%s Successfully created/verified database tables.", CONSOLETAG);

	// Tables are guaranteed to exist at this point so we can start loading data
	LoadItemList();

	// Late load players
	if(g_bLate)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				SDKHook(i, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost); // kappa
				LoadClientData(i);
			}
		}
	}
}

void SQL_CreateTableFailure(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	LogError("SQL_CreateTableFailure - Query %i of %i failed. Error: %s", failIndex, numQueries, error);
}

void LoadItemList()
{
	// Make sure all the items have been deleted and removed from the itemlist before loading
	for(int i = 0; i < g_ItemList.Length; i++)
	{
		PItem item = g_ItemList.Get(i);
		if(item == null)
		{
			LogError("LoadItemList - Found invalid item in g_ItemList at index %i", i);
			continue;
		}
		delete item;
	}
	g_ItemList.Clear();

	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "SELECT * FROM cold_prestige_itemlist");
	g_Database.Query(SQL_LoadItemList, sQuery);
}

void SQL_LoadItemList(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Failed to load item list. Error: %s", error);
		return;
	}

	if(!results.FetchRow()) return;

	int idCol, typeCol, nameCol, priceCol, varCol;
	results.FieldNameToNum("itemid", idCol);
	results.FieldNameToNum("type", typeCol);
	results.FieldNameToNum("name", nameCol);
	results.FieldNameToNum("price", priceCol);
	results.FieldNameToNum("variable", varCol);

	do
	{
		int id = results.FetchInt(idCol);
		ItemType type = view_as<ItemType>(results.FetchInt(typeCol));
		char name[64]; results.FetchString(nameCol, name, sizeof(name));
		int price = results.FetchInt(priceCol);
		char variable[256]; results.FetchString(varCol, variable, sizeof(variable));

		g_ItemList.Push(new PItem(id, type, name, price, variable));
	} while(results.FetchRow());

	LogMessage("%s Loaded %i items from the database", CONSOLETAG, results.RowCount);
}