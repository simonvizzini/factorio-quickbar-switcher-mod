local serpent = require("libs.serpent0272")

local DEBUG = false

local log = function (msg)
    if DEBUG then print(msg) end
end

local function init_player(player_index)
    global.data = global.data or {}
    global.data[player_index] = {
        layouts = {},
        current_layout_index = 1
    }
end

local function init_players()
    for _, player in pairs(game.players) do
        init_player(player.index)
    end
end

script.on_init(
    function()
        log("my_mod: on_init")
        init_players()
    end
)

script.on_load(
    function()
        log("my_mod: on_load")
    end
)

script.on_event(
    defines.events.on_player_created,
    function(event)
        init_player(event.player_index)
    end
)

local function create_hotkey_handler(index)
    return function(event)
        local player = game.players[event.player_index]

        log(serpent.dump(global.data))
        local player_data = global.data[player.index]
        local current_index = player_data.current_layout_index

        log("current index: " .. current_index)
        log("target index: " .. index)

        local quickbar = player.character.get_inventory(defines.inventory.player_quickbar)
        local current_layout = {}
        local num_slots = #quickbar

        for i = 1, num_slots do
            local slot = quickbar[i]
            table.insert(current_layout, slot.valid_for_read and slot.name or "empty")
        end

        player_data.layouts[current_index] = current_layout

        local target_layout = player_data.layouts[index] or {}

        log("current layout\n:" .. serpent.dump(current_layout) .. "\n\n")
        log("target layout:\n" .. serpent.dump(target_layout) .. "\n\n")

        quickbar.clear()

        for i = 1, num_slots do
            local slot = quickbar[i]
            local item = target_layout[i]
            local filter = quickbar.get_filter(i)

            -- If slot is filtered try to restore it
            if filter then
                if slot.can_set_stack(filter) then
                    quickbar[i].set_stack(filter)
                end
            elseif item ~= nil and item ~= "empty" then
                if slot.can_set_stack(item) then
                    quickbar[i].set_stack(item)
                end
            end
        end

        player_data.current_layout_index = index
    end
end

for i = 1, 5 do
    script.on_event(
        "quickbar_switch_" .. i,
        create_hotkey_handler(i)
    )
end

-- script.on_event(
--     "quickbar_layout_1",
--     create_hotkey_handler(1)
-- )

-- script.on_event(
--     "quickbar_layout_2",
--     create_hotkey_handler(2)
-- )

-- script.on_event(
--     "quickbar_layout_3",
--     create_hotkey_handler(3)
-- )

-- script.on_event(
--     "quickbar_layout_4",
--     create_hotkey_handler(4)
-- )

-- script.on_event(
--     "quickbar_layout_5",
--     create_hotkey_handler(5)
-- )
