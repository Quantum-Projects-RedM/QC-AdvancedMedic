# QC-AdvancedMedic

Advanced medical roleplay system for RedM with realistic wound mechanics, treatment systems, and infection progression.

![Version](https://img.shields.io/badge/version-0.2.8--beta-blue.svg)
![Framework](https://img.shields.io/badge/framework-RSG--Core-green.svg)
![Status](https://img.shields.io/badge/status-WIP%20Alpha-orange.svg)

> **Alpha Status**: This is a work-in-progress release. We're seeking feedback and collaboration! Please report issues and suggestions via GitHub Issues.

## Features

- **Advanced Wound System**: Tracks 15 body parts with pain/bleeding severity across 100+ weapons (guns, melee, animals, environmental)
- **Realistic Ballistics**: Distance-based bullet behavior with lodging mechanics and shotgun pellet simulation
- **Treatment Diversity**: 4 types each of bandages, tourniquets, medicines, and injections with time-based decay
- **Infection Progression**: 4-stage infection system with dirty bandage tracking, cure progression, and temporary immunity
- **Wound Healing to Scars**: Properly treated wounds heal into permanent scars with medical history tracking
- **Modern NUI Interface**: Interactive React-based body examination UI with color-coded injury severity
- **Medical Inspection**: `/inspect` command for medics to examine patients with vital signs and treatment application
- **Training Missions**: 5 pre-configured medic training scenarios with difficulty scaling and realistic NPC patients
- **Multi-Job Support**: Flexible job system supporting multiple medic organizations (valmedic, sdmedic, etc.)
- **Database Persistence**: Optimized 4-table schema with stored procedures for complete medical history
- **Multi-Language**: Full localization support (English, Spanish, French)

## Dependencies

- [rsg-core](https://github.com/Rexshack-RedM/rsg-core) - RedM framework
- [rsg-bossmenu](https://github.com/Rexshack-RedM/rsg-bossmenu) - Boss menu integration
- [ox_lib](https://github.com/overextended/ox_lib) - UI library
- [oxmysql](https://github.com/overextended/oxmysql) - Database wrapper
- [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory) - Inventory system

## Installation

1. Extract `QC-AdvancedMedic` to your resources folder
2. Execute `INSTALL_FIRST/schema.sql` in your database (creates 4 tables + stored procedures)
3. Add items from `INSTALL_FIRST/shared_items.lua` to `rsg-core/shared/items.lua`
4. Copy images from `INSTALL_FIRST/IMAGES/` to `rsg-inventory/html/images/`
5. Configure `config.lua` and `ConfigMissions.lua` to match your server setup
6. Add `ensure QC-AdvancedMedic` to server.cfg

**Important**:
- Backup your database before installation
- Item names must match exactly (case-sensitive)
- Review `Config.MedicJobLocations` to set up your medic jobs
- Default max health is set to 600 - adjust `Config.MaxHealth` if your server uses different values

## Quick Start

### For Server Owners
1. Configure medic job locations in `config.lua` (lines 58-82)
2. Set death timer, respawn behavior, and inventory wipe options
3. Adjust treatment effectiveness and wound progression timers
4. Configure infection rates and cure item effectiveness
5. Set up training mission locations in `ConfigMissions.lua`
6. Test with `/heal` and `/revive` admin commands

### For Medics
1. Get hired at a medic job location (Valentine, Saint Denis, etc.)
2. Craft medical bag using materials at job storage
3. Use `/inspect [playerID]` to examine patients
4. Apply treatments via NUI interface (click body parts)
5. Complete training missions for experience
6. Monitor bandage expiration to prevent infections

### For Players
- Wounds accumulate damage, pain, and bleeding from combat/falls/animals
- Pain/bleeding progress over time if untreated
- Seek medic treatment or use basic supplies (bandages, whiskey)
- Infected wounds require special cure items (penicillin, antiseptic)
- Properly healed wounds become permanent scars
- Death occurs at 0 HP or 10+ bleeding - medic or respawn required

## Configuration

Key settings in `config.lua`:

```lua
Config.MaxHealth = 600                          -- Maximum player health
Config.DeathTimer = 300                         -- Seconds before forced respawn
Config.UseScreenEffects = true                  -- Blood/pain visual effects
Config.WipeInventoryOnRespawn = false           -- Clear inventory on death
Config.WipeCashOnRespawn = false                -- Clear cash on death

-- Wound Progression (in minutes)
Config.WoundProgression = {
    bleedingProgressionInterval = 1,            -- Bleeding worsens every 1 min
    painProgressionInterval = 1,                -- Pain increases every 1 min
    painNaturalHealingInterval = 5,             -- Slow heal without treatment
    bandageHealingInterval = 1,                 -- Accelerated heal with bandage
    bleedingProgressAmount = 0.5,               -- Fixed increase per tick
    painProgressAmount = 0.5                    -- Fixed increase per tick
}

-- Infection System (see infection_system.lua for full config)
Config.InfectionTickInterval = 2                -- Check every 2 minutes
Config.BandageGracePeriod = 60                  -- Seconds before infection risk
Config.InfectionRollChance = 15                 -- Base 15% infection chance
Config.MaxSavedInjuries = 5                     -- Store last 5 healed injuries

-- Fall Damage
Config.FallDamage = {
    minHeight = 3.0,                            -- Minor injury threshold (meters)
    fractureHeight = 8.0,                       -- Fracture threshold (non-ragdoll)
    breakHeight = 15.0,                         -- Major break threshold (non-ragdoll)
    ragdollFractureHeight = 6.0,                -- Fracture threshold (ragdoll)
    ragdollBreakHeight = 10.0,                  -- Break threshold (ragdoll)
    ragdollChance = 20                          -- % chance to ragdoll with leg injuries
}
```

### Adding New Medic Jobs

Simply add to `Config.MedicJobLocations` - no code changes needed:

```lua
{
    name = 'Blackwater Medical Office',
    prompt = 'bwmedic',
    coords = vector3(-813.48, -1324.34, 43.63),
    showblip = true,
    blipsprite = 'blip_shop_doctor',
    blipscale = 0.2,
    job = 'bwmedic'  -- Automatically supported by IsMedicJob()
}
```

## System Architecture

### Wound Detection
- Monitors player damage events from weapons, falls, animals
- Maps weapon hashes to configured damage profiles
- Calculates body part based on bone hit detection
- Applies pain/bleeding levels with randomized variation

### Treatment Application
- **Bandages**: Time-based healing with expiration and symptom return
- **Tourniquets**: Emergency bleeding control with max duration limits
- **Medicines**: Pain relief and status effect removal
- **Injections**: Instant effects with gradual decay

### Infection Mechanics
- Bandages decay after grace period (default 60 seconds)
- Dirty bandages trigger infection rolls every 2 minutes
- 4 infection stages: 25% → 50% → 75% → 90%
- Wound type multipliers (bullet stuck 2.0x, fragmented 2.5x)
- Gradual cure system requires multiple applications
- Temporary immunity granted after successful cure

### Healing to Scars
- Requires: bleeding level 1, bandaged, sufficient time elapsed
- Healing times vary by wound type (10-40 minutes)
- Interrupts on new damage to same body part
- Converts wound to permanent scar with medical history
- Max 5 scars stored per player (oldest auto-removed)

## Database Schema

Optimized 4-table design with stored procedures:

- **`player_wounds`** - Active wounds and scars (unique per body part)
- **`medical_treatments`** - All treatment types consolidated (bandages, tourniquets, medicines, injections)
- **`player_infections`** - Infection tracking with cure progress and immunity
- **`medical_history`** - Complete audit trail with 30-day auto-cleanup

**Stored Procedures:**
- `GetCompleteMedicalProfile(citizenid)` - Single-call medical data retrieval
- `CleanupExpiredMedicalData()` - Automatic expired data removal

## Development Roadmap

### Alpha Phase (Current - v0.2.8)
- [x] Core wound/treatment systems
- [x] Infection progression
- [x] Wound healing to scars
- [x] Multi-job support refactor
- [x] Database optimization (8 tables → 4 tables)
- [x] Modern NUI interface
- [ ] Comprehensive testing across scenarios
- [ ] Performance optimization
- [ ] Bug fixes from community feedback

### Beta Phase (Planned)
- [ ] Advanced surgery system for critical wounds
- [ ] Medical supply crafting expansion
- [ ] Hospital bed rest/recovery mechanics
- [ ] Medical record sharing between medic orgs
- [ ] Advanced vital signs (blood pressure, shock)
- [ ] Customizable wound progression rates per server
- [ ] Additional language translations

### Future Enhancements
- [ ] Prosthetic limbs for severe permanent injuries
- [ ] Mental health/trauma system
- [ ] Disease/illness mechanics (cholera, tuberculosis)
- [ ] Field surgery with success/failure mechanics
- [ ] Medical journal/log book item
- [ ] Integration with additional frameworks

## Contributing

We welcome contributions! This is an alpha release and we need:

- **Bug Reports**: Detailed reproduction steps via GitHub Issues
- **Feature Requests**: Suggestions for improvements/additions
- **Code Contributions**: Pull requests with clear descriptions
- **Testing**: Multi-server testing and edge case discovery
- **Documentation**: Improvements to guides and examples
- **Translations**: Additional language support

### Development Guidelines
- Follow existing code structure and naming conventions
- Test thoroughly before submitting PRs
- Comment complex logic for maintainability
- Update relevant documentation with changes
- Keep performance in mind (avoid heavy loops/timers)

## Known Issues

- Shotgun pellet hit detection may occasionally miss at extreme angles
- Rare desync of wound data between client/server in high latency (>200ms)
- NUI body part selection can be finicky on ultrawide monitors
- Fall damage detection sometimes triggers on steep slopes instead of actual falls

See [CHANGELOG.md](CHANGELOG.md) for detailed development history and fixes.

## Performance Notes

- Average client tick: ~0.01ms (wound progression checks)
- Server events: ~5-15ms per medical profile request
- Database queries: Optimized with stored procedures (<10ms)
- NUI impact: Minimal when closed, ~1-2% CPU when active
- Recommended max players: Tested stable up to 128 concurrent

## Credits

**Developer**: Artmines
**Framework**: RSG-Core
**Special Thanks**: RedM community, Quantum Projects contributors, testers

## Support

**Issues**: [GitHub Issues](https://github.com/Quantum-Projects-RedM/QC-AdvancedMedic/issues)
**Discussions**: [GitHub Discussions](https://github.com/Quantum-Projects-RedM/QC-AdvancedMedic/discussions)
**Discord**: [Your Discord Server](https://discord.gg/kJ8ZrGM8TS)

## License

This resource is provided as-is for RedM servers. Please respect the effort put into development.

**Commercial Use**: Allowed with attribution
**Modification**: Allowed (contributions appreciated)
**Redistribution**: Allowed with original credits intact

---

**Version**: 0.2.8-beta | **Framework**: RSG-Core | **Status**: WIP Alpha
**Last Updated**: November 2025
