#!/usr/bin/env python3
"""Build the pinned ARM64 WORDS engine and matching data using native GNAT."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
REVISION = '1f2f0fb0867a896d7b9284a03d615ed635d6f992'
REPOSITORY = 'https://github.com/mk270/whitakers-words.git'
SOURCE = ROOT / '.build' / 'words-source'
DESTINATION = ROOT / 'macOS' / 'Dictionary' / 'WORDS'
# Package only runtime data; dictionary-generation inputs and intermediates stay in SOURCE.
DATA_FILES = ['ADDONS.LAT', 'INFLECTS.LAT', 'UNIQUES.LAT',
              'DICTFILE.GEN', 'STEMFILE.GEN', 'INDXFILE.GEN',
              'INFLECTS.SEC', 'EWDSFILE.GEN']

def run(args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)

def output(args):
    return subprocess.check_output(args, text=True).strip()

def main():
    environment = os.environ.copy()
    if environment.get('GNAT_ROOT'):
        environment['PATH'] = str(Path(environment['GNAT_ROOT']) / 'bin') + os.pathsep + environment['PATH']
    for tool in ['gprbuild', 'gnatls', 'gcc']:
        if not shutil.which(tool, path=environment['PATH']):
            raise SystemExit('Install native macOS ARM64 GNAT/GPRBuild or set GNAT_ROOT; missing ' + tool)
    target = subprocess.check_output(['gcc', '-dumpmachine'], env=environment, text=True).strip()
    if not target.startswith('aarch64-apple-darwin'):
        raise SystemExit('Expected native Apple-silicon GNAT, got ' + target)
    sdk = output(['xcrun', '--sdk', 'macosx', '--show-sdk-path'])
    # GPR External_As_List splits on spaces. Use a path without spaces for the SDK.
    sdk_temp = tempfile.TemporaryDirectory(prefix='iwords-sdk-', dir='/private/tmp')
    sdk_link = Path(sdk_temp.name) / 'MacOSX.sdk'
    sdk_link.symlink_to(sdk)
    environment['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
    environment['ADAFLAGS'] = '-O2 -mmacosx-version-min=14.0 -isysroot ' + str(sdk_link)
    environment['LDFLAGS'] = '-mmacosx-version-min=14.0 -Wl,-syslibroot,' + str(sdk_link)
    if not SOURCE.exists():
        run(['git', 'clone', REPOSITORY, str(SOURCE)])
    run(['git', 'checkout', '--detach', REVISION], cwd=SOURCE)
    patch = ROOT / 'scripts' / 'patches' / 'words-no-trampoline.patch'
    # The build checkout is disposable; restore only our known patched file.
    run(['git', 'restore', 'src/words_engine/words_engine-parse.adb'], cwd=SOURCE)
    run(['git', 'apply', str(patch)], cwd=SOURCE)
    run(['make', 'clean'], cwd=SOURCE, env=environment)
    run(['make'], cwd=SOURCE, env=environment)
    executable = SOURCE / 'bin' / 'words'
    if output(['lipo', '-archs', str(executable)]) != 'arm64':
        raise SystemExit('Engine is not ARM64')
    linkage = output(['otool', '-L', str(executable)])
    dependencies = [line.strip().split(' (')[0] for line in linkage.splitlines()[1:]]
    if dependencies != ['/usr/lib/libSystem.B.dylib']:
        raise SystemExit('Unexpected runtime dependencies: ' + repr(dependencies))
    # Remove build-directory search paths: the Ada runtime is statically linked.
    loads = output(['otool', '-l', str(executable)]).splitlines()
    for index, line in enumerate(loads):
        if line.strip() == 'cmd LC_RPATH':
            path = loads[index + 2].strip().split('path ', 1)[1].split(' (offset')[0]
            run(['install_name_tool', '-delete_rpath', path, str(executable)])
    run(['strip', '-S', str(executable)])
    run(['codesign', '--force', '--options=runtime', '--sign', '-', str(executable)])
    shutil.copy2(executable, DESTINATION / 'words')
    for name in DATA_FILES:
        shutil.copy2(SOURCE / name, DESTINATION / name)
    shutil.copy2(SOURCE / 'LICENCE.txt', ROOT / 'docs' / 'WORDS-LICENCE.txt')
    files = ['words', 'WORD.MDV'] + DATA_FILES
    manifest = {
        'repository': REPOSITORY, 'revision': REVISION, 'architecture': 'arm64',
        'minimumMacOS': '14.0', 'compilerTarget': target,
        'patchSHA256': hashlib.sha256(patch.read_bytes()).hexdigest(),
        'compilerVersion': subprocess.check_output(['gnatls', '--version'], env=environment, text=True).splitlines()[0],
        'sdkVersion': output(['xcrun', '--sdk', 'macosx', '--show-sdk-version']),
        'sha256': {name: hashlib.sha256((DESTINATION / name).read_bytes()).hexdigest() for name in files}
    }
    (ROOT / 'docs' / 'engine-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print('Built and packaged ARM64 WORDS at ' + REVISION)

if __name__ == '__main__':
    main()
