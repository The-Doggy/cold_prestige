/* This file contains all of the utility functions and related code */

// STEAM_1:1:23456789 to 23456789
int GetAccountIdFromSteam2(const char[] steam_id)
{
    Regex exp = new Regex("^STEAM_[0-5]:[0-1]:[0-9]+$");
    int matches = exp.Match(steam_id);
    delete exp;
    
    if (matches != 1)
    {
        return 0;
    }
    
    return StringToInt(steam_id[10]) * 2 + (steam_id[8] - 48);
}