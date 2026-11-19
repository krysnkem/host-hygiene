# Template for the tap formula (Formula/host-hygiene.rb in the homebrew-tap repo).
# Fill the sha256 printed by tools/make-release.sh after the final build.
class HostHygiene < Formula
  desc "Find what eats disk, memory and CPU on a Mac, and clear it only when you say so"
  homepage "https://github.com/krysnkem/host-hygiene"
  url "https://github.com/krysnkem/host-hygiene/releases/download/v1.0.0/host-hygiene-1.0.0.tar.gz"
  sha256 "FILL_FROM_make-release"
  license "MIT"

  depends_on :macos

  def install
    # The bundled interface is built for Apple Silicon; on Intel hh falls back to its shell menu.
    libexec.install Dir["*"]
    rm libexec/"tui/hh_tui" unless Hardware::CPU.arm?
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
  end
end
