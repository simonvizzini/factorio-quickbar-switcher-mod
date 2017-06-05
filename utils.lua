local serpent = require("libs.serpent0272")

local DEBUG = false

local function set_debug(value)
    DEBUG = value
end

local function log(msg)
    if DEBUG then print(msg) end
end

local function dump(msg, object)
    log(msg .. ": " ..serpent.dump(object))
end

local function is_array(collection)
    -- Maybe a bit naive to check if it's an array but it seems to work for now
    return collection[1] ~= nil
end

local function each(collection, callback_fn, skip)
    local length = #collection
    skip = skip ~= nil and skip or 0

    if skip >= length or length == 0 then
        return
    end

    for i = 1 + skip, length do
        local v = collection[i]
        local continue = callback_fn(i, v)
        if continue == false then
            return
        end
    end
end

local function find(collection, predicate_fn)
    local result = nil
    each(
        collection,
        function (i, v)
            local found = predicate_fn(i, v)
            if found then
                result = found
                return false
            end
        end
    )
    return result
end

local function reduce(collection, callback_fn, initial_value)
    local acc = initial_value ~= nil and initial_value or collection[1]
    each(
        collection,
        function (i, v)
            acc = callback_fn(acc, v, i)
        end,
        -- skip first item if no initial value was provided
        initial_value == nil and 1 or 0
    )
    return acc
end

local function find_empty_slot(inventory)
    return find(
        inventory,
        function (_, slot)
            -- a slot is empty if valid_for_read is false
            return slot.valid and not slot.valid_for_read and slot or nil
        end
    )
end

local function count_inventory_items(inventory)
    return reduce(
        inventory,
        function (count, slot)
            -- print("count_inventory_items count: " .. count .. ", slot.valid_for_read:" .. (slot.valid_for_read and "true" or "false"))
            return count + (slot.valid and slot.valid_for_read and 1 or 0)
        end,
        0
    )
end

------------------------------------------------------------------------------------
-- Makes a function that will print messages with a given prefix to the given player
------------------------------------------------------------------------------------
local function make_pprint(player, prefix)
    return function (msg)
        player.print(prefix .. " " .. msg)
    end
end

return {
    set_debug = set_debug,
    log = log,
    dump = dump,
    is_array = is_array,
    each = each,
    find = find,
    reduce = reduce,
    find_empty_slot = find_empty_slot,
    count_inventory_items = count_inventory_items,
    make_pprint = make_pprint
}
