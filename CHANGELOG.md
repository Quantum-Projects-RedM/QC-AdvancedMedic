# Changelog

All notable changes to QC-AdvancedMedic.

## [Unreleased]

### v1.0.0 Planned
- Advanced surgery system
- Medical supply crafting expansion
- Hospital bed recovery mechanics
- Medical record sharing between organizations
- Advanced vital signs (blood pressure, shock)
- Additional translations (German, Portuguese)
- Prosthetic limbs for permanent injuries
- Mental health/trauma system
- Disease mechanics (cholera, tuberculosis, dysentery)
- Field surgery with success/failure
- Medical journal item

## [0.3.1] - 2025-11-17 MAJOR UPDATE

### Fixed
- Smelling salts showing "no patient found" error
- Injections, tourniquets, and medicine not removing items or fixing injuries
- Doctor's bag items showing "player not found" error
- Medic emergency notifications not reaching doctors (fixed event name mismatch)
- Respawn spawning players under map (NetworkResurrectLocalPlayer parameter fix)
- Medicine usage server-side error (GetPlayerServerId on server)
- Tourniquet/injection items missing useable item registration
- Locale loader showing "0 strings loaded" (fixed object key counting)
- NUI translations not displaying (fixed props passing in App.tsx)
- All hardcoded notification strings replaced with locale() calls (59+ server-side strings)

### Changed
- `/heal` command removed - use `/revive` and `/clearwounds` instead
- `/revive` command now fully clears all wounds, fractures, treatments, and infections
- Death screen text shows medic availability status dynamically
- Scripted camera added to `/checkhealth` for better character viewing
- Complete locale system unification - single JSON source for both Lua and NUI
- All three NUI panels (DeathScreen, InspectionPanel, MedicalPanel) use consistent translation pattern

### Added
- Complete French translation (376 keys)
- Complete Spanish translation (376 keys)
- English locale expansion (376 keys total)
- 67 new server-side locale keys for medical notifications
- NUI translation system documentation
- Global `locale()` function using Config.Strings for unified translation system

### Breaking Changes
- **`/heal` command removed**: Server owners using `/heal` in scripts must switch to `/revive`

## [0.3.0] - 2025-11-10

### Fixed
- Medical inspection desync - medics can now see patient wounds correctly
- Scar display in NUI - healed wounds show as "OLD HEALED INJURY"
- Server-side cache synchronization for wounds, treatments, and infections
- Medics not receiving emergency call notifications
- Pain sounds persisting after revive or character logout

### Added
- Event-based cache sync system for real-time medical data updates
- Self medical panel 3-state UI with loading spinner and real-time inventory checks
- `/checkhealth` command documentation

## [0.2.9] - 2025-11-03

### Added
- Fractures system with dedicated table (severity 1-10, healing progress, mobility impact)
- Health tracking in wounds (current/max/percentage)
- Infection immunity system with expiration tracking
- `active_medical_status` view for NUI integration
- **Doctor bag inventory validation** - All doctor bag tools now check inventory before use
- `Config.DoctorsBagTools` - Configuration for diagnostic tools (smelling_salts, stethoscope, thermometer, field_surgery_kit)
- Proper inventory validation for medicines (laudanum, whiskey) when used from doctor bag
- NUI notifications for missing items vs successful tool usage

### Changed
- Database structure: 4 tables → 5 tables (added `player_fractures`)
- Enhanced treatment metadata tracking (pain/bleeding reduction, original levels)
- Improved stored procedures with fracture support
- NUI `handleMedicalAction` now uses `fetch()` instead of `postMessage` for proper Lua callbacks
- Thermometer tool now validates inventory (was bypassing check)
- `/inspect` command now sends medic's inventory to NUI for real-time validation

### Fixed
- Doctor bag tools showing "administering" without inventory check
- Laudanum and whiskey showing "invalid tool action" instead of missing item notification
- Thermometer advancing to temperature screen without item validation

### Removed
- `/medwounds` command (duplicate/faulty - use `/clearwounds` or inspection system instead)

## [0.2.8] - 2025-10-07

### Fixed
- Multi-job support - removed hardcoded `Config.JobRequired`
- Created `IsMedicJob()` helper for dynamic job validation
- Fixed storage, bag, inspection, and revive access for all medic jobs

### Changed
- Refactored 7 files to use centralized job checking
- `Config.MedicJobLocations` is now single source of truth

### Removed
- `Config.JobRequired` global setting

## [0.2.7] - 2025-09-15

### Changed
- Database optimization: 8 tables → 4 tables (42% smaller, 5-10x faster queries)
- Added `GetCompleteMedicalProfile()` and `CleanupExpiredMedicalData()` stored procedures
- Medical profile fetch: 45-80ms → 8-15ms

## [0.2.6] - 2025-08-20

### Added
- Wound healing to scars system
- 6 wound types with healing times (10-40 minutes)
- Max 5 scars per player with full history
- Scar display in NUI

## [0.2.5] - 2025-07-10

### Added
- 4-stage infection system (25% → 50% → 75% → 90%)
- Dirty bandage mechanics (60s grace period, then 15% infection chance/2min)
- Gradual cure system (antiseptic 30%, penicillin 50%, doctor 100%)
- Temporary immunity after cure
- Visual effects per infection stage

## [0.2.0] - 2025-06-01

### Added
- Modern React NUI with interactive body map
- Color-coded injury severity
- Vital signs display (pulse, temperature)
- Wild West themed UI
- Click-to-examine body parts

## [0.1.0] - 2025-05-01

### Added - Initial Alpha
- Advanced wound detection (100+ weapons, 15 body parts)
- Pain/bleeding systems (10-level scales)
- 16 treatment types (bandages, tourniquets, medicines, injections)
- Death/revive mechanics
- Database persistence
- Medic job integration with training missions
- Ballistics system (distance-based bullet behavior)
- Admin commands (`/heal`, `/revive`)
- Multi-language support (EN/ES/FR)

## Upgrading

### v0.2.8 → v0.2.9
1. **Backup database first**
2. Run `INSTALL_FIRST/schema.sql` (creates new `player_fractures` table)
3. Update files
4. Restart resource

### v0.2.7 → v0.2.8
1. Update files
2. Remove `Config.JobRequired` if manually added
3. Verify `Config.MedicJobLocations` has all jobs
4. Restart resource

### v0.2.6 → v0.2.7
1. **Backup database first**
2. Run `INSTALL_FIRST/migration_v027.sql`
3. Update files
4. Test with `/inspect`
5. Set up cleanup cron job (see INSTALL.md)

### v0.2.5 → v0.2.6
1. Update files
2. Run `INSTALL_FIRST/schema_v026_update.sql`
3. Update `config.lua` with healing settings

### v0.2.0 → v0.2.5
1. Update files
2. Run `INSTALL_FIRST/schema_v025_update.sql`
3. Add antiseptic/penicillin items
4. Update `config.lua` with infection settings

### v0.1.0 → v0.2.0
1. **Backup database**
2. Update all files (replace `ui/` completely)
3. Clear client cache
4. Update `config.lua` with UI color settings

## Version Schema

**MAJOR.MINOR.PATCH** (Semantic Versioning)
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward-compatible)
- **PATCH**: Bug fixes

**Current**: `0.3.0-alpha`

**Issues**: [GitHub Issues](https://github.com/YOUR_ORG/QC-AdvancedMedic/issues)
**Last Updated**: November 10, 2025
