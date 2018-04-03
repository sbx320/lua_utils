-- Developer: sbx320
-- License: MIT
-- Github Repos: https://github.com/sbx320/lua_utils

--// classlib
--|| A library providing several tools to enhance OOP with MTA and Lua
--\\
SERVER = triggerServerEvent == nil
CLIENT = not SERVER
DEBUG = DEBUG or false

function enew(element, class, ...)
	-- DEBUG: Validate that we are not instantiating a class with pure virtual methods
	if DEBUG then
		for k, v in pairs(class) do
			assert(v ~= pure_virtual, "Attempted to instanciate a class with an unimplemented pure virtual method ("..tostring(k)..")")
		end
	end
	
	local instance = setmetatable( { element = element },
		{
			__index = class;
			__class = class;
			__newindex = class.__newindex;
			__call = class.__call;
			__len = class.__len;
			__unm = class.__unm;
			__add = class.__add;
			__sub = class.__sub;
			__mul = class.__mul;
			__div = class.__div;
			__pow = class.__pow;
			__concat = class.__concat;		
		})
	
	oop.elementInfo[element] = instance
	
	local callDerivedConstructor;
	callDerivedConstructor = function(parentClasses, instance, ...)
		for k, v in pairs(parentClasses) do
			if rawget(v, "virtual_constructor") then
				rawget(v, "virtual_constructor")(instance, ...)
			end
			local s = superMultiple(v)
			callDerivedConstructor(s, instance, ...)
		end
	end
		
	callDerivedConstructor(superMultiple(class), element, ...) 
	
	-- Call constructor
	if rawget(class, "constructor") then
		rawget(class, "constructor")(element, ...)
	end
	element.constructor = false
	
	-- Add the destruction handler
	if isElement(element) then 
		addEventHandler(
		triggerClientEvent ~= nil and
		"onElementDestroy" or
		"onClientElementDestroy", element, __removeElementIndex, false, "low-999999")
	end
	return element
end

function new(class, ...)
	assert(type(class) == "table", "first argument provided to new is not a table")
	
	-- DEBUG: Validate that we are not instantiating a class with pure virtual methods
	if DEBUG then
		for k, v in pairs(class) do
			assert(v ~= pure_virtual, "Attempted to instanciate a class with an unimplemented pure virtual method ("..tostring(k)..")")
		end
	end
	
	local instance = setmetatable( { },
		{
			__index = class;
			__class = class;
			__newindex = class.__newindex;
			__call = class.__call;
			__len = class.__len;
			__unm = class.__unm;
			__add = class.__add;
			__sub = class.__sub;
			__mul = class.__mul;
			__div = class.__div;
			__pow = class.__pow;
			__concat = class.__concat;		
		})
	
	-- Call derived constructors
	local callDerivedConstructor;
	callDerivedConstructor = function(self, instance, ...)
		for k, v in pairs(self) do
			if rawget(v, "virtual_constructor") then
				rawget(v, "virtual_constructor")(instance, ...)
			end
			local s = superMultiple(v)
			callDerivedConstructor(s, instance, ...)
		end
	end
		
	callDerivedConstructor(superMultiple(class), instance, ...) 
	
	-- Call constructor
	if rawget(class, "constructor") then
		rawget(class, "constructor")(instance, ...)
	end
	instance.constructor = false

	return instance
end

function delete(self, ...)
	if self.destructor then --if rawget(self, "destructor") then
		self:destructor(...)
	end

	-- Prevent the destructor to be called twice 
	self.destructor = false
	
	local callDerivedDestructor;
	callDerivedDestructor = function(parentClasses, instance, ...)
		for k, v in pairs(parentClasses) do
			if rawget(v, "virtual_destructor") then
				rawget(v, "virtual_destructor")(instance, ...)
			end
			local s = superMultiple(v)
			callDerivedDestructor(s, instance, ...)
		end
	end
	callDerivedDestructor(superMultiple(self), self, ...)
