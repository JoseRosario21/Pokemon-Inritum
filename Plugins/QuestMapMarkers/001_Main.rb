#===============================================================================
# Quest Map Markers
# Draws a gold cross on the region map at the current objective location
# for each active story quest.
#===============================================================================
class PokemonRegionMap_Scene
  alias quest_markers_pbStartScene pbStartScene
  def pbStartScene(as_editor = false, fly_map = false)
    result = quest_markers_pbStartScene(as_editor, fly_map)
    if result != false
      @sprites["cursor"].z = 2 if @sprites["cursor"]
      quest_markers_draw
    end
    return result
  end

  def quest_markers_draw
    return if !$PokemonGlobal
    story_quests = $PokemonGlobal.quests.active_quests.select { |q| QuestMapMarkers::STORY_QUEST_IDS.include?(q.id) }
    return if story_quests.empty?
    k = 0
    story_quests.each do |quest|
      location_name = $quest_data.getStageLocation(quest.id, quest.stage)
      next if location_name.nil? || location_name.empty?
      coords = quest_markers_find_coords(location_name)
      next if !coords
      sprite = BitmapSprite.new(SQUARE_WIDTH - 4, SQUARE_HEIGHT - 4, @viewport)
      sprite.x = point_x_to_screen_x(coords[0]) + SQUARE_WIDTH / 2 + 2
      sprite.y = point_y_to_screen_y(coords[1]) + SQUARE_HEIGHT / 2 + 2
      sprite.z = 1
      quest_markers_draw_cross(sprite.bitmap)
      @sprites["quest_marker#{k}"] = sprite
      k += 1
    end
  end

  # Finds the first town map point whose name matches the given location string.
  # Tries exact match first, then falls back to substring containment so that
  # quest locations like "Stuot Lab" match town map points named "Stuot".
  def quest_markers_find_coords(location_name)
    return nil if !@map || !@map.point
    loc = location_name.downcase
    # Pass 1 — exact match
    @map.point.each do |pt|
      return [pt[0], pt[1]] if pt[2].downcase == loc
    end
    # Pass 2 — substring containment (e.g. "Stuot" in "Stuot Lab")
    @map.point.each do |pt|
      ptn = pt[2].downcase
      return [pt[0], pt[1]] if loc.include?(ptn) || ptn.include?(loc)
    end
    return nil
  end

  # Draws a gold X marker with a black outline onto the given 12×12 bitmap.
  # The sprite is inset 2px inside the tile so it stays fully within the
  # cursor's coverage area — no bleeding into surrounding tiles.
  def quest_markers_draw_cross(bitmap)
    cx   = 6
    cy   = 6
    size = 4   # arms reach (2,2)–(10,10): 8px diagonal in a 12×12 canvas
    gold  = Color.new(255, 215, 0)
    black = Color.new(0, 0, 0)
    # Black outline: 3×3 block at each diagonal step
    (-size..size).each do |i|
      bitmap.fill_rect(cx + i - 1, cy + i - 1, 3, 3, black)  # \ arm
      bitmap.fill_rect(cx + i - 1, cy - i - 1, 3, 3, black)  # / arm
    end
    # Gold core: 2×2 per step, visible at 2x display scale
    (-size..size).each do |i|
      bitmap.fill_rect(cx + i, cy + i, 2, 2, gold)  # \ arm
      bitmap.fill_rect(cx + i, cy - i, 2, 2, gold)  # / arm
    end
  end
end
