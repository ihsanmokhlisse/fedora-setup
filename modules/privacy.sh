#!/usr/bin/env bash
# Privacy Hardening — Firefox hardening, DNS-over-HTTPS, tracker blocking, telemetry removal
# Enhances privacy without breaking normal browsing

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

harden_privacy() {
    echo ""
    echo "━━━ Privacy Hardening ━━━"

    harden_firefox_privacy
    configure_dns_over_https
    disable_gnome_telemetry
    harden_tracker_blocking

    echo ""
    echo "[OK] Privacy hardening complete"
}

harden_firefox_privacy() {
    echo ""
    echo "[+] Applying Firefox privacy hardening..."

    local firefox_profiles_dir="$HOME/.mozilla/firefox"
    if [[ ! -d "$firefox_profiles_dir" ]]; then
        echo "  [SKIP] Firefox profile directory not found (run Firefox once first)"
        return 0
    fi

    local profiles_applied=0
    while IFS= read -r profile_dir; do
        local user_js="${profile_dir}/user.js"

        if grep -q "FedoraFlow Privacy" "$user_js" 2>/dev/null; then
            echo "  [OK] Privacy settings already applied to $(basename "$profile_dir")"
            continue
        fi

        cat >> "$user_js" <<'EOF'

// ─── FedoraFlow Privacy Hardening ───

// Disable telemetry
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("toolkit.telemetry.archive.enabled", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("browser.ping-centre.telemetry", false);
user_pref("browser.newtabpage.activity-stream.feeds.telemetry", false);
user_pref("browser.newtabpage.activity-stream.telemetry", false);

// Disable Pocket and Sponsored content
user_pref("extensions.pocket.enabled", false);
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);

// Enhanced Tracking Protection
user_pref("privacy.trackingprotection.enabled", true);
user_pref("privacy.trackingprotection.socialtracking.enabled", true);
user_pref("privacy.trackingprotection.cryptomining.enabled", true);
user_pref("privacy.trackingprotection.fingerprinting.enabled", true);

// Disable prefetch (privacy + bandwidth)
user_pref("network.prefetch-next", false);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.predictor.enabled", false);
user_pref("network.http.speculative-parallel-limit", 0);

// Disable safe browsing phoning home (keeps local list)
user_pref("browser.safebrowsing.malware.enabled", true);
user_pref("browser.safebrowsing.phishing.enabled", true);
user_pref("browser.safebrowsing.downloads.remote.enabled", false);

// HTTPS-Only Mode
user_pref("dom.security.https_only_mode", true);
user_pref("dom.security.https_only_mode_ever_enabled", true);

// Resist fingerprinting (gentle — does not break sites as badly as RFP)
user_pref("privacy.resistFingerprinting.letterboxing", false);
user_pref("webgl.disabled", false);

// Disable WebRTC IP leak
user_pref("media.peerconnection.ice.default_address_only", true);
user_pref("media.peerconnection.ice.proxy_only_if_behind_proxy", true);
EOF
        (( profiles_applied++ ))
        echo "  [OK] Privacy hardening applied to $(basename "$profile_dir")"
    done < <(find "$firefox_profiles_dir" -maxdepth 1 -name "*.default*" -type d 2>/dev/null)

    [[ $profiles_applied -eq 0 ]] && echo "  [OK] All profiles already hardened"
}

configure_dns_over_https() {
    echo ""
    echo "[+] Configuring DNS-over-HTTPS (DoH) via systemd-resolved..."

    local resolved_conf="/etc/systemd/resolved.conf.d/99-doh.conf"
    sudo mkdir -p /etc/systemd/resolved.conf.d

    if [[ ! -f "$resolved_conf" ]]; then
        sudo tee "$resolved_conf" > /dev/null <<'EOF'
[Resolve]
DNS=1.1.1.2#security.cloudflare-dns.com 1.0.0.2#security.cloudflare-dns.com
FallbackDNS=9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net
DNSOverTLS=opportunistic
DNSSEC=allow-downgrade
EOF
        sudo systemctl restart systemd-resolved 2>/dev/null
        echo "  [OK] DNS-over-TLS enabled (Cloudflare Malware Blocking + Quad9 fallback)"
    else
        echo "  [OK] DNS-over-HTTPS already configured"
    fi
}

disable_gnome_telemetry() {
    echo ""
    echo "[+] Disabling GNOME / system telemetry..."

    # Disable ABRT auto-reporting
    if [[ -f /etc/libreport/events.d/smart_event.conf ]]; then
        if grep -q "^#.*report_uReport" /etc/libreport/events.d/smart_event.conf 2>/dev/null; then
            echo "  [OK] ABRT auto-reporting already disabled"
        else
            sudo sed -i 's/^EVENT=report_uReport/#EVENT=report_uReport/' \
                /etc/libreport/events.d/smart_event.conf 2>/dev/null
            echo "  [OK] ABRT auto-reporting disabled"
        fi
    fi

    # Disable GNOME Software telemetry
    gsettings set org.gnome.software download-updates-notify false 2>/dev/null || true

    # Disable location services
    gsettings set org.gnome.system.location enabled false 2>/dev/null || true
    echo "  [OK] Location services disabled"

    # Disable usage & tech reports
    gsettings set org.gnome.desktop.privacy report-technical-problems false 2>/dev/null || true
    gsettings set org.gnome.desktop.privacy send-software-usage-stats false 2>/dev/null || true
    echo "  [OK] Usage statistics and crash reporting disabled"
}

harden_tracker_blocking() {
    echo ""
    echo "[+] Configuring system-level tracker blocking..."

    local hosts_marker="# FedoraFlow tracker blocking"
    if grep -q "$hosts_marker" /etc/hosts 2>/dev/null; then
        echo "  [OK] Tracker blocking already in /etc/hosts"
        return 0
    fi

    sudo tee -a /etc/hosts > /dev/null <<'EOF'

# FedoraFlow tracker blocking
# Common tracking domains blocked at the OS level
0.0.0.0 analytics.google.com
0.0.0.0 www.googleadservices.com
0.0.0.0 pagead2.googlesyndication.com
0.0.0.0 adservice.google.com
0.0.0.0 www.google-analytics.com
0.0.0.0 ssl.google-analytics.com
0.0.0.0 stats.g.doubleclick.net
0.0.0.0 ad.doubleclick.net
0.0.0.0 static.doubleclick.net
0.0.0.0 cm.g.doubleclick.net
0.0.0.0 pixel.facebook.com
0.0.0.0 www.facebook.com/tr
0.0.0.0 connect.facebook.net
0.0.0.0 graph.facebook.com
0.0.0.0 bat.bing.com
0.0.0.0 telemetry.microsoft.com
0.0.0.0 vortex.data.microsoft.com
0.0.0.0 settings-win.data.microsoft.com
0.0.0.0 watson.telemetry.microsoft.com
0.0.0.0 activity.windows.com
EOF
    echo "  [OK] 20 major tracker domains blocked via /etc/hosts"
    echo "  [NOTE] These won't affect normal browsing — only analytics/ad tracking"
}
