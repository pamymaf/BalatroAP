--- STEAMODDED HEADER
--- MOD_NAME: Randomizer
--- MOD_ID: Rando
--- MOD_AUTHOR: [Burndi, Silvris]
--- MOD_DESCRIPTION: Archipelago
----------------------------------------------
------------MOD CODE -------------------------
-- TODO
-- TECH:
-- make most functions only execute when balatro profile is loaded 
-- load Balatro profile 
-- disconnect when other profile is loaded
-- parse AP messages 
-- map ids to checks
-- lock/unlock decks depending on AP 
-- FEATURES:
-- 
-- Traps: Discard random cards, boss blinds
-- Hint Pack
-- When Deathlink: joker will tell you the cause
G.AP = {
    APAddress = "localhost",
    APPort = 38281,
    APSlot = "Player1",
    APPassword = "",
    id_offset = 5606000
}

G.AP.this_mod = SMODS.current_mod

require(G.AP.this_mod.path .. "ap_connection")
require(G.AP.this_mod.path .. "utils")
json = require(G.AP.this_mod.path .. "json")
AP = require('lua-apclientpp')

local isInProfileTabCreation = false
local isInProfileOptionCreation = false
local unloadAPProfile = false
G.AP.profile_Id = -1
G.AP.queue_deathLink = false

function isAPProfileLoaded()
    -- if G.SETTINGS == nil then
    --     return false
    -- end
    return G.SETTINGS.profile == G.AP.profile_Id
end

function isAPProfileSelected()
    return G.focused_profile == G.AP.profile_Id
end

G.FUNCS.APConnect = function()
    local APInfo = json.encode(G.AP)
    save_file('APSettings.json', APInfo)

    APConnect()
end

G.FUNCS.APDisconnect = function()
    G.APClient = nil
    collectgarbage("collect") -- or collectgarbage("step")
    unloadAPProfile = true

end

-- DeathLink 

G.FUNCS.die = function()
    -- check if in run, otherwise dont queue (TODO)

    G.E_MANAGER:add_event(Event({
        trigger = 'immediate',
        delay = 0.2,
        func = function()
            G.STATE = G.STATES.GAME_OVER
            if not G.GAME.won and not G.GAME.seeded and not G.GAME.challenge then
                G.PROFILES[G.SETTINGS.profile].high_scores.current_streak.amt = 0
            end
            G:save_settings()
            G.FILE_HANDLER.force = true
            G.STATE_COMPLETE = false
            return true
        end

    }))
end

-- make joker say death link cause, not working yet

local localizeRef = localize
function localize(args, misc_cat)
    local localize = ''
    if args and args.type == 'quip' and args.key == 'deathlink' then
        G.localization.quips_parsed['deathlink'] = {
            multi_line = true
        }
        for k, v in ipairs(G.AP.death_link_cause) do
            G.localization.quips_parsed['deathlink'][k] = loc_parse_string(v)
        end

        G.AP.death_link_cause = nil
    end

    localize = localizeRef(args, misc_cat)

    return localize
end

local add_speech_bubbleRef = Card_Character.add_speech_bubble
function Card_Character.add_speech_bubble(args, text_key, align, loc_vars)
    -- sendDebugMessage(tostring(G.AP.death_link_cause))
    if G.AP.death_link_cause and loc_vars and loc_vars.quip then
        text_key = 'deathlink'
    end

    local add_speech_bubble = add_speech_bubbleRef(args, text_key, align, loc_vars)

    return add_speech_bubble
end

-- Profile interface

local create_tabsRef = create_tabs
function create_tabs(args)
    -- when profile interface is created, add archipelago tab 
    if isInProfileTabCreation then
        args.tabs[G.AP.profile_Id] = {
            label = "ARCHIPELAGO",
            chosen = G.focused_profile == G.AP.profile_Id,
            tab_definition_function = G.UIDEF.profile_option,
            tab_definition_function_args = G.AP.profile_Id
        }
    end

    local create_tabs = create_tabsRef(args)

    return create_tabs
end

local profile_selectRef = G.UIDEF.profile_select
function G.UIDEF.profile_select()
    isInProfileTabCreation = true

    local profile_select = profile_selectRef()

    isInProfileTabCreation = false
    return profile_select
end

