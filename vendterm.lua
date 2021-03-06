local spritesheet = require 'spritesheet'
local audio = require 'audio'
local input = require 'input'
local ecs = require 'ecs/ecs'
local buff = require 'mech/buff'
local vend = require 'mech/vend'

local player, playerEntity

local term      -- Current terminal entity
local lastDownY
local lastDownX
local lastDownL, lastDownR
local lastDownU, lastDownD
local T         -- Total time

local selRow, selCol = 0, 0 -- Persist

local inCardsPanel
local cardNames
local total
local selIndex = 0  -- Persists
local memUsed = 0

local isMenu, menuItem  -- Is in sell/upgrade menu

local refreshCards = function ()
    cardNames = {}
    total = 0
    for k, v in pairs(player.buff) do
        if not v.equipped then
            total = total + 1
            cardNames[total] = k
        end
    end
end

vendTermReset = function (_term)
    playerEntity = ecs.components.player[1]
    player = playerEntity.player

    term = _term
    lastDownY = nil
    lastDownX = nil
    lastDownL, lastDownR = nil, nil
    lastDownU, lastDownD = nil, nil
    T = 0
    inCardsPanel = false

    memUsed = 0
    for k, v in pairs(player.buff) do
        if v.equipped then
            memUsed = memUsed + buff[k].memory[v.level]
        end
    end

    refreshCards()
    isMenu, menuItem = false, 0
end

local mainUpdate = function ()
    local downY = input.Y()
    if downY and lastDownY == false then
        -- Exit
        return false
    end
    lastDownY = downY

    local downX = input.X()
    if downX and lastDownX == false then
        local selIndex = selRow * 2 + selCol
        if selIndex == 0 then
            local price = vend.heal
            if player.coin >= price and playerEntity.health.val < playerEntity.health.max then
                player.coin = player.coin - price
                playerEntity.health.val = playerEntity.health.val + 1
                audio.play('confirm')
            end
        elseif selIndex == 1 then
            local price = vend.healthMax(playerEntity.health.max)
            if player.coin >= price then
                player.coin = player.coin - price
                playerEntity.health.max = playerEntity.health.max + 1
                playerEntity.health.val = playerEntity.health.val + 1
                audio.play('confirm')
            end
        elseif selIndex == 2 then
            local price = vend.memory(player.memory)
            if player.coin >= price then
                player.coin = player.coin - price
                player.memory = player.memory + 1
                audio.play('confirm')
            end
        elseif selIndex == 3 then
            inCardsPanel = true
            audio.play('menu')
        end
    end
    lastDownX = downX

    local downL = input.L()
    local downR = input.R()
    local downU = input.U()
    local downD = input.D()
    if downL and lastDownL == false then selCol = 1 - selCol end
    if downR and lastDownR == false then selCol = 1 - selCol end
    if downU and lastDownU == false then selRow = 1 - selRow end
    if downD and lastDownD == false then selRow = 1 - selRow end
    lastDownL = downL
    lastDownR = downR
    lastDownU = downU
    lastDownD = downD

    return true
end

local cardsUpdate = function ()
    local downY = input.Y()
    if downY and lastDownY == false then
        lastDownY = downY
        if isMenu then isMenu = false else return false end
    end
    lastDownY = downY

    local downX = input.X()

    if isMenu then
        if downX and lastDownX == false then
            local selName = cardNames[selIndex + 1]
            local selPlayerBuff = player.buff[selName]
            local selCard = buff[selName]
            local selMem = selCard.memory[selPlayerBuff.level]
            if menuItem == 0 then
                -- Upgrade
                if selPlayerBuff.level < #selCard.args and
                    player.coin >= selCard.upgrade[selPlayerBuff.level]
                then
                    player.coin = player.coin - selCard.upgrade[selPlayerBuff.level]
                    selPlayerBuff.level = selPlayerBuff.level + 1
                    audio.play('confirm')
                end
            else
                -- Sell
                player.buff[selName] = nil
                player.coin = player.coin + selCard.sellrate
                refreshCards()
                if selIndex >= total then selIndex = math.max(0, total - 1) end
                audio.play('confirm')
                isMenu = false
            end
        end

        local downL = input.L()
        local downR = input.R()
        local downU = input.U()
        local downD = input.D()
        if downL and lastDownL == false then menuItem = 1 - menuItem end
        if downR and lastDownR == false then menuItem = 1 - menuItem end
        if downU and lastDownU == false then menuItem = 1 - menuItem end
        if downD and lastDownD == false then menuItem = 1 - menuItem end
        lastDownL = downL
        lastDownR = downR
        lastDownU = downU
        lastDownD = downD
    else
        if downX and lastDownX == false and total > 0 then
            isMenu, menuItem = true, 0
            audio.play('menu')
        end

        if total ~= 0 then
            selIndex, lastDownL, lastDownR, lastDownU, lastDownD =
                moveLRUD(total, selIndex, lastDownL, lastDownR, lastDownU, lastDownD)
        end
    end

    lastDownX = downX

    return true
