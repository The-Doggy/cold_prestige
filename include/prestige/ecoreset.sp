/* This file contains all of the economy reset related code */

#define HOURVALUE 10000 // Calculation = (minutes / 60) * HOURVALUE
#define CURRENT_PRESTIGE PRESTIGE_RANK1 // The current prestige rank that players will be given upon reset

Action Command_EcoReset(int client, int args)
{
	if(client == 0)
	{
		PrintToServer("%s This command cannot be run from the server console", CONSOLETAG);
		return Plugin_Handled;
	}

	char sSteam[32];
	if(!GetClientAuthId(client, AuthId_Steam2, sSteam, sizeof(sSteam)))
	{
		CReplyToCommand(client, "%s Failed to get your steamid.", CMDTAG);
		return Plugin_Handled;
	}

	// Sidezz, Syle alt and Syle main steamids only
	#if !defined DEBUG
	if(!StrEqual(sSteam, "STEAM_0:1:92117") && !StrEqual(sSteam, "STEAM_0:0:24795044") && !StrEqual(sSteam, "STEAM_0:0:19051000"))
	{
		CReplyToCommand(client, "%s You are not authorized to use this command.", CMDTAG);
		return Plugin_Handled;
	}
	#endif

	if(!g_bConfirmReset[client])
	{
		CReplyToCommand(client, "%s {red}Warning{default}: Economy will be reset! Run this command again to confirm.", CMDTAG);
		g_bConfirmReset[client] = true;
		return Plugin_Handled;
	}

	// Kick clients and set pw
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i)) continue;

		KickClient(i, "Economy is being reset, please rejoin in a few moments");
	}

	int iRand = GetRandomInt(100000, 99999999);
	FindConVar("sv_password").SetInt(iRand);

	// POINT OF NO RETURN LETS GOOOOO
	char sQuery[2048];
	Transaction playerDataTxn = new Transaction();

	// Cash and bank value
	g_Database.Format(sQuery, sizeof(sQuery), "SELECT steam_id, (cash + bank) as moneyValue FROM bluerp_players;");
	playerDataTxn.AddQuery(sQuery);

	// Item value
	g_Database.Format(sQuery, sizeof(sQuery), "SELECT bluerp_players.steam_id, (bluerp_items.quantity * bluerp_itemlist.price) as itemValue FROM bluerp_players JOIN bluerp_items USING (steam_id) JOIN bluerp_itemlist ON bluerp_items.itemid = bluerp_itemlist.itemID WHERE bluerp_items.itemid NOT IN (195, 196, 197, 198, 250);");
	playerDataTxn.AddQuery(sQuery);

	// Time value
	g_Database.Format(sQuery, sizeof(sQuery), "SELECT steam_id, minutes FROM bluerp_players;");
	playerDataTxn.AddQuery(sQuery);

	g_Database.Execute(playerDataTxn, SQL_RetrieveDataSuccess, SQL_RetrieveDataFailure);

	return Plugin_Handled;
}

void SQL_RetrieveDataSuccess(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	LogMessage("Successfully retrieved player data, calculating prestige now...");

	char sSteam[32];

	// Calculating money prestige
	int steamColumn, moneyColumn, oldTotal;
	results[0].FieldNameToNum("steam_id", steamColumn);
	results[0].FieldNameToNum("moneyValue", moneyColumn);

	while(results[0].FetchRow())
	{
		results[0].FetchString(steamColumn, sSteam, sizeof(sSteam));

		g_smTotalValue.GetValue(sSteam, oldTotal);
		g_smTotalValue.SetValue(sSteam, results[0].FetchInt(moneyColumn) + oldTotal);
	}

	// Calculating item prestige
	int itemColumn;
	results[1].FieldNameToNum("steam_id", steamColumn);
	results[1].FieldNameToNum("itemValue", itemColumn);

	while(results[1].FetchRow())
	{
		results[1].FetchString(steamColumn, sSteam, sizeof(sSteam));

		g_smTotalValue.GetValue(sSteam, oldTotal);
		g_smTotalValue.SetValue(sSteam, results[1].FetchInt(itemColumn) + oldTotal);
	}

	// Calculating playtime prestige
	int minuteColumn;
	results[2].FieldNameToNum("steam_id", steamColumn);
	results[2].FieldNameToNum("minutes", minuteColumn);

	while(results[2].FetchRow())
	{
		results[2].FetchString(steamColumn, sSteam, sizeof(sSteam));

		g_smTotalValue.GetValue(sSteam, oldTotal);
		g_smTotalValue.SetValue(sSteam, ((results[2].FetchInt(minuteColumn) / 60) * HOURVALUE) + oldTotal);
	}

	// Once we've calculated everything we can set the prestige
	SetPrestige();
}

void SQL_RetrieveDataFailure(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	LogError("SQL_RetrieveDataFailure - Query %i of %i failed. Error: %s. Not resetting player data due to failed transaction. Unlocking server...", failIndex, numQueries, error);
	FindConVar("sv_password").SetString("");
	g_smTotalValue.Clear();
}

