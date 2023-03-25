#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <string>

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

int round = 0;
char map[64];

char victimNames[MAXPLAYERS + 1][16][64];
int killTimes[MAXPLAYERS + 1][16];
char killWeapons[MAXPLAYERS + 1][16][64];
bool killIsHeadShot[MAXPLAYERS + 1][16];
bool killIsTeamKill[MAXPLAYERS + 1][16];
bool killIsSuicide[MAXPLAYERS + 1][16];
bool killIsScoped[MAXPLAYERS + 1][16];
bool killIsImpact[MAXPLAYERS + 1][16];
int count[MAXPLAYERS + 1];
 
int lastHitDamage[MAXPLAYERS + 1];
char grenades[MAXPLAYERS + 1][4][64];

public void OnPluginStart() {
    databaseConnect();
    HookEvent("round_start", Event_RoundStart);
    HookEvent("round_end", Event_RoundEnd);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_hurt", Event_PlayerHurt);

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
public void OnMapStart ( ) {
    round = 0;
}

/* EVENTS */
public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
    round++;
    GetCurrentMap(map, sizeof(map));

    resetPlayers();
    resetGrenades();
}
public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
    analyzeKills();
}

public void Event_GrenadeThrown(Event event, const char[] name, bool dontBroadcast) {
    int thrower = GetClientOfUserId(GetEventInt(event, "userid"));
    char grenade[64];
    GetEventString(event, "weapon", grenade, sizeof(grenade));
    addGrenade ( thrower, grenade );
    PrintToConsoleAll ("Grenade thrown: %d", grenade);
}
public void Event_HEGrenadeDetonate(Event event, const char[] name, bool dontBroadcast) {
    int player = GetClientOfUserId(GetEventInt(event, "userid"));
    removeGrenade ( player, "hegrenade" );
}
public void Event_FlashbangDetonate(Event event, const char[] name, bool dontBroadcast) {
    int player = GetClientOfUserId(GetEventInt(event, "userid"));
    removeGrenade ( player, "flashbang" );
}
public void Event_SmokegrenadeDetonate(Event event, const char[] name, bool dontBroadcast) {
    int player = GetClientOfUserId(GetEventInt(event, "userid"));
    removeGrenade ( player, "smokegrenade" );
}
public void Event_IncendiaryGrenadeDetonate(Event event, const char[] name, bool dontBroadcast) {
    int player = GetClientOfUserId(GetEventInt(event, "userid"));
    removeGrenade ( player, "incendiary" );
}
public void Event_MolotovDetonate(Event event, const char[] name, bool dontBroadcast) {
    int player = GetClientOfUserId(GetEventInt(event, "userid"));
    removeGrenade ( player, "molotov" );
}
public void Event_DecoyDetonate(Event event, const char[] name, bool dontBroadcast) {
    int player = GetClientOfUserId(GetEventInt(event, "userid"));
    removeGrenade ( player, "decoy" );
}
public void Event_TagrenadeDetonate(Event event, const char[] name, bool dontBroadcast) {
    int player = GetClientOfUserId(GetEventInt(event, "userid"));
    removeGrenade ( player, "tagrenade" );
}
public void removeGrenade ( int player, char grenade[64] ) {
    PrintToConsoleAll ("removeGrenade: %s", grenade);
    for ( int i = 0; i < 4; i++ ) {
        if ( strcmp(grenades[player][i], grenade) == 0 ) {
            grenades[player][i] = "";
            PrintToConsoleAll (" - Grenade removed: %s", grenade);
            return;
        }
    }
    PrintToConsoleAll (" - Not removed: %s", grenade);
}
public void addGrenade ( int player, char grenade[64] ) {
    PrintToConsoleAll ("addGrenade: %s", grenade);
    for ( int i = 0; i < 4; i++ ) {
        if ( strcmp(grenades[player][i], "") == 0 ) {
            grenades[player][i] = grenade;
            PrintToConsoleAll (" - Grenade added: %d", grenade);
            printGrenades ( player );
            return;
        }
    }
    PrintToConsoleAll (" - Not added!");
    printGrenades ( player );
}

