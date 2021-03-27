#include <amxmodx>
#include <amxmisc>
#include <cromchat>
#include <crxranks_const>
#include <csx>
#include <fakemeta>
#include <nvault>
#include <sqlx>

#if AMXX_VERSION_NUM < 183 || !defined set_dhudmessage
	#tryinclude <dhudmessage>

	#if !defined _dhudmessage_included
		#error "dhudmessage.inc" is missing in your "scripting/include" folder. Download it from: "https://amxx-bg.info/inc/"
	#endif
#endif

#if !defined client_disconnected
	#define client_disconnected client_disconnect
#endif

#if !defined replace_string
	#define replace_string replace_all
#endif

new const PLUGIN_VERSION[] = "3.10"
const Float:DELAY_ON_CONNECT = 5.0
const Float:HUD_REFRESH_FREQ = 1.0
const Float:DELAY_ON_CHANGE = 0.1
const MAX_SQL_LENGTH = 512
const MAX_QUERY_LENGTH = 256
const MAX_SOUND_LENGTH = 128
const MAX_SQL_PLAYER_LENGTH = 64
const MAX_SQL_RANK_LENGTH = CRXRANKS_MAX_RANK_LENGTH * 2
const MAX_TEAM_LENGTH = 10
const TASK_HUD = 304500

#if !defined MAX_NAME_LENGTH
const MAX_NAME_LENGTH = 32
#endif

#if !defined MAX_PLAYERS
const MAX_PLAYERS = 32
#endif

new const ARG_CURRENT_XP[]          = "$current_xp$"
new const ARG_NEXT_XP[]             = "$next_xp$"
new const ARG_XP_NEEDED[]           = "$xp_needed$"
new const ARG_LEVEL[]               = "$level$"
new const ARG_NEXT_LEVEL[]          = "$next_level$"
new const ARG_RANK[]                = "$rank$"
new const ARG_NEXT_RANK[]           = "$next_rank$"
new const ARG_MAX_LEVELS[]          = "$max_levels$"
new const ARG_LINE_BREAK[]          = "$br$"
new const ARG_NAME[]                = "$name$"

new const XPREWARD_KILL[]           = "kill"
new const XPREWARD_HEADSHOT[]       = "headshot"
new const XPREWARD_TEAMKILL[]       = "teamkill"
new const XPREWARD_SUICIDE[]        = "suicide"
new const XPREWARD_DEATH[]          = "death"

new const XPREWARD_BOMB_PLANTED[]   = "bomb_planted"
new const XPREWARD_BOMB_DEFUSED[]   = "bomb_defused"
new const XPREWARD_BOMB_EXPLODED[]  = "bomb_exploded"

new const XPREWARD_TEAM_WIN[]       = "team_win"
new const XPREWARD_TEAM_LOSE[]      = "team_lose"
new const XPREWARD_TEAM_WIN_CT[]    = "team_win_ct"
new const XPREWARD_TEAM_WIN_T[]     = "team_win_t"
new const XPREWARD_TEAM_LOSE_CT[]   = "team_lose_ct"
new const XPREWARD_TEAM_LOSE_T[]    = "team_lose_t"

#define clr(%1) %1 == -1 ? random(256) : %1

#define HUDINFO_PARAMS clr(g_eSettings[HUDINFO_COLOR][0]), clr(g_eSettings[HUDINFO_COLOR][1]), clr(g_eSettings[HUDINFO_COLOR][2]),\
g_eSettings[HUDINFO_POSITION][0], g_eSettings[HUDINFO_POSITION][1], 0, 0.1, 1.0, 0.1, 0.1

#define HUDINFO_PARAMS_DEAD clr(g_eSettings[HUDINFO_COLOR][0]), clr(g_eSettings[HUDINFO_COLOR][1]), clr(g_eSettings[HUDINFO_COLOR][2]),\
g_eSettings[HUDINFO_POSITION_DEAD][0], g_eSettings[HUDINFO_POSITION_DEAD][1], 0, 0.1, 1.0, 0.1, 0.1

#define XP_NOTIFIER_PARAMS_GET clr(g_eSettings[XP_NOTIFIER_COLOR_GET][0]), clr(g_eSettings[XP_NOTIFIER_COLOR_GET][1]), clr(g_eSettings[XP_NOTIFIER_COLOR_GET][2]),\
g_eSettings[XP_NOTIFIER_POSITION][0], g_eSettings[XP_NOTIFIER_POSITION][1], .holdtime = g_eSettings[XP_NOTIFIER_DURATION]

#define XP_NOTIFIER_PARAMS_LOSE clr(g_eSettings[XP_NOTIFIER_COLOR_LOSE][0]), clr(g_eSettings[XP_NOTIFIER_COLOR_LOSE][1]), clr(g_eSettings[XP_NOTIFIER_COLOR_LOSE][2]),\
g_eSettings[XP_NOTIFIER_POSITION][0], g_eSettings[XP_NOTIFIER_POSITION][1], .holdtime = g_eSettings[XP_NOTIFIER_DURATION]

enum _:SaveLoad
{
	SL_SAVE_DATA,
	SL_LOAD_DATA
}

enum _:Objects
{
	OBJ_HUDINFO,
	OBJ_XP_NOTIFIER
}

enum _:SaveTypes
{
	SAVE_NICKNAME,
	SAVE_IP,
	SAVE_STEAMID
}

enum _:SaveInterval
{
	SAVE_ON_DISCONNECT,
	SAVE_ON_DEATH,
	SAVE_ON_ROUND_END,
	SAVE_ON_XP_CHANGE
}

enum _:SaveMethods
{
	SAVE_NVAULT,
	SAVE_MYSQL
}

enum _:HUDInfoVisibility
{
	VIS_ALL_PLAYERS,
	VIS_ONLY_ALIVE,
	VIS_ONLY_DEAD,
	VIS_DEAD_FREEZE_TIME
}

enum _:Sections
{
	SECTION_NONE,
	SECTION_SETTINGS,
	SECTION_RANKS,
	SECTION_XP_REWARDS
}

enum _:PlayerData
{
	XP,
	Level,
	NextXP,
	Rank[CRXRANKS_MAX_RANK_LENGTH],
	NextRank[CRXRANKS_MAX_RANK_LENGTH],
	HUDInfo[CRXRANKS_MAX_HUDINFO_LENGTH],
	SaveInfo[CRXRANKS_MAX_PLAYER_INFO_LENGTH],
	bool:HudInfoEnabled,
	bool:IsOnFinalLevel,
	bool:IsVIP,
	bool:IsBot
}

enum _:Settings
{
	SAVE_TYPE,
	SAVE_INTERVAL,
	bool:USE_MYSQL,
	SQL_HOST[MAX_NAME_LENGTH],
	SQL_USER[MAX_NAME_LENGTH],
	SQL_PASSWORD[MAX_NAME_LENGTH],
	SQL_DATABASE[MAX_NAME_LENGTH],
	SQL_TABLE[MAX_NAME_LENGTH],
	LEVELUP_MESSAGE_TYPE,
	LEVELUP_SOUND[MAX_SOUND_LENGTH],
	bool:LEVELUP_SCREEN_FADE_ENABLED,
	LEVELUP_SCREEN_FADE_COLOR[4],
	LEVELDN_SOUND[MAX_SOUND_LENGTH],
	bool:LEVELDN_SCREEN_FADE_ENABLED,
	LEVELDN_SCREEN_FADE_COLOR[4],
	FINAL_LEVEL_FLAGS[MAX_NAME_LENGTH],
	FINAL_LEVEL_FLAGS_BIT,
	VIP_FLAGS[MAX_NAME_LENGTH],
	VIP_FLAGS_BIT,
	VAULT_NAME[MAX_NAME_LENGTH],
	TEAM_LOCK,
	MINIMUM_PLAYERS,
	bool:IGNORE_BOTS,
	bool:USE_COMBINED_EVENTS,
	bool:NOTIFY_ON_KILL,
	bool:HUDINFO_ENABLED,
	HUDINFO_VISIBILITY,
	bool:HUDINFO_TEAM_LOCK,
	bool:HUDINFO_OTHER_PLAYERS,
	HUDINFO_COLOR[3],
	Float:HUDINFO_POSITION[2],
	Float:HUDINFO_POSITION_DEAD[2],
	bool:HUDINFO_USE_DHUD,
	HUDINFO_FORMAT[CRXRANKS_MAX_HUDINFO_LENGTH],
	HUDINFO_FORMAT_FINAL[CRXRANKS_MAX_HUDINFO_LENGTH],
	HUDINFO_INVALID_TEXT[MAX_NAME_LENGTH],
	bool:XP_NOTIFIER_ENABLED,
	XP_NOTIFIER_COLOR_GET[3],
	XP_NOTIFIER_COLOR_LOSE[3],
	Float:XP_NOTIFIER_POSITION[2],
	Float:XP_NOTIFIER_DURATION,
	bool:XP_NOTIFIER_USE_DHUD
}

