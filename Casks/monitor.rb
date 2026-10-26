cask "monitor" do
  version "0.2.1"
  sha256 "b5d759dafa06ebc22c27c9d90e1aee1fa42362e416bdcb7a4537c3abc22e1b4f"

  url "https://github.com/doumAb180/monitor-control/releases/download/v#{version}/Monitor-#{version}-arm64.dmg"
  name "Monitor"
  desc "Precise external monitor volume and brightness control"
  homepage "https://github.com/doumAb180/monitor-control"

  depends_on arch: :arm64
  depends_on macos: :ventura

  app "Monitor.app"

  zap trash: "~/Library/Preferences/io.github.doumAb180.Monitor.plist"
end
