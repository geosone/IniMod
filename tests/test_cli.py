"""Exercise the real CLI in a private directory; never edit operator INIs."""
import pathlib
import subprocess
import sys
import tempfile

exe = str(pathlib.Path(sys.argv[1]).resolve())


def run(*args):
    result = subprocess.run([exe, *args], capture_output=True, text=True, encoding="utf-8")
    if result.returncode:
        raise AssertionError(f"CLI failed ({result.returncode}): {result.stderr}")
    return result.stdout.strip()


with tempfile.TemporaryDirectory(prefix="inimod-test-") as directory:
    path = pathlib.Path(directory) / "settings.ini"
    path.write_text("; retained comment\n[General]\nBaseDir=/opt/mystic\nKeep=yes\n", encoding="utf-8")
    run("w", str(path), "-s", "General", "-k", "Name", "-v", "Grüße Österreich", "--silent")
    assert run("r", str(path), "-s", "General", "-k", "Name", "--silent") == "Grüße Österreich"
    assert run("r", str(path), "-s", "General", "-k", "Keep", "--silent") == "yes"
    assert "retained comment" in path.read_text(encoding="utf-8-sig")
    run("rnk", str(path), "-s", "General", "-k", "Name", "-kn", "BBSName", "--silent")
    assert run("r", str(path), "-s", "General", "-k", "BBSName", "--silent") == "Grüße Österreich"
    run("rmk", str(path), "-s", "General", "-k", "BBSName", "--silent")
    assert "BBSName=" not in path.read_text(encoding="utf-8-sig")
    run("w", str(path), "-s", "Temporary", "-k", "Key", "-v", "Value", "--silent")
    run("rms", str(path), "-s", "Temporary", "--silent")
    assert "[Temporary]" not in path.read_text(encoding="utf-8-sig")
    invalid = subprocess.run([exe, "invalid-command"], capture_output=True)
    assert invalid.returncode == 2, invalid.returncode
print("PASS real IniMod read/write, UTF-8, comments, key rename/removal, section removal and syntax exit code.")
