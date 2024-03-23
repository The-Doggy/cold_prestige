#if defined _CLASS_PITEM
 #endinput
 #endif
#define _CLASS_PITEM

#include <prestige/cold_prestige>

methodmap PItem < StringMap
{
    public PItem(int id, ItemType type, const char[] name, int price, const char[] variable, bool equipped = false)
    {
        StringMap item = new StringMap();

        item.SetValue("id", id);
        item.SetValue("type", type);
        item.SetString("name", name);
        item.SetValue("price", price);
        item.SetString("variable", variable);
        item.SetValue("equipped", equipped); // Used for when a player has this item equipped
        return view_as<PItem>(item);
    }

    property int ID
    {
        public get()
        {
            int id;
            this.GetValue("id", id);
            return id;
        }

        public set(int id)
        {
            this.SetValue("id", id);
        }
    }

    property ItemType Type
    {
        public get()
        {
            ItemType type;
            this.GetValue("type", type);
            return type;
        }

        public set(ItemType type)
        {
            this.SetValue("type", type);
        }
    }

    public void GetName(char[] buffer, int maxlen)
    {
        this.GetString("name", buffer, maxlen);
    }

    public void SetName(const char[] name)
    {
        this.SetString("name", name);
    }

    property int Price
    {
        public get()
        {
            int price;
            this.GetValue("price", price);
            return price;
        }

        public set(int price)
        {
            if(price < 0)
            {
                price = 0;
            }

            this.SetValue("price", price);
        }
    }

    public void GetVariable(char[] buffer, int maxlen)
    {
        this.GetString("variable", buffer, maxlen);
    }

    public void SetVariable(const char[] variable)
    {
        this.SetString("variable", variable);
    }

    property bool Equipped
    {
    	public get()
    	{
    		bool equipped;
    		this.GetValue("equipped", equipped);
    		return equipped;
    	}

    	public set(bool equipped)
    	{
    		this.SetValue("equipped", equipped);
    	}
    }

    public void GetTypeString(char[] buffer, int maxlen)
    {
    	Format(buffer, maxlen, "%s", this.Type == ItemType_NameColor ? " name color" : this.Type == ItemType_ChatColor ? " chat color" : this.Type == ItemType_Model ? " model" : this.Type == ItemType_PaintColor ? " paint color" : this.Type == ItemType_PaintSize ? " paint size" : 
        this.Type == ItemType_GrenadeModel ? " grenade model" : this.Type == ItemType_GrenadeTrail ? " grenade trail" : this.Type == ItemType_PrinterColor ? " printer color" : this.Type == ItemType_PlantColor ? " plant color" : "");
    }

    public void Save()
    {
        Database db = RequestDatabaseConnection();
        if(db == null)
        {
            LogError("Failed to save item data to itemlist, database is null");
            return;
        }
        
        char name[64], variable[64];
        this.GetName(name, sizeof(name));
        this.GetVariable(variable, sizeof(variable));
        
        char query[512];
        db.Format(query, sizeof(query), "INSERT INTO cold_prestige_itemlist (itemid, type, name, price, variable) VALUES (%i, %i, '%s', %i, '%s') ON DUPLICATE KEY UPDATE type=%i, name='%s', price=%i, variable='%s';", this.ID, this.Type, name, this.Price, variable, this.Type, name, this.Price, variable);
        db.Query(SQL_SaveItem, query);
    }

    public void Delete(bool refund = true)
    {
        Database db = RequestDatabaseConnection();
        if(db == null)
        {
            LogError("Failed to delete item from itemlist, database is null");
            return;
        }

        Transaction deleteTxn = new Transaction();
        char query[512];

        if(refund)
        {
            db.Format(query, sizeof(query), "UPDATE cold_prestige p JOIN cold_prestige_items i ON (p.steamid = i.steamid) SET p.prestige = p.prestige + %i WHERE i.itemid = %i", this.Price, this.ID);
            deleteTxn.AddQuery(query);
        }

        db.Format(query, sizeof(query), "DELETE FROM cold_prestige_items WHERE itemid=%i;", this.ID);
        deleteTxn.AddQuery(query);

        db.Format(query, sizeof(query), "DELETE FROM cold_prestige_itemlist WHERE itemid=%i;", this.ID);
        deleteTxn.AddQuery(query);

        db.Execute(deleteTxn, SQL_DeleteItemSuccess, SQL_DeleteItemFailure);

        // Delete the item instance
        delete this;
    }

    /* Clones the given PItem as a new PItem representation, does not actually clone any Handles */
    public PItem Clone()
    {
        char name[32], variable[64];
        this.GetName(name, sizeof(name));
        this.GetVariable(variable, sizeof(variable));

        PItem clone = new PItem(this.ID, this.Type, name, this.Price, variable);
        return clone;
    }

#if defined DEBUG
	public void Dump(int client)
	{
		CPrintToChat(client, "%s Dumping item data...", CMDTAG);

		char sName[64], sVariable[256];
		this.GetName(sName, sizeof(sName));
		this.GetVariable(sVariable, sizeof(sVariable));

		CPrintToChat(client, "%s %s ID: %i, Type: %i, Price: %i, Variable: %s, Equipped: %s", CMDTAG, sName, this.ID, this.Type, this.Price, sVariable, this.Equipped ? "True" : "False");
		CPrintToChat(client, "%s Finished dumping item data...", CMDTAG);
	}
#endif
}

public void SQL_SaveItem(Database db, DBResultSet results, const char[] sError, any data)
{
    if(results == null)
    {
        LogError("Failed to save item data to itemlist, error: %s", sError);
        return;
    }

    ReloadItemlist();
}

void SQL_DeleteItemSuccess(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
    ReloadItemlist();
}

void SQL_DeleteItemFailure(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
    LogError("Failed to delete item, failed on query %i, error: %s", failIndex, error);
}