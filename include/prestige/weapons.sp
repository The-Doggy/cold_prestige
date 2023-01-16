/* This file contains all of the weapon related code and functionalities */

public void CG_OnPrimaryAttack(int client, int weapon)
{
	char sWeapon[32];
	GetEntityClassname(weapon, sWeapon, sizeof(sWeapon));
	
    // Each custom weapon that has scripted firing mechanisms are to be added here to have their individual firing functions called
	if(StrEqual(sWeapon, "weapon_paintgun"))
	{			
		FirePaintgun(client, weapon);
	}
}