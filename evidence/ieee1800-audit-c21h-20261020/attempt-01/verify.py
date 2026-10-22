import pathlib
import sys


def references(path):
    return [
        line.split()[4]
        for line in path.read_text().splitlines()
        if line.startswith("$var ")
    ]


root = pathlib.Path(sys.argv[1])
for edition in ("2017", "2023"):
    noargs = references(root / edition / "dumpvars_noargs.vcd")
    selectors = references(root / edition / "dumpvars_selectors.vcd")
    assert {"root_value", "a", "b"} <= set(noargs), (edition, noargs)
    assert noargs.count("a") == 1 and noargs.count("b") == 1, (edition, noargs)
    assert "root_value" not in selectors, (edition, selectors)
    assert selectors.count("a") == 1 and selectors.count("b") == 2, (edition, selectors)
print("PASS: $dumpvars no-argument and mixed-scope selection in both editions")
