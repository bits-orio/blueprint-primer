-- The controls every part of the priming window builds the same way (a
-- button, a number field, a slider) and the two setters that refresh them.
-- Shared by the recipe rows and items mode's table, so both look and
-- behave alike.

local widgets = {}

-- The narrowest a button gets; a longer caption widens it.
widgets.BUTTON_WIDTH = 56

-- `tooltip` defaults to the caption's own "-tooltip" key.
function widgets.button(flow, name, key, tooltip, tags)
  local button = flow.add({
    type = "button", name = name, caption = { "bp-primer." .. key },
    tooltip = tooltip or { "bp-primer." .. key .. "-tooltip" }, tags = tags,
  })
  button.style.minimal_width = widgets.BUTTON_WIDTH
  return button
end

-- Every typed amount in the window: whole, non-negative numbers.
function widgets.number_field(flow, name, tooltip, tags)
  return flow.add({
    type = "textfield", name = name, style = "slider_value_textfield", tags = tags,
    tooltip = tooltip, numeric = true, allow_decimal = false, allow_negative = false,
    lose_focus_on_confirm = true,
  })
end

-- Starts on a placeholder range, since the engine refuses a minimum equal
-- to the maximum; the view sets the real one.
function widgets.slider(flow, name, tooltip, tags)
  return flow.add({
    type = "slider", name = name, tooltip = tooltip, tags = tags,
    minimum_value = 0, maximum_value = 1, value = 1, value_step = 1, discrete_values = true,
  })
end

-- A range of one value (or none) shows as a disabled 0..1 slider. The
-- engine moves the knob only when the value changes, so a new range with
-- the same value would leave it where the old range put it (seen in a
-- chest's items lines, whose ranges follow the other rows): the value is
-- nudged to the other end first.
function widgets.set_slider(slider, value, max)
  local low, high = 1, max
  if max < 2 then low, high = 0, 1 end
  slider.set_slider_minimum_maximum(low, high)
  slider.enabled = max >= 2
  slider.slider_value = value == low and high or low
  slider.slider_value = value
end

-- The field being typed into is left alone, or every keystroke would be
-- rewritten mid-number.
function widgets.set_text(field, value, skip)
  if field.name ~= skip then field.text = tostring(value) end
end

return widgets
