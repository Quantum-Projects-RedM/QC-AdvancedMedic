# Installation Guide - QC-AdvancedMedic

Complete step-by-step installation instructions for QC-AdvancedMedic on RedM servers using RSG-Core framework.

## Prerequisites

Before installing, ensure your server has:

- **RedM Server**: Build 1436 or higher
- **RSG-Core Framework**: Latest version
- **MySQL/MariaDB**: Version 5.7+ (MySQL) or 10.2+ (MariaDB)
- **oxmysql**: Latest version
- **ox_lib**: Latest version
- **rsg-inventory**: Latest version
- **rsg-bossmenu**: Latest version

### Checking Prerequisites

```bash
# Check RedM server version
# In server console, type: version

# Verify database connection
# In server console, check for: [oxmysql] Database server connection established

# Check required resources are started
# In server console: ensure rsg-core
# In server console: ensure ox_lib
```

## Installation Steps

### Step 1: Backup Your Server

**CRITICAL**: Always backup before installing new resources.

```bash
# Backup your database
mysqldump -u [username] -p [database_name] > backup_$(date +%Y%m%d).sql

# Backup your resources folder (optional but recommended)
cp -r resources resources_backup_$(date +%Y%m%d)
```

### Step 2: Extract Resource Files

1. Download the latest release from GitHub
2. Extract the `QC-AdvancedMedic` folder
3. Place in your server's resources directory:

```
YourServer/
└── resources/
    └── [quantum]/               # Or your custom resource folder
        └── QC-AdvancedMedic/
```

**Verify folder structure:**
```
QC-AdvancedMedic/
├── fxmanifest.lua          ✓ Present
├── config.lua              ✓ Present
├── client/                 ✓ Folder with 9 files
├── server/                 ✓ Folder with 6 files
├── ui/            ✓ Folder with build/
├── locales/                ✓ Folder with JSON files
└── INSTALL_FIRST/          ✓ Folder with SQL and items
```

### Step 3: Database Setup

**Option A: HeidiSQL (Recommended for Windows)**

1. Open HeidiSQL and connect to your database
2. Navigate to your RedM database (usually `rsg` or similar)
3. Click **File** → **Run SQL file**
4. Select `INSTALL_FIRST/schema.sql`
5. Click **Execute** (blue play button)
6. Verify success message: "4 tables created, 2 procedures created"

**Option B: MySQL Command Line**

```bash
# Navigate to QC-AdvancedMedic folder
cd /path/to/resources/[quantum]/QC-AdvancedMedic/INSTALL_FIRST

# Execute schema
mysql -u [username] -p [database_name] < schema.sql

# Verify tables were created
mysql -u [username] -p [database_name] -e "SHOW TABLES LIKE 'player_%';"
```

**Expected Output:**
```--+
| Tables_in_[db] (player_%)      |--+
| player_wounds                  |
| player_infections              |
| medical_treatments             |
| medical_history                |--+
```

**Option C: phpMyAdmin**

1. Login to phpMyAdmin
2. Select your RedM database
3. Click **Import** tab
4. Choose file: `INSTALL_FIRST/schema.sql`
5. Click **Go**
6. Check for success message

### Step 4: Add Items to Framework

**Location**: `rsg-core/shared/items.lua`

1. Open `INSTALL_FIRST/shared_items.lua` in a text editor
2. Copy the entire contents
3. Open `rsg-core/shared/items.lua`
4. Scroll to the bottom of the items table (before the closing `}`)
5. Paste the copied items
6. **Important**: Ensure proper comma separation

**Example:**
```lua
-- In rsg-core/shared/items.lua
RSGShared.Items = {
    -- ... existing items ...

    ['water'] = {
        ['name'] = 'water',
        ['label'] = 'Water',
        -- ... existing item data ...
    },  -- ← Make sure this comma exists!

    -- Paste QC-AdvancedMedic items here:
    ['bandage'] = {
        ['name'] = 'bandage',
        ['label'] = 'Bandage',
        ['weight'] = 100,
        ['type'] = 'item',
        ['image'] = 'bandage.png',
        ['unique'] = false,
        ['useable'] = true,
        ['shouldClose'] = true,
        ['combinable'] = nil,
        ['description'] = 'Basic cloth bandage for treating wounds'
    },

    -- ... rest of medical items ...
}
```

**Items Added (24 total)**:
- Medical supplies: bandage, cotton_bandage, linen_bandage, sterile_bandage
- Emergency: rope_tourniquet, leather_tourniquet, cloth_tourniquet, medical_tourniquet
- Medicines: laudanum, morphine, whiskey, quinine
- Injections: adrenaline, cocaine, strychnine, saline
- Equipment: medicalbag, stethoscope, thermometer
- Consumables: antiseptic, penicillin, surgical_kit
- Crafting: cotton, linen, leather_strips, medical_supplies

