#!/usr/bin/env python3
"""HumanEval (OpenAI, MIT) contra cualquier API compatible con OpenAI: pass@1 con temperatura 0.

Reproducible: mismos problemas (los N primeros o todos), misma instrucción, temperatura 0.
EJECUTA el código que escribe el modelo (en un proceso aparte, con límite de tiempo): úsalo dentro
del Codespace o de un contenedor, no en tu PC personal.

  python3 tests/bench_humaneval.py --base-url http://localhost:8899/v1 --model jean-grey --n 40
  (la clave sale de JEAN_API_KEY; el resultado se guarda en bench/humaneval-<modelo>.json)
"""
import argparse, gzip, json, os, re, subprocess, sys, tempfile, time, urllib.request

DATA_URL = "https://github.com/openai/human-eval/raw/master/data/HumanEval.jsonl.gz"
SYSTEM = "You are a Python expert. Complete the function. Reply with ONE ```python code block containing the full function (signature included) and any imports it needs. No explanations."


def load_problems(cache):
    if not os.path.exists(cache):
        urllib.request.urlretrieve(DATA_URL, cache)
    with gzip.open(cache, "rt", encoding="utf-8") as f:
        return [json.loads(line) for line in f if line.strip()]


def ask(base, key, model, prompt, max_tokens, timeout):
    body = json.dumps({"model": model, "temperature": 0, "max_tokens": max_tokens, "stream": False,
                       "messages": [{"role": "system", "content": SYSTEM}, {"role": "user", "content": prompt}],
                       "chat_template_kwargs": {"enable_thinking": False}}).encode()
    req = urllib.request.Request(f"{base}/chat/completions", data=body, method="POST",
                                 headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        j = json.loads(r.read())
    return j["choices"][0]["message"]["content"] or "", j.get("usage", {})


def extract(answer, prompt):
    blocks = re.findall(r"```(?:python|py)?\s*\n(.*?)```", answer, re.S)
    code = max(blocks, key=len) if blocks else answer
    # si el modelo solo devolvió el cuerpo, se le antepone el prompt (firma y docstring)
    return code if re.search(r"^\s*def\s", code, re.M) else prompt + code


def run_tests(code, problem, timeout=10):
    program = f"{code}\n\n{problem['test']}\n\ncheck({problem['entry_point']})\n"
    with tempfile.TemporaryDirectory() as d:
        path = os.path.join(d, "t.py")
        with open(path, "w", encoding="utf-8") as f:
            f.write(program)
        try:
            r = subprocess.run([sys.executable, path], cwd=d, capture_output=True, timeout=timeout, text=True)
            return r.returncode == 0, (r.stderr or "")[-300:]
        except subprocess.TimeoutExpired:
            return False, "tiempo agotado"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base-url", default="http://localhost:8899/v1")
    ap.add_argument("--model", required=True)
    ap.add_argument("--n", type=int, default=0, help="los N primeros problemas (0 = los 164)")
    ap.add_argument("--max-tokens", type=int, default=512)
    ap.add_argument("--timeout", type=int, default=300)
    ap.add_argument("--out", default="bench")
    a = ap.parse_args()
    key = os.environ.get("JEAN_API_KEY", "")
    problems = load_problems(os.path.join(tempfile.gettempdir(), "HumanEval.jsonl.gz"))
    if a.n:
        problems = problems[: a.n]
    os.makedirs(a.out, exist_ok=True)
    results, passed, t0, toks = [], 0, time.time(), 0
    for i, p in enumerate(problems, 1):
        s = time.time()
        try:
            answer, usage = ask(a.base_url.rstrip("/"), key, a.model, p["prompt"], a.max_tokens, a.timeout)
            ok, err = run_tests(extract(answer, p["prompt"]), p)
            toks += int(usage.get("completion_tokens") or 0)
        except Exception as e:  # la API cayó o tardó: cuenta como fallo, se anota el motivo
            ok, err = False, f"API: {type(e).__name__}: {e}"[:300]
        passed += ok
        results.append({"task": p["task_id"], "passed": ok, "seconds": round(time.time() - s, 1), "error": "" if ok else err})
        print(f"[{i}/{len(problems)}] {p['task_id']}: {'OK' if ok else 'fallo'} · acumulado {passed}/{i}", flush=True)
    summary = {"benchmark": "HumanEval (openai/human-eval)", "model": a.model, "problems": len(problems),
               "subset": f"los {len(problems)} primeros" if a.n else "completo (164)", "passed": passed,
               "pass@1": round(passed / len(problems), 4), "temperature": 0, "thinking": False,
               "minutes": round((time.time() - t0) / 60, 1), "completion_tokens": toks,
               "date": time.strftime("%Y-%m-%d"), "results": results}
    out = os.path.join(a.out, f"humaneval-{a.model}.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=1, ensure_ascii=False)
    print(json.dumps({k: v for k, v in summary.items() if k != "results"}, ensure_ascii=False))


if __name__ == "__main__":
    main()
