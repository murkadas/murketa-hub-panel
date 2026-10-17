-- Coloque este bloco no início do seu script MURK.
-- Troque API_URL pelo endereço público da sua API.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local API_URL = "https://murketa-hub-panel.onrender.com/activate"
local KEY_FILE = "MurkESP_Key.txt"
local licenseRemainingSeconds = nil
local licenseRemainingText = "Permanente"
local function formatRemaining(totalSeconds)
    if totalSeconds == nil then return "Permanente" end
    totalSeconds = math.max(0, math.floor(tonumber(totalSeconds) or 0))
    local days = math.floor(totalSeconds / 86400)
    totalSeconds = totalSeconds % 86400
    local hours = math.floor(totalSeconds / 3600)
    totalSeconds = totalSeconds % 3600
    local minutes = math.floor(totalSeconds / 60)
    local seconds = totalSeconds % 60
    local parts = {}
    if days > 0 then table.insert(parts, days .. "d") end
    if hours > 0 or days > 0 then table.insert(parts, hours .. "h") end
    if minutes > 0 or hours > 0 or days > 0 then table.insert(parts, minutes .. "min") end
    if #parts == 0 then table.insert(parts, seconds .. "s") end
    return table.concat(parts, " ")
end
local function loadSavedKey()
    if type(isfile) ~= "function" or type(readfile) ~= "function" or not isfile(KEY_FILE) then
        return ""
    end
    local ok, value = pcall(readfile, KEY_FILE)
    return ok and tostring(value or ""):gsub("%s+", "") or ""
end
local function saveKey(value)
    if type(writefile) == "function" then
        pcall(writefile, KEY_FILE, tostring(value or ""))
    end
end
local function clearSavedKey()
    if type(delfile) == "function" and type(isfile) == "function" and isfile(KEY_FILE) then
        pcall(delfile, KEY_FILE)
    end
end
local httpRequest = request or http_request or (syn and syn.request) or (fluxus and fluxus.request) or (http and http.request)
local function getHWID()
    if type(gethwid) == "function" then
        local ok, value = pcall(gethwid)
        if ok and value and #tostring(value) >= 4 then
            return tostring(value)
        end
    end
    local ok, value = pcall(function()
        return game:GetService("RbxAnalyticsService"):GetClientId()
    end)
    return ok and tostring(value) or nil
end
local function createKeyGui()
    local gui = Instance.new("ScreenGui")
    gui.Name = "MurkOnlineKey"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(370, 205)
    frame.Position = UDim2.new(0.5, -185, 0.5, -102)
    frame.BackgroundColor3 = Color3.fromRGB(9, 9, 15)
    frame.BorderSizePixel = 0
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(150, 75, 240)
    stroke.Thickness = 1.5
    stroke.Parent = frame
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -36, 0, 35)
    title.Position = UDim2.fromOffset(18, 14)
    title.BackgroundTransparency = 1
    title.Text = "MURK  //  ONLINE KEY"
    title.TextColor3 = Color3.fromRGB(220, 130, 255)
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 19
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame
    local input = Instance.new("TextBox")
    input.Size = UDim2.new(1, -36, 0, 34)
    input.Position = UDim2.fromOffset(18, 65)
    input.BackgroundColor3 = Color3.fromRGB(24, 25, 37)
    input.PlaceholderText = "Digite sua key"
    input.TextColor3 = Color3.new(1, 1, 1)
    input.Font = Enum.Font.Gotham
    input.TextSize = 13
    input.ClearTextOnFocus = false
    input.Text = loadSavedKey()
    input.Parent = frame
    Instance.new("UICorner", input).CornerRadius = UDim.new(0, 7)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -36, 0, 34)
    button.Position = UDim2.fromOffset(18, 108)
    button.BackgroundColor3 = Color3.fromRGB(112, 52, 190)
    button.Text = "ACTIVATE"
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Font = Enum.Font.GothamBold
    button.TextSize = 12
    button.BorderSizePixel = 0
    button.Parent = frame
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 7)
    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -36, 0, 25)
    status.Position = UDim2.fromOffset(18, 154)
    status.BackgroundTransparency = 1
    status.Text = ""
    status.TextColor3 = Color3.fromRGB(255, 90, 110)
    status.Font = Enum.Font.Gotham
    status.TextSize = 11
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = frame
    return gui, input, button, status
end
local function authenticate()
    if type(httpRequest) ~= "function" then
        warn("MURK: executor sem suporte HTTP")
        return false
    end
    local hwid = getHWID()
    if not hwid then
        warn("MURK: não foi possível obter o HWID")
        return false
    end
    local gui, input, button, status = createKeyGui()
    local finished = false
    local accepted = false
    local function verify()
        status.Text = "Verificando..."
        status.TextColor3 = Color3.fromRGB(230, 190, 90)
        local ok, response = pcall(function()
            return httpRequest({
                Url = API_URL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode({ key = input.Text, hwid = hwid })
            })
        end)
        local responseBody = response and (response.Body or response.body)
        local responseStatus = response and (response.StatusCode or response.status_code or response.Status)
        if not ok or not response or not responseBody then
            status.Text = "API inacessível / executor sem HTTP"
            status.TextColor3 = Color3.fromRGB(255, 90, 110)
            warn("MURK: falha HTTP. Verifique API_URL e o suporte HTTP do executor.")
            return
        end
        local decodedOK, data = pcall(function()
            return HttpService:JSONDecode(responseBody)
        end)
        if not decodedOK or type(data) ~= "table" then
            status.Text = "Resposta inválida (HTTP " .. tostring(responseStatus or "?") .. ")"
            status.TextColor3 = Color3.fromRGB(255, 90, 110)
            return
        end
        if decodedOK and data and data.ok then
            saveKey(input.Text)
            licenseRemainingSeconds = data.remainingSeconds
            licenseRemainingText = formatRemaining(licenseRemainingSeconds)
            accepted = true
            finished = true
            status.Text = "Licença ativada"
            status.TextColor3 = Color3.fromRGB(80, 230, 160)
            task.wait(0.35)
            gui:Destroy()
        else
            local errorCode = decodedOK and data and data.error or "UNKNOWN_ERROR"
            if errorCode == "INVALID_KEY" or errorCode == "EXPIRED_KEY" or errorCode == "REVOKED_KEY" or errorCode == "HWID_MISMATCH" then
                clearSavedKey()
            end
            status.Text = tostring(errorCode)
            status.TextColor3 = Color3.fromRGB(255, 90, 110)
        end
    end
    button.MouseButton1Click:Connect(verify)
    input.FocusLost:Connect(function(enterPressed)
        if enterPressed then verify() end
    end)
    if input.Text ~= "" then
        task.defer(verify)
    end
    repeat task.wait() until finished
    return accepted
end
if not authenticate() then
    return
end
-- O restante do seu script MURK vem abaixo deste bloco.
local P=game:GetService("Players")local R=game:GetService("RunService")local U=game:GetService("UserInputService")local T=game:GetService("TweenService")local LP=P.LocalPlayer local C=workspace.CurrentCamera
local cfg={En=false,Box=true,Nm=true,Dst=true,Hp=true,CarESP=false,CarBox=true,CarNm=true,CarDst=true,EspHue=0.58,CarHue=0.10,Fs=14,FriendQuery="",Friends={},Team=false,Aim=false,AimPart="Head",Fov=150,Smooth=2,WallCheck=true,IgnoreTeam=true,MaxDist=500,NoRecoil=false,GunGiant=false,GunSize=2,GunSound="Normal"}
local CFG_FILE="MurkESP_Config.json"
local function loadCfg()
    if type(isfile)~="function" or type(readfile)~="function" or not isfile(CFG_FILE) then return end
    local ok,data=pcall(function()return HttpService:JSONDecode(readfile(CFG_FILE))end)
    if not ok or type(data)~="table" then return end
    for k,v in pairs(data)do if cfg[k]~=nil and type(v)==type(cfg[k])then cfg[k]=v end end
end
local function saveCfg()
    if type(writefile)~="function" then return end
    pcall(function()writefile(CFG_FILE,HttpService:JSONEncode(cfg))end)