end

function superMultiple(self)
	if isElement(self) then
		assert(oop.elementInfo[self], "Cannot get the superclass of this element") -- at least: not yet
		self = oop.elementInfo[self]
	end
	
	local metatable = getmetatable(self)
	if not metatable then
		return {}
	end
	
	if metatable.__class then -- we're dealing with a class object
		return superMultiple(metatable.__class)
	end
	
	if metatable.__super then -- we're dealing with a class
		return metatable.__super or {}
	end
end

function super(self)
	return superMultiple(self)[1]
end

function classof(self)
	if isElement(self) then
		assert(oop.elementInfo[self], "Cannot get the class of this element") -- at least: not yet
		self = oop.elementInfo[self]
	end
	
	local metatable = getmetatable(self)
	if metatable then
		return metatable.__class
	end
	return {}
end

function inherit(from, what)
	assert(from, "Attempt to inherit a nil table value")
	if not what then
		local classt = setmetatable({}, { __index = _inheritIndex, __super = { from } })
		if from.onInherit then
			from.onInherit(classt)
		end
		return classt
	end
	
	local metatable = getmetatable(what) or {}
	local oldsuper = metatable and metatable.__super or {}
	table.insert(oldsuper, 1, from)
	metatable.__super = oldsuper
	metatable.__index = _inheritIndex
	
	-- Inherit __call
	for k, v in ipairs(metatable.__super) do
		if v.__call then
			metatable.__call = v.__call
			break
		end
	end
	
	return setmetatable(what, metatable)
end

function _inheritIndex(self, key)
	for k, v in pairs(superMultiple(self)) do
		if v[key] then return v[key] end
	end
	return nil
end

---// __removeElementIndex()
---|| @desc: This function calls delete on the hidden source parameter to invoke the destructor
---|| !!! Avoid calling this function manually unless you know what you're doing! !!!
---\\
function __removeElementIndex()
	delete(source)
end

function instanceof(self, class, direct)
	if direct then
		return classof(self) == class
	end
	
	for k, v in pairs(superMultiple(self)) do
		if v == class then return true end
	end
		
	local check = false
	-- Check if any of 'self's base classes is inheriting from 'class'
	for k, v in pairs(superMultiple(self)) do
		print(v)
		check = instanceof(v, class, false)
		if check then
			break
		end
	end	
	return check
end

function pure_virtual()
	outputDebug(debug.traceback())
	error("Function implementation missing")
end

function bind(func, ...)
	if not func then
		if DEBUG then
			outputConsole(debug.traceback())
			outputServerLog(debug.traceback())
		end
		error("Bad function pointer @ bind. See console for more details")
	end
	
	local boundParams = {...}
	return 
		function(...) 
			local params = {}
			local boundParamSize = select("#", unpack(boundParams))
			for i = 1, boundParamSize do
				params[i] = boundParams[i]
			end
			
			local funcParams = {...}
			for i = 1, select("#", ...) do
				params[boundParamSize + i] = funcParams[i]
			end
			return func(unpack(params)) 
		end 
end

