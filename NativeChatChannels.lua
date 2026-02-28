-- NativeChatChannels.lua (Retail 12.0+ / Midnight)
-- Always-visible Blizzard-style buttons near ChatFrame1.
-- Each button opens chat input in specific channel.

local NCC = select(2, ...)
local L = NCC.L
setmetatable(L, { __index = function(t, k) return k end })

local DB_DEFAULTS = {
    enabled = true,

    -- Which buttons to show, order matters (comma-separated):
    -- SAY,YELL,EMOTE,PARTY,RAID,INSTANCE,GUILD,OFFICER,WHISPER,CH:1,CH:2...
    buttonOrder = "SAY,PARTY,RAID,INSTANCE,GUILD,OFFICER,CH:1,CH:2",

    showOnlyJoinedChannels = true, -- CH:n only if joined
    buttonSize = 22,
    buttonSpacing = 1,
    tabCycleEnabled = true,

    -- Text customization (global for all channel buttons)
    textMode = "short",      -- "short", "full", "custom"
    textCustom = "CH",       -- legacy fallback
    customLabelSAY = "S",
    customLabelPARTY = "P",
    customLabelRAID = "R",
    customLabelINSTANCE = "I",
    customLabelGUILD = "G",
    customLabelOFFICER = "O",
    customLabelYELL = "Y",
    customLabelEMOTE = "E",
    customLabelWHISPER = "W",
    customLabelCH1 = "1",
    customLabelCH2 = "2",
    textFont = "Friz Quadrata TT",
    textSize = 12,
    textOutline = true,

    -- Button look customization
    buttonStyle = "flat",    -- "flat", "textured"
    buttonCorner = 8,        -- visual corner/border roundness
    buttonBorderSize = 1,
    buttonAlpha = 0.45,
    buttonBorderAlpha = 0.90,
    buttonBackgroundTexture = "Solid Black",
    buttonBorderTexture = "1px",

    -- Per-channel button visibility
    showBtnSAY = true,
    showBtnYELL = true,
    showBtnEMOTE = true,
    showBtnPARTY = true,
    showBtnRAID = true,
    showBtnINSTANCE = true,
    showBtnGUILD = true,
    showBtnOFFICER = true,
    showBtnWHISPER = true,
    showBtnCH1 = true,
    showBtnCH2 = true,
}

local function CopyDefaults(dst, src)
    for k,v in pairs(src) do
        if dst[k] == nil then dst[k] = v end
    end
end
local DB
local EntryEqualsCurrent
local TAB_CYCLE_ORDER = { "SAY", "PARTY", "INSTANCE", "GUILD" }
local NCC_SettingsCategoryID

local LEGACY_FONT_NAME_MAP = {
    Frizqt = "Friz Quadrata TT",
    Arial = "Arial Narrow",
    Morpheus = "Morpheus",
    Skurri = "Skurri",
}

local FONT_PATHS = {
    ["2002"] = "Fonts\\2002.TTF",
    ["2002 Bold"] = "Fonts\\2002B.TTF",
    ["AR CrystalzcuheiGBK Demibold"] = "Fonts\\ARHei.TTF",
    ["AR ZhongkaiGBK Medium (Combat)"] = "Fonts\\ARKai_C.TTF",
    ["AR ZhongkaiGBK Medium"] = "Fonts\\ARKai_T.TTF",
    ["Arial Narrow"] = "Fonts\\ARIALN.TTF",
    ["Friz Quadrata TT"] = "Fonts\\FRIZQT__.TTF",
    ["MoK"] = "Fonts\\K_Pagetext.TTF",
    ["Morpheus"] = "Fonts\\MORPHEUS.TTF",
    ["Nimrod MT"] = "Fonts\\NIM_____.ttf",
    ["Skurri"] = "Fonts\\skurri.ttf",
}

local DEFAULT_FONT_NAME = "Friz Quadrata TT"
local ADDON_ICON_TEXTURE = "Interface\\AddOns\\NativeChatChannels\\Media\\nccIcon"
local FALLBACK_STATUSBAR_TEXTURES = {
    ["Solid Black"] = "Interface\\Buttons\\WHITE8x8",
    ["Solid White"] = "Interface\\Buttons\\WHITE8x8",
    ["Blizzard"] = "Interface\\TargetingFrame\\UI-StatusBar",
    ["Blizzard Cast Bar"] = "Interface\\TargetingFrame\\UI-StatusBar",
}
local FALLBACK_BORDER_TEXTURES = {
    ["1px"] = "Interface\\Buttons\\WHITE8x8",
    ["2px"] = "Interface\\Buttons\\WHITE8x8",
    ["Soft"] = "Interface\\Buttons\\WHITE8x8",
}

local function NormalizeFontName(name)
    if not name or name == "" then
        return DEFAULT_FONT_NAME
    end
    return LEGACY_FONT_NAME_MAP[name] or name
end

local function GetLSM()
    if not LibStub then return nil end
    return LibStub:GetLibrary("LibSharedMedia-3.0", true)
end

local function GetFontDropdownOptions()
    local options = {}
    local lsm = GetLSM()

    if lsm and lsm.List then
        local list = lsm:List("font") or {}
        local sorted = {}
        for _, name in ipairs(list) do
            table.insert(sorted, name)
        end
        table.sort(sorted)
        for _, name in ipairs(sorted) do
            table.insert(options, { text = name, value = name })
        end
    end

    if #options == 0 then
        local names = {}
        for name in pairs(FONT_PATHS) do
            table.insert(names, name)
        end
        table.sort(names)
        for _, name in ipairs(names) do
            table.insert(options, { text = name, value = name })
        end
    end

    return options
end

local function GetMediaDropdownOptions(mediaType, fallbackMap)
    local options = {}
    local lsm = GetLSM()
    if lsm and lsm.List then
        local list = lsm:List(mediaType) or {}
        local sorted = {}
        for _, name in ipairs(list) do
            table.insert(sorted, name)
        end
        table.sort(sorted)
        for _, name in ipairs(sorted) do
            table.insert(options, { text = name, value = name })
        end
    end
    if #options == 0 and fallbackMap then
        local names = {}
        for name in pairs(fallbackMap) do
            table.insert(names, name)
        end
        table.sort(names)
        for _, name in ipairs(names) do
            table.insert(options, { text = name, value = name })
        end
    end
    return options
end

local function ResolveMediaPath(mediaType, name, fallbackMap)
    local lsm = GetLSM()
    if lsm and lsm.Fetch then
        local path = lsm:Fetch(mediaType, name, true)
        if path and path ~= "" then
            return path
        end
    end
    if fallbackMap then
        return fallbackMap[name]
    end
    return nil
end

local function InitDB()
    NativeChatChannelsDB = NativeChatChannelsDB or {}
    CopyDefaults(NativeChatChannelsDB, DB_DEFAULTS)
    DB = NativeChatChannelsDB
    DB.textFont = NormalizeFontName(DB.textFont)
    if DB.buttonStyle ~= "flat" and DB.buttonStyle ~= "textured" then
        DB.buttonStyle = "flat"
    end
end

