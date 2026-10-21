#==============================================================================
# 02_Hooks.rbx
# Character Creation — Pack handling, Blob Registry, Engine Hooks.
#==============================================================================

module CharacterCreation
  module Pack
    def self.read(path)
      return nil unless File.exist?(path)
      raw = File.open(path, "rb") { |f| f.read }
      return nil unless raw.size > PACK_MAGIC.size + 1
      return nil unless raw[0, PACK_MAGIC.size] == PACK_MAGIC
      return nil unless raw.getbyte(PACK_MAGIC.size) == PACK_VERSION
      body = raw[(PACK_MAGIC.size + 1)..-1]
      payload = Zlib::Inflate.inflate(crypt(body))
      entries = parse_payload(payload)
      hero_text = entries[ENTRY_HERO]
      return nil unless hero_text
      key = File.basename(path, PACK_EXT).downcase.gsub(/[^a-z0-9_]/, "_").to_sym
      build_character(key, hero_text, entries)
    rescue => e
      CharacterCreation.log("Pack.read FAILED for #{path}: #{e.class}: #{e.message}")
      nil
    end

    def self.read_folder(dir)
      return nil unless File.directory?(dir)
      key = File.basename(dir).downcase.gsub(/[^a-z0-9_]/, "_").to_sym
      entries = {}
      Dir.glob(File.join(dir, "*")).each do |path|
        entries[File.basename(path)] = File.binread(path)
      end
      hero_text = entries[ENTRY_HERO]
      return nil unless hero_text
      build_character(key, hero_text, entries)
    rescue => e
      CharacterCreation.log("Pack.read_folder FAILED for #{dir}: #{e.class}: #{e.message}")
      nil
    end

    def self.read_folder_partial(dir)
      return nil unless File.directory?(dir)
      key = File.basename(dir).downcase.gsub(/[^a-z0-9_]/, "_").to_sym
      entries = {}
      Dir.glob(File.join(dir, "*")).each do |path|
        next unless File.file?(path)
        entries[File.basename(path)] = File.binread(path)
      end
      hero_text = entries[ENTRY_HERO]
      if hero_text
        build_character(key, hero_text, entries)
      else
        c = CharacterCreation.new_character(key)
        c.trait_name = nil
        c.trait_lines = []
        c.features = []
        c.tags = []
        c.cutins = []
        c.class_levels = {}
        c.equips = {}
        attach_images(c, entries)
        c
      end
    rescue => e
      CharacterCreation.log("Pack.read_folder_partial FAILED for #{dir}: #{e.class}: #{e.message}")
      nil
    end

    def self.build_character(key, hero_text, entries)
      c = CharacterCreation.new_character(key)
      c.trait_name   = nil
      c.trait_lines  = []
      c.features     = []
      c.tags         = []
      c.cutins       = []
      c.story_rules  = []
      c.class_levels = {}
      c.equips       = {}
      read_hero_lines(c, hero_text.dup.force_encoding("UTF-8"))
      attach_images(c, entries)
      c
    end

    def self.read_hero_lines(c, text)
      text.each_line do |raw|
        line = raw.strip
        next if line.empty? || line.start_with?("#")
        name, value = line.split("=", 2)
        next unless value
        name = name.strip
        value = value.strip
        if name =~ /\Aform([23])\.(\w+)\z/
          read_form_line(c, $1.to_i, $2, value)
        else
          read_main_line(c, name, value)
        end
      end
    end

    def self.read_main_line(c, name, value)
      case name
      when "name"           then c.name = value unless value.empty?
      when "nickname"       then c.nickname = value
      when "artist"         then c.artist = value
      when "sex"            then c.sex = value == "female" ? :female : :male
      when "bust_size"      then c.bust_size = value
      when "job"            then c.job = value.to_i
      when "race"           then c.race = value.to_i
      when "class_levels"   then read_class_levels(c, value)
      when "base_stats"     then c.base_stats = value == "custom" ? :custom : :luka
      when /\Astat([0-7])\z/ then read_curve(c, $1.to_i, value)
      when /\Aequip([0-5])\z/ then c.equips[$1.to_i] = value.to_i
      when "trait"          then c.trait_name = value
      when "trait_line"     then (c.trait_lines ||= []) << value
      when "feature"        then (f = parse_feature(value)) && c.features << f
      when "tag"            then c.tags << value
      when "expressions"    then read_expressions(c, value)
      when "cutin"          then read_cutin(c, value)
      when "story"          then read_story(c, value)
      when "recruit_self"   then c.recruit_self = value == "block" ? :block : :allow
      end
    end

    def self.read_form_line(c, n, key, value)
      if n == 2
        c.form2 ||= Form.new(nil, nil, nil, nil, nil, false, nil, [], [], [])
        form = c.form2
      else
        c.form3 ||= Form.new(nil, nil, nil, nil, nil, false, nil, [], [], [])
        form = c.form3
      end
      case key
      when "sprite"       then form.sprite_blob  = value
      when "face"         then form.face_blob    = value
      when "picture"      then form.picture_blob = value
      when "expressions"  then read_expressions_into(form, value)
      when "cutin"        then read_cutin_into(form, value, n)
      when "own_trait"    then form.own_trait = (value == "yes")
      when "trait"        then form.trait_name = value
      when "trait_line"   then (form.trait_lines ||= []) << value
      when "feature"      then (form.features   ||= []) << parse_feature(value)
      when "tag"          then (form.tags       ||= []) << value
      end
    end

    def self.read_class_levels(c, value)
      c.class_levels = {}
      value.split(",").each do |pair|
        id, lv = pair.strip.split("-")
        next unless id && lv
        c.class_levels[id.to_i] = lv.to_i
      end
    end

    def self.read_curve(c, stat, value)
      a, b, growth = value.split(",")
      c.curves[stat] = [a.to_i, b.to_i, growth.to_i]
    end

    def self.read_expressions(c, value)
      c.expressions ||= {}
      read_expressions_into(c, value)
    end

    def self.read_expressions_into(owner, value)
      owner.expressions ||= {}
      value.split(",").each do |entry|
        situation, cell = entry.split(":", 2)
        next unless situation && cell
        owner.expressions[situation.strip.to_sym] = cell.strip.to_i
      end
    end

    def self.read_cutin(c, value)
      c.cutins ||= []
      read_cutin_into(c, value, nil)
    end

    def self.read_cutin_into(owner, value, form_n)
      owner.cutins ||= []
      skill_list, type, image, se = value.split(";").map(&:strip)
      skill_ids = skill_list.split(",").map(&:to_i).reject { |i| i <= 0 }
      src, file = image.to_s.split(":", 2)
      image_ref = [src == "pack" ? :pack : :game, file, nil]
      owner.cutins << [skill_ids, type.to_sym, image_ref, se]
    end

    def self.read_story(c, value)
      kind, from_id, to_id = value.split(":")
      c.story_rules << [kind, from_id.to_i, to_id.to_i]
    end

    def self.parse_feature(value)
      code, data_id, val = value.split(":")
      if val.to_s.start_with?("{") || val.to_s.include?("=>")
        hash = {}
        val.scan(/\{?(\d+)=([\d\.]+)\}?/) do |k, v|
          hash[k.to_i] = v.include?(".") ? v.to_f : v.to_i
        end
        return [code.to_i, data_id.to_i, hash]
      end
      if val == "true"
        return [code.to_i, data_id.to_i, true]
      elsif val == "false"
        return [code.to_i, data_id.to_i, false]
      end
      [code.to_i, data_id.to_i, val.to_f]
    end

    def self.attach_images(c, entries)
      c.face_blob    = entries["face.png"]
      c.sprite_blob  = entries["sprite.png"]
      c.picture_blob = entries["picture.png"]
      attach_cutin_images(c, entries, "")
      attach_form_images(c.form2, entries, "form2_") if c.form2
      attach_form_images(c.form3, entries, "form3_") if c.form3
    end

    def self.attach_cutin_images(owner, entries, prefix)
      (owner.cutins || []).each_with_index do |cutin, i|
        _skill_ids, _type, image, _se = cutin
        next unless image && image[0] == :pack
        file_name = "#{prefix}cutin_#{i}.png"
        cutin[2] = [:pack, image[1], entries[file_name]] if entries[file_name]
      end
    end

    def self.attach_form_images(form, entries, prefix)
      form.sprite_blob  = attach_one(entries, "#{prefix}sprite.png", form.sprite_blob)
      form.face_blob    = attach_one(entries, "#{prefix}face.png",   form.face_blob)
      form.picture_blob = attach_one(entries, "#{prefix}picture.png", form.picture_blob)
      attach_cutin_images(form, entries, prefix)
    end

    def self.attach_one(entries, name, _declared)
      entries[name]
    end

    def self.parse_payload(payload)
      payload = payload.dup.force_encoding("ASCII-8BIT")
      count = payload[0, 2].unpack("v").first
      offset = 2
      entries = {}
      count.times do
        name_size = payload[offset, 2].unpack("v").first
        name = payload[offset + 2, name_size].force_encoding("UTF-8")
        data_size = payload[offset + 2 + name_size, 4].unpack("V").first
        data = payload[offset + 6 + name_size, data_size]
        entries[name] = data
        offset += 6 + name_size + data_size
      end
      entries
    end

    def self.crypt(data)
      padded = data + "\0" * (data.size % 2)
      words  = padded.unpack("v*")
      keys   = keystream(padded.size).unpack("v*")
      words.each_index { |i| words[i] ^= keys[i] }
      words.pack("v*")[0, data.size]
    end

    def self.keystream(size)
      @key_state ||= KEY_SEED
      @keystream ||= "".force_encoding("ASCII-8BIT")
      missing = size - @keystream.size
      if missing > 0
        bytes = Array.new(missing) do
          @key_state = (@key_state * KEY_MULTIPLIER + KEY_INCREMENT) & 0xFFFFFFFF
          (@key_state >> 16) & 0xFF
        end
        @keystream << bytes.pack("C*")
      end
      @keystream[0, size]
    end

    def self.write(path, character)
      CharacterCreation.make_dir(File.dirname(path))
      hero_text  = build_hero_text(character)
      entries    = { ENTRY_HERO => hero_text.force_encoding("ASCII-8BIT") }
      add_image_entry(entries, "face.png",    character.face_blob)
      add_image_entry(entries, "sprite.png",  character.sprite_blob)
      add_image_entry(entries, "picture.png", character.picture_blob)
      add_form_entries(entries, character.form2, "form2")
      add_form_entries(entries, character.form3, "form3")
      (character.cutins || []).each_with_index do |cutin, i|
        _skill_ids, _type, image, _se = cutin
        next unless image && image[0] == :pack
        add_image_entry(entries, "cutin_#{i}.png", image[2])
      end
      payload = pack_payload(entries)
      body    = crypt(Zlib::Deflate.deflate(payload))
      File.open(path, "wb") do |f|
        f.write(PACK_MAGIC)
        f.write([PACK_VERSION].pack("C"))
        f.write(body)
      end
      true
    rescue => e
      CharacterCreation.log("Pack.write FAILED for #{path}: #{e.class}: #{e.message}")
      false
    end

    def self.build_hero_text(c)
      lines = []
      lines << "# Character Creation mod export"
      lines << "format=1"
      lines << "name=#{c.name}"
      lines << "nickname=#{c.nickname}" unless c.nickname.to_s.empty?
      lines << "artist=#{c.artist}" unless c.artist.to_s.empty?
      lines << "sex=#{c.sex == :female ? 'female' : 'male'}"
      lines << "bust_size=#{c.bust_size}" if c.bust_size && !c.bust_size.empty?
      lines << "job=#{c.job}" if c.job && c.job > 0
      lines << "race=#{c.race}" if c.race && c.race > 0
      lines << class_levels_line(c)
      lines << base_stats_line(c)
      if c.base_stats == :custom
        (0..7).each do |i|
          curve = (c.curves || [])[i]
          lines << "stat#{i}=#{curve[0]},#{curve[1]},#{curve[2]}" if curve
        end
      end
      (c.equips || {}).each do |slot, item_id|
        lines << "equip#{slot}=#{item_id}" if item_id && item_id > 0
      end
      lines << "trait=#{c.trait_name}" unless c.trait_name.to_s.empty?
      (c.trait_lines || []).each { |l| lines << "trait_line=#{l}" }
      (c.features || []).each do |code, id, val|
        if val.is_a?(Hash)
          str = val.map { |k, v| "#{k}=#{v}" }.join(",")
          lines << "feature=#{code}:#{id}:{#{str}}"
        else
          lines << "feature=#{code}:#{id}:#{val}"
        end
      end
      standard = CharacterCreation::StandardTags.tags_for(c)
      remaining_trait_tags = (c.tags || []).reject { |t| CharacterCreation::StandardTags.owns?(t) }
      (standard + remaining_trait_tags).each { |t| lines << "tag=#{t}" }
      lines << expressions_line("expressions", c.expressions)
      (c.cutins || []).each { |cutin| lines << cutin_line("cutin", cutin) }
      (c.story_rules || []).each { |kind, from, to| lines << "story=#{kind}:#{from}:#{to}" }
      lines << "recruit_self=#{c.recruit_self == :block ? 'block' : 'allow'}"
      write_form_lines(lines, c.form2, 2)
      write_form_lines(lines, c.form3, 3)
      lines.compact.reject(&:empty?).join("\n") + "\n"
    end

    def self.class_levels_line(c)
      return nil if c.class_levels.nil? || c.class_levels.empty?
      pairs = c.class_levels.sort.map { |id, lv| "#{id}-#{lv}" }
      "class_levels=#{pairs.join(',')}"
    end

    def self.base_stats_line(c)
      return nil if c.base_stats == :custom
      "base_stats=#{c.base_stats == :luka ? 'luka' : c.base_stats}"
    end

    def self.expressions_line(key, hash)
      return nil if hash.nil? || hash.empty?
      pairs = hash.map { |sit, cell| "#{sit}:#{cell}" }
      "#{key}=#{pairs.join(',')}"
    end

    def self.cutin_line(key, cutin)
      skill_ids, type, image, se = cutin
      src, file = image[0], image[1]
      image_str = "#{src == :pack ? 'pack' : 'game'}:#{file}"
      "#{key}=#{skill_ids.join(',')};#{type};#{image_str};#{se}"
    end

    def self.write_form_lines(lines, form, n)
      return unless form
      lines << "form#{n}.sprite=pack:form#{n}_sprite"  if form.sprite_blob
      lines << "form#{n}.face=pack:form#{n}_face"      if form.face_blob
      lines << "form#{n}.picture=pack:form#{n}_picture" if form.picture_blob
      expr = expressions_line("form#{n}.expressions", form.expressions)
      lines << expr if expr
      (form.cutins || []).each { |cutin| lines << cutin_line("form#{n}.cutin", cutin) }
      if form.own_trait
        lines << "form#{n}.own_trait=yes"
        lines << "form#{n}.trait=#{form.trait_name}" if form.trait_name
        (form.trait_lines || []).each { |l| lines << "form#{n}.trait_line=#{l}" }
        (form.features || []).each { |code, id, val| lines << "form#{n}.feature=#{code}:#{id}:#{val}" }
        (form.tags || []).each { |t| lines << "form#{n}.tag=#{t}" }
      end
    end

    def self.add_image_entry(entries, name, blob)
      entries[name] = blob if blob && !blob.empty?
    end

    def self.add_form_entries(entries, form, prefix)
      return unless form
      add_image_entry(entries, "#{prefix}_sprite.png",  form.sprite_blob)
      add_image_entry(entries, "#{prefix}_face.png",    form.face_blob)
      add_image_entry(entries, "#{prefix}_picture.png", form.picture_blob)
    end

    def self.pack_payload(entries)
      payload = [entries.size].pack("v")
      entries.each do |name, data|
        name_b = name.dup.force_encoding("ASCII-8BIT")
        payload << [name_b.size].pack("v")
        payload << name_b
        payload << [data.size].pack("V")
        payload << data
      end
      payload
    end
  end

  module BlobRegistry
    @blobs = {}

    class << self
      def register(character)
        return unless character
        register_one(character.key, :face,    character.face_blob)
        register_one(character.key, :sprite,  character.sprite_blob)
        register_one(character.key, :picture, character.picture_blob)
        (character.cutins || []).each_with_index do |cutin, i|
          _skill_ids, _type, image, _se = cutin
          next unless image && image[0] == :pack
          register_one(character.key, :"cutin_#{i}", image[2])
        end
        [character.form2, character.form3].each_with_index do |form, i|
          next unless form
          n = i + 2
          register_one(character.key, :"form#{n}_face",    form.face_blob)
          register_one(character.key, :"form#{n}_sprite",  form.sprite_blob)
          register_one(character.key, :"form#{n}_picture", form.picture_blob)
          (form.cutins || []).each_with_index do |cutin, j|
            _skill_ids, _type, image, _se = cutin
            next unless image && image[0] == :pack
            register_one(character.key, :"form#{n}_cutin_#{j}", image[2])
          end
        end
        write_to_disk(character)
      end

      def unregister(key)
        prefix = "lr_cc_#{key}_"
        @blobs.delete_if { |name, _| name.start_with?(prefix) }
      end

      def clear
        @blobs.clear
      end

      def fetch(name)
        @blobs[name]
      end

      def size
        @blobs.size
      end

      def write_to_disk(character)
        return unless character
        dir = File.join(CharacterCreation::CACHE_DIR, character.key.to_s)
        CharacterCreation.make_dir(dir)
        all_for(character).each do |slot, bytes|
          next unless bytes && !bytes.empty?
          File.open(File.join(dir, "#{slot}.png"), "wb") { |f| f.write(bytes) }
        end
      rescue => e
        CharacterCreation.log("BlobRegistry.write_to_disk FAILED: #{e.class}: #{e.message}")
      end

      def all_for(character)
        result = {}
        add_blob(result, :face,    character.face_blob)
        add_blob(result, :sprite,  character.sprite_blob)
        add_blob(result, :picture, character.picture_blob)
        (character.cutins || []).each_with_index do |cutin, i|
          _skill_ids, _type, image, _se = cutin
          next unless image && image[0] == :pack
          add_blob(result, :"cutin_#{i}", image[2])
        end
        [character.form2, character.form3].each_with_index do |form, i|
          next unless form
          n = i + 2
          add_blob(result, :"form#{n}_face",    form.face_blob)
          add_blob(result, :"form#{n}_sprite",  form.sprite_blob)
          add_blob(result, :"form#{n}_picture", form.picture_blob)
          (form.cutins || []).each_with_index do |cutin, j|
            _skill_ids, _type, image, _se = cutin
            next unless image && image[0] == :pack
            add_blob(result, :"form#{n}_cutin_#{j}", image[2])
          end
        end
        result
      end

      private

      def add_blob(hash, slot, bytes)
        return unless bytes && !bytes.empty?
        hash[slot] = bytes
      end

      def register_one(key, slot, blob)
        return unless blob && !blob.empty?
        @blobs[CharacterCreation.image_name(key, slot)] = blob
      end
    end
  end

  module StandardTags
    RACE_CATEGORIES = {
      151  => ["人間",        11], 158  => ["妖魔",        12], 167  => ["亜人",        13],
      175  => ["淫魔",        14], 184  => ["吸血鬼",      15], 194  => ["人魚",        16],
      203  => ["エルフ",      17], 214  => ["妖精",        18], 223  => ["スライム",    19],
      232  => ["魔獣",        20], 245  => ["妖狐",        21], 254  => ["ラミア",      22],
      265  => ["スキュラ",    23], 274  => ["鳥",          24], 283  => ["竜",          25],
      293  => ["陸棲種",      26], 301  => ["海棲種",      27], 309  => ["虫",          28],
      319  => ["植物",        29], 328  => ["ゾンビ",      30], 336  => ["ゴースト",    31],
      344  => ["ドール",      32], 354  => ["キメラ",      33], 362  => ["天使",        34],
      7401 => ["ロイド",      38], 7408 => ["その他",      37],
    }.freeze

    BUST_SKILL_MAP = {
      "Flat"   => 3277, "Small"  => 3278, "Medium" => 3279, "Large"  => 3280, "Huge"   => 3281,
    }.freeze

    REQUIRED_TAGS = [
      "<TP基本値 5>", "<TPLv補正 30>", "<TPLv100補正 30>", "<開始時TP 50%>",
      "<経験値曲線 386>", "<誘惑時使用スキル:3285>", "<人間時追加特徴 397>",
    ].freeze

    HEADS = [
      "<カテゴリー", "<特殊カテゴリー", "<性別", "<初期サブクラス",
      "<経験済職業", "<初期装備", "<スキル変化", "<主人格", "<イラスト",
      "<TP基本値", "<TPLv補正", "<TPLv100補正", "<開始時TP",
      "<経験値曲線", "<誘惑時使用スキル", "<固有習得", "<人間時追加特徴",
      "<パッシブ能力", "<ラーニング", "<夢魔>", "<ターン", "<逃走",
    ].freeze

    def self.owns?(tag)
      HEADS.any? { |head| tag.start_with?(head) }
    end

    def self.tags_for(character)
      return [] unless character
      tags = []
      race_info = RACE_CATEGORIES[character.race]
      if race_info
        name, special_id = race_info
        tags << "<カテゴリー：#{name}>"
        tags << "<特殊カテゴリー #{special_id}>"
      end
      tags << "<性別:1>" if character.sex == :male
      tags << "<初期サブクラス #{character.race}>" if character.race && character.race > 0
      history = {}
      history[character.job] = 3 if character.job && character.job > 0
      history[character.race] = 3 if character.race && character.race > 0
      (character.class_levels || {}).each { |id, lv| history[id] = lv }
      unless history.empty?
        pairs = history.sort.map { |id, lv| "#{id}-#{lv}" }
        tags << "<経験済職業 #{pairs.join(',')}>"
      end
      (character.equips || {}).sort.each do |slot, item_id|
        tags << "<初期装備#{slot}:#{item_id}>" if item_id && item_id > 0
      end
      bust_id = BUST_SKILL_MAP[character.bust_size.to_s] || 3277
      tags << "<スキル変化 3147-#{bust_id}>"
      tags << "<主人格>"
      artist = character.artist.to_s
      tags << "<イラスト:#{artist}>" unless artist.empty?
      tags.concat(REQUIRED_TAGS)
      tags
    end
  end

  module ActorBuilder
    FEATURE_SKILL_TYPE = 41
    KEPT_SKILL_TYPES = [39, 63].freeze
    REQUIRED_FEATURES = [
      [22, 1, 0.05], [22, 2, 0.05], [23, 0, 0.5],
      [52, 41, 0.0], [51, 32, 0.0]
    ].freeze

    def self.build(character, persona_id)
      return nil unless character
      return nil unless $data_actors && $data_actors[persona_id]
      luka = CharacterCreation::LukaSnapshot.actor_for(persona_id) || $data_actors[persona_id]
      actor = Marshal.load(Marshal.dump(luka))
      form = persona_id == 2 ? character.form2 : persona_id == 3 ? character.form3 : nil
      actor.name     = character.name.to_s.empty? ? "Luka" : character.name
      actor.nickname = character.nickname.to_s
      actor.class_id = character.job if character.job && character.job > 0
      actor.initial_level = 3
      apply_graphics(actor, character, persona_id)
      base_features = Array(actor.instance_variable_get(:@features))
      kept_features = base_features.select do |f|
        REQUIRED_FEATURES.include?([f.code, f.data_id, f.value])
      end
      custom_features = trait_features(character, form)
      kept_keys = kept_features.map { |f| [f.code, f.data_id, f.value] }
      custom_features = custom_features.reject do |f|
        kept_keys.include?([f.code, f.data_id, f.value])
      end
      all_features = kept_features + custom_features
      actor.instance_variable_set(:@features, all_features)
      actor.instance_variable_set(:@features_override, all_features)
      if character.sex == :male && defined?(NWSex::MALE)
        data_ex = actor.instance_variable_get(:@data_ex)
        data_ex[:sex] = NWSex::MALE if data_ex
      end
      luka_tags = luka.note.to_s.scan(/<[^>]*>/)
      override_prefixes = [
        "カテゴリー", "特殊カテゴリー", "性別", "初期サブクラス",
        "経験済職業", "初期装備", "スキル変化", "イラスト", "主人格",
        "スキルタイプ強化", "窮地スキルタイプ強化"
      ]
      base_tags = luka_tags.reject { |t| override_prefixes.any? { |p| t.include?(p) } }
      custom_tags = trait_tags(character, form).dup
      custom_tags.concat(CharacterCreation::StandardTags.tags_for(character))
      actor.note = (base_tags + custom_tags).uniq.join("\n")
      actor.note_analyze if actor.respond_to?(:note_analyze)
      actor.setting_feature_data if actor.respond_to?(:setting_feature_data)
      actor
    rescue => e
      CharacterCreation.log("ActorBuilder.build FAILED (persona #{persona_id}): #{e.class}: #{e.message}")
      nil
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
  end

  def self.first_face_cell(bitmap)
    return nil unless bitmap
    if bitmap.width > bitmap.height
      cell = Bitmap.new(FACE_SIZE, FACE_SIZE)
      cell.blt(0, 0, bitmap, Rect.new(0, 0, FACE_SIZE, FACE_SIZE))
      return cell
    end
    bitmap
  rescue => e
    CharacterCreation.log("first_face_cell FAILED: #{e.class}: #{e.message}")
    bitmap
  end

  def self.draw_face_fitted(target, dest_rect, source)
    return unless target && source
    cell = first_face_cell(source)
    return unless cell
    scale = [dest_rect.width.to_f / cell.width, dest_rect.height.to_f / cell.height].min
    w = (cell.width * scale).to_i
    h = (cell.height * scale).to_i
    x = dest_rect.x + (dest_rect.width - w) / 2
    y = dest_rect.y + (dest_rect.height - h) / 2
    target.stretch_blt(Rect.new(x, y, w, h), cell, Rect.new(0, 0, cell.width, cell.height))
    cell.dispose if cell != source && !cell.disposed?
  rescue => e
    CharacterCreation.log("draw_face_fitted FAILED: #{e.class}: #{e.message}")
  end

  # --- Engine Hooks ---

  module CacheHook
    PREFIX = "lr_cc_"

    def self.install
      return if Cache.singleton_class.method_defined?(:cc_original_load_bitmap)
      Cache.singleton_class.class_eval do
        alias_method :cc_original_load_bitmap, :load_bitmap
        def load_bitmap(folder_name, filename, *args)
          name = filename.to_s
          bare = name.sub(/\A\$/, "")
          if bare.start_with?(CharacterCreation::CacheHook::PREFIX)
            path = CharacterCreation::CacheHook.path_for(bare)
            if path && File.exist?(path)
              begin
                bmp = Bitmap.new(path)
                if bare =~ /_face\z/
                  bmp = CharacterCreation::CacheHook.normalize_face(bmp)
                end
                return bmp
              rescue => e
                CharacterCreation.log("CacheHook: load failed for #{path}: #{e.class}: #{e.message}")
              end
            else
              CharacterCreation.log("CacheHook: no file on disk for #{bare} (looked at #{path.inspect})")
            end
          end
          cc_original_load_bitmap(folder_name, filename, *args)
        end
      end
      CharacterCreation.log("Cache hook installed")
    end

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
        cell.stretch_blt(Rect.new(x, y, w, h), src, Rect.new(0, 0, src.width, src.height))
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

  module FaceHook
    def self.install
      return if Window_Base.method_defined?(:cc_original_draw_face_hue)
      Window_Base.class_eval do
        alias_method :cc_original_draw_face_hue, :draw_face_hue
        def draw_face_hue(face_name, face_index, *args)
          character = CharacterCreation.current_character
          if character && face_name.is_a?(String) && CharacterCreation::FaceHook.local_speaker?
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

  begin
    CacheHook.install
    DataManagerHook.install
    ExtractHook.install
    FaceHook.install
    EscapeRenameHook.install
    BitmapRenameHook.install
    LibrarySwap.install
    StatProbe.install
  rescue => e
    CharacterCreation.log("Hook install FAILED: #{e.class}: #{e.message}")
  end
end