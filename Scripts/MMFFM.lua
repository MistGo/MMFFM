--[[
	Copyright (c) 2024
	MistGo
]]

MMFFM = class()

function MMFFM:server_onCreate()
    MMFFM.tool = self.tool
end

function MMFFM:server_onRefresh()
    self:server_onCreate()
end

function MMFFM:sv_changeItem(params)
    local min_slot, current_slot, uuid = 0, params.slot, params.uuid
    local hotbar, hotbar_page = params.hotbar, params.hotbar_page
    local inventory, gamemode = params.inventory, params.gamemode

    min_slot = (hotbar_page - 1) * 10
    current_slot = current_slot + min_slot

    if not gamemode then -- Creative
        local cur_item = hotbar:getItem(current_slot)
        local isFound, isEmpty = false, false
        local emptySlot, emptyUuid = 0, sm.uuid.getNil()
        
        for slot = min_slot, (hotbar:getSize() - 1) do
            local items = hotbar:getItem(slot)

            if items and (items.uuid == uuid) then
                sm.container.beginTransaction()
                if isEmpty then 
                    sm.container.swap(hotbar, current_slot, hotbar, emptySlot) 
                end
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

function MMFFM:client_onCreate()
    self.cl = {
        hotbarPage = 1,
        isSurvival = sm.game.getLimitedInventory()
    }

    sm.gui.chatMessage("#0098EA[MMFFM]#FFFFFF Use #0098EA/get #FFFFFFto obtain the required block without opening the inventory. You can also switch between hotbar pages by adding page number: /get #0098EA[1/2/3]#FFFFFF")
end

function MMFFM:client_onRefresh()
    self:client_onCreate()
end

function MMFFM:client_onFixedUpdate()
    if self.cl.isSurvival ~= sm.game.getLimitedInventory() then
        print("[MMFFM] Changed gamemode for: ".. sm.localPlayer.getPlayer().name)
        self.cl.isSurvival = sm.game.getLimitedInventory()
    end
end

function MMFFM:cl_getItem(hotbarPage)
    local slot = sm.localPlayer.getSelectedHotbarSlot()
    local container = self.cl.isSurvival and sm.localPlayer.getInventory() or sm.localPlayer.getHotbar()
    local hit, hitRes = sm.localPlayer.getRaycast(5)
    local hotbar_page = hotbarPage or self.cl.hotbarPage

    local uuid = sm.uuid.getNil()
    local particle_effect = nil

    if hit then
        local item = hitRes:getShape() or hitRes:getJoint()

        if sm.exists(item) then
            uuid = item.uuid
            particle_effect = (hitRes.type == "body") and "p_tool_multiknife_refine_hit_metal" or "p_barrier_impact"
        end
    
        if particle_effect then
            sm.particle.createParticle(particle_effect, hitRes.pointWorld + (hitRes.normalWorld * 0.03))
        end
        
        local params = {
            hotbar = not self.cl.isSurvival and container or nil,
            inventory = self.cl.isSurvival and container or nil,
            slot = slot,
            uuid = uuid,
            hotbar_page = not self.cl.isSurvival and hotbar_page or 1,
            gamemode = self.cl.isSurvival
        }
        self.network:sendToServer("sv_changeItem", params)
        self.cl.hotbarPage = hotbarPage or self.cl.hotbarPage
    end
end

function MMFFM:sv_tunnel(params)
    self.network:sendToClient(params.player, "cl_getItem", params.hotbar_page)
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
                sm.event.sendToTool(MMFFM.tool, "sv_tunnel", {player = params.player, hotbar_page = params[2]})
                return
            end
        end
        oldWorldEvent(world, callback, params)
    end
    sm.event.sendToWorld = worldEventHook
    commandsBind = true
end