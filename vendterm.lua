local spritesheet = require 'spritesheet'
local ecs = require 'ecs/ecs'
local buff = require 'mech/buff'
local vend = require 'mech/vend'

local player

local term      -- Current terminal entity
local lastDownI -- Is key <I> pressed last frame
local lastDownU -- Is key <U> pressed last frame
local lastDownLa, lastDownRa
local lastDownUa, lastDownDa
local T         -- Total time

local selRow, selCol = 0, 0 -- Persist

local inCardsPanel
local cardNames
local total
local selIndex = 0  -- Persists

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
    player = ecs.components.player[1].player

    term = _term
    lastDownI = nil
    lastDownU = nil
    lastDownLa, lastDownRa = nil, nil
    lastDownUa, lastDownDa = nil, nil
    T = 0
    inCardsPanel = false

    refreshCards()
    isMenu, menuItem = false, 0
end

local mainUpdate = function ()
    local downI = love.keyboard.isDown('i')
    if downI and lastDownI == false then
        -- Exit
        return false
    end
    lastDownI = downI

    local downU = love.keyboard.isDown('u')
    if downU and lastDownU == false then
        local selIndex = selRow * 2 + selCol
        if selIndex == 0 then
            local price = vend.heal
            if player.coin >= price and player.health < player.healthMax then
                player.coin = player.coin - price
                player.health = player.health + 1
            end
        elseif selIndex == 1 then
            local price = vend.healthMax(player.healthMax)
            if player.coin >= price then
                player.coin = player.coin - price
                player.healthMax = player.healthMax + 1
                player.health = player.health + 1
            end
        elseif selIndex == 2 then
            local price = vend.memory(player.memory)
            if player.coin >= price then
                player.coin = player.coin - price
                player.memory = player.memory + 1
            end
        elseif selIndex == 3 then
            inCardsPanel = true
        end
    end
    lastDownU = downU

    local downL = love.keyboard.isDown('left')
    local downR = love.keyboard.isDown('right')
    local downU = love.keyboard.isDown('up')
    local downD = love.keyboard.isDown('down')
    if downL and lastDownLa == false then selCol = 1 - selCol end
    if downR and lastDownRa == false then selCol = 1 - selCol end
    if downU and lastDownUa == false then selRow = 1 - selRow end
    if downD and lastDownDa == false then selRow = 1 - selRow end
    lastDownLa = downL
    lastDownRa = downR
    lastDownUa = downU
    lastDownDa = downD

    return true
end

local cardsUpdate = function ()
    local downI = love.keyboard.isDown('i')
    if downI and lastDownI == false then
        lastDownI = downI
        if isMenu then isMenu = false else return false end
    end
    lastDownI = downI

    local downU = love.keyboard.isDown('u')

    if isMenu then
        if downU and lastDownU == false then
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
                end
            else
                -- Sell
                player.buff[selName] = nil
                player.coin = player.coin + selCard.sellrate
                refreshCards()
                if selIndex >= total then selIndex = math.max(0, total - 1) end
                isMenu = false
            end
        end

        local downL = love.keyboard.isDown('left')
        local downR = love.keyboard.isDown('right')
        local downU = love.keyboard.isDown('up')    -- Shadowed!
        local downD = love.keyboard.isDown('down')
        if downL and lastDownLa == false then menuItem = 1 - menuItem end
        if downR and lastDownRa == false then menuItem = 1 - menuItem end
        if downU and lastDownUa == false then menuItem = 1 - menuItem end
        if downD and lastDownDa == false then menuItem = 1 - menuItem end
        lastDownLa = downL
        lastDownRa = downR
        lastDownUa = downU
        lastDownDa = downD
    else
        if downU and lastDownU == false and total > 0 then
            isMenu, menuItem = true, 0
        end

        if total ~= 0 then
            selIndex, lastDownLa, lastDownRa, lastDownUa, lastDownDa =
                moveLRUD(total, selIndex, lastDownLa, lastDownRa, lastDownUa, lastDownDa)
        end
    end

    lastDownU = downU

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
        W * (0.15 + 0.35 * selCol), H * (0.2 + 0.35 * selRow),
        W * 0.35, H * 0.35)

    love.graphics.setColor(1, 1, 1)
    spritesheet.text('HEAL', W * 0.2, H * 0.25)
    spritesheet.text('SOLIDIFY', W * 0.55, H * 0.25)
    spritesheet.text('ADD MEM', W * 0.2, H * 0.6)
    spritesheet.text('UPGRADE/SELL\nCARDS', W * 0.55, H * 0.6)

    spritesheet.text(
        string.format('+1 for %d coins', vend.heal),
        W * 0.2, H * 0.35)
    spritesheet.text(
        string.format('%d -> %d for %d coins',
            player.healthMax, player.healthMax + 1, vend.healthMax(player.healthMax)),
        W * 0.55, H * 0.35)
    spritesheet.text(
        string.format('%d -> %d for %d coins',
            player.memory, player.memory + 1, vend.memory(player.memory)),
        W * 0.2, H * 0.7)
end

local cardsDraw = function ()
    love.graphics.setColor(1, 1, 1)

    local selName = cardNames[selIndex + 1]
    local selPlayerBuff = player.buff[selName]
    local selCard = buff[selName]
    local selMem = selCard and selCard.memory[selPlayerBuff.level] or nil

    if isMenu then
        drawOneCard(selCard, W * 0.25, H * 0.4)

        spritesheet.text(
            string.format('%s (Lv. %d)', selName, selPlayerBuff.level),
            W * 0.45, H * 0.25, 1)

        love.graphics.setColor(0.6, 0.7, 0.3, 0.8)
        love.graphics.rectangle('fill',
            W * 0.1, H * (0.6 + menuItem * 0.15),
            W * 0.8, H * 0.15)

        love.graphics.setColor(1, 1, 1)
        spritesheet.text('UPGRADE', W * 0.1 + 4, H * 0.6 + 2)
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
        spritesheet.text(upgradeText, W * 0.1 + 4, H * 0.6 + 17)
        spritesheet.text('SELL', W * 0.1 + 4, H * 0.75 + 2)
        spritesheet.text(
            tonumber(selCard.sellrate) .. ' coins',
            W * 0.1 + 4, H * 0.75 + 17)

    else
        drawCardList(cardNames, player, selIndex, 0.3)

        -- Card description
        if total ~= 0 then
            spritesheet.text(
                string.format('%s (Lv. %d)', selName, selPlayerBuff.level),
                W * 0.15, H * 0.7, 1)
        end
    end

    love.graphics.setColor(1, 1, 1)
    spritesheet.flush()
end

vendTermDraw = function ()
    love.graphics.setColor(0.3, 0.3, 0.3, 0.5)
    love.graphics.rectangle('fill', 0, 0, W, H)

    if inCardsPanel then cardsDraw()
    else mainDraw() end

    love.graphics.setColor(1, 1, 1)
    spritesheet.text(
        string.format('Health: %d/%d  Memory: %d  Coins: %d',
            player.health, player.healthMax, player.memory, player.coin),
        W * 0.1, H * 0.1
    )
    spritesheet.flush()
end