local function Trim(s) return (s or ""):gsub("^%s+",""):gsub("%s+$","") end
local function SplitCSV(s)
    local out = {}
    for token in (s or ""):gmatch("[^,]+") do
        token = Trim(token):upper()
        if token ~= "" then table.insert(out, token) end
    end
    return out
end

local function TokenToEntry(token)
    if token == "WHISPER" then return { kind="WHISPER" } end
    if token:match("^CH:%d+$") then
        return { kind="CHANNEL", id = tonumber(token:match("^CH:(%d+)$")) }
    end
    if token == "INSTANCE" then token = "INSTANCE_CHAT" end
    local allowed = { SAY=1,YELL=1,EMOTE=1,PARTY=1,RAID=1,GUILD=1,OFFICER=1,INSTANCE_CHAT=1 }
    if allowed[token] then return { kind="MODE", mode=token } end
    return nil
end

local function BuildButtonList()
    local tokenKey = {
        SAY = "showBtnSAY",
        YELL = "showBtnYELL",
        EMOTE = "showBtnEMOTE",
        PARTY = "showBtnPARTY",
        RAID = "showBtnRAID",
        INSTANCE = "showBtnINSTANCE",
        GUILD = "showBtnGUILD",
        OFFICER = "showBtnOFFICER",
        WHISPER = "showBtnWHISPER",
        ["CH:1"] = "showBtnCH1",
        ["CH:2"] = "showBtnCH2",
    }

    local list = {}
    for _, tok in ipairs(SplitCSV(DB.buttonOrder)) do
        local key = tokenKey[tok]
        if key == nil or DB[key] ~= false then
            local e = TokenToEntry(tok)
            if e then table.insert(list, e) end
        end
    end
    return list
end

local function GetJoinedChannelNameByIndex(i)
    local id, name = GetChannelName(i)
    if id and id > 0 and name and name ~= "" then return name end
    return nil
end

local function EnsureEditBox()
    -- "DEFAULT_CHAT_FRAME" is ChatFrame1 in most cases
    local frame = DEFAULT_CHAT_FRAME or _G.ChatFrame1
    if not frame then return nil end

    local eb = frame.editBox or _G.ChatFrame1EditBox
    if eb and eb:IsShown() then
        return eb
    end

    -- open chat input only if needed
    ChatFrame_OpenChat("", frame)
    return frame.editBox or _G.ChatFrame1EditBox
end

