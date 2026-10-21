#==============================================================================
# 03_BattleLines.rbx
# Character Creation — compatibility shim for Luka Replacer & battle lines.
#==============================================================================

module CharacterCreation
  module LrCompat
    def self.try_install
      return if @settled
      if defined?(MGQ_LukaReplacer)
        @settled = true
        CharacterCreation.log("LrCompat: MGQ_LukaReplacer already defined, deferring to it")
        return
      end
      unless defined?(Game_MpActor)
        @settled = true
        return
      end
      @settled = true
      install_shim
      install_setup_guard
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
              CharacterCreation::BlobRegistry.register(character)
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
      return word unless character && word
      face = face_of(character, actor.id)
      shown = word.instance_variable_get(:@face_name)
      return word unless face && shown.to_s =~ LUKA_FACE
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
end