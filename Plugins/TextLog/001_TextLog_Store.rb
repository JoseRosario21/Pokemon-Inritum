#===============================================================================
# Text Log - Store and capture
#
# Entries live on PokemonGlobalMetadata via a lazy getter, so existing saves pick
# the log up on first access with no save conversion.
#
# Capture hooks pbMessageDisplay, the single funnel every field message passes
# through. Battle messages are captured separately and are off by default -- one
# battle emits dozens of lines and would flush the story out of the log.
#===============================================================================
class PokemonGlobalMetadata
  def text_log
    @text_log = [] if !@text_log
    return @text_log
  end

  def text_log=(value)
    @text_log = value
  end
end

module TextLog
  module_function

  def entries
    return [] if !$PokemonGlobal
    return $PokemonGlobal.text_log
  end

  def add(text, kind = :message)
    return if !$PokemonGlobal
    text = clean(text)
    return if text.nil? || text.empty?
    log = $PokemonGlobal.text_log
    # Collapse an exact repeat of the previous line. Essentials re-displays the
    # same message in a few places and the duplicates are pure noise.
    return if log.last && log.last[:text] == text && log.last[:kind] == kind
    log.push({ :text => text, :kind => kind })
    log.shift while log.length > LIMIT
  end

  def add_choice(text)
    return if !LOG_CHOICES
    add(text, :choice)
  end

  def clear
    return if !$PokemonGlobal
    $PokemonGlobal.text_log = []
  end

  def any?
    return !entries.empty?
  end

  #-----------------------------------------------------------------------------
  # Control codes
  #
  # pbMessageDisplay resolves these inline rather than through a reusable helper,
  # so the log does its own pass: codes that change *which words appear* are
  # resolved, and everything else -- pacing, window skins, sounds, colours -- is
  # stripped, since none of it means anything in a flat list.
  #-----------------------------------------------------------------------------
  CONTENT_CODES = [
    [/\\v\[([0-9]+)\]/i, proc { |m| $game_variables ? $game_variables[m.to_i].to_s : "" }],
    [/\\n\[([1-8])\]/i,  proc { |m| $game_actors ? $game_actors[m.to_i]&.name.to_s : "" }]
  ]

  # Codes with a bracketed argument that should vanish entirely.
  BRACKETED_CODES = /\\(?:wt|wtnp|ts|w|se|me|l|f|ff|ch|sign|cl)\[[^\]]*\]/i

  # Bare codes with no argument.
  BARE_CODES = /\\(?:sh|op|cl|wu|wm|wd|pg|pog|b|r|g|cn|pt|\^|\.|\|)/i

  def clean(text)
    return nil if text.nil?
    out = text.to_s.dup
    CONTENT_CODES.each do |pattern, resolver|
      out.gsub!(pattern) { resolver.call($1) }
    end
    out.gsub!(/\\pn/i, $player ? $player.name : "")
    out.gsub!(/\\pm/i, $player ? $player.money.to_s : "")
    # After the name codes above, a remaining \n is the newline code.
    out.gsub!(/\\n/i, " ")
    # Codes are replaced with a space, not removed: a pause sitting between two
    # words ("there...\wt[40]Melia") would otherwise weld them together. The
    # whitespace collapse below tidies up the extra spaces this creates.
    out.gsub!(BRACKETED_CODES, " ")
    out.gsub!(BARE_CODES, " ")
    out.gsub!(/\\\[[0-9a-f]{8}\]/i, " ")
    out.gsub!(/\\[1-9\\]/, " ")
    # Formatting tags: stripped rather than kept, because removing codes around
    # them can leave an opening tag with no close, which would bleed colour down
    # the rest of the log.
    out.gsub!(/<\/?[a-z][a-z0-9]*(?:=[^>]*)?>/i, "")
    out.gsub!(/[\r\n]+/, " ")
    out.gsub!(/\s{2,}/, " ")
    return out.strip
  end
end

#===============================================================================
# Capture: field messages
#===============================================================================
alias text_log_pbMessageDisplay pbMessageDisplay unless
  Object.private_method_defined?(:text_log_pbMessageDisplay)

def pbMessageDisplay(msgwindow, message, letterbyletter = true, commandProc = nil)
  shown = message
  begin
    # <nolog> anywhere in the message keeps it out of the log, for system prompts
    # and debug chatter that would only clutter it. The tag is stripped before
    # display, or it would be drawn on screen as literal text.
    if message.to_s.include?("<nolog>")
      shown = message.to_s.gsub("<nolog>", "")
    else
      TextLog.add(message)
    end
  rescue StandardError => e
    echoln("[Text Log] capture failed: #{e.message}") if $DEBUG
    shown = message
  end
  return text_log_pbMessageDisplay(msgwindow, shown, letterbyletter, commandProc)
end

#===============================================================================
# Capture: dialogue choices
#
# pbShowCommands returns the index of the chosen option, so the log can record
# the wording rather than a number -- "> Yes" reads as part of the conversation,
# "> 0" does not.
#===============================================================================
alias text_log_pbShowCommands pbShowCommands unless
  Object.private_method_defined?(:text_log_pbShowCommands)

def pbShowCommands(msgwindow, commands = nil, cmdIfCancel = 0, defaultCmd = 0)
  ret = text_log_pbShowCommands(msgwindow, commands, cmdIfCancel, defaultCmd)
  begin
    if TextLog::LOG_CHOICES && commands && ret.is_a?(Integer) && ret >= 0 && commands[ret]
      TextLog.add_choice(commands[ret])
    end
  rescue StandardError => e
    echoln("[Text Log] choice capture failed: #{e.message}") if $DEBUG
  end
  return ret
end

#===============================================================================
# Capture: battle messages, when enabled
#===============================================================================
class Battle::Scene
  alias text_log_pbDisplayMessage pbDisplayMessage unless method_defined?(:text_log_pbDisplayMessage)

  def pbDisplayMessage(msg, brief = false)
    if TextLog::LOG_BATTLE
      # Not `... if X rescue nil` -- the rescue modifier binds tighter than the
      # if modifier, so it would guard the condition instead of the call.
      begin
        TextLog.add(msg)
      rescue StandardError
        nil
      end
    end
    text_log_pbDisplayMessage(msg, brief)
  end
end
