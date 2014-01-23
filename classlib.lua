-- Developer: sbx320
-- License: MIT
-- Github Repos: https://github.com/sbx320/lua_utils

--// classlib
--||	@type:	Shared
--||	@desc:	A library providing several tools to enhance OOP with Lua
--||	@info:  Registers itself into the global namespace
--\\
local elementClasses = {}
local elementIndex = {}

-- Set DEBUG to true to enable some additional checks
DEBUG = DEBUG or nil

--// new(class, ...)
--||	@desc:	Creates an instance of 'class' and calls the constructor
--||			and all derived_constructors
--||	@param:	table 'class' -	The class which should be instanciated
--||	@param: vararg        - Parameters passed to the constructor and derived_constructors
--||	@return:table 		  - The newly created instance 
--\\
function new(class, ...)
	assert(type(class) == "table", "first argument provided to new is not a table")
	
	-- DEBUG: Validate that we are not instanciating a class with pure virtual methods
	if DEBUG then
		for k, v in pairs(class) do
			assert(v ~= pure_virtual, "Attempted to instaciate a class with an unimplemented pure virtual method ("..tostring(k)..")")
		end
	end
	
	local instance = setmetatable( { },
		{
			__index = class;
			__super = { class };
			__newindex = class.__newindex;
			__call = class.__call;
		})
	
	-- Call derived constructors
	-- Weird Lua behaviour requires forwarding of recursive local functions...?
	local callDerivedConstructor;
	callDerivedConstructor = function(self, instance, ...)
		for k, v in pairs(super(self)) do
			if rawget(v, "derived_constructor") then
				rawget(v, "derived_constructor")(instance, ...)
			end
			local s = super(v)
			if s then callDerivedConstructor(s, instance, ...) end
		end
	end
		
	callDerivedConstructor(class, instance, ...) 
	
	-- Call constructor
	if rawget(class, "constructor") then
		rawget(class, "constructor")(instance, ...)
	end
	instance.constructor = false

	-- Add a change handler for all ._changeVARIABLE methods
	for k, v in pairs(class) do
		if k:sub(1, 7) == "_change" then
			addChangeHandler(instance, k:sub(8), v)
		end
	end

	return instance
end

--// enew(element, class, ...)
--||	@desc:	Makes an element an instance of 'class' and calls the constructor
--||	@param:	table 'class' -	The class which should be instanciated
--||	@param: vararg        - Parameters passed to the constructor and derived_constructors
--||	@return:element 	  - The element passed
--\\
function enew(element, class, ...)
	-- DEBUG: Validate that we are not instanciating a class with pure virtual methods
	if DEBUG then
		for k, v in pairs(class) do
			assert(v ~= pure_virtual, "Attempted to instaciate a class with an unimplemented pure virtual method ("..tostring(k)..")")
		end
	end
	
	local instance = setmetatable( { element = element },
		{
			__index = class;
			__super = { class };
			__newindex = class.__newindex;
			__call = class.__call;
		})
		
	elementIndex[element] = instance
	
	-- Weird Lua behaviour requires forwarding of recursive local functions...?
	local callDerivedConstructor;
	callDerivedConstructor = function(self, instance, ...)
		for k, v in pairs(super(self)) do
			if rawget(v, "derived_constructor") then
				rawget(v, "derived_constructor")(instance, ...)
			end
			local s = super(v)
			if s then callDerivedConstructor(s, instance, ...) end
		end
	end
		
	callDerivedConstructor(class, element, ...) 
	
	-- Call constructor
	if rawget(class, "constructor") then
		rawget(class, "constructor")(element, ...)
	end
	element.constructor = false

	-- Add a change handler for all ._changeVARIABLE methods
	for k, v in pairs(class) do
		if k:sub(1, 7) == "_change" then
			addChangeHandler(instance, k:sub(8), v)
		end
	end
	
	-- Add the destruction handler
	addEventHandler(
		triggerClientEvent ~= nil and 
		"onElementDestroy" or
		"onClientElementDestroy", element, __removeElementIndex, false, "low-999999")

	return element
end

--// registerElementClass(elementType, class)
--||	@desc:	Registers a class to be used upon element index operations like e.g.
--||			getPlayerFromName("MrX"):hello() would search in the class assigned to "player"
--||	@param:	string 'elementType'- The element type the class is supposed to be assigned to
--||	@param: table 'class'       - The class which is assigned
--\\
function registerElementClass(elementType, class)
	elementClasses[elementType] = class
end

--// __removeElementIndex()
--||	@desc:	This function calls delete on the hidden source parameter to invoke the destructor
--||			!!! Avoid calling this function manually unless you know what you're doing! !!!
--\\
function __removeElementIndex()
	delete(source)
end

