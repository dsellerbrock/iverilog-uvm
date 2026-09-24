"""Align a copied Adams Bridge MLDSA generator with the pinned SV file protocol."""

import hashlib
import sys
from pathlib import Path

source, target = map(Path, sys.argv[1:])
data = source.read_bytes()
assert hashlib.sha256(data).hexdigest() == "2f92c445c9e38cf398fb4daf64ceb0db964f94a573ed985a77cf071b52aa5490"
text = data.decode()
old_mode = "#define VARYING_MSG 1"
old_declaration = "uint8_t sm[MLEN + CRYPTO_BYTES+SEEDBYTES];"
assert text.count(old_mode) == text.count(old_declaration) == 1
text = text.replace(old_mode, "#define VARYING_MSG 0", 1)
text = text.replace(old_declaration, old_declaration + "\n    char m_hex[2*MLEN + 1];", 1)
target.write_text(text)
