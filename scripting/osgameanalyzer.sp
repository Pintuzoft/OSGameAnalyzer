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
char killKillerNames[MAXPLAYERS+1][16][64];
char killVictimNames[MAXPLAYERS+1][16][64];
char killKillerSteamids[MAXPLAYERS+1][16][64];
char killVictimSteamids[MAXPLAYERS+1][16][64];
int killTimes[MAXPLAYERS + 1][16];
char killWeapons[MAXPLAYERS + 1][16][64];
bool killIsHeadShot[MAXPLAYERS + 1][16];
bool killIsTeamKill[MAXPLAYERS + 1][16];
bool killIsSuicide[MAXPLAYERS + 1][16];
bool killIsNoScope[MAXPLAYERS + 1][16];
bool killIsImpact[MAXPLAYERS + 1][16];
int killPenetrated[MAXPLAYERS + 1][16];
bool killIsThrusmoke[MAXPLAYERS + 1][16];
bool killIsBlinded[MAXPLAYERS + 1][16];

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
    round = (GetTeamScore ( CS_TEAM_T ) + GetTeamScore ( CS_TEAM_CT ) + 1);
    GetCurrentMap(map, sizeof(map));
    resetPlayers();
    resetGrenades();
}
public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
//    if ( ! isWarmup ( ) ) {
        analyzeKills();
