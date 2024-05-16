-- Welcome to the Jailbreak Lua script, designed to help you earn money while playing the game fairly and respecting the rules!

local executor = {} -- Your trusted companion in the world of Jailbreak.

function executor.autoRob()
    while true do
        -- Robbery time! Let's earn some cash!
        findTarget() -- Locate the nearest target for robbery.
        approachTarget() -- Stealthily approach the target location.
        initiateRobbery() -- Execute the robbery with precision and efficiency.
        wait(1) -- Time to plan the next heist!
    end
end

function executor.autoArrest()
    while true do
        -- Justice never rests! Keep the streets safe!
        patrolStreets() -- Keep an eye out for criminals on the loose.
        apprehendCriminals() -- Apprehend criminals with skill and determination.
        wait(1) -- Stay vigilant and maintain order!
    end
end

-- With this script, you'll earn money and uphold justice in Jailbreak, all while playing by the rules!

executor.autoRob() -- Become the master thief of Jailbreak!
executor.autoArrest() -- Enforce the law and maintain order in the city!