public void printGrenades ( int player ) {
    char playerName[64];
    GetClientName(player, playerName, sizeof(playerName));
    PrintToConsoleAll ("printGrenades: %s", playerName);
    for ( int i = 0; i < 4; i++ ) {
        PrintToConsoleAll (" - Grenade: %s", grenades[player][i]);
    }
}

/* log last hit damage */
public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast) {
    int victim = GetClientOfUserId(GetEventInt(event, "userid"));
    int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

    if (!playerIsReal(victim) || !playerIsReal(attacker)) {
        return;
    }

    lastHitDamage[victim] = GetEventInt(event, "dmg_health");
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

    PrintToConsoleAll("count[killer]: %d", count[killer]);  
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
    killIsImpact[killer][count[killer]] = false;
    
    if (weaponMatches(weapon, "hegrenade") || 
        weaponMatches(weapon, "flashbang") || 
        weaponMatches(weapon, "smokegrenade") || 
        weaponMatches(weapon, "decoy") || 
        weaponMatches(weapon, "incendiarygrenade") || 
        weaponMatches(weapon, "molotov") || 
        weaponMatches(weapon, "tagrenade")) {
        
        if ( lastHitDamage[victim] < 3 ) {
            int found = 0;
            for ( int i = 0; i < 4 && found == 0; i++ ) {
                PrintToChatAll ( "2" );
                if ( strcmp(grenades[killer][i], weapon) == 0 ) {
                    PrintToChatAll ( "[OSGameAnalyzer]: %s got hit by a %s and died. Logging event.", victimName, weapon );
                    killIsImpact[killer][count[killer]] = true;
                    found++;
                }
            }
        }
    }

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
  
  
    count[killer]++;
}

/* METHODS */

//public Action Timer_CheckGrenadeExistence(Handle timer, Handle:pack) {
//    int grenadeEntity;
//    char killer[64];
//    char victim[64];
//    char weapon[64];
    
//    ResetPack(pack);
//    grenadeEntity = ReadPackCell(pack);
//    ReadPackString(pack, killer, sizeof(killer));
//    ReadPackString(pack, victim, sizeof(victim));
//    ReadPackString(pack, weapon, sizeof(weapon));

