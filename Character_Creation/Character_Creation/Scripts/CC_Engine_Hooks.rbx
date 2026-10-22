#==============================================================================
# CC_Engine_Hooks.rbx
# Character Creation — engine hooks and actor builder.
#
# Combines:
#   CC_02_BlobRegistry.rb (ActorBuilder portion)
#   CC_03_GameHooks.rb    (CacheHook, FaceHook, text hooks, DataManager hooks,
#                          LibrarySwap, StatProbe)
#
# Provides:
#   CharacterCreation::ActorBuilder         builds a Luka persona as a hero
#   CharacterCreation::CacheHook            resolves lr_cc_* names to cache files
#   CharacterCreation::FaceRedirect         redirects Luka faces to the hero
#   CharacterCreation::FaceHook             rewrites Luka faces at draw time
#   CharacterCreation::TextRename           rewrites "Luka" in text
#   CharacterCreation::EscapeRenameHook     hooks convert_escape_characters
#   CharacterCreation::BitmapRenameHook     hooks draw_text
#   CharacterCreation::LibrarySwap          swaps the Library actor entry
#   CharacterCreation::DataManagerHook      hooks setup_new_game / runtime
#   CharacterCreation::ExtractHook          hooks extract_save_contents
#   CharacterCreation::StatProbe            F9 data dump
#==============================================================================