new g_eSettings[Settings]
new g_ePlayerData[MAX_PLAYERS + 1][PlayerData]
new g_szMaxLevels[CRXRANKS_MAX_XP_LENGTH]
new g_szSqlError[MAX_SQL_LENGTH]
new Handle:g_iSqlTuple
new Array:g_aLevels
new Array:g_aRankNames
new Trie:g_tSettings
new Trie:g_tXPRewards
new Trie:g_tXPRewardsVIP
new bool:g_bIsCstrike
new bool:g_bFreezeTime

new g_iVault
new g_iMaxLevels
new g_iFlagZ
new g_iScreenFade
new g_iObject[2]

new g_fwdUserLevelUpdated
new g_fwdUserReceiveXP
new g_fwdUserXPUpdated
new g_fwdUserNameChanged

// !!!
public amxbans_admin_connect(id)
{
	if(g_ePlayerData[id][Level] == g_iMaxLevels && g_eSettings[FINAL_LEVEL_FLAGS])
	{
		set_user_flags(id, g_eSettings[FINAL_LEVEL_FLAGS_BIT])
		remove_user_flags(id, g_iFlagZ)
	}
}

public plugin_init()
{
	register_plugin("OciXCrom's Rank System", PLUGIN_VERSION, "OciXCrom")
	register_cvar("CRXRankSystem", PLUGIN_VERSION, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED)

	register_dictionary("RankSystem.txt")

	register_event("DeathMsg", "OnPlayerKilled", "a")
	register_event("SayText", "OnSayText", "a", "2=#Cstrike_Name_Change")

	if(g_eSettings[HUDINFO_VISIBILITY] == VIS_DEAD_FREEZE_TIME)
	{
		register_event("HLTV", "OnFreezeTimeStart", "a", "1=0", "2=0")
		register_logevent("OnRoundStart", 2, "1=Round_Start")
	}

	if(g_eSettings[SAVE_INTERVAL] == SAVE_ON_ROUND_END)
	{
		register_logevent("OnRoundEnd", 2, "1=Round_End")
	}

	if(g_bIsCstrike)
	{
		register_event("SendAudio", "OnTeamWin", "a", "2&%!MRAD_terwin", "2&%!MRAD_ctwin")
	}

	register_clcmd("say /xplist",            "Cmd_XPList",      ADMIN_BAN)
	register_clcmd("say_team /xplist",       "Cmd_XPList",      ADMIN_BAN)
	register_clcmd("say /hudinfo",           "Cmd_HudInfo",     ADMIN_ALL)
	register_clcmd("say_team /hudinfo",      "Cmd_HudInfo",     ADMIN_ALL)
	register_concmd("crxranks_give_xp",      "Cmd_GiveXP",      ADMIN_RCON, "<nick|#userid> <amount>")
	register_concmd("crxranks_reset_xp",     "Cmd_ResetXP",     ADMIN_RCON, "<nick|#userid>")

	if(g_eSettings[LEVELUP_SCREEN_FADE_ENABLED] || g_eSettings[LEVELDN_SCREEN_FADE_ENABLED])
	{
		g_iScreenFade = get_user_msgid("ScreenFade")
	}

	g_fwdUserLevelUpdated = CreateMultiForward("crxranks_user_level_updated", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL)
	g_fwdUserReceiveXP    = CreateMultiForward("crxranks_user_receive_xp",    ET_STOP,   FP_CELL, FP_CELL, FP_CELL)
	g_fwdUserXPUpdated    = CreateMultiForward("crxranks_user_xp_updated",    ET_IGNORE, FP_CELL, FP_CELL, FP_CELL)

	if(g_eSettings[USE_MYSQL])
	{
		g_iSqlTuple = SQL_MakeDbTuple(g_eSettings[SQL_HOST], g_eSettings[SQL_USER], g_eSettings[SQL_PASSWORD], g_eSettings[SQL_DATABASE])

		new iErrorCode, Handle:iSqlConnection = SQL_Connect(g_iSqlTuple, iErrorCode, g_szSqlError, charsmax(g_szSqlError))

		if(iSqlConnection == Empty_Handle)
		{
			log_amx(g_szSqlError)
			log_amx("%L", LANG_SERVER, "CRXRANKS_MYSQL_FAILED")
			g_eSettings[USE_MYSQL] = false
		}
		else
		{
			SQL_FreeHandle(iSqlConnection)
		}

		new szQuery[MAX_QUERY_LENGTH]

		formatex(szQuery, charsmax(szQuery), "CREATE TABLE IF NOT EXISTS `%s` (`Player` VARCHAR(%i) NOT NULL, `XP` INT(%i) NOT NULL, `Level` INT(%i) NOT NULL,\
		`Next XP` INT(%i) NOT NULL, `Rank` VARCHAR(%i) NOT NULL, `Next Rank` VARCHAR(%i) NOT NULL, PRIMARY KEY(Player));",\
		g_eSettings[SQL_TABLE], MAX_SQL_PLAYER_LENGTH, CRXRANKS_MAX_XP_LENGTH, CRXRANKS_MAX_XP_LENGTH, CRXRANKS_MAX_XP_LENGTH,\
		MAX_SQL_RANK_LENGTH, MAX_SQL_RANK_LENGTH)

		SQL_ThreadQuery(g_iSqlTuple, "QueryHandler", szQuery)
	}

	if(!g_eSettings[USE_MYSQL])
	{
		g_iVault = nvault_open(g_eSettings[VAULT_NAME])
	}
}

public plugin_precache()
{
	new szModname[MAX_NAME_LENGTH]
	get_modname(szModname, charsmax(szModname))

	if(equal(szModname, "cstrike") || equal(szModname, "czero"))
	{
		g_bIsCstrike = true
	}

	g_aLevels = ArrayCreate(1)
	ArrayPushCell(g_aLevels, 0)

	g_aRankNames = ArrayCreate(MAX_NAME_LENGTH)
	ArrayPushString(g_aRankNames, "")

	g_tSettings = TrieCreate()
	g_tXPRewards = TrieCreate()
	g_tXPRewardsVIP = TrieCreate()

	ReadFile()
}

public plugin_cfg()
{
	if(g_eSettings[HUDINFO_VISIBILITY] == VIS_DEAD_FREEZE_TIME && get_cvar_num("mp_freezetime"))
	{
		g_bFreezeTime = true
	}
}

public plugin_end()
{
	ArrayDestroy(g_aLevels)
	ArrayDestroy(g_aRankNames)
	TrieDestroy(g_tSettings)
	TrieDestroy(g_tXPRewards)
	TrieDestroy(g_tXPRewardsVIP)
	DestroyForward(g_fwdUserLevelUpdated)

	if(g_eSettings[USE_MYSQL])
	{
		SQL_FreeHandle(g_iSqlTuple)
	}
	else
	{
		nvault_close(g_iVault)
	}
}

