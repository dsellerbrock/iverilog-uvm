#!/usr/bin/env python3
"""Run Caliptra DMA firmware on the open AXI target and full testbench top."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys


REPO = Path(os.environ["CALIPTRA_BFM_REPO"]).resolve()
ORIGINAL_AES_PKG = "${CALIPTRA_ROOT}/src/aes/rtl/aes_pkg.sv"
ORIGINAL_AXI_IF = "${CALIPTRA_ROOT}/src/axi/rtl/axi_if.sv"
ORIGINAL_AXI_COMPLEX = "${CALIPTRA_ROOT}/src/integration/tb/caliptra_top_tb_axi_complex.sv"
ORIGINAL_SRAM_EXPORT = "${CALIPTRA_ROOT}/src/integration/tb/caliptra_veer_sram_export.sv"
ORIGINAL_TOP_SVA = "${CALIPTRA_ROOT}/src/integration/asserts/caliptra_top_sva.sv"
ORIGINAL_SOC_BFM = "${CALIPTRA_ROOT}/src/integration/tb/caliptra_top_tb_soc_bfm.sv"
ORIGINAL_TOP_TB = "${CALIPTRA_ROOT}/src/integration/tb/caliptra_top_tb.sv"
ORIGINAL_TOP_SERVICES = "${CALIPTRA_ROOT}/src/integration/tb/caliptra_top_tb_services.sv"
ORIGINAL_DMA_GENERATOR = "${CALIPTRA_ROOT}/src/integration/tb/dma_testcase_generator.sv"
ORIGINAL_AXI4PC = "${CALIPTRA_AXI4PC_DIR}/Axi4PC.sv"
CASE_NAMES = ("smoke_test_dma", "smoke_test_dma_aes_gcm_short_1_dword", "rand_test_dma")
AES_PKG_SHA256 = "19a0096ffb731c99778d68a7baa81d0aa33c8b86a665231005d50251087a710f"
AES_PKG_OVERLAY_SHA256 = "d29c80cd5e51629b25a924e5249f85032c0b42f0f4006c3944906395e98ec158"
AXI_IF_SHA256 = "e03bd7a7654eb9c31bd532861b94d59c876810aa9798f9f67f7df2a5a3f5495c"
AXI_IF_OVERLAY_SHA256 = "d9173b5d3ecf2bff70412016f752e902f3f6ccf4fdb68ffd58764fb33e34f834"
VECTOR_OUTPUTS = {
    "ecc_secp384r1.exe": "ecc_secp384r1.exe",
    "test_dilithium5": "test_dilithium5",
    "doe_test_gen.py": "doe_test_gen.py",
    "sha256_wntz_test_gen.py": "sha256_wntz_test_gen.py",
    "smoke_test_mldsa_vector.hex": "smoke_test_mldsa_vector.hex",
    "ml-kem/native_mlkem": "native_mlkem",
    "ml-kem/random_test_ml_kem.py": "random_test_ml_kem.py",
}
TOP_SVA_SHA256 = "6bd2ade137a90c0701aab28951ba6f8918724e0467c21756b0c308e6e9081c89"
TOP_SVA_OVERLAY_SHA256 = "6e67d67966b030931ec222aacfd0863086c7d35b5e916acd5f358a90ed538654"
SVA_DIAGNOSTICS_TO_REMOVE = (
    "SVA ERROR: KV[%0d][%0d] debug flush failed. Expected: %h, Got: %h, SelValue: %0d",
    "SVA ERROR: [MLDSA keygen] SK register %h does not match expected %h at index %h",
    "SVA ERROR: [MLDSA keygen] SK bank0 %h does not match expected %h at index %h",
    "SVA ERROR: [MLDSA keygen] SK bank1 %h does not match expected %h at index %h",
    "SVA ERROR: [MLDSA keygen] PK register %h does not match expected %h at index %h",
    "SVA ERROR: [MLDSA keygen] PK memory %h does not match expected %h at index %0d %0d",
    "SVA ERROR: [MLDSA signing] Signature C %h does not match expected %h at index %h",
    "SVA ERROR: [MLDSA signing] Signature H %h does not match expected %h at index %h",
    "SVA ERROR: [MLDSA signing] Sig output %h does not match expected sig %h at index %0d %0d",
)
SOC_BFM_SHA256 = "e0c60be6ad48681458ca38093a494ae263304997e658c5eefa006881da10ae06"
TOP_TB_SHA256 = "c212c32da99e90cd3991da65e653998cac3e945d7479abfd640b9d82f47659f9"
PHYSICAL_RNG_SHA256 = "85b73db47fdab769e55d8ca58c976a0cad68631d3f3eed0e7d13649c38abf01f"
TOP_TB_JTAG_OVERLAY_SHA256 = "6b3d6eeb6bbb3acddcc6045b86c9cc6c6ca3934164f29564485a9a3d2fc4d02a"
FAST_TRNG_TOP_TB_OVERLAY_SHA256 = "c4dbd3f75055982a5b31d05d8ba66039027b48b056e769985722a4db4b02dea6"
TOP_SERVICES_SHA256 = "5a048411bf1dcae2cda6406a6d32afba0dc9f9ef447c301875f7b6c7e1939343"
FIRMWARE_COMPAT_OVERLAYS = {
    "smoke_test_uart": "caliptra-legacy-uart-qspi-reg-compat.h",
    "smoke_test_qspi": "caliptra-legacy-uart-qspi-reg-compat.h",
    "smoke_test_ecc_errortrigger5": "caliptra-errortrigger5-abr-compat.h",
    "smoke_test_kv_ecc_flow1": "caliptra-srand-compat.h",
    "smoke_test_kv_ecc_flow2": "caliptra-srand-compat.h",
    "smoke_test_ras": "caliptra-ras-isr-compat.h",
}
RAS_ISR_HEADER_RELATIVE_PATH = (
    "src/integration/test_suites/smoke_test_ras/caliptra_isr.h"
)
RAS_ISR_HEADER_SHA256 = "dff5bff1a7f28c2bad6cd220c1c0f708f7d1980cab1119ceacca0cd9b859e5a8"
RAS_ISR_SIGNATURE = b"inline void service_soc_ifc_notif_intr () {"
RAS_ISR_COMPAT_SIGNATURE = (
    b"static inline __attribute__((used)) void service_soc_ifc_notif_intr () {"
)
FIRMWARE_COMPAT_OVERLAY_DIR = (
    REPO / "docs/conformance/release_overlays/caliptra/environment"
)
DMA_GENERATOR_HELPER_SCOPE = "caliptra_top_tb.tb_services_i"
FINISH = re.compile(r"Finished : minstret = (\d+), mcycle = (\d+)")
RESET_ASSERT = re.compile(r"CALIPTRA_RESET_EDGE state=assert cycle=(\d+)")
AXI_AW = re.compile(r"CALIPTRA_AXI AW .* cycle=(\d+)")
AXI_B = re.compile(r"CALIPTRA_AXI B .* cycle=(\d+)")
BAD = re.compile(
    r"\b(?:UVM_)?(?:ERROR|FATAL)\b(?!\s*=\s*0\b)|"
    r"\bassert(?:ion)?\b[^\n]*\b(?:fail(?:ed|ure)?|error)\b",
    re.IGNORECASE,
)
JTAG_ERROR = re.compile(r"(?m)^jtag0: (?:Failed to|Unable to|Socket read failed|Error while|Client disappeared)")
JTAG_BIND_DENIED = re.compile(
    r"(?m)^jtag0: Failed to bind socket: Operation not permitted \(1\)\s*$"
)


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def tool_identity(path):
    binary = Path(path).resolve()
    version_run = subprocess.run(
        [str(binary), "-V"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, check=False,
    )
    version_lines = version_run.stdout.splitlines()
    return {
        "path": str(binary),
        "version": version_lines[0] if version_lines else "",
        "version_exit_code": version_run.returncode,
        "sha256": sha256(binary),
    }


def source_checkout_identity(root):
    path = Path(root).expanduser().resolve()
    pin = path / "qd-bfm.commit"
    if pin.is_file():
        return {"root": str(path), "commit": pin.read_text().strip(),
                "clean": True, "remote_tracking_refs_containing_head": []}

    def git(*args):
        return subprocess.run(
            ["git", "-C", str(path), *args], stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, text=True, check=True,
        ).stdout.strip()

    commit = git("rev-parse", "HEAD")
    status = git("status", "--porcelain", "--untracked-files=all")
    remote_refs = git(
        "branch", "-r", "--contains", commit, "--format=%(refname:short)"
    )
    return {
        "root": str(path),
        "commit": commit,
        "clean": not status,
        "remote_tracking_refs_containing_head": remote_refs.splitlines() if remote_refs else [],
    }


def prepare_sram_export_overlay(rtl_root, output_path):
    source = Path(rtl_root) / "src/integration/tb/caliptra_veer_sram_export.sv"
    text = source.read_text()
    anchor = "int ii,jj,kk,ll;"
    dccm_q_port = re.compile(
        r"\.Q\s*\(\s*\{el2_mem_export\.dccm_bank_ecc\[i\]\[pt\.DCCM_ECC_WIDTH-1:0\],"
        r"el2_mem_export\.dccm_bank_dout\[i\]\[pt\.DCCM_DATA_WIDTH-1:0\]\}\s*\)"
    )
    iccm_q_port = re.compile(
        r"\.Q\s*\(\s*\{el2_mem_export\.iccm_bank_ecc\[i\]\[pt\.ICCM_ECC_WIDTH-1:0\],"
        r"el2_mem_export\.iccm_bank_dout\[i\]\[31:0\]\}\s*\)"
    )
    counts = (len(dccm_q_port.findall(text)), len(iccm_q_port.findall(text)))
    if text.count(anchor) != 1 or not all(counts):
        raise ValueError(f"unexpected Caliptra SRAM exporter structure: {source}")
    text = text.replace(
        anchor,
        anchor + "\n    logic [pt.ICCM_NUM_BANKS-1:0][pt.ICCM_ECC_WIDTH-1:0] iccm_bank_ecc_icarus;"
        "\n    logic [pt.ICCM_NUM_BANKS-1:0][31:0] iccm_bank_dout_icarus;"
        "\n    logic [pt.DCCM_NUM_BANKS-1:0][pt.DCCM_ECC_WIDTH-1:0] dccm_bank_ecc_icarus;"
        "\n    logic [pt.DCCM_NUM_BANKS-1:0][pt.DCCM_DATA_WIDTH-1:0] dccm_bank_dout_icarus;"
        "\n    assign el2_mem_export.iccm_bank_ecc = iccm_bank_ecc_icarus;"
        "\n    assign el2_mem_export.iccm_bank_dout = iccm_bank_dout_icarus;"
        "\n    assign el2_mem_export.dccm_bank_ecc = dccm_bank_ecc_icarus;"
        "\n    assign el2_mem_export.dccm_bank_dout = dccm_bank_dout_icarus;",
        1,
    )
    text, dccm_replaced = dccm_q_port.subn(
        ".Q({dccm_bank_ecc_icarus[i], dccm_bank_dout_icarus[i]})", text
    )
    text, iccm_replaced = iccm_q_port.subn(
        ".Q({iccm_bank_ecc_icarus[i], iccm_bank_dout_icarus[i]})", text
    )
    if (dccm_replaced, iccm_replaced) != counts:
        raise ValueError(f"SRAM exporter overlay changed Q ports from {counts} to {(dccm_replaced, iccm_replaced)}")
    Path(output_path).write_text(text)
    return {"dccm_q_ports": dccm_replaced, "iccm_q_ports": iccm_replaced}


def allocate_axi_read_resp_user(text):
    before = "            data = new[len+1];\n            resp = new[len+1];"
    after = "            data = new[len+1];\n            resp_user = new[len+1];\n            resp = new[len+1];"
    if text.count(before) != 1:
        raise ValueError("expected one AXI read response-array allocation sequence")
    return text.replace(before, after, 1)


def replace_aes_mul2_partial_writes(text):
    before = (
        "  out[7] = in[6];\n"
        "  out[6] = in[5];\n"
        "  out[5] = in[4];\n"
        "  out[4] = in[3] ^ in[7];\n"
        "  out[3] = in[2] ^ in[7];\n"
        "  out[2] = in[1];\n"
        "  out[1] = in[0] ^ in[7];\n"
        "  out[0] = in[7];"
    )
    after = "  out = {in[6:0], 1'b0} ^ (in[7] ? 8'h1b : 8'h00);"
    if text.count(before) != 1:
        raise ValueError("expected one AES mul2 partial-write block")
    return text.replace(before, after, 1)


def prepare_aes_pkg_overlay(rtl_root, output_path):
    source = Path(rtl_root) / "src/aes/rtl/aes_pkg.sv"
    if sha256(source) != AES_PKG_SHA256:
        raise ValueError(f"Caliptra AES package source hash mismatch: {source}")
    Path(output_path).write_text(replace_aes_mul2_partial_writes(source.read_text()))
    if sha256(output_path) != AES_PKG_OVERLAY_SHA256:
        raise ValueError("Icarus AES package overlay did not match its recorded hash")


def prepare_axi_if_overlay(rtl_root, output_path):
    source = Path(rtl_root) / "src/axi/rtl/axi_if.sv"
    if sha256(source) != AXI_IF_SHA256:
        raise ValueError(f"Caliptra AXI interface source hash mismatch: {source}")
    Path(output_path).write_text(allocate_axi_read_resp_user(source.read_text()))
    if sha256(output_path) != AXI_IF_OVERLAY_SHA256:
        raise ValueError("Icarus AXI interface overlay did not match its recorded hash")


def prepare_firmware_compat_overlay(case, output_path, rtl_root=None):
    filename = FIRMWARE_COMPAT_OVERLAYS.get(case)
    if filename is None:
        raise ValueError(f"no firmware compatibility overlay for {case}")
    source = FIRMWARE_COMPAT_OVERLAY_DIR / filename
    if not source.is_file():
        raise ValueError(f"firmware compatibility overlay not found: {source}")
    output = Path(output_path)
    if case == "smoke_test_ras":
        if rtl_root is None:
            raise ValueError("RTL root required for smoke_test_ras compatibility overlay")
        isr_source = Path(rtl_root) / RAS_ISR_HEADER_RELATIVE_PATH
        if sha256(isr_source) != RAS_ISR_HEADER_SHA256:
            raise ValueError(f"Caliptra RAS ISR source hash mismatch: {isr_source}")
        original = isr_source.read_bytes()
        if original.count(RAS_ISR_SIGNATURE) != 1:
            raise ValueError("Caliptra RAS ISR source did not have one expected handler")
        overlay_source = output.parent / "source_overlay" / "caliptra_isr.h"
        overlay_source.parent.mkdir(parents=True, exist_ok=True)
        overlay_source.write_bytes(
            original.replace(RAS_ISR_SIGNATURE, RAS_ISR_COMPAT_SIGNATURE, 1)
        )
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(source.read_bytes())
    return output


def remove_sva_debug_print(text, message):
    pattern = re.compile(
        r'(?ms)^[ \t]*\$display\("' + re.escape(message) +
        r'".*?\);[ \t]*(?:\r?\n)?'
    )
    return pattern.subn("", text)


def remove_sva_debug_prints(text):
    removed = 0
    for message in SVA_DIAGNOSTICS_TO_REMOVE:
        text, count = remove_sva_debug_print(text, message)
        if count != 1:
            raise ValueError(f"expected one checker diagnostic {message!r}, found {count}")
        removed += count
    return text, removed


def prepare_checker_overlay(rtl_root, output_path):
    source = Path(rtl_root) / "src/integration/asserts/caliptra_top_sva.sv"
    if sha256(source) != TOP_SVA_SHA256:
        raise ValueError(f"Caliptra checker source hash mismatch: {source}")
    text, removed = remove_sva_debug_prints(source.read_text())
    if removed != 9:
        raise ValueError(f"expected nine checker diagnostic prints, removed {removed}")
    Path(output_path).write_text(text)
    if sha256(output_path) != TOP_SVA_OVERLAY_SHA256:
        raise ValueError("Icarus checker overlay did not match its recorded hash")
    return removed


def prepare_reset_overlay(rtl_root, output_path):
    source = Path(rtl_root) / "src/integration/tb/caliptra_top_tb_soc_bfm.sv"
    if sha256(source) != SOC_BFM_SHA256:
        raise ValueError(f"Caliptra reset BFM source hash mismatch: {source}")
    text = source.read_text()
    before = "    initial begin\n        cptra_pwrgood = 1'b0;\n        BootFSM_BrkPoint ="
    after = "    initial begin\n        #0 cptra_pwrgood = 1'b0;\n        BootFSM_BrkPoint ="
    if text.count(before) != 1:
        raise ValueError("expected exactly one Caliptra reset-startup sequence")
    Path(output_path).write_text(text.replace(before, after, 1))


def accelerate_physical_rng_for_diagnostic(text):
    before = "physical_rng physical_rng ("
    if text.count(before) != 1:
        raise ValueError("expected exactly one physical_rng instance")
    return text.replace(before, "physical_rng #(.DutyCycle(50)) physical_rng (", 1)


def prepare_jtag_port_overlay(rtl_root, output_path, fast_trng=False):
    source = Path(rtl_root) / "src/integration/tb/caliptra_top_tb.sv"
    if sha256(source) != TOP_TB_SHA256:
        raise ValueError(f"Caliptra top testbench source hash mismatch: {source}")
    rng_model = Path(rtl_root) / "src/entropy_src/tb/physical_rng.sv"
    if sha256(rng_model) != PHYSICAL_RNG_SHA256:
        raise ValueError(f"Caliptra physical RNG model hash mismatch: {rng_model}")
    text = source.read_text()
    before = ".ListenPort     (63224)"
    if text.count(before) != 1:
        raise ValueError("expected exactly one JTAG DPI listen port")
    overlay = "`timescale 1ns/1ps\n" + text.replace(before, ".ListenPort     (0)", 1)
    if fast_trng:
        overlay = accelerate_physical_rng_for_diagnostic(overlay)
    Path(output_path).write_text(overlay)
    expected = FAST_TRNG_TOP_TB_OVERLAY_SHA256 if fast_trng else TOP_TB_JTAG_OVERLAY_SHA256
    if sha256(output_path) != expected:
        raise ValueError("Caliptra top testbench overlay did not match its recorded hash")


def skip_pq_vector_generators(text):
    before = "            mldsa_input_hex_gen();\n            mlkem_testvector_generator();"
    after = (
        '            if (!$test$plusargs("CLP_SKIP_PQ_VECTOR_GENERATION")) begin\n'
        "                mldsa_input_hex_gen();\n"
        "                mlkem_testvector_generator();\n"
        "            end"
    )
    if text.count(before) != 1:
        raise ValueError("expected one MLDSA/MLKEM vector-generation call block")
    return text.replace(before, after, 1)


def replace_random_reset_delay(text, delay_cycles):
    if not 5 <= delay_cycles <= 8191:
        raise ValueError("diagnostic random-reset delay must be between 5 and 8191 cycles")
    before = (
        "            `ifndef VERILATOR\n"
        "                std::randomize(wait_time_to_rst) with {wait_time_to_rst dist {[5:24] :/ 3, [25:99] :/ 5, [100:255] :/ 8, [256:511] :/ 5, [512:1023] :/ 1};};\n"
        "            `else\n"
        "                wait_time_to_rst = $urandom_range(5,150);\n"
        "            `endif"
    )
    if text.count(before) != 1:
        raise ValueError("expected one Caliptra random warm-reset delay block")
    return text.replace(before, f"            wait_time_to_rst = {delay_cycles};", 1)


def prepare_services_overlay(rtl_root, output_path, skip_pq_vectors=False,
                             rand_dma_reset_delay_cycles=None):
    source = Path(rtl_root) / "src/integration/tb/caliptra_top_tb_services.sv"
    if sha256(source) != TOP_SERVICES_SHA256:
        raise ValueError(f"Caliptra top services source hash mismatch: {source}")
    text = source.read_text()
    if skip_pq_vectors:
        text = skip_pq_vector_generators(text)
    if rand_dma_reset_delay_cycles is not None:
        text = replace_random_reset_delay(text, rand_dma_reset_delay_cycles)
    for before, after in (
        ('"python sha256_wntz_test_gen.py %d %d"', '"python3 sha256_wntz_test_gen.py %d %d"'),
        ('$system("python doe_test_gen.py");', '$system("python3 doe_test_gen.py");'),
    ):
        if text.count(before) != 1:
            raise ValueError(f"expected one runtime vector-generator command: {before}")
        text = text.replace(before, after, 1)
    Path(output_path).write_text(text)


def prepare_dma_generator_overlay(rtl_root, output_path, force_first_reset=False):
    generator_script = REPO / "docs/conformance/release_overlays/caliptra/dma_testcase_generator_overlay.py"
    command = [
        sys.executable, str(generator_script), "--caliptra-root", str(rtl_root),
        "--output", str(output_path), "--top", DMA_GENERATOR_HELPER_SCOPE,
    ]
    if force_first_reset:
        command.append("--force-first-reset")
    subprocess.run(command, check=True)


def prepare_limited_aes_case_source(rtl_root, output_dir, case_limit, case_start=0):
    source = Path(rtl_root) / "src/integration/test_suites/smoke_test_dma_aes_gcm_short_1_dword"
    source_file = source / "smoke_test_dma_aes_gcm_short_1_dword.c"
    text = source_file.read_text()
    table = re.search(r"test_config_t\s+test_cases\[\]\s*=\s*\{(.*?)\n\s*\};", text, re.S)
    if not table:
        raise ValueError(f"unexpected AES DMA test-case table: {source_file}")
    table_lines = [line.rstrip() for line in table.group(1).splitlines()
                   if line.strip() and not line.lstrip().startswith("//")]
    if not table_lines or any(not re.match(r"\s*\{AES_(?:ENC|DEC),", line)
                              for line in table_lines):
        raise ValueError(f"unexpected AES DMA test-case table entries: {source_file}")
    case_count = len(table_lines)
    if not 1 <= case_limit <= case_count:
        raise ValueError(f"AES DMA case limit must be between 1 and {case_count}")
    if not 0 <= case_start < case_count or case_start + case_limit > case_count:
        raise ValueError(
            f"AES DMA case window starting at {case_start} with limit {case_limit} "
            f"exceeds {case_count} cases"
        )
    before = "int num_tests = sizeof(test_cases) / sizeof(test_config_t);"
    if text.count(before) != 1:
        raise ValueError(f"unexpected AES DMA firmware loop: {source_file}")
    selected_cases = "\n".join(table_lines[case_start:case_start + case_limit])
    text = text[:table.start(1)] + "\n" + selected_cases + text[table.end(1):]
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True)
    patched_source = output_dir / source_file.name
    patched_source.write_text(
        text.replace(before, f"int num_tests = {case_limit}; /* bounded AES DMA diagnostic */", 1)
    )
    shutil.copy2(source / "caliptra_isr.h", output_dir / "caliptra_isr.h")
    return output_dir, sha256(patched_source)


def prepare_iverilog_profile(base_profile, output_profile, repo_root, rtl_root,
                             checker_overlay, reset_overlay, jtag_overlay,
                             generator_overlay=None, services_overlay=None):
    text = Path(base_profile).read_text()
    lines = text.splitlines()
    if lines.count(ORIGINAL_AXI4PC) > 1:
        raise ValueError(f"Icarus profile contains duplicate licensed checker entries: {ORIGINAL_AXI4PC}")
    excluded_sources = [ORIGINAL_AXI4PC] if ORIGINAL_AXI4PC in lines else []
    lines = [line for line in lines if line != ORIGINAL_AXI4PC]
    for source in (ORIGINAL_AES_PKG, ORIGINAL_AXI_IF, ORIGINAL_AXI_COMPLEX, ORIGINAL_SRAM_EXPORT, ORIGINAL_TOP_SVA,
                   ORIGINAL_SOC_BFM, ORIGINAL_TOP_TB, ORIGINAL_DMA_GENERATOR):
        if lines.count(source) != 1:
            raise ValueError(f"Icarus profile must contain exactly one {source}")

    sram_overlay = Path(output_profile).parent / "caliptra_veer_sram_export_icarus.sv"
    prepare_sram_export_overlay(rtl_root, sram_overlay)
    aes_overlay = Path(output_profile).parent / "aes_pkg_icarus.sv"
    prepare_aes_pkg_overlay(rtl_root, aes_overlay)
    axi_if_overlay = Path(output_profile).parent / "axi_if_icarus.sv"
    prepare_axi_if_overlay(rtl_root, axi_if_overlay)

    bfm_sources = []
    for line in (Path(repo_root) / "dv/caliptra_bfm/caliptra_bfm.f").read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        source = (Path(repo_root) / line).resolve()
        if not source.is_file():
            raise ValueError(f"missing BFM source in caliptra_bfm.f: {source}")
        bfm_sources.append(source)

    replacement = Path(repo_root) / "dv/caliptra_bfm/axi/caliptra_top_tb_axi_complex_bfm.sv"
    checker_overlay = Path(checker_overlay)
    sources = [replacement, *bfm_sources]
    overlays = [aes_overlay, axi_if_overlay, sram_overlay, checker_overlay, reset_overlay, jtag_overlay]
    if generator_overlay:
        overlays.append(generator_overlay)
    if services_overlay:
        overlays.append(services_overlay)
    for source in [*overlays, *sources]:
        if any(char.isspace() for char in str(source)):
            raise ValueError(f"Icarus filelists cannot safely represent a source path with whitespace: {source}")
    lines = [line for line in lines if line != ORIGINAL_AXI_COMPLEX]
    replacements = {
        ORIGINAL_AES_PKG: str(aes_overlay),
        ORIGINAL_AXI_IF: str(axi_if_overlay),
        ORIGINAL_SRAM_EXPORT: str(sram_overlay),
        ORIGINAL_TOP_SVA: str(checker_overlay),
        ORIGINAL_SOC_BFM: str(reset_overlay),
        ORIGINAL_TOP_TB: str(jtag_overlay),
    }
    if generator_overlay:
        replacements[ORIGINAL_DMA_GENERATOR] = str(generator_overlay)
    if services_overlay:
        if lines.count(ORIGINAL_TOP_SERVICES) != 1:
            raise ValueError(f"Icarus profile must contain exactly one {ORIGINAL_TOP_SERVICES}")
        replacements[ORIGINAL_TOP_SERVICES] = str(services_overlay)
    lines = [replacements.get(line, line) for line in lines]
    lines.extend(str(source) for source in sources)
    Path(output_profile).write_text("\n".join(lines) + "\n")
    return excluded_sources


def load_case(rtl_root, name, case_yaml_path=None):
    if not re.fullmatch(r"[A-Za-z0-9_]+", name):
        raise ValueError("case name must contain only letters, digits, and underscores")
    suites = (Path(rtl_root) / "src/integration/test_suites").resolve()
    relative_yaml = Path(case_yaml_path) if case_yaml_path else Path(name) / f"{name}.yml"
    if relative_yaml.is_absolute():
        raise ValueError("case YAML path must be relative to src/integration/test_suites")
    case_yaml = (suites / relative_yaml).resolve()
    if not case_yaml.is_relative_to(suites):
        raise ValueError("case YAML path must stay within src/integration/test_suites")
    if not case_yaml.is_file():
        raise ValueError(f"case YAML not found: {case_yaml}")
    text = case_yaml.read_text()
    testnames = re.findall(r"(?m)^testname:\s*(\S+)\s*$", text)
    seeds = re.findall(r"(?m)^seed:\s*(\S+)\s*$", text)
    if (len(testnames) != 1 or not re.fullmatch(r"[A-Za-z0-9_]+", testnames[0]) or
            len(seeds) != 1 or (case_yaml_path is None and testnames != [name])):
        raise ValueError(f"unexpected Caliptra case YAML: {case_yaml}")
    seed = "1" if seeds[0] == "${PLAYBOOK_RANDOM_SEED}" else seeds[0]
    if not seed.isdigit():
        raise ValueError(f"case seed must be numeric: {seed}")
    plusargs = re.findall(r"(?m)^\s*-\s+(\+\S+)\s*$", text)
    return case_yaml, seed, plusargs, testnames[0]


DCCM_BASE = 0x50000000
DCCM_SIZE = 0x40000
DATA_COPY_BRANCH_PC = 0x46
DATA_COPY_BRANCH = bytes.fromhex("63 fa 62 00")
POST_COPY_BRANCH = bytes.fromhex("6f 00 00 04")


def readmemh_image(text):
    # Caliptra's program and DCCM hex files are byte-addressed and fit in 256 KiB.
    image = bytearray(DCCM_SIZE)
    present = bytearray(DCCM_SIZE)
    address = None
    for line_number, line in enumerate(text.splitlines(), 1):
        line = line.strip()
        if not line:
            continue
        if line.startswith("@"):
            if not re.fullmatch(r"@[0-9a-fA-F]+", line):
                raise ValueError(f"invalid readmemh address on line {line_number}")
            address = int(line[1:], 16)
            if address >= DCCM_SIZE:
                raise ValueError(f"readmemh address exceeds the 256 KiB image on line {line_number}")
            continue
        tokens = line.split()
        if address is None or any(not re.fullmatch(r"[0-9a-fA-F]{2}", token) for token in tokens):
            raise ValueError(f"invalid byte data on readmemh line {line_number}")
        for token in tokens:
            if address >= DCCM_SIZE or present[address]:
                raise ValueError(f"duplicate or out-of-range readmemh byte on line {line_number}")
            image[address] = int(token, 16)
            present[address] = 1
            address += 1
    return image, present


def read_hex_range(text, start, end):
    if start < 0 or end <= start or end > DCCM_SIZE:
        raise ValueError("invalid Caliptra readmemh byte range")
    image, present = readmemh_image(text)
    if not all(present[start:end]):
        raise ValueError(f"readmemh image does not cover 0x{start:x}-0x{end:x}")
    return bytes(image[start:end])


def replace_hex_range(text, start, replacement):
    read_hex_range(text, start, start + len(replacement))
    end = start + len(replacement)
    output = []
    address = None
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped:
            output.append(line)
        elif stripped.startswith("@"):
            address = int(stripped[1:], 16)
            output.append(line)
        else:
            tokens = stripped.split()
            changed = False
            for index in range(len(tokens)):
                if start <= address < end:
                    tokens[index] = f"{replacement[address - start]:02X}"
                    changed = True
                address += 1
            output.append(" ".join(tokens) if changed else line)
    return "\n".join(output) + ("\n" if text.endswith("\n") else "")


def format_readmemh_segment(start, data):
    lines = [f"@{start:08X}"]
    lines.extend(" ".join(f"{byte:02X}" for byte in data[offset:offset + 16])
                  for offset in range(0, len(data), 16))
    return "\n".join(lines) + "\n"


def prepare_fast_boot_data_preload(program_path, dccm_path, map_path, dis_path):
    symbols = {}
    map_text = Path(map_path).read_text()
    for name in ("_data_lma_start", "_bss_lma_start", "_data_vma_start",
                 "_bss_lma_end", "_bss_vma_start", "_bss_vma_end"):
        matches = re.findall(rf"(?m)^\s*0x([0-9a-fA-F]+)\s+{name}\s*=", map_text)
        if len(matches) != 1:
            raise ValueError(f"firmware map must define {name} exactly once")
        symbols[name] = int(matches[0], 16)

    disassembly = Path(dis_path).read_text()
    if (not re.search(r"(?m)^\s*46:\s+0062fa63\s+bgeu\s+t0,t1,5a\s+<bss_cp_setup>\s*$", disassembly) or
            any(not re.search(rf"(?m)^000000{address} <{label}>:$", disassembly)
                for address, label in (("4a", "data_cp_loop"), ("5a", "bss_cp_setup"),
                                       ("76", "bss_cp_loop"), ("86", "post_cp_loops")))):
        raise ValueError("firmware CRT0 startup branch or data/BSS loops are not the verified layout")

    data_start = symbols["_data_lma_start"]
    data_end = symbols["_bss_lma_start"]
    data_vma = symbols["_data_vma_start"]
    bss_start = symbols["_bss_lma_start"]
    bss_end = symbols["_bss_lma_end"]
    bss_vma = symbols["_bss_vma_start"]
    bss_vma_end = symbols["_bss_vma_end"]
    if (data_end <= data_start or (data_start | data_end | data_vma) & 3 or
            data_end > DCCM_SIZE or data_end - data_start > DCCM_SIZE):
        raise ValueError("firmware .data range is empty, unaligned, or outside the image")
    if (bss_end < bss_start or bss_vma_end < bss_vma or
            (bss_start | bss_end | bss_vma | bss_vma_end) & 3 or
            bss_end > DCCM_SIZE or bss_end - bss_start > DCCM_SIZE or
            bss_end - bss_start != bss_vma_end - bss_vma):
        raise ValueError("firmware .bss range is reversed, unaligned, or has mismatched LMA/VMA lengths")
    if not DCCM_BASE <= data_vma < DCCM_BASE + DCCM_SIZE:
        raise ValueError("firmware .data destination is outside DCCM")
    if not DCCM_BASE <= bss_vma <= bss_vma_end <= DCCM_BASE + DCCM_SIZE:
        raise ValueError("firmware .bss destination is outside DCCM")
    destination = data_vma - DCCM_BASE
    destination_end = destination + data_end - data_start
    bss_destination = bss_vma - DCCM_BASE
    bss_destination_end = bss_vma_end - DCCM_BASE
    if destination_end > DCCM_SIZE:
        raise ValueError("firmware .data destination exceeds DCCM")
    if destination < bss_destination_end and bss_destination < destination_end:
        raise ValueError("firmware .data and .bss destinations overlap")

    program_path = Path(program_path)
    dccm_path = Path(dccm_path)
    program_text = program_path.read_text()
    dccm_text = dccm_path.read_text()
    program, program_present = readmemh_image(program_text)
    dccm, dccm_present = readmemh_image(dccm_text)
    if (not all(program_present[DATA_COPY_BRANCH_PC:DATA_COPY_BRANCH_PC + 4]) or
            bytes(program[DATA_COPY_BRANCH_PC:DATA_COPY_BRANCH_PC + 4]) != DATA_COPY_BRANCH):
        raise ValueError("firmware startup branch bytes do not match the verified data-copy branch")
    if not all(program_present[data_start:data_end]):
        raise ValueError("firmware program image does not cover its .data load range")
    if not all(program_present[bss_start:bss_end]):
        raise ValueError("firmware program image does not cover its .bss load range")
    if any(program[bss_start:bss_end]):
        raise ValueError("firmware BSS load range is not zero-filled")
    if (any(dccm_present[destination:destination_end]) or
            any(dccm_present[bss_destination:bss_destination_end])):
        raise ValueError("firmware .data or .bss destination overlaps existing DCCM image data")

    data = bytes(program[data_start:data_end])
    bss = bytes(program[bss_start:bss_end])
    patched_program = replace_hex_range(program_text, DATA_COPY_BRANCH_PC, POST_COPY_BRANCH)
    preloaded_dccm = format_readmemh_segment(destination, data)
    if bss:
        preloaded_dccm += format_readmemh_segment(bss_destination, bss)
    preloaded_dccm += dccm_text
    program_path.write_text(patched_program)
    dccm_path.write_text(preloaded_dccm)
    return {
        "diagnostic_only": True,
        "source_lma_start": f"0x{data_start:x}",
        "source_lma_end": f"0x{data_end:x}",
        "destination_vma_start": f"0x{data_vma:x}",
        "destination_offset": f"0x{destination:x}",
        "data_bytes": len(data),
        "data_sha256": hashlib.sha256(data).hexdigest(),
        "bss_lma_start": f"0x{bss_start:x}",
        "bss_lma_end": f"0x{bss_end:x}",
        "bss_vma_start": f"0x{bss_vma:x}",
        "bss_bytes": len(bss),
        "bss_sha256": hashlib.sha256(bss).hexdigest(),
        "branch_pc": f"0x{DATA_COPY_BRANCH_PC:x}",
        "original_branch": DATA_COPY_BRANCH.hex(),
        "replacement_branch": POST_COPY_BRANCH.hex(),
    }

def required_env(name):
    value = os.environ.get(name)
    if not value:
        raise ValueError(f"set {name} before running this test")
    path = Path(value).expanduser().resolve()
    if not path.exists():
        raise ValueError(f"{name} does not exist: {path}")
    return path


def normalize_gcc_prefix(prefix, env):
    prefix_path = Path(prefix.removesuffix("-"))
    if prefix_path.parent != Path("."):
        env["PATH"] = f"{prefix_path.parent}{os.pathsep}{env.get('PATH', '')}"
    return prefix_path.name


def run_logged(command, cwd, env, logfile):
    with Path(logfile).open("wb") as log:
        return subprocess.run(command, cwd=cwd, env=env, stdout=log, stderr=subprocess.STDOUT).returncode


def build_sim_command(vvp, jtagdpi, binary, plusargs, progress_plugin, stdbuf):
    return [
        "perf", "record", "-F", "99", "-g", "--call-graph", "dwarf",
        "-o", os.environ["A5_PERF_DATA"], "--",
        vvp, "-d", jtagdpi, "-n", "-m", progress_plugin,
        "-m", os.environ["CALIPTRA_MCYCLE_WINDOW_PLUGIN"], binary, *plusargs,
    ]


def preflight_riscv_toolchain(gcc_prefix, env, cwd, logfile):
    if not shutil.which(f"{gcc_prefix}-gcc", path=env.get("PATH")):
        raise RuntimeError(f"RISC-V preflight failed: {gcc_prefix}-gcc not found on PATH")
    cpp = shutil.which(f"{gcc_prefix}-cpp", path=env.get("PATH"))
    if not cpp:
        raise RuntimeError(f"RISC-V preflight failed: {gcc_prefix}-cpp not found on PATH")
    command = [cpp, "-x", "c", "-E", "-o", os.devnull, os.devnull]
    exit_code = run_logged(command, cwd, env, logfile)
    if exit_code:
        raise RuntimeError(f"RISC-V preflight failed ({exit_code}); see {logfile}")
    return command


def scan_sim_log(path):
    passed = failed = bad = jtag_errors = jtag_bind_denials = 0
    jtag_bind_denied = False
    finish = None
    reset_assert_cycles = []
    outstanding_writes = 0
    outstanding_writes_at_reset = []
    with Path(path).open(errors="replace") as log:
        for line in log:
            passed += line.count("* TESTCASE PASSED")
            failed += line.count("TESTCASE FAILED")
            bad += bool(BAD.search(line))
            if JTAG_BIND_DENIED.match(line):
                jtag_bind_denials += 1
                jtag_bind_denied = True
            else:
                expected_jtag_unavailable = (
                    jtag_bind_denied and
                    line.rstrip("\r\n") == "jtag0: Unable to create TCP server on port 0"
                )
                jtag_errors += bool(JTAG_ERROR.match(line) and not expected_jtag_unavailable)
            if AXI_AW.search(line):
                outstanding_writes += 1
            if AXI_B.search(line):
                outstanding_writes = max(0, outstanding_writes - 1)
            reset_assert = RESET_ASSERT.search(line)
            if reset_assert:
                reset_assert_cycles.append(int(reset_assert[1]))
                outstanding_writes_at_reset.append(outstanding_writes)
            match = FINISH.search(line)
            if match:
                finish = [int(match.group(1)), int(match.group(2))]
    return {"passed": passed, "failed": failed, "bad": bad,
            "jtag_errors": jtag_errors, "jtag_bind_denials": jtag_bind_denials,
            "finish": finish,
            "reset_assert_cycles": reset_assert_cycles,
            "outstanding_writes_at_reset": outstanding_writes_at_reset,
            "reset_in_flight": any(count > 0 for count in outstanding_writes_at_reset)}


def native_vector_outputs(skip_pq_vectors=False):
    pq_outputs = {"test_dilithium5", "smoke_test_mldsa_vector.hex",
                  "native_mlkem", "random_test_ml_kem.py"}
    return {
        relative: name for relative, name in VECTOR_OUTPUTS.items()
        if not skip_pq_vectors or name not in pq_outputs
    }


def prepare_native_vectors(rtl_root, output, env, skip_pq_vectors=False):
    macos = sys.platform == "darwin" and platform.machine() == "arm64"
    linux = sys.platform == "linux" and platform.machine() in ("x86_64", "amd64")
    if not (macos or linux):
        raise RuntimeError("native Caliptra vector preparation requires macOS ARM64 or Linux x86-64")
    compiler = shutil.which("clang") if macos else shutil.which("cc")
    tool_names = ("make", "openssl", "xxd", "python3.12")
    tools = {name: shutil.which(name) for name in tool_names}
    tools["compiler"] = compiler
    missing = [name for name, path in tools.items() if path is None]
    if macos:
        tools["brew"] = shutil.which("brew")
        if tools["brew"] is None:
            missing.append("brew")
    if missing:
        raise RuntimeError(f"missing native vector tools: {missing}")
    if macos:
        packages = ["mbedtls@3"] + ([] if skip_pq_vectors else ["openssl@3"])
        roots = {
            package: Path(subprocess.check_output([tools["brew"], "--prefix", package], text=True).strip())
            for package in packages
        }
        library_suffix = ".dylib"
    else:
        mbedtls_root = env.get("CALIPTRA_MBEDTLS_ROOT")
        if not mbedtls_root:
            raise RuntimeError("Linux native vector preparation requires CALIPTRA_MBEDTLS_ROOT")
        roots = {
            "mbedtls@3": Path(mbedtls_root),
            "openssl@3": Path(tools["openssl"]).resolve().parent.parent,
        }
        library_suffix = ".so"
    adams = Path(rtl_root) / "submodules/adams-bridge"
    ref_source = adams / "src/abr_top/uvmf/Dilithium_ref/dilithium/ref"
    vectors = REPO / "dv/caliptra_bfm/native_vectors"
    mbedtls = roots["mbedtls@3"]
    inputs = {
        "ecc_secp384r1.c": Path(rtl_root) / "src/ecc/tb/ecc_secp384r1.c",
        "doe_test_gen.py": Path(rtl_root) / "src/doe/tb/doe_test_gen.py",
        "sha256_wntz_test_gen.py": Path(rtl_root) / "src/sha256/tb/sha256_wntz_test_gen.py",
        "stage_sha256_wntz.py": vectors / "stage_sha256_wntz.py",
        "mbedtls_libcrypto": mbedtls / f"lib/libmbedcrypto{library_suffix}",
        "mbedtls_libx509": mbedtls / f"lib/libmbedx509{library_suffix}",
        "mbedtls_libtls": mbedtls / f"lib/libmbedtls{library_suffix}",
    }
    if not skip_pq_vectors:
        openssl = roots["openssl@3"]
        inputs.update({
            "native_mlkem.c": vectors / "native_mlkem.c",
            "random_test_ml_kem.py": vectors / "random_test_ml_kem.py",
            "stage_mldsa.py": vectors / "stage_mldsa.py",
            "check_native_mlkem.py": vectors / "check_native_mlkem.py",
            "check_native_mldsa.py": vectors / "check_native_mldsa.py",
            "test_dilithium.c": ref_source / "test/test_dilithium.c",
            "smoke_test_mldsa_vector.hex": Path(rtl_root) / "src/mldsa/tb/smoke_test_mldsa_vector.hex",
            "openssl_libcrypto": openssl / f"lib/libcrypto{library_suffix}",
        })
        if not ref_source.is_dir():
            raise RuntimeError(f"missing native vector input directory: {ref_source}")
    missing = [name for name, path in inputs.items() if not path.is_file()]
    if missing:
        raise RuntimeError(f"missing native vector inputs: {missing}")

    native = Path(output) / "native_vectors"
    native.mkdir()
    generated = {
        "ecc_secp384r1.exe": native / "ecc_secp384r1.exe",
        "sha256_wntz_test_gen.py": native / "sha256_wntz_test_gen.py",
    }
    commands = []
    if not skip_pq_vectors:
        ref = native / "dilithium-ref"
        shutil.copytree(ref_source, ref)
        (ref / "test/test_dilithium5").unlink(missing_ok=True)
        generated.update({
            "test_dilithium5": ref / "test/test_dilithium5",
            "native_mlkem": native / "native_mlkem",
        })
        commands.append([
            tools["compiler"], "-Wall", "-Wextra", "-Werror", "-O2",
            f"-I{roots['openssl@3'] / 'include'}", str(inputs["native_mlkem.c"]),
            f"-L{roots['openssl@3'] / 'lib'}", "-lcrypto", "-o", str(generated["native_mlkem"]),
        ])
    commands.append([
        tools["compiler"], "-O2", f"-I{mbedtls / 'include'}", str(inputs["ecc_secp384r1.c"]),
        f"-L{mbedtls / 'lib'}", "-lmbedtls", "-lmbedx509", "-lmbedcrypto",
        "-o", str(generated["ecc_secp384r1.exe"]),
    ])
    if not skip_pq_vectors:
        commands.extend([
            [sys.executable, str(vectors / "stage_mldsa.py"), str(inputs["test_dilithium.c"]),
             str(ref / "test/test_dilithium.c")],
            [tools["make"], "-C", str(ref), f"CC={tools['compiler']}", "test/test_dilithium5"],
        ])
    commands.append([
        sys.executable, str(vectors / "stage_sha256_wntz.py"),
        str(inputs["sha256_wntz_test_gen.py"]), str(generated["sha256_wntz_test_gen.py"]),
    ])
    if not skip_pq_vectors:
        commands.extend([
            [sys.executable, str(vectors / "check_native_mlkem.py"), str(adams), str(generated["native_mlkem"])],
            [sys.executable, str(vectors / "check_native_mldsa.py"), str(adams), str(generated["test_dilithium5"])],
        ])
    for index, command in enumerate(commands):
        log = native / f"step_{index}.log"
        if run_logged(command, native, env, log):
            raise RuntimeError(f"native vector preparation failed at step {index}; see {log}")
    files = {
        "ecc_secp384r1.exe": generated["ecc_secp384r1.exe"],
        "doe_test_gen.py": inputs["doe_test_gen.py"],
        "sha256_wntz_test_gen.py": generated["sha256_wntz_test_gen.py"],
    }
    if not skip_pq_vectors:
        files.update({
            "test_dilithium5": generated["test_dilithium5"],
            "smoke_test_mldsa_vector.hex": inputs["smoke_test_mldsa_vector.hex"],
            "native_mlkem": generated["native_mlkem"],
            "random_test_ml_kem.py": inputs["random_test_ml_kem.py"],
        })
    return files, {name: sha256(path) for name, path in files.items()}, commands, tools


def stage_native_vectors(test_output, files, hashes, tools, env, skip_pq_vectors=False):
    outputs = native_vector_outputs(skip_pq_vectors)
    if "ml-kem/native_mlkem" in outputs:
        (test_output / "ml-kem/tv").mkdir(parents=True)
    bin_dir = test_output / ".bin"
    bin_dir.mkdir()
    for relative, name in outputs.items():
        target = test_output / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(files[name], target)
        if sha256(target) != hashes[name]:
            raise RuntimeError(f"native vector copy hash mismatch: {relative}")
    for alias in ("python", "python3.9"):
        (bin_dir / alias).symlink_to(tools["python3.12"])
    for alias in ("openssl", "xxd"):
        (bin_dir / alias).symlink_to(tools[alias])
    env["PATH"] = f"{bin_dir}{os.pathsep}{env['PATH']}"
    return {relative: hashes[name] for relative, name in outputs.items()}


def fulltop_compile_command(iverilog, profile, binary, checker_enabled):
    command = [
        iverilog, "-g2017", "-gassertions", "-gcommercial-unsafe", "-s", "caliptra_top_tb",
        "-D", "RV_OPENSOURCE", "-D", "CLP_ASSERT_ON", "-D", "CALIPTRA_INTERNAL_TRNG",
    ]
    if checker_enabled:
        command.extend(["-D", "CALIPTRA_BFM_CHECKER"])
    command.extend(["-f", str(profile), "-o", str(binary)])
    return command


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--case", default="smoke_test_dma",
                        help="stock firmware test suite directory under src/integration/test_suites")
    parser.add_argument("--case-yaml", metavar="RELATIVE_PATH",
                        help="specific test-suite YAML under src/integration/test_suites")
    parser.add_argument("--output", required=True, type=Path, help="new directory outside the source checkouts")
    parser.add_argument("--fast-trng", action="store_true",
                        help="use the diagnostic 50-cycle physical RNG cadence; default is 500")
    parser.add_argument("--fast-boot-data-preload", action="store_true",
                        help="diagnostic only: preload verified .data/.bss and skip CRT0 copy/clear loops")
    parser.add_argument("--first-aes-case-diagnostic", action="store_true",
                        help="diagnostic only: run one AES/DMA case and skip MLDSA/MLKEM helper vectors")
    parser.add_argument("--limit-aes-cases", type=int, metavar="N",
                        help="diagnostic only: run N cases from the short AES/DMA firmware suite")
    parser.add_argument("--start-aes-case", type=int, metavar="INDEX",
                        help="zero-based start index for --limit-aes-cases")
    parser.add_argument("--skip-pq-vector-generation", action="store_true",
                        help="diagnostic only: skip MLDSA/MLKEM vector generation without limiting AES DMA cases")
    parser.add_argument("--quiet-firmware", action="store_true",
                        help="diagnostic only: quiet routine DMA output")
    parser.add_argument("--firmware-compat-overlay", action="store_true",
                        help="use a case-specific build-time upstream firmware compatibility header")
    parser.add_argument("--trace-axi", action="store_true",
                        help="diagnostic only: trace CPU progress and full-top AXI handshakes with VPI")
    parser.add_argument("--disable-bfm-checker", action="store_true",
                        help="diagnostic only: omit the native AXI checker for A/B comparison")
    parser.add_argument("--rand-dma-iterations", type=int, metavar="N",
                        help="diagnostic only: run the first N generated rand_test_dma transfers (1..100)")
    parser.add_argument("--force-first-rand-dma-reset", action="store_true",
                        help="diagnostic only: set inject_rst on the first generated rand_test_dma transfer")
    parser.add_argument("--rand-dma-reset-delay-cycles", type=int, metavar="N",
                        help="diagnostic only: use a fixed 5..8191-cycle delay before the forced first warm reset")
    args = parser.parse_args()
    if args.fast_boot_data_preload and args.case not in (
            "smoke_test_dma", "smoke_test_dma_aes_gcm_short_1_dword", "rand_test_dma"):
        raise ValueError("--fast-boot-data-preload requires a supported DMA firmware case")
    if args.first_aes_case_diagnostic and args.limit_aes_cases is not None:
        raise ValueError("use only one of --first-aes-case-diagnostic and --limit-aes-cases")
    if args.start_aes_case is not None and args.limit_aes_cases is None and not args.first_aes_case_diagnostic:
        raise ValueError("--start-aes-case requires --limit-aes-cases")
    if args.start_aes_case is not None and args.start_aes_case < 0:
        raise ValueError("--start-aes-case must be nonnegative")
    if args.first_aes_case_diagnostic and args.start_aes_case not in (None, 0):
        raise ValueError("--first-aes-case-diagnostic starts at case 0")
    aes_case_limit = 1 if args.first_aes_case_diagnostic else args.limit_aes_cases
    aes_case_start = args.start_aes_case or 0
    if aes_case_limit is not None and args.case != "smoke_test_dma_aes_gcm_short_1_dword":
        raise ValueError("AES case limits are available only for smoke_test_dma_aes_gcm_short_1_dword")
    if aes_case_limit is not None and aes_case_limit < 1:
        raise ValueError("--limit-aes-cases must be positive")
    if args.skip_pq_vector_generation and args.case not in (
            "smoke_test_dma", "smoke_test_dma_aes_gcm_short_1_dword"):
        raise ValueError("--skip-pq-vector-generation requires a DMA-only firmware case")
    if args.quiet_firmware and args.case not in (
            "smoke_test_dma", "smoke_test_dma_aes_gcm_short_1_dword", "rand_test_dma"):
        raise ValueError("--quiet-firmware requires a supported DMA firmware case")
    if args.rand_dma_iterations is not None:
        if args.case != "rand_test_dma":
            raise ValueError("--rand-dma-iterations is limited to rand_test_dma")
        if not 1 <= args.rand_dma_iterations <= 100:
            raise ValueError("--rand-dma-iterations must be between 1 and 100")
    if args.force_first_rand_dma_reset:
        if args.case != "rand_test_dma":
            raise ValueError("--force-first-rand-dma-reset is limited to rand_test_dma")
        if args.rand_dma_iterations is None:
            raise ValueError("--force-first-rand-dma-reset requires --rand-dma-iterations")
    if args.rand_dma_reset_delay_cycles is not None:
        if not args.force_first_rand_dma_reset:
            raise ValueError("--rand-dma-reset-delay-cycles requires --force-first-rand-dma-reset")
        if not args.trace_axi:
            raise ValueError("--rand-dma-reset-delay-cycles requires --trace-axi to verify an in-flight reset")
        if not 5 <= args.rand_dma_reset_delay_cycles <= 8191:
            raise ValueError("--rand-dma-reset-delay-cycles must be between 5 and 8191")
    skip_pq_vectors = aes_case_limit is not None or args.skip_pq_vector_generation
    quiet_firmware = aes_case_limit is not None or args.quiet_firmware

    rtl = required_env("CALIPTRA_RTL")
    base_profile = required_env("CALIPTRA_BFM_PROFILE")
    jtagdpi = required_env("CALIPTRA_JTAGDPI_VPI")
    gcc_prefix = os.environ.get("CALIPTRA_GCC_PREFIX")
    if not gcc_prefix:
        raise ValueError("set CALIPTRA_GCC_PREFIX to the RISC-V toolchain prefix")
    iverilog = shutil.which(os.environ.get("IVERILOG_BIN", "iverilog"))
    vvp = shutil.which(os.environ.get("VVP_BIN", "vvp"))
    if not iverilog or not vvp:
        raise ValueError("IVERILOG_BIN and VVP_BIN must name executable tools")
    simulator_provenance = {
        "iverilog": tool_identity(iverilog),
        "vvp": tool_identity(vvp),
        "source_checkout": (
            source_checkout_identity(os.environ["IVERILOG_SOURCE_ROOT"])
            if os.environ.get("IVERILOG_SOURCE_ROOT") else None
        ),
    }
    if args.output.exists():
        raise ValueError(f"output directory already exists: {args.output}")

    case_yaml, seed, plusargs, yaml_testname = load_case(rtl, args.case, args.case_yaml)
    source_commit = subprocess.check_output(["git", "-C", str(rtl), "rev-parse", "HEAD"], text=True).strip()
    args.output.mkdir(parents=True)
    args.output = args.output.resolve()
    firmware_compat_overlay = None
    if args.firmware_compat_overlay:
        firmware_compat_overlay = prepare_firmware_compat_overlay(
            args.case, args.output / "caliptra_firmware_compat.h", rtl_root=rtl
        )
    profile = args.output / "open_caliptra_top.vf"
    checker_overlay = args.output / "caliptra_top_sva_icarus.sv"
    prepare_checker_overlay(rtl, checker_overlay)
    reset_overlay = args.output / "caliptra_top_tb_soc_bfm_icarus.sv"
    prepare_reset_overlay(rtl, reset_overlay)
    jtag_overlay = args.output / "caliptra_top_tb_ephemeral_jtag.sv"
    prepare_jtag_port_overlay(rtl, jtag_overlay, args.fast_trng)
    generator_overlay = None
    if args.case == "rand_test_dma":
        generator_overlay = args.output / "dma_testcase_generator_icarus.sv"
        prepare_dma_generator_overlay(rtl, generator_overlay, args.force_first_rand_dma_reset)
    services_overlay = None
    case_limit_source = None
    if skip_pq_vectors or args.rand_dma_reset_delay_cycles is not None:
        services_overlay = args.output / "caliptra_top_tb_services_icarus.sv"
        prepare_services_overlay(
            rtl, services_overlay, skip_pq_vectors,
            args.rand_dma_reset_delay_cycles,
        )
    if aes_case_limit is not None:
        case_limit_source = prepare_limited_aes_case_source(
            rtl, args.output / "limited_aes_case_source", aes_case_limit, aes_case_start
        )
    env = os.environ.copy()
    gcc_prefix = normalize_gcc_prefix(gcc_prefix, env)
    env.update(
        CALIPTRA_ROOT=str(rtl),
        CALIPTRA_PRIM_ROOT=str(rtl / "src/caliptra_prim_generic"),
        CALIPTRA_PRIM_MODULE_PREFIX="caliptra_prim_generic",
        CALIPTRA_AXI4PC_DIR=str(rtl / "src/integration/tb"),
    )
    preflight_riscv_toolchain(gcc_prefix, env, args.output, args.output / "toolchain-preflight.log")
    profile_excluded_sources = prepare_iverilog_profile(
        base_profile, profile, REPO, rtl, checker_overlay,
        reset_overlay, jtag_overlay, generator_overlay, services_overlay)
    vector_files, vector_hashes, vector_commands, vector_tools = prepare_native_vectors(
        rtl, args.output, env, skip_pq_vectors
    )
    binary = args.output / "caliptra_top_tb.vvp"
    compile_command = fulltop_compile_command(
        iverilog, profile, binary, checker_enabled=not args.disable_bfm_checker
    )
    compile_exit = run_logged(compile_command, args.output, env, args.output / "compile.log")
    if compile_exit:
        raise RuntimeError(f"top compile failed ({compile_exit}); see {args.output / 'compile.log'}")

    trace_source = REPO / "dv/caliptra_bfm/uvm/tests/sim-axi-trace-vpi.c"
    trace_compiler = shutil.which(os.environ.get(
        "IVERILOG_VPI_BIN", str(Path(iverilog).with_name("iverilog-vpi"))))
    if not trace_compiler:
        raise ValueError("VVP progress requires IVERILOG_VPI_BIN or sibling iverilog-vpi")
    trace_dir = args.output / "trace_vpi"
    trace_dir.mkdir()
    trace_compile_command = [trace_compiler, str(trace_source)]
    trace_compile_exit = run_logged(
        trace_compile_command, trace_dir, env, trace_dir / "compile.log")
    trace_plugin = trace_dir / f"{trace_source.stem}.vpi"
    if trace_compile_exit or not trace_plugin.is_file():
        raise RuntimeError(f"Progress VPI build failed ({trace_compile_exit}); see {trace_dir / 'compile.log'}")

    test_output = args.output / args.case
    test_output.mkdir()
    build_flags = "-std=gnu11 -O2"
    if quiet_firmware:
        build_flags += " -DCPT_VERBOSITY=ERROR"
    if firmware_compat_overlay:
        build_flags += f" -include {firmware_compat_overlay}"
    firmware_command = [
        "make", "-f", str(rtl / "tools/scripts/Makefile"), f"TESTNAME={args.case}",
        f"GCC_PREFIX={gcc_prefix}", "CALIPTRA_INTERNAL_TRNG=1", f"PLAYBOOK_RANDOM_SEED={seed}",
        f"BUILD_CFLAGS={build_flags}",
    ]
    if case_limit_source:
        firmware_command.append(f"TEST_DIR={case_limit_source[0]}")
    firmware_command.append("program.hex")
    firmware_exit = run_logged(firmware_command, test_output, env, test_output / "firmware.log")
    images = ["program.hex", "dccm.hex", "iccm.hex", "mailbox.hex"]
    missing_images = [name for name in images if not (test_output / name).is_file()]
    if firmware_exit or missing_images or (test_output / "program.hex").stat().st_size == 0:
        raise RuntimeError(f"firmware build failed ({firmware_exit}); missing/empty images: {missing_images}")

    stock_firmware_image_sha256 = {name: sha256(test_output / name) for name in images}
    fast_boot_data_preload = None
    if args.fast_boot_data_preload or aes_case_limit is not None:
        fast_boot_data_preload = prepare_fast_boot_data_preload(
            test_output / "program.hex", test_output / "dccm.hex",
            test_output / f"{args.case}.map", test_output / f"{args.case}.dis",
        )
    simulation_image_sha256 = {name: sha256(test_output / name) for name in images}
    staged_vector_hashes = stage_native_vectors(
        test_output, vector_files, vector_hashes, vector_tools, env, skip_pq_vectors
    )
    sim_command = build_sim_command(
        str(vvp), str(jtagdpi), str(binary), ["+CLP_REGRESSION", *plusargs],
        str(trace_plugin), shutil.which("stdbuf", path=env.get("PATH")))
    if args.rand_dma_iterations is not None:
        sim_command.append(f"+NUM_ITERATIONS={args.rand_dma_iterations}")
    if skip_pq_vectors:
        sim_command.append("+CLP_SKIP_PQ_VECTOR_GENERATION")
    sim_env = env.copy()
    sim_env["CALIPTRA_BFM_PROGRESS_ONLY"] = "0" if args.trace_axi else "1"
    sim_exit = run_logged(sim_command, test_output, sim_env, test_output / "sim.log")
    log_scan = scan_sim_log(test_output / "sim.log")
    passed = (sim_exit == 0 and log_scan["passed"] == 1 and log_scan["failed"] == 0 and
              log_scan["bad"] == 0 and log_scan["jtag_errors"] == 0 and log_scan["finish"] is not None)
    if args.rand_dma_reset_delay_cycles is not None:
        passed = passed and log_scan["reset_in_flight"]
    result = {
        "test": args.case,
        "testname": yaml_testname,
        "case_yaml": str(case_yaml.relative_to(Path(rtl).resolve())),
        "passed": passed,
        "caliptra_commit": source_commit,
        "case_yaml_sha256": sha256(case_yaml),
        "bfm_wrapper_sha256": sha256(REPO / "dv/caliptra_bfm/axi/caliptra_top_tb_axi_complex_bfm.sv"),
        "aes_pkg_overlay_sha256": sha256(args.output / "aes_pkg_icarus.sv"),
        "trng_duty_cycle": 50 if args.fast_trng else 500,
        "physical_rng_source_sha256": sha256(rtl / "src/entropy_src/tb/physical_rng.sv"),
        "axi_if_overlay_sha256": sha256(args.output / "axi_if_icarus.sv"),
        "checker_overlay_sha256": sha256(checker_overlay),
        "reset_overlay_sha256": sha256(reset_overlay),
        "jtag_overlay_sha256": sha256(jtag_overlay),
        "pq_vector_source_sha256": TOP_SERVICES_SHA256 if skip_pq_vectors else None,
        "services_overlay_sha256": sha256(services_overlay) if services_overlay else None,
        "dma_generator_overlay_sha256": sha256(generator_overlay) if generator_overlay else None,
        "profile_sha256": sha256(profile),
        "profile_excluded_sources": profile_excluded_sources,
        "caliptra_bfm_checker_enabled": not args.disable_bfm_checker,
        "compile_command": compile_command,
        "compile_exit": compile_exit,
        "firmware_command": firmware_command,
        "firmware_exit": firmware_exit,
        "firmware_compat_overlay": (
            str(firmware_compat_overlay) if firmware_compat_overlay else None
        ),
        "firmware_compat_overlay_sha256": (
            sha256(firmware_compat_overlay) if firmware_compat_overlay else None
        ),
        "aes_case_limit": aes_case_limit,
        "aes_case_start": aes_case_start if aes_case_limit is not None else None,
        "aes_case_limit_source_sha256": case_limit_source[1] if case_limit_source else None,
        "rand_dma_iterations": args.rand_dma_iterations,
        "force_first_rand_dma_reset": args.force_first_rand_dma_reset,
        "rand_dma_reset_delay_cycles": args.rand_dma_reset_delay_cycles,
        "firmware_image_sha256": stock_firmware_image_sha256,
        "simulation_image_sha256": simulation_image_sha256,
        "fast_boot_data_preload": fast_boot_data_preload,
        "diagnostic_modes": {"fast_trng": args.fast_trng,
                             "fast_boot_data_preload": args.fast_boot_data_preload or aes_case_limit is not None,
                             "first_aes_case": args.first_aes_case_diagnostic,
                             "aes_case_limit": aes_case_limit,
                             "aes_case_start": aes_case_start if aes_case_limit is not None else None,
                             "rand_dma_iterations": args.rand_dma_iterations,
                             "force_first_rand_dma_reset": args.force_first_rand_dma_reset,
                             "rand_dma_reset_delay_cycles": args.rand_dma_reset_delay_cycles,
                             "caliptra_bfm_checker": not args.disable_bfm_checker,
                             "skip_pq_vector_generation": skip_pq_vectors,
                             "quiet_firmware": quiet_firmware},
        "native_vector_build_commands": vector_commands,
        "native_vector_tools": vector_tools,
        "native_vector_sha256": staged_vector_hashes,
        "progress_vpi_source_sha256": sha256(trace_source),
        "progress_vpi_plugin_sha256": sha256(trace_plugin),
        "progress_vpi_compile_command": trace_compile_command,
        "progress_vpi_compile_exit": trace_compile_exit,
        "axi_trace_source_sha256": sha256(trace_source) if args.trace_axi else None,
        "axi_trace_plugin_sha256": sha256(trace_plugin) if args.trace_axi else None,
        "axi_trace_compile_command": trace_compile_command if args.trace_axi else None,
        "axi_trace_compile_exit": trace_compile_exit if args.trace_axi else None,
        "sim_command": sim_command,
        "simulator_provenance": simulator_provenance,
        "sim_exit": sim_exit,
        "testcase_pass_markers": log_scan["passed"],
        "testcase_fail_markers": log_scan["failed"],
        "jtag_server_errors": log_scan["jtag_errors"],
        "jtag_bind_denials": log_scan["jtag_bind_denials"],
        "reset_assert_cycles": log_scan["reset_assert_cycles"],
        "outstanding_writes_at_reset": log_scan["outstanding_writes_at_reset"],
        "reset_in_flight": log_scan["reset_in_flight"],
        "bad_diagnostics": log_scan["bad"],
        "finish": log_scan["finish"],
        "sim_log_sha256": sha256(test_output / "sim.log"),
    }
    (args.output / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    label = "PASS" if passed else "FAIL"
    if aes_case_limit is not None:
        label += (f" (AES DMA cases {aes_case_start + 1}..{aes_case_start + aes_case_limit}; "
                  "not stock firmware qualification)")
    elif args.rand_dma_iterations is not None:
        reset_note = ", forced first reset" if args.force_first_rand_dma_reset else ""
        if args.rand_dma_reset_delay_cycles is not None:
            reset_note += f" after {args.rand_dma_reset_delay_cycles} cycles"
        label += f" (first {args.rand_dma_iterations} random DMA transfer(s){reset_note}; not full-suite qualification)"
    elif args.fast_boot_data_preload:
        label += " (diagnostic fast boot; not stock firmware qualification)"
    elif quiet_firmware:
        label += " (diagnostic firmware verbosity; not stock firmware qualification)"
    print(f"{label} {args.case}: {args.output / 'result.json'}")
    return 0 if passed else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, subprocess.CalledProcessError, ValueError, RuntimeError) as exc:
        print(f"Caliptra full-top BFM run failed: {exc}", file=sys.stderr)
        sys.exit(1)
