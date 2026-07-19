--!strict
-- The Ghats: where a warrior falls past saving, a small flame is set — the
-- session remembers the spot. Living allies who stop to pay tribute at a
-- ghat take a breath of the fallen's fire (a little Tejas), once per flame
-- each. The arena keeps only so many flames; the oldest are released.
-- Pure cap/tribute math (Lune-tested); GhatService tends the fires.

local Ghat = {}

Ghat.Config = {
	MaxFlames = 8, -- the arena keeps only so many memories at once
	TributeTejas = 12,
}

-- FIFO: push an entry, release the oldest past the cap. Returns what was
-- released (the caller extinguishes it) or nil.
function Ghat.push<T>(list: { T }, entry: T, max: number): T?
	table.insert(list, entry)
	if #list > math.max(max, 1) then
		return table.remove(list, 1)
	end
	return nil
end

return Ghat
