local used_nodes = {
	wall = "default:stone",
	glass = "default:glass",
	floor1 = "default:cobble",
	floor2 = "default:desert_cobble",
	roof1 = "default:wood",
	roof2 = "stairs:slab_wood",
	bef = "wool:white"
}


-- functions for indexing by x and y
local function get(tab, y,x)
	local data = tab[y]
	if data then
		return data[x]
	end
end

local function set(tab, y,x, data)
	if tab[y] then
		tab[y][x] = data
		return
	end
	tab[y] = {[x] = data}
end

local function remove(tab, y,x)
	if get(tab, y,x) == nil then
		return
	end
	tab[y][x] = nil
	if not next(tab[y]) then
		tab[y] = nil
	end
end

local function gtab2tab(tab)
	local t,n = {},1
	local miny, minx, maxy, maxx
	for y,xs in pairs(tab) do
		if not miny then
			miny = y
			maxy = y
		else
			miny = math.min(miny, y)
			maxy = math.max(maxy, y)
		end
		for x,v in pairs(xs) do
			if not minx then
				minx = x
				maxx = x
			else
				minx = math.min(minx, x)
				maxx = math.max(maxx, x)
			end
			t[n] = {y,x, v}
			n = n+1
		end
	end
	return t, {x=minx, y=miny}, {x=maxx, y=maxy}, n-1
end


-- findet die nächste Position der Wandsäulen
local function get_next_ps(pos, ps)
	local tab = {}
	for i = -1,1,2 do
		for _,p in pairs({
			{x=pos.x+i, y=pos.y, z=pos.z},
			{x=pos.x, y=pos.y, z=pos.z+i},
		}) do
			if not get(ps, p.z,p.x)
			and minetest.get_node(p).name == used_nodes.bef then
				table.insert(tab, p)
			end
		end
	end
	for i = -1,1,2 do
		for j = -1,1,2 do
			local p = {x=pos.x+i, y=pos.y, z=pos.z+j}
			if not get(ps, p.z,p.x)
			and minetest.get_node(p).name == used_nodes.bef then
				table.insert(tab, p)
			end
		end
	end
	return tab
end

-- gibt die Positionen der Wandsäulen an
local function get_wall_ps(pos)
	pos.y = pos.y-1
	if minetest.get_node(pos).name ~= used_nodes.bef then
		return
	end
	local tab = {}
	local tab2 = {}
	local p = get_next_ps(pos, tab)[1]
	while p do
		set(tab, p.z,p.x, true)
		table.insert(tab2, p)
		p = get_next_ps(p, tab)[1]
	end
	return tab, tab2
end

-- gibt die min und max Werte an
local function get_minmax_coord(oldmin, oldmax, new)
	if not oldmin then
		return new, new
	end
	return math.min(oldmin, new), math.max(oldmax, new)
end

-- [[ gibt die Positionen innerhalb an und funktioniert irgendwie nicht richtig (Wandprüfung) und erneuert die Wand Positionen
local function get_inside_ps(startpos, ps, corners)
	local todo = {startpos}
	local avoid = {}
	local tab2 = {}
	local itab = {}
	local new_wall_ps = {}
	local new_wall_tab = {}
	while next(todo) do
		for n,pos in pairs(todo) do
			for i = -1,1,2 do
				for _,p in pairs({
					{x=pos.x+i, z=pos.z},
					{x=pos.x, z=pos.z+i},
				}) do
					local z,x = p.z,p.x
					if x < corners[1]
					or x > corners[2]
					or z < corners[3]
					or z > corners[4] then
						return tab2, itab, new_wall_ps, new_wall_tab
					end
					if not get(avoid, z,x) then
						set(avoid, z,x, true)
						if get(ps, z,x) then
							set(new_wall_ps, z,x, true)
							table.insert(new_wall_tab, p)
						else
							set(tab2, z,x, true)
							table.insert(itab, p)
							table.insert(todo, p)
						end
					end
				end
			end
			todo[n] = nil
		end
	end
	return tab2, itab, new_wall_ps, new_wall_tab
end--]]

-- gibt die Boden Positionen
local function get_floor_ps(ps, ps_list)
	local xmin, xmax, zmin, zmax
	for _,p in pairs(ps_list) do
		xmin, xmax = get_minmax_coord(xmin, xmax, p.x)
		zmin, zmax = get_minmax_coord(zmin, zmax, p.z)
	end
	return get_inside_ps({x=math.floor((xmin+xmax)/2), z=math.floor((zmin+zmax)/2)}, ps, {xmin-1, xmax+1, zmin-1, zmax+1}) --{x=(xmin+xmax)*0.5, z=(zmax+zmin)*0.5}
end

