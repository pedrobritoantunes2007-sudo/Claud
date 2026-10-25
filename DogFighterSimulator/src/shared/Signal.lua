-- Evento simples feito em Lua, no lugar do BindableEvent nos serviços do servidor.
-- O BindableEvent COPIA as tabelas enviadas (o ouvinte recebe outra tabela, então "victim == s.Fighter"
-- nunca é verdade) e pode falhar com tabelas que têm Instances como chave ou referências cíclicas.
-- Aqui o ouvinte recebe a tabela original, e cada ouvinte roda separado: o erro de um não para os outros.
-- Mesma forma de uso: Sinal.Event:Connect(fn) e Sinal:Fire(...).
local Signal = {}
Signal.__index = Signal

local Event = {}
Event.__index = Event

function Event:Connect(fn)
	local handlers = self._handlers
	table.insert(handlers, fn)
	local connection = { Connected = true }
	function connection.Disconnect()
		if not connection.Connected then
			return
		end
		connection.Connected = false
		local i = table.find(handlers, fn)
		if i then
			table.remove(handlers, i)
		end
	end
	return connection
end

function Event:Once(fn)
	local connection
	connection = self:Connect(function(...)
		connection.Disconnect()
		fn(...)
	end)
	return connection
end

function Event:Wait()
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal.new()
	return setmetatable({ Event = setmetatable({ _handlers = {} }, Event) }, Signal)
end

function Signal:Fire(...)
	for _, fn in ipairs(table.clone(self.Event._handlers)) do
		task.spawn(fn, ...)
	end
end

return Signal
