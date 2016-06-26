gutenberg = {}
gutenberg.path = minetest.get_modpath(minetest.get_current_modname())
local world_path = minetest.get_worldpath()
gutenberg.cache_path = world_path .. '/book_cache/'

local files = {}
for _, filename in pairs(minetest.get_dir_list(gutenberg.path.."/books/")) do
	if filename:find('%.txt$') then
		files[#files+1] = filename
	end
end

--local lpp = 21 -- Lines per book's page
local lpp = 18 -- Lines per book's page

local function book_on_use(itemstack, user)
	local player_name = user:get_player_name()
	local data = minetest.deserialize(itemstack:get_metadata())
	local item_name = itemstack:get_name()

	local book = gutenberg.books[item_name]
	if not book then
		return
	end

	local page = 1
	if data and data.page then
		page = data.page
	end

	local formspec = ""
	local lines, string = {}, ""

	local file = item_name:gsub('gutenberg:book_', '') .. string.format('%04d', page) .. '.txt'
	local f = io.open(gutenberg.cache_path..'/'..file, 'r')
	if not f then
		return
	end

	local text = f:read('*a')
	f.close()
	for str in (text .. "\n"):gmatch("([^\n]*)[\n]") do
		lines[#lines+1] = str
	end

	--formspec = "size[11,10]" .. default.gui_bg ..
	formspec = "size[9,8]" .. default.gui_bg ..
	default.gui_bg_img ..
	"label[0.5,0.5;by " .. book.author .. "]" ..
	"tablecolumns[color;text]" ..
	"tableoptions[background=#00000000;highlight=#00000000;border=false]" ..
	"table[0.4,0;7,0.5;title;#FFFF00," .. minetest.formspec_escape(book.title) .. "]" ..
	--"textarea[0.5,1.5;10.5,9;;" ..
	"textarea[0.5,1.5;8.5,7;;" ..
	minetest.formspec_escape(string ~= "" and string or text) .. ";]" ..
	--"button[2.4,9.6;0.8,0.8;book_prev;<]" ..
	--"label[3.2,9.7;Page " .. page .. " of " .. book.page_max .. "]" ..
	--"button[5.9,9.6;0.8,0.8;book_next;>]"
	"button[2.4,7.6;0.8,0.8;book_prev;<]" ..
	"label[3.2,7.7;Page " .. page .. " of " .. book.page_max .. "]" ..
	"button[4.9,7.6;0.8,0.8;book_next;>]"

	minetest.show_formspec(player_name, "gutenberg:book_gutenberg", formspec)
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "gutenberg:book_gutenberg" then return end
	local stack = player:get_wielded_item()

	if fields.book_next or fields.book_prev then
		local book = gutenberg.books[stack:get_name()]
		if not book then
			return
		end

		local data = minetest.deserialize(stack:get_metadata())
		if not data or not data.page then
			data = {}
			data.page = 1
			data.page_max = book.page_max
		end

		if fields.book_next then
			data.page = data.page + 1
			if data.page > data.page_max then
				data.page = 1
			end
		else
			data.page = data.page - 1
			if data.page == 0 then
				data.page = data.page_max
			end
		end

		local data_str = minetest.serialize(data)
		stack:set_metadata(data_str)
		book_on_use(stack, player)
	end

	player:set_wielded_item(stack)
end)

gutenberg.books = {}
local titles = {}
for _, file in pairs(files) do
	if file:find('^[a-zA-Z0-9%._]+$') then
		local f = io.open(gutenberg.path..'/books/'..file, 'r')
		if f then
			for non = 1, 1 do
				local book = {}

				local text = f:read('*a')
				f:seek('set')
				text = text:gsub('\r', '')

				for tit in text:gmatch('Title: ([^\n]+)') do
					book.title = tit
				end

				for aut in text:gmatch('Author: ([^\n]+)') do
					book.author = aut
				end

				if not (book.title and book.author) then
					break
				end

				local page_max = 0
				local line = 1
				local page = 1
				local page_text = {}
				for str in (text .. "\n"):gmatch("([^\n]*)[\n]") do
					if page > lpp then
						line = 1
						local cache_file = file:gsub('%.txt$', '') .. string.format('%04d', page_max) .. '.txt'
						local full_cache_file = gutenberg.cache_path..'/'..cache_file
						local fo = io.open(full_cache_file, 'w')
						if not fo then
							gutenberg.cache_path = world_path
							full_cache_file = gutenberg.cache_path..'/'..cache_file
							fo = io.open(full_cache_file, 'w')
						end
						if fo then
							fo:write(table.concat(page_text, '\n'))
						else
							break
						end
						page_text = {}
						page_max = page_max + 1
						page = 1
					end
					page_text[#page_text+1] = str
					page = page + 1
				end

				book.page_max = page_max

				local node = 'gutenberg:book_'..file:gsub('%.txt', '')
				gutenberg.books[node] = book
				titles[#titles+1] = node

				minetest.register_craftitem(node, {
					description = book.title..' by '..book.author,
					inventory_image = "default_book_written.png",
					groups = {book = 1, not_in_creative_inventory = 1},
					stack_max = 1,
					on_use = book_on_use,
				})
			end
		end
	end
end

minetest.register_craftitem('gutenberg:book_gutenberg', {
	description = 'A Project Gutenberg book',
	inventory_image = "default_book_written.png",
	groups = {book = 1, not_in_creative_inventory = 1},
	stack_max = 1,
})

minetest.register_craft({
	output = 'gutenberg:book_gutenberg',
	recipe = {
		{'default:paper', '', ''},
		{'', 'default:paper', ''},
		{'', '', 'default:paper'},
	}
})

minetest.register_on_craft(function(itemstack, player, old_craft_grid, craft_inv)
	if #titles < 1 or itemstack:get_name() ~= "gutenberg:book_gutenberg" then
		return
	end

	itemstack:replace(titles[math.random(#titles)])
end)
