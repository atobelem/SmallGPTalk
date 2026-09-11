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


def run(command, log, env, timeout=300):
    with log.open('w') as output:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=output,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        try:
            code = process.wait(timeout=timeout)
        except BaseException:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
            raise
    if code:
        raise RuntimeError(f'Check failed ({code}). Read {log}')
    print(f'PASS: {log.stem}. Log: {log}', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--native', action='store_true', help='Check four native views.')
    parser.add_argument('--live', action='store_true', help='Use the stored OpenAI login.')
    args = parser.parse_args()
    base = Path(os.environ['SMALLGPTALK_BASE_IMAGE']).resolve()
    vm = os.environ.get('SMALLGPTALK_VM', str(Path.home() /
        'Documents/Pharo/vms/130-x64/Pharo.app/Contents/MacOS/Pharo'))
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
        run(command, directory / f'{name}.log', check_env)
    print(f'All selected checks passed. Loaded image: {loaded}', flush=True)


if __name__ == '__main__':
    main()
