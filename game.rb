require_relative "common"
require_relative "world"
require_relative "actors"

include Gosu
class GameConsole < TextInput
#	A developer's console.  It's handy for debugging.
	Active_Color = 0xdd_ff6666
	Passive_Color=0xbf_666666
	Selection_Color = 0xcc_0000ff
	Caret_color = 0xff_ffffff
	Padding = 5
	attr_reader :x, :y, :width, :height
	attr_accessor :active
	
	def initialize font, x, y
		super()
		@font, @x, @y = font, x, y
		self.text = "COMMAND"
		active = false
	end
	def width
		w = @font.text_width(self.text)
		return (w > 200 ? w : 200)
	end
	def height
		@font.height
	end
	def filter input
		input.capitalize #This is a lazy way to forbid executing arbitrary code, since Ruby is case-sensitive
	end
	def draw
		bgcolor = active ? Active_Color : Passive_Color
		draw_quad(
			x-Padding, 			y-Padding,				bgcolor,
			x+width+Padding, 	y-Padding, 			bgcolor,
			x-Padding,				y+height+Padding,	bgcolor,
			x+width+Padding,	y+height+Padding, 	bgcolor,
			Z::UI)
		
		pos_x = x + @font.text_width(self.text[0...self.caret_pos])
	    sel_x = x + @font.text_width(self.text[0...self.selection_start])
		
		draw_quad(
			sel_x, y,          Selection_Color,
			pos_x, y,          Selection_Color,
			sel_x, y + height, Selection_Color,
			pos_x, y + height, Selection_Color, Z::UI)
		
		draw_line( pos_x, y, 0xff_ffffff, pos_x, y+height, 0xff_ffffff, Z::Text)
		@font.draw(self.text, x, y, Z::Text)
	end
	def under_point?(mx, my)
		mx > x-Padding and mx < x + width+ Padding and
			my > y-Padding and my < y+height+Padding
	end
end

class GameWindow < Window
	def initialize
		super W_WIDTH, W_HEIGHT, false
		@offsetY = 80	#off-center player from camera for aesthetic appeal
		@ui_font = Font.new(20)
		@console = GameConsole.new(@ui_font, 20, W_HEIGHT-40)
		LOAD_MAP "0_test"
		@camx = @camy = 0
		@paused = false
		@cursor = Image.new(get_asset("cursor.png"))
	end

	def debug_print
		@ui_font.draw("Player Status", 15, 15, Z::Text, 1.0, 1.0, 0xff_ffffff )
		@ui_font.draw(@player.status, 45, 35, Z::Text, 1.0, 1.0, 0xff_ffffff )
		@ui_font.draw("Map Status",15, 55, Z::Text, 1.0, 1.0, 0xff_ffffff )
		@ui_font.draw(@map.status, 45, 75, Z::Text, 1.0, 1.0, 0xff_ffffff )
		@ui_font.draw("Camera position:#{@camx},#{@camy}", 45, 95, Z::Text, 1.0, 1.0, 0xff_ffffff )
	end
	
	def draw
		debug_print if $debug > 0
		if @paused  then
			@cursor.draw(mouse_x, mouse_y, Z::Cursor)
			@console.draw if $enableconsole
		end
		@player.draw @camx, @camy
		@map.draw @camx, @camy
	end
	
	def update
		return if @paused
		@map.update
		@player.update
		#camera controls can get pretty crazy
		#basically, this is just to smooth the camera when it follows the player
		rx = (@player.x + @player.vx*25 - W_WIDTH/2)  - @camx 
		ry = (@player.y - W_HEIGHT/2 - @offsetY) - @camy 
		
		if ry > 100 then
			@camy += ry**2/(W_HEIGHT/2)/2
		elsif ry <= -250 || ry > 100 then
			@camy += ry/20
		elsif @player.grounded && @player.vy.to_i == 0 then
			@camy += ry/8 
		end
		@camx += rx/20 if(@player.moving || rx.abs > 60)
		
		@camx = @camx.to_i #all positions are as integers to prevent seams in the world tiles due to floating-point errors
		@camy = @camy.to_i
		@paused = true if ($debug > 3) #ridiculous frame-by-frame debugging
	end
	#NAMES IN ALL CAPS CAN BE ACCESSED BY THE COMMAND LINE
	def LOAD_MAP mapfile
		@map.audio.stop unless @map == nil
		@map = Map.new(mapfile.downcase)
		px, py = @map.playerstart
		self.caption = "%s (%s) - %s" % [TITLE, VERSION, @map.name]
		@player = Player.new(px, py, @map)
		@camx, @camy = px-W_WIDTH/2, py-W_HEIGHT/2
	end
	def RESET
		@player.x, @player.y = @map.playerstart
		@camx, @camy = @player.x-W_WIDTH/2, @player.y-W_HEIGHT/2
	end
	def  PLAYER_POS x=@player.x, y=@player.y
		@player.x, @player.y = x.to_i, y.to_i
	end
	def DEBUG_MODE lvl
		$debug = lvl.to_i
	end
	def FORCE_QUIT
		close
	end
	def SYSTEM_OVERRIDE
		$enableconsole = false
	end
	def LIGHT_COLOR input #I like to play with the colors
		@map.lightcolor = Color.new(input.hex.to_i)
	end
	def DARK_COLOR input
		@map.darkcolor = Color.new(input.hex.to_i)
	end
	
	def button_down(id)
		if id == KbEscape then
			@paused = !@paused
			if  !@paused && self.text_input != nil then
				@console.active = false
				self.text_input = nil
			elsif $enableconsole
				@console.active = true
				self.text_input = @console
			end
		elsif id == MsLeft then
			if @console.under_point?(mouse_x, mouse_y) && @paused then
				@console.active = true
				self.text_input = @console
			else
				@console.active = false
				@console.text = ""
				self.text_input = nil
			end
		elsif @console.active then
			if id == KbReturn then #It just sends the console text as real code.  Pretty slapdash
				begin
					self.send *@console.text.split(" ")
					@console.text = ""
				rescue Exception => exc
					@console.text = "Error: #{exc.class.name}"
					puts exc.message
				end
			elsif id == KbTab then
				@console.text = ""
			end
		end
	end
end

window = GameWindow.new

window.show
