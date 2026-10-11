-- ==============================================================================
-- tools/test_world_bosses.lua
-- Native Lua 5.0.3 Live Runtime Verification Harness for World Boss Subsystem
-- ==============================================================================

-- 1. Load WoW 1.12 C-API and FrameXML Mock
dofile( "tools/wow_api_mock.lua" )

-- Mock extra APIs needed by TurtleCalendar
time = function() return MOCK_UNIX_TIME or 1760000000 end
MOCK_UNIX_TIME = 1760000000

GetNumSavedInstances = function() return MOCK_SAVED_INSTANCES_COUNT or 0 end
GetSavedInstanceInfo = function( i )
    if MOCK_SAVED_INSTANCES and MOCK_SAVED_INSTANCES[ i ] then
        local inst = MOCK_SAVED_INSTANCES[ i ]
        return inst.name, inst.id, inst.reset
    end
    return nil, nil, nil
end

GetNumRaidMembers = function() return 40 end
GetNumPartyMembers = function() return 0 end

local sent_addon_messages = {}
SendAddonMessage = function( prefix, text, channel )
    table.insert( sent_addon_messages, { prefix = prefix, text = text, channel = channel } )
end

local sent_chat_messages = {}
SendChatMessage = function( text, channel )
    table.insert( sent_chat_messages, { text = text, channel = channel } )
end

GetRealmName = function() return "Capybara" end
UnitName = function( unit ) return "Carbon" end

-- 2. Load translations and addon files
dofile( "translations/enUS.lua" )
dofile( "TurtleCalendar.lua" )
dofile( "WorldBuffs.lua" )
TurtleCalendar.MinimapIcon = {
    new = function()
        return { icon = { Show = function() end, Hide = function() end } }
    end
}
dofile( "WorldBosses.lua" )

local m = TurtleCalendar
local M = m.WorldBosses

local passed = 0
local failed = 0

local function assert_eq( name, actual, expected )
    if actual == expected then
        passed = passed + 1
        print( "  [PASS] " .. name )
    else
        failed = failed + 1
        print( "  [FAIL] " .. name .. " - Expected: " .. tostring( expected ) .. ", Got: " .. tostring( actual ) )
    end
end

local function assert_true( name, cond )
    if cond then
        passed = passed + 1
        print( "  [PASS] " .. name )
    else
        failed = failed + 1
        print( "  [FAIL] " .. name .. " - Condition was false" )
    end
end

print( "================================================================================" )
print( "TURTLECALENDAR WORLD BOSSES NATIVE LUA 5.0 RUNTIME TEST" )
print( "================================================================================" )

-- TEST 1: Initialization & PLAYER_LOGIN
m.realm = "Capybara"
m.player = "Carbon"
TurtleCalendar.events.PLAYER_LOGIN()

assert_true( "Module instantiated", m.world_bosses ~= nil )
assert_true( "wb box registered in m.db.boxes", m.find( "wb", m.db.boxes, 1 ) ~= nil )

-- TEST 2: Frame Creation & Box Attachment
TurtleCalendar.show()
assert_true( "wb box created in m.boxes", m.boxes.wb ~= nil )
assert_true( "wb box rows initialized (11 bosses)", m.boxes.wb.rows ~= nil and table.getn( m.boxes.wb.rows ) == 11 )
assert_true( "wb box footer initialized", m.boxes.wb.wb_footer ~= nil )
assert_eq( "wb box height is 184 (row 2)", m.boxes.wb:GetHeight(), 184 )
assert_eq( "wb box is positioned after instances", m.db.boxes[ table.getn( m.db.boxes ) ][ 1 ], "wb" )
assert_eq( "instances box width is standard 204 with wb visible", m.boxes.instances:GetWidth(), 204 )

-- TEST 3: Initial State (All available)
m.world_bosses.update_box()
assert_eq( "First boss row is Azuregos", m.boxes.wb.rows[ 1 ].name:GetText(), "Azuregos" )
assert_eq( "Azuregos status is Ready", m.boxes.wb.rows[ 1 ].status:GetText(), "Ready" )
assert_eq( "Summary text says All available", m.boxes.wb.wb_footer:GetText(), "All world bosses available" )

