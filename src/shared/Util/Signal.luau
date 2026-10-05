--!strict
-- Minimal synchronous signal for service-to-service (or controller-to-controller) events.
-- Handlers run in connection order on the firing thread, so they must not yield;
-- wrap slow work in task.spawn. This keeps ordering deterministic, e.g. "save hooks run
-- before the profile is released".

export type Connection = { Connected: boolean, Disconnect: (self: Connection) -> () }
export type Signal<T...> = {
	Connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
}

local Signal = {}

function Signal.new<T...>(): Signal<T...>
	local handlers: { any } = {}
	local self = {}

	function self.Connect(_, handler)
		local connection
		connection = {
			Connected = true,
			_handler = handler,
			Disconnect = function()
				if not connection.Connected then
					return
				end
				connection.Connected = false
				local i = table.find(handlers, connection)
				if i then
					table.remove(handlers, i)
				end
			end,
		}
		table.insert(handlers, connection)
		return connection
	end

	function self.Fire(_, ...)
		-- Clone so handlers may disconnect themselves mid-fire.
		for _, connection in table.clone(handlers) do
			if connection.Connected then
				connection._handler(...)
			end
		end
	end

	return self :: any
end

return Signal
