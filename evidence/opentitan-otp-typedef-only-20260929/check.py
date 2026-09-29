#!/usr/bin/env python3
"""Check bit method signatures of late, typedef-reached class specializations."""
import pathlib
import re
import subprocess
import sys
import tempfile

source = pathlib.Path(__file__).with_name("probe.sv")
driver, lib, modules = sys.argv[1:]
for edition in ("2017", "2023"):
    with tempfile.TemporaryDirectory(prefix="dd089-method-") as tmp:
        image = pathlib.Path(tmp) / "probe.vvp"
        subprocess.run([driver, "-B", lib, "-B", f"M{modules}",
                        f"-g{edition}", "-gstrict-expr-width", "-s", "top",
                        "-o", str(image), str(source)], check=True)
        lines = [line for line in image.read_text().splitlines()
                 if re.search(r'\.scope autofunction\..*"exists"', line)]
        assert len(lines) == 4, (edition, lines)
        assert all("autofunction.vec2.s1" in line for line in lines), (edition, lines)
        print(f"{edition}: 4 bit method signatures")
