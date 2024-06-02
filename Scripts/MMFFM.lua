--[[
	Copyright (c) 2024
	MistGo
]]

MMFFM = class()
local isSurvival = nil
local defaultHotbarPage = 1

function MMFFM:server_onCreate()
    MMFFM.tool = self.tool
    isSurvival = sm.game.getLimitedInventory()

    local GameMode = isSurvival and "Survival" or "Creative"
    print("MMFFM for " .. GameMode .. " loaded.")
    sm.gui.chatMessage("#0098EA[MMFFM]#FFFFFF Use #0098EA/get #FFFFFFto obtain the required block without opening the inventory. You can also switch between hotbar pages, just write /get #0098EA[1/2/3]#FFFFFF")
end

function MMFFM:server_onRefresh()
    MMFFM.tool = self.tool
    isSurvival = sm.game.getLimitedInventory()
end

function MMFFM:sv_changeItem(args)
    local min_slot, current_slot, hotbar, hotbar_page, inventory, uuid = 0, args.slot, args.hotbar, args.hotbar_page, args.inventory, args.uuid

    if hotbar_page == nil then
    elseif hotbar_page == 2 then
        current_slot = current_slot + 10
    elseif hotbar_page == 3 then
        current_slot = current_slot + 20
    elseif hotbar_page > 3 or hotbar_page < 1 then else end

    if not isSurvival then -- Creative
        local cur_item = hotbar:getItem(current_slot)
        local found = false
        local isEmpty, emptySlot = false, 0
        for slot = min_slot, (hotbar:getSize() - 1) do
            local items = hotbar:getItem(slot)
            if items and (items.uuid == uuid) then
                if isEmpty then
                    sm.container.beginTransaction()
                    sm.container.swap(hotbar, current_slot, hotbar, emptySlot)
                    sm.container.swap(hotbar, slot, hotbar, current_slot)
                    sm.container.endTransaction()
                else
                    sm.container.beginTransaction()
                    sm.container.swap(hotbar, slot, hotbar, current_slot)
                    sm.container.endTransaction()
                end
                found = true
                break
            elseif items and not isEmpty and (items.uuid == sm.uuid.new("00000000-0000-0000-0000-000000000000")) then
                isEmpty = true
                emptySlot = slot
            end
        end
        if not found and not isEmpty then
            sm.container.beginTransaction()
            sm.container.spendFromSlot(hotbar, current_slot, cur_item.uuid, cur_item.quantity, true)
            sm.container.collectToSlot(hotbar, current_slot, uuid, 1, true)
            sm.container.endTransaction()
        elseif not found and isEmpty then
            sm.container.beginTransaction()
            sm.container.swap(hotbar, current_slot, hotbar, emptySlot)
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

function MMFFM:cl_getItem(params)
    local slot = sm.localPlayer.getSelectedHotbarSlot()
    local hotbar_page = params.hotbar_page
    local container = isSurvival and sm.localPlayer.getInventory() or sm.localPlayer.getHotbar()
    local bool, result = sm.localPlayer.getRaycast(5, sm.localPlayer.getRaycastStart(), sm.localPlayer.getDirection())

    if bool and (result.type == "body") then
        local shape = result:getShape()
        if sm.exists(shape) then
            local args = { hotbar = not isSurvival and container or nil, inventory = isSurvival and container or nil, slot = slot, uuid = shape.uuid, hotbar_page = not isSurvival and hotbar_page or nil }
            self.network:sendToServer("sv_changeItem", args)
            sm.particle.createParticle("p_tool_multiknife_refine_hit_metal", result.pointWorld + (result.normalWorld * 0.05))
        end
    elseif bool and (result.type == "joint") then
        local joint = result:getJoint()
        if sm.exists(joint) then
            local args = { hotbar = not isSurvival and container or nil, inventory = isSurvival and container or nil, slot = slot, uuid = joint.uuid, hotbar_page = not isSurvival and hotbar_page or nil }
            self.network:sendToServer("sv_changeItem", args)
            sm.particle.createParticle("p_barrier_impact", result.pointWorld + (result.normalWorld * 0.05))
        end
    end
end

function MMFFM:sv_tunnel(params)
    if params.hotbar_page ~= nil then
        defaultHotbarPage = params.hotbar_page
    end
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
                sm.event.sendToTool(MMFFM.tool, "sv_tunnel", { player = params.player, hotbar_page = (params[2] or defaultHotbarPage) })
                return
            end
        end
        oldWorldEvent(world, callback, params)
    end
    sm.event.sendToWorld = worldEventHook
    commandsBind = true
end