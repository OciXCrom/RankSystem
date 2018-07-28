#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <nvault>

// Comment or remove this line in order to run the plugin on a mod different than Counter-Strike.
#define USE_CSTRIKE

#if defined USE_CSTRIKE
	#include <cromchat>
	#include <csx>
#else
new CC_PREFIX[64]
#endif

#if AMXX_VERSION_NUM < 183
	#include <dhudmessage>
#endif

#include <crxranks_const>

#if defined client_disconnected
	#define client_disconnect client_disconnected
#endif

#define PLUGIN_VERSION "2.3"
#define DELAY_ON_CONNECT 2.0
#define HUD_REFRESH_FREQ 1.0
#define DELAY_ON_CHANGE 0.1
#define MAX_HUDINFO_LENGTH 192
#define MAX_SOUND_LENGTH 128
#define MAX_PLAYER_INFO_LENGTH 35
#define MAX_RANK_LENGTH 32
#define MAX_XP_REWARD_LENGTH 32
#define MAX_XP_LENGTH 16
#define TASK_HUD 304500

#if !defined MAX_NAME_LENGTH
	#define MAX_NAME_LENGTH 32
#endif

#define ARG_CURRENT_XP 			"$current_xp$"
#define ARG_NEXT_XP 			"$next_xp$"
#define ARG_XP_NEEDED 			"$xp_needed$"
#define ARG_LEVEL 				"$level$"
#define ARG_NEXT_LEVEL 			"$next_level$"
#define ARG_RANK 				"$rank$"
#define ARG_NEXT_RANK 			"$next_rank$"
#define ARG_MAX_LEVELS			"$max_levels$"
#define ARG_LINE_BREAK 			"$br$"
#define ARG_NAME 				"$name$"

#define XPREWARD_KILL			"kill"
#define XPREWARD_HEADSHOT 		"headshot"
#define XPREWARD_TEAMKILL 		"teamkill"
#define XPREWARD_SUICIDE 		"suicide"

#if defined USE_CSTRIKE
	#define XPREWARD_BOMB_PLANTED 	"bomb_planted"
	#define XPREWARD_BOMB_DEFUSED 	"bomb_defused"
	#define XPREWARD_BOMB_EXPLODED 	"bomb_exploded"
#endif

#define clr(%1) %1 == -1 ? random(256) : %1

#define HUDINFO_PARAMS clr(g_eSettings[HUDINFO_COLOR][0]), clr(g_eSettings[HUDINFO_COLOR][1]), clr(g_eSettings[HUDINFO_COLOR][2]),\
g_eSettings[HUDINFO_POSITION][0], g_eSettings[HUDINFO_POSITION][1], 0, 0.1, 1.0, 0.1, 0.1

#define XP_NOTIFIER_PARAMS_GET clr(g_eSettings[XP_NOTIFIER_COLOR_GET][0]), clr(g_eSettings[XP_NOTIFIER_COLOR_GET][1]), clr(g_eSettings[XP_NOTIFIER_COLOR_GET][2]),\
g_eSettings[XP_NOTIFIER_POSITION][0], g_eSettings[XP_NOTIFIER_POSITION][1], .holdtime = g_eSettings[XP_NOTIFIER_DURATION]

#define XP_NOTIFIER_PARAMS_LOSE clr(g_eSettings[XP_NOTIFIER_COLOR_LOSE][0]), clr(g_eSettings[XP_NOTIFIER_COLOR_LOSE][1]), clr(g_eSettings[XP_NOTIFIER_COLOR_LOSE][2]),\
g_eSettings[XP_NOTIFIER_POSITION][0], g_eSettings[XP_NOTIFIER_POSITION][1], .holdtime = g_eSettings[XP_NOTIFIER_DURATION]

enum
{
	VAULT_WRITE = 0,
	VAULT_READ
}

enum
{
	OBJ_HUDINFO = 0,
	OBJ_XP_NOTIFIER
}

enum
{
	SAVE_NICKNAME = 0,
	SAVE_IP,
	SAVE_STEAMID
}

enum _:Sections
{
	SECTION_NONE = 0,
	SECTION_SETTINGS,
	SECTION_RANKS,
	SECTION_XP_REWARDS
}

enum _:PlayerData
{
	XP,
	Level,
	NextXP,
	Rank[MAX_RANK_LENGTH],
	NextRank[MAX_RANK_LENGTH],
	HUDInfo[MAX_HUDINFO_LENGTH],
	bool:IsOnFinalLevel,
	bool:IsVIP
}

enum _:Settings
{
	SAVE_TYPE,
	LEVELUP_MESSAGE_TYPE,
	LEVELUP_SOUND[MAX_SOUND_LENGTH],
	bool:LEVELUP_SCREEN_FADE_ENABLED,
	LEVELUP_SCREEN_FADE_COLOR[4],
	LEVELDN_SOUND[MAX_SOUND_LENGTH],
	bool:LEVELDN_SCREEN_FADE_ENABLED,
	LEVELDN_SCREEN_FADE_COLOR[4],
	FINAL_LEVEL_FLAGS[32],
	FINAL_LEVEL_FLAGS_BIT,
	VIP_FLAGS[32],
	VIP_FLAGS_BIT,
	VAULT_NAME[32],
	TEAM_LOCK,
	MINIMUM_PLAYERS,
	bool:USE_COMBINED_EVENTS,
	bool:HUDINFO_ENABLED,
	bool:HUDINFO_ALIVE_ONLY,
	bool:HUDINFO_TEAM_LOCK,
	bool:HUDINFO_OTHER_PLAYERS,
	HUDINFO_COLOR[3],
	Float:HUDINFO_POSITION[2],
	bool:HUDINFO_USE_DHUD,
	HUDINFO_FORMAT[MAX_HUDINFO_LENGTH],
	HUDINFO_FORMAT_FINAL[MAX_HUDINFO_LENGTH],
	HUDINFO_INVALID_TEXT[32],
	bool:XP_NOTIFIER_ENABLED,
	XP_NOTIFIER_COLOR_GET[3],
	XP_NOTIFIER_COLOR_LOSE[3],
	Float:XP_NOTIFIER_POSITION[2],
	Float:XP_NOTIFIER_DURATION,
	bool:XP_NOTIFIER_USE_DHUD
}

