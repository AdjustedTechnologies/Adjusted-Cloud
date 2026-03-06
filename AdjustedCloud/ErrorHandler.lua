local ErrorHandler = {}

local logLevels = {
	DEBUG = 1,
	INFO = 2,
	WARN = 3,
	ERROR = 4,
}

local currentLogLevel = logLevels.INFO

function ErrorHandler.setLevel(level)
	currentLogLevel = level
end

function ErrorHandler.debug(...)
	if currentLogLevel <= logLevels.DEBUG then
		print("[AdjustedCloud:DEBUG]", ...)
	end
end

function ErrorHandler.info(...)
	if currentLogLevel <= logLevels.INFO then
		print("[AdjustedCloud:INFO]", ...)
	end
end

function ErrorHandler.warn(...)
	if currentLogLevel <= logLevels.WARN then
		warn("[AdjustedCloud:WARN]", ...)
	end
end

function ErrorHandler.error(...)
	if currentLogLevel <= logLevels.ERROR then
		error("[AdjustedCloud:ERROR] " .. table.concat({...}, " "), 2)
	end
end

return ErrorHandler