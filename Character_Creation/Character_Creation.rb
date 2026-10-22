module Character_Creation
  MOD_DIR = "Patch/Character_Creation/Scripts"

  FILES = %w[
    CC_Core
    CC_Data_Traits
    CC_Data_Packs
    CC_Engine_Hooks
    CC_UI_Menus
    CC_Multiplayer
  ]

  def self.log_error(name, e)
    File.open("Logs/Character Creation.log", "ab") do |f|
      f.write("#{Time.now}  [LOADER] #{name}.rbx FAILED: #{e.class}: #{e.message}\n")
      f.write(e.backtrace.first(20).join("\n") + "\n")
    end
  rescue
  end

  def self.load_scripts
    FILES.each do |name|
      path = "#{MOD_DIR}/#{name}.rbx"
      begin
        eval(File.read(path, encoding: "BOM|UTF-8"), TOPLEVEL_BINDING, path)
      rescue Exception => e
        log_error(name, e)
        # Re-raise so RGSS3's own error dialog shows the failure.
        # Wrapping it preserves the original class and backtrace.
        raise
      end
    end
  end
end

Character_Creation.load_scripts