new g_eSettings[Settings]
new g_ePlayerData[33][PlayerData]
new g_szMaxLevels[MAX_XP_LENGTH]
new Array:g_aLevels
new Array:g_aRankNames
new Trie:g_tXPRewards
new Trie:g_tXPRewardsVIP

new g_iVault
new g_iMaxLevels
new g_iObject[2]
new g_iScreenFade
new g_iFlagZ
new g_fwdUserLevelUpdated
new g_fwdUserReceiveXP

public plugin_init()
{
	register_plugin("OciXCrom's Rank System", PLUGIN_VERSION, "OciXCrom")
	register_cvar("CRXRankSystem", PLUGIN_VERSION, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED)
	register_event("DeathMsg", "OnPlayerKilled", "a")
	
	#if defined USE_CSTRIKE
	register_dictionary("RankSystem.txt")
	#else
	register_dictionary("RankSystemNoColors.txt")
	#endif
	
	register_clcmd("say /xplist", "Cmd_XPList", ADMIN_BAN)
	register_clcmd("say_team /xplist", "Cmd_XPList", ADMIN_BAN)
	register_concmd("crxranks_give_xp", "Cmd_GiveXP", ADMIN_RCON, "<nick|#userid> <amount>")
	register_concmd("crxranks_reset_xp", "Cmd_ResetXP", ADMIN_RCON, "<nick|#userid>")
	
	if(g_eSettings[LEVELUP_SCREEN_FADE_ENABLED] || g_eSettings[LEVELDN_SCREEN_FADE_ENABLED])
		g_iScreenFade = get_user_msgid("ScreenFade")

	g_fwdUserLevelUpdated = CreateMultiForward("crxranks_user_level_updated", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL)
	g_fwdUserReceiveXP = CreateMultiForward("crxranks_user_receive_xp", ET_STOP, FP_CELL, FP_CELL, FP_CELL)
}

public plugin_precache()
{
	g_aLevels = ArrayCreate(16)
	ArrayPushCell(g_aLevels, 0)
	g_aRankNames = ArrayCreate(32)
	ArrayPushString(g_aRankNames, "")
	g_tXPRewards = TrieCreate()
	g_tXPRewardsVIP = TrieCreate()
	ReadFile()
}

public plugin_end()
{
	ArrayDestroy(g_aLevels)
	ArrayDestroy(g_aRankNames)
	TrieDestroy(g_tXPRewards)
	TrieDestroy(g_tXPRewardsVIP)
	DestroyForward(g_fwdUserLevelUpdated)
	nvault_close(g_iVault)
}

