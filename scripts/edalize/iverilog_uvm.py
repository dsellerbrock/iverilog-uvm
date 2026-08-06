# Custom edalize backend for the iverilog-uvm-opentitan fork
# Based on edalize/icarus.py but adapted for the custom iverilog-uvm install layout.
#
# Tool name: iverilog_uvm  (use with FuseSoC: --tool=iverilog_uvm)
#
# Key differences from stock icarus backend:
#   1. Uses driver/iverilog instead of system iverilog
#   2. Uses vvp/vvp instead of system vvp
#   3. Always passes -g2012 for SystemVerilog support
#   4. Passes -B. so iverilog finds its support files (ivl, ivlpp, etc.)
#   5. Configurable install prefix via IVERILOG_UVM_ROOT env var or tool_options

import os
import logging

from edalize.edatool import Edatool

logger = logging.getLogger(__name__)

MAKEFILE_TEMPLATE = """
all: $(VPI_MODULES) $(TARGET)

$(TARGET):
\t$(IVERILOG) $(TOPLEVEL) -c $(TARGET).scr -o $@ $(IVERILOG_OPTIONS)

run: $(VPI_MODULES) $(TARGET)
\t$(VVP) -n -M. -l icarus.log $(patsubst %.vpi,-m%,$(VPI_MODULES)) $(VVP_OPTIONS) $(TARGET) -fst $(EXTRA_OPTIONS)

clean:
\t$(RM) $(VPI_MODULES) $(TARGET)
"""

VPI_MAKE_SECTION = """
{name}_LIBS := {libs}
{name}_INCS := {incs}
{name}_SRCS := {srcs}

{name}.vpi: $({name}_SRCS)
\t$(IVERILOG_VPI) --name={name} $({name}_LIBS) $({name}_INCS) $?

clean_{name}:
\t$(RM) {name}.vpi
"""


