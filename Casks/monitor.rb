cask "monitor" do
  version "0.2.0"
  sha256 "9fadc9db112d7a952e33053e32cae810f14753609772aa0c9449e8ac58fe1288"

  url "https://github.com/doumAb180/monitor-control/releases/download/v#{version}/Monitor-#{version}-arm64.dmg"
  name "Monitor"
  desc "Precise external monitor volume and brightness control"
  homepage "https://github.com/doumAb180/monitor-control"

  depends_on arch: :arm64
  depends_on macos: :ventura

  app "Monitor.app"

  zap trash: "~/Library/Preferences/io.github.doumAb180.Monitor.plist"
end
