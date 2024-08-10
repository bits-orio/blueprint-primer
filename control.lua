local mod_gui = require("mod-gui")

-- Initialize global variables
script.on_init(function()
    global.players = global.players or {}
    for _, player in pairs(game.players) do
        global.players[player.index] = global.players[player.index] or {}
        global.players[player.index].max_stack =
            global.players[player.index].max_stack or false
    end
    global.preferred_fuel = global.preferred_fuel or "coal"
end)

-- Function to get valid and unlocked recipes for an entity
local function get_valid_recipes(entity_name, force)
    local entity_prototype = game.entity_prototypes[entity_name]
    if not entity_prototype then return {} end

    local valid_recipes = {}
    if entity_prototype.type == "assembling-machine" or entity_prototype.type ==
        "furnace" or entity_prototype.type == "rocket-silo" then
        for recipe_name, recipe in pairs(force.recipes) do
            if recipe.enabled and
                entity_prototype.crafting_categories[recipe.category] then
                valid_recipes[recipe_name] = recipe
            end
        end
    elseif entity_prototype.type == "boiler" then
        valid_recipes["steam"] = {
            name = "steam",
            ingredients = {{type = "fluid", name = "water", amount = 60}}
        }
    end

    return valid_recipes
end

-- Function to check if an entity uses fuel
local function entity_uses_fuel(entity_name)
    local entity_prototype = game.entity_prototypes[entity_name]
    return entity_prototype and entity_prototype.burner_prototype ~= nil
end

-- Function to create the GUI
local function create_gui(player)
    local button_flow = mod_gui.get_button_flow(player)
    if not button_flow.blueprint_primer_button then
        button_flow.add {
            type = "button",
            name = "blueprint_primer_button",
            caption = "Prime Blueprint",
            style = mod_gui.button_style
        }
    end
end

-- Function to prime the blueprint
local function prime_blueprint(player, input_name)
    local cursor_stack = player.cursor_stack
    if not cursor_stack or not cursor_stack.valid or
        not cursor_stack.valid_for_read or cursor_stack.type ~= "blueprint" then
        player.print("No valid blueprint in cursor")
        return
    end

    local blueprint = cursor_stack
    if not blueprint.is_blueprint_setup() then
        player.print("Blueprint is not set up")
        return
    end

    local entities = blueprint.get_blueprint_entities()
    if not entities then
        player.print("No entities in blueprint")
        return
    end

    local max_stack = global.players[player.index].max_stack

    local primed = false
    for _, entity in pairs(entities) do
        local entity_prototype = game.entity_prototypes[entity.name]
        if entity_prototype.type == "assembling-machine" or
            entity_prototype.type == "furnace" or entity_prototype.type ==
            "rocket-silo" then
            local entity_recipe = entity.recipe

            local recipe_to_use = entity_recipe
            if not recipe_to_use then
                if player.force.recipes[input_name] and
                    player.force.recipes[input_name].enabled then
                    recipe_to_use = input_name
                else
                    local valid_recipes =
                        get_valid_recipes(entity.name, player.force)
                    recipe_to_use = next(valid_recipes)
                end
            end

            if recipe_to_use then
                local recipe = player.force.recipes[recipe_to_use]
                if recipe and recipe.enabled then
                    entity.recipe = recipe_to_use

                    entity.items = {}
                    for _, ingredient in pairs(recipe.ingredients) do
                        local item_name = ingredient.name
                        local item_count = max_stack and
                                               game.item_prototypes[item_name]
                                                   .stack_size or
                                               ingredient.amount
                        entity.items[item_name] = item_count
                    end

                    primed = true
                end
            end
        end

        -- Add fuel for entities that use fuel
        if entity_uses_fuel(entity.name) then
            local fuel_count = max_stack and
                                   game.item_prototypes[global.preferred_fuel]
                                       .stack_size or 1
            entity.items = entity.items or {}
            entity.items[global.preferred_fuel] = fuel_count
        end
    end

    if primed then
        blueprint.set_blueprint_entities(entities)
        player.print("Blueprint primed successfully")
    else
        player.print("No suitable entities found for priming")
    end
end

