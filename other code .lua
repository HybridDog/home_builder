
--[[
local function pos_to_string(pos, y)
	if y then
		return pos.x.." "..pos.y.." "..pos.z
	end
	return pos.x.." "..pos.z
end

local function pos_allowed(pos, tab)
	if tab[pos_to_string(pos)]
	or minetest.get_node(pos).name ~= "air"
	or minetest.get_node({x=pos.x, y=pos.y-1, z=pos.z}).name == "air" then
		return false
	end
	for b = -1,1,2 do
		for _,p in pairs({
			{x=pos.x+b, y=pos.y, z=pos.z},
			{x=pos.x, y=pos.y, z=pos.z+b},
		}) do
			if minetest.get_node(p).name ~= "air"
			or minetest.get_node({x=p.x, y=p.y-1, z=p.z}).name == "air" then
				return true
			end
		end
	end
	return false
end

local function get_next_pos(pos, tab)
	for b = -1,1,2 do
		for _,p in pairs({
			{x=pos.x+b, y=pos.y, z=pos.z},
			{x=pos.x, y=pos.y, z=pos.z+b},
		}) do
			if pos_allowed(p, tab) then
				return p
			end
		end
	end
	for i = -1,1,2 do
		for j = -1,1,2 do
			local p = {x=pos.x+i, y=pos.y, z=pos.z+j}
			if pos_allowed(p, tab) then
				return p
			end
		end
	end
	return false
end

local function get_pos_table(pos)
	local tab = {}
	local n = 1
	while n < 60 do
		pos = get_next_pos(pos, tab)
		if not pos then
			return tab
		end
		tab[pos_to_string(pos)] = true
		n = n+1
	end
	tab = clean_tab(tab)
	return tab
end]]

local function get_p_yaw(x, y)
	if x == 0 then
		if y > 0 then
			return 0
		end
		return math.pi
	else
		local yaw = math.atan(y/x)
		return x > 0 and yaw+math.pi*1.5 or yaw+math.pi*0.5
	end
end

local function sort_func(a, b)
	return get_p_yaw(a[1], a[2]) > get_p_yaw(b[1], b[2])
end

-- removes unwanted positions from a table, where's the mistake?
local function clean_tab(tab)

	-- remove some outside positions
	for i,_ in pairs(tab) do
		local x, z = unpack(string.split(i, " "))
		local pstr = x.." "..z
		if (
			tab[x+1 .." "..z]
			or tab[x-1 .." "..z]
		)
		and (
			tab[x.." "..z+1]
			or tab[x.." "..z-1]
		) then
			tab[pstr] = nil
		end
	end

	-- removes corners (3 times)
	for _ = 1,3 do
		for i,_ in pairs(tab) do
			local x, z = unpack(string.split(i, " "))
			local found = 0
			for a = -1,1 do
				for b = -1,1 do
					local pstr = x+a.." "..z+b
					if tab[pstr] then
						found = found+1
					end
				end
			end
			if found < 3 then
				tab[x.." "..z] = nil
			end
		end
	end
	return tab
end

local function unneccesary(x,z,t)
	if (
		t[x+1 .." "..z]
		or t[x-1 .." "..z]
	)
	and (
		t[x.." "..z+1]
		or t[x.." "..z-1]
	) then
		return true
	end
end

