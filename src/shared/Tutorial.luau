--!strict
-- Adhyaya 0 — The First Lesson. Rishi Agastya walks a brand-new warrior
-- through the fundamentals as a gentle checklist over the first waves:
-- strike, guard, Astra, spoils, and holding the line. Finish it and the
-- rishi pays a blessing; it never appears again. Non-blocking by design —
-- the war doesn't wait, and neither does the lesson.
-- Pure steps + advance math (Lune-tested); TutorialService feeds events.

local Tutorial = {}

export type Step = {
	id: string,
	event: string, -- "kill" | "parry" | "ability" | "gold" | "waveClear"
	count: number,
	text: string, -- Agastya's instruction, shown with progress
}

local function step(def: Step): Step
	return def
end

Tutorial.Steps = {
	step({ id = "first_blood", event = "kill", count = 3, text = "Strike, child. The chain flows — three blows, then the finisher. Slay 3 demons." }),
	step({ id = "first_parry", event = "parry", count = 1, text = "Now the harder art: raise your guard AS the blow lands. Parry once." }),
	step({ id = "first_astra", event = "ability", count = 1, text = "Your blood carries fire. Press Z and loose an Astra." }),
	step({ id = "first_spoils", event = "gold", count = 1, text = "The fallen leave gold. Walk over it — the war must be paid for." }),
	step({ id = "first_stand", event = "waveClear", count = 1, text = "Now hold the line with me until the wave breaks." }),
} :: { Step }

Tutorial.Lines = {
	intro = "I am Agastya. The horde does not wait for the ready — so learn quickly.",
	outro = "You learn well. Take this — and remember: dharma is held, not given.",
}

Tutorial.Reward = {
	gold = 250,
}

export type Advance = {
	stepIndex: number,
	progress: number,
	completedStep: boolean, -- this event finished the current step
	done: boolean, -- the whole lesson is over
}

-- Feed one event into the lesson. Events that don't match the current step
-- are ignored — the lesson is ordered on purpose (parry AFTER first blood).
function Tutorial.advance(stepIndex: number, progress: number, eventKind: string): Advance
	local current = Tutorial.Steps[stepIndex]
	if not current then
		return { stepIndex = stepIndex, progress = progress, completedStep = false, done = true }
	end
	if eventKind ~= current.event then
		return { stepIndex = stepIndex, progress = progress, completedStep = false, done = false }
	end

	local newProgress = progress + 1
	if newProgress < current.count then
		return { stepIndex = stepIndex, progress = newProgress, completedStep = false, done = false }
	end
	local nextIndex = stepIndex + 1
	return {
		stepIndex = nextIndex,
		progress = 0,
		completedStep = true,
		done = Tutorial.Steps[nextIndex] == nil,
	}
end

function Tutorial.stepAt(index: number): Step?
	return Tutorial.Steps[index]
end

return Tutorial