-- Function to toggle the GUI
local function toggle_gui(player)
    if not player or not player.valid then
        log("Invalid player in toggle_gui")
        return
    end

    local frame_flow = mod_gui.get_frame_flow(player)
    if not frame_flow then
        log("No frame flow for player " .. player.name)
        return
    end

    local main_frame = frame_flow.blueprint_primer_frame

    if main_frame then
        main_frame.destroy()
    else
        local cursor_stack = player.cursor_stack
        if cursor_stack and cursor_stack.valid and cursor_stack.valid_for_read and
            cursor_stack.type == "blueprint" then
            local blueprint = cursor_stack
            if blueprint.is_blueprint_setup() then
                local entities = blueprint.get_blueprint_entities()
                if entities then
                    local needs_recipe_selection = false
                    local uses_fuel = false

                    for _, entity in pairs(entities) do
                        if entity and entity.name then
                            if (game.entity_prototypes[entity.name].type ==
                                "assembling-machine" or
                                game.entity_prototypes[entity.name].type ==
                                "furnace" or
                                game.entity_prototypes[entity.name].type ==
                                "rocket-silo") and not entity.recipe then
                                needs_recipe_selection = true
                            end
                            if entity_uses_fuel(entity.name) then
                                uses_fuel = true
                            end
                        end
                    end

                    if needs_recipe_selection then
                        main_frame = frame_flow.add {
                            type = "frame",
                            name = "blueprint_primer_frame",
                            direction = "vertical"
                        }
                        main_frame.add {
                            type = "label",
                            caption = "Blueprint Primer"
                        }

                        local content_frame = main_frame.add {
                            type = "frame",
                            name = "content_frame",
                            direction = "vertical",
                            style = "inside_shallow_frame"
                        }

                        local recipe_flow = content_frame.add {
                            type = "flow",
                            name = "recipe_flow",
                            direction = "vertical"
                        }
                        recipe_flow.add {
                            type = "label",
                            caption = "Select Recipe:"
                        }

                        local recipe_tabbed_pane = recipe_flow.add {
                            type = "tabbed-pane",
                            name = "recipe_tabbed_pane"
                        }
                        local valid_recipes = get_valid_recipes(
                                                  entities[1].name, player.force)
                        local categories = {}

                        for _, recipe in pairs(valid_recipes) do
                            if not categories[recipe.category] then
                                categories[recipe.category] = {}
                            end
                            table.insert(categories[recipe.category], recipe)
                        end

                        for category, recipes in pairs(categories) do
                            local tab = recipe_tabbed_pane.add {
                                type = "tab",
                                caption = category
                            }
                            local tab_content =
                                recipe_tabbed_pane.add {
                                    type = "flow",
                                    direction = "vertical"
                                }
                            recipe_tabbed_pane.add_tab(tab, tab_content)

                            local recipe_table = tab_content.add {
                                type = "table",
                                column_count = 10
                            }
                            for _, recipe in pairs(recipes) do
                                recipe_table.add {
                                    type = "sprite-button",
                                    sprite = "recipe/" .. recipe.name,
                                    tooltip = recipe.localised_name,
                                    name = "prime_" .. recipe.name,
                                    style = "slot_button"
                                }
                            end
                        end

                        content_frame.add {
                            type = "checkbox",
                            name = "max_stack",
                            caption = "Max stack",
                            state = global.players[player.index].max_stack
                        }

                        if uses_fuel then
                            local fuel_flow = content_frame.add {
                                type = "flow",
                                name = "fuel_flow",
                                direction = "horizontal"
                            }
                            fuel_flow.add {
                                type = "label",
                                caption = "Preferred fuel:"
                            }
                            local fuel_dropdown = fuel_flow.add {
                                type = "drop-down",
                                name = "fuel_dropdown"
                            }

                            local fuels = {}
                            for item_name, item in pairs(game.item_prototypes) do
                                if item.fuel_value > 0 then
                                    table.insert(fuels, item_name)
                                end
                            end
                            table.sort(fuels)

                            for i, fuel_name in ipairs(fuels) do
                                fuel_dropdown.add_item(fuel_name)
                                if fuel_name == global.preferred_fuel then
                                    fuel_dropdown.selected_index = i
                                end
                            end

                            if not fuel_dropdown.selected_index then
                                fuel_dropdown.selected_index = 1
                                global.preferred_fuel = fuels[1] or "coal"
                            end
                        end
                    else
                        prime_blueprint(player)
                    end
                else
                    player.print("Blueprint has no entities")
                end
            else
                player.print("Blueprint is not set up")
            end
        else
            player.print("No valid blueprint in cursor")
        end
    end
end

-- Event handlers
script.on_event(defines.events.on_gui_click, function(event)
    local player = game.players[event.player_index]
    local element = event.element

    if not player or not player.valid or not element or not element.valid then
        return
    end

    if element.name == "blueprint_primer_button" then
        toggle_gui(player)
    elseif element.name:sub(1, 6) == "prime_" then
        local recipe_name = element.name:sub(7)
        prime_blueprint(player, recipe_name)
        -- Hide the expanded GUI after recipe selection
        local frame_flow = mod_gui.get_frame_flow(player)
        if frame_flow.blueprint_primer_frame then
            frame_flow.blueprint_primer_frame.destroy()
        end
    end
end)

script.on_event(defines.events.on_gui_checked_state_changed, function(event)
    local player = game.players[event.player_index]
    local element = event.element
    if element.name == "max_stack" then
        global.players[player.index].max_stack = element.state
    end
end)

script.on_event(defines.events.on_gui_selection_state_changed, function(event)
    local element = event.element
    if element.name == "fuel_dropdown" then
        global.preferred_fuel = element.get_item(element.selected_index)
    end
end)

script.on_event("blueprint-primer-toggle-gui", function(event)
    local player = game.players[event.player_index]
    toggle_gui(player)
end)

script.on_configuration_changed(function(data)
    for _, player in pairs(game.players) do create_gui(player) end
end)

script.on_event(defines.events.on_player_created, function(event)
    local player = game.players[event.player_index]
    global.players[player.index] = global.players[player.index] or {}
    global.players[player.index].max_stack =
        global.players[player.index].max_stack or false
    create_gui(player)
end)
