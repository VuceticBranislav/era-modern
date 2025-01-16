const
(* Creature IDs *)
NO_MON                  = -1;
ANY_MON                 = -1;
MON_FIRST               = 0;
MON_PIKEMAN             = 0;
MON_HALBERDIER          = 1;
MON_ARCHER              = 2;
MON_MARKSMAN            = 3;
MON_GRIFFIN             = 4;
MON_ROYAL_GRIFFIN       = 5;
MON_SWORDSMAN           = 6;
MON_CRUSADER            = 7;
MON_MONK                = 8;
MON_ZEALOT              = 9;
MON_CAVALIER            = 10;
MON_CHAMPION            = 11;
MON_ANGEL               = 12;
MON_ARCHANGEL           = 13;
MON_CENTAUR             = 14;
MON_CENTAUR_CAPTAIN     = 15;
MON_DWARF               = 16;
MON_BATTLE_DWARF        = 17;
MON_WOOD_ELF            = 18;
MON_GRAND_ELF           = 19;
MON_PEGASUS             = 20;
MON_SILVER_PEGASUS      = 21;
MON_DENDROID_GUARD      = 22;
MON_DENDROID_SOLDIER    = 23;
MON_UNICORN             = 24;
MON_WAR_UNICORN         = 25;
MON_GREEN_DRAGON        = 26;
MON_GOLD_DRAGON         = 27;
MON_GREMLIN             = 28;
MON_MASTER_GREMLIN      = 29;
MON_STONE_GARGOYLE      = 30;
MON_OBSIDIAN_GARGOYLE   = 31;
MON_STONE_GOLEM         = 32;
MON_IRON_GOLEM          = 33;
MON_MAGE                = 34;
MON_ARCH_MAGE           = 35;
MON_GENIE               = 36;
MON_MASTER_GENIE        = 37;
MON_NAGA                = 38;
MON_NAGA_QUEEN          = 39;
MON_GIANT               = 40;
MON_TITAN               = 41;
MON_IMP                 = 42;
MON_FAMILIAR            = 43;
MON_GOG                 = 44;
MON_MAGOG               = 45;
MON_HELL_HOUND          = 46;
MON_CERBERUS            = 47;
MON_DEMON               = 48;
MON_HORNED_DEMON        = 49;
MON_PIT_FIEND           = 50;
MON_PIT_LORD            = 51;
MON_EFREETI             = 52;
MON_EFREET_SULTAN       = 53;
MON_DEVIL               = 54;
MON_ARCH_DEVIL          = 55;
MON_SKELETON            = 56;
MON_SKELETON_WARRIOR    = 57;
MON_WALKING_DEAD        = 58;
MON_ZOMBIE              = 59;
MON_WIGHT               = 60;
MON_WRAITH              = 61;
MON_VAMPIRE             = 62;
MON_VAMPIRE_LORD        = 63;
MON_LICH                = 64;
MON_POWER_LICH          = 65;
MON_BLACK_KNIGHT        = 66;
MON_DREAD_KNIGHT        = 67;
MON_BONE_DRAGON         = 68;
MON_GHOST_DRAGON        = 69;
MON_TROGLODYTE          = 70;
MON_INFERNAL_TROGLODYTE = 71;
MON_HARPY               = 72;
MON_HARPY_HAG           = 73;
MON_BEHOLDER            = 74;
MON_EVIL_EYE            = 75;
MON_MEDUSA              = 76;
MON_MEDUSA_QUEEN        = 77;
MON_MINOTAUR            = 78;
MON_MINOTAUR_KING       = 79;
MON_MANTICORE           = 80;
MON_SCORPICORE          = 81;
MON_RED_DRAGON          = 82;
MON_BLACK_DRAGON        = 83;
MON_GOBLIN              = 84;
MON_HOBGOBLIN           = 85;
MON_WOLF_RIDER          = 86;
MON_WOLF_RAIDER         = 87;
MON_ORC                 = 88;
MON_ORC_CHIEFTAIN       = 89;
MON_OGRE                = 90;
MON_OGRE_MAGE           = 91;
MON_ROC                 = 92;
MON_THUNDERBIRD         = 93;
MON_CYCLOPS             = 94;
MON_CYCLOPS_KING        = 95;
MON_BEHEMOTH            = 96;
MON_ANCIENT_BEHEMOTH    = 97;
MON_GNOLL               = 98;
MON_GNOLL_MARAUDER      = 99;
MON_LIZARDMAN           = 100;
MON_LIZARD_WARRIOR      = 101;
MON_GORGON              = 102;
MON_MIGHTY_GORGON       = 103;
MON_SERPENT_FLY         = 104;
MON_DRAGON_FLY          = 105;
MON_BASILISK            = 106;
MON_GREATER_BASILISK    = 107;
MON_WYVERN              = 108;
MON_WYVERN_MONARCH      = 109;
MON_HYDRA               = 110;
MON_CHAOS_HYDRA         = 111;
MON_AIR_ELEMENTAL       = 112;
MON_EARTH_ELEMENTAL     = 113;
MON_FIRE_ELEMENTAL      = 114;
MON_WATER_ELEMENTAL     = 115;
MON_GOLD_GOLEM          = 116;
MON_DIAMOND_GOLEM       = 117;
MON_PIXIE               = 118;
MON_SPRITE              = 119;
MON_PSYCHIC_ELEMENTAL   = 120;
MON_MAGIC_ELEMENTAL     = 121;
MON_NOT_USED_1          = 122;
MON_ICE_ELEMENTAL       = 123;
MON_NOT_USED_2          = 124;
MON_MAGMA_ELEMENTAL     = 125;
MON_NOT_USED_3          = 126;
MON_STORM_ELEMENTAL     = 127;
MON_NOT_USED_4          = 128;
MON_ENERGY_ELEMENTAL    = 129;
MON_FIREBIRD            = 130;
MON_PHOENIX             = 131;
MON_AZURE_DRAGON        = 132;
MON_CRYSTAL_DRAGON      = 133;
MON_FAERIE_DRAGON       = 134;
MON_RUST_DRAGON         = 135;
MON_ENCHANTER           = 136;
MON_SHARPSHOOTER        = 137;
MON_HALFLING            = 138;
MON_PEASANT             = 139;
MON_BOAR                = 140;
MON_MUMMY               = 141;
MON_NOMAD               = 142;
MON_ROGUE               = 143;
MON_TROLL               = 144;
MON_CATAPULT            = 145;
MON_BALLISTA            = 146;
MON_FIRST_AID_TENT      = 147;
MON_AMMO_CART           = 148;
MON_ARROW_TOWERS        = 149;
MON_SUPREME_ARCHANGEL   = 150;
MON_DIAMOND_DRAGON      = 151;
MON_LORD_OF_THUNDER     = 152;
MON_HELL_BARON          = 153;
MON_BLOOD_DRAGON        = 154;
MON_DARKNESS_DRAGON     = 155;
MON_GHOST_BEHEMOTH      = 156;
MON_HELL_HYDRA          = 157;
MON_SACRED_PHOENIX      = 158;
MON_GHOST               = 159;
MON_EMISSARY_OF_WAR     = 160;
MON_EMISSARY_OF_PEACE   = 161;
MON_EMISSARY_OF_MANA    = 162;
MON_EMISSARY_OF_LORE    = 163;
MON_FIRE_MESSENGER      = 164;
MON_EARTH_MESSENGER     = 165;
MON_AIR_MESSENGER       = 166;
MON_WATER_MESSENGER     = 167;
MON_GORYNYCH            = 168;
MON_WAR_ZEALOT          = 169;
MON_ARCTIC_SHARPSHOOTER = 170;
MON_LAVA_SHARPSHOOTER   = 171;
MON_NIGHTMARE           = 172;
MON_SANTA_GREMLIN       = 173;
MON_COMMANDER_FIRST_A   = 174;
MON_PALADIN_A           = 174;
MON_HIEROPHANT_A        = 175;
MON_TEMPLE_GUARDIAN_A   = 176;
MON_SUCCUBUS_A          = 177;
MON_SOUL_EATER_A        = 178;
MON_BRUTE_A             = 179;
MON_OGRE_LEADER_A       = 180;
MON_SHAMAN_A            = 181;
MON_ASTRAL_SPIRIT_A     = 182;
MON_COMMANDER_LAST_A    = 182;
MON_COMMANDER_FIRST_D   = 183;
MON_PALADIN_D           = 183;
MON_HIEROPHANT_D        = 184;
MON_TEMPLE_GUARDIAN_D   = 185;
MON_SUCCUBUS_D          = 186;
MON_SOUL_EATER_D        = 187;
MON_BRUTE_D             = 188;
MON_OGRE_LEADER_D       = 189;
MON_SHAMAN_D            = 190;
MON_ASTRAL_SPIRIT_D     = 191;
MON_COMMANDER_LAST_D    = 191;
MON_SYLVAN_CENTAUR      = 192;
MON_SORCERESS           = 193;
MON_WEREWOLF            = 194;
MON_HELL_STEED          = 195;
MON_DRACOLICH           = 196;
MON_LAST_WOG            = 196;

