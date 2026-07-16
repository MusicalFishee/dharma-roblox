--!strict
-- Chat tags: prefixes every chat message with the sender's equipped title, in the
-- title's colour — [Dharmapala] MusicalFishee: gg. Reads the replicated attributes
-- TitleService stamps on each Player, so it needs no extra network traffic.

local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")

TextChatService.OnIncomingMessage = function(message: TextChatMessage)
	local source = message.TextSource
	if not source then
		return nil
	end
	local sender = Players:GetPlayerByUserId(source.UserId)
	if not sender then
		return nil
	end

	local titleName = sender:GetAttribute("DharmaTitle")
	local hex = sender:GetAttribute("DharmaTitleHex")
	if typeof(titleName) ~= "string" or titleName == "" then
		return nil
	end

	local props = Instance.new("TextChatMessageProperties")
	local color = if typeof(hex) == "string" and #hex == 6 then hex else "ffc828"
	props.PrefixText = string.format('<font color="#%s">[%s]</font> %s', color, titleName, message.PrefixText)
	-- The bundled defs type this callback as returning nil; the engine accepts properties.
	return props :: any
end

print("[Dharma] Chat tags ready.")