ReadFile()
{
	new szConfigsName[256], szFilename[256]
	get_configsdir(szConfigsName, charsmax(szConfigsName))
	formatex(szFilename, charsmax(szFilename), "%s/RankSystem.ini", szConfigsName)
	
	new iFilePointer = fopen(szFilename, "rt")
	
	if(iFilePointer)
	{
		new szData[192], szValue[96], szMap[32], szKey[32], szTemp[4][5], bool:bRead = true, i, iSize, iSection = SECTION_NONE
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
						continue
						
					strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=')
					trim(szKey); trim(szValue)
							
					if(!szValue[0])
						continue
						
					switch(iSection)
					{
						case SECTION_SETTINGS:
						{
							if(equal(szKey, "CHAT_PREFIX"))
							{
								#if defined USE_CSTRIKE
								CC_SetPrefix(szValue)
								#else
								copy(CC_PREFIX, charsmax(CC_PREFIX), szValue)
								#endif
							}
							else if(equal(szKey, "SAVE_TYPE"))
								g_eSettings[SAVE_TYPE] = clamp(str_to_num(szValue), SAVE_NICKNAME, SAVE_STEAMID)
							else if(equal(szKey, "XP_COMMANDS"))
							{
								while(szValue[0] != 0 && strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ','))
								{
									trim(szKey); trim(szValue)
									register_clcmd(szKey, "Cmd_XP")
								}
							}
							else if(equal(szKey, "LEVELUP_MESSAGE_TYPE"))
								g_eSettings[LEVELUP_MESSAGE_TYPE] = clamp(str_to_num(szValue), 0, 2)
							else if(equal(szKey, "LEVELUP_SOUND"))
							{
								copy(g_eSettings[LEVELUP_SOUND], charsmax(g_eSettings[LEVELUP_SOUND]), szValue)
								
								if(szValue[0])
									precache_sound(szValue)
							}
							else if(equal(szKey, "LEVELUP_SCREEN_FADE_ENABLED"))
								g_eSettings[LEVELUP_SCREEN_FADE_ENABLED] = _:clamp(str_to_num(szValue), false, true)
							else if(equal(szKey, "LEVELUP_SCREEN_FADE_COLOR"))
							{
								parse(szValue, szTemp[0], charsmax(szTemp[]), szTemp[1], charsmax(szTemp[]), szTemp[2], charsmax(szTemp[]), szTemp[3], charsmax(szTemp[]))
								
								for(i = 0; i < 4; i++)
									g_eSettings[LEVELUP_SCREEN_FADE_COLOR][i] = clamp(str_to_num(szTemp[i]), -1, 255)
							}
							else if(equal(szKey, "LEVELDN_SOUND"))
							{
								copy(g_eSettings[LEVELDN_SOUND], charsmax(g_eSettings[LEVELDN_SOUND]), szValue)
								
								if(szValue[0])
									precache_sound(szValue)
							}
							else if(equal(szKey, "LEVELDN_SCREEN_FADE_ENABLED"))
								g_eSettings[LEVELDN_SCREEN_FADE_ENABLED] = _:clamp(str_to_num(szValue), false, true)
							else if(equal(szKey, "LEVELDN_SCREEN_FADE_COLOR"))
							{
								parse(szValue, szTemp[0], charsmax(szTemp[]), szTemp[1], charsmax(szTemp[]), szTemp[2], charsmax(szTemp[]), szTemp[3], charsmax(szTemp[]))
								
								for(i = 0; i < 4; i++)
									g_eSettings[LEVELDN_SCREEN_FADE_COLOR][i] = clamp(str_to_num(szTemp[i]), -1, 255)
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
								g_iVault = nvault_open(szValue)
								copy(g_eSettings[VAULT_NAME], charsmax(g_eSettings[VAULT_NAME]), szValue)
							}
							else if(equal(szKey, "TEAM_LOCK"))
								g_eSettings[TEAM_LOCK] = str_to_num(szValue)
							else if(equal(szKey, "MINIMUM_PLAYERS"))
								g_eSettings[MINIMUM_PLAYERS] = clamp(str_to_num(szValue), 0, 32)
							else if(equal(szKey, "USE_COMBINED_EVENTS"))
								g_eSettings[USE_COMBINED_EVENTS] = _:clamp(str_to_num(szValue), false, true)
							else if(equal(szKey, "HUDINFO_ENABLED"))
								g_eSettings[HUDINFO_ENABLED] = _:clamp(str_to_num(szValue), false, true)
							else if(equal(szKey, "HUDINFO_ALIVE_ONLY"))
								g_eSettings[HUDINFO_ALIVE_ONLY] = _:clamp(str_to_num(szValue), false, true)
							else if(equal(szKey, "HUDINFO_TEAM_LOCK"))
								g_eSettings[HUDINFO_TEAM_LOCK] = _:clamp(str_to_num(szValue), false, true)
							else if(equal(szKey, "HUDINFO_OTHER_PLAYERS"))
								g_eSettings[HUDINFO_OTHER_PLAYERS] = _:clamp(str_to_num(szValue), false, true)
							else if(equal(szKey, "HUDINFO_COLOR"))
							{
								parse(szValue, szTemp[0], charsmax(szTemp[]), szTemp[1], charsmax(szTemp[]), szTemp[2], charsmax(szTemp[]))
								
								for(i = 0; i < 3; i++)
									g_eSettings[HUDINFO_COLOR][i] = clamp(str_to_num(szTemp[i]), -1, 255)
							}
							else if(equal(szKey, "HUDINFO_POSITION"))
							{
								parse(szValue, szTemp[0], charsmax(szTemp[]), szTemp[1], charsmax(szTemp[]))
								
								for(i = 0; i < 2; i++)
									g_eSettings[HUDINFO_POSITION][i] = _:floatclamp(str_to_float(szTemp[i]), -1.0, 1.0)
							}
							else if(equal(szKey, "HUDINFO_USE_DHUD"))
							{
								g_eSettings[HUDINFO_USE_DHUD] = _:clamp(str_to_num(szValue), false, true)
								
								if(!g_eSettings[HUDINFO_USE_DHUD])
									g_iObject[OBJ_HUDINFO] = CreateHudSyncObj()
							}
							else if(equal(szKey, "HUDINFO_FORMAT"))
								copy(g_eSettings[HUDINFO_FORMAT], charsmax(g_eSettings[HUDINFO_FORMAT]), szValue)
							else if(equal(szKey, "HUDINFO_FORMAT_FINAL"))
								copy(g_eSettings[HUDINFO_FORMAT_FINAL], charsmax(g_eSettings[HUDINFO_FORMAT_FINAL]), szValue)
							else if(equal(szKey, "HUDINFO_INVALID_TEXT"))
								copy(g_eSettings[HUDINFO_INVALID_TEXT], charsmax(g_eSettings[HUDINFO_INVALID_TEXT]), szValue)
							else if(equal(szKey, "XP_NOTIFIER_ENABLED"))
								g_eSettings[XP_NOTIFIER_ENABLED] = _:clamp(str_to_num(szValue), false, true)
							else if(equal(szKey, "XP_NOTIFIER_COLOR_GET"))
							{
								parse(szValue, szTemp[0], charsmax(szTemp[]), szTemp[1], charsmax(szTemp[]), szTemp[2], charsmax(szTemp[]))
								
								for(i = 0; i < 3; i++)
									g_eSettings[XP_NOTIFIER_COLOR_GET][i] = clamp(str_to_num(szTemp[i]), -1, 255)
							}
							else if(equal(szKey, "XP_NOTIFIER_COLOR_LOSE"))
							{
								parse(szValue, szTemp[0], charsmax(szTemp[]), szTemp[1], charsmax(szTemp[]), szTemp[2], charsmax(szTemp[]))
								
								for(i = 0; i < 3; i++)
									g_eSettings[XP_NOTIFIER_COLOR_LOSE][i] = clamp(str_to_num(szTemp[i]), -1, 255)
							}
							else if(equal(szKey, "XP_NOTIFIER_POSITION"))
							{
								parse(szValue, szTemp[0], charsmax(szTemp[]), szTemp[1], charsmax(szTemp[]))
								
								for(i = 0; i < 2; i++)
									g_eSettings[XP_NOTIFIER_POSITION][i] = _:floatclamp(str_to_float(szTemp[i]), -1.0, 1.0)
							}
							else if(equal(szKey, "XP_NOTIFIER_DURATION"))
								g_eSettings[XP_NOTIFIER_DURATION] = _:floatclamp(str_to_float(szValue), 0.0, float(cellmax))
							else if(equal(szKey, "XP_NOTIFIER_USE_DHUD"))
							{
								g_eSettings[XP_NOTIFIER_USE_DHUD] = _:clamp(str_to_num(szValue), false, true)
								
								if(!g_eSettings[XP_NOTIFIER_USE_DHUD])
									g_iObject[OBJ_XP_NOTIFIER] = CreateHudSyncObj()
							}
						}
						case SECTION_RANKS:
						{
							ArrayPushCell(g_aLevels, clamp(str_to_num(szValue), 0))
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
								TrieSetCell(g_tXPRewardsVIP, szKey, str_to_num(szReward[1]))
						}
					}
				}
			}
		}
		
		num_to_str(g_iMaxLevels, g_szMaxLevels, charsmax(g_szMaxLevels))
		fclose(iFilePointer)
	}
}

