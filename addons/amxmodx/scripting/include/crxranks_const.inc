#if defined _crxranks_const_included
    #endinput
#endif

#define _crxranks_const_included

/**
 * Plugin-specific return codes
 */
#define CRXRANKS_CONTINUE 900300
#define CRXRANKS_HANDLED 900301

/**
 * Save types for crxranks_get_save_type()
 */
enum CRXRanks_SaveTypes
{
	CRXRANKS_ST_NICKNAME = 0,
	CRXRANKS_ST_IP,
	CRXRANKS_ST_STEAMID
}

/**
 * Types of sources when receiving XP
 */
enum CRXRanks_XPSources
{
	CRXRANKS_XPS_PLUGIN = 0,
	CRXRANKS_XPS_REWARD,
	CRXRANKS_XPS_ADMIN
}