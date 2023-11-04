
local detailsFramework = _G["DetailsFramework"]
if (not detailsFramework or not DetailsFrameworkCanLoad) then
	return
end

---@cast detailsFramework detailsframework

local CreateFrame = CreateFrame
local unpack = unpack
local wipe = table.wipe
local _

--[=[
    file description: this file has the code for the object editor
    the object editor itself is a frame and has a scrollframe as canvas showing another frame where there's the options for the editing object
    
--]=]


--the editor doesn't know which key in the profileTable holds the current value for an attribute, so it uses a map table to find it.
--the mapTable is a table with the attribute name as a key, and the value is the profile key. For example, {["size"] = "text_size"} means profileTable["text_size"] = 10.

---@class df_editor_attribute
---@field name string
---@field label string
---@field widget string
---@field default any
---@field minvalue number?
---@field maxvalue number?
---@field step number?
---@field usedecimals boolean?
---@field subkey string?

--which object attributes are used to build the editor menu for each object type
local attributes = {
    ---@type df_editor_attribute[]
    FontString = {
        {
            name = "text",
            label = "Text",
            widget = "textentry",
            default = "font string text",
        },
        {
            name = "size",
            label = "Size",
            widget = "range",
            --default = 10,
            minvalue = 5,
            maxvalue = 120,
        },
        {
            name = "font",
            label = "Font",
            widget = "fontdropdown",
            --default = "Friz Quadrata TT",
        },
        {
            name = "color",
            label = "Color",
            widget = "colordropdown",
            --default = "white",
        },
        {
            name = "alpha",
            label = "Alpha",
            widget = "range",
            --default = 1,
        },
        {
            name = "shadow",
            label = "Draw Shadow",
            widget = "toggle",
            --default = true,
        },
        {
            name = "shadowcolor",
            label = "Shadow Color",
            widget = "colordropdown",
            --default = "black",
        },
        {
            name = "shadowoffsetx",
            label = "Shadow X Offset",
            widget = "range",
            --default = 1,
            minvalue = -10,
            maxvalue = 10,
        },
        {
            name = "shadowoffsety",
            label = "Shadow Y Offset",
            widget = "range",
            --default = -1,
            minvalue = -10,
            maxvalue = 10,
        },
        {
            name = "outline",
            label = "Outline",
            widget = "outlinedropdown",
            --default = "NONE",
        },
        {
            name = "monochrome",
            label = "Monochrome",
            widget = "toggle",
            --default = false,
        },
        {
            name = "anchor",
            label = "Anchor",
            widget = "anchordropdown",
            --default = {side = 1, x = 0, y = 0},
            subkey = "side", --anchor is a table with three keys: side, x, y
        },
        {
            name = "anchoroffsetx",
            label = "Anchor X Offset",
            widget = "range",
            --default = 0,
            minvalue = -20,
            maxvalue = 20,
            subkey = "x",
        },
        {
            name = "anchoroffsety",
            label = "Anchor Y Offset",
            widget = "range",
            --default = 0,
            minvalue = -20,
            maxvalue = 20,
            subkey = "y",
        },
        {
            name = "rotation",
            label = "Rotation",
            widget = "range",
            --default = 0,
            usedecimals = true,
            minvalue = 0,
            maxvalue = math.pi*2
        },
    }
}

