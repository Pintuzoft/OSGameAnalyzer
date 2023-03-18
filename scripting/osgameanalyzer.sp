#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <regex>

char error[255];
Handle mysql = null;

public Plugin myinfo = {
    name = "OSGameAnalyzer",
    author = "Pintuz",
    description = "OldSwedes Game Analyzer plugin",
    version = "0.01",
    url = "https://github.com/Pintuzoft/OSGameAnalyzer"
};

struct Grenade {
    public int index;
    public int thrower;
};

char victimNames[MAXPLAYERS + 1][16][64];
int killTimes[MAXPLAYERS + 1][16];
char killWeapons[MAXPLAYERS + 1][16][64];
bool killIsHeadShot[MAXPLAYERS + 1][16];
bool killIsTeamKill[MAXPLAYERS + 1][16];
bool killIsSuicide[MAXPLAYERS + 1][16];
bool killIsScoped[MAXPLAYERS + 1][16];
int count[MAXPLAYERS + 1];

ArrayList grenadeList;

public void OnPluginStart() {
    grenadeList = new ArrayList();
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
}

/* EVENTS */
public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
    resetPlayers();
}
public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
    analyzeKills();
}

public void Event_GrenadeThrown(Event event, const char[] name, bool dontBroadcast) {
    int grenade = GetEventInt(event, "entityid");
    grenadeList.Push(grenade);
    PrintToChatAll ("Grenade thrown: %d", grenade);
}
public void Event_HEGrenadeDetonate(Event event, const char[] name, bool dontBroadcast) {
    removeGrenade ( GetEventInt(event, "entityid") );
}
public void Event_FlashbangDetonate(Event event, const char[] name, bool dontBroadcast) {
    removeGrenade ( GetEventInt(event, "entityid") );
}
public void Event_SmokegrenadeDetonate(Event event, const char[] name, bool dontBroadcast) {
    removeGrenade ( GetEventInt(event, "entityid") );
}
public void Event_IncendiaryGrenadeDetonate(Event event, const char[] name, bool dontBroadcast) {
    removeGrenade ( GetEventInt(event, "entityid") );
}
public void Event_MolotovDetonate(Event event, const char[] name, bool dontBroadcast) {
    removeGrenade ( GetEventInt(event, "entityid") );
}
public void Event_DecoyDetonate(Event event, const char[] name, bool dontBroadcast) {
    removeGrenade ( GetEventInt(event, "entityid") );
}
public void Event_TagrenadeDetonate(Event event, const char[] name, bool dontBroadcast) {
    removeGrenade ( GetEventInt(event, "entityid") );
}
public void removeGrenade ( int grenade ) {
    for (int i = 0; i < grenadeList.Length; i++) {
        if (grenadeList.Get(i) == grenade) {
            grenadeList.Erase(i);
            PrintToChatAll ("Grenade removed: %d", grenade);
            return;
        }
    }
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

    PrintToChatAll ("Killer: %s, Victim: %s", killerName, victimName);

    strcopy(victimNames[killer][count[killer]], sizeof(victimName), victimName);
    killTimes[killer][count[killer]] = GetTime();

    char weapon[64];
    GetEventString(event, "weapon", weapon, sizeof(weapon));
    strcopy(killWeapons[killer][count[killer]], sizeof(weapon), weapon);

    killIsHeadShot[killer][count[killer]] = GetEventInt(event, "headshot") == 1;
    if ( GetClientTeam(killer) == GetClientTeam(victim) ) {
        killIsTeamKill[killer][count[killer]] = true;
    } else {
        killIsTeamKill[killer][count[killer]] = false;
    }
    killIsSuicide[killer][count[killer]] = killer == victim;
    killIsScoped[killer][count[killer]] = GetEventInt(event, "scoped") == 1;

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
                PrintToConsoleAll ( "Player %s killed %s with %s", killer, victimNames[i][j], killWeapons[i][j] );
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
 
public bool weaponMatches(const char[] weapon, const char[] pattern) {
    Handle regex = CompileRegex(pattern);
    if (regex == INVALID_HANDLE) {
        return false;
    }

    bool matches = MatchRegex(regex, weapon) != -1;
    CloseHandle(regex);

    return matches;
}

