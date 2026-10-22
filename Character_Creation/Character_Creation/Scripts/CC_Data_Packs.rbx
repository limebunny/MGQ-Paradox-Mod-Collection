#==============================================================================
# CC_Data_Packs.rbx
# Character Creation — hero pack storage and standard tags.
#
# Combines:
#   CC_01_Pack.rb        (hero pack read/write)
#   CC_02_BlobRegistry.rb (image bytes, StandardTags)
#
# Provides:
#   CharacterCreation::BlobRegistry     image bytes in memory and on disk
#   CharacterCreation::StandardTags     default actor-level tags
#   CharacterCreation::Pack             hero pack read/write (.luka)
#
# Also provides the two shared face-drawing helpers used by the UI:
#   CharacterCreation.first_face_cell
#   CharacterCreation.draw_face_fitted
#==============================================================================

module CharacterCreation
  #=== BlobRegistry ==========================================================
  # Holds image bytes in memory and on disk; serves them to Cache.
  module BlobRegistry
    @blobs = {}

    class << self
      def register(character, skip_disk = false)
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
        write_to_disk(character) unless skip_disk
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

  #=== StandardTags ==========================================================
  # Generates the standard actor-level tags a custom character's note carries:
  # the category / special category of the chosen race, sex, sub-class, class
  # history, starting gear, skill-change (bust size), main persona, artist, and
  # the required TP/EXP/unique-skill/human-feature defaults Luka has.
  #
  # Pure: reads only the Character struct and the RACE_CATEGORIES table. No
  # $data_actors, no live actor. Used by both ActorBuilder.build (to write the
  # live actor's note) and Pack.build_hero_text (to heal stale .luka files).
  module StandardTags
    RACE_CATEGORIES = {
      151  => ["人間",        11],
      158  => ["妖魔",        12],
      167  => ["亜人",        13],
      175  => ["淫魔",        14],
      184  => ["吸血鬼",      15],
      194  => ["人魚",        16],
      203  => ["エルフ",      17],
      214  => ["妖精",        18],
      223  => ["スライム",    19],
      232  => ["魔獣",        20],
      245  => ["妖狐",        21],
      254  => ["ラミア",      22],
      265  => ["スキュラ",    23],
      274  => ["鳥",          24],
      283  => ["竜",          25],
      293  => ["陸棲種",      26],
      301  => ["海棲種",      27],
      309  => ["虫",          28],
      319  => ["植物",        29],
      328  => ["ゾンビ",      30],
      336  => ["ゴースト",    31],
      344  => ["ドール",      32],
      354  => ["キメラ",      33],
      362  => ["天使",        34],
      7401 => ["ロイド",      38],
      7408 => ["その他",      37],
    }.freeze

    BUST_SKILL_MAP = {
      "Flat"   => 3277,
      "Small"  => 3278,
      "Medium" => 3279,
      "Large"  => 3280,
      "Huge"   => 3281,
    }.freeze

    REQUIRED_TAGS = [
      "<TP基本値 5>", "<TPLv補正 30>", "<TPLv100補正 30>", "<開始時TP 50%>",
      "<経験値曲線 386>", "<誘惑時使用スキル:3285>",
      "<人間時追加特徴 397>",
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

  #=== Pack ==================================================================
  # Reads and writes .luka hero packs (Luka Replacer format).
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

    # Reads pack cut-in images back into the cut-in tuple. Base-form cut-ins
    # and form cut-ins both store their bytes under cutin_<index>.png (form
    # cut-ins are prefixed by the caller with "form2_" / "form3_"), which is
    # the same slot name BlobRegistry.register and CacheHook.path_for use.
    # A cut-in whose blob is missing keeps its [:pack, ..., nil] and will not
    # play; BattleLines treats a nil :ct_pic as no cut-in for that entry.
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
      # Base-form cut-ins travel as cutin_<i>.png, matching the slot name
      # BlobRegistry and CacheHook already use (lr_cc_<key>_cutin_<i> ->
      # Cache/<key>/cutin_<i>.png). Without this entry the blob is dropped
      # on save and no cut-in plays after a reload.
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

      # --- Regenerate standard tags to self-heal stale .luka files ---
      standard = CharacterCreation::StandardTags.tags_for(c)

      # Strip any old standard tags from c.tags, keeping only trait tags
      remaining_trait_tags = (c.tags || []).reject do |t|
        CharacterCreation::StandardTags.owns?(t)
      end

      (standard + remaining_trait_tags).each { |t| lines << "tag=#{t}" }

      lines << expressions_line("expressions", c.expressions)
      (c.cutins || []).each { |cutin| lines << cutin_line("cutin", cutin) }
      (c.story_rules || []).each do |kind, from, to|
        lines << "story=#{kind}:#{from}:#{to}"
      end
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

  #=== Image helpers ========================================================
  # Extracts the first face cell (96x96) from a face sheet. A "sheet" is
  # any bitmap wider than it is tall (like Luka_Replacer's 384x192 face
  # sheets). Single-portrait faces (like mercenary's 400x480) are not
  # sheets and are returned as-is.
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

  # Draws a face into a bitmap, scaled to fit a target box. For a wide
  # face sheet, extracts the first 96x96 cell first.
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
end

CharacterCreation.log("CC_Data_Packs loaded")