end
loadCfg()
local cache={}local gui,frame,mtog,sbar,content,licenseLabel,homeExpiryLabel,homeStreamerButton local open=false local collapsed=false local streamerMode=false local hue=0 local isM=U.TouchEnabled and not U.MouseEnabled
local resetGunSoundsAction=nil
local rgb={}local fovC=nil
local function sc()return Color3.fromHSV(hue,0.8,1)end
local function espColor()return Color3.fromHSV(tonumber(cfg.EspHue)or 0.58,0.85,1)end
local function carColor()return Color3.fromHSV(tonumber(cfg.CarHue)or 0.10,0.85,1)end
local function friendMatches(p)
    local query=tostring(cfg.FriendQuery or ""):lower():gsub("^%s+",""):gsub("%s+$","")
    if p==LP then return false end
    if type(cfg.Friends)=="table" and #cfg.Friends>0 then
        for _,friendName in ipairs(cfg.Friends) do
            if tostring(friendName):lower()==tostring(p.Name):lower() then return true end
        end
    end
    if query=="" then return false end
    local name=tostring(p.Name or ""):lower()
    local display=tostring(p.DisplayName or ""):lower()
    return name:find(query,1,true)~=nil or display:find(query,1,true)~=nil
end
local function sf(f)return function(...)local ok,e=pcall(f,...)if not ok then warn("[MURK]",e)end return ok end end
pcall(function()local o=LP:WaitForChild("PlayerGui"):FindFirstChild("MurkESP")if o then o:Destroy()end end)
gui=Instance.new("ScreenGui")gui.Name="MurkESP"gui.ResetOnSpawn=false gui.IgnoreGuiInset=true gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling gui.Parent=LP:WaitForChild("PlayerGui")
local intro=Instance.new("TextLabel")intro.Size=UDim2.new(1,0,1,0)intro.BackgroundTransparency=1 intro.Text="MURK"intro.TextColor3=sc()intro.Font=Enum.Font.GothamBlack intro.TextScaled=true intro.TextStrokeTransparency=0 intro.TextStrokeColor3=Color3.new()intro.TextSize=0 intro.ZIndex=20 intro.Parent=gui table.insert(rgb,intro)
T:Create(intro,TweenInfo.new(1.2,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{TextSize=120}):Play()
task.delay(2.5,function()local f=T:Create(intro,TweenInfo.new(1.5,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{TextTransparency=1,TextStrokeTransparency=1})f:Play()f.Completed:Wait()intro:Destroy()end)
frame=Instance.new("Frame")frame.Name="MainFrame"frame.Size=UDim2.new(0,520,0,360)frame.Position=UDim2.new(0.5,-260,0.5,-180)frame.BackgroundColor3=Color3.fromRGB(8,8,12)frame.BorderSizePixel=0 frame.Active=true frame.Draggable=true frame.Visible=false frame.ZIndex=10 frame.ClipsDescendants=true frame.Parent=gui
Instance.new("UICorner",frame).CornerRadius=UDim.new(0,10)
local ms=Instance.new("UIStroke")ms.Thickness=1.5 ms.Color=sc()ms.Transparency=0.2 ms.Parent=frame table.insert(rgb,ms)
sbar=Instance.new("Frame")sbar.Size=UDim2.new(0,130,1,0)sbar.BackgroundColor3=Color3.fromRGB(5,5,8)sbar.BorderSizePixel=0 sbar.Parent=frame Instance.new("UICorner",sbar).CornerRadius=UDim.new(0,10)
local fx=Instance.new("Frame")fx.Size=UDim2.new(0,10,1,0)fx.Position=UDim2.new(1,-10,0,0)fx.BackgroundColor3=Color3.fromRGB(5,5,8)fx.BorderSizePixel=0 fx.ZIndex=11 fx.Parent=sbar
local bl=Instance.new("TextLabel")bl.Size=UDim2.new(1,0,0,50)bl.Position=UDim2.new(0,0,0,15)bl.BackgroundTransparency=1 bl.Text="MURK"bl.TextColor3=sc()bl.Font=Enum.Font.GothamBlack bl.TextSize=26 bl.TextStrokeTransparency=0.7 bl.Parent=sbar table.insert(rgb,bl)
local ln=Instance.new("Frame")ln.Size=UDim2.new(0,80,0,1)ln.Position=UDim2.new(0.5,-40,0,62)ln.BackgroundColor3=sc()ln.BorderSizePixel=0 ln.Parent=sbar table.insert(rgb,ln)
local ts=Instance.new("ScrollingFrame")ts.Size=UDim2.new(1,-20,1,-85)ts.Position=UDim2.new(0,10,0,75)ts.BackgroundTransparency=1 ts.BorderSizePixel=0 ts.ScrollBarThickness=3 ts.ScrollBarImageColor3=Color3.fromRGB(120,50,200)ts.CanvasSize=UDim2.new()ts.AutomaticCanvasSize=Enum.AutomaticSize.Y ts.Parent=sbar
local tl=Instance.new("UIListLayout")tl.Padding=UDim.new(0,6)tl.SortOrder=Enum.SortOrder.LayoutOrder tl.Parent=ts
content=Instance.new("Frame")content.Size=UDim2.new(1,-130,1,0)content.Position=UDim2.new(0,130,0,0)content.BackgroundTransparency=1 content.Parent=frame
local ct=Instance.new("TextLabel")ct.Size=UDim2.new(1,-220,0,40)ct.Position=UDim2.new(0,20,0,15)ct.BackgroundTransparency=1 ct.Text="ESP"ct.TextColor3=Color3.fromRGB(240,240,240)ct.Font=Enum.Font.GothamBold ct.TextSize=20 ct.TextXAlignment=Enum.TextXAlignment.Left ct.Parent=content
licenseLabel=Instance.new("TextLabel")licenseLabel.Size=UDim2.new(0,180,0,28)licenseLabel.Position=UDim2.new(1,-210,0,21)licenseLabel.BackgroundTransparency=1 licenseLabel.Text="Restante: "..licenseRemainingText licenseLabel.TextColor3=Color3.fromRGB(170,130,220)licenseLabel.Font=Enum.Font.GothamBold licenseLabel.TextSize=11 licenseLabel.TextXAlignment=Enum.TextXAlignment.Right licenseLabel.Parent=content
task.spawn(function()while licenseLabel and licenseLabel.Parent do if licenseRemainingSeconds then if licenseRemainingSeconds<=0 then licenseLabel.Text="Key expirada"if homeExpiryLabel then homeExpiryLabel.Text="Sua key expirou"end break end local remainingText=formatRemaining(licenseRemainingSeconds)licenseLabel.Text="Restante: "..remainingText if homeExpiryLabel then homeExpiryLabel.Text="Sua key expira em: "..remainingText end licenseRemainingSeconds=licenseRemainingSeconds-1 end task.wait(1)end end)
local cl=Instance.new("Frame")cl.Size=UDim2.new(1,-40,0,1)cl.Position=UDim2.new(0,20,0,55)cl.BackgroundColor3=Color3.fromRGB(40,20,60)cl.BorderSizePixel=0 cl.Parent=content
local xb=Instance.new("TextButton")xb.Size=UDim2.new(0,26,0,26)xb.Position=UDim2.new(1,-36,0,15)xb.BackgroundColor3=Color3.fromRGB(30,10,40)xb.Text="X"xb.TextColor3=Color3.fromRGB(200,100,255)xb.Font=Enum.Font.GothamBold xb.TextSize=14 xb.BorderSizePixel=0 xb.AutoButtonColor=false xb.Parent=content Instance.new("UICorner",xb).CornerRadius=UDim.new(0,6)
local pages={}
local function mkPage(n)local p=Instance.new("ScrollingFrame")p.Size=UDim2.new(1,-40,1,-75)p.Position=UDim2.new(0,20,0,65)p.BackgroundTransparency=1 p.BorderSizePixel=0 p.ScrollBarThickness=4 p.ScrollBarImageColor3=Color3.fromRGB(120,50,200)p.CanvasSize=UDim2.new()p.AutomaticCanvasSize=Enum.AutomaticSize.Y p.Visible=false p.Parent=content local l=Instance.new("UIListLayout")l.Padding=UDim.new(0,8)l.SortOrder=Enum.SortOrder.LayoutOrder l.Parent=p local pd=Instance.new("UIPadding")pd.PaddingRight=UDim.new(0,8)pd.PaddingBottom=UDim.new(0,10)pd.Parent=p pages[n]=p return p end
mkPage("HOME")mkPage("ESP")mkPage("AIM")mkPage("GUN")
local function mkTog(par,lab,k,ord)local b=Instance.new("TextButton")b.Size=UDim2.new(1,0,0,34)b.BackgroundColor3=Color3.fromRGB(15,15,20)b.Text=""b.BorderSizePixel=0 b.AutoButtonColor=false b.LayoutOrder=ord b.Parent=par Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)
local s=Instance.new("UIStroke")s.Thickness=1 s.Color=Color3.fromRGB(40,20,60)s.Transparency=0.3 s.Parent=b
local lt=Instance.new("TextLabel")lt.Size=UDim2.new(1,-60,1,0)lt.Position=UDim2.new(0,12,0,0)lt.BackgroundTransparency=1 lt.Text=lab lt.TextColor3=Color3.fromRGB(220,220,220)lt.Font=Enum.Font.Gotham lt.TextSize=13 lt.TextXAlignment=Enum.TextXAlignment.Left lt.Parent=b
local sb=Instance.new("Frame")sb.Size=UDim2.new(0,36,0,18)sb.Position=UDim2.new(1,-48,0.5,-9)sb.BackgroundColor3=cfg[k]and Color3.fromRGB(120,50,200)or Color3.fromRGB(35,35,45)sb.BorderSizePixel=0 sb.Parent=b Instance.new("UICorner",sb).CornerRadius=UDim.new(0,9)
local kn=Instance.new("Frame")kn.Size=UDim2.new(0,14,0,14)kn.Position=cfg[k]and UDim2.new(1,-16,0.5,-7)or UDim2.new(0,2,0.5,-7)kn.BackgroundColor3=Color3.new(1,1,1)kn.BorderSizePixel=0 kn.Parent=sb Instance.new("UICorner",kn).CornerRadius=UDim.new(0,7)
b.MouseButton1Click:Connect(sf(function()cfg[k]=not cfg[k]saveCfg()T:Create(sb,TweenInfo.new(0.15),{BackgroundColor3=cfg[k]and Color3.fromRGB(120,50,200)or Color3.fromRGB(35,35,45)}):Play()T:Create(kn,TweenInfo.new(0.15),{Position=cfg[k]and UDim2.new(1,-16,0.5,-7)or UDim2.new(0,2,0.5,-7)}):Play()end))end
local function mkMain(par,ord,txt)local b=Instance.new("TextButton")b.Size=UDim2.new(1,0,0,40)b.BackgroundColor3=Color3.fromRGB(30,10,45)b.Text=txt or "ESP: DESATIVADO"b.TextColor3=Color3.fromRGB(220,100,255)b.Font=Enum.Font.GothamBold b.TextSize=15 b.BorderSizePixel=0 b.AutoButtonColor=false b.LayoutOrder=ord b.Parent=par Instance.new("UICorner",b).CornerRadius=UDim.new(0,8)
local s=Instance.new("UIStroke")s.Thickness=1 s.Color=sc()s.Transparency=0.4 s.Parent=b table.insert(rgb,s)return b end
local function mkSld(par,lab,k,mn,mx,ord,stp)stp=stp or 1 local c=Instance.new("Frame")c.Size=UDim2.new(1,0,0,42)c.BackgroundColor3=Color3.fromRGB(15,15,20)c.BorderSizePixel=0 c.LayoutOrder=ord c.Parent=par Instance.new("UICorner",c).CornerRadius=UDim.new(0,6)
local s=Instance.new("UIStroke")s.Thickness=1 s.Color=Color3.fromRGB(40,20,60)s.Transparency=0.3 s.Parent=c
local lt=Instance.new("TextLabel")lt.Size=UDim2.new(1,-24,0,20)lt.Position=UDim2.new(0,12,0,4)lt.BackgroundTransparency=1 lt.Text=lab..": "..cfg[k]lt.TextColor3=Color3.fromRGB(220,220,220)lt.Font=Enum.Font.Gotham lt.TextSize=12 lt.TextXAlignment=Enum.TextXAlignment.Left lt.Parent=c
local sl=Instance.new("TextButton")sl.Size=UDim2.new(1,-24,0,8)sl.Position=UDim2.new(0,12,0,28)sl.BackgroundColor3=Color3.fromRGB(30,30,40)sl.Text=""sl.BorderSizePixel=0 sl.AutoButtonColor=false sl.Parent=c Instance.new("UICorner",sl).CornerRadius=UDim.new(0,4)
local fl=Instance.new("Frame")local pc=(cfg[k]-mn)/(mx-mn)fl.Size=UDim2.new(pc,0,1,0)fl.BackgroundColor3=Color3.fromRGB(140,60,220)fl.BorderSizePixel=0 fl.Parent=sl Instance.new("UICorner",fl).CornerRadius=UDim.new(0,4)
local drg=false
sl.InputBegan:Connect(sf(function(i)if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drg=true end end))
U.InputEnded:Connect(function(i)if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drg=false end end)
U.InputChanged:Connect(sf(function(i)if drg and(i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch)then local r=math.clamp((i.Position.X-sl.AbsolutePosition.X)/sl.AbsoluteSize.X,0,1)local v=mn+r*(mx-mn)v=math.floor(v/stp+0.5)*stp if k=="Smooth"then v=math.floor(v*10+0.5)/10 end cfg[k]=v saveCfg()fl.Size=UDim2.new(r,0,1,0)lt.Text=lab..": "..v end end))end
local function mkDrop(par,lab,k,opts,ord)local c=Instance.new("Frame")c.Size=UDim2.new(1,0,0,34)c.BackgroundColor3=Color3.fromRGB(15,15,20)c.BorderSizePixel=0 c.LayoutOrder=ord c.Parent=par Instance.new("UICorner",c).CornerRadius=UDim.new(0,6)
local s=Instance.new("UIStroke")s.Thickness=1 s.Color=Color3.fromRGB(40,20,60)s.Transparency=0.3 s.Parent=c
local lt=Instance.new("TextLabel")lt.Size=UDim2.new(1,-110,1,0)lt.Position=UDim2.new(0,12,0,0)lt.BackgroundTransparency=1 lt.Text=lab lt.TextColor3=Color3.fromRGB(220,220,220)lt.Font=Enum.Font.Gotham lt.TextSize=13 lt.TextXAlignment=Enum.TextXAlignment.Left lt.Parent=c
local btn=Instance.new("TextButton")btn.Size=UDim2.new(0,90,0,24)btn.Position=UDim2.new(1,-102,0.5,-12)btn.BackgroundColor3=Color3.fromRGB(35,35,45)btn.Text=cfg[k]btn.TextColor3=Color3.fromRGB(220,100,255)btn.Font=Enum.Font.GothamBold btn.TextSize=12 btn.BorderSizePixel=0 btn.AutoButtonColor=false btn.Parent=c Instance.new("UICorner",btn).CornerRadius=UDim.new(0,5)
btn.MouseButton1Click:Connect(sf(function()local idx=1 for i,v in ipairs(opts)do if v==cfg[k]then idx=i break end end idx=idx%#opts+1 cfg[k]=opts[idx]saveCfg()btn.Text=cfg[k]end))end
local function mkAction(par,lab,ord,fn)
    local b=Instance.new("TextButton") b.Size=UDim2.new(1,0,0,34) b.BackgroundColor3=Color3.fromRGB(55,25,35) b.Text=lab b.TextColor3=Color3.fromRGB(255,190,190) b.Font=Enum.Font.GothamBold b.TextSize=12 b.BorderSizePixel=0 b.AutoButtonColor=false b.LayoutOrder=ord b.Parent=par
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)
    b.MouseButton1Click:Connect(sf(fn))
end
local function mkColorPicker(par,lab,k,ord)
    local c=Instance.new("Frame") c.Size=UDim2.new(1,0,0,58) c.BackgroundColor3=Color3.fromRGB(15,15,20) c.BorderSizePixel=0 c.LayoutOrder=ord c.Parent=par
    Instance.new("UICorner",c).CornerRadius=UDim.new(0,6)
    local s=Instance.new("UIStroke") s.Thickness=1 s.Color=Color3.fromRGB(40,20,60) s.Transparency=0.3 s.Parent=c
    local lt=Instance.new("TextLabel") lt.Size=UDim2.new(1,-120,0,22) lt.Position=UDim2.fromOffset(12,4) lt.BackgroundTransparency=1 lt.Text=lab lt.TextColor3=Color3.fromRGB(220,220,220) lt.Font=Enum.Font.Gotham lt.TextSize=12 lt.TextXAlignment=Enum.TextXAlignment.Left lt.Parent=c
    local preview=Instance.new("Frame") preview.Size=UDim2.fromOffset(18,18) preview.Position=UDim2.new(1,-32,0,6) preview.BackgroundColor3=Color3.fromHSV(cfg[k],0.85,1) preview.BorderSizePixel=0 preview.Parent=c Instance.new("UICorner",preview).CornerRadius=UDim.new(1,0)
    local strip=Instance.new("TextButton") strip.Size=UDim2.new(1,-24,0,14) strip.Position=UDim2.fromOffset(12,34) strip.BackgroundColor3=Color3.new(1,1,1) strip.Text="" strip.BorderSizePixel=0 strip.AutoButtonColor=false strip.Parent=c Instance.new("UICorner",strip).CornerRadius=UDim.new(0,7)
    local grad=Instance.new("UIGradient") grad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromHSV(0,1,1)),ColorSequenceKeypoint.new(.166,Color3.fromHSV(.166,1,1)),ColorSequenceKeypoint.new(.333,Color3.fromHSV(.333,1,1)),ColorSequenceKeypoint.new(.5,Color3.fromHSV(.5,1,1)),ColorSequenceKeypoint.new(.666,Color3.fromHSV(.666,1,1)),ColorSequenceKeypoint.new(.833,Color3.fromHSV(.833,1,1)),ColorSequenceKeypoint.new(1,Color3.fromHSV(1,1,1))}) grad.Parent=strip
    local dot=Instance.new("Frame") dot.Size=UDim2.fromOffset(16,16) dot.AnchorPoint=Vector2.new(.5,.5) dot.Position=UDim2.new(cfg[k],0,.5,0) dot.BackgroundColor3=Color3.new(1,1,1) dot.BorderSizePixel=0 dot.ZIndex=3 dot.Parent=strip Instance.new("UICorner",dot).CornerRadius=UDim.new(1,0)
    local function setHue(x)
        local value=math.clamp((x-strip.AbsolutePosition.X)/math.max(strip.AbsoluteSize.X,1),0,1)
        cfg[k]=value saveCfg() dot.Position=UDim2.new(value,0,.5,0) preview.BackgroundColor3=Color3.fromHSV(value,.85,1)
    end
    local dragging=false
    strip.InputBegan:Connect(sf(function(i)if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=true setHue(i.Position.X)end end))
    U.InputEnded:Connect(function(i)if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end end)
    U.InputChanged:Connect(sf(function(i)if dragging and(i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch)then setHue(i.Position.X)end end))
