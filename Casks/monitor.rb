cask "monitor" do
  version "0.1.0"
  sha256 "34d4f4a03a3ee23f9c7838e8b4deed4015c66d61e31e62849ae938c0b20e6155"

  url "https://github.com/doumAb180/monitor-control/releases/download/v#{version}/Monitor-#{version}-arm64.dmg"
  name "Monitor"
  desc "Precise external monitor volume and brightness control"
  homepage "https://github.com/doumAb180/monitor-control"

  depends_on arch: :arm64
  depends_on macos: :ventura

  app "Monitor.app"

  zap trash: "~/Library/Preferences/io.github.doumAb180.Monitor.plist"
end
