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
├── apple/                # Isolated Swift Package
│   ├── Package.swift     # Depends on local ../../ (GodotSwiftPlugin)
│   ├── Sources/
│   │   └── GodotExamplePlugin/
│   └── Tests/            # Swift unit tests (mock service injection)
└── godot_editor/         # Godot testbed project
    ├── project.godot
    ├── addons/example_plugin/
    └── sample/
        ├── sample.tscn   # Interactive testbed UI
        └── sample.gd     # UI logic with automated headless verification
```

## Running the Sample

### 1. Build the Native Binaries

```bash
./scripts/build_local.sh all
```

Or using native Swift Package Manager inside `example/apple`:
```bash
cd example/apple && swift package --disable-sandbox --allow-writing-to-package-directory godot-build all
```

### 2. Run in Godot Editor

Interactive:
```bash
./scripts/run_example.sh
```

Headless automated test:
```bash
./scripts/run_example.sh --headless --quit-after 1
```
