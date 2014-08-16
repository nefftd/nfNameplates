

-- TODO:
-- Rip off Semlar's idea. Add an integrated healthbar directly into the health
-- fontstring. That is, the coloring on the fontstring will fill like a bar
-- would to visually indicate health percentage.

-- NOTE: In order for enemy player class detection to work, you must enable
-- the game option "Class Colors in Nameplates" (Options->Interface->Names).


-- Namespace
  local _,mod = ...


-- Core config switches
  -- Set to `true` to enable "faster" updating of nameplate positioning. This
  -- will use significantly less CPU for complex visual styles (many child or
  -- region elements on your nameplate) but causes the positions to update
  -- lazily (your nameplate will lag 1 frame behind the real position).
  mod.manual_pos = false


-- Custom class colors
  local RAID_CLASS_COLORS = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS


-- Style constants
  local f_name = {mod.path..'\\media\\bavaria.ttf',  8,'OUTLINEMONOCHROME'}
  local f_hp   = {mod.path..'\\media\\tempesta.ttf',16,'OUTLINEMONOCHROME'}
  
  local c_types = {
    ['hostile']        = {0.90,0.64,0.64},
    ['docile']         = {0.90,0.90,0.64},
    ['friendly']       = {0.64,0.64,0.90},
    ['friendlyplayer'] = {0.40,1.00,0.40},
    ['enemyplayer']    = {1.00,0.40,0.40},
  }
  local c_default  = {0.64,0.64,0.64}
  
  -- If mod.plate_size is present, the core will adjust the base (real)
  -- nameplates to this size, so they spread properly. Format: {width,height}.
  local p_size = {80,36}; mod.plate_size = p_size


-- Helpers
  local function abbrev(text)
    return text:sub(1,1)..'.'
  end
  
  local suf = {'k','M','B','T'}
  local function clean_format(val)
    if val == 0 then return '0' end
    local m = math.log10(val)/3
      m = m - m % 1
      if m > #suf then m = #suf end
    local n = val / 1000 ^ m
    local fmt = (m == 0 or n >= 100) and '%d%s' or '%.1f%s'
    return fmt:format(n,suf[m] or '')
  end


-- Update events
  -- Core fires the following methods on the plate if they exist:
  -- :update_info(name,level,classification)
  -- :update_health(current,max)
  -- :update_type(npctype,englishclass)
  
  local plateAPI = {}
  
  function plateAPI:update_info(name,level,classification)
    if classification == 'minus' then
      self:Hide()
      return
    else
      self:Show()
    end
    
    local ctext = (
      classification == 'elite' and '+' or
      classification == 'worldboss' and '??' or
      ''
    )
    self.elitetext:SetText(ctext)
    self.nametext:SetText(name:gsub('(%S+) ',abbrev))
  end
  
  function plateAPI:update_health(current,max)
    self.hptext:SetText(clean_format(current))
  end
  
  function plateAPI:update_type(npctype,enclass)
    self.nametext:SetTextColor(unpack(c_types[npctype] or c_default))
    
    if npctype == 'enemyplayer' then
      local color = RAID_CLASS_COLORS[enclass]
      if color then
        self.hptext:SetTextColor(color.r,color.g,color.b)
        return
      end
    end
    self.hptext:SetTextColor(unpack(c_default))
  end


-- Nameplate construct
  -- The core expects this function to exist. It should create a full frame
  -- representing the nameplate and return it. This will be anchored to the
  -- actual nameplate, and is the object that the above methods get fired upon.
  -- It will be automatically hidden/shown at need, and its opacity will be set
  -- to match the opacity behavior of default nameplates.
  function mod.newplate()
    local plate = CreateFrame('Frame',nil,UIParent)
      plate:SetFrameStrata('BACKGROUND')
      plate:SetFrameLevel(1)
      plate:SetSize(unpack(p_size))
    
    local nametext = plate:CreateFontString(nil,'OVERLAY')
      nametext:SetPoint('CENTER',0,-10)
      nametext:SetFont(unpack(f_name))
      nametext:SetJustifyH('CENTER')
      plate.nametext = nametext
    
    local elitetext = plate:CreateFontString(nil,'OVERLAY')
      elitetext:SetPoint('LEFT',nametext,'RIGHT',2,0)
      elitetext:SetFont(unpack(f_name))
      elitetext:SetJustifyH('CENTER')
      plate.elitetext = elitetext
    
    local hptext = plate:CreateFontString(nil,'ARTWORK')
      hptext:SetPoint('CENTER',0,4)
      hptext:SetFont(unpack(f_hp))
      hptext:SetJustifyH('CENTER')
      plate.hptext = hptext
    
    --[[ Comment in to show size/position of the whole frame, for dev purposes.
    local boundrect = plate:CreateTexture(nil,'BACKGROUND')
      boundrect:SetAllPoints(true)
      boundrect:SetTexture(0.0,1.0,0.0,0.5)
      plate.boundrect = boundrect
    --]]
    
    -- Doesn't matter how you do it, but if you want events to be called on your
    -- plate, the methods must exist on them.
    for name,func in pairs(plateAPI) do
      plate[name] = func
    end
    
    return plate
  end
