"""D4: summarise factory_eval.sh outputs. Args: tmpdir first last."""
import sys, json

t, f, l = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
rows = []
for s in range(f, l + 1):
    r = None
    try:
        for ln in open(f"{t}/{s}.out"):
            if ln.startswith("EVALJSON "):
                r = json.loads(ln[9:])
    except OSError:
        pass
    rows.append(r or {"seed": s, "over": "TIMEOUT/ERR"})
b = lambda x: "Y" if x else "-"
print("seed over            alive aud P1 P2 P3 P4 parts launch pol%  debt% refined real plates waste")
for r in rows:
    if "alive" not in r:
        print(f"{r['seed']:>4} {r['over']}")
        continue
    print(f"{r['seed']:>4} {(r['over'] or 'ok'):<15} {r['alive']:>5} {b(r['audit']):>3} "
          + " ".join(f"{b(x):>2}" for x in r["p"])
          + f" {r['parts']:>3}/{r['need']:<2} {b(r['launch']):>5} {r['pol']:>4.0f} {r['debt']:>5.0f} {r['refined']:>7} {r.get('real',0):>4} {r['plates']:>6} {r['waste']:>5}  {r.get('blocker','')[:60]}")
qc = {}
for r in rows:
    for q in r.get("quests", []):
        qc[q] = qc.get(q, 0) + 1
print("quests fired:", qc)
print("audit days:", [round(r.get("audit_day", -1)) for r in rows])
n = len(rows)
ok = [r for r in rows if "alive" in r]
c = lambda fn: sum(1 for r in ok if fn(r))
for name, v, th in [("audit tier2", c(lambda r: r["audit"]), 6), ("P1", c(lambda r: r["p"][0]), 5),
                    ("P3", c(lambda r: r["p"][2]), 3), ("launch", c(lambda r: r["launch"]), 1)]:
    print(f"{name:<12} {v}/{n}  need>={th}  {'PASS' if v >= th else 'FAIL'}")
ad = [r["audit_day"] for r in ok if r.get("audit_day", -1) >= 0]
if ad:
    print(f"audit day: mean {sum(ad)/len(ad):.1f}  min {min(ad):.0f}  max {max(ad):.0f}   alive>=8: {c(lambda r: r['alive'] >= 8)}/{n}")
# threat-pacing columns (design threats_pacing W4): all expected 0 flee/hidden deaths
fd = [r.get("flee_deaths", 0) for r in ok]
hs = [r.get("hidden_starve", 0) for r in ok]
om = [r.get("objmet", 0) for r in ok]
print(f"flee_deaths {sum(1 for x in fd if x)}/{n} seeds ({sum(fd)} total)  need 0   {'PASS' if not any(fd) else 'FAIL'}")
print(f"hidden_starve {sum(1 for x in hs if x)}/{n} seeds ({sum(hs)} total)  need 0   {'PASS' if not any(hs) else 'FAIL'}")
print(f"objmet {sum(om)} total over {n} seeds  per-seed: {om}")
# F1b: path / ending / gear / branch columns (all blank or 0 while the pg_bot knobs are off)
print("seed path    ending_won  gear_eq branches susp_peak")
for r in ok:
    print(f"{r['seed']:>4} {(r.get('path') or '-'):<7} {(r.get('ending_won') or '-'):<11} {r.get('gear_equipped', 0):>7} {r.get('branches', 0):>8} {r.get('susp_peak', 0):>9}")
print("regs (W1):", [r.get("regs", "") or "-" for r in ok])
mr = [r.get("metro", 0) for r in ok]
print(f"metro raids per seed: {mr}  seeds>=2: {sum(1 for x in mr if x >= 2)}/{n}  seeds==0: {sum(1 for x in mr if x == 0)}/{n}")
print("defiance end:", [r.get("defiance", 0) for r in ok])
# F11W5: passives / traits columns (blank unless PASSIVES_V2=1)
if any(r.get("f11", {}).get("inmates", 0) for r in ok):
    print("seed marks earned/spent  spend%  keystones allocated rules")
    for r in ok:
        f = r.get("f11", {})
        e, sp = f.get("earned", 0), f.get("spent", 0)
        print(f"{r['seed']:>4} {e:>6}/{sp:<6} {100*sp/e if e else 0:>6.0f} {f.get('keystones', 0):>9} {f.get('allocated', 0):>9} {','.join(f.get('rules', []))}")
    te, ts = sum(r.get("f11", {}).get("earned", 0) for r in ok), sum(r.get("f11", {}).get("spent", 0) for r in ok)
    print(f"spent {ts}/{te} = {100*ts/te if te else 0:.0f}%  need >=80%  {'PASS' if te and ts >= 0.8*te else 'FAIL'}")
