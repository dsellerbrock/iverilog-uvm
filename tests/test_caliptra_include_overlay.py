import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import sys


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "caliptra_include_overlay.py"
SPEC = importlib.util.spec_from_file_location("caliptra_include_overlay", SCRIPT)
overlay = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(overlay)

CORPUS_ROOT = None
if "--corpus-root" in sys.argv:
    argument = sys.argv.index("--corpus-root")
    try:
        CORPUS_ROOT = Path(sys.argv[argument + 1]).resolve()
    except IndexError as error:
        raise SystemExit("--corpus-root requires a path") from error
    del sys.argv[argument:argument + 2]


class IncludeOverlayTest(unittest.TestCase):
    def write_provider(self, root, directory, name, requires=()):
        base = root / directory
        (base / "config").mkdir(parents=True)
        (base / "rtl").mkdir()
        (base / "config" / "compile.yml").write_text(
            "---\nprovides: [%s]\nrequires: [%s]\ntargets:\n  rtl:\n"
            "    directories: [$COMPILE_ROOT/rtl]\n"
            % (name, ", ".join(requires))
        )

    def test_dependency_order_overlay_and_directory_deduplication(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write_provider(root, "pkg", "abr_prim_pkg")
            self.write_provider(root, "libs", "abr_libs", ["common"])
            self.write_provider(root, "common", "common")
            providers = overlay.load_providers(root, {})
            # Exercise directory deduplication without weakening provider ordering.
            providers["abr_libs"]["rtl_directories"] = providers["common"]["rtl_directories"]
            result = overlay.resolve(providers, ["abr_libs"])
            self.assertEqual(result["providers"], ["common", "abr_prim_pkg", "abr_libs"])
            self.assertEqual(len(result["directories"]), 2)

    def test_missing_cycle_duplicate_variable_and_directory_are_errors(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write_provider(root, "a", "a", ["missing"])
            with self.assertRaisesRegex(overlay.OverlayError, "missing provider"):
                overlay.resolve(overlay.load_providers(root, {}), ["a"], {})
            self.write_provider(root, "b", "b", ["a"])
            providers = overlay.load_providers(root, {})
            providers["a"]["requires"] = ["b"]
            with self.assertRaisesRegex(overlay.OverlayError, "provider cycle"):
                overlay.resolve(providers, ["a"], {})

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write_provider(root, "a", "same")
            self.write_provider(root, "b", "same")
            with self.assertRaisesRegex(overlay.OverlayError, "duplicate provider"):
                overlay.load_providers(root, {})

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            config = root / "a" / "config"
            config.mkdir(parents=True)
            (config / "compile.yml").write_text(
                "provides: [a]\ntargets:\n  rtl:\n    directories: [$UNKNOWN/rtl]\n"
            )
            with self.assertRaisesRegex(overlay.OverlayError, "unexpanded variable"):
                overlay.load_providers(root, {})
            (config / "compile.yml").write_text(
                "provides: [a]\ntargets:\n  rtl:\n    directories: [$COMPILE_ROOT/missing]\n"
            )
            with self.assertRaisesRegex(overlay.OverlayError, "nonexistent RTL directory"):
                overlay.load_providers(root, {})

    def test_compile_root_expansion(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write_provider(root, "unit", "unit")
            provider = overlay.load_providers(root, {})["unit"]
            self.assertEqual(provider["rtl_directories"], [str((root / "unit" / "rtl").resolve())])

    def test_explicit_environment_expansion(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            rtl = root / "external" / "rtl"
            rtl.mkdir(parents=True)
            config = root / "unit" / "config"
            config.mkdir(parents=True)
            (config / "compile.yml").write_text(
                "provides: [unit]\ntargets:\n  rtl:\n    directories: [$RTL_HOME/rtl]\n"
            )
            provider = overlay.load_providers(root, {"RTL_HOME": str(root / "external")})["unit"]
            self.assertEqual(provider["rtl_directories"], [str(rtl.resolve())])

    def test_relative_directory_is_an_error(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            config = root / "unit" / "config"
            config.mkdir(parents=True)
            (config / "compile.yml").write_text(
                "provides: [unit]\ntargets:\n  rtl:\n    directories: [rtl]\n"
            )
            with self.assertRaisesRegex(overlay.OverlayError, "relative RTL directory"):
                overlay.load_providers(root, {})


if CORPUS_ROOT is not None:
    def test_frozen_caliptra_overlay_covers_exact_header_jobs(self):
        groups = {
            "abr": (
                "abr_libs", "abr_prim_generic", "rej_sampler", "rej_bounded",
                "exp_mask", "sample_in_ball", "cbd_sampler", "decompose",
                "decompose_tb", "compress", "compress_tb", "decompress",
                "skencode", "skencode_tb", "skdecode", "skdecode_tb",
                "makehint", "makehint_tb", "sigencode_z", "sigencode_z_tb",
                "sigdecode_z", "sigdecode_z_tb", "sigdecode_h", "sigdecode_h_tb",
                "pkdecode", "pkdecode_tb", "power2round", "power2round_tb",
                "ntt_pkg", "ntt_top", "ntt_top_tb", "barrett_reduction",
            ),
            "prim": ("pcrvault", "datavault", "axi_sub", "caliptra_axi_sram",
                     "caliptra_prim_generic"),
            "reg": ("aes", "csrng", "csrng_tb"),
        }
        suffixes = {
            "abr": "/submodules/adams-bridge/src/abr_prim/rtl",
            "prim": "/src/caliptra_prim/rtl",
            "reg": "/src/integration/rtl/caliptra_reg",
        }
        self.assertTrue(CORPUS_ROOT.is_dir(), f"missing corpus {CORPUS_ROOT}")
        self.assertEqual(sum(map(len, groups.values())), 40)
        providers = overlay.load_providers(CORPUS_ROOT)
        for group, jobs in groups.items():
            for job in jobs:
                result = overlay.resolve(providers, [job])
                self.assertTrue(any(path.endswith(suffixes[group])
                                    for path in result["directories"]), job)
                self.assertFalse(any(path.endswith("/caliptra_reg_ss")
                                     for path in result["directories"]), job)

    setattr(IncludeOverlayTest, "test_frozen_caliptra_overlay_covers_exact_header_jobs",
            test_frozen_caliptra_overlay_covers_exact_header_jobs)


if __name__ == "__main__":
    unittest.main()
