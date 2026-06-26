--[[
  Modular UI System for Ink-Inspired Dialogue Framework

  This provides a flexible, component-based UI system that can be customized
  for different game types (visual novels, RPGs, adventure games, etc.)

  Architecture:
    - DialogueUI: Main UI manager
    - Components: Swappable UI pieces (TextBox, ChoiceList, etc.)
    - Customizable styling and positioning

  Components can be enabled/disabled per scene, and custom components
  can be easily added by extending the base component class.
]]

local DialogueUI = {}
DialogueUI.__index = DialogueUI

--[[
  Component Base Class

  All UI components inherit from this base class.
  Custom components should implement these methods:
    - draw() - Render the component
    - update(dt) - Update component state
    - mousepressed(x, y, button) - Handle mouse clicks
    - keypressed(key) - Handle keyboard input
]]
local Component = {}
Component.__index = Component

function Component:new(id)
  local obj = setmetatable({}, self)
  obj.id = id
  obj.enabled = true
  obj.visible = true
  return obj
end

function Component:draw() end
function Component:update(dt) end
function Component:mousepressed(x, y, button) end
function Component:keypressed(key) end

--[[
  TextBox Component

  Displays dialogue text with optional typewriter effect and speaker name.

  Configuration:
    - x, y, width, height: Position and size
    - padding: Internal padding
    - background_color: Box background
    - text_color: Text color
    - typewriter_speed: Characters per second (0 = instant)
    - font: Text font
]]
local TextBox = setmetatable({}, {__index = Component})
TextBox.__index = TextBox

function TextBox:new(config)
  local obj = Component.new(self, "textbox")

  -- Default configuration
  obj.x = config.x or 50
  obj.y = config.y or 400
  obj.width = config.width or 700
  obj.height = config.height or 150
  obj.padding = config.padding or 20

  obj.background_color = config.background_color or {0.1, 0.1, 0.15, 0.9}
  obj.text_color = config.text_color or {1, 1, 1, 1}
  obj.border_color = config.border_color or {0.3, 0.3, 0.4, 1}

  obj.typewriter_speed = config.typewriter_speed or 30 -- chars per second
  obj.font = config.font or love.graphics.getFont()

  -- State
  obj.current_text = ""
  obj.display_text = ""
  obj.current_speaker = nil
  obj.typewriter_progress = 0
  obj.is_complete = false

  return obj
end

function TextBox:setText(text, speaker)
  self.current_text = text or ""
  self.current_speaker = speaker
  self.display_text = ""
  self.typewriter_progress = 0
  self.is_complete = false
end

function TextBox:skipTypewriter()
  self.display_text = self.current_text
  self.typewriter_progress = #self.current_text
  self.is_complete = true
end

function TextBox:update(dt)
  if not self.is_complete then
    if self.typewriter_speed > 0 then
      self.typewriter_progress = self.typewriter_progress + self.typewriter_speed * dt
      local chars_to_show = math.floor(self.typewriter_progress)

      if chars_to_show >= #self.current_text then
        self.display_text = self.current_text
        self.is_complete = true
      else
        self.display_text = string.sub(self.current_text, 1, chars_to_show)
      end
    else
      -- Instant display
      self:skipTypewriter()
    end
  end
end

function TextBox:draw()
  if not self.visible then return end

  -- Draw background
  love.graphics.setColor(self.background_color)
  love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)

  -- Draw border
  love.graphics.setColor(self.border_color)
  love.graphics.rectangle("line", self.x, self.y, self.width, self.height)

  -- Draw speaker name if present
  local text_y = self.y + self.padding
  if self.current_speaker then
    love.graphics.setColor(0.7, 0.9, 1, 1) -- Light blue for speaker names
    love.graphics.setFont(self.font)
    love.graphics.print(self.current_speaker, self.x + self.padding, text_y)
    text_y = text_y + self.font:getHeight() + 5
  end

  -- Draw text with word wrap
  love.graphics.setColor(self.text_color)
  love.graphics.setFont(self.font)

  local max_width = self.width - (self.padding * 2)
  local _, wrapped_text = self.font:getWrap(self.display_text, max_width)

  for i, line in ipairs(wrapped_text) do
    love.graphics.print(line, self.x + self.padding, text_y)
    text_y = text_y + self.font:getHeight()
  end

  -- Draw continue indicator if complete
  if self.is_complete then
    love.graphics.setColor(1, 1, 1, 0.5 + 0.5 * math.sin(love.timer.getTime() * 4))
    local indicator = "▼"
    local indicator_width = self.font:getWidth(indicator)
    love.graphics.print(indicator,
      self.x + self.width - self.padding - indicator_width,
      self.y + self.height - self.padding - self.font:getHeight())
  end
end

function TextBox:mousepressed(x, y, button)
  if not self.enabled then return false end

  -- Check if click is within textbox
  if x >= self.x and x <= self.x + self.width and
     y >= self.y and y <= self.y + self.height then
    if not self.is_complete then
      self:skipTypewriter()
      return true
    end
  end
  return false
end

--[[
  ChoiceList Component

  Displays clickable choice buttons for player decisions.

  Configuration:
    - x, y: Starting position
    - width: Button width
    - spacing: Space between buttons
    - button_height: Height of each button
    - font: Text font
]]
local ChoiceList = setmetatable({}, {__index = Component})
ChoiceList.__index = ChoiceList