local create_text_inputRef = create_text_input
function create_text_input(args)
    local create_text_input = create_text_inputRef(args)

    if isInProfileOptionCreation then

        create_text_input['config']['draw_layer'] = nil
        create_text_input['nodes'][1]['config']['draw_layer'] = nil

        local ui_letters = create_text_input['nodes'][1]['nodes'][1]['nodes'][1]['nodes'][1]
        -- sendDebugMessage("Is not null: " .. tostring(#ui_letters))

        if #ui_letters > 0 then
            ui_letters[#ui_letters]['config']['id'] = 'position_' .. args.prompt_text
        end
    end

    return create_text_input
end

local profile_optionRef = G.UIDEF.profile_option
function G.UIDEF.profile_option(_profile)
    G.focused_profile = _profile
    if isAPProfileSelected() then -- AP profile tab code

        isInProfileOptionCreation = true
        local t = {
            n = G.UIT.ROOT,
            config = {
                align = 'cm',
                colour = G.C.CLEAR
            },
            nodes = {{
                n = G.UIT.R,
                config = {
                    align = 'cm',
                    padding = 0.1,
                    minh = 0.8
                },
                nodes = {((_profile == G.SETTINGS.profile) or not profile_data) and {
                    n = G.UIT.R,
                    config = {
                        align = "cm"
                    },
                    nodes = {create_text_input({
                        w = 4,
                        max_length = 16,
                        prompt_text = 'Server Address',
                        ref_table = G.AP,
                        ref_value = 'APAddress',
                        extended_corpus = true,
                        keyboard_offset = 1,
                        callback = function()
                            -- code for when enter is hit (?)
                        end
                    }), create_text_input({
                        w = 4,
                        max_length = 16,
                        prompt_text = 'PORT',
                        ref_table = G.AP,
                        ref_value = 'APPort',
                        extended_corpus = false,
                        keyboard_offset = 1,
                        callback = function()
                            -- code for when enter is hit (?)
                        end
                    })}
                }}
            }, {
                n = G.UIT.R,
                config = {
                    align = 'cm',
                    padding = 0.1,
                    minh = 0.8
                },
                nodes = {((_profile == G.SETTINGS.profile) or not profile_data) and {
                    n = G.UIT.R,
                    config = {
                        align = "cm"
                    },
                    nodes = {create_text_input({
                        w = 4,
                        max_length = 16,
                        prompt_text = 'Slot name',
                        ref_table = G.AP,
                        ref_value = 'APSlot',
                        extended_corpus = true,
                        keyboard_offset = 1,
                        callback = function()
                            -- code for when enter is hit (?)
                        end
                    }), create_text_input({
                        w = 4,
                        max_length = 16,
                        prompt_text = 'Password',
                        ref_table = G.AP,
                        ref_value = 'APPassword',
                        extended_corpus = true,
                        keyboard_offset = 1,
                        callback = function()
                            -- code for when enter is hit (?)
                        end
                    })}
                }}
            }, UIBox_button({
                button = "APConnect",
                label = {"Connect"},
                minw = 3,
                Func = G.FUNCS.APConnect
            }), {
                n = G.UIT.R,
                config = {
                    align = "cm",
                    padding = 0,
                    minh = 0.7
                },
                nodes = {{
                    n = G.UIT.R,
                    config = {
                        align = "cm",
                        minw = 3,
                        maxw = 4,
                        minh = 0.6,
                        padding = 0.2,
                        r = 0.1,
                        hover = true,
                        colour = G.C.RED,
                        func = 'can_delete_AP_profile',
                        button = "delete_profile",
                        shadow = true,
                        focus_args = {
                            nav = 'wide'
                        }
                    },
                    nodes = {{
                        n = G.UIT.T,
                        config = {
                            text = _profile == G.SETTINGS.profile and localize('b_reset_profile') or
                                localize('b_delete_profile'),
                            scale = 0.3,
                            colour = G.C.UI.TEXT_LIGHT
                        }
                    }}
                }}
            }, {
                n = G.UIT.R,
                config = {
                    align = "cm",
                    padding = 0
                },
                nodes = {{
                    n = G.UIT.T,
                    config = {
                        id = 'warning_text',
                        text = localize('ph_click_confirm'),
                        scale = 0.4,
                        colour = G.C.CLEAR
                    }
                }}
            }}
        }
        isInProfileOptionCreation = false
        return t

    else -- if not AP profile behave normally

        local profile_option = profile_optionRef(_profile)
        return profile_option
    end

end

-- game changes

local game_updateRef = Game.update
function Game.update(arg_298_0, dt)
    local game_update = game_updateRef(arg_298_0, dt)
    if G.APClient ~= nil then
        G.APClient:poll()
    end

    return game_update
end

local game_drawRef = Game.draw
function Game.draw(args)
    local game_draw = game_drawRef(args)

    if G.APClient ~= nil and G.APClient:get_state() == AP.State.SLOT_CONNECTED then
        love.graphics.print("Connected to Archipelago at " .. G.AP.APAddress .. ":" .. G.AP.APPort .. " as " ..
                                G.AP.APSlot, 10, 30)
        -- print("connected")
    else
        love.graphics.print("Not connected to Archipelago.", 10, 30)
    end

    return game_draw
end

-- load APSettings when opening Profile Select
-- also create new profile when first loading (might have to move this somewhere more fitting)

local game_load_profileRef = Game.load_profile
function Game.load_profile(args, _profile)

    

    if unloadAPProfile then
        _profile = 1
        unloadAPProfile = false
    end

    if G.AP.profile_Id == -1 then
        G.AP.profile_Id = #G.PROFILES + 1
        G.PROFILES[G.AP.profile_Id] = {}
        sendDebugMessage("Created AP Profile in Slot " .. tostring(G.AP.profile_Id))
    end

    local game_load_profile = game_load_profileRef(args, _profile)

    local APSettings = load_file('APSettings.json')

    APSettings = json.decode(APSettings)

    if APSettings ~= nil then
        G.AP.APSlot = APSettings['APSlot']
        G.AP.APAddress = APSettings['APAddress']
        G.AP.APPort = APSettings['APPort']
        G.AP.APPassword = APSettings['APPassword']
    end

    return game_load_profile
end

-- handle profile deletion
G.FUNCS.can_delete_AP_profile = function(e)
    G.AP.CHECK_PROFILE_DATA = G.AP.CHECK_PROFILE_DATA or
                                  love.filesystem.getInfo(G.AP.profile_Id .. '/' .. 'profile.jkr')
    if (not G.AP.CHECK_PROFILE_DATA) or e.config.disable_button then
        G.AP.CHECK_PROFILE_DATA = false
        e.config.colour = G.C.UI.BACKGROUND_INACTIVE
        e.config.button = nil
    else
        e.config.colour = G.C.RED
        e.config.button = 'delete_AP_profile'
    end
end

local ap_profile_delete = false

G.FUNCS.delete_AP_profile = function(e)
    if ap_profile_delete then 
        G.FUNCS.APDisconnect()
        ap_profile_delete = false
    end
    G.FUNCS.delete_profile(e)
    ap_profile_delete = true
    G.AP.CHECK_PROFILE_DATA = nil
    
end


-- When Load Profile Button is clicked
local load_profile_funcRef = G.FUNCS.load_profile

G.FUNCS.load_profile = function(delete_prof_data)
    if isAPProfileLoaded() and not isAPProfileSelected() and G.APClient ~= nil then
        G.FUNCS.APDisconnect()
    end
    return load_profile_funcRef(delete_prof_data)
end

-- other stuff 

-- (not tested)
-- Here you can unlock checks

local check_for_unlockRef = check_for_unlock
function check_for_unlock(args)
    local check_for_unlock = check_for_unlockRef(args)
    if isAPProfileLoaded() then
        if args.type == 'ante_up' then
            sendDebugMessage("args.type is ante_up")
            -- when an ante is beaten
            local deck_name = G.GAME.selected_back.name
            local stake = get_deck_win_stake()

            sendDebugMessage("deck_name is " .. deck_name)
            -- specify the deck
            if deck_name == 'Red Deck' then
                sendLocationCleared(G.AP.id_offset + (args.ante - 2) * 8 + (G.GAME.stake - 1))
            elseif deck_name == 'Blue Deck' then
                sendLocationCleared(G.AP.id_offset + 64 + (args.ante - 2) * 8 + (G.GAME.stake - 1))
            elseif deck_name == 'Yellow Deck' then
                sendLocationCleared(G.AP.id_offset + 64 * 2 + (args.ante - 2) * 8 + (G.GAME.stake - 1))
            elseif deck_name == 'Green Deck' then
                sendLocationCleared(G.AP.id_offset + 64 * 3 + (args.ante - 2) * 8 + (G.GAME.stake - 1))
            elseif deck_name == 'Black Deck' then
                sendLocationCleared(G.AP.id_offset + 64 * 4 + (args.ante - 2) * 8 + (G.GAME.stake - 1))
            elseif deck_name == 'Magic Deck' then
                sendLocationCleared(G.AP.id_offset + 64 * 5 + (args.ante - 2) * 8 + (G.GAME.stake - 1))
            elseif deck_name == 'Nebula Deck' then
                sendLocationCleared(G.AP.id_offset + 64 * 6 + (args.ante - 2) * 8 + (G.GAME.stake - 1))
            elseif deck_name == 'Ghost Deck' then
                sendLocationCleared(G.AP.id_offset + 64 * 7 + (args.ante - 2) * 8 + (G.GAME.stake - 1))
            elseif deck_name == 'Abandoned Deck' then
                sendLocationCleared(G.AP.id_offset + 64 * 8 + (args.ante - 2) * 8 + (G.GAME.stake - 1))
            elseif deck_name == 'Checkered Deck' then
                sendLocationCleared(G.AP.id_offset + 64 * 9 + (args.ante - 2) * 8 + (G.GAME.stake - 1))
            elseif deck_name == 'Zodiac Deck' then
                sendLocationCleared(G.AP.id_offset + 64 * 10 + (args.ante - 2) * 8 + (G.GAME.stake - 1))
            elseif deck_name == 'Painted Deck' then
                sendLocationCleared(G.AP.id_offset + 64 * 11 + (args.ante - 2) * 8 + (G.GAME.stake - 1))
            elseif deck_name == 'Anaglyph Deck' then
                sendLocationCleared(G.AP.id_offset + 64 * 12 + (args.ante - 2) * 8 + (G.GAME.stake - 1))
            elseif deck_name == 'Plasma Deck' then
                sendLocationCleared(G.AP.id_offset + 64 * 13 + (args.ante - 2) * 8 + (G.GAME.stake - 1))
            elseif deck_name == 'Erratic Deck' then
                sendLocationCleared(G.AP.id_offset + 64 * 14 + (args.ante - 2) * 8 + (G.GAME.stake - 1))
            end
        end

        -- also need to check for goal completions!
    end

    return check_for_unlock
end

function sendLocationCleared(id)
    if G.APClient ~= nil and G.APClient:get_state() == AP.State.SLOT_CONNECTED then
        sendDebugMessage("sendLocationCleared: " .. tostring(id))
        sendDebugMessage("Queuing LocationCheck was successful: " .. tostring(G.APClient:LocationChecks({id})))
    end
end

-- Unlock Decks from received items

G.FUNCS.set_up_APProfile = function()

    sendDebugMessage("set_up_APProfile called")

    G.AP.unlocked_backs = {}
end

-- I couldnt for the life of me figure out how else to easily lock decks, 
-- so i feel like this is a hacky but intuitive solution.

local back_generate_UIRef = Back.generate_UI
function Back.generate_UI(args, other, ui_scale, min_dims, challenge)

    if isAPProfileLoaded() then
        local back_name = args["name"]
        args.effect.center.unlocked = G.AP.unlocked_backs[back_name] == true
        -- sendDebugMessage(args["name"] .. " is unlocked: " .. tostring(args.effect.center.unlocked))

    end

    local back_generate_UI = back_generate_UIRef(args, other, ui_scale, min_dims, challenge)

    return back_generate_UI
end

-- debug

function copy_uncrompessed(_file)
    local file_data = love.filesystem.getInfo(_file)
    if file_data ~= nil then
        local file_string = love.filesystem.read(_file)
        if file_string ~= '' then
            local success = nil
            success, file_string = pcall(love.data.decompress, 'string', 'deflate', file_string)
            love.filesystem.write(_file .. ".txt", file_string)
        end
    end
end

-- fix turning '0' into 'o'
local zeroWasInput = false

local text_input_keyRef = G.FUNCS.text_input_key
function G.FUNCS.text_input_key(args)
    if args.key == '0' then
        zeroWasInput = true
    end

    local text_input_key = text_input_keyRef(args)
    zeroWasInput = false

    return text_input_key

end

local modify_text_inputRef = MODIFY_TEXT_INPUT
function MODIFY_TEXT_INPUT(args)

    if zeroWasInput then
        args.letter = '0'
    end

    local modify_text_input = modify_text_inputRef(args)

    return modify_text_input

end

----------------------------------------------
------------MOD CODE END----------------------
