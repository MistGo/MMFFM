--[[
    Script created by MistGo
    Updated 18.04.2024
]]

PickableShapes = class()
local isSurvival = nil

function PickableShapes:server_onCreate()
    PickableShapes.tool = self.tool
    isSurvival = sm.game.getLimitedInventory()

    local GameMode = isSurvival and "Survival" or "Creative"
    print("Pickable Shapes for " .. GameMode .. " loaded.")
end

function PickableShapes:server_onRefresh()
    PickableShapes.tool = self.tool
    isSurvival = sm.game.getLimitedInventory()

    print("Pickable Shapes refreshed.")
end

function PickableShapes:client_onFixedUpdate()
    if better and better.isAvailable() then
        local state = better.mouse.isCenter()
        if state ~= oldstate then
            if state then
                self.network:sendToServer("sv_tunnel", { player = sm.localPlayer.getPlayer(), hotbar_page = 1 })
            end
            oldstate = state
        end
    end
end

function PickableShapes:sv_changeItem(args)
    local current_slot, hotbar, hotbar_page, inventory, uuid = args.slot, args.hotbar, args.hotbar_page, args.inventory, args.uuid

    if hotbar_page == nil then
    elseif hotbar_page == 2 then
        current_slot = current_slot + 10
    elseif hotbar_page == 3 then
        current_slot = current_slot + 20
    elseif hotbar_page > 3 or hotbar_page < 1 then else end

    if not isSurvival then -- Creative
        local cur_item = hotbar:getItem(current_slot)
        local found = false
        for slot = 0, (hotbar:getSize() - 1) do
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
        for slot = 0, (inventory:getSize() - 1) do
            local items = inventory:getItem(slot)
            if items and (items.uuid == uuid) then
                sm.container.beginTransaction()
                sm.container.swap(inventory, slot, inventory, current_slot)
                sm.container.endTransaction()
                break
            end
        end
    end
end

function PickableShapes:cl_getItem(params)
    local slot = sm.localPlayer.getSelectedHotbarSlot()
    local hotbar_page = params.hotbar_page
    local container = isSurvival and sm.localPlayer.getInventory() or sm.localPlayer.getHotbar()
    local bool, result = sm.localPlayer.getRaycast(5, sm.localPlayer.getRaycastStart(), sm.localPlayer.getDirection())

    if bool and (result.type == "body") then
        local shape = result:getShape()
        if sm.exists(shape) then
            local args = { hotbar = not isSurvival and container or nil, inventory = isSurvival and container or nil, slot = slot, uuid = shape.uuid, hotbar_page = not isSurvival and hotbar_page or nil }
            self.network:sendToServer("sv_changeItem", args)
            sm.particle.createParticle("p_tool_multiknife_refine_hit_metal", result.pointWorld)
        end
    end
end

function PickableShapes:sv_tunnel(params)
    self.network:sendToClient(params.player, "cl_getItem", { hotbar_page = params.hotbar_page })
end

if not commandsBind then
    local oldBindCommand = sm.game.bindChatCommand
    local function bindCommandHook(command, params, callback, help)
        oldBindCommand(command, params, callback, help)
        if not added then
            oldBindCommand("/get", { { "int", "hotbar_page", true } }, "cl_onChatCommand", "")
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