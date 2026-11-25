# Template for the tap formula (Formula/host-hygiene.rb in the homebrew-tap repo). tools/render-formula.sh fills in the version and the checksum;
# the release workflow does that and pushes the result to the tap.
class HostHygiene < Formula
  desc "Find what eats disk, memory and CPU on a Mac, and clear it only when you say so"
  homepage "https://github.com/krysnkem/host-hygiene"
  url "https://github.com/krysnkem/host-hygiene/releases/download/v@VERSION@/host-hygiene-@VERSION@.tar.gz"
  sha256 "@SHA256@"
  license "MIT"

  depends_on :macos

  def install
    # The archive carries an interface binary for each chip; keep the one for this Mac.
    libexec.install Dir["*"]
    rm libexec/"tui/hh_tui-#{Hardware::CPU.arm? ? "x86_64" : "arm64"}"
    (bin/"hh").write <<~SH
      #!/bin/sh
      exec "#{libexec}/scripts/host-hygiene.sh" "$@"
    SH
    bin.install_symlink "hh" => "host-hygiene"
  end

  def caveats
    <<~EOS

        Start here:  hh

      Alarms for disk, memory and CPU (optional):  hh schedule on
      Before uninstalling, if alarms are on:       hh schedule off
      Your settings are kept in ~/.config/host-hygiene.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/hh --version")
    assert_match "hh_tui-", shell_output("#{bin}/hh --tui-bin")
  end
end
