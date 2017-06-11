local serpent = require("libs.serpent0272")

local DEBUG = false

local function set_debug(value)
    DEBUG = value
end

local function log(msg)
    if DEBUG then print(msg) end
end

local function dump(msg, object)
    log(msg .. ":\n" .. serpent.dump(object) .. "\n")
end

local function is_array(collection)
    -- Maybe a bit naive to check if it's an array but it seems to work for now
    return collection[1] ~= nil
end

local function _for(from, to, collection, callback_fn)
    for i = from, to do
        local v = collection[i]
        local continue = callback_fn(i, v)
        if continue == false then
            return
        end
    end
end

local function each(collection, callback_fn, skip)
    local length = #collection
    skip = skip ~= nil and skip or 0

    if skip >= length or length == 0 then
        return
    end

    _for(1 + skip, length, collection, callback_fn)
end

local function each_right(collection, callback_fn, skip)
    local length = #collection
    skip = skip ~= nil and skip or 0

    if skip >= length or length == 0 then
        return
    end

    _for(length - skip, 1, collection, callback_fn)
end

local function _find(iterator, collection, predicate_fn, skip)
    local result = nil
    iterator(
        collection,
        function(i, v)
            local found = predicate_fn(i, v)
            if found then
                result = found
                return false
            end
        end,
        skip
    )
    return result
end

local function find(collection, predicate_fn, skip)
    return _find(each, collection, predicate_fn, skip)
end

local function find_right(collection, predicate_fn, skip)
    return _find(each_right, collection, predicate_fn, skip)
end

local function reduce(collection, callback_fn, initial_value)
    local acc = initial_value ~= nil and initial_value or collection[1]
    each(
        collection,
        function(i, v)
            acc = callback_fn(acc, v, i)
        end,
        -- skip first item if no initial value was provided
        initial_value == nil and 1 or 0
    )
    return acc
end

local function filter(collection, predicate_fn)
    local result = {}
    each(
        collection,
        function (i, v)
            if predicate_fn(v, i) then
                table.insert(result, v)
            end
        end
    )
    return result
end

local function find_empty_slot(inventory, skip)
    return find(
        inventory,
        function(_, slot)
            -- a slot is empty if valid_for_read is false
            return slot.valid and not slot.valid_for_read and slot or nil
        end,
        skip
    )
end

local function find_item_stack(inventory, name, skip)
    return find(
        inventory,
        function (_, slot)
            -- a slot is empty if valid_for_read is false
            return slot.valid and slot.valid_for_read and slot.name == name and slot or nil
        end,
        skip
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

local function get_at(table, path)
    return reduce(
        path,
        function (curr, key)
            if curr and curr[key] and curr[key].valid then
                return curr[key]
            end
            return curr
        end,
        table
    )
end

-- TODO: make this function generic again
local function intersection(a, b, comparator_fn)
    local result = {}

    local hashmap = reduce(
        b,
        function (map, item)
            if map[item.name] then
                map[item.name] = map[item.name] + 1
            else
                map[item.name] = 1
            end
            return map
        end,
        {}
    )

    each(
        a,
        function (_, v)
            if not hashmap[v.name] then return end

            if hashmap[v.name] > 0 then
                table.insert(result, v)
                hashmap[v.name] = hashmap[v.name] - 1
            end
        end
    )

    -- while a_i <= #a and b_i <= #b do
    --     -- TODO: use a lookup table instead
    --     _for(b_i, #b, b, function (_, v)
    --         if comparator_fn(a[a_i], v) then
    --             table.insert(result, a[a_i]) -- or b?! does it matter?
    --             b_i = b_i + 1
    --             return false
    --         end
    --     end)
    --     a_i = a_i + 1
    -- end

    return result
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
    each_right = each_right,
    find = find,
    find_right= find_right,
    reduce = reduce,
    filter = filter,
    find_empty_slot = find_empty_slot,
    find_item_stack = find_item_stack,
    count_inventory_items = count_inventory_items,
    get_at = get_at,
    intersection = intersection,
    make_pprint = make_pprint
}