public client_connect(id)
{
	reset_stats(id)
	
	new szInfo[MAX_PLAYER_INFO_LENGTH]
	get_user_saveinfo(id, szInfo, charsmax(szInfo))
	use_vault(id, szInfo, VAULT_READ)
	update_vip_status(id)
	
	if(g_eSettings[HUDINFO_ENABLED])
		set_task(HUD_REFRESH_FREQ, "DisplayHUD", id + TASK_HUD, .flags = "b")
}

public client_disconnect(id)
{
	new szInfo[MAX_PLAYER_INFO_LENGTH]
	get_user_saveinfo(id, szInfo, charsmax(szInfo))
	use_vault(id, szInfo, VAULT_WRITE)
	remove_task(id + TASK_HUD)
}

public client_infochanged(id)
{
	if(!is_user_connected(id))
		return
		
	static const szKey[] = "name"
	static szNewName[MAX_NAME_LENGTH], szOldName[MAX_NAME_LENGTH]
	get_user_info(id, szKey, szNewName, charsmax(szNewName))
	get_user_name(id, szOldName, charsmax(szOldName))
	
	if(!equal(szNewName, szOldName))
	{		
		if(g_eSettings[SAVE_TYPE] == SAVE_NICKNAME)
		{
			use_vault(id, szOldName, VAULT_WRITE)
			use_vault(id, szNewName, VAULT_READ)
			update_hudinfo(id)
		}
		
		set_task(DELAY_ON_CHANGE, "update_vip_status", id)
	}
}

public DisplayHUD(id)
{
	id -= TASK_HUD
	
	static iTarget
	iTarget = id
	
	if(!is_user_alive(id))
	{		
		if(g_eSettings[HUDINFO_ALIVE_ONLY])
			return
			
		if(g_eSettings[HUDINFO_OTHER_PLAYERS])
			iTarget = pev(id, pev_iuser2)
	}
	
	if(!iTarget)
		return

	if(g_eSettings[TEAM_LOCK] && g_eSettings[HUDINFO_TEAM_LOCK] && get_user_team(iTarget) != g_eSettings[TEAM_LOCK])
		return
	
	if(g_eSettings[HUDINFO_USE_DHUD])
	{
		set_dhudmessage(HUDINFO_PARAMS)
		show_dhudmessage(id, g_ePlayerData[iTarget][HUDInfo])
	}
	else
	{
		set_hudmessage(HUDINFO_PARAMS)
		ShowSyncHudMsg(id, g_iObject[OBJ_HUDINFO], g_ePlayerData[iTarget][HUDInfo])
	}
}

#if defined USE_CSTRIKE
public bomb_planted(id)
	give_user_xp(id, get_xp_reward(id, XPREWARD_BOMB_PLANTED), CRXRANKS_XPS_REWARD)
	
public bomb_defused(id)
	give_user_xp(id, get_xp_reward(id, XPREWARD_BOMB_DEFUSED), CRXRANKS_XPS_REWARD)
	
public bomb_explode(id)
	give_user_xp(id, get_xp_reward(id, XPREWARD_BOMB_EXPLODED), CRXRANKS_XPS_REWARD)
#endif

public Cmd_XP(id)
{	
	if(g_ePlayerData[id][Level] == g_iMaxLevels)
		send_message(id, false, "%L", id, "CRXRANKS_RANKINFO_FINAL", g_ePlayerData[id][XP], g_ePlayerData[id][Level], g_ePlayerData[id][Rank])
	else
	{
		send_message(id, false, "%L", id, "CRXRANKS_RANKINFO_NORMAL", g_ePlayerData[id][XP], g_ePlayerData[id][NextXP],\
		g_ePlayerData[id][Level], g_ePlayerData[id][Rank], g_ePlayerData[id][NextRank])
	}
	
	return PLUGIN_HANDLED
}

