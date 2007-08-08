# Created by Satoshi Nakagawa.
# You can redistribute it and/or modify it under the Ruby's license or the GPL2.

class AppController < OSX::NSObject
  include OSX
  ib_outlet :window, :tree, :log_base, :console_base, :member_list, :text
  ib_outlet :root_split, :log_split, :info_split
  ib_outlet :menu, :server_menu, :channel_menu, :member_menu, :tree_menu, :log_menu, :console_menu, :url_menu, :addr_menu
  
  def awakeFromNib
    app = NSApplication.sharedApplication
    nc = NSWorkspace.sharedWorkspace.notificationCenter
    nc.addObserver_selector_name_object(self, :terminateWithoutConfirm, NSWorkspaceWillPowerOffNotification, NSWorkspace.sharedWorkspace)
    
    @pref = Preferences.new
    @pref.load
    
    @window.key_delegate = self
    @text.setFocusRingType(NSFocusRingTypeNone)
    @window.makeFirstResponder(@text)
    @root_split.setFixedViewIndex(1)
    @log_split.setFixedViewIndex(1)
    @info_split.setFixedViewIndex(1)
    load_window_state
    
    @world = IRCWorld.alloc.init
    @world.pref = @pref
    @world.window = @window
    @world.tree = @tree
    @world.text = @text
    @world.log_base = @log_base
    @world.console_base = @console_base
    @world.member_list = @member_list
    @world.server_menu = @server_menu
    @world.channel_menu = @channel_menu
    @world.tree_menu = @tree_menu
    @world.log_menu = @log_menu
    @world.console_menu = @console_menu
    @world.url_menu = @url_menu
    @world.addr_menu = @addr_menu
    @world.menu_controller = @menu
    @tree.setDataSource(@world)
    @tree.setDelegate(@world)
    @tree.responder_delegate = @world
    #cell = UnitNameCell.alloc.init
    #cell.view = @tree
    #@tree.tableColumnWithIdentifier('name').setDataCell(cell)
    #@tree.setIndentationPerLevel(0.0)
    #seed = {:units => {}}
    #@world.setup(IRCWorldConfig.new(seed))
    @world.setup(IRCWorldConfig.new(@pref.load_world))
    @tree.reloadData
    @world.setup_tree
    
    @menu.app = self
    @menu.pref = @pref
    @menu.world = @world
    @menu.window = @window
    @menu.tree = @tree
    @menu.member_list = @member_list
    @menu.text = @text
    
    @member_list.setTarget(@menu)
    @member_list.setDoubleAction('memberList_doubleClicked:')
    @member_list.key_delegate = @world
    #@member_list.tableColumnWithIdentifier('nick').setDataCell(MemberListCell.alloc.init)
    
    @dcc = DccManager.alloc.init
    @dcc.pref = @pref
    @dcc.world = @world
    @world.dcc = @dcc
    
    @history = InputHistory.new
  end
  
  def terminateWithoutConfirm(sender)
    @terminating = true
    NSApp.terminate(self)
  end
  
  def applicationDidFinishLaunching(sender)
    @world.start_timer
    @world.auto_connect
  end
  
  def applicationShouldTerminate(sender)
    return NSTerminateNow if @terminating
    if queryTerminate
      NSTerminateNow
    else
      NSTerminateCancel
    end
  end
  
  def applicationWillTerminate(notification)
    @menu.terminate
    @world.terminate
    @dcc.save_window_state
    save_window_state
    #@world.save
  end
  
  def applicationDidBecomeActive(notification)
    sel = @world.selected
    sel.reset_state if sel
    @tree.setNeedsDisplay(true)
  end
  
  def applicationDidResignActive(notification)
    @tree.setNeedsDisplay(true)
  end
  
  objc_method :windowShouldClose, 'c@:@'
  def windowShouldClose(sender)
    if queryTerminate
      @terminating = true
      true
    else
      false
    end
  end
  
  def windowWillClose(notification)
    terminateWithoutConfirm(self)
  end
  
  def windowWillReturnFieldEditor_toObject(sender, obj)
    unless @field_editor
      @field_editor = FieldEditorTextView.alloc.initWithFrame(NSRect.new(0,0,0,0))
      @field_editor.setFieldEditor(true)
      @field_editor.paste_delegate = self
    end
    @field_editor
  end
  
  def fieldEditorTextView_paste(sender)
    s = NSPasteboard.generalPasteboard.stringForType(NSStringPboardType)
    return false unless s
    s = s.to_s
    sel = @world.selected
    if sel && !sel.unit? && /.+(\r\n|\r|\n).+/ =~ s
      @menu.start_paste_dialog(sel.unit.id, sel.id, s)
      true
    else
      false
    end
  end
  
  def preferences_changed
    @world.preferences_changed
  end
  
  def textEntered(sender)
    s = @text.stringValue.to_s
    unless s.empty?
      if @world.input_text(s)
        @history.add(s)
        @text.setStringValue('')
      end
    end
    @world.select_text
  end
  
  objc_method 'control:textView:doCommandBySelector:', 'c@:@@:'
  def control_textView_doCommandBySelector(control, textview, selector)
    case selector
    when 'moveUp:'
      s = @history.up
      if s
        @text.setStringValue(s)
        @world.select_text
      end
      true
    when 'moveDown:'
      s = @history.down(@text.stringValue.to_s)
      if s
        @text.setStringValue(s)
        @world.select_text
      end
      true
    else
      false
    end
  end
  
  def controlUp
    move(:up)
  end
  
  def controlDown
    move(:down)
  end
  
  def controlLeft
    move(:left)
  end
  
  def controlRight
    move(:right)
  end
  
  def commandUp
    move(:up, :active)
  end
  
  def commandDown
    move(:down, :active)
  end
  
  def commandLeft
    move(:left, :active)
  end
  
  def commandRight
    move(:right, :active)
  end
  
  def tab
    case @pref.gen.tab_action
    when Preferences::General::TAB_UNREAD
      move(:down, :unread)
      true
    when Preferences::General::TAB_COMPLETE_NICK
      complete_nick
      true
    else
      false
    end
  end
  
  def controlTab
    move(:down, :unread)
  end
  
  def controlShiftTab
    move(:up, :unread)
  end
  
  def altSpace
    move(:down, :unread)
  end
  
  def altShiftSpace
    move(:up, :unread)
  end
  
  def scroll(direction)
    if @window.firstResponder == @text.currentEditor
      sel = @world.selected
      if sel
        log = sel.log
        view = log.view
        case direction
        when :up; view.scrollPageUp(self)
        when :down; view.scrollPageDown(self)
        when :home; log.moveToTop
        when :end; log.moveToBottom
        end
      end
      true
    else
      false
    end
  end
  
  def number(n)
    @world.select_channel_at(n)
  end
  
  
  private
  
  def complete_nick
    u, c = @world.sel
    return unless u && c
    @world.select_text if @window.firstResponder != @window.fieldEditor_forObject(true, @text)
    fe = @window.fieldEditor_forObject(true, @text)
    return unless fe
    r = fe.selectedRanges.to_a[0]
    return unless r
    r = r.rangeValue
    nicks = c.members.map {|i| i.nick }
    
    s = @text.stringValue
    pre = s.substringToIndex(r.location).to_s
    sel = s.substringWithRange(r).to_s
    if /\s([^\s]*)$/ =~ pre
      pre = $1
      head = false
    else
      head = true
    end
    return if pre.empty?
    if /^[^\w\[\]\\`_^{}|](.+)$/ =~ pre
      pre[0] = ''
      head = false
    end
    
    current = pre + sel
    current = $1 if /([^:\s]+):?\s?$/ =~ current
    downpre = pre.downcase
    downcur = current.downcase
    
    nicks = nicks.select {|i| i[0...pre.length].downcase == downpre }
    return if nicks.empty?
    
    if sel.empty?
      s = nicks[0]
    else
      index = nicks.index {|i| i.downcase == downcur }
      if index
        index += 1
        index = 0 if nicks.length <= index
        s = nicks[index]
      else
        s = nicks[0]
      end
    end
    s += ': ' if head
    
    ps = NSString.stringWithString(pre)
    ns = NSString.stringWithString(s)
    range = r.dup
    range.location -= ps.length
    range.length += ps.length
    fe.replaceCharactersInRange_withString(range, s)
    
    if nicks.length == 1
      r.location = @text.stringValue.length
      r.length = 0
    else
      r.length = ns.length
    end
    fe.setSelectedRange(r)
  end

  def queryTerminate
    rec = @dcc.count_receiving_items
    send = @dcc.count_sending_items
    if rec > 0 || send > 0
      msg = "Now you are "
      if rec > 0
        msg += "receiving #{rec} files"
      end
      if send > 0
        msg += " and " if rec > 0
        msg += "sending #{send} files"
      end
      msg += ".\nAre you sure to quit?"
      return NSRunCriticalAlertPanel('LimeChat', msg, 'Anyway Quit', 'Cancel', nil) == NSAlertDefaultReturn
    elsif @pref.gen.confirm_quit
      NSRunCriticalAlertPanel('LimeChat', 'Are you sure to quit?', 'Quit', 'Cancel', nil) == NSAlertDefaultReturn
    else
      true
    end
  end
  
  def load_window_state
    win = @pref.load_window('main_window')
    if win
      f = NSRect.from_dic(win)
      @window.setFrame_display(f, true)
      @root_split.setPosition(win[:root])
      @log_split.setPosition(win[:log])
      @info_split.setPosition(win[:info])
    else
      scr = NSScreen.screens[0]
      if scr
        p = scr.visibleFrame.center
        w = 500
        h = 500
        win = {
          :x => p.x - w/2,
          :y => p.y - h/2,
          :w => w,
          :h => h
        }
        f = NSRect.from_dic(win)
        @window.setFrame_display(f, true)
      end
      @root_split.setPosition(150)
      @log_split.setPosition(150)
      @info_split.setPosition(250)
    end
  end
  
  def save_window_state
    win = @window.frame.to_dic
    split = {
      :root => @root_split.position,
      :log => @log_split.position,
      :info => @info_split.position,
    }
    win.merge!(split)
    @pref.save_window('main_window', win)
  end

  def move(direction, target=:all)
    case direction
    when :up,:down
      sel = @world.selected
      return unless sel
      n = @tree.rowForItem(sel)
      return unless n
      n = n.to_i
      start = n
      size = @tree.numberOfRows.to_i
      loop do
        if direction == :up
          n -= 1
          n = size - 1 if n < 0
        else
          n += 1
          n = 0 if n >= size
        end
        break if n == start
        i = @tree.itemAtRow(n)
        if i
          case target
          when :active
            if !i.unit? && i.active?
              @world.select(i)
              break
            end
          when :unread
            if i.unread
              @world.select(i)
              break
            end
          else
            @world.select(i)
            break
          end
        end
      end
    when :left,:right
      sel = @world.selected
      return unless sel
      unit = sel.unit
      n = @world.units.index(unit)
      return unless n
      start = n
      size = @world.units.length
      loop do
        if direction == :left
          n -= 1
          n = size - 1 if n < 0
        else
          n += 1
          n = 0 if n >= size
        end
        break if n == start
        unit = @world.units[n]
        if unit
          case target
          when :active
            if unit.login?
              t = unit.last_selected_channel
              t = unit unless t
              @world.select(t)
              break
            end
          else
            t = unit.last_selected_channel
            t = unit unless t
            @world.select(t)
            break
          end
        end
      end
    end
  end
end