end
local function mkFriendControl(par,ord)
    local c=Instance.new("Frame")
    c.Size=UDim2.new(1,0,0,230)
    c.BackgroundColor3=Color3.fromRGB(15,15,20)
    c.BorderSizePixel=0
    c.LayoutOrder=ord
    c.Parent=par
    Instance.new("UICorner",c).CornerRadius=UDim.new(0,6)
    local s=Instance.new("UIStroke")
    s.Thickness=1
    s.Color=Color3.fromRGB(40,20,60)
    s.Transparency=0.3
    s.Parent=c
    local title=Instance.new("TextLabel")
    title.Size=UDim2.new(1,-24,0,20)
    title.Position=UDim2.fromOffset(12,5)
    title.BackgroundTransparency=1
    title.Text="Amigo protegido"
    title.TextColor3=Color3.fromRGB(220,220,220)
    title.Font=Enum.Font.Gotham
    title.TextSize=12
    title.TextXAlignment=Enum.TextXAlignment.Left
    title.Parent=c
    local input=Instance.new("TextBox")
    input.Size=UDim2.new(1,-140,0,28)
    input.Position=UDim2.fromOffset(12,30)
    input.BackgroundColor3=Color3.fromRGB(25,25,34)
    input.BorderSizePixel=0
    input.ClearTextOnFocus=false
    input.PlaceholderText="Nome parcial, ex.: lule"
    input.Text=tostring(cfg.FriendQuery or "")
    input.TextColor3=Color3.fromRGB(235,235,235)
    input.Font=Enum.Font.Gotham
    input.TextSize=11
    input.TextXAlignment=Enum.TextXAlignment.Left
    input.Parent=c
    Instance.new("UICorner",input).CornerRadius=UDim.new(0,5)
    local refresh=Instance.new("TextButton")
    refresh.Size=UDim2.new(0,112,0,28)
    refresh.Position=UDim2.new(1,-124,0,30)
    refresh.BackgroundColor3=Color3.fromRGB(35,16,50)
    refresh.BorderSizePixel=0
    refresh.AutoButtonColor=false
    refresh.Text="Atualizar lista"
    refresh.TextColor3=Color3.fromRGB(220,170,255)
    refresh.Font=Enum.Font.GothamBold
    refresh.TextSize=10
    refresh.Parent=c
    Instance.new("UICorner",refresh).CornerRadius=UDim.new(0,5)
    local status=Instance.new("TextLabel")
    status.Size=UDim2.new(1,-24,0,18)
    status.Position=UDim2.fromOffset(12,66)
    status.BackgroundTransparency=1
    status.TextColor3=Color3.fromRGB(125,235,155)
    status.Font=Enum.Font.Gotham
    status.TextSize=10
    status.TextWrapped=false
    status.TextXAlignment=Enum.TextXAlignment.Left
    status.TextYAlignment=Enum.TextYAlignment.Top
    status.Parent=c
    local list=Instance.new("ScrollingFrame")
    list.Size=UDim2.new(1,-24,0,82)
    list.Position=UDim2.fromOffset(12,88)
    list.BackgroundColor3=Color3.fromRGB(10,10,15)
    list.BorderSizePixel=0
    list.ScrollBarThickness=3
    list.ScrollBarImageColor3=Color3.fromRGB(120,50,200)
    list.CanvasSize=UDim2.new()
    list.AutomaticCanvasSize=Enum.AutomaticSize.Y
    list.Parent=c
    Instance.new("UICorner",list).CornerRadius=UDim.new(0,5)
    local listLayout=Instance.new("UIListLayout")
    listLayout.Padding=UDim.new(0,3)
    listLayout.SortOrder=Enum.SortOrder.Name
    listLayout.Parent=list
    local listPadding=Instance.new("UIPadding")
    listPadding.PaddingTop=UDim.new(0,4)
    listPadding.PaddingLeft=UDim.new(0,4)
    listPadding.PaddingRight=UDim.new(0,4)
    listPadding.Parent=list
    local removeFriend=Instance.new("TextButton")
    removeFriend.Size=UDim2.new(0.5,-15,0,28)
    removeFriend.Position=UDim2.fromOffset(12,176)
    removeFriend.BackgroundColor3=Color3.fromRGB(70,28,42)
    removeFriend.BorderSizePixel=0
    removeFriend.AutoButtonColor=false
    removeFriend.Text="Remover amigo"
    removeFriend.TextColor3=Color3.fromRGB(255,170,180)
    removeFriend.Font=Enum.Font.GothamBold
    removeFriend.TextSize=10
    removeFriend.Parent=c
    Instance.new("UICorner",removeFriend).CornerRadius=UDim.new(0,5)
    local removeAll=Instance.new("TextButton")
    removeAll.Size=UDim2.new(0.5,-15,0,28)
    removeAll.Position=UDim2.new(0.5,3,0,176)
    removeAll.BackgroundColor3=Color3.fromRGB(85,24,32)
    removeAll.BorderSizePixel=0
    removeAll.AutoButtonColor=false
    removeAll.Text="Tirar todos"
    removeAll.TextColor3=Color3.fromRGB(255,190,150)
    removeAll.Font=Enum.Font.GothamBold
    removeAll.TextSize=10
    removeAll.Parent=c
    Instance.new("UICorner",removeAll).CornerRadius=UDim.new(0,5)
    local function refreshList()
        for _,child in ipairs(list:GetChildren()) do
            if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
                child:Destroy()
            end
        end
        local players={}
        local matches={}
        for _,p in ipairs(P:GetPlayers()) do
            if p~=LP then
                table.insert(players,p)
                if friendMatches(p) then table.insert(matches,p.Name) end
            end
        end
        table.sort(players,function(a,b)return a.Name:lower()<b.Name:lower()end)
        for index,p in ipairs(players) do
            local row=Instance.new("TextButton")
            row.Name=string.format("%03d_%s",index,p.Name)
            row.Size=UDim2.new(1,-8,0,24)
            row.BackgroundColor3=friendMatches(p) and Color3.fromRGB(25,75,40) or Color3.fromRGB(24,24,32)
            row.BorderSizePixel=0
            row.AutoButtonColor=false
            row.Text=(p.DisplayName~=p.Name and p.DisplayName.."  @"..p.Name or p.Name)
            row.TextColor3=friendMatches(p) and Color3.fromRGB(110,255,145) or Color3.fromRGB(220,220,220)
            row.Font=Enum.Font.Gotham
            row.TextSize=10
            row.TextXAlignment=Enum.TextXAlignment.Left
            row.Parent=list
            Instance.new("UICorner",row).CornerRadius=UDim.new(0,4)
            row.MouseButton1Click:Connect(sf(function()
                local selected=false
                for i=#cfg.Friends,1,-1 do
                    if tostring(cfg.Friends[i]):lower()==p.Name:lower() then
                        table.remove(cfg.Friends,i)
                        selected=true
                    end
                end
                if not selected then
                    table.insert(cfg.Friends,p.Name)
                    cfg.FriendQuery=p.Name
                    input.Text=p.Name
                else
                    cfg.FriendQuery=""
                    input.Text=""
                end
                saveCfg()
                refreshList()
            end))
        end
        local protected={}
        for _,friendName in ipairs(cfg.Friends) do
            table.insert(protected,tostring(friendName))
        end
        if #protected>0 then
            status.Text="Protegidos: "..table.concat(protected,", ").."  | ESP verde"
        elseif tostring(cfg.FriendQuery or ""):gsub("%s+","")=="" then
            status.Text=#players==0 and "Nenhum outro jogador no servidor" or "Clique em um jogador para proteger"
        elseif #matches==0 then
            status.Text="Nenhum jogador corresponde ao nome"
        else
            status.Text="Encontrados: "..table.concat(matches,", ").." | clique para proteger"
        end
    end
    input.FocusLost:Connect(sf(function()
        cfg.FriendQuery=input.Text
        saveCfg()
        refreshList()
    end))
    refresh.MouseButton1Click:Connect(sf(function()
        cfg.FriendQuery=input.Text
        saveCfg()
        refreshList()
    end))
    removeFriend.MouseButton1Click:Connect(sf(function()
        local target=tostring(input.Text or ""):lower():gsub("^%s+",""):gsub("%s+$","")
        if target=="" then
            status.Text="Digite ou selecione um amigo primeiro"
            return
        end
        for i=#cfg.Friends,1,-1 do
            local saved=tostring(cfg.Friends[i]):lower()
            if saved==target or saved:find(target,1,true) then
                table.remove(cfg.Friends,i)
                break
            end
        end
        cfg.FriendQuery=""
        input.Text=""
        saveCfg()
        refreshList()
    end))
    removeAll.MouseButton1Click:Connect(sf(function()
        cfg.Friends={}
        cfg.FriendQuery=""
        input.Text=""
        saveCfg()
        refreshList()
    end))
    P.PlayerAdded:Connect(function()task.defer(refreshList)end)
    P.PlayerRemoving:Connect(function()task.defer(refreshList)end)
    refreshList()
