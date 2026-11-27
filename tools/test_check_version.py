"""Tests for tools/check_version.py. Run from anywhere: python3 tools/test_check_version.py"""
from pathlib import Path
import subprocess
import sys
import tempfile

TOOLS = Path(__file__).resolve().parent
sys.dont_write_bytecode = True
sys.path.insert(0, str(TOOLS))
import check_version as cv  # noqa: E402

SCRIPT = TOOLS / 'check_version.py'


def toc(version):
    return f'## Interface: 16001\n## Title: Moteve Plates\n## Version: {version}\n\nCore.lua\n'


def readme(version, entries):
    """A README.txt fixture: line 1 with `version`, then an ELLENŐRZÉS section with `entries`."""
    body = ''.join(f'  {v}:{text}\n' for v, text in entries)
    return (f'Moteve Plates {version} – WoW Forever / Interface 16001\n\nLEÍRÁS\n  Szöveg.\n\n'
            f'ELLENŐRZÉS\n  Helyi szimulációval tesztelve.\n{body}\nBETŰTÍPUSOK\n  Barlow.\n')


MULTI = readme('0.2.10', [
    ('0.2.9', ' kilences első sor\n  kilences második sor'),
    ('0.2.10', ' tízes első sor\n  tízes második sor'),
    ('0.2.11', ' tizenegyes sor'),
])


def write(root, toc_text, readme_text):
    (root / 'MotevePlates').mkdir(exist_ok=True)
    (root / cv.TOC).write_text(toc_text, encoding='utf-8')
    (root / cv.README).write_text(readme_text, encoding='utf-8')


results = []


def test(name):
    def run(fn):
        try:
            fn()
            results.append((name, None))
        except Exception as error:  # report every failure, then exit non-zero
            results.append((name, error))
        return fn
    return run


def eq(actual, expected, what):
    if actual != expected:
        raise AssertionError(f'{what}: expected {expected!r}, got {actual!r}')


@test('parses_toc_and_readme_versions')
def _():
    eq(cv.toc_version(toc('0.2.13')), '0.2.13', 'toc')
    eq(cv.toc_version('## Title: x\n'), None, 'toc without version')
    eq(cv.readme_version(readme('0.2.13', [])), '0.2.13', 'readme line 1')
    eq(cv.readme_version('Valami más\n'), None, 'readme without version')


@test('consistent_files_pass')
def _():
    eq(cv.check_files(toc('0.2.10'), MULTI), [], 'errors')


@test('rejects_toc_readme_mismatch')
def _():
    errors = cv.check_files(toc('0.2.11'), readme('0.2.10', [('0.2.11', ' x')]))
    eq(len(errors), 1, 'error count')
    assert 'line 1' in errors[0], errors


@test('rejects_missing_changelog_entry')
def _():
    errors = cv.check_files(toc('0.2.12'), readme('0.2.12', [('0.2.11', ' x')]))
    eq(len(errors), 1, 'error count')
    assert '0.2.12:' in errors[0], errors


@test('entry_outside_changelog_section_does_not_count')
def _():
    text = 'Moteve Plates 0.2.12 – x\n\nLEÍRÁS\n  0.2.12: nem changelog\n\nELLENŐRZÉS\n  0.2.11: x\n'
    eq(cv.release_notes(text, '0.2.12'), None, 'notes')
    eq(len(cv.check_files(toc('0.2.12'), text)), 1, 'error count')


@test('rejects_malformed_version')
def _():
    eq(len(cv.check_files(toc('0.2'), readme('0.2', [('0.2', ' x')]))), 1, 'error count')


@test('compares_versions_numerically')
def _():
    assert cv.version_tuple('0.2.10') > cv.version_tuple('0.2.9'), '0.2.10 > 0.2.9'
    assert cv.version_tuple('1.0.0') > cv.version_tuple('0.9.99'), '1.0.0 > 0.9.99'
    eq(cv.check_bump('0.2.9', '0.2.10', ['MotevePlates/Core.lua']), [], '0.2.9 -> 0.2.10')
    eq(len(cv.check_bump('0.2.10', '0.2.9', ['MotevePlates/Core.lua'])), 1, '0.2.10 -> 0.2.9')
    eq(len(cv.check_bump('0.2.9', '0.2.9', ['MotevePlates/Core.lua'])), 1, 'same version')
    eq(cv.check_bump('0.2.9', '0.2.9', []), [], 'no addon change')