//    }
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
    for ( int i = 0; i < 4; i++ ) {
        if ( strcmp(grenades[player][i], grenade) == 0 ) {
            grenades[player][i] = "";
            return;
        }
    }
}
public void addGrenade ( int player, char grenade[64] ) {
    for ( int i = 0; i < 4; i++ ) {
        if ( strcmp(grenades[player][i], "") == 0 ) {
            grenades[player][i] = grenade;
            return;
        }
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
    int kTeam = GetClientTeam(killer);
    int vTeam = GetClientTeam(victim);
    char killerName[64];
    char victimName[64];
    char killerSteamid[64];
    char victimSteamid[64];

//    if (!playerIsReal(killer) || !playerIsReal(victim)) {
//        return;
//    }


    GetClientName(killer, killerName, sizeof(killerName));
    GetClientName(victim, victimName, sizeof(victimName));
    if ( killer > 0 ) {
        GetClientAuthId(killer, AuthId_Steam2, killerSteamid, sizeof(killerSteamid));
    } else {
        killerSteamid = "BOT";
    }
    if ( victim > 0 ) {
        GetClientAuthId(victim, AuthId_Steam2, victimSteamid, sizeof(victimSteamid));
    } else {
        victimSteamid = "BOT";
    }

    killKillerNames[killer][count[killer]] = killerName;
    killKillerSteamids[killer][count[killer]] = killerSteamid;
    killVictimNames[killer][count[killer]] = victimName;
    killVictimSteamids[killer][count[killer]] = victimSteamid;

    killTimes[killer][count[killer]] = GetTime();

    char weapon[64];
    GetEventString(event, "weapon", weapon, sizeof(weapon));
    strcopy(killWeapons[killer][count[killer]], sizeof(weapon), weapon);

    killIsHeadShot[killer][count[killer]] = GetEventBool(event, "headshot");

    killIsTeamKill[killer][count[killer]] = kTeam == vTeam;
    killIsSuicide[killer][count[killer]] = killer == victim;
    killIsNoScope[killer][count[killer]] = GetEventBool(event, "noscope");
    killIsThrusmoke[killer][count[killer]] = GetEventBool(event, "thrusmoke");
    killPenetrated[killer][count[killer]] = GetEventBool(event, "penetrated");
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
    return true;
//    return (player > 0 &&
//            player <= MAXPLAYERS &&
//            IsClientInGame(player) &&
//            ! IsFakeClient(player) &&
//            ! IsClientSourceTV(player));
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
    PrintToServer ( "[OSGameAnalyzer]: Analyzing data..." );
    for (int i = 1; i <= MAXPLAYERS; i++) {
        if (count[i] == 0) {
            continue;
        }
        Format ( killer, sizeof(killer), "%s", killKillerNames[i][0] );

        int quickFrags = 0;
        int lastFragTime = killTimes[i][0];

        for (int j = 0; j < count[i]; j++) {
            Format ( victim, sizeof(victim), "%s", killVictimNames[i][j] );

            logkill ( i, j );
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
                    PrintToServer ( "  - Player %s killed %s with %s", killer, killVictimNames[i][j], killWeapons[i][j] );
                    Format ( info, sizeof(info), "GrenadeImpact: %s", killWeapons[i][j] );
                    logEvent ( killTimes[i][j], killer, victim, info );
                }
            }

            // Check for knife or taser frags
            if (  isWeapon ( killWeapons[i][j], "knife" ) ||
                  isWeapon ( killWeapons[i][j], "taser" ) ) {
                // Handle knife or taser event
                PrintToServer ( "  - Player %s killed %s with %s", killer, killVictimNames[i][j], killWeapons[i][j] );
                Format ( info, sizeof(info), "Weapon: %s", killWeapons[i][j] );
                logEvent ( killTimes[i][j], killer, victim, info );
            }

            // Check for suicide

            if ( killIsSuicide[i][j] ) {
                PrintToServer ( "  - Player %s suicide", killer, killVictimNames[i][j] );
                Format ( info, sizeof(info), "Suicide: %s", killWeapons[i][j] );
                logEvent ( killTimes[i][j], killer, victim, info );
            }

            // Check for teamkills
            if ( killIsTeamKill[i][j] && ! killIsSuicide[i][j] ) {
                // Handle teamkill event
                PrintToServer ( "  - Player %s teamkilled %s", killer, killVictimNames[i][j] );
                Format ( info, sizeof(info), "Teamkill: %s", killWeapons[i][j] );
                logEvent ( killTimes[i][j], killer, victim, info );
            }

            // Check for noscope frags
            if ( ( isWeapon ( killWeapons[i][j], "awp" ) || isWeapon ( killWeapons[i][j], "ssg08" ) ) && killIsNoScope[i][j]) {
                // Handle noscope event
                PrintToServer ( "  - Player %s noscoped %s using %s", killer, killVictimNames[i][j], killWeapons[i][j] );
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
        // check for 3+ total frags for whole round
        if ( count[i] >= 3 ) {
            // Handle 3+ total frags for whole round event
            PrintToServer ( "  - Player %s has done %d frags in this round", killer, count[i] );
            Format ( info, sizeof(info), "TotalFrags: %d", count[i] );
            logEvent ( killTimes[i][0], killer, victim, info );
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
        PrintToServer("[OSGameAnalyzer]: Failed to prepare query[0x01] (error: %s)", error);
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
        PrintToServer("[OSGameAnalyzer]: Failed to execute[0x02] (error: %s)", error);
        return;
    }

    if ( stmt != null ) {
        delete stmt;
    }

}

/**
 
 CREATE TABLE `kills` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `map` varchar(64) NOT NULL,
  `round` int(11) NOT NULL,
  `stamp` datetime DEFAULT NULL,
  `attacker_steamid` varchar(32) NOT NULL,
  `attacker_name` varchar(64) NOT NULL,
  `victim_steamid` varchar(32) NOT NULL,
  `victim_name` varchar(64) NOT NULL,
  `assister_steamid` varchar(32) NOT NULL,
  `assister_name` varchar(64) NOT NULL,
  `weapon` varchar(32) NOT NULL,
  `suicide` int(11) NOT NULL,
  `teamkill` int(11) NOT NULL,
  `teamassist` int(11) NOT NULL,
  `headshot` int(11) NOT NULL,
  `penetrated` int(11) NOT NULL,
  `thrusmoke` int(11) NOT NULL,
  `blinded` int(11) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;

 */

public void logkill ( int killer, int killid ) {
    char killerName[64];
    char victimName[64];
    char killerSteamid[64];
    char victimSteamid[64];
    char weapon[64];
    int stamp;
    int suicide;
    int teamkill;
    int headshot;
    int penetrated;
    int thrusmoke;
    int blinded;

    if ( killTimes[killer][killid] == 0 ) {
        return;
    }



    killerName = killKillerNames[killer][killid];
    victimName = killVictimNames[killer][killid];

    killerSteamid = killKillerSteamids[killer][killid];
    victimSteamid = killVictimSteamids[killer][killid];

    stamp = killTimes[killer][killid];
    weapon = killWeapons[killer][killid];

    suicide = killIsSuicide[killer][killid];
    teamkill = killIsTeamKill[killer][killid];

    headshot = killIsHeadShot[killer][killid];
    penetrated = killPenetrated[killer][killid];

    thrusmoke = killIsThrusmoke[killer][killid];
    blinded = killIsBlinded[killer][killid];

    Handle stmt = null;
    checkConnection();

    if ( ( stmt = SQL_PrepareQuery ( mysql, "insert into kills (stamp,server,map,round,killer_steamid,killer_name,victim_steamid,victim_name,weapon,suicide,teamkill,headshot,penetrated,thrusmoke,blinded) values (from_unixtime(?),?,?,?,?,?,?,?,?,?,?,?,?,?,?)", error, sizeof(error) ) ) == null ) {
        SQL_GetError ( mysql, error, sizeof(error) );
        PrintToServer("[OSGameAnalyzer]: Failed to prepare query[0x03] (error: %s)", error);
        return;
    }

    SQL_BindParamInt ( stmt, 0, stamp );
    SQL_BindParamString ( stmt, 1, serverName, false );
    SQL_BindParamString ( stmt, 2, map, false );
    SQL_BindParamInt ( stmt, 3, round );
    SQL_BindParamString ( stmt, 4, killerSteamid, false );
    SQL_BindParamString ( stmt, 5, killerName, false );
    SQL_BindParamString ( stmt, 6, victimSteamid, false );
    SQL_BindParamString ( stmt, 7, victimName, false );
    SQL_BindParamString ( stmt, 8, weapon, false );
    SQL_BindParamInt ( stmt, 9, suicide );
    SQL_BindParamInt ( stmt, 10, teamkill );
    SQL_BindParamInt ( stmt, 11, headshot );
    SQL_BindParamInt ( stmt, 12, penetrated );
    SQL_BindParamInt ( stmt, 13, thrusmoke );
    SQL_BindParamInt ( stmt, 14, blinded );

    if ( ! SQL_Execute ( stmt ) ) {
        SQL_GetError ( mysql, error, sizeof(error) );
        PrintToServer("[OSGameAnalyzer]: Failed to execute[0x04] (error: %s)", error);
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
            killKillerNames[i][j][0] = '\0';
            killVictimNames[i][j][0] = '\0';
            killKillerSteamids[i][j][0] = '\0';
            killVictimSteamids[i][j][0] = '\0';
            killTimes[i][j] = 0;
            killWeapons[i][j][0] = '\0';
            killIsHeadShot[i][j] = false;
            killIsTeamKill[i][j] = false;
            killIsSuicide[i][j] = false;
            killIsImpact[i][j] = false;
            killIsNoScope[i][j] = false;
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