end
local home=pages["HOME"]
local homeTitle=Instance.new("TextLabel")homeTitle.Size=UDim2.new(1,0,0,48)homeTitle.BackgroundTransparency=1 homeTitle.Text="BEM-VINDO À MURKADAS HUB"homeTitle.TextColor3=Color3.fromRGB(220,130,255)homeTitle.Font=Enum.Font.GothamBlack homeTitle.TextSize=18 homeTitle.TextScaled=false homeTitle.TextXAlignment=Enum.TextXAlignment.Left homeTitle.Parent=home
local homeSub=Instance.new("TextLabel")homeSub.Size=UDim2.new(1,0,0,32)homeSub.BackgroundTransparency=1 homeSub.Text="Seu painel está pronto. Configure tudo pelas abas ao lado."homeSub.TextColor3=Color3.fromRGB(155,155,175)homeSub.Font=Enum.Font.Gotham homeSub.TextSize=12 homeSub.TextWrapped=true homeSub.TextXAlignment=Enum.TextXAlignment.Left homeSub.Parent=home
local homeCard=Instance.new("Frame")homeCard.Size=UDim2.new(1,0,0,92)homeCard.BackgroundColor3=Color3.fromRGB(22,14,32)homeCard.BorderSizePixel=0 homeCard.Parent=home Instance.new("UICorner",homeCard).CornerRadius=UDim.new(0,10)
local homeStroke=Instance.new("UIStroke")homeStroke.Color=Color3.fromRGB(140,60,220)homeStroke.Transparency=0.35 homeStroke.Parent=homeCard
local homeStatus=Instance.new("TextLabel")homeStatus.Size=UDim2.new(1,-24,0,25)homeStatus.Position=UDim2.new(0,12,0,10)homeStatus.BackgroundTransparency=1 homeStatus.Text="● SISTEMA ONLINE"homeStatus.TextColor3=Color3.fromRGB(85,230,165)homeStatus.Font=Enum.Font.GothamBold homeStatus.TextSize=13 homeStatus.TextXAlignment=Enum.TextXAlignment.Left homeStatus.Parent=homeCard
homeExpiryLabel=Instance.new("TextLabel")homeExpiryLabel.Size=UDim2.new(1,-24,0,25)homeExpiryLabel.Position=UDim2.new(0,12,0,42)homeExpiryLabel.BackgroundTransparency=1 homeExpiryLabel.Text="Sua key expira em: "..licenseRemainingText homeExpiryLabel.TextColor3=Color3.fromRGB(230,210,245)homeExpiryLabel.Font=Enum.Font.Gotham homeExpiryLabel.TextSize=13 homeExpiryLabel.TextXAlignment=Enum.TextXAlignment.Left homeExpiryLabel.Parent=homeCard
local homeTip=Instance.new("TextLabel")homeTip.Size=UDim2.new(1,0,0,30)homeTip.BackgroundTransparency=1 homeTip.Text="Dica: RightShift abre o menu | RightAlt alterna o modo streamer."homeTip.TextColor3=Color3.fromRGB(130,130,150)homeTip.Font=Enum.Font.Gotham homeTip.TextSize=10 homeTip.TextWrapped=true homeTip.TextXAlignment=Enum.TextXAlignment.Left homeTip.Parent=home
homeStreamerButton=Instance.new("TextButton")homeStreamerButton.Size=UDim2.new(1,0,0,38)homeStreamerButton.BackgroundColor3=Color3.fromRGB(35,16,50)homeStreamerButton.Text="MODO STREAMER: DESATIVADO"homeStreamerButton.TextColor3=Color3.fromRGB(220,170,255)homeStreamerButton.Font=Enum.Font.GothamBold homeStreamerButton.TextSize=12 homeStreamerButton.BorderSizePixel=0 homeStreamerButton.AutoButtonColor=false homeStreamerButton.LayoutOrder=5 homeStreamerButton.Parent=home Instance.new("UICorner",homeStreamerButton).CornerRadius=UDim.new(0,8)
local ep=pages["ESP"]local et=mkMain(ep,1)et.Text=cfg.En and "ESP: ATIVADO"or "ESP: DESATIVADO"
mkTog(ep,"Box","Box",2)mkTog(ep,"Nome","Nm",3)mkTog(ep,"Distancia","Dst",4)mkTog(ep,"Vida","Hp",5)mkTog(ep,"Carros","CarESP",6)mkTog(ep,"Cor do Time","Team",7)mkColorPicker(ep,"Cor dos jogadores","EspHue",8)mkTog(ep,"Box dos carros","CarBox",9)mkTog(ep,"Nome dos carros","CarNm",10)mkTog(ep,"Distancia dos carros","CarDst",11)mkColorPicker(ep,"Cor dos carros","CarHue",12)mkSld(ep,"Fonte","Fs",8,32,13)
local ap=pages["AIM"]local at=mkMain(ap,1,"AIM: DESATIVADO")at.Text=cfg.Aim and "AIM: ATIVADO"or "AIM: DESATIVADO"
mkTog(ap,"Wall Check","WallCheck",2)mkTog(ap,"Ignorar Time","IgnoreTeam",3)
mkDrop(ap,"Parte","AimPart",{"Head","Torso","HumanoidRootPart"},4)
mkFriendControl(ap,5)
mkSld(ap,"FOV","Fov",50,600,6,10)mkSld(ap,"Distancia","MaxDist",50,2000,7,50)mkSld(ap,"Suavidade","Smooth",0,5,8,0.1)
local gp=pages["GUN"]
mkTog(gp,"Sem recoil","NoRecoil",1)mkTog(gp,"Arma gigante (visual)","GunGiant",2)mkSld(gp,"Tamanho (visual)","GunSize",1,2,3,0.1)mkDrop(gp,"Som da arma","GunSound",{"Normal","Pato","Tiro realista"},4)
mkAction(gp,"Resetar som da arma",5,function()cfg.GunSound="Normal"saveCfg()if resetGunSoundsAction then resetGunSoundsAction()end end)
local tb={}
local function sw(n)ct.Text=n for tn,pg in pairs(pages)do pg.Visible=(tn==n)end for tn,bt in pairs(tb)do if tn==n then T:Create(bt,TweenInfo.new(0.15),{BackgroundColor3=Color3.fromRGB(30,10,45)}):Play()bt.TextColor3=Color3.fromRGB(200,100,255)else T:Create(bt,TweenInfo.new(0.15),{BackgroundColor3=Color3.fromRGB(12,12,18)}):Play()bt.TextColor3=Color3.fromRGB(140,140,150)end end end
local function mkTab(n,o)local b=Instance.new("TextButton")b.Size=UDim2.new(1,0,0,36)b.BackgroundColor3=Color3.fromRGB(12,12,18)b.Text="  "..n b.TextColor3=Color3.fromRGB(140,140,150)b.Font=Enum.Font.GothamBold b.TextSize=14 b.TextXAlignment=Enum.TextXAlignment.Left b.BorderSizePixel=0 b.AutoButtonColor=false b.LayoutOrder=o b.Parent=ts Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)b.MouseButton1Click:Connect(sf(function()sw(n)end))tb[n]=b end
mkTab("HOME",1)mkTab("ESP",2)mkTab("AIM",3)mkTab("GUN",4)sw("HOME")
local mh=Instance.new("TextButton")mh.Size=UDim2.new(0,40,0,6)mh.Position=UDim2.new(1,-55,0,5)mh.BackgroundColor3=Color3.fromRGB(140,60,220)mh.BackgroundTransparency=0.2 mh.Text=""mh.BorderSizePixel=0 mh.ZIndex=30 mh.Visible=isM mh.Parent=frame Instance.new("UICorner",mh).CornerRadius=UDim.new(0,3)
mh.MouseButton1Click:Connect(sf(function()collapsed=not collapsed if collapsed then T:Create(frame,TweenInfo.new(0.25,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=UDim2.new(0,220,0,35)}):Play()content.Visible=false sbar.Visible=false else T:Create(frame,TweenInfo.new(0.25,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=UDim2.new(0,520,0,360)}):Play()content.Visible=true sbar.Visible=true end end))
mtog=Instance.new("TextButton")mtog.Size=UDim2.new(0,45,0,45)mtog.Position=UDim2.new(0,15,0,15)mtog.BackgroundColor3=Color3.fromRGB(8,8,12)mtog.Text="M"mtog.TextColor3=sc()mtog.Font=Enum.Font.GothamBlack mtog.TextSize=20 mtog.BorderSizePixel=0 mtog.ZIndex=15 mtog.Visible=not isM mtog.Parent=gui Instance.new("UICorner",mtog).CornerRadius=UDim.new(0,50)table.insert(rgb,mtog)
local mst=Instance.new("UIStroke")mst.Thickness=1.5 mst.Color=sc()mst.Transparency=0.2 mst.Parent=mtog table.insert(rgb,mst)
-- ESP DE CARROS: marca todos os Models diretamente dentro de workspace.CarrosSpawnados.
local carCache = {}
local carRoot = workspace:FindFirstChild("CarrosSpawnados")
local function isCarModel(obj)
    if not carRoot or not obj:IsA("Model") or not obj:IsDescendantOf(carRoot) then
        return false
    end
    local parent = obj.Parent
    while parent and parent ~= carRoot do
        if parent:IsA("Model") then
            return false
        end
        parent = parent.Parent
    end
    return parent == carRoot
