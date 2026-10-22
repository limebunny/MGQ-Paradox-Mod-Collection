#==============================================================================
# CC_Multiplayer.rbx
# Character Creation — Multiplayer bridge, Luka Replacer shim, battle lines,
# and pack transfer.
#
# Combines:
#   CC_07_MpBridge.rb        (Game_MpActor graphics/name/battle-line fixes)
#   CC_08_LrCompat.rb        (MGQ_LukaReplacer shim + BattleLines)
#   CC_09_PackTransfer.rb    (chunked .luka transfer over the world room)
#
# Provides:
#   CharacterCreation::MpBridge
#   CharacterCreation::LrCompat
#   CharacterCreation::BattleLines
#   CharacterCreation::PackTransfer
#
# The deferred install (LrCompat → MpBridge → PackTransfer) runs from
# CharacterCreation.install_all_deferred_hooks, called by DataManagerHook
# and ExtractHook in CC_Engine_Hooks.rbx.
#==============================================================================

module CharacterCreation
  #=== MpBridge =============================================================
  module MpBridge
    @settled = false

    class << self
      attr_accessor :settled
    end

    def self.try_install
      return if @settled
      return unless defined?(Game_MpActor)
      if defined?(MGQ_LukaReplacer) &&
         !(MGQ_LukaReplacer.const_defined?(:CC_SHIM) && MGQ_LukaReplacer::CC_SHIM)
        return
      end

      @settled = true
      install_graphic_override
      CharacterCreation.log("MpBridge: installed the Game_MpActor graphic override")
      install_pvp_picture_fix
      install_name_fix
      install_battle_line_fix
    rescue => e
      CharacterCreation.log("MpBridge.try_install FAILED: #{e.class}: #{e.message}")
    end

    def self.install_graphic_override
      Game_MpActor.class_eval do
        alias_method :cc_mp_original_setup, :setup
        def setup(actor_id, *args)
          cc_mp_original_setup(actor_id, *args)
          snap = CharacterCreation::LukaSnapshot.actor_for(actor_id)
          return unless snap
          @character_name  = snap.character_name
          @character_index = snap.character_index
          @face_name       = snap.face_name
          @face_index      = snap.face_index
        end
      end
    end

    def self.debug_rebuild(actor_id = 1, hero_key = "nyx")
      CharacterCreation.log(
        "MpBridge.debug_rebuild START: actor_id=#{actor_id.inspect} hero_key=#{hero_key.inspect}"
      )

      unless defined?(Game_MpActor)
        CharacterCreation.log("MpBridge.debug_rebuild: Game_MpActor not defined, aborting")
        return nil
      end

      unless CharacterCreation::LukaSnapshot.taken?
        CharacterCreation.log("MpBridge.debug_rebuild: no Luka snapshot, aborting")
        return nil
      end

      character = CharacterCreation.character_for_mp_key(hero_key)
      CharacterCreation.log(
        "MpBridge.debug_rebuild: character_for_mp_key(#{hero_key.inspect}) = " \
        "#{character ? character.key.inspect : 'nil'}"
      )

      member = build_fake_member(actor_id, hero_key)
      unless member
        CharacterCreation.log("MpBridge.debug_rebuild: could not build a member, aborting")
        return nil
      end

      actor = nil
      begin
        actor = Game_MpActor.new(member, "DebugTester")
      rescue => e
        CharacterCreation.log(
          "MpBridge.debug_rebuild: Game_MpActor.new RAISED #{e.class}: #{e.message}"
        )
        CharacterCreation.log(e.backtrace.first(5).join(" | ")) if e.backtrace
        return nil
      end

      begin
        CharacterCreation.log(
          "MpBridge.debug_rebuild RESULT: class=#{actor.class} " \
          "char=#{actor.character_name.inspect}/#{actor.character_index.inspect} " \
          "face=#{actor.face_name.inspect}/#{actor.face_index.inspect} " \
          "cc_key=#{actor.instance_variable_get(:@cc_character_key).inspect} " \
          "mp_key=#{actor.instance_variable_get(:@mgq_luka_key).inspect} " \
          "name=#{actor.name.inspect}"
        )
      rescue => e
        CharacterCreation.log("MpBridge.debug_rebuild result log FAILED: #{e.class}: #{e.message}")
      end

      actor
    end

    def self.build_fake_member(actor_id, hero_key)
      unless defined?(MGQ_MpActors::Builds::Member)
        CharacterCreation.log(
          "MpBridge.build_fake_member: MGQ_MpActors::Builds::Member not defined, aborting"
        )
        return nil
      end

      klass = MGQ_MpActors::Builds::Member
      param_count = (defined?(MGQ_MpActors::Builds::PARAM_COUNT) ? MGQ_MpActors::Builds::PARAM_COUNT : 8)
      counter_count = (defined?(MGQ_MpActors::Builds::COUNTERS) ? MGQ_MpActors::Builds::COUNTERS.size : 7)

      member = klass.new(
        actor_id,                       # :actor_id
        1,                              # :base_level
        nil,                            # :class_id
        nil,                            # :tribe_id
        {},                             # :level_list
        [0] * param_count,              # :param_plus
        [],                             # :skill_ids
        {},                             # :abilities
        {},                             # :equip_abilities
        [],                             # :equips
        [0] * param_count,              # :params
        [0] * 5,                        # :rates
        [0] * counter_count,            # :counters
        [],                             # :switches_on
        hero_key.to_s                   # :hero
      )
      member
    rescue => e
      CharacterCreation.log("MpBridge.build_fake_member FAILED: #{e.class}: #{e.message}")
      nil
    end

    def self.install_pvp_picture_fix
      return if @pvp_picture_fixed
      return unless defined?(MGQ_MpBattlesPvp) && defined?(MGQ_MpBattlesPvp::Pictures)

      @pvp_picture_fixed = true

      pictures = MGQ_MpBattlesPvp::Pictures
      singleton = class << pictures; self; end
      unless singleton.method_defined?(:cc_original_stand_in_for) ||
             singleton.private_method_defined?(:cc_original_stand_in_for)
        singleton.send(:alias_method, :cc_original_stand_in_for, :stand_in_for)
        singleton.send(:define_method, :stand_in_for) do |battler|
          if battler.is_a?(MGQ_MpBattlesPvp::Opponent)
            key = battler.instance_variable_get(:@mgq_luka_key).to_s
            unless key.empty?
              picture = CharacterCreation::MpBridge.pvp_picture_for(key) ||
                        MGQ_MpBattlesPvp::Pictures.face(battler)
              return picture
            end
          end
          cc_original_stand_in_for(battler)
        end
      end
      CharacterCreation.log("MpBridge: installed the PvP picture fix")
    rescue => e
      CharacterCreation.log("MpBridge.install_pvp_picture_fix FAILED: #{e.class}: #{e.message}")
    end

    def self.install_name_fix
      return if @name_fixed
      return unless defined?(Game_MpActor)

      @name_fixed = true
      Game_MpActor.class_eval do
        alias_method :cc_mp_original_actor, :actor unless method_defined?(:cc_mp_original_actor)
        def actor
          key = @mgq_luka_key.to_s
          unless key.empty?
            unless instance_variable_defined?(:@cc_mp_built_actor)
              character = CharacterCreation.character_for_mp_key(key)
              @cc_mp_built_actor =
                character ? CharacterCreation::ActorBuilder.build(character, @actor_id) : nil
            end
            return @cc_mp_built_actor if @cc_mp_built_actor
          end
          cc_mp_original_actor
        end
      end
      CharacterCreation.log("MpBridge: installed the name fix")
    rescue => e
      CharacterCreation.log("MpBridge.install_name_fix FAILED: #{e.class}: #{e.message}")
    end

    def self.install_battle_line_fix
      return if @battle_line_fixed
      return unless defined?(Game_MpActor)
      @battle_line_fixed = true

      Game_MpActor.class_eval do
        unless method_defined?(:cc_mp_original_skill_word)
          alias_method :cc_mp_original_skill_word, :skill_word
        end

        def skill_word(skill_id)
          word = cc_mp_original_skill_word(skill_id)
          CharacterCreation::BattleLines.dress_word(self, word, :skill)
        rescue => e
          CharacterCreation.log(
            "MpBridge#skill_word FAILED for #{skill_id.inspect}: #{e.class}: #{e.message}"
          )
          cc_mp_original_skill_word(skill_id)
        end

        CharacterCreation::BattleLines::DOWN_SITUATIONS.each do |line, situation|
          original = :"cc_mp_original_#{line}"
          next if method_defined?(original)
          alias_method original, line
          define_method(line) do |*args|
            CharacterCreation::BattleLines.dress_word(self, send(original, *args), situation)
          end
        end
      end
      CharacterCreation.log("MpBridge: installed the battle line fix")
    rescue => e
      CharacterCreation.log("MpBridge.install_battle_line_fix FAILED: #{e.class}: #{e.message}")
    end

    def self.debug_skill_word(actor_id = 1, hero_key = "nyx", skill_id = 1)
      CharacterCreation.log("debug_skill_word START: actor_id=#{actor_id.inspect} hero_key=#{hero_key.inspect} skill_id=#{skill_id.inspect}")

      unless defined?(Game_MpActor)
        CharacterCreation.log("debug_skill_word: Game_MpActor not defined, aborting")
        return nil
      end
      unless CharacterCreation::LukaSnapshot.taken?
        CharacterCreation.log("debug_skill_word: no Luka snapshot, aborting")
        return nil
      end

      character = CharacterCreation.character_for_mp_key(hero_key)
      CharacterCreation.log(
        "debug_skill_word: character_for_mp_key(#{hero_key.inspect}) = " \
        "#{character ? character.key.inspect : 'nil'}"
      )

      member = build_fake_member(actor_id, hero_key)
      unless member
        CharacterCreation.log("debug_skill_word: could not build a member, aborting")
        return nil
      end

      actor = nil
      begin
        actor = Game_MpActor.new(member, "DebugTester")
      rescue => e
        CharacterCreation.log("debug_skill_word: Game_MpActor.new RAISED #{e.class}: #{e.message}")
        CharacterCreation.log(e.backtrace.first(5).join(" | ")) if e.backtrace
        return nil
      end

      CharacterCreation.log(
        "debug_skill_word: built actor class=#{actor.class} " \
        "method(:skill_word).owner=#{safe_method_owner(actor, :skill_word)} " \
        "mgq_luka_key=#{actor.instance_variable_get(:@mgq_luka_key).inspect} " \
        "cc_character_key=#{actor.instance_variable_get(:@cc_character_key).inspect}"
      )

      resolved = CharacterCreation::BattleLines.character_for(actor)
      CharacterCreation.log(
        "debug_skill_word: BattleLines.character_for(actor) = " \
        "#{resolved ? resolved.key.inspect : 'nil'}"
      )

      word = nil
      begin
        word = actor.skill_word(skill_id)
      rescue => e
        CharacterCreation.log("debug_skill_word: actor.skill_word RAISED #{e.class}: #{e.message}")
        CharacterCreation.log(e.backtrace.first(5).join(" | ")) if e.backtrace
        return actor
      end

      unless word
        CharacterCreation.log("debug_skill_word: skill_word(#{skill_id}) returned nil")
        return actor
      end

      report_word(word)

      local = $game_actors && $game_actors[actor_id]
      if local
        begin
          local_word = local.skill_word(skill_id)
          CharacterCreation.log(
            "debug_skill_word: local actor #{actor_id} " \
            "method(:skill_word).owner=#{safe_method_owner(local, :skill_word)} " \
            "mgq_luka_key=#{local.instance_variable_get(:@mgq_luka_key).inspect}"
          )
          report_word(local_word, "local")
        rescue => e
          CharacterCreation.log("debug_skill_word: local.skill_word RAISED #{e.class}: #{e.message}")
        end
      end

      actor
    end

    def self.report_word(word, tag = "remote")
      return unless word
      face_name  = word.instance_variable_get(:@face_name)
      face_index = word.instance_variable_get(:@face_index)
      words      = word.instance_variable_get(:@words)
      list = Array(words)
      CharacterCreation.log(
        "debug_skill_word: #{tag} word face=#{face_name.inspect}/#{face_index.inspect} " \
        "word_count=#{list.size} " \
        "first_bytes=[#{CharacterCreation.byte_dump(list[0].to_s)}]"
      )
    rescue => e
      CharacterCreation.log("debug_skill_word: report_word FAILED: #{e.class}: #{e.message}")
    end

    def self.safe_method_owner(obj, name)
      return "?" unless obj
      m = obj.method(name) rescue nil
      return "method_missing" unless m
      m.owner
    rescue
      "?"
    end

    def self.pvp_picture_for(key)
      @pvp_pictures ||= {}
      cached = @pvp_pictures[key]
      return cached if cached && !cached.disposed?

      path = File.join(CharacterCreation::CACHE_DIR, key, "picture.png")
      return nil unless File.exist?(path)

      sheet = Bitmap.new(path)
      area = pvp_character_area(sheet)
      area.height = sheet.height - area.y
      bitmap = Bitmap.new(area.width, area.height)
      bitmap.blt(0, 0, sheet, area)
      sheet.dispose unless sheet.disposed?
      @pvp_pictures[key] = bitmap
      bitmap
    rescue => e
      CharacterCreation.log("MpBridge.pvp_picture_for(#{key}) FAILED: #{e.class}: #{e.message}")
      @pvp_pictures[key] = false if @pvp_pictures
      nil
    end

    def self.pvp_character_area(sheet)
      step = 4
      left, top, right, bottom = sheet.width, sheet.height, -1, -1

      (0...sheet.height).step(step) do |y|
        (0...sheet.width).step(step) do |x|
          next if sheet.get_pixel(x, y).alpha == 0
          left = x if x < left
          right = x if x > right
          top = y if y < top
          bottom = y if y > bottom
        end
      end

      return sheet.rect if right < 0

      left = [left - step, 0].max
      top = [top - step, 0].max
      Rect.new(left, top,
               [right + step, sheet.width].min - left,
               [bottom + step, sheet.height].min - top)
    end
  end

  #=== LrCompat =============================================================
  module LrCompat
    def self.try_install
      return if @settled
      if defined?(MGQ_LukaReplacer) &&
        !(MGQ_LukaReplacer.const_defined?(:CC_SHIM) && MGQ_LukaReplacer::CC_SHIM)
        @settled = true
        CharacterCreation.log("LrCompat: MGQ_LukaReplacer already defined, deferring to it")
        return
      end
      unless defined?(Game_MpActor)
        @settled = true
        return
      end

      @settled = true
      # install_shim is idempotent only when MGQ_LukaReplacer is not yet defined;
      # if the bottom-of-file installer already ran, skip it. Otherwise define it.
      install_shim unless defined?(MGQ_LukaReplacer)
      CharacterCreation::BattleLines.install
      CharacterCreation.log("LrCompat: installed the MGQ_LukaReplacer shim")
    rescue => e
      CharacterCreation.log("LrCompat.try_install FAILED: #{e.class}: #{e.message}")
    end

    def self.install_shim
      Object.const_set(:MGQ_LukaReplacer, build_shim_module)
    end

    def self.install_setup_guard
      return if @guards_installed
      @guards_installed = true

      unless defined?(Game_Actor) && defined?(Game_Actors)
        CharacterCreation.log("LrCompat: Game_Actor / Game_Actors not defined, setup guard skipped")
        return
      end

      Game_Actor.class_eval do
        alias_method :cc_lrcompat_setup, :setup unless method_defined?(:cc_lrcompat_setup)
        def setup(actor_id, *args)
          MGQ_LukaReplacer.setting_up(self, actor_id) { cc_lrcompat_setup(actor_id, *args) }
        end
      end

      Game_Actors.class_eval do
        alias_method :cc_lrcompat_lookup, :[] unless method_defined?(:cc_lrcompat_lookup)
        def [](actor_id)
          MGQ_LukaReplacer.stand_in_actor(actor_id, @data) || cc_lrcompat_lookup(actor_id)
        end
      end

      CharacterCreation.log("LrCompat: setup guard installed")
    rescue => e
      CharacterCreation.log("LrCompat.install_setup_guard FAILED: #{e.class}: #{e.message}")
    end

    def self.build_shim_module
      shim = Module.new
      shim.const_set(:CC_SHIM, true)
      shim.const_set(:PERSONAS, [1, 2, 3])

      shim.define_singleton_method(:hero_key) do |actor|
        begin
          key = actor && actor.instance_variable_get(:@cc_character_key)
          key ? key.to_s : ""
        rescue => e
          CharacterCreation.log("LrCompat.hero_key FAILED: #{e.class}: #{e.message}")
          ""
        end
      end

      shim.define_singleton_method(:dress) do |actor, key|
        begin
          k = key.to_s
          if k.empty?
            nil
          else
            character = CharacterCreation.character_for_mp_key(k)
            if character
              begin
                CharacterCreation::BlobRegistry.register(character)
              rescue => e
                CharacterCreation.log("LrCompat.dress register FAILED for #{k.inspect}: #{e.class}: #{e.message}")
              end
              CharacterCreation::LrCompat.apply_graphics(actor, character)
              actor.instance_variable_set(:@cc_character_key, k)
              actor.instance_variable_set(:@mgq_luka_key,     k)
            end
          end
        rescue => e
          CharacterCreation.log("LrCompat.dress FAILED for #{key.inspect}: #{e.class}: #{e.message}")
        end
      end

      shim.define_singleton_method(:hero_of) do |actor|
        begin
          key = actor && actor.instance_variable_get(:@cc_character_key)
          if key && !key.to_s.empty?
            CharacterCreation.character_for_mp_key(key.to_s)
          else
            nil
          end
        rescue => e
          CharacterCreation.log("LrCompat.hero_of FAILED: #{e.class}: #{e.message}")
          nil
        end
      end

      shim.define_singleton_method(:face) do |name, index, key = nil|
        begin
          k = key.to_s
          if k.empty?
            [name, index]
          else
            character = CharacterCreation.character_for_mp_key(k)
            if character
              slot = CharacterCreation::LrCompat.face_slot_for($data_actors, name)
              if slot && CharacterCreation::BlobRegistry.fetch(
                   CharacterCreation.image_name(character.key, slot))
                [CharacterCreation.image_name(character.key, slot), 0]
              else
                [name, index]
              end
            else
              [name, index]
            end
          end
        rescue => e
          CharacterCreation.log("LrCompat.face FAILED: #{e.class}: #{e.message}")
          [name, index]
        end
      end

      shim.define_singleton_method(:building) do
        @building ||= {}
      end

      shim.define_singleton_method(:setting_up) do |actor, actor_id, &block|
        return block.call unless PERSONAS.include?(actor_id)

        building[actor_id] = actor
        begin
          block.call
        ensure
          building.delete(actor_id)
        end
      end

      shim.define_singleton_method(:stand_in_actor) do |actor_id, actors|
        return nil if building.empty?

        data = $data_actors && $data_actors[actor_id]
        persona_id = data && data.respond_to?(:original_persona_id) ? data.original_persona_id : actor_id
        (actors && actors[persona_id]) ? nil : building[persona_id]
      end
      shim
    end

    def self.face_slot_for(actors, name)
      persona = CharacterCreation::PERSONAS.find do |id|
        actor_data = actors && actors[id]
        actor_data && actor_data.face_name == name
      end
      case persona
      when 2 then :form2_face
      when 3 then :form3_face
      when 1 then :face
      else nil
      end
    end

    def self.apply_graphics(actor, character)
      return unless actor && character

      new_face   = CharacterCreation.image_name(character.key, :face)
      new_sprite = CharacterCreation.image_name(character.key, :sprite)
      has_face   = CharacterCreation::BlobRegistry.fetch(new_face)   ? true : false
      has_sprite = CharacterCreation::BlobRegistry.fetch(new_sprite) ? true : false

      sprite_name  = has_sprite ? "$#{new_sprite}" : actor.character_name
      sprite_index = has_sprite ? 0               : actor.character_index
      face_name    = has_face   ? new_face        : actor.face_name
      face_index   = has_face   ? 0               : actor.face_index

      actor.set_graphic(sprite_name, sprite_index, face_name, face_index)

      actor.instance_variable_set(:@cc_character_key, character.key.to_s)
      actor.instance_variable_set(:@mgq_luka_key,     character.key.to_s)
    end
  end

  #=== BattleLines ==========================================================
  module BattleLines
    PERSONA_FACES = { "ruka_fc1" => 1, "ruka_fc4" => 2, "ruka_fc3" => 3 }.freeze

    LUKA_FACE = /\Aruka_fc(?:1|2|3|4|5)\z/i

    PINCH_HP = 0.25

    DOWN_SITUATIONS = {
      :dead_word         => :down,
      :orgasm_word       => :pleasure,
      :incontinence_word => :pleasure,
      :predation_word    => :eaten,
    }.freeze

    CUTIN_FIELDS = [:ct_type, :ct_pic, :ct_se].freeze

    def self.character_for(actor)
      return nil unless actor
      return nil unless actor.is_a?(Game_Actor)
      return nil unless CharacterCreation::PERSONAS.include?(actor.id)
      key = actor.instance_variable_get(:@mgq_luka_key).to_s
      if !key.empty?
        return CharacterCreation.character_for_mp_key(key)
      end
      CharacterCreation.current_character
    rescue
      nil
    end

    def self.cutins_for(character, persona_id)
      return [] unless character
      form = case persona_id
            when 2 then character.form2
            when 3 then character.form3
            end
      own = form && form.cutins
      return format_cutins(own, :"form#{persona_id}_cutin") if own && !own.empty?
      format_cutins(character.cutins, :cutin)
    end

    def self.format_cutins(source, slot_prefix)
      return [] unless source
      source.each_with_index.map do |cutin, i|
        skill_ids, type, image, se = cutin
        [skill_ids, type, image, se, :"#{slot_prefix}_#{i}"]
      end
    end

    def self.face_cell?(name, cell)
      sheet = face_sheet(name)
      return false unless sheet && cell.is_a?(Integer) && cell >= 0
      cell % 4 < sheet[0] && cell / 4 < sheet[1]
    end

    def self.face_sheet(name)
      @face_sheets ||= {}
      return @face_sheets[name] if @face_sheets.key?(name)
      bmp = Cache.face(name)
      @face_sheets[name] = [[bmp.width / 96, 4].min, bmp.height / 96]
    rescue
      @face_sheets[name] = nil
    end

    def self.face_of(character, persona_id)
      return nil unless character
      slot = case persona_id
             when 2 then (character.form2 && character.form2.face_blob) ? :form2_face : :face
             when 3 then (character.form3 && character.form3.face_blob) ? :form3_face : :face
             else :face
             end
      name = CharacterCreation.image_name(character.key, slot)
      return nil unless CharacterCreation::BlobRegistry.fetch(name)
      [name, 0]
    end

    def self.expressions_of(character, persona_id)
      return {} unless character
      form = persona_id != 1 && (persona_id == 2 ? character.form2 : character.form3)
      (form && form.expressions) || character.expressions || {}
    end

    def self.line_cell(character, persona_id, face, situation, actor)
      situation = :pinch if situation == :skill && actor &&
                            actor.hp <= actor.mhp * PINCH_HP
      cell = expressions_of(character, persona_id)[situation]
      cell && face_cell?(face[0], cell) ? cell : face[1]
    end

    def self.name_of(character)
      character && !character.name.to_s.empty? ? character.name : nil
    end

    DEBUG_RENAME = true

    def self.rename_speaker(word, from_name, to_name)
      return unless word && from_name && to_name
      lines = word.instance_variable_get(:@words)
      return unless lines
      lines.map! do |line|
        line = line.gsub("\\n<#{from_name}>")  { "\\n<#{to_name}>" }
        line = line.gsub("\\<n#{from_name}>")  { "\\<n#{to_name}>" }
        line = line.gsub("<#{from_name}>")     { "<#{to_name}>" }
        line = line.gsub("【#{from_name}】")    { "【#{to_name}】" }
        line
      end
    rescue => e
      CharacterCreation.log("rename_speaker FAILED: #{e.class}: #{e.message}")
    end

    def self.dress_word(actor, word, situation)
      character = character_for(actor)
      if DEBUG_RENAME
        CharacterCreation.log(
          "dress_word: actor=#{actor.name.inspect} id=#{actor.id} key=#{actor.instance_variable_get(:@mgq_luka_key).inspect} " \
          "character=#{character ? character.key.inspect : 'nil'}"
        )
      end
      return word unless character && word

      face = face_of(character, actor.id)
      shown = word.instance_variable_get(:@face_name)
      if DEBUG_RENAME
        CharacterCreation.log(
          "dress_word: face=#{face.inspect} shown=#{shown.inspect}"
        )
      end
      return word unless face && shown.to_s =~ LUKA_FACE
      # If the word already carries one of the character's own faces (from a
      # previous dressing pass), leave it alone so a re-dress is idempotent.
      shown = word.instance_variable_get(:@face_name).to_s
      return word if shown == face[0]

      name = name_of(character)
      dressed = Marshal.load(Marshal.dump(word))
      rename_speaker(dressed, luka_name_for(word), name) if name
      dressed.instance_variable_set(:@face_name, face[0])
      dressed.instance_variable_set(:@face_index,
                                    line_cell(character, actor.id, face, situation, actor))
      dressed
    rescue => e
      CharacterCreation.log("BattleLines.dress_word FAILED: #{e.class}: #{e.message}")
      word
    end

    def self.word_table(actor, character, table, cutins)
      return table if cutins.empty?
      words = {}
      (table || {}).each do |key, entry|
        words[key] = entry[:common] ? entry : entry.reject { |field, _| CUTIN_FIELDS.include?(field) }
      end
      cutins.each do |skill_ids, type, image, se, slot_name|
        next unless image && image[2] && !image[2].empty?
        pic = CharacterCreation.image_name(character.key, slot_name)
        skill_ids.each do |skill_id|
          found = words.keys.select do |key|
            key.respond_to?(:include?) ? key.include?(skill_id) : key == skill_id
          end.last
          entry = found ? words[found].dup : {}
          words.delete([skill_id])
          words[[skill_id]] = entry.merge(:ct_type => type, :ct_pic => pic, :ct_se => se)
        end
      end
      words
    end

    LUKA_NAME = "Luka".freeze

    def self.luka_name_for(_word)
      LUKA_NAME
    end

    def self.install
      return if @installed
      return unless defined?(Game_Actor) && defined?(NWConst::Actor::SKILL_WORDS)
      @installed = true
      install_actor_hooks
      install_battle_hooks
      CharacterCreation.log("BattleLines: installed")
    rescue => e
      CharacterCreation.log("BattleLines.install FAILED: #{e.class}: #{e.message}")
    end

    def self.install_actor_hooks
      Game_Actor.class_eval do
        unless method_defined?(:cc_bl_skill_word)
          alias_method :cc_bl_skill_word, :skill_word
          def skill_word(skill_id)
            CharacterCreation::BattleLines.dress_word(
              self, cc_bl_skill_word(skill_id), :skill
            )
          end
        end

        unless method_defined?(:cc_bl_skill_word_hash)
          alias_method :cc_bl_skill_word_hash, :skill_word_hash
          def skill_word_hash
            table = cc_bl_skill_word_hash
            character = CharacterCreation::BattleLines.character_for(self)
            return table unless character
            cutins = CharacterCreation::BattleLines.cutins_for(character, id)
            return table if cutins.empty?
            CharacterCreation::BattleLines.word_table(self, character, table, cutins)
          end
        end

        unless method_defined?(:cc_bl_exist_cutin?)
          alias_method :cc_bl_exist_cutin?, :exist_cutin?
          def exist_cutin?(skill_id)
            return cc_bl_exist_cutin?(skill_id) unless CharacterCreation::BattleLines.character_for(self)
            begin
              super
            rescue
              false
            end
          end
        end

        CharacterCreation::BattleLines::DOWN_SITUATIONS.each do |line, situation|
          original = :"cc_bl_#{line}"
          next if method_defined?(original)
          alias_method original, line
          define_method(line) do |*args|
            CharacterCreation::BattleLines.dress_word(
              self, send(original, *args), situation
            )
          end
        end
      end
    end

    def self.install_battle_hooks
      return unless defined?(Scene_Battle)
      return if Scene_Battle.method_defined?(:cc_bl_process_luca_orgasm)
      Scene_Battle.class_eval do
        alias_method :cc_bl_process_luca_orgasm, :process_luca_orgasm
        def process_luca_orgasm(*args)
          actor = $game_actors && $game_actors[1]
          character = CharacterCreation::BattleLines.character_for(actor)
          return if character && character.sex == :female
          cc_bl_process_luca_orgasm(*args)
        end
      end
    rescue => e
      CharacterCreation.log("BattleLines battle hooks FAILED: #{e.class}: #{e.message}")
    end
  end

  #=== PackTransfer =========================================================
  module PackTransfer
    LOG_TAG = "PackTransfer"

    CHUNK_BYTES = 2000
    SEND_EVERY = 2
    RETRY_FRAMES = 1800
    MAX_TRIES = 2

    @settled = false
    @peers = {}
    @frame = 0

    class << self
      attr_accessor :settled
      attr_accessor :peers
    end

    def self.log(message)
      CharacterCreation.log("#{LOG_TAG}: #{message}")
    rescue
    end

    def self.try_install
      return if @settled
      unless defined?(MGQ_MpOverworldSync)
        @settled = true
        return
      end

      @settled = true
      install_routes
      install_observers
      log("pack transfer installed")
    rescue => e
      log("try_install FAILED: #{e.class}: #{e.message}")
    end

    def self.install_routes
      MGQ_MpOverworldSync.route("ccpackhas")  { |peer, message| receive_has(peer, message) }
      MGQ_MpOverworldSync.route("ccpackyes")  { |peer, message| receive_yes(peer, message) }
      MGQ_MpOverworldSync.route("ccpackno")   { |peer, message| receive_no(peer, message) }
      MGQ_MpOverworldSync.route("ccpack")     { |peer, message| receive_chunk(peer, message) }
      MGQ_MpOverworldSync.route("ccpackdone") { |peer, message| receive_done(peer, message) }
      MGQ_MpOverworldSync.route("ccpackfail") { |peer, message| receive_fail(peer, message) }
    end

    def self.install_observers
      MGQ_MpOverworldSync.on_observe  { |peer| observe_peer(peer) }
      MGQ_MpOverworldSync.on_tick     { |in_world| tick(in_world) }
      MGQ_MpOverworldSync.on_leave    { |peer| forget_peer(peer) }
    end

    def self.local_key
      character = CharacterCreation.current_character
      return nil unless character
      key = character.key.to_s
      key.empty? ? nil : key
    rescue
      nil
    end

    def self.local_pack_path
      key = local_key
      return nil unless key
      path = File.join(CharacterCreation::HEROES_DIR, "#{key}#{CharacterCreation::PACK_EXT}")
      File.exist?(path) ? path : nil
    rescue
      nil
    end

    def self.peer_state(seat)
      @peers[seat] ||= {
        :name => "seat #{seat}",
        :probed => false,
        :sent => {},
        :tries => {},
        :retry_at => {},
        :received => {},
      }
    end

    def self.observe_peer(peer)
      return unless peer
      seat = peer.seat
      record = peer_state(seat)
      record[:name] = peer.state["name"].to_s unless peer.state["name"].to_s.empty?
      return if record[:probed]
      return unless local_key
      return unless probe(seat, record)
      record[:probed] = true
    rescue => e
      log("observe_peer FAILED: #{e.class}: #{e.message}")
    end

    def self.forget_peer(peer)
      return unless peer
      seat = peer.seat
      record = @peers.delete(seat)
      return unless record
      count = record[:sent].size + record[:received].size
      log("#{record[:name]} left (seat #{seat}); dropped #{count} transfer record(s)")
    rescue => e
      log("forget_peer FAILED: #{e.class}: #{e.message}")
    end

    def self.probe(seat, record)
      key = local_key
      unless key
        log("no local character to send to #{record[:name]} (seat #{seat})")
        return false
      end
      sent = MGQ_MpOverworldSync.tell(seat, { "ccpackhas" => key })
      log("probed #{record[:name]} for #{key}#{sent ? '' : ', which did not go out'}")
      sent ? true : false
    rescue => e
      log("probe FAILED: #{e.class}: #{e.message}")
      false
    end

    def self.receive_yes(peer, message)
      return unless peer
      record = peer_state(peer.seat)
      log("#{record[:name]} has #{message['ccpackyes']}, not sending")
    rescue => e
      log("receive_yes FAILED: #{e.class}: #{e.message}")
    end

    def self.receive_no(peer, message)
      return unless peer
      seat = peer.seat
      record = peer_state(seat)
      key = message["ccpackno"].to_s
      return if key.empty?
      return if key != local_key
      start_send(seat, record, key)
    rescue => e
      log("receive_no FAILED: #{e.class}: #{e.message}")
    end

    def self.start_send(seat, record, key)
      path = local_pack_path
      unless path
        log("no .luka file for #{key}, not sending to #{record[:name]}")
        return
      end
      bytes = File.binread(path)
      base64 = [bytes].pack("m0")
      chunks = base64.scan(/.{1,#{CHUNK_BYTES}}/m)
      total = chunks.size
      sha = Zlib.crc32(base64).to_s(16)
      record[:sent][key] = {
        :chunks => chunks,
        :total => total,
        :sha => sha,
        :at => 0,
        :bytes => bytes.bytesize,
      }
      record[:tries][key] = 0
      record[:retry_at][key] = nil
      log("sending #{key} to #{record[:name]} (#{total} chunks, #{bytes.bytesize} bytes)")
    rescue => e
      log("start_send FAILED for #{key}: #{e.class}: #{e.message}")
    end

    def self.tick(in_world)
      @frame += 1
      if in_world
        return if @frame % SEND_EVERY != 0
        @peers.each do |seat, record|
          send_one_chunk(seat, record)
          check_retry(seat, record)
        end
      else
        unless @peers.empty?
          log("world closed, dropped state for #{@peers.size} peer(s)")
          @peers.clear
        end
      end
    rescue => e
      log("tick FAILED: #{e.class}: #{e.message}")
    end

    def self.send_one_chunk(seat, record)
      record[:sent].each do |key, transfer|
        next if transfer[:at] >= transfer[:total]
        chunk = transfer[:chunks][transfer[:at]]
        sent = MGQ_MpOverworldSync.tell(seat, {
          "ccpack" => key,
          "seq"   => transfer[:at] + 1,
          "of"    => transfer[:total],
          "sha"   => transfer[:sha],
        }, chunk)
        unless sent
          log("a chunk of #{key} to #{record[:name]} did not go out")
          return
        end
        transfer[:at] += 1
        if transfer[:at] == transfer[:total]
          log("sent #{key} to #{record[:name]} (#{transfer[:total]} chunks)")
          record[:retry_at][key] = @frame + RETRY_FRAMES
        end
      end
    rescue => e
      log("send_one_chunk FAILED: #{e.class}: #{e.message}")
    end

    def self.check_retry(seat, record)
      record[:retry_at].each do |key, at|
        next unless at && @frame >= at
        tries = record[:tries][key].to_i
        if tries + 1 >= MAX_TRIES
          record[:sent].delete(key)
          record[:retry_at].delete(key)
          log("transfer of #{key} to #{record[:name]} failed: no acknowledgement after #{MAX_TRIES} tries")
          next
        end
        record[:tries][key] = tries + 1
        transfer = record[:sent][key]
        next unless transfer
        transfer[:at] = 0
        record[:retry_at][key] = nil
        log("retrying #{key} to #{record[:name]} (try #{tries + 2} of #{MAX_TRIES})")
      end
    rescue => e
      log("check_retry FAILED: #{e.class}: #{e.message}")
    end

    def self.receive_has(peer, message)
      return unless peer
      key = message["ccpackhas"].to_s
      return if key.empty?
      have = !CharacterCreation.character_for_mp_key(key).nil?
      route = have ? "ccpackyes" : "ccpackno"
      MGQ_MpOverworldSync.tell(peer.seat, { route => key })
      name = peer.state["name"].to_s
      log("#{name} asked for #{key}, we #{have ? 'have it' : 'do not have it'}")
    rescue => e
      log("receive_has FAILED: #{e.class}: #{e.message}")
    end

    def self.receive_chunk(peer, message)
      return unless peer
      seat = peer.seat
      key = message["ccpack"].to_s
      seq = message["seq"].to_i
      total = message["of"].to_i
      sha = message["sha"].to_s
      return if key.empty? || seq <= 0 || total <= 0 || sha.empty?
      record = peer_state(seat)
      id = "#{seat}:#{key}:#{sha}"
      buffer = record[:received][id] ||= {
        :key => key,
        :total => total,
        :sha => sha,
        :chunks => {},
        :at => @frame,
        :logged => false,
      }
      if buffer[:chunks].empty? && !buffer[:logged]
        buffer[:logged] = true
        log("receiving #{key} from #{record[:name]} (#{total} chunks)")
      end
      buffer[:chunks][seq] = message[:payload].to_s
      buffer[:at] = @frame
      complete_receive(seat, record, id, buffer) if buffer[:chunks].size == buffer[:total]
    rescue => e
      log("receive_chunk FAILED: #{e.class}: #{e.message}")
    end

    def self.complete_receive(seat, record, id, buffer)
      parts = (1..buffer[:total]).map { |n| buffer[:chunks][n] }
      if parts.any? { |part| part.nil? }
        log("a chunk of #{buffer[:key]} from #{record[:name]} is missing")
        record[:received].delete(id)
        MGQ_MpOverworldSync.tell(seat, { "ccpackfail" => buffer[:key] })
        return
      end
      base64 = parts.join
      unless Zlib.crc32(base64).to_s(16) == buffer[:sha]
        log("a chunk of #{buffer[:key]} from #{record[:name]} was corrupted")
        record[:received].delete(id)
        MGQ_MpOverworldSync.tell(seat, { "ccpackfail" => buffer[:key] })
        return
      end
      bytes = base64.unpack("m0").first
      path = File.join(CharacterCreation::CACHE_DIR, "received_#{buffer[:key]}_#{buffer[:sha][0, 8]}.luka")
      File.open(path, "wb") { |f| f.write(bytes) }
      character = CharacterCreation::Pack.read(path)
      unless character
        log("received pack for #{buffer[:key]} from #{record[:name]} would not parse")
        record[:received].delete(id)
        MGQ_MpOverworldSync.tell(seat, { "ccpackfail" => buffer[:key] })
        return
      end
      CharacterCreation::BlobRegistry.register(character)
      alias_cache(character, buffer[:key])
      refresh_ghosts(buffer[:key])
      (CharacterCreation.mp_received_characters ||= {})[buffer[:key]] = character
      record[:received].delete(id)
      log("received #{buffer[:key]} from #{record[:name]}, registered")
      MGQ_MpOverworldSync.tell(seat, { "ccpackdone" => buffer[:key] })
    rescue => e
      log("complete_receive FAILED: #{e.class}: #{e.message}")
    end

    def self.alias_cache(character, wire_key)
      return if wire_key.to_s.empty? || character.key.to_s == wire_key.to_s

      source = File.join(CharacterCreation::CACHE_DIR, character.key.to_s)
      target = File.join(CharacterCreation::CACHE_DIR, wire_key.to_s)
      return unless File.directory?(source)

      CharacterCreation.make_dir(target)
      Dir.glob(File.join(source, "*.png")).each do |path|
        name = File.basename(path)
        next if File.exist?(File.join(target, name))

        File.open(File.join(target, name), "wb") { |f| f.write(File.binread(path)) }
      end
    rescue => e
      log("alias_cache FAILED for #{wire_key}: #{e.class}: #{e.message}")
    end

    def self.refresh_ghosts(wire_key)
      return if wire_key.to_s.empty?
      return unless defined?(MGQ_MpOverworld) && defined?(MGQ_MpOverworldSync)

      # 1. Clear the Multiplayer mod's graphic failure cache
      graphics = MGQ_MpOverworld.instance_variable_get(:@graphics)
      if graphics.is_a?(Hash)
        # Clear any cache entry that contains our prefix, since the files are now on disk
        graphics.keys.each do |k|
          graphics.delete(k) if k.to_s.include?("lr_cc_#{wire_key}")
        end
      end

      # 2. Force all peers using this key to refresh their appearance
      MGQ_MpOverworldSync::Peers.all.each do |peer|
        next unless peer.respond_to?(:state) && peer.state
        
        # Check if the peer is using this character (regardless of sprite format)
        peer_hero = peer.state["hero"].to_s
        next unless peer_hero == wire_key

        ghost = peer.ghost
        next unless ghost
        
        # Clear the ghost's internal memory of the sprite so it forces a re-draw
        ghost.instance_variable_set(:@sent_name, nil)
        ghost.instance_variable_set(:@sent_index, nil)
        
        # Tell the ghost to update its graphics
        ghost.follow(peer.state, peer.member) if ghost.respond_to?(:follow)
      end
    rescue => e
      log("refresh_ghosts FAILED for #{wire_key}: #{e.class}: #{e.message}")
    end

    def self.receive_done(peer, message)
      return unless peer
      seat = peer.seat
      record = peer_state(seat)
      key = message["ccpackdone"].to_s
      return if key.empty?
      record[:sent].delete(key)
      record[:retry_at].delete(key)
    rescue => e
      log("receive_done FAILED: #{e.class}: #{e.message}")
    end

    def self.receive_fail(peer, message)
      return unless peer
      seat = peer.seat
      record = peer_state(seat)
      key = message["ccpackfail"].to_s
      return if key.empty?
      transfer = record[:sent][key]
      return unless transfer
      transfer[:at] = 0
      record[:retry_at][key] = @frame + 30
    rescue => e
      log("receive_fail FAILED: #{e.class}: #{e.message}")
    end
  end
end

# Install the shim (if no real Luka Replacer is present) and the setup
# guard at load time, so they are active before DataManager.setup_new_game
# builds the live actor.
if defined?(Game_Actor) && defined?(Game_Actors)
  CharacterCreation::LrCompat.install_shim unless defined?(MGQ_LukaReplacer)
  CharacterCreation::LrCompat.install_setup_guard
end

CharacterCreation.log("CC_Multiplayer loaded")