ReadFile()
{
	new szFilename[256]
	get_configsdir(szFilename, charsmax(szFilename))
	add(szFilename, charsmax(szFilename), "/RankSystem.ini")

	new iFilePointer = fopen(szFilename, "rt")

	if(iFilePointer)
	{
		new szData[CRXRANKS_MAX_HUDINFO_LENGTH + MAX_NAME_LENGTH], szValue[CRXRANKS_MAX_HUDINFO_LENGTH], szMap[MAX_NAME_LENGTH], szKey[MAX_NAME_LENGTH]
		new szTemp[4][5], bool:bRead = true, bool:bHasDeadPosition, i, iSize, iSection = SECTION_NONE
		get_mapname(szMap, charsmax(szMap))

		while(!feof(iFilePointer))
		{
			fgets(iFilePointer, szData, charsmax(szData))
			trim(szData)

			switch(szData[0])
			{
				case EOS, '#', ';': continue
				case '-':
				{
					iSize = strlen(szData)

					if(szData[iSize - 1] == '-')
					{
						szData[0] = ' '
						szData[iSize - 1] = ' '
						trim(szData)

						if(contain(szData, "*") != -1)
						{
							strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '*')
							copy(szValue, strlen(szKey), szMap)
							bRead = equal(szValue, szKey) ? true : false
						}
						else
						{
							static const szAll[] = "#all"
							bRead = equal(szData, szAll) || equali(szData, szMap)
						}
					}
					else continue
				}
				case '[':
				{
					iSize = strlen(szData)

					if(szData[iSize - 1] == ']')
					{
						switch(szData[1])
						{
							case 'S', 's': iSection = SECTION_SETTINGS
							case 'R', 'r': iSection = SECTION_RANKS
							case 'X', 'x': iSection = SECTION_XP_REWARDS
							default: iSection = SECTION_NONE
						}
					}
					else continue
				}
				default:
				{
					if(!bRead || iSection == SECTION_NONE)
					{
						continue
					}

					strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=')
					trim(szKey); trim(szValue)

					switch(iSection)
					{
						case SECTION_SETTINGS:
						{
							TrieSetString(g_tSettings, szKey, szValue)

							if(equal(szKey, "CHAT_PREFIX"))
							{
								if(g_bIsCstrike)
								{
									CC_SetPrefix(szValue)
								}
								else
								{
									copy(CC_PREFIX, charsmax(CC_PREFIX), szValue)
								}
							}
							else if(equal(szKey, "SAVE_TYPE"))
							{
								g_eSettings[SAVE_TYPE] = clamp(str_to_num(szValue), SAVE_NICKNAME, SAVE_STEAMID)
							}
							else if(equal(szKey, "SAVE_INTERVAL"))
							{
								g_eSettings[SAVE_INTERVAL] = clamp(str_to_num(szValue), SAVE_ON_DISCONNECT, SAVE_ON_XP_CHANGE)
							}
							else if(equal(szKey, "USE_MYSQL"))
							{
								g_eSettings[USE_MYSQL] = _:clamp(str_to_num(szValue), false, true)
							}
							else if(equal(szKey, "SQL_HOST"))
							{
								copy(g_eSettings[SQL_HOST], charsmax(g_eSettings[SQL_HOST]), szValue)
							}
							else if(equal(szKey, "SQL_USER"))
							{
								copy(g_eSettings[SQL_USER], charsmax(g_eSettings[SQL_USER]), szValue)
							}
							else if(equal(szKey, "SQL_PASSWORD"))
							{
								copy(g_eSettings[SQL_PASSWORD], charsmax(g_eSettings[SQL_PASSWORD]), szValue)
							}
							else if(equal(szKey, "SQL_DATABASE"))
							{
								copy(g_eSettings[SQL_DATABASE], charsmax(g_eSettings[SQL_DATABASE]), szValue)
							}
							else if(equal(szKey, "SQL_TABLE"))
							{
								copy(g_eSettings[SQL_TABLE], charsmax(g_eSettings[SQL_TABLE]), szValue)
							}
							else if(equal(szKey, "XP_COMMANDS"))
							{
								while(szValue[0] != 0 && strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ','))
								{
									trim(szKey); trim(szValue)
									register_clcmd(szKey, "Cmd_XP")
								}
							}
							else if(equal(szKey, "LEVELUP_MESSAGE_TYPE"))
							{
								g_eSettings[LEVELUP_MESSAGE_TYPE] = clamp(str_to_num(szValue), 0, 2)
							}
							else if(equal(szKey, "LEVELUP_SOUND"))
							{
								copy(g_eSettings[LEVELUP_SOUND], charsmax(g_eSettings[LEVELUP_SOUND]), szValue)

								if(szValue[0])
								{
									precache_sound_if_found(szValue)
								}
							}
							else if(equal(szKey, "LEVELUP_SCREEN_FADE_ENABLED"))
							{
								g_eSettings[LEVELUP_SCREEN_FADE_ENABLED] = _:clamp(str_to_num(szValue), false, true)
							}
							else if(equal(szKey, "LEVELUP_SCREEN_FADE_COLOR"))
							{
								parse(szValue, szTemp[0], charsmax(szTemp[]), szTemp[1], charsmax(szTemp[]), szTemp[2], charsmax(szTemp[]), szTemp[3], charsmax(szTemp[]))

								for(i = 0; i < 4; i++)
								{
									g_eSettings[LEVELUP_SCREEN_FADE_COLOR][i] = clamp(str_to_num(szTemp[i]), -1, 255)
								}
							}
							else if(equal(szKey, "LEVELDN_SOUND"))
							{
								copy(g_eSettings[LEVELDN_SOUND], charsmax(g_eSettings[LEVELDN_SOUND]), szValue)

								if(szValue[0])
								{
									precache_sound_if_found(szValue)
								}
							}
							else if(equal(szKey, "LEVELDN_SCREEN_FADE_ENABLED"))
							{
								g_eSettings[LEVELDN_SCREEN_FADE_ENABLED] = _:clamp(str_to_num(szValue), false, true)
							}
							else if(equal(szKey, "LEVELDN_SCREEN_FADE_COLOR"))
							{
								parse(szValue, szTemp[0], charsmax(szTemp[]), szTemp[1], charsmax(szTemp[]), szTemp[2], charsmax(szTemp[]), szTemp[3], charsmax(szTemp[]))

								for(i = 0; i < 4; i++)
								{
									g_eSettings[LEVELDN_SCREEN_FADE_COLOR][i] = clamp(str_to_num(szTemp[i]), -1, 255)
								}
							}
							else if(equal(szKey, "FINAL_LEVEL_FLAGS"))
							{
								copy(g_eSettings[FINAL_LEVEL_FLAGS], charsmax(g_eSettings[FINAL_LEVEL_FLAGS]), szValue)
								g_eSettings[FINAL_LEVEL_FLAGS_BIT] = read_flags(szValue)
								g_iFlagZ = read_flags("z")
							}
							else if(equal(szKey, "VIP_FLAGS"))
							{
								copy(g_eSettings[VIP_FLAGS], charsmax(g_eSettings[VIP_FLAGS]), szValue)
								g_eSettings[VIP_FLAGS_BIT] = read_flags(szValue)
							}
							else if(equal(szKey, "VAULT_NAME"))
							{
								copy(g_eSettings[VAULT_NAME], charsmax(g_eSettings[VAULT_NAME]), szValue)
							}
							else if(equal(szKey, "TEAM_LOCK"))
							{
								g_eSettings[TEAM_LOCK] = str_to_num(szValue)
							}
							else if(equal(szKey, "MINIMUM_PLAYERS"))
							{
								g_eSettings[MINIMUM_PLAYERS] = clamp(str_to_num(szValue), 0, 32)
							}
							else if(equal(szKey, "IGNORE_BOTS"))
							{
								g_eSettings[IGNORE_BOTS] = _:clamp(str_to_num(szValue), false, true)
							}
							else if(equal(szKey, "USE_COMBINED_EVENTS"))
							{
								g_eSettings[USE_COMBINED_EVENTS] = _:clamp(str_to_num(szValue), false, true)
							}
							else if(equal(szKey, "NOTIFY_ON_KILL"))
							{
								g_eSettings[NOTIFY_ON_KILL] = _:clamp(str_to_num(szValue), false, true)
							}
							else if(equal(szKey, "HUDINFO_ENABLED"))
							{
								g_eSettings[HUDINFO_ENABLED] = _:clamp(str_to_num(szValue), false, true)
							}
							else if(equal(szKey, "HUDINFO_VISIBILITY") || equal(szKey, "HUDINFO_ALIVE_ONLY") /* changed in v3.9 */ )
							{
								g_eSettings[HUDINFO_VISIBILITY] = clamp(str_to_num(szValue), VIS_ALL_PLAYERS, VIS_DEAD_FREEZE_TIME)
							}
							else if(equal(szKey, "HUDINFO_TEAM_LOCK"))
							{
								g_eSettings[HUDINFO_TEAM_LOCK] = _:clamp(str_to_num(szValue), false, true)
							}
							else if(equal(szKey, "HUDINFO_OTHER_PLAYERS"))
							{
								g_eSettings[HUDINFO_OTHER_PLAYERS] = _:clamp(str_to_num(szValue), false, true)
							}
							else if(equal(szKey, "HUDINFO_COLOR"))
							{
								parse(szValue, szTemp[0], charsmax(szTemp[]), szTemp[1], charsmax(szTemp[]), szTemp[2], charsmax(szTemp[]))

								for(i = 0; i < 3; i++)
								{
									g_eSettings[HUDINFO_COLOR][i] = clamp(str_to_num(szTemp[i]), -1, 255)
								}
							}
							else if(equal(szKey, "HUDINFO_POSITION"))
							{
								parse(szValue, szTemp[0], charsmax(szTemp[]), szTemp[1], charsmax(szTemp[]))

								for(i = 0; i < 2; i++)
								{
									g_eSettings[HUDINFO_POSITION][i] = _:floatclamp(str_to_float(szTemp[i]), -1.0, 1.0)
								}
							}
							else if(equal(szKey, "HUDINFO_POSITION_DEAD"))
							{
								bHasDeadPosition = true
								parse(szValue, szTemp[0], charsmax(szTemp[]), szTemp[1], charsmax(szTemp[]))

								for(i = 0; i < 2; i++)
								{
									g_eSettings[HUDINFO_POSITION_DEAD][i] = _:floatclamp(str_to_float(szTemp[i]), -1.0, 1.0)
								}
							}
							else if(equal(szKey, "HUDINFO_USE_DHUD"))
							{
								g_eSettings[HUDINFO_USE_DHUD] = _:clamp(str_to_num(szValue), false, true)

								if(!g_eSettings[HUDINFO_USE_DHUD])
								{
									g_iObject[OBJ_HUDINFO] = CreateHudSyncObj()
								}
							}
							else if(equal(szKey, "HUDINFO_FORMAT"))
							{
								copy(g_eSettings[HUDINFO_FORMAT], charsmax(g_eSettings[HUDINFO_FORMAT]), szValue)
							}
							else if(equal(szKey, "HUDINFO_FORMAT_FINAL"))
							{
								copy(g_eSettings[HUDINFO_FORMAT_FINAL], charsmax(g_eSettings[HUDINFO_FORMAT_FINAL]), szValue)
							}
							else if(equal(szKey, "HUDINFO_INVALID_TEXT"))
							{
								copy(g_eSettings[HUDINFO_INVALID_TEXT], charsmax(g_eSettings[HUDINFO_INVALID_TEXT]), szValue)
							}
							else if(equal(szKey, "XP_NOTIFIER_ENABLED"))
							{
								g_eSettings[XP_NOTIFIER_ENABLED] = _:clamp(str_to_num(szValue), false, true)
							}
							else if(equal(szKey, "XP_NOTIFIER_COLOR_GET"))
							{
								parse(szValue, szTemp[0], charsmax(szTemp[]), szTemp[1], charsmax(szTemp[]), szTemp[2], charsmax(szTemp[]))

								for(i = 0; i < 3; i++)
								{
									g_eSettings[XP_NOTIFIER_COLOR_GET][i] = clamp(str_to_num(szTemp[i]), -1, 255)
								}
							}
							else if(equal(szKey, "XP_NOTIFIER_COLOR_LOSE"))
							{
								parse(szValue, szTemp[0], charsmax(szTemp[]), szTemp[1], charsmax(szTemp[]), szTemp[2], charsmax(szTemp[]))

								for(i = 0; i < 3; i++)
								{
									g_eSettings[XP_NOTIFIER_COLOR_LOSE][i] = clamp(str_to_num(szTemp[i]), -1, 255)
								}
							}
							else if(equal(szKey, "XP_NOTIFIER_POSITION"))
							{
								parse(szValue, szTemp[0], charsmax(szTemp[]), szTemp[1], charsmax(szTemp[]))

								for(i = 0; i < 2; i++)
								{
									g_eSettings[XP_NOTIFIER_POSITION][i] = _:floatclamp(str_to_float(szTemp[i]), -1.0, 1.0)
								}
							}
							else if(equal(szKey, "XP_NOTIFIER_DURATION"))
							{
								g_eSettings[XP_NOTIFIER_DURATION] = _:floatclamp(str_to_float(szValue), 0.0, float(cellmax))
							}
							else if(equal(szKey, "XP_NOTIFIER_USE_DHUD"))
							{
								g_eSettings[XP_NOTIFIER_USE_DHUD] = _:clamp(str_to_num(szValue), false, true)

								if(!g_eSettings[XP_NOTIFIER_USE_DHUD])
								{
									g_iObject[OBJ_XP_NOTIFIER] = CreateHudSyncObj()
								}
							}
						}
						case SECTION_RANKS:
						{
							ArrayPushCell(g_aLevels, g_iMaxLevels == 0 ? 0 : max(str_to_num(szValue), 0))
							ArrayPushString(g_aRankNames, szKey)
							g_iMaxLevels++
						}
						case SECTION_XP_REWARDS:
						{
							static szReward[2][16]
							szReward[1][0] = EOS

							parse(szValue, szReward[0], charsmax(szReward[]), szReward[1], charsmax(szReward[]))
							TrieSetCell(g_tXPRewards, szKey, str_to_num(szReward[0]))

							if(szReward[1][0])
							{
								TrieSetCell(g_tXPRewardsVIP, szKey, str_to_num(szReward[1]))
							}
						}
					}
				}
			}
		}

		if(!bHasDeadPosition)
		{
			for(i = 0; i < 2; i++)
			{
				g_eSettings[HUDINFO_POSITION_DEAD][i] = _:g_eSettings[HUDINFO_POSITION][i]
			}
		}

		num_to_str(g_iMaxLevels, g_szMaxLevels, charsmax(g_szMaxLevels))
		fclose(iFilePointer)
	}
}