end
local function removeCarESP(car)
    local data = carCache[car]
    if data then
        for _, drawing in pairs(data) do
            pcall(function() drawing:Remove() end)
        end
        carCache[car] = nil
    end
end
local function hideCarESP(data)
    data.box.Visible = false
    data.name.Visible = false
    data.distance.Visible = false
end
local function addCarESP(car)
    if not isCarModel(car) or carCache[car] then return end
    local ok, data = pcall(function()
        return {box=Drawing.new("Square"), name=Drawing.new("Text"), distance=Drawing.new("Text")}
    end)
    if not ok then return end
    data.box.Thickness=2 data.box.Filled=false data.box.Color=Color3.fromRGB(255,170,0) data.box.Visible=false
    data.name.Center=true data.name.Outline=true data.name.Size=14 data.name.Color=Color3.fromRGB(255,200,80) data.name.Visible=false
    data.distance.Center=true data.distance.Outline=true data.distance.Size=13 data.distance.Color=Color3.new(1,1,1) data.distance.Visible=false
    carCache[car]=data
end
local function getCarBounds(car)
    local ok, cf, size = pcall(function()
        local boxCFrame, boxSize = car:GetBoundingBox()
        return boxCFrame, boxSize
    end)
    if not ok or not cf or not size then return nil end
    local h=size/2
    local points={Vector3.new(-h.X,-h.Y,-h.Z),Vector3.new(-h.X,-h.Y,h.Z),Vector3.new(-h.X,h.Y,-h.Z),Vector3.new(-h.X,h.Y,h.Z),Vector3.new(h.X,-h.Y,-h.Z),Vector3.new(h.X,-h.Y,h.Z),Vector3.new(h.X,h.Y,-h.Z),Vector3.new(h.X,h.Y,h.Z)}
    local minX,minY=math.huge,math.huge local maxX,maxY=-math.huge,-math.huge local visible=false
    for _,point in ipairs(points) do
        local screen=C:WorldToViewportPoint(cf:PointToWorldSpace(point))
        if screen.Z>0 then
            visible=true minX=math.min(minX,screen.X) minY=math.min(minY,screen.Y) maxX=math.max(maxX,screen.X) maxY=math.max(maxY,screen.Y)
        end
    end
    if not visible then return nil end
    return minX,minY,maxX,maxY
