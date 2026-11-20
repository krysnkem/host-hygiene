# Template for the tap formula (Formula/host-hygiene.rb in the homebrew-tap repo).
class HostHygiene < Formula
  desc "Find what eats disk, memory and CPU on a Mac, and clear it only when you say so"
  homepage "https://github.com/krysnkem/host-hygiene"
  url "https://github.com/krysnkem/host-hygiene/releases/download/v1.0.1/host-hygiene-1.0.1.tar.gz"
  sha256 "60dea427c4a979e8198a14135ff8293e54d6cd6d98f2655606f169c0f7b6a914"
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
      Run `hh` to open the interface, and `hh schedule on` for disk, memory and CPU alarms.
      Your settings live in ~/.config/host-hygiene and are kept if you uninstall.
      If you turned alarms on, run `hh schedule off` before `brew uninstall host-hygiene`.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/hh --version")
    assert_match "hh_tui-", shell_output("#{bin}/hh --tui-bin")
  end
end
