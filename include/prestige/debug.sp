/* This file contains debug functions and things that should not be compiled into a production build so DONT DO IT */

Action Command_DumpInfo(int client, int args)
{
	PClient target;
	if(args)
	{
		char sTarget[MAX_NAME_LENGTH];
		GetCmdArg(1, sTarget, sizeof(sTarget));

		int iTarget = FindTarget(client, sTarget, true, false);
		if(iTarget == -1) return Plugin_Handled;

		target = g_Players[iTarget];
	}
	else
	{
		target = g_Players[client];
	}

	if(target == null || !target.Loaded)
	{
		CReplyToCommand(client, "%s %N's data has not loaded yet.", CMDTAG, target.ClientIndex);
		return Plugin_Handled;
	}

	target.Dump(g_Players[client]);
	return Plugin_Handled;
}

Action Command_DumpItemList(int client, int args)
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
			LogError("Found invalid item in g_ItemList at index %i while dumping items.", i);
			continue;
		}

		item.Dump(client);
	}

	return Plugin_Handled;
}

stock void PrintToDeveloper(const char[] format, any ...)
{
	char sMessage[1024];
	VFormat(sMessage, sizeof(sMessage), format, 2);

	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || !IsClientAuthorized(i)) continue;

		char sSteam[32];
		GetClientAuthId(i, AuthId_SteamID64, sSteam, sizeof(sSteam));
		if(!StrEqual(sSteam, "76561198050395665")) continue;

		SetGlobalTransTarget(i);
		CPrintToChat(i, "%s", sMessage);
	}
}