public Cmd_XPList(id, iLevel, iCid)
{
	if(!cmd_access(id, iLevel, iCid, 1))
		return PLUGIN_HANDLED
		
	new szTitle[128]
	formatex(szTitle, charsmax(szTitle), "%L", id, "CRXRANKS_MENU_TITLE")
	
	new iPlayers[32], iPnum, iMenu = menu_create(szTitle, "XPList_Handler")
	get_players(iPlayers, iPnum); SortCustom1D(iPlayers, iPnum, "sort_players_by_xp")
	
	for(new szItem[128], szName[32], iPlayer, i; i < iPnum; i++)
	{
		iPlayer = iPlayers[i]
		get_user_name(iPlayer, szName, charsmax(szName))
		formatex(szItem, charsmax(szItem), "%L", id, "CRXRANKS_ITEM_FORMAT", g_ePlayerData[iPlayer][XP], szName, g_ePlayerData[iPlayer][Level], g_ePlayerData[iPlayer][Rank])
		menu_additem(iMenu, szItem)
	}
	
	menu_display(id, iMenu)
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
		return PLUGIN_HANDLED
	
	new szPlayer[MAX_NAME_LENGTH]
	read_argv(1, szPlayer, charsmax(szPlayer))
	
	new iPlayer = cmd_target(id, szPlayer, 0)
	
	if(!iPlayer)
		return PLUGIN_HANDLED
		
	new szName[2][MAX_NAME_LENGTH], szAmount[MAX_XP_LENGTH]
	read_argv(2, szAmount, charsmax(szAmount))
	get_user_name(id, szName[0], charsmax(szName[]))
	get_user_name(iPlayer, szName[1], charsmax(szName[]))
	
	new szKey[32], iXP = str_to_num(szAmount)
	give_user_xp(iPlayer, iXP, CRXRANKS_XPS_ADMIN)
	
	if(iXP >= 0)
		copy(szKey, charsmax(szKey), "CRXRANKS_GIVE_XP")
	else
	{
		copy(szKey, charsmax(szKey), "CRXRANKS_TAKE_XP")
		iXP *= -1
	}
	
	send_message(0, true, "%L", id, szKey, szName[0], iXP, szName[1])
	return PLUGIN_HANDLED
}

public Cmd_ResetXP(id, iLevel, iCid)
{	
	if(!cmd_access(id, iLevel, iCid, 2))
		return PLUGIN_HANDLED
	
	new szPlayer[MAX_NAME_LENGTH]
	read_argv(1, szPlayer, charsmax(szPlayer))
	
	new iPlayer = cmd_target(id, szPlayer, CMDTARGET_OBEY_IMMUNITY|CMDTARGET_ALLOW_SELF)
	
	if(!iPlayer)
		return PLUGIN_HANDLED
		
	new szName[2][MAX_NAME_LENGTH]
	get_user_name(id, szName[0], charsmax(szName[]))
	get_user_name(iPlayer, szName[1], charsmax(szName[]))
	g_ePlayerData[iPlayer][XP] = 0
	check_level(iPlayer, true)
	send_message(0, true, "%L", id, "CRXRANKS_RESET_XP", szName[0], szName[1])
	return PLUGIN_HANDLED
}

public OnPlayerKilled()
{
	new iAttacker = read_data(1), iVictim = read_data(2)
	
	if(!is_user_connected(iAttacker) || !is_user_connected(iVictim))
		return
		
	new iReward, iTemp
	
	if(iAttacker == iVictim)
	{
		iTemp = get_xp_reward(iAttacker, XPREWARD_SUICIDE)
		iReward += iTemp
		
		if(should_skip(iTemp))
			goto @GIVE_REWARD
	}
	else if(get_user_team(iAttacker) == get_user_team(iVictim))
	{
		iTemp = get_xp_reward(iAttacker, XPREWARD_TEAMKILL)
		iReward += iTemp
		
		if(should_skip(iTemp))
			goto @GIVE_REWARD
	}
	else
	{
		new szWeapon[16]
		read_data(4, szWeapon, charsmax(szWeapon))
		
		iTemp = get_xp_reward(iAttacker, szWeapon)
		iReward += iTemp
		
		if(should_skip(iTemp))
			goto @GIVE_REWARD
			
		if(read_data(3))
		{
			iTemp = get_xp_reward(iAttacker, XPREWARD_HEADSHOT)
			iReward += iTemp
			
			if(should_skip(iTemp))
				goto @GIVE_REWARD
		}
		
		iReward += get_xp_reward(iAttacker, XPREWARD_KILL)
	}
	
	@GIVE_REWARD:
	give_user_xp(iAttacker, iReward, CRXRANKS_XPS_REWARD)
}

public sort_players_by_xp(id1, id2)
{
	if(g_ePlayerData[id1][XP] > g_ePlayerData[id2][XP])
		return -1
	else if(g_ePlayerData[id1][XP] < g_ePlayerData[id2][XP])
		return 1
	
	return 0
}

use_vault(const id, const szInfo[], const iType)
{
	if(!szInfo[0])
		return	
		
	switch(iType)
	{
		case VAULT_WRITE:
		{
			static szData[MAX_XP_LENGTH]
			num_to_str(g_ePlayerData[id][XP], szData, charsmax(szData))
			nvault_set(g_iVault, szInfo, szData)
		}
		case VAULT_READ:
		{
			static iData
			iData = nvault_get(g_iVault, szInfo)
			
			if(iData)
				g_ePlayerData[id][XP] = clamp(iData, 0)
				
			check_level(id, false)
		}
	}
}

