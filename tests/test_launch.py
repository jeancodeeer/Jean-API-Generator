"""Pruebas del lanzador (launch.py): qué modelo va a qué puerto y a qué GPU."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import launch  # noqa: E402


class ParseModels(unittest.TestCase):
    def test_default_is_grey_and_marvel(self):
        self.assertEqual([m["name"] for m in launch.parse_models("")], ["grey", "marvel"])

    def test_hf_and_file(self):
        ms = launch.parse_models("hf:unsloth/Qwen3-4B-GGUF/Qwen3-4B-Q4_K_M.gguf, file:/kaggle/input/mio/m.gguf")
        self.assertEqual(ms[0], {"kind": "hf", "repo": "unsloth/Qwen3-4B-GGUF", "file": "Qwen3-4B-Q4_K_M.gguf"})
        self.assertEqual(ms[1], {"kind": "file", "path": "/kaggle/input/mio/m.gguf"})

    def test_hf_file_in_subfolder(self):
        m = launch.parse_models("hf:a/b/Q4/x-00001-of-00002.gguf")[0]
        self.assertEqual((m["repo"], m["file"]), ("a/b", "Q4/x-00001-of-00002.gguf"))

    def test_rejects_bad_input(self):
        for bad in ("gpt-4", "hf:solo/repo", "hf:a/b/c.bin", "file:/x/model.bin"):
            with self.assertRaises(ValueError, msg=bad):
                launch.parse_models(bad)


class PlanSlots(unittest.TestCase):
    def plan(self, spec, gpus, is_free=None):
        return launch.plan_slots(launch.parse_models(spec), gpus=gpus, is_free=is_free or (lambda p: True))

    def test_skips_busy_ports_like_kaggle_jupyter(self):
        p = self.plan("grey,marvel", 2, is_free=lambda port: port != 8888)
        self.assertEqual([s["port"] for s in p], [8889, 8890])

    def test_never_uses_the_router_port(self):
        p = self.plan(",".join(["grey"] * 10), 2)
        self.assertNotIn(8899, [s["port"] for s in p])

    def test_two_models_one_gpu_each(self):
        p = self.plan("grey,marvel", 2)
        self.assertEqual([(s["port"], s["gpu"], s["alias"]) for s in p],
                         [(8888, "0", "jean-grey"), (8889, "1", "jean-marvel")])

    def test_fenix_uses_both_gpus(self):
        p = self.plan("fenix", 2)
        self.assertEqual(p[0]["gpu"], "0,1")

    def test_single_model_uses_all_gpus(self):
        p = self.plan("hf:a/b/Big-Model.Q4.gguf", 2)
        self.assertEqual((p[0]["gpu"], p[0]["alias"]), ("0,1", "big-model.q4"))

    def test_without_gpu_runs_on_cpu(self):
        p = self.plan("grey,marvel", 0)
        self.assertEqual([s["gpu"] for s in p], ["", ""])

    def test_three_models_share_two_gpus(self):
        p = self.plan("grey,marvel,hf:a/b/c.gguf", 2)
        self.assertEqual([s["gpu"] for s in p], ["0", "1", "0"])

    def test_router_port_is_never_taken(self):
        with self.assertRaises(ValueError):
            self.plan(",".join(["grey"] * 12), 2)


if __name__ == "__main__":
    unittest.main()