end
local function updateCarESP()
    for car,data in pairs(carCache) do
        if not car.Parent then
            removeCarESP(car)
        elseif streamerMode or not cfg.CarESP then
            hideCarESP(data)
        else
            local minX,minY,maxX,maxY=getCarBounds(car)
            if not minX then
                hideCarESP(data)
            else
                local width=maxX-minX local height=maxY-minY local centerX=minX+width/2
                local distance=math.floor((C.CFrame.Position-car:GetPivot().Position).Magnitude)
                local col=carColor()
                data.box.Color=col data.box.Position=Vector2.new(minX,minY) data.box.Size=Vector2.new(width,height) data.box.Visible=cfg.CarBox
                data.name.Color=col data.name.Text=car.Name data.name.Position=Vector2.new(centerX,minY-18) data.name.Visible=cfg.CarNm
                data.distance.Text=distance.." studs" data.distance.Position=Vector2.new(centerX,maxY+2) data.distance.Visible=cfg.CarDst
            end
        end
    end
end
if carRoot then
    for _,obj in ipairs(carRoot:GetDescendants()) do addCarESP(obj) end
    carRoot.DescendantAdded:Connect(function(obj) task.wait(0.2) addCarESP(obj) end)
end
local function rmESP(p)local e=cache[p]if e then for _,o in pairs(e)do pcall(function()o:Remove()end)end cache[p]=nil end end
local function mkESP(p)if p==LP or cache[p]then return end if not p.Parent then return end local ok=pcall(function()cache[p]={ol=Drawing.new("Square"),bx=Drawing.new("Square"),nm=Drawing.new("Text"),ds=Drawing.new("Text"),hb=Drawing.new("Square"),hg=Drawing.new("Square"),ht=Drawing.new("Text")}end)if not ok then return end local e=cache[p]e.ol.Thickness=3 e.ol.Filled=false e.ol.Visible=false e.bx.Thickness=1 e.bx.Filled=false e.bx.Visible=false e.nm.Center=true e.nm.Outline=true e.nm.Visible=false e.ds.Center=true e.ds.Outline=true e.ds.Visible=false e.hg.Filled=true e.hg.Color=Color3.new()e.hg.Visible=false e.hb.Filled=true e.hb.Visible=false e.ht.Center=true e.ht.Outline=true e.ht.Visible=false end
local function hideESP(e)pcall(function()e.ol.Visible=false e.bx.Visible=false e.nm.Visible=false e.ds.Visible=false e.hg.Visible=false e.hb.Visible=false e.ht.Visible=false end)end
local function updESP()
    for p,e in pairs(cache) do
        if not p.Parent then
            rmESP(p)
        end
        if p.Parent and not p.Character then
            hideESP(e)
        end
        if p.Parent and p.Character then
            local ch=p.Character
            local hr=ch:FindFirstChild("HumanoidRootPart") or ch:FindFirstChild("UpperTorso") or ch:FindFirstChild("Torso") or ch.PrimaryPart
            local hd=ch:FindFirstChild("Head") or hr
            local hm=ch:FindFirstChildOfClass("Humanoid")
            if not (hr and hd and hm) then
                hideESP(e)
            end
            if hr and hd and hm then
                local col=espColor()
                if friendMatches(p) then
                    col=Color3.fromRGB(80,255,120)
                elseif cfg.Team and p.Team then
                    col=p.Team.TeamColor.Color
                end
                local tw=hd.Position+Vector3.new(0,0.8,0)
                local bw=hr.Position-Vector3.new(0,3,0)
                local ts2,to=C:WorldToViewportPoint(tw)
                local bs,bo=C:WorldToViewportPoint(bw)
                if not (to and bo) then
                    hideESP(e)
                end
                if to and bo then
                    local h=math.abs(bs.Y-ts2.Y)
                    local w=h*0.55
                    local x=ts2.X-w/2
                    local y=ts2.Y
                    if cfg.Box then
                        e.ol.Size=Vector2.new(w,h)
                        e.ol.Position=Vector2.new(x,y)
                        e.ol.Color=Color3.new()
                        e.ol.Visible=true
                        e.bx.Size=Vector2.new(w,h)
                        e.bx.Position=Vector2.new(x,y)
                        e.bx.Color=col
                        e.bx.Visible=true
                    end
                    if not cfg.Box then
                        e.ol.Visible=false
                        e.bx.Visible=false
                    end
                    if cfg.Nm then
                        e.nm.Text=p.Name
                        e.nm.Size=cfg.Fs
                        e.nm.Color=col
                        e.nm.Position=Vector2.new(ts2.X,y-cfg.Fs-4)
                        e.nm.Visible=true
                    end
                    if not cfg.Nm then
                        e.nm.Visible=false
                    end
                    if cfg.Dst then
                        local d=math.floor((C.CFrame.Position-hr.Position).Magnitude)
                        e.ds.Text=tostring(d).." studs"
                        e.ds.Size=cfg.Fs-2
                        e.ds.Color=Color3.new(1,1,1)
                        e.ds.Position=Vector2.new(ts2.X,y+h+2)
                        e.ds.Visible=true
                    end
                    if not cfg.Dst then
                        e.ds.Visible=false
                    end
                    if cfg.Hp then
                        local hp=hm.Health
                        local mh2=hm.MaxHealth
                        local pc=math.clamp(hp/math.max(mh2,1),0,1)
                        local bx2=4
                        local bxx=x-bx2-4
                        e.hg.Size=Vector2.new(bx2,h)
                        e.hg.Position=Vector2.new(bxx,y)
                        e.hg.Visible=true
                        local fh=h*pc
                        e.hb.Size=Vector2.new(bx2,fh)
                        e.hb.Position=Vector2.new(bxx,y+(h-fh))
                        e.hb.Color=Color3.fromRGB(255*(1-pc),255*pc,0)
                        e.hb.Visible=true
                        e.ht.Text=tostring(math.floor(hp))
                        e.ht.Size=cfg.Fs-4
                        e.ht.Color=Color3.new(1,1,1)
                        e.ht.Position=Vector2.new(bxx+bx2/2,y+h/2-(cfg.Fs-4)/2)
                        e.ht.Visible=true
                    end
                    if not cfg.Hp then
                        e.hg.Visible=false
                        e.hb.Visible=false
                        e.ht.Visible=false
                    end
                end
            end
        end
    end
