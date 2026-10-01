"""Use the same fail-closed temporary root as the shell test suites."""

from contextlib import contextmanager
from pathlib import Path
import subprocess

HELPER = Path(__file__).with_name("temp.sh")


@contextmanager
def temporary_directory():
    made = subprocess.run(["bash", "-c", '. "$1"; new_test_temp_dir made; printf "%s" "$made"',
                           "test-temp", str(HELPER)], capture_output=True, text=True, check=True)
    try:
        yield made.stdout
    finally:
        subprocess.run(["bash", "-c", '. "$1"; remove_test_temp_dir "$2"',
                        "test-temp", str(HELPER), made.stdout], check=True)
