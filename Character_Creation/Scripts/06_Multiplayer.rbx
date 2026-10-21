#==============================================================================
# 06_Multiplayer.rbx
# Character Creation — Multiplayer bridge, Pack Transfer, and Deferred Hooks.
#==============================================================================

module CharacterCreation
  module MpBridge
    @settled = false
    class << self; attr_accessor :settled; end

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
          CharacterCreation.log("MpBridge#skill_word FAILED for #{skill_id.inspect}: #{e.class}: #{e.message}")
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
      Rect.new(left, top, [right + step, sheet.width].min - left, [bottom + step, sheet.height].min - top)
    end
  end

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
    def self.log(message); CharacterCreation.log("#{LOG_TAG}: #{message}"); rescue; end
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
        :name => "seat #{seat}", :probed => false, :sent => {}, :tries => {}, :retry_at => {}, :received => {},
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
      record[:sent][key] = { :chunks => chunks, :total => total, :sha => sha, :at => 0, :bytes => bytes.bytesize }
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
          "ccpack" => key, "seq" => transfer[:at] + 1, "of" => transfer[:total], "sha" => transfer[:sha],
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
        :key => key, :total => total, :sha => sha, :chunks => {}, :at => @frame, :logged => false,
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
      self.alias_cache(character, buffer[:key])
      self.refresh_ghosts(buffer[:key])
      (@mp_received_characters ||= {})[buffer[:key]] = character
      CharacterCreation.instance_variable_set(:@mp_received_characters, @mp_received_characters)
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
      sprite_name = "$lr_cc_#{wire_key}_sprite"
      graphics = MGQ_MpOverworld.instance_variable_get(:@graphics)
      graphics.delete("character/#{sprite_name}") if graphics.is_a?(Hash)
      MGQ_MpOverworldSync::Peers.all.each do |peer|
        next unless peer.state["sprite"].to_s == sprite_name
        ghost = peer.ghost
        next unless ghost
        ghost.instance_variable_set(:@sent_name, nil)
        ghost.instance_variable_set(:@sent_index, nil)
        ghost.follow(peer.state, peer.member)
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

  def self.install_all_deferred_hooks
    LrCompat.try_install
    MpBridge.try_install
    PackTransfer.try_install
  rescue => e
    CharacterCreation.log("install_all_deferred_hooks FAILED: #{e.class}: #{e.message}")
  end

  module DataManagerHook
    class << self
      unless method_defined?(:cc_install_original_apply_pending_data)
        alias_method :cc_install_original_apply_pending_data, :apply_pending_data
        def apply_pending_data(*args)
          result = cc_install_original_apply_pending_data(*args)
          CharacterCreation.install_all_deferred_hooks
          result
        end
      end
      unless method_defined?(:cc_install_original_apply_pending_runtime)
        alias_method :cc_install_original_apply_pending_runtime, :apply_pending_runtime
        def apply_pending_runtime(*args)
          result = cc_install_original_apply_pending_runtime(*args)
          CharacterCreation.install_all_deferred_hooks
          result
        end
      end
    end
  end

  module ExtractHook
    class << self
      alias_method :cc_install_original_reinstall, :reinstall unless method_defined?(:cc_install_original_reinstall)
      def reinstall(*args)
        result = cc_install_original_reinstall(*args)
        CharacterCreation.install_all_deferred_hooks
        result
      end
    end
  end
end

CharacterCreation.log("06_Multiplayer loaded")