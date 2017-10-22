class SSCElement
  constructor: (@element) ->
    @id = SSCElement.id_counter++
    @parent = null
  show: -> 
    @element.style.display = 'block'
  hide: ->
    @element.style.display = 'none'
  width:->
    @element.clientWidth
  height:->
    @element.clientHeight
  x: ->
    @element.offsetLeft
  y: ->
    @element.offsetTop
  r: ->
    Math.sqrt(Math.pow(@width(), 2) + Math.pow(@height(), 2)) / 1.414
  
  distance_to: (other) ->
    Math.sqrt(Math.pow( (@x() + @width()/2) - (other.x() + other.width()/2), 2) + Math.pow( (@y() + @height()/2) - (other.y() + other.height()/2), 2 ))

  move: (x, y) ->
    @element.style.left = x
    @element.style.top  = y

SSCElement.id_counter = 0

class SandStar extends SSCElement
  constructor: (@element, @touch_dx, @touch_dy) ->
    super(@element)
    @mouse_down = false
    @last_mosue_pos = null
    @element.addEventListener('mousedown', (evt) => @_on_mousedown evt)
    document.addEventListener('mouseup', (evt) => @_on_mouseup evt)
    document.addEventListener('mousemove', (evt) => @_on_mousemove evt)
    @element.style.position = 'absolute'
    @element.style.userSelect = 'none'


    @element.addEventListener 'mouseenter', ({clientX, clientY})=>
      @last_mosue_pos = [clientX, clientY]
      @_on_touching({clientX, clientY})
    @element.addEventListener 'mouseout', (evt)=>
      @_on_touching(evt)
      @last_mosue_pos = null
    # @element.addEventListener 'mouseover', (evt) => @_on_touching(evt)

  _on_touching: ({clientX, clientY}) ->
    return if @mouse_down or @last_mosue_pos is null
    [lx, ly] = @last_mosue_pos
    dx = @touch_dx*(clientX-lx)
    nx = @x()+dx
    dy = @touch_dy*(clientY-ly)
    ny = @y()+dy
    # console.log dx, dy
    @move(nx, ny)
    @last_mosue_pos = [clientX, clientY]
  _on_mousedown: ({clientX, clientY}) ->
    @mouse_down = true

  _on_mouseup:   () ->
    @mouse_down = false

  _on_mousemove: ({clientX, clientY}) ->
    return if not @mouse_down
    nx = (clientX - @element.clientLeft) - @element.clientWidth / 2
    ny = (clientY - @element.clientTop)  - @element.clientHeight / 2
    @element.style.left = nx
    @element.style.top = ny
    @on_mousemove(this, nx, ny)

  on_mousemove: (ss) ->


class Friend extends SSCElement
  check_hit: (other) ->
    # @distance_to(other) <= Math.max(@r(), other.r()) * (@parent && @parent.hit_dist_adj || 1.0)
    (
      other.y() > this.y() &&
      other.y() + other.height() < this.y() + this.height()
    ) && (
      other.x() + other.width() < this.x() + this.width()  && 
      other.x()  > this.x()
    )
  
  on_hit: (el) ->
    console.log "HIT!!"


class SandStarController
  constructor: ({el, number, generator, speed: @speed, refresh_time: @refresh_time, release_time: @release_time, touch_dx: @touch_dx, touch_dy: @touch_dy, click_dx: @click_dx, click_dy: @click_dy}) ->
    @element = el
    @wait_queue = (new SandStar(generator(i), @touch_dx, @touch_dy) for i in [0...number])
    @move_set  = {}
    # @pos_dict  = {}
    @friends  = []
    for ss in @wait_queue
      el.appendChild ss.element
      mouse_down = false
      ss.hide()
      ss.on_mousemove = (ss, x, y) =>
        # @pos_dict[ss.id] = [x, y]
        @check_hit_for_ss ss
    el.addEventListener('click', (evt) => @on_click(evt))
  
  add_friend: (friend) ->
    friend.parent = this
    @friends.push friend

  start: ->
    @released_ts = 0
    @iid = setInterval (=> 
      # console.log @wait_queue
      @update_pos()
      if @released_ts <= 0
        @release()
        @released_ts = @release_time
      @released_ts -= @refresh_time
    ), @refresh_time
  
  stop: ->
    clearInterval @iid
    for ss in @wait_queue
      ss.hide()
  
  recovery: (ss)->
    ss.hide()
    delete @move_set[ss.id]
    @wait_queue.push ss

  release: ->
    return if @wait_queue.length == 0
    el = @wait_queue.shift()
    x = Math.random() * (@element.clientWidth - el.width())
    # @pos_dict[el.id] = [x, -el.height()]
    el.move(x, -el.height())
    el.show()
    @move_set[el.id] = el
  
  check_hit_for_ss: (ss) ->
    for f in @friends
      if f.check_hit(ss)
        f.on_hit()
        @recovery ss

  update_pos: ->
    for id, ss of @move_set
      continue if ss.mouse_down
      # console.log ss
      # [x, y] = @pos_dict[id]
      # ny = y + @speed * @refresh_time
      # @pos_dict[id] = [x, ny]
      x = ss.x()
      ny= ss.y() + @speed * @refresh_time
      ss.move x, ny 
      @check_hit_for_ss ss
      if ny > @element.clientHeight + ss.height()
        @recovery ss

  on_click: ({clientX, clientY}) ->
    for id, ss of @move_set
      continue if ss.mouse_down
      dx = @click_dx * (clientX-ss.x())
      dy = @click_dy * (clientY-ss.y())
      ss.move ss.x()+dx, ss.y()+dy