function load(class, ...)
	assert(type(class) == "table", "first argument provided to load is not a table")
	local instance = setmetatable( { },
		{
			__index = class;
			__class = class;
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

-- Magic to allow MTA elements to be used as data storage
-- e.g. localPlayer.foo = 12
oop = {}
oop.elementInfo = setmetatable({}, { __mode = "k" })
oop.elementClasses = {}

oop.prepareClass = function(name)
	local mt = debug.getregistry().mt[name]
	
	if not mt then
		outputDebugString("No such class mt "..tostring(name))
		return
	end
	
	-- Store MTA's metafunctions
	local __mtaindex = mt.__index
	local __mtanewindex = mt.__newindex
	local __set= mt.__set
	
	mt.__index = function(self, key)
		if not oop.handled then
			if not oop.elementInfo[self] and isElement(self) then
				enew(self, oop.elementClasses[getElementType(self)] or {})
			end
			if oop.elementInfo[self] and oop.elementInfo[self][key] ~= nil  then
				oop.handled = false
				return oop.elementInfo[self][key]
			end
			oop.handled = true
		end
		local value = __mtaindex(self, key)
		oop.handled = false
		return value
	end
	
	
	mt.__newindex = function(self, key, value)
		if __set[key] ~= nil then
			__mtanewindex(self, key, value)
			return
		end
		
		if not oop.elementInfo[self] and isElement(self) then
			enew(self, oop.elementClasses[getElementType(self)] or {})
		end
		
		oop.elementInfo[self][key] = value
	end
end

function registerElementClass(name, class) 
	assert(type(name) == "string", "Bad argument #1 for registerElementClass")
	assert(type(class) == "table", "Bad argument #2 for registerElementClass")
	oop.elementClasses[name] = class
end

oop.initClasses = function()
	-- this has to match 
	--	(Server) MTA10_Server\mods\deathmatch\logic\lua\CLuaMain.cpp
	--	(Client) MTA10\mods\shared_logic\lua\CLuaMain.cpp
	if SERVER then	
		oop.prepareClass("ACL")
		oop.prepareClass("ACLGroup")
		oop.prepareClass("Account")
		oop.prepareClass("Ban")
		oop.prepareClass("Connection")
		oop.prepareClass("QueryHandle")
		oop.prepareClass("TextDisplay")
		oop.prepareClass("TextItem")
	elseif CLIENT then
		oop.prepareClass("Browser")
		oop.prepareClass("Camera")
		oop.prepareClass("Light")
		oop.prepareClass("Projectile")
		oop.prepareClass("SearchLight")
		oop.prepareClass("Sound")
		oop.prepareClass("Sound3D")
		oop.prepareClass("Weapon")
		oop.prepareClass("Effect")
		oop.prepareClass("GuiElement")
		oop.prepareClass("GuiWindow")
		oop.prepareClass("GuiButton")
		oop.prepareClass("GuiEdit")
		oop.prepareClass("GuiLabel")
		oop.prepareClass("GuiMemo")
		oop.prepareClass("GuiStaticImage")
		oop.prepareClass("GuiComboBox")
		oop.prepareClass("GuiCheckBox")
		oop.prepareClass("GuiRadioButton")
		oop.prepareClass("GuiScrollPane")
		oop.prepareClass("GuiScrollBar")
		oop.prepareClass("GuiProgressBar")
		oop.prepareClass("GuiGridList")
		oop.prepareClass("GuiTabPanel")
		oop.prepareClass("GuiTab")
		oop.prepareClass("GuiFont")
		oop.prepareClass("GuiBrowser")
		oop.prepareClass("EngineCOL")
		oop.prepareClass("EngineTXD")
		oop.prepareClass("EngineDFF")
		oop.prepareClass("DxMaterial")
		oop.prepareClass("DxTexture")
		oop.prepareClass("DxFont")
		oop.prepareClass("DxShader")
		oop.prepareClass("DxScreenSource")
		oop.prepareClass("DxRenderTarget")
		oop.prepareClass("Weapon")
	end
	
	oop.prepareClass("Object")
	oop.prepareClass("Ped")
	oop.prepareClass("Pickup")
	oop.prepareClass("Player")
	oop.prepareClass("RadarArea")
	--oop.prepareClass("Vector2")
	--oop.prepareClass("Vector3")
	--oop.prepareClass("Vector4")
	--oop.prepareClass("Matrix")
	oop.prepareClass("Element")
	oop.prepareClass("Blip")
	oop.prepareClass("ColShape")
	oop.prepareClass("File")
	oop.prepareClass("Marker")		
	oop.prepareClass("Vehicle")
	oop.prepareClass("Water")
	oop.prepareClass("XML")
	oop.prepareClass("Timer")
	oop.prepareClass("Team")
	oop.prepareClass("Resource")
end
oop.initClasses()
