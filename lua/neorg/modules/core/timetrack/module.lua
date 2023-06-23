--[[
    file: timetrack
    title: Time tracking
    summary: Track the time you spend on various tasks.
    internal: true
    ---
`core.tempus` is an internal module specifically designed
to handle complex dates. It exposes two functions: `parse_date(string) -> date|string`
and `to_lua_date(date) -> osdate`.
--]]

local module = neorg.modules.create("core.timetrack")

module.setup = function()
    return {
        requires = {
            "core.tempus",
        },
    }
end

module.load = function()
    neorg.modules.await("core.keybinds", function(keybinds)
        keybinds.register_keybinds(module.name, { "clock-in", "clock-out" })
    end)
end

local function clock_in()
    local tempus = module.required["core.tempus"]
    local current_time = tostring(tempus.to_date(os.date("*t"), true))
    vim.api.nvim_put({ "{@ " .. current_time .. "}" }, "c", false, true)
end

local function clock_out() end

module.on_event = function(event)
    if event.split_type[2] == "core.timetrack.clock-in" then
        clock_in()
    elseif event.split_type[2] == "core.timetrack.clock-out" then
        clock_out()
    end
end

module.events.subscribed = {
    ["core.keybinds"] = {
        [module.name .. ".clock-in"] = true,
        [module.name .. ".clock-out"] = true,
    },
}

return module