local function SwitchTo(editBox, entry)
    if not entry or not editBox then return end

    local frame = editBox.chatFrame or DEFAULT_CHAT_FRAME or _G.ChatFrame1
    if not frame then return end

    local prefix = ""
    if entry.kind == "MODE" then
        local map = {
            SAY = "/s ",
            YELL = "/y ",
            EMOTE = "/e ",
            PARTY = "/p ",
            RAID = "/ra ",
            INSTANCE_CHAT = "/i ",
            GUILD = "/g ",
            OFFICER = "/o ",
        }
        prefix = map[entry.mode] or ""
    elseif entry.kind == "CHANNEL" then
        prefix = ("/%d "):format(entry.id)
    elseif entry.kind == "WHISPER" then
        local target = ChatEdit_GetLastTellTarget and ChatEdit_GetLastTellTarget(DEFAULT_CHAT_FRAME)
        prefix = target and target ~= "" and ("/w " .. target .. " ") or "/w "
    end

    local wasShown = editBox:IsShown()
    local existing = wasShown and (editBox:GetText() or "") or ""

    ChatFrame_OpenChat(prefix, frame)

    local eb = frame.editBox or _G.ChatFrame1EditBox or editBox
    if not eb then return end

    if prefix ~= "" and ChatEdit_ParseText then
        ChatEdit_ParseText(eb, 0)
    end

    if existing ~= "" then
        eb:SetText(existing)
        eb:SetCursorPosition(#existing)
    end

    if ChatEdit_UpdateHeader then
        ChatEdit_UpdateHeader(eb)
    end
end

local function GetEntryLabel(entry)
    local fullModeLabelByMode = {
        SAY = L["channel.mode.SAY"],
        YELL = L["channel.mode.YELL"],
        EMOTE = L["channel.mode.EMOTE"],
        PARTY = L["channel.mode.PARTY"],
        RAID = L["channel.mode.RAID"],
        INSTANCE_CHAT = L["channel.mode.INSTANCE"],
        GUILD = L["channel.mode.GUILD"],
        OFFICER = L["channel.mode.OFFICER"],
    }

    local function GetCustomLabelKey(e)
        if e.kind == "MODE" then
            local modeMap = {
                SAY = "customLabelSAY",
                PARTY = "customLabelPARTY",
                RAID = "customLabelRAID",
                INSTANCE_CHAT = "customLabelINSTANCE",
                GUILD = "customLabelGUILD",
                OFFICER = "customLabelOFFICER",
                YELL = "customLabelYELL",
                EMOTE = "customLabelEMOTE",
            }
            return modeMap[e.mode]
        end
        if e.kind == "WHISPER" then
            return "customLabelWHISPER"
        end
        if e.kind == "CHANNEL" then
            if e.id == 1 then return "customLabelCH1" end
            if e.id == 2 then return "customLabelCH2" end
        end
        return nil
    end

    if DB.textMode == "custom" then
        local key = GetCustomLabelKey(entry)
        if key then
            local custom = Trim(DB[key] or "")
            if custom ~= "" then
                return custom
            end
        end

        -- Legacy fallback for old single custom text setting.
        local legacy = Trim(DB.textCustom or "")
        if legacy ~= "" then return legacy end
    end

    if entry.kind == "MODE" then
        local m = entry.mode
        if DB.textMode == "full" then
            return fullModeLabelByMode[m] or m
        end

        if m == "INSTANCE_CHAT" then return "I" end
        local map = { SAY="S", YELL="Y", EMOTE="E", PARTY="P", RAID="R", GUILD="G", OFFICER="O" }
        return map[m] or m:sub(1,1)
    end
    if entry.kind == "WHISPER" then
        return DB.textMode == "full" and L["channel.mode.WHISPER"] or "W"
    end
    if entry.kind == "CHANNEL" then
        return DB.textMode == "full" and ("CH:" .. tostring(entry.id)) or tostring(entry.id)
    end
    return "?"
end

local function GetResolvedFontPath()
    local fontName = NormalizeFontName(DB.textFont)
    local lsm = GetLSM()
    if lsm and lsm.Fetch then
        local fetched = lsm:Fetch("font", fontName, true)
        if fetched and fetched ~= "" then
            return fetched
        end
    end
    return FONT_PATHS[fontName] or FONT_PATHS[DEFAULT_FONT_NAME] or "Fonts\\FRIZQT__.TTF"
end

local function ApplyButtonLook(btn)
    if not btn then return end
    local style = DB.buttonStyle or "flat"
    local bgTexturePath = ResolveMediaPath("statusbar", DB.buttonBackgroundTexture, FALLBACK_STATUSBAR_TEXTURES) or "Interface\\Buttons\\WHITE8x8"
    local borderTexturePath = ResolveMediaPath("border", DB.buttonBorderTexture, FALLBACK_BORDER_TEXTURES) or "Interface\\Buttons\\WHITE8x8"
    local cornerAmount = math.max(0, math.floor((tonumber(DB.buttonCorner) or 0) + 0.5))
    local borderSize = math.max(1, math.floor((tonumber(DB.buttonBorderSize) or 1) + 0.5))

    -- Some clients reject nil here; use a harmless 1x1 asset and hide via alpha.
    btn:SetNormalTexture("Interface\\Buttons\\WHITE8x8")
    btn:SetPushedTexture("Interface\\Buttons\\WHITE8x8")
    btn:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
    if btn.GetNormalTexture and btn:GetNormalTexture() then btn:GetNormalTexture():SetAlpha(0) end
    if btn.GetPushedTexture and btn:GetPushedTexture() then btn:GetPushedTexture():SetAlpha(0) end
    if btn.GetHighlightTexture and btn:GetHighlightTexture() then btn:GetHighlightTexture():SetAlpha(0) end

    if not btn.__nccSkin then
        btn.__nccSkin = CreateFrame("Frame", nil, btn, BackdropTemplateMixin and "BackdropTemplate")
        btn.__nccSkin:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
        btn.__nccSkin:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
        local level = math.max(0, (btn:GetFrameLevel() or 1) - 1)
        btn.__nccSkin:SetFrameLevel(level)
    end

    if btn.__nccSkin and btn.__nccSkin.SetBackdrop then
        local edgeFile = borderTexturePath
        local edgeSize = borderSize
        if cornerAmount > 0 then
            -- Rounded visual profile for both border and background.
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border"
            edgeSize = 8 + cornerAmount + math.max(0, borderSize - 1)
        end

        local bgFile = (style == "textured") and bgTexturePath or "Interface\\Buttons\\WHITE8x8"
        btn.__nccSkin:SetBackdrop({
            bgFile = bgFile,
            edgeFile = edgeFile,
            edgeSize = edgeSize,
            insets = { left = borderSize, right = borderSize, top = borderSize, bottom = borderSize },
        })
        btn.__nccSkin:SetBackdropBorderColor(0.65, 0.65, 0.65, DB.buttonBorderAlpha or 0.9)

        local alpha = DB.buttonAlpha or 0.45
        if style == "textured" then
            btn.__nccSkin:SetBackdropColor(1, 1, 1, alpha)
        else
            btn.__nccSkin:SetBackdropColor(0, 0, 0, alpha)
        end
    end
end

local function ApplyEntryColor(btn, entry)
    local r,g,b = 1,1,1
    if entry.kind == "MODE" then
        local info = ChatTypeInfo and ChatTypeInfo[entry.mode]
        if info then r,g,b = info.r, info.g, info.b end
    elseif entry.kind == "WHISPER" then
        local info = ChatTypeInfo and ChatTypeInfo["WHISPER"]
        if info then r,g,b = info.r, info.g, info.b end
    elseif entry.kind == "CHANNEL" then
        -- Channel colors are dynamic; use CHANNEL base
        local info = ChatTypeInfo and ChatTypeInfo["CHANNEL"]
        if info then r,g,b = info.r, info.g, info.b end
    end
    if btn.Text then
        btn.Text:SetTextColor(r,g,b)
    end
end

-- ---------------------------
-- UI: create Blizzard-style bar near chat
-- ---------------------------
local Bar

local function GetActiveChatFrame()
    return SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME or _G.ChatFrame1
end

local function FindAnchorButtons()
    -- We try a few common Blizzard chat buttons (top + bottom in vertical stack).
    local top = _G.ChatFrameChannelButton
        or _G.ChatFrameToggleVoiceDeafenButton
        or _G.ChatFrameToggleVoiceMuteButton

    local bottom = _G.ChatFrameMenuButton
        or _G.ChatFrameMenuButton

    return top, bottom
end

local function UpdateBarAnchor(bar)
    if not bar then return end

    local topBtn, bottomBtn = FindAnchorButtons()
    local activeFrame = GetActiveChatFrame()
    local barWidth = DB.buttonSize or GetNativeButtonSize()

    bar:ClearAllPoints()
    bar:SetFrameLevel((topBtn and topBtn.GetFrameLevel and topBtn:GetFrameLevel() or 10) + 1)

    -- If both native buttons exist, place our bar between them.
    if topBtn and bottomBtn then
        bar:SetPoint("TOP", topBtn, "BOTTOM", 0, -2)
        bar:SetPoint("BOTTOM", bottomBtn, "TOP", 0, 2)
        bar:SetWidth(barWidth)
    elseif topBtn then
        bar:SetPoint("TOPLEFT", topBtn, "BOTTOMLEFT", 0, -2)
        bar:SetWidth(barWidth)
    elseif bottomBtn then
        bar:SetPoint("BOTTOMLEFT", bottomBtn, "TOPLEFT", 0, 2)
        bar:SetWidth(barWidth)
    elseif activeFrame then
        bar:SetPoint("BOTTOMLEFT", activeFrame, "BOTTOMLEFT", 2, 24)
        bar:SetWidth(barWidth)
    end
end

local function GetNativeButtonSize()
    local topBtn, bottomBtn = FindAnchorButtons()
    local ref = topBtn or bottomBtn
    if ref and ref.GetWidth and ref.GetHeight then
        local w, h = ref:GetWidth(), ref:GetHeight()
        if w and h and w > 0 and h > 0 then
            return math.floor(math.min(w, h) + 0.5)
        end
    end
    return DB.buttonSize or 22
end

local function CreateBar()
    if Bar then return Bar end
    if not UIParent then return nil end

    Bar = CreateFrame("Frame", "NCC_ChannelBar", UIParent)
    Bar:SetFrameStrata("LOW")
    Bar.buttons = {}

    UpdateBarAnchor(Bar)

    return Bar
end

local function ClearButtons()
    if not Bar or not Bar.buttons then return end
    for _, b in ipairs(Bar.buttons) do
        b:Hide()
        b:SetParent(nil)
    end
    Bar.buttons = {}
end

local function CreateButton(i, entry)
    local btn = CreateFrame("Button", nil, Bar, BackdropTemplateMixin and "BackdropTemplate")
    btn:SetSize(DB.buttonSize or GetNativeButtonSize(), DB.buttonSize or GetNativeButtonSize())
    ApplyButtonLook(btn)

    -- Position
    if i == 1 then
        btn:SetPoint("TOP", Bar, "TOP", 0, 0)
    else
        btn:SetPoint("TOP", Bar.buttons[i-1], "BOTTOM", 0, -DB.buttonSpacing)
    end

    -- Text label
    btn.Text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.Text:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.Text:SetText(GetEntryLabel(entry))
    btn.Text:SetFont(GetResolvedFontPath(), tonumber(DB.textSize) or 12, DB.textOutline and "OUTLINE" or "")

    ApplyEntryColor(btn, entry)

    btn.entry = entry

    btn:SetScript("OnClick", function(self, mouseButton)
        if not DB.enabled then return end
        local eb = EnsureEditBox()
        SwitchTo(eb, self.entry)
        -- keep focus
        if eb then eb:SetFocus() end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if self.entry.kind == "MODE" then
            local name = self.entry.mode
            if name == "INSTANCE_CHAT" then
                name = L["channel.mode.INSTANCE"]
            else
                name = L["channel.mode." .. name] or name
            end
            GameTooltip:SetText(L["tooltip.channel_mode"]:format(name))
        elseif self.entry.kind == "WHISPER" then
            GameTooltip:SetText(L["tooltip.channel_whisper_last"])
        elseif self.entry.kind == "CHANNEL" then
            local chName = GetJoinedChannelNameByIndex(self.entry.id)
            if chName then
                GameTooltip:SetText(L["tooltip.channel_number_name"]:format(self.entry.id, chName))
            else
                GameTooltip:SetText(L["tooltip.channel_number"]:format(self.entry.id))
            end
        end
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return btn
end

local function RebuildBar()
    if not DB.enabled then
        if Bar then Bar:Hide() end
        return
    end

    local bar = CreateBar()
    if not bar then return end
    UpdateBarAnchor(bar)
    bar:Show()

    ClearButtons()

    local list = BuildButtonList()
    for _, entry in ipairs(list) do
        local shouldAdd = true

        if entry.kind == "CHANNEL" and DB.showOnlyJoinedChannels then
            if not GetJoinedChannelNameByIndex(entry.id) then
                shouldAdd = false
            end
        end

        if shouldAdd then
            local idx = #bar.buttons + 1
            local b = CreateButton(idx, entry)
            table.insert(bar.buttons, b)
        end
    end
end

EntryEqualsCurrent = function(editBox, entry)
    if not editBox or not entry then return false end
    if entry.kind == "MODE" then
        return editBox.chatType == entry.mode
    end
    if entry.kind == "CHANNEL" then
        return editBox.chatType == "CHANNEL" and tonumber(editBox.channelTarget) == entry.id
    end
    if entry.kind == "WHISPER" then
        return editBox.chatType == "WHISPER"
    end
    return false
end

local function BuildCycleList()
    local out = {}
    for _, tok in ipairs(TAB_CYCLE_ORDER) do
        local entry = TokenToEntry(tok)
        if entry then table.insert(out, entry) end
    end
    return out
end

local function CycleNext(editBox)
    local list = BuildCycleList()
    if #list == 0 then return end

    local cur = editBox.__nccLastCycleIndex
    if not cur or cur < 1 or cur > #list then
        cur = nil
        for i, entry in ipairs(list) do
            if EntryEqualsCurrent(editBox, entry) then
                cur = i
                break
            end
        end
        cur = cur or 0
    end

    local nextIdx = cur + 1
    if nextIdx > #list then nextIdx = 1 end
    editBox.__nccLastCycleIndex = nextIdx
    SwitchTo(editBox, list[nextIdx])
end

local TabHookInstalled = false
local TabEditHooked = {}
local OriginalTabScripts = {}
local OriginalKeyDownScripts = {}
local DockSelectHookInstalled = false

local function HandleTabCycle(editBox)
    if not (DB.enabled and editBox and editBox:IsShown()) then
        return false
    end
    if DB.tabCycleEnabled == false then
        return false
    end
    CycleNext(editBox)
    return true
end

local function HookTabOnEditBox(editBox)
    if not editBox or TabEditHooked[editBox] then return end
    TabEditHooked[editBox] = true

    OriginalTabScripts[editBox] = editBox:GetScript("OnTabPressed")
    editBox:SetScript("OnTabPressed", function(self)
        if HandleTabCycle(self) then
            return
        end
        if OriginalTabScripts[self] then
            return OriginalTabScripts[self](self)
        end
    end)

    OriginalKeyDownScripts[editBox] = editBox:GetScript("OnKeyDown")
    editBox:SetScript("OnKeyDown", function(self, key)
        if key == "TAB" and HandleTabCycle(self) then
            return
        end
        if OriginalKeyDownScripts[self] then
            return OriginalKeyDownScripts[self](self, key)
        end
    end)
end

local function HookTabAll()
    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame" .. i]
        if frame and frame.editBox then
            HookTabOnEditBox(frame.editBox)
        end
    end

    if not TabHookInstalled and type(ChatEdit_OnTabPressed) == "function" then
        local OriginalChatEdit_OnTabPressed = ChatEdit_OnTabPressed
        ChatEdit_OnTabPressed = function(editBox)
            if HandleTabCycle(editBox) then
                return
            end
            return OriginalChatEdit_OnTabPressed(editBox)
        end
        TabHookInstalled = true
    end
end

local function HookChatTabSwitch()
    if DockSelectHookInstalled then return end
    if type(hooksecurefunc) ~= "function" then return end
    if type(FCFDock_SelectWindow) ~= "function" then return end

    hooksecurefunc("FCFDock_SelectWindow", function()
        C_Timer.After(0, RebuildBar)
    end)
    DockSelectHookInstalled = true
end

-- ---------------------------
-- Settings UI
-- ---------------------------
local function RebuildBarDelayed()
    C_Timer.After(0, RebuildBar)
end

local function CreateSettings()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then
        return
    end
    if NCC_SettingsCategoryID then return end

    local panel = CreateFrame("Frame")
    panel:Hide()

    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetSize(32, 32)
    logo:SetPoint("TOPLEFT", 20, -14)
    logo:SetTexture(ADDON_ICON_TEXTURE)

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("LEFT", logo, "RIGHT", 10, 0)
    title:SetFontObject("GameFontNormalHuge")
    title:SetTextColor(1, 1, 1)
    title:SetText(L["addon.name"])

    local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    sub:SetText(L["settings.subtitle"])

    local resetAll = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetAll:SetSize(140, 22)
    resetAll:SetPoint("RIGHT", -20, 0)
    resetAll:SetPoint("CENTER", title, "CENTER", 0, 0)
    resetAll:SetText(L["settings.reset_defaults"])

    local lineTex = panel:CreateTexture(nil, "ARTWORK")
    lineTex:SetColorTexture(1, 1, 1, 0.08)
    lineTex:SetPoint("TOPLEFT", 16, -60)
    lineTex:SetPoint("TOPRIGHT", -16, -60)
    lineTex:SetHeight(1)

    local contentRoot = CreateFrame("Frame", nil, panel)
    contentRoot:SetPoint("TOPLEFT", 16, -90)
    contentRoot:SetPoint("BOTTOMRIGHT", -16, 16)

    local scrollFrame = CreateFrame("ScrollFrame", nil, contentRoot, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", 0, 0)
    scrollFrame:EnableMouseWheel(true)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(700, 1200)
    scrollFrame:SetScrollChild(scrollChild)

    local tabs = {}
    local sections = {}
    local refreshers = {}
    local UpdateCustomTextFields
    local UpdateButtonsStyleFields

    local function ApplyLeftLabelStyle(fs)
        if not fs then return end
        fs:SetFontObject("GameFontHighlight")
        fs:SetTextColor(1.0, 0.82, 0.0)
    end

    local function MakeHeader(parent, text)
        local h = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        h:SetPoint("TOPLEFT", 8, -8)
        h:SetText(text)
        ApplyLeftLabelStyle(h)
        return h
    end

    local function MakeCheckbox(parent, label, tooltip, key, anchor, yOff, onChanged)
        local okModern, modern = pcall(CreateFrame, "Frame", nil, parent, "EditModeSettingCheckboxTemplate")
        if okModern and modern and modern.Button and modern.Label then
            modern:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff)
            modern:SetSize(420, 24)
            modern:Show()
            modern.Button:Show()
            modern.Label:Show()
            modern.Button:ClearAllPoints()
            modern.Button:SetPoint("LEFT", modern, "LEFT", 0, 0)
            modern.Label:ClearAllPoints()
            modern.Label:SetPoint("LEFT", modern.Button, "RIGHT", 6, 0)
            modern.Label:SetWidth(380)
            modern.Label:SetJustifyH("LEFT")
            modern.Label:SetText(label)
            ApplyLeftLabelStyle(modern.Label)
            modern.Button:SetChecked(DB[key] and true or false)
            modern.Button:SetScript("OnClick", function(self)
                DB[key] = self:GetChecked() and true or false
                if onChanged then onChanged() end
            end)
            modern:SetScript("OnEnter", function(self)
                if tooltip and tooltip ~= "" then
                    if SettingsTooltip then
                        SettingsTooltip:SetOwner(self, "ANCHOR_NONE")
                        SettingsTooltip:SetPoint("BOTTOMRIGHT", self, "TOPLEFT")
                        SettingsTooltip:SetText(label, 1, 1, 1)
                        SettingsTooltip:AddLine(tooltip)
                        SettingsTooltip:Show()
                    else
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetText(label)
                        GameTooltip:AddLine(tooltip, 1, 1, 1, true)
                        GameTooltip:Show()
                    end
                end
            end)
            modern:SetScript("OnLeave", function()
                if SettingsTooltip then
                    SettingsTooltip:Hide()
                end
                GameTooltip:Hide()
            end)
            table.insert(refreshers, function()
                modern.Button:SetChecked(DB[key] and true or false)
            end)
            return modern
        end

        local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff)
        cb:SetSize(22, 22)
        local fs = cb.Text or cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        fs:SetPoint("LEFT", cb, "RIGHT", 6, 0)
        fs:SetText(label)
        ApplyLeftLabelStyle(fs)
        cb.Text = fs
        cb:SetHitRectInsets(0, -math.max(0, math.floor(fs:GetStringWidth() + 8)), 0, 0)
        cb:SetChecked(DB[key] and true or false)
        cb:SetScript("OnClick", function(self)
            DB[key] = self:GetChecked() and true or false
            if onChanged then onChanged() end
        end)
        cb:SetScript("OnEnter", function(self)
            if tooltip and tooltip ~= "" then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(tooltip)
                GameTooltip:Show()
            end
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        table.insert(refreshers, function()
            cb:SetChecked(DB[key] and true or false)
        end)
        return cb
    end

    local function MakeEdit(parent, label, key, width, anchor, yOff, onChanged)
        local lf = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        lf:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff)
        lf:SetText(label)
        ApplyLeftLabelStyle(lf)
        local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        eb:SetPoint("TOPLEFT", lf, "BOTTOMLEFT", 0, -3)
        eb:SetSize(width, 24)
        eb:SetAutoFocus(false)
        eb:SetText(tostring(DB[key] or ""))
        eb:SetScript("OnEnterPressed", function(self)
            DB[key] = self:GetText() or ""
            self:ClearFocus()
            if onChanged then onChanged() end
        end)
        eb:SetScript("OnEditFocusLost", function(self)
            DB[key] = self:GetText() or ""
            if onChanged then onChanged() end
        end)
        table.insert(refreshers, function()
            eb:SetText(tostring(DB[key] or ""))
        end)
        return eb
    end

    local function MakeEditAt(parent, label, key, width, x, y, onChanged)
        local lf = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        lf:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        lf:SetText(label)
        ApplyLeftLabelStyle(lf)

        local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        eb:SetPoint("TOPLEFT", lf, "BOTTOMLEFT", 0, -3)
        eb:SetSize(width, 24)
        eb:SetAutoFocus(false)
        eb:SetText(tostring(DB[key] or ""))
        eb:SetScript("OnEnterPressed", function(self)
            DB[key] = self:GetText() or ""
            self:ClearFocus()
            if onChanged then onChanged() end
        end)
        eb:SetScript("OnEditFocusLost", function(self)
            DB[key] = self:GetText() or ""
            if onChanged then onChanged() end
        end)
        table.insert(refreshers, function()
            eb:SetText(tostring(DB[key] or ""))
        end)
        return eb
    end

    local function MakeSlider(parent, label, key, minv, maxv, step, anchor, yOff, onChanged)
        local okModern, frame = pcall(CreateFrame, "Frame", nil, parent, "EditModeSettingSliderTemplate")
        if okModern and frame and frame.Slider and frame.Label and frame.Slider.Init and frame.OnLoad and CreateMinimalSliderFormatter and MinimalSliderWithSteppersMixin then
            local okSetup = pcall(function()
            frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff)
            frame:SetHeight(32)
            frame:SetWidth(560)
            frame:Show()
            frame.Slider:Show()
            frame.Label:Show()
            frame.Label:SetText(label)
            ApplyLeftLabelStyle(frame.Label)
            frame.Label:SetWidth(220)
            frame.Label:SetJustifyH("LEFT")
            frame.Slider:SetWidth(320)
            if frame.Slider.MinText then frame.Slider.MinText:Hide() end
            if frame.Slider.MaxText then frame.Slider.MaxText:Hide() end
            frame.Label:SetPoint("LEFT", 0, 0)

            local formatter = function(value)
                if step < 1 then
                    return string.format("%.2f", value)
                end
                return tostring(math.floor(value + 0.5))
            end

            frame.initInProgress = true
            frame.OnSliderValueChanged = function(self, value)
                if self.initInProgress then return end
                DB[key] = value
                if onChanged then onChanged() end
            end
            frame:OnLoad()

            local cur = tonumber(DB[key]) or minv
            local steps = math.floor(((maxv - minv) / step) + 0.5)
            local formats = {}
            formats[MinimalSliderWithSteppersMixin.Label.Right] =
                CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right, formatter)
            frame.Slider:Init(cur, minv, maxv, steps, formats)
            frame.initInProgress = false

            table.insert(refreshers, function()
                local v = tonumber(DB[key]) or minv
            frame.initInProgress = true
            frame.Slider:SetValue(v)
            frame.initInProgress = false
        end)
            end)
            if okSetup then
                return frame
            end
            frame:Hide()
        end

        local lf = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        lf:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff)
        lf:SetText(label)
        ApplyLeftLabelStyle(lf)
        local value = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        value:SetPoint("LEFT", lf, "RIGHT", 10, 0)
        value:SetText(tostring(DB[key]))
        local s = CreateFrame("Slider", "NCC_SettingsSlider_" .. key, parent, "OptionsSliderTemplate")
        s:SetPoint("TOPLEFT", lf, "BOTTOMLEFT", 0, -8)
        s:SetMinMaxValues(minv, maxv)
        s:SetValueStep(step)
        s:SetObeyStepOnDrag(true)
        s:SetWidth(320)
        local low = _G[s:GetName() .. "Low"]
        local high = _G[s:GetName() .. "High"]
        local txt = _G[s:GetName() .. "Text"]
        if low then low:SetText("") end
        if high then high:SetText("") end
        if txt then txt:SetText("") end
        s:SetValue(tonumber(DB[key]) or minv)
        s:SetScript("OnValueChanged", function(self, v)
            v = math.floor((v / step) + 0.5) * step
            if step < 1 then
                v = tonumber(("%.2f"):format(v))
            else
                v = math.floor(v + 0.5)
            end
            DB[key] = v
            value:SetText(tostring(v))
            if onChanged then onChanged() end
        end)
        table.insert(refreshers, function()
            local v = tonumber(DB[key]) or minv
            s:SetValue(v)
            value:SetText(tostring(v))
        end)
        return s
    end

    local function MakeDropdown(parent, label, key, options, anchor, yOff, onChanged, optionInitializer, scrollPixels)
        local row = CreateFrame("Frame", nil, parent)
        row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff)
        row:SetSize(700, 32)

        local lf = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        lf:SetPoint("LEFT", row, "LEFT", 0, 0)
        lf:SetText(label)
        ApplyLeftLabelStyle(lf)
        lf:SetWidth(220)
        lf:SetJustifyH("LEFT")
        local selector = CreateFrame("Frame", nil, row)
        selector:SetPoint("LEFT", lf, "RIGHT", 12, 0)
        selector:SetSize(340, 30)

        local okControl, control = pcall(CreateFrame, "Frame", nil, selector, "SettingsDropdownWithButtonsTemplate")
        local dropdown, leftBtn, rightBtn
        if okControl and control and control.Dropdown then
            control:SetAllPoints(selector)
            dropdown = control.Dropdown
            leftBtn = control.DecrementButton
            rightBtn = control.IncrementButton
            if not leftBtn then
                leftBtn = CreateFrame("Button", nil, selector)
                leftBtn:SetSize(24, 24)
                leftBtn:SetPoint("LEFT", selector, "LEFT", 0, 0)
                leftBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
                leftBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
            end
            if not rightBtn then
                rightBtn = CreateFrame("Button", nil, selector)
                rightBtn:SetSize(24, 24)
                rightBtn:SetPoint("RIGHT", selector, "RIGHT", 0, 0)
                rightBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
                rightBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
            end
        else
            control = nil
            leftBtn = CreateFrame("Button", nil, selector)
            rightBtn = CreateFrame("Button", nil, selector)
            leftBtn:SetSize(24, 24)
            rightBtn:SetSize(24, 24)
            leftBtn:SetPoint("LEFT", selector, "LEFT", 0, 0)
            rightBtn:SetPoint("RIGHT", selector, "RIGHT", 0, 0)
            leftBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
            leftBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
            rightBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
            rightBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
            dropdown = CreateFrame("DropdownButton", nil, selector, "WowStyle1DropdownTemplate")
            dropdown:SetPoint("LEFT", leftBtn, "RIGHT", 6, 0)
            dropdown:SetPoint("RIGHT", rightBtn, "LEFT", -6, 0)
            dropdown:SetHeight(30)
        end

        local function FindIndexByValue(v)
            for i, opt in ipairs(options) do
                if opt.value == v then
                    return i
                end
            end
            return 1
        end

        selector.SetValue = function(self, v, silent)
            local idx = FindIndexByValue(v)
            local opt = options[idx]
            DB[key] = opt.value
            if dropdown.SetDefaultText then
                dropdown:SetDefaultText(opt.text)
            end
            if dropdown.SetText then
                pcall(dropdown.SetText, dropdown, opt.text)
            end
            self._index = idx
            if not silent and onChanged then
                onChanged()
            end
        end

        leftBtn:SetScript("OnClick", function()
            local idx = (selector._index or FindIndexByValue(DB[key])) - 1
            if idx < 1 then idx = #options end
            selector:SetValue(options[idx].value)
        end)
        rightBtn:SetScript("OnClick", function()
            local idx = (selector._index or FindIndexByValue(DB[key])) + 1
            if idx > #options then idx = 1 end
            selector:SetValue(options[idx].value)
        end)

        if dropdown.SetupMenu then
            dropdown:SetupMenu(function(_, rootDescription)
                for _, opt in ipairs(options) do
                    local radio = rootDescription:CreateRadio(
                        opt.text,
                        function()
                            return DB[key] == opt.value
                        end,
                        function()
                            selector:SetValue(opt.value)
                        end
                    )
                    if optionInitializer then
                        radio:AddInitializer(function(button)
                            optionInitializer(button, opt)
                        end)
                    end
                end
                if scrollPixels then
                    rootDescription:SetScrollMode(scrollPixels)
                end
            end)
        else
            dropdown:SetScript("OnClick", function()
                local idx = (selector._index or FindIndexByValue(DB[key])) + 1
                if idx > #options then idx = 1 end
                selector:SetValue(options[idx].value)
            end)
        end

        selector:SetValue(DB[key], true)
        table.insert(refreshers, function()
            selector:SetValue(DB[key], true)
        end)
        return row, selector, lf
    end

    local function MakeMediaOptionInitializer(mediaType, fallbackMap)
        return function(button, opt)
            if not button then return end
            local fs = button.fontString or button.Text or (button.GetFontString and button:GetFontString())
            if not fs then return end

            local previewWidth, previewHeight = 120, 14
            local previewLeft = 28
            local tex = button.leftTexture1 or button.LeftTexture or button.Icon
            if tex then
                tex:ClearAllPoints()
                tex:SetPoint("LEFT", button, "LEFT", previewLeft, 0)
                tex:SetSize(previewWidth, previewHeight)
                if mediaType == "border" then
                    tex:SetTexture(ResolveMediaPath("border", opt.value, fallbackMap) or "Interface\\Buttons\\WHITE8x8")
                else
                    tex:SetTexture(ResolveMediaPath("statusbar", opt.value, fallbackMap) or "Interface\\Buttons\\WHITE8x8")
                end
                tex:SetVertexColor(1, 1, 1, 1)
                tex:Show()
            end

            fs:ClearAllPoints()
            fs:SetPoint("LEFT", button, "LEFT", previewLeft + previewWidth + 8, 0)
            fs:SetPoint("RIGHT", button, "RIGHT", -8, 0)
            fs:SetJustifyH("LEFT")
        end
    end

    local function CreateSection()
        local s = CreateFrame("Frame", nil, scrollChild)
        s:SetPoint("TOPLEFT", 0, 0)
        s:SetPoint("TOPRIGHT", -26, 0)
        s:SetHeight(800)
        s:Hide()
        table.insert(sections, s)
        return s
    end

    local general = CreateSection()
    do
        local topAnchor = CreateFrame("Frame", nil, general)
        topAnchor:SetPoint("TOPLEFT", 8, -8)
        topAnchor:SetSize(1, 1)
        local line = MakeCheckbox(general, L["settings.general.enable.label"], L["settings.general.enable.tooltip"], "enabled", topAnchor, -4, RebuildBarDelayed)
        line = MakeCheckbox(general, L["settings.general.only_joined.label"], L["settings.general.only_joined.tooltip"], "showOnlyJoinedChannels", line, -4, RebuildBarDelayed)
        local tabHeader = general:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        tabHeader:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 0, -20)
        tabHeader:SetText(L["settings.general.tab.header"])
        ApplyLeftLabelStyle(tabHeader)
        MakeCheckbox(general, L["settings.general.tab_cycle.label"], L["settings.general.tab_cycle.tooltip"], "tabCycleEnabled", tabHeader, -10, nil)
        general:SetHeight(320)
    end

    local text = CreateSection()
    do
        local topAnchor = CreateFrame("Frame", nil, text)
        topAnchor:SetPoint("TOPLEFT", 8, -8)
        topAnchor:SetSize(1, 1)
        local labelModeOptions = {
            { text = L["settings.text.mode.short"], value = "short" },
            { text = L["settings.text.mode.full"], value = "full" },
            { text = L["settings.text.mode.custom"], value = "custom" },
        }
        local modeRow, modeDD = MakeDropdown(text, L["settings.text.mode.label"], "textMode", labelModeOptions, topAnchor, -4, function()
            if UpdateCustomTextFields then
                UpdateCustomTextFields()
            end
            RebuildBarDelayed()
        end)

        local customGroup = CreateFrame("Frame", nil, text)
        customGroup:SetPoint("TOPLEFT", modeRow, "BOTTOMLEFT", 0, -10)
        customGroup:SetSize(700, 330)

        local customHeader = customGroup:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        customHeader:SetPoint("TOPLEFT", customGroup, "TOPLEFT", 0, 0)
        customHeader:SetText(L["settings.text.custom_labels.header"])
        ApplyLeftLabelStyle(customHeader)

        local customFields = {
            { label = L["settings.custom_label.say"], key = "customLabelSAY" },
            { label = L["settings.custom_label.party"], key = "customLabelPARTY" },
            { label = L["settings.custom_label.raid"], key = "customLabelRAID" },
            { label = L["settings.custom_label.instance"], key = "customLabelINSTANCE" },
            { label = L["settings.custom_label.guild"], key = "customLabelGUILD" },
            { label = L["settings.custom_label.officer"], key = "customLabelOFFICER" },
            { label = L["settings.custom_label.yell"], key = "customLabelYELL" },
            { label = L["settings.custom_label.emote"], key = "customLabelEMOTE" },
            { label = L["settings.custom_label.whisper"], key = "customLabelWHISPER" },
            { label = L["settings.custom_label.ch1"], key = "customLabelCH1" },
            { label = L["settings.custom_label.ch2"], key = "customLabelCH2" },
        }
        local customStartY = -30
        local customRowStep = 52
        local customColX = { 0, 320 }
        local customWidth = 260
        for i, field in ipairs(customFields) do
            local col = ((i - 1) % 2) + 1
            local row = math.floor((i - 1) / 2)
            local x = customColX[col]
            local y = customStartY - (row * customRowStep)
            MakeEditAt(customGroup, field.label, field.key, customWidth, x, y, RebuildBarDelayed)
        end

        local fontOptions = GetFontDropdownOptions()
        local hasCurrent = false
        for _, opt in ipairs(fontOptions) do
            if opt.value == DB.textFont then
                hasCurrent = true
                break
            end
        end
        if not hasCurrent then
            DB.textFont = DEFAULT_FONT_NAME
        end

        local fontRow = MakeDropdown(text, L["settings.text.font.label"], "textFont", fontOptions, modeRow, -14, RebuildBarDelayed)

        local fontHint = text:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        fontHint:SetPoint("TOPLEFT", fontRow, "BOTTOMLEFT", 0, -4)
        fontHint:SetWidth(620)
        fontHint:SetJustifyH("LEFT")
        fontHint:SetTextColor(0.85, 0.85, 0.85)

        local hasSharedMedia = false
        local hasAdditionalFonts = false
        if C_AddOns and C_AddOns.IsAddOnLoaded then
            hasSharedMedia = C_AddOns.IsAddOnLoaded("SharedMedia")
            hasAdditionalFonts = C_AddOns.IsAddOnLoaded("SharedMediaAdditionalFonts")
        elseif IsAddOnLoaded then
            hasSharedMedia = IsAddOnLoaded("SharedMedia")
            hasAdditionalFonts = IsAddOnLoaded("SharedMediaAdditionalFonts")
        end
        if (not hasSharedMedia) or (not hasAdditionalFonts) then
            fontHint:SetText(L["settings.text.font.hint"])
            fontHint:Show()
        else
            fontHint:SetText("")
            fontHint:Hide()
        end

        local sizeSlider = MakeSlider(text, L["settings.text.size.label"], "textSize", 8, 24, 1, fontHint, -16, RebuildBarDelayed)
        MakeCheckbox(text, L["settings.text.outline.label"], L["settings.text.outline.tooltip"], "textOutline", sizeSlider, -8, RebuildBarDelayed)

        UpdateCustomTextFields = function()
            fontRow:ClearAllPoints()
            if DB.textMode == "custom" then
                customGroup:Show()
                fontRow:SetPoint("TOPLEFT", customGroup, "BOTTOMLEFT", 0, -10)
                text:SetHeight(900)
            else
                customGroup:Hide()
                fontRow:SetPoint("TOPLEFT", modeRow, "BOTTOMLEFT", 0, -14)
                text:SetHeight(520)
            end
        end

        UpdateCustomTextFields()
        modeDD:SetValue(DB.textMode, true)
    end

    local buttons = CreateSection()
    do
        local topAnchor = CreateFrame("Frame", nil, buttons)
        topAnchor:SetPoint("TOPLEFT", 8, -8)
        topAnchor:SetSize(1, 1)
        local line = MakeSlider(buttons, L["settings.buttons.size.label"], "buttonSize", 16, 36, 1, topAnchor, -4, RebuildBarDelayed)
        line = MakeSlider(buttons, L["settings.buttons.spacing.label"], "buttonSpacing", 0, 10, 1, line, -14, RebuildBarDelayed)
        local styleRow = MakeDropdown(buttons, L["settings.buttons.style.label"], "buttonStyle", {
            { text = L["settings.buttons.style.flat"], value = "flat" },
            { text = L["settings.buttons.style.textured"], value = "textured" },
        }, line, -14, function()
            if UpdateButtonsStyleFields then
                UpdateButtonsStyleFields()
            end
            RebuildBarDelayed()
        end)

        local backgroundOptions = GetMediaDropdownOptions("statusbar", FALLBACK_STATUSBAR_TEXTURES)
        local hasBackground = false
        for _, opt in ipairs(backgroundOptions) do
            if opt.value == DB.buttonBackgroundTexture then
                hasBackground = true
                break
            end
        end
        if not hasBackground then
            DB.buttonBackgroundTexture = "Solid Black"
        end
        local backgroundRow = MakeDropdown(
            buttons,
            L["settings.buttons.bg_texture.label"],
            "buttonBackgroundTexture",
            backgroundOptions,
            styleRow,
            -14,
            RebuildBarDelayed,
            MakeMediaOptionInitializer("statusbar", FALLBACK_STATUSBAR_TEXTURES),
            560
        )

        local afterStyleAnchor = CreateFrame("Frame", nil, buttons)
        afterStyleAnchor:SetSize(1, 1)

        UpdateButtonsStyleFields = function()
            afterStyleAnchor:ClearAllPoints()
            if DB.buttonStyle == "textured" then
                backgroundRow:Show()
                afterStyleAnchor:SetPoint("TOPLEFT", backgroundRow, "BOTTOMLEFT", 0, 0)
            else
                backgroundRow:Hide()
                afterStyleAnchor:SetPoint("TOPLEFT", styleRow, "BOTTOMLEFT", 0, 0)
            end
        end
        UpdateButtonsStyleFields()

        line = MakeSlider(buttons, L["settings.buttons.corner.label"], "buttonCorner", 0, 12, 1, afterStyleAnchor, -56, RebuildBarDelayed)
        line = MakeSlider(buttons, L["settings.buttons.bg_alpha.label"], "buttonAlpha", 0.10, 1.00, 0.05, line, -14, RebuildBarDelayed)
        line = MakeSlider(buttons, L["settings.buttons.border_alpha.label"], "buttonBorderAlpha", 0.00, 1.00, 0.05, line, -14, RebuildBarDelayed)
        MakeSlider(buttons, L["settings.buttons.border_thickness.label"], "buttonBorderSize", 1, 8, 1, line, -14, RebuildBarDelayed)
        buttons:SetHeight(820)
    end

    local channels = CreateSection()
    do
        local topAnchor = CreateFrame("Frame", nil, channels)
        topAnchor:SetPoint("TOPLEFT", 8, -8)
        topAnchor:SetSize(1, 1)
        local line = MakeCheckbox(channels, L["settings.channels.say.label"], L["settings.channels.say.tooltip"], "showBtnSAY", topAnchor, -4, RebuildBarDelayed)
        line = MakeCheckbox(channels, L["settings.channels.party.label"], L["settings.channels.party.tooltip"], "showBtnPARTY", line, -4, RebuildBarDelayed)
        line = MakeCheckbox(channels, L["settings.channels.instance.label"], L["settings.channels.instance.tooltip"], "showBtnINSTANCE", line, -4, RebuildBarDelayed)
        line = MakeCheckbox(channels, L["settings.channels.guild.label"], L["settings.channels.guild.tooltip"], "showBtnGUILD", line, -4, RebuildBarDelayed)
        line = MakeCheckbox(channels, L["settings.channels.raid.label"], L["settings.channels.raid.tooltip"], "showBtnRAID", line, -4, RebuildBarDelayed)
        line = MakeCheckbox(channels, L["settings.channels.officer.label"], L["settings.channels.officer.tooltip"], "showBtnOFFICER", line, -4, RebuildBarDelayed)
        line = MakeCheckbox(channels, L["settings.channels.yell.label"], L["settings.channels.yell.tooltip"], "showBtnYELL", line, -4, RebuildBarDelayed)
        line = MakeCheckbox(channels, L["settings.channels.emote.label"], L["settings.channels.emote.tooltip"], "showBtnEMOTE", line, -4, RebuildBarDelayed)
        line = MakeCheckbox(channels, L["settings.channels.whisper.label"], L["settings.channels.whisper.tooltip"], "showBtnWHISPER", line, -4, RebuildBarDelayed)
        line = MakeCheckbox(channels, L["settings.channels.ch1.label"], L["settings.channels.ch1.tooltip"], "showBtnCH1", line, -4, RebuildBarDelayed)
        MakeCheckbox(channels, L["settings.channels.ch2.label"], L["settings.channels.ch2.tooltip"], "showBtnCH2", line, -4, RebuildBarDelayed)
        channels:SetHeight(760)
    end

    local function ShowTab(index)
        for i, s in ipairs(sections) do
            if i == index then s:Show() else s:Hide() end
        end
        scrollChild:SetWidth(math.max(680, contentRoot:GetWidth() - 26))
        local h = sections[index] and sections[index]:GetHeight() or 700
        scrollChild:SetHeight(h)
        scrollFrame:SetVerticalScroll(0)
        for i, b in ipairs(tabs) do
            if PanelTemplates_SelectTab and PanelTemplates_DeselectTab and b._isTabStyle then
                if i == index then
                    PanelTemplates_SelectTab(b)
                else
                    PanelTemplates_DeselectTab(b)
                end
            else
                b:SetEnabled(i ~= index)
            end
        end
    end

    local tabDefs = {
        L["settings.tabs.general"],
        L["settings.tabs.text"],
        L["settings.tabs.buttons"],
        L["settings.tabs.channels"],
    }
    for i, label in ipairs(tabDefs) do
        local ok, b = pcall(CreateFrame, "Button", nil, panel, "PanelTabButtonTemplate")
        if not ok or not b then
            b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
            b:SetSize(100, 22)
            b._isTabStyle = false
        else
            b._isTabStyle = true
            b:SetSize(100, 24)
        end
        if i == 1 then
            b:SetPoint("TOPLEFT", 16, -60)
        else
            b:SetPoint("LEFT", tabs[i - 1], "RIGHT", 6, 0)
        end
        b:SetText(label)
        if b._isTabStyle and PanelTemplates_TabResize then
            PanelTemplates_TabResize(b, 0)
        end
        b:SetScript("OnClick", function()
            ShowTab(i)
        end)
        tabs[i] = b
    end

    ShowTab(1)

    local function ResetDefaultsAndRefresh()
        for k, v in pairs(DB_DEFAULTS) do
            DB[k] = v
        end
        if UpdateCustomTextFields then
            UpdateCustomTextFields()
        end
        if UpdateButtonsStyleFields then
            UpdateButtonsStyleFields()
        end
        for _, fn in ipairs(refreshers) do
            fn()
        end
        RebuildBarDelayed()
    end

    resetAll:SetScript("OnClick", function()
        ResetDefaultsAndRefresh()
        print(L["msg.settings_reset"])
    end)

    panel:SetScript("OnShow", function()
        scrollChild:SetWidth(math.max(1, contentRoot:GetWidth() - 26))
        if UpdateCustomTextFields then
            UpdateCustomTextFields()
        end
        if UpdateButtonsStyleFields then
            UpdateButtonsStyleFields()
        end
    end)

    local category = Settings.RegisterCanvasLayoutCategory(panel, L["addon.name"])
    category.ID = category.ID or category:GetID()
    Settings.RegisterAddOnCategory(category)
    NCC_SettingsCategoryID = category.ID
end

-- ---------------------------
-- Init
-- ---------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("CHANNEL_UI_UPDATE")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
    if not DB then
        InitDB()
    end
    -- Delay a bit to let Blizzard chat buttons appear
    C_Timer.After(0.2, function()
        RebuildBar()
        CreateSettings()
        HookTabAll()
        HookChatTabSwitch()
    end)
end)

SLASH_NATIVECHATCHANNELS1 = "/ncc"
SlashCmdList.NATIVECHATCHANNELS = function(msg)
    if not DB then
        InitDB()
    end
    msg = (msg or ""):lower()
    if msg == "rebuild" then
        RebuildBar()
        print(L["msg.rebuilt"])
        return
    end

    CreateSettings()
    if Settings and Settings.OpenToCategory and NCC_SettingsCategoryID then
        Settings.OpenToCategory(NCC_SettingsCategoryID)
        return
    end

    print(L["msg.cannot_open_settings"])
end