void SetPrestige()
{
	char sSteam[32], sQuery[256];
	int totalValue, prestigeValue;
	Transaction prestigeTxn = new Transaction();
	StringMapSnapshot totalValueSnapshot = g_smTotalValue.Snapshot();

	// Iterate stringmap entries
	for(int i = 0; i < totalValueSnapshot.Length; i++)
	{
		totalValueSnapshot.GetKey(i, sSteam, sizeof(sSteam));
		g_smTotalValue.GetValue(sSteam, totalValue);

		// Calculate actual prestige
		prestigeValue = RoundToCeil(float(totalValue / 10000));

		// Convert Steam2 to accountid
		int accountId = GetAccountIdFromSteam2(sSteam);

		// Update prestige
		g_Database.Format(sQuery, sizeof(sQuery), "INSERT INTO cold_prestige (steamid, prestige, rank) VALUES (CAST(%i + CAST('76561197960265728' AS UNSIGNED) AS CHAR), %i, %i) ON DUPLICATE KEY UPDATE prestige = prestige + %i, rank = rank + %i;", accountId, prestigeValue, CURRENT_PRESTIGE, prestigeValue, CURRENT_PRESTIGE); // This is extremely scuffed but is one of the only ways to convert to community id :')
		prestigeTxn.AddQuery(sQuery);
	}

	// Execute Transaction
	g_Database.Execute(prestigeTxn, SQL_PrestigeSuccess, SQL_PrestigeFailure);
	delete totalValueSnapshot;
}

void SQL_PrestigeSuccess(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	LogMessage("Successfully updated prestige values, resetting player data now...");

	char sQuery[1024];
	Transaction resetDataTxn = new Transaction();

	// Tables that can just be straight up deleted
	g_Database.Format(sQuery, sizeof(sQuery), "DELETE FROM bluerp_challenges;");
	resetDataTxn.AddQuery(sQuery);

	g_Database.Format(sQuery, sizeof(sQuery), "DELETE FROM bluerp_deathmatching;");
	resetDataTxn.AddQuery(sQuery);

	g_Database.Format(sQuery, sizeof(sQuery), "DELETE FROM bluerp_doorowners;");
	resetDataTxn.AddQuery(sQuery);

	g_Database.Format(sQuery, sizeof(sQuery), "DELETE FROM bluerp_gangdoors;");
	resetDataTxn.AddQuery(sQuery);

	g_Database.Format(sQuery, sizeof(sQuery), "DELETE FROM bluerp_gangs;");
	resetDataTxn.AddQuery(sQuery);

	g_Database.Format(sQuery, sizeof(sQuery), "DELETE FROM bluerp_plants;");
	resetDataTxn.AddQuery(sQuery);

	g_Database.Format(sQuery, sizeof(sQuery), "DELETE FROM bluerp_printers;");
	resetDataTxn.AddQuery(sQuery);

	// Delete items that aren't super doorhacks
	g_Database.Format(sQuery, sizeof(sQuery), "DELETE FROM bluerp_items WHERE itemid <> 250;");
	resetDataTxn.AddQuery(sQuery);

	// Update doors
	g_Database.Format(sQuery, sizeof(sQuery), "UPDATE bluerp_doors SET locks = 0, buyable = 1 WHERE buyable = 2;");
	resetDataTxn.AddQuery(sQuery);

	// Delete door furniture
	g_Database.Format(sQuery, sizeof(sQuery), "DELETE FROM bluerp_furniture_furniture WHERE doorid <> 0;");
	resetDataTxn.AddQuery(sQuery);

	***REMOVED***
	g_Database.Format(sQuery, sizeof(sQuery), "UPDATE bluerp_players SET cash = 0, bank = 0, income = 0, felony = 0, cuffed = 0, jail_time = 0, jail_progress = 0, minutes = 0, maxjailseconds = 180, experience = 0, gangid = '-1', respect = 0, specialty = '';");
	resetDataTxn.AddQuery(sQuery);

	g_Database.Execute(resetDataTxn, SQL_ResetSuccess, SQL_ResetFailure);
}

void SQL_PrestigeFailure(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	LogError("SQL_PrestigeFailure - Query %i of %i failed. Error: %s. Not resetting player data due to failed transaction", failIndex, numQueries, error);
	FindConVar("sv_password").SetString("");
	g_smTotalValue.Clear();
}

void SQL_ResetSuccess(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	LogMessage("Economy reset completed successfully, unlocking server...");
	FindConVar("sv_password").SetString("");
	g_smTotalValue.Clear();
}

void SQL_ResetFailure(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	LogError("SQL_ResetFailure - Query %i of %i failed. Error: %s. Please reset MySQL tables manually. Server will not unlock until the password is changed manually.", failIndex, numQueries, error);
	g_smTotalValue.Clear();
}