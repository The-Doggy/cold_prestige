/* Model related code */

StringMap g_Models;
bool g_InPreview[MAXPLAYERS + 1];
int g_CurrentModel[MAXPLAYERS + 1];
int g_ModelEnt[MAXPLAYERS + 1];
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

    if(g_InPreview[client])
    {
        ExitPreview(client);
    }

    CPrintToChat(client, "%s Use A/D to switch between models, press E to purchase and equip the current model and left click to exit preview.", CMDTAG);

    SetEntityMoveType(client, MOVETYPE_NONE);
    
    // Create dummy ent to display models
    g_ModelEnt[client] = CreateEntityByName("prop_dynamic_override");
    DispatchKeyValue(g_ModelEnt[client], "model", "models/gman.mdl");
    DispatchSpawn(g_ModelEnt[client]);

    float pos[3], ang[3], spawnPos[3];
    GetClientAbsOrigin(client, pos);
    GetClientEyeAngles(client, ang);
    spawnPos[0] = pos[0] + Cosine(DegToRad(ang[1])) * 65;
    spawnPos[1] = pos[1] + Sine(DegToRad(ang[1])) * 65;
    spawnPos[2] = pos[2] + 2;

    TeleportEntity(g_ModelEnt[client], spawnPos, NULL_VECTOR, NULL_VECTOR);

    g_InPreview[client] = true;
    g_CurrentModel[client] = 0;
}

void ExitPreview(int client)
{
    SetEntityMoveType(client, MOVETYPE_ISOMETRIC);
    RemoveEntity(g_ModelEnt[client]);
    g_InPreview[client] = false;
    g_CurrentModel[client] = 0;
}