(* Monster flags *)
MON_FLAG_WIDE               = 1;
MON_FLAG_FLYER              = 2;
MON_FLAG_SHOOTER            = 4;
MON_FLAG_WIDE_ATTACK        = 8;
MON_FLAG_ALIVE              = 16;
MON_FLAG_DESTROYS_WALLS     = 32;
MON_FLAG_SIEGE_WEAPON       = 64;
MON_FLAG_KING_1             = 128;
MON_FLAG_KING_2             = 256;
MON_FLAG_KING_3             = 512;
MON_FLAG_MIND_IMMUNITY      = 1024;
MON_FLAG_RAY_SHOOT          = 2048;
MON_FLAG_NO_MELEE_PENALTY   = 4096;
MON_FLAG_UNUSED_1           = 8192;
MON_FLAG_FIRE_IMMUNITY      = 16384;
MON_FLAG_ATTACKS_TWICE      = 32768;
MON_FLAG_NO_RETALIATION     = 65536;
MON_FLAG_NO_MORALE          = 131072;
MON_FLAG_UNDEAD             = 262144;
MON_FLAG_ATTACKS_ALL_AROUND = 524288;
MON_FLAG_SPLASH_SHOOTER     = 1048576;
MON_FLAG_DIED               = 2097152;
MON_FLAG_SUMMONED           = 4194304;
MON_FLAG_CLONE              = 8388608;
MON_FLAG_MORALE             = 16777216;
MON_FLAG_WAITING            = 33554432;
MON_FLAG_ACTED              = 67108864;
MON_FLAG_DEFENDING          = 134217728;
MON_FLAG_SACRIFICED         = 268435456;
MON_FLAG_NO_COLORING        = 536870912;
MON_FLAG_GRAY               = 1073741824;
MON_FLAG_DRAGON             = -2147483648;

