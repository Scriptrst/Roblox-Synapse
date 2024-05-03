-- Reflection generator
-- type = required type
-- type? = optional type

local ERROR = require(script.Parent.Parent.Internal.Error)
local KNOWN_TYPES = {}
local KNOWN_CUSTOM = {}

type ReflectionArg = {
	Optional: boolean,
	Type: string?,
	CustomAssert: ((any, string, number) -> boolean)
}

local function ASSERTION_REFLECTION_TEST(ok, eType, ...)
	if not ok then
		ERROR[eType](...)
	end
end

local function REFLECTION(intended: {ReflectionArg}, fName: string, ...)
	for idx, arg in intended do
		local obj = select(idx, ...)
		
		local aType = arg.Type
		local optional = arg.Optional

		if aType == "any" then continue end
		if optional and obj == nil then continue end

		if aType then
			-- classic type assert
			local objType = typeof(obj)
			if objType ~= aType then ERROR.BAD_ARG(idx, fName, arg.Type, objType) end
			continue
		end

		ASSERTION_REFLECTION_TEST(arg.CustomAssert(obj, fName, idx))
	end
end

local function Reflection<A..., R...>(fName, f: (A...) -> R..., ...): (A...) -> R...
	local reflectionArgs = {}
	
	for i, v in {...} do
		local isFunctional = type(v) == "function"
		
		local arg = if isFunctional then KNOWN_CUSTOM[v] else KNOWN_TYPES[v]
		if not arg then
			local isOpt = if not isFunctional then string.sub(v, -1) == "?" else false
		
			arg = {
				Optional = isOpt,
				Type = if not isFunctional then if isOpt	then string.sub(v, 1, -2) else v else nil,
				CustomAssert = if isFunctional then v else nil	
			}
			
			(if isFunctional then KNOWN_CUSTOM else KNOWN_TYPES)[v] = arg
		end
		
		reflectionArgs[i] = arg
	end

	
	return function(...)
		REFLECTION(reflectionArgs, fName, ...)
		return f(...)
	end
end

return Reflection