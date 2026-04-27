import sys
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parent.parent
DEPS_DIR = ROOT_DIR / ".localdeps"

sys.path.insert(0, str(ROOT_DIR))

if DEPS_DIR.exists():
    sys.path.insert(0, str(DEPS_DIR))

import uvicorn


if __name__ == "__main__":
    uvicorn.run("backend.main:app", host="127.0.0.1", port=8000, reload=False)
