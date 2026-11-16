-- PSN Arrange Nodes | Fusion composition script
-- Long spans use exterior lanes. Layout scores approximate wires as line segments.
-- Rebuild all underlays and bypass existing PipeRouters before planning the flow.
local COL_STEP, ROW_STEP = 1.5, 1.5
local ISLAND_GAP, INPUTS_LEFT = 3, true
local UND_X, UND_Y = 110, 33
local TILE_W, TILE_H = 0.87, 0.79
local owner = "PSN.ArrangeNodes.GeneratedV2"
local app = fu or fusion or Fusion()
local comp = app and app.CurrentComp
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
	local i = 1
	while true do
		local ok, inp = pcall(function() return t:FindMainInput(i) end)
		if not ok or inp == nil then break end
		local okID, id = pcall(function() return inp:GetAttrs().INPS_ID end)
		if okID and id then mainIDs[id] = i end
		addEdge(srcNameOf(inp), name, i)
		i = i + 1
	end
	-- mask / effect inputs: still wires, ordered after the main ones
	local side = 0
    local inputs = {}
    for _, inp in pairs(t:GetInputList() or {}) do inputs[#inputs+1] = inp end
    table.sort(inputs, function(a,b) return tostring(a:GetAttrs().INPS_ID) < tostring(b:GetAttrs().INPS_ID) end)
	for _, inp in ipairs(inputs) do
		local okID, id = pcall(function() return inp:GetAttrs().INPS_ID end)
		local out = inp:GetConnectedOutput()
        local source = out and out:GetTool():GetAttrs().TOOLS_Name
        if toolByName[source] then
            wires[#wires+1] = {src=source, dst=name, input=inp, output=out}
        end
        if okID and id and not mainIDs[id] then
			local src = srcNameOf(inp)
			if src and not seen[src .. "\0" .. name] then
				side = side + 1
				addEdge(src, name, 100 + side)
			end
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
local offsetLane = 0

local function sideOffset(k)
	if k % 2 == 1 then return -math.ceil(k / 2) end
	return math.ceil(k / 2)
end

local function layoutIsland(isl)
	local members = isl.names
	isl.count = #members

	-- 1. columns. Count the longest run of *main input* wires from a source, so every
	--    chain starts at the left edge: all Loaders/MediaIns end up in one column at
	--    the left of the scheme, each node exactly one column right of its main input.
	local depth, busy = {}, {}
	local function depthOf(name)
		local d = depth[name]
		if d ~= nil then return d end
		if busy[name] then return 0 end
		busy[name] = true
		local best = 0
		for _, e in ipairs(preds[name]) do
			if e.idx == 1 then
				local ds = depthOf(e.name) + 1
				if ds > best then best = ds end
			end
		end
		busy[name] = nil
		depth[name] = best
		return best
	end
	for _, name in ipairs(members) do depthOf(name) end

	local myCol = {}
	if INPUTS_LEFT then
		for _, name in ipairs(members) do myCol[name] = depth[name] end
	else
		-- alternative: count columns backwards from the end nodes, which keeps every
		-- wire one column long but scatters the Loaders across the scheme
		local dist, busy2 = {}, {}
		local function distOf(name)
			local d = dist[name]
			if d ~= nil then return d end
			if busy2[name] then return 0 end
			busy2[name] = true
			local best = 0
			for _, e in ipairs(succs[name]) do
				if e.idx == 1 then
					local ds = distOf(e.name) + 1
					if ds > best then best = ds end
				end
			end
			busy2[name] = nil
			dist[name] = best
			return best
		end
		local maxDist = 0
		for _, name in ipairs(members) do
			local d = distOf(name)
			if d > maxDist then maxDist = d end
		end
		for _, name in ipairs(members) do myCol[name] = maxDist - dist[name] end
	end
	-- a pure source that only feeds secondary ports (a mask, a generator) hangs in the
	-- column of the node it feeds instead of starting its own line
	for _, name in ipairs(members) do
		if #preds[name] == 0 and #succs[name] > 0 then
			local onlySecondary = true
			for _, e in ipairs(succs[name]) do
				if e.idx == 1 then onlySecondary = false end
			end
			if onlySecondary then
				local c = 0
				for _, e in ipairs(succs[name]) do
					if myCol[e.name] > c then c = myCol[e.name] end
				end
				myCol[name] = c
			end
		end
	end

	-- inputs win over everything: every Loader/MediaIn sits in the first column, even
	-- when it feeds a secondary port — its wire is routed around by waypoints later
	local baseCol = math.huge
	for _, name in ipairs(members) do
		if myCol[name] < baseCol then baseCol = myCol[name] end
	end
	for _, name in ipairs(members) do
		local reg = regidOf[name]
		if reg == "Loader" or reg == "MediaIn" then myCol[name] = baseCol end
	end

	-- 2. lanes. Walk upstream from the trunk sink: the main input keeps the lane, so the
	--    main line is one straight run, while secondary inputs drop straight above or
	--    below the node that consumes them.
	local sink, bestCount = nil, -1
	for _, name in ipairs(members) do
		if #succs[name] == 0 then
			local seenUp, stack, count = {}, { name }, 0
			while #stack > 0 do
				local cur = table.remove(stack)
				if not seenUp[cur] then
					seenUp[cur] = true
					count = count + 1
					for _, e in ipairs(preds[cur]) do stack[#stack + 1] = e.name end
				end
			end
			if count > bestCount then sink, bestCount = name, count end
		end
	end
	if sink == nil then sink = members[1] end
	isl.sink = sink

	local used, myLane = {}, {}
	local function put(name, want)
		local c, l = myCol[name], want
		if used[c .. ":" .. l] then
			local k = 0
			while true do
				k = k + 1
				if not used[c .. ":" .. (want + k)] then l = want + k break end
				if not used[c .. ":" .. (want - k)] then l = want - k break end
			end
		end
		myLane[name] = l
		used[c .. ":" .. l] = name
	end

	local children = {}
    local branches = {}
    local queue = { sink }
	put(sink, 0)
	local qi = 1
	while qi <= #queue do
		local name = queue[qi]; qi = qi + 1
		local list = {}
		for i, e in ipairs(preds[name]) do list[i] = e end
		table.sort(list, function(a, b) return a.idx < b.idx end)
		local sideNo = 0
		for _, e in ipairs(list) do
			if myLane[e.name] == nil then
				local l = myLane[name]
				if e.idx ~= 1 then
					sideNo = sideNo + 1
					l = myLane[name] + sideOffset(sideNo)
				end
				children[name] = children[name] or {}
                table.insert(children[name], e.name)
                if e.idx ~= 1 then table.insert(branches, {root=e.name, parent=name}) end
                put(e.name, l)
				queue[#queue + 1] = e.name
			end
		end
	end

	local rest = {}
	for _, name in ipairs(members) do
		if myLane[name] == nil then rest[#rest + 1] = name end
	end
	table.sort(rest)
	for _, name in ipairs(rest) do put(name, 0) end

	
    local edges = {}
    for _, dst in ipairs(members) do
        for _, e in ipairs(preds[dst]) do edges[#edges+1]={e.name,dst} end
    end
    local function placementScore()
        local pts,segs,occupied={},{},{}
        for _,name in ipairs(members) do
            local key=myCol[name]..":"..myLane[name]
            if occupied[key] then return math.huge end
            occupied[key]=true
            pts[name]={x=myCol[name],y=myLane[name]}
        end
        local score=0
        for _,e in ipairs(edges) do
            local a,b=pts[e[1]],pts[e[2]]
            score=score+scoreSegment(a,b,pts,segs)*1000+math.abs(a.y-b.y)
            segs[#segs+1]={a,b}
        end
        return score
    end
    -- Lay out the backbone first. Visit its joins left to right so a later
    -- return can pass outside the short branches and their attached masks.
    local assigned, occupied = {}, {}
    local function placeChain(tip, consumer)
        local chain, pending = {}, {}
        local name = tip
        while name and not assigned[name] and not pending[name] do
            table.insert(chain,1,name)
            pending[name]=true
            local upstream
            for _,e in ipairs(preds[name]) do
                if e.idx==1 then upstream=e.name; break end
            end
            name=upstream
        end
        if #chain==0 then return end
        if consumer and #succs[tip]==1 and regidOf[tip]~="Loader" and regidOf[tip]~="MediaIn" then
            myCol[tip]=math.max(myCol[tip],myCol[consumer])
        end
        local left,right=myCol[chain[1]],myCol[tip]
        if name and assigned[name] then left=math.min(left,myCol[name]+1) end
        local row=consumer and myLane[consumer] or 0
        local dir=(#chain==1 and #preds[tip]==0 and row==0) and -1 or 1
        if consumer then row=row+dir end
        while true do
            local clear=true
            for x=left,right do
                if occupied[x..":"..row] then clear=false; break end
            end
            if clear then break end
            row=row+dir
        end
        for x=left,right do occupied[x..":"..row]=true end
        for _,node in ipairs(chain) do assigned[node]=true; myLane[node]=row end
        for _,node in ipairs(chain) do
            for _,e in ipairs(preds[node]) do
                if not assigned[e.name] then placeChain(e.name,node) end
            end
        end
    end
    placeChain(sink)
    for _,node in ipairs(members) do if not assigned[node] then placeChain(node) end end
    local best=placementScore()
    for pass=1,3 do
        local changed=false
        for _,branch in ipairs(branches) do
            local group={branch.root}
            local original={}
            local i=1
            while i<=#group do
                local name=group[i]
                original[name]=myLane[name]
                for _,child in ipairs(children[name] or {}) do group[#group+1]=child end
                i=i+1
            end
            local pivot=myLane[branch.parent]
            local chosenSign,chosenShift=1,0
            for _,sign in ipairs({-1,1}) do
                for shift=-2,2 do
                    for _,name in ipairs(group) do myLane[name]=pivot+sign*(original[name]-pivot)+shift end
                    local score=placementScore()
                    if score<best then best,chosenSign,chosenShift,changed=score,sign,shift,true end
                end
            end
            for _,name in ipairs(group) do myLane[name]=pivot+chosenSign*(original[name]-pivot)+chosenShift end
        end
        if not changed then break end
    end
    if #members>=24 then
        -- Keep the main run straight. Let side operators move towards their
        -- consumers, including masks shared across several branches.
        local trunk,cur={},sink
        while cur and not trunk[cur] do
            trunk[cur]=true
            local upstream
            for _,e in ipairs(preds[cur]) do if e.idx==1 then upstream=e.name; break end end
            cur=upstream
        end
        local pts,incident={},{}
        local base=myLane[sink]
        for _,v in ipairs(members) do
            pts[v]={x=myCol[v],y=myLane[v]-base}
            incident[v]={}
        end
        for _,e in ipairs(edges) do
            table.insert(incident[e[1]],e)
            table.insert(incident[e[2]],e)
        end
        local columns={}
        for _,v in ipairs(members) do
            local x=pts[v].x
            columns[x]=columns[x] or {}
            table.insert(columns[x],v)
        end
        for _,list in pairs(columns) do
            table.sort(list,function(a,b)
                if pts[a].y==pts[b].y then return a<b end
                return pts[a].y<pts[b].y
            end)
            local center=math.ceil(#list/2)
            for i,v in ipairs(list) do if trunk[v] then center=i end end
            for i,v in ipairs(list) do pts[v].y=i-center end
        end
        local function orientCost(e)
            local a,b=pts[e[1]],pts[e[2]]
            local dx,dy=b.x-a.x,math.abs(b.y-a.y)
            return math.abs(dx)+2*dy+4*math.min(math.abs(dx),dy)+8*math.max(0,-dx)
        end
        local function cost(v)
            local p=pts[v]
            local result=.25*math.abs(p.y)
            local nearby={}
            for _,u in ipairs(members) do
                if u~=v and p.x==pts[u].x and p.y==pts[u].y then return math.huge end
            end
            for _,e in ipairs(edges) do
                if e[1]~=v and e[2]~=v then
                    local a,b=pts[e[1]],pts[e[2]]
                    nearby[#nearby+1]={a,b}
                    result=result+scoreSegment(a,b,{p},{})*12
                end
            end
            for _,e in ipairs(incident[v]) do
                result=result+orientCost(e)+scoreSegment(pts[e[1]],pts[e[2]],pts,nearby)*12
            end
            return result
        end
        for pass=1,7 do
            local changed=false
            for i=1,#members do
                local v=members[pass%2==1 and i or #members-i+1]
                if not trunk[v] then
                    local p=pts[v]
                    local ox,oy=p.x,p.y
                    local bx,by,best=ox,oy,cost(v)
                    local cols={[ox]=true}
                    if regidOf[v]~="Loader" and regidOf[v]~="MediaIn" then
                        for _,e in ipairs(incident[v]) do
                            local other=pts[e[1]==v and e[2] or e[1]]
                            cols[other.x]=true
                            cols[math.max(0,other.x+(e[1]==v and -1 or 1))]=true
                        end
                    end
                    local xs={}
                    for x in pairs(cols) do xs[#xs+1]=x end
                    table.sort(xs)
                    for _,x in ipairs(xs) do
                        for y=-6,6 do
                            p.x,p.y=x,y
                            local value=cost(v)
                            if value<best then bx,by,best=x,y,value end
                        end
                    end
                    p.x,p.y=bx,by
                    changed=changed or bx~=ox or by~=oy
                end
            end
            if not changed then break end
        end
        for _,v in ipairs(members) do myCol[v],myLane[v]=pts[v].x,pts[v].y end
    end
-- 3. normalise the island to column 0 / lane 0
	local minC, minL, maxL = math.huge, math.huge, -math.huge
	for _, name in ipairs(members) do
		if myCol[name] < minC then minC = myCol[name] end
		if myLane[name] < minL then minL = myLane[name] end
		if myLane[name] > maxL then maxL = myLane[name] end
	end

	local bottom = 0
	for _, name in ipairs(members) do
		col[name] = myCol[name] - minC
		local l = myLane[name] - minL + offsetLane
		lane[name] = l
		if l > bottom then bottom = l end
		place[name] = { x = col[name] * COL_STEP, y = l * ROW_STEP }
	end
	
    local pts,segs,long={},{},{}
    for _,name in ipairs(members) do pts[name]={x=col[name],y=lane[name]} end
    for _,w in ipairs(wires) do
        if pts[w.dst] then
            local a,b=pts[w.src],pts[w.dst]
            if math.max(math.abs(a.x-b.x),math.abs(a.y-b.y))>=2 then
                long[#long+1]=w
            else segs[#segs+1]={a,b} end
        end
    end
    local low,high=offsetLane,bottom
    for _,w in ipairs(long) do
        if #members>=24 then segs[#segs+1]={pts[w.src],pts[w.dst],w} end
    end
    for _,w in ipairs(long) do
        for j=#segs,1,-1 do if segs[j][3]==w then table.remove(segs,j); break end end
        local a,b=pts[w.src],pts[w.dst]
        local chosen, bestRisk, bestStyle, bestLength
        local function consider(bends, style)
            style=style or 0
            local path={a}
            for _,p in ipairs(bends) do path[#path+1]=p end
            path[#path+1]=b
            local risk,length=0,0
            for j=2,#path do
                local p,q=path[j-1],path[j]
                if p.x==q.x and p.y==q.y then return end
                risk=risk+scoreSegment(p,q,pts,segs)
                if #members>=24 and p.y~=q.y and math.abs(p.x-q.x)>1 then risk=risk+0.12*math.abs(p.x-q.x) end
                length=length+math.sqrt((p.x-q.x)^2+(p.y-q.y)^2)
            end
            if not chosen or risk<bestRisk or (risk==bestRisk and
                (style<bestStyle or (style==bestStyle and (#bends<#chosen or (#bends==#chosen and length<bestLength))))) then
                chosen,bestRisk,bestStyle,bestLength=bends,risk,style,length
            end
        end
        local parallel=math.abs(a.x-b.x)>=3 and a.y~=b.y
        consider({},parallel and 1 or 0)
        if parallel then
            local step=b.x>a.x and 1 or -1
            consider({{x=a.x+step,y=b.y}})
        end
        if a.x==b.x then
            local right=0
            for _,name in ipairs(members) do right=math.max(right,col[name]) end
            for _,x in ipairs({-1,right+1}) do
                consider({{x=x,y=(a.y+b.y)/2}})
                consider({{x=x,y=a.y},{x=x,y=b.y}})
            end
        end
        if #members>=24 and a.x~=b.x then
            local step=b.x>a.x and 1 or -1
            for y=math.min(a.y,b.y)-2,math.max(a.y,b.y)+2 do
                if math.abs(a.x-b.x)>2 then
                    consider({{x=a.x+step,y=y},{x=b.x-step,y=y}})
                end
            end
        end
        for depth=1,(#members>=24 and 1 or math.min(#long+1,12)) do
            for _,y in ipairs({offsetLane-depth,bottom+depth}) do
                for _,x in ipairs({a.x,(a.x+b.x)/2,b.x}) do consider({{x=x,y=y}},1) end
                if a.x~=b.x then consider({{x=a.x,y=y},{x=b.x,y=y}},1) end
            end
        end
        w.bends=chosen
        local prev=a
        for _,p in ipairs(chosen) do
            pts[#pts+1]=p
            segs[#segs+1]={prev,p}
            prev=p
            low,high=math.min(low,p.y),math.max(high,p.y)
        end
        segs[#segs+1]={prev,b}
    end
    local shift=offsetLane-low
    for _,name in ipairs(members) do place[name].y=(lane[name]+shift)*ROW_STEP end
    for _,w in ipairs(long) do
        for _,p in ipairs(w.bends) do p.y=p.y+shift end
    end
    offsetLane=high+shift+1+ISLAND_GAP
end

for _,isl in ipairs(islands) do layoutIsland(isl) end
local parkedInputs={}
local inputTop,inputBottom=math.huge,-math.huge
if #islands==1 then
    for _,name in ipairs(islands[1].names) do
        if regidOf[name]=="Loader" or regidOf[name]=="MediaIn" then
            inputTop=math.min(inputTop,place[name].y)
            inputBottom=math.max(inputBottom,place[name].y)
        end
    end
end
local parked=0
for _,name in ipairs(loose) do
    if inputTop<math.huge and (regidOf[name]=="Loader" or regidOf[name]=="MediaIn") then
        local i=#parkedInputs
        local rows=math.floor((inputBottom-inputTop)/ROW_STEP)+1
        place[name]={x=-(1+math.floor(i/rows))*COL_STEP,y=inputTop+(i%rows)*ROW_STEP}
        parkedInputs[i+1]=name
    else
        place[name]={x=(parked%5)*COL_STEP,y=(offsetLane+math.floor(parked/5))*ROW_STEP}
        parked=parked+1
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
local count=0
for _,w in ipairs(wires) do
    local prev=w.output
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
for i,isl in ipairs(islands) do
    local loaders,sources={},{}
    for _,name in ipairs(isl.names) do
        if regidOf[name]=="Loader" or regidOf[name]=="MediaIn" then loaders[#loaders+1]=name end
        if #preds[name]==0 then sources[#sources+1]=name end
    end
    if #islands==1 then for _,name in ipairs(parkedInputs) do loaders[#loaders+1]=name end end
    frameGroup("PSN_INPUTS_"..i,#loaders>0 and loaders or sources,{R=.72,G=.58,B=.86})
    if isl.sink and #succs[isl.sink]==0 then
        frameGroup("PSN_OUTPUTS_"..i,{isl.sink},{R=.93,G=.55,B=.13})
    end
end
print(string.format("Arranged %d operators with %d waypoints. %d frame members used standard tile dimensions.",n,count,fallback))
end

comp:Lock()
local started=false
local ok,err=xpcall(function()
    comp:StartUndo("PSN Arrange Nodes")
    started=true
    arrange()
end,debug.traceback)
if started then comp:EndUndo(true) end
comp:Unlock()
if ok then pcall(function() flow:FrameAll() end)
else print("PSN Arrange Nodes stopped. Undo 'PSN Arrange Nodes' to restore the previous state.\n"..tostring(err)) end