function ChoiceList:new(config)
  local obj = Component.new(self, "choicelist")

  obj.x = config.x or 100
  obj.y = config.y or 250
  obj.width = config.width or 600
  obj.button_height = config.button_height or 40
  obj.spacing = config.spacing or 10
  obj.padding = config.padding or 10

  obj.normal_color = config.normal_color or {0.2, 0.2, 0.3, 0.9}
  obj.hover_color = config.hover_color or {0.3, 0.3, 0.5, 0.9}
  obj.text_color = config.text_color or {1, 1, 1, 1}
  obj.border_color = config.border_color or {0.5, 0.5, 0.6, 1}

  obj.font = config.font or love.graphics.getFont()

  obj.choices = {}
  obj.prompt = nil
  obj.hovered_index = nil
  obj.on_choice = nil -- Callback function

  return obj
end

function ChoiceList:setChoices(choices, prompt, callback)
  self.choices = choices or {}
  self.prompt = prompt
  self.on_choice = callback
  self.hovered_index = nil
end

function ChoiceList:clear()
  self.choices = {}
  self.prompt = nil
  self.hovered_index = nil
end

function ChoiceList:update(dt)
  -- Update hover state
  local mx, my = love.mouse.getPosition()
  self.hovered_index = nil

  local start_y = self.y
  if self.prompt then
    start_y = start_y + self.font:getHeight() + self.spacing
  end

  for i, choice in ipairs(self.choices) do
    local button_y = start_y + (i - 1) * (self.button_height + self.spacing)

    if mx >= self.x and mx <= self.x + self.width and
       my >= button_y and my <= button_y + self.button_height then
      self.hovered_index = i
      break
    end
  end
end

function ChoiceList:draw()
  if not self.visible or #self.choices == 0 then return end

  local draw_y = self.y

  -- Draw prompt if present
  if self.prompt then
    love.graphics.setColor(self.text_color)
    love.graphics.setFont(self.font)
    love.graphics.print(self.prompt, self.x, draw_y)
    draw_y = draw_y + self.font:getHeight() + self.spacing
  end

  -- Draw choice buttons
  for i, choice in ipairs(self.choices) do
    local button_y = draw_y + (i - 1) * (self.button_height + self.spacing)
    local is_hovered = (i == self.hovered_index)

    -- Draw button background
    if is_hovered then
      love.graphics.setColor(self.hover_color)
    else
      love.graphics.setColor(self.normal_color)
    end
    love.graphics.rectangle("fill", self.x, button_y, self.width, self.button_height)

    -- Draw button border
    love.graphics.setColor(self.border_color)
    love.graphics.rectangle("line", self.x, button_y, self.width, self.button_height)

    -- Draw choice text
    love.graphics.setColor(self.text_color)
    love.graphics.setFont(self.font)

    local choice_text = type(choice) == "string" and choice or choice[1]
    local text_x = self.x + self.padding
    local text_y = button_y + (self.button_height - self.font:getHeight()) / 2

    love.graphics.print(choice_text, text_x, text_y)
  end
end

function ChoiceList:mousepressed(x, y, button)
  if not self.enabled or button ~= 1 then return false end

  local start_y = self.y
  if self.prompt then
    start_y = start_y + self.font:getHeight() + self.spacing
  end

  for i, choice in ipairs(self.choices) do
    local button_y = start_y + (i - 1) * (self.button_height + self.spacing)

    if x >= self.x and x <= self.x + self.width and
       y >= button_y and y <= button_y + self.button_height then
      if self.on_choice then
        self.on_choice(i)
      end
      return true
    end
  end

  return false
end

--[[
  DialogueUI Manager

  Manages all UI components and coordinates between dialogue engine and display.
]]
function DialogueUI.new(config)
  local self = setmetatable({}, DialogueUI)

  config = config or {}

  -- Create components
  self.components = {}

  -- Create textbox
  self.textbox = TextBox:new(config.textbox or {})
  table.insert(self.components, self.textbox)

  -- Create choice list
  self.choicelist = ChoiceList:new(config.choicelist or {})
  table.insert(self.components, self.choicelist)

  -- State
  self.current_content = nil
  self.waiting_for_input = false

  return self
end

--[[
  Show content from the dialogue engine

  @param content table - Content object from Dialogue:getNext()
]]
function DialogueUI:showContent(content)
  self.current_content = content
  self.waiting_for_input = false

  if not content then
    return
  end

  if content.type == "text" then
    self.textbox:setText(content.content, content.speaker)
    self.choicelist:clear()
    self.waiting_for_input = true

  elseif content.type == "choice" then
    self.textbox:setText("", nil) -- Clear textbox
    self.choicelist:setChoices(content.options, content.prompt, function(index)
      if self.on_choice_made then
        self.on_choice_made(index)
      end
    end)

  elseif content.type == "end" then
    self.textbox:setText("", nil)
    self.choicelist:clear()
  end
end

function DialogueUI:update(dt)
  for _, component in ipairs(self.components) do
    if component.enabled then
      component:update(dt)
    end
  end
end

function DialogueUI:draw()
  for _, component in ipairs(self.components) do
    if component.visible then
      component:draw()
    end
  end
end

function DialogueUI:mousepressed(x, y, button)
  -- Check components in reverse order (top to bottom)
  for i = #self.components, 1, -1 do
    local component = self.components[i]
    if component.enabled and component:mousepressed(x, y, button) then
      return true
    end
  end

  return false
end

function DialogueUI:isTextComplete()
  return self.textbox.is_complete
end

function DialogueUI:skipTypewriter()
  self.textbox:skipTypewriter()
end

--[[
  EXTENSION POINTS:

  Additional components that could be added:
    - Portrait: Display character images
    - NamePlate: Styled speaker name box
    - BacklogView: Scrollable dialogue history
    - AutoPlayButton: Toggle automatic progression
    - SaveLoadMenu: Save/load dialogue state
    - SettingsPanel: Adjust text speed, volume, etc.

  Each component would follow the same pattern:
    1. Inherit from Component base class
    2. Implement draw(), update(), and input methods
    3. Add to DialogueUI.components table
]]

return DialogueUI

