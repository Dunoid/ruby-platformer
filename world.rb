require "csv"
require "yaml"
require_relative "common"

# Constants and functions
class Map
	attr_reader :name, :audio
	attr_accessor :lightcolor, :darkcolor
	def initialize map_file
		dir = "maps/#{map_file}/"
		yml = YAML.load_file(get_asset(dir+"map.yml") )
		
		@name = yml["name"]
		@skybox = Image.new(get_asset(dir + yml["skybox"]))
		@audio = Song.new(get_asset("audio/" + yml["ambiance"] ) )
		@audio.play(looping=true)
		@lightcolor = Gosu::Color.new(yml["lightcolor"].to_i)
		@darkcolor = Gosu::Color.new(yml["darkcolor"].to_i)
		tiles = []
		yml["tiles"].each_with_index do |tile, i|
			tiles[i] = Image.new(get_asset( dir + tile) )
		end
		@drawcalls = @collisions = 0
		@playerX= @playerY = 0
		@objects = {}
		@w = yml["tilewidth"]
		h = yml["tileheight"]
		y = @w/2
		CSV.parse(yml["tilemap"]).each do |row|
			x = @w/2
			row.each do |tile|
				if tile == "X" then
					@playerX, @playerY = x, y
				elsif tile != "-"&& tile != "0" then
					index = tile.to_i
					if index <= tiles.length then
						image = tiles[index-1]
						@objects[[x, y]] = StaticBlock.new(image, x, y, width=@w, height=h) 
					end
				end
				x += @w
			end
			y += @w
		end
		
	end
	
	def playerstart
		[@playerX, @playerY]
	end
	
	def get_tile x, y
		@objects[[x, y]]
	end
	
	def each_in_box x, y, w, h
	#	Alright, this is probably going to cause some head scratching, but it's simpler than it looks.
	#	The tiles in the map are aligned to a grid, and their positions are used as the keys to a hash map.
	#	This means I can optimize collision detection and drawing by making a box around where the 
	#	tiles can be and getting any values along the grid in that box.  Since accessing a hash map is 
	#	in constant time, I can draw tiles and do collision checks on maps of any size.  The only thing 
	# that affects speed is how large a box I need to use and how many things are in the box. A
	# map of fifty tiles would (theoretically) perform just as quickly as one with a million tiles.

		x = x.to_i
		y = y.to_i
		min_x = ( (x-w/2)/@w )*@w + @w/2
		min_y = ( (y-h/2)/@w)*@w + @w/2
		y += @w if h > @w
		max_x = ((x+w/2)/@w)*@w + @w/2
		max_y = ((y+h/2)/@w)*@w + @w/2
		x = min_x
		while x <= max_x do
			y = min_y
			while y <= max_y do
				tile = get_tile(x,y)
				if (tile != nil) then
					yield tile
				end
				y += @w #the grid is spaced apart by w pixels
			end
			x += @w
		end
	end
	
	def collisions? collider
		each_in_box(collider.x, collider.y, collider.w, collider.h) do |tile|
			@collisions += 1
			return true if tile.collider.collision? collider
		end
		puts "Total Collision Checks: #{@collisions}" if ($debug > 2)
		return false
	end
	def update
		@collisions = 0
	end
	def draw camx, camy
		@drawcalls = 0
		@skybox.draw_as_quad(
			0, 0, 0xff_ffffff,  W_WIDTH, 0, 0xff_ffffff, 
			W_WIDTH, W_HEIGHT, 0xff_ffffff,   0, W_HEIGHT, 0xff_ffffff, Z::Skybox)
		each_in_box(camx+W_WIDTH/2, camy+W_HEIGHT/2, W_WIDTH, W_HEIGHT) do |tile| 
			tile.draw(@lightcolor, camx, camy)
			@drawcalls += 1
		end
	end
	def status
		"#{@objects.size} Objects; #{@drawcalls} Draw Calls; #{@collisions} Collision Checks"
	end
end

class StaticBlock
	attr_reader :x, :y, :collider
	def initialize image, x, y, width = 0, height = 0, shape = :box
		@x = x
		@y = y
		@image = image
		w = width == 0? image.width : width
		h = height == 0? image.height : height
		if shape == :box
			@collider = BoxCollider.new(x, y, w, h)
		else 
			@collider = CircleCollider.new(x, y, w/2)
		end
	end
	def draw color = 0xff_ffffff, camx = 0, camy = 0
		w = @image.width/2
		h = @image.width/2
		x = @x-camx
		y = @y-camy
		@image.draw_as_quad(
			x-w, y-h, color, 
			x+w, y-h, color, 
			x+w, y+h, color,
			x-w, y+h, color,
			Z::World)
		@collider.draw(camx, camy, 0xa0_ff2266) if $debug>1
	end
end