module CharacterCreation
  #=== ActorBuilder ==========================================================
  module ActorBuilder
    FEATURE_SKILL_TYPE = 41
    KEPT_SKILL_TYPES = [39, 63].freeze

    # Engine-level features every actor must have (Hit, Crit, MP Cost, Accessory/Chaos equip)
    REQUIRED_FEATURES = [
      [22, 1, 0.05], [22, 2, 0.05], [23, 0, 0.5],
      [52, 41, 0.0], [51, 32, 0.0]
    ].freeze

    def self.build(character, persona_id)
      return nil unless character
      return nil unless $data_actors && $data_actors[persona_id]

      luka = CharacterCreation::LukaSnapshot.actor_for(persona_id) || $data_actors[persona_id]
      actor = Marshal.load(Marshal.dump(luka))

      form = persona_id == 2 ? character.form2 :
            persona_id == 3 ? character.form3 : nil
      use_own = form && form.own_trait

      actor.name     = character.name.to_s.empty? ? "Luka" : character.name
      actor.nickname = character.nickname.to_s
      actor.class_id = character.job if character.job && character.job > 0
      actor.initial_level = 3

      apply_graphics(actor, character, persona_id)

      # 1. Start with the engine-level features every actor must have
      #    (Hit/Evasion, Critical Rate, MP Cost, Accessory/Chaos equip).
      base_features = Array(actor.instance_variable_get(:@features))
      kept_features = base_features.select do |f|
        REQUIRED_FEATURES.include?([f.code, f.data_id, f.value])
      end

      # 2. Add the custom trait features.
      custom_features = trait_features(character, form)

      # 3. Drop custom features already present in the kept features.
      kept_keys = kept_features.map { |f| [f.code, f.data_id, f.value] }
      custom_features = custom_features.reject do |f|
        kept_keys.include?([f.code, f.data_id, f.value])
      end

      all_features = kept_features + custom_features

      actor.instance_variable_set(:@features, all_features)
      actor.instance_variable_set(:@features_override, all_features)

      # Sex: male characters get data_ex[:sex] = NWSex::MALE defensively; females
      # keep the default NWSex::FEMALE (see ベース_DataObject, sex method).
      if character.sex == :male && defined?(NWSex::MALE)
        data_ex = actor.instance_variable_get(:@data_ex)
        # Allow males to use Pleasure skills by combining MALE and FEMALE bits
        data_ex[:sex] = NWSex::MALE | NWSex::FEMALE if data_ex
      end

      # --- Rebuild the Note Tags ---
      luka_tags = luka.note.to_s.scan(/<[^>]*>/)
      override_prefixes = [
        "カテゴリー", "特殊カテゴリー", "性別", "初期サブクラス",
        "経験済職業", "初期装備", "スキル変化", "イラスト", "主人格",
        "スキルタイプ強化", "窮地スキルタイプ強化"
      ]
      base_tags = luka_tags.reject { |t| override_prefixes.any? { |p| t.include?(p) } }

      # Luka's own note also teaches Double Slash via <固有習得 3-917>,
      # duplicating the Warrior job's natural Lv3 learning. Strip just
      # that entry from any <固有習得> tag Luka carries, leaving every
      # other 固有習得 (Talk, Slime Body, ...) intact.
      base_tags = base_tags.map { |t|
        t.start_with?("<固有習得 ") ? strip_skill_from_unique_tag(t, 917) : t
      }.reject(&:empty?)

      custom_tags = trait_tags(character, form).dup
      custom_tags.concat(CharacterCreation::StandardTags.tags_for(character))

      actor.note = (base_tags + custom_tags).uniq.join("\n")
      # note_analyze builds @features_override from @features + @add_features,
      # where @add_features contains any features extracted from the note tags.
      # Do NOT overwrite @features_override afterward, or those features are lost.
      actor.note_analyze if actor.respond_to?(:note_analyze)
      # Rebuild feature_data from @features_override (which now includes the
      # note-derived features) so features_with_id sees them.
      actor.setting_feature_data if actor.respond_to?(:setting_feature_data)
      # Luka's Apprentice Hero job teaches Double Slash at level 3, which
      # every custom character inherits from <経験済職業 141-3>. Remove
      # it so the skill is not granted by the job; a character who wants
      # it can pick the skill via a trait or a class_levels entry.
      actor.forget_skill(917) if actor.respond_to?(:forget_skill)

      actor
    rescue => e
      CharacterCreation.log("ActorBuilder.build FAILED (persona #{persona_id}): #{e.class}: #{e.message}")
      nil
    end

    # Removes one skill id from a <固有習得 ...> tag. The tag's body is a
    # comma-separated list of "level-skill_id" entries, e.g.
    # "<固有習得 1-6933,3-917,5-3277>". If removing the skill empties the
    # tag, the helper returns "" so the caller can drop it.
    def self.strip_skill_from_unique_tag(tag, skill_id)
      return tag unless tag =~ /\A<固有習得\s+([^>]*)>\z/
      body = $1
      kept = body.split(",").reject { |pair|
        lv, id = pair.strip.split("-", 2)
        id.to_i == skill_id
      }
      return "" if kept.empty?
      "<固有習得 #{kept.join(',')}>"
    end

    def self.apply_graphics(actor, character, persona_id)
      face_slot, sprite_slot = graphics_slots(character, persona_id)
      if BlobRegistry.fetch(CharacterCreation.image_name(character.key, face_slot))
        actor.face_name  = CharacterCreation.image_name(character.key, face_slot)
        actor.face_index = 0
      end
      if BlobRegistry.fetch(CharacterCreation.image_name(character.key, sprite_slot))
        actor.character_name  = "$#{CharacterCreation.image_name(character.key, sprite_slot)}"
        actor.character_index = 0
      end
    end

    def self.graphics_slots(character, persona_id)
      case persona_id
      when 2
        face   = character.form2 && character.form2.face_blob   ? :form2_face   : :face
        sprite = character.form2 && character.form2.sprite_blob ? :form2_sprite : :sprite
        [face, sprite]
      when 3
        face   = character.form3 && character.form3.face_blob   ? :form3_face   : :face
        sprite = character.form3 && character.form3.sprite_blob ? :form3_sprite : :sprite
        [face, sprite]
      else
        [:face, :sprite]
      end
    end

    def self.trait_features(character, form)
      source = trait_source(character, form)
      Array(source[:features]).map do |code, data_id, value|
        if defined?(RPG::BaseItem::Feature)
          RPG::BaseItem::Feature.new(code, data_id, value)
        else
          [code, data_id, value]
        end
      end
    end

    def self.trait_tags(character, form)
      source = trait_source(character, form)
      Array(source[:tags])
    end

    def self.trait_source(character, form)
      if form && form.own_trait
        { :features => form.features, :tags => form.tags }
      else
        { :features => character.features, :tags => character.tags }
      end
    end

    def self.luka_tags(actor)
      actor.note.to_s.scan(/<[^>]*>/)
    end

    PRESERVED_TAG = /\A<(?:初期装備|TP基本値|TPLv補正|TPLv100補正|開始時TP)/

    def self.rebuild_note(original, tags)
      stripped = original.gsub(/<[^>]*>/) { |tag| tag =~ PRESERVED_TAG ? tag : "" }
      [stripped.strip, *tags].reject { |s| s.to_s.empty? }.join("\n")
    end
  end

  #=== Skill Learnable Hook =================================================
  module SkillLearnableHook
    def self.install
      return if @installed
      return unless defined?(Game_Actor)
      @installed = true
      Game_Actor.class_eval do
        alias_method :cc_original_skill_learnable?, :skill_learnable? unless method_defined?(:cc_original_skill_learnable?)
        def skill_learnable?(skill)
          return cc_original_skill_learnable?(skill) unless skill.is_a?(RPG::Skill)
          return cc_original_skill_learnable?(skill) unless CharacterCreation::PERSONAS.include?(id)
          return cc_original_skill_learnable?(skill) unless CharacterCreation.current_character
          
          blocked = skill.not_learn_actors
          # If the skill uses the bare <習得不可> tag, it returns the global constant.
          # We bypass this for the custom character (who is persona 1/2/3).
          if blocked.equal?(NWConst::Actor::NOT_LEARN_ACTORS) || blocked == NWConst::Actor::NOT_LEARN_ACTORS
            return true
          end
          # If it's a numbered <習得不可 N>, respect the original check.
          !blocked.include?(actor.original_persona_id)
        end
      end
      CharacterCreation.log("SkillLearnableHook: installed")
    rescue => e
      CharacterCreation.log("SkillLearnableHook.install FAILED: #{e.class}: #{e.message}")
    end
  end

  #=== Cache.load_bitmap hook ===============================================
  module CacheHook
    PREFIX = "lr_cc_"
    @bitmap_cache = {}

    def self.install
      return if Cache.singleton_class.method_defined?(:cc_original_load_bitmap)
      Cache.singleton_class.class_eval do
        alias_method :cc_original_load_bitmap, :load_bitmap
        def load_bitmap(folder_name, filename, *args)
          name = filename.to_s
          bare = name.sub(/\A\$/, "")
          
          if bare.start_with?(CharacterCreation::CacheHook::PREFIX)
            # 1. Check if we already have a valid, un-disposed bitmap in memory
            cached = CharacterCreation::CacheHook.cached_bitmap(bare)
            return cached if cached
            
            path = CharacterCreation::CacheHook.path_for(bare)
            if path && File.exist?(path)
              begin
                bmp = Bitmap.new(path)
                if bare =~ /_face\z/
                  bmp = CharacterCreation::CacheHook.normalize_face(bmp)
                end
                # 2. Store it in our custom cache before returning
                CharacterCreation::CacheHook.store_bitmap(bare, bmp)
                return bmp
              rescue => e
                CharacterCreation.log("CacheHook: load failed for #{path}: #{e.class}: #{e.message}")
              end
            else
              CharacterCreation.log("CacheHook: no file on disk for #{bare} (looked at #{path.inspect})")
              # Return a blank bitmap to prevent crashes
              blank = Bitmap.new(32, 32)
              blank.fill_rect(0, 0, 32, 32, Color.new(0, 0, 0, 0))
              return blank
            end
          end
          cc_original_load_bitmap(folder_name, filename, *args)
        end
      end
      CharacterCreation.log("Cache hook installed")
    end

    # Helper methods for the custom cache
    def self.cached_bitmap(bare_name)
      bmp = @bitmap_cache[bare_name]
      if bmp && !bmp.disposed?
        return bmp
      else
        @bitmap_cache.delete(bare_name)
        return nil
      end
    end

    def self.store_bitmap(bare_name, bmp)
      @bitmap_cache[bare_name] = bmp
    end

    # Ensure that when the game disposes a bitmap, we remove it from our cache
    def self.patch_dispose
      return if Bitmap.method_defined?(:cc_original_dispose)
      Bitmap.class_eval do
        alias_method :cc_original_dispose, :dispose
        def dispose(*args)
          cc_original_dispose(*args)
          CharacterCreation::CacheHook.forget_bitmap(self)
        end
      end
    end

    def self.forget_bitmap(bmp)
      return if @bitmap_cache.nil?
      @bitmap_cache.delete_if { |_, v| v.equal?(bmp) }
    end

    # --- Original Helpers (Restored) ---
    
    def self.normalize_face(src)
      return src unless src
      return src if src.width == 384 && src.height == 192

      cell = Bitmap.new(96, 96)
      if src.width > src.height
        cell.blt(0, 0, src, Rect.new(0, 0, 96, 96))
      else
        scale = [96.0 / src.width, 96.0 / src.height].min
        w = (src.width * scale).to_i
        h = (src.height * scale).to_i
        x = (96 - w) / 2
        y = (96 - h) / 2
        cell.stretch_blt(Rect.new(x, y, w, h), src,
                         Rect.new(0, 0, src.width, src.height))
      end

      sheet = Bitmap.new(384, 192)
      2.times do |row|
        4.times do |col|
          sheet.blt(col * 96, row * 96, cell, Rect.new(0, 0, 96, 96))
        end
      end
      cell.dispose
      src.dispose unless src.disposed?
      sheet
    rescue => e
      CharacterCreation.log("CacheHook.normalize_face FAILED: #{e.class}: #{e.message}")
      src
    end

    SLOTS = %w[form2_picture form2_sprite form2_face form3_picture form3_sprite form3_face
               picture sprite face].freeze

    def self.path_for(synthetic_name)
      rest = synthetic_name.sub(/\Alr_cc_/, "")
      SLOTS.each do |slot|
        suffix = "_#{slot}"
        next unless rest.end_with?(suffix)
        key = rest[0, rest.size - suffix.size]
        return nil if key.empty?
        return File.join(CharacterCreation::CACHE_DIR, key, "#{slot}.png")
      end
      if rest =~ /\A(.+)_((?:form[23]_)?cutin_\d+)\z/
        return File.join(CharacterCreation::CACHE_DIR, $1, "#{$2}.png")
      end
      nil
    end
  end

  #=== Face redirect ========================================================
  module FaceRedirect
    PATTERN = /\Aruka_fc(\d+)\z/i
    UNTOUCHED = 99

    def self.form_for(n)
      case n
      when 1  then 1
      when 4  then 2
      when 3  then 3
      else 1
      end
    end

    def self.face_name_for(character, form)
      cc = CharacterCreation
      base = cc.image_name(character.key, :face)
      case form
      when 2
        slot = character.form2 && character.form2.face_blob ? :form2_face : :face
      when 3
        slot = character.form3 && character.form3.face_blob ? :form3_face : :face
      else
        slot = :face
      end
      name = cc.image_name(character.key, slot)
      return name if cc::BlobRegistry.fetch(name)
      return base if cc::BlobRegistry.fetch(base)
      nil
    end
  end

  #=== Text rename ==========================================================
  module TextRename
    KEPT_NAMES = [
      "Luka Holly", "Luka Rinoa", "Luka Heine", "Luka Kyrie",
      "Luka Doppel", "Doppel Luka", "Idea Luka", "Father of Chaos Luka",
    ].freeze

    def self.pattern
      kept = KEPT_NAMES.map { |name| Regexp.escape(name) }.join("|")
      /\b(?:#{kept}|Luka)\b/
    end

    def self.local_text?
      CharacterCreation::FaceHook.local_speaker?
    rescue
      true
    end

    def self.apply(text)
      return text unless text.is_a?(String)
      return text unless local_text?
      character = CharacterCreation.current_character
      return text unless character
      return text unless text.include?("Luka")
      name = character.name.to_s
      return text if !name.empty? && text.include?(name)
      text.gsub(pattern) do |found|
        KEPT_NAMES.include?(found) ? found : name
      end
    rescue => e
      CharacterCreation.log("TextRename.apply FAILED: #{e.class}: #{e.message}")
      text
    end
  end

  #=== Library swap =========================================================
  module LibrarySwap
    def self.install
      return if @installed
      @installed = true
      @luka_image = nil
      @luka_ability = nil
    end

    def self.update(character)
      return unless defined?(NWConst::Library)
      character ? swap_in(character) : revert
    rescue => e
      CharacterCreation.log("LibrarySwap.update FAILED: #{e.class}: #{e.message}")
    end

    def self.swap_in(character)
      if @luka_image.nil? && NWConst::Library.const_defined?(:ACTOR_IMAGE)
        @luka_image = NWConst::Library::ACTOR_IMAGE[1]
      end
      if @luka_ability.nil? && NWConst::Library.const_defined?(:ACTOR_FIX_ABILITY)
        @luka_ability = NWConst::Library::ACTOR_FIX_ABILITY[1]
      end
      if @luka_image && NWConst::Library.const_defined?(:ACTOR_IMAGE)
        folder = "#{CharacterCreation::CACHE_DIR}/#{character.key}/"
        placement = @luka_image[2..-1] || [0, 0, 0, 1.0]
        NWConst::Library::ACTOR_IMAGE[1] = [folder, "picture", *placement]
      end
      if NWConst::Library.const_defined?(:ACTOR_FIX_ABILITY)
        lines = character.trait_lines || []
        NWConst::Library::ACTOR_FIX_ABILITY[1] = [character.trait_name, *lines]
      end
    end

    def self.revert
      if @luka_image && NWConst::Library.const_defined?(:ACTOR_IMAGE)
        NWConst::Library::ACTOR_IMAGE[1] = @luka_image
      end
      if @luka_ability && NWConst::Library.const_defined?(:ACTOR_FIX_ABILITY)
        NWConst::Library::ACTOR_FIX_ABILITY[1] = @luka_ability
      end
    end
  end

  #=== DataManager hooks ====================================================
  module DataManagerHook
    def self.install
      return if DataManager.singleton_class.method_defined?(:cc_original_setup_new_game)
      DataManager.singleton_class.class_eval do
        alias_method :cc_original_setup_new_game, :setup_new_game
        def setup_new_game(*args)
          begin
            CharacterCreation::DataManagerHook.apply_pending_data
          rescue => e
            CharacterCreation.log("apply_pending_data FAILED: #{e.class}: #{e.message}")
          end
          result = cc_original_setup_new_game(*args)
          begin
            CharacterCreation::DataManagerHook.apply_pending_runtime
          rescue => e
            CharacterCreation.log("apply_pending_runtime FAILED: #{e.class}: #{e.message}")
          end
          # Deferred Multiplayer installs. Runs after runtime so the live actor
          # is tagged with the character key before the Multiplayer mod's hooks
          # fire.
          begin
            CharacterCreation.install_all_deferred_hooks
          rescue => e
            CharacterCreation.log("install_all_deferred_hooks FAILED: #{e.class}: #{e.message}")
          end
          result
        end
      end
    end

    def self.apply_pending_data
      CharacterCreation::LukaSnapshot.ensure_snapshot
      CharacterCreation::LukaSnapshot.restore
      character = CharacterCreation.pending
      CharacterCreation.pending = nil
      if character
        CharacterCreation::BlobRegistry.register(character)
        [1, 2, 3].each do |persona_id|
          actor_data = CharacterCreation::ActorBuilder.build(character, persona_id)
          next unless actor_data
          $data_actors[persona_id] = actor_data
        end
        CharacterCreation.current_character = character
        CharacterCreation::LibrarySwap.update(character)
        CharacterCreation.log("Prepared pending character: #{character.name} (#{character.key})")
      else
        CharacterCreation.current_character = nil
        CharacterCreation::LibrarySwap.update(nil)
        CharacterCreation.log("No pending character: playing as Luka")
      end
    end

    def self.apply_pending_runtime
      character = CharacterCreation.current_character
      if character
        $game_system.instance_variable_set(:@cc_character, character) if $game_system
      elsif $game_system && $game_system.instance_variable_defined?(:@cc_character)
        $game_system.remove_instance_variable(:@cc_character)
      end
      refresh_live_actor
    end

    def self.refresh_live_actor
      if $game_actors && $game_actors[1]
        luka = $game_actors[1]
        character = CharacterCreation.current_character

        if character
          luka.instance_variable_set(:@name, character.name)
          luka.instance_variable_set(:@nickname, character.nickname)

          snapshot = CharacterCreation::LukaSnapshot.actor_for(1)
          base_features = snapshot ? Array(snapshot.features) : []

          kept_features = base_features.select do |f|
            CharacterCreation::ActorBuilder::REQUIRED_FEATURES.include?([f.code, f.data_id, f.value])
          end

          custom_features = []
          Array(character.features).each do |code, data_id, value|
            custom_features << RPG::BaseItem::Feature.new(code, data_id, value)
          end

          kept_keys = kept_features.map { |f| [f.code, f.data_id, f.value] }
          custom_features = custom_features.reject do |f|
            kept_keys.include?([f.code, f.data_id, f.value])
          end

          luka.instance_variable_set(:@features, kept_features + custom_features)
          luka.instance_variable_set(:@features_override, luka.instance_variable_get(:@features))
          luka.setting_feature_data if luka.respond_to?(:setting_feature_data)

          if character.sex == :male && defined?(NWSex::MALE)
            data_ex = luka.instance_variable_get(:@data_ex)
            data_ex[:sex] = NWSex::MALE if data_ex
          end

          luka.instance_variable_set(:@tribe_id, character.race) if character.race
        else
          snapshot = CharacterCreation::LukaSnapshot.actor_for(1)
          luka.instance_variable_set(:@features, Array(snapshot.features))
        end

        luka.refresh if luka.respond_to?(:refresh)

        if character
          luka.instance_variable_set(:@hp, luka.mhp) if luka.hp < luka.mhp
          luka.instance_variable_set(:@mp, luka.mmp) if luka.mp < luka.mmp

          if luka.respond_to?(:max_tp) && luka.max_tp > 0
            rate = luka.respond_to?(:start_tp_rate) ? luka.start_tp_rate : 0.0
            rate = 0.5 if rate.nil? || rate <= 0.0
            luka.instance_variable_set(:@tp, (luka.max_tp * rate).ceil)
          end
        end

        tag_actor_with_character_key(luka)
      end
      $game_player.refresh if $game_player && $game_player.respond_to?(:refresh)
    end

    def self.tag_actor_with_character_key(actor)
      return unless actor
      character = CharacterCreation.current_character
      if character
        actor.instance_variable_set(:@cc_character_key, character.key.to_s)
        actor.instance_variable_set(:@mgq_luka_key,     character.key.to_s)
      else
        actor.instance_variable_set(:@cc_character_key, "")
        actor.instance_variable_set(:@mgq_luka_key,     "")
      end
    rescue => e
      CharacterCreation.log("tag_actor_with_character_key FAILED: #{e.class}: #{e.message}")
    end
  end

  #=== Extract hook =========================================================
  module ExtractHook
    def self.install
      return if DataManager.singleton_class.method_defined?(:cc_original_extract_save_contents)
      DataManager.singleton_class.class_eval do
        alias_method :cc_original_extract_save_contents, :extract_save_contents
        def extract_save_contents(*args)
          cc_original_extract_save_contents(*args)
          begin
            CharacterCreation::ExtractHook.reinstall
          rescue => e
            CharacterCreation.log("reinstall on load FAILED: #{e.class}: #{e.message}")
          end
          # Deferred Multiplayer installs after every save load.
          begin
            CharacterCreation.install_all_deferred_hooks
          rescue => e
            CharacterCreation.log("install_all_deferred_hooks FAILED: #{e.class}: #{e.message}")
          end
        end
      end
    end

    def self.reinstall
      CharacterCreation::LukaSnapshot.ensure_snapshot
      CharacterCreation::LukaSnapshot.restore
      character = $game_system && $game_system.instance_variable_get(:@cc_character)
      if character
        CharacterCreation::BlobRegistry.clear
        CharacterCreation::BlobRegistry.register(character)
        [1, 2, 3].each do |persona_id|
          actor_data = CharacterCreation::ActorBuilder.build(character, persona_id)
          next unless actor_data
          $data_actors[persona_id] = actor_data
        end
        CharacterCreation.current_character = character
        CharacterCreation::LibrarySwap.update(character)
        CharacterCreation.log("Re-installed #{character.name} on save load")
      else
        CharacterCreation.current_character = nil
        CharacterCreation::LibrarySwap.update(nil)
        CharacterCreation.log("Save has no custom character: playing as Luka")
      end
      CharacterCreation::DataManagerHook.refresh_live_actor
      [2, 3].each do |persona_id|
        actor = $game_actors && $game_actors[persona_id]
        CharacterCreation::DataManagerHook.tag_actor_with_character_key(actor) if actor
      end
    end
  end

  #=== Face hook ============================================================
  module FaceHook
    def self.install
      return if Window_Base.method_defined?(:cc_original_draw_face_hue)
      Window_Base.class_eval do
        alias_method :cc_original_draw_face_hue, :draw_face_hue
        def draw_face_hue(face_name, face_index, *args)
          character = CharacterCreation.current_character
          if character && face_name.is_a?(String) &&
             CharacterCreation::FaceHook.local_speaker?
            m = CharacterCreation::FaceRedirect::PATTERN.match(face_name)
            if m
              n = m[1].to_i
              unless n == CharacterCreation::FaceRedirect::UNTOUCHED
                form = CharacterCreation::FaceRedirect.form_for(n)
                new_name = CharacterCreation::FaceRedirect.face_name_for(character, form)
                face_name = new_name if new_name
                face_index = 0
              end
            end
          end
          cc_original_draw_face_hue(face_name, face_index, *args)
        end
      end
    end

    def self.local_speaker?
      speaker = current_speaker
      return true unless speaker
      if defined?(Game_MpActor) && speaker.is_a?(Game_MpActor)
        return false
      end
      key = speaker.instance_variable_get(:@mgq_luka_key)
      return false if key && !key.to_s.empty?
      true
    rescue
      true
    end

    def self.current_speaker
      return nil unless $game_message
      return nil unless $game_message.respond_to?(:speaker)
      $game_message.speaker
    end
  end

  #=== Escape rename hook ===================================================
  module EscapeRenameHook
    def self.install
      return if Window_Base.method_defined?(:cc_original_convert_escape_characters)
      Window_Base.class_eval do
        alias_method :cc_original_convert_escape_characters, :convert_escape_characters
        def convert_escape_characters(text)
          cc_original_convert_escape_characters(CharacterCreation::TextRename.apply(text))
        end
      end
    end
  end

  #=== Bitmap rename hook ===================================================
  module BitmapRenameHook
    def self.install
      return if Window_Base.method_defined?(:cc_original_draw_text)
      Window_Base.class_eval do
        alias_method :cc_original_draw_text, :draw_text
        def draw_text(*args)
          character = CharacterCreation.current_character
          if character
            index = args.first.is_a?(Rect) ? 1 : 4
            if index < args.size
              text = args[index]
              if text.is_a?(String) && text.include?("Luka")
                args = args.dup
                args[index] = CharacterCreation::TextRename.apply(text)
              end
            end
          end
          cc_original_draw_text(*args)
        end
      end
    end
  end

  #=== Engine state probe ===================================================
  module StatProbe
    def self.install
      return if @installed
      return unless defined?(Scene_Map)
      @installed = true
      Scene_Map.class_eval do
        alias_method :cc_stat_probe_update, :update unless method_defined?(:cc_stat_probe_update)
        def update(*args)
          cc_stat_probe_update(*args)
          return unless Input.trigger?(:F9)
          begin
            CharacterCreation::StatProbe.dump
          rescue => e
            CharacterCreation.log("StatProbe FAILED: #{e.class}: #{e.message}")
            CharacterCreation.log(e.backtrace.first(8).join(" | ")) if e.backtrace
          end
        end
      end
      CharacterCreation.log("StatProbe: F9 installed")
    end

    def self.dump
      log("=== DATA PROBE START ===")
      dump_default_luka
      dump_current_character
      log("=== DATA PROBE END ===")
    end

    def self.dump_default_luka
      log("-- Default Luka (Snapshot) --")
      snap = CharacterCreation::LukaSnapshot.actor_for(1)
      return log("No snapshot taken!") unless snap

      log("Name: #{snap.name} / #{snap.nickname}")
      log("Class: #{snap.class_id} / Initial Tribe: #{snap.initial_tribe_id}")
      log("Initial Level: #{snap.initial_level}")
      log("Equips: #{snap.equips.inspect}")

      log("Features:")
      Array(snap.features).each { |f| log("  code=#{f.code} id=#{f.data_id} value=#{f.value}") }

      log("Tags:")
      snap.note.to_s.scan(/<[^>]*>/).each { |t| log("  #{t}") }
    end

    def self.dump_current_character
      log("-- Test Character (Current) --")
      char = CharacterCreation.current_character
      return log("No current character!") unless char

      log("Pack Data (Character Object):")
      log("  Name: #{char.name} / #{char.nickname}")
      log("  Class: #{char.job} / Race: #{char.race}")
      log("  Base Stats: #{char.base_stats.inspect}")
      log("  Equips: #{char.equips.inspect}")
      log("  Features:")
      Array(char.features).each { |f| log("    code=#{f[0]} id=#{f[1]} value=#{f[2]}") }
      log("  Tags:")
      Array(char.tags).each { |t| log("    #{t}") }

      live_data = $data_actors[1]
      log("Built Actor Data ($data_actors[1]):")
      log("  Name: #{live_data.name} / #{live_data.nickname}")
      log("  Class: #{live_data.class_id} / Initial Tribe: #{live_data.initial_tribe_id}")
      log("  Initial Level: #{live_data.initial_level}")
      log("  Equips: #{live_data.equips.inspect}")

      log("  Features (from @features):")
      Array(live_data.instance_variable_get(:@features)).each { |f| log("    code=#{f.code} id=#{f.data_id} value=#{f.value}") }

      log("  Tags:")
      live_data.note.to_s.scan(/<[^>]*>/).each { |t| log("    #{t}") }
    end

    def self.log(msg)
      CharacterCreation.log(msg)
    end
  end

  #=== Install all engine hooks =============================================
  begin
    CacheHook.install
    CacheHook.patch_dispose
    DataManagerHook.install
    ExtractHook.install
    FaceHook.install
    EscapeRenameHook.install
    BitmapRenameHook.install
    LibrarySwap.install
    StatProbe.install
    SkillLearnableHook.install
  rescue => e
    CharacterCreation.log("Hook install FAILED: #{e.class}: #{e.message}")
  end
end

CharacterCreation.log("CC_Engine_Hooks loaded")