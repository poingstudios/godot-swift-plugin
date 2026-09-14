# Sample & Testbed Project

The repository includes a complete, standalone sample implementation under `example/` demonstrating:
- Primitive passing & returning
- String conversions
- Dictionary (`[String: Any]`) returns and signal payloads
- Multi-argument and parameterless signal emissions
- SOLID architecture with isolated service layers

## Directory Structure

```
example/
├── ios/                  # Isolated Swift Package
│   ├── Package.swift     # Depends on local ../../ (GodotSwiftPlugin)
│   ├── Sources/
│   │   └── GodotExamplePlugin/
│   ├── Tests/            # Swift unit tests (including mock service injection)
│   └── scripts/
│       └── build_local.sh
└── godot_editor/         # Godot 4.7.2 testbed project
    ├── project.godot
    ├── addons/example_plugin/
    └── sample/
        ├── sample.tscn   # Interactive testbed UI
        └── sample.gd     # UI logic with automated headless verification
```

## Running the Sample

### 1. Build the Native macOS Dylib
```bash
./example/ios/scripts/build_local.sh
```

### 2. Run in Godot
Open `example/godot_editor/project.godot` in Godot 4.6+, or run headless:

```bash
godot --path example/godot_editor --headless --quit-after 5
```
