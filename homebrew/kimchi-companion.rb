cask "kimchi-companion" do
  version "1.0.0"
  sha256 "PLACEHOLDER_SHA256"

  url "https://github.com/castai/kimchi-companion/releases/download/v#{version}/KimchiCompanion.dmg"
  name "Kimchi Companion"
  desc "macOS menu bar companion for CAST AI usage monitoring"
  homepage "https://github.com/castai/kimchi-companion"

  depends_on macos: ">= :sonoma"

  app "Kimchi Companion.app"

  zap trash: [
    "~/Library/Preferences/com.castai.kimchi-companion.plist",
    "~/Library/Caches/com.castai.kimchi-companion",
  ]
end
