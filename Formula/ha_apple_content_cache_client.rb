class HaAppleContentCacheClient < Formula
  desc "Home Assistant Apple Content Caching client"
  homepage "https://github.com/zacs/homebrew-ha-apple_content_cache-client"
  url "https://github.com/zacs/homebrew-ha-apple_content_cache-client/archive/refs/tags/v0.1.10.tar.gz"
  sha256 "3838602bedcb14c8a1ad6bd0d26f304deb40afbffac3e5433c8ba9ab6afb2cb9"
  license "MIT"

  depends_on "jq"

  def install
    bin.install "bin/ha_apple_content_cache_client.sh"
    (etc/"ha-apple_content_cache-client").install ".env.example"
  end

  service do
    run [opt_bin/"ha_apple_content_cache_client.sh"]
    keep_alive true
    interval 300
    log_path var/"log/ha-apple_content_cache-client.log"
    error_log_path var/"log/ha-apple_content_cache-client.log"
    environment_variables(
      "ENV_PATH" => etc/"ha-apple_content_cache-client/.env",
    )
  end

  def caveats
    <<~EOS
      Configuration file:
        #{etc}/ha-apple_content_cache-client/.env

      Service commands:
        brew services start zacs/ha-apple_content_cache-client/ha-apple_content_cache_client
        brew services stop zacs/ha-apple_content_cache-client/ha-apple_content_cache_client

      Logs:
        tail -f #{var}/log/ha-apple_content_cache-client.log
    EOS
  end

  test do
    system "#{bin}/ha_apple_content_cache_client.sh", "--help"
  end
end
