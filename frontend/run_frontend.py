import sys
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parent.parent
DEPS_DIR = ROOT_DIR / ".localdeps"

sys.path.insert(0, str(ROOT_DIR))

if DEPS_DIR.exists():
    sys.path.insert(0, str(DEPS_DIR))

from streamlit.web.cli import main


if __name__ == "__main__":
    sys.argv = [
        "streamlit",
        "run",
        str(ROOT_DIR / "frontend" / "app.py"),
    ]
    raise SystemExit(main())
