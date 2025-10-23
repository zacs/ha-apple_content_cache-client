# ha-apple_content_cache-client

![Build Status](https://github.com/zacs/ha-apple_content_cache-client/actions/workflows/homebrew.yml/badge.svg)
![Last Commit](https://img.shields.io/github/last-commit/zacs/ha-apple_content_cache-client)
![License](https://img.shields.io/github/license/zacs/ha-apple_content_cache-client)

A Homebrew-installable client that pushes **Apple Content Caching** metrics from macOS to Home Assistant via the REST API.

Each cache metric (used, free, iCloud, etc.) becomes its own dynamic sensor in Home Assistant — no YAML templates or webhooks required.

---

## 🧩 Installation

```bash
brew tap zacs/ha-apple_content_cache-client
brew install ha-apple_content_cache_client
brew services start zacs/ha-apple_content_cache-client/ha-apple_content_cache_client
```

---

## ⚙️ Configuration

Edit the configuration file at:

```bash
/usr/local/etc/ha-apple_content_cache-client/.env
```

Example:

```bash
HA_URL="https://your-home-assistant.local:8123"
HA_TOKEN="your_token_here"
CLIENT_ID="macos_server"
CACHE_NAME="Primary Apple Cache"
```

| Variable | Description | Required | Default |
|-----------|--------------|-----------|----------|
| `HA_URL` | Home Assistant base URL | ✅ | — |
| `HA_TOKEN` | Long-lived access token | ✅ | — |
| `CLIENT_ID` | Custom client name for sensor IDs | ❌ | `hostname -s` |
| `CACHE_NAME` | Friendly display name in HA | ❌ | Apple Content Caching |

---

## 📊 Entities Created

| Entity ID Pattern | Example | Type | Units |
|-------------------|----------|------|--------|
| `sensor.<client>_apple_content_caching_used` | `sensor.macmini_seattle_apple_content_caching_used` | Numeric | MB |
| `sensor.<client>_apple_content_caching_free` | ... | Numeric | MB |
| `sensor.<client>_apple_content_caching_actual` | ... | Numeric | MB |
| `sensor.<client>_apple_content_caching_icloud` | ... | Numeric | MB |
| `sensor.<client>_apple_content_caching_ios` | ... | Numeric | MB |
| `sensor.<client>_apple_content_caching_mac` | ... | Numeric | MB |
| `sensor.<client>_apple_content_caching_other` | ... | Numeric | MB |
| `sensor.<client>_apple_content_caching_origin` | ... | Numeric | MB |
| `sensor.<client>_apple_content_caching_clients` | ... | Numeric | MB |
| `sensor.<client>_apple_content_caching_dropped` | ... | Numeric | MB |
| `binary_sensor.<client>_apple_content_caching_active` | ... | Boolean | — |

---

## 📄 Logs

```bash
tail -f /usr/local/var/log/ha-apple_content_cache-client.log
```

---

MIT © [zacs](https://github.com/zacs)