--// delete(self, ...)
--||	@desc:	Deletes an instance and calls the destructor
--||			and all derived_destructors
--||	@param:	table 'self' -	The instance to be deleted
--||	@param: vararg        - Parameters passed to the destructor and derived_destructors
--\\
function delete(self, ...)
	if self.destructor then --if rawget(self, "destructor") then
		self:destructor(...)
	end

	-- Prevent the destructor to be called twice 
	self.destructor = false
	
	-- Weird Lua behaviour requires forwarding of recursive local functions...?
	local callDerivedDestructor;
	callDerivedDestructor = function(self, instance, ...)
		for k, v in pairs(super(self)) do
			if rawget(v, "derived_destructor") then
				rawget(v, "derived_destructor")(instance, ...)
			end
			local s = super(v)
			if s then callDerivedDestructor(s, instance, ...) end
		end
	end
	
	-- Cleanup
	elementIndex[self] = nil
end

--// super(self)
--||	@desc:	Gets the superclasses of an instance or class
--||	@param:	table 'self' -	The instance / class to get the parent class of
--||	@return:table<table> - The superclasses
--\\
function super(self)
	if isElement(self) then
		self = elementIndex[self]
	end
	local metatable = getmetatable(self)
	if metatable then return metatable.__super 
	else return {}
	end
end

--// instanceof(self, class, direct = false)
--||	@desc:	Returns if 'self' is an instance of 'class'. If 'direct' is set to true it enforces 'self'
--||			to be a direct descendant of 'class' (new(self, class)). If 'direct' is set to false 
--||			(default) 'self' is allowed to be a instance with any kind of link to 'class' even with 
--||			multiple levels of inheritance or similar polymorphic connections.
--||	@param:	table 'self' 			  -	The instance to check
--||	@param:	table 'class' 			  -	The class to check
--||	@optparam:	bool 'direct' (false) -	Whether to check for direct inheritance
--||	@return:bool - the result of the check
--\\
function instanceof(self, class, direct)
	for k, v in pairs(super(self)) do
		if v == class then return true end
	end
	
	if direct then return false end
		
	local check = false
	-- Check if any of 'self's base classes is inheriting from 'class'
	for k, v in pairs(super(self)) do
		check = instanceof(v, class, false)
	end	
	return check
end