end

vendTermUpdate = function ()
    T = T + love.timer.getDelta()

    if inCardsPanel then inCardsPanel = cardsUpdate() return true
    else return mainUpdate() end
end

local mainDraw = function ()
    love.graphics.setColor(0.6, 0.7, 0.3, 0.8)
    love.graphics.rectangle('fill',
        W * (0.15 + 0.35 * selCol), H * (0.2 + 0.3 * selRow),
        W * 0.35, H * 0.3)

    spritesheet.drawCen('heart', W * 0.325, H * 0.35)
    spritesheet.drawCen('heart_empty', W * 0.675, H * 0.35)
    spritesheet.drawCen('memory2', W * 0.325, H * 0.65)
    spritesheet.drawCen('floppy', W * 0.675, H * 0.675)
    spritesheet.text('HEAL', W * 0.2, H * 0.225)
    spritesheet.text('GROW', W * 0.55, H * 0.225)
    spritesheet.text('EXTEND', W * 0.2, H * 0.525)
    spritesheet.text('UPGRADE/SELL', W * 0.55, H * 0.525)

    spritesheet.text(
        string.format('%d coins', vend.heal),
        W * 0.2, H * 0.4)
    spritesheet.text(
        string.format('%d coins',
            vend.healthMax(playerEntity.health.max)),
        W * 0.55, H * 0.4)
    spritesheet.text(
        string.format('%d coins',
            vend.memory(player.memory)),
        W * 0.2, H * 0.7)
end

local cardsDraw = function ()
    love.graphics.setColor(1, 1, 1)

    local selName = cardNames[selIndex + 1]
    local selPlayerBuff = player.buff[selName]
    local selCard = buff[selName]
    local selMem = selCard and selCard.memory[selPlayerBuff.level] or nil

    if isMenu then
        drawOneCard(selCard, W * 0.25, H * 0.35)

        spritesheet.text(
            string.format('%s (Lv. %d)', selCard.name, selPlayerBuff.level),
            W * 0.45, H * 0.2)
        spritesheet.text(selCard.desc, W * 0.45, H * 0.275, W * 0.425)
        spritesheet.text('mem: ' .. tostring(selMem), W * 0.45, H * 0.425)

        love.graphics.setColor(0.6, 0.7, 0.3, 0.8)
        love.graphics.rectangle('fill',
            W * 0.1, H * (0.525 + menuItem * 0.15),
            W * 0.8, H * 0.15)

        love.graphics.setColor(1, 1, 1)
        spritesheet.text('UPGRADE', W * 0.1 + 4, H * 0.525 + 2)
        local upgradeText
        if selPlayerBuff.level < #selCard.args then
            upgradeText = string.format('%d coins | val: %d -> %d | mem: %d -> %d',
                selCard.upgrade[selPlayerBuff.level],
                selCard.args[selPlayerBuff.level],
                selCard.args[selPlayerBuff.level + 1],
                selCard.memory[selPlayerBuff.level],
                selCard.memory[selPlayerBuff.level + 1])
        else
            upgradeText = 'Maximum'
        end
        spritesheet.text(upgradeText, W * 0.1 + 4, H * 0.525 + 17)
        spritesheet.text('SELL', W * 0.1 + 4, H * 0.675 + 2)
        spritesheet.text(
            tonumber(selCard.sellrate) .. ' coins',
            W * 0.1 + 4, H * 0.675 + 17)

    else
        drawCardList(cardNames, player, selIndex, 0.25)

        -- Card description
        if total ~= 0 then
            spritesheet.text(
                string.format('%s (Lv. %d)', selCard.name, selPlayerBuff.level),
                W * 0.15, H * 0.585)
            spritesheet.text(selCard.desc, W * 0.15, H * 0.65, W * 0.7)
        end
    end
end

vendTermDraw = function ()
    love.graphics.setColor(0.3, 0.3, 0.3, 0.5)
    love.graphics.rectangle('fill', 0, 0, W, H)

    if inCardsPanel then cardsDraw()
    else mainDraw() end

    love.graphics.setColor(1, 1, 1)
    spritesheet.text(
        string.format('Coins: %d', player.coin),
        W * 0.8, H * 0.1
    )
    -- HUD
    for i = 1, playerEntity.health.max do
        spritesheet.draw(
            i <= playerEntity.health.val and 'heart' or 'heart_empty',
            i * 20 - 10, 8)
    end
    for i = 1, player.memory do
        local num = (i <= memUsed and 1 or 2)
        spritesheet.draw(
            'memory' .. tostring(num),
            i * 15 - 5, 27
        )
    end

    spritesheet.draw('gamepad4', W * 0.7, H * 0.82)
    spritesheet.text('Select', W * 0.7 + 20, H * 0.82)
    spritesheet.draw('gamepad1', W * 0.7, H * 0.9)
    spritesheet.text('Back', W * 0.7 + 20, H * 0.9)

    spritesheet.flush()
end