end
local function clrESP()for p in pairs(cache)do rmESP(p)end end
local function watchPlayer(p)
    if p==LP then return end
    p.CharacterAdded:Connect(function()
        task.spawn(function()
            for _=1,10 do
                task.wait(0.15)
                if not p.Parent then return end
                if cfg.En then mkESP(p) end
                local ch=p.Character
                if ch and (ch:FindFirstChild("HumanoidRootPart") or ch:FindFirstChild("UpperTorso") or ch:FindFirstChild("Torso") or ch.PrimaryPart) then return end
            end
        end)
    end)
    p.CharacterRemoving:Connect(function()
        local e=cache[p]
        if e then hideESP(e) end
    end)
    if cfg.En then mkESP(p) end
end
for _,p in ipairs(P:GetPlayers())do watchPlayer(p)end
P.PlayerAdded:Connect(watchPlayer)
P.PlayerRemoving:Connect(function(p)rmESP(p)end)
local function getAimPart(ch)
    if not ch then return nil end
    local part=nil
    if cfg.AimPart=="Head" then
        part=ch:FindFirstChild("Head")
    elseif cfg.AimPart=="Torso" then
        part=ch:FindFirstChild("Torso") or ch:FindFirstChild("UpperTorso") or ch:FindFirstChild("LowerTorso")
    else
        part=ch:FindFirstChild("HumanoidRootPart")
    end
    if part and part:IsA("BasePart") then return part end
    return ch:FindFirstChild("HumanoidRootPart") or ch:FindFirstChild("UpperTorso") or ch:FindFirstChild("Head")
end
local function rayHitIsInsideSeatVehicle(hit,seat)
    if not hit or not seat then return false end
    local node=seat.Parent
    while node and node~=workspace do
        if node:IsA("Model") and hit:IsDescendantOf(node) then
            return true
        end
        node=node.Parent
    end
    return false
end
local function canSeeAimPart(p,part)
    if not cfg.WallCheck then return true end
    local origin=C.CFrame.Position
    local direction=part.Position-origin
    if direction.Magnitude<=0.01 then return false end
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={LP.Character}
    params.IgnoreWater=true
    local result=workspace:Raycast(origin,direction,params)
    if not result then return true end
    if p.Character and result.Instance:IsDescendantOf(p.Character) then return true end
    local targetHumanoid=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
    local targetSeat=targetHumanoid and targetHumanoid.SeatPart
    if rayHitIsInsideSeatVehicle(result.Instance,targetSeat) then
        return true
    end
    local localHumanoid=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    local localSeat=localHumanoid and localHumanoid.SeatPart
    if rayHitIsInsideSeatVehicle(result.Instance,localSeat) then
        return true
    end
    return false
end
local function getTarget()
    local closest=nil
    local shortest=tonumber(cfg.Fov) or 150
    local maxDistance=tonumber(cfg.MaxDist) or 500
    for _,p in ipairs(P:GetPlayers()) do
        if p~=LP and p.Character then
            local skip=false
            if friendMatches(p) then
                skip=true
            end
            if cfg.IgnoreTeam and p.Team and LP.Team and p.Team==LP.Team then
                skip=true
            end
            local hm=p.Character:FindFirstChildOfClass("Humanoid")
            if not hm or hm.Health<=0 then
                skip=true
            end
            if not skip then
                local part=getAimPart(p.Character)
                if part and part:IsA("BasePart") then
                    local dist=(C.CFrame.Position-part.Position).Magnitude
                    if dist<=maxDistance then
                        local sp,on=C:WorldToViewportPoint(part.Position)
                        if on and sp.Z>0 then
                            local center=Vector2.new(C.ViewportSize.X/2,C.ViewportSize.Y/2)
                            local cursor=Vector2.new(sp.X,sp.Y)
                            local sd=(cursor-center).Magnitude
                            if sd<=shortest and canSeeAimPart(p,part) then
                                shortest=sd
                                closest=part
                            end
                        end
                    end
                end
            end
        end
    end
    return closest
end
local function updAim()
    if not cfg.Aim then return end
    local t=getTarget()
    if t then
        local factor=cfg.Smooth<=0 and 1 or math.clamp(1/cfg.Smooth,0.01,1)
        C.CFrame=C.CFrame:Lerp(CFrame.new(C.CFrame.Position,t.Position),factor)
    end
end
local recoilHooks={}
local recoilValueData={}
local recoilAttrData={}
local gunScaleData={}
local gunSoundData={}
local gunSoundOriginals={}
local gunTool=nil
local gunSoundTool=nil
local gunSoundMode=nil
local function currentGun()
    if not LP.Character then return nil end
    for _,obj in ipairs(LP.Character:GetChildren()) do
        if obj:IsA("Tool") then return obj end
    end
    return nil
end
local function restoreRecoil()
    for _,data in pairs(recoilHooks) do
        if data.env then
            data.env.ShakeCamera=data.shake
            data.env.RotCamera=data.rot
        end
    end
    recoilHooks={}
    for obj,value in pairs(recoilValueData) do
        if obj and obj.Parent then pcall(function()obj.Value=value end) end
    end
    recoilValueData={}
    for _,data in ipairs(recoilAttrData) do
        if data.obj and data.obj.Parent then pcall(function()data.obj:SetAttribute(data.name,data.value)end) end
    end
    recoilAttrData={}