(* Artifacts *)
NO_ART                              = -1;
ANY_ART                             = -1;
ART_FIRST                           = 0;
ART_SPELL_BOOK                      = 0;
ART_SPELL_SCROLL                    = 1;
ART_GRAIL                           = 2;
ART_CATAPULT                        = 3;
ART_BALLISTA                        = 4;
ART_AMMO_CART                       = 5;
ART_FIRST_AID_TENT                  = 6;
ART_CENTAUR_AXE                     = 7;
ART_BLACKSHARD_OF_THE_DEAD_KNIGHT   = 8;
ART_GREATER_GNOLLS_FLAIL            = 9;
ART_OGRES_CLUB_OF_HAVOC             = 10;
ART_SWORD_OF_HELLFIRE               = 11;
ART_TITANS_GLADIUS                  = 12;
ART_SHIELD_OF_THE_DWARVEN_LORDS     = 13;
ART_SHIELD_OF_THE_YAWNING_DEAD      = 14;
ART_BUCKLER_OF_THE_GNOLL_KING       = 15;
ART_TARG_OF_THE_RAMPAGING_OGRE      = 16;
ART_SHIELD_OF_THE_DAMNED            = 17;
ART_SENTINELS_SHIELD                = 18;
ART_HELM_OF_THE_ALABASTER_UNICORN   = 19;
ART_SKULL_HELMET                    = 20;
ART_HELM_OF_CHAOS                   = 21;
ART_CROWN_OF_THE_SUPREME_MAGI       = 22;
ART_HELLSTORM_HELMET                = 23;
ART_THUNDER_HELMET                  = 24;
ART_BREASTPLATE_OF_PETRIFIED_WOOD   = 25;
ART_RIB_CAGE                        = 26;
ART_SCALES_OF_THE_GREATER_BASILISK  = 27;
ART_TUNIC_OF_THE_CYCLOPS_KING       = 28;
ART_BREASTPLATE_OF_BRIMSTONE        = 29;
ART_TITANS_CUIRASS                  = 30;
ART_ARMOR_OF_WONDER                 = 31;
ART_SANDALS_OF_THE_SAINT            = 32;
ART_CELESTIAL_NECKLACE_OF_BLISS     = 33;
ART_LIONS_SHIELD_OF_COURAGE         = 34;
ART_SWORD_OF_JUDGEMENT              = 35;
ART_HELM_OF_HEAVENLY_ENLIGHTENMENT  = 36;
ART_QUIET_EYE_OF_THE_DRAGON         = 37;
ART_RED_DRAGON_FLAME_TONGUE         = 38;
ART_DRAGON_SCALE_SHIELD             = 39;
ART_DRAGON_SCALE_ARMOR              = 40;
ART_DRAGONBONE_GREAVES              = 41;
ART_DRAGON_WING_TABARD              = 42;
ART_NECKLACE_OF_DRAGONTEETH         = 43;
ART_CROWN_OF_DRAGONTOOTH            = 44;
ART_STILL_EYE_OF_THE_DRAGON         = 45;
ART_CLOVER_OF_FORTUNE               = 46;
ART_CARDS_OF_PROPHECY               = 47;
ART_LADYBIRD_OF_LUCK                = 48;
ART_BADGE_OF_COURAGE                = 49;
ART_CREST_OF_VALOR                  = 50;
ART_GLYPH_OF_GALLANTRY              = 51;
ART_SPECULUM                        = 52;
ART_SPYGLASS                        = 53;
ART_AMULET_OF_THE_UNDERTAKER        = 54;
ART_VAMPIRES_COWL                   = 55;
ART_DEAD_MANS_BOOTS                 = 56;
ART_GARNITURE_OF_INTERFERENCE       = 57;
ART_SURCOAT_OF_COUNTERPOISE         = 58;
ART_BOOTS_OF_POLARITY               = 59;
ART_BOW_OF_ELVEN_CHERRYWOOD         = 60;
ART_BOWSTRING_OF_THE_UNICORNS_MANE  = 61;
ART_ANGEL_FEATHER_ARROWS            = 62;
ART_BIRD_OF_PERCEPTION              = 63;
ART_STOIC_WATCHMAN                  = 64;
ART_EMBLEM_OF_COGNIZANCE            = 65;
ART_STATESMANS_MEDAL                = 66;
ART_DIPLOMATS_RING                  = 67;
ART_AMBASSADORS_SASH                = 68;
ART_RING_OF_THE_WAYFARER            = 69;
ART_EQUESTRIANS_GLOVES              = 70;
ART_NECKLACE_OF_OCEAN_GUIDANCE      = 71;
ART_ANGEL_WINGS                     = 72;
ART_CHARM_OF_MANA                   = 73;
ART_TALISMAN_OF_MANA                = 74;
ART_MYSTIC_ORB_OF_MANA              = 75;
ART_COLLAR_OF_CONJURING             = 76;
ART_RING_OF_CONJURING               = 77;
ART_CAPE_OF_CONJURING               = 78;
ART_ORB_OF_THE_FIRMAMENT            = 79;
ART_ORB_OF_SILT                     = 80;
ART_ORB_OF_TEMPESTUOUS_FIRE         = 81;
ART_ORB_OF_DRIVING_RAIN             = 82;
ART_RECANTERS_CLOAK                 = 83;
ART_SPIRIT_OF_OPPRESSION            = 84;
ART_HOURGLASS_OF_THE_EVIL_HOUR      = 85;
ART_TOME_OF_FIRE_MAGIC              = 86;
ART_TOME_OF_AIR_MAGIC               = 87;
ART_TOME_OF_WATER_MAGIC             = 88;
ART_TOME_OF_EARTH_MAGIC             = 89;
ART_BOOTS_OF_LEVITATION             = 90;
ART_GOLDEN_BOW                      = 91;
ART_SPHERE_OF_PERMANENCE            = 92;
ART_ORB_OF_VULNERABILITY            = 93;
ART_RING_OF_VITALITY                = 94;
ART_RING_OF_LIFE                    = 95;
ART_VIAL_OF_LIFEBLOOD               = 96;
ART_NECKLACE_OF_SWIFTNESS           = 97;
ART_BOOTS_OF_SPEED                  = 98;
ART_CAPE_OF_VELOCITY                = 99;
ART_PENDANT_OF_DISPASSION           = 100;
ART_PENDANT_OF_SECOND_SIGHT         = 101;
ART_PENDANT_OF_HOLINESS             = 102;
ART_PENDANT_OF_LIFE                 = 103;
ART_PENDANT_OF_DEATH                = 104;
ART_PENDANT_OF_FREE_WILL            = 105;
ART_PENDANT_OF_NEGATIVITY           = 106;
ART_PENDANT_OF_TOTAL_RECALL         = 107;
ART_PENDANT_OF_COURAGE              = 108;
ART_EVERFLOWING_CRYSTAL_CLOAK       = 109;
ART_RING_OF_INFINITE_GEMS           = 110;
ART_EVERPOURING_VIAL_OF_MERCURY     = 111;
ART_INEXHAUSTIBLE_CART_OF_ORE       = 112;
ART_EVERSMOKING_RING_OF_SULFUR      = 113;
ART_INEXHAUSTIBLE_CART_OF_LUMBER    = 114;
ART_ENDLESS_SACK_OF_GOLD            = 115;
ART_ENDLESS_BAG_OF_GOLD             = 116;
ART_ENDLESS_PURSE_OF_GOLD           = 117;
ART_LEGS_OF_LEGION                  = 118;
ART_LOINS_OF_LEGION                 = 119;
ART_TORSO_OF_LEGION                 = 120;
ART_ARMS_OF_LEGION                  = 121;
ART_HEAD_OF_LEGION                  = 122;
ART_SEA_CAPTAINS_HAT                = 123;
ART_SPELLBINDERS_HAT                = 124;
ART_SHACKLES_OF_WAR                 = 125;
ART_ORB_OF_INHIBITION               = 126;
ART_VIAL_OF_DRAGON_BLOOD            = 127;
ART_ARMAGEDDONS_BLADE               = 128;
ART_ANGELIC_ALLIANCE                = 129;
ART_CLOAK_OF_THE_UNDEAD_KING        = 130;
ART_ELIXIR_OF_LIFE                  = 131;
ART_ARMOR_OF_THE_DAMNED             = 132;
ART_STATUE_OF_LEGION                = 133;
ART_POWER_OF_THE_DRAGON_FATHER      = 134;
ART_TITANS_THUNDER                  = 135;
ART_ADMIRALS_HAT                    = 136;
ART_BOW_OF_THE_SHARPSHOOTER         = 137;
ART_WIZARDS_WELL                    = 138;
ART_RING_OF_THE_MAGI                = 139;
ART_CORNUCOPIA                      = 140;
ART_MAGIC_WAND                      = 141;
ART_GOLD_TOWER_ARROW                = 142;
ART_MONSTERS_POWER                  = 143;
ART_HIGHLIGHTED_SLOT                = 144;
ART_ARTIFACT_LOCK                   = 145;
ART_AXE_OF_SMASHING                 = 146;
ART_MITHRIL_MAIL                    = 147;
ART_SWORD_OF_SHARPNESS              = 148;
ART_HELM_OF_IMMORTALITY             = 149;
ART_PENDANT_OF_SORCERY              = 150;
ART_BOOTS_OF_HASTE                  = 151;
ART_BOW_OF_SEEKING                  = 152;
ART_DRAGON_EYE_RING                 = 153;
ART_HARDENED_SHIELD                 = 154;
ART_SLAVAS_RING_OF_POWER            = 155;
ART_WARLORDS_BANNER                 = 156;
ART_CRIMSON_SHIELD_OF_RETRIBUTION   = 157;
ART_BARBARIAN_LORDS_AXE_OF_FEROCITY = 158;
ART_DRAGONHEART                     = 159;
ART_GATE_KEY                        = 160;
ART_BLANK_HELMET                    = 161;
ART_BLANK_SWORD                     = 162;
ART_BLANK_SHIELD                    = 163;
ART_BLANK_HORNED_RING               = 164;
ART_BLANK_GEMMED_RING               = 165;
ART_BLANK_NECK_BROACH               = 166;
ART_BLANK_ARMOR                     = 167;
ART_BLANK_SURCOAT                   = 168;
ART_BLANK_BOOTS                     = 169;
ART_BLANK_HORN                      = 170;
ART_LAST_WOG                        = 170;
ART_META_SPELLBOOK                  = 1000; // used by HE:A command, not a real ID
ART_META_SPELL_SCROLL_FIRST         = 1001; // used by HE:A command, not a real ID

