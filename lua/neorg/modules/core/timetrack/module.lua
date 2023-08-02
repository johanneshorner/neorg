--[[
    file: timetrack
    title: Time tracking
    summary: Track the time you spend on various tasks.
    internal: true
    ---
--]]

local neorg = require("neorg.core")
local module = neorg.modules.create("core.timetrack")

module.setup = function()
    return {
        requires = {
            "core.tempus",
            "core.qol.todo_items",
            "core.integrations.treesitter",
        },
    }
end

module.load = function()
    neorg.modules.await("core.keybinds", function(keybinds)
        keybinds.register_keybinds(module.name, { "clock-in", "clock-out" })
    end)
end

--- Finds or creates a timetrack tag
---
---@param buffer integer
---@param line_idx integer
---@return (TSNode|nil)
local function find_or_create_timetrack_tag(buffer, line_idx)
    local mod_todo = module.required["core.qol.todo_items"]

    local todo_node = mod_todo.get_todo_item_from_cursor(buffer, line_idx)

    -- cursor not on a todo item
    if not todo_node then
        -- not an error, just for debugging purposes
        neorg.utils.notify("not on a todo node", vim.log.levels.ERROR)
        return
    end

    local mod_ts = module.required["core.integrations.treesitter"]

    local todo_line_idx = todo_node:start()

    local next_node
    if todo_line_idx == (vim.api.nvim_buf_line_count(buffer) - 1) then
        vim.api.nvim_buf_set_lines(buffer, todo_line_idx + 1, todo_line_idx + 1, true, { "|timetrack", "|end" })
        next_node = mod_ts.get_first_node_on_line(buffer, todo_line_idx + 1)
    else
        next_node = mod_ts.get_first_node_on_line(buffer, todo_line_idx + 1)
        if not next_node then
            -- not an error, just for debugging purposes
            neorg.utils.notify("next node nil", vim.log.levels.ERROR)
            return
        end

        if next_node:type() ~= "ranged_tag" then
            -- local timetrack_line_idx = next_node:start()
            vim.api.nvim_buf_set_lines(buffer, todo_line_idx + 1, todo_line_idx + 1, true, { "|timetrack", "|end" })
            next_node = mod_ts.get_first_node_on_line(buffer, todo_line_idx + 1)
        end
    end

    return next_node
end

local function clock_out(event)
    local timetrack_node = find_or_create_timetrack_tag(event.buffer, event.cursor_position[1] - 1)

    if not timetrack_node then
        return
    end

    local tag_start_idx, _, tag_end_idx, _ = timetrack_node:range(false)
    local entry_idx = tag_start_idx + 1

    -- there is at least one time entry in the ranged tag
    if tag_end_idx ~= (tag_start_idx + 1) then
        local line = vim.api.nvim_buf_get_lines(event.buffer, entry_idx, entry_idx + 1, true)[1]
        local pos = line:find("-}")

        if pos then
            pos = pos - 1
            local time_str = line:gsub("-}", os.date("- %H:%M}"))
            vim.api.nvim_buf_set_lines(event.buffer, entry_idx, entry_idx + 1, true, { time_str })
        end
    end

    return entry_idx
end

local function clock_in(event)
    local entry_idx = clock_out(event)

    if entry_idx then
        local tempus = module.required["core.tempus"]
        local current_time = tostring(tempus.to_date(os.date("*t"), true))
        vim.api.nvim_buf_set_lines(0, entry_idx, entry_idx, true, { "{@ " .. current_time .. " -}" })
    end
end

module.on_event = function(event)
    if event.split_type[2] == "core.timetrack.clock-in" then
        clock_in(event)
    elseif event.split_type[2] == "core.timetrack.clock-out" then
        clock_out(event)
    end
end

module.events.subscribed = {
    ["core.keybinds"] = {
        [module.name .. ".clock-in"] = true,
        [module.name .. ".clock-out"] = true,
    },
}

return module
