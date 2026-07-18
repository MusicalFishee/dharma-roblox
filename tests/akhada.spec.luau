--!strict
-- Headless tests for the Akhada's rolling damage window.

local process = require("@lune/process")
local Akhada = require("../src/shared/Akhada")

local passed, failed = 0, 0
local failures: { string } = {}
local function check(name: string, cond: boolean)
	if cond then
		passed += 1
		print("  ok   " .. name)
	else
		failed += 1
		table.insert(failures, name)
		print("  FAIL " .. name)
	end
end

print("Akhada")

local cfg = Akhada.Config
check("the dummy is a mountain", cfg.DummyHealth >= 10000)
check("the window is a real read", cfg.WindowSeconds >= 5)
check("the dummy tops up before half", cfg.ResetBelowFraction > 0 and cfg.ResetBelowFraction < 1)

local events = { { at = 100, amount = 50 }, { at = 105, amount = 30 }, { at = 109, amount = 20 } }
local total, dps = Akhada.readOver(events, 110, 10)
check("the window sums what it holds", total == 100)
check("the rate divides by the window", math.abs(dps - 10) < 1e-9)

local total2 = Akhada.readOver(events, 112, 10)
check("old blows fall out of the read", total2 == 50)
check("an empty yard reads zero", (Akhada.readOver({}, 100, 10)) == 0)
check("negative junk never counts", (Akhada.readOver({ { at = 100, amount = -50 } }, 100, 10)) == 0)

local pruned = Akhada.prune(events, 112, 10)
check("pruning keeps only the window", #pruned == 2 and pruned[1].at == 105)
check("pruning an empty list is calm", #Akhada.prune({}, 100, 10) == 0)

-- The combo lab: strings of blows.
local gap = cfg.ComboGapSeconds
check("the gap is humane", gap >= 2 and gap <= 5)

local r1 = Akhada.advance(nil, 100, 40, gap)
check("a first blow opens a string", r1.hits == 1 and r1.total == 40 and r1.maxHit == 40 and r1.startedAt == 100)

local r2 = Akhada.advance(r1, 101.5, 60, gap)
check("a quick follow-up extends it", r2.hits == 2 and r2.total == 100 and r2.startedAt == 100)
check("the biggest blow is remembered", r2.maxHit == 60)

local r3, finished3 = Akhada.advance(r2, 101.5 + gap, 10, gap)
check("a blow at the gap's edge still lands", r3.hits == 3 and finished3 == nil)

local r4, finished4 = Akhada.advance(r3, 200, 25, gap)
check("silence past the gap breaks the string", r4.hits == 1 and r4.startedAt == 200)
check("the broken string is handed back", finished4 ~= nil and (finished4 :: Akhada.Run).hits == 3 and (finished4 :: Akhada.Run).total == 110)
check("advancing preserves the old run untouched", r3.hits == 3 and r3.lastAt == 101.5 + gap)

check("a live string is not stale", not Akhada.isStale(r4, 200 + gap, gap))
check("a quiet string goes stale", Akhada.isStale(r4, 200 + gap + 0.1, gap))

check("pokes end in silence", not Akhada.isNotable(r4, cfg.MinReportHits))
check("real strings earn a verdict", Akhada.isNotable({ startedAt = 0, lastAt = 4, hits = cfg.MinReportHits, total = 300, maxHit = 90 }, cfg.MinReportHits))

-- The sparring partner's contract: real rules, pulled punches, leashed.
local spar = Akhada.Spar
check("the partner pulls its punches", spar.Damage > 0 and spar.Damage <= 10)
check("the partner is beatable", spar.Health >= 500 and spar.Health <= 5000)
check("its cadence can be read and parried", spar.AttackInterval >= 2)
check("the yard's fight stays in the yard", spar.LeashRadius <= 60 and spar.AggroRadius < spar.LeashRadius)
check("it bows out when nobody trains", spar.LonelySeconds >= 30)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
