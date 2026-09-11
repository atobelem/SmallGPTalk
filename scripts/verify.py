#!/usr/bin/env python3
"""Run isolated Pharo checks. Live account access requires --live."""
import argparse
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent


def copy_image(source, directory):
    directory.mkdir(parents=True)
    target = directory / 'SmallGPTalk.image'
    shutil.copy2(source, target)
    shutil.copy2(source.with_suffix('.changes'), target.with_suffix('.changes'))
    for path in source.parent.glob('*.sources'):
        shutil.copy2(path, directory / path.name)
    return target


def run(command, log, env, timeout=300, cwd=None):
    with log.open('w') as output:
        process = subprocess.Popen(command, cwd=cwd or log.parent, env=env, stdout=output,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        try:
            code = process.wait(timeout=timeout)
        except BaseException as error:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()
            if isinstance(error, subprocess.TimeoutExpired):
                raise RuntimeError(f'Check timed out after {timeout} seconds. Read {log}') from None
            raise
    if code:
        raise RuntimeError(f'Check failed ({code}). Read {log}')
    print(f'PASS: {log.stem}. Log: {log}', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--native', action='store_true', help='Check four native views.')
    parser.add_argument('--live', action='store_true', help='Use the stored OpenAI login.')
    args = parser.parse_args()
    base_name = os.environ.get('SMALLGPTALK_BASE_IMAGE')
    if not base_name:
        parser.error('Set SMALLGPTALK_BASE_IMAGE to a clean Pharo 13 image.')
    base = Path(base_name).expanduser().resolve()
    for path in (base, base.with_suffix('.changes')):
        if not path.is_file():
            parser.error(f'File not found: {path}')
    if not any(base.parent.glob('*.sources')):
        parser.error(f'No Pharo sources file in {base.parent}')
    vm = os.environ.get('SMALLGPTALK_VM', str(Path.home() /
        'Documents/Pharo/vms/130-x64/Pharo.app/Contents/MacOS/Pharo'))
    executable = shutil.which(os.path.expanduser(vm))
    if not executable:
        parser.error('Set SMALLGPTALK_VM to an executable Pharo VM.')
    vm = str(Path(executable).resolve())
    (ROOT / '.build').mkdir(exist_ok=True)
    directory = Path(tempfile.mkdtemp(prefix='verify-', dir=ROOT / '.build'))
    print(f'Verification: {directory}', flush=True)
    env = dict(os.environ, SMALLGPTALK_ROOT=str(ROOT),
               SMALLGPTALK_BASE_IMAGE=str(base), SMALLGPTALK_VM=vm,
               SMALLGPTALK_TEST_IMAGE_FILE=str(directory / 'image.txt'))
    run(['bash', str(ROOT / 'scripts/test.sh')], directory / 'tests.log', env)
    loaded = Path((directory / 'image.txt').read_text().strip())
    checks = [('source', loaded, False), ('core', base, False),
              ('refresh-cost', loaded, False)]
    if args.native:
        checks += [(name, loaded, True) for name in
                   ('chat', 'stream-view', 'context-estimate-ui', 'evaluations')]
    if args.live:
        checks.append(('live-session', loaded, False))
    for name, source, native in checks:
        image = copy_image(source, directory / name)
        output = image.parent / 'output'
        output.mkdir()
        check_env = dict(env, SMALLGPTALK_CHECK_DIR=str(output))
        command = [vm] + ([] if native else ['--headless'])
        command += [str(image), 'st', str(ROOT / 'scripts' / f'check-{name}.st')]
        run(command, directory / f'{name}.log', check_env, cwd=image.parent)
    print(f'All selected checks passed. Loaded image: {loaded}', flush=True)


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError) as error:
        raise SystemExit(str(error)) from None