--// bind(func, self)
--||	@desc:	Wraps the function(...) return function(self, ...) end idiom
--||	@param:	table 'func' 			  -	The function to bind
--||	@param:	vararg ... 		 		  -	The parameters to bind
--||	@return:function - the bound function
--\\
function bind(func, ...)
	local boundParams = {...}
	return 
		function(...) 
			local params = {}
			for k, v in ipairs(boundParams) do
				params[#params+1] = v
			end
			for k, v in ipairs({...}) do
				params[#params+1] = v
			end
			return func(unpack(params)) 
		end 
end
--// load(class, ...)
--||	@desc:	Creates an instance of 'class' and call the 'load' method
--||	@param:	table 'class' -	The class which should be instanciated
--||	@param: vararg        - Parameters passed to the 'load' method
--||	@return:table 		  - The newly created instance 
--\\
function load(class, ...)
	assert(type(class) == "table", "first argument provided to load is not a table")
	local instance = setmetatable( { },
		{
			__index = class;
			__super = { class };
			__newindex = class.__newindex;
			__call = class.__call;
		})
	
	-- Call load
	if rawget(class, "load") then
		rawget(class, "load")(instance, ...)
	end
	instance.load = false

	return instance
end

--// inherit(from, what)
--||	@desc:	Creates a new class inheriting from 'from' or sets 'what' to inherit from 'from'
--||	@param:	table 'from' 		-	The class to inherit from
--||	@optparam:	table 'what' 	-	The class which should inherit, optional
--||	@return:table - The now inheriting class
--\\
function inherit(from, what)
	if not from then
		outputDebug("Attempt to inherit a nil table value")
		outputConsole(debug.traceback())
		return {}
	end
	
	if not what then
		local classt = setmetatable({}, { __index = _inheritIndex, __super = { from } })
		if from.onInherit then
			from.onInherit(classt)
		end
		return classt
	end
	
	local metatable = getmetatable(what) or {}
	local oldsuper = metatable and metatable.__super or {}
	oldsuper[#oldsuper+1] = from
	metatable.__super = oldsuper
	metatable.__index = _inheritIndex
	
	return setmetatable(what, metatable)
end

function _inheritIndex(self, key)
	for k, v in pairs(super(self) or {}) do
		if v[key] then return v[key] end
	end
	return nil
end

--// pure_virtual()
--||	@desc:	Yields an error on call. Use like: class.memberfunction = pure_virtual to enforce 
--||			implementation in derived classes
--\\
function pure_virtual()
	error("Function implementation missing")
end

--// getTypeName(object)
--||	@desc:   Returns the type name of the specified object (for debug purpose only)
--||	@param:  object - the object
--||	@return: The type name
--\\
function getTypeName(object)
	return table.find(_G, getmetatable(object).__index)
end

--// Syntax 1: addChangeHandler(instance, key, func)
--||	@desc:	addChangeHandler calls 'func' whenever 'key' is changed on 'instance'
--||	@param:	table instance  - any table to watch for changes
--||	@param: string key		- the key to watch
--||	@param:	function func	- the function to call when the value of instance[key] is changed
--||							  return anything but nil to override the value. Do not attempt to
--||							  change instance[key] directly within 'func' as it will cause a 
--||							  stack overflow. Additionally: do not use rawset on the table and 
--||							  key with a changehandler unless you want to face some awkward bugs
--||
--|| 	Parameters for func: 	  function (table/element instance, any value)
--||
--|| Syntax 2: addChangeHandler(instance, func, func)
--||	@desc:	addChangeHandler calls 'func' whenever any key is changed on 'instance'
--||	@param:	table instance  - any table to watch for changes
--||	@param:	function func	- the function to call when the value of any index in instance is changed
--||							  return anything but nil to override the value. Do not attempt to
--||							  change the contents of instance directly within 'func' as it will cause a 
--||							  stack overflow. Additionally: do not use rawset on the table with a 
--||							  changehandler unless you want to face some awkward bugs
--||
--|| 	Parameters for func: 	  function (table/element instance, any key, any value)
--\\
function addChangeHandler(instance, key, func)
	if isElement(instance) then
		instance = elementIndex[instance]
	end
	local metatable = getmetatable(instance) or {}
	if not metatable.__changeHandler then
		metatable.__changeHandler = {}
		metatable.__changeData = {}

		metatable.__realNewindexFunction = metatable.__newindex

		-- This saves us from checking on each call		
		if type(metatable.__index) == "table" then
			metatable.__realIndexTable = metatable.__index
		elseif type(metatable.__index) == "function" then
			metatable.__realIndexFunction = metatable.__index
		end

		metatable.__index = __changeHandlerIndex
		metatable.__newindex = __changeHandlerNewindex
	end
	
	if type(key) == "function" then
		func = key
		metatable.__changeHandler = func
	else
		metatable.__changeHandler[key] = func
	end
	return setmetatable(instance, metatable)
end

function __changeHandlerIndex(self, key)
	local metatable = getmetatable(self)
	if metatable.__changeData[key] then return metatable.__changeData[key] end
	
	return (
		-- If we have a __index function use it
		metatable.__realIndexFunction and
			metatable.__realIndexFunction(rawget(self, "element") or self, key) or
			
		-- If we have a __index table use it
		metatable.__realIndexTable and
			metatable.__realIndexTable[key] or

		-- Else rawget
		rawget(self, key)
	)
end

function __changeHandlerNewindex(self, key, value)
	local metatable = getmetatable(self)
	if type(metatable.__changeHandler) == "table" then
		if metatable.__changeHandler[key] then 
			local ret = metatable.__changeHandler[key](rawget(self, "element") or self, value)
			if ret ~= nil then
				value = ret
			end
			metatable.__changeData[key] = value
			setmetatable(self, metatable)
			return
		end
	elseif type(metatable.__changeHandler) == "function" then
		local ret = metatable.__changeHandler(rawget(self, "element") or self, key, value)
		if ret ~= nil then
			value = ret
		end
		metatable.__changeData[key] = value
		setmetatable(self, metatable)		
		return
	end
	
	return (
		-- If we have a __newindex function use it
		metatable.__realNewindexFunction and
			metatable.__realNewindexFunction(rawget(self, "element") or self, key, value) or

		-- Else rawset
		rawset(self, key, value)
	)
end



-- -- Magic happens here. -- -- 
-- Lua's lightuserdata's (which MTA uses for Elements) can have on global shared metatable. This blocks
-- the possibility to do debug.setmetatable(element, class), therefore we redirect all class on elements
-- to a table. This allows full control about the metaactions on any lightuserdata.
-- The debug.setmetatable is applied to root as it will always be an existing element. It could be applied
-- to any other element and have the same effect
-- Note for 1.4: add "<oop>false</oop>" into the meta
debug.setmetatable(root,
	{
		__index = function(self, key)
			if elementIndex[self] then 	
				return elementIndex[self][key]
			elseif elementClasses[getElementType(self)] then
				enew(self, elementClasses[getElementType(self)])
				return self[key]
			end
		end,
		__newindex = function(self, key, value) 
			if not elementIndex[self] then
				enew(self, elementClasses[getElementType(self)] or {})
			end
			elementIndex[self][key] = value
		end,
	}
)