-- gibt die Dach Positionen
local function get_roof_ps(wall_ps_list, ps, ps_list)
	for _,p in pairs(wall_ps_list) do
		if not get(ps, p.z,p.x) then
			table.insert(ps_list, p)
			set(ps, p.z,p.x, true)
		end
	end
	for _,p in pairs(wall_ps_list) do
		for i = -1,1,2 do
			for _,pos in pairs({
				{x=p.x+i, z=p.z},
				{x=p.x, z=p.z+i},
			}) do
				if not get(ps, pos.z,pos.x) then
					set(ps, pos.z,pos.x, true)
					pos.h = true
					table.insert(ps_list, pos)
				end
			end
		end
	end
end

-- gibt die Distanz zur naechsten Wandsaeule
local function get_wall_dist(pos, wall_ps)
	if pos.h then
		return -1
	end
	if get(wall_ps, pos.z,pos.x) then
		return 0
	end
	local dist = 1
	while dist <= 999 do
		for z = -dist,dist do
			for x = -dist,dist do
				if math.abs(x+z) == dist
				and get(wall_ps, pos.z+z,pos.x+x) then
					return dist
				end
			end
		end
		dist = dist+1
	end
	return 1000
end

-- macht eine Saeule der Wand
local glass_count = -1
local function make_wall(pos)
	local used_block = used_nodes.wall
	local nam
	minetest.set_node(pos, {name=used_block})
	minetest.set_node({x=pos.x, y=pos.y-1, z=pos.z}, {name=used_block})
	if glass_count >= 8
	or (math.random(8) == 1 and glass_count >= 4)
	or glass_count == -1 then
		nam = used_block
		glass_count = 0
	else
		nam = used_nodes.glass
		glass_count = glass_count+1
	end
	for i = 1,3 do
		minetest.set_node({x=pos.x, y=pos.y+i, z=pos.z}, {name=nam})
	end
end

-- macht einen Block des Bodens
local function make_floor_node(x, y, z)
	if z%2 == 0
	or (x%4 == 1 and z%4 == 1)
	or (x%4 == 3 and z%4 == 3) then
		minetest.set_node({x=x, y=y, z=z}, {name=used_nodes.floor1})
	else
		minetest.set_node({x=x, y=y, z=z}, {name=used_nodes.floor2})
	end
end

-- erstellt den Boden und das Dach
local function make_floor_and_roof(ps,ps_list, wall_ps, wall_ps_list, y)
	y = y-1
	for _,p in pairs(ps_list) do
		make_floor_node(p.x, y, p.z)
	end
	--[[for _,p in pairs(wall_ps_list) do
		make_floor_node(p.x, y, p.z)
	end]]
	y = y+1
	get_roof_ps(wall_ps_list, ps, ps_list)
	for _,p in pairs(ps_list) do
		local h = get_wall_dist(p, wall_ps)/2
		local h2 = math.ceil(h)
		if h == h2 then
			minetest.set_node({x=p.x, y=y+4+h, z=p.z}, {name=used_nodes.roof1})
		else
			minetest.set_node({x=p.x, y=y+4+h2, z=p.z}, {name=used_nodes.roof2})
		end
	end
	--[[for _,p in pairs(wall_ps_list) do
		minetest.set_node({x=p.x, y=y+5, z=p.z}, {name="default:desert_stone"})
	end]]
end

-- erstellt die Wände
local function make_walls(ps_list, y)
	for _,p in pairs(ps_list) do
		p.y = y
		make_wall(p)
	end
	glass_count = -1
end

-- erstellt das haus
local function make_house(pos)
	local wall_ps, wall_ps_list = get_wall_ps(pos)
	if not wall_ps
	or #wall_ps_list < 2 then
		return
	end
	local ps,ps_list, wall_ps,wall_ps_list = get_floor_ps(wall_ps, wall_ps_list)
	if not ps
	or #wall_ps_list < 2 then
		return
	end
	make_walls(wall_ps_list, pos.y)
	make_floor_and_roof(ps,ps_list, wall_ps, wall_ps_list, pos.y)
	--[[for i,_ in pairs(wall_ps) do
		local coords = string.split(i, " ")
		local p = {x=coords[2], y=pos.y, z=coords[1]}
		make_wall(p)
	end]]
end

