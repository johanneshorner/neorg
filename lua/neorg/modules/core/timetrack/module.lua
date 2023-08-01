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

local function clock_in(event)
    local mod_todo = module.required["core.qol.todo_items"]

    local todo_node = mod_todo.get_todo_item_from_cursor(event.buffer, event.cursor_position[1] - 1)

    -- cursor not on a todo item
    if not todo_node then
        -- not an error, just for debugging purposes
        neorg.utils.notify("not on a todo node", vim.log.levels.ERROR)
        return
    end

    local mod_ts = module.required["core.integrations.treesitter"]

    local todo_line_idx, _, _ = todo_node:start()
    local next_node = mod_ts.get_first_node_on_line(event.buffer, todo_line_idx + 1)
    if not next_node then
        -- not an error, just for debugging purposes
        neorg.utils.notify("next node nil", vim.log.levels.ERROR)
        return
    end

    if next_node:type() ~= "ranged_tag" then
        local line_idx, _, _ = next_node:start()
        vim.api.nvim_buf_set_lines(event.buffer, line_idx, line_idx, true, { "|timetrack", "|end" })
    end

    local tempus = module.required["core.tempus"]
    local tag_start_idx, _, tag_end_idx, _ = next_node:range(false)
    local entry_idx = tag_start_idx + 1

    -- there is at least one time entry in the ranged tag
    if tag_end_idx ~= (tag_start_idx + 1) then
        local line = vim.api.nvim_buf_get_lines(event.buffer, entry_idx, entry_idx + 1, true)[1]
        local pos = line:find("-}")

        if pos then
            pos = pos - 1
            local time_str = line:gsub("-}", os.date("- %H:%M}"))
            print(time_str)
            vim.api.nvim_buf_set_lines(event.buffer, entry_idx, entry_idx + 1, true, { time_str })
            return
        end
    end

    local current_time = tostring(tempus.to_date(os.date("*t"), true))
    vim.api.nvim_buf_set_lines(0, entry_idx, entry_idx, true, { "{@ " .. current_time .. " -}" })
end
--
-- local function clock_in(event)
--     local mod_treesitter = module.required["core.integrations.treesitter"]
--     local ts_utils = mod_treesitter.get_ts_utils()
--
--     local current_node = ts_utils.get_node_at_cursor()
--     local found_node = mod_treesitter.find_parent(current_node, "todo_item_")
--
--     -- cursor not on a todo item
--     if not found_node then
--         print("fail")
--         neorg.utils.notify("cursor not on a todo item", vim.log.levels.ERROR)
--         return
--     else
--         print("success")
--     end
--     --
--     -- local tempus = module.required["core.tempus"]
--     -- local current_time = tostring(tempus.to_date(os.date("*t"), true))
--     --
--     -- local current_line_idx = vim.api.nvim_win_get_cursor(0)[1] - 1
--     -- vim.api.nvim_buf_set_lines(0, current_line_idx + 1, current_line_idx + 1, true, { "{@ " .. current_time .. "}" })
-- end

-- searches upwards in the tree to find the first node that is a todo_item and returns it
-- (this might not work in some cases. Needs a treesitter expert)
local function find_parent_todo(node)
    local _node = node:parent()

    while _node do
        for child, _ in _node:iter_children() do
            if child:type() == "detached_modifier_extension" then
                for child_1, _ in child:iter_children() do
                    if child_1:type():find("todo_item_") then
                        return child_1
                    end
                end
            end
        end

        _node = _node:parent()
    end
end

local function clock_out()
    local mod_treesitter = module.required["core.integrations.treesitter"]
    local ts_utils = mod_treesitter.get_ts_utils()
    local current_node = ts_utils.get_node_at_cursor()
    local found_node = find_parent_todo(current_node)

    print(found_node)
end

module.on_event = function(event)
    if event.split_type[2] == "core.timetrack.clock-in" then
        clock_in(event)
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
