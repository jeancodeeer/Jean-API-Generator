# Graph Report - Jean-API-Generator  (2026-11-15)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 301 nodes · 522 edges · 20 communities (13 shown, 7 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 6 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `cd23c99c`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- control_server.py
- project_map.py
- launch.py
- router.py
- test_router.py
- bench_humaneval.py
- .plan
- read_tensor_table
- EndToEnd
- SlotTable
- jean-api-generator.sh script
- serve.sh
- e2e_launch.sh
- Resolve
- jean-api-generator.ps1
- setup-vm.sh
- test_ctx.sh
- fenix_test1.sh
- probe_asset.sh
- test_github_source.sh

## God Nodes (most connected - your core abstractions)
1. `main()` - 18 edges
2. `EndToEnd` - 16 edges
3. `Handler` - 13 edges
4. `RouteError` - 13 edges
5. `load_job()` - 13 edges
6. `PlanSlots` - 10 edges
7. `main()` - 10 edges
8. `read_tensor_table()` - 10 edges
9. `Resolve` - 9 edges
10. `fake_llama()` - 9 edges

## Surprising Connections (you probably didn't know these)
- `hf_file_size()` --calls--> `json`  [EXTRACTED]
  control/control_server.py →   _Bridges community 0 → community 5_
- `main()` --calls--> `parse_models()`  [EXTRACTED]
  launch.py → launch.py  _Bridges community 2 → community 6_
- `requested_model()` --calls--> `json`  [EXTRACTED]
  control/router.py →   _Bridges community 3 → community 5_

## Import Cycles
- None detected.

## Communities (20 total, 7 thin omitted)

### Community 0 - "control_server.py"
Cohesion: 0.13
Nodes (15): alias_for(), Handler, hf_file_size(), launch(), load_job(), log(), meminfo(), read_env() (+7 more)

### Community 1 - "project_map.py"
Cohesion: 0.06
Nodes (18): api_router(), _api_url(), archivo_experimentos(), base_qwen_gguf(), config_opencode(), espejo_repo(), fuente_llama_cpp(), github_perfil() (+10 more)

### Community 2 - "launch.py"
Cohesion: 0.11
Nodes (22): again(), alias_of(), banner(), check_platform(), count_gpus(), download(), extract(), find_bin() (+14 more)

### Community 3 - "router.py"
Cohesion: 0.09
Nodes (11): forward(), models_payload(), _NoRedirect, rank(), relay(), relay_hosts(), relay_target(), requested_model() (+3 more)

### Community 4 - "test_router.py"
Cohesion: 0.11
Nodes (7): fake_llama(), do_GET(), do_POST(), send_json(), fake_provider(), free_port(), Relay

### Community 5 - "bench_humaneval.py"
Cohesion: 0.18
Nodes (8): served_models(), ask(), extract(), load_problems(), main(), run_tests(), sha256_file(), split()

### Community 6 - ".plan"
Cohesion: 0.16
Nodes (3): parse_models(), ParseModels, PlanSlots

### Community 7 - "read_tensor_table"
Cohesion: 0.23
Nodes (4): lora_target(), main(), read_tensor_table(), Reader

### Community 10 - "jean-api-generator.sh script"
Cohesion: 0.40
Nodes (9): fenix_pick(), find_server(), install_llama(), model_ctx(), model_file(), model_port(), model_ram(), jean-api-generator.sh script (+1 more)

### Community 11 - "serve.sh"
Cohesion: 0.39
Nodes (8): download_github(), fail(), fenix_pick(), find_server(), hf_get(), install_llama(), LLAMA_API_KEY, serve.sh script

### Community 12 - "e2e_launch.sh"
Cohesion: 0.25
Nodes (7): fail(), JEAN_API_KEY, JEAN_CTX, JEAN_MAX_HOURS, JEAN_MODELS, JEAN_TUNNEL, e2e_launch.sh script

### Community 14 - "jean-api-generator.ps1"
Cohesion: 0.60
Nodes (3): Get-HfFile(), Get-LlamaServer(), Log()

### Community 15 - "setup-vm.sh"
Cohesion: 0.70
Nodes (4): model_ctx(), model_file(), model_port(), setup-vm.sh script

## Knowledge Gaps
- **6 isolated node(s):** `LLAMA_API_KEY`, `JEAN_API_KEY`, `JEAN_CTX`, `JEAN_MAX_HOURS`, `JEAN_MODELS` (+1 more)
  These have ≤1 connection - possible missing edges. (Counts symbols only; 106 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **7 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `EndToEnd` connect `EndToEnd` to `test_router.py`?**
  _High betweenness centrality (0.077) - this node is a cross-community bridge._
- **What connects `LLAMA_API_KEY`, `JEAN_API_KEY`, `JEAN_CTX` to the rest of the system?**
  _6 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `control_server.py` be split into smaller, more focused modules?**
  _Cohesion score 0.12802275960170698 - nodes in this community are weakly interconnected._
- **Why does `SlotTable` connect `SlotTable` to `router.py`?**
  _High betweenness centrality (0.050) - this node is a cross-community bridge._
- **Should `project_map.py` be split into smaller, more focused modules?**
  _Cohesion score 0.05555555555555555 - nodes in this community are weakly interconnected._
- **Why does `Resolve` connect `Resolve` to `test_router.py`?**
  _High betweenness centrality (0.044) - this node is a cross-community bridge._
- **Should `launch.py` be split into smaller, more focused modules?**
  _Cohesion score 0.10795454545454546 - nodes in this community are weakly interconnected._