end
local function isRecoilName(name)
    local n=string.lower(tostring(name or ""))
    if n:find("decay",1,true) or n:find("delay",1,true) then return false end
    return n=="recoil" or n:find("recoilmin",1,true) or n:find("recoilmax",1,true) or n:find("totalrecoil",1,true) or n:find("camerashake",1,true) or n:find("shakeamount",1,true) or n:find("camerakick",1,true)
end
local function disableRecoilConfig(tool)
    local objects={tool}
    for _,obj in ipairs(tool:GetDescendants()) do table.insert(objects,obj) end
    for _,obj in ipairs(objects) do
        if (obj:IsA("NumberValue") or obj:IsA("IntValue")) and isRecoilName(obj.Name) then
            if recoilValueData[obj]==nil then recoilValueData[obj]=obj.Value end
            obj.Value=0
        end
        for name,value in pairs(obj:GetAttributes()) do
            if type(value)=="number" and isRecoilName(name) then
                local found=false
                for _,data in ipairs(recoilAttrData) do if data.obj==obj and data.name==name then found=true break end end
                if not found then table.insert(recoilAttrData,{obj=obj,name=name,value=value}) end
                obj:SetAttribute(name,0)
            end
        end
    end
end
local function disableRecoil(tool)
    disableRecoilConfig(tool)
    if type(getsenv)~="function" then return end
    for _,obj in ipairs(tool:GetDescendants()) do
        if obj:IsA("LocalScript") and not recoilHooks[obj] then
            local ok,env=pcall(getsenv,obj)
            if ok and type(env)=="table" then
                local shake=env.ShakeCamera
                local rot=env.RotCamera
                if type(shake)=="function" or type(rot)=="function" then
                    recoilHooks[obj]={env=env,shake=shake,rot=rot}
                    if type(shake)=="function" then env.ShakeCamera=function()end end
                    if type(rot)=="function" then env.RotCamera=function()end end
                end
            end
        end
    end
end
local function restoreGunScale()
    for obj,data in pairs(gunScaleData) do
        if obj and obj.Parent then
            if data.kind=="part" then obj.Size=data.value end
            if data.kind=="mesh" then obj.Scale=data.value end
        end
    end
    gunScaleData={}
end
local function applyGunScale(tool,scale)
    for _,obj in ipairs(tool:GetDescendants()) do
        if obj:IsA("BasePart") and not gunScaleData[obj] then
            gunScaleData[obj]={kind="part",value=obj.Size}
        elseif obj:IsA("SpecialMesh") and not gunScaleData[obj] then
            gunScaleData[obj]={kind="mesh",value=obj.Scale}
        end
        local data=gunScaleData[obj]
        if data and data.kind=="part" then obj.Size=data.value*scale end
        if data and data.kind=="mesh" then obj.Scale=data.value*scale end
    end
end
local gunSoundIds={Pato="rbxassetid://162958822",["Tiro realista"]="rbxassetid://2811598570"}
local function isShotSound(sound)
    local n=string.lower(sound.Name or "")
    if n:find("reload",1,true) or n:find("equip",1,true) or n:find("empty",1,true) or n:find("hit",1,true) or n:find("impact",1,true) then return false end
    return n:find("fire",1,true) or n:find("shoot",1,true) or n:find("shot",1,true) or n:find("muzzle",1,true) or n:find("blast",1,true)
end
local function restoreGunSounds()
    for sound,id in pairs(gunSoundData) do
        if gunSoundOriginals and gunSoundOriginals[sound] then id=gunSoundOriginals[sound] end
        if sound and sound.Parent then pcall(function()sound.SoundId=id end) end
    end
    gunSoundData={}
    gunSoundTool=nil
    gunSoundMode=nil
end
resetGunSoundsAction=restoreGunSounds
local function applyGunSound(tool)
    local mode=tostring(cfg.GunSound or "Normal")
    if mode=="Normal" then restoreGunSounds() return end
    if gunSoundTool==tool and gunSoundMode==mode then return end
    restoreGunSounds()
    local id=gunSoundIds[mode]
    if not id then return end
    for _,obj in ipairs(tool:GetDescendants()) do
        if obj:IsA("Sound") and isShotSound(obj) then
            if not gunSoundOriginals[obj] then gunSoundOriginals[obj]=obj.SoundId end
            gunSoundData[obj]=gunSoundOriginals[obj]
            pcall(function()obj.SoundId=id end)
        end
    end
    gunSoundTool=tool
    gunSoundMode=mode
end
local function updateGunEffects()
    local tool=currentGun()
    if tool~=gunTool then
        restoreRecoil()
        restoreGunScale()
        restoreGunSounds()
        gunSoundOriginals={}
        gunTool=tool
    end
    if not tool then
        restoreRecoil()
        restoreGunSounds()
        gunSoundOriginals={}
        return
    end
    if cfg.NoRecoil then
        disableRecoil(tool)
    else
        restoreRecoil()
    end
    if cfg.GunGiant then
        applyGunScale(tool,math.max(1,tonumber(cfg.GunSize) or 2))
    else
        restoreGunScale()
    end
    applyGunSound(tool)
end
fovC=Drawing.new("Circle")fovC.Thickness=1 fovC.NumSides=64 fovC.Filled=false fovC.Color=Color3.fromRGB(140,60,220)fovC.Transparency=1 fovC.Visible=false
local function setStreamerMode(enabled)
    streamerMode=enabled==true
    gui.Enabled=true
    if streamerMode then
        for _,e in pairs(cache)do hideESP(e)end
        for _,e in pairs(carCache)do hideCarESP(e)end
        fovC.Visible=false
    end
    if homeStreamerButton then
        homeStreamerButton.Text=streamerMode and "MODO STREAMER: ATIVADO"or "MODO STREAMER: DESATIVADO"
        homeStreamerButton.BackgroundColor3=streamerMode and Color3.fromRGB(70,35,20)or Color3.fromRGB(35,16,50)
    end
end
homeStreamerButton.MouseButton1Click:Connect(sf(function()setStreamerMode(not streamerMode)end))
R.RenderStepped:Connect(function()hue=(hue+0.003)%1 for _,o in ipairs(rgb)do pcall(function()o.TextColor3=sc()end)pcall(function()o.Color=sc()end)end
    fovC.Position=Vector2.new(C.ViewportSize.X/2,C.ViewportSize.Y/2)
    fovC.Radius=cfg.Fov
    fovC.Visible=cfg.Aim and not streamerMode
    if streamerMode then
        for _,e in pairs(cache)do hideESP(e)end
        for _,e in pairs(carCache)do hideCarESP(e)end
    else
        if cfg.En then
            for _,p in ipairs(P:GetPlayers())do if p~=LP and not cache[p]then sf(mkESP)(p)end end
            sf(updESP)()
        end
        sf(updateCarESP)()
    end
    sf(updateGunEffects)()
    sf(updAim)()
end)
local function togE()cfg.En=not cfg.En saveCfg()if cfg.En then et.Text="ESP: ATIVADO"for _,p in ipairs(P:GetPlayers())do if p~=LP then sf(mkESP)(p)end end else et.Text="ESP: DESATIVADO"sf(clrESP)()end end
et.MouseButton1Click:Connect(sf(togE))
local function togA()cfg.Aim=not cfg.Aim saveCfg()at.Text=cfg.Aim and "AIM: ATIVADO"or "AIM: DESATIVADO"end
at.MouseButton1Click:Connect(sf(togA))
local function opM()open=true frame.Visible=true frame.Size=UDim2.new(0,0,0,0)T:Create(frame,TweenInfo.new(0.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Size=UDim2.new(0,520,0,360)}):Play()end
local function clM()open=false local t=T:Create(frame,TweenInfo.new(0.2,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Size=UDim2.new(0,0,0,0)})t:Play()t.Completed:Wait()frame.Visible=false end
local function tgM()if open then clM()else opM()end end
mtog.MouseButton1Click:Connect(sf(tgM))
xb.MouseButton1Click:Connect(sf(clM))
U.InputBegan:Connect(function(i,gp)
    if gp then
        return
    end
    if i.KeyCode==Enum.KeyCode.RightShift then
        sf(tgM)()
    elseif i.KeyCode==Enum.KeyCode.RightAlt then
        sf(function()
            setStreamerMode(not streamerMode)
        end)()
    end
end)
task.delay(3,sf(function()opM()end))
print("[MURK] carregado")
