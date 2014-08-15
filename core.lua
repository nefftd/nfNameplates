

-- Namespace
  local _,mod = ...


-- Import stuff from ui.lua
  local newplate = mod.newplate
    mod.newplate = nil
  
  if not newplate then
    self:print('Function mod.newplate() @ ui.lua not found. Aborting.')
    return
  end
  
  local psize = mod.plate_size
    mod.plate_size = nil
  
  if (
    #psize ~= 2 or
    type(psize[1]) ~= 'number' or
    type(psize[2]) ~= 'number' or
    psize[1] < 1 or psize[2] < 1
  ) then
    self:print('Warning: mod.plate_size table is improperly formatted.')
    psize = nil
  end
  
  local manual_pos = mod.manual_pos
    mod.manual_pos = nil


-- Compute type+class info
  local function classcolor(r,g,b)
    r = math.floor(r*100+.5)
    g = math.floor(g*100+.5)
    b = math.floor(b*100+.5)
    return ('%03d%03d%03d'):format(r,g,b)
  end
  
  local classes = {}
  
  for class,color in pairs(RAID_CLASS_COLORS) do
    classes[classcolor(color.r,color.g,color.b)] = class
  end
  classes['000100060'] = 'MONK'  -- Rounding error in default UI.
  
  local function compute_type(self)
    local r,g,b = self.hpbar:GetStatusBarColor()
    local R,G,B = math.ceil(r),math.ceil(g),math.ceil(b)
    
    local npctype = (
      (R == 1 and G == 0 and B == 0) and 'hostile' or
      (R == 0 and G == 1 and B == 0) and 'friendly' or
      (R == 0 and G == 0 and B == 1) and 'friendlyplayer' or
      (R == 1 and G == 1 and B == 0) and 'docile' or
      'enemyplayer'
    )
    
    local enclass
    if npctype == 'enemyplayer' then
      enclass = classes[classcolor(r,g,b)] or 'unknown'
    end
    
    return npctype,enclass
  end


-- Position
  -- According to investigations by Semlar, complex nameplates styles can
  -- become inefficient for the game engine to position relative to the base
  -- nameplate frame. A working solution is to do it manually. Every OnUpdate,
  -- hide your frame, reposition it against the WorldFrame, then reshow your
  -- frame. The caveat is this creates a 1 FPS lag behind the actual position.
  
  -- Sources on this:
  -- http://www.wowinterface.com/forums/showthread.php?t=46740
  -- http://www.wowinterface.com/forums/showpost.php?p=280548&postcount=5
  
  local active = {}
  
  if manual_pos then
    WorldFrame:HookScript('OnUpdate',function()
      for nfframe in pairs(active) do
        nfframe:Hide()
        nfframe:SetPoint('CENTER',WorldFrame,'BOTTOMLEFT',nfframe.__p:GetCenter())
        nfframe:Show()
      end
    end)
  end


-- Base hooks/callbacks
  local function hpbar_OnValueChanged(self)
    local current = self:GetValue()
    local _,max = self:GetMinMaxValues()
    local nfframe = self.parent.nfframe
    if nfframe.update_health then
      nfframe:update_health(current,max)
    end
  end
  
  local function plate_OnUpdate(self)
    local alpha = self:GetAlpha()
    if alpha > 0 then
      self.nfframe:SetAlpha(alpha)
    end
    self:SetAlpha(0)
  end
  
  local function plate_OnShow(self)
    if psize and not InCombatLockdown() then
      self.overlay:SetSize(unpack(psize))
    end
    
    local nfframe = self.nfframe
      nfframe:Show()
      active[nfframe] = true
    
    -- Events
    local name = self.nametext:GetText()
    if not name or name == '' then name = 'Name' end
    name = name:gsub(' %(.+%)$','',1)
    
    local level = tonumber(self.leveltext:GetText())
    
    local classification = (
      self.bossicon:IsShown()      and 'worldboss' or
      self.eliteicon:IsShown()     and 'elite' or
      self.overlay:GetScale() < .5 and 'minus' or
      'normal'
    )
    
    if nfframe.update_info then
      nfframe:update_info(name,level,classification)
    end
    if nfframe.update_type then
      nfframe:update_type(compute_type(self))
    end
    
    -- Force an immediate update on other properties
    plate_OnUpdate(self)
    hpbar_OnValueChanged(self.hpbar)
  end
  
  local function plate_OnHide(self)
    self.nfframe:Hide()
    active[self.nfframe] = nil
  end


-- Creation
  local function handle_plate(plate)
    local overlay,name = plate:GetChildren()
    local hpbar,castbar = overlay:GetChildren()
    local nametext = name:GetRegions()
    local _,_,_,leveltext,bossicon,_,eliteicon = overlay:GetRegions()
    
    plate.overlay = overlay
    plate.hpbar = hpbar
    plate.castbar = castbar
    plate.nametext = nametext
    plate.leveltext = leveltext
    plate.bossicon = bossicon
    plate.eliteicon = eliteicon
    
    hpbar.parent = plate
    
    plate.nfframe = newplate()
    plate.nfframe.__p = plate
    if not manual_pos then
      plate.nfframe:SetPoint('CENTER',overlay,'CENTER')
    end
    
    plate:SetScript('OnShow',plate_OnShow)
    plate:SetScript('OnHide',plate_OnHide)
    plate:SetScript('OnUpdate',plate_OnUpdate)
    plate.hpbar:SetScript('OnValueChanged',hpbar_OnValueChanged)
    
    if plate:IsShown() then
      plate_OnShow(plate)
    end
  end


-- Scanning
  local function scan(f,...)
    if not f then return end
    
    if not f.NFNAMEPLATE then
      if (f:GetName() or ''):find('^NamePlate%d+$') then
        handle_plate(f)
        f.NFNAMEPLATE = true
      end
    end
    return scan(...)
  end
  
  local lastnum = 0
  mod:timer_register(.2,true,function()
    local num = WorldFrame:GetNumChildren()
    if num ~= lastnum then
      scan(WorldFrame:GetChildren())
      lastnum = num
    end
  end)


-- Sizer
  -- Attempt to resize the nameplate
  -- Derived from SemlarPlates by Semlar, with permission. <3
  if not psize then return end
  
  local sizer = CreateFrame('Frame',nil,WorldFrame,'SecureHandlerStateTemplate')
    sizer:SetAllPoints(true)
    sizer:Execute('children = newtable()')
    sizer:SetAttribute('_onstate-mousestate',[[
      wipe(children)
      self:GetParent():GetChildList(children)
      local f,c
      for i = 1,#children do
        f = children[i]
        if strmatch((f:GetName() or ''),'^NamePlate%d+$') then
          c = f:GetChildren()
          c:SetWidth(]]..psize[1]..[[)
          c:SetHeight(]]..psize[2]..[[)
        end
      end
    ]])
    RegisterStateDriver(sizer,'mousestate','[@mouseover,exists] on; off')
  
  local delayed = true
  local function DCF(self)
    delayed = not delayed
    if delayed then
      self:SetScript('OnUpdate',nil)
      FlipCameraYaw(-0.005)
    end
  end
  
  sizer:HookScript('OnAttributeChanged',function(self)
    FlipCameraYaw(0.005)
    self:SetScript('OnUpdate',DCF)
  end)
