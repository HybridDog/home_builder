-- findet die naechste Position der Wandsaeulen
local function get_next_ps(pos, ps)
	local tab = {}
	for i = -1,1,2 do
		for _,p in pairs({
			{x=pos.x+i, y=pos.y, z=pos.z},
			{x=pos.x, y=pos.y, z=pos.z+i},
		}) do
			if not ps[p.z.." "..p.x]
			and minetest.get_node(p).name == "default:desert_stone" then
				table.insert(tab, p)
			end
		end
	end
	for i = -1,1,2 do
		for j = -1,1,2 do
			local p = {x=pos.x+i, y=pos.y, z=pos.z+j}
			if not ps[p.z.." "..p.x]
			and minetest.get_node(p).name == "default:desert_stone" then
				table.insert(tab, p)
			end
		end
	end
	return tab
end

-- gibt die Positionen der Wandsaeulen an
local function get_wall_ps(pos)
	pos.y = pos.y-1
	if minetest.get_node(pos).name ~= "default:desert_stone" then
		return
	end
	local tab = {}
	local tab2 = {}
	local p = get_next_ps(pos, tab)[1]
	while p do
		tab[p.z.." "..p.x] = true
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

-- gibt die Positionen innerhalb an und funktioniert nicht richtig (Wandpruefung)
local function get_inside_ps(startpos, ps, corners)
	local tab = {startpos}
	local tab2 = {}
	local tab3 = {}
	while tab[1] do
		for n,pos in pairs(tab) do
			tab[n] = nil
			for i = -1,1,2 do
				for _,p in pairs({
					{x=pos.x+i, z=pos.z},
					{x=pos.x, z=pos.z+i},
				}) do
					if p.x < corners[1]
					or p.x > corners[2]
					or p.z < corners[3]
					or p.z > corners[4] then
						return tab2, tab3
					end
					local pstr = p.z.." "..p.x
					if not tab2[pstr] then
						tab2[pstr] = true
						table.insert(tab3, p)
						if not ps[pstr] then
							table.insert(tab, p)
						end
					end
				end
			end
		end
	end
	return tab2, tab3
end

-- gibt die Boden Positionen
local function get_floor_ps(ps, ps_list)
	local xmin, xmax, zmin, zmax
	for _,p in pairs(ps_list) do
		xmin, xmax = get_minmax_coord(xmin, xmax, p.x)
		zmin, zmax = get_minmax_coord(zmin, zmax, p.z)
	end
	local pos = {x=xmin+(xmax-xmin)*0.5, z=zmin+(zmax-zmin)*0.5}
	return get_inside_ps(pos, ps, {xmin-1, xmax+1, zmin-1, zmax+1})
end

-- gibt die Dach Positionen
local function get_roof_ps(wall_ps_list, ps, ps_list)
	for _,p in pairs(wall_ps_list) do
		for i = -1,1,2 do
			for _,pos in pairs({
				{x=p.x+i, z=p.z},
				{x=p.x, z=p.z+i},
			}) do
				if not ps[pos.z.." "..pos.x] then
					pos.h = true
					table.insert(ps_list, pos)
				end
			end
		end
	end		
	return ps_list
end

-- gibt die Distanz zur naechsten Wandsaeule
local function get_wall_dist(pos, wall_ps)
	if pos.h then
		return -1
	end
	if wall_ps[pos.z.." "..pos.x] then
		return 0
	end
	local dist = 1
	while dist <= 9 do
		for z = -dist,dist do
			for x = -dist,dist do
				if math.abs(x+z) == dist
				and wall_ps[pos.z+z.." "..pos.x+x] then
					return dist
				end
			end
		end
		dist = dist+1
	end
	return 10
end

-- macht eine Saeule der Wand
local glass_count = -1
local function make_wall(pos)
	local used_block = "default:stone"
	local nam
	minetest.set_node(pos, {name=used_block})
	if glass_count >= 8
	or (math.random(8) == 1 and glass_count >= 4)
	or glass_count == -1 then
		nam = used_block
		glass_count = 0
	else
		nam = "default:glass"
		glass_count = glass_count+1
	end
	for i = 1,3 do
		minetest.set_node({x=pos.x, y=pos.y+i, z=pos.z}, {name=nam})
	end
end

-- erstellt den Boden und das Dach
local function make_floor_and_roof(wall_ps, wall_ps_list, y)
	local ps,ps_list = get_floor_ps(wall_ps, wall_ps_list)
	for _,p in pairs(ps_list) do
		if p.z%2 == 0
		or (p.x%4 == 1 and p.z%4 == 1)
		or (p.x%4 == 3 and p.z%4 == 3) then
			minetest.set_node({x=p.x, y=y-1, z=p.z}, {name="default:cobble"})
		else
			minetest.set_node({x=p.x, y=y-1, z=p.z}, {name="default:desert_cobble"})
		end
	end
	ps_list = get_roof_ps(wall_ps_list, ps, ps_list)
	for _,p in pairs(ps_list) do
		local h = get_wall_dist(p, wall_ps)/2
		local h2 = math.ceil(h)
		if h == h2 then
			minetest.set_node({x=p.x, y=y+4+h, z=p.z}, {name="default:wood"})
		else
			minetest.set_node({x=p.x, y=y+4+h2, z=p.z}, {name="stairs:slab_wood"})
		end
	end
end

-- erstellt die Wände
local function make_walls(ps_list)
	for _,p in ipairs(ps_list) do
		make_wall(p)
	end
	glass_count = -1
end

-- erstellt das haus
local function make_house(pos)
	local wall_ps, wall_ps_list = get_wall_ps(pos)
	if not wall_ps then
		return
	end
	make_walls(wall_ps_list)
	make_floor_and_roof(wall_ps, wall_ps_list, pos.y)
	--[[for i,_ in pairs(wall_ps) do
		local coords = string.split(i, " ")
		local p = {x=coords[2], y=pos.y, z=coords[1]}
		make_wall(p)
	end]]
end

minetest.register_node("home_builder:block", {
	description = "house",
	tiles = {"ac_block.png"},
	groups = {snappy=1,bendy=2,cracky=1},
	sounds = default_stone_sounds,
	on_place = function(_, _, pointed_thing)
		local pos = pointed_thing.above
		if not pos then
			return
		end
		make_house(pos)
	end,
})
