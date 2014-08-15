

-- Initialize host
  local name,mod = ...
  _G[name] = mod
  
  mod.name     = name
  mod.version  = GetAddOnMetadata(name,'Version')
  mod.path     = 'Interface\\AddOns\\'..name
  mod.debuglog = {}


-- Error, type checking
  do
    local err_fmt = "bad argument #%s to '%s' (%s expected, got %s)"
    
    local function checktypelist(t,a1,...)
      if a1 then
        return t == a1 or checktypelist(t,...)
      end
    end
    
    function mod:argcheck(val,argn,...)
      if not checktypelist(type(val),...) then
        local name = debugstack(2,1,0):match("in function `([^']+)'") or '?'
        local types = ('/'):join(tostringall(...))
        argn = tonumber(argn) or '?'
        error(err_fmt:format(argn,name,types,type(val)),3)
      end
    end
  end
  
  function mod:softerror(err)
    if not pcall(geterrorhandler(),err) then
      self:print('|cffff7f7fError|r: %s',err)
    end
  end


-- I/O
  function mod:print(msg,...)
    msg = tostring(msg)
    msg = ('|cffff6fff%s|r: '..msg):format((self.name or '?'),...)
    DEFAULT_CHAT_FRAME:AddMessage(msg)
  end
  
  function mod:debug(msg,...)
    msg = tostring(msg)
    msg = ('%s> '..msg):format(date('%Y-%m-%d %H:%M:%S'),...)
    self.debuglog[#self.debuglog+1] = msg
  end


-- Events
  do
    local event_registry = {}  -- Active callbacks for event K
    local event_queue = {}     -- Callbacks waiting to be registered for event K
    local event_isiterating = {}
    
    local event_handler = CreateFrame('Frame')
    
    function mod:event_register(event,func)
      self:argcheck(event,1,'string')
      self:argcheck(func,2,'function')
      
      local E_registry = event_registry[event]
      local E_queue = event_queue[event]
      if not E_registry then  -- Registering event for first time
        E_registry = {}; event_registry[event] = E_registry
        E_queue = {};    event_queue[event] = E_queue
        event_handler:RegisterEvent(event)
      end
      
      if E_registry[func] or E_queue[func] then return func,false end
      
      if event_isiterating[event] then
        E_queue[func] = true
      else
        E_registry[func] = true
      end
      
      return func,true
    end
    
    function mod:event_unregister(event,func)
      local E_registry = event_registry[event]
      local E_queue = event_queue[event]
      if not E_registry then return end
      
      if not E_registry[func] and not E_queue[func] then return end
      
      E_registry[func] = nil
      E_queue[func] = nil
      
      if not next(E_registry) and not next(E_queue) then
        event_registry[event] = nil
        event_queue[event] = nil
        event_handler:UnregisterEvent(event)
      end
    end
    
    function mod:event_runonce(event,func)
      self:argcheck(event,1,'string')
      self:argcheck(func,2,'function')
      
      local f; f = function(...)
        self:event_unregister(event,f)
        return func(...)
      end
      self:event_register(event,f)
      
      return func
    end
    
    event_handler:SetScript('OnEvent',function(_,event,...)
      if event_isiterating[event] then
        mod:debug('event %q looped!',event)
        return  -- We're not re-entrant. This isn't supposed to occur anyway.
      end
      
      local E_registry = event_registry[event]
      local E_queue = event_queue[event]
      
      event_isiterating[event] = true
      local succ,err
      for func in pairs(E_registry) do
        succ,err = pcall(func,...)
        if not succ then mod:softerror(err) end
      end
      event_isiterating[event] = nil
      
      for func in pairs(E_queue) do
        E_registry[func] = true
        E_queue[func] = nil
      end
    end)
  end


-- Timers
  do
    local trecycle = {}
    local timer_registry = {}
    
    local T_dispatch
    
    local timer_handler = CreateFrame('Frame')
    
    local function gettimer()
      local T = trecycle[#trecycle]
      if T then
        trecycle[#trecycle] = nil
      else
        local agroup = timer_handler:CreateAnimationGroup()
        T = agroup:CreateAnimation()
        T.parent = agroup
        T:SetScript('OnFinished',T_dispatch)
      end
      return T
    end
    
    local function deltimer(T)
      trecycle[#trecycle+1] = T
    end
    
    function T_dispatch(T)  -- local
      local func = T.func
      local realdur = T:GetElapsed()
      
      if not T.rpt then
        T.rpt = nil
        T.func = nil
        timer_registry[func] = nil
        deltimer(T)
      end
      
      return func(realdur)
    end
    
    function mod:timer_register(delay,rpt,func)
      self:argcheck(delay,1,'number')
      self:argcheck(func,3,'function')
      
      if timer_registry[func] then return func,false end
      
      local T = gettimer()
      T.rpt = (not not rpt)
      T.func = func
      
      if delay < .01 then delay = .01 end  -- Thanks, Ace3
      
      T.parent:SetLooping(rpt and 'REPEAT' or 'NONE')
      T:SetDuration(delay)
      
      timer_registry[func] = T
      T.parent:Play()
      
      return func,true
    end
    
    function mod:timer_unregister(func)
      local T = timer_registry[func]
      if not T then return end
      
      timer_registry[func] = nil
      T.parent:Stop()
      T.rpt = nil
      T.func = nil
      deltimer(T)
    end
  end


-- Screen draws
  do
    local frecycle = {}
    local draw_registry = {}
    
    local function getframe()
      local F = frecycle[#frecycle]
      if F then
        frecycle[#frecycle] = nil
      else
        F = CreateFrame('Frame')
      end
      return F
    end
    
    local function delframe(F)
      frecycle[#frecycle+1] = F
    end
    
    function mod:update_register(func)
      self:argcheck(func,1,'function')
      
      if draw_registry[func] then return func,false end
      
      local F = getframe()
      F:SetScript('OnUpdate',function(_,e) func(e) end)
      draw_registry[func] = F
      
      return func,true
    end
    
    function mod:update_unregister(func)
      local F = draw_registry[func]
      if not F then return end
      
      draw_registry[func] = nil
      F:SetScript('OnUpdate',nil)
      delframe(F)
    end
    
    function mod:update_next(func)
      self:argcheck(func,1,'function')
      
      local f; f = function(e)
        self:update_unregister(f)
        return func(e)
      end
      self:update_register(f)
      
      return func
    end
  end
