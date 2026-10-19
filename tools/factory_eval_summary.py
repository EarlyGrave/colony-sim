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
print("seed over            alive aud P1 P2 P3 P4 parts launch pol%  debt% refined plates waste")
for r in rows:
    if "alive" not in r:
        print(f"{r['seed']:>4} {r['over']}")
        continue
    print(f"{r['seed']:>4} {(r['over'] or 'ok'):<15} {r['alive']:>5} {b(r['audit']):>3} "
          + " ".join(f"{b(x):>2}" for x in r["p"])
          + f" {r['parts']:>3}/{r['need']:<2} {b(r['launch']):>5} {r['pol']:>4.0f} {r['debt']:>5.0f} {r['refined']:>7} {r['plates']:>6} {r['waste']:>5}")
n = len(rows)
ok = [r for r in rows if "alive" in r]
c = lambda fn: sum(1 for r in ok if fn(r))
for name, v, th in [("audit tier2", c(lambda r: r["audit"]), 6), ("P1", c(lambda r: r["p"][0]), 5),
                    ("P3", c(lambda r: r["p"][2]), 3), ("launch", c(lambda r: r["launch"]), 1)]:
    print(f"{name:<12} {v}/{n}  need>={th}  {'PASS' if v >= th else 'FAIL'}")
ad = [r["audit_day"] for r in ok if r.get("audit_day", -1) >= 0]
if ad:
    print(f"audit day: mean {sum(ad)/len(ad):.1f}  min {min(ad):.0f}  max {max(ad):.0f}   alive8: {c(lambda r: r['alive'] == 8)}/{n}")
