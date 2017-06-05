local utils = require("utils")

utils.set_debug(true)

local function init_player(player_index)
    global.player_data = global.player_data or {}
    global.player_data[player_index] = {
        layouts = {},
        current_layout_index = 1
    }
end

script.on_init(
    function()
        utils.log("QuickbarSwitcher: on_init")
        for _, player in pairs(game.players) do
            init_player(player.index)
        end
    end
)

script.on_load(
    function()
        utils.log("QuickbarSwitcher: on_load")
    end
)

script.on_event(
    defines.events.on_player_created,
    function(event)
        init_player(event.player_index)
    end
)

local function make_hotkey_handler(target_index)
    return function(event)
        local player = game.players[event.player_index]
        local pprint = utils.make_pprint(player, "[QuickbarSwitcher]")
        local player_data = global.player_data[player.index]
        local current_index = player_data.current_layout_index

        utils.log("trying to switch quickbar " .. current_index .. " to " .. target_index)

        if current_index == target_index then
            utils.log("same index, nothing to do")
            return
        end

        utils.log("global.player_data dump: " .. serpent.dump(global.player_data))

        -- TODO:
        -- Implement smart inventory moving that considers currently free quickbar slots,
        -- required slots for the target layout and items with only 1 stack available that are shared between quickbars.
        local quickbar = player.character.get_inventory(defines.inventory.player_quickbar)
        local quickbar_slot_count = #quickbar
        local quickbar_item_count = utils.count_inventory_items(quickbar)
        -- local quickbar_free_slots = quickbar_slot_count - quickbar_item_count

        -- pprint("quickbar slot count: " .. quickbar_slot_count)
        -- pprint("quickbar used slots: " .. quickbar_item_count)
        -- pprint("free quickbar slots: " .. quickbar_free_slots)

        local inventory = player.character.get_inventory(defines.inventory.player_main)
        local inventory_slot_count = #inventory
        local inventory_item_count = utils.count_inventory_items(inventory)
        local inventory_free_slots = inventory_slot_count - inventory_item_count

        -- pprint("inventory slot count: " .. inventory_slot_count)
        -- pprint("inventory used slots: " .. inventory_item_count)
        -- pprint("free inventory slots: " .. inventory_free_slots)

        local target_layout = player_data.layouts[target_index] or {}
        -- local target_layout_item_count = #target_layout

        if inventory_free_slots < quickbar_item_count then
            local missing_slots = quickbar_item_count - inventory_free_slots
            pprint("Cannot switch, not enough empty inventory slots. Need " .. missing_slots .. " more slot" .. (missing_slots > 1 and "s" or ""))
            return
        end

        --------------------------------------------------
        -- store the current active quickbar layout
        --------------------------------------------------
        local current_layout = {}

        for i = 1, quickbar_slot_count do
            local quickbar_slot = quickbar[i]
            local filter = quickbar.get_filter(i)

            table.insert(
                current_layout,
                {
                    -- if current slot is empty, but a filter is set then take the filter as name
                    name = quickbar_slot.valid_for_read and quickbar_slot.name or filter or nil,
                    filter = filter
                }
            )
        end

        utils.dump("current layout\n:", current_layout)
        utils.dump("target layout:\n", target_layout)

        --------------------------------------------------
        -- move quickbar items to inventory
        --------------------------------------------------
        for i = 1, quickbar_slot_count do
            local quickbar_slot = quickbar[i]

            -- clear filter
            if quickbar.get_filter(i) then
                quickbar.set_filter(i, nil)
            end

            if quickbar_slot.valid_for_read then
                local empty_slot = utils.find_empty_slot(inventory)

                if not empty_slot then
                    -- should not happen because of the safe guard above
                    pprint("no empty inventory slot found")
                    return
                end

                if not empty_slot.can_set_stack(quickbar_slot) then
                    pprint("cannot set inventory stack, now what?")
                    return
                end

                empty_slot.set_stack(quickbar_slot)
                quickbar_slot.clear()
            end
        end

        --------------------------------------------------
        -- put items from target layout into quickbar
        --------------------------------------------------
        for i = 1, quickbar_slot_count do
            local quickbar_slot = quickbar[i]
            local item = target_layout[i]

            if item then
                if item.name then
                    local item_stack = inventory.find_item_stack(item.name)

                    if not item_stack then
                        pprint("couldn't find item " .. item.name .. " in inventory, skipping")
                    elseif not quickbar_slot.can_set_stack(item_stack) then
                        pprint("can't set quickbar stack, now what? item: " .. item.name)
                    else
                        quickbar_slot.set_stack(item_stack)
                        item_stack.clear()
                    end
                end

                -- restore filter
                if item.filter then
                    quickbar.set_filter(i, item.filter)
                end
            end
        end

        -- store new layout and index
        player_data.layouts[current_index] = current_layout
        player_data.current_layout_index = target_index
    end
end

for i = 1, 5 do
    script.on_event(
        "quickbar_switch_" .. i,
        make_hotkey_handler(i)
    )
end
