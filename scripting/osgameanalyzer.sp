#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

#define BOUNCE_TIME_THRESHOLD 0.5

char error[255];
Handle mysql = null;

public Plugin myinfo = {
    name = "OSGameAnalyzer",
    author = "Pintuz",
    description = "OldSwedes Game Analyzer plugin",
    version = "0.01",
    url = "https://github.com/Pintuzoft/OSGameAnalyzer"
};
 
char victimNames[MAXPLAYERS + 1][16][64];
int killTimes[MAXPLAYERS + 1][16];
char killWeapons[MAXPLAYERS + 1][16][64];
bool killIsHeadShot[MAXPLAYERS + 1][16];
bool killIsTeamKill[MAXPLAYERS + 1][16];
bool killIsSuicide[MAXPLAYERS + 1][16];
bool killIsScoped[MAXPLAYERS + 1][16];
bool killIsImpact[MAXPLAYERS + 1][16];
int count[MAXPLAYERS + 1];

int grenades[MAXPLAYERS + 1][4];

public void OnPluginStart() {
    HookEvent("round_start", Event_RoundStart);
    HookEvent("round_end", Event_RoundEnd);
    HookEvent("player_death", Event_PlayerDeath);

    HookEvent("grenade_thrown", Event_GrenadeThrown);
    HookEvent("hegrenade_detonate", Event_HEGrenadeDetonate);
    HookEvent("flashbang_detonate", Event_FlashbangDetonate);
    HookEvent("smokegrenade_detonate", Event_SmokegrenadeDetonate);
    HookEvent("inferno_startburn", Event_IncendiaryGrenadeDetonate);
    HookEvent("molotov_detonate", Event_MolotovDetonate);
    HookEvent("decoy_detonate", Event_DecoyDetonate);
    HookEvent("tagrenade_detonate", Event_TagrenadeDetonate);

    resetPlayers();
    resetGrenades();

}

/* EVENTS */
public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
    resetPlayers();
    resetGrenades();
}
public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
    analyzeKills();
}

public void Event_GrenadeThrown(Event event, const char[] name, bool dontBroadcast) {
    int grenade = GetEventInt(event, "entityid");
    int thrower = GetClientOfUserId(GetEventInt(event, "userid"));
    addGrenade ( thrower, grenade );
    PrintToConsoleAll ("Grenade thrown: %d", grenade);
}
public void Event_HEGrenadeDetonate(Event event, const char[] name, bool dontBroadcast) {
    int player = GetClientOfUserId(GetEventInt(event, "userid"));
    removeGrenade ( player, GetEventInt(event, "entityid") );
}
public void Event_FlashbangDetonate(Event event, const char[] name, bool dontBroadcast) {
    int player = GetClientOfUserId(GetEventInt(event, "userid"));
    removeGrenade ( player, GetEventInt(event, "entityid") );
}
public void Event_SmokegrenadeDetonate(Event event, const char[] name, bool dontBroadcast) {
    int player = GetClientOfUserId(GetEventInt(event, "userid"));
    removeGrenade ( player, GetEventInt(event, "entityid") );
}
public void Event_IncendiaryGrenadeDetonate(Event event, const char[] name, bool dontBroadcast) {
    int player = GetClientOfUserId(GetEventInt(event, "userid"));
    removeGrenade ( player, GetEventInt(event, "entityid") );
}
public void Event_MolotovDetonate(Event event, const char[] name, bool dontBroadcast) {
    int player = GetClientOfUserId(GetEventInt(event, "userid"));
    removeGrenade ( player, GetEventInt(event, "entityid") );
}
public void Event_DecoyDetonate(Event event, const char[] name, bool dontBroadcast) {
    int player = GetClientOfUserId(GetEventInt(event, "userid"));
    removeGrenade ( player, GetEventInt(event, "entityid") );
}
public void Event_TagrenadeDetonate(Event event, const char[] name, bool dontBroadcast) {
    int player = GetClientOfUserId(GetEventInt(event, "userid"));
    removeGrenade ( player, GetEventInt(event, "entityid") );
}
public void removeGrenade ( int player, int grenade ) {
    PrintToConsoleAll ("removeGrenade: %d", grenade);
    for ( int i = 0; i < 4; i++ ) {
        if ( grenades[player][i] == grenade ) {
            grenades[player][i] = 0;
            PrintToConsoleAll (" - Grenade removed: %d", grenade);
            return;
        }
    }
}
public void addGrenade ( int player, int grenade ) {
    PrintToConsoleAll ("addGrenade: %s", grenade);
    for ( int i = 0; i < 4; i++ ) {
        if ( grenades[player][i] == 0 ) {
            grenades[player][i] = grenade;
            PrintToConsoleAll (" - Grenade added: %d", grenade);
            printGrenades ( player );
            return;
        }
    }
    PrintToConsoleAll (" - Not added!");
    printGrenades ( player );
}

