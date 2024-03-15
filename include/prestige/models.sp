/* Model related code */

StringMap g_Models;
bool g_InPreview[MAXPLAYERS + 1];
int g_CurrentModel[MAXPLAYERS + 1];
Handle g_HudSync;

void SetupModelList()
{
    if(g_Models == null || g_ItemList.Length == 0)
    {
        return;
    }

    g_Models.Clear();

    for(int i = 0; i < g_ItemList.Length; i++)
    {
        PItem item = g_ItemList.Get(i);
        if(item == null)
        {
            LogError("%s Invalid item found in itemlist at position %i", CONSOLETAG, i);
            continue;
        }

        // Ensure that the item is a model
        if(item.Type != ItemType_Model)
        {
            continue;
        }

        // Get model name and file path
        char modelName[128], modelPath[128];
        item.GetName(modelName, sizeof(modelName));
        item.GetVariable(modelPath, sizeof(modelPath));

        // Push data to map
        g_Models.SetString(modelName, modelPath);
    }
}

void PreviewModels(int client)
{
    if(g_Models == null || g_Models.Size == 0)
    {
        CPrintToChat(client, "%s No models to preview.", CMDTAG);
        return;
    }

    CPrintToChat(client, "%s Use A/D to switch between models and left click to exit preview.", CMDTAG);

    SetEntityMoveType(client, MOVETYPE_NONE);
    SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", 0);
    SetEntProp(client, Prop_Send, "m_iObserverMode", 1);
    SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 0);
    g_InPreview[client] = true;
    g_CurrentModel[client] = 0;
}

void ExitPreview(int client)
{
    SetEntityMoveType(client, MOVETYPE_ISOMETRIC);
    SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", -1);
    SetEntProp(client, Prop_Send, "m_iObserverMode", 0);
    SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1);
    g_InPreview[client] = false;
    g_CurrentModel[client] = 0;
}