//    if (IsValidEntity(grenadeEntity)) {
//        PrintToChatAll ("Grenade still exists");
//    } else {
//        PrintToChatAll ("Grenade doesn't exist");
//    }
//    CloseHandle(timer);
//    return Plugin_Continue;
//}


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
    char killer[64];
    char victim[64];
    char info[64];
    PrintToChatAll ( "[OSGameAnalyzer]: Analyzing data..." );
    for (int i = 1; i <= MAXPLAYERS; i++) {
        if (count[i] == 0) {
            continue;
        }
        
        GetClientName(i, killer, sizeof(killer));
        int quickFrags = 0;
        int lastFragTime = killTimes[i][0];


        for (int j = 0; j < count[i]; j++) {
            victim = victimNames[i][j];
            // Check for 3+ frags in a short amount of time
            if (killTimes[i][j] - lastFragTime <= 5) {
                quickFrags++;
                if (quickFrags >= 3) {
                    // Handle the quick frags event
                    PrintToConsoleAll ("  - Player %s has done %d frags within 5 seconds!", killer, quickFrags);
                    Format ( info, sizeof(info), "QuickFrags: %d", quickFrags ); 
                    logEvent ( killTimes[i][j], killer, victim, info );
                }
            } else {
                quickFrags = 1;
            }
            lastFragTime = killTimes[i][j];

            // Check for unlikely weapon frags
            if (weaponMatches(killWeapons[i][j], "decoy|flashbang|smokegrenade|hegrenade|incgrenade|molotov|tagrenade")) {
                // Handle unlikely weapon event
                if (killIsImpact[i][j]) {   
                    PrintToConsoleAll ( "  - Player %s killed %s with %s", killer, victimNames[i][j], killWeapons[i][j] );
                    Format ( info, sizeof(info), "GrenadeImpact: %s", killWeapons[i][j] );
                    logEvent ( killTimes[i][j], killer, victim, info );
                }
            }

            // Check for knife or taser frags
            if (weaponMatches(killWeapons[i][j], ".*knife|taser")) {
                // Handle knife or taser event
                PrintToConsoleAll ( "  - Player %s killed %s with %s", killer, victimNames[i][j], killWeapons[i][j] );
                Format ( info, sizeof(info), "Weapon: %s", killWeapons[i][j] );
                logEvent ( killTimes[i][j], killer, victim, info );
            }

            // Check for teamkills
            if (killIsTeamKill[i][j]) {
                // Handle teamkill event
                PrintToConsoleAll ( "  - Player %s teamkilled %s", killer, victimNames[i][j] );
                Format ( info, sizeof(info), "Teamkill: %s", killWeapons[i][j] );
                logEvent ( killTimes[i][j], killer, victim, info );
            }

            // Check for noscope frags
            if ((strcmp(killWeapons[i][j], "awp") == 0 || strcmp(killWeapons[i][j], "ssg08") == 0) && !killIsScoped[i][j]) {
                // Handle noscope event
                PrintToConsoleAll ( "  - Player %s noscoped %s using %s", killer, victimNames[i][j], killWeapons[i][j] );
                Format ( info, sizeof(info), "Noscope: %s", killWeapons[i][j] );
                logEvent ( killTimes[i][j], killer, victim, info );
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
                    PrintToConsoleAll ( "  - Player %s killed %d players at the same time/second (potential doublekill+)", killer, simultaneousFrags );
                    Format ( info, sizeof(info), "SimultaneousFrags: %d", simultaneousFrags );
                    logEvent ( killTimes[i][j], killer, victim, info );
                }
            }
        }
    }
    PrintToChatAll ( "[OSGameAnalyzer]: End of Analyze" );

}

/* 
    MariaDB [gameanalyzer]> desc event;
    +--------+--------------+------+-----+---------+-------+
    | Field  | Type         | Null | Key | Default | Extra |
    +--------+--------------+------+-----+---------+-------+
    | id     | int(11)      | NO   | PRI | NULL    |       |
    | stamp  | datetime     | YES  |     | NULL    |       |
    | round  | int(11)      | YES  |     | NULL    |       |
    | killer | varchar(64)  | YES  |     | NULL    |       |
    | victim | varchar(64)  | YES  |     | NULL    |       |
    | info   | varchar(128) | YES  |     | NULL    |       |
    +--------+--------------+------+-----+---------+-------+

 */

/* Log event */
public void logEvent(int stamp, char[] killer, char[] victim, char[] info) { 
    Handle stmt = null;

    checkConnection();

    if ( ( stmt = SQL_PrepareQuery ( mysql, "insert into event (stamp, map, round, killer, victim, info) values (from_unixtime(?), ?, ?, ?, ?, ?)", error, sizeof(error) ) ) == null ) {
        SQL_GetError ( mysql, error, sizeof(error) );
        PrintToServer("[OSGameAnalyzer]: Failed to query[0x01] (error: %s)", error);
        return;
    }

    SQL_BindParamInt    ( stmt, 0, stamp );
    SQL_BindParamString ( stmt, 1, map, false );
    SQL_BindParamInt    ( stmt, 2, round );
    SQL_BindParamString ( stmt, 3, killer, false );
    SQL_BindParamString ( stmt, 4, victim, false );
    SQL_BindParamString ( stmt, 5, info, false );

    if ( ! SQL_Execute ( stmt ) ) {
        SQL_GetError ( mysql, error, sizeof(error) );
        PrintToServer("[OSGameAnalyzer]: Failed to query[0x02] (error: %s)", error);
        return;
    }

    if ( stmt != null ) {
        delete stmt;
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
            killIsImpact[i][j] = false;
        }
        lastHitDamage[i] = 0;
    }
}
 
public void resetGrenades() {
    for (int i = 1; i <= MAXPLAYERS; i++) {
        for (int j = 0; j < 4; j++) {
            grenades[i][j] = "";
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
