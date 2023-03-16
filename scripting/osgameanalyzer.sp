#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <string>
#include <cstrike>

char error[255];
Handle mysql = null;

public Plugin myinfo = {
	name = "OSGameAnalyzer",
	author = "Pintuz",
	description = "OldSwedes Game Analyzer plugin",
	version = "0.01",
	url = "https://github.com/Pintuzoft/OSGameAnalyzer"
}

struct Game {
    public char server[64];
    public char map[64];
    public int round;
};

struct Player {
    public char name[64];
    public int killCount;
    public KillInfo kills[12];
};

struct KillInfo {
    public char victim[64];
    public int time;
	public char weapon[64];
    public bool isHeadShot;
    public bool isTeamKill;
    public bool isSuicide;
};

Game game;
public Player pList[MAXPLAYERS+1];

public void OnPluginStart ( ) {
    HookEvent ( "round_start", Event_RoundStart );
    HookEvent ( "round_end", Event_RoundEnd );
    HookEvent ( "player_death", Event_PlayerDeath );
}

/* EVENTS */
public void Event_RoundStart ( Event event, const char[] name, bool dontBroadcast ) { 
    
}
public void Event_PlayerDeath ( Event event, const char[] name, bool dontBroadcast ) {
    char killerName[64];
    char victimName[64];
    int killer = GetClientOfUserId(GetEventInt(event, "attacker"));
    int victim = GetClientOfUserId(GetEventInt(event, "userid"));

    int count;
    if ( ! playerIsReal ( killer ) || ! playerIsReal ( victim ) ) {
        return;
    }
//    Player p = pList[killer];
//    count = p.killCount;


//    GetClientName ( killer, killerName, sizeof(killerName) );
//    GetClientName ( victim, victimName, sizeof(victimName) );

//    player.kills[count].victim = victimName;
//    player.kills[count].time = GetTime();
//    player.kills[count].weapon = GetEventString(event, "weapon");
//    player.kills[count].isHeadShot = GetEventInt(event, "headshot") == 1;
//    player.kills[count].isTeamKill = GetEventInt(event, "assister") != 0;
//    player.kills[count].isSuicide = killer == victim;

//    player.killCount++;

}

public void Event_RoundEnd ( Event event, const char[] name, bool dontBroadcast ) {

}

/* METHODS */
public void databaseConnect ( ) {
    if ( ( mysql = SQL_Connect ( "gameanalyzer", true, error, sizeof(error) ) ) != null ) {
        PrintToServer ( "[OSGameAnalyzer]: Connected to mysql database!" );
    } else {
        PrintToServer ( "[OSGameAnalyzer]: Failed to connect to mysql database! (error: %s)", error );
    }
}

public void checkConnection ( ) {
    if ( mysql == null || mysql == INVALID_HANDLE ) {
        databaseConnect ( );
    }
}

/* return true if player is real */
public bool playerIsReal ( int player ) {
    return ( player > 0 &&
        IsClientInGame ( player ) &&
        ! IsClientSourceTV ( player ) );
}


/* isWarmup */
public bool isWarmup ( ) {
    if ( GameRules_GetProp ( "m_bWarmupPeriod" ) == 1 ) {
        return true;
    }
    return false;
}

/* analyze kills for each player and figure out if the kills is:
   1: 3 or more in a short amount of time (quick frags) 
   2: killer kills more than 1 player in the same second
   3: killer makes a teamkill
   4: weapon is a knife or a taser
   5: weapon is a flashbang, smoke or decoy

   code is descriptive enough to understand what it does
 */
public void analyzeKills ( ) {

  
    
}
 