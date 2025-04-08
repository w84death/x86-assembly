# GAME12 Engine Function Map

This document provides a map of all functions in the GAME12 engine, showing when they are fired and in what order. This map helps understand the high-level architecture and flow of the game engine.

## Core Engine Flow

```
start
  │
  ├── Initialize VGA mode (0x13)
  │   └── Set video mode 320x200, 256 colors
  │
  ├── Initialize memory segments
  │   ├── Set ES to VGA memory (0xA000)
  │   └── Set stack (SS:SP to 0x9000:0xFFFF)
  │
  ├── initialize_custom_palette
  │   └── Load DawnBringer 16 color palette
  │
  ├── Set initial game state (STATE_INIT_ENGINE)
  │
  ├── main_loop ◄────────────────────────────────┐
  │   │                                           │
  │   ├── Process current game state              │
  │   │   └── Jump via StateJumpTable to handler  │
  │   │                                           │
  │   ├── Handle keyboard input                   │
  │   │   ├── Check state transitions             │
  │   │   └── Handle game-specific input          │
  │   │                                           │
  │   ├── wait_for_tick                           │
  │   │   └── Synchronize to system timer         │
  │   │                                           │
  │   └── Loop back ─────────────────────────────►│
  │
  └── exit
      ├── stop_sound
      ├── Set text mode (0x03)
      ├── Display exit message
      └── Return to DOS
```

## Game State Handlers

```
StateJumpTable:
  ├── init_engine             # Initialize engine components
  ├── exit                    # Exit to DOS
  ├── init_title_screen       # Set up title screen
  ├── live_title_screen       # Animate title screen
  ├── init_menu               # Set up menu
  ├── live_menu               # Process menu
  ├── new_game                # Create new game
  ├── init_game               # Initialize gameplay
  ├── live_game               # Main gameplay loop
  ├── init_map_view           # Set up map view
  ├── live_map_view           # Process map view
  ├── init_debug_view         # Set up debug view
  └── live_debug_view         # Process debug view
```

## State Transition Flow

```
Title Screen ──► Menu ──► Game ──► Map View
    │            │         │         │
    │            │         │         │
    └────────────┴────┬────┴─────────┘
                      │
                      ▼
                     Exit
```

## Initialization Functions

```
init_engine
  │
  ├── reset_to_default_values
  │   └── Initialize game variables & memory
  │
  ├── init_sound
  │   └── Configure PC speaker
  │
  ├── decompress_tiles
  │   └── Decompress sprite data to memory
  │
  ├── generate_map
  │   └── Create procedural terrain
  │
  └── init_gameplay_elements
      └── Set initial game objects
```

## Rendering Pipeline

```
draw_terrain
  │
  ├── Calculate viewport window from map
  │
  ├── Draw terrain tiles
  │   └── draw_tile for each visible map cell
  │
  ├── Draw transport elements
  │   └── draw_transport for railroad tiles
  │
  └── Draw UI border

draw_entities
  │
  ├── Check each entity against viewport
  │
  ├── Calculate screen position
  │
  └── Draw sprites
      └── draw_sprite for each visible entity

draw_cursor
  │
  └── Draw cursor at current position
      └── draw_sprite with appropriate cursor type

draw_ui
  │
  ├── Draw UI background
  │
  ├── Draw resource counts
  │
  └── Draw current mode information
```

## User Input Processing

```
check_keyboard
  │
  ├── Process state transitions from StateTransitionTable
  │
  └── If in STATE_GAME
      │
      ├── MODE_VIEWPORT_PANNING
      │   │
      │   ├── Move viewport with arrow keys
      │   │   └── Update _VIEWPORT_X_ and _VIEWPORT_Y_
      │   │
      │   └── Redraw terrain when moved
      │
      └── MODE_TRACKS_PLACING
          │
          ├── Move cursor with arrow keys
          │   └── Update _CURSOR_X_ and _CURSOR_Y_
          │
          ├── Place railroad with spacebar
          │   │
          │   ├── Check economy resources
          │   │
          │   └── Update map with META_TRANSPORT flag
          │
          └── Redraw affected tiles
```

## Map Generation

```
generate_map
  │
  ├── Create initial terrain
  │   └── Use TerrainRules for procedural generation
  │
  └── Apply metadata
      └── Set collision flags for obstacles
```

## Entity System

```
init_entities
  │
  └── Create initial entities with random positions

init_gameplay_elements
  │
  ├── Create initial railroad tracks
  │
  └── Create initial carts with resources
```

## UI Functions

```
draw_minimap
  │
  ├── Draw minimap frame
  │
  ├── Draw terrain on minimap
  │
  ├── Draw entities on minimap
  │
  └── Draw viewport box

draw_ui
  │
  ├── Draw UI background
  │
  ├── Draw resource counters
  │   ├── Railroad tracks
  │   ├── Blue resources
  │   ├── Yellow resources
  │   ├── Red resources
  │   └── Score
  │
  └── Draw UI text elements
```

## Memory Management

```
Memory Layout:
_BASE_         0x2000    # Start of memory
_GAME_TICK_    +0x00     # 2 bytes
_GAME_STATE_   +0x02     # 1 byte
_RNG_          +0x03     # 2 bytes
_VIEWPORT_X_   +0x05     # 2 bytes
_VIEWPORT_Y_   +0x07     # 2 bytes
_CURSOR_X_     +0x09     # 2 bytes
_CURSOR_Y_     +0x0B     # 2 bytes
_INTERACTION_MODE_ +0x0D # 1 byte
_ECONOMY_TRACKS_ +0x0E   # 2 bytes
_ECONOMY_*_RES_ +0x10    # 2 bytes each
_TILES_        +0x20     # 40 tiles = 10K
_MAP_          +0x4820   # Map data 128*128*1b
_METADATA_     +0x8820   # Map metadata 128*128*1b
_ENTITIES_     +0xC820   # Entities data 128*128*1b
```

## Helper Functions

```
get_random            # Generate pseudo-random number
clear_screen          # Fill screen with solid color
draw_gradient         # Draw color gradient effect
draw_text             # Draw text string at position
draw_number           # Draw numeric value at position
play_sound            # Trigger PC speaker sound
stop_sound            # Stop PC speaker sound
```

## Sprite Rendering

```
decompress_sprite
  │
  └── Decompress RLE-encoded sprite data

draw_sprite
  │
  ├── Calculate sprite position
  │
  └── Draw non-transparent pixels

draw_tile
  │
  └── Fast blit full tile to screen

draw_transport
  │
  ├── Calculate railroad connections
  │
  └── Draw appropriate railroad sprite
```

## Game Loop Timing

```
wait_for_tick
  │
  ├── Get current system timer tick
  │
  ├── Wait until tick changes
  │
  ├── stop_sound (clear PC speaker)
  │
  └── Increment _GAME_TICK_
```