get_xp_reward(const id, const szKey[])
{
	static iReward
	
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
		return

	if(iSource == CRXRANKS_XPS_REWARD)
	{
		if(g_eSettings[MINIMUM_PLAYERS] && get_playersnum() < g_eSettings[MINIMUM_PLAYERS])
			return;

		if(g_eSettings[TEAM_LOCK] && get_user_team(id) != g_eSettings[TEAM_LOCK])
			return
	}
		
	static iReturn
	ExecuteForward(g_fwdUserReceiveXP, iReturn, id, iXP, iSource)
	
	switch(iReturn)
	{
		case CRXRANKS_HANDLED: return
		case CRXRANKS_CONTINUE: { }
		default:
		{
			if(iReturn != 0)
				iXP = iReturn
		}
	}
		
	g_ePlayerData[id][XP] += iXP
	
	if(g_ePlayerData[id][XP] < 0)
		g_ePlayerData[id][XP] = 0
	
	if(!check_level(id, true))
		update_hudinfo(id)
		
	if(g_eSettings[XP_NOTIFIER_ENABLED])
	{
		static szKey[32], bool:bPositive
		bPositive = iXP >= 0
		
		if(bPositive)
			copy(szKey, charsmax(szKey), "CRXRANKS_XP_NOTIFIER_GET")
		else
		{
			copy(szKey, charsmax(szKey), "CRXRANKS_XP_NOTIFIER_LOSE")
			iXP *= -1
		}
			
		if(g_eSettings[XP_NOTIFIER_USE_DHUD])
		{
			if(bPositive) set_dhudmessage(XP_NOTIFIER_PARAMS_GET)
			else set_dhudmessage(XP_NOTIFIER_PARAMS_LOSE)				
			show_dhudmessage(id, "%L", id, szKey, iXP)
		}
		else
		{
			if(bPositive) set_hudmessage(XP_NOTIFIER_PARAMS_GET)
			else set_hudmessage(XP_NOTIFIER_PARAMS_LOSE)				
			ShowSyncHudMsg(id, g_iObject[OBJ_XP_NOTIFIER], "%L", id, szKey, iXP)
		}
	}			
}

get_user_saveinfo(const id, szInfo[MAX_PLAYER_INFO_LENGTH], const iLen)
{
	switch(g_eSettings[SAVE_TYPE])
	{
		case SAVE_NICKNAME:	get_user_name(id, szInfo, iLen)
		case SAVE_IP: get_user_ip(id, szInfo, iLen, 1)
		case SAVE_STEAMID: get_user_authid(id, szInfo, iLen)
	}
}

reset_stats(const id)
{
	g_ePlayerData[id][XP] = 0
	g_ePlayerData[id][Level] = 0
	g_ePlayerData[id][NextXP] = 0
	g_ePlayerData[id][Rank][0] = EOS
	g_ePlayerData[id][NextRank][0] = EOS
	g_ePlayerData[id][HUDInfo][0] = EOS
	g_ePlayerData[id][IsOnFinalLevel] = false
	g_ePlayerData[id][IsVIP] = false
}

bool:has_argument(const szMessage[], const szArg[])
	return contain(szMessage, szArg) != -1
	
bool:should_skip(const iNum)
	return (iNum != 0 && !g_eSettings[USE_COMBINED_EVENTS])
	
send_message(const id, const bool:bLog, const szInput[], any:...)
{
	static szMessage[192]
	vformat(szMessage, charsmax(szMessage), szInput, 4)
	
	#if defined USE_CSTRIKE
	bLog ? CC_LogMessage(id, _, szMessage) : CC_SendMessage(id, szMessage)
	#else
	format(szMessage, charsmax(szMessage), "%s %s", CC_PREFIX, szMessage)
	client_print(id, print_chat, szMessage)
	
	if(bLog)
		log_amx(szMessage)
	#endif
}

update_hudinfo(const id)
{
	if(!g_eSettings[HUDINFO_ENABLED])
		return
		
	static szMessage[MAX_HUDINFO_LENGTH], szPlaceHolder[32], bool:bIsOnFinal
	bIsOnFinal = g_ePlayerData[id][IsOnFinalLevel]
	copy(szMessage, charsmax(szMessage), g_eSettings[bIsOnFinal ? HUDINFO_FORMAT_FINAL : HUDINFO_FORMAT])
	
	if(has_argument(szMessage, ARG_CURRENT_XP))
	{
		num_to_str(g_ePlayerData[id][XP], szPlaceHolder, charsmax(szPlaceHolder))
		replace_all(szMessage, charsmax(szMessage), ARG_CURRENT_XP, szPlaceHolder)
	}
	
	if(has_argument(szMessage, ARG_NEXT_XP))
	{
		num_to_str(g_ePlayerData[id][NextXP], szPlaceHolder, charsmax(szPlaceHolder))
		replace_all(szMessage, charsmax(szMessage), ARG_NEXT_XP, szPlaceHolder)
	}
	
	if(has_argument(szMessage, ARG_XP_NEEDED))
	{
		num_to_str(g_ePlayerData[id][NextXP] - g_ePlayerData[id][XP], szPlaceHolder, charsmax(szPlaceHolder))
		replace_all(szMessage, charsmax(szMessage), ARG_XP_NEEDED, szPlaceHolder)
	}
	
	if(has_argument(szMessage, ARG_LEVEL))
	{
		num_to_str(g_ePlayerData[id][Level], szPlaceHolder, charsmax(szPlaceHolder))
		replace_all(szMessage, charsmax(szMessage), ARG_LEVEL, szPlaceHolder)
	}
	
	if(has_argument(szMessage, ARG_NEXT_LEVEL))
	{
		num_to_str(g_ePlayerData[id][bIsOnFinal ? Level : Level + 1], szPlaceHolder, charsmax(szPlaceHolder))
		replace_all(szMessage, charsmax(szMessage), ARG_NEXT_LEVEL, szPlaceHolder)
	}
	
	if(has_argument(szMessage, ARG_MAX_LEVELS))
		replace_all(szMessage, charsmax(szMessage), ARG_MAX_LEVELS, g_szMaxLevels)

	if(has_argument(szMessage, ARG_NAME))
	{
		get_user_name(id, szPlaceHolder, charsmax(szPlaceHolder))
		replace_all(szMessage, charsmax(szMessage), ARG_NAME, szPlaceHolder)
	}
	
	replace_all(szMessage, charsmax(szMessage), ARG_RANK, g_ePlayerData[id][Rank])
	replace_all(szMessage, charsmax(szMessage), ARG_NEXT_RANK, g_ePlayerData[id][NextRank])
	replace_all(szMessage, charsmax(szMessage), ARG_LINE_BREAK, "^n")
	
	copy(g_ePlayerData[id][HUDInfo], charsmax(g_ePlayerData[][HUDInfo]), szMessage)
}