### Step 5: Add Item Images

**Location**: `rsg-inventory/html/images/`

1. Navigate to `INSTALL_FIRST/IMAGES/` folder
2. Copy all PNG files (3 core images provided):
   - `bandage.png`
   - `cotton.png`
   - `medicalbag.png`
3. Paste into `rsg-inventory/html/images/`

**Note**: The provided images are core items. Additional items will use placeholder images until you add custom ones.

**Missing Images Checklist** (you'll need to source these):
- [ ] cotton_bandage.png
- [ ] linen_bandage.png
- [ ] sterile_bandage.png
- [ ] rope_tourniquet.png
- [ ] leather_tourniquet.png
- [ ] cloth_tourniquet.png
- [ ] medical_tourniquet.png
- [ ] laudanum.png
- [ ] morphine.png
- [ ] whiskey.png (may already exist)
- [ ] quinine.png
- [ ] adrenaline.png
- [ ] cocaine.png
- [ ] strychnine.png
- [ ] saline.png
- [ ] stethoscope.png
- [ ] thermometer.png
- [ ] antiseptic.png
- [ ] penicillin.png
- [ ] surgical_kit.png
- [ ] linen.png
- [ ] leather_strips.png
- [ ] medical_supplies.png

**Recommended Image Specs**:
- Format: PNG with transparency
- Size: 256x256 pixels (or 512x512 for high-res)
- Style: Match your server's inventory theme

### Step 6: Configure the Resource

**Required Configuration**:

1. Open `config.lua` in a text editor
2. Update medic job locations to match your server:

```lua
Config.MedicJobLocations = {
    {
        name = 'Valentine Medical Office',        -- Display name
        prompt = 'valmedic',                      -- Prompt label
        coords = vector3(-281.82, 809.39, 119.38),-- Your coordinates
        showblip = true,                          -- Show on map?
        blipsprite = 'blip_shop_doctor',          -- Blip icon
        blipscale = 0.2,                          -- Blip size
        job = 'valmedic'                          -- EXACT job name from database
    },
    {
        name = 'Saint Denis Hospital',
        prompt = 'sdmedic',
        coords = vector3(2721.28, -1230.74, 50.37),
        showblip = true,
        blipsprite = 'blip_shop_doctor',
        blipscale = 0.2,
        job = 'sdmedic'
    },
    -- Add more locations as needed
}
```

**Finding Your Coordinates**:
```lua
-- In-game, stand at desired location and run:
/coords

-- Or use this command to print to F8 console:
-- Press F8 and type:
GetEntityCoords(PlayerPedId())
```

3. **Verify job names** match your `rsg-core` job database:

```sql
-- Run this query to see all jobs in your database:
SELECT * FROM jobs;

-- Make sure your Config.MedicJobLocations[].job values match the 'name' column
```

4. **Adjust server-specific settings**:

```lua
-- In config.lua, customize these for your server:
Config.MaxHealth = 600                    -- Match your server's max health
Config.DeathTimer = 300                   -- Seconds before respawn (5 min default)
Config.WipeInventoryOnRespawn = true      -- Clear items on death?
Config.WipeCashOnRespawn = true           -- Clear cash on death?
Config.EnableScreenEffects = true         -- Blood/pain visual effects?
```

5. **Configure mission locations** (optional):

Open `ConfigMissions.lua` and update coordinates:

```lua
Config.MissionLocations = {
    valentine = {
        vector3(-324.66, 803.94, 117.88),  -- Update to your locations
        vector3(-175.39, 626.77, 114.09),
        -- ... more locations
    },
    -- ... other towns
}
```

### Step 7: Add to Server.cfg

1. Open your `server.cfg` file
2. Add the resource in the appropriate section:

```cfg
# Medical Systems
ensure QC-AdvancedMedic
```

**Load Order Matters** - Ensure these start BEFORE QC-AdvancedMedic:
```cfg
ensure oxmysql
ensure ox_lib
ensure rsg-core
ensure rsg-inventory
ensure rsg-bossmenu

# Then start medical system:
ensure QC-AdvancedMedic
```

### Step 8: Restart Server

**For Test/Development Servers**:
```bash
# In server console:
restart QC-AdvancedMedic
```

**For Production Servers**:
```bash
# Full server restart recommended for first installation:
stop
# Wait 10 seconds
start
```

**Watch for errors** in console during startup:
- ✓ `[QC-AdvancedMedic] Resource started successfully`
- ✓ `[oxmysql] Query executed successfully`
- ✗ `[script:QC-AdvancedMedic] SCRIPT ERROR` - See troubleshooting below

## Verification Steps

### 1. Database Verification

```sql
-- Check tables exist:
SHOW TABLES LIKE 'player_%';
SHOW TABLES LIKE 'medical_%';

-- Check stored procedures:
SHOW PROCEDURE STATUS WHERE Db = '[your_database_name]';

-- Expected: GetCompleteMedicalProfile, CleanupExpiredMedicalData
```

### 2. In-Game Verification

**As Admin**:
```
/heal         → Should restore health
/revive       → Should revive if downed
```

**As Player**:
1. Check inventory for medical items (give yourself a bandage via admin)
2. Take damage (fall, shoot yourself)
3. Use bandage - should see NUI interface
4. Check F8 console for errors

**As Medic**:
1. Get hired at medic job: `/setjob [yourID] valmedic 4`
2. Go to medic location (blip should appear on map)
3. Access storage (should see 48 slots)
4. Try `/inspect [playerID]` on another player
5. Craft medical bag using materials from storage
6. Complete a training mission

### 3. NUI Verification

1. As medic, use `/inspect [targetID]`
2. NUI should open showing body diagram
3. Click on body parts - should show wound details
4. Try applying a treatment
5. Check browser console (F8 → Console tab) for JavaScript errors

## Troubleshooting

### Database Issues

**Error**: `Table 'player_wounds' doesn't exist`
```sql
-- Verify database name in oxmysql configuration:
-- Check server.cfg or database.cfg for:
set mysql_connection_string "mysql://user:password@localhost/DATABASE_NAME"

-- Make sure you ran schema.sql on the CORRECT database
-- Re-run if needed:
mysql -u root -p CORRECT_DATABASE_NAME < INSTALL_FIRST/schema.sql
```

**Error**: `Stored procedure not found`
```sql
-- Check procedures exist:
SHOW PROCEDURE STATUS WHERE Db = '[your_database]';

-- If missing, manually execute the CREATE PROCEDURE statements
-- from INSTALL_FIRST/schema.sql
```

### Item Issues

**Error**: `Item 'bandage' not found in shared items`

**Solution**:
1. Verify you added items to `rsg-core/shared/items.lua`
2. Check for syntax errors (missing commas, brackets)
3. Restart `rsg-core` resource:
```
restart rsg-core
```
4. Then restart QC-AdvancedMedic:
```
restart QC-AdvancedMedic
```

**Error**: Item images show as placeholder

**Solution**:
1. Check image file names match EXACTLY (case-sensitive):
   - `bandage.png` ✓
   - `Bandage.png` ✗
   - `bandage.PNG` ✗
2. Clear browser cache (Ctrl+F5 in-game)
3. Verify images are in correct folder: `rsg-inventory/html/images/`

### Job System Issues

**Error**: "You are not a medic" when you ARE a medic

**Solution**:
1. Check your job name in database:
```sql
SELECT job FROM players WHERE citizenid = '[your_citizenid]';
```
2. Make sure it matches EXACTLY in `Config.MedicJobLocations`:
```lua
job = 'valmedic'  -- Must match database exactly (case-sensitive)
```
3. Check helper function is loaded:
```lua
-- In F8 console in-game:
IsMedicJob('valmedic')  -- Should return true if working
```

### NUI Issues

**Error**: NUI doesn't open when using `/inspect`

**Solution**:
1. Check browser console (F8 → Console tab) for errors
2. Verify NUI files exist:
```
ui/
└── build/
    ├── index.html       ← Must exist
    ├── static/
    │   ├── css/
    │   └── js/
    └── asset-manifest.json
```
3. Try clearing FiveM cache:
   - Close RedM
   - Navigate to `%localappdata%/RedM/FiveM Application Data`
   - Delete `cache` folder
   - Restart RedM

**Error**: Body parts not clickable

**Solution**:
1. Check screen resolution - UI optimized for 1920x1080
2. Try windowed mode instead of fullscreen
3. Check browser console for click handler errors
4. Verify image files exist in `ui/build/static/media/`

### Performance Issues

**Symptom**: Server lag when multiple players have wounds

**Solution**:
1. Increase tick intervals in `config.lua`:
```lua
Config.BleedingProgression = 2      -- Increase from 1 to 2 minutes
Config.PainProgression = 2          -- Increase from 1 to 2 minutes
Config.InfectionTickInterval = 5    -- Increase from 2 to 5 minutes
```
2. Reduce wound history retention:
```lua
Config.MaxScarsPerPlayer = 3        -- Reduce from 5 to 3
```
3. Run database cleanup procedure manually:
```sql
CALL CleanupExpiredMedicalData();
```

## Post-Installation Tasks

### 1. Set Up Medic Jobs

Add jobs to your RSG-Core job system:

```sql
-- Example job insertion (adjust for your system):
INSERT INTO jobs (name, label) VALUES ('valmedic', 'Valentine Medic');
INSERT INTO jobs (name, label) VALUES ('sdmedic', 'Saint Denis Medic');

-- Set up job grades:
INSERT INTO job_grades (job_name, grade, name, label, salary, isboss)
VALUES
    ('valmedic', 0, 'recruit', 'Recruit', 50, 0),
    ('valmedic', 1, 'medic', 'Medic', 75, 0),
    ('valmedic', 2, 'surgeon', 'Surgeon', 100, 0),
    ('valmedic', 3, 'chief', 'Chief Physician', 150, 1);
```

### 2. Populate Medical Supplies

Add initial supplies to medic storage:

```lua
-- In-game as admin:
/openinv storage_valmedic_1  -- Access storage

-- Then use admin menu to add items:
-- 10x bandage
-- 10x cotton_bandage
-- 5x linen_bandage
-- 5x antiseptic
-- 3x morphine
-- 2x surgical_kit
```

### 3. Configure Crafting Recipes

Edit `config.lua` to customize medical bag crafting:

```lua
Config.BagCraftingRecipe = {
    {item = 'leather', amount = 5},
    {item = 'thread', amount = 3},
    {item = 'medical_supplies', amount = 1}
}
```

### 4. Train Your Medics

1. Create medic job guide document for players
2. Demonstrate `/inspect` command usage
3. Show how to complete training missions
4. Explain infection prevention (bandage grace period)
5. Review scar system for medical RP

### 5. Set Up Cron Job for Cleanup

**Linux Server**:
```bash
# Add to crontab:
0 3 * * * mysql -u [user] -p[pass] [database] -e "CALL CleanupExpiredMedicalData();"
```

**Windows Server** (Task Scheduler):
1. Create batch file `cleanup_medical.bat`:
```batch
mysql -u [user] -p[pass] [database] -e "CALL CleanupExpiredMedicalData();"
```
2. Schedule to run daily at 3:00 AM

## Uninstallation

If you need to remove QC-AdvancedMedic:

### 1. Stop the Resource
```cfg
# In server.cfg, remove or comment out:
# ensure QC-AdvancedMedic
```

### 2. Remove Database Tables (OPTIONAL - Data will be lost!)
```sql
DROP TABLE IF EXISTS player_wounds;
DROP TABLE IF EXISTS medical_treatments;
DROP TABLE IF EXISTS player_infections;
DROP TABLE IF EXISTS medical_history;
DROP PROCEDURE IF EXISTS GetCompleteMedicalProfile;
DROP PROCEDURE IF EXISTS CleanupExpiredMedicalData;
```

### 3. Remove Items from Framework
1. Open `rsg-core/shared/items.lua`
2. Remove all QC-AdvancedMedic items
3. Restart `rsg-core`

### 4. Delete Resource Folder
```bash
rm -rf resources/[quantum]/QC-AdvancedMedic
```

## Support

If you encounter issues not covered in this guide:

1. **Check GitHub Issues**: [Link to your repo]/issues
2. **Join Discord**: [Your Discord invite]
3. **Provide Details**:
   - Server console errors
   - F8 console errors
   - RedM version
   - RSG-Core version
   - Steps to reproduce

**When Reporting Issues, Include**:
```
- RedM Build: [e.g., 1436]
- RSG-Core Version: [e.g., 1.2.5]
- MySQL Version: [e.g., 8.0.33]
- Error Message: [full error from console]
- Reproduction Steps: [what you did before error occurred]
```

## Success Checklist

Before going live, verify:

- [ ] Database tables created successfully (4 tables)
- [ ] Stored procedures created (2 procedures)
- [ ] Items added to rsg-core shared items
- [ ] Item images added to inventory folder
- [ ] Config.lua updated with correct job names
- [ ] Config.lua updated with correct coordinates
- [ ] Server starts without errors
- [ ] `/heal` and `/revive` commands work
- [ ] Medic job access to storage works
- [ ] `/inspect` command opens NUI
- [ ] Wounds track correctly when taking damage
- [ ] Treatments can be applied via NUI
- [ ] Infections progress when bandages expire
- [ ] Wounds heal to scars with proper treatment
- [ ] Training missions can be started
- [ ] No console errors during normal gameplay

**Installation Complete!**

Your QC-AdvancedMedic system is now ready for alpha testing. Monitor server console and player feedback for any issues.
