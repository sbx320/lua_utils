-- Developer: sbx320
-- License: MIT
-- Github Repos: https://github.com/sbx320/lua_utils
Async = { id = false; threads = {}}

function Async.create(func)
	local t = setmetatable({}, { __index = Async, __call = Async.__call })
	
	t:constructor(func)
	return function(...) return t:continue(...) end
end

function Async.constructor(self, func)
	self.m_Fn = func
	self.m_Id = #Async.threads+1
	Async.threads[self.m_Id] = self
	self.m_IsRunning = false
end

function Async.__call(self, ...)
	self:continue(...)
end

function Async.wait()
	Async.id = false
	coroutine.yield()
	return unpack(Async.threads[Async.id].m_Args)
end

function Async.waitFor(element)
	assert(Async.id, "Not within async execution, cannot wait")
	Async.threads[Async.id].m_Element = element
	local id = Async.id
	return function(...) return Async.continueAsync(id, ...) end
end

function Async.continueAsync(id, ...)
	return Async.threads[id]:continue(...)
end

function Async:continue(...)
	Async.id = self.m_Id
	
	if not self.m_IsRunning then
		self.m_Coroutine = coroutine.create(self.m_Fn)
		self.m_IsRunning = true
		assert(coroutine.resume(self.m_Coroutine, ...))
		return
	else
		self.m_Args = {...}
		if self.m_Element then
			if not self.m_Element then
				-- abandon the coroutine so the gc can clear it
				Async.threads[Async.id] = nil
				self.m_Coroutine  = nil
				return
			end
			self.m_Element = nil
		end
	end
	assert(coroutine.resume(self.m_Coroutine))
end