public client_connect(id)
{
	reset_player_stats(id)

	switch(g_eSettings[SAVE_TYPE])
	{
		case SAVE_NICKNAME: get_user_name(id, g_ePlayerData[id][SaveInfo], charsmax(g_ePlayerData[][SaveInfo]))
		case SAVE_IP:       get_user_ip(id, g_ePlayerData[id][SaveInfo], charsmax(g_ePlayerData[][SaveInfo]), 1)
		case SAVE_STEAMID:  get_user_authid(id, g_ePlayerData[id][SaveInfo], charsmax(g_ePlayerData[][SaveInfo]))
	}

	save_or_load(id, g_ePlayerData[id][SaveInfo], SL_LOAD_DATA)

	g_ePlayerData[id][IsBot] = is_user_bot(id) != 0
	set_task(DELAY_ON_CONNECT, "update_vip_status", id)

	if(g_eSettings[HUDINFO_ENABLED])
	{
		set_task(HUD_REFRESH_FREQ, "DisplayHUD", id + TASK_HUD, .flags = "b")
	}
}

public client_disconnected(id)
{
	if(g_eSettings[SAVE_INTERVAL] != SAVE_ON_XP_CHANGE)
	{
		save_or_load(id, g_ePlayerData[id][SaveInfo], SL_SAVE_DATA)
	}

	remove_task(id + TASK_HUD)
}

public OnSayText(iMsg, iDestination, iEntity)
{
	g_fwdUserNameChanged = register_forward(FM_ClientUserInfoChanged, "OnNameChange", 1)
}

public OnNameChange(id)
{
	if(!is_user_connected(id))
	{
		return
	}

	new szName[MAX_NAME_LENGTH]
	get_user_name(id, szName, charsmax(szName))

	if(g_eSettings[SAVE_TYPE] == SAVE_NICKNAME)
	{
		save_or_load(id, g_ePlayerData[id][SaveInfo], SL_SAVE_DATA)
		copy(g_ePlayerData[id][SaveInfo], charsmax(g_ePlayerData[][SaveInfo]), szName)

		if(g_eSettings[USE_MYSQL])
		{
			reset_player_stats(id)
		}

		save_or_load(id, szName, SL_LOAD_DATA)
		update_hudinfo(id)
	}

	update_vip_status(id)
	unregister_forward(FM_ClientUserInfoChanged, g_fwdUserNameChanged, 1)
}

public DisplayHUD(id)
{
	id -= TASK_HUD

	if(!g_ePlayerData[id][HudInfoEnabled])
	{
		return
	}

	new bool:bIsAlive, iTarget

	bIsAlive = is_user_alive(id) != 0
	iTarget = id

	if(bIsAlive)
	{
		switch(g_eSettings[HUDINFO_VISIBILITY])
		{
			case VIS_ONLY_DEAD: return
			case VIS_DEAD_FREEZE_TIME:
			{
				if(!g_bFreezeTime)
				{
					return
				}
			}
		}
	}
	else
	{
		if(g_eSettings[HUDINFO_VISIBILITY] == VIS_ONLY_ALIVE)
		{
			return
		}

		if(g_eSettings[HUDINFO_OTHER_PLAYERS])
		{
			iTarget = pev(id, pev_iuser2)
		}
	}

	if(!iTarget)
	{
		return
	}

	if(g_eSettings[TEAM_LOCK] && g_eSettings[HUDINFO_TEAM_LOCK] && get_user_team(iTarget) != g_eSettings[TEAM_LOCK])
	{
		return
	}

	if(g_eSettings[HUDINFO_USE_DHUD])
	{
		if(bIsAlive)
		{
			set_dhudmessage(HUDINFO_PARAMS)
		}
		else
		{
			set_dhudmessage(HUDINFO_PARAMS_DEAD)
		}

		show_dhudmessage(id, g_ePlayerData[iTarget][HUDInfo])
	}
	else
	{
		if(bIsAlive)
		{
			set_hudmessage(HUDINFO_PARAMS)
		}
		else
		{
			set_hudmessage(HUDINFO_PARAMS_DEAD)
		}

		ShowSyncHudMsg(id, g_iObject[OBJ_HUDINFO], g_ePlayerData[iTarget][HUDInfo])
	}
}

public bomb_planted(id)
{
	give_user_xp(id, get_xp_reward(id, XPREWARD_BOMB_PLANTED), CRXRANKS_XPS_REWARD)
}

public bomb_defused(id)
{
	give_user_xp(id, get_xp_reward(id, XPREWARD_BOMB_DEFUSED), CRXRANKS_XPS_REWARD)
}

public bomb_explode(id)
{
	give_user_xp(id, get_xp_reward(id, XPREWARD_BOMB_EXPLODED), CRXRANKS_XPS_REWARD)
}

public Cmd_XP(id)
{
	if(g_ePlayerData[id][Level] == g_iMaxLevels)
	{
		CC_SendMessage(id, "%L", id, "CRXRANKS_RANKINFO_FINAL", g_ePlayerData[id][XP], g_ePlayerData[id][Level], g_ePlayerData[id][Rank])
	}
	else
	{
		CC_SendMessage(id, "%L", id, "CRXRANKS_RANKINFO_NORMAL", g_ePlayerData[id][XP], g_ePlayerData[id][NextXP],\
		g_ePlayerData[id][Level], g_ePlayerData[id][Rank], g_ePlayerData[id][NextRank])
	}

	return PLUGIN_HANDLED
}

