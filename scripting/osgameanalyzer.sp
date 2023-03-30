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
    
char serverName[128]; 
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
    CreateTimer(5.0, SetServerName);

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
    if ( ! isWarmup ( ) ) {
        round++;
    }
    GetCurrentMap(map, sizeof(map));

    resetPlayers();
    resetGrenades();
}
public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
    if ( ! isWarmup ( ) ) {
        analyzeKills();
    }
}

public void Event_GrenadeThrown(Event event, const char[] name, bool dontBroadcast) {
    int thrower = GetClientOfUserId(GetEventInt(event, "userid"));
    char grenade[64];
    GetEventString(event, "weapon", grenade, sizeof(grenade));
    addGrenade ( thrower, grenade );
    //PrintToConsoleAll ("Grenade thrown: %d", grenade);
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
    //PrintToConsoleAll ("removeGrenade: %s", grenade);
    for ( int i = 0; i < 4; i++ ) {
        if ( strcmp(grenades[player][i], grenade) == 0 ) {
            grenades[player][i] = "";
            //PrintToConsoleAll (" - Grenade removed: %s", grenade);
            return;
        }
    }
    //PrintToConsoleAll (" - Not removed: %s", grenade);
}
public void addGrenade ( int player, char grenade[64] ) {
    //PrintToConsoleAll ("addGrenade: %s", grenade);
    for ( int i = 0; i < 4; i++ ) {
        if ( strcmp(grenades[player][i], "") == 0 ) {
            grenades[player][i] = grenade;
            //PrintToConsoleAll (" - Grenade added: %d", grenade);
            printGrenades ( player );
            return;
        }
    }
    //PrintToConsoleAll (" - Not added!");
    printGrenades ( player );
}

public void printGrenades ( int player ) {
    char playerName[64];
    GetClientName(player, playerName, sizeof(playerName));
    //PrintToConsoleAll ("printGrenades: %s", playerName);
    for ( int i = 0; i < 4; i++ ) {
        //PrintToConsoleAll (" - Grenade: %s", grenades[player][i]);
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
    char killerName[64];
    char victimName[64];
    int killer = GetClientOfUserId(GetEventInt(event, "attacker"));
    int victim = GetClientOfUserId(GetEventInt(event, "userid"));
    int kTeam = GetClientTeam(killer);
    int vTeam = GetClientTeam(victim);

    if (!playerIsReal(killer) || !playerIsReal(victim)) {
        return;
    }

    GetClientName(killer, killerName, sizeof(killerName));
    GetClientName(victim, victimName, sizeof(victimName));

    //PrintToConsoleAll("count[killer]: %d", count[killer]);  
    strcopy(victimNames[killer][count[killer]], sizeof(victimName), victimName);
    killTimes[killer][count[killer]] = GetTime();

    char weapon[64];
    GetEventString(event, "weapon", weapon, sizeof(weapon));
    strcopy(killWeapons[killer][count[killer]], sizeof(weapon), weapon);

    //PrintToConsoleAll("Weapon: %s", weapon); // Add this line to print the weapon string value

    killIsHeadShot[killer][count[killer]] = GetEventBool(event, "headshot") == true;

    killIsTeamKill[killer][count[killer]] = kTeam == vTeam;
    killIsSuicide[killer][count[killer]] = killer == victim;
    killIsScoped[killer][count[killer]] = GetEventBool(event, "noscope") == true;
    killIsImpact[killer][count[killer]] = false;
    


    if ( isWeapon ( weapon, "hegrenade" ) || 
         isWeapon ( weapon, "flashbang" ) || 
         isWeapon ( weapon, "smokegrenade" ) || 
         isWeapon ( weapon, "decoy" ) || 
         isWeapon ( weapon, "incendiarygrenade" ) || 
         isWeapon ( weapon, "molotov" ) || 
         isWeapon ( weapon, "tagrenade" ) ) {
        
        if ( lastHitDamage[victim] < 3 ) {
            int found = 0;
            for ( int i = 0; i < 4 && found == 0; i++ ) {
                if ( isWeapon ( grenades[killer][i], weapon ) ) {
                    PrintToServer ( "[OSGameAnalyzer]: %s got hit by a %s and died. Logging event.", victimName, weapon );
                    killIsImpact[killer][count[killer]] = true;
                    found++;
                }
            }
        }
    }
    count[killer]++;
}

/* METHODS */

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
//            ! IsFakeClient(player) &&
            ! IsClientSourceTV(player));
}

