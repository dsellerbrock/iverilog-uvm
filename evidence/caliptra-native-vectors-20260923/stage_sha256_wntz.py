"""Copy pinned SHA256 WNTZ generator with OpenSSL output parsing corrected.

The algorithm and all generated vectors remain the pinned testbench's own.
Only the two digest text parsers are changed to use OpenSSL's binary output.
"""

import hashlib
import sys
from pathlib import Path

source, target = map(Path, sys.argv[1:])
data = source.read_bytes()
assert hashlib.sha256(data).hexdigest() == "12eacab8c3b3a8733390a8207432bd23ef98a436434c5f834e91115644a82bdd"
text = data.decode()
for spaces in ("    ", "        "):
    old = (
        spaces + "digest_str = str(digest)\n\n"
        + spaces + "#Chomp extra chars at beginning and end if python 3.6.8 is loaded\n"
        + spaces + "if digest_str[1] == \"'\":\n"
        + spaces + "    digest_str = digest_str[11:-3]\n"
        + spaces + "else:\n"
        + spaces + "    digest_str = digest_str.rstrip()\n"
        + spaces + "    digest_str = digest_str[9:]"
    )
    assert text.count(old) == 1
    text = text.replace(old, spaces + "digest_str = digest.hex()", 1)
assert text.count("openssl dgst -sha256'") == 2
text = text.replace("openssl dgst -sha256'", "openssl dgst -sha256 -binary'")
target.write_text(text)