public Cmd_XPList(id, iLevel, iCid)
{
	if(!cmd_access(id, iLevel, iCid, 1))
	{
		return PLUGIN_HANDLED
	}

	new szTitle[128]
	formatex(szTitle, charsmax(szTitle), "%L", id, "CRXRANKS_MENU_TITLE")

	new iPlayers[MAX_PLAYERS], iPnum, iMenu = menu_create(szTitle, "XPList_Handler")
	get_players(iPlayers, iPnum); SortCustom1D(iPlayers, iPnum, "sort_players_by_xp")

	for(new szItem[128], szName[MAX_NAME_LENGTH], iPlayer, i; i < iPnum; i++)
	{
		iPlayer = iPlayers[i]
		get_user_name(iPlayer, szName, charsmax(szName))
		formatex(szItem, charsmax(szItem), "%L", id, "CRXRANKS_ITEM_FORMAT", g_ePlayerData[iPlayer][XP], szName, g_ePlayerData[iPlayer][Level], g_ePlayerData[iPlayer][Rank])
		menu_additem(iMenu, szItem)
	}

	menu_display(id, iMenu)
	return PLUGIN_HANDLED
}

public Cmd_HudInfo(id, iLevel, iCid)
{
	if(!cmd_access(id, iLevel, iCid, 1))
	{
		return PLUGIN_HANDLED
	}

	if(!g_eSettings[HUDINFO_ENABLED])
	{
		CC_SendMessage(id, "%L", id, "CRXRANKS_HUDINFO_UNAVAILABLE")
		return PLUGIN_HANDLED
	}

	g_ePlayerData[id][HudInfoEnabled] = !g_ePlayerData[id][HudInfoEnabled]
	CC_SendMessage(id, "%L", id, g_ePlayerData[id][HudInfoEnabled] ? "CRXRANKS_HUDINFO_ENABLED" : "CRXRANKS_HUDINFO_DISABLED")
	return PLUGIN_HANDLED
}

public XPList_Handler(id, iMenu, iItem)
{
	menu_destroy(iMenu)
	return PLUGIN_HANDLED
}

public Cmd_GiveXP(id, iLevel, iCid)
{
	if(!cmd_access(id, iLevel, iCid, 3))
	{
		return PLUGIN_HANDLED
	}

	new szPlayer[MAX_NAME_LENGTH]
	read_argv(1, szPlayer, charsmax(szPlayer))

	new iPlayer = cmd_target(id, szPlayer, 0)

	if(!iPlayer)
	{
		return PLUGIN_HANDLED
	}

	new szName[2][MAX_NAME_LENGTH], szAmount[CRXRANKS_MAX_XP_LENGTH]
	read_argv(2, szAmount, charsmax(szAmount))
	get_user_name(id, szName[0], charsmax(szName[]))
	get_user_name(iPlayer, szName[1], charsmax(szName[]))

	new szKey[MAX_NAME_LENGTH], iXP = str_to_num(szAmount)
	give_user_xp(iPlayer, iXP, CRXRANKS_XPS_ADMIN)

	if(iXP >= 0)
	{
		copy(szKey, charsmax(szKey), "CRXRANKS_GIVE_XP")
	}
	else
	{
		copy(szKey, charsmax(szKey), "CRXRANKS_TAKE_XP")
		iXP *= -1
	}

	CC_LogMessage(0, _, "%L", id, szKey, szName[0], iXP, szName[1])
	return PLUGIN_HANDLED
}

public Cmd_ResetXP(id, iLevel, iCid)
{
	if(!cmd_access(id, iLevel, iCid, 2))
	{
		return PLUGIN_HANDLED
	}

	new szPlayer[MAX_NAME_LENGTH]
	read_argv(1, szPlayer, charsmax(szPlayer))

	new iPlayer = cmd_target(id, szPlayer, CMDTARGET_OBEY_IMMUNITY|CMDTARGET_ALLOW_SELF)

	if(!iPlayer)
	{
		return PLUGIN_HANDLED
	}

	new szName[2][MAX_NAME_LENGTH]
	get_user_name(id, szName[0], charsmax(szName[]))
	get_user_name(iPlayer, szName[1], charsmax(szName[]))

	g_ePlayerData[iPlayer][XP] = 0
	check_level(iPlayer, true)
	CC_LogMessage(0, _, "%L", id, "CRXRANKS_RESET_XP", szName[0], szName[1])

	if(g_eSettings[SAVE_INTERVAL] == SAVE_ON_XP_CHANGE)
	{
		save_or_load(iPlayer, g_ePlayerData[iPlayer][SaveInfo], SL_SAVE_DATA)
	}

	return PLUGIN_HANDLED
}

public OnFreezeTimeStart()
{
	g_bFreezeTime = true
}

public OnRoundStart()
{
	g_bFreezeTime = false
}

public OnRoundEnd()
{
	new iPlayers[32], iPnum
	get_players(iPlayers, iPnum)

	for(new i, iPlayer; i < iPnum; i++)
	{
		iPlayer = iPlayers[i]
		save_or_load(iPlayer, g_ePlayerData[iPlayer][SaveInfo], SL_SAVE_DATA)
	}
}

public OnTeamWin()
{
	new szTeam[MAX_TEAM_LENGTH], szWinTeam[MAX_TEAM_LENGTH], szLoseTeam[MAX_TEAM_LENGTH]
	read_data(2, szTeam, charsmax(szTeam))
	copy(szWinTeam, charsmax(szWinTeam),   szTeam[7] == 'c' ? "CT" : "TERRORIST")
	copy(szLoseTeam, charsmax(szLoseTeam), szTeam[7] == 'c' ? "TERRORIST" : "CT")

	if(xp_reward_is_set(XPREWARD_TEAM_WIN))
	{
		reward_team(szWinTeam, XPREWARD_TEAM_WIN)
	}

	if(xp_reward_is_set(XPREWARD_TEAM_LOSE))
	{
		reward_team(szLoseTeam, XPREWARD_TEAM_LOSE)
	}

	if(szWinTeam[0] == 'C')
	{
		if(xp_reward_is_set(XPREWARD_TEAM_WIN_CT))
		{
			reward_team(szWinTeam, XPREWARD_TEAM_WIN_CT)
		}

		if(xp_reward_is_set(XPREWARD_TEAM_LOSE_T))
		{
			reward_team(szLoseTeam, XPREWARD_TEAM_LOSE_T)
		}
	}
	else
	{
		if(xp_reward_is_set(XPREWARD_TEAM_WIN_T))
		{
			reward_team(szWinTeam, XPREWARD_TEAM_WIN_T)
		}

		if(xp_reward_is_set(XPREWARD_TEAM_LOSE_CT))
		{
			reward_team(szLoseTeam, XPREWARD_TEAM_LOSE_CT)
		}
	}
}

public OnPlayerKilled()
{
	new szWeapon[16], iAttacker = read_data(1), iVictim = read_data(2), iXP
	read_data(4, szWeapon, charsmax(szWeapon))

	if(!is_user_connected(iVictim))
	{
		return
	}

	if(g_eSettings[SAVE_INTERVAL] == SAVE_ON_DEATH)
	{
		save_or_load(iVictim, g_ePlayerData[iVictim][SaveInfo], SL_SAVE_DATA)
	}

	if(iAttacker == iVictim || equal(szWeapon, "worldspawn") || equal(szWeapon, "door", 4) || equal(szWeapon, "trigger_hurt"))
	{
		iXP = get_xp_reward(iVictim, XPREWARD_SUICIDE)

		if(g_eSettings[USE_COMBINED_EVENTS])
		{
			iXP += get_xp_reward(iVictim, XPREWARD_DEATH)
		}

		give_user_xp(iVictim, iXP, CRXRANKS_XPS_REWARD)

		if(should_send_kill_message(iXP))
		{
			CC_SendMessage(iVictim, "%L", iVictim, iXP > 0 ? "CRXRANKS_NOTIFY_SUICIDE_GET" : "CRXRANKS_NOTIFY_SUICIDE_LOSE", abs(iXP))
		}

		return
	}

	if(!is_user_connected(iAttacker))
	{
		return
	}

	new iReward, iTemp

	if(iAttacker == iVictim)
	{
		iTemp = get_xp_reward(iAttacker, XPREWARD_SUICIDE)
		iReward += iTemp

		if(should_skip(iTemp))
		{
			goto @GIVE_REWARD
		}
	}
	else if(get_user_team(iAttacker) == get_user_team(iVictim))
	{
		iTemp = get_xp_reward(iAttacker, XPREWARD_TEAMKILL)
		iReward += iTemp

		if(should_skip(iTemp))
		{
			goto @GIVE_REWARD
		}
	}
	else
	{
		iTemp = get_xp_reward(iAttacker, szWeapon)
		iReward += iTemp

		if(should_skip(iTemp))
		{
			goto @GIVE_REWARD
		}

		if(read_data(3))
		{
			iTemp = get_xp_reward(iAttacker, XPREWARD_HEADSHOT)
			iReward += iTemp

			if(should_skip(iTemp))
			{
				goto @GIVE_REWARD
			}
		}

		iReward += get_xp_reward(iAttacker, XPREWARD_KILL)
	}

	@GIVE_REWARD:
	iXP = give_user_xp(iAttacker, iReward, CRXRANKS_XPS_REWARD)

	if(should_send_kill_message(iXP))
	{
		new szName[MAX_NAME_LENGTH]
		get_user_name(iVictim, szName, charsmax(szName))
		CC_SendMessage(iAttacker, "%L", iAttacker, iXP > 0 ? "CRXRANKS_NOTIFY_KILL_GET" : "CRXRANKS_NOTIFY_KILL_LOSE", abs(iXP), szName)
	}

	iXP = give_user_xp(iVictim, get_xp_reward(iVictim, XPREWARD_DEATH), CRXRANKS_XPS_REWARD)

	if(should_send_kill_message(iXP))
	{
		CC_SendMessage(iVictim, "%L", iVictim, iXP > 0 ? "CRXRANKS_NOTIFY_DEATH_GET" : "CRXRANKS_NOTIFY_DEATH_LOSE", abs(iXP))
	}
}