@test('notes_return_only_current_entry')
def _():
    eq(cv.release_notes(MULTI, '0.2.10'), 'tízes első sor\ntízes második sor', '0.2.10')
    eq(cv.release_notes(MULTI, '0.2.9'), 'kilences első sor\nkilences második sor', '0.2.9')
    eq(cv.release_notes(MULTI, '0.2.11'), 'tizenegyes sor', 'last entry stops at blank line')
    eq(cv.release_notes(MULTI, '0.2.8'), None, 'missing')


@test('notes_stop_at_unindented_header')
def _():
    text = 'Moteve Plates 0.2.1 – x\nELLENŐRZÉS\n  0.2.1: egy\n  kettő\nBETŰTÍPUSOK\n  Barlow.\n'
    eq(cv.release_notes(text, '0.2.1'), 'egy\nkettő', 'notes')


@test('notes_cli_prints_current_entry')
def _():
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        write(root, toc('0.2.10'), MULTI)
        out = subprocess.run([sys.executable, str(SCRIPT), '--root', str(root), '--notes'],
                             capture_output=True, text=True, encoding='utf-8')
        eq(out.returncode, 0, 'exit code')
        eq(out.stdout, 'tízes első sor\ntízes második sor\n', 'stdout')


def git(root, *args):
    subprocess.run(['git', '-C', str(root), '-c', 'user.name=test', '-c', 'user.email=test@example.invalid',
                    '-c', 'commit.gpgsign=false', '-c', 'core.hooksPath=/dev/null', *args],
                   check=True, capture_output=True)


def base_run(change):
    """Fixture repo: main at 0.2.9, a branch where `change(root)` is committed; run --base main."""
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        git(root, 'init', '-q', '-b', 'main')
        write(root, toc('0.2.9'), readme('0.2.9', [('0.2.9', ' x')]))
        (root / 'MotevePlates' / 'Core.lua').write_text('local a=1\n', encoding='utf-8')
        (root / 'README.md').write_text('# Moteve Plates\n', encoding='utf-8')
        git(root, 'add', '-A')
        git(root, 'commit', '-q', '-m', 'base')
        git(root, 'checkout', '-q', '-b', 'feature')
        change(root)
        git(root, 'add', '-A')
        git(root, 'commit', '-q', '-m', 'change')
        return subprocess.run([sys.executable, str(SCRIPT), '--root', str(root), '--base', 'main'],
                              capture_output=True, text=True, encoding='utf-8')


@test('base_fails_when_addon_changed_without_bump')
def _():
    out = base_run(lambda root: (root / 'MotevePlates' / 'Core.lua').write_text('local a=2\n', encoding='utf-8'))
    eq(out.returncode, 1, 'exit code')
    assert 'MotevePlates/Core.lua' in out.stderr, out.stderr


@test('base_passes_when_only_files_outside_addon_changed')
def _():
    out = base_run(lambda root: (root / 'README.md').write_text('# Moteve Plates\n\nÚj.\n', encoding='utf-8'))
    eq(out.returncode, 0, 'exit code: ' + out.stderr)


@test('base_passes_when_addon_changed_with_numeric_bump')
def _():
    def change(root):
        (root / 'MotevePlates' / 'Core.lua').write_text('local a=2\n', encoding='utf-8')
        write(root, toc('0.2.10'), readme('0.2.10', [('0.2.9', ' x'), ('0.2.10', ' y')]))
    out = base_run(change)
    eq(out.returncode, 0, 'exit code: ' + out.stderr)


@test('base_fails_when_version_bumped_but_changelog_missing')
def _():
    def change(root):
        (root / 'MotevePlates' / 'Core.lua').write_text('local a=2\n', encoding='utf-8')
        write(root, toc('0.2.10'), readme('0.2.10', [('0.2.9', ' x')]))
    out = base_run(change)
    eq(out.returncode, 1, 'exit code')
    assert '0.2.10:' in out.stderr, out.stderr


failed = 0
for name, error in results:
    print(('ok   ' if error is None else 'FAIL ') + name + ('' if error is None else f': {error}'))
    failed += error is not None
print(f'{len(results) - failed}/{len(results)} passed')
sys.exit(1 if failed else 0)
