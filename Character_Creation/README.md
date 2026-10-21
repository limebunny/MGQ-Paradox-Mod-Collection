# Character Creation

Lets you make a custom hero and start a new game playing as that hero in Luka's place. The story still treats your hero as Luka, but they bring their own name, looks, sex, base stats, starting job, race, equipment and trait — and their own cut-ins in battle.

## What you get

- After **New Game**, a menu asks what to play: **Create New Character**, **Load Character**, **Delete Character**, or **Start as Default** (Luka). The save remembers your choice.
- Your hero's name, sprite, face and picture replace Luka's everywhere: on the map, in menus, in battle, in story messages, on the save screen, and in the Library. Other characters named Luka keep their names.
- Your hero speaks their own battle lines and knock-out lines, with their own face and expressions, and plays their own cut-ins.
- Your hero grows by their own stats and has their own trait, built from a catalogue of more than 180 traits with a 100‑point budget. They keep Luka's Talk skill, which recruiting needs.
- A heroine counts as female for skills that only affect one sex.
- In Luka's Part 3 forms your hero can look different and speak other lines. Father of Chaos, World Breaker and Judgement stay Luka.

## Install

1. Install the community's mod loader: the `Patch.rb` from [*Patch.rb (enable Type 1 mods)*](https://mgq.miraheze.org/wiki/Paradox_mods#Patch.rb_(enable_Type_1_mods)) on the MGQ wiki, in your `Patch` folder. If you already use other Patch folder mods, you have it.
2. [Download `Character_Creation.zip`](https://github.com/limebunny/Character_Creation/releases/latest/download/Character_Creation.zip) and extract it into the game folder, the one with `Game.exe`. It puts `CharacterCreation.rb` into your `Patch` folder and `Character_Creation/` alongside it.

To uninstall, delete `Patch\CharacterCreation.rb` and the `Patch\Character_Creation` folder. A save started with a custom character keeps their starting job and gear; to play as Luka again, start a new game.

## Making your first hero

Creating a hero is done entirely in‑game. Everything you need is a **folder of images** called an **Import**.

### 1. Prepare an Import folder

An Import is one folder inside `Patch\Character_Creation\Imports`. The folder can be called anything you like — the name is just how you'll recognise it in the picker.

At minimum, it must contain:

- `face.png` — the face shown in menus, the message box and the status screen. If your file is a wide face sheet (such as the 4‑column, 2‑row sheets the game itself uses), the top‑left 96×96 cell is used.
- `sprite.png` — the walking sprite sheet. The game's format is 3 columns × 4 rows of cells.

Optionally, it may contain:

- `picture.png` — the tall portrait shown in the Library and in cut‑ins that use it.
- `cutin.png` — the cut‑in image, if you want the hero to flash a picture in battle. See *Cut‑ins* below.
- `form2_face.png`, `form2_sprite.png`, `form2_picture.png` — images for Luka's second form.
- `form3_face.png`, `form3_sprite.png`, `form3_picture.png` — images for Luka's third form.

A typical folder looks like this:

- `Patch/`
  - `Character_Creation/`
    - `Imports/`
      - `cecil/`
        - `face.png`
        - `sprite.png`
        - `picture.png`
        - `cutin.png`

### 2. Open the Dashboard

Start the game and choose **New Game**. Instead of Luka, a menu offers four choices. Pick **Create New Character**.

The **Dashboard** has two panels: the editor fields on the left, and a live preview on the right showing the hero's **Face**, **Sprite** and **Cut‑in** side by side, plus their name, artist, trait, job and race.

### 3. Walk down the fields

Use **Up** and **Down** to move between fields. Use **OK** to edit, and **Cancel** when you are done.

| Field | What it does |
|---|---|
| **Import** | Opens a list of your Import folders. Pick one to load its images into the draft. |
| **Name** | The hero's name. It replaces Luka's name everywhere. |
| **Artist** | Optional. Shown in the Library's records. |
| **Sex** | Male or Female. Affects skills that only target one sex. |
| **Bust Size** | Flat, Small, Medium, Large or Huge. It changes one of Luka's skills for a variant — pick whichever you like. |
| **Job** | The hero's starting job. Lists every job the game allows a new character to start as. |
| **Race** | The hero's starting race. Lists every race the game allows a new character to start as. |
| **Cut‑in** | Opens the Skill Type picker. See *Cut‑ins*. If your Import has no `cutin.png`, this field is greyed out. |
| **Trait** | Opens the Trait Dashboard. See *Building a trait*. |
| **Save** | Writes the hero to `Patch\Character_Creation\Heroes\<name>.luka`. Needs a name and an Import. |
| **Cancel** | Discards the draft. |

The **Save** field stays greyed until the hero has a name and an Import with both a `face.png` and a `sprite.png`.

## Cut-ins

A cut‑in is a picture that flashes over the battle screen when a skill of the chosen **Skill Type** is used. For example, choose **Sword** and every Sword skill plays the cut‑in; a Heroism skill does not.

To set one up:

1. Put a `cutin.png` in your Import folder.
2. On the Dashboard, walk to **Cut‑in** and press **OK**.
3. Pick a Skill Type from the list. **None** leaves the image unused but still on the character.
4. The Dashboard now shows `Cut‑in: Sword` (or whichever type you chose).

Only one cut‑in per character is supported at present. Multiple cut‑ins, per‑skill cut‑ins and form‑specific cut‑ins are planned.

## Building a trait

Every hero has a trait, and a trait is a list of small effects. You have a **100‑point budget** to spend across the catalogue.

From the Dashboard, walk to **Trait** and press **OK**. The **Trait Dashboard** opens with a header showing your character's name, job, race and current cost, a list of the traits you have picked, and a large empty preview area.

Three commands:

- **Rename** — give the whole trait a name. If you leave it blank, the name is generated from the first trait you picked.
- **Edit** — open the trait list to add, change or remove entries.
- **Save** — accept the current trait and return to the Dashboard.

In the **Edit** list, **OK** on a row opens the picker. The picker groups traits into tabs (**Combat**, **Job**, **Magic**, **Defense**, **Special**, **Unique**) and switches tabs with **Left** and **Right**. Each entry shows its cost on the right, and costs more than your remaining budget are greyed out. **OK** on a trait adds it (or replaces the trait you were editing). **Cancel** backs out without changing anything.

To **remove** a trait, hold **A** on it in the list. It disappears.

To **change** a trait, press **OK** on it in the list, then pick a replacement from the picker. The replacement costs whatever it costs, but the old trait is refunded.

Traits in the same **conflict group** evict each other. If you pick "Sword Booster 30%", any "Sword Booster 15%" you already had is removed automatically.

The preview area fills in as you add traits. It merges the names into a paragraph you can read at a glance, such as *"Can always use Sword and Holy skills. Sword skills deal +30% more damage. Max HP +20%."* That paragraph is what shows in the Library's records and in the hero's trait tooltip.

## Playing with your hero

When the hero is saved, go back to the title screen, choose **New Game**, then **Load Character**, and pick the hero from the list. **Start as Default** starts a normal Luka game without touching your heroes.

A saved hero appears in the **Delete Character** list as well. Deleting a hero does not affect a save you have already started with them.

## Sharing your hero

A hero is a single `.luka` file, and it carries everything about them: name, images, job, race, trait, story rules and cut‑ins. Sharing is just moving the file.

- **Share one hero:** copy `Patch\Character_Creation\Heroes\<name>.luka` to the other player. They drop it into their own `Patch\Character_Creation\Heroes` folder.
- **Share with a Multiplayer friend:** you don't have to. When you both play together in **Monster Girl Quest! Online**, the mod sends your `.luka` file over the world to anyone who joins and doesn't have it, and they see your hero for the session.

The two mods, Character Creation and Luka Replacer, both read `.luka` files, so a hero from one opens in the other. The two mods themselves should not be installed at the same time.

## Multiplayer

With [Monster Girl Quest! Online](https://github.com/Pauliinchen/MGQ-Online), other players see your hero in battle and on the map. If their game does not have your `.luka` file, they receive it automatically when they join your world, and it stays for that session only.

An opponent who plays Luka shows the original Luka if their file is not available in your game, and their own hero if it is.

## Troubleshooting

- **Import is missing from the picker.** The folder is either in the wrong place or missing `face.png` or `sprite.png`. The picker only shows folders that have both.
- **Save stays greyed.** The hero needs a name and a working Import.
- **Cut‑in field is greyed.** The Import folder has no `cutin.png`.
- **Nothing happened.** Open `Logs\Character Creation.log` in the game folder; every step the mod takes writes a line there.
- **Playing as Luka again.** Start a new game and choose **Start as Default**. Existing saves keep their hero.

## Notes for modders

If you want to retune traits, edit `Patch\Character_Creation\Scripts\00_Data.rbx`. Rename it to `00_Data.rb`, open it in any text editor, save, and rename it back. Everything in the mod is loaded this way from `Patch\CharacterCreation.rb`, so you can inspect any of the scripts the same way.

## Credits

Character Creation is a sibling of Luka Replacer. The character file format, the Luka Replacer compatibility shim, the title screen structure, and much of the battle‑line handling are adapted from Luka Replacer by Paulinchen. The trait catalogue, the dashboard, the trait picker and the cut‑in system are new.

Cecil's images come from *Hyperdimension Girl Quest!* (D‑Gate / The_HeroLuka), via Luka Replacer. Herzfeld's sprite and face are RPG Maker's stock images; his picture is by Archeia.

Playtesting was conducted by Discord users Aru, Weeg, and "Aubrey with the plan".

Special thanks to AstralKnight for promoting the idea.