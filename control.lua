local utils = require("utils")

utils.set_debug(false)

local function get_player_data(player_index)
    global.player_data = global.player_data or {}
    global.player_data[player_index] = global.player_data[player_index] or {
        layouts = {},
        current_layout_index = 1
    }
    return global.player_data[player_index]
end

local function switch_layout(player, target_index)
    local pprint = utils.make_pprint(player, "[QuickbarSwitcher]")
    local player_data = get_player_data(player.index)
    local current_index = player_data.current_layout_index

    utils.log("trying to switch quickbar " .. current_index .. " to " .. target_index)

    if current_index == target_index then
        utils.log("same index, nothing to do")
        return
    end

    local quickbar = player.character.get_inventory(defines.inventory.player_quickbar)
    local quickbar_slot_count = #quickbar
    local quickbar_items = utils.filter(quickbar, function (slot) return slot.valid and slot.valid_for_read end)
    local quickbar_item_count = #quickbar_items

    local inventory = player.character.get_inventory(defines.inventory.player_main)
    local inventory_slot_count = #inventory
    local inventory_item_count = utils.count_inventory_items(inventory)
    local inventory_free_slots = inventory_slot_count - inventory_item_count

    local target_layout = player_data.layouts[target_index] or {}
    local target_layout_items = utils.filter(target_layout, function (item) return item.name ~= nil end)
    local target_layout_item_count = #target_layout_items

    utils.log("target layout item count: " .. target_layout_item_count)

    -- how many items can we carry over from the current layout to the target layout?
    -- required to know how many free inventory slots are necessary to switch layouts
    local items_to_carry_over = utils.intersection(
        quickbar_items,
        target_layout_items,
        function (quickbar_slot, target_item)
            return quickbar_slot.name == target_item.name
        end
    )

    utils.log("items to carry over: " .. #items_to_carry_over)

    local required_inventory_slots = quickbar_item_count - target_layout_item_count - #items_to_carry_over

    utils.log("required inventory slots: " .. required_inventory_slots)

    if inventory_free_slots < required_inventory_slots then
        local missing_slots = required_inventory_slots - inventory_free_slots
        pprint("Cannot switch, not enough empty inventory slots. Need " .. missing_slots .. " more slot" .. (missing_slots > 1 and "s" or ""))
        return
    end

    local cursor_stack = utils.get_at(player, {"character", "cursor_stack"})
    local cursor_not_empty = cursor_stack and cursor_stack.valid_for_read

    ----------------------------------------------------------------------------------------------------
    -- if there is no empty slot to temporary hold items then print a message and return.
    -- with the check above this should never be true, but just in case I messed up
    ----------------------------------------------------------------------------------------------------
    if inventory_free_slots == 0 and cursor_not_empty then
        pprint("Cannot switch, need 1 empty slot to temporary hold items.")
        return
    end

    -- this will prevent the cursor stack from being used if the player currently holds something
    if cursor_not_empty then
        cursor_stack = nil
    end

    ----------------------------------------------------------------------------------------------------
    -- store the current active quickbar layout
    ----------------------------------------------------------------------------------------------------
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

        -- clear filter
        if filter then
            quickbar.set_filter(i, nil)
        end
    end

    utils.dump("\ncurrent layout", current_layout)
    utils.dump("target layout", target_layout)

    --------------------------------------------------
    -- move quickbar items to inventory
    --------------------------------------------------
    for i = 1, quickbar_slot_count do
        local quickbar_slot = quickbar[i]
        local target_item = target_layout[i] or {}

        -- utils.log("slot " .. i .. "\nquickbar item: " .. (quickbar_slot.valid_for_read and quickbar_slot.name or "nil") .. "\ntarget item: " .. (target_item.name or "nil"))

        if quickbar_slot.valid_for_read and target_item.name ~= quickbar_slot.name then
            local empty_slot = cursor_stack or utils.find_empty_slot(inventory) or utils.find_empty_slot(quickbar, i)

            -- check if we can temporary use a quickslot ahead to store the current item
            if not empty_slot then
                empty_slot = utils.find_empty_slot(quickbar, i)
            end

            if not empty_slot then
                pprint("could not find slot to temporary hold item, please report if you read this.")
                return
            end

            if not empty_slot.can_set_stack(quickbar_slot) then
                pprint("no empty slot or cannot set inventory stack, please report if you read this..")
                return
            end

            empty_slot.set_stack(quickbar_slot)
            quickbar_slot.clear()
        end

        if not quickbar_slot.valid_for_read and target_item.name then
            -- first look in inventory, then in the quickbar slots ahead
            local item_stack = utils.find_item_stack(quickbar, target_item.name, i) or inventory.find_item_stack(target_item.name)

            if not item_stack then
                utils.log("couldn't find item " .. target_item.name .. " in inventory, skipping")
            elseif not quickbar_slot.can_set_stack(item_stack) then
                -- this should also not happen anymore. the only time this did not work was
                -- when the target quickbar slot was filtered, but all quickbar filters ahead are reset at this point.
                -- but who knows, maybe there are other scenarios I don't know about yet
                pprint("can't set quickbar stack. item: [" .. target_item.name .. "], please report if you read this.")
            else
                quickbar_slot.set_stack(item_stack)
                item_stack.clear()
            end
        end

        -- reset cursor stack if we used it as temporary holder
        if cursor_stack and cursor_stack.valid_for_read then
            local empty_slot = utils.find_empty_slot(inventory) or utils.find_empty_slot(quickbar, i)
            if not empty_slot then
                -- this should never happen, but who knows, return so no items in the cursor stack are destroyed
                pprint("no empty slot found to put cursor item back, please report if you read this.")
                return
            end
            if not empty_slot.can_set_stack(cursor_stack) then
                -- again, this should not happen anymore
                pprint("cannot set cursor stack, please report if you read this.")
                return
            end
            empty_slot.set_stack(cursor_stack)
            cursor_stack.clear()
        end

        -- restore filter
        if target_item.filter then
            quickbar.set_filter(i, target_item.filter)
        end
    end

    -- store new layout and index
    player_data.layouts[current_index] = current_layout
    player_data.current_layout_index = target_index

    utils.log("quickbar switch done\n")
end

local function make_hotkey_handler(target_index)
    return function (event)
        local player = game.players[event.player_index]
        switch_layout(player, target_index)
    end
end

for i = 1, 5 do
    script.on_event(
        "quickbar_switch_" .. i,
        make_hotkey_handler(i)
    )
end
