#!/usr/bin/env python3
"""Pin the Homebrew tap to the exact DMG uploaded by the release job."""
import hashlib
import pathlib
import re
import sys

version, image_path = sys.argv[1:]
if not re.fullmatch(r"\d+\.\d+\.\d+", version):
    raise SystemExit("Version must have the form 1.2.3")
image = pathlib.Path(image_path)
if image.name != f"Monitor-{version}-arm64.dmg":
    raise SystemExit("The cask requires the matching arm64 DMG")
target = pathlib.Path(__file__).resolve().parent.parent / "Casks" / "monitor.rb"
if target.exists():
    old = re.search(r'version "(\d+\.\d+\.\d+)"', target.read_text())
    if old and tuple(map(int, old[1].split("."))) > tuple(map(int, version.split("."))):
        print("Keeping the newer cask version")
        raise SystemExit(0)
digest = hashlib.sha256(image.read_bytes()).hexdigest()
target.parent.mkdir(exist_ok=True)
target.write_text('''cask "monitor" do
  version "%s"
  sha256 "%s"

  url "https://github.com/doumAb180/monitor-control/releases/download/v#{version}/Monitor-#{version}-arm64.dmg"
  name "Monitor"
  desc "Precise external monitor volume and brightness control"
  homepage "https://github.com/doumAb180/monitor-control"

  depends_on arch: :arm64
  depends_on macos: :ventura

  app "Monitor.app"

  zap trash: "~/Library/Preferences/io.github.doumAb180.Monitor.plist"
end
''' % (version, digest))
print(f"Updated {target.name} to {version} ({digest})")
