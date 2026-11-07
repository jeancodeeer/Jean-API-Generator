# Graph Report - codespaces-jean  (2026-11-06)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 90 nodes · 132 edges · 18 communities (7 shown, 11 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 5 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `beb0df74`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- set_secrets.py
- jean-api-generator.sh script
- check_lora.py
- read_tensor_table
- autostart.sh
- watchdog.sh
- serve.sh
- jean-api-generator.ps1
- setup-vm.sh
- test_ctx.sh
- mode-fenix.sh
- mode-standard.sh
- prep.sh
- diag.sh
- fenix_test1.sh
- probe_asset.sh
- test_fenix_lite.sh
- test_github_source.sh

## God Nodes (most connected - your core abstractions)
1. `read_tensor_table()` - 10 edges
2. `jean-api-generator.sh script` - 9 edges
3. `Reader` - 8 edges
4. `serve.sh script` - 5 edges
5. `split()` - 4 edges
6. `autostart.sh script` - 4 edges
7. `setup-vm.sh script` - 4 edges
8. `api()` - 3 edges
9. `main()` - 3 edges
10. `sha256_file()` - 3 edges

## Surprising Connections (you probably didn't know these)
- `main()` --calls--> `read_tensor_table()`  [EXTRACTED]
  tools/check_lora.py → tools/check_lora.py  _Bridges community 2 → community 3_

## Import Cycles
- None detected.

## Communities (18 total, 11 thin omitted)

### Community 0 - "set_secrets.py"
Cohesion: 0.23
Nodes (4): api(), main(), sha256_file(), split()

### Community 1 - "jean-api-generator.sh script"
Cohesion: 0.40
Nodes (9): fenix_pick(), find_server(), install_llama(), model_ctx(), model_file(), model_port(), model_ram(), jean-api-generator.sh script (+1 more)

### Community 4 - "autostart.sh"
Cohesion: 0.52
Nodes (6): install_cf(), publish_status(), autostart.sh script, start_model(), start_tunnel(), tunnel_url()

### Community 5 - "watchdog.sh"
Cohesion: 0.60
Nodes (5): check_model(), check_tunnel(), publish_urls(), watchdog.sh script, tunnel_url()

### Community 6 - "serve.sh"
Cohesion: 0.60
Nodes (5): download_github(), find_server(), hf_get(), install_llama(), serve.sh script

### Community 7 - "jean-api-generator.ps1"
Cohesion: 0.60
Nodes (3): Get-HfFile(), Get-LlamaServer(), Log()

### Community 8 - "setup-vm.sh"
Cohesion: 0.70
Nodes (4): model_ctx(), model_file(), model_port(), setup-vm.sh script

## Knowledge Gaps
- **11 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `read_tensor_table()` connect `read_tensor_table` to `check_lora.py`?**
  _High betweenness centrality (0.029) - this node is a cross-community bridge._
- **Are the 5 inferred relationships involving `read_tensor_table()` (e.g. with `.read()` and `.string()`) actually correct?**
  _`read_tensor_table()` has 5 INFERRED edges - model-reasoned connections that need verification._
- **Why does `Reader` connect `read_tensor_table` to `check_lora.py`?**
  _High betweenness centrality (0.017) - this node is a cross-community bridge._