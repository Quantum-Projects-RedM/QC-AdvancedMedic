# Changelog

All notable changes to QC-AdvancedMedic.

## [Unreleased]

### v0.3.0 Planned
- Advanced surgery system
- Medical supply crafting expansion
- Hospital bed recovery mechanics
- Medical record sharing between organizations
- Advanced vital signs (blood pressure, shock)
- Additional translations (German, Portuguese)

### v1.0.0 Planned
- Prosthetic limbs for permanent injuries
- Mental health/trauma system
- Disease mechanics (cholera, tuberculosis, dysentery)
- Field surgery with success/failure
- Medical journal item
- QBCore and VORP framework support

## [0.2.9] - 2025-11-03

### Added
- Fractures system with dedicated table (severity 1-10, healing progress, mobility impact)
- Health tracking in wounds (current/max/percentage)
- Infection immunity system with expiration tracking
- `active_medical_status` view for NUI integration

### Changed
- Database structure: 4 tables → 5 tables (added `player_fractures`)
- Enhanced treatment metadata tracking (pain/bleeding reduction, original levels)
- Improved stored procedures with fracture support

## [0.2.8] - 2024-10-07

### Fixed
- Multi-job support - removed hardcoded `Config.JobRequired`
- Created `IsMedicJob()` helper for dynamic job validation
- Fixed storage, bag, inspection, and revive access for all medic jobs

### Changed
- Refactored 7 files to use centralized job checking
- `Config.MedicJobLocations` is now single source of truth

### Removed
- `Config.JobRequired` global setting

## [0.2.7] - 2024-09-15

### Changed
- Database optimization: 8 tables → 4 tables (42% smaller, 5-10x faster queries)
- Added `GetCompleteMedicalProfile()` and `CleanupExpiredMedicalData()` stored procedures
- Medical profile fetch: 45-80ms → 8-15ms

## [0.2.6] - 2024-08-20

### Added
- Wound healing to scars system
- 6 wound types with healing times (10-40 minutes)
- Max 5 scars per player with full history
- Scar display in NUI

## [0.2.5] - 2024-07-10

### Added
- 4-stage infection system (25% → 50% → 75% → 90%)
- Dirty bandage mechanics (60s grace period, then 15% infection chance/2min)
- Gradual cure system (antiseptic 30%, penicillin 50%, doctor 100%)
- Temporary immunity after cure
- Visual effects per infection stage

## [0.2.0] - 2024-06-01

### Added
- Modern React NUI with interactive body map
- Color-coded injury severity
- Vital signs display (pulse, temperature)
- Wild West themed UI
- Click-to-examine body parts

## [0.1.0] - 2024-05-01

### Added - Initial Beta
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

**Current**: `0.2.9-beta` (approaching v0.3.0)

**Issues**: [GitHub Issues](https://github.com/YOUR_ORG/QC-AdvancedMedic/issues)
**Last Updated**: November 3, 2025
