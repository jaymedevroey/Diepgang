"""UDP-tussenstation dat internet nabootst: vertraging, schommeling en verlies.

De client verbindt met dit station in plaats van met de host; elk pakket wordt in beide richtingen
`latency` ms (± `jitter`) vastgehouden en met kans `loss` % weggegooid. Door de schommeling komen
pakketten soms in een andere volgorde aan, zoals echt.

Los gebruiken:
    py -3.11 tools/udp_lag_proxy.py --listen=24600 --target=127.0.0.1:24599 --latency=60 --jitter=15 --loss=1
Vanuit tools/net_test.py met --latency/--jitter/--loss.
"""

import argparse
import heapq
import random
import socket
import threading
import time


class LagProxy:
    def __init__(self, listen_port: int, target: tuple[str, int], latency_ms: float, jitter_ms: float,
                 loss_pct: float, seed: int = 1) -> None:
        self.target = target
        self.latency = latency_ms / 1000.0
        self.jitter = jitter_ms / 1000.0
        self.loss = loss_pct / 100.0
        self.rng = random.Random(seed)
        self.front = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.front.bind(("127.0.0.1", listen_port))
        self.client_addr: tuple[str, int] | None = None
        self.back = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.back.bind(("127.0.0.1", 0))
        self.queue: list[tuple[float, int, socket.socket, bytes, tuple[str, int]]] = []
        self.lock = threading.Condition()
        self.n = 0
        self.sent = 0
        self.dropped = 0
        self.running = True

    def _delay(self) -> float:
        return max(0.0, self.latency + self.rng.uniform(-self.jitter, self.jitter))

    def _push(self, sock: socket.socket, data: bytes, addr: tuple[str, int]) -> None:
        if self.rng.random() < self.loss:
            self.dropped += 1
            return
        with self.lock:
            self.n += 1
            heapq.heappush(self.queue, (time.monotonic() + self._delay(), self.n, sock, data, addr))
            self.lock.notify()

    def _from_client(self) -> None:
        while self.running:
            try:
                data, addr = self.front.recvfrom(65535)
            except OSError:
                return
            self.client_addr = addr
            self._push(self.back, data, self.target)

    def _from_host(self) -> None:
        while self.running:
            try:
                data, _ = self.back.recvfrom(65535)
            except OSError:
                return
            if self.client_addr:
                self._push(self.front, data, self.client_addr)

    def _sender(self) -> None:
        while self.running:
            with self.lock:
                while self.running and (not self.queue or self.queue[0][0] > time.monotonic()):
                    wait = (self.queue[0][0] - time.monotonic()) if self.queue else 0.5
                    self.lock.wait(max(0.0005, wait))
                if not self.running:
                    return
                _, _, sock, data, addr = heapq.heappop(self.queue)
            try:
                sock.sendto(data, addr)
                self.sent += 1
            except OSError:
                pass

    def start(self) -> None:
        for f in (self._from_client, self._from_host, self._sender):
            threading.Thread(target=f, daemon=True).start()

    def stop(self) -> None:
        self.running = False
        with self.lock:
            self.lock.notify_all()
        self.front.close()
        self.back.close()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--listen", type=int, default=24600)
    ap.add_argument("--target", default="127.0.0.1:24599")
    ap.add_argument("--latency", type=float, default=60.0, help="ms per richting")
    ap.add_argument("--jitter", type=float, default=15.0, help="± ms")
    ap.add_argument("--loss", type=float, default=1.0, help="% per pakket")
    args = ap.parse_args()
    host, port = args.target.rsplit(":", 1)
    p = LagProxy(args.listen, (host, int(port)), args.latency, args.jitter, args.loss)
    p.start()
    print(f"[proxy] 127.0.0.1:{args.listen} → {args.target}: {args.latency}±{args.jitter} ms, {args.loss}% verlies")
    try:
        while True:
            time.sleep(5)
            print(f"[proxy] verstuurd {p.sent}, weggegooid {p.dropped}")
    except KeyboardInterrupt:
        p.stop()


if __name__ == "__main__":
    main()