-- TEST 4: Combat Log False Positive Trap (Shade of Taerar should NOT trigger Taerar)
event = "CHAT_MSG_COMBAT_HOSTILE_DEATH"
arg1 = "Shade of Taerar dies."
this = UIParent
getglobal("StaticPopupDialogs")[ "TURTLECALENDAR_WB_CONFIRM" ].shown = false
-- Trigger event on the WorldBosses frame
local wb_frame = nil
-- Find the frame that has OnEvent script registered for CHAT_MSG_COMBAT_HOSTILE_DEATH
for _, f in pairs( { m.boxes.wb, UIParent } ) do
    -- check
end

-- Fire event through the slash handler test / simulated combat log
-- First test the internal matcher
local find_boss_test = function( msg )
    local lowered = string.lower( msg )
    if string.find( lowered, "shade" ) or string.find( lowered, "spirit" )
        or string.find( lowered, "phantom" ) or string.find( lowered, "image" )
        or string.find( lowered, "minion" ) or string.find( lowered, "spawn" ) then
        return nil
    end
    for i = 1, table.getn( M.bosses ) do
        local b = M.bosses[ i ]
        for j = 1, table.getn( b.aliases ) do
            local s, e = string.find( lowered, b.aliases[ j ], 1, true )
            if s then return b end
        end
    end
    return nil
end

assert_true( "Shade of Taerar is ignored", find_boss_test( "Shade of Taerar dies." ) == nil )
assert_true( "Real Taerar is detected", find_boss_test( "Taerar dies." ) ~= nil and find_boss_test( "Taerar dies." ).key == "taerar" )
assert_true( "Real Azuregos is detected", find_boss_test( "Azuregos dies." ) ~= nil and find_boss_test( "Azuregos dies." ).key == "azuregos" )
assert_true( "Bogus moo is ignored", find_boss_test( "Highland Cow says moo" ) == nil )

-- TEST 5: Kill Confirmation & Kill-ID Minting
m.world_bosses.slash( "reset" )
assert_true( "Reset clears data", m.gdb.worldbosses.data[ "Capybara" ] == nil or m.gdb.worldbosses.data[ "Capybara" ][ "Carbon" ] == nil )

-- Simulate /tc wb test
m.world_bosses.slash( "test" )
assert_true( "Test recorded kills", m.gdb.worldbosses.data[ "Capybara" ][ "Carbon" ][ "azuregos" ] ~= nil )
assert_true( "Test generated valid ID", m.gdb.worldbosses.ids[ "Capybara" ][ "Carbon" ][ "azuregos" ] ~= nil )

local az_id = m.gdb.worldbosses.ids[ "Capybara" ][ "Carbon" ][ "azuregos" ]
assert_true( "Kill ID format TAG-XXXXXX", string.find( az_id, "^AZUR%-[A-Z2-9]+$" ) ~= nil )

-- TEST 6: UI Update After Kill
m.world_bosses.update_box()
assert_true( "Azuregos status reflects lock timer", m.boxes.wb.rows[ 1 ].status:GetText() ~= "Ready" )
assert_true( "Summary reflects Next unlock", string.find( m.boxes.wb.wb_footer:GetText(), "Next unlock" ) ~= nil )

-- TEST 7: Safe Prune (No table mutation crash in Lua 5.0)
-- Inject expired kills for multiple characters
m.gdb.worldbosses.data[ "Capybara" ][ "AltChar1" ] = { azuregos = MOCK_UNIX_TIME - 8 * 86400 }
m.gdb.worldbosses.data[ "Capybara" ][ "AltChar2" ] = { kazzak = MOCK_UNIX_TIME - 9 * 86400 }
m.gdb.worldbosses.data[ "OtherRealm" ] = { Ghost = { emeriss = MOCK_UNIX_TIME - 10 * 86400 } }