local function make_preparation(pos)

	-- make a circle
	local circle = vector.circle(7)

	-- take random positions near it
	local circran = {}
	for n,p in pairs(circle) do
		local m = n/2
		if m == math.floor(m) then
			circran[m] = {p.x+math.random(-2,2), p.z+math.random(-2,2)}
		end
	end

	-- sort them by their angle to the middle
	table.sort(circran, sort_func)

	-- connect them with lines
	local lin = {}
	local lin2 = {}
	for n = 1,#circran do
		local p1 = circran[n]
		local p2 = circran[n+1] or circran[1]
		for _,i in ipairs(vector.twoline(p2[1]-p1[1], p2[2]-p1[2])) do
			local x,z = i[1]+p1[1], i[2]+p1[2]
			table.insert(lin, {x, z})
			lin2[x.." "..z] = true
		end
	end

	-- remove unallowed positions
	--[[ remove inside nodes made by lines
	for n,p in pairs(lin) do
		local x,z = unpack(p)
		local dist = math.hypot(x, z)
		local tab = {}
		for i = -1,1,2 do
			for _,j in pairs({
				{i, 0},
				{0, i},
			}) do
				local xc, zc = x+j[1], z+j[2]
				local pstr = xc.." "..zc
				if lin2[pstr]
				and math.hypot(xc, zc) >= dist then
					tab[pstr] = true
				end
			end
		end
		if unneccesary(x, z, tab) then
			lin[n] = nil
			--lin2[x.." "..z] = nil
		end
	end

	-- update lin2
	lin2 = {}
	for _,p in pairs(lin) do
		lin2[p[1].." "..p[2] ] = true
	end
	lin = nil

	-- removes other unwanted positions
	lin2 = clean_tab(lin2)
	--]]

	local tab = {}
	local x,z = unpack(lin[1])
	local yaw = get_p_yaw(x, z)
	while yaw do
		tab[x.." "..z] = true
		local ps = {}
		for i = -1,1 do
			for j = -1,1 do
				local xc, zc = x+i, z+j
				local cyaw = get_p_yaw(xc, zc)
				if cyaw >= yaw
				and lin2[xc.." "..zc]
				and not tab[xc.." "..zc] then
					table.insert(ps, {xc, zc, cyaw})
				end
			end
		end
		local t = {}
		local maxdist
		for i = 1,#ps do
			local x = ps[i][1]
			local z = ps[i][2]
			local dist = math.hypot(x,z)
			if not maxdist then
				maxdist = dist
			else
				maxdist = math.max(dist, maxdist)
			end
			t[dist] = ps[i]
		end
		if not maxdist then
			break
		end
		x,z,yaw = unpack(t[maxdist])
	end
	lin = nil
	lin2 = tab

	-- set the nodes
	for i,_ in pairs(lin2) do
		local x, z = unpack(string.split(i, " "))
		local p = {x=x+pos.x, y=pos.y, z=z+pos.z}
		minetest.set_node(p, {name=used_nodes.bef})
	end
--[[	for i,_ in pairs(get_pos_table(pos)) do
		local x, z = unpack(string.split(i, " "))
		local p = {x=x, y=pos.y, z=z}
		minetest.set_node(p, {name=used_nodes.bef})
	end
	local startpos = vector.new(pos)
	local used_ps = {}
	pos.z = pos.z+r
	local count = 0
	while count < 60 do
		count = count+1
		used_ps[pos.x.." "..pos.z] = true
		--if nd1 == "air"
		--and nd2 ~= "air" then
			minetest.set_node(pos, {name=used_nodes.bef})
		--end
		for _,p in pairs({
			{x=pos.x+1, z=pos.z},
			{x=pos.x-1, z=pos.z},
			{x=pos.x, z=pos.z+1},
			{x=pos.x, z=pos.z-1},
		}) do
			local nd1 = minetest.get_node({x=p.x, y=pos.y, z=p.z}).name
			local nd2 = minetest.get_node({x=p.x, y=pos.y-1, z=p.z}).name
			local ra = math.floor(( (p.x-startpos.x)^2 + (p.z-startpos.z)^2 )/10+0.5)
				minetest.chat_send_all(ra.." "..rr)
			if not used_ps[p.x.." "..p.z]
			and nd2 ~= "air"
			and nd1 == "air"
			and ra == rr then
				pos.x = p.x
				pos.z = p.z
				break
			end
		end
	end]]
end

minetest.register_node("home_builder:prep", {
	description = "Hut Preparation",
	tiles = {"home_builder.png"},
	groups = {snappy=1,bendy=2,cracky=1},
	sounds = default.node_sound_stone_defaults(),
	on_place = function(_, _, pointed_thing)
		local pos = pointed_thing.above
		if not pos then
			return
		end
		make_preparation(pos)
	end,
})
