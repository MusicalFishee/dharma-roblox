--!strict
-- Duel tournaments: a four-bracket kumbha. Four names seed two semifinals;
-- winners meet in the final; the champion takes the purse. Walkovers advance
-- the survivor when an opponent vanishes. Pure bracket math (Lune-tested);
-- TournamentService runs the live nights on the ordinary duel machinery.

local Tournament = {}

Tournament.Size = 4

Tournament.Purse = {
	gold = 1500,
	shards = 5,
}

export type Bracket = {
	semis: { { number } }, -- two pairs of userIds
	finalists: { number },
	champion: number?, -- set when the final resolves
}

-- Seed four ids into two semifinals, in the order they queued.
function Tournament.seed(ids: { number }): Bracket?
	if #ids < Tournament.Size then
		return nil
	end
	return {
		semis = { { ids[1], ids[2] }, { ids[3], ids[4] } },
		finalists = {},
		champion = nil,
	}
end

local function inPair(pair: { number }, id: number): boolean
	return pair[1] == id or pair[2] == id
end

-- A semifinal resolves: the winner joins the finalists.
function Tournament.reportSemiWin(bracket: Bracket, winnerId: number): boolean
	for _, pair in bracket.semis do
		if inPair(pair, winnerId) then
			for _, existing in bracket.finalists do
				if existing == winnerId then
					return false -- already advanced
				end
			end
			table.insert(bracket.finalists, winnerId)
			return true
		end
	end
	return false
end

function Tournament.isFinalReady(bracket: Bracket): boolean
	return #bracket.finalists == 2 and bracket.champion == nil
end

-- The final resolves: the champion is crowned (must be a finalist).
function Tournament.reportFinalWin(bracket: Bracket, winnerId: number): boolean
	if bracket.champion ~= nil then
		return false
	end
	for _, id in bracket.finalists do
		if id == winnerId then
			bracket.champion = winnerId
			return true
		end
	end
	return false
end

-- A name vanishes mid-bracket: their standing opponent advances by walkover.
-- Returns the id that advanced (0 = the loss changed nothing).
function Tournament.walkover(bracket: Bracket, goneId: number): number
	-- Gone from an unresolved semi: the partner advances.
	for _, pair in bracket.semis do
		if inPair(pair, goneId) then
			local partner = if pair[1] == goneId then pair[2] else pair[1]
			local resolved = false
			for _, f in bracket.finalists do
				if f == partner or f == goneId then
					resolved = true
				end
			end
			if not resolved then
				table.insert(bracket.finalists, partner)
				return partner
			end
		end
	end
	-- Gone from the final: the other finalist is champion.
	if bracket.champion == nil and #bracket.finalists == 2 then
		for _, f in bracket.finalists do
			if f == goneId then
				local other = if bracket.finalists[1] == goneId then bracket.finalists[2] else bracket.finalists[1]
				bracket.champion = other
				return other
			end
		end
	end
	return 0
end

return Tournament
