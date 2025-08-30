function love.load()
    Timer = require "libraries/timer"
    anim8 = require "libraries/anim8"
    camera = require "libraries/camera"
    lume = require "libraries/lume"
    local sti = require 'libraries/sti'
    cam = camera()
    gameMap = sti('maps/testMap.lua')
    background = love.graphics.newImage("maps/cave_background2.jpg")
    arcadeFont = love.graphics.newFont("joystix monospace.otf", 16)
    arcadeFontSmall = love.graphics.newFont("joystix monospace.otf", 12)
    arcadeFontBig = love.graphics.newFont("joystix monospace.otf", 32)
    love.graphics.setFont(arcadeFont)
    wf = require "libraries/windfield"
    world = wf.newWorld(0, 10000)
    
    --audio from zapslat.com
    menu_sfx = love.audio.newSource("audio/menu.mp3", "static")
    select_sfx = love.audio.newSource("audio/select.mp3", "static")
    nomoney_sfx = love.audio.newSource("audio/nomoney.mp3", "static")
    levelup_sfx = love.audio.newSource("audio/levelup.mp3", "static")
    hit_sfx = love.audio.newSource("audio/hit.mp3", "static")
    jump_sfx = love.audio.newSource("audio/jump.mp3", "static")
    thud_sfx = love.audio.newSource("audio/thud.mp3", "static")
    gameover_sfx = love.audio.newSource("audio/gameover.mp3", "static")
    coin_sfx = love.audio.newSource("audio/coin.wav", "static")
    run_sfx = love.audio.newSource("audio/run2.mp3", "static")
    save_sfx = love.audio.newSource("audio/save.mp3", "static")
    bought_sfx = love.audio.newSource("audio/bought.mp3", "static")
    slimeDeath_sfx = love.audio.newSource("audio/slimeDeath.mp3", "static")


    --bgm from Kevin MacLeod
    bgm = love.audio.newSource("audio/bgm.mp3", "stream")

    --settings for hp bars
    hp = {}
    hp.width = 70
    hp.height = 10

    love.graphics.setDefaultFilter("nearest", "nearest")
    player = {}
    player.level = 1
    player.x = 350
    player.y = 500
    player.speed = 300
    player.maxHealth = 90 + player.level*10
    player.strength = 10
    player.currentHealth = player.maxHealth
    player.currentXp = 0
    player.maxXp = 80
    player.armor = 0

    player.spritesheetRun = love.graphics.newImage("sprites/_Run.png")
    player.gridRun = anim8.newGrid(120, 80, player.spritesheetRun:getWidth(), player.spritesheetRun:getHeight())

    player.spritesheetIdle = love.graphics.newImage("sprites/_Idle.png")
    player.gridIdle = anim8.newGrid(120, 80, player.spritesheetIdle:getWidth(), player.spritesheetIdle:getHeight())

    player.spritesheetJump = love.graphics.newImage("sprites/_Jump.png")
    player.gridJump = anim8.newGrid(120, 80, player.spritesheetJump:getWidth(), player.spritesheetJump:getHeight())

    player.spritesheetAttack1 = love.graphics.newImage("sprites/_Attack.png")
    player.gridAttack1 = anim8.newGrid(120, 80, player.spritesheetAttack1:getWidth(), player.spritesheetAttack1:getHeight())

    player.spritesheetAttack2 = love.graphics.newImage("sprites/_Attack2.png")
    player.gridAttack2 = anim8.newGrid(120, 80, player.spritesheetAttack2:getWidth(), player.spritesheetAttack2:getHeight())

    player.spritesheetDeath = love.graphics.newImage("sprites/_Death.png")
    player.gridDeath = anim8.newGrid(120, 80, player.spritesheetDeath:getWidth(), player.spritesheetDeath:getHeight())

    player.animations = {}
    player.animations.idleRight = anim8.newAnimation(player.gridIdle("1-10", 1), 0.2)
    player.animations.idleLeft = player.animations.idleRight:clone():flipH()

    player.animations.runRight = anim8.newAnimation(player.gridRun("1-10", 1), 0.075)
    player.animations.runLeft = player.animations.runRight:clone():flipH()

    player.animations.jumpRight = anim8.newAnimation(player.gridJump("1-3", 1), 0.2)
    player.animations.jumpLeft = player.animations.jumpRight:clone():flipH()

    player.animations.attack1Right = anim8.newAnimation(player.gridAttack1("1-4", 1), 0.05)
    player.animations.attack1Left = player.animations.attack1Right:clone():flipH()

    player.animations.attack2Right = anim8.newAnimation(player.gridAttack2("1-6", 1), 0.05)
    player.animations.attack2Left = player.animations.attack2Right:clone():flipH()

    player.animations.deathRight = anim8.newAnimation(player.gridDeath("1-10", 1), 0.2, 'pauseAtEnd')
    player.animations.deathLeft = player.animations.deathRight:clone():flipH()

    
    coinCounter = 50
    

    player.anim = player.animations.runRight
    player.inAir = false                                
    player.direction = "right"
    player.attacking = false
    player.attackTimer = 1
    hitLockTimer = 10
    player.hitLockOutTimer = hitLockTimer
    player.invincFrame = false

    isPlayerDead = false
    --transition back to title screen once dead and wipe save
    function deathTransition()
        gameover_sfx:play()
        love.filesystem.remove("savedata.txt")
        gameOverMessage = {color = {1,0,0,1}, y = 0}
        Timer.tween(2, gameOverMessage, {y = 30}, 'bounce')

        fadeToBlack = {color = {0.2,0.2,0.2,0}}
        Timer.tween(4, fadeToBlack, {color = {0,0,0,1}}, 'linear', function()
            love.event.quit("restart")
        end)
    end
        
     --Add collision classes, including for attack to register on mob
    world:addCollisionClass('Solid')
    world:addCollisionClass('Player')
    world:addCollisionClass('Mob', {ignores = {'Player', 'Mob'}})
    world:addCollisionClass('DeadMob', {ignores = {'Player', 'Mob', 'DeadMob'}})
    world:addCollisionClass('Coin', {ignores = {'Mob', 'DeadMob', 'Coin', 'Player'}})

    

    -- boolean to spawn additional mobs based on level threshold
    levelupspawn1 = false
    levelupspawn2 = false
    levelupspawn3 = false

    --inital values to control attack animation combo based on how fast the second press is 
    comboAttack = false
    comboAttackTimer = 1

    coins = {}
    
    function spawnCoin(x, y)
        coin = {}
        coin.spritesheetCoinSpin = love.graphics.newImage("sprites/GoldCoinSpinning.png")
        coin.gridCoinSpin = anim8.newGrid(192/24, 8, coin.spritesheetCoinSpin:getWidth(), coin.spritesheetCoinSpin:getHeight())
        coin.spinAnimation = anim8.newAnimation(coin.gridCoinSpin("1-24", 1), 0.05)
        coin.x = x
        coin.y = y
        coin.collider = world:newCircleCollider(coin.x, coin.y, 5)
        coin.collider:setFixedRotation(true)
        coin.collider:setCollisionClass('Coin')
        coin.collider:setObject(self)
        coin.bounce = {y = 0, color = {255, 255, 255, 1}}
        table.insert(coins, coin)
    end 
    -- import ground from tiled
    walls = {}
    if gameMap.layers["Walls"] then
        
        for i, object in pairs(gameMap.layers["Walls"].objects) do
            local wall = world:newRectangleCollider(object.x, object.y, object.width, object.height)
            wall:setType("static")
            wall:setCollisionClass('Solid')
            table.insert(walls, wall)
        end
    end
    spritesheetSlimeIdle = love.graphics.newImage("sprites/slimeIdle.png")
    gridSlimeIdle = anim8.newGrid(96, 32, spritesheetSlimeIdle:getWidth(), spritesheetSlimeIdle:getHeight())
    spritesheetSlimeHurt = love.graphics.newImage("sprites/slimeHurt.png")
    gridSlimeHurt = anim8.newGrid(96, 32, spritesheetSlimeHurt:getWidth(), spritesheetSlimeHurt:getHeight())
    spritesheetSlimeDeath = love.graphics.newImage("sprites/slimeDeath.png")
    gridSlimeDeath = anim8.newGrid(96, 32, spritesheetSlimeDeath:getWidth(), spritesheetSlimeDeath:getHeight())
    slimeIdle = anim8.newAnimation(gridSlimeIdle("1-7", 1), 0.1)
    slimeHurt = anim8.newAnimation(gridSlimeHurt("1-11", 1), 0.1)
    slimeDeath = anim8.newAnimation(gridSlimeDeath("1-14", 1), 0.1, 'pauseAtEnd')
    mobs = {}

    function createMob(mobColor)
        mob = {}
        mob.spritesheetSlimeIdle = spritesheetSlimeIdle
        mob.gridSlimeIdle = gridSlimeIdle
        mob.spritesheetSlimeHurt = spritesheetSlimeHurt
        mob.gridSlimeHurt = gridSlimeHurt
        mob.spritesheetSlimeDeath = spritesheetSlimeDeath
        mob.gridSlimeDeath = gridSlimeDeath
        mob.animations = {}
        mob.animations.slimeIdle = anim8.newAnimation(mob.gridSlimeIdle("1-7", 1), 0.1)
        mob.animations.slimeHurt = anim8.newAnimation(mob.gridSlimeHurt("1-11", 1), 0.1)
        mob.animations.slimeDeath = anim8.newAnimation(mob.gridSlimeDeath("1-14", 1), 0.1, 'pauseAtEnd')
        mob.anim = mob.animations.slimeIdle
        mob.height = mob.spritesheetSlimeIdle:getHeight()
        mob.width = mob.spritesheetSlimeIdle:getWidth()/14
        mob.x = love.math.random(400, 3000)
        mob.y = 500
        mob.collider = world:newBSGRectangleCollider(mob.x, mob.y, mob.width, mob.height -5, 6)
        mob.collider:setFixedRotation(true)
        mob.collider:setCollisionClass('Mob')
        mob.damaged = false
        mob.maxHealth = 50
        mob.currentHealth = mob.maxHealth
        mob.speed = love.math.random(50, 100)
        mob.vx = 0
        mob.vy = 0
        mob.strength = 20
        mob.xp = 60
        mob.dmgTable = {}
        mob.color = mobColor
        -- modify stats according to color of mob
        if mob.color == "red" then
            mob.maxHealth = mob.maxHealth * 2
            mob.currentHealth = mob.maxHealth
            mob.speed = love.math.random(100, 200)
            mob.strength = mob.strength * 1.5
            mob.xp = mob.xp * 2
        elseif mob.color == "blue" then 
            mob.maxHealth = mob.maxHealth * 4
            mob.currentHealth = mob.maxHealth
            mob.speed = love.math.random(1, 50)
            mob.strength = mob.strength * 3
            mob.xp = mob.xp * 5
        end
        table.insert(mobs, mob)
    end

    -- initial mob spawns
    maxMobs = 10
    for i = 1, maxMobs do
        createMob("green")
    end

    --TIMER functions
    function spawnTimer()
        count = maxMobs - #mobs
        color = "green"
        redChance = 5
        blueChance = 1
        colorRoll = love.math.random(1, 100)
        if colorRoll <= redChance then
            color = "red"
        elseif colorRoll <= redChance + blueChance then
            color = "blue"
        end
        handle = Timer.every(8, createMob(color), count)
        Timer.cancel(handle)
    end

    function levelAnimation()
        -- circle
        levelCircle = {rad = 1, pos = {x = 0, y = 0}, color = {255, 255, 0, 1}} --origin will be changed to player pos
        Timer.tween(0.5, levelCircle, {rad = 900}, 'expo')
        Timer.tween(1, levelCircle, {color = {255, 255, 0, 0}})
        -- level up text
        text = {y = 0, opacity = {0, 255, 0, 1}}
        Timer.tween(1, text, {y = 100}, 'bounce')
        Timer.tween(1, text, {opacity = {255, 255, 0, 0}})
    end

        -- player gains e experience points
    function giveXp(e)
        player.currentXp = player.currentXp + e
        --level up
        if player.currentXp >= player.maxXp then
            leveledUp = true
            player.level = player.level + 1
            player.currentXp = player.currentXp - player.maxXp
            player.maxXp = math.floor(player.maxXp*1.2 + 0.5)
            --level up animation
            levelAnimation()
            levelup_sfx:play()
        end
    end

    -- attack calculations and mob interaction
    function attackReg()
        -- query the hitbox of our attack animation to scan for any mobs
        if player.direction == "right" then
            mobsAttacked = world:queryRectangleArea(player.x, player.y, 85, 60, {'Mob'})
        elseif player.direction == "left" then
            mobsAttacked = world:queryRectangleArea(player.x - 80, player.y, 85, 60, {'Mob'})
        end     
        -- problem is we cant remove from mobs table based on a table reference. need a way to identify index of that mob 
        for i, v in pairs(mobsAttacked) do
            for j, k in pairs(mobs) do
                -- Knockback and dmg calculation
                if mobs[j].collider == mobsAttacked[i] then                
                    if player.direction == "right" then
                        mobs[j].collider:applyLinearImpulse(8000, -2000)
                    elseif player.direction == "left" then
                        mobs[j].collider:applyLinearImpulse(-8000, -2000)
                    end
                    thud_sfx:play()
                    -- damage calculation
                    minDamage = player.strength * 1
                    maxDamage = player.strength * 2
                    damage = love.math.random(minDamage, maxDamage)
                    mobs[j].currentHealth = mobs[j].currentHealth - damage
                    mobs[j].damaged = true
                    mobs[j].anim = mobs[j].animations.slimeHurt
                    --transition from white, opaque number to rising, fading number
                    --insert to individual mob's dmgTable to keep track of all the damage that need to be displayed
                    dmg = damage
                    dmgNumbers = {y = 0, color = {255, 255, 255, 1}}
                    dmgNumberMaxHeight = Timer.tween(0.5, dmgNumbers, {y=150})
                    dmgNumberTransparent = Timer.tween(0.5, dmgNumbers, {color = {255, 255, 255, 0}}, 'expo')
                    singleDmgTable = {dmgNumbers, dmgNumberMaxHeight, dmgNumberTransparent, dmg}
                    table.insert(mobs[j].dmgTable, singleDmgTable)
                    
                    -- if mob dies then
                    if mobs[j].currentHealth <= 0 then
                        slimeDeath_sfx:seek(0)
                        slimeDeath_sfx:play()
                        mobs[j].currentHealth = 0
                        giveXp(mobs[j].xp * upgradeXp[xpLevel].rate)
                        mobs[j].anim = mobs[j].animations.slimeDeath
                        
                        --base chance of 50% to drop coin
                        coinDrop = love.math.random(1,10)
                        if coinDrop * upgradeCoin[coinLevel].rate > 5 then
                            spawnCoin(mobs[j].x, mobs[j].y)
                        end
                    end    
                end
            end 
        end
    end
    
    isTitleScreen = true
    screenWidth = love.graphics.getWidth()
    screenHeight = love.graphics.getHeight()
    menuTextColor = {doneness = 0, color = {1, 1, 1, 1}}
    function fadeMenuText()
        Timer.tween(2, menuTextColor, {color = {1, 1, 1, 0}})
        Timer.tween(2, menuTextColor, {doneness = 10})
    end
    -- slime animation in title screen
    titleSlimeX = -200
    fadeMenuText()
    titleTransition = {doneness = 0, color = {1,1,1,1}}
    highlightEnter = false


    isPauseScreen = false
    pauseColor = {0.2, 0.2, 0.2, 1}
    widthMargin = 100
    heightMargin = 100
    --store hardcoded x and y values of pointer for the selection options
    option1 = {x = 250, y = 200}
    option2 = {x = 250, y = 350}
    pauseSelections = {option1, option2}
    selectionIndex = 1
    printSaveMessage = false

    isShopScreen = false
    shopSelectionIndex = 1
    shopTextColor = {0,1,0}
    shopMaxedColor = {0.8, 0.8, 0.8}
    shopOption1 = {x = 160, y = 220, color = shopTextColor}
    shopOption2 = {x = 160, y = 250, color = shopTextColor}
    shopOption3 = {x = 160, y = 280, color = shopTextColor}
    shopOption4 = {x = 160, y = 310, color = shopTextColor}
    shopOption5 = {x = 160, y = 340, color = shopTextColor}
    shopOption6 = {x = 160, y = 370, color = shopTextColor}
    shopSelections = {shopOption1, shopOption2, shopOption3, shopOption4, shopOption5, shopOption6}
    
    function checkMoney(c, shopCost)
        if c >= shopCost then
            coinCounter = coinCounter - shopCost
            return true
        else
            return false
        end

    end
    notEnoughMoney = false

    errorText = {y = 0, color = {1, 0, 0, 1}}

    function printNotEnoughMoney()    
        Timer.tween(1, errorText, {y = 20}, 'out-elastic')
        Timer.after(1, 
        function()
            Timer.tween(1, errorText, {color = {1,0,0,0}})
        end)
    end

    function errorMessage()
        if errorText.y > 19.99 then
            errorText = {y = 0, color = {1, 0, 0, 1}}
        end
        notEnoughMoney = true
        printNotEnoughMoney()
        nomoney_sfx:play()
    end

    maxHealthLevel = 1
    upgradeMaxHealth = {
        {level = 1, increase = 0, price = 5},
        {level = 2, increase = 50, price = 15},
        {level = 3, increase = 90, price = 40},
        {level = 4, increase = 140, price = 70},
        {level = 5, increase = 200, price = 0}
    }
    armorLevel = 1
    upgradeArmor = {
        {level = 1, increase = 0, price = 5},
        {level = 2, increase = 5, price = 15},
        {level = 3, increase = 5, price = 40},
        {level = 4, increase = 5, price = 70},
        {level = 5, increase = 5, price = 0}
    }
    -- in shop, the level of attribute is current level. When price is paid at that level, the increase is shown at next level.
    --Ex: i am level 1 strength. i pay 5 coins to bring strength to level 2. In return, I get an increase of 10 in player.strength.
    strengthLevel = 1
    upgradeStrength = {
        {level = 1, increase = 0, price = 5},
        {level = 2, increase = 10, price = 15},
        {level = 3, increase = 20, price = 40},
        {level = 4, increase = 40, price = 70},
        {level = 5, increase = 60, price = 0}
    }
    xpLevel = 1
    upgradeXp = {
        {level = 1, rate = 1, price = 5},
        {level = 2, rate = 1.25, price = 10},
        {level = 3, rate = 1.5, price = 20},
        {level = 4, rate = 1.75, price = 40},
        {level = 5, rate = 2, price = 0}
    }
    coinLevel = 1
    upgradeCoin = {
        {level = 1, rate = 1, price = 5},
        {level = 2, rate = 1.5, price = 15},
        {level = 3, rate = 2, price = 30},
        {level = 4, rate = 2.5, price = 60},
        {level = 5, rate = 3, price = 0}
    }
    maxMobsLevel = 1
    upgradeMaxMobs = {
        {level = 1, increase = 0, price = 10},
        {level = 2, increase = 5, price = 20},
        {level = 3, increase = 5, price = 30},
        {level = 4, increase = 5, price = 40},
        {level = 5, increase = 5, price = 0}
    }

    

    saveExists = false
    -- check if save file exists
    if love.filesystem.getInfo("savedata.txt") then
        saveExists = true
        file = love.filesystem.read("savedata.txt")
        data = lume.deserialize(file)
        -- apply save data
        player.x = data.x
        player.y = data.y
        player.level = data.level
        player.currentXp = data.currentXp
        player.maxXp = data.maxXp
        coinCounter = data.coins
        player.strength = data.strength
        player.armor = data.armor
        player.maxHealth = data.maxHp
        player.currentHealth = data.currentHp
        xpLevel = data.xpLevel
        coinLevel = data.coinLevel
        strengthLevel = data.strengthLevel
        maxHealthLevel = data.maxHealthLevel
        maxMobsLevel = data.maxMobsLevel
        armorLevel = data.armorLevel
        maxMobs = data.maxMobs
    end
    --update shop text color to match maxed leveled attributes with save file
    attributesLevelTable = {maxHealthLevel, armorLevel, strengthLevel, xpLevel, coinLevel, maxMobsLevel}
    for i = 1, #attributesLevelTable do
        if attributesLevelTable[i] == 5 then
            shopSelections[i].color = shopMaxedColor
        end
    end

    -- make collision for the player
    player.collider = world:newBSGRectangleCollider(player.x, player.y, 20, 60, 6) --newBSGRectangleCollider(x, y, w, h, corner_cut_size)
    player.collider:setFixedRotation(true)
    player.collider:setCollisionClass('Player')
    love.filesystem.remove("savedata.txt")

    love.audio.setVolume(0.3)
    bgm:setVolume(0.5)

    
