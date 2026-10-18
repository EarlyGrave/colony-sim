#!/usr/bin/env python3
"""Web build smoke test: export, serve, load in Chromium (844x390, DPR 3, touch).

Usage: PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers python3 tools/web_smoke.py [--no-export] [--out DIR]
Needs `pip install playwright==1.56.0` (matches the pre-installed chromium-1194) (never `playwright install`; Chromium is pre-installed).
Software GL: FPS is a LOWER BOUND. Exit code 1 on console errors / boot failure.
"""
import argparse
import functools
import http.server
import os
import subprocess
import sys
import threading
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEF_OUT = "/tmp/claude-0/-home-user-colony-sim/2c9ef3d5-c73d-4d98-a862-7d15a0bb0a1a/scratchpad"
os.environ.setdefault("PLAYWRIGHT_BROWSERS_PATH", "/opt/pw-browsers")


def shot(pg, path: str) -> None:
	try:  # software GL can take minutes per frame at DPR 3
		pg.screenshot(path=path, timeout=180000)
	except Exception as e:  # noqa: BLE001
		print("screenshot failed:", path, str(e).splitlines()[0])


def main() -> int:
	ap = argparse.ArgumentParser()
	ap.add_argument("--no-export", action="store_true")
	ap.add_argument("--out", default=DEF_OUT)
	ap.add_argument("--boot-timeout", type=int, default=150)
	ap.add_argument("--fps-secs", type=int, default=8)
	a = ap.parse_args()
	os.makedirs(a.out, exist_ok=True)
	web = os.path.join(ROOT, "build/web")
	if not a.no_export:
		os.makedirs(web, exist_ok=True)
		subprocess.run(["godot", "--headless", "--path", ROOT, "--export-release", "Web", "build/web/index.html"], check=True)
	size = sum(os.path.getsize(os.path.join(web, f)) for f in os.listdir(web))
	print("export size: %.1f MB (wasm %.1f, pck %.1f)" % (size / 1e6,
		os.path.getsize(os.path.join(web, "index.wasm")) / 1e6, os.path.getsize(os.path.join(web, "index.pck")) / 1e6))
	class Quiet(http.server.SimpleHTTPRequestHandler):
		def log_message(self, *args):  # noqa: D401
			pass

	handler = functools.partial(Quiet, directory=web)
	srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
	threading.Thread(target=srv.serve_forever, daemon=True).start()
	base = "http://127.0.0.1:%d/index.html" % srv.server_address[1]

	from playwright.sync_api import sync_playwright
	errors: list = []
	ok = True
	with sync_playwright() as p:
		br = p.chromium.launch(args=["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"])
		for name, query in (("tutorial", ""), ("size250", "?size=250")):
			ctx = br.new_context(viewport={"width": 844, "height": 390}, device_scale_factor=3, has_touch=True, is_mobile=True)
			pg = ctx.new_page()
			pg.on("console", lambda m, n=name: errors.append((n, m.text)) if m.type in ("error", "warning") and "GL Driver Message" not in m.text else None)
			pg.on("pageerror", lambda e, n=name: errors.append((n, "pageerror: %s" % e)))
			t0 = time.time()
			pg.goto(base + query)
			booted = False
			while time.time() - t0 < a.boot_timeout:
				time.sleep(2)
				if pg.evaluate("!!document.querySelector('canvas') && (document.getElementById('status') === null || document.getElementById('status').style.visibility === 'hidden')"):
					booted = True
					break
			print("[%s] boot %s in %.0fs" % (name, "ok" if booted else "FAILED", time.time() - t0))
			ok &= booted
			time.sleep(3)
			shot(pg, os.path.join(a.out, "w2e_%s_main.png" % name))
			if name == "tutorial":  # tap along the bottom toolbar
				for x in (60, 160, 260, 360, 460, 560, 660):
					pg.touchscreen.tap(x, 370)
					time.sleep(1.5)
				shot(pg, os.path.join(a.out, "w2e_%s_toolbar.png" % name))
			pg.evaluate("window.__f = 0; (function l(){ window.__f++; requestAnimationFrame(l); })()")
			time.sleep(a.fps_secs)
			fps = pg.evaluate("window.__f") / a.fps_secs
			mem = pg.evaluate("performance.memory ? performance.memory.usedJSHeapSize : 0")
			wasm = pg.evaluate("(window.Module && Module.HEAPU8) ? Module.HEAPU8.length : 0")
			print("[%s] fps>=%.1f (lower bound, software GL) jsheap=%.0f MB wasmheap=%.0f MB" % (name, fps, mem / 1e6, wasm / 1e6))
			shot(pg, os.path.join(a.out, "w2e_%s_end.png" % name))
			ctx.close()
		br.close()
	srv.shutdown()
	for n, t in errors:
		print("CONSOLE [%s] %s" % (n, t))
	if errors:
		ok = False
	print("WEB SMOKE", "PASS" if ok else "FAIL")
	return 0 if ok else 1


if __name__ == "__main__":
	sys.exit(main())
