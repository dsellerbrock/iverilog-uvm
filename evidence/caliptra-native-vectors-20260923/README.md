# Native Caliptra L0 vector generators (macOS ARM64)

The pinned non-VERILATOR `caliptra_top_tb_services.sv` calls ECC, DOE, SHA256/WNTZ, MLDSA, and ML-KEM generators unconditionally at startup (`UVM_TB=0`, lines 2632–2638). The pinned integration `compile.yml` copies the generator inputs in its `pre_exec` (lines 207–213). Those commands are testbench setup requirements, not optional DV checks.

The released ECC and MLDSA executables are Linux x86-64 ELF. Native ECC builds from the pinned C source against Homebrew `mbedtls@3` 3.6.7. The Adams Bridge MLDSA C source defaults to a varying-message file format, while this pinned SV writes fixed 64-byte messages; `stage_mldsa.py` makes a hash-guarded source copy selecting its existing `M_PRIME=1` branch and adds a missing local debug buffer declaration. Native MLDSA then builds from that copy. The DOE Python script works with Python 3.12 and OpenSSL 3.6. The SHA256/WNTZ script assumes an older OpenSSL digest text prefix and silently emits nonhex `stdin)= ` with OpenSSL 3.6. `stage_sha256_wntz.py` makes a hash-guarded copy and changes only its two digest parsers to use binary OpenSSL output; the pinned files stay untouched.

The referenced `$MSFT_SCRIPTS_DIR/models/ml-kem/random_test_ml_kem.py` is **absent** from both pinned Git trees. `native_mlkem.c` supplies precisely the testbench's keygen and encap text-file protocol using OpenSSL 3.6's FIPS 203 ML-KEM-1024 implementation; `random_test_ml_kem.py` invokes it through the expected Python path. The helper rejects malformed input and cryptographic errors. It does not change or bypass any RTL or testbench assertion. It is an independent reference implementation, so record its version and use its checks when reporting DV results.

From the campaign worktree, prepare once outside either pinned checkout:

```sh
campaign_root=$PWD
caliptra_root=$campaign_root/../caliptra-rtl
evidence_root=$campaign_root/evidence/caliptra-native-vectors-20260923
build_root=$(mktemp -d /tmp/caliptra-native-vectors.XXXXXX)

openssl_root=$(brew --prefix openssl@3)
mbedtls_root=$(brew --prefix mbedtls@3)
clang -Wall -Wextra -Werror -O2 -I"$openssl_root/include" \
  "$evidence_root/native_mlkem.c" -L"$openssl_root/lib" -lcrypto \
  -o "$build_root/native_mlkem"
clang -O2 -I"$mbedtls_root/include" \
  "$caliptra_root/src/ecc/tb/ecc_secp384r1.c" \
  -L"$mbedtls_root/lib" -lmbedtls -lmbedx509 -lmbedcrypto \
  -o "$build_root/ecc_secp384r1.exe"
cp -R "$caliptra_root/submodules/adams-bridge/src/abr_top/uvmf/Dilithium_ref/dilithium/ref" "$build_root/dilithium-ref"
python3 "$evidence_root/stage_mldsa.py" \
  "$caliptra_root/submodules/adams-bridge/src/abr_top/uvmf/Dilithium_ref/dilithium/ref/test/test_dilithium.c" \
  "$build_root/dilithium-ref/test/test_dilithium.c"
rm "$build_root/dilithium-ref/test/test_dilithium5"  # copied Linux ELF only
make -C "$build_root/dilithium-ref" CC=clang test/test_dilithium5
python3 "$evidence_root/check_native_mlkem.py" \
  "$caliptra_root/submodules/adams-bridge" "$build_root/native_mlkem"
python3 "$evidence_root/check_native_mldsa.py" \
  "$caliptra_root/submodules/adams-bridge" "$build_root/dilithium-ref/test/test_dilithium5"
file "$build_root/native_mlkem" "$build_root/ecc_secp384r1.exe" \
  "$build_root/dilithium-ref/test/test_dilithium5"
```

Stage into each isolated firmware/simulation directory before VVP starts:

```sh
case_dir=/absolute/path/to/case-directory
mkdir -p "$case_dir/ml-kem/tv" "$case_dir/.bin"
cp "$build_root/ecc_secp384r1.exe" "$case_dir/"
cp "$build_root/dilithium-ref/test/test_dilithium5" "$case_dir/"
cp "$build_root/native_mlkem" "$case_dir/ml-kem/"
cp "$evidence_root/random_test_ml_kem.py" "$case_dir/ml-kem/"
cp "$caliptra_root/src/doe/tb/doe_test_gen.py" "$case_dir/"
python3 "$evidence_root/stage_sha256_wntz.py" \
  "$caliptra_root/src/sha256/tb/sha256_wntz_test_gen.py" \
  "$case_dir/sha256_wntz_test_gen.py"
cp "$caliptra_root/src/mldsa/tb/smoke_test_mldsa_vector.hex" "$case_dir/"
ln -s /opt/homebrew/bin/python3.12 "$case_dir/.bin/python"
ln -s /opt/homebrew/bin/python3.12 "$case_dir/.bin/python3.9"
PATH="$case_dir/.bin:$PATH" /path/to/installed/vvp -d /path/to/jtagdpi.vpi /path/to/image.vvp
```

The `python` and `python3.9` names are hardcoded by the pinned SV; Python 3.12.14 was tested. The directory for ML-KEM's `tv` files must exist. The official pre-exec also copies `test_dilithium5_debug`, but the pinned testbench never calls it; its only executable MLDSA call uses `test_dilithium5`. Both copy overlays are local environment repairs and should be recorded as such, separate from Icarus language conformance and the `-gcommercial-unsafe` compatibility mode.

Focused evidence on macOS ARM64:

- Native MLDSA `test_dilithium5` reproduced pinned `keygen_KAT1_expected.hex` byte for byte (SHA256 `457d848995a9fbe2c1ffce2ca1622f21b4ce31e2dd6e5b8bbeb568c597b1e0a2`). The testbench's keygen/sign/verify file exchange returned success for a valid signature and rejected a tampered signature.
- Native ECC exited zero and generated 11 lines of 96 hex characters for `secp384_testvector.hex`, exactly the testbench reader's field count and width.
- DOE exited zero and generated 12 hex fields with the expected key/IV/plaintext/ciphertext widths.
- The unmodified SHA script generated a nonhex digest; the isolated patched copy generated two valid hex fields of 128 and 64 characters.
- `check_native_mlkem.py` passed pinned Adams Bridge keygen EK/DK and encap ciphertext/shared-key KATs byte for byte, plus malformed-input rejection.
- Both pinned checkouts remained clean at their required commits. No Verilator or commercial simulator was run.

These are generator checks only. They are not Caliptra L0 passes.