public int findGrenade ( int player, char weapon[64] ) {
    char className[64];
    PrintToConsoleAll ("findGrenade: %s", weapon );
    for ( int i = 0; i < 4; i++ ) {
        PrintToConsoleAll (" - Grenade: %d", grenades[player][i]);
        if ( grenades[player][i] > 0 ) {
            GetEntityClassname(grenades[player][i], className, sizeof(className));
            PrintToConsoleAll (" - classname: %s", className);
            if ( strcmp ( weapon, className ) == 0 ) {
                PrintToConsoleAll (" - Matched name: %s", className);
                return grenades[player][i];
            }
        }
    }
    PrintToConsoleAll (" - Not Found!");
    return 0;
}

public int printGrenades ( int player ) {
    PrintToConsoleAll ("printGrenades: %d", player);
    for ( int i = 0; i < 4; i++ ) {
        PrintToConsoleAll (" - Grenade: %d", grenades[player][i]);
    }
    return 0;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
    int killer = GetClientOfUserId(GetEventInt(event, "attacker"));
    int victim = GetClientOfUserId(GetEventInt(event, "userid"));

    if (!playerIsReal(killer) || !playerIsReal(victim)) {
        return;
    }

    char killerName[64];
    char victimName[64];
    GetClientName(killer, killerName, sizeof(killerName));
    GetClientName(victim, victimName, sizeof(victimName));

    strcopy(victimNames[killer][count[killer]], sizeof(victimName), victimName);
    killTimes[killer][count[killer]] = GetTime();

    char weapon[64];
    GetEventString(event, "weapon", weapon, sizeof(weapon));
    strcopy(killWeapons[killer][count[killer]], sizeof(weapon), weapon);

    PrintToConsoleAll("Weapon: %s", weapon); // Add this line to print the weapon string value

    killIsHeadShot[killer][count[killer]] = GetEventInt(event, "headshot") == 1;
    killIsTeamKill[killer][count[killer]] = GetEventInt(event, "assister") != 0;
    killIsSuicide[killer][count[killer]] = killer == victim;
    killIsScoped[killer][count[killer]] = GetEventInt(event, "scoped") == 1;

    PrintToChatAll ( "0" );
    if (weaponMatches(weapon, "hegrenade") || 
        weaponMatches(weapon, "flashbang") || 
        weaponMatches(weapon, "smokegrenade") || 
        weaponMatches(weapon, "decoy") || 
        weaponMatches(weapon, "incendiarygrenade") || 
        weaponMatches(weapon, "molotov") || 
        weaponMatches(weapon, "tagrenade")) {
    
    PrintToChatAll ( "1" );
        int grenadeIndex = findGrenade(killer, weapon);
    PrintToChatAll ( "2" );

        if (grenadeIndex > 0) {
    PrintToChatAll ( "3" );
            char className[64];
        
    PrintToChatAll ( "4" );
            PrintToConsoleAll("className: %s", className);

        }
    PrintToChatAll ( "5" );


//        int grenadeEntity = GetEventInt(event, "inflictor_entindex");
//        PrintToChatAll ("Killed by a grenade: %d", grenadeEntity);

//        if (grenadeEntity != 0) {     
//            Handle pack;
//            CreateTimer(0.1, Timer_CheckGrenadeExistence, pack);
//            WritePackCell(pack, grenadeEntity);
//            WritePackString(pack, killerName);
//            WritePackString(pack, victimName);
//            WritePackString(pack, weapon);
//        }
    }
    PrintToChatAll ( "6" );
    
    count[killer]++;
}

/* METHODS */

public Action Timer_CheckGrenadeExistence(Handle timer, Handle:pack) {
    int grenadeEntity;
    char killer[64];
    char victim[64];
    char weapon[64];
    
    ResetPack(pack);
    grenadeEntity = ReadPackCell(pack);
    ReadPackString(pack, killer, sizeof(killer));
    ReadPackString(pack, victim, sizeof(victim));
    ReadPackString(pack, weapon, sizeof(weapon));

    if (IsValidEntity(grenadeEntity)) {
        PrintToChatAll ("Grenade still exists");
    } else {
        PrintToChatAll ("Grenade doesn't exist");
    }
    CloseHandle(timer);
    return Plugin_Continue;
}