public sort_players_by_xp(id1, id2)
{
	return g_ePlayerData[id2][XP] - g_ePlayerData[id1][XP]
}

public QueryHandler(iFailState, Handle:iQuery, szError[], iErrorCode)
{
	check_and_log_query_error(iFailState, szError, iErrorCode)
}

check_and_log_query_error(iFailState, const szError[], iErrorCode)
{
	switch(iFailState)
	{
		case TQUERY_CONNECT_FAILED: log_amx("[SQL Error] Connection failed (%i): %s", iErrorCode, szError)
		case TQUERY_QUERY_FAILED:   log_amx("[SQL Error] Query failed (%i): %s", iErrorCode, szError)
	}
}

bool:xp_reward_is_set(const szReward[])
{
	return TrieKeyExists(g_tXPRewards, szReward)
}

reward_team(const szTeam[], const szReward[])
{
	new iPlayers[MAX_PLAYERS], iPnum
	get_players(iPlayers, iPnum, "e", szTeam)

	for(new i, iPlayer; i < iPnum; i++)
	{
		iPlayer = iPlayers[i]
		give_user_xp(iPlayer, get_xp_reward(iPlayer, szReward), CRXRANKS_XPS_REWARD)
	}
}

save_or_load(const id, const szInfo[], const iType)
{
	if(!szInfo[0])
	{
		return
	}

	switch(iType)
	{
		case SL_SAVE_DATA:
		{
			if(g_eSettings[USE_MYSQL])
			{
				new szQuery[MAX_QUERY_LENGTH], szPlayer[MAX_SQL_PLAYER_LENGTH], szRank[MAX_SQL_RANK_LENGTH], szNextRank[MAX_SQL_RANK_LENGTH]

				SQL_QuoteString(Empty_Handle, szPlayer, charsmax(szPlayer), szInfo)
				SQL_QuoteString(Empty_Handle, szRank, charsmax(szRank), g_ePlayerData[id][Rank])
				SQL_QuoteString(Empty_Handle, szNextRank, charsmax(szNextRank), g_ePlayerData[id][NextRank])

				formatex(szQuery, charsmax(szQuery), "REPLACE INTO `%s` (`Player`, `XP`, `Level`, `Next XP`, `Rank`, `Next Rank`) VALUES ('%s', '%i', '%i', '%i', '%s', '%s');",\
				g_eSettings[SQL_TABLE], szPlayer, g_ePlayerData[id][XP], g_ePlayerData[id][Level], g_ePlayerData[id][NextXP], szRank, szNextRank)
				SQL_ThreadQuery(g_iSqlTuple, "QueryHandler", szQuery)
			}
			else
			{
				new szData[CRXRANKS_MAX_XP_LENGTH]
				num_to_str(g_ePlayerData[id][XP], szData, charsmax(szData))
				nvault_set(g_iVault, szInfo, szData)
			}
		}
		case SL_LOAD_DATA:
		{
			if(g_eSettings[USE_MYSQL])
			{
				new szPlayer[MAX_SQL_PLAYER_LENGTH]
				SQL_QuoteString(Empty_Handle, szPlayer, charsmax(szPlayer), szInfo)

				new szQuery[MAX_QUERY_LENGTH]
				formatex(szQuery, charsmax(szQuery), "SELECT XP FROM `%s` WHERE Player = '%s';", g_eSettings[SQL_TABLE], szPlayer)

				new iData[1]; iData[0] = id
				SQL_ThreadQuery(g_iSqlTuple, "QueryLoadData", szQuery, iData, sizeof(iData))
			}
			else
			{
				new iData = nvault_get(g_iVault, szInfo)
				g_ePlayerData[id][XP] = iData ? clamp(iData, 0) : 0
				check_level(id, false)
			}
		}
	}
}

public QueryLoadData(iFailState, Handle:iQuery, szError[], iErrorCode, iData[], iSize)
{
	new id = iData[0]

	if(SQL_NumResults(iQuery))
	{
		g_ePlayerData[id][XP] = SQL_ReadResult(iQuery, 0)
	}
	
	check_level(id, false)
}

get_xp_reward(const id, const szKey[])
{
	new iReward

	if(g_ePlayerData[id][IsVIP])
	{
		if(TrieKeyExists(g_tXPRewardsVIP, szKey))
		{
			TrieGetCell(g_tXPRewardsVIP, szKey, iReward)
			return iReward
		}
	}

	if(TrieKeyExists(g_tXPRewards, szKey))
	{
		TrieGetCell(g_tXPRewards, szKey, iReward)
		return iReward
	}

	return 0
}

give_user_xp(const id, iXP, CRXRanks_XPSources:iSource = CRXRANKS_XPS_PLUGIN)
{
	if(!iXP)
	{
		return 0
	}

	if(g_eSettings[IGNORE_BOTS] && g_ePlayerData[id][IsBot])
	{
		return 0
	}

	if(iSource == CRXRANKS_XPS_REWARD)
	{
		if(g_eSettings[MINIMUM_PLAYERS] && get_playersnum() < g_eSettings[MINIMUM_PLAYERS])
		{
			return 0
		}

		if(g_eSettings[TEAM_LOCK] && get_user_team(id) != g_eSettings[TEAM_LOCK])
		{
			return 0
		}
	}
	
	update_vip_status(id)

	new iReturn
	ExecuteForward(g_fwdUserReceiveXP, iReturn, id, iXP, iSource)

	switch(iReturn)
	{
		case CRXRANKS_HANDLED: return 0
		case CRXRANKS_CONTINUE: { }
		default:
		{
			if(iReturn != 0)
			{
				iXP = iReturn
			}
		}
	}

	g_ePlayerData[id][XP] += iXP

	if(g_ePlayerData[id][XP] < 0)
	{
		g_ePlayerData[id][XP] = 0
	}

	if(g_eSettings[SAVE_INTERVAL] == SAVE_ON_XP_CHANGE)
	{
		save_or_load(id, g_ePlayerData[id][SaveInfo], SL_SAVE_DATA)
	}

	check_level(id, true)
	ExecuteForward(g_fwdUserXPUpdated, iReturn, id, g_ePlayerData[id][XP], iSource)

	if(g_eSettings[XP_NOTIFIER_ENABLED])
	{
		new szKey[MAX_NAME_LENGTH], bool:bPositive
		bPositive = iXP >= 0

		copy(szKey, charsmax(szKey), bPositive ? "CRXRANKS_XP_NOTIFIER_GET" : "CRXRANKS_XP_NOTIFIER_LOSE")

		if(g_eSettings[XP_NOTIFIER_USE_DHUD])
		{
			if(bPositive)
			{
				set_dhudmessage(XP_NOTIFIER_PARAMS_GET)
			}
			else
			{
				set_dhudmessage(XP_NOTIFIER_PARAMS_LOSE)
			}

			show_dhudmessage(id, "%L", id, szKey, abs(iXP))
		}
		else
		{
			if(bPositive)
			{
				set_hudmessage(XP_NOTIFIER_PARAMS_GET)
			}
			else
			{
				set_hudmessage(XP_NOTIFIER_PARAMS_LOSE)
			}

			ShowSyncHudMsg(id, g_iObject[OBJ_XP_NOTIFIER], "%L", id, szKey, abs(iXP))
		}
	}

	return iXP
}

precache_sound_if_found(const szValue[])
{
	new szSound[MAX_SOUND_LENGTH]
	format(szSound, charsmax(szSound), "sound/%s", szValue)

	if(file_exists(szSound))
	{
		precache_sound(szValue)
	}
	else
	{
		log_amx("ERROR: sound file ^"%s^" not found", szValue)
	}
}

