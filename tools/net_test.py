"""Start een host en een client (headless) en laat ze de nettest draaien.

Gebruik:
    py -3.11 tools/net_test.py                # met de editor-Godot op het project
    py -3.11 tools/net_test.py --exe builds/windows/Diepgang.console.exe
    py -3.11 tools/net_test.py --latency=60 --jitter=15 --loss=1   # zoals over het internet
Exitcode 0 als beide instanties slagen.
"""

import argparse
import os
import subprocess
import sys
import threading
import time
from pathlib import Path

from udp_lag_proxy import LagProxy

ROOT = Path(__file__).resolve().parents[1]
GODOT = Path(os.environ["LOCALAPPDATA"]) / "Programs/Godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe"


def launch(cmd: list[str], tag: str, lines: list[str]) -> subprocess.Popen:
    proc = subprocess.Popen(cmd, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, encoding="utf-8", errors="replace")

    def pump() -> None:
        for line in proc.stdout:
            line = line.rstrip()
            lines.append(line)
            if line.startswith(("[mol", "[finds", "[net", "[game", "[terrain_sync", "SCRIPT ERROR", "ERROR")) and "material\" is null" not in line:
                print(f"{tag} {line}", flush=True)

    threading.Thread(target=pump, daemon=True).start()
    return proc


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser()
    ap.add_argument("--exe", help="geëxporteerde build i.p.v. de editor")
    ap.add_argument("--port", type=int, default=24599)
    ap.add_argument("--timeout", type=float, default=280.0)
    ap.add_argument("--scenario", default="net_test", help="net_test of net_ship_test")
    ap.add_argument("--latency", type=float, default=0.0, help="ms per richting (via udp_lag_proxy)")
    ap.add_argument("--jitter", type=float, default=0.0, help="± ms")
    ap.add_argument("--loss", type=float, default=0.0, help="% verlies per pakket")
    args = ap.parse_args()
    proxy = None
    join_port = args.port
    if args.latency > 0 or args.jitter > 0 or args.loss > 0:
        join_port = args.port + 1
        proxy = LagProxy(join_port, ("127.0.0.1", args.port), args.latency, args.jitter, args.loss)
        proxy.start()
        print(f"[proxy] {args.latency}±{args.jitter} ms per richting, {args.loss}% verlies")

    base = [str(ROOT / args.exe)] if args.exe else [str(GODOT), "--path", "game"]
    common = ["--headless", "--", f"--scenario={args.scenario}", "--no-steam", f"--port={args.port}"]
    # --headless moet voor `--`, de rest erna.
    host_cmd = base + common[:1] + common[1:] + ["--host"]
    client_cmd = base + ["--headless", "--", f"--scenario={args.scenario}", "--no-steam", f"--port={join_port}", "--join=127.0.0.1"]

    host_lines: list[str] = []
    client_lines: list[str] = []
    host = launch(host_cmd, "[HOST  ]", host_lines)
    time.sleep(3.0)
    client = launch(client_cmd, "[CLIENT]", client_lines)

    deadline = time.time() + args.timeout
    for proc in (host, client):
        try:
            proc.wait(timeout=max(1.0, deadline - time.time()))
        except subprocess.TimeoutExpired:
            proc.kill()
            print("time-out: proces gestopt")
    if proxy:
        print(f"[proxy] verstuurd {proxy.sent}, weggegooid {proxy.dropped}")
        proxy.stop()
    ok = host.returncode == 0 and client.returncode == 0
    print(f"host exit={host.returncode} client exit={client.returncode} → {'GESLAAGD' if ok else 'GEFAALD'}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
