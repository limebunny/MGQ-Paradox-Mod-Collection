#==============================================================================
# CC_Data_Traits.rbx
# Character Creation — trait data, catalogue, dashboard, and audit.
#
# Combines:
#   CC_11a_TraitData.rb       (costs, element tables, feature codes)
#   CC_11b_TraitFeatures.rb   (catalogue builder + display_lines)
#   CC_12_TraitDashboard.rb   (scene + windows for trait editing)
#   CC_13_TraitAudit.rb       (F7 audit helpers)
#
# Provides:
#   CharacterCreation::TraitData
#   CharacterCreation::TraitLibrary     (Hero's Blood, Slime Body)
#   CharacterCreation::TraitFeatures
#   CharacterCreation::Scene_TraitDashboard (+ its windows)
#   CharacterCreation::TraitAudit
#==============================================================================

module CharacterCreation
  #=== TraitData ============================================================
  module TraitData
    HAND_COSTS = {
      # --- Stats ---
      :stat_10 => 3, :stat_20 => 5, :stat_30 => 7, :stat_40 => 10,
      :hit_10 => 3, :hit_20 => 6, :hit_30 => 9, :hit_40 => 12,
      :crit_10 => 4, :crit_30 => 8,# :crit_50 => 12,
      :evasion_10 => 5, :evasion_20 => 10,# :evasion_30 => 15,
      :magic_evasion_10 => 5, :magic_evasion_20 => 10,# :magic_evasion_30 => 15,
      :physical_counter_10 => 4, :physical_counter_30 => 8,# :physical_counter_50 => 12,
      :magic_counter_10 => 4, :magic_counter_30 => 8,# :magic_counter_50 => 12,
      #:counter_damage_100 => 8,
      :hp_regen_5 => 5, :hp_regen_10 => 10,# :hp_regen_20 => 20, :hp_regen_30 => 30,
      :mp_regen_1 => 5, :mp_regen_2 => 10,# :mp_regen_4 => 20, :mp_regen_8 => 30,
      :sp_regen_5 => 5, :sp_regen_10 => 10,# :sp_regen_20 => 20, :sp_regen_30 => 30,

      # --- Costs ---
      :hp_cost_50 => 10,
      :mp_cost_75 => 30,
      :sp_cost_75 => 30,
      :gold_cost_50 => 10,

      # --- Weapon / Skill ---
      :weapon_booster_15 => 10, :weapon_booster_30 => 20,# :weapon_booster_50 => 30,
      :pinch_booster_100 => 20, :pinch_booster_200 => 40,# :pinch_booster_300 => 60,

      # --- Tiered Element Boosters ---
      :element_booster_t1_15 => 8,  :element_booster_t1_30 => 16, :element_booster_t1_50 => 24,
      :element_booster_t2_15 => 8,  :element_booster_t2_30 => 16, :element_booster_t2_50 => 24,
      :element_booster_t3_15 => 10, :element_booster_t3_30 => 20, :element_booster_t3_50 => 30,

      # --- Tiered Element Resists ---
      :element_resist_t1 => 5,  :element_resist_t2 => 5,  :element_resist_t3 => 10,
      :element_half_t1   => 10, :element_half_t2   => 10, :element_half_t3   => 20,

      # --- Status ---
      :status_strike_10 => 5, :status_strike_25 => 10,# :status_strike_50 => 15,
      :status_effect_50 => 20,
      :status_resist => 4, :status_nullify => 10,
      :magic_reflect_10 => 4, :magic_reflect_30 => 8,# :magic_reflect_50 => 15,
      :mug => 5, :learning => 10, :nightmare => 20,

      # --- Slayers ---
      :slayer_species => 10,
      :slayer_boss_15 => 15, :slayer_boss_30 => 25,
      :slayer_booster => 25,

      # --- Chains ---
      :chain_mag_combat => 60,
      :chain_job_combat => 60,
      :chain_job_magic  => 60,
      :chain_race_combat => 60,
      :chain_mag_race   => 60,
      :chain_job_race   => 60,
      :chain_cost_down => 15, :chain_boost => 15,

      # --- Action ---
      :dual_wield => 25, :dual_shield => 25,
      :multi_strike_type => 30,
      # :steal_rate_50 => 8, :steal_rate_100 => 20,
      # :party_stats_10 => 40, :party_stats_20 => 75,
      # :party_hpmp_10 => 40, :party_hpmp_20 => 75,
    }.freeze

    STATS = [
      [:max_hp, "Max HP", 0, 1], [:max_mp, "Max MP", 1, 3], [:max_sp, "Max SP", 1, 2],
      [:attack, "Attack", 2, 1], [:defense, "Defense", 3, 4], [:magic, "Magic", 4, 3],
      [:willpower, "Willpower", 5, 4], [:agility, "Agility", 6, 2], [:dexterity, "Dexterity", 7, 2],
    ].freeze

    ELEMENTS = [
      # Tier 1: Elementals
      [:fire, "Fire", 3, 1], [:ice, "Ice", 4, 1], [:lightning, "Lightning", 5, 1],
      [:wind, "Wind", 6, 1], [:earth, "Earth", 7, 1], [:water, "Water", 8, 1],
      # Tier 2: Waves
      [:bio, "Bio", 36, 2], [:sonic, "Sonic", 35, 2],
      # Tier 3: Fusion
      [:physical, "Physical", 1, 3], [:pleasure, "Pleasure", 2, 3], [:holy, "Holy", 9, 3], [:dark, "Dark", 10, 3],
      # Tier 4: Chaos
      [:nuclear, "Nuclear", 43, 4], [:quantum, "Quantum", 44, 4], [:ion, "Ion", 45, 4],
      [:hadron, "Hadron", 46, 4], [:terra, "Terra", 47, 4], [:nano, "Nano", 48, 4],
      # Tier 5: Chaos
      [:carnage, "Carnage", 51, 5], [:nightmare, "Nightmare", 52, 5], [:eternal, "Eternal", 49, 5],
      [:demise, "Demise", 50, 5], [:galactic, "Galactic", 41, 5],
      # Tier 9: Other (Excluded from auto-generation)
      [:recovery, "Recovery", 38, 0], [:gravity, "Gravity", 40, 0]
    ].freeze

    SKILL_TYPES = [
      [6, "Dagger"], [7, "Sword"], [8, "Rapier"], [9, "Katana"], [10, "Spear"], [11, "Axe"],
      [12, "Club"], [13, "Scythe"], [14, "Bow"], [15, "Whip"], [16, "Throwing"], [17, "Flail"],
      [18, "Fan"], [19, "Gun"], [20, "Multiweapon"], [21, "Unarmed"], [22, "White Magic"],
      [23, "Black Magic"], [24, "Time Magic"], [25, "Summoning"], [26, "Holy"], [27, "Dark"],
      [28, "Spellblade"], [29, "Taoism"], [30, "Thievery"], [31, "Ninjutsu"], [32, "Piracy"],
      [33, "Justice"], [34, "Mercantile"], [35, "EX Item"], [36, "Oracle"], [37, "Dancing"],
      [38, "Singing"], [39, "Talk"], [40, "Magic Science"], [41, "Alchemy"], [42, "Grimoire"],
      [43, "Makina"], [44, "Cooking"], [45, "Medicine"], [46, "Service"], [47, "Ruling"],
      [48, "Heroism"], [49, "Sexcraft"], [50, "Demon Arts"], [51, "Ocean"], [52, "Slime"],
      [53, "Beast"], [54, "Snake"], [55, "Tentacle"], [56, "Wing"], [57, "Insect"],
      [58, "Plant"], [59, "Corpse"], [60, "Artificial"], [61, "Nature"], [62, "Breath"],
      [63, "Special"], [67, "Psychic"], [68, "Sorcery"], [69, "Giant"], [70, "Chaos"]
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
      [29, "Grimoire", 3], [30, "Gun", 1], [31, "Sex Toy", 2],
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

    #--- Base feature codes ---
    FEATURE_ELEMENT_RATE        = 11
    FEATURE_DEBUFF_RATE         = 12
    FEATURE_STATE_RATE          = 13
    FEATURE_STATE_RESIST        = 14
    FEATURE_PARAM               = 21
    FEATURE_XPARAM              = 22
    FEATURE_SPARAM              = 23
    FEATURE_ATK_ELEMENT         = 31
    FEATURE_ATK_STATE           = 32
    FEATURE_ATK_SPEED           = 33
    FEATURE_ATK_TIMES           = 34
    FEATURE_STYPE_ADD           = 41
    FEATURE_STYPE_SEAL          = 42
    FEATURE_SKILL_ADD           = 43
    FEATURE_SKILL_SEAL          = 44
    FEATURE_EQUIP_WTYPE         = 51
    FEATURE_EQUIP_ATYPE         = 52
    FEATURE_EQUIP_FIX           = 53
    FEATURE_EQUIP_SEAL          = 54
    FEATURE_SLOT_TYPE           = 55
    FEATURE_ACTION_PLUS         = 61
    FEATURE_SPECIAL_FLAG        = 62
    FEATURE_COLLAPSE_TYPE       = 63
    FEATURE_PARTY_ABILITY       = 64

    #--- Extended feature codes ---
    FEATURE_XPARAM_EX                 = 66
    FEATURE_PARTY_EX_ABILITY          = 67
    FEATURE_BATTLER_ABILITY           = 68
    FEATURE_MULTI_BOOSTER             = 69
    FEATURE_DUMMY_ENCHANT             = 70
    FEATURE_TERRAIN_BOOSTER           = 71
    FEATURE_EQUIP_MASTERY             = 72
    FEATURE_SKILL_STATE_ADD           = 73
    FEATURE_SKILL_TYPE_STATE_ADD      = 74
    FEATURE_SUCCUBUS                  = 75
    FEATURE_ALL_ADD_ELEMENT           = 76
    FEATURE_PENETRATION_ELEMENT       = 77
    FEATURE_EX_CATEGORY_ATTACK        = 78
    FEATURE_EX_CATEGORY_DEFENCE       = 79
    FEATURE_STYPE_ADD_PARAM           = 80
    FEATURE_SKILL_COMBO               = 81
    FEATURE_SKILL_TYPE_COMBO          = 82
    FEATURE_ADD_ELEMENT               = 83
    FEATURE_EX_CATEGORY_ATTACK_BONUS  = 84
    FEATURE_SKILL_PLUS_ATTACK         = 85
    FEATURE_SKILL_TYPE_PLUS_ATTACK    = 86
    FEATURE_STATE_RATE_FIX            = 87
    FEATURE_ELEMENT_RATE_FIX          = 88
    FEATURE_AUTO_SKILL_INVALID        = 89
    FEATURE_SKILL_PLUS_ATTACK_ONE           = 90
    FEATURE_SKILL_TYPE_PLUS_ATTACK_ONE      = 91
    FEATURE_SKILL_PLUS_ATTACK_ONE_RANDOM    = 92
    FEATURE_SKILL_TYPE_PLUS_ATTACK_ONE_RANDOM = 93
    FEATURE_SKILL_SCOPE_ALL           = 94
    FEATURE_SKILL_TYPE_SCOPE_ALL      = 95
    FEATURE_SKILL_SCOPE_ONE           = 96
    FEATURE_SKILL_TYPE_SCOPE_ONE      = 97
    FEATURE_ENEMY_MULTI_SKILL_BOOST         = 98
    FEATURE_ENEMY_MULTI_SKILL_TYPE_BOOST    = 99
    FEATURE_ENEMY_SINGLE_SKILL_BOOST        = 100
    FEATURE_ENEMY_SINGLE_SKILL_TYPE_BOOST   = 101
    FEATURE_WEAPON_TYPE_ATTACK_BOOST        = 102
    FEATURE_ARMOR_TYPE_DEFENCE_BOOST        = 103
    FEATURE_STATE_EFFECT_BOOST        = 104
    FEATURE_STATE_DAMAGE_BOOST        = 105
    FEATURE_WIELD_BOOST               = 106
    FEATURE_BATTLE_START_STATE        = 107
    FEATURE_MULTI_ELEMENT             = 108
    FEATURE_PARAM_NEUTRALIZE          = 109
    FEATURE_COST_ZERO                 = 110
    FEATURE_SKILL_COST_ZERO           = 111
    FEATURE_SKILL_TYPE_COST_ZERO      = 112
    FEATURE_PARAM_STATE               = 113
    FEATURE_SAME_ELEMENT_DAMAGE_BOOST = 114
    FEATURE_STATE_BOOST_PLUS          = 115
    FEATURE_LEARNING                  = 116
    FEATURE_EX_CATEGORY               = 117
    FEATURE_FAST_MOVE_ALL             = 118
    FEATURE_SLOW_MOVE_ALL             = 119
    FEATURE_SKILL_TYPE_DEFENCE_PENETRATION = 120
    FEATURE_DUAL_SHIELD_ADD_ABILITY   = 121
    FEATURE_STATE_CHAIN               = 122
    FEATURE_FULL_HP_BOOST             = 123
    FEATURE_FULL_HP_SKILL_BOOST       = 124
    FEATURE_FULL_HP_SKILL_TYPE_BOOST  = 125
    FEATURE_MAX_AP_RATE               = 126
    FEATURE_SKILL_CHAIN               = 127
    FEATURE_SKILL_CHAIN_BOOST         = 128
    FEATURE_SKILL_CHAIN_COST_RATE     = 129
    FEATURE_ITEM_COST_RATE            = 130
    FEATURE_ITEM_GET_RATE             = 131
    FEATURE_SKILL_COUNTER_EX          = 132
    FEATURE_SKILL_TIMING_BOOST        = 133
    FEATURE_SKILL_TIMING_REPEAT       = 134
    FEATURE_TURN_END_REVIVE           = 135
    FEATURE_FULL_SP_BOOST             = 136
    FEATURE_FULL_MP_BOOST             = 137
    FEATURE_UNDEAD                    = 138
    FEATURE_SKILL_UNSTOPPABLE         = 140
    FEATURE_SKILL_TYPE_UNSTOPPABLE    = 141
    FEATURE_ELEMENT_DRAIN             = 142
    FEATURE_MAGICAL_CRITICAL          = 143
    FEATURE_FULL_SP_STYPE_BOOST       = 144
    FEATURE_FULL_MP_STYPE_BOOST       = 145
    FEATURE_ADD_STEAL_STYPE           = 146
    FEATURE_ADD_RESTORATION           = 147
    FEATURE_ADD_RESTORATION_STYPE_HP  = 148
    FEATURE_ADD_RESTORATION_STYPE_MP  = 149
    FEATURE_ADD_SPEED                 = 150
    FEATURE_ADD_SPEED_PARAM_RATE      = 151
    FEATURE_ADD_DUMMY_ENCHANT         = 152
    FEATURE_AUTO_REVIVE               = 153
    FEATURE_BLOCK_RATE                = 154
    FEATURE_ID_ITEM_BOOST             = 155
    FEATURE_STYPE_ITEM_COST_RATE      = 156
    FEATURE_STYPE_ITEM_GET_RATE       = 157
    FEATURE_ONCE_TURN_END_STATE       = 158
    FEATURE_DAMAGE_BOOST              = 159
    FEATURE_SINGLE_SKILL_BOOST        = 160
    FEATURE_STYPE_COUNTER_EX          = 161
    FEATURE_FAST_MOVE_SID             = 162
    FEATURE_FAST_MOVE_STYPE           = 163
    FEATURE_SLOW_MOVE_SID             = 164
    FEATURE_SLOW_MOVE_STYPE           = 165
    FEATURE_ADD_STEAL_SID             = 166
    FEATURE_ADD_ELEMENT_STYPE         = 167
    FEATURE_ADD_ELEMENT_SID           = 168
    FEATURE_HIT_DAMAGE_BOOST          = 169
    FEATURE_TURN_HIT_DAMAGE_RATE      = 170
    FEATURE_MAX_AP_BONUS              = 171
    FEATURE_EX_CATEGORY_STYPE         = 172
    FEATURE_REDUCE_BOOST_DAMAGE       = 173
    FEATURE_ALTERNATE_TP_TO_MP        = 174
    FEATURE_XPARAM_FIX                = 175
    FEATURE_PARTY_PARAM_BOOST         = 176
    FEATURE_VARIABLE_HP_DAMAGE        = 177
    FEATURE_AUTO_SKILL_PRIORITY_INVALID  = 178
    FEATURE_AUTO_SKILL_CONDITION_INVALID = 179
    FEATURE_ACTION_MINUS              = 180

    #--- Sub-id tables ---
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

    FEATURE_SUMMARY = {
      11 => "FEATURE_ELEMENT_RATE", 13 => "FEATURE_STATE_RATE", 14 => "FEATURE_STATE_RESIST",
      21 => "FEATURE_PARAM", 22 => "FEATURE_XPARAM", 23 => "FEATURE_SPARAM", 32 => "FEATURE_ATK_STATE",
      41 => "FEATURE_STYPE_ADD", 51 => "FEATURE_EQUIP_WTYPE", 52 => "FEATURE_EQUIP_ATYPE",
      55 => "FEATURE_SLOT_TYPE", 61 => "FEATURE_ACTION_PLUS", 67 => "FEATURE_PARTY_EX_ABILITY",
      68 => "FEATURE_BATTLER_ABILITY", 69 => "FEATURE_MULTI_BOOSTER", 71 => "FEATURE_TERRAIN_BOOSTER",
      75 => "FEATURE_SUCCUBUS", 78 => "FEATURE_EX_CATEGORY_ATTACK", 84 => "FEATURE_EX_CATEGORY_ATTACK_BONUS",
      104 => "FEATURE_STATE_EFFECT_BOOST", 116 => "FEATURE_LEARNING", 154 => "FEATURE_BLOCK_RATE",
    }.freeze

    BATTLER_SUMMARY = {
      0 => "STEAL_SUCCESS", 1 => "AUTO_STAND", 2 => "HEEL_REVERSE", 3 => "AUTO_STATE", 4 => "TRIGGER_STATE",
      5 => "METAL_BODY", 6 => "DEFENSE_WALL", 7 => "INVALIDATE_WALL", 8 => "DAMAGE_MP_CONVERT",
      9 => "DAMAGE_GOLD_CONVERT", 10 => "DAMAGE_MP_DRAIN", 11 => "DAMAGE_GOLD_DRAIN", 12 => "DEAD_SKILL",
      13 => "BATTLE_START_SKILL", 14 => "TURN_START_SKILL", 15 => "TURN_END_SKILL", 16 => "CHANGE_ACTION",
      17 => "STYPE_COST_RATE", 18 => "SKILL_COST_RATE", 19 => "TP_COST_RATE", 20 => "HP_COST_RATE",
      21 => "GOLD_COST_RATE", 22 => "INCREASE_TP", 23 => "START_TP_RATE", 24 => "BATTLE_END_HEEL_HP",
      25 => "BATTLE_END_HEEL_MP", 26 => "NORMAL_ATTACK", 27 => "COUNTER_SKILL", 28 => "FINAL_INVOKE",
      29 => "CERTAIN_COUNTER", 30 => "MAGICAL_COUNTER", 31 => "PHYSICAL_COUNTER_EX", 32 => "MAGICAL_COUNTER_EX",
      33 => "CERTAIN_COUNTER_EX", 34 => "CONSIDERATE", 35 => "GET_EXP_RATE", 36 => "GET_CLASSEXP_RATE",
      37 => "INVOKE_REPEATS_TYPE", 38 => "INVOKE_REPEATS_SKILL", 45 => "PHYSICAL_REFLECTION",
      46 => "SLOT_CANNOT_DUAL_WIELD", 48 => "HP_REGEN_INVALID", 49 => "CANT_MOVE", 50 => "BATTLE_START_HP",
      54 => "CERTAIN_DAMAGE_RATE", 55 => "ELEMENT_REFLECTION", 56 => "SELF_STATE_ETERNAL",
      57 => "TARGET_STATE_ETERNAL", 58 => "EQUIP_ABILITY_BOOST", 60 => "NORMAL_ATTACK_FORCE_ELEMENT",
      61 => "CERTAIN_REFLECTION", 64 => "MAGICAL_COUNTER_SKILL", 65 => "CERTAIN_COUNTER_SKILL",
      66 => "COUNTER_EX_SKILL", 67 => "MAGICAL_COUNTER_EX_SKILL", 68 => "CERTAIN_COUNTER_EX_SKILL",
      69 => "EVASION_SKILL",
    }.freeze

    BOOSTER_SUMMARY = {
      0 => "ELEMENT", 1 => "WEAPON_PHYSICAL", 2 => "WEAPON_MAGICAL", 3 => "WEAPON_CERTAIN",
      4 => "NORMAL_ATTACK", 5 => "STATE_RATIO_TYPE", 6 => "STATE_FIX_TYPE", 7 => "SKILL_TYPE",
      8 => "STATE_RATIO_SKILL", 9 => "SKILL", 10 => "WTYPE_SKILL", 11 => "COUNTER", 12 => "FALL_HP",
      13 => "OVER_SOUL", 14 => "REFLECTION", 15 => "CRITICAL", 16 => "ACTOR_PARAM", 17 => "ACTOR_EXIST_PARAM",
      18 => "CLASS", 19 => "EQUIP_ABILITY", 20 => "SELF_STATE", 21 => "TARGET_STATE", 22 => "STATE_SKILL",
      23 => "STATE_SKILL_TYPE", 24 => "STATE_NORMAL_ATACK", 25 => "PINCHI_SKILL", 26 => "PINCHI_SKILL_TYPE",
      27 => "BATTLE_COUNT", 28 => "ACTOR_DEFEAT", 29 => "ACTOR_CARRY", 30 => "ACTOR_DOWN", 31 => "ACTOR_ORGASM",
      32 => "ACTOR_STEAL", 33 => "ACTOR_LOVE", 34 => "ENEMY_MULTI", 35 => "ENEMY_SIGNLE", 36 => "ITEM_DAMAGE",
    }.freeze

    PARTYEX_SUMMARY = {
      0 => "GET_GOLD_RATE", 1 => "GET_ITEM_RATE", 2 => "ENCOUNTER_RATE", 3 => "COLLECT_RATE",
      4 => "SLOT_CHANCE", 5 => "UNLOCK_LEVEL", 10 => "GET_GOLD_RATE_STATE", 11 => "GET_ITEM_RATE_STATE",
      13 => "COLLECT_RATE_STATE",
    }.freeze

    def self.describe_feature(f)
      code, sub_id, value = f.is_a?(RPG::BaseItem::Feature) ? [f.code, f.data_id, f.value] : f
      name = FEATURE_SUMMARY[code] || "FEATURE_#{code}"
      sub = case code
            when FEATURE_BATTLER_ABILITY    then BATTLER_SUMMARY[sub_id]
            when FEATURE_MULTI_BOOSTER      then BOOSTER_SUMMARY[sub_id]
            when FEATURE_PARTY_EX_ABILITY   then PARTYEX_SUMMARY[sub_id]
            end
      sub = sub ? "#{sub_id}:#{sub}" : sub_id.to_s
      "#{name}[#{sub}] = #{value.inspect}"
    rescue => e
      "[describe_feature FAILED: #{e.class}: #{e.message}]"
    end

    def self.describe_features(fs)
      Array(fs).map { |f| describe_feature(f) }.join(" | ")
    end
  end

  #=== TraitLibrary =========================================================
  module TraitLibrary
    TRAITS = {
      :heros_blood => {
        :name  => "Hero's Blood",
        :lines => [
          "Can always use Sword, Spear, Katana, Axe, Holy, Talk, and",
          "Heroism skills. Heroism skills deal +30% damage, gaining +2%",
          "damage for every % of missing HP.",
        ],
        :features => [
          [41, 63, 0.0], [22, 2, 0.05], [22, 1, 0.05], [23, 0, 0.5],
          [52, 41, 0.0], [51, 32, 0.0],
          [41, 7, 0.0], [41, 10, 0.0], [41, 9, 0.0], [41, 11, 0.0], [41, 26, 0.0], [41, 39, 0.0], [41, 48, 0.0],
          [68, 23, 0.5], [68, 42, { 3147 => 3277 }],
          [69, 7, { 48 => 0.3 }], [69, 26, { 48 => 2.0 }],
        ],
        :tags => [],
      },
      :slime_body => {
        :name  => "Slime Body",
        :lines => ["Can always use Slime skills. Resists Physical damage."],
        :features => [
          [41, 63, 0.0], [22, 2, 0.05], [22, 1, 0.05], [23, 0, 0.5],
          [52, 41, 0.0], [51, 32, 0.0], [41, 22, 0.0],
        ],
        :tags => [],
      },
    }

    def self.get(key); TRAITS[key] || TRAITS[:heros_blood]; end
    def self.keys; TRAITS.keys; end
    def self.names; TRAITS.values.map { |t| t[:name] }; end
  end

  #=== TraitFeatures ========================================================
  module TraitFeatures
    include TraitData

    MAX_TRAIT_COST = 100
    STYPE_ICONS = { 1 => 97, 2 => 102, 3 => 100, 4 => 98, 5 => 99, 6 => 103 }.freeze
    GROUP_LABELS = { :combat => "Combat Traits", :job => "Job Traits", :magic => "Magic Traits", :defense => "Defense Traits", :special => "Special Traits", :unique => "Unique Traits" }.freeze
    GROUPS = [:combat, :job, :magic, :defense, :special, :unique].freeze

    COMBAT_STYPE_IDS = [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21].freeze
    MAGIC_STYPE_IDS  = [22, 23, 24, 25, 26, 27, 28, 29, 67, 68, 70].freeze
    JOB_STYPE_IDS    = [30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49].freeze
    RACIAL_STYPE_IDS = [50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 69].freeze

    STAT_PARAM_NAMES = { 0 => "Max HP", 1 => "Max MP", 2 => "Attack", 3 => "Defense", 4 => "Magic", 5 => "Willpower", 6 => "Agility", 7 => "Dexterity" }.freeze
    STAT_RATE_NAMES = { 0 => "Evasion", 1 => "Hit Rate", 2 => "Critical Rate", 4 => "Magic Evasion" }.freeze

    HERO_BLOOD_KEYS = [
      :hero_base, :skill_type_7, :skill_type_10, :skill_type_9, :skill_type_11,
      :skill_type_26, :skill_type_39, :skill_type_48, :skill_booster_48_30, :skill_tenacity_48_200,
    ].freeze

    SLIME_BODY_KEYS = [:skill_type_52, :defense_10].freeze

    CUSTOM_CHAINS = [
      [7, 6], [7, 10], [6, 10], [22, 26]
    ].freeze

    LIGHTWEAR_ATYPES = [1, 2, 7, 8, 9]
    HEAVYWEAR_ATYPES = [1, 3, 4, 5, 6]
    LIGHT_HEADGEAR_ATYPES = [33, 36, 37]
    HEAVY_HEADGEAR_ATYPES = [33, 34, 35]
    SHIELD_ATYPES = [38, 39, 40]

    @catalogue = {}
    class << self
      attr_reader :catalogue
    end

    def self.group_for_stype(stype)
      case stype
      when 1 then :combat when 2 then :job when 3 then :magic
      when 4 then :defense when 5 then :special else :unique
      end
    end

    def self.stype_for_skill_type(stype_id)
      return 1 if COMBAT_STYPE_IDS.include?(stype_id)
      return 3 if MAGIC_STYPE_IDS.include?(stype_id)
      return 2 if JOB_STYPE_IDS.include?(stype_id)
      return 5 if RACIAL_STYPE_IDS.include?(stype_id)
      6
    end

    def self.entry(name, cost, features, tags, stype, kind, conflict, desc)
      {
        :name => name, :cost => cost, :features => features, :tags => tags,
        :group => group_for_stype(stype), :stype => stype, :kind => kind,
        :icon => STYPE_ICONS[stype] || 0, :desc => desc, :conflict_group => conflict,
      }
    end

    def self.get(key); @catalogue[key]; end
    def self.keys; @catalogue.keys; end
    def self.keys_in_group(g); @catalogue.select { |k, e| e[:group] == g && !e[:hidden] }.keys; end
    def self.keys_by_group; GROUPS.map { |g| [g, keys_in_group(g)] }.reject { |_, ks| ks.empty? }; end
    def self.total_cost(ks); Array(ks).map { |k| (@catalogue[k] || {})[:cost].to_i }.inject(0, :+); end
    def self.group_label(g); GROUP_LABELS[g] || g.to_s.capitalize; end
    def self.add_entry(k, e); @catalogue[k] = e.merge(:key => k); end
    def self.hidden?(k); (@catalogue[k] || {})[:hidden] ? true : false; end

    def self.feature_present?(c, f)
      return false unless c && f
      Array(c.features).any? { |x| x[0] == f[0] && x[1] == f[1] && x[2] == f[2] }
    end

    def self.tag_present?(c, t)
      return false unless c && t
      Array(c.tags).include?(t)
    end

    def self.equipped?(c, k)
      e = @catalogue[k]; return false unless c && e
      e[:features].any? { |f| feature_present?(c, f) } || e[:tags].any? { |t| tag_present?(c, t) }
    end

    def self.add_features(c, fs)
      c.features ||= []
      Array(fs).each { |f| c.features << [f[0], f[1], f[2]] unless feature_present?(c, f) }
    end

    def self.add_tags(c, ts)
      c.tags ||= []
      Array(ts).each { |t| c.tags << t unless c.tags.include?(t) }
    end

    def self.remove_features(c, fs)
      return unless c && c.features
      Array(fs).each { |f| c.features.reject! { |x| x[0] == f[0] && x[1] == f[1] && x[2] == f[2] } }
    end

    def self.remove_tags(c, ts)
      return unless c && c.tags
      Array(ts).each { |t| c.tags.delete(t) }
    end

    def self.evict_conflicts(c, new_key)
      return unless c && new_key
      ne = @catalogue[new_key]; return unless ne
      group = ne[:conflict_group]
      explicit = Array(ne[:evicts])
      return if group.nil? && explicit.empty?
      (c.trait_feature_keys || []).dup.each do |other|
        next if other == new_key
        oe = @catalogue[other]
        hit = (group && oe && oe[:conflict_group] == group) || explicit.include?(other)
        c.trait_feature_keys.delete(other) if hit
      end
    end

    def self.build_catalogue
      @catalogue = {}
      build_stats
      build_rates
      build_counters
      build_regen
      build_costs
      build_element_boosters
      build_equip_boosters
      build_skill_families
      build_slayers
      build_resistances
      build_chains
      build_equip_access
      build_skill_access
      build_wields
      build_cost_modifiers
      # build_action
      build_state_effects
      build_utility
      # build_party
      # build_terrain
      build_hero_base
    end

    def self.build_stats
      STATS.each do |key, label, param_id, stype|
        [[10, :stat_10], [20, :stat_20], [30, :stat_30], [40, :stat_40]].each do |pct, cost_key|
          next unless HAND_COSTS.key?(cost_key)
          if key == :max_sp
            add_entry(:"#{key}_#{pct}", entry("#{label} +#{pct}%", HAND_COSTS[cost_key], [],
              ["<TPLv補正 #{pct}>"], stype, :stat, :"#{key}_boost", "#{label} +#{pct}%."))
          else
            add_entry(:"#{key}_#{pct}", entry("#{label} +#{pct}%", HAND_COSTS[cost_key],
              [[FEATURE_PARAM, param_id, 1.0 + pct / 100.0]], [], stype, :stat,
              :"#{key}_boost", "#{label} +#{pct}%."))
          end
        end
      end
    end

    def self.build_rates
      { :hit_10 => [1, 0.10], :hit_20 => [1, 0.20], :hit_30 => [1, 0.30], :hit_40 => [1, 0.40],
        :crit_10 => [2, 0.10], :crit_30 => [2, 0.30], :crit_50 => [2, 0.50],
        :crit_damage_25 => [15, 0.25], :crit_damage_50 => [15, 0.50], :crit_damage_100 => [15, 1.0],
        :evasion_10 => [0, 0.10], :evasion_20 => [0, 0.20], :evasion_30 => [0, 0.30],
        :magic_evasion_10 => [4, 0.10], :magic_evasion_20 => [4, 0.20], :magic_evasion_30 => [4, 0.30]
      }.each do |cost_key, (xparam, value)|
        next unless HAND_COSTS.key?(cost_key)
        label = { 1 => "Hit Rate", 2 => "Critical Rate", 0 => "Evasion", 4 => "Magic Evasion", 15 => "Critical Damage" }[xparam]
        stype = (xparam == 0 || xparam == 4) ? 4 : 1
        kind = xparam == 4 ? :magic_evasion_boost : xparam == 0 ? :evasion_boost :
              xparam == 1 ? :hit_boost : xparam == 15 ? :crit_damage_boost : :crit_boost

        feature =
          case xparam
          when 1 then [FEATURE_XPARAM, 1, value]        # Hit
          when 2 then [FEATURE_MULTI_BOOSTER, 15, value] # Crit rate (applied to damage)
          when 0 then [FEATURE_XPARAM, 0, value]        # Evasion
          when 4 then [FEATURE_XPARAM, 4, value]        # Magic Evasion
          when 15 then [FEATURE_MULTI_BOOSTER, 15, value] # Crit damage
          end

        add_entry(cost_key, entry("#{label} +#{(value * 100).to_i}%", HAND_COSTS[cost_key],
          [feature], [], stype, :stat, kind,
          "#{label} +#{(value * 100).to_i}%."))
      end
    end

    def self.build_counters
      [[:counter_10, "Counter Rate +10%", :physical_counter_10, 0.10],
       [:counter_30, "Counter Rate +30%", :physical_counter_30, 0.30],
       [:counter_50, "Counter Rate +50%", :physical_counter_50, 0.50]].each do |key, name, cost_key, value|
        next unless HAND_COSTS.key?(cost_key)
        add_entry(key, entry(name, HAND_COSTS[cost_key], [[FEATURE_XPARAM, XPARAM_COUNTER, value]], [], 1, :other, :counter_rate, "Counters #{(value * 100).to_i}% of attacks."))
      end
      [[:magic_counter_10, "Magic Counter +10%", :magic_counter_10, 0.10],
       [:magic_counter_30, "Magic Counter +30%", :magic_counter_30, 0.30],
       [:magic_counter_50, "Magic Counter +50%", :magic_counter_50, 0.50]].each do |key, name, cost_key, value|
        next unless HAND_COSTS.key?(cost_key)
        add_entry(key, entry(name, HAND_COSTS[cost_key], [[FEATURE_BATTLER_ABILITY, BATTLER_MAGICAL_COUNTER, value]], [], 1, :other, :magic_counter_rate, "Counters #{(value * 100).to_i}% of magic attacks."))
      end

      if HAND_COSTS.key?(:counter_damage_100)
        add_entry(:counter_damage_100, entry("Counterattack Damage +100%", HAND_COSTS[:counter_damage_100], [[FEATURE_MULTI_BOOSTER, BOOSTER_COUNTER, 1.0]], [], 1, :other, :counter_damage, "Counterattacks deal 100% more damage."))
      end

      add_entry(:nullify_counter, entry("Counter on Nullify", HAND_COSTS[:physical_counter_50], [], ["<無効化反撃 100%>"], 1, :other, :nullify_counter, "Counters any attack nullified.")) if HAND_COSTS.key?(:physical_counter_50)
    end

    def self.build_regen
      { :hp => [7, { 5 => :hp_regen_5, 10 => :hp_regen_10, 20 => :hp_regen_20, 30 => :hp_regen_30 }],
        :mp => [8, { 1 => :mp_regen_1, 2 => :mp_regen_2, 4 => :mp_regen_4, 8 => :mp_regen_8 }],
        :sp => [9, { 5 => :sp_regen_5, 10 => :sp_regen_10, 20 => :sp_regen_20, 30 => :sp_regen_30 }] }.each do |kind, (xparam, cost_map)|
        cost_map.each do |pct, cost_key|
          next unless HAND_COSTS.key?(cost_key)
          add_entry(cost_key, entry("#{kind.to_s.upcase} Regen #{pct}%", HAND_COSTS[cost_key],
            [[FEATURE_XPARAM, xparam, pct / 100.0]], [], 5, :stat, :"#{kind}_regen_boost",
            "Restores #{pct}% of max #{kind.to_s.upcase} each turn."))
        end
      end
    end

    def self.build_costs
      if HAND_COSTS.key?(:hp_cost_50)
        add_entry(:hp_cost_50, entry("HP Cost 50%", HAND_COSTS[:hp_cost_50], [[FEATURE_BATTLER_ABILITY, BATTLER_HP_COST_RATE, 0.5]], [], 5, :hp_cost, :hp_cost_boost, "All skills cost 50% HP."))
      end
      if HAND_COSTS.key?(:mp_cost_75)
        add_entry(:mp_cost_75, entry("MP Cost 75%", HAND_COSTS[:mp_cost_75], [[FEATURE_BATTLER_ABILITY, BATTLER_SKILL_COST_RATE, 0.75]], [], 3, :mp_cost, :mp_cost_boost, "Skills cost 75% of their MP."))
      end
      if HAND_COSTS.key?(:sp_cost_75)
        add_entry(:sp_cost_75, entry("SP Cost 75%", HAND_COSTS[:sp_cost_75], [[FEATURE_BATTLER_ABILITY, BATTLER_TP_COST_RATE, 0.75]], [], 2, :sp_cost, :sp_cost_boost, "All skills cost 75% SP."))
      end
      if HAND_COSTS.key?(:gold_cost_50)
        add_entry(:gold_cost_50, entry("Gold Cost 50%", HAND_COSTS[:gold_cost_50], [[FEATURE_BATTLER_ABILITY, BATTLER_GOLD_COST_RATE, 0.5]], [], 6, :gold_cost, :gold_cost_boost, "All skills cost 50% of their Gold."))
      end
    end

    def self.build_equip_boosters
      WEAPONS.each do |wtype_id, label, stype|
        next if stype.nil? || stype > 3
        [[15, :weapon_booster_15], [30, :weapon_booster_30], [50, :weapon_booster_50]].each do |pct, cost_key|
          next unless HAND_COSTS.key?(cost_key)
          add_entry(:"#{label.downcase.gsub(' ', '_')}_booster_#{pct}", entry(
            "#{label} Booster #{pct}%", HAND_COSTS[cost_key],
            [[FEATURE_MULTI_BOOSTER, BOOSTER_WEAPON_PHYSICAL, { wtype_id => pct / 100.0 }]], [],
            stype, :weapon_boost, :"weapon_booster_#{wtype_id}",
            "#{label} weapons deal +#{pct}% more damage."
          ))
        end
      end
    end

    def self.build_element_boosters
      ELEMENTS.each do |_, label, element_id, tier|
        next if tier == 0
        [[15, 0.15], [30, 0.30], [50, 0.50]].each do |pct, value|
          cost_key = :"element_booster_t#{tier}_#{pct}"
          next unless HAND_COSTS.key?(cost_key)
          add_entry(:"#{label.downcase.gsub(' ', '_')}_booster_#{pct}", entry(
            "#{label} Booster #{pct}%", HAND_COSTS[cost_key],
            [[FEATURE_MULTI_BOOSTER, BOOSTER_ELEMENT, { element_id => value }]], [],
            3, :element_boost, :"element_booster_#{element_id}",
            "Deals +#{pct}% #{label} damage."
          ))
        end
      end
    end

    def self.build_skill_families
      SKILL_TYPES.each do |stype_id, label|
        grp = stype_for_skill_type(stype_id)
        next if grp == 6 && ![48, 63].include?(stype_id)

        [[15, :weapon_booster_15], [30, :weapon_booster_30], [50, :weapon_booster_50]].each do |pct, cost_key|
          next unless HAND_COSTS.key?(cost_key)
          add_entry(:"skill_booster_#{stype_id}_#{pct}", entry(
            "#{label} Skill Booster #{pct}%", HAND_COSTS[cost_key],
            [[FEATURE_MULTI_BOOSTER, BOOSTER_SKILL_TYPE, { stype_id => pct / 100.0 }]], [],
            grp, :skill_booster, :"skill_booster_#{stype_id}",
            "#{label} skills deal +#{pct}% more damage."
          ))
        end

        [[100, :pinch_booster_100], [200, :pinch_booster_200]].each do |pct, cost_key|
          next unless HAND_COSTS.key?(cost_key)
          add_entry(:"skill_tenacity_#{stype_id}_#{pct}", entry(
            "#{label} Tenacity +#{pct}%", HAND_COSTS[cost_key],
            [[FEATURE_MULTI_BOOSTER, BOOSTER_PINCHI_SKILL_TYPE, { stype_id => pct / 100.0 }]], [],
            grp, :pinch_boost, :"skill_tenacity_#{stype_id}",
            "#{label} skills deal up to +#{pct}% damage as HP falls."
          ))
        end

        if HAND_COSTS.key?(:multi_strike_type)
          feat = [[FEATURE_BATTLER_ABILITY, BATTLER_INVOKE_REPEATS_TYPE, { stype_id => 2 }]]
          [:HP, :MP, :TP, :GOLD].each do |type|
            feat << [FEATURE_BATTLER_ABILITY, BATTLER_STYPE_COST_RATE, { :type => type, :id => stype_id, :rate => 1.5 }]
          end
          add_entry(:"multi_strike_type_#{stype_id}", entry(
            "#{label} Rush", HAND_COSTS[:multi_strike_type],
            feat, [], grp, :multi_strike, :"multi_strike_type_#{stype_id}",
            "#{label} skills act twice in a row, but costs 50% more to use."
          ))
        end
      end
    end

    def self.build_slayers
      SLAYER_CATEGORIES.each do |id, key, label, pct, _stype|
        next unless HAND_COSTS.key?(:slayer_species)
        add_entry(:"slayer_#{key}", entry("#{label} Slayer", HAND_COSTS[:slayer_species],
          [[FEATURE_EX_CATEGORY_ATTACK, id, pct / 100.0]], [], 1, :slayer,
          :"slayer_#{key}", "Deals +#{pct}% damage to #{label} enemies."))
      end
      [15, 30, 50, 75].each do |pct|
        cost_key = :"slayer_boss_#{pct}"
        next unless HAND_COSTS.key?(cost_key)
        add_entry(:"slayer_boss_#{pct}", entry("Boss Slayer #{pct}%", HAND_COSTS[cost_key],
          [[FEATURE_EX_CATEGORY_ATTACK, 10, pct / 100.0]], [], 1, :slayer, :slayer_boss,
          "Deals +#{pct}% damage to Boss enemies."))
      end
      if HAND_COSTS.key?(:slayer_booster)
        add_entry(:slayer_booster_50, entry("Slayer Booster 50%", HAND_COSTS[:slayer_booster],
          [[FEATURE_EX_CATEGORY_ATTACK_BONUS, 0, 0.5]], [], 1, :slayer_boost, :slayer_booster,
          "Species Slayer attacks deal +50% damage."))
      end
    end

    def self.build_resistances
      ELEMENTS.each do |_, label, element_id, tier|
        next if tier == 0
        rate_keys = { "Resist" => :"element_resist_t#{tier}", "Half" => :"element_half_t#{tier}", "Nullify" => :"element_null_t#{tier}" }
        rate_values = { "Resist" => 0.5, "Half" => 0.25, "Nullify" => 0.0 }

        rate_keys.each do |tier_name, cost_key|
          next unless HAND_COSTS.key?(cost_key)
          add_entry(:"#{label.downcase.gsub(' ', '_')}_resist_#{tier_name.downcase}", entry(
            "#{label} #{tier_name}", HAND_COSTS[cost_key],
            [[FEATURE_ELEMENT_RATE, element_id, rate_values[tier_name]]], [], 4, :element_resist,
            :"element_resist_#{element_id}", "#{label} damage taken: #{(rate_values[tier_name] * 100).to_i}%."))
        end
      end

      STATES.each do |_, label, state_id|
        [[STATE_RESIST_RATE, :status_resist, "Resist", 50], [STATE_RESIST_NULL, :status_nullify, "Nullify", 0]].each do |rate, cost_key, tier, pct|
          next unless HAND_COSTS.key?(cost_key)
          add_entry(:"#{label.downcase.gsub(' ', '_')}_resist_#{tier.downcase}", entry(
            "#{label} #{tier}", HAND_COSTS[cost_key],
            [[FEATURE_STATE_RATE, state_id, rate]], [], 4, :status_resist, :"status_resist_#{state_id}",
            "#{label} lands #{pct == 0 ? 'never' : "at #{pct}%"}."))
        end
      end
    end

    def self.build_chains
      build_chain_features = lambda do |sources, targets|
        sources.map do |src|
          [FEATURE_SKILL_CHAIN, src, Hash[targets.map { |tgt| [tgt, tgt] }]]
        end
      end

      if HAND_COSTS.key?(:chain_mag_combat)
        add_entry(:chain_mag_combat, entry(
          "Chain: Magical Armament", HAND_COSTS[:chain_mag_combat],
          build_chain_features.call(MAGIC_STYPE_IDS, COMBAT_STYPE_IDS), [],
          6, :other, :chain_mag_combat, "Can chain Magic skills into Combat skills."
        ))
      end

      if HAND_COSTS.key?(:chain_job_combat)
        add_entry(:chain_job_combat, entry(
          "Chain: Gadget Weaponry", HAND_COSTS[:chain_job_combat],
          build_chain_features.call(JOB_STYPE_IDS, COMBAT_STYPE_IDS), [],
          6, :other, :chain_job_combat, "Can chain Job skills into Combat skills."
        ))
      end

      if HAND_COSTS.key?(:chain_job_magic)
        add_entry(:chain_job_magic, entry(
          "Chain: Literature Knowledge", HAND_COSTS[:chain_job_magic],
          build_chain_features.call(JOB_STYPE_IDS, MAGIC_STYPE_IDS), [],
          6, :other, :chain_job_magic, "Can chain Job skills into Magic skills."
        ))
      end

      if HAND_COSTS.key?(:chain_race_combat)
        add_entry(:chain_race_combat, entry(
          "Chain: Wild Assault", HAND_COSTS[:chain_race_combat],
          build_chain_features.call(RACIAL_STYPE_IDS, COMBAT_STYPE_IDS), [],
          6, :other, :chain_race_combat, "Can chain Race skills into Combat skills."
        ))
      end

      if HAND_COSTS.key?(:chain_mag_race)
        add_entry(:chain_mag_race, entry(
          "Chain: Natural Aptitude", HAND_COSTS[:chain_mag_race],
          build_chain_features.call(MAGIC_STYPE_IDS, RACIAL_STYPE_IDS), [],
          6, :other, :chain_mag_race, "Can chain Magic skills into Race skills."
        ))
      end

      if HAND_COSTS.key?(:chain_job_race)
        add_entry(:chain_job_race, entry(
          "Chain: Cunning Scavenger", HAND_COSTS[:chain_job_race],
          build_chain_features.call(JOB_STYPE_IDS, RACIAL_STYPE_IDS), [],
          6, :other, :chain_job_race, "Can chain Job skills into Race skills."
        ))
      end

      [
        [:chain_cost_down, "Chain Cost -50%", :chain_cost_down, [], ["<チェーン消費軽減 50%>"], 6, :chain_cost, "Chained skills cost 50% less."],
        [:chain_boost, "Chain Power +50%", :chain_boost, [], ["<チェーン強化 50%>"], 6, :chain_boost, "Chained skills deal +50% damage."]
      ].each do |key, name, cost_key, features, tags, stype, conflict, desc|
        next unless HAND_COSTS.key?(cost_key)
        add_entry(key, entry(name, HAND_COSTS[cost_key], features, tags, stype, :other, conflict, desc))
      end
    end

    def self.build_equip_access
      WEAPONS.each do |wtype_id, label, stype|
        add_entry(:"weapon_access_#{wtype_id}", entry("Equip: #{label}", 5,
          [[FEATURE_EQUIP_WTYPE, wtype_id, 0.0]], [], stype, :equipment_access, nil,
          "Can equip #{label}-type weapons."))
      end

      {
        :lightwear => ["Lightwear", LIGHTWEAR_ATYPES],
        :heavywear => ["Heavywear", HEAVYWEAR_ATYPES],
        :light_headgear => ["Light Headgear", LIGHT_HEADGEAR_ATYPES],
        :heavy_headgear => ["Heavy Headgear", HEAVY_HEADGEAR_ATYPES],
        :shield => ["Shield", SHIELD_ATYPES]
      }.each do |key, (name, atypes)|
        feats = atypes.map { |atype| [FEATURE_EQUIP_ATYPE, atype, 0.0] }
        add_entry(:"armor_access_#{key}", entry("Equip: #{name}", 5,
          feats, [], 4, :equipment_access, nil,
          "Can equip #{name} armor."))
      end
    end

    def self.build_skill_access
      SKILL_TYPES.each do |stype_id, label|
        grp = stype_for_skill_type(stype_id)
        e = entry("Skill Use: #{label}", 5, [[FEATURE_STYPE_ADD, stype_id, 0.0]], [], grp, :access, nil, "Can always use #{label} skills.")
        e[:hidden] = true if stype_id == 63
        add_entry(:"skill_type_#{stype_id}", e)
      end
    end

    def self.build_wields
      { 1 => [:dual_wield, "Dual Wield", :dual_wield],
        2 => [:dual_shield, "Dual Shield", :dual_shield],
        3 => [:triple_wield, "Triple Wield", :triple_wield] }.each do |data_id, (key, label, cost_key)|
        next unless HAND_COSTS.key?(cost_key)
        add_entry(:"slot_#{key}", entry(label, HAND_COSTS[cost_key],
          [[FEATURE_SLOT_TYPE, data_id, 0.0]], [], 5, :equipment_access, :slot_type, "#{label}."))
      end
    end

    COST_MODIFIER_ENTRIES = [
      [:mp_for_sp, "Pay SP Costs with MP", :mp_for_sp, [], ["<MP代替消費 100%>"], 6, :mp_for_sp, "SP costs are paid with MP instead."],
      [:save_items, "Save Items 50%", :save_items, [], ["<消費アイテム節約 1-50%>"], 6, :save_items, "Items have a 50% chance not to be used up."],
      [:ignore_items, "Ignore Item Requirement", :ignore_items, [], ["<必要アイテム無視 1>"], 6, :ignore_items, "Skills that need an item work without it."]
    ].freeze

    def self.build_cost_modifiers
      COST_MODIFIER_ENTRIES.each do |key, name, cost_key, features, tags, stype, conflict, desc|
        next unless HAND_COSTS.key?(cost_key)
        add_entry(key, entry(name, HAND_COSTS[cost_key], features, tags, stype, :other, conflict, desc))
      end
    end

    # def self.build_action
    #   [[:extra_action_50, "Extra Action 50%", :extra_action_50, 0.5], [:extra_action_100, "Extra Action", :extra_action_100, 1.0]].each do |key, name, cost_key, value|
    #     next unless HAND_COSTS.key?(cost_key)
    #     add_entry(key, entry(name, HAND_COSTS[cost_key], [[FEATURE_ACTION_PLUS, 0, value]], [], 1, :other, :extra_action, value >= 1.0 ? "Acts twice each turn." : "#{value * 100}% chance of one more action each turn."))
    #   end
    # end

    def self.build_state_effects
      STATES.each do |key, label, state_id|
        next if [:death, :ascension, :climax].include?(key)

        [[10, :status_strike_10], [25, :status_strike_25], [50, :status_strike_50]].each do |pct, cost_key|
          next unless HAND_COSTS.key?(cost_key)
          add_entry(:"inflict_#{key}_#{pct}", entry("#{label} Strike #{pct}%", HAND_COSTS[cost_key], [[FEATURE_ATK_STATE, state_id, pct / 100.0]], [], 2, :status_inflict, :"inflict_#{key}", "Innate #{pct}% #{label} strike."))
        end

        if HAND_COSTS.key?(:status_effect_50)
          add_entry(:"state_boost_#{key}", entry("#{label} Effect +50%", HAND_COSTS[:status_effect_50], [], ["<ステート増加効果アップ #{state_id}-50>"], 2, :other, :"state_boost_#{key}", "#{label}'s effect is 50% stronger."))
        end
      end
    end

    def self.build_utility
      if HAND_COSTS.key?(:learning)
        add_entry(:learning, entry("Learning", HAND_COSTS[:learning], [], ["<ラーニング>"], 5, :other, :learning, "Learns skills foes use."))
      end

      if HAND_COSTS.key?(:nightmare)
        add_entry(:succubus, entry("Nightmare Attribute", HAND_COSTS[:nightmare], [], ["<夢魔>"], 6, :other, :succubus, "Nightmare Attribute."))
      end

      # if HAND_COSTS.key?(:mug)
      #   add_entry(:mug, entry("Mug", HAND_COSTS[:mug], [], ["<固有習得 1-6933>"], 2, :other, :mug, "At the start of battle, attempt to mug an enemy."))
      # end
    end

    # def self.build_party
    #   [[:gold_from_damage, "Gold from Damage", "ダメージゴールド回収", "Gains gold equal to 10% of damage taken.", 6], [:mp_from_damage, "MP from Damage", "ダメージMP吸収", "Gains MP equal to 10% of damage taken.", 6], [:hp_drain, "HP Drain on Attack", "全攻撃HP還元", "Restores 10% HP on every attack.", 5], [:mp_drain, "MP Drain on Attack", "全攻撃MP還元", "Restores 10% MP on every attack.", 5]].each do |key, label, jp, desc, stype|
    #     next unless HAND_COSTS.key?(:damage_resist)
    #     add_entry(key, entry(label, HAND_COSTS[:damage_resist], [], ["<#{jp} 10%>"], stype, :other, key, desc))
    #   end
    # end

    # def self.build_terrain
    #   [[:desert, "Desert", "砂漠"], [:town, "Town", "市街"], [:cave, "Cave", "洞窟"]].each do |key, label, jp|
    #     if HAND_COSTS.key?(:damage_resist)
    #       add_entry(:"terrain_#{key}", entry("#{label} Strength", HAND_COSTS[:damage_resist], [], ["<#{jp}地形強化>"], 5, :other, :"terrain_#{key}", "Fights stronger in #{label.downcase}s."))
    #     end
    #     if HAND_COSTS.key?(:damage_null)
    #       add_entry(:"terrain_#{key}_super", entry("Super #{label} Strength", HAND_COSTS[:damage_null], [], ["<#{jp}地形超強化>"], 5, :other, :"terrain_#{key}", "Fights much stronger in #{label.downcase}s."))
    #     end
    #   end
    # end

    def self.build_hero_base
      add_entry(:hero_base, entry("Hero's Blood: Base", 0,
        [[FEATURE_STYPE_ADD, 63, 0.0], [FEATURE_XPARAM, 1, 0.05], [FEATURE_XPARAM, 2, 0.05], [FEATURE_SPARAM, 0, 0.50], [FEATURE_EQUIP_ATYPE, 41, 0.0], [FEATURE_EQUIP_WTYPE, 32, 0.0]],
        [], 6, :baseline, nil, "The baseline of a hero.").merge(:hidden => true))
    end

    def self.display_lines(character)
      keys = (character && character.trait_feature_keys || []).reject { |k| hidden?(k) }
      return ["There is nothing special about this character."] if keys.empty?

      pool = keys.map { |k| get(k) }.compact
      sentences = []

      # 0. Wields (Dual Wield, Dual Shield, Triple Wield)
      wields = pool.select { |e| e[:name] =~ /Wield/ }
      if wields.any?
        wields.each { |e| sentences << "Innate " + e[:name] + "." }
        pool -= wields
      end

      # 1. Stats (Hit, Crit, Evasion, etc.)
      # We look for any trait with MULTI_BOOSTER or XPARAM to handle custom additions
      stats = pool.select { |e| e[:kind] == :stat }
      if stats.any?
        sentences.concat(build_stat_sentences(stats))
        pool -= stats
      end

      # 2. Regen
      regens = pool.select { |e| e[:name] =~ / Regen \d+%/ }
      if regens.any?
        h = m = s = nil
        regens.each do |e|
          if e[:name] =~ /HP Regen (\d+)%/ then h = $1
          elsif e[:name] =~ /MP Regen (\d+)%/ then m = $1
          elsif e[:name] =~ /SP Regen (\d+)%/ then s = $1
          end
        end
        parts = []
        parts << "HP #{h}%" if h
        parts << "MP #{m}%" if m
        parts << "SP #{s}%" if s
        sentences << "#{parts.join('/')} Regen."
        pool -= regens
      end

      # 3. Counters (Physical, Magic, Nullify)
      # Extract them based on their names, but separate Physical from Magic
      phys_counters = pool.select { |e| e[:name] =~ /Counter Rate/ }
      magic_counters = pool.select { |e| e[:name] =~ /Magic Counter/ }
      nullify_counter = pool.select { |e| e[:key] == :nullify_counter }

      if phys_counters.any? || magic_counters.any?
        # Group by percentage
        phys_by_val = Hash.new { |h, k| h[k] = [] }
        magic_by_val = Hash.new { |h, k| h[k] = [] }
        
        phys_counters.each { |e| v = e[:name][/\d+/].to_i; phys_by_val[v] << "physical" }
        magic_counters.each { |e| v = e[:name][/\d+/].to_i; magic_by_val[v] << "magic" }

        # Combine percentages that match
        all_pcts = (phys_by_val.keys + magic_by_val.keys).uniq.sort.reverse
        all_pcts.each do |pct|
          has_phys = phys_by_val.key?(pct)
          has_mag = magic_by_val.key?(pct)
          
          if has_phys && has_mag
            sentences << "Counters #{pct}% of physical and magic attacks."
          elsif has_phys
            sentences << "Counters #{pct}% of physical attacks."
          elsif has_mag
            sentences << "Counters #{pct}% of magic attacks."
          end
        end
      end

      # 4. Status inflict & effect
      inflict = pool.select { |e| e[:kind] == :status_inflict }
      if inflict.any?
        by_pct = Hash.new { |h, k| h[k] = [] }
        inflict.each { |e| m = e[:name].match(/\A(.+) Strike (\d+)%\z/); by_pct[m[2].to_i] << m[1] if m }
        by_pct.keys.sort.reverse.each { |v| sentences << "Attacks inflict #{join_with_and(by_pct[v])} #{v}% of the time." }
        pool -= inflict
      end
      effect = pool.select { |e| e[:kind] == :other && e[:name] =~ / Effect \+(\d+)%/ }
      if effect.any?
        by_pct = Hash.new { |h, k| h[k] = [] }
        effect.each { |e| m = e[:name].match(/\A(.+) Effect \+(\d+)%\z/); by_pct[m[2].to_i] << m[1] if m }
        by_pct.keys.sort.reverse.each { |v| sentences << "The effects of #{join_with_and(by_pct[v])} are +#{v}% stronger." }
        pool -= effect
      end

      
      # 5. Access
      access = pool.select { |e| e[:kind] == :access }
      if access.any?
        sentences << "Can always use #{join_with_and(access.map { |e| e[:name].sub(/^Skill Use: /, "") })} skills."
        pool -= access
      end
      equip = pool.select { |e| e[:kind] == :equipment_access && e[:name] =~ /^Equip: / }
      if equip.any?
        sentences << "Can equip #{join_with_and(equip.map { |e| e[:name].sub(/^Equip: /, "") })}."
        pool -= equip
      end

      # 6. Element boosters
      e_boost = pool.select { |e| e[:kind] == :element_boost }
      if e_boost.any?
        by_val = Hash.new { |h, k| h[k] = [] }
        e_boost.each { |e| m = e[:name].match(/\A(.+) Booster (\d+)%\z/); by_val[m[2].to_i] << m[1] if m }
        by_val.keys.sort.reverse.each { |v| sentences << "Deals +#{v}% #{join_with_and(by_val[v])} damage." }
        pool -= e_boost
      end
      
      nullify_counter.each { |e| sentences << "Counters any attack nullified." }
      pool -= (phys_counters + magic_counters + nullify_counter)

      # 7. Weapon boosters (Equip)
      weapon_boost = pool.select { |e| e[:kind] == :weapon_boost }
      if weapon_boost.any?
        by_val = Hash.new { |h, k| h[k] = [] }
        weapon_boost.each { |e| m = e[:name].match(/\A(.+) Booster (\d+)%\z/); by_val[m[2].to_i] << m[1] if m }
        by_val.keys.sort.reverse.each { |v| sentences << "#{join_with_and(by_val[v])} weapons deal +#{v}% more damage." }
        pool -= weapon_boost
      end

      # 8. Skill boosters & Tenacity (Merged)
      skill_boost = pool.select { |e| e[:kind] == :skill_booster }
      tenacity = pool.select { |e| e[:kind] == :pinch_boost }
      if skill_boost.any? || tenacity.any?
        b_by_val = Hash.new { |h, k| h[k] = [] }
        skill_boost.each { |e| m = e[:name].match(/\A(.+) Skill Booster (\d+)%\z/); b_by_val[m[2].to_i] << m[1] if m }

        t_by_type = {}
        tenacity.each { |e| m = e[:name].match(/\A(.+) Tenacity \+(\d+)%\z/); t_by_type[m[1]] = m[2].to_i if m }

        b_by_val.keys.sort.reverse.each do |val|
          names = b_by_val[val]
          matched = names.select { |n| t_by_type.key?(n) }
          if matched.any?
            only_b = names - matched
            matched.each { |n| sentences << "#{n} skills deal +#{val}% more damage, gaining +#{t_by_type[n] / 100}% damage for every % of missing HP." }
            sentences << "#{join_with_and(only_b)} skills deal +#{val}% more damage." if only_b.any?
            matched.each { |n| t_by_type.delete(n) }
          else
            sentences << "#{join_with_and(names)} skills deal +#{val}% more damage."
          end
        end
        t_by_type.each { |n, c| sentences << "#{n} skills deal +#{c / 100}% damage for every % of missing HP." }
        pool -= skill_boost
        pool -= tenacity
      end

      # 9. Multi Strike (Rush)
      multi = pool.select { |e| e[:kind] == :multi_strike }
      if multi.any?
        sentences << "#{join_with_and(multi.map { |e| e[:name].sub(/ Rush\z/, "") })} skills act twice in a row, but costs 50% more to use."
        pool -= multi
      end

      # 10. Slayers
      slayers = pool.select { |e| e[:kind] == :slayer }
      if slayers.any?
        by_pct = Hash.new { |h, k| h[k] = [] }
        slayers.each { |e| m = e[:name].match(/\A(.+) Slayer(?: (\d+)%)?\z/); by_pct[m[2] ? m[2].to_i : 100] << m[1] if m }
        by_pct.keys.sort.reverse.each { |v| sentences << "Deals +#{v}% damage to #{join_with_and(by_pct[v])}." }
        pool -= slayers
      end
      slayer_boost = pool.select { |e| e[:kind] == :slayer_boost }
      if slayer_boost.any?
        sentences << "Slayer damage +50%."
        pool -= slayer_boost
      end

      # 11. Costs
      cost_levels = { 75 => "reduced", 50 => "halved", 25 => "quartered", 1 => "heavily reduced", 0 => "negated" }
      mp_costs = pool.select { |e| e[:kind] == :mp_cost }
      mp_costs.each { |e| sentences << "MP cost is #{cost_levels[(e[:features].first[2] * 100).round] || 'reduced'}." }
      pool -= mp_costs
      hp_costs = pool.select { |e| e[:kind] == :hp_cost }
      hp_costs.each { |e| sentences << "HP cost is #{cost_levels[(e[:features].first[2] * 100).round] || 'reduced'}." }
      pool -= hp_costs
      sp_costs = pool.select { |e| e[:kind] == :sp_cost }
      sp_costs.each { |e| sentences << "SP cost is #{cost_levels[(e[:features].first[2] * 100).round] || 'reduced'}." }
      pool -= sp_costs
      gold_costs = pool.select { |e| e[:kind] == :gold_cost }
      gold_costs.each { |e| sentences << "Gold cost is #{cost_levels[(e[:features].first[2] * 100).round] || 'reduced'}." }
      pool -= gold_costs

      # 12. Elemental resists
      resists = pool.select { |e| e[:kind] == :element_resist }
      if resists.any?
        by_tier = Hash.new { |h, k| h[k] = [] }
        resists.each do |e|
          m = e[:name].match(/\A(.+) (Resist|Half|Nullify)\z/)
          by_tier[m[2]] << m[1] if m
        end
        by_tier.each do |tier, list|
          case tier
          when "Resist"  then sentences << "Takes 50% less #{join_with_and(list)} damage."
          when "Half"    then sentences << "Takes halved #{join_with_and(list)} damage."
          when "Nullify" then sentences << "Immune to #{join_with_and(list)} damage."
          end
        end
        pool -= resists
      end

      # 13. Status resists
      status_resists = pool.select { |e| e[:kind] == :status_resist }
      if status_resists.any?
        normal = status_resists.select { |e| e[:name] =~ / Resist\z/ }.map { |e| e[:name].sub(/ Resist\z/, "") }
        nulls  = status_resists.select { |e| e[:name] =~ / Nullify\z/ }.map { |e| e[:name].sub(/ Nullify\z/, "") }
        sentences << "Resists #{join_with_and(normal)}." if normal.any?
        sentences << "Immune to #{join_with_and(nulls)}." if nulls.any?
        pool -= status_resists
      end

      # 14. Chests & terrains
      unlock = pool.select { |e| e[:kind] == :other && e[:conflict_group] == :unlock_level }
      if unlock.any?
        lvl = unlock.map { |e| e[:name][/\d+/].to_i }.max
        names = ["Blue"]
        names << "Green" if lvl >= 2
        names << "Silver" if lvl >= 3
        sentences << "Can always open #{join_with_and(names)} chests."
        pool -= unlock
      end
      terrains = pool.select { |e| e[:name] =~ /(Desert|Town|Cave) Strength/ }
      if terrains.any?
        normal = terrains.reject { |e| e[:name] =~ /Super/ }.map { |e| e[:name].split(" ")[0] }
        supers = terrains.select  { |e| e[:name] =~ /Super/ }.map { |e| e[:name].split(" ")[1] }
        sentences << "+20% stats in #{join_with_and(normal)}." if normal.any?
        sentences << "+40% stats in #{join_with_and(supers)}." if supers.any?
        pool -= terrains
      end

      # 15. Chains
      chains = pool.select { |e| e[:kind] == :other && e[:desc] =~ /^Can chain/ }
      if chains.any?
        sentences << chains.map { |e| e[:desc] }.join(" ")
        pool -= chains
      end

      # 16. Everything else
      pool.each { |e| sentences << e[:desc].to_s unless e[:desc].to_s.empty? }

      [sentences.reject { |s| s.to_s.empty? }.join(" ")]
    end

    def self.build_stat_sentences(entries)
      return [] if entries.empty?
      
      # We separate them by how we stored their features
      base = entries.select { |e| e[:features].first && e[:features].first[0] == FEATURE_PARAM }
      sp_entries = entries.select { |e| e[:name] =~ /\AMax SP \+(\d+)%\z/ }
      
      # Check both XPARAM and MULTI_BOOSTER for rates (Hit, Crit, Evasion)
      rates = entries.select do |e| 
        f = e[:features].first
        f && (
          (f[0] == FEATURE_XPARAM && [0,1,2,4].include?(f[1])) ||
          (f[0] == FEATURE_MULTI_BOOSTER && f[1] == 15) # 15 is Critical
        )
      end
      
      # Check Regen
      regens = entries.select { |e| e[:features].first && e[:features].first[0] == FEATURE_XPARAM && [7,8,9].include?(e[:features].first[1]) }

      sentences = []
      
      if base.any? || sp_entries.any?
        by_val = Hash.new { |h,k| h[k] = [] }
        base.each { |e| f = e[:features].first; by_val[f[2]] << f[1] }

        by_val.each do |val, ids|
          pct = ((val - 1.0) * 100).round
          hp = entries.any? { |e| e[:name] == "Max HP +#{pct}%" }
          mp = entries.any? { |e| e[:name] == "Max MP +#{pct}%" }
          sp = sp_entries.any? { |e| e[:name] == "Max SP +#{pct}%" }

          if hp && mp && sp
            sentences << "Max HP/MP/SP +#{pct}%."
            ids = ids - [0, 1]
            sp_entries.reject! { |e| e[:name] == "Max SP +#{pct}%" }
          end

          combat_ids = ids & [2, 3, 4, 5, 6, 7]
          if combat_ids.size == 6
            sentences << "All stats +#{pct}%."
            ids = ids - [2, 3, 4, 5, 6, 7]
          end

          next if ids.empty?
          names = ids.map { |id| STAT_PARAM_NAMES[id] }.compact
          sentences << "#{join_with_and(names)} +#{pct}%."
        end

        sp_entries.each do |e|
          pct = e[:name][/\d+/]
          sentences << "Max SP +#{pct}%."
        end
      end

      # Group rates
      if rates.any?
        by_val = Hash.new { |h,k| h[k] = [] }
          rates.each do |e|
            f = e[:features].first
            if f[0] == FEATURE_MULTI_BOOSTER && f[1] == 15
              by_val[f[2]] << (e[:name].include?("Damage") ? "Critical Damage" : "Critical Rate")
            else
              by_val[f[2]] << STAT_RATE_NAMES[f[1]]
            end
          end
        
        by_val.each do |val, ids|
          names = ids.compact.uniq
          sentences << "+#{(val * 100).round}% #{join_with_and(names)}." if names.any?
        end
      end

      # Group regens
      if regens.any?
        h = m = s = nil
        regens.each do |e|
          f = e[:features].first
          if f[1] == XPARAM_HP_REGEN then h = (f[2] * 100).round
          elsif f[1] == XPARAM_MP_REGEN then m = (f[2] * 100).round
          elsif f[1] == XPARAM_TP_REGEN then s = (f[2] * 100).round
          end
        end
        parts = []
        parts << "HP #{h}%" if h
        parts << "MP #{m}%" if m
        parts << "SP #{s}%" if s
        sentences << "#{parts.join('/')} Regen."
      end
      
      sentences
    end

    def self.join_with_and(items)
      return items.first.to_s if items.size <= 1
      return "#{items[0]} and #{items[1]}" if items.size == 2
      "#{items[0..-2].join(', ')}, and #{items[-1]}"
    end
  end

  #=== Trait Dashboard ======================================================
  class Window_TraitCommands < Window_Command
    COMMANDS = [
      [:rename, "Rename"],
      [:edit,   "Edit"],
      [:save,   "Save"],
      [:cancel, "Cancel"],
    ].freeze

    CELL_PADDING = 24

    LABEL_WIDTH = begin
      bmp = Bitmap.new(1, 1)
      w = COMMANDS.map { |_, label| bmp.text_size(label).width }.max
      bmp.dispose unless bmp.disposed?
      w
    rescue
      60
    end

    def window_width
      col_max * item_width + spacing * (col_max - 1) + standard_padding * 2
    end

    def window_height; fitting_height(1); end
    def horizontal?; true; end
    def col_max; COMMANDS.size; end
    def item_width; LABEL_WIDTH + CELL_PADDING; end

    def make_command_list
      COMMANDS.each { |key, label| add_command(label, key, true, key) }
    end

    def draw_item(index)
      rect = item_rect_for_text(index)
      change_color(normal_color, command_enabled?(index))
      draw_text(rect, command_name(index), 1)
    end

    def current_key; current_ext; end
  end

  class Window_TraitHeader < Window_Base
    FACE_SIZE = 96
    FACE_PAD  = 8
    LINE_GAP  = 4
    COST_PAD  = 4
    COST_LABEL_WIDTH = 60

    def initialize(x, y, width)
      text_height = line_height * 4 + LINE_GAP * 3
      inner = [FACE_SIZE + FACE_PAD * 2, text_height + FACE_PAD * 2].max
      super(x, y, width, inner + standard_padding * 2)
      refresh
    end

    def character; CharacterCreation.draft; end
    def total_cost; TraitFeatures.total_cost(equipped_keys); end
    def max_cost; TraitFeatures::MAX_TRAIT_COST; end
    def equipped_keys; (character && character.trait_feature_keys) || []; end

    def refresh
      contents.clear
      draw_face_column
      draw_text_column
    end

    def draw_face_column
      path = face_path
      return draw_face_placeholder unless path
      bmp = Bitmap.new(path)
      CharacterCreation.draw_face_fitted(
        contents,
        Rect.new(FACE_PAD, FACE_PAD, FACE_SIZE, FACE_SIZE),
        bmp
      )
      bmp.dispose unless bmp.disposed?
    rescue => e
      CharacterCreation.log("TraitHeader face FAILED: #{e.class}: #{e.message}")
      draw_face_placeholder
    end

    def face_path
      c = character
      return nil unless c
      path = File.join(CharacterCreation::CACHE_DIR, c.key.to_s, "face.png")
      File.exist?(path) ? path : nil
    end

    def draw_face_placeholder
      contents.fill_rect(FACE_PAD, FACE_PAD, FACE_SIZE, FACE_SIZE, Color.new(40, 40, 40))
      change_color(system_color)
      draw_text(FACE_PAD, FACE_PAD + FACE_SIZE / 2 - line_height / 2,
                FACE_SIZE, line_height, "(no face)", 1)
    end

    def draw_text_column
      c = character
      return unless c

      x = FACE_PAD + FACE_SIZE + FACE_PAD
      max_w = contents_width - x - FACE_PAD
      return if max_w <= 0

      has_artist = c.artist && !c.artist.empty?
      text_height = line_height * (has_artist ? 5 : 4) + LINE_GAP * (has_artist ? 4 : 3)

      text_top = FACE_PAD + (FACE_SIZE - text_height) / 2
      text_top = FACE_PAD if text_top < FACE_PAD

      change_color(normal_color)
      draw_text(x, text_top, max_w, line_height, c.name.to_s, 0)
      y = text_top + line_height + LINE_GAP

      if has_artist
        change_color(tp_gauge_color2)
        draw_text(x, y, max_w, line_height, "Art: #{c.artist}", 0)
        y += line_height + LINE_GAP
      end

      change_color(system_color)
      job  = class_name(c.job)
      race = class_name(c.race)
      draw_text(x, y, max_w, line_height, "#{job} / #{race}", 0)
      y += line_height + LINE_GAP

      rate = max_cost > 0 ? [total_cost.to_f / max_cost, 1.0].min : 0.0
      draw_gauge(x, y, max_w, rate, tp_gauge_color1, cost_color)

      change_color(normal_color, true)
      draw_text(x, y, COST_LABEL_WIDTH, line_height, "Cost", 0)
      change_color(cost_color, true)
      draw_text(x + COST_LABEL_WIDTH, y, max_w - COST_LABEL_WIDTH, line_height, "#{total_cost}/#{max_cost}", 0)
    end

    def class_name(id)
      return "" unless id && id > 0
      data = $data_classes && $data_classes[id]
      data ? data.name.to_s : ""
    end

    def cost_color
      total_cost > max_cost ? crisis_color : tp_gauge_color2
    end
  end

  class Window_TraitFeatureList < Window_Selectable
    def initialize(x, y, width, height)
      @character = nil
      @pending_key = nil
      super(x, y, width, height)
      refresh
    end

    def character; @character || CharacterCreation.draft; end
    attr_accessor :pending_key

    def keys
      all = (character && character.trait_feature_keys) || []
      all.reject { |k| TraitFeatures.hidden?(k) }
    end

    def item_max; keys.size + 1; end

    def draw_item(index)
      rect = item_rect(index)
      return unless rect
      contents.fill_rect(rect, pending_color) if index == pending_index
      if index >= keys.size
        draw_add_row(index)
      else
        draw_key_row(index)
      end
    end

    def pending_index
      return -1 unless @pending_key
      keys.index(@pending_key) || -1
    end

    def draw_key_row(index)
      key = keys[index]
      entry = TraitFeatures.get(key)
      name = entry ? entry[:name] : key.to_s
      cost = entry ? entry[:cost] : 0
      icon = entry ? entry[:icon].to_i : 0
      rect = item_rect_for_text(index)

      change_color(system_color)
      draw_text(rect.x, rect.y, 24, line_height, "E:")

      name_x = rect.x + 24
      if icon > 0
        draw_icon(icon, name_x, rect.y, true)
        name_x += 24
      end

      change_color(normal_color, true)
      draw_text(name_x, rect.y,
                rect.width - (name_x - rect.x) - 32, line_height, name)
      change_color(system_color)
      draw_text(rect.x + rect.width - 32, rect.y, 32, line_height, cost.to_s, 2)
    end

    def draw_add_row(index)
      rect = item_rect_for_text(index)
      change_color(system_color)
      draw_text(rect.x, rect.y, rect.width, line_height, "(empty)")
    end

    def refresh
      create_contents
      draw_all_items
      @index = 0 if @index.nil? || @index < 0 || @index >= item_max
      update_cursor
    end

    def set_character(c)
      @character = c
      refresh
    end

    def current_key
      return nil if index.nil? || index >= keys.size
      keys[index]
    end

    def on_blank?; index == keys.size; end
  end

  class Window_TraitPickerHeader < Window_Base
    def initialize(x, y, width, height)
      super(x, y, width, height)
      @label  = ""
      @count  = ""
      refresh
    end

    def set_group(label, position, total, cursor, items)
      @label = label.to_s
      @count = "#{position}/#{total}, #{cursor}/#{items}"
      refresh
    end

    def refresh
      contents.clear
      change_color(crisis_color, true)
      draw_text(0, 0, contents_width - 120, line_height, @label, 0)
      change_color(system_color, true)
      draw_text(contents_width - 120, 0, 120, line_height, @count, 2)
    end
  end

  class Window_TraitFeaturePicker < Window_Selectable
    def initialize(x, y, width, height)
      @character = nil
      @pending_key = nil
      @groups = []
      @group_index = 0
      @entries = []
      super(x, y, width, height)
      refresh
    end

    def character; @character || CharacterCreation.draft; end
    attr_accessor :pending_key

    def header=(h)
      @header = h
      notify_header
    end

    def entries; @entries; end

    def rebuild_entries
      return unless character
      equipped = (character.trait_feature_keys || [])

      @groups = TraitFeatures.keys_by_group.map do |group, keys|
        available = keys.reject { |k| equipped.include?(k) }
                         .reject { |k| TraitFeatures.hidden?(k) }
        [group, available]
      end

      @groups = @groups.reject { |_, keys| keys.nil? || keys.empty? }

      if @groups.empty?
        @entries = []
        @group_index = 0
      else
        @group_index = [[@group_index, 0].max, @groups.size - 1].min
        @entries = @groups[@group_index][1]
      end

      @index = 0 if @index.nil? || @index >= @entries.size
      refresh
    end

    def group_header_info
      return ["", 0, 0, 0, 0] if @groups.empty?
      group, keys = @groups[@group_index]
      cursor = (@index || 0) + 1
      [TraitFeatures.group_label(group), @group_index + 1, @groups.size, cursor, keys.size]
    end

    def notify_header
      return unless @header
      label, position, total, cursor, items = group_header_info
      @header.set_group(label, position, total, cursor, items)
    end

    def item_max; @entries.size; end

    def draw_item(index)
      rect = item_rect_for_text(index)
      return unless rect
      key = @entries[index]
      entry = TraitFeatures.get(key)
      return unless entry
      ok = affordable?(key)
      icon = entry[:icon].to_i

      name_x = rect.x
      if icon > 0
        draw_icon(icon, rect.x, rect.y, ok)
        name_x = rect.x + 24
      end

      change_color(normal_color, ok)
      draw_text(name_x, rect.y,
                rect.width - (name_x - rect.x) - 32,
                line_height, entry[:name])

      change_color(system_color)
      draw_text(rect.x + rect.width - 32, rect.y,
                32, line_height, entry[:cost].to_s, 2)
    end

    def process_cursor_move
      if Input.trigger?(:LEFT)
        cursor_left
        Sound.play_cursor if Sound.respond_to?(:play_cursor)
        return
      elsif Input.trigger?(:RIGHT)
        cursor_right
        Sound.play_cursor if Sound.respond_to?(:play_cursor)
        return
      end
      super
    end

    def update_cursor
      super
      notify_header
    end

    def refresh
      create_contents
      draw_all_items
      @index = 0 if @index.nil? || @index < 0 || @index >= item_max
      update_cursor
    end

    def cursor_left(wrap = true)
      return if @groups.empty?
      @group_index = (@group_index - 1) % @groups.size
      @entries = @groups[@group_index][1]
      @index = 0
      refresh
      notify_header
    end

    def cursor_right(wrap = true)
      return if @groups.empty?
      @group_index = (@group_index + 1) % @groups.size
      @entries = @groups[@group_index][1]
      @index = 0
      refresh
      notify_header
    end

    def affordable?(key)
      return true unless character
      entry = TraitFeatures.get(key)
      return true unless entry
      future = (character.trait_feature_keys || []).dup
      future.delete(@pending_key) if @pending_key
      future << key unless future.include?(key)
      TraitFeatures.total_cost(future) <= TraitFeatures::MAX_TRAIT_COST
    end

    def process_ok
      return unless current_item_enabled?
      Input.update
      call_ok_handler
    end

    def call_ok_handler
      call_handler(:ok)
      activate
    end

    def set_character(c)
      @character = c
      @groups = []
      @entries = []
      rebuild_entries
      notify_header
    end

    def current_catalogue_key
      return nil if index.nil? || index < 0 || index >= @entries.size
      @entries[index]
    end
  end

  class Window_TraitPreview < Window_Base
    def initialize(x, y, width, height)
      super(x, y, width, height)
      refresh
    end

    def character; CharacterCreation.draft; end

    def refresh
      contents.clear
      c = character
      return unless c
      title = c.trait_name.to_s
      title = "(no trait)" if title.empty?
      change_color(crisis_color, true)
      draw_text(0, 0, contents_width, line_height, title)
      y = line_height + 8
      change_color(normal_color)
      preview_lines(c).each do |line|
        break if y + line_height > contents_height
        y = draw_wrapped_line(0, y, contents_width, line)
      end
    end

    def preview_lines(c)
      TraitFeatures.display_lines(c)
    end

    def join_with_and(items)
      return items.first.to_s if items.size <= 1
      return "#{items[0]} and #{items[1]}" if items.size == 2
      "#{items[0..-2].join(', ')}, and #{items[-1]}"
    end

    def draw_wrapped_line(x, y, width, text)
      return y unless text
      words = text.split(/\s+/)
      return y if words.empty?
      line = ""
      words.each do |word|
        candidate = line.empty? ? word : "#{line} #{word}"
        if text_size(candidate).width > width && !line.empty?
          draw_text(x, y, width, line_height, line)
          y += line_height
          line = word
        else
          line = candidate
        end
      end
      draw_text(x, y, width, line_height, line) unless line.empty?
      y + line_height
    end
  end

  class Scene_TraitDashboard < Scene_MenuBase
    MARGIN = 8
    GAP    = 8

    EQUIP_SE = RPG::SE.new("Equip1")

    def play_equip_se
      EQUIP_SE.play
    rescue
    end

    def start
      super
      @character = CharacterCreation.draft
      return_to_dashboard unless @character
      @character.trait_feature_keys ||= []
      if @character.trait_feature_keys.empty? && @character.features && !@character.features.empty?
        @character.trait_feature_keys = match_keys_from_features(@character)
      end
      @snapshot = snapshot_character(@character)
      @dirty = false
      @pending_key = nil
      build_windows
      rebuild_all
      @cmd_window.activate
    end

    def update
      if CharacterCreation.pending_refresh
        CharacterCreation.pending_refresh = false
        @header.refresh
        @preview.refresh
      end
      super
      handle_remove_key
    end

    def return_to_dashboard
      SceneManager.return
    end

    def match_keys_from_features(c)
      matched = []
      TraitFeatures.keys.each do |k|
        next if TraitFeatures.hidden?(k)
        entry = TraitFeatures.get(k)
        next unless entry
        all_present = entry[:features].all? { |f| TraitFeatures.feature_present?(c, f) } &&
                      entry[:tags].all?     { |t| TraitFeatures.tag_present?(c, t) }
        next unless all_present
        next if entry[:features].empty? && entry[:tags].empty?
        matched << k
      end
      matched
    end

    def build_windows
      top = MARGIN
      @cmd_window = Window_TraitCommands.new(MARGIN, top)
      @cmd_window.set_handler(:ok,     method(:on_command))
      @cmd_window.set_handler(:cancel, method(:on_cancel))

      top += @cmd_window.height + GAP
      avail_w = Graphics.width - MARGIN * 2

      list_w = (avail_w * 0.50).to_i
      prev_x = MARGIN + list_w + GAP
      prev_w = avail_w - list_w - GAP

      @header = Window_TraitHeader.new(MARGIN, top, list_w)
      top += @header.height + GAP

      list_top    = top
      list_bottom = Graphics.height - MARGIN
      list_h      = list_bottom - list_top
      preview_top    = list_top - @header.height - GAP
      preview_height = list_bottom - preview_top

      @list = Window_TraitFeatureList.new(MARGIN, list_top, list_w, list_h)
      @list.set_handler(:ok,     method(:on_list_ok))
      @list.set_handler(:cancel, method(:on_list_cancel))

      @preview = Window_TraitPreview.new(prev_x, preview_top, prev_w, preview_height)

      picker_header_h = @preview.fitting_height(1)
      @picker_header = Window_TraitPickerHeader.new(
        prev_x, preview_top, prev_w, picker_header_h
      )
      @picker = Window_TraitFeaturePicker.new(
        prev_x, preview_top + picker_header_h, prev_w,
        preview_height - picker_header_h
      )
      @picker.set_handler(:ok,     method(:on_picker_ok))
      @picker.set_handler(:cancel, method(:on_picker_cancel))
      @picker.header = @picker_header
      @picker.hide
      @picker.deactivate
      @picker_header.hide
    end

    def rebuild_all
      @header.refresh
      @list.pending_key = @pending_key
      @list.set_character(@character)
      @preview.refresh
    end

    def refresh_after_edit
      sync_character
      @header.refresh
      @list.pending_key = @pending_key
      @list.refresh
      @preview.refresh
    end

    def sync_character
      c = @character
      return unless c
      c.features = []
      c.tags = []
      c.trait_feature_keys.each do |key|
        entry = TraitFeatures.get(key)
        next unless entry
        TraitFeatures.add_features(c, entry[:features])
        TraitFeatures.add_tags(c, entry[:tags])
      end
      c.trait_lines = build_trait_lines(c)
    end

    def build_trait_lines(c)
      TraitFeatures.display_lines(c)
    end

    def on_command
      case @cmd_window.current_key
      when :rename then on_rename
      when :edit   then on_edit
      when :save   then on_save
      when :cancel then on_cancel
      end
    end

    def on_rename
      Sound.play_ok if Sound.respond_to?(:play_ok)
      CharacterCreation.text_input_target = :trait_name
      SceneManager.call(CharacterCreation::Scene_TextInput)
    end

    def on_edit
      @cmd_window.deactivate
      @list.activate
      @list.select(0) if @list.index.nil? || @list.index >= @list.item_max
    end

    def on_save
      if over_budget?
        Sound.play_buzzer if Sound.respond_to?(:play_buzzer)
        return
      end
      sync_character
      if @character.trait_name.to_s.empty?
        @character.trait_name = default_trait_name(@character)
      end
      play_equip_se
      @snapshot = nil
      SceneManager.return
    end

    def on_cancel
      restore_character(@character, @snapshot) if @snapshot
      Sound.play_cancel if Sound.respond_to?(:play_cancel)
      SceneManager.return
    end

    def on_list_ok
      @pending_key = @list.current_key
      open_picker
    end

    def on_list_cancel
      @list.deactivate
      @cmd_window.activate
    end

    def open_picker
      @picker.pending_key = @pending_key
      @picker.set_character(@character)
      @picker.show
      @picker_header.show
      @picker.activate
      @list.deactivate
    end

    def hide_picker
      @picker.deactivate
      @picker.hide
      @picker_header.hide
      @list.pending_key = @pending_key
      @list.activate
    end

    def evict_stat_conflicts(key)
      TraitFeatures.evict_conflicts(@character, key)
    end

    def on_picker_ok
      key = @picker.current_catalogue_key
      if key.nil?
        hide_picker
        return
      end
      entry = TraitFeatures.get(key)
      if entry.nil?
        hide_picker
        return
      end

      future_keys = @character.trait_feature_keys.dup
      future_keys.delete(@pending_key) if @pending_key
      future_keys << key unless future_keys.include?(key)
      if TraitFeatures.total_cost(future_keys) > TraitFeatures::MAX_TRAIT_COST
        Sound.play_buzzer if Sound.respond_to?(:play_buzzer)
        @picker.activate
        @picker.refresh
        return
      end

      evict_stat_conflicts(key)
      if @pending_key && @character.trait_feature_keys.include?(@pending_key)
        pos = @character.trait_feature_keys.index(@pending_key)
        @character.trait_feature_keys[pos] = key
      else
        @character.trait_feature_keys << key unless @character.trait_feature_keys.include?(key)
      end
      @pending_key = nil
      @dirty = true

      play_equip_se
      refresh_after_edit
      hide_picker
    end

    def on_picker_cancel
      @pending_key = nil
      @picker.pending_key = nil
      refresh_after_edit
      hide_picker
    end

    def return
      super
      if @character
        @header.refresh
        @preview.refresh
      end
    end

    def handle_remove_key
      return unless @list.active
      return unless Input.trigger?(:A)
      key = @list.current_key
      return if key.nil?
      remove_key(key)
    end

    def remove_key(key)
      @character.trait_feature_keys.delete(key)
      @dirty = true
      play_equip_se
      max_i = [@list.item_max - 1, 0].max
      @list.select([@list.index || 0, max_i].min)
      refresh_after_edit
    end

    def total_cost
      TraitFeatures.total_cost(@character.trait_feature_keys)
    end

    def over_budget?
      total_cost > TraitFeatures::MAX_TRAIT_COST
    end

    def default_trait_name(c)
      return "Custom Trait" if c.trait_feature_keys.empty?
      first = TraitFeatures.get(c.trait_feature_keys.first)
      first && first[:name] ? "#{first[:name]}..." : "Custom Trait"
    end

    def snapshot_character(c)
      {
        :name     => c.trait_name,
        :lines    => (c.trait_lines || []).dup,
        :features => (c.features || []).map { |f| f.dup },
        :tags     => (c.tags || []).dup,
        :keys     => (c.trait_feature_keys || []).dup,
      }
    end

    def restore_character(c, snap)
      c.trait_name  = snap[:name]
      c.trait_lines = snap[:lines].dup
      c.features    = snap[:features].map { |f| f.dup }
      c.tags        = snap[:tags].dup
      c.trait_feature_keys = snap[:keys].dup
    end

    def terminate
      [@picker_header, @picker, @list, @preview, @header, @cmd_window].each do |w|
        w.dispose if w && !w.disposed?
      end
      super
    end
  end

  #=== TraitAudit ===========================================================
  module TraitAudit
    AUDIT_KEY = :F7

    STEPS = [
      :catalogue_compact,
      :weapon_booster,
      :skill_booster,
      :skill_tenacity_and_multi,
      :slayer,
      :resist,
      :cost,
      :smoke_check,
      :skill_access,
      :equip_access,
      :catalogue_full,
    ].freeze

    @index = 0
    class << self
      attr_accessor :index
    end

    def self.log(msg)
      CharacterCreation.log(msg)
    rescue
    end

    def self.dump_entry(key)
      e = TraitFeatures.get(key)
      unless e
        log("[TraitAudit] no entry for #{key.inspect}")
        return
      end
      log("[TraitAudit] #{key}: name=#{e[:name].inspect} cost=#{e[:cost].inspect} " \
          "group=#{e[:group].inspect} stype=#{e[:stype]} kind=#{e[:kind].inspect} " \
          "conflict=#{e[:conflict_group].inspect} hidden=#{TraitFeatures.hidden?(key)}")
      log("[TraitAudit] #{key}:   features=#{TraitData.describe_features(e[:features])}")
      log("[TraitAudit] #{key}:   tags=#{Array(e[:tags]).inspect}")
    end

    def self.dump_family(prefix)
      return unless prefix
      hits = TraitFeatures.keys.select { |k| k.to_s.start_with?(prefix.to_s) }
      log("[TraitAudit] family #{prefix.inspect}: #{hits.size} entries")
      hits.each { |k| dump_entry(k) }
    end

    def self.dump_family_matching(&block)
      hits = TraitFeatures.keys.select { |k| block.call(k) }
      log("[TraitAudit] matching family: #{hits.size} entries")
      hits.each { |k| dump_entry(k) }
    end

    def self.audit_family(prefix)
      hits = TraitFeatures.keys.select { |k| k.to_s.start_with?(prefix.to_s) }
      log("[TraitAudit] audit #{prefix.inspect}: #{hits.size} entries")
      hits.each { |k| log("[TraitAudit]   #{audit_line(k)}") }
    end

    def self.audit_family_matching(&block)
      hits = TraitFeatures.keys.select { |k| block.call(k) }
      log("[TraitAudit] audit matching: #{hits.size} entries")
      hits.each { |k| log("[TraitAudit]   #{audit_line(k)}") }
    end

    def self.audit_line(key)
      e = TraitFeatures.get(key)
      return "  #{key}: (missing)" unless e
      "  #{key}: cost=#{e[:cost].inspect} features=#{e[:features].size} tags=#{Array(e[:tags]).size} " \
      "kind=#{e[:kind].inspect} group=#{e[:group].inspect}"
    end

    def self.dump_catalogue(is_compact = true)
      log("[TraitAudit] catalogue: #{TraitFeatures.keys.size} entries")
      if is_compact
        TraitFeatures.keys.sort_by(&:to_s).each { |k| log("[TraitAudit]   #{audit_line(k)}") }
      else
        TraitFeatures.keys.sort_by(&:to_s).each { |k| dump_entry(k) }
      end
    end

    def self.apply_to_draft(keys)
      c = CharacterCreation.draft
      unless c
        log("[TraitAudit.apply_to_draft] no draft")
        return
      end
      c.trait_feature_keys = Array(keys).dup
      log("[TraitAudit.apply_to_draft] set #{c.trait_feature_keys.inspect}")
    end

    def self.smoke_check_heros_blood
      return unless defined?(CharacterCreation::StandardTags)
      fresh = CharacterCreation.new_character(:__audit__)
      standard = CharacterCreation::StandardTags.tags_for(fresh)
      trait_tags = (CharacterCreation::TraitLibrary.get(:heros_blood)[:tags] || [])
      missing = trait_tags - standard
      extra   = standard - trait_tags
      log("[TraitAudit.smoke] standard_tags=#{standard.size} trait_tags=#{trait_tags.size}")
      log("[TraitAudit.smoke] in trait but not StandardTags: #{missing.inspect}")
      log("[TraitAudit.smoke] in StandardTags but not trait: #{extra.inspect}")
    end

    def self.cycle_next
      step = STEPS[@index % STEPS.size]
      log("[TraitAudit/F7] step #{@index + 1}/#{STEPS.size}: #{step}")
      begin
        cycle_step(step)
      rescue => e
        log("[TraitAudit/F7] #{step} FAILED: #{e.class}: #{e.message}")
        log(e.backtrace.first(6).join(" | ")) if e.backtrace
      end
      @index = (@index + 1) % STEPS.size
    end

    def self.cycle_step(step)
      case step
      when :catalogue_compact   then dump_catalogue(true)
      when :weapon_booster      then audit_family_matching { |k| k.to_s =~ /_booster_\d+$/ }
      when :skill_booster       then audit_family_matching { |k| k.to_s =~ /^skill_booster_\d+_\d+$/ }
      when :skill_tenacity_and_multi then
        audit_family_matching { |k| k.to_s =~ /^skill_tenacity_\d+$/ }
        audit_family_matching { |k| k.to_s =~ /^multi_strike_type_\d+$/ }
      when :slayer              then audit_family(:slayer_)
      when :resist              then audit_family_matching { |k| k.to_s =~ /_resist_/ }
      when :cost                then
        audit_family(:mp_cost_)
        audit_family(:hp_cost_)
        audit_family(:sp_cost_)
        audit_family(:gold_cost_)
        audit_family(:chain_)
        audit_family(:heroism_)
        audit_family(:save_items)
        audit_family(:ignore_items)
        audit_family(:mp_for_sp)
      when :smoke_check         then smoke_check_heros_blood
      when :skill_access        then audit_family(:skill_type_)
      when :equip_access        then
        audit_family(:weapon_access_)
        audit_family(:armor_access_)
      when :catalogue_full      then dump_catalogue(false)
      else
        log("[TraitAudit/F7] unknown step #{step.inspect}")
      end
    end

    def self.install
      return if @installed
      return unless AUDIT_KEY
      return unless defined?(Scene_Map)
      @installed = true
      Scene_Map.class_eval do
        alias_method :cc_trait_audit_update, :update unless method_defined?(:cc_trait_audit_update)
        def update(*args)
          cc_trait_audit_update(*args)
          return unless Input.trigger?(CharacterCreation::TraitAudit::AUDIT_KEY)
          begin
            CharacterCreation::TraitAudit.cycle_next
          rescue => e
            CharacterCreation.log("[TraitAudit/F7] crashed: #{e.class}: #{e.message}")
          end
        end
      end
      CharacterCreation.log("TraitAudit: #{AUDIT_KEY} installed")
    end
  end
end

# Build the catalogue and install the audit hook.
CharacterCreation::TraitFeatures.build_catalogue
CharacterCreation::TraitAudit.install

CharacterCreation.log("CC_Data_Traits loaded")