public void databaseConnect() {
    if ((mysql = SQL_Connect("gameanalyzer", true, error, sizeof(error))) != null) {
        PrintToServer("[OSGameAnalyzer]: Connected to mysql database!");
    } else {
        PrintToServer("[OSGameAnalyzer]: Failed to connect to mysql database! (error: %s)", error);
    }
}

public void checkConnection() {
    if (mysql == null || mysql == INVALID_HANDLE) {
        databaseConnect();
    }
}

/* return true if player is real */
public bool playerIsReal(int player) {
    return (player > 0 &&
            player <= MAXPLAYERS &&
            IsClientInGame(player) &&
            !IsClientSourceTV(player));
}

/* isWarmup */
public bool isWarmup() {
    if (GameRules_GetProp("m_bWarmupPeriod") == 1) {
        return true;
    }
    return false;
}
 
/* analyze kills for each player */
public void analyzeKills() {
    for (int i = 1; i <= MAXPLAYERS; i++) {
        if (count[i] == 0) {
            continue;
        }
        char killer[64];
        GetClientName(i, killer, sizeof(killer));
        int quickFrags = 0;
        int lastFragTime = killTimes[i][0];

        for (int j = 0; j < count[i]; j++) {
            // Check for 3+ frags in a short amount of time
            if (killTimes[i][j] - lastFragTime <= 5) {
                quickFrags++;
                if (quickFrags >= 3) {
                    // Handle the quick frags event
                    PrintToConsoleAll ("Player %s has done %d frags within 5 seconds!", killer, quickFrags);
                }
            } else {
                quickFrags = 1;
            }
            lastFragTime = killTimes[i][j];

            // Check for unlikely weapon frags
            if (weaponMatches(killWeapons[i][j], "decoy|flashbang|smokegrenade|hegrenade|incgrenade|molotov|tagrenade")) {
                // Handle unlikely weapon event
                if (killIsImpact[i][j]) {   
                    PrintToConsoleAll ( "Player %s killed %s with %s", killer, victimNames[i][j], killWeapons[i][j] );
                }
            }

            // Check for knife or taser frags
            if (weaponMatches(killWeapons[i][j], ".*knife|taser")) {
                // Handle knife or taser event
                PrintToConsoleAll ( "Player %s killed %s with %s", killer, victimNames[i][j], killWeapons[i][j] );
            }

            // Check for teamkills
            if (killIsTeamKill[i][j]) {
                // Handle teamkill event
                PrintToConsoleAll ( "Player %s teamkilled %s", killer, victimNames[i][j] );
            }

            // Check for noscope frags
            if ((strcmp(killWeapons[i][j], "awp") == 0 || strcmp(killWeapons[i][j], "ssg08") == 0) && !killIsScoped[i][j]) {
                // Handle noscope event
                PrintToConsoleAll ( "Player %s noscoped %s using %s", killer, victimNames[i][j], killWeapons[i][j] );
            }

            // Check for 2+ players fragged at the same time
            if (j < count[i] - 1 && killTimes[i][j] == killTimes[i][j + 1]) {
                int simultaneousFrags = 1;
                while (j < count[i] - 1 && killTimes[i][j] == killTimes[i][j + 1]) {
                    simultaneousFrags++;
                    j++;
                }
                if (simultaneousFrags >= 2) {
                    // Handle 2+ players fragged at the same time event
                    PrintToConsoleAll ( "Player %s fragged %d players at the same time/second", killer, simultaneousFrags );
                }
            }
        }
    }
}


public void resetPlayers() {
    for (int i = 1; i <= MAXPLAYERS; i++) {
        count[i] = 0;
        for (int j = 0; j < 16; j++) {
            victimNames[i][j][0] = '\0';
            killTimes[i][j] = 0;
            killWeapons[i][j][0] = '\0';
            killIsHeadShot[i][j] = false;
            killIsTeamKill[i][j] = false;
            killIsSuicide[i][j] = false;
        }
    }
}
 
public void resetGrenades() {
    for (int i = 1; i <= MAXPLAYERS; i++) {
        for (int j = 0; j < 4; j++) {
            grenades[i][j] = 0;
        }
    }
}

bool weaponMatches(const char[] weapon, const char[] pattern) {
    return StrContains(weapon, pattern) != -1;
}

public int GetClientOfEnt(int entity) {
    if (entity > 0 && entity <= MaxClients) {
        if (IsClientInGame(entity)) {
            return entity;
        }
    }
    return 0;
}
