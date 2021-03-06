local audio = require 'audio'
local ecs = require 'ecs/ecs'

return function () return {

update = function (self, cs)
    for _, e1 in pairs(cs.bullet or {}) do
        if e1.bullet.age then e1.bullet.age = e1.bullet.age + 1 end
        local penetrated = false

        cs.dim:colliding(e1, function (e2)
            if not e2.colli.fence and
                bit.band(e2.colli.tag or 0, e1.bullet.mask) ~= 0
            then
                if e2.health ~= nil then
                    -- Is absorbed?
                    local p = e2.player
                    if p ~= nil and p.colour == e1.bullet.colour then
                        local increment = (
                            (p.colour == 0 and p.buff.rstarve and p.buff.rstarve.equipped) or
                            (p.colour == 1 and p.buff.bstarve and p.buff.bstarve.equipped)
                        ) and 15 or 10
                        p.energy = math.min(p.energy + increment, p.energyMax)
                        audio.play('absorb')
                    else
                        -- Penetrate?
                        if e1.bullet.penetrate then
                            if e1.bullet.penetrate == e2 then return end
                            e1.bullet.penetrate = e2
                            penetrated = true
                        end
                        -- Dodge?
                        if p ~= nil then
                            if e1.bullet.dodged then return end
                            if p.buff.dodge and p.buff.dodge.equipped and math.random() < 0.1 then
                                e1.bullet.dodged = true
                                return
                            end
                        end
                        local damage = (e1.bullet.damage or 1)
                        -- Incise?
                        if e1.bullet.age and e1.bullet.age >= 90 then damage = damage * 1.5 end
                        print(damage)
                        -- Invincible?
                        if not p or p.invincibility == 0 then
                            e2.health.val = e2.health.val - damage
                            if p then
                                p.invincibility = 120   -- One second of invincibility
                                audio.play('playerbeenshot')
                            end
                        end
                        -- Play hit animation
                        if p then
                            if p.fsm.curState <= 2 then
                                p.fsm:trans(
                                    p.fsm.curState == 1 and
                                    (e2.health.val <= 0 and 'akaDeath' or 'akaHit') or
                                    (e2.health.val <= 0 and 'ookamiDeath' or 'ookamiHit'),
                                    true
                                )
                            end
                        elseif e2.enemy then
                            e2.enemy.fsm:trans(e2.health.val <= 0 and 'death' or 'hit', true)
                            if e2.health.val <= 0 then
                                cs.player[1].player.slayed = true
                            end
                        end
                    end
                end

                -- Vanish
                if not penetrated then
                    ecs.markEntityForRemoval(e1)
                end
                return true
            end
        end)
    end
end

} end
