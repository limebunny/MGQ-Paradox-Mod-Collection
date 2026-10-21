#==============================================================================
# 00_Data.rbx
# Character Creation — trait data tables.
# Edit this file to add or retune traits.
#==============================================================================

module CharacterCreation
  module TraitData
    HAND_COSTS = {
      :stat_10 => 3, :stat_20 => 5,
      :hit_10 => 3, :hit_20 => 6,
      :crit_10 => 4, :crit_30 => 8,
      :evasion_10 => 5, :evasion_20 => 10,
      :magic_evasion_10 => 5, :magic_evasion_20 => 10,
      :physical_counter_10 => 4, :physical_counter_30 => 8,
      :magic_counter_10 => 4, :magic_counter_30 => 8,
      :counter_damage_100 => 8,
      :hp_regen_5 => 5, :hp_regen_10 => 10,
      :mp_regen_1 => 5, :mp_regen_2 => 10,
      :sp_regen_5 => 5, :sp_regen_10 => 10,
      :hp_cost_50 => 10,
      :mp_cost_75 => 30,
      :sp_cost_75 => 30,
      :gold_cost_50 => 10,
      :weapon_booster_15 => 10, :weapon_booster_30 => 20,
      :pinch_booster_100 => 15, :pinch_booster_200 => 30,
      :element_booster_t1_15 => 8,  :element_booster_t1_30 => 16, :element_booster_t1_50 => 24,
      :element_booster_t2_15 => 8,  :element_booster_t2_30 => 16, :element_booster_t2_50 => 24,
      :element_booster_t3_15 => 10, :element_booster_t3_30 => 20, :element_booster_t3_50 => 30,
      :element_resist_t1 => 5,  :element_resist_t2 => 5,  :element_resist_t3 => 10,
      :element_half_t1   => 10, :element_half_t2   => 10, :element_half_t3   => 20,
      :status_strike_10 => 5, :status_strike_25 => 10,
      :status_resist => 4, :status_nullify => 10,
      :magic_reflect_10 => 4, :magic_reflect_30 => 8,
      :mug => 5, :learning => 25, :nightmare => 25,
      :slayer_species => 10,
      :slayer_boss_15 => 15, :slayer_boss_30 => 25,
      :slayer_booster => 25,
      :chain_mag_combat => 80, :chain_job_combat => 80, :chain_job_magic  => 80,
      :chain_race_combat => 80, :chain_mag_race   => 80, :chain_job_race   => 80,
      :chain_cost_down => 25, :chain_boost => 25,
      :dual_wield => 25, :dual_shield => 25,
      :multi_strike_type => 30,
      :steal_rate_50 => 8, :steal_rate_100 => 20,
      :party_stats_10 => 40, :party_stats_20 => 75,
      :party_hpmp_10 => 40, :party_hpmp_20 => 75,
    }.freeze

    STATS = [
      [:max_hp, "Max HP", 0, 1], [:max_mp, "Max MP", 1, 3], [:max_sp, "Max SP", 1, 2],
      [:attack, "Attack", 2, 1], [:defense, "Defense", 3, 4], [:magic, "Magic", 4, 3],
      [:willpower, "Willpower", 5, 4], [:agility, "Agility", 6, 2], [:dexterity, "Dexterity", 7, 2],
    ].freeze

    ELEMENTS = [
      [:fire, "Fire", 3, 1], [:ice, "Ice", 4, 1], [:lightning, "Lightning", 5, 1],
      [:wind, "Wind", 6, 1], [:earth, "Earth", 7, 1], [:water, "Water", 8, 1],
      [:bio, "Bio", 36, 2], [:sonic, "Sonic", 35, 2],
      [:physical, "Physical", 1, 3], [:pleasure, "Pleasure", 2, 3], [:holy, "Holy", 9, 3], [:dark, "Dark", 10, 3],
      [:nuclear, "Nuclear", 43, 4], [:quantum, "Quantum", 44, 4], [:ion, "Ion", 45, 4],
      [:hadron, "Hadron", 46, 4], [:terra, "Terra", 47, 4], [:nano, "Nano", 48, 4],
      [:carnage, "Carnage", 51, 5], [:nightmare, "Nightmare", 52, 5], [:eternal, "Eternal", 49, 5],
      [:demise, "Demise", 50, 5], [:galactic, "Galactic", 41, 5],
      [:recovery, "Recovery", 38, 0], [:gravity, "Gravity", 40, 0]
    ].freeze

    SKILL_TYPES = [
      [6, "Dagger"], [7, "Sword"], [8, "Rapier"], [9, "Katana"], [10, "Spear"], [11, "Axe"],
      [12, "Club"], [13, "Scythe"], [14, "Bow"], [15, "Whip"], [16, "Boomerang"], [17, "Flail"],
      [18, "Fan"], [19, "Gun"], [20, "Multiweapon"], [21, "Unarmed"], [22, "White Magic"],
      [23, "Black Magic"], [24, "Time Magic"], [25, "Summoning"], [26, "Holy"], [27, "Dark"],
      [28, "Spellblade"], [29, "Taoism"], [30, "Thievery"], [31, "Ninjutsu"], [32, "Piracy"],
      [33, "Justice"], [34, "Mercantile"], [35, "EX Item"], [36, "Oracle"], [37, "Dancing"],
      [38, "Singing"], [39, "Talk"], [40, "Magic Science"], [41, "Alchemy"], [42, "Grimoire"],
      [43, "Makina"], [44, "Cooking"], [45, "Medicine"], [46, "Service"], [47, "Ruling"],
      [48, "Heroism"], [49, "Sexcraft"], [50, "Demon Arts"], [51, "Ocean"], [52, "Slime"],
      [53, "Beast"], [54, "Snake"], [55, "Tentacle"], [56, "Wing"], [57, "Insect"],
      [58, "Plant"], [59, "Corpse"], [60, "Artificial"], [61, "Nature"], [62, "Breath"],
      [63, "Special"], [67, "Psychic"], [68, "Sorcery"], [69, "Giant"]
    ].freeze

    SLAYER_CATEGORIES = [
      [11, :human, "Human", 100, 1], [12, :yoma, "Yoma", 100, 1], [13, :demi_human, "Demi-Human", 100, 1],
      [14, :succubus, "Succubus", 100, 3], [15, :vampire, "Vampire", 100, 3], [16, :mermaid, "Mermaid", 100, 3],
      [17, :elf, "Elf", 100, 3], [18, :fairy, "Fairy", 100, 3], [19, :slime, "Slime", 100, 5],
      [20, :beast, "Beast", 100, 5], [21, :kitsune, "Kitsune", 100, 5], [22, :lamia, "Lamia", 100, 5],
      [23, :scylla, "Scylla", 100, 5], [24, :harpy, "Harpy", 100, 5], [25, :dragon, "Dragon", 100, 5],
      [26, :land_dweller, "Land-Dweller", 100, 5], [27, :sea_dweller, "Sea-Dweller", 100, 5],
      [28, :insect, "Insect", 100, 5], [29, :plant, "Plant", 100, 5], [30, :zombie, "Zombie", 100, 5],
      [31, :ghost, "Ghost", 100, 5], [32, :doll, "Doll", 100, 5], [33, :chimera, "Chimera", 100, 5],
      [34, :angel, "Angel", 100, 3], [35, :apoptosis, "Apoptosis", 100, 5], [38, :roid, "Roid", 100, 5],
      [40, :flying, "Flying", 100, 1],
    ].freeze

    STATES = [
      [:death, "Death", 230], [:ascension, "Ascension", 231], [:climax, "Climax", 232],
      [:bind, "Bind", 28], [:poison, "Poison", 7], [:blind, "Blind", 8], [:silence, "Silence", 9],
      [:confusion, "Confusion", 10], [:sleep, "Sleep", 11], [:paralysis, "Paralysis", 12],
      [:burn, "Burn", 13], [:freeze, "Freeze", 14], [:shock, "Shock", 15], [:slow, "Slow", 16],
      [:stop, "Stop", 17], [:mini, "Mini", 18], [:zombie, "Zombie", 19], [:petrify, "Petrify", 20],
      [:digest, "Digest", 21], [:stun, "Stun", 22], [:slimed, "Slimed", 23], [:horny, "Horny", 24],
      [:trance, "Trance", 25], [:seduction, "Seduction", 26], [:incontinence, "Incontinence", 27]
    ].freeze

    WEAPONS = [
      [1, "Dagger", 1], [2, "Sword", 1], [3, "Knight Sword", 1], [4, "Great Sword", 1],
      [5, "Rapier", 1], [6, "Magic Sword", 3], [7, "Spear", 1], [8, "Heavy Spear", 1],
      [9, "Katana", 1], [10, "Ninja Sword", 1], [11, "Fist", 1], [12, "Fang", 1],
      [13, "Axe", 1], [14, "Club", 1], [15, "Scythe", 1], [16, "Staff", 3],
      [17, "Rod", 3], [18, "Bow", 1], [19, "Whip", 1], [20, "Harp", 2],
      [21, "Boomerang", 1], [22, "Flail", 1], [23, "Fan", 1], [24, "Kitchen Knife", 2],
      [25, "Abacus", 2], [26, "Scalpel", 2], [27, "Card", 2], [28, "Plate", 2],
      [29, "Grimoire", 3], [30, "Gun", 1], [31, "Sex Toy", 2]
    ].freeze

    ARMORS = [
      [1, "Clothes", 4], [2, "Gi", 4], [3, "Breastplate", 4], [4, "Armor", 4], [5, "Heavy Armor", 4],
      [6, "Shell", 4], [7, "Robe", 4], [8, "Dress", 4], [9, "Skimpy", 4], [10, "Yoma", 4],
      [11, "Demi-Human", 4], [12, "Succubus", 4], [13, "Vampire", 4], [14, "Mermaid", 4],
      [15, "Elf", 4], [16, "Fairy", 4], [17, "Slime", 4], [18, "Beast", 4], [19, "Kitsune", 4],
      [20, "Lamia", 4], [21, "Scylla", 4], [22, "Harpy", 4], [23, "Dragon", 4], [24, "Land-Dweller", 4],
      [25, "Sea-Dweller", 4], [26, "Insect", 4], [27, "Plant", 4], [28, "Zombie", 4], [29, "Ghost", 4],
      [30, "Doll", 4], [31, "Chimera", 4], [32, "Angel", 4], [33, "Hat", 4], [34, "Helmet", 4],
      [35, "Heavy Helmet", 4], [36, "Magic Hat", 4], [37, "Fancy Cap", 4], [38, "Buckler", 4],
      [39, "Shield", 4], [40, "Heavy Shield", 4], [41, "Accessory", 4]
    ].freeze

    FEATURE_ELEMENT_RATE        = 11; FEATURE_DEBUFF_RATE         = 12
    FEATURE_STATE_RATE          = 13; FEATURE_STATE_RESIST        = 14
    FEATURE_PARAM               = 21; FEATURE_XPARAM              = 22
    FEATURE_SPARAM              = 23; FEATURE_ATK_ELEMENT         = 31
    FEATURE_ATK_STATE           = 32; FEATURE_ATK_SPEED           = 33
    FEATURE_ATK_TIMES           = 34; FEATURE_STYPE_ADD           = 41
    FEATURE_STYPE_SEAL          = 42; FEATURE_SKILL_ADD           = 43
    FEATURE_SKILL_SEAL          = 44; FEATURE_EQUIP_WTYPE         = 51
    FEATURE_EQUIP_ATYPE         = 52; FEATURE_EQUIP_FIX           = 53
    FEATURE_EQUIP_SEAL          = 54; FEATURE_SLOT_TYPE           = 55
    FEATURE_ACTION_PLUS         = 61; FEATURE_SPECIAL_FLAG        = 62
    FEATURE_COLLAPSE_TYPE       = 63; FEATURE_PARTY_ABILITY       = 64

    FEATURE_XPARAM_EX                 = 66; FEATURE_PARTY_EX_ABILITY          = 67
    FEATURE_BATTLER_ABILITY           = 68; FEATURE_MULTI_BOOSTER             = 69
    FEATURE_DUMMY_ENCHANT             = 70; FEATURE_TERRAIN_BOOSTER           = 71
    FEATURE_EQUIP_MASTERY             = 72; FEATURE_SKILL_STATE_ADD           = 73
    FEATURE_SKILL_TYPE_STATE_ADD      = 74; FEATURE_SUCCUBUS                  = 75
    FEATURE_ALL_ADD_ELEMENT           = 76; FEATURE_PENETRATION_ELEMENT       = 77
    FEATURE_EX_CATEGORY_ATTACK        = 78; FEATURE_EX_CATEGORY_DEFENCE       = 79
    FEATURE_STYPE_ADD_PARAM           = 80; FEATURE_SKILL_COMBO               = 81
    FEATURE_SKILL_TYPE_COMBO          = 82; FEATURE_ADD_ELEMENT               = 83
    FEATURE_EX_CATEGORY_ATTACK_BONUS  = 84; FEATURE_SKILL_PLUS_ATTACK         = 85
    FEATURE_SKILL_TYPE_PLUS_ATTACK    = 86; FEATURE_STATE_RATE_FIX            = 87
    FEATURE_ELEMENT_RATE_FIX          = 88; FEATURE_AUTO_SKILL_INVALID        = 89
    FEATURE_SKILL_PLUS_ATTACK_ONE           = 90; FEATURE_SKILL_TYPE_PLUS_ATTACK_ONE      = 91
    FEATURE_SKILL_PLUS_ATTACK_ONE_RANDOM    = 92; FEATURE_SKILL_TYPE_PLUS_ATTACK_ONE_RANDOM = 93
    FEATURE_SKILL_SCOPE_ALL           = 94; FEATURE_SKILL_TYPE_SCOPE_ALL      = 95
    FEATURE_SKILL_SCOPE_ONE           = 96; FEATURE_SKILL_TYPE_SCOPE_ONE      = 97
    FEATURE_ENEMY_MULTI_SKILL_BOOST         = 98; FEATURE_ENEMY_MULTI_SKILL_TYPE_BOOST    = 99
    FEATURE_ENEMY_SINGLE_SKILL_BOOST        = 100; FEATURE_ENEMY_SINGLE_SKILL_TYPE_BOOST   = 101
    FEATURE_WEAPON_TYPE_ATTACK_BOOST        = 102; FEATURE_ARMOR_TYPE_DEFENCE_BOOST        = 103
    FEATURE_STATE_EFFECT_BOOST        = 104; FEATURE_STATE_DAMAGE_BOOST        = 105
    FEATURE_WIELD_BOOST               = 106; FEATURE_BATTLE_START_STATE        = 107
    FEATURE_MULTI_ELEMENT             = 108; FEATURE_PARAM_NEUTRALIZE          = 109
    FEATURE_COST_ZERO                 = 110; FEATURE_SKILL_COST_ZERO           = 111
    FEATURE_SKILL_TYPE_COST_ZERO      = 112; FEATURE_PARAM_STATE               = 113
    FEATURE_SAME_ELEMENT_DAMAGE_BOOST = 114; FEATURE_STATE_BOOST_PLUS          = 115
    FEATURE_LEARNING                  = 116; FEATURE_EX_CATEGORY               = 117
    FEATURE_FAST_MOVE_ALL             = 118; FEATURE_SLOW_MOVE_ALL             = 119
    FEATURE_SKILL_TYPE_DEFENCE_PENETRATION = 120; FEATURE_DUAL_SHIELD_ADD_ABILITY   = 121
    FEATURE_STATE_CHAIN               = 122; FEATURE_FULL_HP_BOOST             = 123
    FEATURE_FULL_HP_SKILL_BOOST       = 124; FEATURE_FULL_HP_SKILL_TYPE_BOOST  = 125
    FEATURE_MAX_AP_RATE               = 126; FEATURE_SKILL_CHAIN               = 127
    FEATURE_SKILL_CHAIN_BOOST         = 128; FEATURE_SKILL_CHAIN_COST_RATE     = 129
    FEATURE_ITEM_COST_RATE            = 130; FEATURE_ITEM_GET_RATE             = 131
    FEATURE_SKILL_COUNTER_EX          = 132; FEATURE_SKILL_TIMING_BOOST        = 133
    FEATURE_SKILL_TIMING_REPEAT       = 134; FEATURE_TURN_END_REVIVE           = 135
    FEATURE_FULL_SP_BOOST             = 136; FEATURE_FULL_MP_BOOST             = 137
    FEATURE_UNDEAD                    = 138; FEATURE_SKILL_UNSTOPPABLE         = 140
    FEATURE_SKILL_TYPE_UNSTOPPABLE    = 141; FEATURE_ELEMENT_DRAIN             = 142
    FEATURE_MAGICAL_CRITICAL          = 143; FEATURE_FULL_SP_STYPE_BOOST       = 144
    FEATURE_FULL_MP_STYPE_BOOST       = 145; FEATURE_ADD_STEAL_STYPE           = 146
    FEATURE_ADD_RESTORATION           = 147; FEATURE_ADD_RESTORATION_STYPE_HP  = 148
    FEATURE_ADD_RESTORATION_STYPE_MP  = 149; FEATURE_ADD_SPEED                 = 150
    FEATURE_ADD_SPEED_PARAM_RATE      = 151; FEATURE_ADD_DUMMY_ENCHANT         = 152
    FEATURE_AUTO_REVIVE               = 153; FEATURE_BLOCK_RATE                = 154
    FEATURE_ID_ITEM_BOOST             = 155; FEATURE_STYPE_ITEM_COST_RATE      = 156
    FEATURE_STYPE_ITEM_GET_RATE       = 157; FEATURE_ONCE_TURN_END_STATE       = 158
    FEATURE_DAMAGE_BOOST              = 159; FEATURE_SINGLE_SKILL_BOOST        = 160
    FEATURE_STYPE_COUNTER_EX          = 161; FEATURE_FAST_MOVE_SID             = 162
    FEATURE_FAST_MOVE_STYPE           = 163; FEATURE_SLOW_MOVE_SID             = 164
    FEATURE_SLOW_MOVE_STYPE           = 165; FEATURE_ADD_STEAL_SID             = 166
    FEATURE_ADD_ELEMENT_STYPE         = 167; FEATURE_ADD_ELEMENT_SID           = 168
    FEATURE_HIT_DAMAGE_BOOST          = 169; FEATURE_TURN_HIT_DAMAGE_RATE      = 170
    FEATURE_MAX_AP_BONUS              = 171; FEATURE_EX_CATEGORY_STYPE         = 172
    FEATURE_REDUCE_BOOST_DAMAGE       = 173; FEATURE_ALTERNATE_TP_TO_MP        = 174
    FEATURE_XPARAM_FIX                = 175; FEATURE_PARTY_PARAM_BOOST         = 176
    FEATURE_VARIABLE_HP_DAMAGE        = 177; FEATURE_AUTO_SKILL_PRIORITY_INVALID  = 178
    FEATURE_AUTO_SKILL_CONDITION_INVALID = 179; FEATURE_ACTION_MINUS              = 180

    BATTLER_STEAL_SUCCESS = 0; BATTLER_AUTO_STAND = 1; BATTLER_HEEL_REVERSE = 2; BATTLER_AUTO_STATE = 3
    BATTLER_TRIGGER_STATE = 4; BATTLER_METAL_BODY = 5; BATTLER_DEFENSE_WALL = 6; BATTLER_INVALIDATE_WALL = 7
    BATTLER_DAMAGE_MP_CONVERT = 8; BATTLER_DAMAGE_GOLD_CONVERT = 9; BATTLER_DAMAGE_MP_DRAIN = 10
    BATTLER_DAMAGE_GOLD_DRAIN = 11; BATTLER_DEAD_SKILL = 12; BATTLER_BATTLE_START_SKILL = 13
    BATTLER_TURN_START_SKILL = 14; BATTLER_TURN_END_SKILL = 15; BATTLER_CHANGE_ACTION = 16
    BATTLER_STYPE_COST_RATE = 17; BATTLER_SKILL_COST_RATE = 18; BATTLER_TP_COST_RATE = 19
    BATTLER_HP_COST_RATE = 20; BATTLER_GOLD_COST_RATE = 21; BATTLER_INCREASE_TP = 22
    BATTLER_START_TP_RATE = 23; BATTLER_BATTLE_END_HEEL_HP = 24; BATTLER_BATTLE_END_HEEL_MP = 25
    BATTLER_NORMAL_ATTACK = 26; BATTLER_COUNTER_SKILL = 27; BATTLER_FINAL_INVOKE = 28
    BATTLER_CERTAIN_COUNTER = 29; BATTLER_MAGICAL_COUNTER = 30; BATTLER_PHYSICAL_COUNTER_EX = 31
    BATTLER_MAGICAL_COUNTER_EX = 32; BATTLER_CERTAIN_COUNTER_EX = 33; BATTLER_CONSIDERATE = 34
    BATTLER_GET_EXP_RATE = 35; BATTLER_GET_CLASSEXP_RATE = 36; BATTLER_INVOKE_REPEATS_TYPE = 37
    BATTLER_INVOKE_REPEATS_SKILL = 38; BATTLER_OWN_CRUSH_RESIST = 39; BATTLER_IGNORE_OVER_DRIVE = 40
    BATTLER_INSTANT_DEAD_REVERSE = 41; BATTLER_CHANGE_SKILL = 42; BATTLER_ITEM_COST_SCRIMP = 43
    BATTLER_NEED_ITEM_IGNORE = 44; BATTLER_PHYSICAL_REFLECTION = 45; BATTLER_SLOT_CANNOT_DUAL_WIELD = 46
    BATTLER_HP_REGEN_INVALID = 48; BATTLER_CANT_MOVE = 49; BATTLER_BATTLE_START_HP = 50
    BATTLER_CERTAIN_DAMAGE_RATE = 54; BATTLER_ELEMENT_REFLECTION = 55; BATTLER_SELF_STATE_ETERNAL = 56
    BATTLER_TARGET_STATE_ETERNAL = 57; BATTLER_EQUIP_ABILITY_BOOST = 58; BATTLER_ITEM_COST_SCRIMP_TYPE = 59
    BATTLER_NORMAL_ATTACK_FORCE_ELEMENT = 60; BATTLER_CERTAIN_REFLECTION = 61; BATTLER_GET_EXP_RATE_STATE = 62
    BATTLER_GET_CLASSEXP_RATE_STATE = 63; BATTLER_MAGICAL_COUNTER_SKILL = 64; BATTLER_CERTAIN_COUNTER_SKILL = 65
    BATTLER_COUNTER_EX_SKILL = 66; BATTLER_MAGICAL_COUNTER_EX_SKILL = 67; BATTLER_CERTAIN_COUNTER_EX_SKILL = 68
    BATTLER_EVASION_SKILL = 69; BATTLER_AUTO_STATE_WITH_SWITCH = 70

    BOOSTER_ELEMENT = 0; BOOSTER_WEAPON_PHYSICAL = 1; BOOSTER_WEAPON_MAGICAL = 2; BOOSTER_WEAPON_CERTAIN = 3
    BOOSTER_NORMAL_ATTACK = 4; BOOSTER_STATE_RATIO_TYPE = 5; BOOSTER_STATE_FIX_TYPE = 6; BOOSTER_SKILL_TYPE = 7
    BOOSTER_STATE_RATIO_SKILL = 8; BOOSTER_SKILL = 9; BOOSTER_WTYPE_SKILL = 10; BOOSTER_COUNTER = 11
    BOOSTER_FALL_HP = 12; BOOSTER_OVER_SOUL = 13; BOOSTER_REFLECTION = 14; BOOSTER_CRITICAL = 15
    BOOSTER_ACTOR_PARAM = 16; BOOSTER_ACTOR_EXIST_PARAM = 17; BOOSTER_CLASS = 18; BOOSTER_EQUIP_ABILITY = 19
    BOOSTER_SELF_STATE = 20; BOOSTER_TARGET_STATE = 21; BOOSTER_STATE_SKILL = 22; BOOSTER_STATE_SKILL_TYPE = 23
    BOOSTER_STATE_NORMAL_ATACK = 24; BOOSTER_PINCHI_SKILL = 25; BOOSTER_PINCHI_SKILL_TYPE = 26
    BOOSTER_BATTLE_COUNT = 27; BOOSTER_ACTOR_DEFEAT = 28; BOOSTER_ACTOR_CARRY = 29; BOOSTER_ACTOR_DOWN = 30
    BOOSTER_ACTOR_ORGASM = 31; BOOSTER_ACTOR_STEAL = 32; BOOSTER_ACTOR_LOVE = 33; BOOSTER_ENEMY_MULTI = 34
    BOOSTER_ENEMY_SIGNLE = 35; BOOSTER_ITEM_DAMAGE = 36

    PARTYEX_GET_GOLD_RATE = 0; PARTYEX_GET_ITEM_RATE = 1; PARTYEX_ENCOUNTER_RATE = 2; PARTYEX_COLLECT_RATE = 3
    PARTYEX_SLOT_CHANCE = 4; PARTYEX_UNLOCK_LEVEL = 5; PARTYEX_GET_GOLD_RATE_STATE = 10
    PARTYEX_GET_ITEM_RATE_STATE = 11; PARTYEX_COLLECT_RATE_STATE = 13

    XPARAM_HIT = 0; XPARAM_EVASION = 1; XPARAM_CRITICAL = 2; XPARAM_CRITICAL_EV = 3
    XPARAM_MAGIC_EV = 4; XPARAM_MAGIC_REFL = 5; XPARAM_COUNTER = 6
    XPARAM_HP_REGEN = 7; XPARAM_MP_REGEN = 8; XPARAM_TP_REGEN = 9

    SPARAM_TARGET_RATE = 0; SPARAM_GUARD_RATE = 1; SPARAM_RECOVERY_RATE = 2; SPARAM_PHARMACOLOGY = 3
    SPARAM_MP_COST_RATE = 4; SPARAM_TP_CHARGE_RATE = 5; SPARAM_PHYSICAL_DAMAGE = 6
    SPARAM_MAGICAL_DAMAGE = 7; SPARAM_FLOOR_DAMAGE = 8; SPARAM_EXP_RATE = 9

    STATE_RESIST_RATE = 0.5
    STATE_RESIST_NULL = 0.0
  end
end