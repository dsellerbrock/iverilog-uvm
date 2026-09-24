"""Invoke the local FIPS 203 helper through Caliptra's expected Python path."""

import os
import sys
from pathlib import Path

helper = Path(__file__).with_name("native_mlkem")
os.execv(helper, [str(helper), *sys.argv[1:]])
