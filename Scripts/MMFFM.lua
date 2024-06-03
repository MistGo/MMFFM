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
    sm.gui.chatMessage("#0098EA[MMFFM]#FFFFFF Use #0098EA/get #FFFFFFto obtain the required block without opening the inventory. You can also switch between hotbar pages by adding page number: /get #0098EA[1/2/3]#FFFFFF")
end

function MMFFM:server_onRefresh()
    MMFFM.tool = self.tool
    isSurvival = sm.game.getLimitedInventory()
end

function MMFFM:sv_changeItem(args)
    local min_slot, current_slot, hotbar, hotbar_page, inventory, uuid = 0, args.slot, args.hotbar, args.hotbar_page, args.inventory, args.uuid

    if hotbar_page == 2 then
        min_slot = 10
        current_slot = current_slot + 10
    elseif hotbar_page == 3 then
        min_slot = 20
        current_slot = current_slot + 20
    end

    if not isSurvival then -- Creative
        local cur_item = hotbar:getItem(current_slot)
        local isFound, isEmpty = false, false
        local emptySlot, emptyUuid = 0, sm.uuid.new("00000000-0000-0000-0000-000000000000")
        
        for slot = min_slot, (hotbar:getSize() - 1) do
            local items = hotbar:getItem(slot)
            if items and (items.uuid == uuid) then
                sm.container.beginTransaction()
                if isEmpty then sm.container.swap(hotbar, current_slot, hotbar, emptySlot) end
                sm.container.swap(hotbar, slot, hotbar, current_slot)
                sm.container.endTransaction()
                isFound = true
                break
            elseif items and not isEmpty and (items.uuid == emptyUuid) and (cur_item.uuid ~= emptyUuid) then
                isEmpty = true
                emptySlot = slot
            end
        end
        if not isFound then
            sm.container.beginTransaction()
            if isEmpty then 
                sm.container.swap(hotbar, current_slot, hotbar, emptySlot)
            else 
                sm.container.spendFromSlot(hotbar, current_slot, cur_item.uuid, cur_item.quantity, true) 
            end
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
    local bool, result = sm.localPlayer.getRaycast(6, sm.localPlayer.getRaycastStart(), sm.localPlayer.getDirection())

    local uuid = sm.uuid.new("00000000-0000-0000-0000-000000000000")
    local particle_effect = nil

    if bool then
        local item = result:getShape() or result:getJoint()
        if sm.exists(item) then
            uuid = item.uuid
            particle_effect = (result.type == "body") and "p_tool_multiknife_refine_hit_metal" or "p_barrier_impact"
        end
    
        if particle_effect then
            sm.particle.createParticle(particle_effect, result.pointWorld + (result.normalWorld * 0.03))
        end

        local args = {
            hotbar = not isSurvival and container or nil,
            inventory = isSurvival and container or nil,
            slot = slot,
            uuid = uuid,
            hotbar_page = not isSurvival and hotbar_page or nil
        }
        self.network:sendToServer("sv_changeItem", args)
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
            oldBindCommand("/get", { { "int", "hotbar_page", true } }, "cl_onChatCommand", "Use that command to obtain the required block without opening the inventory. You can also switch between hotbar pages by adding page number: /get #0098EA[1/2/3]#FFFFFF")
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