end



function love.update(dt)

    -- Controls all title screen interactions
    if isTitleScreen == true then
        slimeIdle:update(dt)
        Timer.update(dt)
        --make slime animation move right and left
        titleSlimeX = titleSlimeX + 100*dt
        if titleSlimeX > screenWidth then
            titleSlimeX = -200
        end
        --loops the menu text fade
        if highlightEnter == false then
            if menuTextColor.doneness > 9.999 then
                menuTextColor.color = {1, 1, 1, 1}
                menuTextColor.doneness = 0
                fadeMenuText()
            end
        end

        function love.keypressed(key)
            if key == "return" then
                Timer.tween(3, titleTransition, {color = {1, 1, 1, 0}})
                Timer.tween(3, titleTransition, {doneness = 10})
                menuTextColor.color = {1, 1, 0, 1}
                highlightEnter = true
                select_sfx:play()
            end
        end
        -- once the title screen transition is done, move on to level gamestate
        if titleTransition.doneness > 9.999 then
            isTitleScreen = false
        end
        -- skips the rest of love.update if we're still on title screen
        return
    end

    if isPauseScreen == true then
        Timer.update(dt)
        bgm:pause()
        function love.keypressed(key)
            if key == "escape" then
                menu_sfx:play()
                isPauseScreen = false
            -- up and down arrows to navigate the pause menu. going too far down brings pointer to the top and viceversa
            elseif key == "down" then
                select_sfx:seek(0)
                select_sfx:play()
                selectionIndex = selectionIndex + 1
                if selectionIndex > #pauseSelections then
                    selectionIndex = 1 
                end
            elseif key == "up" then
                select_sfx:seek(0)
                select_sfx:play()
                selectionIndex = selectionIndex - 1
                if selectionIndex == 0 then
                    selectionIndex = #pauseSelections
                end
            elseif key == "return" then
                select_sfx:seek(0)
                select_sfx:play()
                --option 1 is shop button
                if selectionIndex == 1 then
                    isShopScreen = true
                --option 2 is save button
                elseif selectionIndex == 2 then
                    save_sfx:play()
                    saveGame()
                    printSaveMessage = true
                end
            
            end

        end
        if isShopScreen == true then
            

            function love.keypressed(key)
                if key == "escape" then
                    isShopScreen = false
                    menu_sfx:play()
                --navigate shop menu
                elseif key == "down" then
                    select_sfx:seek(0)
                    select_sfx:play()
                    shopSelectionIndex = shopSelectionIndex + 1
                    if shopSelectionIndex > #shopSelections then
                        shopSelectionIndex = 1
                    end
                elseif key == "up" then
                    select_sfx:seek(0)
                    select_sfx:play()
                    shopSelectionIndex = shopSelectionIndex - 1
                    if shopSelectionIndex == 0 then
                        shopSelectionIndex = #shopSelections
                    end
                --press enter to make a purchase
                elseif key == "return" then
                    --Option 1 Max Health
                    if shopSelectionIndex == 1 and maxHealthLevel ~= #upgradeMaxHealth then                         
                        --use checkMoney function to subtract our coins
                        if checkMoney(coinCounter, upgradeMaxHealth[maxHealthLevel].price) == true then
                            bought_sfx:play()
                            maxHealthLevel = maxHealthLevel + 1
                            player.maxHealth = player.maxHealth + upgradeMaxHealth[maxHealthLevel].increase
                            player.currentHealth = player.currentHealth + upgradeMaxHealth[maxHealthLevel].increase
                            if maxHealthLevel == #upgradeMaxHealth then
                                shopSelections[1].color = shopMaxedColor
                            end
                        else
                            errorMessage()
                        end
                    
                    --Option 2 Armor
                    elseif shopSelectionIndex == 2 and armorLevel ~= #upgradeArmor then
                        if checkMoney(coinCounter, upgradeArmor[armorLevel].price) == true then
                            bought_sfx:play()
                            armorLevel = armorLevel + 1
                            player.armor = player.armor + upgradeArmor[armorLevel].increase
                            if armorLevel == #upgradeArmor then
                                shopSelections[shopSelectionIndex].color = shopMaxedColor
                            end
                        else
                            errorMessage()
                        end
                    --Option 3 Strength
                    elseif shopSelectionIndex == 3 and strengthLevel ~= #upgradeStrength then
                        bought_sfx:play()
                        if checkMoney(coinCounter, upgradeStrength[strengthLevel].price) == true then
                            strengthLevel = strengthLevel + 1
                            player.strength = player.strength + upgradeStrength[strengthLevel].increase
                            if strengthLevel == #upgradeStrength then
                                shopSelections[shopSelectionIndex].color = shopMaxedColor
                            end
                        else
                            errorMessage()
                        end
                    --Option 4 XP Rate
                    elseif shopSelectionIndex == 4 and xpLevel ~= #upgradeXp then
                        if checkMoney(coinCounter, upgradeXp[xpLevel].price) == true then
                            bought_sfx:play()
                            xpLevel = xpLevel + 1
                            if xpLevel == #upgradeXp then
                                shopSelections[shopSelectionIndex].color = shopMaxedColor
                            end
                        else
                            errorMessage()
                        end
                    --Option 5 Drop Rate
                    elseif shopSelectionIndex == 5 and coinLevel ~= #upgradeCoin then
                        if checkMoney(coinCounter, upgradeCoin[coinLevel].price) == true then
                            bought_sfx:play()
                            coinLevel = coinLevel + 1
                            if coinLevel == #upgradeCoin then
                                shopSelections[shopSelectionIndex].color = shopMaxedColor
                            end
                        else
                            errorMessage()
                        end
                    --Option 6 Max Mobs
                    elseif shopSelectionIndex == 6 and maxMobsLevel ~= #upgradeMaxMobs then
                        if checkMoney(coinCounter, upgradeMaxMobs[maxMobsLevel].price) == true then
                            bought_sfx:play()
                            maxMobs = maxMobs + upgradeMaxMobs[maxMobsLevel].increase
                            maxMobsLevel = maxMobsLevel + 1
                            if maxMobsLevel == #upgradeMaxMobs then
                                shopSelections[shopSelectionIndex].color = shopMaxedColor
                            end
                        else
                            errorMessage()
                        end
                    end
                end

            end
        end      
        --freeze all updates by returning
        return
    end
    
    bgm:play()
    
    player.isMoving = false
    local vx = 0
    local vy = 0
    -- don't move character if dead
    if isPlayerDead == false then
        if love.keyboard.isDown("left") then
            if player.inAir == false then
                run_sfx:play()
            end
            vx = player.speed * -1 
            player.anim = player.animations.runLeft
            player.isMoving = true
            player.direction = "left"
        elseif love.keyboard.isDown("right") then
            if player.inAir == false then
                run_sfx:play()
            end
            vx = player.speed 
            player.anim = player.animations.runRight
            player.isMoving = true
            player.direction = "right"
        end
    end
    player.collider:setLinearVelocity(vx,vy+50)

    if player.isMoving == false then
        if player.direction == "left" then
            player.anim = player.animations.idleLeft
        elseif player.direction == "right" then
            player.anim = player.animations.idleRight
        end
    end

    --Every time player touches "wall", like the ground, that means they can jump again. May need to rework to make ground only.
    if player.collider:enter('Solid') then 
        player.inAir = false
        if player.direction == "left" then
            player.anim = player.animations.idleLeft
        elseif player.direction == "right" then
            player.anim = player.animations.idleRight
        end 
    end
    
    --Every time player touches a mob, player should be knocked back and take damage if armor is not high enough
    if isPlayerDead == false then
        if player.invincFrame == false and player.collider:enter('Mob') then
            hit_sfx:play()
            local collision_data_mob = player.collider:getEnterCollisionData('Mob')
            for i, mob in pairs(mobs) do
                if mob.collider == collision_data_mob.collider then
                    if mob.strength - player.armor > 0 then
                        player.currentHealth = player.currentHealth - (mob.strength - player.armor)
                        player.collider:applyLinearImpulse(20000, -8000)
                    end
                end
            end
            player.invincFrame = true
            --check if player is dead
            if player.currentHealth <= 0 then 
                player.currentHealth = 0
                isPlayerDead = true
                deathTransition()
            end   
        end
    end

    if player.invincFrame == true then
        player.hitLockOutTimer = player.hitLockOutTimer - 5*dt
        
        if player.hitLockOutTimer < 0 then
            player.hitLockOutTimer = hitLockTimer
            player.invincFrame = false
        end
    end

    if player.collider:enter('Coin') then
        coin_sfx:play()
        coinCounter = coinCounter + 1
        -- new technique! we can use getEnterCollisionData to find the specific object we're colliding with
        local collision_data = player.collider:getEnterCollisionData('Coin')
        -- start tween animation for coins bouncing after colliding with player
        for i, v in pairs(coins) do
            if coins[i].collider == collision_data.collider then
                Timer.tween(0.5, coins[i].bounce, {y = 100}, 'in-out-quad')
                Timer.tween(0.5, coins[i].bounce, {color = {255, 255, 255, 0}}, 'in-out-quad')
            end
        end
    end
    -- every update cycle, check if the tween has finished for coin pickup, and if so remove coin from table
    if #coins > 0 then
        for i, v in pairs(coins) do
            if coins[i].bounce.y > 90 then
                coins[i].collider:destroy()
                table.remove(coins, i)
            end
        end
    end

    --KEYPRESSES for jump, attack, saving
    function love.keypressed(key)
        if isPlayerDead == false then
            if key == "space" and player.inAir == false then
                jump_sfx:play()
                player.inAir = true
                player.collider:applyLinearImpulse(0, -20000)
                world:update(dt)
            elseif key == "v" then
                player.attacking = true
                if comboAttackTimer == 1 then
                    comboAttack = false
                else
                    comboAttack = true
                end
                attackReg() 
            -- SAVE/RESET GAME
            elseif key == "f1" then
                saveGame()
            elseif key == "f2" then
                love.filesystem.remove("savedata.txt")
                love.event.quit("restart")
            elseif key == "escape" then
                menu_sfx:play()
                isPauseScreen = true
                selectionIndex = 1
                return
            end
        end
    end

    --Jump condition and animation
    if player.inAir == true then
        if player.direction == "left" then
            player.anim = player.animations.jumpLeft
        elseif player.direction == "right" then
            player.anim = player.animations.jumpRight
        end
    end

    --Attack condition and animation
    if player.attacking == true then     
        if comboAttack == false then
            if player.direction == "left" then
                player.anim = player.animations.attack1Left
            elseif player.direction == "right" then
                player.anim = player.animations.attack1Right
            end
            comboAttackTimer = comboAttackTimer - 0.01 

        elseif comboAttack == true then
            if player.direction == "left" then
                player.anim = player.animations.attack2Left
            elseif player.direction == "right" then
                player.anim = player.animations.attack2Right
            end
        end
        -- controls attack frames to not repeat itself with 1 click. depends on constant*dt (combo atk has more frames to draw)
        if comboAttack == false then
            player.attackTimer = player.attackTimer - 5*dt
        elseif comboAttack == true then
            player.attackTimer = player.attackTimer - 4*dt
        end
        if player.attackTimer < 0 then
            player.attacking = false
            player.attackTimer = 1
        end    
    end
    -- counts down the combo timer every frame, and sets to 1 after a bit so we revert to first attack animation every time
    if comboAttackTimer ~= 1 then
        comboAttackTimer = comboAttackTimer - 5*dt
        if comboAttackTimer <= 0 then
            comboAttackTimer = 1
        end
    end

    --update player and coin position to match the colliders
    player.x = player.collider:getX() 
    player.y = player.collider:getY() -30
    player.anim:update(dt)
    world:update(dt)
    for i, coin in ipairs(coins) do
        coin.x = coin.collider:getX() - 10
        coin.y = coin.collider:getY() - 10
        coin.spinAnimation:update(dt)
    end


    cam:lookAt(player.x, 450)

    --iterates over every mob and change their movement/speed relative to player. Also death animation 
    for i, mob in ipairs(mobs) do
        mob.x = mob.collider:getX() + 18 
        mob.y = mob.collider:getY() + 32
        -- if player is left of mob and mob is damaged, make mob move left to chase
        if player.x > mob.x then
            mob.vx = mob.speed
        elseif player.x <= mob.x then
            mob.vx = mob.speed * -1
        end
        mob.collider:setLinearVelocity(mob.vx, mob.vy)
        mob.anim:update(dt)

        --let whole mob death animation play out before removing mob from table
        if mob.anim == mob.animations.slimeDeath then
            mob.collider:setCollisionClass('DeadMob')
            mob.collider:setType('static')
            frameposition = mob.animations.slimeDeath.position
            if frameposition == 14 then
                mob.collider:destroy()
                table.remove(mobs, i)
            end
        end
    end

    --spawn more mobs periodically
    if #mobs < maxMobs then
        spawnTimer()
    end
    
    --spawn additional mobs depending on level thresholds
    if player.level == 10 and levelupspawn1 == false then 
        for i=1, 10 do
            createMob("red")
        end
        levelupspawn1 = true
    elseif player.level == 15 and levelupspawn2 == false then
        for i=1, 10 do
            createMob("blue")
        end
        levelupspawn2 = true
    elseif player.level == 20 and levelupspawn3 == false then
        for i=1,10 do
            createMob("red")
            createMob("blue")
            createMob("green")
        end
        levelupspawn3 = true
    end

    if isPlayerDead == true then
        bgm:pause()
        if player.direction == "left" then
            player.anim = player.animations.deathLeft
        elseif player.direction == "right" then
            player.anim = player.animations.deathRight
        end
        player.anim:update(dt) 
    end
    Timer.update(dt)
