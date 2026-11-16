-- PSN Arrange Nodes | Fusion composition script
-- Long spans use exterior lanes. Layout scores approximate wires as line segments.
-- Rebuild all underlays and bypass existing PipeRouters before planning the flow.
local COL_STEP, ROW_STEP = 1.5, 1.5
local ISLAND_GAP, INPUTS_LEFT = 3, true
local UND_X, UND_Y = 110, 33
local TILE_W, TILE_H = 0.87, 0.79
local owner = "PSN.ArrangeNodes.GeneratedV2"
local app = fu or fusion or Fusion()
local comp = comp or (app and app.CurrentComp)
if not comp then print("Open a Fusion composition first.") return end
local flow = comp.CurrentFrame and comp.CurrentFrame.FlowView
if not flow then print("Open the Flow view first.") return end

local function connect(input, output)
    input:ConnectTo(output)
    assert(input:GetConnectedOutput() == output, "Fusion rejected a connection")
end

local function arrange()
    local old = {}
    for _, t in pairs(comp:GetToolList(false) or {}) do
        local reg = t:GetAttrs().TOOLS_RegID
        if reg == "Underlay" then t:Delete() end
        if reg == "PipeRouter" then old[#old+1] = t end
    end
    -- Bypass each router before deleting it, including any user-added fan-out.
    for _, t in ipairs(old) do
        local original = t:FindMainInput(1):GetConnectedOutput()
        local output = t:FindMainOutput(1)
        local consumers = output:GetConnectedInputs() or {}
        for _, input in pairs(consumers) do connect(input, original) end
        assert(not next(output:GetConnectedInputs() or {}), "Router still has consumers")
        t:Delete()
    end
-- ---------------------------------------------------------------- collect

local names, toolByName, regidOf = {}, {}, {}
local posY, minX, minY = {}, math.huge, math.huge
for _, t in pairs(comp:GetToolList(false) or {}) do
	local a = t:GetAttrs()
	local name, regid = a.TOOLS_Name, a.TOOLS_RegID
	-- modifiers, splines and other sub-operators share the tool list but have no flow
	-- tile of their own, so they must stay out of the lattice
	local ok, x, y = pcall(function() return flow:GetPos(t) end)
	if name and name ~= "" and regid ~= "Underlay" and regid ~= "Note" and regid ~= "StickyNote" and ok and type(x) == "number" and type(y) == "number" then
		toolByName[name] = t
		regidOf[name] = regid
		names[#names + 1] = name
		posY[name] = y
		if x < minX then minX = x end
		if y < minY then minY = y end
	end
end
table.sort(names)
local n = #names
if n == 0 then print("PSN_ArrangeNodes: no nodes to arrange") return end
if minX == math.huge then minX = 0 end
if minY == math.huge then minY = 0 end


-- ---------------------------------------------------------------- graph

local preds, succs = {}, {}
for _, name in ipairs(names) do preds[name], succs[name] = {}, {} end

local function srcNameOf(inp)
	local okOut, out = pcall(function() return inp:GetConnectedOutput() end)
	if not okOut or not out then return nil end
	local okT, st = pcall(function() return out:GetTool() end)
	if not okT or not st then return nil end
	local okA, a = pcall(function() return st:GetAttrs() end)
	return okA and a and a.TOOLS_Name or nil
end

local wires = {}
local seen = {}
local function addEdge(src, dst, order)
	if src == nil or src == dst or toolByName[src] == nil then return end
	local key = src .. "\0" .. dst
	if seen[key] then return end
	seen[key] = true
	preds[dst][#preds[dst] + 1] = { name = src, idx = order }
	succs[src][#succs[src] + 1] = { name = dst, idx = order }
end

for _, name in ipairs(names) do
	local t = toolByName[name]
	local mainIDs = {}
    local hasPrimary=false
	local i = 1
	while true do
		local ok, inp = pcall(function() return t:FindMainInput(i) end)
		if not ok or inp == nil then break end
		local okID, id = pcall(function() return inp:GetAttrs().INPS_ID end)
		if okID and id then mainIDs[id] = i end
		local source=srcNameOf(inp)
        if source and toolByName[source] then
            -- An empty Background must not break a foreground-only Merge chain.
            addEdge(source,name,hasPrimary and i or 1)
            hasPrimary=true
        end
		i = i + 1
	end
	-- mask / effect inputs: still wires, ordered after the main ones
	local side = 0
    local inputs = {}
    for _, inp in pairs(t:GetInputList() or {}) do
        local out = inp:GetConnectedOutput()
        if out then
            local source = out:GetTool():GetAttrs().TOOLS_Name
            if toolByName[source] then
                inputs[#inputs+1] = {id=inp:GetAttrs().INPS_ID, src=source, dst=name, input=inp, output=out}
            end
        end
    end
    table.sort(inputs, function(a,b) return tostring(a.id)<tostring(b.id) end)
    for _,w in ipairs(inputs) do
        wires[#wires+1]=w
        if not mainIDs[w.id] and not seen[w.src .. "\0" .. name] then
            side=side+1
            addEdge(w.src,name,100+side)
        end
    end
end

-- weakly connected islands (mask connections included)
local parent = {}
local function find(a)
	while parent[a] ~= a do
		parent[a] = parent[parent[a]] or parent[a]
		a = parent[a]
	end
	return a
end
for _, name in ipairs(names) do parent[name] = name end
for _, name in ipairs(names) do
	for _, e in ipairs(preds[name]) do
		local ra, rb = find(name), find(e.name)
		if ra ~= rb then parent[ra] = rb end
	end
end

-- tools with no wires at all are parked separately
local loose = {}
for _, name in ipairs(names) do
	if #preds[name] == 0 and #succs[name] == 0 then loose[#loose + 1] = name end
end

local islands, islandOf = {}, {}
for _, name in ipairs(names) do
	if #preds[name] > 0 or #succs[name] > 0 then
		local root = find(name)
		local isl = islandOf[root]
		if not isl then
			isl = { root = root, names = {}, top = math.huge }
			islandOf[root] = isl
			islands[#islands + 1] = isl
		end
		isl.names[#isl.names + 1] = name
		local y = posY[name] or 0
		if y < isl.top then isl.top = y end
	end
end
table.sort(islands, function(a, b)
	if a.top ~= b.top then return a.top < b.top end
	return a.root < b.root
end)


-- An overlap counts even on adjacent wires if they double back along one another.
local function hit(a,b,c,d)
    local function cross(p,q,r)
        return (q.x-p.x)*(r.y-p.y)-(q.y-p.y)*(r.x-p.x)
    end
    local function on(p,q,r)
        return cross(p,q,r)==0 and r.x>=math.min(p.x,q.x) and r.x<=math.max(p.x,q.x)
            and r.y>=math.min(p.y,q.y) and r.y<=math.max(p.y,q.y)
    end
    if cross(a,b,c)*cross(a,b,d)<0 and cross(c,d,a)*cross(c,d,b)<0 then return 1 end
    if cross(a,b,c)==0 and cross(a,b,d)==0 then
        local k = a.x==b.x and "y" or "x"
        if math.min(math.max(a[k],b[k]),math.max(c[k],d[k])) >
           math.max(math.min(a[k],b[k]),math.min(c[k],d[k])) then return 1 end
    end
    if a==c or a==d or b==c or b==d then return 0 end
    return (on(a,b,c) or on(a,b,d) or on(c,d,a) or on(c,d,b)) and 1 or 0
end

local function scoreSegment(a,b,points,segments)
    local cost = 0
    for _, p in pairs(points) do
        if p~=a and p~=b then
            -- Clip the segment against the node rectangle in grid units.
            local lo,hi=0,1
            for _,k in ipairs({"x","y"}) do
                local r = k=="x" and TILE_W/(2*COL_STEP) or TILE_H/(2*ROW_STEP)
                local delta=b[k]-a[k]
                if delta==0 then
                    if math.abs(a[k]-p[k])>r then hi=-1 end
                else
                    local t,u=(p[k]-r-a[k])/delta,(p[k]+r-a[k])/delta
                    lo,hi=math.max(lo,math.min(t,u)),math.min(hi,math.max(t,u))
                end
            end
            if lo<=hi then cost=cost+100 end
        end
    end
    for _,s in ipairs(segments) do cost=cost+hit(a,b,s[1],s[2]) end
    return cost
end
-- ---------------------------------------------------------------- columns + lanes

local col, lane, place = {}, {}, {}
local inputNames,endNames,inputSet,endSet={},{},{},{}
local function media(v) return regidOf[v]=="Loader" or regidOf[v]=="MediaIn" end
for _,isl in ipairs(islands) do
    local hasMedia=false
    for _,v in ipairs(isl.names) do if media(v) then hasMedia=true end end
    for _,v in ipairs(isl.names) do
        if media(v) or (not hasMedia and #preds[v]==0) then inputSet[v]=true end
        if #succs[v]==0 then endSet[v]=true end
    end
end
for _,v in ipairs(names) do
    if media(v) then inputSet[v]=true end
    if inputSet[v] then inputNames[#inputNames+1]=v end
    if endSet[v] then endNames[#endNames+1]=v end
end

-- Partition the connected graph into paths, starting with the longest path
-- to a terminal. Prefer main inputs when paths have the same length.
local right=2
for _,isl in ipairs(islands) do
    local taken={}
    isl.lines={}
    while true do
        local memo,visiting={},{}
        local function upstream(v)
            if taken[v] or visiting[v] then return {} end
            if memo[v] then return memo[v] end
            visiting[v]=true
            local longest,first={},math.huge
            if not inputSet[v] then
                for _,e in ipairs(preds[v]) do
                    local path=upstream(e.name)
                    if #path>#longest or (#path==#longest and e.idx<first) then longest,first=path,e.idx end
                end
            end
            visiting[v]=nil
            local line={}
            for _,n in ipairs(longest) do line[#line+1]=n end
            line[#line+1]=v
            memo[v]=line
            return line
        end
        local best={}
        for _,v in ipairs(isl.names) do
            if not taken[v] and (#isl.lines>0 or endSet[v]) then
                local line=upstream(v)
                if #line>#best then best=line end
            end
        end
        if #best==0 then
            for _,v in ipairs(isl.names) do if not taken[v] then best=upstream(v);break end end
        end
        if #best==0 then break end
        for _,v in ipairs(best) do taken[v]=true end
        isl.lines[#isl.lines+1]=best
        right=math.max(right,#best+1-(inputSet[best[1]] and 1 or 0)-(endSet[best[#best]] and 1 or 0))
    end
    isl.sink=isl.lines[1][#isl.lines[1]]
end

local pinned={}
local offsetLane=0
for _,isl in ipairs(islands) do
    local points,segments={},{}
    local edges={}
    local member={}
    for _,v in ipairs(isl.names) do member[v]=true end
    for _,w in ipairs(wires) do if member[w.dst] then edges[#edges+1]=w end end
    local function cell(x,y) return x..":"..y end
    local occupied={}
    for index,line in ipairs(isl.lines) do
        local tip=line[#line]
        local anchorY=0
        for _,e in ipairs(succs[tip]) do
            local dest=points[e.name]
            if dest then anchorY=dest.y;break end
        end
        local vertical=index>1 and #line<=2
        local best,chosen
        local function try(x,y,dy)
            local trial={}
            for i,v in ipairs(line) do
                local cx=inputSet[v] and 0 or endSet[v] and right or (vertical and x or x+i-1)
                if cx<0 or cx>right or (not inputSet[v] and not endSet[v] and (cx<1 or cx>=right)) then return end
                local cy=y+(i-1)*dy
                if occupied[cell(cx,cy)] then return end
                trial[v]={x=cx,y=cy}
            end
            local cost=math.abs(y)*.1
            for _,w in ipairs(edges) do
                local a,b=trial[w.src] or points[w.src],trial[w.dst] or points[w.dst]
                if a and b and (trial[w.src] or trial[w.dst]) then
                    cost=cost+math.abs(a.x-b.x)+math.abs(a.y-b.y)+6*math.max(0,a.x-b.x)
                    cost=cost+20*scoreSegment(a,b,points,segments)+20*scoreSegment(a,b,trial,{})
                end
            end
            if not best or cost<best then best,chosen=cost,trial end
        end
        if index==1 then try(inputSet[line[1]] and 0 or 1,0,0) end
        if not chosen then
            for distance=1,#isl.names+1 do
                for _,sign in ipairs({-1,1}) do
                    for x=1,right-1 do
                        local dy=vertical and -sign or 0
                        try(x,anchorY+sign*distance-(#line-1)*dy,dy)
                    end
                end
                if chosen and distance>=4 then break end
            end
        end
        assert(chosen,"Could not place calculation branch")
        for _,v in ipairs(line) do
            local p=chosen[v]
            points[v]=p
            occupied[cell(p.x,p.y)]=true
            if #line>1 or inputSet[v] or endSet[v] then pinned[v]=true end
        end
        for _,w in ipairs(edges) do
            if (chosen[w.src] or chosen[w.dst]) and points[w.src] and points[w.dst] then
                segments[#segments+1]={points[w.src],points[w.dst]}
            end
        end
    end

    local top,bottom=math.huge,-math.huge
    for _,p in pairs(points) do top,bottom=math.min(top,p.y),math.max(bottom,p.y) end
    local low,high=top,bottom
    segments={}
    local long={}
    for _,w in ipairs(edges) do
        local a,b=points[w.src],points[w.dst]
        if math.abs(b.x-a.x)>=3 and (a.y~=b.y or scoreSegment(a,b,points,{})>0) then long[#long+1]=w
        else segments[#segments+1]={a,b} end
    end
    local obstacles={}
    for _,p in pairs(points) do obstacles[#obstacles+1]=p end
    for _,w in ipairs(long) do
        local a,b=points[w.src],points[w.dst]
        local dir=b.x>a.x and 1 or -1
        local best,chosen
        local function consider(bends)
            -- Compare direct, one-bend and outer routes. Reserve enough room
            -- for both router sockets and Flow grid snapping.
            for _,bend in ipairs(bends) do
                for _,q in ipairs(obstacles) do
                    if math.abs(q.x-bend.x)<1 and math.abs(q.y-bend.y)<1 then return end
                end
            end
            if #bends==2 and math.abs(bends[1].x-bends[2].x)<1 and math.abs(bends[1].y-bends[2].y)<1 then return end
            local cost,last=#bends*3,a
            for j=1,#bends+1 do
                local p=bends[j] or b
                if last.x==p.x and last.y==p.y then return end
                cost=cost+100*scoreSegment(last,p,obstacles,segments)+math.abs(last.x-p.x)+math.abs(last.y-p.y)
                if last.y~=p.y and math.abs(last.x-p.x)>1 then cost=cost+2*math.abs(last.x-p.x) end
                last=p
            end
            if not best or cost<best then best,chosen=cost,bends end
        end
        consider({})
        for step=1,2 do
            consider({{x=a.x+dir*step,y=b.y}})
            consider({{x=b.x-dir*step,y=a.y}})
        end
        for depth=1,#long+1 do
            local previous=best
            for _,y in ipairs({top-depth,bottom+depth}) do
                consider({{x=a.x+dir,y=y},{x=b.x-dir,y=y}})
            end
            if depth>=3 and best==previous then break end
        end
        w.bends=chosen
        pinned[w.src],pinned[w.dst]=true,true
        local prev=a
        for _,p in ipairs(chosen) do
            segments[#segments+1]={prev,p}
            obstacles[#obstacles+1]=p
            prev=p
            low,high=math.min(low,p.y),math.max(high,p.y)
        end
        segments[#segments+1]={prev,b}
    end
    local shift=offsetLane-low
    for v,p in pairs(points) do place[v]={x=p.x*COL_STEP,y=(p.y+shift)*ROW_STEP} end
    for _,w in ipairs(long) do for _,p in ipairs(w.bends) do p.y=p.y+shift end end
    offsetLane=high+shift+ISLAND_GAP
end
local freeInputs,freeNodes=0,0
for _,v in ipairs(loose) do
    if inputSet[v] then
        place[v]={x=0,y=(offsetLane+freeInputs)*ROW_STEP}
        freeInputs=freeInputs+1
    else
        place[v]={x=(1+freeNodes%math.max(1,right-1))*COL_STEP,y=(offsetLane+math.floor(freeNodes/math.max(1,right-1)))*ROW_STEP}
        freeNodes=freeNodes+1
    end
end

local firstX=0
for _,p in pairs(place) do firstX=math.min(firstX,p.x) end
minX=minX-firstX
local firstY=math.huge
for _,p in pairs(place) do firstY=math.min(firstY,p.y) end
local originY=minY-firstY
for _,name in ipairs(names) do
    flow:SetPos(toolByName[name],minX+place[name].x,originY+place[name].y)
end
local hubs,groups={},{}
for _,w in ipairs(wires) do
    local a=w.input:GetAttrs()
    if a.INPS_DataType=="Mask" or a.INPS_ID=="EffectMask" then
        local key=w.src.."\0"..tostring(w.output:GetAttrs().OUTS_ID)
        if not groups[key] then groups[key]={}; hubs[#hubs+1]=groups[key] end
        table.insert(groups[key],w)
    end
end
local taken,existing={},{}
for _,v in ipairs(names) do
    local x,y=flow:GetPos(toolByName[v])
    taken[v]={x=(x-minX)/COL_STEP,y=(y-originY)/ROW_STEP}
end
for _,g in ipairs(hubs) do
    if #g>=3 then for _,w in ipairs(g) do w.hub=g;w.bends=nil end end
end
for _,w in ipairs(wires) do
    if not w.hub then
        local prev=taken[w.src]
        for _,p in ipairs(w.bends or {}) do
            existing[#existing+1]={prev,p}
            taken[#taken+1]=p
            prev=p
        end
        existing[#existing+1]={prev,taken[w.dst]}
    end
end
local protected={}
local count=0
for _,g in ipairs(hubs) do
    if #g>=3 then
        local src=taken[g[1].src]
        local best,chosen
        local function segmentCost(a,b)
            return 50*scoreSegment(a,b,taken,existing)+math.abs(a.x-b.x)+math.abs(a.y-b.y)
        end
        for radius=1,#names+2 do
            for dx=-radius,radius do
                for _,sign in ipairs({-1,1}) do
                    local p={x=src.x+dx,y=src.y+sign*radius}
                    local free=true
                    for _,q in pairs(taken) do
                        if math.abs(p.x-q.x)<.9 and math.abs(p.y-q.y)<.9 then free=false;break end
                    end
                    if free then
                        local cost=segmentCost(src,p)+4*(dx*dx+radius*radius)
                        for _,w in ipairs(g) do cost=cost+segmentCost(p,taken[w.dst]) end
                        if not best or cost<best then best,chosen=cost,p end
                    end
                end
            end
            if chosen and radius>=2 then break end
        end
        assert(chosen,"No free cell for mask junction")
        local x,y=minX+chosen.x*COL_STEP,originY+chosen.y*ROW_STEP
        local r=assert(comp:AddTool("PipeRouter",x,y))
        r:SetData(owner,"router")
        flow:SetPos(r,x,y)
        connect(r:FindMainInput(1),g[1].output)
        g.output=assert(r:FindMainOutput(1))
        protected[r:GetAttrs().TOOLS_Name]=true
        count=count+1
        taken[#taken+1]=chosen
        existing[#existing+1]={src,chosen}
        for _,w in ipairs(g) do existing[#existing+1]={chosen,taken[w.dst]} end
    end
end

for _,w in ipairs(wires) do
    local prev=w.hub and w.hub.output or w.output
    for _,p in ipairs(w.bends or {}) do
        -- Explicit coordinates suppress interactive insertion on the selected wire.
        local r=assert(comp:AddTool("PipeRouter",minX+p.x*COL_STEP,originY+p.y*ROW_STEP))
        r:SetData(owner,"router")
        local routerY=originY+p.y*ROW_STEP
        if p.y*ROW_STEP==place[w.dst].y then
            local _,snappedY=flow:GetPos(toolByName[w.dst])
            routerY=snappedY
        end
        flow:SetPos(r,minX+p.x*COL_STEP,routerY)
        connect(r:FindMainInput(1),prev)
        prev=assert(r:FindMainOutput(1))
        count=count+1
    end
    if prev~=w.output then connect(w.input,prev) end
    w.expected=prev
end
for _,w in ipairs(wires) do assert(w.input:GetConnectedOutput()==w.expected,"Wire verification failed") end

-- Refine the wires after Fusion has snapped every tile to the Flow grid.
local function refine()
    local points,byName,paths,segments={},{},{},{}
    local function read(p)
        p.x,p.y=flow:GetPos(p.tool)
    end
    local function point(t)
        local name=t:GetAttrs().TOOLS_Name
        if not byName[name] then
            local p={tool=t}
            read(p)
            points[#points+1]=p
            byName[name]=p
        end
        return byName[name]
    end
    for _,name in ipairs(names) do point(toolByName[name]) end
    local function rebuild()
        segments={}
        local seen={}
        for _,path in ipairs(paths) do
            for i=2,#path do
                local a,b=path[i-1],path[i]
                seen[a]=seen[a] or {}
                if not seen[a][b] then segments[#segments+1]={a,b};seen[a][b]=true end
            end
        end
    end
    for _,w in ipairs(wires) do
        local path={byName[w.dst]}
        local out=w.input:GetConnectedOutput()
        while out~=w.output do
            local router=out:GetTool()
            assert(router:GetData(owner)=="router","Unexpected wire while measuring layout")
            table.insert(path,1,point(router))
            out=router:FindMainInput(1):GetConnectedOutput()
        end
        table.insert(path,1,byName[w.src])
        paths[#paths+1]=path
    end
    rebuild()
    local function score()
        local length,crossings,blocks,parallel=0,0,0,0
        for i,p in ipairs(points) do
            if not p.removed then
                for j=1,i-1 do
                    local q=points[j]
                    if not q.removed and math.abs(p.x-q.x)<TILE_W and math.abs(p.y-q.y)<TILE_H then blocks=blocks+1 end
                end
            end
        end
        for i,s in ipairs(segments) do
            local a,b=s[1],s[2]
            local dx,dy=b.x-a.x,b.y-a.y
            length=length+math.sqrt((dx*UND_X)^2+(dy*UND_Y)^2)
            if math.abs(dy)<0.1 and math.abs(dx)>=COL_STEP*.9 then parallel=parallel+1 end
            for j=1,i-1 do crossings=crossings+hit(a,b,segments[j][1],segments[j][2]) end
            for _,p in ipairs(points) do
                if not p.removed and p~=a and p~=b then
                    local lo,hi=0,1
                    if dx==0 then
                        if math.abs(a.x-p.x)>TILE_W/2 then hi=-1 end
                    else
                        local t,u=(p.x-TILE_W/2-a.x)/dx,(p.x+TILE_W/2-a.x)/dx
                        lo,hi=math.max(lo,math.min(t,u)),math.min(hi,math.max(t,u))
                    end
                    if dy==0 then
                        if math.abs(a.y-p.y)>TILE_H/2 then hi=-1 end
                    else
                        local t,u=(p.y-TILE_H/2-a.y)/dy,(p.y+TILE_H/2-a.y)/dy
                        lo,hi=math.max(lo,math.min(t,u)),math.min(hi,math.max(t,u))
                    end
                    if lo<=hi then blocks=blocks+1 end
                end
            end
        end
        return {length=length,cross=crossings,blocks=blocks,parallel=parallel}
    end
    local function improves(s,b)
        return s.cross<=b.cross and s.blocks<=b.blocks and s.parallel>=b.parallel and s.length<b.length-.1
    end
    local best=score()
    local initial=best.length
    local function move(group,deltas)
        local old={}
        for i,p in ipairs(group) do old[i]={p.x,p.y} end
        local target,choice=best,nil
        for _,d in ipairs(deltas) do
            for i,p in ipairs(group) do p.x,p.y=old[i][1]+d[1],old[i][2]+d[2] end
            local s=score()
            if improves(s,target) then target,choice=s,d end
        end
        for i,p in ipairs(group) do p.x,p.y=old[i][1],old[i][2] end
        if choice then
            for _,p in ipairs(group) do flow:SetPos(p.tool,p.x+choice[1],p.y+choice[2]); read(p) end
            local measured=score()
            if improves(measured,best) then best=measured
            else
                for i,p in ipairs(group) do flow:SetPos(p.tool,old[i][1],old[i][2]); read(p) end
                best=score()
            end
        end
    end
    local vertical={{0,-1},{0,1},{0,-2},{0,2}}
    local neighbors={{0,-1},{0,1},{-.5,0},{.5,0}}
    for _,isl in ipairs(islands) do
        local trunk,cur={},isl.sink
        while cur and not trunk[cur] do
            trunk[cur]=true
            local up
            for _,e in ipairs(preds[cur]) do if e.idx==1 then up=e.name; break end end
            cur=up
        end
        local function movable(name)
            return not pinned[name] and not trunk[name] and regidOf[name]~="Loader" and regidOf[name]~="MediaIn"
        end
        -- Pass 1: move unshared upstream branches as a unit.
        for _,dst in ipairs(isl.names) do
            for _,e in ipairs(preds[dst]) do
                if e.idx~=1 and movable(e.name) and #succs[e.name]==1 then
                    local group,seen={},{}
                    local function collect(v)
                        if seen[v] or not movable(v) or #succs[v]~=1 then return end
                        seen[v]=true
                        group[#group+1]=byName[v]
                        for _,input in ipairs(preds[v]) do collect(input.name) end
                    end
                    collect(e.name)
                    if #group>1 then move(group,vertical) end
                end
            end
        end
        -- Pass 2: shorten individual side connections in neighboring grid cells.
        for _,v in ipairs(isl.names) do if movable(v) then move({byName[v]},neighbors) end end
    end
    -- Pass 3: bypass a router only when the direct wire earns its place.
    for k,path in ipairs(paths) do
        for j=#path-1,2,-1 do
            if not protected[path[j].tool:GetAttrs().TOOLS_Name] then
            local p=table.remove(path,j)
            p.removed=true
            rebuild()
            local s=score()
            if improves(s,best) and (math.abs(path[j-1].y-path[j].y)<.1 or math.abs(path[j-1].x-path[j].x)<.1) then
                local w=wires[k]
                local input=j==#path and w.input or path[j].tool:FindMainInput(1)
                local out=p.tool:FindMainInput(1):GetConnectedOutput()
                connect(input,out)
                assert(not next(p.tool:FindMainOutput(1):GetConnectedInputs() or {}))
                p.tool:Delete()
                count=count-1
                best=s
            else
                p.removed=false
                table.insert(path,j,p)
                rebuild()
            end
            end
        end
    end
    print(string.format("Three-pass refinement: estimated wire length %.0f -> %.0f Flow pixels",initial,best.length))
end
refine()

local fallback=0
local function bounds(name)
    local t=toolByName[name]
    local x,y=flow:GetPos(t)
    local w,h=TILE_W,TILE_H
    local ok,size=pcall(function()
        local setting=t:SaveSettings()
        return setting.Tools[name].ViewInfo.Size
    end)
    if ok and size and tonumber(size[1]) and tonumber(size[2]) and size[1]>0 and size[2]>0 then
        w,h=size[1]/UND_X,size[2]/UND_Y
    else fallback=fallback+1 end
    return x-w/2,y-h/2,x+w/2,y+h/2
end
local function frameGroup(label,members,tint)
    if #members==0 then return end
    local l,t,r,b=math.huge,math.huge,-math.huge,-math.huge
    for _,name in ipairs(members) do
        local x,y,u,v=bounds(name)
        l,t,r,b=math.min(l,x),math.min(t,y),math.max(r,u),math.max(b,v)
    end
    -- Underlays grow downwards from the title bar. Reserve room above the
    -- top tile for the title and grid snapping as well as its input sockets.
    local cx=(l+r)/2
    local top=math.floor(t-1)
    local width=(r-l+1.5)*UND_X
    local height=(b+0.8-top)*UND_Y
    local id=label
    local suffix=1
    while comp:FindTool(id) do suffix=suffix+1; id=label.."_"..suffix end
    local data=string.format("{Tools=ordered(){%s=Underlay{ViewInfo=UnderlayInfo{Pos={%g,%g},Size={%g,%g}}}}}",
        id,cx,top,width,height)
    flow:Select()
    comp:Paste(assert(bmd.readstring(data)))
    local frame=assert(comp:FindTool(id),"Could not identify pasted underlay "..id)
    frame:SetData(owner,"frame")
    flow:SetPos(frame,cx-width/(2*UND_X)+0.5,top)
    frame.TileColor=tint
end
frameGroup("PSN_INPUTS_1",inputNames,{R=.72,G=.58,B=.86})
frameGroup("PSN_OUTPUTS_1",endNames,{R=.93,G=.55,B=.13})
print(string.format("Arranged %d operators with %d waypoints. %d frame members used standard tile dimensions.",n,count,fallback))
end

print("PSN Arrange Nodes: arranging "..tostring(comp:GetAttrs().COMPS_Name)..". Please wait.")
comp:Lock()
local started=false
local ok,err=xpcall(function()
    comp:StartUndo("PSN Arrange Nodes")
    started=true
    arrange()
end,debug.traceback)
if started then comp:EndUndo(true) end
comp:Unlock()
if ok then pcall(function() flow:FrameAll(); flow:Refresh() end)
else print("PSN Arrange Nodes stopped. Undo 'PSN Arrange Nodes' to restore the previous state.\n"..tostring(err)) end
