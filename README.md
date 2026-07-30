# MVision

> [English](README.md) | [简体中文](README.zh-CN.md)

Cross-platform AI knowledge client — connect your own storage and let AI automatically turn scattered materials into a beautiful, readable, searchable, and continuously evolving personal Wiki.

## Product Vision

The "Infuse of knowledge": users connect their own local directory or cloud storage; the app scans the Markdown, PDF, images and other materials within, builds a local index, and an LLM continuously compiles the raw materials into an interlinked, traceable, auditable personal Wiki.

## Features

### Core Knowledge Base (Obsidian-like)

- **Vault model** — single vault directory, replacing the multi-source architecture
- **File explorer** — tree sidebar with expand/collapse and context menu
- **Backlinks** — link mentions + outbound links panel
- **Tag system** — `#tag` parsing + YAML frontmatter + tag panel
- **Quick switcher** — `⌘O` fuzzy search + recent files
- **Command palette** — `⌘K` extensible command registry
- **Graph view** — force-directed graph visualization with zoom/pan/click interaction

### Editor

- Markdown syntax highlighting (headings, bold, italic, code, links)
- `[[Wiki-link autocompletion]]` with a note-list popup
- Side-by-side edit/preview split mode
- Word count + reading time
- `![[embed]]` to embed another note's content
- Edit history (auto snapshots + rollback)

### AI Features (BYOK)

- **Wiki compilation** — select source docs, AI generates a structured Wiki with Patch application
- **Knowledge Q&A** — retrieves relevant docs via FTS, AI answers with source citations
- **Streaming responses** — real-time per-token display via SSE
- Supports any OpenAI-compatible API

### Other

- Daily notes (`daily/YYYY-MM-DD.md`)
- Template insertion (`templates/` folder)
- Favorites / starred notes
- Split view (draggable divider)
- Rename auto-updates all reference links
- Baidu Netdisk sync (OAuth / BDUSS dual mode)

## Platforms

| Platform | Status |
|----------|--------|
| macOS | ✅ Primary dev platform |
| Windows | ✅ Supported |
| iOS / iPadOS | ✅ Mobile shell |
| Android | ✅ Mobile shell |
| HarmonyOS NEXT | TBD |

## Tech Stack

| Layer | Technology |
|-------|------------|
| UI | Flutter (Material 3) |
| State management | Riverpod (StateNotifier) |
| Routing | go_router |
| Local database | SQLite (sqlite3) + FTS5 |
| Networking | Dio |
| AI | OpenAI-compatible API (BYOK) |
| Secure storage | flutter_secure_storage |
| Design system | Custom tokens (AppColors, AppSpacing, AppRadius) |

## Project Structure

```
├── apps/client/           # Flutter application entry
│   ├── lib/
│   │   ├── app/               # routing, providers
│   │   ├── desktop/           # desktop pages and components
│   │   │   ├── pages/         # pages (home, reader, editor, graph, ai...)
│   │   │   └── widgets/       # widgets (file_explorer, backlinks, palette...)
│   │   ├── mobile/            # mobile shell
│   │   ├── services/          # services (database, scanner, ai, sync)
│   │   └── shared/            # shared utilities (responsive, animations)
├── packages/              # shared packages
│   ├── design_system/         # design tokens
│   ├── knowledge_core/        # domain model
│   ├── markdown_engine/       # Markdown parsing
│   ├── markdown_reader/       # Markdown reader
│   ├── markdown_editor/       # Markdown editor
│   ├── search_engine/         # FTS5 search
│   ├── sync_engine/           # sync engine
│   ├── wiki_engine/           # LLM Wiki compilation
│   ├── platform_api/          # platform abstraction
│   └── connectors/            # data source connectors (baidu_connector)
├── docs/                  # documentation
│   ├── adr/                   # architecture decision records
│   └── ...
└── pubspec.yaml           # workspace config
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘O` | Quick switcher |
| `⌘K` | Command palette |
| `⌘N` | New note |
| `⌘S` | Save |
| `⌘\` | Toggle sidebar |
| `⌘,` | Settings |
| `⌘⇧F` | Global search |
| `⌘Z` / `⌘⇧Z` | Undo / Redo |

## Development

```bash
# Install dependencies
cd apps/client && flutter pub get

# Run (macOS)
flutter run -d macos

# Analyze
flutter analyze
```

## Documentation

- [Requirements](mvision-development-requirements.md) — product requirements (Chinese)
- [Architecture Decision Records](docs/adr/) — ADRs (Chinese)
- [Build Guide](build.md) — cross-platform build instructions

## License

TBD
