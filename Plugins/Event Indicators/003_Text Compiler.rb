if Essentials::VERSION.include?("20")
    alias event_indicator_set_text pbSetTextMessages
    def pbSetTextMessages
        event_indicator_set_text
        pbCompileIndicatorTexts
    end
else
    module Translator
        module_function
        Translator.singleton_class.send(:alias_method, :gather_event_indicator_text, :gather_script_and_event_texts)

        def gather_script_and_event_texts
            gather_event_indicator_text
            pbCompileIndicatorTexts
        end
    end
end

def pbCompileIndicatorTexts
    begin
        t = Time.now.to_i
        mapinfos = pbLoadMapInfos
        mapinfos.each_key do |id|
            if Time.now.to_i - t >= 5
                t = Time.now.to_i
                Graphics.update
            end
            filename = sprintf("Data/Map%03d.rxdata", id)
            next if !pbRgssExists?(filename)
            map = load_data(filename)
            items = []
            map.events.each_value do |event|
                begin
                    event.pages.size.times do |i|  
                        list = event.pages[i].list
                        params = pbEventCommentCompilerIndicator(list)
                        if params
                            text = ""
                            params.each_with_index do |line, k|
                                next if k == 0
                                break if line.nil?
                                text += line
                            end
                            items.push(text) unless text == ""
                        end
                    end
                end
            end
            next if items.empty?
            MessageTypes.addMapMessagesAsHash(id, items)
        end
    rescue Hangup
    end
    Graphics.update
end

def pbEventCommentCompilerIndicator(list)
  parameters = []
  trigger = "Event Indicator"
  return nil if list.nil?
  return nil unless list.is_a?(Array)
  list.each do |item|
    next if ![108, 408].include?(item.code)
    next if item.parameters[0] != trigger
    id = list.index(item) + 1
    loop do
      if list[id] && [108, 408].include?(list[id].code)
        parameters.push(list[id].parameters[0]) 
        id += 1
      else
        break
      end
    end
    return parameters
  end
  return nil
end