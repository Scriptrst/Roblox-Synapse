-- better to handle this in its own module than try to weave it into Catwork
-- handles dispatching of Fragments

local Common = require(script.Parent.Common)
local ERROR = require(script.Parent.Error)

local Dispatcher = {}
local fragmentDispatchState = {}

local function getFragmentState(f)
	local state = fragmentDispatchState[f]
	if not state then
		state = {
			Spawned = false,
			Loaded = false,
			ErrMsg = nil,

			HeldThreads = {},
			Dispatchers = {}
		}

		fragmentDispatchState[f] = state
	end
	
	return state
end

local function runFragmentAction(
	f,
	spawnSignal,
	service,
	state
)
	local ok, err = pcall(spawnSignal, service, f)

	state.Loaded = ok
	state.ErrMsg = err

	for _, v in state.Dispatchers do
		task.spawn(v, ok, err)
	end

	for _, v in state.HeldThreads do
		task.spawn(v, ok, err)
	end

	return ok, err
end

local function spawnFragment(self, state, asyncHandler)
	local service = self.Service
	local spawnSignal = service.Spawning

	if asyncHandler then
		task.spawn(runFragmentAction, self, spawnSignal, service, state)
		return nil
	else
		return runFragmentAction(self, spawnSignal, service, state)
	end
end

function Dispatcher.spawnFragment(f, asyncHandler)
	if not Common.Fragments[f.ID] then
		-- the fragment does not exist, most likely because it was destroyed
		ERROR:DISPATCHER_DESTROYED_FRAGMENT(f)
	end
	
	local state = getFragmentState(f)
	
	-- basically new logic for Spawn
	if state.Spawned then
		ERROR:DISPATCHER_ALREADY_SPAWNED(f)
	end

	state.Spawned = true
	if asyncHandler then state.Dispatchers = {asyncHandler} end
	
	return spawnFragment(f, state, asyncHandler)
end

function Dispatcher.cleanFragmentState(f)
	fragmentDispatchState[f] = nil
end

function Dispatcher.slotAwait(f)
	local state = getFragmentState(f)

	if state.ErrMsg then
		return false, state.ErrMsg
	elseif state.Loaded then
		return true
	end

	table.insert(state.HeldThreads, coroutine.running())
	return coroutine.yield()
end

function Dispatcher.slotHandleAsync(f, asyncHandler)
	local state = getFragmentState(f)

	if state.ErrMsg then
		asyncHandler(false, state.ErrMsg)
	elseif state.Loaded then
		asyncHandler(true)
	else
		table.insert(state.Dispatchers, asyncHandler)
	end
end

return Dispatcher