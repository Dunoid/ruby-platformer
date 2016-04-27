require_relative "common"

class Player
	attr_reader :collider, :vx, :vy, :grounded, :jumping, :x, :y
	attr_accessor :moving
	def initialize x, y, map
		@map = map
		width = 64
		height = 64
		@animation =  {
			:idle => Animation.new(Image.load_tiles(get_asset("player/idle.bmp"), width, height), 180, Z::Player, loop ),
			:run => Animation.new(Image.load_tiles(get_asset("player/run.bmp"), width, height), 100, Z::Player, loop),
			:air => Animation.new(Image.load_tiles(get_asset("player/falling.bmp"), width, height), 0, Z::Player)
		}
		@moving = false
		@x, @y = x, y
		@collider = BoxCollider.new(@x, @y, 20, 56)
		@ground_box = BoxCollider.new(@x, @y+30, 20, 8)
		@vx = 0
		@vy = 0
		@jump_power = 20
		@hspeed = 3
		@jumping = false
		@direction = :right
		@grounded =  @map.collisions? @ground_box
	end
	
	def update
		@grounded = @map.collisions? @ground_box
		ax = 0
		ay = GRAVITY
		ax -= 1 if button_down?(KbA) || button_down?(GpLeft)
		ax += 1 if button_down?(KbD) || button_down?(GpRight)
		
		if @grounded && !@jumping && (button_down? KbSpace) then
			@vy -= @jump_power
		elsif !@grounded && (button_down? KbSpace) then
			@jumping = true
		elsif @jumping && @grounded && !(button_down? KbSpace) then
			@jumping = false
		end
		
		ax *= @hspeed
		@vx += ax
		@vy += ay
		@vx *= 0.7
		@vy *= 0.98
		
		#Apply velocity, check for collisions, and subtract if there were any
		
		@collider.x += @vx.to_i
		s = @vx.abs > 1 ? @vx/@vx.abs : @vx
		while @map.collisions?(@collider) && @vx != 0 do
			@collider.x -= s.to_i
			@vx -= s
		end
		
		@collider.y += @vy.to_i
		s = @vy.abs > 1 ? @vy/@vy.abs : @vy
		while @map.collisions?(@collider) && @vy != 0 do
			@collider.y -= s.to_i
			@vy -= s
		end
		
		if(@vx.to_i != 0 && !@moving) then
			@moving = true
			@animation[:idle].reset
		elsif(@vx.to_i == 0 && @moving) then
			@moving = false
			@animation[:run].reset
		end
		
		@ground_box.x += @vx.to_i
		@ground_box.y += @vy.to_i
		
		@x = @collider.x
		@y = @collider.y
		if @vx > 0 then
			@direction = :right
		elsif @vx < 0 then
			@direction = :left
		end
		if !@grounded then
			if @vy >=4 then
				@animation[:air].frame = 3
			elsif @vy >= 0 then 
				@animation[:air].frame = 2
			elsif @vy >= -2 then
				@animation[:air].frame = 1
			else
				@animation[:air].frame = 0
			end
		elsif moving then
			@animation[:run].update
		else
			@animation[:idle].update
		end
	end
	def draw camx = 0, camy = 0
		if $debug > 1 then
			@collider.draw(camx, camy, 0xcc_55ff88)
			color = grounded ? 0xcc_ff22dd : 0xff_ee8855
			@ground_box.draw(camx, camy, color)
		end
		
		state = :idle
		if !@grounded then
			state = :air
		elsif @moving then
			state = :run
		end
		if @direction == :right then
			@animation[state].draw(@x-camx, @y-camy,:normal,@map.lightcolor, @map.darkcolor) 
		else 
			@animation[state].draw(@x-camx, @y-camy,:flipH,@map.lightcolor, @map.darkcolor)
		end
	end
	def anim_status
		state = moving ? :run : :idle
		@animation[state].status
	end
	def status
		sprintf "Pos: (%d,%d) Grounded: %s, Moving: %s; Velocity: (%.2f, %.2f)", @x, @y, @grounded  , @moving , @vx, @vy
	end
	def x= x
		dx = x-@x
		@x += dx
		@collider.x += dx
		@ground_box.x += dx
	end
	def y= y
		dy = y-@y
		@y += dy
		@collider.y += dy
		@ground_box.y += dy
	end
end

class Animation
	def initialize(images, framerate=0, z = Z::Effects, loop = false, start_frame = 0)
		@seq = images
		@ms_frame = framerate
		@loop = loop
		@frame = start_frame
		@z = z
	end

	def update 
		return if @ms_frame == 0 #if ms_frame is zero, assume it doesn't update here
		now = Gosu.milliseconds
		@time ||= now
		if (now - @time) > @ms_frame
			@loop ? @frame = (@frame + 1) % @seq.size : @frame += 1
			@time = now
		end
	end

	def done?
		return @frame >= @seq.size
	end
	
	def frame=(value)
		if value >= 0 && value < @seq.length
			@frame = value
		end
	end

	def draw(x,y, mode=:normal, color1 = 0xff_ffffff, color2 = 0xff_ffffff) 
		return if done?
		@frame = @frame % @seq.size
		image = @seq[@frame]
		
		h = mode == :flipV ? -image.height/2 : image.height/2
		w =  mode == :flipH ? -image.width/2 : image.width/2
		image.draw_as_quad(x-w, y-h, color1, x+w, y-h, color1, x+w, y+h, color2, x-w, y+h, color2, @z)
	end

	def reset
		@frame = 0
	end

	def status
		l = @loop ? "true" : "false"
		"Z: #{@z} Frame: #{@frame} Loop: #{l}"
	end
end
