local __CLASSNAME__
local __BASECLASSES__ 
local __CLASSES__ = {}
local __MEMBERS__ 
local __IS_STATIC = false

function static_class(name)
	__IS_STATIC = true 
	return class(name)
end

function maybeExtends(name)
	if name == extends then 
		return extends
	else 
		return buildClass(name)
	end 
end 

local __MEMBERNAME__
function buildMember(data)
	__MEMBERS__[__MEMBERNAME__] = data
end


function buildClass(definition)
	__CLASSES__[__CLASSNAME__] = definition
	_G[__CLASSNAME__] = definition
	definition.__CLASSNAME__ = __CLASSNAME__
	definition.__members__ = __MEMBERS__
	local parents = {}
	for k, v in pairs(__BASECLASSES__) do
		parents[k] = __CLASSES__[v]
	end
	
	-- Prepare parent members
	local defaults = {}
	for k, class in pairs(parents) do
		for name, member in pairs(class.__members__) do 
			defaults[name] = member.default 
		end 
	end 
	
	for k, v in pairs(__MEMBERS__) do 
		defaults[k] = v.default 
	end
	
	setmetatable(definition,
	{
		__index = function(self, key)
			for k, v in pairs(parents) do 
				if v[key] then 
					return v[key]
				end 
			end
		end;
		
		__call = function(...)
			local member = defaults
			local instance = setmetatable({ __members__ = member, __class__ = definition },
			{
				__index = function(self, key)
					if definition.__members__[key] then 
						if definition.__members__[key].get then 
							return definition.__members__[key].get(self)
						end
						return self.__members__[key]
					end 
					
					return definition[key]
				end;
				-- Todo: Other metamethods
				
				__newindex = function(self, key, value)
					if definition.__members__[key] then 
						if definition.__members__[key].set then 
							if not definition.__members__[key].set(self, value) then 
								return 
							end 
						end
						self.__members__[key] = value
					end 
					
					-- Implicit member creation 
					-- If you want, replace this by an error
					-- and make sure to add this line above
					-- to ensure proper setting for non-setter
					-- members
					self.__members__[key] = value
				end 
			})
			
			return instance
		end;
	})
	
	if __IS_STATIC then 
		if definition.constructor then 
			definition:constructor()
		end
	end 
	__IS_STATIC = false 
end 


function class(name)
	__CLASSNAME__ = name
	__BASECLASSES__ = {}
	__MEMBERS__ = {}
	return maybeExtends
end 

function extends(name)
	if type(name) == "string" then 
		-- Handle base classes 
		__BASECLASSES__[#__BASECLASSES__+1] = name 
		return extends
	else 
		-- Handle class definition
		return buildClass(name)
	end 
end

function member(name)
	__MEMBERNAME__ = name 
	__MEMBERS__[name] = {}
	return buildMember
end 