bool:check_level(const id, const bool:bNotify)
{
	static iLevel, i
	iLevel = 0
	
	for(i = 1; i < g_iMaxLevels + 1; i++)
	{
		if(g_ePlayerData[id][XP] >= ArrayGetCell(g_aLevels, i))
			iLevel++
	}
	
	if(iLevel != g_ePlayerData[id][Level])
	{
		static bool:bLevelUp, iReturn
		bLevelUp = iLevel > g_ePlayerData[id][Level]
		g_ePlayerData[id][Level] = iLevel
		
		ExecuteForward(g_fwdUserLevelUpdated, iReturn, id, iLevel, bLevelUp)
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
				set_user_flags(id, g_eSettings[FINAL_LEVEL_FLAGS])
				remove_user_flags(id, g_iFlagZ)
			}
		}
			
		if(bNotify && g_eSettings[LEVELUP_MESSAGE_TYPE])
		{
			static szMessage[128], szName[32], bool:bGlobalMsg
			get_user_name(id, szName, charsmax(szName))
			bGlobalMsg = g_eSettings[LEVELUP_MESSAGE_TYPE] == 2
			
			formatex(szMessage, charsmax(szMessage), "%L", bGlobalMsg ? LANG_PLAYER : id,\
			bLevelUp ? "CRXRANKS_LEVEL_REACHED" : "CRXRANKS_LEVEL_LOST", szName, g_ePlayerData[id][Level], g_ePlayerData[id][Rank])
			send_message(bGlobalMsg ? 0 : id, false, szMessage)
			
			if(bLevelUp && g_eSettings[LEVELUP_SOUND][0])
				emit_sound(id, CHAN_AUTO, g_eSettings[LEVELUP_SOUND], 1.0, ATTN_NORM, 0, PITCH_NORM)
			else if(!bLevelUp && g_eSettings[LEVELDN_SOUND][0])
				emit_sound(id, CHAN_AUTO, g_eSettings[LEVELDN_SOUND], 1.0, ATTN_NORM, 0, PITCH_NORM)
				
			if(g_eSettings[bLevelUp ? LEVELUP_SCREEN_FADE_ENABLED : LEVELDN_SCREEN_FADE_ENABLED])
			{
				message_begin(MSG_ONE, g_iScreenFade, {0, 0, 0}, id)
				write_short(1<<10)
				write_short(1<<10)
				write_short(0x0000)
				
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
		
		update_hudinfo(id)
		return true
	}
	
	return false
}

public update_vip_status(id)
{
	if(g_eSettings[VIP_FLAGS_BIT] != ADMIN_ALL)
		g_ePlayerData[id][IsVIP] = bool:((get_user_flags(id) & g_eSettings[VIP_FLAGS_BIT]) == g_eSettings[VIP_FLAGS_BIT])
}

public plugin_natives()
{
	register_library("crxranks")
	register_native("crxranks_get_chat_prefix", 		"_crxranks_get_chat_prefix")
	register_native("crxranks_get_final_flags", 		"_crxranks_get_final_flags")
	register_native("crxranks_get_hudinfo_format", 		"_crxranks_get_hudinfo_format")
	register_native("crxranks_get_max_levels", 			"_crxranks_get_max_levels")
	register_native("crxranks_get_rank_by_level", 		"_crxranks_get_rank_by_level")
	register_native("crxranks_get_save_type", 			"_crxranks_get_save_type")
	register_native("crxranks_get_user_hudinfo", 		"_crxranks_get_user_hudinfo")
	register_native("crxranks_get_user_level", 			"_crxranks_get_user_level")
	register_native("crxranks_get_user_next_rank", 		"_crxranks_get_user_next_rank")
	register_native("crxranks_get_user_next_xp", 		"_crxranks_get_user_next_xp")
	register_native("crxranks_get_user_rank", 			"_crxranks_get_user_rank")
	register_native("crxranks_get_user_xp", 			"_crxranks_get_user_xp")
	register_native("crxranks_get_vault_name", 			"_crxranks_get_vault_name")
	register_native("crxranks_get_vip_flags", 			"_crxranks_get_vip_flags")
	register_native("crxranks_get_xp_for_level", 		"_crxranks_get_xp_for_level")
	register_native("crxranks_get_xp_reward", 			"_crxranks_get_xp_reward")
	register_native("crxranks_give_user_xp",	 		"_crxranks_give_user_xp")
	register_native("crxranks_hi_is_using_dhud",		"_crxranks_hi_is_using_dhud")
	register_native("crxranks_is_hud_enabled", 			"_crxranks_is_hud_enabled")
	register_native("crxranks_is_sfdn_enabled", 		"_crxranks_is_sfdn_enabled")
	register_native("crxranks_is_sfup_enabled", 		"_crxranks_is_sfup_enabled")
	register_native("crxranks_is_user_on_final", 		"_crxranks_is_user_on_final")
	register_native("crxranks_is_user_vip",				"_crxranks_is_user_vip")
	register_native("crxranks_is_xpn_enabled", 			"_crxranks_is_xpn_enabled")
	register_native("crxranks_using_comb_events",		"_crxranks_using_comb_events")
	register_native("crxranks_xpn_is_using_dhud",		"_crxranks_xpn_is_using_dhud")
}

