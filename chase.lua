--[[
chase.lua 2.0.0 -- aquietone

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

TLO:
Chase.Paused
Chase.Target
Chase.Distance
Chase.Role

Chase.Open - Open UI

]]--

--- The mq require is mandatory to provide the plugin table factory
---@class Mq
---@field public plugin fun(name:string, version:string):Plugin
local mq = require("mq")

--- If the imgui callback is to be used, be sure to also require the ImGui
--- interface
---@type ImGui
local imgui = require("ImGui")

--- The plugin table factory will instantiate a plugin object that is used to
--- define all the functionality of the plugin. A name and version is supplied
--- to the factory function and both are required strings.
---@class Plugin
---@field public name string the name of the plugin, specified in this factory
---@field public version string the version of the plugin, specified in this factory
---@field public addcommand fun(self:Plugin, command:string, func:fun(line:string))
---@field public removecommand fun(self:Plugin, command:string):boolean
---@field public addtype fun(self:Plugin, type:string, definition:table)
---@field public removetype fun(self:Plugin, type:string)
---@field public addtlo fun(self:Plugin, tlo:string, func:fun(index:string):any)
---@field public removetlo fun(self:Plugin, tlo:string):boolean
local plugin = mq.plugin("chase", "1.0")

--- Plugin "global" state can be stored as variables on the plugin object, and
--- any functions can be defined on the object, they will be persisted with the
--- plugin object and can be used in any registered functions, provided a self
--- argument is provided to access them
plugin.is_open = false
plugin.paused = false
plugin.chase_target = ''
plugin.chase_distance = 30
plugin.role = 'none'
local ROLES = {[1]='none',none=1,[2]='ma',ma=1,[3]='mt',mt=1,[4]='leader',leader=1,[5]='raid1',raid1=1,[6]='raid2',raid2=1,[7]='raid3',raid3=1}

function plugin:validate_distance(distance)
    if distance < 15 or distance > 300 then return false end
    return true
end

function plugin:validate_chase_role(role)
    if not ROLES[role] then return false end
    return true
end

function plugin:check_distance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end

function plugin:get_spawn_for_role()
    local spawn = nil
    if self.role == 'none' then
        spawn = mq.TLO.Spawn('pc ='..self.chase_target)
    elseif self.role == 'ma' then
        spawn = mq.TLO.Group.MainAssist
    elseif self.role == 'mt' then
        spawn = mq.TLO.Group.MainTank
    elseif self.role == 'leader' then
        spawn = mq.TLO.Group.Leader
    elseif self.role == 'raid1' then
        spawn = mq.TLO.Raid.MainAssist(1)
    elseif self.role == 'raid2' then
        spawn = mq.TLO.Raid.MainAssist(2)
    elseif self.role == 'raid3' then
        spawn = mq.TLO.Raid.MainAssist(3)
    end
    return spawn
end

function plugin:print_help()
    print('Lua Chase 1.0 -- Available Commands:')
    print('\t/luachase role ma|mt|leader|raid1|raid2|raid3\n\t/luachase target\n\t/luachase name [pc_name_to_chase]\n\t/luachase distance [10,300]\n\t/luachase pause on|1|true\n\t/luachase pause off|0|false\n\t/luachase show\n\t/luachase hide')
end

--- Plugin commands, datatypes, and TLOs will need definitions that will be
--- passed into the add functions during initialization
function plugin:chasecmd(line)
    local args = {}
    for arg in line:gmatch("%w+") do table.insert(args, arg) end
    local key = args[1]
    local value = args[2]
    if not key or key == 'help' then
        self:print_help()
    elseif key == 'target' then
        if not mq.TLO.Target() or mq.TLO.Target.Type() ~= 'PC' then
            return
        end
        self.chase_target = mq.TLO.Target.CleanName()
    elseif key == 'name' then
        if value then
            self.chase_target = value
        else
            print(string.format('Chase Target: %s', self.chase_target))
        end
    elseif key == 'role' then
        if value and self:validate_chase_role(value) then
            self.role = value
        else
            print(string.format('Chase Role: %s', self.role))
        end
    elseif key == 'distance' then
        if tonumber(value) then
            local tmp_distance = tonumber(value)
            if self:validate_distance(tmp_distance) then
                self.chase_distance = tmp_distance
            end
        else
            print(string.format('Chase Target: %s', self.chase_distance))
        end
    elseif key == 'pause' then
        if value == 'on' or value == '1' or value == 'true' then
            self.paused = true
            mq.cmd('/squelch /nav stop')
        elseif value == 'off' or value == '0' or value == 'false' then
            self.paused = false
        else
            print(string.format('Chase Paused: %s', self.paused))
        end
    elseif key == 'show' then
        self.is_open = true
    elseif key == 'hide' then
        self.is_open = false
    end
