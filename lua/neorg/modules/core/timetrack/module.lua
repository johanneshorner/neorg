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

-- local function clock_in(event)
--     local mod_todo = module.required["core.qol.todo_items"]
--
--     local node = mod_todo.get_todo_item_from_cursor(event.buffer, event.cursor_position[1] - 1)
--
--     -- cursor not on a todo item
--     if not node then
--         neorg.utils.notify("cursor not on a todo item", vim.log.levels.ERROR)
--         return
--     end
--
--     local tempus = module.required["core.tempus"]
--     local current_time = tostring(tempus.to_date(os.date("*t"), true))
--
--     local current_line_idx = vim.api.nvim_win_get_cursor(0)[1] - 1
--     vim.api.nvim_buf_set_lines(0, current_line_idx + 1, current_line_idx + 1, true, { "{@ " .. current_time .. "}" })
-- end
--
local function clock_in(event)
    local mod_treesitter = module.required["core.integrations.treesitter"]
    local ts_utils = mod_treesitter.get_ts_utils()
    local current_node = ts_utils.get_node_at_cursor()
    local found_node = mod_treesitter.find_parent(current_node, "todo_item_")

    -- cursor not on a todo item
    if not found_node then
        print("fail")
        neorg.utils.notify("cursor not on a todo item", vim.log.levels.ERROR)
        return
    else
        print("success")
    end
    --
    -- local tempus = module.required["core.tempus"]
    -- local current_time = tostring(tempus.to_date(os.date("*t"), true))
    --
    -- local current_line_idx = vim.api.nvim_win_get_cursor(0)[1] - 1
    -- vim.api.nvim_buf_set_lines(0, current_line_idx + 1, current_line_idx + 1, true, { "{@ " .. current_time .. "}" })
end

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
