#!/usr/bin/env python3
"""Lo llama kaggle/jean-api.ipynb (también los notebooks ya importados). El lanzador está en ../launch.py."""
import os
import runpy

runpy.run_path(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "launch.py"),
               run_name="__main__")
