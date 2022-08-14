--[[
chase.lua 1.0.2 -- aquietone

Commands:
- /luachase pause on|1|true -- pause chasing
- /luachase pause off|0|false -- resume chasing
- /luachase target -- sets the chase to your current target, if it is a valid PC target
- /luachase name somedude -- sets the chase target to somedude
- /luachase name -- prints the current chase target
- /luachase role [ma|mt|leader|raid1|raid2|raid3] -- chase the PC with the specified role
- /luachase role -- displays the role to chase
- /luachase distance 30 -- sets the chase distance to 30
- /luachase distance -- prints the current chase distance
- /luachase show -- displays the UI window
- /luachase hide -- hides the UI window
- /luachase [help] -- displays the help output
]]--

local mq = require('mq')

local PAUSED = false
local CHASE = ''
local DISTANCE = 30

local open_gui = true
local should_draw_gui = true

local ROLES = {[1]='none',none=1,[2]='ma',ma=1,[3]='mt',mt=1,[4]='leader',leader=1,[5]='raid1',raid1=1,[6]='raid2',raid2=1,[7]='raid3',raid3=1}
local ROLE = 'none'

local function validate_distance(distance)
    if distance < 15 or distance > 300 then return false end
    return true
end

local function check_distance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end

local function validate_chase_role(role)
    if not ROLES[role] then return false end
    return true
end

local function get_spawn_for_role()
    local spawn = nil
    if ROLE == 'none' then
        spawn = mq.TLO.Spawn('pc ='..CHASE)
    elseif ROLE == 'ma' then
        spawn = mq.TLO.Group.MainAssist
    elseif ROLE == 'mt' then
        spawn = mq.TLO.Group.MainTank
    elseif ROLE == 'leader' then
        spawn = mq.TLO.Group.Leader
    elseif ROLE == 'raid1' then
        spawn = mq.TLO.Raid.MainAssist(1)
    elseif ROLE == 'raid2' then
        spawn = mq.TLO.Raid.MainAssist(2)
    elseif ROLE == 'raid3' then
        spawn = mq.TLO.Raid.MainAssist(3)
    end
    return spawn
end

local function do_chase()
    if PAUSED then return end
    if mq.TLO.Me.Hovering() or mq.TLO.Me.AutoFire() or mq.TLO.Me.Combat() or (mq.TLO.Me.Casting() and mq.TLO.Me.Class.ShortName() ~= 'BRD') or mq.TLO.Stick.Active() then return end
    local chase_spawn = get_spawn_for_role()
    local me_x = mq.TLO.Me.X()
    local me_y = mq.TLO.Me.Y()
    local chase_x = chase_spawn.X()
    local chase_y = chase_spawn.Y()
    if not chase_x or not chase_y then return end
    if check_distance(me_x, me_y, chase_x, chase_y) > DISTANCE then
        if not mq.TLO.Nav.Active() and mq.TLO.Navigation.PathExists(string.format('spawn pc =%s', chase_spawn.CleanName())) then
            mq.cmdf('/nav spawn pc =%s | dist=10 log=off', chase_spawn.CleanName())
        end
    end
end

local function draw_combo_box(resultvar, options)
    if ImGui.BeginCombo('Chase Role', resultvar) then
        for _,j in ipairs(options) do
            if ImGui.Selectable(j, j == resultvar) then
                resultvar = j
            end
        end
        ImGui.EndCombo()
    end
    return resultvar
end

local function chase_ui()
    if not open_gui or mq.TLO.MacroQuest.GameState() ~= 'INGAME' then return end
    open_gui, should_draw_gui = ImGui.Begin('Chase', open_gui)
    if should_draw_gui then
        if PAUSED then
            if ImGui.Button('Resume') then
                PAUSED = false
            end
        else
            if ImGui.Button('Pause') then
                PAUSED = true
                mq.cmd('/squelch /nav stop')
            end
        end
        ImGui.PushItemWidth(100)
        ROLE = draw_combo_box(ROLE, ROLES)
        CHASE = ImGui.InputText('Chase Target', CHASE)
        local tmp_distance = ImGui.InputInt('Chase Distance', DISTANCE)
        ImGui.PopItemWidth()
        if validate_distance(tmp_distance) then
            DISTANCE = tmp_distance
        end
    end
    ImGui.End()
end
mq.imgui.init('Chase', chase_ui)

local function print_help()
    print('Lua Chase 1.0 -- Available Commands:')
    print('\t/luachase role ma|mt|leader|raid1|raid2|raid3\n\t/luachase target\n\t/luachase name [pc_name_to_chase]\n\t/luachase distance [10,300]\n\t/luachase pause on|1|true\n\t/luachase pause off|0|false\n\t/luachase show\n\t/luachase hide')
end

local function bind_chase(...)
    local args = {...}
    local key = args[1]
    local value = args[2]
    if not key or key == 'help' then
        print_help()
    elseif key == 'target' then
        if not mq.TLO.Target() or mq.TLO.Target.Type() ~= 'PC' then
            return
        end
        CHASE = mq.TLO.Target.CleanName()
    elseif key == 'name' then
        if value then
            CHASE = value
        else
            print(string.format('Chase Target: %s', CHASE))
        end
    elseif key == 'role' then
        if value and validate_chase_role(value) then
            ROLE = value
        else
            print(string.format('Chase Role: %s', ROLE))
        end
    elseif key == 'distance' then
        if tonumber(value) then
            local tmp_distance = tonumber(value)
            if validate_distance(tmp_distance) then
                DISTANCE = tmp_distance
            end
        else
            print(string.format('Chase Target: %s', DISTANCE))
        end
    elseif key == 'pause' then
        if value == 'on' or value == '1' or value == 'true' then
            PAUSED = true
            mq.cmd('/squelch /nav stop')
        elseif value == 'off' or value == '0' or value == 'false' then
            PAUSED = false
        else
            print(string.format('Chase Paused: %s', PAUSED))
        end
    elseif key == 'show' then
        open_gui = true
    elseif key == 'hide' then
        open_gui = false
    end
end
mq.bind('/luachase', bind_chase)

local args = {...}
if args[1] then
    if validate_chase_role(args[1]) then
        ROLE = args[1]
    else
        CHASE=args[1]
    end
end

while true do
    if mq.TLO.MacroQuest.GameState() == 'INGAME' then
        do_chase()
    end
    mq.delay(50)
end
