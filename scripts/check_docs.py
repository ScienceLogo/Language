"""Check local links and trailing whitespace in public Markdown files."""

from pathlib import Path
import re
from urllib.parse import unquote, urlsplit


ROOT = Path(__file__).resolve().parents[1]
MARKDOWN_FILES = [
    *ROOT.glob("*.md"),
    *ROOT.glob("examples/*.md"),
    *ROOT.glob("spec/*.md"),
]
LINKS = re.compile(r"\[[^]]*\]\(([^)]+)\)|<img\b[^>]*\bsrc=\"([^\"]+)\"", re.I)


def main() -> int:
    errors = []
    for document in MARKDOWN_FILES:
        content = document.read_text(encoding="utf-8")
        for line_number, line in enumerate(content.splitlines(), 1):
            if line.rstrip() != line:
                errors.append(f"{document.relative_to(ROOT)}:{line_number}: trailing whitespace")
        for match in LINKS.finditer(content):
            target = match.group(1) or match.group(2)
            parsed = urlsplit(target)
            if parsed.scheme or parsed.netloc or not parsed.path:
                continue
            path = document.parent / unquote(parsed.path)
            if not path.exists():
                errors.append(f"{document.relative_to(ROOT)}: missing link target {target}")

    for error in errors:
        print(error)
    print(f"Checked {len(MARKDOWN_FILES)} Markdown files; {len(errors)} error(s).")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