end

--- function to open the ImGui window
---@param self Plugin optionally specify a self plugin
---@param val string the storage value of the type, can be any type
---@param index string an index if required (must still have the parameter specified)
function plugin:Open(val, index)
    self.is_open = true
end

-- datatypes are defined by tables with 5 (all optional) members: Members, Methods,
-- ToString, FromData, and FromString.
---@class Datatype
---@field public Members table
---@field public Methods table
---@field public ToString fun(self:Plugin, val:any):any
---@field public FromData fun(self:Plugin, source:any):any
---@field public FromString fun(self:Plugin, source:string):any
plugin.chasetype = {
    Members = {
        Paused = function(val, index) return 'bool', val.paused end,
        Role = function(val, index) return 'string', val.role end,
        Target = function(val, index) return 'string', val.chase_target end,
        Distance = function(val, index) return 'int', val.chase_distance end,
    },
    Methods = {
        Open = plugin.Open,
    },
    ToString = function(val) return tostring(not val.paused) end,
}


-- tlo functions return a tuple of typename (which can be any valid MQ typename
-- like 'string' or 'spawn' and then the data required to assign the value)
function plugin:Chase(Index)
    return "chase", self
end

--- InitializePlugin
---
--- This is called once on plugin initialization and can be considered the startup
--- routine for the plugin.
---
---@param self Plugin optionally specify a self plugin
function plugin:InitializePlugin()
    printf("%s::Initializing version %f", self.name, self.version)

    self:addcommand("/luachase", self.chasecmd)
    self:addtype("chase", self.chasetype)
    self:addtlo("Chase", self.Chase)
end

--- ShutdownPlugin
---
--- This is called once when the plugin has been asked to shutdown. The plugin has
--- not actually shut down until this completes.
---
---@param self Plugin optionally specify a self plugin
function plugin:ShutdownPlugin()
    printf("%s::Shutting down", self.name)

    self:removecommand("/luachase")
    self:removetype("chase")
    self:removetlo("Chase")
end

--- SetGameState
---
--- This is called when the GameState changes. It is also called once after the
--- plugin is initialized.
---
--- For a list of known GameState values, see the constants that begin with
--- GAMESTATE_. The most commonly used of these is GAMESTATE_INGAME.
---
--- When zoning, this is called once after OnBeginZone OnRemoveSpawn
--- and OnRemoveGroundItem are all done and then called once again after
--- OnEndZone and OnAddSpawn are done but prior to OnAddGroundItem
--- and OnZoned
---
---@param self Plugin optionally specify a self plugin
---@param GameState number The integer value of GameState at the time of the call
function plugin:SetGameState(GameState)
    printf("%s::SetGameState(%d)", self.name, GameState)
end

function plugin:do_chase()
    if self.paused then return end
    if mq.TLO.Me.Hovering() or mq.TLO.Me.AutoFire() or mq.TLO.Me.Combat() or (mq.TLO.Me.Casting() and mq.TLO.Me.Class.ShortName() ~= 'BRD') or mq.TLO.Stick.Active() then return end
    local chase_spawn = self:get_spawn_for_role()
    local me_x = mq.TLO.Me.X()
    local me_y = mq.TLO.Me.Y()
    local chase_x = chase_spawn.X()
    local chase_y = chase_spawn.Y()
    if not chase_x or not chase_y then return end
    if plugin:check_distance(me_x, me_y, chase_x, chase_y) > self.chase_distance then
        if not mq.TLO.Nav.Active() and mq.TLO.Navigation.PathExists(string.format('spawn pc =%s', chase_spawn.CleanName())) then
            mq.cmdf('/nav spawn pc =%s | dist=10 log=off', chase_spawn.CleanName())
        end
    end
end