minetest.register_node("home_builder:block", {
	description = "Hut Builder",
	tiles = {"home_builder.png"},
	groups = {snappy=1,bendy=2,cracky=1},
	sounds = default.node_sound_stone_defaults(),
	on_place = function(_, _, pointed_thing)
		local pos = pointed_thing.above
		if not pos then
			return
		end
		make_house(pos)
	end,
	on_use = function(itemstack, player, pointed_thing)
		if not player
		or not pointed_thing then
			return
		end
		local pos = pointed_thing.under
		if not pos then
			return
		end
		local control = player:get_player_control()
		local nam = minetest.get_node(pos).name
		local msg = "[home_builder] "
		if control.aux1 then
			if control.sneak then
				used_nodes.roof2 = nam
				msg = msg.."roof slab"
			else
				used_nodes.roof1 = nam
				msg = msg.."roof"
			end
		elseif control.up
		and control.down then
			if control.sneak then
				used_nodes.floor2 = nam
				msg = msg.."second floor"
			else
				used_nodes.floor1 = nam
				msg = msg.."main floor"
			end
		elseif control.sneak then
			used_nodes.glass = nam
			msg = msg.."glass"
		else
			used_nodes.wall = nam
			msg = msg.."wall"
		end
		msg = msg..": "..nam
		print(msg)
		minetest.chat_send_all(msg)
	end
})

local make_preparation
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

-- returns a perlin chunk field of positions
local default_nparams = {
   offset = 0,
   scale = 1,
   seed = 3337,
   octaves = 6,
   persist = 0.6
}
local function get_perlin_field(rmin, rmax, nparams)
	local t1 = os.clock()

	local r = math.ceil(rmax)
	nparams = nparams or {}
	for i,v in pairs(default_nparams) do
		nparams[i] = nparams[i] or v
	end
	nparams.spread = nparams.spread or vector.from_number(r*5)

	local pos = {x=math.random(-30000, 30000), y=math.random(-30000, 30000)}
	local map = minetest.get_perlin_map(nparams, vector.from_number(r+r+1)):get2dMap_flat(pos)

	local id = 1

	local bare_maxdist = rmax*rmax
	local bare_mindist = rmin*rmin

	local mindist = math.sqrt(bare_mindist)
	local dist_diff = math.sqrt(bare_maxdist)-mindist
	mindist = mindist/dist_diff

	local pval_min, pval_max

	local tab, n = {}, 1
	for z=-r,r do
		local bare_dist = z*z
		for x=-r,r do
			local bare_dist = bare_dist+x*x
			local add = bare_dist < bare_mindist
			local pval, distdiv
			if not add
			and bare_dist <= bare_maxdist then
				distdiv = math.sqrt(bare_dist)/dist_diff-mindist
				pval = math.abs(map[id]) -- strange perlin values…
				if not pval_min then
					pval_min = pval
					pval_max = pval
				else
					pval_min = math.min(pval, pval_min)
					pval_max = math.max(pval, pval_max)
				end
				add = true--distdiv < 1-math.abs(map[id])
			end

			if add then
				tab[n] = {z,x, pval, distdiv}
				n = n+1
			end
			id = id+1
		end
	end

	-- change strange values
	local pval_diff = pval_max - pval_min
	pval_min = pval_min/pval_diff

	for n,i in pairs(tab) do
		if i[3] then
			local new_pval = math.abs(i[3]/pval_diff - pval_min)
			if i[4] < new_pval then
				tab[n] = {i[1], i[2]}
			else
				tab[n] = nil
			end
		end
	end

	minetest.log("info", string.format("[home_builder] table created after ca. %.2fs", os.clock() - t1))
	return tab
end

-- [[ tests if it's a round corner
local function outcorner(tab, y,x)
	return (
		get(tab, y+1,x)
		or get(tab, y-1,x)
	)
	and (
		get(tab, y,x+1)
		or get(tab, y,x-1)
	)
end--]]

-- filters possible wall positions from the perlin field
local function get_wall_ps(rmin, rmax)
	local tab = get_perlin_field(rmin, rmax)
	local gtab = {}
	for _,p in pairs(tab) do
		set(gtab, p[1],p[2], true)
	end
	for _,p in pairs(tab) do
		local y,x = unpack(p)
		local is_wall
		for i = -1,1,2 do
			if get(gtab, y+i,x) == nil
			or get(gtab, y,x+i) == nil then
				is_wall = true
				break
			end
		end
		if not is_wall then
			set(gtab, y,x, false)
		end
	end
	for _,p in pairs(tab) do
		local y,x = unpack(p)
		if get(gtab, y,x)
		and outcorner(gtab, y,x) then
			remove(gtab, y,x)
		end
	end
	return gtab2tab(gtab)
end

-- places the nodes
function make_preparation(pos)
	local tab,minp,maxp = get_wall_ps(5,20)
	for _,p in pairs(tab) do
		if p[3] then
			p = {x=pos.x+p[2], y=pos.y, z=pos.z+p[1]}
			if minetest.get_node(p).name == "air" then
				minetest.set_node(p, {name=used_nodes.bef})
			end
		end
	end
end
