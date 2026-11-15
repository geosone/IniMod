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


# The fork release version must match the MSI, archive and Debian package names.
assert run("--version").startswith("IniMod 1.0.4 "), run("--version")

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

    # --no-bom: a new (empty) INI gets plain UTF-8, no blank first line, and
    # repeated writes keep exactly one blank line between sections.
    fresh = pathlib.Path(directory) / "fresh.ini"
    fresh.write_bytes(b"")
    for section, key, value in (("COMMON", "VENDOR", "x"), ("COMMON", "PN", "y"), ("OTHER", "c", "3"), ("COMMON", "PN", "z")):
        run("w", str(fresh), "-s", section, "-k", key, "-v", value, "--silent", "--no-bom")
    assert fresh.read_bytes() == b"[COMMON]\nVENDOR=x\nPN=z\n\n[OTHER]\nc=3\n", fresh.read_bytes()

    # Without --no-bom the historic default (UTF-8 with BOM) is unchanged.
    bom = pathlib.Path(directory) / "bom.ini"
    bom.write_bytes(b"")
    run("w", str(bom), "-s", "S", "-k", "k", "-v", "v", "--silent")
    assert bom.read_bytes() == b"\xef\xbb\xbf[S]\nk=v\n", bom.read_bytes()
print("PASS IniMod 1.0.4 version, real read/write, UTF-8, comments, key rename/removal, section removal, syntax exit code, --no-bom and stable section layout.")
