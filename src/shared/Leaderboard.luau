--!strict
-- Leaderboard definitions + score hygiene. Pure (Lune-tested); the server service
-- owns the OrderedDataStore I/O and the physical boards.

local Leaderboard = {}

export type BoardDef = {
	id: string,
	storeName: string,
	title: string,
	-- Turns a raw score into its display form ("Lv 12" / "Wave 8").
	prefix: string,
}

Leaderboard.Boards = {
	{
		id = "level",
		storeName = "DharmaTopLevel_v1",
		title = "HIGHEST LEVEL",
		prefix = "Lv",
	},
	{
		id = "wave",
		storeName = "DharmaTopWave_v1",
		title = "DEEPEST WAVE",
		prefix = "Wave",
	},
} :: { BoardDef }

Leaderboard.TopN = 10
Leaderboard.ScoreMax = 1e6

-- OrderedDataStores only accept non-negative integers; make any input safe.
function Leaderboard.sanitizeScore(value: any): number
	if type(value) ~= "number" or value ~= value or value < 0 then
		return 0
	end
	return math.min(math.floor(value), Leaderboard.ScoreMax)
end

function Leaderboard.formatValue(board: BoardDef, value: number): string
	return string.format("%s %d", board.prefix, Leaderboard.sanitizeScore(value))
end

-- Row text for the physical board: "1.  PlayerName        Lv 12"
function Leaderboard.formatRow(board: BoardDef, rank: number, name: string, value: number): string
	return string.format("%d.  %s  —  %s", rank, name, Leaderboard.formatValue(board, value))
end

return Leaderboard
