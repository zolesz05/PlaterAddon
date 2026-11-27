"""Build the installable addon ZIP (default: dist/MotevePlates.zip) and verify it."""
from pathlib import Path
import argparse
import re
import zipfile

root = Path(__file__).resolve().parents[1]
addon = root / 'MotevePlates'

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--out', type=Path, default=root / 'dist' / 'MotevePlates.zip',
                    help='where to write the ZIP (default: dist/MotevePlates.zip)')
target = parser.parse_args().out.resolve()

toc = (addon / 'MotevePlates.toc').read_text(encoding='utf-8')
version = re.search(r'^## Version:\s*(\S+)', toc, re.MULTILINE).group(1)
for line in toc.splitlines():
    if line.strip() and not line.startswith('#'):
        assert (addon / line.strip()).is_file(), f'Missing TOC entry: {line}'

target.parent.mkdir(parents=True, exist_ok=True)
pending = target.with_name(target.name + '.tmp')
files = sorted(p for p in addon.rglob('*') if p.is_file())
with zipfile.ZipFile(pending, 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in files:
        archive.write(path, path.relative_to(root).as_posix())
with zipfile.ZipFile(pending) as archive:
    assert archive.testzip() is None
    assert archive.namelist() == [p.relative_to(root).as_posix() for p in files]
    assert all(name.startswith('MotevePlates/') for name in archive.namelist())
    for path in files:
        assert archive.read(path.relative_to(root).as_posix()) == path.read_bytes()
pending.replace(target)

print(f'PASS: {version}; {len(files)} verified addon files; wrote {target}')
