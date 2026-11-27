"""Check the addon version, its changelog entry and (with --base) the version-bump rule.

The version lives in three places that must agree:
  MotevePlates/MotevePlates.toc   "## Version: x.y.z"
  MotevePlates/README.txt line 1  "Moteve Plates x.y.z – ..."
  MotevePlates/README.txt         a "  x.y.z:" line in the ELLENŐRZÉS section

--base REF   fail when files under MotevePlates/ changed since the merge base with REF
             and the TOC version there is not numerically lower than now.
--notes      print the current version's changelog entry (release notes) and exit.
"""
from pathlib import Path
import argparse
import re
import subprocess
import sys

ADDON = 'MotevePlates'
TOC = f'{ADDON}/MotevePlates.toc'
README = f'{ADDON}/README.txt'
CHANGELOG_HEADER = 'ELLENŐRZÉS'
ENTRY = re.compile(r'^  (\d+\.\d+\.\d+):\s?(.*)$')


def toc_version(text):
    """The '## Version:' value of a TOC, or None."""
    match = re.search(r'^## Version:\s*(\S+)', text, re.MULTILINE)
    return match.group(1) if match else None


def readme_version(text):
    """The version on README.txt line 1 ('Moteve Plates <v> – ...'), or None."""
    first = text.splitlines()[0] if text else ''
    match = re.match(r'^Moteve Plates (\S+)', first)
    return match.group(1) if match else None


def version_tuple(version):
    """'0.2.10' -> (0, 2, 10); ValueError when it is not x.y.z."""
    if version is None or not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise ValueError(f'not an x.y.z version: {version!r}')
    return tuple(int(part) for part in version.split('.'))


def changelog_lines(text):
    """The lines of the ELLENŐRZÉS section, up to the next unindented header."""
    lines = text.splitlines()
    try:
        start = lines.index(CHANGELOG_HEADER) + 1
    except ValueError:
        return []
    section = []
    for line in lines[start:]:
        if line and not line[0].isspace():
            break
        section.append(line)
    return section


def release_notes(text, version):
    """The changelog entry of `version`, or None when there is none.

    It starts after '  <version>:' and runs until the next '  x.y.z:' line,
    a blank line or an unindented section header.
    """
    notes = None
    for line in changelog_lines(text):
        match = ENTRY.match(line)
        if notes is not None:
            if match or not line.strip():
                break
            notes.append(line.strip())
        elif match and match.group(1) == version:
            notes = [match.group(2).strip()] if match.group(2).strip() else []
    return None if notes is None else '\n'.join(notes)


def check_files(toc_text, readme_text):
    """Errors for the current tree (empty list when it is consistent)."""
    errors = []
    version = toc_version(toc_text)
    try:
        version_tuple(version)
    except ValueError as error:
        return [f'{TOC}: {error}']
    first = readme_version(readme_text)
    if first != version:
        errors.append(f'{README} line 1 has version {first!r}, {TOC} has {version!r}')
    if release_notes(readme_text, version) is None:
        errors.append(f'{README}: no "  {version}:" entry in the {CHANGELOG_HEADER} section')
    return errors


def check_bump(base_version, head_version, changed):
    """Errors for the bump rule: changed addon files need a higher version than the base."""
    if not changed or base_version is None:
        return []
    try:
        if version_tuple(head_version) > version_tuple(base_version):
            return []
    except ValueError as error:
        return [f'{TOC}: {error}']
    return [f'{len(changed)} file(s) under {ADDON}/ changed but the version did not rise '
            f'({base_version} -> {head_version}); bump {TOC}, {README} line 1 and add a '
            f'"  <version>:" changelog entry: ' + ', '.join(changed)]


def git(root, *args):
    return subprocess.run(['git', '-C', str(root), *args], check=True,
                          capture_output=True, text=True, encoding='utf-8').stdout


def base_state(root, ref):
    """(TOC version at the merge base of ref and HEAD, files under MotevePlates/ changed since)."""
    changed = [p for p in git(root, 'diff', '--name-only', f'{ref}...HEAD', '--', f'{ADDON}/').splitlines() if p]
    merge_base = git(root, 'merge-base', ref, 'HEAD').strip()
    try:
        base_toc = git(root, 'show', f'{merge_base}:{TOC}')
    except subprocess.CalledProcessError:
        base_toc = ''
    return toc_version(base_toc), changed


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1],
                        help='repository root (default: the one this script is in)')
    parser.add_argument('--base', metavar='REF', help='enforce the version-bump rule against REF')
    parser.add_argument('--notes', action='store_true', help="print the current version's changelog entry")
    args = parser.parse_args(argv)

    toc_text = (args.root / TOC).read_text(encoding='utf-8')
    readme_text = (args.root / README).read_text(encoding='utf-8')
    errors = check_files(toc_text, readme_text)
    version = toc_version(toc_text)
    if not errors and args.notes:
        print(release_notes(readme_text, version))
        return 0
    if args.base:
        base_version, changed = base_state(args.root, args.base)
        errors += check_bump(base_version, version, changed)
    for error in errors:
        print(f'FAIL: {error}', file=sys.stderr)
    if errors:
        return 1
    print(f'PASS: version {version}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