detailsFramework.EditorMixin = {
    ---@param self df_editor
    GetEditingObject = function(self)
        return self.editingObject
    end,

    ---@param self df_editor
    ---@return table, table
    GetEditingProfile = function(self)
        return self.editingProfileTable, self.editingProfileMap
    end,

    ---@param self df_editor
    ---@return function
    GetOnEditCallback = function(self)
        return self.onEditCallback
    end,

    GetOptionsFrame = function(self)
        return self.optionsFrame
    end,

    GetCanvasScrollBox = function(self)
        return self.canvasScrollBox
    end,

    ---@param self df_editor
    ---@param object uiobject
    ---@param profileTable table
    ---@param profileKeyMap table
    ---@param callback function calls when an attribute is changed with the payload: editingObject, optionName, newValue, profileTable, profileKey
    EditObject = function(self, object, profileTable, profileKeyMap, callback)
        assert(type(object) == "table", "EditObject(object) expects an UIObject on first parameter.")
        assert(type(profileTable) == "table", "EditObject(object) expects a table on second parameter.")
        assert(object.GetObjectType, "EditObject(object) expects an UIObject on first parameter.")

        self.editingObject = object
        self.editingProfileMap = profileKeyMap
        self.editingProfileTable = profileTable
        self.onEditCallback = callback

        self:PrepareObjectForEditing()
    end,

    PrepareObjectForEditing = function(self)
        --get the object and its profile table with the current values
        local object = self:GetEditingObject()
        local profileTable, profileMap = self:GetEditingProfileTable()
        profileMap = profileMap or {}

        if (not object or not profileTable) then
            return
        end

        --get the object type
        local objectType = object:GetObjectType()

        if (objectType == "FontString") then
            local menuOptions = {}
            local fontStringAttributeList = attributes[objectType]

            for i = 1, #fontStringAttributeList do
                local option = fontStringAttributeList[i]

                --get the key to be used on profile table
                local profileKey = profileMap[option.name]
                --get the values from profile table
                local value = profileTable[profileKey] or option.default

                if (value) then
                    local subKey = option.subkey
                    if (subKey) then
                        value = value[subKey]
                    end

                    --test value again as the sub key might not exist
                    if (value) then
                        menuOptions[#menuOptions+1] = {
                            type = option.widget,
                            name = option.label,
                            get = function() return value end,
                            set = function(widget, fixedValue, newValue)
                                if (subKey) then
                                    profileTable[profileKey][subKey] = newValue
                                else
                                    profileTable[profileKey] = newValue
                                end

                                if (self:GetOnEditCallback()) then
                                    self:GetOnEditCallback()(object, option.name, newValue, profileTable, profileKey)
                                end
                            end,
                            min = option.minvalue,
                            max = option.maxvalue,
                            step = option.step,
                            usedecimals = option.usedecimals,
                        }
                    end
                end
            end

            --at this point, the optionsTable is ready to be used on DF:BuildMenuVolatile()
            menuOptions.align_as_pairs = true
            menuOptions.align_as_pairs_length = 150

            local optionsFrame = self:GetOptionsFrame()
            local canvasScrollBox = self:GetCanvasScrollBox()
            local bUseColon = true
            local bSwitchIsCheckbox = true
            local maxHeight = 5000

            --templates
            local options_text_template = detailsFramework:GetTemplate("font", "OPTIONS_FONT_TEMPLATE")
            local options_dropdown_template = detailsFramework:GetTemplate("dropdown", "OPTIONS_DROPDOWN_TEMPLATE")
            local options_switch_template = detailsFramework:GetTemplate("switch", "OPTIONS_CHECKBOX_TEMPLATE")
            local options_slider_template = detailsFramework:GetTemplate("slider", "OPTIONS_SLIDER_TEMPLATE")
            local options_button_template = detailsFramework:GetTemplate("button", "OPTIONS_BUTTON_TEMPLATE")

            detailsFramework:BuildMenuVolatile(optionsFrame, menuOptions, 0, 0, maxHeight, bUseColon, options_text_template, options_dropdown_template, options_switch_template, bSwitchIsCheckbox, options_slider_template, options_button_template)
        end
    end,

}

local editorDefaultOptions = {
    width = 400,
    height = 600,
}

---@class df_editor
---@field options table
---@field editingObject uiobject
---@field editingProfileTable table
---@field editingProfileMap table
---@field onEditCallback function
---@field optionsFrame frame
---@field canvasScrollBox df_canvasscrollbox

function detailsFramework:CreateEditor(parent, name, options)
    name = name or ("DetailsFrameworkEditor" .. math.random(100000, 10000000))
    local editorFrame = CreateFrame("frame", name, parent, "BackdropTemplate")

    detailsFramework:Mixin(editorFrame, detailsFramework.EditorMixin)
    detailsFramework:Mixin(editorFrame, detailsFramework.OptionsFunctions)

    options = options or {}
    editorFrame:BuildOptionsTable(editorDefaultOptions, options)

    editorFrame:SetSize(options.width, options.height)

    --options frame is the frame that holds the options for the editing object, it is used as the parent frame for BuildMenuVolatile()
    local optionsFrame = CreateFrame("frame", name .. "OptionsFrame", editorFrame, "BackdropTemplate")

    local canvasFrame = detailsFramework:CreateCanvasScrollBox(editorFrame, optionsFrame, name .. "CanvasScrollBox")
    canvasFrame:SetAllPoints()

    editorFrame.optionsFrame = optionsFrame
    editorFrame.canvasScrollBox = canvasFrame

    return editorFrame
end