--- OnPulse
---
--- This is called each time MQ2 goes through its heartbeat (pulse) function.
---
--- Because this happens very frequently, it is recommended to have a timer or
--- counter at the start of this call to limit the amount of times the code in
--- this section is executed.
---
---@param self Plugin optionally specify a self plugin
function plugin:OnPulse()
    if not self.PulseTimer then
        self.PulseTimer = os.clock()
    end
    if os.clock() > self.PulseTimer then
        -- Wait 5 seconds before running again
        self.PulseTimer = os.clock() + 1
        --printf("%s::OnPulse()", self.name)
        self:do_chase()
    end
end

--- OnBeginZone
---
--- This is called just after entering a zone line and as the loading screen appears.
---
---@param self Plugin optionally specify a self plugin
function plugin:OnBeginZone()
    printf("%s::OnBeginZone()", self.name)
end

--- OnEndZone
---
--- This is called just after the loading screen, but prior to the zone being fully
--- loaded.
---
--- This should occur before OnAddSpawn and OnAddGroundItem are called. It
--- always occurs before OnZoned is called.
---
---@param self Plugin optionally specify a self plugin
function plugin:OnEndZone()
    printf("%s::OnEndZone()", self.name)
end

--- OnZoned
---
--- This is called after entering a new zone and the zone is considered "loaded."
---
--- It occurs after OnEndZone OnAddSpawn and OnAddGroundItem have
--- been called.
---
---@param self Plugin optionally specify a self plugin
function plugin:OnZoned()
    printf("%s::OnZoned()", self.name)
end

function plugin:draw_combo_box(resultvar, options)
    if imgui.BeginCombo('Chase Role', resultvar) then
        for _,j in ipairs(options) do
            if imgui.Selectable(j, j == resultvar) then
                resultvar = j
            end
        end
        imgui.EndCombo()
    end
    return resultvar
end

--- OnUpdateImGui
---
--- This is called each time that the ImGui Overlay is rendered. Use this to render
--- and update plugin specific widgets.
---
--- Because this happens extremely frequently, it is recommended to move any actual
--- work to a separate call and use this only for updating the display.
---
---@param self Plugin optionally specify a self plugin
function plugin:OnUpdateImGui()
    if not self.is_open or mq.TLO.MacroQuest.GameState() ~= 'INGAME' then
        return
    end
    local is_drawn = false
    self.is_open, is_drawn = imgui.Begin('Chase', self.is_open)
    if is_drawn then
        if self.paused then
            if imgui.Button('Resume') then
                self.paused = false
            end
        else
            if imgui.Button('Pause') then
                self.paused = true
                mq.cmd('/squelch /nav stop')
            end
        end
        imgui.PushItemWidth(100)
        self.role = self:draw_combo_box(self.role, ROLES)
        self.chase_target = imgui.InputText('Chase Target', self.chase_target)
        local tmp_distance = imgui.InputInt('Chase Distance', self.chase_distance)
        imgui.PopItemWidth()
        if self:validate_distance(tmp_distance) then
            self.chase_distance = tmp_distance
        end
    end
    imgui.End()
end

--- OnLoadPlugin
---
--- This is called each time a plugin is loaded (ex: /plugin someplugin), after the
--- plugin has been loaded and any associated -AutoExec.cfg file has been launched.
--- This means it will be executed after the plugin's InitializePlugin callback.
---
--- This is also called when THIS plugin is loaded, but initialization tasks should
--- still be done in InitializePlugin.
---
---@param self Plugin optionally specify a self plugin
---@param Name string The name of the plugin that was loaded
function plugin:OnLoadPlugin(Name)
    printf("%s::OnLoadPlugin(%s)", self.name, Name)
end

--- OnUnloadPlugin
---
--- This is called each time a plugin is unloaded (ex: /plugin someplugin unload),
--- just prior to the plugin unloading. This means it will be executed prior to that
--- plugin's ShutdownPlugin callback.
---
--- This is also called when THIS plugin is unloaded, but shutdown tasks should still
--- be done in ShutdownPlugin.
---
---@param self Plugin optionally specify a self plugin
---@param Name string The name of the plugin that is to be unloaded
function plugin:OnUnloadPlugin(Name)
    printf("%s::OnUnloadPlugin(%s)", self.name, Name)
end

--- The script must return the constructed plugin object
return plugin
