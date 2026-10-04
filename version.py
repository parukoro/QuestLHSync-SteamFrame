"""Shared release version; does not import Quest/Android build dependencies."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent
VERSION = "v" + re.search(r'#define QLHS_RELEASE "([^"]+)"',
                         (ROOT / "src/common/qlhs_status.h").read_text(encoding="utf-8")).group(1)
