# MacTwix — Known Fixes Reference

## Network Fixes (sysctl)

All values tested on Intel Mac / Broadcom BCM43602 / macOS Tahoe.
Safe to apply on Apple Silicon — same sysctl namespace.

### TCP Optimization (`fix-tcp-tahoe.sh --install`)

| Key | Optimized | Apple Default | Why |
|-----|-----------|---------------|-----|
| `net.inet.tcp.tso` | 0 | 1 | TSO broken on Broadcom/Tahoe, causes stalls |
| `net.inet.tcp.ecn_initiate_out` | 0 | 2 | ECN lottery — random drops on legacy routers |
| `net.inet.tcp.ecn_setup_percentage` | 0 | 100 | Disable ECN negotiation completely |
| `net.inet.tcp.mssdflt` | 1460 | 512 | Apple's insane default MSS = tiny packets |
| `net.inet.tcp.delayed_ack` | 0 | 3 | Immediate ACKs — faster loss recovery |
| `net.inet.tcp.win_scale_factor` | 8 | 3 | Larger TCP windows (256KB vs 8KB) |
| `net.inet.tcp.autorcvbufmax` | 33554432 | 4194304 | 32MB max receive buffer (was 4MB) |
| `net.inet.tcp.autosndbufmax` | 33554432 | 4194304 | 32MB max send buffer |
| `net.inet.tcp.sendspace` | 262144 | 131072 | 256KB initial send buffer |
| `net.inet.tcp.recvspace` | 262144 | 131072 | 256KB initial receive buffer |
| `net.inet.tcp.recv_allowed_iaj` | 100 | 5 | Relax IAJ throttling (was killing torrent traffic) |
| `net.inet.tcp.acc_iaj_react_limit` | 10000 | 200 | Higher threshold before IAJ kicks in |
| `net.inet.tcp.recv_throttle_minwin` | 4194304 | 0 | 4MB window before throttle considered |
| `net.inet.tcp.local_slowstart_flightsize` | 20 | 8 | Larger initial burst (local connections) |
| `net.inet.tcp.cubic_tcp_friendliness` | 1 | 0 | CUBIC plays nice with Reno flows |
| `net.inet.tcp.cubic_fast_convergence` | 1 | 0 | Faster CUBIC convergence after loss |
| `net.inet.tcp.cubic_use_minrtt` | 1 | 0 | Use min RTT for better CUBIC accuracy |

### AWDL Fix (`fix-wifi-tahoe.sh`)

| Action | Command | Effect |
|--------|---------|--------|
| Disable AWDL | `ifconfig awdl0 down` | Stops channel-switching. **10x throughput boost** on multi-connection workloads |
| Re-enable AWDL | `ifconfig awdl0 up` | Restores AirDrop/AirPlay |

### Power Management

| Setting | Value | Why |
|---------|-------|-----|
| `pmset womp` | 0 | Disable Wake on LAN (unnecessary probing) |
| `pmset tcpkeepalive` | 0 | Disable TCP keepalive during sleep (prevents Wi-Fi wakeups) |

## Experimental Fixes (not in default profile)

| Key | Value | Risk |
|-----|-------|------|
| `net.inet.tcp.use_newreno` | 1 | Force NewReno instead of CUBIC — less aggressive |
| `net.inet.tcp.do_ack_compression` | 0 | Disable ACK compression — more responsive |
| `net.inet.tcp.rack` | 0 | Disable RACK loss detection — simpler recovery |
| `net.inet.tcp.cubic_rfc_compliant` | 0 | Non-RFC CUBIC — more aggressive growth |

## Apple Silicon Notes

- `ifconfig awdl0 down` may be re-enabled automatically by macOS (Ventura+)
- Workaround: watchdog timer every 2-3 seconds
- Alternative: set router to channel 149 (AWDL's preferred channel)
- Universal Control also triggers AWDL — disable in System Settings if unneeded