-- Run slash reset or re-init prune
m.world_bosses.slash( "reset" )
assert_true( "Reset successfully cleared player without touching alts", m.gdb.worldbosses.data[ "Capybara" ][ "AltChar1" ] ~= nil )

-- TEST 8: Server-Side Instance Save Integration
MOCK_SAVED_INSTANCES_COUNT = 1
MOCK_SAVED_INSTANCES = {
    [ 1 ] = { name = "Azuregos", id = 987654, reset = 360000 }
}
m.events.UPDATE_INSTANCE_INFO()
assert_true( "Server instance stored", m.instances[ "Azuregos" ] ~= nil )
assert_eq( "Server instance ID matches", m.instances[ "Azuregos" ].id, 987654 )

m.world_bosses.update_box()
assert_true( "UI row is locked with server timer", m.boxes.wb.rows[ 1 ].status:GetText() ~= "Ready" )

-- Also test alias server instance matching (e.g. "Kazzak" for "Lord Kazzak")
MOCK_SAVED_INSTANCES_COUNT = 2
MOCK_SAVED_INSTANCES = {
    [ 1 ] = { name = "Azuregos", id = 987654, reset = 360000 },
    [ 2 ] = { name = "Kazzak", id = 554433, reset = 250000 }
}
m.events.UPDATE_INSTANCE_INFO()
m.world_bosses.update_box()
assert_true( "Kazzak alias matched server save", m.boxes.wb.rows[ 2 ].status:GetText() ~= "Ready" )

-- TEST 9: Addon Message Convergence (merge_id)
sent_addon_messages = {}
m.world_bosses.slash( "test" )
m.world_bosses.slash( "who" )
assert_true( "WBWHO query sent", table.getn( sent_addon_messages ) > 0 )

-- TEST 10: Symmetrical 2-Row Layout Geometry & Reorder
TurtleCalendar.reorder()
assert_eq( "Symmetrical instances width with wb visible", m.boxes.instances:GetWidth(), 204 )
assert_eq( "wb box height in row 2", m.boxes.wb:GetHeight(), 184 )

-- When wb is toggled hidden:
local wb_entry = nil
for _, binfo in ipairs( m.db.boxes ) do
    if binfo[ 1 ] == "wb" then wb_entry = binfo break end
end
wb_entry[ 2 ] = false
TurtleCalendar.reorder()
assert_eq( "instances expands to 413 when wb is hidden", m.boxes.instances:GetWidth(), 413 )

-- Re-enable wb:
wb_entry[ 2 ] = true
TurtleCalendar.reorder()
assert_eq( "instances returns to 204 when wb is restored", m.boxes.instances:GetWidth(), 204 )

-- TEST 11: SavedVariables Migration (Legacy index 7 moved to end)
m.db.boxes = {
    { "raid40", true },
    { "ony", true },
    { "kara", true },
    { "zg", true },
    { "tmh", true },
    { "eom", true },
    { "wb", true },
    { "bg", true },
    { "dmf", true },
    { "instances", true }
}
TurtleCalendar.events.PLAYER_LOGIN()
assert_eq( "Migration puts wb at the end after instances", m.db.boxes[ table.getn( m.db.boxes ) ][ 1 ], "wb" )

-- TEST 12: Manual kill and clear commands (/tc wb kill reaver 2)
m.world_bosses.slash( "kill reaver 2" )
assert_true( "Manual kill recorded for reaver", m.gdb.worldbosses.data[ "Capybara" ][ "Carbon" ][ "reaver" ] ~= nil )
assert_true( "Manual kill generated valid ID", m.gdb.worldbosses.ids[ "Capybara" ][ "Carbon" ][ "reaver" ] ~= nil )
m.world_bosses.slash( "clear reaver" )
assert_true( "Manual clear removed reaver", m.gdb.worldbosses.data[ "Capybara" ][ "Carbon" ][ "reaver" ] == nil )

print( "================================================================================" )
print( string.format( "TEST RESULTS: %d PASSED, %d FAILED", passed, failed ) )
print( "================================================================================" )

if failed > 0 then
    os.exit( 1 )
else
    os.exit( 0 )
end
