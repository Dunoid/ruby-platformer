require "gosu"

TITLE = "Project Hail"
VERSION = "Alpha"
GRAVITY = 1
W_WIDTH = 900
W_HEIGHT = 600
$debug = 0
$enableconsole = true

def get_asset(file)
	File.join(File.dirname(__FILE__), "assets", VERSION, file)
end

module Z
	Skybox, World, Debug, Player, UI, Text, Cursor = *0..40
end

class BoxCollider
	attr_reader :w, :h
	attr_accessor :x, :y
	def initialize x, y, width, height
		@x = x
		@y = y
		@w = width
		@h = height
	end

	def collision? collider
		if collider.respond_to?(:radius) then
			return collider.collision? self
		else
			((collider.x - @x).abs <= collider.w/2 + @w/2 ) && ( (collider.y-@y).abs <= collider.h/2 + @h/2 )
		end
	end
	
	def draw camx=0, camy=0, color=0xff_00ff55
		Gosu.draw_rect(@x-@w/2-camx, @y-@h/2-camy, @w, @h, color, Z::Debug)
	end
end
"""
	The Circle Collider detects collision properly, but without friction and sliding it constantly snags on objects, 
	so it isn't terribly useful.
"""
class CircleCollider
	attr_reader :radius
	attr_accessor :x, :y
	def initialize x, y, radius
		@x = x
		@y = y
		@radius = radius
	end
	
	def w
		radius * 2
	end
	
	def h
		radius*2
	end
	
	def collision? collider
		if collider.respond_to?(:radius) then
			Math.sqrt( (collider.x-@x)**2 + (collider.y-@y)**2 ) <= collider.radius + @radius
		else
			dist = @radius/Math.sqrt( (collider.x-@x)**2 + (collider.y-@y)**2 ) 
			colx = (@x + (collider.x - @x)*dist - collider.x).abs <= collider.w/2
			if colx then
				coly = (@y + (collider.y - @y)*dist - collider.y).abs <= collider.w/2
				colx && coly
			else
				false
			end
		end
	end
end