class Iverilog_uvm(Edatool):

    argtypes = ["plusarg", "vlogdefine", "vlogparam"]

    @classmethod
    def get_doc(cls, api_ver):
        if api_ver == 0:
            return {
                "description": "Iverilog-uvm: A custom Icarus Verilog fork for OpenTitan/Caliptra UVM support. Supports SystemVerilog (-g2012) by default.",
                "members": [
                    {"name": "timescale",
                     "type": "String",
                     "desc": "Default timescale (e.g. 1ns/1ps)"},
                    {"name": "iverilog_root",
                     "type": "String",
                     "desc": "Path to iverilog-uvm install root (default: $IVERILOG_UVM_ROOT or auto-detect)"},
                ],
                "lists": [
                    {
                        "name": "iverilog_options",
                        "type": "String",
                        "desc": "Additional options for iverilog (already includes -g2012)",
                    },
                    {
                        "name": "vvp_options",
                        "type": "String",
                        "desc": "Additional options for vvp",
                    },
                ],
            }

    def _find_iverilog_root(self):
        """Find the iverilog-uvm install root."""
        # Check tool_options first
        root = self.tool_options.get("iverilog_root")
        if root:
            return root

        # Check environment variable
        root = os.environ.get("IVERILOG_UVM_ROOT")
        if root:
            return root

        # Auto-detect: walk up from this file to find iverilog-uvm-opentitan-upstream
        current = os.path.dirname(os.path.abspath(__file__))
        for _ in range(8):
            parent = os.path.dirname(current)
            if parent == current:
                break
            current = parent
            candidate = os.path.join(current, 'iverilog_uvm',
                                     'iverilog-uvm-opentitan-upstream')
            if os.path.isfile(os.path.join(candidate, 'driver', 'iverilog')):
                logger.info(f"Auto-detected iverilog-uvm at {candidate}")
                return candidate

        return None

    def _get_iverilog(self):
        """Get path to the iverilog driver."""
        root = self._find_iverilog_root()
        if root:
            iverilog = os.path.join(root, 'driver', 'iverilog')
            if os.path.isfile(iverilog):
                return iverilog
        return "iverilog"  # fallback to PATH

    def _get_ivl_dir(self):
        """Get the -B directory: where ivl, ivlpp, vpi modules, and vvp.conf live.
        
        Our iverilog-uvm fork uses a local-install layout:
          local-install/lib/ivl/ivl       (the compiler)
          local-install/lib/ivl/system.vpi (VPI modules)
          local-install/lib/ivl/vvp.conf   (config)
        """
        root = self._find_iverilog_root()
        if root:
            # Check local-install layout first
            candidates = [
                os.path.join(root, 'local-install', 'lib', 'ivl'),
                os.path.join(root),  # fallback: project root
            ]
            for c in candidates:
                if os.path.isfile(os.path.join(c, 'ivl')):
                    return c
        return None

    def _get_vvp(self):
        """Get path to the vvp runtime."""
        root = self._find_iverilog_root()
        if root:
            vvp = os.path.join(root, 'vvp', 'vvp')
            if os.path.isfile(vvp):
                return vvp
        return "vvp"  # fallback to PATH

    def _get_iverilog_vpi(self):
        """Get path to iverilog-vpi."""
        root = self._find_iverilog_root()
        if root:
            vpi = os.path.join(root, 'iverilog-vpi')
            if os.path.isfile(vpi):
                return vpi
        return "iverilog-vpi"  # fallback to PATH

    def configure_main(self):
        """Configure the build: write .scr file and Makefile."""
        (src_files, incdirs) = self._get_fileset_files()

        # Gather options
        iverilog = self._get_iverilog()
        ivl_dir = self._get_ivl_dir()
        vvp = self._get_vvp()
        iverilog_vpi = self._get_iverilog_vpi()

        # Always include -g2012 for SystemVerilog
        iverilog_opts = ["-g2012"]
        # Tell iverilog where to find the ivl binary and support files
        if ivl_dir:
            iverilog_opts.extend(["-B" + ivl_dir])
        user_opts = self.tool_options.get("iverilog_options", [])
        iverilog_opts.extend(user_opts)

        vvp_opts = self.tool_options.get("vvp_options", [])

        # Write the source file list (.scr file)
        scr_path = os.path.join(self.work_root, self.name + ".scr")
        with open(scr_path, "w") as f:
            # vlogdefines
            for key, value in self.vlogdefine.items():
                f.write("+define+{}={}\n".format(
                    key, self._param_value_str(value, "")))

            # vlogparams
            for key, value in self.vlogparam.items():
                for top in self.toplevel.split(" "):
                    f.write("+parameter+{}.{}={}\n".format(
                        top, key, self._param_value_str(value, '"')))

            # include dirs
            for incdir in incdirs:
                f.write("+incdir+" + incdir + "\n")

            # timescale
            timescale = self.tool_options.get("timescale")
            if timescale:
                ts_path = os.path.join(self.work_root, "timescale.v")
                with open(ts_path, "w") as tsfile:
                    tsfile.write("`timescale {}\n".format(timescale))
                f.write("timescale.v\n")

            # source files
            supported_file_types = [
                "verilogSource",
                "verilogSource-95",
                "verilogSource-2001",
                "verilogSource-2005",
                "systemVerilogSource",
                "systemVerilogSource-3.0",
                "systemVerilogSource-3.1",
                "systemVerilogSource-3.1a",
            ]
            for src_file in src_files:
                if src_file.file_type in supported_file_types:
                    f.write(src_file.name + "\n")
                elif src_file.file_type == "user":
                    pass
                else:
                    _s = "{} has unknown file type '{}'"
                    logger.warning(_s.format(
                        src_file.name, src_file.file_type))

        # Write the Makefile
        makefile_path = os.path.join(self.work_root, "Makefile")
        with open(makefile_path, "w") as f:
            f.write("TARGET           := {}\n".format(self.name))
            _vpi_modules = " ".join(
                [m["name"] + ".vpi" for m in self.vpi_modules])
            if _vpi_modules:
                f.write("VPI_MODULES      := {}\n".format(_vpi_modules))

            f.write("IVERILOG         := {}\n".format(iverilog))
            f.write("VVP              := {}\n".format(vvp))
            f.write("IVERILOG_VPI     := {}\n".format(iverilog_vpi))

            f.write("TOPLEVEL         := {}\n".format(
                " ".join(["-s" + x for x in self.toplevel.split()])))

            f.write("IVERILOG_OPTIONS := {}\n".format(
                " ".join(iverilog_opts)))
            f.write("VVP_OPTIONS := {}\n".format(" ".join(vvp_opts)))

            if self.plusarg:
                plusargs = []
                for key, value in self.plusarg.items():
                    plusargs += ["+{}={}".format(
                        key, self._param_value_str(value))]
                f.write("EXTRA_OPTIONS    ?= {}\n".format(
                    " ".join(plusargs)))

            f.write(MAKEFILE_TEMPLATE)

            for vpi_module in self.vpi_modules:
                _incs = ["-I" + s for s in vpi_module["include_dirs"]]
                _libs = ["-l" + l for l in vpi_module["libs"]]
                _srcs = vpi_module["src_files"]
                f.write(
                    VPI_MAKE_SECTION.format(
                        name=vpi_module["name"],
                        libs=" ".join(_libs),
                        incs=" ".join(_incs),
                        srcs=" ".join(_srcs),
                    )
                )

    def run_main(self):
        args = ["run"]

        # Set plusargs
        if self.plusarg:
            plusargs = []
            for key, value in self.plusarg.items():
                plusargs += ["+{}={}".format(
                    key, self._param_value_str(value))]
            args.append("EXTRA_OPTIONS=" + " ".join(plusargs))

        self._run_tool("make", args)
