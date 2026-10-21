#==============================================================================
# 04_TitleAndDashboard.rbx
# Character Creation — Title Screen, Dashboard, Import/Cutin/Job/Race Pickers,
# Text Input, and related UI.
#==============================================================================

module CharacterCreation
  module WindowSwap
    def self.hide(window)
      return unless window && !window.disposed?
      window.deactivate
      window.hide
    end
    def self.show(window)
      return unless window && !window.disposed?
      window.show
      window.activate
    end
    def self.dispose(window)
      return unless window && !window.disposed?
      begin; window.dispose; rescue; end
    end
    def self.dispose_all(*windows)
      windows.flatten.each { |w| dispose(w) }
    end
  end

  module TitleScreen
    ENABLED = true
    MENU_WIDTH = 320
    def self.hero_files
      dir = CharacterCreation::HEROES_DIR
      return [] unless File.directory?(dir)
      Dir.glob(File.join(dir, "*.luka")).sort_by { |path| File.basename(path).downcase }
    rescue => e
      CharacterCreation.log("TitleScreen.hero_files FAILED: #{e.class}: #{e.message}")
      []
    end
    def self.label_for(path)
      File.basename(path, ".luka")
    end
  end

  class Window_NewGameMenu < Window_Command
    def window_width; CharacterCreation::TitleScreen::MENU_WIDTH; end
    def make_command_list
      add_command("Create New Character", :create, true, nil)
      add_command("Load Character",       :load,   true, nil)
      add_command("Delete Character",     :delete, true, nil)
      add_command("Start as Default",     :default, true, nil)
    end
  end

  class Window_ComingSoon < Window_Base
    def initialize(x, y, width = 300, text = "Coming soon!")
      @text = text
      super(x, y, width, fitting_height(2))
      refresh
    end
    def refresh
      contents.clear
      change_color(normal_color)
      draw_text(0, 0, contents_width, line_height, @text, 1)
      change_color(system_color)
      draw_text(0, line_height, contents_width, line_height, "Press OK to close.", 1)
    end
  end

  class Window_HeroBrowser < Window_Selectable
    COLUMNS      = 5
    TILE_WIDTH   = 112
    TILE_HEIGHT  = 128
    FACE_SIZE    = 96
    PADDING      = 8
    VISIBLE_ROWS = 3

    def initialize(x, y)
      @heroes = []
      @face_cache = {}
      super(x, y, window_width, window_height)
      refresh
    end
    def window_width; COLUMNS * item_width + standard_padding * 2; end
    def window_height; VISIBLE_ROWS * item_height + standard_padding * 2; end
    def item_width; TILE_WIDTH; end
    def item_height; TILE_HEIGHT; end
    def col_max; COLUMNS; end
    def item_max; @heroes ? @heroes.size : 0; end
    def spacing; 0; end

    def refresh_hero_list
      @heroes = CharacterCreation::TitleScreen.hero_files
      @index = [[@index || 0, 0].max, [@heroes.size - 1, 0].max].min
      refresh
    end
    def empty?; @heroes.nil? || @heroes.empty?; end
    def current_path
      return nil unless @index && @index >= 0 && @index < @heroes.size
      @heroes[@index]
    end
    def refresh
      contents.clear
      return if empty?
      (0...@heroes.size).each { |i| draw_item(i) }
      update_cursor
    end
    def draw_item(i)
      rect = item_rect(i)
      return if rect.y + rect.height < 0 || rect.y > contents.height
      draw_tile_background(rect, i == @index)
      draw_tile_face(rect, i)
      draw_tile_name(rect, i)
    end
    def draw_tile_background(rect, selected)
      return if selected
      overlay = Color.new(0, 0, 0, 96)
      contents.fill_rect(rect.x + 4, rect.y + 4, rect.width - 8, rect.height - 8, overlay)
    end
    def draw_tile_face(rect, i)
      face = face_bitmap_for(i)
      return unless face
      fx = rect.x + (rect.width - FACE_SIZE) / 2
      fy = rect.y + PADDING
      CharacterCreation.draw_face_fitted(contents, Rect.new(fx, fy, FACE_SIZE, FACE_SIZE), face)
    end
    def draw_tile_name(rect, i)
      name = CharacterCreation::TitleScreen.label_for(@heroes[i])
      ty = rect.y + PADDING + FACE_SIZE + 4
      change_color(normal_color, true)
      draw_text(rect.x + 4, ty, rect.width - 8, line_height, name, 1)
    end
    def face_bitmap_for(i)
      path = @heroes[i]
      return nil unless path
      key = File.basename(path, ".luka").downcase
      return @face_cache[key] if @face_cache.key?(key)
      character = CharacterCreation::Pack.read(path)
      unless character
        @face_cache[key] = nil
        return nil
      end
      face_path = File.join(CharacterCreation::CACHE_DIR, character.key.to_s, "face.png")
      CharacterCreation::BlobRegistry.register(character) unless File.exist?(face_path)
      @face_cache[key] = File.exist?(face_path) ? Bitmap.new(face_path) : nil
    rescue => e
      CharacterCreation.log("Window_HeroBrowser.face_bitmap_for FAILED: #{e.class}: #{e.message}")
      @face_cache[key] = nil
    end
    def dispose
      @face_cache.each_value { |bmp| bmp.dispose if bmp && !bmp.disposed? } if @face_cache
      super
    end
  end

  class Window_DeleteConfirm < Window_Command
    attr_accessor :file_label
    def window_width; 280; end
    def window_height; fitting_height(3); end
    def make_command_list
      add_command("Delete", :yes, true, nil)
      add_command("Cancel", :no,  true, nil)
    end
    def header_text
      label = @file_label.to_s
      label.empty? ? "Delete this file?" : "Delete #{label}?"
    end
    def item_rect(index)
      rect = super
      rect.y += line_height
      rect
    end
    def refresh
      super
      change_color(system_color)
      draw_text(0, 0, contents_width, line_height, header_text, 1)
    end
  end

  module TitleHook
    def self.install
      return if Scene_Title.method_defined?(:cc_original_command_new_game)
      Scene_Title.class_eval do
        alias_method :cc_original_command_new_game, :command_new_game
        alias_method :cc_original_start, :start
        alias_method :cc_original_update, :update
        alias_method :cc_original_terminate, :terminate

        def start
          CharacterCreation.current_character = nil
          CharacterCreation.pending = nil
          cc_original_start
        end
        def command_new_game(*args)
          return cc_original_command_new_game(*args) if @cc_proceeding
          return cc_original_command_new_game(*args) unless CharacterCreation::TitleScreen::ENABLED
          cc_open_new_game_menu(args)
        end
        def cc_open_new_game_menu(args)
          @cc_new_game_args = args
          @cc_menu = CharacterCreation::Window_NewGameMenu.new(0, 0)
          @cc_menu.x = (Graphics.width  - @cc_menu.width)  / 2
          @cc_menu.y = (Graphics.height - @cc_menu.height) / 2
          @cc_menu.set_handler(:create,  method(:cc_on_menu_create))
          @cc_menu.set_handler(:load,    method(:cc_on_menu_load))
          @cc_menu.set_handler(:delete,  method(:cc_on_menu_delete))
          @cc_menu.set_handler(:default, method(:cc_on_menu_default))
          @cc_menu.set_handler(:cancel,  method(:cc_on_menu_cancel))
          @cc_menu.activate
          @command_window.deactivate if @command_window
        end
        def cc_hide_new_game_menu
          return unless @cc_menu && !@cc_menu.disposed?
          @cc_menu.deactivate
          @cc_menu.hide
        end
        def cc_show_new_game_menu
          return unless @cc_menu && !@cc_menu.disposed?
          @cc_menu.show
          @cc_menu.activate
        end
        def cc_on_menu_create
          CharacterCreation.log("New Game menu: Create New Character")
          CharacterCreation.draft = nil
          SceneManager.call(CharacterCreation::Scene_CharDashboard)
        end
        def cc_on_menu_load
          CharacterCreation.log("New Game menu: Load Character")
          heroes = CharacterCreation::TitleScreen.hero_files
          if heroes.empty?
            cc_show_coming_soon(method(:cc_on_coming_soon_closed), "No characters to load.")
            return
          end
          cc_open_hero_browser(method(:cc_on_load_chosen))
        end
        def cc_on_load_chosen(path)
          character = CharacterCreation::Pack.read(path)
          unless character
            CharacterCreation.log("Load: could not read #{path}")
            return
          end
          CharacterCreation.pending = character
          CharacterCreation.log("Load Character: chose #{character.name} (#{character.key})")
          cc_close_hero_browser
          cc_proceed_with_new_game
        end
        def cc_on_menu_delete
          heroes = CharacterCreation::TitleScreen.hero_files
          if heroes.empty?
            cc_show_coming_soon(method(:cc_on_coming_soon_closed), "No characters to delete.")
            return
          end
          cc_open_hero_browser(method(:cc_open_delete_confirm))
        end
        def cc_on_menu_default
          CharacterCreation.pending = nil
          cc_hide_new_game_menu
          cc_proceed_with_new_game
        end
        def cc_on_menu_cancel
          CharacterCreation.pending = nil
          cc_hide_new_game_menu
          cc_reopen_title_menu
        end
        def cc_show_coming_soon(on_close, text = "Coming soon!")
          cc_hide_new_game_menu
          @cc_coming_soon = CharacterCreation::Window_ComingSoon.new(
            (Graphics.width  - 300) / 2, (Graphics.height - 96)  / 2, 300, text
          )
          @cc_coming_soon.z = 200
          @cc_coming_soon.activate
          @cc_coming_soon_handler = on_close
        end
        def cc_update_coming_soon
          return unless @cc_coming_soon && !@cc_coming_soon.disposed?
          return unless Input.trigger?(:C) || Input.trigger?(:B)
          @cc_coming_soon.deactivate
          @cc_coming_soon.dispose
          @cc_coming_soon = nil
          handler = @cc_coming_soon_handler
          @cc_coming_soon_handler = nil
          handler.call if handler
        end
        def cc_on_coming_soon_closed
          cc_show_new_game_menu
        end
        def cc_reopen_title_menu
          @command_window.activate if @command_window && !@command_window.disposed?
        end
        def cc_proceed_with_new_game
          args = @cc_new_game_args || []
          @cc_proceeding = true
          begin
            cc_original_command_new_game(*args)
          ensure
            @cc_proceeding = false
          end
        end
        def update
          cc_update_coming_soon
          cc_original_update
        end
        def cc_open_hero_browser(on_ok)
          CharacterCreation::WindowSwap.hide(@cc_menu)
          @cc_browser = CharacterCreation::Window_HeroBrowser.new(0, 0)
          @cc_browser.x = (Graphics.width  - @cc_browser.width)  / 2
          @cc_browser.y = (Graphics.height - @cc_browser.height) / 2
          @cc_browser.set_handler(:ok,     method(:cc_on_browser_ok))
          @cc_browser.set_handler(:cancel, method(:cc_on_browser_cancel))
          @cc_browser.refresh_hero_list
          @cc_browser.activate
          @cc_browser_on_ok = on_ok
        end
        def cc_on_browser_ok
          path = @cc_browser.current_path
          handler = @cc_browser_on_ok
          handler.call(path) if handler
        end
        def cc_on_browser_cancel
          cc_close_hero_browser
          cc_show_new_game_menu
        end
        def cc_close_hero_browser
          CharacterCreation::WindowSwap.hide(@cc_browser)
        end
        def cc_open_delete_confirm(path)
          hero = CharacterCreation::Pack.read(path)
          unless hero
            CharacterCreation.log("Delete: could not read #{path}")
            return
          end
          @cc_delete_path = path
          @cc_delete_label = File.basename(path, ".luka")
          CharacterCreation::WindowSwap.hide(@cc_browser)
          unless @cc_delete_confirm && !@cc_delete_confirm.disposed?
            @cc_delete_confirm = CharacterCreation::Window_DeleteConfirm.new(0, 0)
            @cc_delete_confirm.x = (Graphics.width  - @cc_delete_confirm.width)  / 2
            @cc_delete_confirm.y = (Graphics.height - @cc_delete_confirm.height) / 2
            @cc_delete_confirm.set_handler(:yes, method(:cc_on_delete_yes))
            @cc_delete_confirm.set_handler(:no,  method(:cc_on_delete_no))
            @cc_delete_confirm.set_handler(:cancel, method(:cc_on_delete_no))
          end
          @cc_delete_confirm.file_label = @cc_delete_label
          @cc_delete_confirm.refresh
          @cc_delete_confirm.select(0)
          @cc_delete_confirm.show
          @cc_delete_confirm.activate
        end
        def cc_on_delete_yes
          path = @cc_delete_path
          if path && File.exist?(path)
            begin
              File.delete(path)
              CharacterCreation.log("Deleted hero file: #{path}")
            rescue => e
              CharacterCreation.log("Delete FAILED for #{path}: #{e.class}: #{e.message}")
            end
          end
          cc_close_delete_confirm
          cc_refresh_hero_browser
        end
        def cc_on_delete_no
          cc_close_delete_confirm
          CharacterCreation::WindowSwap.show(@cc_browser)
        end
        def cc_close_delete_confirm
          CharacterCreation::WindowSwap.hide(@cc_delete_confirm)
          @cc_delete_path = nil
          @cc_delete_label = nil
        end
        def cc_refresh_hero_browser
          return unless @cc_browser && !@cc_browser.disposed?
          @cc_browser.refresh_hero_list
          if @cc_browser.empty?
            cc_close_hero_browser
            cc_show_new_game_menu
          else
            CharacterCreation::WindowSwap.show(@cc_browser)
          end
        end
        def terminate
          CharacterCreation::WindowSwap.dispose_all(
            @cc_menu, @cc_coming_soon, @cc_browser, @cc_delete_confirm
          )
          @cc_menu = nil
          @cc_coming_soon = nil
          @cc_browser = nil
          @cc_delete_confirm = nil
          cc_original_terminate
        end
      end
    end
  end

  class Window_DashboardFields < Window_Command
    FIELDS = [
      [:import, "Import", :edit], [:name, "Name", :edit], [:artist, "Artist", :edit],
      [:sex, "Sex", :toggle], [:bust, "Bust Size", :toggle], [:job, "Job", :edit],
      [:race, "Race", :edit], [:cutin, "Cut-in", :label], [:trait, "Trait", :action],
      [:save, "Save", :action], [:cancel, "Cancel", :action],
    ]
    def window_width; 240; end
    def make_command_list
      FIELDS.each do |key, label, kind|
        enabled = field_enabled?(key)
        text = if kind == :action
                label
              else
                "#{label}: #{value_for(key)}"
              end
        text = "#{text}  #{save_hint}" if key == :save && !enabled
        add_command(text, key, enabled, key)
      end
    end
    def field_enabled?(key)
      return false if key == :cutin && !has_cutin_image?
      return true unless key == :save
      c = CharacterCreation.draft
      return false unless c
      !c.name.to_s.strip.empty? && c.face_blob && !c.face_blob.empty? && c.sprite_blob && !c.sprite_blob.empty?
    end
    def has_cutin_image?
      c = CharacterCreation.draft
      return false unless c && c.import_key
      File.exist?(File.join(CharacterCreation::IMPORTS_DIR, c.import_key.to_s, "cutin.png"))
    end
    def save_hint
      c = CharacterCreation.draft
      return "(need name and import)" unless c
      name_ok   = !c.name.to_s.strip.empty?
      import_ok = c.face_blob && !c.face_blob.empty? && c.sprite_blob && !c.sprite_blob.empty?
      if !name_ok && !import_ok then "(need name and import)"
      elsif !name_ok             then "(need name)"
      elsif !import_ok           then "(need import)"
      else ""
      end
    end
    def value_for(key)
      c = CharacterCreation.draft
      return "" unless c
      case key
      when :import then import_label(c)
      when :name   then c.name.to_s
      when :artist then c.artist.to_s.empty? ? "(none)" : c.artist.to_s
      when :sex    then c.sex == :female ? "Female" : "Male"
      when :bust   then c.bust_size.to_s
      when :job    then class_name(c.job)
      when :race   then class_name(c.race)
      when :cutin  then cutin_label(c)
      when :trait  then c.trait_name.to_s
      else ""
      end
    end
    def import_label(c); c.import_key ? c.import_key.to_s : "(none)"; end
    def class_name(id)
      return "?" unless id && id > 0
      data = $data_classes && $data_classes[id]
      data ? data.name.to_s : "?"
    end
    def cutin_label(c)
      return "(none)" unless c && has_cutin_image_for?(c)
      return "(unused)" if c.cutins.nil? || c.cutins.empty?
      skills = c.cutins.first[0]
      return "(unused)" if skills.nil? || skills.empty?
      skill = $data_skills && $data_skills[skills.first]
      if skill && TraitData::SKILL_TYPES.assoc(skill.stype_id)
        TraitData::SKILL_TYPES.assoc(skill.stype_id)[1]
      else
        "Custom"
      end
    end
    def has_cutin_image_for?(c)
      return false unless c && c.import_key
      File.exist?(File.join(CharacterCreation::IMPORTS_DIR, c.import_key.to_s, "cutin.png"))
    end
    def refresh_values; refresh; end
    def redraw_field_labels; refresh; end
    def process_ok
      if current_item_enabled?
        Input.update
        call_ok_handler
      else
        Sound.play_buzzer if current_ext == :cutin && Sound.respond_to?(:play_buzzer)
      end
    end
    def call_ok_handler
      call_handler(:ok)
      activate
    end
  end

  class Window_DashboardPreview < Window_Base
    BOX_SIZE = 96
    BOX_GAP = 4
    LABEL_GAP = 2
    def initialize(x, y, width, height)
      @face_bmp, @sprite_bmp, @cutin_bmp = nil, nil, nil
      super
      refresh
    end
    def refresh
      contents.clear
      c = CharacterCreation.draft
      return unless c
      draw_face_and_sprite
      draw_name_and_details(c)
    rescue => e
      CharacterCreation.log("Window_DashboardPreview.refresh FAILED: #{e.class}: #{e.message}")
    end
    def draw_face_and_sprite
      face_bmp, sprite_bmp, cutin_bmp = load_cached_image(:face), load_cached_image(:sprite), load_cached_image(:cutin)
      if face_bmp
        CharacterCreation.draw_face_fitted(contents, Rect.new(0, 0, BOX_SIZE, BOX_SIZE), face_bmp)
      else
        draw_preview_placeholder(0, "(no face)")
      end
      draw_box_label(0, "Face")
      sx = BOX_SIZE + BOX_GAP
      if sprite_bmp
        cell_w, cell_h = sprite_bmp.width / 3, sprite_bmp.height / 4
        scale = [BOX_SIZE.to_f / cell_w, BOX_SIZE.to_f / cell_h].min
        w, h = (cell_w * scale).to_i, (cell_h * scale).to_i
        x, y = sx + (BOX_SIZE - w) / 2, (BOX_SIZE - h) / 2
        contents.stretch_blt(Rect.new(x, y, w, h), sprite_bmp, Rect.new(0, 0, cell_w, cell_h))
      else
        draw_preview_placeholder(sx, "(no sprite)")
      end
      draw_box_label(sx, "Sprite")
      cx = BOX_SIZE + BOX_GAP + BOX_SIZE + BOX_GAP
      if cutin_bmp
        scale = [BOX_SIZE.to_f / cutin_bmp.width, BOX_SIZE.to_f / cutin_bmp.height].min
        w, h = (cutin_bmp.width * scale).to_i, (cutin_bmp.height * scale).to_i
        x, y = cx + (BOX_SIZE - w) / 2, (BOX_SIZE - h) / 2
        contents.stretch_blt(Rect.new(x, y, w, h), cutin_bmp, Rect.new(0, 0, cutin_bmp.width, cutin_bmp.height))
      else
        draw_preview_placeholder(cx, "(no cut-in)")
      end
      draw_box_label(cx, "Cut-in")
    end
    def draw_box_label(x, text)
      change_color(system_color)
      draw_text(x, BOX_SIZE + LABEL_GAP, BOX_SIZE, line_height, text, 1)
    end
    def draw_preview_placeholder(x, text)
      contents.fill_rect(x, 0, BOX_SIZE, BOX_SIZE, Color.new(40, 40, 40))
      change_color(system_color)
      draw_text(x, BOX_SIZE / 2 - line_height / 2, BOX_SIZE, line_height, text, 1)
    end
    def draw_name_and_details(c)
      y = BOX_SIZE + line_height + 12
      change_color(normal_color)
      draw_text(0, y, contents_width, line_height, c.name.to_s)
      y += line_height
      if c.artist && !c.artist.empty?
        change_color(tp_gauge_color2)
        draw_text(0, y, contents_width, line_height, "Art: #{c.artist}")
        y += line_height
      end
      change_color(crisis_color)
      trait_label = c.trait_name.to_s.empty? ? "Hero's Blood" : c.trait_name.to_s
      draw_text(0, y, contents_width, line_height, trait_label)
      y += line_height
      job, race = class_name(c.job), class_name(c.race)
      change_color(system_color)
      draw_text(0, y, contents_width, line_height, "#{job} / #{race}")
    end
    def class_name(id)
      return "?" unless id && id > 0
      data = $data_classes && $data_classes[id]
      data ? data.name.to_s : "?"
    end
    def load_cached_image(slot)
      c = CharacterCreation.draft
      return nil unless c
      path = nil
      if slot == :cutin
        blob = c.cutins && c.cutins[0] ? c.cutins[0][2][2] : nil
        if blob && !blob.empty?
          path = File.join(CharacterCreation::CACHE_DIR, c.key.to_s, "cutin_0.png")
        elsif c.import_key
          import_path = File.join(CharacterCreation::IMPORTS_DIR, c.import_key.to_s, "cutin.png")
          path = import_path if File.exist?(import_path)
        end
      else
        filename = (slot == :face ? "face.png" : "sprite.png")
        path = File.join(CharacterCreation::CACHE_DIR, c.key.to_s, filename)
      end
      return nil unless path && File.exist?(path)
      bmp_var = (slot == :face ? :@face_bmp : slot == :sprite ? :@sprite_bmp : :@cutin_bmp)
      old = instance_variable_get(bmp_var)
      old.dispose if old && !old.disposed?
      instance_variable_set(bmp_var, Bitmap.new(path))
      instance_variable_get(bmp_var)
    rescue => e
      CharacterCreation.log("Window_DashboardPreview.load_cached_image(#{slot}) FAILED: #{e.class}: #{e.message}")
      nil
    end
    def dispose_cached_bitmaps
      [@face_bmp, @sprite_bmp, @cutin_bmp].each { |b| b.dispose if b && !b.disposed? }
      @face_bmp, @sprite_bmp, @cutin_bmp = nil, nil, nil
    end
    def dispose
      [@face_bmp, @sprite_bmp, @cutin_bmp].each { |b| b.dispose if b && !b.disposed? }
      super
    end
  end

  class Scene_CharDashboard < Scene_MenuBase
    PANEL_TOP, PANEL_GAP, FIELDS_WIDTH, PREVIEW_W = 40, 40, 220, 320
    @draft_serial = 0
    class << self; attr_accessor :draft_serial; end
    def start
      super
      unless CharacterCreation.draft
        Scene_CharDashboard.draft_serial += 1
        key = "draft_#{Time.now.to_i}_#{Scene_CharDashboard.draft_serial}".to_sym
        CharacterCreation.draft = CharacterCreation.new_character(key)
        CharacterCreation.draft.nickname = CharacterCreation.draft.trait_name.to_s
        CharacterCreation.draft.trait_feature_keys = CharacterCreation::TraitFeatures::HERO_BLOOD_KEYS.dup
      end
      total_w = FIELDS_WIDTH + PANEL_GAP + PREVIEW_W
      left_x  = (Graphics.width - total_w) / 2
      @fields = Window_DashboardFields.new(left_x, PANEL_TOP)
      @fields.set_handler(:ok, method(:on_field_ok))
      @fields.activate
      px = left_x + FIELDS_WIDTH + PANEL_GAP
      @preview = Window_DashboardPreview.new(px, PANEL_TOP, PREVIEW_W, @fields.height)
    end
    def return
      super
      CharacterCreation.pending_refresh = true
      refresh_all
    end
    def update
      if CharacterCreation.pending_refresh
        CharacterCreation.pending_refresh = false
        refresh_all
      end
      if CharacterCreation.pending_discard
        CharacterCreation.pending_discard = false
        clean_cache_for(CharacterCreation.draft.key) if CharacterCreation.draft
        CharacterCreation.draft = nil
        SceneManager.return
        return
      end
      if CharacterCreation.pending_close
        CharacterCreation.pending_close = false
        clean_cache_for(CharacterCreation.draft.key) if CharacterCreation.draft
        CharacterCreation.draft = nil
        SceneManager.return
        return
      end
      super
    end
    def on_field_ok
      case @fields.current_ext
      when :import then on_edit_import
      when :name   then on_edit_name
      when :artist then on_edit_artist
      when :sex    then on_toggle_sex
      when :bust   then on_toggle_bust
      when :job    then on_edit_job
      when :race   then on_edit_race
      when :cutin  then on_edit_cutin
      when :trait  then on_edit_trait
      when :save   then on_save
      when :cancel then on_cancel
      end
    end
    def on_edit_import
      Sound.play_ok if Sound.respond_to?(:play_ok)
      SceneManager.call(CharacterCreation::Scene_ImportPicker)
    end
    def on_edit_name
      Sound.play_ok if Sound.respond_to?(:play_ok)
      CharacterCreation.text_input_target = :name
      SceneManager.call(CharacterCreation::Scene_TextInput)
    end
    def on_edit_artist
      Sound.play_ok if Sound.respond_to?(:play_ok)
      CharacterCreation.text_input_target = :artist
      SceneManager.call(CharacterCreation::Scene_TextInput)
    end
    def on_toggle_sex
      c = CharacterCreation.draft
      return unless c
      c.sex = (c.sex == :female ? :male : :female)
      Sound.play_cursor if Sound.respond_to?(:play_cursor)
      refresh_all
    end
    def on_toggle_bust
      c = CharacterCreation.draft
      return unless c
      sizes = ["Flat", "Small", "Medium", "Large", "Huge"]
      idx = sizes.index(c.bust_size) || 0
      c.bust_size = sizes[(idx + 1) % sizes.size]
      Sound.play_cursor if Sound.respond_to?(:play_cursor)
      refresh_all
    end
    def on_edit_job
      Sound.play_ok if Sound.respond_to?(:play_ok)
      CharacterCreation::Scene_JobRacePicker.target = :job
      SceneManager.call(CharacterCreation::Scene_JobRacePicker)
    end
    def on_edit_race
      Sound.play_ok if Sound.respond_to?(:play_ok)
      CharacterCreation::Scene_JobRacePicker.target = :race
      SceneManager.call(CharacterCreation::Scene_JobRacePicker)
    end
    def on_edit_cutin
      Sound.play_ok if Sound.respond_to?(:play_ok)
      SceneManager.call(CharacterCreation::Scene_CutinPicker)
    end
    def on_edit_trait
      Sound.play_ok if Sound.respond_to?(:play_ok)
      SceneManager.call(CharacterCreation::Scene_TraitDashboard)
    end
    def on_save
      unless @fields.field_enabled?(:save)
        Sound.play_buzzer if Sound.respond_to?(:play_buzzer)
        return
      end
      c = CharacterCreation.draft
      old_key = c.key.to_sym
      key = c.name.to_s.downcase.gsub(/[^a-z0-9_]/, "_")
      key = "hero_#{Time.now.to_i}" if key.empty?
      c.key = key.to_sym
      path = File.join(CharacterCreation::HEROES_DIR, "#{key}.luka")
      if CharacterCreation::Pack.write(path, c)
        Sound.play_ok if Sound.respond_to?(:play_ok)
        clean_cache_for(old_key)
        SceneManager.call(CharacterCreation::Scene_SaveSuccess)
      else
        Sound.play_buzzer if Sound.respond_to?(:play_buzzer)
      end
    end
    def on_cancel
      Sound.play_cancel
      SceneManager.call(CharacterCreation::Scene_DiscardConfirm)
    end
    def clean_cache_for(key)
      return unless key
      dir = File.join(CharacterCreation::CACHE_DIR, key.to_s)
      return unless File.directory?(dir)
      begin
        @preview.dispose_cached_bitmaps if @preview
        Dir.glob(File.join(dir, "*")).each { |f| File.delete(f) }
        Dir.rmdir(dir)
      rescue; end
    end
    def refresh_all
      @fields.redraw_field_labels
      @preview.refresh
    end
  end

  class Window_ImportList < Window_Command
    def initialize(x, y, folders)
      @folders = folders
      super(x, y)
    end
    def window_width; 320; end
    def make_command_list
      @folders.each { |path| add_command(File.basename(path), :import, true, path) }
    end
  end

  class Scene_ImportPicker < Scene_MenuBase
    def start
      super
      folders = import_folders
      if folders.empty?
        CharacterCreation.log("Import picker: no valid folders found")
        SceneManager.return
        return
      end
      @list = Window_ImportList.new(0, 0, folders)
      @list.x, @list.y = (Graphics.width - @list.width) / 2, (Graphics.height - @list.height) / 2
      @list.set_handler(:import, method(:on_ok))
      @list.set_handler(:cancel, method(:on_cancel))
      @list.activate
    end
    def import_folders
      dir = CharacterCreation::IMPORTS_DIR
      return [] unless File.directory?(dir)
      Dir.glob(File.join(dir, "*")).select { |p| File.directory?(p) && valid_import?(p) }.sort
    end
    def valid_import?(path)
      File.exist?(File.join(path, "face.png")) && File.exist?(File.join(path, "sprite.png"))
    end
    def on_ok
      path = @list.current_ext
      return unless path
      begin
        apply_import(path)
        Sound.play_ok if Sound.respond_to?(:play_ok)
        CharacterCreation.pending_refresh = true
        SceneManager.return
      rescue => e
        CharacterCreation.log("Import picker: apply_import FAILED: #{e.class}: #{e.message}")
      end
    end
    def on_cancel; SceneManager.return; end
    def apply_import(path)
      pack = CharacterCreation::Pack.read_folder_partial(path)
      return unless pack
      c = CharacterCreation.draft
      return unless c
      c.import_key = File.basename(path).downcase.to_sym
      c.face_blob, c.sprite_blob, c.picture_blob = pack.face_blob, pack.sprite_blob, pack.picture_blob
      c.form2, c.form3 = pack.form2, pack.form3
      c.cutins = pack.cutins || []
      if File.exist?(File.join(path, "cutin.png")) && c.cutins.empty?
        c.cutins << [[], :basic, [:pack, "cutin", File.binread(File.join(path, "cutin.png"))], "wind10"]
      end
      c.expressions = pack.expressions
      if pack.trait_name || !pack.features.empty?
        c.name, c.nickname = pack.name, pack.nickname if pack.name
        c.sex, c.job, c.race = pack.sex, pack.job, pack.race if pack.sex
        c.trait_key, c.trait_name, c.trait_lines = :custom, pack.trait_name, pack.trait_lines
        c.features, c.tags = pack.features, pack.tags
        c.artist = pack.artist if pack.artist
        c.class_levels = pack.class_levels if pack.class_levels
        c.equips = pack.equips if pack.equips
      end
      CharacterCreation::BlobRegistry.register(c)
    rescue => e
      CharacterCreation.log("Import: apply_import CRASHED: #{e.class}: #{e.message}")
    end
    def terminate
      @list.dispose if @list && !@list.disposed?
      super
    end
  end

  class Window_SkillTypePicker < Window_Command
    def initialize(x, y); super(x, y); end
    def window_width; 360; end
    def window_height; fitting_height(12); end
    def visible_line_number; 12; end
    def make_command_list
      add_command("None", :pick, true, 0)
      TraitData::SKILL_TYPES.each { |stype_id, label| add_command(label, :pick, true, stype_id) }
    end
  end

  class Scene_CutinPicker < Scene_MenuBase
    def start
      super
      @list = Window_SkillTypePicker.new(0, 0)
      @list.x, @list.y = (Graphics.width - @list.width) / 2, (Graphics.height - @list.height) / 2
      @list.set_handler(:pick,   method(:on_pick))
      @list.set_handler(:cancel, method(:on_cancel))
      @list.activate
    end
    def on_pick
      stype_id = @list.current_ext
      c = CharacterCreation.draft
      if c
        if stype_id == 0
          c.cutins = []
        elsif stype_id
          skill_ids = (1...$data_skills.size).select { |i| $data_skills[i] && $data_skills[i].stype_id == stype_id }
          blob = cutin_blob_for(c)
          c.cutins = []
          c.cutins << [skill_ids, :basic, [:pack, "cutin", blob], "wind10"]
          CharacterCreation::BlobRegistry.register(c) if blob
        end
        Sound.play_ok if Sound.respond_to?(:play_ok)
      end
      SceneManager.return
    end
    def cutin_blob_for(c)
      return nil unless c && c.import_key
      path = File.join(CharacterCreation::IMPORTS_DIR, c.import_key.to_s, "cutin.png")
      File.exist?(path) ? File.binread(path) : nil
    rescue => e
      CharacterCreation.log("Scene_CutinPicker.cutin_blob_for FAILED: #{e.class}: #{e.message}")
      nil
    end
    def on_cancel
      Sound.play_cancel if Sound.respond_to?(:play_cancel)
      SceneManager.return
    end
    def terminate
      @list.dispose if @list && !@list.disposed?
      super
    end
  end

  class Window_DiscardConfirm < Window_Command
    def window_width; 320; end
    def make_command_list
      add_command("Discard and return", :discard, true, nil)
      add_command("Keep editing",       :keep,    true, nil)
    end
  end

  class Scene_DiscardConfirm < Scene_MenuBase
    def start
      super
      @confirm = Window_DiscardConfirm.new(0, 0)
      @confirm.x, @confirm.y = (Graphics.width - @confirm.width) / 2, (Graphics.height - @confirm.height) / 2
      @confirm.set_handler(:discard, method(:on_discard))
      @confirm.set_handler(:keep,    method(:on_keep))
      @confirm.set_handler(:cancel,  method(:on_keep))
      @confirm.select(1)
      @confirm.activate
    end
    def on_discard
      Sound.play_ok if Sound.respond_to?(:play_ok)
      CharacterCreation.pending_discard = true
      SceneManager.return
    end
    def on_keep
      Sound.play_cancel if Sound.respond_to?(:play_cancel)
      SceneManager.return
    end
    def terminate
      @confirm.dispose if @confirm && !@confirm.disposed?
      super
    end
  end

  class Window_SaveSuccess < Window_Base
    def initialize
      super(0, 0, 320, fitting_height(2))
      self.x, self.y = (Graphics.width - width) / 2, (Graphics.height - height) / 2
      refresh
    end
    def refresh
      contents.clear
      change_color(normal_color)
      draw_text(0, 0, contents_width, line_height, "Character Created", 1)
      change_color(system_color)
      draw_text(0, line_height, contents_width, line_height, "Press OK to close", 1)
    end
  end

  class Scene_SaveSuccess < Scene_MenuBase
    def start
      super
      @window = Window_SaveSuccess.new
      @window.activate
    end
    def update
      super
      if Input.trigger?(:C) || Input.trigger?(:B)
        Sound.play_ok if Sound.respond_to?(:play_ok)
        close
      end
    end
    def close
      CharacterCreation.pending_close = true
      SceneManager.return
    end
    def terminate
      @window.dispose if @window && !@window.disposed?
      super
    end
  end

  class Window_JobRaceList < Window_Command
    WINDOW_WIDTH = 360
    VISIBLE_ROWS = 12
    def initialize(x, y, entries)
      @entries = entries || []
      super(x, y)
    end
    def window_width; WINDOW_WIDTH; end
    def window_height; fitting_height(VISIBLE_ROWS); end
    def make_command_list
      @entries.each { |id, name| add_command(name, :pick, true, id) }
    end
    def current_id; current_ext; end
  end

  class Scene_JobRacePicker < Scene_MenuBase
    class << self; attr_accessor :target; end
    def start
      super
      @target = Scene_JobRacePicker.target
      Scene_JobRacePicker.target = nil
      unless @target == :job || @target == :race
        SceneManager.return
        return
      end
      entries = list_for(@target)
      if entries.empty?
        SceneManager.return
        return
      end
      @list = Window_JobRaceList.new(0, 0, entries)
      @list.x, @list.y = (Graphics.width - @list.width) / 2, (Graphics.height - @list.height) / 2
      @list.set_handler(:ok,     method(:on_ok))
      @list.set_handler(:cancel, method(:on_cancel))
      @list.select(index_of_current(entries))
      @list.activate
    end
    def list_for(target)
      target == :job ? CharacterCreation::BasicClass.jobs : CharacterCreation::BasicClass.races
    rescue
      []
    end
    def index_of_current(entries)
      c = CharacterCreation.draft
      return 0 unless c
      current = @target == :job ? c.job : c.race
      found = entries.index { |id, _| id == current }
      found || 0
    end
    def on_ok
      id = @list.current_id
      c = CharacterCreation.draft
      if c && id
        if @target == :job
          c.job = id
        else
          c.race = id
        end
      end
      Sound.play_ok if Sound.respond_to?(:play_ok)
      SceneManager.return
    end
    def on_cancel
      Sound.play_cancel if Sound.respond_to?(:play_cancel)
      SceneManager.return
    end
    def terminate
      @list.dispose if @list && !@list.disposed?
      super
    end
  end

  class Window_TextInputGrid < Window_Base
    PLATE = [
      'ABCDEabcde', 'FGHIJfghij', 'KLMNOklmno', 'PQRSTpqrst',
      'UVWXYuvwxy', 'Z[]^\'z{}|~', '01234!#$%&', '56789()*+-', '/=@<>:;. _',
    ].freeze
    ROWS, COLS = PLATE.size, PLATE[0].size
    ACTIONS = [:cancel, :ok].freeze
    LINE_HEIGHT, PADDING, NAME_HEIGHT = 24, 12, 72
    def initialize(x, y, width, on_enter, on_backspace, on_confirm, on_cancel, buffer_getter, face_getter)
      @cursor_row, @cursor_col = 0, 0
      @in_action_row, @action_index = false, 1
      @on_enter, @on_backspace, @on_confirm, @on_cancel = on_enter, on_backspace, on_confirm, on_cancel
      @buffer_getter, @face_getter = buffer_getter, face_getter
      total_h = PADDING * 2 + NAME_HEIGHT + LINE_HEIGHT + (ROWS + 1) * LINE_HEIGHT
      super(x, y, width, total_h)
      refresh
    end
    def line_height; LINE_HEIGHT; end
    def standard_padding; PADDING; end
    def update
      super
      return unless active
      process_cursor
      process_input
    end
    def process_cursor
      moved = false
      if @in_action_row
        if Input.repeat?(:LEFT) && @action_index > 0
          @action_index -= 1; moved = true
        elsif Input.repeat?(:RIGHT) && @action_index < ACTIONS.size - 1
          @action_index += 1; moved = true
        elsif Input.repeat?(:UP)
          @in_action_row, @cursor_row, @cursor_col = false, ROWS - 1, [@cursor_col, COLS - 1].min; moved = true
        elsif Input.repeat?(:DOWN)
          @in_action_row, @cursor_row, @cursor_col = false, 0, @action_index == 0 ? 4 : 9; moved = true
        end
      else
        if Input.repeat?(:LEFT)
          @cursor_col = (@cursor_col - 1) % COLS; moved = true
        elsif Input.repeat?(:RIGHT)
          @cursor_col = (@cursor_col + 1) % COLS; moved = true
        elsif Input.repeat?(:UP)
          if @cursor_row > 0
            @cursor_row -= 1; moved = true
          else
            @in_action_row, @action_index = true, 1; moved = true
          end
        elsif Input.repeat?(:DOWN)
          if @cursor_row < ROWS - 1
            @cursor_row += 1; moved = true
          else
            @in_action_row, @action_index = true, 1; moved = true
          end
        end
      end
      if moved
        Sound.play_cursor
        refresh
      end
    end
    def process_input
      if Input.trigger?(:C)
        if @in_action_row
          if @action_index == 0
            @on_cancel.call
            Sound.play_cancel
          else
            @on_confirm.call
            Sound.play_ok
          end
        else
          ch = current_char
          if ch
            @on_enter.call(ch)
            Sound.play_ok
          end
        end
      elsif Input.trigger?(:B)
        unless @in_action_row
          @on_backspace.call
          Sound.play_cursor
        end
      end
    end
    def current_char; PLATE[@cursor_row][@cursor_col]; end
    def refresh
      contents.clear
      draw_name_box
      draw_character_grid
      draw_action_row
    end
    def draw_name_box
      box_h = NAME_HEIGHT
      border = Color.new(128, 128, 128)
      contents.fill_rect(0, 0, contents_width, 2, border)
      contents.fill_rect(0, box_h - 2, contents_width, 2, border)
      contents.fill_rect(0, 0, 2, box_h, border)
      contents.fill_rect(contents_width - 2, 0, 2, box_h, border)
      face_bmp = @face_getter.call
      if face_bmp
        target_h = box_h - 12
        CharacterCreation.draw_face_fitted(contents, Rect.new(8, 6, target_h, target_h), face_bmp)
      end
      name = @buffer_getter.call
      text_x, text_w = NAME_HEIGHT + 4, contents_width - (NAME_HEIGHT + 4) - 8
      change_color(normal_color)
      draw_text(text_x, 6, text_w, LINE_HEIGHT, name, 1)
    end
    def draw_character_grid
      grid_top = NAME_HEIGHT + LINE_HEIGHT
      ROWS.times do |r|
        COLS.times do |c|
          ch = PLATE[r][c]
          next if ch.nil?
          x, y = 4 + c * 24, grid_top + r * LINE_HEIGHT
          selected = !@in_action_row && r == @cursor_row && c == @cursor_col
          label = (ch == " ") ? "spc" : ch
          change_color(selected ? normal_color : system_color)
          draw_text(x, y, 24, LINE_HEIGHT, label, 1)
        end
      end
    end
    def draw_action_row
      action_y = NAME_HEIGHT + LINE_HEIGHT + ROWS * LINE_HEIGHT
      change_color((@in_action_row && @action_index == 0) ? normal_color : system_color)
      draw_text(4 + 3 * 24, action_y, 72, LINE_HEIGHT, "Cancel", 1)
      change_color((@in_action_row && @action_index == 1) ? normal_color : system_color)
      draw_text(4 + 7 * 24, action_y, 48, LINE_HEIGHT, "OK", 1)
    end
  end

  class Scene_TextInput < Scene_MenuBase
    MAX_LENGTH = 24
    attr_reader :buffer
    def start
      super
      @target = CharacterCreation.text_input_target
      @buffer = initial_buffer
      w = 300
      h = Window_TextInputGrid::PADDING * 2 + Window_TextInputGrid::NAME_HEIGHT +
          Window_TextInputGrid::LINE_HEIGHT + (Window_TextInputGrid::ROWS + 1) * Window_TextInputGrid::LINE_HEIGHT
      x, y = (Graphics.width - w) / 2, (Graphics.height - h) / 2
      @grid = Window_TextInputGrid.new(
        x, y, w, method(:on_enter), method(:on_backspace), method(:on_confirm),
        method(:on_cancel), -> { @buffer }, method(:face_bitmap)
      )
      @grid.activate
    end
    def initial_buffer
      c = CharacterCreation.draft
      return "" unless c
      case @target
      when :name       then c.name.to_s
      when :nickname   then c.nickname.to_s
      when :artist     then c.artist.to_s
      when :trait_name then c.trait_name.to_s
      else ""
      end
    end
    def on_enter(ch)
      return if @buffer.size >= MAX_LENGTH
      @buffer += ch
      @grid.refresh
    end
    def on_backspace
      return if @buffer.empty?
      @buffer = @buffer[0..-2]
      @grid.refresh
    end
    def on_confirm; commit; end
    def on_cancel; abort_input; end
    def commit
      c = CharacterCreation.draft
      case @target
      when :name       then c.name       = @buffer
      when :nickname   then c.nickname   = @buffer
      when :artist     then c.artist     = @buffer
      when :trait_name then c.trait_name = @buffer
      end
      CharacterCreation.text_input_target = nil
      CharacterCreation.pending_refresh = true
      SceneManager.return
    end
    def abort_input
      CharacterCreation.text_input_target = nil
      SceneManager.return
    end
    def face_bitmap
      c = CharacterCreation.draft
      return nil unless c
      path = File.join(CharacterCreation::CACHE_DIR, c.key.to_s, "face.png")
      return nil unless File.exist?(path)
      @face_bmp ||= Bitmap.new(path)
    end
    def terminate
      @grid.dispose if @grid && !@grid.disposed?
      @face_bmp.dispose if @face_bmp && !@face_bmp.disposed?
      super
    end
  end
end

CharacterCreation::TitleHook.install