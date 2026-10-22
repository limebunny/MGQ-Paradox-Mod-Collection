#==============================================================================
# CC_Core.rbx
# Character Creation — core: paths, logging, data model, snapshot, and the
# deferred install runner for the Multiplayer modules.
#
# This file replaces CC_00_Core.rb and CC_99_InstallHooks.rb.
#==============================================================================

module CharacterCreation
  #--- Paths -----------------------------------------------------------------
  MOD_DIR      = "Patch/Character_Creation"
  HEROES_DIR   = "#{MOD_DIR}/Heroes"
  IMPORTS_DIR  = "#{MOD_DIR}/Imports"
  EXPORTS_DIR  = "#{MOD_DIR}/Exports"
  CACHE_DIR    = "#{MOD_DIR}/Cache"
  LOG_DIR      = "Logs"
  LOG_FILE     = "Character Creation.log"

  #--- Pack format -----------------------------------------------------------
  PACK_EXT     = ".luka"
  PACK_MAGIC   = "LUKA"
  PACK_VERSION = 1
  KEY_SEED     = 0x4C554B41
  KEY_MULTIPLIER = 1103515245
  KEY_INCREMENT  = 12345
  ENTRY_HERO   = "hero.txt"
  IMAGE_ENTRY  = /\A([A-Za-z0-9_\-]{1,64})\.png\z/

  #--- Personas --------------------------------------------------------------
  PERSONAS  = [1, 2, 3].freeze
  BASE_FORM = 1
  FORMS     = [1, 2, 3].freeze

  #--- Skin sizes ------------------------------------------------------------
  FACE_SIZE    = 96
  FACE_COLUMNS = 4
  SITUATIONS   = [:skill, :pinch, :down, :pleasure, :eaten].freeze

  #=== Logging ===============================================================
  # Logging is enabled for development. Set to false for release builds.
  LOGGING_ENABLED = true

  def self.log(message)
    return unless LOGGING_ENABLED
    Dir.mkdir(LOG_DIR) unless File.directory?(LOG_DIR)
    File.open(File.join(LOG_DIR, LOG_FILE), "ab") do |f|
      f.write("#{Time.now}  #{message}\n")
    end
  rescue
  end

  # Renders a string as a space-separated list of its byte values. Used by
  # the battle-line and Multiplayer probes so a log line shows exactly what
  # a string contains, independent of how Ruby inspects it.
  def self.byte_dump(str)
    arr = []
    str.to_s.each_byte { |b| arr << b }
    arr.join(" ")
  rescue
    "?"
  end

  def self.make_dir(path)
    parts = path.split("/")
    built = nil
    parts.each do |part|
      built = built ? "#{built}/#{part}" : part
      Dir.mkdir(built) unless File.directory?(built)
    end
  rescue => e
    log("make_dir FAILED for #{path}: #{e.class}: #{e.message}")
  end

  #=== BasicClass ============================================================
  module BasicClass
    JOB_MAX_ID = 149
    RANK_TAG   = /<職業ランク\s+(\d+)>/

    def self.basic?(data)
      data && data.note.to_s =~ RANK_TAG && $1.to_i == 1 ? true : false
    end

    # The id blocks that are jobs, and those that are races. The base game
    # puts jobs in 1..149 and races in 151..370, with 150 and the gaps
    # between races as separators. A mod in this build adds a second block
    # in the same shape: jobs 6998..7078, races 7401..7455. The classes
    # index of this game's $data_classes confirms both blocks.
    JOB_RANGES   = [(1..149), (6998..7078)].freeze
    RACE_RANGES  = [(151..370), (7401..7455)].freeze

    def self.job_id?(id)
      JOB_RANGES.any? { |range| range.include?(id) }
    end

    def self.race_id?(id)
      RACE_RANGES.any? { |range| range.include?(id) }
    end

    def self.jobs
      return @jobs if @jobs
      base = list
      return [] if base.empty? && !$data_classes
      @jobs = base.select { |id, _| job_id?(id) }
    end

    def self.races
      return @races if @races
      base = list
      return [] if base.empty? && !$data_classes
      @races = base.reject { |id, _| job_id?(id) }
    end

    def self.list
      return @list if @list
      return [] unless $data_classes
      result = []
      $data_classes.each_with_index do |data, id|
        next if data.nil?
        next unless basic?(data)
        next if data.name.to_s.empty?
        result << [id, data.name]
      end
      @list = result.sort_by { |id, _| id }
    end

    def self.reload!
      @list = @jobs = @races = nil
    end
  end

  #=== Character + Form ======================================================
  Character = Struct.new(
    :key, :name, :nickname, :sex, :bust_size, :artist,
    :job, :race, :class_levels, :base_stats, :curves, :equips,
    :trait_key, :trait_name, :trait_lines, :features, :tags,
    :sprite_blob, :face_blob, :picture_blob, :expressions, :cutins,
    :form2, :form3,
    :story_rules, :recruit_self,
    :import_key,
    :trait_feature_keys
  )

  Form = Struct.new(
    :sprite_blob, :face_blob, :picture_blob,
    :expressions, :cutins,
    :own_trait, :trait_name, :trait_lines, :features, :tags
  )

  #=== LukaSnapshot ==========================================================
  module LukaSnapshot
    def self.ensure_snapshot
      return if @snapshot
      return unless $data_actors
      @snapshot = {}
      [1, 2, 3].each do |id|
        @snapshot[id] = Marshal.load(Marshal.dump($data_actors[id])) if $data_actors[id]
      end
      CharacterCreation.log("Luka snapshot taken (#{@snapshot.keys.sort.inspect})")
    end

    def self.restore
      return unless @snapshot
      @snapshot.each do |id, actor|
        $data_actors[id] = Marshal.load(Marshal.dump(actor))
      end
    end

    def self.taken?
      !@snapshot.nil?
    end

    def self.actor_for(persona_id)
      @snapshot && @snapshot[persona_id]
    end
  end

  #=== Character construction ================================================
  def self.new_character(key = :custom)
    c = Character.new
    c.key           = key.to_sym
    c.name          = "Luka"
    c.nickname      = "Apprentice Hero"
    c.sex           = :male
    c.artist        = ""
    c.bust_size     = "Flat"
    c.job           = 141
    c.race          = 151
    c.class_levels  = {}
    c.base_stats    = :luka
    c.curves        = []
    c.equips        = { 0 => 47, 3 => 1 }
    c.trait_key     = :heros_blood
    c.trait_name    = "Hero's Blood"
    c.trait_lines   = ["Can always use Sword, Spear, Katana, Axe, Holy, Talk, and Heroism skills."]
    c.features      = []
    c.tags          = []
    c.sprite_blob   = nil
    c.face_blob     = nil
    c.picture_blob  = nil
    c.expressions   = {}
    c.cutins        = []
    c.form2         = nil
    c.form3         = nil
    c.story_rules   = []
    c.recruit_self  = :allow
    c.import_key    = nil
    c.trait_feature_keys = []
    c
  end

  def self.apply_trait(character, trait_key)
    return unless defined?(TraitLibrary)
    trait = TraitLibrary.get(trait_key)
    character.trait_key   = trait_key
    character.trait_name  = trait[:name]
    character.trait_lines = trait[:lines].dup
    character.features    = trait[:features].map(&:dup)
    character.tags        = trait[:tags].dup
  end

  # Finds a character by the key the Multiplayer mod carries on the wire.
  #
  # Resolution order:
  #   1. The character this game is currently playing, if its key matches.
  #   2. A .luka file in Heroes/ whose key matches, read with Pack.read.
  #   3. A character received from the network in this session, if any.
  def self.character_for_mp_key(key)
    k = key.to_s
    return nil if k.empty?

    current = CharacterCreation.current_character
    return current if current && current.key.to_s == k

    received = (@mp_received_characters ||= {})
    return received[k] if received[k]
    received.each_value do |character|
      return character if character.key.to_s == k
    end

    path = File.join(CharacterCreation::HEROES_DIR, "#{k}#{CharacterCreation::PACK_EXT}")
    return nil unless File.exist?(path)
    Pack.read(path)
  rescue => e
    CharacterCreation.log("character_for_mp_key FAILED for #{key.inspect}: #{e.class}: #{e.message}")
    nil
  end

  def self.image_name(key, slot)
    "lr_cc_#{key}_#{slot}"
  end

  #=== Deferred installs =====================================================
  # Runs each Multiplayer module's deferred install, in order. Idempotent:
  # the modules' own @settled flags stop a second run from doing anything.
  #
  # Called after DataManager.setup_new_game and after extract_save_contents
  # (see CC_Engine_Hooks.rb).
  def self.install_all_deferred_hooks
    if defined?(LrCompat)
      LrCompat.try_install
    end
    if defined?(MpBridge)
      MpBridge.try_install
    end
    if defined?(PackTransfer)
      PackTransfer.try_install
    end
  rescue => e
    CharacterCreation.log("install_all_deferred_hooks FAILED: #{e.class}: #{e.message}")
  end

  #=== Module state ==========================================================
  class << self
    attr_accessor :draft
    attr_accessor :pending
    attr_accessor :pending_discard
    attr_accessor :pending_refresh
    attr_accessor :pending_close
    attr_accessor :text_input_target
    attr_accessor :current_character
    attr_accessor :mp_received_characters
  end
end

# Create the mod's folders and take the Luka snapshot once, at load time,
# so the Draft and Trait Dashboards have Luka's graphics to fall back to
# even before a new game starts.
begin
  CharacterCreation.make_dir(CharacterCreation::IMPORTS_DIR)
  CharacterCreation.make_dir(CharacterCreation::EXPORTS_DIR)
  CharacterCreation.make_dir(CharacterCreation::CACHE_DIR)
  CharacterCreation.make_dir(CharacterCreation::HEROES_DIR)
rescue => e
  CharacterCreation.log("Core startup FAILED: #{e.class}: #{e.message}")
end

# Clean the cache folder on launch, to prevent it filling up with
# Multiplayer friends' temporary files.
begin
  if File.directory?(CharacterCreation::CACHE_DIR)
    Dir.glob(File.join(CharacterCreation::CACHE_DIR, "*")).each do |path|
      if File.directory?(path)
        Dir.glob(File.join(path, "*")).each { |f| File.delete(f) }
        Dir.rmdir(path)
      else
        File.delete(path)
      end
    end
  end
rescue => e
  CharacterCreation.log("Cache cleanup FAILED: #{e.class}: #{e.message}")
end

CharacterCreation.log("CC_Core loaded")