end


function love.draw()

    --draw title screen
    if isTitleScreen == true then
        love.graphics.setBackgroundColor(0,0,0)
        love.graphics.setColor(titleTransition.color)
        love.graphics.setFont(arcadeFontBig)
        love.graphics.printf("Slime Attack", 0, screenHeight/4, screenWidth, "center")
        love.graphics.setFont(arcadeFont)
        love.graphics.printf("By Nathan Ly", 0, screenHeight/3, screenWidth, "center")
        love.graphics.setFont(arcadeFontSmall)
        if saveExists == true then
            love.graphics.print("save file found!", 20, screenHeight-50)
        end
        slimeIdle:draw(spritesheetSlimeIdle, titleSlimeX, 400, 0, 2, 2)
        --fade loop
        love.graphics.setColor(menuTextColor.color)
        love.graphics.printf("(press enter)", 0, screenHeight/2, screenWidth, "center")
        return
    end
    

    love.graphics.setLineWidth(1)
    --fill out background 
    love.graphics.draw(background, -player.x/2, 0, 0, 2, 2)
    love.graphics.draw(background, -player.x/2 + background:getWidth(), 0, 0, 2, 2)
    love.graphics.draw(background, -player.x/2 + 2*background:getWidth(), 0, 0, 2, 2)
    
    cam:attach()

        gameMap:drawLayer(gameMap.layers["terrain"])
            
            --draw the mobs
            for i, mob in ipairs(mobs) do
                if mob.color == "green" then
                    love.graphics.setColor(1, 1, 1)
                elseif mob.color == "red" then
                    love.graphics.setColor(love.math.colorFromBytes(231, 100, 100))
                elseif mob.color == "blue" then
                    --love.graphics.setColor(love.math.colorFromBytes(50, 50, 255))
                    love.graphics.setColor(love.math.colorFromBytes(50,60,250))
                end

                if mob.anim == mob.animations.slimeIdle then
                    mob.anim:draw(mob.spritesheetSlimeIdle, mob.x, mob.y, 0, 1.5, 1.5, 60, 40)
                elseif mob.anim == mob.animations.slimeHurt then
                    mob.anim:draw(mob.spritesheetSlimeHurt, mob.x, mob.y, 0, 1.5, 1.5, 60, 40)
                elseif mob.anim == mob.animations.slimeDeath then
                    mob.anim:draw(mob.spritesheetSlimeDeath, mob.x, mob.y, 0, 1.5, 1.5, 60, 40)
                end
                --print damage numbers above enemies
                if mob.damaged == true then
                    for i, v in pairs(mob.dmgTable) do
                        --references for indexes of dmg values, color, and height
                        --dmgNumbers = {y = 0, color = {255, 255, 255, 1}}
                        --singleDmgTable = {dmgNumbers, dmgNumberMaxHeight, dmgNumberTransparent, dmg}
                        --table.insert(mobs[j].dmgTable, singleDmgTable)
                        love.graphics.setColor(mob.dmgTable[i][1].color)
                        love.graphics.print(mob.dmgTable[i][4], mob.x-50, mob.y-50-mob.dmgTable[i][1].y)
                    end
                end
                --show hp bar of enemies only if they are damaged and not dead
                if mob.currentHealth > 0 and mob.currentHealth < mob.maxHealth then
                --draw inside of hp bar
                    love.graphics.setColor(0.4, 0.4, 0.4)
                    love.graphics.rectangle("fill", mob.width/2 + mob.x - hp.width/2 - 42, mob.y, hp.width, hp.height)
                    love.graphics.setColor(1, 0, 0)
                    love.graphics.rectangle("fill", mob.width/2 + mob.x - hp.width/2 - 42, mob.y, hp.width*mob.currentHealth/mob.maxHealth, hp.height)
                    --draw black outline of hp bar
                    love.graphics.setLineWidth(3)
                    love.graphics.setColor(0,0,0)
                    love.graphics.rectangle("line", mob.width/2 + mob.x - hp.width/2 - 42, mob.y, hp.width, hp.height)
                end   
            end
            --draw all spinning coins
            for i, coin in ipairs(coins) do
                love.graphics.setColor(coin.bounce.color)
                coin.spinAnimation:draw(coin.spritesheetCoinSpin, coin.x, coin.y-coin.bounce.y, 0, 2, 2)
            end

            love.graphics.setLineWidth(1)
            love.graphics.setColor(1, 1, 1)

            -- player animations
            if player.anim == player.animations.runRight or player.anim == player.animations.runLeft then
                player.anim:draw(player.spritesheetRun, player.x, player.y, 0, 1.5, 1.5, 60, 40)
            elseif player.anim == player.animations.attack1Right or player.anim == player.animations.attack1Left then
                player.anim:draw(player.spritesheetAttack1, player.x, player.y, 0, 1.5, 1.5, 60, 40)
            elseif player.anim == player.animations.attack2Right or player.anim == player.animations.attack2Left then
                player.anim:draw(player.spritesheetAttack2, player.x, player.y, 0, 1.5, 1.5, 60, 40)
            elseif player.anim == player.animations.idleRight or player.anim == player.animations.idleLeft then
                player.anim:draw(player.spritesheetIdle, player.x, player.y, 0, 1.5, 1.5, 60, 40)
            elseif player.anim == player.animations.jumpRight or player.anim == player.animations.jumpLeft then
                player.anim:draw(player.spritesheetJump, player.x, player.y, 0, 1.5, 1.5, 60, 40)
            elseif player.anim == player.animations.deathRight or player.anim == player.animations.deathLeft then
                player.anim:draw(player.spritesheetDeath, player.x, player.y, 0, 1.5, 1.5, 60, 40)
            end
            

            --level up animation
            if leveledUp == true then
                love.graphics.setColor(levelCircle.color)
                love.graphics.circle('fill', player.x, player.y, levelCircle.rad)
                love.graphics.setColor(text.opacity)
                love.graphics.print("LEVEL UP", player.x - 60, player.y - text.y)
            end
            --world:draw()
    cam:detach()
    if isPlayerDead == false then
        --player HP bar
        love.graphics.setFont(arcadeFont)
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.rectangle("fill", 10, 570, 200, 20)
        love.graphics.setColor(1, 0, 0)
        love.graphics.rectangle("fill", 10, 570, 200 * player.currentHealth/player.maxHealth, 20)
        love.graphics.setColor(0, 0, 0)
        love.graphics.setLineWidth(5)
        love.graphics.rectangle("line", 10, 570, 200, 20)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("HP", 10, 550)
        love.graphics.setFont(arcadeFontSmall)
        love.graphics.print("["..player.currentHealth.."/"..player.maxHealth.."]", 100, 552)
        love.graphics.setFont(arcadeFont)

        --player XP bar
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.rectangle("fill", 300, 570, 200, 20)
        love.graphics.setColor(1, 1, 0)
        love.graphics.rectangle("fill", 300, 570, 200 * player.currentXp/player.maxXp, 20)
        love.graphics.setColor(0, 0, 0)
        love.graphics.setLineWidth(5)
        love.graphics.rectangle("line", 300, 570, 200, 20)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("EXP", 300, 550)
        love.graphics.setFont(arcadeFontSmall)
        local percentxp = string.format("%.2f%%", 100*player.currentXp/player.maxXp)
        love.graphics.print("["..player.currentXp.."/"..player.maxXp.."]".."("..percentxp..")", 360, 552)
        love.graphics.setFont(arcadeFont)

        --player level and coins display
        love.graphics.setColor(0.4, 0.4, 0.4)
        love.graphics.rectangle("fill", -5, -5, 100, 60, 10, 10)
        love.graphics.setColor(0, 0, 0)
        love.graphics.setLineWidth(5)
        love.graphics.rectangle("line", -5, -5, 100, 60, 10, 10)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(0, 0, 0)
        love.graphics.print("LV "..player.level, 8, 9)
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("LV "..player.level, 10, 8)
        love.graphics.setColor(0, 0, 0)
        love.graphics.print("$"..coinCounter, 7, 32)
        love.graphics.setColor(0, 1, 0)
        love.graphics.print("$"..coinCounter, 8, 30)
        love.graphics.setColor(1, 1, 1)
    end

    --draw pause screen
    if isPauseScreen == true then
        --menu background
        love.graphics.setColor(pauseColor)
        love.graphics.rectangle('fill', widthMargin, heightMargin, screenWidth-2*widthMargin, screenHeight-2*heightMargin, 20, 20)
        love.graphics.setColor(0,0,0)
        love.graphics.setLineWidth(5)
        love.graphics.rectangle('line', widthMargin, heightMargin, screenWidth-2*widthMargin, screenHeight-2*heightMargin, 20, 20)

        --esc button 
        love.graphics.rectangle('line', widthMargin, heightMargin, 60, 40, 20, 20)
        love.graphics.setColor(1,1,1)
        love.graphics.print("esc", 110, 110)
        
        --text
        love.graphics.setFont(arcadeFontBig)
        love.graphics.setColor(1,1,1)
        love.graphics.printf("PAUSED",0,10,screenWidth, "center")

        if isShopScreen == false then
            
            love.graphics.setColor(0,1,0)
            love.graphics.printf("SHOP", 0, screenHeight/3, screenWidth, "center")
            love.graphics.printf("SAVE", 0, screenHeight*2/3-50, screenWidth, "center")
            -- selection pointer
            love.graphics.print(">", pauseSelections[selectionIndex].x, pauseSelections[selectionIndex].y)

            --print a save confirmation after saving
            if printSaveMessage == true then
                love.graphics.setFont(arcadeFontSmall)
                love.graphics.setColor(1,1,1)
                love.graphics.print("SAVED!", screenWidth - 80, screenHeight-30)
            end
            
        end

        if isShopScreen == true then
            love.graphics.setFont(arcadeFontBig)
            love.graphics.setColor(0,1,0)
            love.graphics.printf("SHOP", 0, screenHeight/5, screenWidth, "center")

            love.graphics.setFont(arcadeFont)
            love.graphics.setColor(1,1,1)
            love.graphics.print("UPGRADES", 180, 180)
            love.graphics.print("________", 180, 185)
            love.graphics.printf("LV", 0, 180, screenWidth, "center")
            love.graphics.printf("__", 0, 185, screenWidth, "center")
            love.graphics.print("PRICE", 510, 180)
            love.graphics.print("_____", 510, 185)

            love.graphics.setFont(arcadeFontSmall)
            love.graphics.setColor(shopSelections[1].color)
            love.graphics.print("max hp", 180, 220)
            love.graphics.printf(maxHealthLevel, 0, 220, screenWidth, "center")
            love.graphics.print("$"..upgradeMaxHealth[maxHealthLevel].price, 520, 220)

            love.graphics.setColor(shopSelections[2].color)
            love.graphics.print("armor", 180, 250)
            love.graphics.printf(armorLevel, 0, 250, screenWidth, "center")
            love.graphics.print("$"..upgradeArmor[armorLevel].price, 520, 250)
            
            love.graphics.setColor(shopSelections[3].color)
            love.graphics.print("strength", 180, 280)
            love.graphics.printf(strengthLevel, 0, 280, screenWidth, "center")
            love.graphics.print("$"..upgradeStrength[strengthLevel].price, 520, 280)

            love.graphics.setColor(shopSelections[4].color)
            love.graphics.print("xp rate", 180, 310)
            love.graphics.printf(xpLevel, 0, 310, screenWidth, "center")
            love.graphics.print("$"..upgradeXp[xpLevel].price, 520, 310)

            love.graphics.setColor(shopSelections[5].color)
            love.graphics.print("drop rate", 180, 340)
            love.graphics.printf(coinLevel, 0, 340, screenWidth, "center")
            love.graphics.print("$"..upgradeCoin[coinLevel].price, 520, 340)

            love.graphics.setColor(shopSelections[6].color)
            love.graphics.print("max mobs", 180, 370)
            love.graphics.printf(maxMobsLevel, 0, 370, screenWidth, "center")
            love.graphics.print("$"..upgradeMaxMobs[maxMobsLevel].price, 520, 370)

            --selection pointer
            love.graphics.print(">", shopSelections[shopSelectionIndex].x, shopSelections[shopSelectionIndex].y)

            --not enough money error text
            if notEnoughMoney == true then
                love.graphics.setColor(errorText.color)
                love.graphics.print("NOT ENOUGH MONEY!", 500, 430+errorText.y)
            end
        end
        -- darken the background whenever paused
        love.graphics.setColor(pauseColor)
    end
    if isPlayerDead == true then
        --love.graphics.setColor(fadeToBlack.color)
        
        love.graphics.setColor(gameOverMessage.color)
        love.graphics.setFont(arcadeFontBig)
        love.graphics.printf("GAME OVER", 0, screenHeight/4 + gameOverMessage.y, screenWidth, "center")
        love.graphics.setColor(fadeToBlack.color)
        love.graphics.rectangle("fill", 0,0,screenWidth,screenHeight)
    end
end

--save file
function saveGame()
    data = {
        x = player.x,
        y = player.y,
        level = player.level,
        strength = player.strength,
        armor = player.armor,
        maxHp = player.maxHealth,
        currentHp = player.currentHealth,
        currentXp = player.currentXp,
        maxXp = player.maxXp,
        coins = coinCounter,
        xpLevel = xpLevel,
        coinLevel = coinLevel,
        strengthLevel = strengthLevel,
        maxHealthLevel = maxHealthLevel,
        maxMobsLevel = maxMobsLevel,
        armorLevel = armorLevel,
        maxMobs = maxMobs
    }
    serialized = lume.serialize(data)
    love.filesystem.write("savedata.txt", serialized)

end