reset_player_stats(const id)
{
	g_ePlayerData[id][XP] = 0
	g_ePlayerData[id][Level] = 0
	g_ePlayerData[id][NextXP] = 0
	g_ePlayerData[id][Rank][0] = EOS
	g_ePlayerData[id][NextRank][0] = EOS
	g_ePlayerData[id][HUDInfo][0] = EOS
	g_ePlayerData[id][HudInfoEnabled] = true
	g_ePlayerData[id][IsOnFinalLevel] = false
	g_ePlayerData[id][IsVIP] = false
	g_ePlayerData[id][IsBot] = false
}

bool:has_argument(const szMessage[], const szArg[])
{
	return contain(szMessage, szArg) != -1
}

bool:should_skip(const iNum)
{
	return (iNum != 0 && !g_eSettings[USE_COMBINED_EVENTS])
}

bool:should_send_kill_message(const iXP)
{
	return (g_eSettings[NOTIFY_ON_KILL] && iXP != 0)
}

update_hudinfo(const id)
{
	if(!g_eSettings[HUDINFO_ENABLED])
	{
		return
	}

	new szMessage[CRXRANKS_MAX_HUDINFO_LENGTH], szPlaceHolder[MAX_NAME_LENGTH], bool:bIsOnFinal

	bIsOnFinal = g_ePlayerData[id][IsOnFinalLevel]
	copy(szMessage, charsmax(szMessage), g_eSettings[bIsOnFinal ? HUDINFO_FORMAT_FINAL : HUDINFO_FORMAT])

	if(has_argument(szMessage, ARG_CURRENT_XP))
	{
		num_to_str(g_ePlayerData[id][XP], szPlaceHolder, charsmax(szPlaceHolder))
		replace_string(szMessage, charsmax(szMessage), ARG_CURRENT_XP, szPlaceHolder)
	}

	if(has_argument(szMessage, ARG_NEXT_XP))
	{
		num_to_str(g_ePlayerData[id][NextXP], szPlaceHolder, charsmax(szPlaceHolder))
		replace_string(szMessage, charsmax(szMessage), ARG_NEXT_XP, szPlaceHolder)
	}

	if(has_argument(szMessage, ARG_XP_NEEDED))
	{
		num_to_str(g_ePlayerData[id][NextXP] - g_ePlayerData[id][XP], szPlaceHolder, charsmax(szPlaceHolder))
		replace_string(szMessage, charsmax(szMessage), ARG_XP_NEEDED, szPlaceHolder)
	}

	if(has_argument(szMessage, ARG_LEVEL))
	{
		num_to_str(g_ePlayerData[id][Level], szPlaceHolder, charsmax(szPlaceHolder))
		replace_string(szMessage, charsmax(szMessage), ARG_LEVEL, szPlaceHolder)
	}

	if(has_argument(szMessage, ARG_NEXT_LEVEL))
	{
		num_to_str(g_ePlayerData[id][bIsOnFinal ? Level : Level + 1], szPlaceHolder, charsmax(szPlaceHolder))
		replace_string(szMessage, charsmax(szMessage), ARG_NEXT_LEVEL, szPlaceHolder)
	}

	replace_string(szMessage, charsmax(szMessage), ARG_MAX_LEVELS, g_szMaxLevels)

	if(has_argument(szMessage, ARG_NAME))
	{
		get_user_name(id, szPlaceHolder, charsmax(szPlaceHolder))
		replace_string(szMessage, charsmax(szMessage), ARG_NAME, szPlaceHolder)
	}

	replace_string(szMessage, charsmax(szMessage), ARG_RANK, g_ePlayerData[id][Rank])
	replace_string(szMessage, charsmax(szMessage), ARG_NEXT_RANK, g_ePlayerData[id][NextRank])
	replace_string(szMessage, charsmax(szMessage), ARG_LINE_BREAK, "^n")
	copy(g_ePlayerData[id][HUDInfo], charsmax(g_ePlayerData[][HUDInfo]), szMessage)
}

check_level(const id, const bool:bNotify)
{
	new iLevel, i

	for(i = 1; i < g_iMaxLevels + 1; i++)
	{
		if(g_ePlayerData[id][XP] >= ArrayGetCell(g_aLevels, i))
		{
			iLevel++
		}
	}

	if(iLevel != g_ePlayerData[id][Level])
	{
		new bool:bLevelUp, iReturn
		bLevelUp = iLevel > g_ePlayerData[id][Level]
		g_ePlayerData[id][Level] = iLevel
		ArrayGetString(g_aRankNames, iLevel, g_ePlayerData[id][Rank], charsmax(g_ePlayerData[][Rank]))

		if(iLevel < g_iMaxLevels)
		{
			g_ePlayerData[id][IsOnFinalLevel] = false
			g_ePlayerData[id][NextXP] = ArrayGetCell(g_aLevels, iLevel + 1)
			ArrayGetString(g_aRankNames, iLevel + 1, g_ePlayerData[id][NextRank], charsmax(g_ePlayerData[][NextRank]))
		}
		else
		{
			g_ePlayerData[id][IsOnFinalLevel] = true
			g_ePlayerData[id][NextXP] = ArrayGetCell(g_aLevels, iLevel)
			copy(g_ePlayerData[id][NextRank], charsmax(g_ePlayerData[][NextRank]), g_eSettings[HUDINFO_INVALID_TEXT])

			if(g_eSettings[FINAL_LEVEL_FLAGS])
			{
				set_user_flags(id, g_eSettings[FINAL_LEVEL_FLAGS_BIT])
				remove_user_flags(id, g_iFlagZ)
			}
		}

		ExecuteForward(g_fwdUserLevelUpdated, iReturn, id, iLevel, bLevelUp)

		if(bNotify && g_eSettings[LEVELUP_MESSAGE_TYPE])
		{
			new szName[MAX_NAME_LENGTH]
			get_user_name(id, szName, charsmax(szName))

			if(g_eSettings[LEVELUP_MESSAGE_TYPE] == 2)
			{
				new iPlayers[MAX_PLAYERS], iPlayer, iPnum
				get_players(iPlayers, iPnum)

				for(i = 0; i < iPnum; i++)
				{
					iPlayer = iPlayers[i]
					CC_SendMessage(iPlayer, "%L", iPlayer, bLevelUp ? "CRXRANKS_LEVEL_REACHED" : "CRXRANKS_LEVEL_LOST", szName, g_ePlayerData[id][Level], g_ePlayerData[id][Rank])
				}
			}
			else
			{
				CC_SendMessage(id, "%L", id, bLevelUp ? "CRXRANKS_LEVEL_REACHED" : "CRXRANKS_LEVEL_LOST", szName, g_ePlayerData[id][Level], g_ePlayerData[id][Rank])
			}

			if(bLevelUp && g_eSettings[LEVELUP_SOUND][0])
			{
				emit_sound(id, CHAN_AUTO, g_eSettings[LEVELUP_SOUND], 1.0, ATTN_NORM, 0, PITCH_NORM)
			}
			else if(!bLevelUp && g_eSettings[LEVELDN_SOUND][0])
			{
				emit_sound(id, CHAN_AUTO, g_eSettings[LEVELDN_SOUND], 1.0, ATTN_NORM, 0, PITCH_NORM)
			}

			if(g_eSettings[bLevelUp ? LEVELUP_SCREEN_FADE_ENABLED : LEVELDN_SCREEN_FADE_ENABLED])
			{
				message_begin(MSG_ONE, g_iScreenFade, {0, 0, 0}, id)
				write_short(1<<10)
				write_short(1<<10)
				write_short(0)

				if(bLevelUp)
				{
					write_byte(clr(g_eSettings[LEVELUP_SCREEN_FADE_COLOR][0]))
					write_byte(clr(g_eSettings[LEVELUP_SCREEN_FADE_COLOR][1]))
					write_byte(clr(g_eSettings[LEVELUP_SCREEN_FADE_COLOR][2]))
					write_byte(clr(g_eSettings[LEVELUP_SCREEN_FADE_COLOR][3]))
				}
				else
				{
					write_byte(clr(g_eSettings[LEVELDN_SCREEN_FADE_COLOR][0]))
					write_byte(clr(g_eSettings[LEVELDN_SCREEN_FADE_COLOR][1]))
					write_byte(clr(g_eSettings[LEVELDN_SCREEN_FADE_COLOR][2]))
					write_byte(clr(g_eSettings[LEVELDN_SCREEN_FADE_COLOR][3]))
				}

				message_end()
			}
		}
	}

	update_hudinfo(id)
}

public update_vip_status(id)
{
	if(is_user_connected(id) && g_eSettings[VIP_FLAGS_BIT] != ADMIN_ALL)
	{
		g_ePlayerData[id][IsVIP] = bool:((get_user_flags(id) & g_eSettings[VIP_FLAGS_BIT]) == g_eSettings[VIP_FLAGS_BIT])
	}
}

