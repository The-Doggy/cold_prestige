// Thanks to hmmmmm for making their paint plugin (https://forums.alliedmods.net/showthread.php?p=2541664) which most of this was stripped from and ported to work with customguns and prestige
#include <customguns>
#include <sdktools>

#define PAINT_DISTANCE_SQ	1.0

/* COLOURS! */
/* Colour name, file name */
char g_cPaintColours[][][64] = // Modify this to add/change colours
{
	{ "White", "paint_white" },
	{ "Black", "paint_black" },
	{ "Blue", "paint_blue" },
	{ "Light Blue", "paint_lightblue" },
	{ "Brown", "paint_brown" },
	{ "Cyan", "paint_cyan" },
	{ "Green", "paint_green" },
	{ "Dark Green", "paint_darkgreen" },
	{ "Red", "paint_red" },
	{ "Orange", "paint_orange" },
	{ "Yellow", "paint_yellow" },
	{ "Pink", "paint_pink" },
	{ "Light Pink", "paint_lightpink" },
	{ "Purple", "paint_purple" },
};

/* Size name, size suffix */
char g_cPaintSizes[][][64] = // Modify this to add more sizes
{
	{ "Small", "" },
	{ "Medium", "_med" },
	{ "Large", "_large" },
};

StringMap g_PaintSprites;

public void CG_OnPrimaryAttack(int client, int weapon){
	char sWeapon[32];
	GetEntityClassname(weapon, sWeapon, sizeof(sWeapon));
	
	if(StrEqual(sWeapon, "weapon_paintgun")){			
		// Make sure player firing weapon has a valid PClient instance
		PClient player = GetPlayerPClient(client);
		if(player == null || !player.Loaded) return;

		// Make sure that the player has bought and equipped both a paint color and paint size
		PItem colorItem = player.GetEquippedItemOfType(ItemType_PaintColor);
		PItem sizeItem = player.GetEquippedItemOfType(ItemType_PaintSize);
		if(colorItem == null || sizeItem == null)
		{
			player.Chat("%s You need to buy/equip a %s before you can use your paintgun!", CMDTAG, colorItem == null ? "paint color" : "paint size");
			return;
		}

		// Get the color and size from the item variables
		int paintSprite;
		char sColor[32], sSize[32];
		colorItem.GetVariable(sColor, sizeof(sColor));
		sizeItem.GetVariable(sSize, sizeof(sSize));

		// We need to delete the items now since GetEquippedItemOfType returns a clone of the item
		delete colorItem;
		delete sizeItem;

		// If the color is random we get a random sprite from the g_PaintSprites stringmap
		if(StrEqual(sColor, "random", false))
		{
			StringMapSnapshot snapshot = g_PaintSprites.Snapshot();

			int randomSpriteIndex = GetRandomInt(0, snapshot.Length - 1);
			int size = snapshot.KeyBufferSize(randomSpriteIndex);
			char[] randomSpriteKey = new char[size];
			snapshot.GetKey(randomSpriteIndex, randomSpriteKey, size);

			delete snapshot;

			if(!g_PaintSprites.GetValue(randomSpriteKey, paintSprite))
			{
				ThrowError("Failed to get random paint sprite at key %s from g_PaintSprites stringmap", randomSpriteKey);
			}
		}
		// Otherwise we combine the color and size variables together to get the key for the correct sprite
		else
		{
			char sKey[64];
			Format(sKey, sizeof(sKey), "%s%s", sColor, sSize);
			if(!g_PaintSprites.GetValue(sKey, paintSprite))
			{
				ThrowError("Failed to get paint sprite at key %s from g_PaintSprites stringmap", sKey);
			}
		}

		CG_SetPlayerAnimation(client, PLAYER_ATTACK1);
		CG_PlayPrimaryAttack(weapon);
		EmitGameSoundToAll("Weapon_Paintgun.Single", weapon);
		CG_Cooldown(weapon, 0.2);

		static float pos[3];
		TraceEye( client, pos );

		// Paint the sprite
		AddPaint( pos, paintSprite );
	}
}

void AddPaint( float pos[3], int sprite )
{	
	TE_SetupWorldDecal( pos, sprite );
	TE_SendToAll();
}

int PrecachePaint( char[] filename )
{
	char tmpPath[PLATFORM_MAX_PATH];
	Format( tmpPath, sizeof( tmpPath ), "materials/%s", filename );
	AddFileToDownloadsTable( tmpPath );
	
	return PrecacheDecal( filename, true );
}

stock void TE_SetupWorldDecal( const float vecOrigin[3], int index )
{    
    TE_Start( "World Decal" );
    TE_WriteVector( "m_vecOrigin", vecOrigin );
    TE_WriteNum( "m_nIndex", index );
}

stock void TraceEye( int client, float pos[3] )
{
	float vAngles[3], vOrigin[3];
	GetClientEyePosition( client, vOrigin );
	GetClientEyeAngles( client, vAngles );
	
	TR_TraceRayFilter( vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer );
	
	if( TR_DidHit() )
		TR_GetEndPosition( pos );
}

public bool TraceEntityFilterPlayer( int entity, int contentsMask )
{
	return ( entity > MaxClients || !entity );
}