public _crxranks_get_chat_prefix(iPlugin, iParams)
	set_string(1, CC_PREFIX, get_param(2))

public _crxranks_get_final_flags(iPlugin, iParams)
{
	set_string(1, g_eSettings[FINAL_LEVEL_FLAGS], get_param(2))
	return g_eSettings[FINAL_LEVEL_FLAGS_BIT]
}

public _crxranks_get_hudinfo_format(iPlugin, iParams)
	set_string(2, g_eSettings[get_param(1) ? HUDINFO_FORMAT_FINAL : HUDINFO_FORMAT], get_param(3))
	
public _crxranks_get_max_levels(iPlugin, iParams)
	return g_iMaxLevels
	
public _crxranks_get_rank_by_level(iPlugin, iParams)
{
	static iLevel
	iLevel = get_param(1)
	
	if(iLevel < 1 || iLevel > g_iMaxLevels)
		return 0
		
	static szRank[MAX_RANK_LENGTH]
	ArrayGetString(g_aRankNames, iLevel, szRank, charsmax(szRank))
	set_string(2, szRank, get_param(3))
	return 1
}

public _crxranks_get_save_type(iPlugin, iParams)
	return g_eSettings[SAVE_TYPE]

public _crxranks_get_user_hudinfo(iPlugin, iParams)
	set_string(2, g_ePlayerData[get_param(1)][HUDInfo], get_param(3))
	
public _crxranks_get_user_level(iPlugin, iParams)
	return g_ePlayerData[get_param(1)][Level]
	
public _crxranks_get_user_next_rank(iPlugin, iParams)
	set_string(2, g_ePlayerData[get_param(1)][NextRank], get_param(3))
	
public _crxranks_get_user_next_xp(iPlugin, iParams)
	return g_ePlayerData[get_param(1)][NextXP]	
	
public _crxranks_get_user_rank(iPlugin, iParams)
	set_string(2, g_ePlayerData[get_param(1)][Rank], get_param(3))
	
public _crxranks_get_user_xp(iPlugin, iParams)
	return g_ePlayerData[get_param(1)][XP]
	
public _crxranks_get_vault_name(iPlugin, iParams)
	set_string(1, g_eSettings[VAULT_NAME], get_param(2))
	
public _crxranks_get_vip_flags(iPlugin, iParams)
{
	set_string(1, g_eSettings[VIP_FLAGS], get_param(2))
	return g_eSettings[VIP_FLAGS_BIT]
}
	
public _crxranks_get_xp_for_level(iPlugin, iParams)
{
	static iLevel
	iLevel = get_param(1)
	
	if(iLevel < 1 || iLevel > g_iMaxLevels)
		return -1
		
	return ArrayGetCell(g_aLevels, iLevel)
}

public _crxranks_get_xp_reward(iPlugin, iParams)
{
	static szReward[MAX_XP_REWARD_LENGTH]
	get_string(2, szReward, charsmax(szReward))
	return get_xp_reward(get_param(1), szReward)
}
	
public _crxranks_give_user_xp(iPlugin, iParams)
{
	static szReward[MAX_XP_REWARD_LENGTH], iReward, id
	szReward[0] = EOS
	get_string(3, szReward, charsmax(szReward))
	id = get_param(1)
	
	if(szReward[0])
	{
		iReward = get_xp_reward(id, szReward)
		
		if(iReward)
			give_user_xp(id, iReward, CRXRanks_XPSources:get_param(3))
			
		return iReward
	}
	
	iReward = get_param(2)
	give_user_xp(id, iReward, CRXRanks_XPSources:get_param(3))
	return iReward
}

public bool:_crxranks_hi_is_using_dhud(iPlugin, iParams)
	return g_eSettings[HUDINFO_USE_DHUD]

public bool:_crxranks_is_hud_enabled(iPlugin, iParams)
	return g_eSettings[HUDINFO_ENABLED]
	
public bool:_crxranks_is_sfdn_enabled(iPlugin, iParams)
	return g_eSettings[LEVELDN_SCREEN_FADE_ENABLED]

public bool:_crxranks_is_sfup_enabled(iPlugin, iParams)
	return g_eSettings[LEVELUP_SCREEN_FADE_ENABLED]

public bool:_crxranks_is_user_on_final(iPlugin, iParams)
	return g_ePlayerData[get_param(1)][IsOnFinalLevel]
	
public bool:_crxranks_is_user_vip(iPlugin, iParams)
	return g_ePlayerData[get_param(1)][IsVIP]
	
public bool:_crxranks_is_xpn_enabled(iPlugin, iParams)
	return g_eSettings[XP_NOTIFIER_ENABLED]
	
public bool:_crxranks_using_comb_events(iPlugin, iParams)
	return g_eSettings[USE_COMBINED_EVENTS]
	
public bool:_crxranks_xpn_is_using_dhud(iPlugin, iParams)
	return g_eSettings[XP_NOTIFIER_USE_DHUD]
