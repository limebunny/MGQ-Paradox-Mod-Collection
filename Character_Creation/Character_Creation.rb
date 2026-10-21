#==============================================================================
# CharacterCreation.rb
# The single entry point for the Character Creation mod.
#==============================================================================

module CharacterCreation
  MOD_DIR = "Patch/Character_Creation"
  
  # The .rbx scripts, in load order.
  SCRIPTS = %w[
    00_Data
    01_Core
    02_Hooks
    03_BattleLines
    04_TitleAndDashboard
    05_TraitDashboard
    06_Multiplayer
  ]

  def self.load_scripts
    SCRIPTS.each do |name|
      file = "#{MOD_DIR}/Scripts/#{name}.rbx"
      begin
        eval(File.read(file, encoding: "BOM|UTF-8"), TOPLEVEL_BINDING, file)
      rescue Exception => e
        print "FAILED TO LOAD: #{name}.rbx\n#{e.class}: #{e.message}\n"
        raise e
      end
    end
  end
end

CharacterCreation.load_scripts