/* isWarmup */
public bool isWarmup() {
    if (GameRules_GetProp("m_bWarmupPeriod") == 1) {
        return false;
    }
    return false;
}
 
/* analyze kills for each player */
public void analyzeKills() {
    char killer[64];
    char victim[64];
    char info[64];
    PrintToServer ( "[OSGameAnalyzer]: Analyzing data..." );
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
                    PrintToServer ("  - Player %s has done %d frags within 5 seconds!", killer, quickFrags);
                    Format ( info, sizeof(info), "QuickFrags: %d", quickFrags ); 
                    logEvent ( killTimes[i][j], killer, victim, info );
                }
            } else {
                quickFrags = 1;
            }
            lastFragTime = killTimes[i][j];

            // Check for unlikely weapon frags
            if ( isWeapon ( killWeapons[i][j], "decoy" ) ||
                 isWeapon ( killWeapons[i][j], "flashbang" ) ||
                 isWeapon ( killWeapons[i][j], "smokegrenade" ) ||
                 isWeapon ( killWeapons[i][j], "hegrenade" ) || 
                 isWeapon ( killWeapons[i][j], "incgrenade" ) ||
                 isWeapon ( killWeapons[i][j], "molotov" ) ||
                 isWeapon ( killWeapons[i][j], "tagrenade" ) ) {
                // Handle unlikely weapon event
                if (killIsImpact[i][j]) {   
                    PrintToServer ( "  - Player %s killed %s with %s", killer, victimNames[i][j], killWeapons[i][j] );
                    Format ( info, sizeof(info), "GrenadeImpact: %s", killWeapons[i][j] );
                    logEvent ( killTimes[i][j], killer, victim, info );
                }
            }

            // Check for knife or taser frags
            if (  isWeapon ( killWeapons[i][j], "knife" ) ||
                  isWeapon ( killWeapons[i][j], "taser" ) ) {
                // Handle knife or taser event
                PrintToServer ( "  - Player %s killed %s with %s", killer, victimNames[i][j], killWeapons[i][j] );
                Format ( info, sizeof(info), "Weapon: %s", killWeapons[i][j] );
                logEvent ( killTimes[i][j], killer, victim, info );
            }

            // Check for teamkills
            if ( killIsTeamKill[i][j] ) {
                // Handle teamkill event
                PrintToServer ( "  - Player %s teamkilled %s", killer, victimNames[i][j] );
                Format ( info, sizeof(info), "Teamkill: %s", killWeapons[i][j] );
                logEvent ( killTimes[i][j], killer, victim, info );
            }

            // Check for noscope frags
            if ( isWeapon ( killWeapons[i][j], "awp" ) ||  isWeapon ( killWeapons[i][j], "ssg08" ) && !killIsScoped[i][j]) {
                // Handle noscope event
                PrintToServer ( "  - Player %s noscoped %s using %s", killer, victimNames[i][j], killWeapons[i][j] );
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
                    PrintToServer ( "  - Player %s killed %d players at the same time/second (potential doublekill+)", killer, simultaneousFrags );
                    Format ( info, sizeof(info), "SimultaneousFrags: %d", simultaneousFrags );
                    logEvent ( killTimes[i][j], killer, victim, info );
                }
            }
        }
    }
    PrintToServer ( "[OSGameAnalyzer]: End of Analyze" );

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

    if ( ( stmt = SQL_PrepareQuery ( mysql, "insert into event (stamp, server, map, round, killer, victim, info) values (from_unixtime(?), ?, ?, ?, ?, ?, ?)", error, sizeof(error) ) ) == null ) {
        SQL_GetError ( mysql, error, sizeof(error) );
        PrintToServer("[OSGameAnalyzer]: Failed to query[0x01] (error: %s)", error);
        return;
    }

    SQL_BindParamInt    ( stmt, 0, stamp );
    SQL_BindParamString ( stmt, 1, serverName, false );
    SQL_BindParamString ( stmt, 2, map, false );
    SQL_BindParamInt    ( stmt, 3, round );
    SQL_BindParamString ( stmt, 4, killer, false );
    SQL_BindParamString ( stmt, 5, victim, false );
    SQL_BindParamString ( stmt, 6, info, false );

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

bool isWeapon ( const char[] weapon, const char[] pattern ) {
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

public Action SetServerName ( Handle timer ) {
    GetConVarString(FindConVar("hostname"), serverName, sizeof(serverName));
    PrintToServer("Server name: %s", serverName);
    return Plugin_Stop; // Stop the timer
}
