--[[
    Script created by MistGo
    Updated 25.03.2024
]]

PickableShapes = class()
local isSurvival = nil

function PickableShapes:server_onCreate()
    PickableShapes.tool = self.tool
    isSurvival = sm.game.getLimitedInventory()
    local GameMode = isSurvival and "Survival" or "Creative"

    print("Pickable Shapes for " .. GameMode .. " Server loaded.")
end

function PickableShapes:server_onRefresh()
    PickableShapes.tool = self.tool
    print("Pickable Shapes refreshed.")
end

function PickableShapes:sv_tunnel(args)
    self.network:sendToClient(args.player, "cl_getItem", {hotbar_page = args.hotbar_page})
end

function PickableShapes:sv_changeItem(args)
    local current_slot, max_slot, hotbar, hotbar_page, inventory, uuid = args.slot, 9, args.hotbar, args.hotbar_page, args.inventory, args.uuid

    print(hotbar_page)

    if hotbar_page == nil then
    elseif hotbar_page == 2 then
        current_slot = current_slot+10
        max_slot = 19
    elseif hotbar_page == 3 then
        current_slot = current_slot+20
        max_slot = 29
    elseif hotbar_page > 3 or hotbar_page < 1 then else end

    if not isSurvival then -- Creative
        local cur_item = hotbar:getItem(current_slot)
        local found = false
        for slot = 0, max_slot do
            local items = hotbar:getItem(slot)
            if items and (items.uuid == uuid) then
                sm.container.beginTransaction()
                sm.container.swap(hotbar, slot, hotbar, current_slot)
                sm.container.endTransaction()
                found = true
                break
            end
        end
        if not found then
            sm.container.beginTransaction()
            sm.container.spendFromSlot(hotbar, current_slot, cur_item.uuid, cur_item.quantity, true)
            sm.container.collectToSlot(hotbar, current_slot, uuid, 1, true)
            sm.container.endTransaction()
        end
    else -- Survival
        for slot = 0, 39 do
            local items = inventory:getItem(slot)
            if items and (items.uuid == uuid) then
                sm.container.beginTransaction()
                sm.container.swap(inventory, slot, inventory, current_slot)
                sm.container.endTransaction()
            end
        end
    end
end

function PickableShapes:cl_getItem(args)
    local slot = sm.localPlayer.getSelectedHotbarSlot()
    local container = isSurvival and sm.localPlayer.getInventory() or sm.localPlayer.getHotbar()
    local hotbar_page = args.hotbar_page
    local bool, result = sm.localPlayer.getRaycast(5, sm.localPlayer.getRaycastStart(), sm.localPlayer.getDirection())

    if bool and (result.type == "body") then
        local shape = result:getShape().uuid
        if sm.exists(shape) then
            local args = { hotbar = not isSurvival and container or nil, inventory = isSurvival and container or nil, slot = slot, uuid = shape, hotbar_page = not isSurvival and hotbar_page or nil }
            self.network:sendToServer("sv_changeItem", args)
        end
    end
end

if not commandsBind then
    local oldBindCommand = sm.game.bindChatCommand
    local function bindCommandHook(command, params, callback, help)
        oldBindCommand(command, params, callback, help)
        if not added then
            oldBindCommand("/get", { { "int", "hotbar_page", true } }, "cl_onChatCommand", "Aim at the desired block and enter the following command to get it in the active hotbar slot. You can also choose the hotbar page (default 1).")
            added = true
        end
    end
    sm.game.bindChatCommand = bindCommandHook

    local oldWorldEvent = sm.event.sendToWorld

    local function worldEventHook(world, callback, params)
        if params then
            if params[1] == "/get" then
                sm.event.sendToTool(PickableShapes.tool, "sv_tunnel", { player = params.player, hotbar_page = (params[2] or 1) })
                return
            end
        end
        oldWorldEvent(world, callback, params)
    end
    sm.event.sendToWorld = worldEventHook
    commandsBind = true
end