(* Towns *)
NO_TOWN         = -1;
CURRENT_TOWN    = -1;
TOWN_FIRST      = 0;
TOWN_CASTLE     = 0;
TOWN_RAMPART    = 1;
TOWN_TOWER      = 2;
TOWN_INFERNO    = 3;
TOWN_NECROPOLIS = 4;
TOWN_DUNGEON    = 5;
TOWN_STRONGHOLD = 6;
TOWN_FORTRESS   = 7;
TOWN_CONFLUX    = 8;
TOWN_LAST_WOG   = 8;

MAP_TOWN_FIRST = 0;
MAP_TOWN_LAST  = 47;

(* Spell Schools *)
SPELL_SCHOOL_AIR   = 1;
SPELL_SCHOOL_FIRE  = 2;
SPELL_SCHOOL_WATER = 4;
SPELL_SCHOOL_EARTH = 8;

(* Spells *)
NO_SPELL                    = -1;
ANY_SPELL                   = -1;
SPELL_FIRST                 = 0;
SPELL_FIRST_ADVENTURE       = 0;
SPELL_SUMMON_BOAT           = 0;
SPELL_SCUTTLE_BOAT          = 1;
SPELL_VISIONS               = 2;
SPELL_VIEW_EARTH            = 3;
SPELL_DISGUISE              = 4;
SPELL_VIEW_AIR              = 5;
SPELL_FLY                   = 6;
SPELL_WATER_WALK            = 7;
SPELL_DIMENSION_DOOR        = 8;
SPELL_TOWN_PORTAL           = 9;
SPELL_LAST_ADVENTURE        = 9;
SPELL_FIRST_BATTLE          = 10;
SPELL_QUICKSAND             = 10;
SPELL_LAND_MINE             = 11;
SPELL_FORCE_FIELD           = 12;
SPELL_FIRE_WALL             = 13;
SPELL_EARTHQUAKE            = 14;
SPELL_MAGIC_ARROW           = 15;
SPELL_ICE_BOLT              = 16;
SPELL_LIGHTNING_BOLT        = 17;
SPELL_IMPLOSION             = 18;
SPELL_CHAIN_LIGHTNING       = 19;
SPELL_FROST_RING            = 20;
SPELL_FIREBALL              = 21;
SPELL_INFERNO               = 22;
SPELL_METEOR_SHOWER         = 23;
SPELL_DEATH_RIPPLE          = 24;
SPELL_DESTROY_UNDEAD        = 25;
SPELL_ARMAGEDDON            = 26;
SPELL_SHIELD                = 27;
SPELL_AIR_SHIELD            = 28;
SPELL_FIRE_SHIELD           = 29;
SPELL_PROTECTION_FROM_AIR   = 30;
SPELL_PROTECTION_FROM_FIRE  = 31;
SPELL_PROTECTION_FROM_WATER = 32;
SPELL_PROTECTION_FROM_EARTH = 33;
SPELL_ANTI_MAGIC            = 34;
SPELL_DISPEL                = 35;
SPELL_MAGIC_MIRROR          = 36;
SPELL_CURE                  = 37;
SPELL_RESURRECTION          = 38;
SPELL_ANIMATE_DEAD          = 39;
SPELL_SACRIFICE             = 40;
SPELL_BLESS                 = 41;
SPELL_CURSE                 = 42;
SPELL_BLOODLUST             = 43;
SPELL_PRECISION             = 44;
SPELL_WEAKNESS              = 45;
SPELL_STONE_SKIN            = 46;
SPELL_DISRUPTING_RAY        = 47;
SPELL_PRAYER                = 48;
SPELL_MIRTH                 = 49;
SPELL_SORROW                = 50;
SPELL_FORTUNE               = 51;
SPELL_MISFORTUNE            = 52;
SPELL_HASTE                 = 53;
SPELL_SLOW                  = 54;
SPELL_SLAYER                = 55;
SPELL_FRENZY                = 56;
SPELL_TITANS_LIGHTNING_BOLT = 57;
SPELL_COUNTERSTRIKE         = 58;
SPELL_BERSERK               = 59;
SPELL_HYPNOTIZE             = 60;
SPELL_FORGETFULNESS         = 61;
SPELL_BLIND                 = 62;
SPELL_TELEPORT              = 63;
SPELL_REMOVE_OBSTACLE       = 64;
SPELL_CLONE                 = 65;
SPELL_FIRE_ELEMENTAL        = 66;
SPELL_EARTH_ELEMENTAL       = 67;
SPELL_WATER_ELEMENTAL       = 68;
SPELL_AIR_ELEMENTAL         = 69;
SPELL_LAST_BATTLE           = 69;
SPELL_LAST_WOG              = 69;