public plugin_natives()
{
	register_library("crxranks")
	register_native("crxranks_get_chat_prefix",         "_crxranks_get_chat_prefix")
	register_native("crxranks_get_final_flags",         "_crxranks_get_final_flags")
	register_native("crxranks_get_hudinfo_format",      "_crxranks_get_hudinfo_format")
	register_native("crxranks_get_max_levels",          "_crxranks_get_max_levels")
	register_native("crxranks_get_rank_by_level",       "_crxranks_get_rank_by_level")
	register_native("crxranks_get_save_type",           "_crxranks_get_save_type")
	register_native("crxranks_get_setting",             "_crxranks_get_setting")
	register_native("crxranks_get_user_hudinfo",        "_crxranks_get_user_hudinfo")
	register_native("crxranks_get_user_level",          "_crxranks_get_user_level")
	register_native("crxranks_get_user_next_rank",      "_crxranks_get_user_next_rank")
	register_native("crxranks_get_user_next_xp",        "_crxranks_get_user_next_xp")
	register_native("crxranks_get_user_rank",           "_crxranks_get_user_rank")
	register_native("crxranks_get_user_xp",             "_crxranks_get_user_xp")
	register_native("crxranks_get_vault_name",          "_crxranks_get_vault_name")
	register_native("crxranks_get_vip_flags",           "_crxranks_get_vip_flags")
	register_native("crxranks_get_xp_for_level",        "_crxranks_get_xp_for_level")
	register_native("crxranks_get_xp_reward",           "_crxranks_get_xp_reward")
	register_native("crxranks_give_user_xp",            "_crxranks_give_user_xp")
	register_native("crxranks_has_user_hudinfo",        "_crxranks_has_user_hudinfo")
	register_native("crxranks_is_hi_using_dhud",        "_crxranks_is_hi_using_dhud")
	register_native("crxranks_is_hud_enabled",          "_crxranks_is_hud_enabled")
	register_native("crxranks_is_sfdn_enabled",         "_crxranks_is_sfdn_enabled")
	register_native("crxranks_is_sfup_enabled",         "_crxranks_is_sfup_enabled")
	register_native("crxranks_is_user_on_final",        "_crxranks_is_user_on_final")
	register_native("crxranks_is_user_vip",             "_crxranks_is_user_vip")
	register_native("crxranks_is_using_mysql",          "_crxranks_is_using_mysql")
	register_native("crxranks_is_xpn_enabled",          "_crxranks_is_xpn_enabled")
	register_native("crxranks_is_xpn_using_dhud",       "_crxranks_is_xpn_using_dhud")
	register_native("crxranks_set_user_xp",             "_crxranks_set_user_xp")
	register_native("crxranks_using_comb_events",       "_crxranks_using_comb_events")
	register_native("crxranks_xp_reward_is_set",        "_crxranks_xp_reward_is_set")
}

public _crxranks_get_chat_prefix(iPlugin, iParams)
{
	set_string(1, CC_PREFIX, get_param(2))
}

public _crxranks_get_final_flags(iPlugin, iParams)
{
	set_string(1, g_eSettings[FINAL_LEVEL_FLAGS], get_param(2))
	return g_eSettings[FINAL_LEVEL_FLAGS_BIT]
}

public _crxranks_get_hudinfo_format(iPlugin, iParams)
{
	set_string(2, g_eSettings[get_param(1) ? HUDINFO_FORMAT_FINAL : HUDINFO_FORMAT], get_param(3))
}

public _crxranks_get_max_levels(iPlugin, iParams)
{
	return g_iMaxLevels
}

public _crxranks_get_rank_by_level(iPlugin, iParams)
{
	new iLevel = get_param(1)

	if(iLevel < 1 || iLevel > g_iMaxLevels)
	{
		return 0
	}

	new szRank[CRXRANKS_MAX_RANK_LENGTH]
	ArrayGetString(g_aRankNames, iLevel, szRank, charsmax(szRank))
	set_string(2, szRank, get_param(3))
	return 1
}

public _crxranks_get_save_type(iPlugin, iParams)
{
	return g_eSettings[SAVE_TYPE]
}

public bool:_crxranks_get_setting(iPlugin, iParams)
{
	new szKey[MAX_NAME_LENGTH], szValue[CRXRANKS_MAX_HUDINFO_LENGTH], bool:bReturn
	get_string(1, szKey, charsmax(szKey))

	bReturn = TrieGetString(g_tSettings, szKey, szValue, charsmax(szValue))
	set_string(2, szValue, get_param(3))
	return bReturn
}

public _crxranks_get_user_hudinfo(iPlugin, iParams)
{
	set_string(2, g_ePlayerData[get_param(1)][HUDInfo], get_param(3))
}

public _crxranks_get_user_level(iPlugin, iParams)
{
	return g_ePlayerData[get_param(1)][Level]
}

public _crxranks_get_user_next_rank(iPlugin, iParams)
{
	set_string(2, g_ePlayerData[get_param(1)][NextRank], get_param(3))
}

public _crxranks_get_user_next_xp(iPlugin, iParams)
{
	return g_ePlayerData[get_param(1)][NextXP]
}

public _crxranks_get_user_rank(iPlugin, iParams)
{
	set_string(2, g_ePlayerData[get_param(1)][Rank], get_param(3))
}

public _crxranks_get_user_xp(iPlugin, iParams)
{
	return g_ePlayerData[get_param(1)][XP]
}

public _crxranks_get_vault_name(iPlugin, iParams)
{
	set_string(1, g_eSettings[VAULT_NAME], get_param(2))
}

public _crxranks_get_vip_flags(iPlugin, iParams)
{
	set_string(1, g_eSettings[VIP_FLAGS], get_param(2))
	return g_eSettings[VIP_FLAGS_BIT]
}

public _crxranks_get_xp_for_level(iPlugin, iParams)
{
	new iLevel = get_param(1)

	if(iLevel < 1 || iLevel > g_iMaxLevels)
	{
		return -1
	}

	return ArrayGetCell(g_aLevels, iLevel)
}

public _crxranks_get_xp_reward(iPlugin, iParams)
{
	new szReward[CRXRANKS_MAX_XP_REWARD_LENGTH]
	get_string(2, szReward, charsmax(szReward))
	return get_xp_reward(get_param(1), szReward)
}

public _crxranks_give_user_xp(iPlugin, iParams)
{
	new szReward[CRXRANKS_MAX_XP_REWARD_LENGTH], iReward, id = get_param(1)
	get_string(3, szReward, charsmax(szReward))

	if(szReward[0])
	{
		iReward = get_xp_reward(id, szReward)

		if(iReward)
		{
			give_user_xp(id, iReward, CRXRanks_XPSources:get_param(4))
		}

		return iReward
	}

	iReward = get_param(2)
	give_user_xp(id, iReward, CRXRanks_XPSources:get_param(4))
	return iReward
}

public bool:_crxranks_has_user_hudinfo(iPlugin, iParams)
{
	return g_ePlayerData[get_param(1)][HudInfoEnabled]
}

public bool:_crxranks_is_hi_using_dhud(iPlugin, iParams)
{
	return g_eSettings[HUDINFO_USE_DHUD]
}

public bool:_crxranks_is_hud_enabled(iPlugin, iParams)
{
	return g_eSettings[HUDINFO_ENABLED]
}

public bool:_crxranks_is_sfdn_enabled(iPlugin, iParams)
{
	return g_eSettings[LEVELDN_SCREEN_FADE_ENABLED]
}

public bool:_crxranks_is_sfup_enabled(iPlugin, iParams)
{
	return g_eSettings[LEVELUP_SCREEN_FADE_ENABLED]
}

public bool:_crxranks_is_user_on_final(iPlugin, iParams)
{
	return g_ePlayerData[get_param(1)][IsOnFinalLevel]
}

public bool:_crxranks_is_user_vip(iPlugin, iParams)
{
	return g_ePlayerData[get_param(1)][IsVIP]
}

public bool:_crxranks_is_using_mysql(iPlugin, iParams)
{
	return g_eSettings[USE_MYSQL]
}

public bool:_crxranks_is_xpn_enabled(iPlugin, iParams)
{
	return g_eSettings[XP_NOTIFIER_ENABLED]
}

public bool:_crxranks_is_xpn_using_dhud(iPlugin, iParams)
{
	return g_eSettings[XP_NOTIFIER_USE_DHUD]
}


public bool:_crxranks_set_user_xp(iPlugin, iParams)
{
	new iReturn, id = get_param(1), CRXRanks_XPSources:iSource = CRXRanks_XPSources:get_param(3)
	g_ePlayerData[id][XP] = clamp(get_param(2), 0)

	if(g_eSettings[SAVE_INTERVAL] == SAVE_ON_XP_CHANGE)
	{
		save_or_load(id, g_ePlayerData[id][SaveInfo], SL_SAVE_DATA)
	}

	check_level(id, true)
	ExecuteForward(g_fwdUserXPUpdated, iReturn, id, g_ePlayerData[id][XP], iSource)
}

public bool:_crxranks_using_comb_events(iPlugin, iParams)
{
	return g_eSettings[USE_COMBINED_EVENTS]
}

public bool:_crxranks_xp_reward_is_set(iPlugin, iParams)
{
	new szReward[CRXRANKS_MAX_XP_REWARD_LENGTH]
	get_string(1, szReward, charsmax(szReward))
	return xp_reward_is_set(szReward)
}
